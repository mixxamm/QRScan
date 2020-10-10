import 'package:flutter/material.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:qr_code_scanner/qr_code_scanner.dart';
import 'package:screen/screen.dart';

class QRViewExample extends StatefulWidget {
  const QRViewExample({
    Key key,
  }) : super(key: key);

  @override
  State<StatefulWidget> createState() => _QRViewExampleState();
}

class _QRViewExampleState extends State<QRViewExample> {
  var qrText = '';
  QRViewController controller;
  final GlobalKey qrKey = GlobalKey();
  bool flash = false;
  bool front = false;
  bool scanning = true;

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
        Text(qrText),
        RaisedButton(
          child: Text("Scan again"),
          onPressed: () {
            setState(() {
              scanning = true;
            });
          },
        )
      ],
    ));
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
          cutOutSize: MediaQuery.of(context).size.height * 0.5,
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

  void _onQRViewCreated(QRViewController controller) {
    this.controller = controller;
    controller.scannedDataStream.listen((scanData) {
      controller.pauseCamera();
      setState(() {
        qrText = scanData;
        scanning = false;
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
