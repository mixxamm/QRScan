import 'package:flutter/material.dart';
import 'package:hive/hive.dart';

class History extends StatefulWidget {
  const History({
    Key key,
  }) : super(key: key);
  @override
  _HistoryState createState() => _HistoryState();
}

class _HistoryState extends State<History> {
  Map<String, String> map = Map();

  @override
  void initState() {
    initItems();
    super.initState();
  }

  void initItems() {
    var box = Hive.box('scans');
    int length = box.length;
    for (int i = 0; i < length; i++) map[box.keyAt(i)] = box.getAt(i);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      child: ListView.builder(
          itemCount: map.length,
          itemBuilder: (BuildContext context, int index) {
            return ListTile(
              title: Text("test"),
            );
          }),
    );
  }
}
