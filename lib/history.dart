import 'package:animations/animations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive/hive.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:qrscan/generated/l10n.dart';
import 'package:simple_vcard_parser/simple_vcard_parser.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:wifi_iot/wifi_iot.dart';

import 'model/mail.dart';
import 'model/scan.dart';
import 'package:intl/intl.dart';

import 'model/wifi.dart';
import 'package:qrscan/qrview.dart';

class History extends StatefulWidget {
  const History({
    Key key,
  }) : super(key: key);
  @override
  _HistoryState createState() => _HistoryState();
}

class _HistoryState extends State<History> {
  bool connecting = false;
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
        child: scans.length <= 0
            ? Center(
                child: Padding(
                  padding: EdgeInsets.all(8.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.access_time,
                        size: 96,
                      ),
                      Text(
                        S.of(context).itsEmptyInHere,
                        style: TextStyle(fontSize: 24),
                      ),
                      SizedBox(
                        height: 10,
                      ),
                      Text(
                        S.of(context).aFullListOfScannedQrAndBarcodesWillShow,
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              )
            : ListView.builder(
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
      return ListTile(
        onTap: connecting ? null : () => storeAndConnect(wifi),
        title: Text(wifi.ssid),
        subtitle: Text(dateFormat.format(DateTime.parse(timestamp))),
        leading: Icon(Icons.access_time),
        trailing: AnimatedSwitcher(
            duration: Duration(milliseconds: 300),
            transitionBuilder: (Widget child, Animation<double> animation) =>
                ScaleTransition(
                  child: child,
                  scale: animation,
                ),
            child: connecting ? CircularProgressIndicator() : Icon(Icons.wifi)),
      );
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
      return OpenContainer(
        closedElevation: 0,
        openColor: Theme.of(context).canvasColor,
        closedColor: Theme.of(context).canvasColor,
        closedBuilder: (BuildContext c, VoidCallback action) => ListTile(
          leading: Icon(Icons.access_time),
          trailing: Icon(Icons.contact_phone),
          title: Text("${vc.name[0]} ${vc.name[1]}"),
          subtitle: Text(dateFormat.format(DateTime.parse(timestamp))),
        ),
        openBuilder: (BuildContext c, VoidCallback action) => Scaffold(
          appBar: AppBar(
            title: Text(S.of(context).businessCardDetails),
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 16.0),
                child: Icon(Icons.contact_phone),
              )
            ],
          ),
          body: ListView(
            children: vcardDetails(vc),
          ),
        ),
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
          content: Text(S.of(context).copiedToClipboard),
        ));
      },
      subtitle: Text(dateFormat.format(DateTime.parse(timestamp))),
    );
  }

  List<Widget> vcardDetails(VCard vc) {
    List<Widget> result = List();

    if (vc.name.length > 0)
      result.add(copyTile(
          "${vc.name[0]} ${vc.name.length > 1 ? vc.name[1] : ""}", context,
          subtitle: S.of(context).name));
    if (vc.organisation != "")
      result.add(copyTile(vc.organisation, context,
          subtitle: S.of(context).organisation));
    if (vc.typedTelephone.length > 0) {
      for (dynamic phone in vc.typedTelephone)
        result.add(callTile(phone[0],
            subtitle: phone[1].length > 0 ? phone[1][0] : S.of(context).phone));
    }
    if (vc.email != "") {
      Mail email = Mail();
      email.to = vc.email;
      email.sub = "";
      email.body = "";
      result.add(mailTile(email));
    }
    return result;
  }

  storeAndConnect(Wifi wifi) async {
    setState(() {
      connecting = true;
    });
    bool connected = await WiFiForIoTPlugin.connect(wifi.ssid,
        password: wifi.password,
        joinOnce: false,
        security: wifi.networkSecurity);
    print(connected);
    setState(() {
      connecting = false;
    });
  }
}
