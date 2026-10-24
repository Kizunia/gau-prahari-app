import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/localization/app_localizations.dart';
import '../screens/voice_assistant_screen.dart';

/// Reusable entry point button for opening the Voice Assistant screen.
/// Placed in the AppBar actions of authenticated workflow screens.
class VoiceAssistantButton extends StatelessWidget {
  final Color? color;
  final double size;

  const VoiceAssistantButton({super.key, this.color, this.size = 24.0});

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
        Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (_) => const VoiceAssistantScreen()));
      },
    );
  }
}
