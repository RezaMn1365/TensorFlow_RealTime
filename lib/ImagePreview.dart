import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image/image.dart' as imglib;
import 'package:tensor_real_time_1/main.dart';

class ImagePreview extends StatelessWidget {
  final Image img;
  // final Uint8List img;

  const ImagePreview({Key key, this.img}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: Text("Preview Image"),
        ),
        body: Column(
          children: [
            Expanded(
              flex: 9,
              child: Center(child: img),
            ),
            Expanded(
              flex: 1,
              child: ElevatedButton(
                onPressed: () {
                  // Navigator.pop(context);
                  Navigator.pushReplacement(context,
                      MaterialPageRoute(builder: (context) => MyAppLeg()));
                },
                child: Text('Back'),
              ),
            )
          ],
        ));
  }
}
