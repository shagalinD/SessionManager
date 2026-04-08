import 'package:flutter/foundation.dart';

/// Result of validating a scanned URL for the local session flow.
@immutable
class QrParseResult {
  const QrParseResult({this.session, this.rejectionMessage});

  final String? session;
  final String? rejectionMessage;

  bool get isSuccess => session != null;
}

/// Validates QR content that points at this device's local session endpoint.
@immutable
class QrUrlValidator {
  const QrUrlValidator();

  /// Returns session id when [uri] is a valid session request for this device.
  QrParseResult parse({
    required Uri uri,
    required String? deviceWifiIpv4,
  }) {
    final session = uri.queryParameters['session'] ??
        uri.queryParameters['session_id'];
    if (session == null || session.isEmpty) {
      return const QrParseResult(
        rejectionMessage: 'В ссылке нет параметра session.',
      );
    }

    final host = uri.host.toLowerCase();
    if (!_targetsThisDevice(host, deviceWifiIpv4)) {
      final hint = deviceWifiIpv4 != null && deviceWifiIpv4.isNotEmpty
          ? 'В QR должен быть IP этого телефона в Wi‑Fi: $deviceWifiIpv4'
          : 'Используйте локальный IP (192.168.x.x / 10.x) или 127.0.0.1 для эмулятора.';
      return QrParseResult(rejectionMessage: hint);
    }

    final port = uri.hasPort ? uri.port : (uri.scheme == 'https' ? 443 : 80);
    if (port != 8080) {
      return const QrParseResult(
        rejectionMessage: 'Нужен порт 8080 в ссылке.',
      );
    }

    final path = uri.path;
    if (path != '/request' && !path.endsWith('/request')) {
      return const QrParseResult(
        rejectionMessage: 'Путь должен быть /request',
      );
    }

    return QrParseResult(session: session);
  }

  bool _targetsThisDevice(String host, String? deviceWifiIpv4) {
    if (_isLoopback(host)) {
      return true;
    }
    if (deviceWifiIpv4 != null && deviceWifiIpv4.isNotEmpty) {
      return host == deviceWifiIpv4;
    }
    // IP телефона недоступен (симулятор, права, момент до подключения Wi‑Fi):
    // принимаем только «домашние» IPv4, чтобы MVP работал без строгого совпадения.
    return _isPrivateLanIpv4(host);
  }

  bool _isPrivateLanIpv4(String host) {
    final parts = host.split('.');
    if (parts.length != 4) return false;
    final n = parts.map(int.tryParse).toList();
    if (n.any((e) => e == null)) return false;
    final a = n[0]!;
    final b = n[1]!;
    if (a == 10) return true;
    if (a == 172 && b >= 16 && b <= 31) return true;
    if (a == 192 && b == 168) return true;
    return false;
  }

  bool _isLoopback(String host) {
    return host == '127.0.0.1' ||
        host == 'localhost' ||
        host == '::1';
  }
}
