import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:tflite/tflite.dart';
import 'dart:math' as math;

import 'camera.dart';
import 'bndbox.dart';
import 'models.dart';

class HomePage extends StatefulWidget {
  final List<CameraDescription> cameras;

  HomePage(this.cameras);

  @override
  _HomePageState createState() => new _HomePageState();
}

class _HomePageState extends State<HomePage> {
  List<dynamic> _recognitions;
  int _imageHeight = 0;
  int _imageWidth = 0;
  String _model = "";

  @override
  void initState() {
    super.initState();
  }

  loadModel() async {
    String res;
    switch (_model) {
      case yolo:
        res = await Tflite.loadModel(
          model: "assets/yolov2_tiny.tflite",
          labels: "assets/yolov2_tiny.txt",
        );
        break;

      // case mobilenet:
      //   res = await Tflite.loadModel(
      //       model: "assets/mobilenet_v1_1.0_224.tflite",
      //       labels: "assets/mobilenet_v1_1.0_224.txt");
      //   break;

      // case posenet:
      //   res = await Tflite.loadModel(
      //       model: "assets/posenet_mv1_075_float_from_checkpoints.tflite");
      //   break;

      default:
        res = await Tflite.loadModel(
            numThreads: 4,
            // useGpuDelegate: true,
            model: "assets/ssd_mobilenet.tflite",
            labels: "assets/ssd_mobilenet.txt");
    }
    // print('result: $res');
    // print('result: $_model');
  }

  onSelect(model) async {
    await loadModel();
    setState(() {
      _model = model;
    });
  }

  setRecognitions(recognitions, imageHeight, imageWidth) {
    setState(() {
      _recognitions = recognitions;
      _imageHeight = imageHeight;
      _imageWidth = imageWidth;
    });
  }

  @override
  Widget build(BuildContext context) {
    Size screen = MediaQuery.of(context).size;
    return Scaffold(
      body: _model == ""
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  ElevatedButton(
                    child: const Text(ssd),
                    onPressed: () async => await onSelect(ssd),
                  ),
                  ElevatedButton(
                    child: const Text(yolo),
                    onPressed: () async => await onSelect(yolo),
                  ),
                  // ElevatedButton(
                  //   child: const Text(mobilenet),
                  //   onPressed: () => onSelect(mobilenet),
                  // ),
                  // ElevatedButton(
                  //   child: const Text(posenet),
                  //   onPressed: () => onSelect(posenet),
                  // ),
                ],
              ),
            )
          : Column(
              children: [
                Expanded(
                  flex: 9,
                  child: Stack(
                    children: [
                      Camera(
                        widget.cameras,
                        _model,
                        setRecognitions,
                      ),
                      BndBox(
                          _recognitions == null ? [] : _recognitions,
                          math.max(_imageHeight, _imageWidth),
                          math.min(_imageHeight, _imageWidth),
                          screen.height,
                          screen.width,
                          _model),
                    ],
                  ),
                ),
                // Expanded(
                //   flex: 1,
                //   child: ElevatedButton(
                //     onPressed: () {
                //       setState(() {
                //         _model = "";
                //       });
                //     },
                //     child: Text('Reset'),
                //   ),
                // )
              ],
            ),
    );
  }
}
