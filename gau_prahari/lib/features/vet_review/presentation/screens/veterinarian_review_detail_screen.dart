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

/// Screen displaying assigned review request details, immutable clinical snapshot,
/// conversation thread, and case closure for veterinarians.
class VeterinarianReviewDetailScreen extends StatefulWidget {
  final String requestId;

  const VeterinarianReviewDetailScreen({super.key, required this.requestId});

  @override
  State<VeterinarianReviewDetailScreen> createState() =>
      _VeterinarianReviewDetailScreenState();
}

class _VeterinarianReviewDetailScreenState
    extends State<VeterinarianReviewDetailScreen> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  bool _isSending = false;
  bool _showSnapshot = true;

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _sendVetReply(ReviewRequest request) async {
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
        senderRole: 'veterinarian',
        text: text,
        currentStatus: request.status,
      );
      _messageController.clear();
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
            content: Text('Failed to send reply: ${e.toString()}'),
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

  Future<void> _confirmCloseRequest(ReviewRequest request) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Close Review Request'),
        content: const Text(
          'Are you sure you want to close this case? Once closed, this consultation thread becomes terminal and read-only for both you and the farmer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Close Case', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final user = context.read<AuthController>().currentUser;
      if (user == null) return;

      try {
        final repo = context.read<VetReviewRepository>();
        await repo.closeReviewRequest(
          requestId: request.id,
          veterinarianUid: user.id,
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Review request has been successfully closed.'),
              backgroundColor: AppColors.success,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Could not close request: ${e.toString()}'),
              backgroundColor: AppColors.error,
            ),
          );
        }
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
            appBar: AppBar(title: const Text('Case Review')),
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
                  'Case: ${request.cowTagNumber}',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
                Text(
                  'Farmer: ${request.farmerNameSnapshot}',
                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
              ],
            ),
            actions: [
              Center(child: ReviewStatusBadge(status: request.status)),
              const SizedBox(width: 8),
              if (!request.status.isClosed)
                IconButton(
                  icon: const Icon(Icons.check_circle_outline_rounded, color: AppColors.error),
                  tooltip: 'Close Request',
                  onPressed: () => _confirmCloseRequest(request),
                ),
              const SizedBox(width: 8),
            ],
          ),
          body: SafeArea(
            child: Column(
              children: [
                // Collapsible Snapshot Header
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
                                  ? 'Collapse Clinical Snapshot'
                                  : 'Expand Clinical Snapshot (Cow & Telemetry)',
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

                // Snapshot display
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

                // Conversation thread
                Expanded(
                  flex: _showSnapshot ? 3 : 7,
                  child: StreamBuilder<List<ReviewMessage>>(
                    stream: repo.streamMessages(request.id),
                    builder: (context, msgSnapshot) {
                      if (msgSnapshot.connectionState == ConnectionState.waiting) {
                        return const Center(
                          child: CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                          ),
                        );
                      }

                      final messages = msgSnapshot.data ?? [];

                      if (messages.isEmpty) {
                        return Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Text(
                              'No conversation yet.\nProvide clinical guidance, treatment directions, or request further information below.',
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

                // Message composer or Closed banner
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
                          'This clinical review is closed. No further messages can be added.',
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
                              hintText: 'Type your clinical assessment or advice...',
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
                              : const Icon(Icons.send_rounded, color: Color(0xFF1565C0)),
                          onPressed: _isSending ? null : () => _sendVetReply(request),
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
