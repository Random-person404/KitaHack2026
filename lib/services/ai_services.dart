import 'package:firebase_ai/firebase_ai.dart';
import 'package:flutter/foundation.dart';

class AIService {
  static const String _modelName = 'gemini-2.0-flash';
  late final GenerativeModel _model;
  bool _isInitialized = false;

  AIService() {
    _initialize();
  }

  void _initialize() {
    try {
      _model = FirebaseAI.googleAI().generativeModel(
        model: _modelName,
        generationConfig: GenerationConfig(
          temperature: 0.1,
          maxOutputTokens: 50,
        ),
        systemInstruction: Content.system("""
You are an ASL fingerspelling interpreter.
Turn the input letters and numbers into a natural readable sentence.
Some characters are ambiguous — use context to pick the right one:
- F could mean F or 9
- V could mean V or 2
- O could mean O or 0
Return ONLY the final sentence, nothing else. Keep it short and natural.

Examples:
Input: "HELLO" → Output: Hello!
Input: "I NEED HELP" → Output: I need help.
Input: "MY NUMBER IS F2F" → Output: My number is 929.
Input: "THNK YOU" → Output: Thank you.
Input: "1 2 3" → Output: 1 2 3
        """),
      );
      _isInitialized = true;
      debugPrint('✅ AIService initialized successfully');
    } catch (e) {
      _isInitialized = false;
      debugPrint('❌ AIService initialization failed: $e');
    }
  }

  Future<String?> getSentenceCorrection(String rawLetters) async {
    if (!_isInitialized || rawLetters.trim().isEmpty) return null;

    try {
      debugPrint('📤 Sending to Gemini: "$rawLetters"');
      final response = await _model.generateContent([
        Content.text(rawLetters.trim()),
      ]);
      final result = response.text?.trim();
      debugPrint('📥 Gemini response: "$result"');
      return result;
    } catch (e, stack) {
      debugPrint('❌ Gemini error: $e');
      debugPrint('❌ Stack: $stack');
      // Fallback: return cleaned up raw letters if Gemini fails
      return rawLetters.trim().toLowerCase();
    }
  }
}