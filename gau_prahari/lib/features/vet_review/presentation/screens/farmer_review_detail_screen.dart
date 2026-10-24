import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../domain/entities/review_message.dart';
import '../../domain/entities/review_request.dart';
import '../../domain/repositories/vet_review_repository.dart';
import '../widgets/review_message_bubble.dart';
import '../widgets/review_status_badge.dart';
import '../widgets/snapshot_view.dart';

/// Screen displaying the submitted review request, immutable clinical snapshot, and live 2-way message thread for the farmer.
class FarmerReviewDetailScreen extends StatefulWidget {
  final String requestId;

  const FarmerReviewDetailScreen({super.key, required this.requestId});

  @override
  State<FarmerReviewDetailScreen> createState() =>
      _FarmerReviewDetailScreenState();
}

class _FarmerReviewDetailScreenState extends State<FarmerReviewDetailScreen> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  bool _isSending = false;
  bool _showSnapshot = false;

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _sendMessage(ReviewRequest request) async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;
    final user = context.read<AuthController>().currentUser;
    if (user == null) return;

    setState(() => _isSending = true);
    try {
      final repo = context.read<VetReviewRepository>();
      await repo.sendMessage(
        requestId: request.id,
        senderUid: user.id,
        senderRole: 'farmer',
        text: text,
        currentStatus: request.status,
      );
      _messageController.clear();
      // Scroll to bottom
      Future.delayed(const Duration(milliseconds: 100), () {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to send message: ${e.toString()}'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthController>().currentUser;
    final repo = context.watch<VetReviewRepository>();

    return StreamBuilder<ReviewRequest?>(
      stream: repo.streamRequestById(widget.requestId),
      builder: (context, requestSnapshot) {
        if (requestSnapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: AppColors.background,
            body: Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
              ),
            ),
          );
        }

        final request = requestSnapshot.data;
        if (request == null) {
          return Scaffold(
            backgroundColor: AppColors.background,
            appBar: AppBar(title: const Text('Review Detail')),
            body: const Center(child: Text('Review request not found.')),
          );
        }

        return Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppBar(
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Review: ${request.cowTagNumber}',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
                Text(
                  'Vet: ${request.veterinarianNameSnapshot}',
                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
              ],
            ),
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 16),
                child: Center(child: ReviewStatusBadge(status: request.status)),
              ),
            ],
          ),
          body: SafeArea(
            child: Column(
              children: [
                // Collapsible Snapshot Banner
                Container(
                  color: AppColors.surface,
                  child: InkWell(
                    onTap: () => setState(() => _showSnapshot = !_showSnapshot),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      child: Row(
                        children: [
                          Icon(
                            _showSnapshot
                                ? Icons.keyboard_arrow_up_rounded
                                : Icons.keyboard_arrow_down_rounded,
                            color: AppColors.primary,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _showSnapshot
                                  ? 'Hide Clinical Snapshot'
                                  : 'View Clinical Snapshot (Cow, Milk & Collar Data)',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.primaryLight,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              'SNAPSHOT',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const Divider(height: 1, color: AppColors.border),

                // Snapshot display when expanded
                if (_showSnapshot)
                  Expanded(
                    flex: 4,
                    child: Container(
                      color: AppColors.background,
                      child: ListView(
                        padding: const EdgeInsets.all(16),
                        children: [
                          SnapshotView(request: request),
                        ],
                      ),
                    ),
                  ),

                // Messages List (streamed)
                Expanded(
                  flex: _showSnapshot ? 3 : 7,
                  child: StreamBuilder<List<ReviewMessage>>(
                    stream: repo.streamMessages(request.id),
                    builder: (context, msgSnapshot) {
                      if (msgSnapshot.connectionState == ConnectionState.waiting) {
                        return const Center(
                          child: CircularProgressIndicator(
                            valueColor:
                                AlwaysStoppedAnimation<Color>(AppColors.primary),
                          ),
                        );
                      }

                      final messages = msgSnapshot.data ?? [];

                      if (messages.isEmpty) {
                        return Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Text(
                              'No messages yet.\nYour request has been delivered to Dr. ${request.veterinarianNameSnapshot}. You can send updates or questions below.',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 13,
                                color: AppColors.textSecondary,
                                height: 1.4,
                              ),
                            ),
                          ),
                        );
                      }

                      return ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        itemCount: messages.length,
                        itemBuilder: (context, index) {
                          final msg = messages[index];
                          final isMe = user != null && msg.senderUid == user.id;
                          return ReviewMessageBubble(
                            message: msg,
                            isMe: isMe,
                          );
                        },
                      );
                    },
                  ),
                ),

                // Bottom Composer or Closed Banner
                if (request.status.isClosed)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                    color: AppColors.surfaceVariant,
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.lock_rounded, size: 16, color: AppColors.textSecondary),
                        SizedBox(width: 8),
                        Text(
                          'This review consultation has been closed by the veterinarian.',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: const BoxDecoration(
                      color: AppColors.surface,
                      border: Border(top: BorderSide(color: AppColors.border)),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _messageController,
                            maxLength: 2000,
                            maxLines: null,
                            decoration: const InputDecoration(
                              hintText: 'Type your message or question...',
                              border: InputBorder.none,
                              counterText: '',
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                            ),
                          ),
                        ),
                        IconButton(
                          icon: _isSending
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.send_rounded, color: AppColors.primary),
                          onPressed: _isSending ? null : () => _sendMessage(request),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
