import 'dart:async';
import 'dart:io';
import 'package:camera_macos/camera_macos_arguments.dart';
import 'package:camera_macos/camera_macos_controller.dart';
import 'package:camera_macos/camera_macos_file.dart';
import 'package:camera_macos/camera_macos_view.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:screen_capturer/screen_capturer.dart';
import 'package:apple_vision_face_detection/apple_vision_face_detection.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // final cameras = await availableCameras();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Timer App',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const TimerScreen(),
    );
  }
}

class TimerScreen extends StatefulWidget {
  const TimerScreen({super.key});

  @override
  TimerScreenState createState() => TimerScreenState();
}

class TimerScreenState extends State<TimerScreen> {
  List<Uint8List> faceList = [];
  List<String> screenshotList = [];
  bool _isTimerRunning = false;
  String _timerText = "00:00:00";
  late Timer _timer;
  int _start = 0;
  bool isDetecting = false;
  bool cameraStarted = false;
  bool _isAccessAllowed = false;
  final GlobalKey cameraKey = GlobalKey(debugLabel: "cameraKey");
  late CameraMacOSController macOSController;

  CapturedData? _lastCapturedData;
  @override
  void initState() {
    super.initState();
    _init();
  }

  void _init() async {
    _isAccessAllowed = await ScreenCapturer.instance.isAccessAllowed();
    if (!_isAccessAllowed) {
      requestScreenCapturePermission();
    }
    debugPrint("is access allowed: $_isAccessAllowed");
  }

  Future<void> detectFaces(Uint8List imageBytes) async {
    debugPrint("detecting face....");
    try {
      AppleVisionFaceDetectionController visionController =
          AppleVisionFaceDetectionController();

      List<Rect>? faces = await visionController.processImage(
          imageBytes, const Size(1000, 700));
      if (faces != null && faces.isNotEmpty) {
        _handleClickCapture(CaptureMode.screen);
        setState(() {
          faceList.add(imageBytes);
        });
        debugPrint("Faces found: ${faces.length}");
      } else {
        debugPrint("No faces detected.");
      }
    } catch (e) {
      debugPrint('Error detecting faces: $e');
    }
  }

  void requestScreenCapturePermission() async {
    debugPrint("request permisssion");
    await ScreenCapturer.instance.requestAccess();
  }

  void _handleClickCapture(CaptureMode mode) async {
    debugPrint("taking screenshot .......");
    Directory directory = await getApplicationDocumentsDirectory();
    String imageName =
        'Screenshot-${DateTime.now().millisecondsSinceEpoch}.png';
    String imagePath = '${directory.path}/Screenshots/$imageName';
    debugPrint(imagePath);
    _lastCapturedData = await ScreenCapturer.instance.capture(
      mode: mode,
      imagePath: imagePath,
      silent: true,
      copyToClipboard: true,
    );
    if (_lastCapturedData != null) {
      screenshotList.add(imagePath);
    } else {
      // ignore: avoid_print
      debugPrint('User canceled capture');
    }
    setState(() {});
  }

  void startTimer() {
    const oneSec = Duration(seconds: 1);
    _timer = Timer.periodic(
      oneSec,
      (Timer timer) {
        if (mounted) {
          setState(() {
            _start++;
            _timerText = _formatTime(_start);
          });
        }
        takePhoto();
      },
    );
  }

  String _formatTime(int seconds) {
    final hours = (seconds ~/ 3600).toString().padLeft(2, '0');
    final minutes = ((seconds % 3600) ~/ 60).toString().padLeft(2, '0');
    final secs = (seconds % 60).toString().padLeft(2, '0');
    return "$hours:$minutes:$secs";
  }

  void takePhoto() async {
    debugPrint("taking photo ..........");
    try {
      CameraMacOSFile? file = await macOSController.takePicture();
      if (file != null) {
        debugPrint("taken shot");
        Uint8List? bytes = file.bytes;
        if (bytes != null) {
          detectFaces(bytes);
        } else {
          debugPrint("Failed to get image bytes.");
        }
      } else {
        debugPrint("No file returned from camera controller.");
      }
    } catch (e) {
      debugPrint("Error taking picture: $e");
    }
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Timer App'),
        actions: [
          IconButton(
              tooltip: "Ask for screenshot",
              onPressed: () {
                requestScreenCapturePermission();
              },
              icon: const Icon(Icons.radio)),
          IconButton(
              tooltip: "Take photo of yourself",
              onPressed: () => takePhoto(),
              icon: const Icon(Icons.photo_camera)),
          IconButton(
              tooltip: "Take screenshot [Screen]",
              onPressed: () => _handleClickCapture(CaptureMode.screen),
              icon: const Icon(Icons.screenshot)),
          IconButton(
              tooltip: "Take screenshot [Window]",
              onPressed: () => _handleClickCapture(CaptureMode.window),
              icon: const Icon(Icons.window)),
          IconButton(
              tooltip: "Take screenshot [Region]",
              onPressed: () => _handleClickCapture(CaptureMode.region),
              icon: const Icon(Icons.screenshot_monitor_outlined)),
          IconButton(
            icon: const Icon(Icons.camera),
            onPressed: () {},
          ),
        ],
      ),
      body: Row(
        children: [
          Expanded(
            flex: 6,
            child: Column(
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _timerText,
                      style: const TextStyle(fontSize: 48),
                    ),
                    ElevatedButton(
                      onPressed: () {
                        setState(() {
                          _isTimerRunning = !_isTimerRunning;
                          if (_isTimerRunning) {
                            startTimer();
                          } else {
                            _timer.cancel();
                          }
                        });
                      },
                      child: Text(_isTimerRunning ? 'PAUSE' : 'START'),
                    ),
                    ElevatedButton(
                      onPressed: () {
                        setState(() {
                          _timer.cancel();
                          _start = 0;
                          _timerText = "00:00:00";
                          _isTimerRunning = false;
                        });
                      },
                      child: const Text("STOP"),
                    ),
                  ],
                ),
                Expanded(
                  child: CameraMacOSView(
                    key: cameraKey,
                    fit: BoxFit.fill,
                    cameraMode: CameraMacOSMode.photo,
                    onCameraInizialized: (CameraMacOSController controller) {
                      debugPrint("camera initialized");
                      setState(() {
                        macOSController = controller;
                      });
                    },
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 2,
            child: Container(
              width: double.infinity,
              color: Colors.red,
              child: ListView.builder(
                itemCount: faceList.length,
                itemBuilder: (context, index) {
                  return Stack(
                    children: [
                      Image.memory(faceList[index]),
                      Positioned(
                        top: 0,
                        right: 0,
                        child: IconButton(
                          onPressed: () {
                            setState(() {
                              faceList.removeAt(index);
                            });
                          },
                          icon: const Icon(Icons.delete),
                        ),
                      )
                    ],
                  );
                },
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Container(
              color: Colors.green,
              width: double.infinity,
              child: ListView.builder(
                itemCount: screenshotList.length,
                itemBuilder: (context, index) {
                  return Stack(
                    children: [
                      Image.file(File(screenshotList[index])),
                      Positioned(
                        top: 0,
                        right: 0,
                        child: IconButton(
                          onPressed: () {
                            setState(() {
                              screenshotList.removeAt(index);
                            });
                          },
                          icon: const Icon(
                            Icons.delete,
                            color: Colors.red,
                          ),
                        ),
                      )
                    ],
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
