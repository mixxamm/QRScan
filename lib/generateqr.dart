import 'package:barcode_widget/barcode_widget.dart';
import 'package:flutter/material.dart';
import 'package:qrscan/generated/l10n.dart';

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
              )
            ],
          ),
        ),
      ),
    );
  }
}
