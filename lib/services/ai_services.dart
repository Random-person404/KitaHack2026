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
          maxOutputTokens: 500,
        ),
        systemInstruction: Content.system("""
You are an ASL fingerspelling interpreter.
The user spells letters one by one using sign language.
Your ONLY job is to clean up the spelling and return the result.

Critical rules:
- NEVER cut words short
- O and 0 are interchangeable (2O26 = 2026)
- If input looks like a name or code, preserve it with proper casing
- Return the COMPLETE output, never truncate
- Return ONLY the result, no explanation

Examples:
Input: KITAHACK2O26 → KitaHack2026
Input: HELLO → Hello
Input: THNK YOU → Thank you
Input: MY NAME IS ALI → My name is Ali
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
  Content.text("Clean up this fingerspelled input and return the complete result: $rawLetters"),
]);
      final result = response.text?.trim();
      debugPrint('📥 Gemini response: "$result"');
      debugPrint('📥 Finish reason: ${response.candidates?.first.finishReason}');
      return result;
    } catch (e) {
      debugPrint('❌ Gemini error: $e');
      return null;
    }
  }
}