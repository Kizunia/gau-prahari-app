import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/localization/locale_controller.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../domain/entities/chat_message.dart';
import '../controllers/voice_assistant_controller.dart';
import '../widgets/conversation_history_sheet.dart';

/// Dedicated voice assistant screen with interactive transcript,
/// microphone control, multi-state indicators, and conversation management.
class VoiceAssistantScreen extends StatefulWidget {
  const VoiceAssistantScreen({super.key});

  @override
  State<VoiceAssistantScreen> createState() => _VoiceAssistantScreenState();
}

class _VoiceAssistantScreenState extends State<VoiceAssistantScreen>
    with SingleTickerProviderStateMixin {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _textInputController = TextEditingController();
  late AnimationController _pulseAnimController;

  @override
  void initState() {
    super.initState();
    _pulseAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    // Initialize controller with current user's ID if AuthController is in tree
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      try {
        final authCtrl = Provider.of<AuthController?>(context, listen: false);
        final user = authCtrl?.currentUser;
        context.read<VoiceAssistantController>().init(currentOwnerId: user?.id);
      } catch (_) {
        context.read<VoiceAssistantController>().init();
      }
    });
  }

  @override
  void dispose() {
    _pulseAnimController.dispose();
    _scrollController.dispose();
    _textInputController.dispose();
    super.dispose();
  }

  int _prevMessageCount = 0;

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final controller = context.watch<VoiceAssistantController>();
    final locale = context.watch<LocaleController>().locale;
    final messages = controller.messages;

    // Trigger scroll when message count changes
    if (messages.length != _prevMessageCount) {
      _prevMessageCount = messages.length;
      _scrollToBottom();
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              t.translate('voiceAssistant'),
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
            ),
            Text(
              controller.activeConversation?.title ??
                  t.translate('newConversation'),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.normal,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
        actions: [
          // History action
          IconButton(
            tooltip: t.translate('conversationHistory'),
            icon: const Icon(Icons.history_rounded, color: AppColors.primary),
            onPressed: () => ConversationHistorySheet.show(context),
          ),
          // New conversation action
          IconButton(
            tooltip: t.translate('newConversation'),
            icon: const Icon(
              Icons.add_comment_outlined,
              color: AppColors.primary,
            ),
            onPressed: () => controller.startNewConversation(),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Error banner if recoverable error occurred
            if (controller.errorMessage != null)
              _buildErrorBanner(context, controller, t),

            // Transcript View
            Expanded(
              child: messages.isEmpty && controller.currentTranscript == null
                  ? _buildEmptyState(context, t, locale.languageCode)
                  : ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 16,
                      ),
                      itemCount:
                          messages.length +
                          (controller.currentTranscript != null ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (index < messages.length) {
                          return _buildMessageBubble(context, messages[index]);
                        } else {
                          // Real-time speech transcript bubble while listening
                          return _buildListeningBubble(
                            context,
                            controller.currentTranscript!,
                          );
                        }
                      },
                    ),
            ),

            // Status indicator pill
            _buildStatusIndicator(context, controller, t),

            // Microphone and input controls area
            _buildControlBar(context, controller, t, locale.languageCode),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorBanner(
    BuildContext context,
    VoiceAssistantController controller,
    AppLocalizations t,
  ) {
    String errorText;
    switch (controller.errorMessage) {
      case 'permissionDenied':
        errorText = t.translate('permissionDenied');
        break;
      case 'noSpeechDetected':
        errorText = t.translate('noSpeechDetected');
        break;
      case 'speechError':
        errorText = t.translate('speechError');
        break;
      case 'languageNotSupported':
        errorText = t.translate('languageNotSupported');
        break;
      default:
        errorText = controller.errorMessage!;
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.error_outline_rounded,
            color: AppColors.error,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              errorText,
              style: const TextStyle(
                color: AppColors.error,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(
              Icons.close_rounded,
              size: 18,
              color: AppColors.error,
            ),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            onPressed: () => controller.clearError(),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(
    BuildContext context,
    AppLocalizations t,
    String langCode,
  ) {
    String langName = langCode == 'hi'
        ? 'हिन्दी'
        : langCode == 'mr'
        ? 'मराठी'
        : 'English';

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.primaryLight.withValues(alpha: 0.6),
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.2),
                  width: 2,
                ),
              ),
              child: const Icon(
                Icons.record_voice_over_rounded,
                size: 56,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              t.translate('assistantWelcomeTitle'),
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              t.translate('assistantWelcomeSubtitle'),
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.surfaceVariant,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.language_rounded,
                    size: 16,
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Language: $langName',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primaryDark,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageBubble(BuildContext context, ChatMessage message) {
    final isUser = message.isUser;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: isUser
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isUser) ...[
            CircleAvatar(
              backgroundColor: AppColors.primary,
              radius: 16,
              child: const Icon(
                Icons.smart_toy_rounded,
                color: Colors.white,
                size: 18,
              ),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isUser ? AppColors.primary : AppColors.surface,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(isUser ? 16 : 4),
                  bottomRight: Radius.circular(isUser ? 4 : 16),
                ),
                border: Border.all(
                  color: isUser ? AppColors.primaryDark : AppColors.border,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: isUser
                    ? CrossAxisAlignment.end
                    : CrossAxisAlignment.start,
                children: [
                  Text(
                    message.content,
                    style: TextStyle(
                      color: isUser ? Colors.white : AppColors.textPrimary,
                      fontSize: 15,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _formatMessageTime(message.createdAt),
                    style: TextStyle(
                      color: isUser
                          ? Colors.white.withValues(alpha: 0.7)
                          : AppColors.textMuted,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (isUser) ...[
            const SizedBox(width: 8),
            CircleAvatar(
              backgroundColor: AppColors.primaryDark,
              radius: 16,
              child: const Icon(
                Icons.person_rounded,
                color: Colors.white,
                size: 18,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildListeningBubble(BuildContext context, String currentWords) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.8),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                  bottomLeft: Radius.circular(16),
                  bottomRight: Radius.circular(4),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      currentWords.isEmpty ? '...' : currentWords,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  const SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white70),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          CircleAvatar(
            backgroundColor: AppColors.primaryDark,
            radius: 16,
            child: const Icon(
              Icons.person_rounded,
              color: Colors.white,
              size: 18,
            ),
          ),
        ],
      ),
    );
  }

  String _formatMessageTime(int epochMillis) {
    final dt = DateTime.fromMillisecondsSinceEpoch(
      epochMillis,
      isUtc: true,
    ).toLocal();
    final hour = dt.hour.toString().padLeft(2, '0');
    final minute = dt.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  Widget _buildStatusIndicator(
    BuildContext context,
    VoiceAssistantController controller,
    AppLocalizations t,
  ) {
    if (controller.isListening) {
      if (!_pulseAnimController.isAnimating) {
        _pulseAnimController.repeat(reverse: true);
      }
      return Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.error.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            FadeTransition(
              opacity: _pulseAnimController,
              child: const Icon(
                Icons.mic_rounded,
                color: AppColors.error,
                size: 18,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              t.translate('listeningState'),
              style: const TextStyle(
                color: AppColors.error,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
          ],
        ),
      );
    } else if (controller.isProcessing) {
      return Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.secondary.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.secondary.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(AppColors.secondary),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              t.translate('processingState'),
              style: const TextStyle(
                color: AppColors.secondary,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
          ],
        ),
      );
    } else if (controller.isSpeaking) {
      return InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => controller.stopSpeaking(),
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.volume_up_rounded,
                color: AppColors.primary,
                size: 18,
              ),
              const SizedBox(width: 8),
              Text(
                t.translate('speakingState'),
                style: const TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
              const SizedBox(width: 8),
              const Icon(
                Icons.stop_circle_outlined,
                size: 16,
                color: AppColors.primary,
              ),
            ],
          ),
        ),
      );
    }

    if (_pulseAnimController.isAnimating) {
      _pulseAnimController.stop();
    }

    return const SizedBox(height: 12);
  }

  Widget _buildControlBar(
    BuildContext context,
    VoiceAssistantController controller,
    AppLocalizations t,
    String langCode,
  ) {
    Color micBg;
    IconData micIcon;
    String actionLabel;

    if (controller.isListening) {
      micBg = AppColors.error;
      micIcon = Icons.stop_rounded;
      actionLabel = t.translate('tapToStopListening');
    } else if (controller.isSpeaking) {
      micBg = AppColors.warning;
      micIcon = Icons.stop_rounded;
      actionLabel = t.translate('tapToStopSpeaking');
    } else if (controller.isProcessing) {
      micBg = AppColors.textMuted;
      micIcon = Icons.hourglass_top_rounded;
      actionLabel = t.translate('processingState');
    } else {
      micBg = AppColors.primary;
      micIcon = Icons.mic_rounded;
      actionLabel = t.translate('idleState');
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: const Border(top: BorderSide(color: AppColors.border)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Optional text query input row for touch fallback
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _textInputController,
                  decoration: InputDecoration(
                    hintText: t.translate('typeOrSpeak'),
                    hintStyle: const TextStyle(
                      fontSize: 14,
                      color: AppColors.textMuted,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    filled: true,
                    fillColor: AppColors.background,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: const BorderSide(color: AppColors.border),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: const BorderSide(color: AppColors.border),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: const BorderSide(
                        color: AppColors.primary,
                        width: 1.5,
                      ),
                    ),
                  ),
                  onSubmitted: (value) {
                    if (value.trim().isNotEmpty) {
                      controller.submitQuery(value, languageCode: langCode);
                      _textInputController.clear();
                    }
                  },
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.send_rounded, color: AppColors.primary),
                onPressed: () {
                  final text = _textInputController.text.trim();
                  if (text.isNotEmpty) {
                    controller.submitQuery(text, languageCode: langCode);
                    _textInputController.clear();
                  }
                },
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Central prominent Microphone button
          GestureDetector(
            onTap: () => controller.toggleListening(languageCode: langCode),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              width: 68,
              height: 68,
              decoration: BoxDecoration(
                color: micBg,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: micBg.withValues(alpha: 0.4),
                    blurRadius: controller.isListening ? 18 : 8,
                    spreadRadius: controller.isListening ? 4 : 1,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Icon(micIcon, color: Colors.white, size: 34),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            actionLabel,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
