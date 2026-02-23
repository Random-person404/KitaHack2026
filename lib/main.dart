import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:hand_landmarker/hand_landmarker.dart';
import 'gestures_logic.dart';
import 'services/ai_services.dart';

late List<CameraDescription> _cameras;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  _cameras = await availableCameras();
  runApp(const MaterialApp(
    home: HandDetectionScreen(),
    debugShowCheckedModeBanner: false,
  ));
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

class HandDetectionScreen extends StatefulWidget {
  const HandDetectionScreen({super.key});
  @override
  State<HandDetectionScreen> createState() => _HandDetectionScreenState();
}

class _HandDetectionScreenState extends State<HandDetectionScreen> {
  final ValueNotifier<String> _detectedSign = ValueNotifier<String>("Searching...");
  final AIService _aiService = AIService();

  CameraController? _controller;
  HandLandmarkerPlugin? _plugin;
  List<Hand> _hands = [];
  bool _isProcessing = false;
  String _recognizedGesture2 = "";
  int _handCount = 0;
  
  // Frame history for motion detection
  List<String>? _prevLandmarks1;
  List<String>? _prevLandmarks2;
  int _aiCallCount = 0;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    debugPrint('\n========== KITAHACK INITIALIZING ==========');
    debugPrint('🚀 Creating HandLandmarkerPlugin...');
    _plugin = HandLandmarkerPlugin.create(
      numHands: 2,
      minHandDetectionConfidence: 0.7,
      delegate: HandLandmarkerDelegate.gpu, 
    );
    debugPrint('✅ HandLandmarkerPlugin created');

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

_controller!.startImageStream((CameraImage image) async {
  if (_isProcessing) return;
  _isProcessing = true;

  final results = _plugin!.detect(
    image,
    _controller!.description.sensorOrientation
  );

  if (mounted) {
    String detectedGesture = "Detecting...";
    String detectedGesture2 = "";
    int handCount = results.length;

    if (results.isNotEmpty) {
      // HAND 1: Process with PRIMARY AI + Secondary Local Logic
      final hand1 = results[0];
      final landmarks1 = hand1.landmarks
          .map((lm) => Point3D(lm.x, lm.y, lm.z))
          .toList();
      
      final hand1String = landmarks1.toString();

      // Analyze motion for context
      String motionContext = '';
      if (_prevLandmarks1 != null) {
        motionContext = _aiService.analyzeMotion(_prevLandmarks1!, [hand1String]);
      }

      // PRIMARY: Call AI every 10 frames for responsive detection (includes dynamics)
      _aiCallCount++;
      if (_aiCallCount % 10 == 0) {
        debugPrint('\ud83d\udca1 [Frame $_aiCallCount] Calling AI for Hand 1 (right)...');
        final aiResult = await _aiService.getSignTranslation(
          hand1String,
          motionContext: motionContext,
          handedness: 'right',
        );

        if (aiResult != null && mounted) {
          detectedGesture = aiResult;
          _detectedSign.value = aiResult;
          debugPrint('\u2705 Hand 1 AI detected: $aiResult');
        } else {
          // FALLBACK: Use local logic if AI fails
          detectedGesture = BIMGestureLogic.recognize(landmarks1);
          _detectedSign.value = detectedGesture;
          debugPrint('\u26a0\ufe0f Hand 1 AI returned null, using local logic: $detectedGesture');
        }
      } else if (_aiCallCount <= 10) {
        debugPrint('\u23f3 Frame $_aiCallCount: Waiting for AI call (next at frame 10)...');
      }

      _prevLandmarks1 = [hand1String];

      // HAND 2: Also use AI (not just local)
      if (results.length > 1) {
        final hand2 = results[1];
        final landmarks2 = hand2.landmarks
            .map((lm) => Point3D(lm.x, lm.y, lm.z))
            .toList();
        
        final hand2String = landmarks2.toString();

        // Analyze motion for hand 2
        String motionContext2 = '';
        if (_prevLandmarks2 != null) {
          motionContext2 = _aiService.analyzeMotion(_prevLandmarks2!, [hand2String]);
        }

        // AI for second hand (every 10 frames to manage cost)
        if (_aiCallCount % 10 == 0) {
          final aiResult2 = await _aiService.getSignTranslation(
            hand2String,
            motionContext: motionContext2,
            handedness: 'left',
          );

          if (aiResult2 != null && mounted) {
            detectedGesture2 = aiResult2;
          } else {
            // Fallback to local if AI fails
            detectedGesture2 = BIMGestureLogic.recognize(landmarks2);
          }
        }

        _prevLandmarks2 = [hand2String];
      }
    }

    setState(() {
      _hands = results;
      _recognizedGesture2 = detectedGesture2;
      _handCount = handCount;
    });
  }
  _isProcessing = false;
});
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
                        colors: [Colors.blue.withValues(alpha: 0.5), Colors.blue.withValues(alpha: 0.0)],
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
                  // Display gestures from detected hands
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ValueListenableBuilder<String>(
                        valueListenable: _detectedSign, // Listens to the notifier we added at the top
                        builder: (context, currentSign, child) {
                          return Text(
                            currentSign, // Uses the updated value from AI or Local Logic
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 56,
                              fontWeight: FontWeight.bold,
                            ),
                          );
                        },
                      ),
                      // Hand 2 gesture (if available)
                      if (_recognizedGesture2.isNotEmpty && _handCount > 1) ...
                        [
                          const SizedBox(height: 8),
                          const Text(
                            "&",
                            style: TextStyle(
                              color: Colors.cyanAccent,
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _recognizedGesture2,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 56,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                    ],
                  ),
                  const Spacer(),
                  // Hand count indicator
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: _handCount > 0 ? Colors.greenAccent.withValues(alpha: 0.2) : Colors.orangeAccent.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: _handCount > 0 ? Colors.greenAccent : Colors.orangeAccent,
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _handCount > 0 ? Icons.back_hand : Icons.pause_circle_filled,
                          color: _handCount > 0 ? Colors.greenAccent : Colors.orangeAccent,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _handCount == 0
                              ? "Searching for hands..."
                              : _handCount == 1
                                  ? "1 Hand Detected"
                                  : "2 Hands Detected",
                          style: TextStyle(
                            color: _handCount > 0 ? Colors.greenAccent : Colors.orangeAccent,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
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

