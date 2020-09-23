import 'package:flutter/material.dart';

class EditWidget extends StatefulWidget {
  @override
  _EditWidgetState createState() => _EditWidgetState();
}

class _EditWidgetState extends State<EditWidget> {
  String name;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: Text('Edit'),
        ),
        body: WillPopScope(
          child: Container(
            padding: EdgeInsets.all(10.0),
            child: TextField(
              onChanged: (value) => (name = value),
              decoration: InputDecoration(labelText: 'Name'),
            ),
          ),
          onWillPop: () {
            Navigator.pop(context, name);
            return new Future(() => false);
          },
        ));
  }
  // ···
}
