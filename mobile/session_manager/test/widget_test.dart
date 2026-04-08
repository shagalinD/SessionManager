import 'package:flutter_test/flutter_test.dart';

import 'package:session_manager/features/qr/qr_url_validator.dart';

void main() {
  test('QrUrlValidator accepts device IP and session', () {
    const v = QrUrlValidator();
    final uri = Uri.parse('http://192.168.1.10:8080/request?session=abc123');
    final r = v.parse(uri: uri, deviceWifiIpv4: '192.168.1.10');
    expect(r.session, 'abc123');
    expect(r.isSuccess, true);
  });

  test('QrUrlValidator rejects wrong host when device IP known', () {
    const v = QrUrlValidator();
    final uri = Uri.parse('http://192.168.1.99:8080/request?session=abc');
    final r = v.parse(uri: uri, deviceWifiIpv4: '192.168.1.10');
    expect(r.session, isNull);
    expect(r.rejectionMessage, isNotNull);
  });

  test('QrUrlValidator allows loopback for emulator', () {
    const v = QrUrlValidator();
    final uri = Uri.parse('http://127.0.0.1:8080/request?session=x');
    final r = v.parse(uri: uri, deviceWifiIpv4: null);
    expect(r.session, 'x');
  });

  test('QrUrlValidator accepts private LAN when WiFi IP unknown', () {
    const v = QrUrlValidator();
    final uri = Uri.parse('http://192.168.0.5:8080/request?session=z');
    final r = v.parse(uri: uri, deviceWifiIpv4: null);
    expect(r.session, 'z');
  });
}
