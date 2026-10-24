import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/localization/app_localizations.dart';
import '../controllers/voice_assistant_controller.dart';
import '../screens/voice_assistant_screen.dart';

/// Reusable entry point button for opening the Voice Assistant screen.
/// Placed in the AppBar actions of authenticated workflow screens.
class VoiceAssistantButton extends StatelessWidget {
  final Color? color;
  final double size;
  final String? screenName;
  final Map<String, dynamic>? contextData;

  const VoiceAssistantButton({
    super.key,
    this.color,
    this.size = 24.0,
    this.screenName,
    this.contextData,
  });

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);

    return IconButton(
      tooltip: t.translate('voiceAssistant'),
      icon: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: (color ?? AppColors.primary).withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: (color ?? AppColors.primary).withValues(alpha: 0.25),
          ),
        ),
        child: Icon(
          Icons.mic_rounded,
          color: color ?? AppColors.primary,
          size: size - 4,
        ),
      ),
      onPressed: () {
        if (screenName != null) {
          try {
            context.read<VoiceAssistantController>().setScreenContext(
              screenName: screenName!,
              contextData: contextData,
            );
          } catch (_) {}
        }
        Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (_) => const VoiceAssistantScreen()));
      },
    );
  }
}
