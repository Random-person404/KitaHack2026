import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:hand_landmarker/hand_landmarker.dart';

late List<CameraDescription> _cameras;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  _cameras = await availableCameras();
  runApp(const MaterialApp(
    home: HandDetectionScreen(),
    debugShowCheckedModeBanner: false,
  ));
}

class HandDetectionScreen extends StatefulWidget {
  const HandDetectionScreen({super.key});
  @override
  State<HandDetectionScreen> createState() => _HandDetectionScreenState();
}

class _HandDetectionScreenState extends State<HandDetectionScreen> {
  CameraController? _controller;
  HandLandmarkerPlugin? _plugin;
  List<Hand> _hands = [];
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    _plugin = HandLandmarkerPlugin.create(
      numHands: 2,
      minHandDetectionConfidence: 0.7,
      delegate: HandLandmarkerDelegate.gpu, 
    );

    // FORCE BACK CAMERA: Loop through cameras to find the back one
    CameraDescription? backCamera;
    for (var camera in _cameras) {
      if (camera.lensDirection == CameraLensDirection.back) {
        backCamera = camera;
        break;
      }
    }

    // Fallback to first camera if no "back" label found
    backCamera ??= _cameras.first;

    _controller = CameraController(
      backCamera, 
      ResolutionPreset.medium,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.yuv420, // Better for Android processing
    );
    
    await _controller!.initialize();

    _controller!.startImageStream((CameraImage image) {
      if (_isProcessing) return;
      _isProcessing = true;

      final results = _plugin!.detect(
        image, 
        _controller!.description.sensorOrientation
      );
      
      if (mounted) {
        setState(() {
          _hands = results;
        });
      }
      _isProcessing = false;
    });

    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_controller == null || !_controller!.value.isInitialized) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator(color: Colors.cyanAccent)),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black, // Background color behind the rounded box
      body: Column(
        children: [
          // TOP SCREEN: 60% Camera & Tracking
          Expanded(
            flex: 6, // 60% of the screen
            child: Stack(
              fit: StackFit.expand,
              children: [
                ClipRect(
                  child: FittedBox(
                    fit: BoxFit.cover,
                    child: SizedBox(
                      width: _controller!.value.previewSize!.height,
                      height: _controller!.value.previewSize!.width,
                      child: CameraPreview(_controller!),
                    ),
                  ),
                ),
                // Your working HandPainter
                CustomPaint(
                  painter: HandPainter(_hands),
                ),
                // Subtle Gradient Overlay to make the text pop
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    height: 100,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.black.withOpacity(0.7), Colors.transparent],
                      ),
                    ),
                    padding: const EdgeInsets.only(top: 50, left: 20),
                    child: const Text(
                      "ASL Kitahack Tracker",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // BOTTOM SCREEN: 40% Rounded Translation Box
          Expanded(
            flex: 4, // 40% of the screen
            child: Container(
              width: double.infinity,
              decoration: const BoxDecoration(
                color: Color(0xFF1E1E1E), // Slightly lighter dark grey
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(30),
                  topRight: Radius.circular(30),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black54,
                    blurRadius: 10,
                    offset: Offset(0, -5),
                  )
                ],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 40,
                    height: 5,
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  const Spacer(),
                  const Text(
                    "TRANSLATION",
                    style: TextStyle(
                      color: Colors.cyanAccent,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 3.0,
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    "HELLO", // This is where your detected word goes
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 64,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  // Indicator for connection status or hand count
                  Padding(
                    padding: const EdgeInsets.only(bottom: 20),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          _hands.isNotEmpty ? Icons.check_circle : Icons.pause_circle_filled,
                          color: _hands.isNotEmpty ? Colors.greenAccent : Colors.orangeAccent,
                          size: 16,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _hands.isNotEmpty ? "Hand Detected" : "Searching...",
                          style: TextStyle(
                            color: _hands.isNotEmpty ? Colors.greenAccent : Colors.orangeAccent,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class HandPainter extends CustomPainter {
  final List<Hand> hands;
  HandPainter(this.hands);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.cyanAccent
      ..strokeWidth = 10.0
      ..strokeCap = StrokeCap.round;

    for (var hand in hands) {
      for (var landmark in hand.landmarks) {
        // COORDINATE MATH:
        // x is horizontal (0 to 1) -> maps to width
        // y is vertical (0 to 1)
        // 1. Calculate and declare x first
        double x = landmark.y * size.width; 

// 2. Calculate and declare y
        double y = landmark.x * size.height;

// 3. Apply your horizontal flip to the now-declared x
        x = size.width - x;

         canvas.drawCircle(Offset(x, y), 6, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant HandPainter oldDelegate) => true;
}