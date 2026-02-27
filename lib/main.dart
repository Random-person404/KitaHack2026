import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hand_landmarker/hand_landmarker.dart';
import 'package:firebase_core/firebase_core.dart';
import 'gestures_logic.dart';
import 'services/ai_services.dart';
import 'firebase_options.dart';
import 'landmark_processor.dart';

late List<CameraDescription> _cameras;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
  ));
  if (Firebase.apps.isEmpty) {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  }
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
      ..color = const Color(0xFF00E5FF)
      ..strokeWidth = 8.0
      ..style = PaintingStyle.fill;

    final glowPaint = Paint()
      ..color = const Color(0xFF00E5FF).withOpacity(0.3)
      ..strokeWidth = 16.0
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);

    for (var hand in hands) {
      for (var lm in hand.landmarks) {
        final offset = Offset(size.width - (lm.y * size.width), lm.x * size.height);
        canvas.drawCircle(offset, 8, glowPaint);
        canvas.drawCircle(offset, 4, paint);
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

class _HandDetectionScreenState extends State<HandDetectionScreen>
    with TickerProviderStateMixin {
  final AIService _aiService = AIService();
  final ValueNotifier<String> _detectedSign  = ValueNotifier<String>("");
  final ValueNotifier<String> _currentWord   = ValueNotifier<String>("");
  final ValueNotifier<String> _aiSentence    = ValueNotifier<String>("");
  final ValueNotifier<bool>   _isAiLoading   = ValueNotifier<bool>(false);
  final GestureSmoother _smoother = GestureSmoother(bufferSize: 10);

  CameraController? _controller;
  HandLandmarkerPlugin? _plugin;
  List<Hand> _hands = [];
  bool _isProcessing = false;
  bool _isSendingToGemini = false;

  String _letterBuffer    = "";
  String _fullSentence    = "";
  String _lastAddedLetter = "";
  int    _stableFrameCount = 0;
  int    _noHandFrameCount = 0;
  String _prevGesture      = "";

  static const int _stableFramesNeeded  = 8;
  static const int _noHandFramesForWord = 15;
  static const int _noHandFramesForSend = 30;

  late AnimationController _pulseController;
  late AnimationController _letterPopController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _letterPopAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _letterPopController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _letterPopAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _letterPopController, curve: Curves.elasticOut),
    );

    _initialize();
  }

  Future<void> _initialize() async {
    _plugin = HandLandmarkerPlugin.create(numHands: 1, delegate: HandLandmarkerDelegate.gpu);
    final back = _cameras.firstWhere(
      (c) => c.lensDirection == CameraLensDirection.back,
      orElse: () => _cameras.first,
    );
    _controller = CameraController(back, ResolutionPreset.low, enableAudio: false);
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
        _stableFrameCount = 0;
        _prevGesture = "";

        if (_noHandFrameCount >= _noHandFramesForWord &&
            _noHandFrameCount < _noHandFramesForWord + 2 &&
            _letterBuffer.isNotEmpty) {
          _addSpace();
        }
        if (_noHandFrameCount >= _noHandFramesForSend &&
            _noHandFrameCount < _noHandFramesForSend + 2) {
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

      if (gesture == _prevGesture && gesture.isNotEmpty && gesture != "Detecting...") {
        _stableFrameCount++;
      } else {
        _stableFrameCount = 0;
        _prevGesture = gesture;
      }

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
    if (gesture.isEmpty || gesture == "Detecting..." || gesture == _lastAddedLetter) return;
    final cleanGesture = gesture.split('/')[0].trim();
    final isValid = cleanGesture.length == 1 &&
        cleanGesture.contains(RegExp(r'[A-Z0-9]'));
    if (!isValid) return;
    _lastAddedLetter = gesture;
    _letterBuffer += cleanGesture;
    _currentWord.value = _letterBuffer;
    _letterPopController.forward(from: 0);
  }

  void _addSpace() {
    if (_letterBuffer.isEmpty) return;
    _fullSentence += _letterBuffer + " ";
    _letterBuffer = "";
    _lastAddedLetter = "";
    _currentWord.value = "";
  }

  Future<void> _sendToGemini() async {
    if (_isSendingToGemini) return;
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
    _isAiLoading.value = true;
    final result = await _aiService.getSentenceCorrection(toSend);
    _isAiLoading.value = false;
    _isSendingToGemini = false;
    if (result != null && mounted) {
      _aiSentence.value = result;
    }
  }

  void _clearAll() {
    _letterBuffer = "";
    _fullSentence = "";
    _lastAddedLetter = "";
    _prevGesture = "";
    _stableFrameCount = 0;
    _noHandFrameCount = 0;
    _isSendingToGemini = false;
    _isAiLoading.value = false;
    _currentWord.value = "";
    _aiSentence.value = "";
    _detectedSign.value = "";
    _smoother.clear();
  }

  @override
  Widget build(BuildContext context) {
    if (_controller == null || !_controller!.value.isInitialized) {
      return const Scaffold(
        backgroundColor: Color(0xFF0A0A0A),
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFF00E5FF)),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // ── Camera feed ──────────────────────────────────────────────
          CameraPreview(_controller!),

          // ── Dark gradient overlay top ─────────────────────────────────
          Positioned(
            top: 0, left: 0, right: 0,
            height: 200,
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xCC000000), Colors.transparent],
                ),
              ),
            ),
          ),

          // ── Dark gradient overlay bottom ──────────────────────────────
          Positioned(
            bottom: 0, left: 0, right: 0,
            height: 320,
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [Color(0xEE000000), Colors.transparent],
                ),
              ),
            ),
          ),

          // ── Landmarks ────────────────────────────────────────────────
          CustomPaint(painter: HandPainter(_hands)),

          // ── App name top left ─────────────────────────────────────────
          Positioned(
            top: 52,
            left: 20,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                RichText(
                  text: const TextSpan(
                    children: [
                      TextSpan(
                        text: 'Sign',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5,
                        ),
                      ),
                      TextSpan(
                        text: 'Speak',
                        style: TextStyle(
                          color: Color(0xFF00E5FF),
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5,
                        ),
                      ),
                    ],
                  ),
                ),
                ValueListenableBuilder<String>(
                  valueListenable: _detectedSign,
                  builder: (_, v, __) => Row(
                    children: [
                      AnimatedBuilder(
                        animation: _pulseAnimation,
                        builder: (_, __) => Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: v.isEmpty
                                ? Colors.white38
                                : const Color(0xFF00E5FF),
                            boxShadow: v.isEmpty ? [] : [
                              BoxShadow(
                                color: const Color(0xFF00E5FF).withOpacity(_pulseAnimation.value),
                                blurRadius: 6,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        v.isEmpty ? 'Waiting...' : 'Detecting',
                        style: TextStyle(
                          color: v.isEmpty ? Colors.white38 : const Color(0xFF00E5FF),
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ── Clear button top right ────────────────────────────────────
          Positioned(
            top: 48,
            right: 16,
            child: GestureDetector(
              onTap: _clearAll,
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white24),
                ),
                child: const Icon(Icons.refresh_rounded, color: Colors.white70, size: 22),
              ),
            ),
          ),

          // ── Big detected letter center ────────────────────────────────
          Positioned(
            top: 100,
            left: 0, //changed
            right: 0,
            child: Center(
              child: ValueListenableBuilder<String>(
                valueListenable: _detectedSign,
                builder: (_, v, __) {
                  if (v.isEmpty) return const SizedBox();
                  return AnimatedSwitcher(
                    duration: const Duration(milliseconds: 120),
                    transitionBuilder: (child, anim) => ScaleTransition(
                      scale: anim,
                      child: child,
                    ),
                    child: Container(
                      key: ValueKey(v),
                      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: const Color(0xFF00E5FF).withOpacity(0.6),
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF00E5FF).withOpacity(0.2),
                            blurRadius: 20,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: Text(
                        v,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 80,
                          fontWeight: FontWeight.w900,
                          height: 1.0,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),

          // ── Bottom panel ──────────────────────────────────────────────
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [

                  // Word being built
                  ValueListenableBuilder<String>(
                    valueListenable: _currentWord,
                    builder: (_, word, __) {
                      if (word.isEmpty) return const SizedBox(height: 8);
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: ScaleTransition(
                          scale: _letterPopAnimation,
                          child: Row(
                            children: [
                              const Text(
                                'SPELLING  ',
                                style: TextStyle(
                                  color: Color(0xFF00E5FF),
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 2,
                                ),
                              ),
                              Flexible(
                                child: Text(
                                  word,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 28,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 6,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),

                  // Gemini output box
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.07),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Label row
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: const Color(0xFF00E5FF).withOpacity(0.15),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: const Color(0xFF00E5FF).withOpacity(0.4),
                                ),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.auto_awesome, color: Color(0xFF00E5FF), size: 10),
                                  SizedBox(width: 4),
                                  Text(
                                    'GEMINI AI',
                                    style: TextStyle(
                                      color: Color(0xFF00E5FF),
                                      fontSize: 9,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 1.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Spacer(),
                            const Text(
                              'Lower hand to translate',
                              style: TextStyle(
                                color: Colors.white30,
                                fontSize: 10,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        // Output
                        ValueListenableBuilder<bool>(
                          valueListenable: _isAiLoading,
                          builder: (_, loading, __) {
                            if (loading) {
                              return Row(
                                children: [
                                  const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Color(0xFF00E5FF),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Text(
                                    'Translating...',
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(0.5),
                                      fontSize: 15,
                                    ),
                                  ),
                                ],
                              );
                            }
                            return ValueListenableBuilder<String>(
                              valueListenable: _aiSentence,
                              builder: (_, sentence, __) => Text(
                                sentence.isEmpty
                                    ? 'Sign letters, then lower your hand...'
                                    : sentence,
                                style: TextStyle(
                                  color: sentence.isEmpty
                                      ? Colors.white30
                                      : Colors.white,
                                  fontSize: sentence.isEmpty ? 13 : 24,
                                  fontWeight: sentence.isEmpty
                                      ? FontWeight.normal
                                      : FontWeight.w600,
                                  height: 1.3,
                                ),
                              ),
                            );
                          },
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

  @override
  void dispose() {
    _pulseController.dispose();
    _letterPopController.dispose();
    _controller?.dispose();
    super.dispose();
  }
}