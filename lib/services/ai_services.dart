import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:flutter/foundation.dart';

/// AIService integrates Google Gemini API for intelligent sign language recognition
/// Now as PRIMARY detector for both static AND dynamic gestures
/// Features smart model fallback - tries multiple models until one works
class AIService {
  static const String _apiKey = String.fromEnvironment('API_KEY');
  
  // List of models to try in order (from newest to most compatible)
  static const List<String> _modelsToTry = [
    'gemini-pro',           // Try this first
    'gemini-1.0-pro',       // Fallback to older version
    'gemini-pro-vision',    // With vision support
  ];
  
  late final GenerativeModel _model;
  late final String _activeModel;
  bool _isInitialized = false;
  String? _initError;

  AIService() {
    // Validate API Key early
    if (_apiKey.isEmpty) {
      _initError = 'API_KEY is not set! Use: flutter run --dart-define=API_KEY=your_key_here';
      debugPrint('❌ $_initError');
      return;
    }
    
    // Try models in order until one works
    _initializeWithFallback();
  }

  /// Try initializing with multiple models until one works
  void _initializeWithFallback() {
    for (String modelName in _modelsToTry) {
      try {
        debugPrint('🔄 Trying model: $modelName...');
        _model = GenerativeModel(
          model: modelName,
          apiKey: _apiKey,
        );
        _activeModel = modelName;
        _isInitialized = true;
        debugPrint('✅ AIService initialized successfully');
        debugPrint('🔑 API Key length: ${_apiKey.length} characters');
        debugPrint('📱 Using Model: $_activeModel');
        return; // Success! Exit the loop
      } catch (e) {
        debugPrint('⚠️ Model "$modelName" failed: $e');
        // Continue to next model
      }
    }
    
    // If we get here, no models worked
    _initError = 'All models failed. Available models: ${_modelsToTry.join(", ")}. Check your API permissions.';
    debugPrint('❌ $_initError');
  }

  /// Smart recognition for both STATIC and DYNAMIC gestures
  /// Returns the detected sign/letter based on hand position and motion patterns
  Future<String?> getSignTranslation(
    String landmarks, {
    String? motionContext = '',
    String? handedness = 'right',
  }) async {
    // Check initialization
    if (!_isInitialized) {
      debugPrint('❌ AIService not initialized: $_initError');
      return null;
    }

    if (_apiKey.isEmpty) {
      debugPrint('❌ API_KEY is empty!');
      return null;
    }

    try {
      // SMARTER PROMPT: Understands motion, finger positions, hand orientation, and intent
      final prompt = [
        Content.text('''Analyze these hand joint coordinates for Malaysian Sign Language (BIM):

LANDMARKS DATA:
$landmarks

MOTION PATTERN: ${motionContext?.isNotEmpty == true ? motionContext : 'static/stable'}
HAND: $handedness

TASK: Identify the sign language gesture by analyzing:
1. Individual finger positions (extended/folded/raised/lowered)
2. Finger touching patterns (thumbs, index touching middle, etc.)
3. Hand orientation and palm direction
4. Motion if present (moving up/down/sideways)
5. Overall hand shape and configuration

FOCUS: Malaysian Sign Language (BIM) includes:
- Letters A-Z
- Numbers 0-9  
- Common words: HELLO, YES, NO, THANK YOU, GOOD, BAD, LOVE, YOU, ME, STOP
- Dynamic gestures: pointing, waving, opening/closing fist, rotating hand

RESPOND WITH ONLY:
- The detected letter (A-Z)
- Number (0-9)
- Word name
- Or "UNCERTAIN" if unsure

Be intelligent and infer intent from hand movement and position.''')
      ];

      debugPrint('🔄 Sending request to Gemini (Model: $_activeModel) for hand: $handedness');
      final response = await _model.generateContent(prompt);
      final result = response.text?.trim().toUpperCase();
      
      debugPrint('📝 Raw Gemini response: "$result"');
      
      if (result != null && result.isNotEmpty && result != 'UNCERTAIN') {
        debugPrint('✅✅✅ AI DETECTED (Hand: $handedness): "$result" ✅✅✅');
        return result;
      }
      
      debugPrint('⚠️ AI Response was unclear or UNCERTAIN: "$result"');
      return null;
      
    } catch (e, stackTrace) {
      debugPrint('❌❌❌ GEMINI API ERROR: $e');
      debugPrint('Stack trace: $stackTrace');
      debugPrint('⚠️ Model being used: $_activeModel');
      debugPrint('💡 If model is not supported:');
      debugPrint('   1. Check your API key at: https://aistudio.google.com/app/apikey');
      debugPrint('   2. Ensure the model "$_activeModel" is available in your region');
      debugPrint('   3. Try manual setup: edit lib/services/ai_services.dart');
      return null;
    }
  }

  /// Analyze motion between two landmark frames to detect dynamic gestures
  /// Returns motion description: "moving_up", "moving_down", "rotating", "opening", "closing", etc.
  String analyzeMotion(List<String> previousLandmarks, List<String> currentLandmarks) {
    // Simple motion detection: compare positions
    // This helps AI understand gesture intent
    if (previousLandmarks.isEmpty || currentLandmarks.isEmpty) {
      return 'stable';
    }

    // In a real implementation, you'd parse coordinates and calculate velocity
    // For now, return a placeholder that can be enhanced
    try {
      // Split landmark strings and compare positions
      final prevPos = previousLandmarks.toString();
      final currPos = currentLandmarks.toString();
      
      // More sophisticated motion analysis could happen here
      // For example: calculate centroid changes, finger velocity, etc.
      return 'dynamic_motion_detected';
    } catch (e) {
      return 'stable';
    }
  }

  void dispose() {}
}