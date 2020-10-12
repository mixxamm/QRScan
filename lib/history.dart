import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive/hive.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:simple_vcard_parser/simple_vcard_parser.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:wifi_iot/wifi_iot.dart';

import 'model/mail.dart';
import 'model/scan.dart';
import 'package:intl/intl.dart';

import 'model/wifi.dart';
import 'qrview.dart';

class History extends StatefulWidget {
  const History({
    Key key,
  }) : super(key: key);
  @override
  _HistoryState createState() => _HistoryState();
}

class _HistoryState extends State<History> {
  List<Scan> scans = List();
  final DateFormat dateFormat = DateFormat('yyyy-MM-dd HH:mm:ss');
  @override
  void initState() {
    super.initState();
    loadScans();
  }

  void loadScans() {
    var box = Hive.box("scans");
    for (int i = box.length - 1; i >= 0; i--) {
      scans.add(Scan(box.keyAt(i).toString(), box.getAt(i)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
        child: ListView.builder(
      itemCount: scans.length,
      itemBuilder: (_, index) =>
          getQRType(scans[index].data, scans[index].timestamp),
    ));
  }

  dynamic getQRType(String qrText, String timestamp) {
    QRType qrType;
    String phoneNumber;
    String message;
    Mail mail;
    VCard vc;
    Wifi wifi;
    RegExp urlRegExp = RegExp(
        "(https?:\/\/(?:www\.|(?!www))[a-zA-Z0-9][a-zA-Z0-9-]+[a-zA-Z0-9]\.[^\s]{2,}|www\.[a-zA-Z0-9][a-zA-Z0-9-]+[a-zA-Z0-9]\.[^\s]{2,}|https?:\/\/(?:www\.|(?!www))[a-zA-Z0-9]+\.[^\s]{2,}|www\.[a-zA-Z0-9]+\.[^\s]{2,})");
    if (qrText.startsWith("WIFI:S:")) {
      qrType = QRType.wifi;
      RegExp ssidRegExp = RegExp(
          "(?<=S:)((?:[^\;\?\"\$\[\\\]\+])|(?:\\[\\;,:]))+(?<!\\;)(?=;)");
      RegExp passwordRegExp =
          RegExp("(?<=P:)((?:\\[\\;,:])|(?:[^;]))+(?<!\\;)(?=;)");
      RegExp networkTypeRegExp = RegExp("(?<=T:)[a-zA-Z]+(?=;)");
      String ssid = ssidRegExp.stringMatch(qrText);
      String password = passwordRegExp.stringMatch(qrText);
      String nws = networkTypeRegExp.stringMatch(qrText);
      NetworkSecurity networkSecurity;
      if (nws == "WPA")
        networkSecurity = NetworkSecurity.WPA;
      else if (nws == "WEP")
        networkSecurity = NetworkSecurity.WEP;
      else
        networkSecurity = NetworkSecurity.NONE;
      wifi = Wifi(ssid, password, networkSecurity, false);
    } else if (qrText.startsWith("http") && urlRegExp.hasMatch(qrText)) {
      qrType = QRType.website;
      return ListTile(
        onTap: () async {
          await launch(qrText);
        },
        leading: Icon(Icons.access_time),
        trailing: Icon(MdiIcons.web),
        title: Text(qrText),
        subtitle: Text(dateFormat.format(DateTime.parse(timestamp))),
      );
    } else if (qrText.startsWith("SMSTO:") || qrText.startsWith("SMS:")) {
      int firstDivider = qrText.indexOf(":");
      int secondDivider = qrText.indexOf(":", firstDivider + 1);
      phoneNumber = qrText.substring(firstDivider + 1, secondDivider);
      message = qrText.substring(secondDivider + 1);
      qrType = QRType.sms;
      return ListTile(
        leading: Icon(Icons.access_time),
        trailing: Icon(Icons.message),
        title: Text(phoneNumber),
        onTap: () async {
          await launch(
              "sms:$phoneNumber?body=$message"); // TODO: Dit werkt niet op iOS, canLaunch gebruiken om op te vangen.
        },
        subtitle: Text(dateFormat.format(DateTime.parse(timestamp))),
      );
    } else if (qrText.startsWith("tel:")) {
      qrType = QRType.tel;
      return ListTile(
        leading: Icon(Icons.access_time),
        trailing: Icon(MdiIcons.phone),
        title: Text(qrText.substring(4)),
        onTap: () async {
          await launch(qrText);
        },
        subtitle: Text(dateFormat.format(DateTime.parse(timestamp))),
      );
    } else if (qrText.startsWith("MATMSG:TO:")) {
      int toEnd = qrText.indexOf(";"),
          subStart = qrText.indexOf(":", toEnd + 1),
          subStop = qrText.indexOf(";", subStart + 1),
          bodyStart = qrText.indexOf(":", subStop);
      mail = Mail();
      mail.to = qrText.substring(10, toEnd);
      mail.sub = qrText.substring(subStart + 1, subStop);
      mail.body = qrText.substring(bodyStart + 1, qrText.length - 2);
      qrType = QRType.mail;
      return mail;
    } else if (qrText.startsWith("BEGIN:VCARD")) {
      qrType = QRType.vcard;
      vc = VCard(qrText);
      return ListTile(
        leading: Icon(Icons.access_time),
        trailing: Icon(Icons.contact_phone),
        title: Text("${vc.name[0]} ${vc.name[1]}"),
        subtitle: Text(dateFormat.format(DateTime.parse(timestamp))),
      );
    } else
      qrType = QRType.text;
    return ListTile(
      leading: Icon(Icons.access_time),
      trailing: Icon(MdiIcons.text),
      title: Text(qrText),
      onTap: () {
        Clipboard.setData(ClipboardData(text: qrText));
        Scaffold.of(context).showSnackBar(SnackBar(
          content: Text("Copied to clipboard!"),
        ));
      },
      subtitle: Text(dateFormat.format(DateTime.parse(timestamp))),
    );
  }
}
