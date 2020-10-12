import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive/hive.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:qr_code_scanner/qr_code_scanner.dart';
import 'package:qrscan/generated/l10n.dart';
import 'package:screen/screen.dart';
import 'package:simple_vcard_parser/simple_vcard_parser.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:wifi_iot/wifi_iot.dart';

import 'model/mail.dart';
import 'model/wifi.dart';

class QRViewExample extends StatefulWidget {
  const QRViewExample({
    Key key,
  }) : super(key: key);

  @override
  State<StatefulWidget> createState() => _QRViewExampleState();
}

enum QRType { text, website, wifi, tel, sms, mail, vcard }

class _QRViewExampleState extends State<QRViewExample> {
  var qrText = '';
  QRViewController controller;
  final GlobalKey qrKey = GlobalKey();
  bool flash = false;
  bool front = false;
  bool scanning = true;
  QRType qrType = QRType.text;
  Wifi wifi;
  bool connecting = false;
  String phoneNumber, message;
  Mail mail;
  VCard vc;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: <Widget>[
          Expanded(
            flex: 4,
            child: AnimatedSwitcher(
              duration: Duration(milliseconds: 300),
              transitionBuilder: (Widget child, Animation<double> animation) =>
                  ScaleTransition(
                child: child,
                scale: animation,
              ),
              child: scanning ? scanView() : resultView(),
            ),
          ),
        ],
      ),
    );
  }

  Widget resultView() {
    return Center(
        child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (qrType == QRType.wifi)
          ListTile(
            onTap: connecting ? null : storeAndConnect,
            title: Text(wifi.ssid),
            subtitle: Text(wifi.password),
            trailing: AnimatedSwitcher(
                duration: Duration(milliseconds: 300),
                transitionBuilder:
                    (Widget child, Animation<double> animation) =>
                        ScaleTransition(
                          child: child,
                          scale: animation,
                        ),
                child: connecting
                    ? CircularProgressIndicator()
                    : Icon(Icons.wifi)),
          )
        else if (qrType == QRType.website)
          ListTile(
            title: Text(qrText),
            trailing: Icon(MdiIcons.web),
            onTap: () async {
              await launch(qrText);
            },
          )
        else if (qrType == QRType.sms)
          ListTile(
            title: Text(message),
            subtitle: Text(phoneNumber),
            trailing: Icon(Icons.message, color: Colors.redAccent),
            onTap: () async {
              await launch(
                  "sms:$phoneNumber?body=$message"); // TODO: Dit werkt niet op iOS, canLaunch gebruiken om op te vangen.
            },
          )
        else if (qrType == QRType.tel)
          callTile(qrText.substring(4), subtitle: "Phone")
        else if (qrType == QRType.mail)
          mailTile(mail)
        else if (qrType == QRType.vcard)
          Flexible(
            child: ListView(
              children: vcardDetails(),
            ),
          )
        else
          copyTile(qrText, context, subtitle: "Text"),
        RaisedButton(
          child: Text(
            S.of(context).newScan,
            style: TextStyle(color: Colors.white),
          ),
          color: Colors.red,
          onPressed: () {
            setState(() {
              scanning = true;
            });
          },
        )
      ],
    ));
  }

  List<Widget> vcardDetails() {
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

  Widget scanView() {
    return Stack(children: [
      QRView(
        key: qrKey,
        onQRViewCreated: _onQRViewCreated,
        overlay: QrScannerOverlayShape(
          borderColor: Colors.blue,
          borderRadius: 15,
          borderLength: 50,
          borderWidth: 3,
          cutOutSize: MediaQuery.of(context).size.height * 0.45,
          overlayColor: flash && front ? Colors.white70 : Colors.black45,
        ),
      ),
      Align(
        alignment: Alignment.bottomCenter,
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                onPressed: () {
                  setState(() {
                    flash = !flash;
                  });
                  controller.toggleFlash();
                  _setBrightness();
                },
                icon: Icon(
                  flash ? Icons.flash_on : Icons.flash_off,
                  color: Colors.white,
                  size: 38,
                ),
              ),
              IconButton(
                onPressed: () {
                  setState(() {
                    front = !front;
                  });
                  controller.flipCamera();
                  _setBrightness();
                },
                icon: Icon(
                  front ? MdiIcons.cameraFront : MdiIcons.cameraRear,
                  color: Colors.white,
                  size: 38,
                ),
              )
            ],
          ),
        ),
      )
    ]);
  }

  storeAndConnect() async {
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

  void _onQRViewCreated(QRViewController controller) {
    this.controller = controller;
    controller.scannedDataStream.listen((scanData) {
      controller.pauseCamera();
      setState(() {
        qrText = scanData;
        var scans = Hive.box("scans");
        scans.put(DateTime.now().toIso8601String(), qrText);
        scanning = false;
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
        } else if (qrText.startsWith("SMSTO:") || qrText.startsWith("SMS:")) {
          int firstDivider = qrText.indexOf(":");
          int secondDivider = qrText.indexOf(":", firstDivider + 1);
          phoneNumber = qrText.substring(firstDivider + 1, secondDivider);
          message = qrText.substring(secondDivider + 1);

          qrType = QRType.sms;
        } else if (qrText.startsWith("tel:")) {
          qrType = QRType.tel;
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
        } else if (qrText.startsWith("BEGIN:VCARD")) {
          vc = VCard(qrText);
          qrType = QRType.vcard;
        } else
          qrType = QRType.text;
      });
    });
  }

  void _setBrightness() async {
    if (front && flash)
      Screen.setBrightness(1);
    else
      Screen.setBrightness(-1);
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }
}

ListTile copyTile(String text, BuildContext context, {String subtitle}) {
  return ListTile(
    title: Text(text),
    trailing: Icon(
      Icons.content_copy,
      color: Colors.redAccent,
    ),
    subtitle: Text(subtitle ?? ""),
    onTap: () {
      Clipboard.setData(ClipboardData(text: text));
      Scaffold.of(context).showSnackBar(
          SnackBar(content: Text(S.of(context).copiedToClipboard)));
    },
  );
}

ListTile callTile(String phone, {String subtitle}) {
  return ListTile(
    title: Text(phone),
    trailing: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
            padding: EdgeInsets.all(0),
            alignment: Alignment.centerRight,
            enableFeedback: true,
            icon: Icon(
              Icons.call,
              color: Colors.redAccent,
            ),
            onPressed: () async {
              await launch("tel:$phone");
            }),
        IconButton(
          padding: EdgeInsets.all(0),
          alignment: Alignment.centerRight,
          enableFeedback: true,
          icon: Icon(Icons.message, color: Colors.redAccent),
          onPressed: () async {
            await launch("sms:$phone");
          },
        )
      ],
    ),
    subtitle: Text(subtitle ?? ""),
  );
}

ListTile mailTile(Mail email) {
  return ListTile(
    title: Text(email.to ?? ""),
    subtitle: Text(email.sub != "" ? email.sub : "Email"),
    trailing: Icon(
      Icons.mail,
      color: Colors.redAccent,
    ),
    onTap: () async {
      await launch(
          "mailto:${email.to}?subject=${email.sub}&body=${email.body}");
    },
  );
}
