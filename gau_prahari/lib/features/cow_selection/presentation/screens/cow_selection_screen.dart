import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:gau_prahari/core/constants/app_colors.dart';
import 'package:gau_prahari/features/auth/presentation/controllers/auth_controller.dart';
import 'package:gau_prahari/features/collar_import/presentation/screens/collar_import_screen.dart';
import 'package:gau_prahari/features/cow_selection/domain/entities/cow.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../shared/widgets/language_selector.dart';
import 'qr_scanner_screen.dart';

class CowSelectionScreen extends StatelessWidget {
  const CowSelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authController = context.watch<AuthController>();
    final user = authController.currentUser;
    final t = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(t.translate('appName')),
        actions: [
          IconButton(
            tooltip: t.translate('scanQrCode'),
            icon: const Icon(Icons.qr_code_scanner_rounded, color: AppColors.primary),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const QrScannerScreen()),
              );
            },
          ),
          const LanguageSelector(),
          const SizedBox(width: 8),
          IconButton(
            tooltip: t.translate('signOut'),
            icon: const Icon(Icons.logout_rounded, color: AppColors.textSecondary),
            onPressed: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: Text(t.translate('signOutConfirmTitle')),
                  content: Text(t.translate('signOutConfirmMessage')),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      child: Text(t.translate('cancel')),
                    ),
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(true),
                      child: Text(t.translate('signOut'), style: const TextStyle(color: AppColors.error)),
                    ),
                  ],
                ),
              );

              if (confirm == true && context.mounted) {
                await context.read<AuthController>().logout();
              }
            },
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            // User status card
            if (user != null) _buildUserCard(user),
            const SizedBox(height: 16),

            // Scan QR Ear Tag Action Card
            InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const QrScannerScreen()),
                );
              },
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppColors.primary, AppColors.primaryDark],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.25),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.qr_code_scanner_rounded,
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            t.translate('scanQrCode'),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            t.translate('scanQrPrompt'),
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.85),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(
                      Icons.arrow_forward_ios_rounded,
                      color: Colors.white70,
                      size: 16,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Section Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    t.translate('selectAnimalForAnalysis'),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.primaryLight,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    t.translate('roundII'),
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Demo Cattle Cards ready for Phase 1 & 2
            _buildCowCard(
              context: context,
              cow: const Cow(
                id: 'COW-104',
                tagNumber: 'RFID-9821',
                breed: 'Gir / Sahiwal Cross',
                ageYears: 4,
                lactationStage: 'Early Lactation (Day 42)',
                status: 'Ready for Test',
              ),
              statusColor: AppColors.primary,
            ),
            const SizedBox(height: 12),
            _buildCowCard(
              context: context,
              cow: const Cow(
                id: 'COW-101',
                tagNumber: 'RFID-7714',
                breed: 'Murrah Buffalo',
                ageYears: 5,
                lactationStage: 'Mid Lactation (Day 110)',
                status: 'Collar History Available',
              ),
              statusColor: AppColors.secondary,
            ),
            const SizedBox(height: 12),
            _buildCowCard(
              context: context,
              cow: const Cow(
                id: 'COW-102',
                tagNumber: 'RFID-5529',
                breed: 'Tharparkar',
                ageYears: 3,
                lactationStage: 'Fresh (Day 14)',
                status: 'Needs Milk Test',
              ),
              statusColor: AppColors.warning,
            ),

            const SizedBox(height: 24),

            // Pipeline info indicator
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surfaceVariant,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline_rounded, color: AppColors.primary, size: 22),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      t.translate('nextPhaseInfo'),
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                        height: 1.3,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.qr_code_scanner_rounded),
        label: Text(t.translate('scanQrCode')),
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const QrScannerScreen()),
          );
        },
      ),
    );
  }

  Widget _buildUserCard(dynamic user) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primaryLight,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.15)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: AppColors.primary,
            radius: 22,
            child: Text(
              user.name.isNotEmpty ? user.name[0] : 'U',
              style: const TextStyle(
                color: AppColors.textLight,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user.name,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primaryDark,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${user.role} • ${user.identifier}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.primaryAccent,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCowCard({
    required BuildContext context,
    required Cow cow,
    required Color statusColor,
  }) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: AppColors.border),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => CollarImportScreen(cow: cow),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceVariant,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.pets_rounded,
                      size: 20,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          cow.id,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        Text(
                          '${cow.breed} • Tag: ${cow.tagNumber}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(Icons.arrow_forward_ios_rounded, size: 16, color: AppColors.textMuted),
                ],
              ),
              const Divider(height: 24, color: AppColors.border),
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 8,
                runSpacing: 6,
                children: [
                  Text(
                    cow.lactationStage,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      cow.status,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: statusColor,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
