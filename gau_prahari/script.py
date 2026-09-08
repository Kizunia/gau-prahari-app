import re

file_path = r'c:\Users\lenovo\OneDrive\Documents\Hackathon Project\gau-prahari-app\gau_prahari\lib\features\milk_tester\presentation\screens\milk_tester_screen.dart'

with open(file_path, 'r', encoding='utf-8') as f:
    content = f.read()

# Add import
import_stmt = "import '../../../../core/localization/app_localizations.dart';\n"
content = content.replace("import 'package:provider/provider.dart';", "import 'package:provider/provider.dart';\n" + import_stmt)

# Add 'final t = AppLocalizations.of(context);' to MilkTesterScreen.build
content = content.replace("Widget build(BuildContext context) {", "Widget build(BuildContext context) {\n    final t = AppLocalizations.of(context);", 1)

# Replace 'Handheld Milk Tester' (removing const from FittedBox)
content = content.replace("title: const FittedBox(", "title: FittedBox(")
content = content.replace("child: Text('Handheld Milk Tester'),", "child: Text(t.translate('handheldMilkTester')),")

# Add 'final t = AppLocalizations.of(context);' to _MilkTesterView.build
content = content.replace("Widget build(BuildContext context) {\n    final controller", "Widget build(BuildContext context) {\n    final t = AppLocalizations.of(context);\n    final controller")

# Replace 'Collar Telemetry Attached...'
content = content.replace("'Collar Telemetry Attached: ${collarHistory!.recordCount} Days (Mean Skin Temp: ${collarHistory!.meanSkinTemperature.toStringAsFixed(1)} °C, THI: ${collarHistory!.meanThi.toStringAsFixed(1)})'", "t.translate('collarTelemetryAttached', args: {'days': collarHistory!.recordCount.toString(), 'skinTemp': collarHistory!.meanSkinTemperature.toStringAsFixed(1), 'thi': collarHistory!.meanThi.toStringAsFixed(1)})")

# Replace mode strings inside _buildModeSelector
content = content.replace("'Live Arduino (HC-05)'", "t.translate('liveArduino')")
content = content.replace("'Demo Simulation'", "t.translate('demoSimulation')")
content = content.replace("Widget _buildModeSelector(BuildContext context, MilkTesterController controller) {", "Widget _buildModeSelector(BuildContext context, MilkTesterController controller) {\n    final t = AppLocalizations.of(context);")

# Replace MQ2 Gas and Distance
content = content.replace("'MQ-2 Gas: ${meta.gasMq2}'", "t.translate('mq2Gas', args: {'value': meta.gasMq2.toString()})")
content = content.replace("'Dist: ${meta.distanceCm} cm'", "t.translate('distanceCm', args: {'value': meta.distanceCm.toString()})")
content = content.replace("Widget _buildHardwareSensorsBadge(BuildContext context, MilkTesterController controller) {", "Widget _buildHardwareSensorsBadge(BuildContext context, MilkTesterController controller) {\n    final t = AppLocalizations.of(context);")

# Replace hardware status strings
content = content.replace("Widget _buildHardwareStatusCard(\n    BuildContext context,\n    MilkTesterController controller,\n  ) {", "Widget _buildHardwareStatusCard(\n    BuildContext context,\n    MilkTesterController controller,\n  ) {\n    final t = AppLocalizations.of(context);")

content = content.replace("'Tester Standby (Arduino HC-05 Ready)'", "t.translate('testerStandbyArduino')")
content = content.replace("'Tester Standby (Mock Provider)'", "t.translate('testerStandbyMock')")
content = content.replace("'Scanning for HC-05 Bluetooth...'", "t.translate('scanningHc05')")
content = content.replace("'Scanning for ESP32 Milk Tester...'", "t.translate('scanningEsp32')")
content = content.replace("'Connecting to HC-05 (9600 baud)...'", "t.translate('connectingHc05')")
content = content.replace("'Connecting via BLE/GATT...'", "t.translate('connectingBle')")
content = content.replace("'Connected to Milk Tester'", "t.translate('connectedToMilkTester')")
content = content.replace("'Reading ADC & Spectrometry Stream...'", "t.translate('readingAdcStream')")
content = content.replace("'Reading Spectrometry & Conductivity Cell...'", "t.translate('readingSpectrometry')")
content = content.replace("'Milk Sample Captured Successfully'", "t.translate('milkSampleCaptured')")
content = content.replace("'Hardware Communication Error'", "t.translate('hardwareCommunicationError')")
content = content.replace("'Animal: ${cow.id} (${cow.breed})'", "'${t.translate(\"animalPrefix\")} ${cow.id} (${cow.breed})'")

# Replace preset strings
content = content.replace("Widget _buildPresetSelector(\n    BuildContext context,\n    MilkTesterController controller,\n  ) {", "Widget _buildPresetSelector(\n    BuildContext context,\n    MilkTesterController controller,\n  ) {\n    final t = AppLocalizations.of(context);")

content = content.replace("'Simulation Presets (Testing Profiles)'", "t.translate('simulationPresets')")
content = content.replace("'Healthy Sample'", "t.translate('healthySample')")
content = content.replace("'Subclinical Risk'", "t.translate('subclinicalRisk')")
content = content.replace("'Clinical Mastitis'", "t.translate('clinicalMastitis')")

# Replace empty state strings
content = content.replace("_buildEmptyState(),", "_buildEmptyState(context),")
content = content.replace("Widget _buildEmptyState() {", "Widget _buildEmptyState(BuildContext context) {\n    final t = AppLocalizations.of(context);")
content = content.replace("const Text(\n            'No Milk Measurement Yet'", "Text(\n            t.translate('noMilkMeasurementYet')")
content = content.replace("const Text(\n            'Insert sampling strip into the tester and tap Start Analysis to stream real-time spectrometry & conductivity metrics.'", "Text(\n            t.translate('noMilkMeasurementDescription')")

# Replace measuring indicator strings
content = content.replace("_buildMeasuringIndicator(controller.state)", "_buildMeasuringIndicator(context, controller.state)")
content = content.replace("Widget _buildMeasuringIndicator(MilkTestingState state) {", "Widget _buildMeasuringIndicator(BuildContext context, MilkTestingState state) {\n    final t = AppLocalizations.of(context);")
content = content.replace("const Text(\n            'Acquiring Milk Telemetry...'", "Text(\n            t.translate('acquiringMilkTelemetry')")
content = content.replace("'Handshaking BLE / RFCOMM connection...'", "t.translate('handshakingConnection')")
content = content.replace("'Processing multi-wavelength optical transmission...'", "t.translate('processingOpticalTransmission')")

# Replace results section strings
content = content.replace("Widget _buildResultsSection(\n    BuildContext context,\n    MilkMeasurement measurement,\n  ) {", "Widget _buildResultsSection(\n    BuildContext context,\n    MilkMeasurement measurement,\n  ) {\n    final t = AppLocalizations.of(context);")
content = content.replace("const Expanded(\n              child: Text(\n                'Sample Measurements'", "Expanded(\n              child: Text(\n                t.translate('sampleMeasurements')")
content = content.replace("const Row(\n                mainAxisSize: MainAxisSize.min,\n                children: [\n                  Icon(Icons.check_rounded, size: 14, color: AppColors.success),\n                  SizedBox(width: 4),\n                  Text(\n                    'Valid Sample'", "Row(\n                mainAxisSize: MainAxisSize.min,\n                children: [\n                  const Icon(Icons.check_rounded, size: 14, color: AppColors.success),\n                  const SizedBox(width: 4),\n                  Text(\n                    t.translate('validSample')")
content = content.replace("title: 'Temperature'", "title: t.translate('temperatureLabel')")
content = content.replace("subtitle: 'Normal: 35.0 - 37.8 °C'", "subtitle: t.translate('normalTempRange')")
content = content.replace("title: 'pH Value'", "title: t.translate('phValueLabel')")
content = content.replace("subtitle: 'Normal: 6.50 - 6.80'", "subtitle: t.translate('normalPhRange')")
content = content.replace("title: 'Conductivity'", "title: t.translate('conductivityLabel')")
content = content.replace("subtitle: 'Normal: 4.5 - 5.8 mS/cm'", "subtitle: t.translate('normalConductivityRange')")
content = content.replace("title: 'Somatic Cell Count'", "title: t.translate('somaticCellCountLabel')")
content = content.replace("subtitle: 'Risk Threshold: >250k'", "subtitle: t.translate('riskThresholdScc')")
content = content.replace("title: 'Fat Content'", "title: t.translate('fatContentLabel')")
content = content.replace("subtitle: 'Typical: 3.5 - 5.0 %'", "subtitle: t.translate('typicalFatRange')")
content = content.replace("title: 'SNF (Solids)'", "title: t.translate('snfSolidsLabel')")
content = content.replace("subtitle: 'Typical: 8.0 - 9.5 %'", "subtitle: t.translate('typicalSnfRange')")

# Misc replacements in build
content = content.replace("'Retake Milk Measurement'", "t.translate('retakeMilkMeasurement')")
content = content.replace("'Start Milk Sample Analysis'", "t.translate('startMilkSampleAnalysis')")
content = content.replace("'Stop Live'", "t.translate('stopLive')")
content = content.replace("'Live Stream'", "t.translate('liveStream')")
content = content.replace("const Row(\n                mainAxisAlignment: MainAxisAlignment.center,\n                children: [\n                  Icon(Icons.sensors_rounded, size: 14, color: AppColors.success),\n                  SizedBox(width: 6),\n                  Text(\n                    'Real-Time Live Sensor Telemetry Active (1.5s refresh)'", "Row(\n                mainAxisAlignment: MainAxisAlignment.center,\n                children: [\n                  const Icon(Icons.sensors_rounded, size: 14, color: AppColors.success),\n                  const SizedBox(width: 6),\n                  Text(\n                    t.translate('realTimeSensorActive')")
content = content.replace("'Proceed to Mastitis Risk Analysis'", "t.translate('proceedToAnalysis')")
content = content.replace("const Center(\n                    child: Card(\n                      child: Padding(\n                        padding: EdgeInsets.all(24),\n                        child: Column(\n                          mainAxisSize: MainAxisSize.min,\n                          children: [\n                            CircularProgressIndicator(\n                              valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),\n                            ),\n                            SizedBox(height: 16),\n                            Text(\n                              'Running AI Mastitis Risk Model...',", "Center(\n                    child: Card(\n                      child: Padding(\n                        padding: const EdgeInsets.all(24),\n                        child: Column(\n                          mainAxisSize: MainAxisSize.min,\n                          children: [\n                            const CircularProgressIndicator(\n                              valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),\n                            ),\n                            const SizedBox(height: 16),\n                            Text(\n                              t.translate('runningAiModel'),")
content = content.replace("'Analysis Error: $e'", "t.translate('analysisError', args: {'error': e.toString()})")

with open(file_path, 'w', encoding='utf-8') as f:
    f.write(content)
