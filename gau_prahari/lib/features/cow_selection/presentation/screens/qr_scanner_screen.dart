import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../data/repositories/cow_repository_impl.dart';
import '../../../collar_import/presentation/screens/collar_import_screen.dart';

/// Screen for scanning animal RFID/QR Ear Tags using the device camera.
/// Includes real camera scanning, visual viewfinder overlay, torch/camera toggle,
/// and quick demo simulation buttons for emulator and test environments.
class QrScannerScreen extends StatefulWidget {
  const QrScannerScreen({super.key});

  @override
  State<QrScannerScreen> createState() => _QrScannerScreenState();
}

class _QrScannerScreenState extends State<QrScannerScreen> with SingleTickerProviderStateMixin {
  final MobileScannerController _scannerController = MobileScannerController(
    detectionSpeed: DetectionSpeed.normal,
    facing: CameraFacing.back,
    torchEnabled: false,
  );

  final CowRepositoryImpl _cowRepository = CowRepositoryImpl();
  bool _isProcessing = false;
  late AnimationController _laserAnimController;

  @override
  void initState() {
    super.initState();
    _laserAnimController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _laserAnimController.dispose();
    _scannerController.dispose();
    super.dispose();
  }

  Future<void> _handleBarcode(String rawValue) async {
    if (_isProcessing) return;
    setState(() => _isProcessing = true);

    final cow = await _cowRepository.getCowById(rawValue);

    if (!mounted) return;

    if (cow != null) {
      final t = AppLocalizations.of(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  t.translate('cowFetchedSuccess', args: {'cowId': cow.id}),
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          backgroundColor: AppColors.success,
          duration: const Duration(seconds: 2),
        ),
      );

      // Navigate directly into Collar Telemetry import for this fetched cow
      await Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => CollarImportScreen(cow: cow),
        ),
      );
    } else {
      final t = AppLocalizations.of(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            t.translate('cowNotFound', args: {'cowId': rawValue}),
          ),
          backgroundColor: AppColors.error,
          duration: const Duration(seconds: 2),
        ),
      );
      // Allow re-scanning after delay
      await Future.delayed(const Duration(milliseconds: 1200));
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          t.translate('scanQrCode'),
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
        ),
        actions: [
          IconButton(
            icon: ValueListenableBuilder<MobileScannerState>(
              valueListenable: _scannerController,
              builder: (context, state, child) {
                return Icon(
                  state.torchState == TorchState.on
                      ? Icons.flash_on_rounded
                      : Icons.flash_off_rounded,
                  color: state.torchState == TorchState.on
                      ? Colors.amber
                      : Colors.white70,
                );
              },
            ),
            onPressed: () => _scannerController.toggleTorch(),
          ),
          IconButton(
            icon: const Icon(Icons.flip_camera_ios_rounded, color: Colors.white70),
            onPressed: () => _scannerController.switchCamera(),
          ),
        ],
      ),
      body: Stack(
        children: [
          // 1. Camera Viewfinder
          MobileScanner(
            controller: _scannerController,
            onDetect: (capture) {
              final barcodes = capture.barcodes;
              if (barcodes.isNotEmpty) {
                final code = barcodes.first.rawValue;
                if (code != null && code.isNotEmpty) {
                  _handleBarcode(code);
                }
              }
            },
            errorBuilder: (context, error) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.videocam_off_rounded, color: Colors.white54, size: 54),
                      const SizedBox(height: 12),
                      const Text(
                        'Camera unavailable (Emulator / Permission)',
                        style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Use the Quick Demo Test buttons below to simulate scanning COW-104.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white70, fontSize: 13),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),

          // 2. Translucent Cutout & Target Finder Box
          Positioned.fill(
            child: _buildScannerOverlay(context),
          ),

          // 3. Instruction Banner at Top
          Positioned(
            top: 20,
            left: 24,
            right: 24,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.65),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white24),
              ),
              child: Row(
                children: [
                  const Icon(Icons.qr_code_scanner_rounded, color: AppColors.success, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      t.translate('scanQrPrompt'),
                      style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 4. Quick Demo Test Bar (Allows instant testing for COW-104 on Emulator/PC)
          Positioned(
            bottom: 30,
            left: 20,
            right: 20,
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.surface.withValues(alpha: 0.95),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.3),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.touch_app_rounded, size: 16, color: AppColors.primary),
                      const SizedBox(width: 6),
                      Text(
                        t.translate('orScanManual'),
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      _buildSimulateChip(
                        label: 'COW-104 (Gir Cross)',
                        cowId: 'COW-104',
                        color: AppColors.primary,
                      ),
                      _buildSimulateChip(
                        label: 'COW-101 (Buffalo)',
                        cowId: 'COW-101',
                        color: AppColors.secondary,
                      ),
                      _buildSimulateChip(
                        label: 'COW-102 (Tharparkar)',
                        cowId: 'COW-102',
                        color: AppColors.warning,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // 5. Loading Indicator during lookup
          if (_isProcessing)
            Container(
              color: Colors.black.withValues(alpha: 0.6),
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Colors.white)),
                    SizedBox(height: 16),
                    Text(
                      'Fetching Cattle Telemetry Profile...',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildScannerOverlay(BuildContext context) {
    final scanAreaSize = MediaQuery.of(context).size.width * 0.72;

    return Center(
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Target box
          Container(
            width: scanAreaSize,
            height: scanAreaSize,
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.success, width: 2.5),
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          // Corner accents
          SizedBox(
            width: scanAreaSize + 8,
            height: scanAreaSize + 8,
            child: Stack(
              children: [
                _cornerPiece(top: 0, left: 0),
                _cornerPiece(top: 0, right: 0),
                _cornerPiece(bottom: 0, left: 0),
                _cornerPiece(bottom: 0, right: 0),
              ],
            ),
          ),
          // Animated scanning laser bar
          AnimatedBuilder(
            animation: _laserAnimController,
            builder: (context, child) {
              final topOffset = -scanAreaSize / 2 + (_laserAnimController.value * scanAreaSize);
              return Transform.translate(
                offset: Offset(0, topOffset),
                child: Container(
                  width: scanAreaSize - 16,
                  height: 3,
                  decoration: BoxDecoration(
                    color: AppColors.success,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.success.withValues(alpha: 0.8),
                        blurRadius: 8,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _cornerPiece({double? top, double? bottom, double? left, double? right}) {
    return Positioned(
      top: top,
      bottom: bottom,
      left: left,
      right: right,
      child: Container(
        width: 22,
        height: 22,
        decoration: BoxDecoration(
          color: Colors.transparent,
          border: Border(
            top: top != null ? const BorderSide(color: Colors.white, width: 4) : BorderSide.none,
            bottom: bottom != null ? const BorderSide(color: Colors.white, width: 4) : BorderSide.none,
            left: left != null ? const BorderSide(color: Colors.white, width: 4) : BorderSide.none,
            right: right != null ? const BorderSide(color: Colors.white, width: 4) : BorderSide.none,
          ),
        ),
      ),
    );
  }

  Widget _buildSimulateChip({
    required String label,
    required String cowId,
    required Color color,
  }) {
    return InkWell(
      onTap: () => _handleBarcode(cowId),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.qr_code_2_rounded, size: 14, color: color),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
