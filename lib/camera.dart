import 'dart:async';

import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:tensor_real_time_1/ImagePreview.dart';
import 'package:tflite/tflite.dart';
import 'dart:math' as math;
import 'package:image/image.dart' as imglib;

import 'models.dart';

typedef void Callback(List<dynamic> list, int h, int w);

class Camera extends StatefulWidget {
  final List<CameraDescription> cameras;
  final Callback setRecognitions;
  final String model;

  Camera(this.cameras, this.model, this.setRecognitions);

  @override
  _CameraState createState() => new _CameraState();
}

class _CameraState extends State<Camera> {
  CameraController controller;
  bool isDetecting = false;

  Future<void> loadModel() async {
    String res;
    switch (widget.model) {
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
            numThreads: 1,
            // useGpuDelegate: true,
            model: "assets/ssd_mobilenet.tflite",
            labels: "assets/ssd_mobilenet.txt");
    }
    // print('result: $res');
    // print('result: $_model');
  }

  @override
  void initState() {
    super.initState();
    print('result: initiate capturing');
    loadModel().then((value) {
      if (widget.cameras == null || widget.cameras.length < 1) {
        print('No camera is found');
      } else {
        controller = new CameraController(
            widget.cameras[0], ResolutionPreset.high,
            enableAudio: false);
        controller.initialize().then(
          (_) {
            if (!mounted) {
              return;
            }
            setState(() {});

            controller.startImageStream(
              (CameraImage img) async {
                print('result: img captured');
                if (!isDetecting) {
                  print('result: processing...');
                  isDetecting = true;
                  if (widget.model == ssd) {
                    var recognitions = await applyModelOnFrame(img);

                    widget.setRecognitions(recognitions, img.height, img.width);

                    List<dynamic> newRecogList = []; //growable list
                    String recognizedObj = '';
                    dynamic elem;
                    bool isDetected = false;
                    Image imgFinal;
                    List<double> CroppingAreaList;

                    // print('result: ${recognitions}');

                    for (var element in recognitions) {
                      recognizedObj = element['detectedClass'];
                      if (recognizedObj == 'keyboard') {
                        elem = element;
                        isDetected = true;
                        break;
                      }
                    }

                    if (isDetected) {
                      print('result: detected');
                      await controller.stopImageStream();
                      await controller?.dispose();

                      newRecogList.insert(0, elem);

                      widget.setRecognitions(
                          newRecogList, img.height, img.width);

                      CroppingAreaList = croppingAreaCalculator(
                          newRecogList, img.height, img.width);

                      imgFinal = await convertYUV420toImageColor(
                          img, CroppingAreaList);

                      await Future.delayed(
                        Duration(milliseconds: 250),
                        (() {}),
                      );
                      img = null;
                      isDetected = false;
                      newRecogList = [];
                      recognitions = [];
                      elem = null;

                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (context) => new ImagePreview(img: imgFinal),
                        ),
                      );
                    } else {
                      print('result: did not detected');
                      isDetecting = false;
                    }
                  }
                }
              },
            );
          },
        );
      }
    });
  }

  Future<List<dynamic>> applyModelOnFrame(CameraImage img) async {
    var detectedObjects = await Tflite.detectObjectOnFrame(
      bytesList: img.planes.map((plane) {
        return plane.bytes;
      }).toList(),
      model: widget.model == yolo ? "YOLO" : "SSDMobileNet",
      imageHeight: img.height,
      imageWidth: img.width,
      imageMean: widget.model == yolo ? 0 : 127.5,
      imageStd: widget.model == yolo ? 255.0 : 127.5,
      numResultsPerClass: 1,
      // rotation: 0,
      threshold: 0.45,
    );

    return detectedObjects;
  }

  // static const shift = (0xFF << 24);
  Future<Image> convertYUV420toImageColor(
      CameraImage image, List<double> croppedArea) async {
    // try {
    int width1 = (croppedArea[0]).round();
    int left = (croppedArea[1]).round();
    int height1 = (croppedArea[2]).round();
    int top = (croppedArea[3]).round();

    int width = image.width;
    int height = image.height;
    int uvRowStride = image.planes[1].bytesPerRow;
    int uvPixelStride = image.planes[1].bytesPerPixel;

    // imgLib -> Image package from https://pub.dartlang.org/packages/image
    var img = imglib.Image(width1, height1); // Create Image buffer

    // for (int x = 0; x < width1; x++) {
    //   for (int y = 0; y < height1; y++) {
    //     if (img.boundsSafe(x, y)) {
    //       img.setPixelRgba(x, y, 255, 255, 0, 255);
    //     }
    //   }
    // }

    for (int x = top; x < top + height1; x++) {
      for (int y = left; y < left + width1; y++) {
        int uvIndex =
            uvPixelStride * (x / 2).floor() + uvRowStride * (y / 2).floor();
        int index = y * width + x;

        int yp = image.planes[0].bytes[index];
        int up = image.planes[1].bytes[uvIndex];
        int vp = image.planes[2].bytes[uvIndex];
        // Calculate pixel color
        int r = (yp + vp * 1436 / 1024 - 179).round().clamp(0, 255);
        int g = (yp - up * 46549 / 131072 + 44 - vp * 93604 / 131072 + 91)
            .round()
            .clamp(0, 255);
        int b = (yp + up * 1814 / 1024 - 227).round().clamp(0, 255);

        if (img.boundsSafe((width1 - 1) - (y - left), x - top)) {
          img.setPixelRgba((width1 - 1) - (y - left), x - top, r, g, b, 255);
        }
      }
    }

    // }

    imglib.PngEncoder pngEncoder = new imglib.PngEncoder(level: 0, filter: 0);
    List<int> png = pngEncoder.encodeImage(img);
    // muteYUVProcessing = false;
    return Image.memory(png);
    // } catch (e) {
    //   print(">>>>>>>>>>>> ERROR:" + e.toString());
    // }
    // return null;
  }

  List<double> croppingAreaCalculator(
      List<dynamic> recognitionResult, int _imageHeight, int _imageWidth) {
    var x, y, w, h;
    var _x = recognitionResult[0]["rect"]["x"];
    var _w = recognitionResult[0]["rect"]["w"];
    var _y = recognitionResult[0]["rect"]["y"];
    var _h = recognitionResult[0]["rect"]["h"];

    x = _x * _imageHeight;
    y = _y * _imageWidth;
    w = _w * _imageHeight;
    h = _h * _imageWidth;

    double left = math.max(0, x);
    double top = math.max(0, y);
    double width = w;
    double height = h;
    List<double> croppedArea = [];
    croppedArea.addAll([width, left, height, top]);

    return croppedArea;
  }

  Future<dynamic> release() async => await Tflite.close();

  // @override
  // void dispose() async {
  //   // await release();
  //   await controller.dispose();
  //   super.dispose();
  // }

  @override
  Widget build(BuildContext context) {
    if (controller == null || !controller.value.isInitialized) {
      return Container();
    }

    var tmp = MediaQuery.of(context).size;
    var screenH = math.max(tmp.height, tmp.width);
    var screenW = math.min(tmp.height, tmp.width);
    tmp = controller.value.previewSize;
    var previewH = math.max(tmp.height, tmp.width);
    var previewW = math.min(tmp.height, tmp.width);
    var screenRatio = screenH / screenW;
    var previewRatio = previewH / previewW;

    return OverflowBox(
      maxHeight:
          screenRatio > previewRatio ? screenH : screenW / previewW * previewH,
      maxWidth:
          screenRatio > previewRatio ? screenH / previewH * previewW : screenW,
      child: CameraPreview(controller),
    );
  }
}
