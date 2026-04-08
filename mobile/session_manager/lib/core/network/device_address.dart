import 'package:network_info_plus/network_info_plus.dart';

/// Resolves the device Wi‑Fi IPv4 address for validating scanned QR URLs.
class DeviceAddressService {
  DeviceAddressService({NetworkInfo? networkInfo})
      : _networkInfo = networkInfo ?? NetworkInfo();

  final NetworkInfo _networkInfo;

  Future<String?> getWifiIpv4() async {
    final ip = await _networkInfo.getWifiIP();
    if (ip == null || ip.isEmpty || ip == '0.0.0.0') {
      return null;
    }
    return ip;
  }
}
