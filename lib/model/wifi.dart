import 'package:wifi_iot/wifi_iot.dart';

class Wifi {
  final String ssid, password;
  final NetworkSecurity networkSecurity;
  final bool hidden;

  Wifi(this.ssid, this.password, this.networkSecurity, this.hidden);
}
