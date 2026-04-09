import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';

import '../../../core/network/device_address.dart';
import '../../credentials/presentation/credentials_notifier.dart';
import '../qr_url_validator.dart';

class QrScanScreen extends StatefulWidget {
  const QrScanScreen({super.key, required this.deviceAddress});

  final DeviceAddressService deviceAddress;

  @override
  State<QrScanScreen> createState() => _QrScanScreenState();
}

class _QrScanScreenState extends State<QrScanScreen> {
  late final MobileScannerController _controller;
  bool _handled = false;
  DateTime _lastSnack = DateTime.fromMillisecondsSinceEpoch(0);

  @override
  void initState() {
    super.initState();
    _controller = MobileScannerController(
      formats: const [BarcodeFormat.qrCode],
      detectionSpeed: DetectionSpeed.normal,
      facing: CameraFacing.back,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _maybeSnack(String message) {
    final now = DateTime.now();
    if (now.difference(_lastSnack) < const Duration(seconds: 2)) return;
    _lastSnack = now;
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_handled) return;
    for (final barcode in capture.barcodes) {
      final raw = barcode.rawValue ?? barcode.displayValue;
      if (raw == null || raw.isEmpty) continue;
      final uri = Uri.tryParse(raw.trim());
      if (uri == null) {
        _maybeSnack('Не удалось разобрать ссылку из QR.');
        continue;
      }
      final ip = await widget.deviceAddress.getWifiIpv4();
      final result = const QrUrlValidator().parse(uri: uri, deviceWifiIpv4: ip);
      if (result.isSuccess && result.session != null) {
        _handled = true;
        await _controller.stop();
        if (!mounted) return;
        context.read<SessionFlowNotifier>().setSessionFromQr(
              sessionId: result.session!,
              requestUri: uri,
            );
        Navigator.of(context).pop(true);
        return;
      }
      if (result.rejectionMessage != null) {
        _maybeSnack(result.rejectionMessage!);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan session QR'),
      ),
      body: Stack(
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: _onDetect,
          ),
          Positioned(
            left: 16,
            right: 16,
            bottom: 32,
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  'После скана сами данные не отправляются — откройте список, '
                  'выберите запись и «Отправить на сервер».\n'
                  'QR с Mac: http://<IP_Mac>:8080/request?session=…',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
