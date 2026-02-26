import 'package:firebase_ai/firebase_ai.dart';
import 'package:flutter/foundation.dart';

class AIService {
  static const String _modelName = 'gemini-2.5-flash';
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
          maxOutputTokens: 100,
        ),
        systemInstruction: Content.system("""
You are an ASL fingerspelling interpreter.
The user has fingerspelled a sequence of letters using sign language.
Your job is to turn those letters into a natural, readable sentence or phrase.

Rules:
- The input is space-separated words made of capital letters
- Correct obvious spelling mistakes (fingerspelling is hard)
- Output ONLY the final sentence, nothing else
- Keep it short and natural
- If the input is a single word, just return that word properly capitalized

Examples:
Input: "HELLO WORLD" → Output: Hello world.
Input: "I NEEd HELP" → Output: I need help.
Input: "MY NAEM IS ALI" → Output: My name is Ali.
Input: "THNK YOU" → Output: Thank you.
        """),
      );
      _isInitialized = true;
      debugPrint('✅ AIService initialized successfully');
    } catch (e, stack) {
  debugPrint('❌ Gemini error: $e');
  debugPrint('❌ Stack: $stack');
  return null;
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
    } catch (e) {
      debugPrint('❌ Gemini error: $e');
      return null;
    }
  }
}