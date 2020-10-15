import 'package:barcode_widget/barcode_widget.dart';
import 'package:flutter/material.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:qrscan/generated/l10n.dart';
import 'package:barcode_image/barcode_image.dart';
import 'package:image/image.dart' as i;
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share/share.dart';

class GenerateQR extends StatefulWidget {
  const GenerateQR({
    Key key,
  }) : super(key: key);
  @override
  _GenerateQRState createState() => _GenerateQRState();
}

class _GenerateQRState extends State<GenerateQR> {
  TextEditingController _controller;
  String qrText = "";

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
    _controller.addListener(() {
      updateQRText();
    });
  }

  void updateQRText() {
    setState(() {
      qrText = _controller.text;
    });
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Center(
        child: SingleChildScrollView(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: TextField(
                  controller: _controller,
                  decoration: InputDecoration(
                    border: OutlineInputBorder(),
                    labelText: S.of(context).qrCodeText,
                  ),
                ),
              ),
              Container(
                color: Color(0xFFFAFAFA),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 32.0),
                  child: BarcodeWidget(
                    barcode: Barcode.qrCode(),
                    data: qrText,
                    backgroundColor: Color(0xFFFAFAFA),
                  ),
                ),
              ),
              IconButton(
                iconSize: 32,
                icon: Icon(Icons.share),
                onPressed: () async {
                  final image = i.Image(400, 400);

                  i.fill(image, i.getColor(255, 255, 255));

                  drawBarcode(image, Barcode.qrCode(), qrText,
                      height: 300, width: 300, x: 50, y: 50);

                  var path = await getApplicationDocumentsDirectory();
                  File file = File('${path.path}/qr.png');
                  file.writeAsBytesSync(i.encodePng(image));
                  Share.shareFiles(["${path.path}/qr.png"]);
                },
              )
            ],
          ),
        ),
      ),
    );
  }
}
