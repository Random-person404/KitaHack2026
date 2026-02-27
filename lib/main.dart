import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:hand_landmarker/hand_landmarker.dart';
import 'package:firebase_core/firebase_core.dart';
import 'gestures_logic.dart';
import 'services/ai_services.dart';
import 'firebase_options.dart';
import 'landmark_processor.dart';

late List<CameraDescription> _cameras;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (Firebase.apps.isEmpty) {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  }
  _cameras = await availableCameras();
  runApp(const MaterialApp(home: HandDetectionScreen(), debugShowCheckedModeBanner: false));
}

class HandPainter extends CustomPainter {
  final List<Hand> hands;
  HandPainter(this.hands);
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.cyanAccent..strokeWidth = 10.0;
    for (var hand in hands) {
      for (var lm in hand.landmarks) {
        canvas.drawCircle(Offset(size.width - (lm.y * size.width), lm.x * size.height), 6, paint);
      }
    }
  }
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class HandDetectionScreen extends StatefulWidget {
  const HandDetectionScreen({super.key});
  @override
  State<HandDetectionScreen> createState() => _HandDetectionScreenState();
}

class _HandDetectionScreenState extends State<HandDetectionScreen> {
  final AIService _aiService = AIService();
  final ValueNotifier<String> _detectedSign   = ValueNotifier<String>("");
  final ValueNotifier<String> _currentWord    = ValueNotifier<String>("");
  final ValueNotifier<String> _aiSentence     = ValueNotifier<String>("");
  final ValueNotifier<bool>   _isAiLoading    = ValueNotifier<bool>(false);
  final GestureSmoother _smoother = GestureSmoother(bufferSize: 10);

  CameraController? _controller;
  HandLandmarkerPlugin? _plugin;
  List<Hand> _hands = [];
  bool _isProcessing = false;
  bool _isSendingToGemini = false;

  // Letter accumulation
  String _letterBuffer     = "";   // letters typed so far in current word
  String _fullSentence     = "";   // all confirmed words
  String _lastAddedLetter  = "";   // prevent duplicate consecutive letters
  int    _stableFrameCount = 0;
  int    _noHandFrameCount = 0;    // frames with no hand detected
  String _prevGesture      = "";

  // Timing
  static const int _stableFramesNeeded = 8;  // frames before letter is confirmed
  static const int _noHandFramesForWord = 15; // no hand for ~1.5s = end of word
  static const int _noHandFramesForSend = 30; // no hand for ~3s = send to Gemini

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    _plugin = HandLandmarkerPlugin.create(numHands: 2, delegate: HandLandmarkerDelegate.cpu);
    final back = _cameras.firstWhere(
      (c) => c.lensDirection == CameraLensDirection.back,
      orElse: () => _cameras.first,
    );
    _controller = CameraController(back, ResolutionPreset.medium, enableAudio: false);
    await _controller!.initialize();
    if (mounted) {
      setState(() {});
      _controller!.startImageStream((image) => _processFrame(image));
    }
  }

  void _processFrame(CameraImage image) {
    if (_isProcessing || _plugin == null) return;
    _isProcessing = true;

    try {
      final results = _plugin!.detect(image, _controller!.description.sensorOrientation);

      if (results.isEmpty || results[0].landmarks.isEmpty) {
  _noHandFrameCount++;
  debugPrint('🚫 No hand: $_noHandFrameCount');
  _stableFrameCount = 0;
  _prevGesture = "";

  if (_noHandFrameCount >= _noHandFramesForWord && _noHandFrameCount < _noHandFramesForWord + 2 && _letterBuffer.isNotEmpty) {
  _addSpace();
}

if (_noHandFrameCount >= _noHandFramesForSend && _noHandFrameCount < _noHandFramesForSend + 2) {
  debugPrint('🔵 Reached 90 frames! Sentence: "$_fullSentence" Buffer: "$_letterBuffer"');
  if (_fullSentence.trim().isNotEmpty || _letterBuffer.isNotEmpty) {
    _sendToGemini();
  }
}

  _detectedSign.value = "";
  setState(() { _hands = []; });
  return;
}

      _noHandFrameCount = 0;

      final landmarks = results[0].landmarks
          .map((lm) => Point3D(lm.x, lm.y, lm.z))
          .toList();

      final gesture = _smoother.getSmoothedGesture(BIMGestureLogic.recognize(landmarks));
      _detectedSign.value = gesture;

      // Count stable frames for same gesture
      if (gesture == _prevGesture && gesture.isNotEmpty && gesture != "Detecting...") {
        _stableFrameCount++;
      } else {
        _stableFrameCount = 0;
        _prevGesture = gesture;
      }

      // Confirm letter after held for enough frames
      if (_stableFrameCount == _stableFramesNeeded) {
        _confirmLetter(gesture);
      }

      setState(() { _hands = results; });
    } catch (e) {
      debugPrint('Frame error: $e');
    } finally {
      _isProcessing = false;
    }
  }

  void _confirmLetter(String gesture) {
    // Skip non-letter gestures and duplicates
     debugPrint('🔤 Confirming: $gesture | last: $_lastAddedLetter');
    if (gesture.isEmpty || gesture == "Detecting..." || gesture == _lastAddedLetter) return;

    // Only add single letters (A-Z), not phrases like "I Love You"
    final isLetter = gesture.length == 1 && gesture.contains(RegExp(r'[A-Z]'));
    if (!isLetter) return;

    _lastAddedLetter = gesture;
    _letterBuffer += gesture;
    _currentWord.value = _letterBuffer;
    debugPrint('✅ Letter confirmed: $gesture | Word so far: $_letterBuffer');
  }

  void _addSpace() {
    if (_letterBuffer.isEmpty) return;
    _fullSentence += _letterBuffer + " ";
    _letterBuffer = "";
    _lastAddedLetter = "";
    _currentWord.value = "";
    debugPrint('📝 Word added. Full sentence: $_fullSentence');
  }

  Future<void> _sendToGemini() async {
  if (_isSendingToGemini) return; // prevent repeated calls
  _isSendingToGemini = true;

  if (_letterBuffer.isNotEmpty) {
    _fullSentence += _letterBuffer + " ";
    _letterBuffer = "";
    _currentWord.value = "";
  }

  final toSend = _fullSentence.trim();
  if (toSend.isEmpty) {
    _isSendingToGemini = false;
     _isAiLoading.value = false;
    return;
  }

  debugPrint('🔵 Sending to Gemini: "$toSend"');
  _isAiLoading.value = true;

  debugPrint('⏳ Waiting for Gemini...');
final result = await _aiService.getSentenceCorrection(toSend);
debugPrint('📥 Raw result: $result');

  _isAiLoading.value = false;
  _isSendingToGemini = false;

  if (result != null && mounted) {
    _aiSentence.value = result;
    debugPrint('✅ Gemini result: $result');
  }
}

  void _clearAll() {
    _letterBuffer = "";
    _fullSentence = "";
    _lastAddedLetter = "";
    _prevGesture = "";
    _stableFrameCount = 0;
    _noHandFrameCount = 0;
    _isSendingToGemini = false;  // ADD THIS
    _currentWord.value = "";
    _aiSentence.value = "";
    _detectedSign.value = "";
    _smoother.clear();
  }

  @override
  Widget build(BuildContext context) {
    if (_controller == null || !_controller!.value.isInitialized) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Camera
          CameraPreview(_controller!),

          // Landmarks
          CustomPaint(painter: HandPainter(_hands)),

          // Top: current detected sign
          Positioned(
            top: 50,
            left: 0,
            right: 0,
            child: Center(
              child: ValueListenableBuilder<String>(
                valueListenable: _detectedSign,
                builder: (_, v, __) => AnimatedSwitcher(
                  duration: const Duration(milliseconds: 150),
                  child: Text(
                    v,
                    key: ValueKey(v),
                    style: const TextStyle(
                      color: Colors.cyanAccent,
                      fontSize: 72,
                      fontWeight: FontWeight.bold,
                      shadows: [Shadow(blurRadius: 10, color: Colors.black)],
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Middle: word being built
          Positioned(
            top: 140,
            left: 20,
            right: 20,
            child: ValueListenableBuilder<String>(
              valueListenable: _currentWord,
              builder: (_, word, __) => word.isEmpty
                  ? const SizedBox()
                  : Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.black45,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        word,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 36,
                          letterSpacing: 8,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
            ),
          ),

          // Bottom: Gemini sentence output
          Positioned(
            bottom: 40,
            left: 20,
            right: 20,
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.cyanAccent.withOpacity(0.3)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Hint text
                  const Text(
                    "Lower hand for 3s to translate",
                    style: TextStyle(color: Colors.white38, fontSize: 12),
                  ),
                  const SizedBox(height: 8),

                  // Loading or result
                  ValueListenableBuilder<bool>(
                    valueListenable: _isAiLoading,
                    builder: (_, loading, __) {
                      if (loading) {
                        return const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.cyanAccent)),
                            SizedBox(width: 12),
                            Text("Translating...", style: TextStyle(color: Colors.white54, fontSize: 16)),
                          ],
                        );
                      }
                      return ValueListenableBuilder<String>(
                        valueListenable: _aiSentence,
                        builder: (_, sentence, __) => Text(
                          sentence.isEmpty ? "Sign letters, then lower your hand..." : sentence,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: sentence.isEmpty ? Colors.white38 : Colors.white,
                            fontSize: sentence.isEmpty ? 14 : 28,
                            fontWeight: sentence.isEmpty ? FontWeight.normal : FontWeight.bold,
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),

          // Clear button
          Positioned(
            top: 50,
            right: 20,
            child: GestureDetector(
              onTap: _clearAll,
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.redAccent.withOpacity(0.8),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.refresh, color: Colors.white, size: 24),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }
}