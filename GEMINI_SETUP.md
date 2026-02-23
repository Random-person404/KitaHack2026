# Gemini Integration Setup Guide

## ✅ Latest Updates

1. **AI as PRIMARY detector** - Now recognizes both static AND dynamic gestures
2. **Both hands use AI** - Hand 1 and Hand 2 both get AI processing with motion context
3. **Smarter prompts** - AI understands finger motion, positions, hand orientation, and intent
4. **Motion tracking** - Analyzes landmark changes between frames to detect dynamic gestures
5. **Fallback protection** - Local logic is backup if AI fails or API is down


---

## 🔧 How to Setup Gemini API

### Step 1: Get Your API Key
1. Go to [Google AI Studio](https://aistudio.google.com/app/apikey)
2. Click **"Get API Key"** → **"Create API key in new project"**
3. Copy your API key (keep it secret!)

### Step 2: Run with API Key

Use one of these commands to run your app with the API key:

```bash
# ✅ Development (Recommended)
flutter run --dart-define=API_KEY=your_actual_api_key_here

# ✅ For Android
flutter run -d android --dart-define=API_KEY=your_actual_api_key_here

# ✅ For web
flutter run -d web --dart-define=API_KEY=your_actual_api_key_here
```

### Step 3: Verify Setup
- App should not show console warnings about missing API key
- When gesture is uncertain (`"Detecting..."`), Gemini will be queried every 60 frames (~1 second)
- Check console for `✅ Gemini Response: ...` messages

---

## 🎯 How It Works (AI-Primary + Local Fallback)

```
Hand Detection (21 landmarks per hand)
    ↓
Analyze landmarks + Motion between frames
    ↓
Query Gemini AI (EVERY 10 FRAMES) ──→ "A", "HELLO", "POINTING UP", etc.
    ↓ AI fails/returns null
Fallback to Local BIMGestureLogic (FAST)
    ↓
Display Result
```

### Key Improvements:
- ✅ **AI detects DYNAMIC gestures** - Motion is sent as context to Gemini
- ✅ **Both hands use AI** - Hand 1 (right) and Hand 2 (left) both processed
- ✅ **More frequent calls** - Every 10 frames (6 times per second) instead of 1 per second
- ✅ **Intelligent prompting** - AI understands finger positions, hand orientation, and movement intent
- ✅ **Motion-aware** - Previous landmark positions compared to detect gestures like "waving", "pointing", "rotating"


---

## 📄 Code References

### State Variables (in `_HandDetectionScreenState`)
```dart
final ValueNotifier<String> _detectedSign = ValueNotifier<String>("Searching...");
final AIService _aiService = AIService();

// Frame history for motion detection
List<String>? _prevLandmarks1;
List<String>? _prevLandmarks2;
int _aiCallCount = 0;  // Call AI every 10 frames
```

### AI Processing (BOTH HANDS - New!)
```dart
// HAND 1: AI Primary + Local Fallback
_aiCallCount++;
if (_aiCallCount % 10 == 0) {  // Every 10 frames
  final aiResult = await _aiService.getSignTranslation(
    hand1String,
    motionContext: motionContext,
    handedness: 'right',
  );
  
  if (aiResult != null) {
    detectedGesture = aiResult;  // Use AI result
  } else {
    detectedGesture = BIMGestureLogic.recognize(landmarks1);  // Fallback
  }
}

// HAND 2: Same AI processing (also gets analyzed!)
if (results.length > 1) {
  if (_aiCallCount % 10 == 0) {
    final aiResult2 = await _aiService.getSignTranslation(
      hand2String,
      motionContext: motionContext2,
      handedness: 'left',
    );
    detectedGesture2 = aiResult2 ?? BIMGestureLogic.recognize(landmarks2);
  }
}
```

### Smarter AI Prompt (ai_services.dart)
The AI now receives:
- **Landmarks**: 21 joint coordinates (X, Y, Z positions)
- **Motion Context**: "stable" or "dynamic_motion_detected"
- **Handedness**: "right" or "left" for better context
- **Smart Instructions**: Understands both static AND dynamic BIM gestures

Example: User pointing with index finger moving upward → AI recognizes as "POINTING UP" or similar


---

## ⚠️ Common Issues & Solutions

| Issue | Cause | Solution |
|-------|-------|----------|
| "API Key is missing" | Didn't pass `--dart-define` | Use: `flutter run --dart-define=API_KEY=your_key` |
| No Gemini responses | Wrong API key | Verify key is active at [Google AI Studio](https://aistudio.google.com/app/apikey) |
| Slowdowns | Too many API calls | Default is 60-frame throttle (safe) |
| "Quota exceeded" | Free tier limit reached | Upgrade to paid plan or wait 24 hours |

---

## 💡 What's Changed (vs Previous Version)

| Aspect | Before | Now |
|--------|--------|-----|
| Primary Detector | Local BIMGestureLogic | AI (Gemini) |
| AI Role | Fallback only | Primary detector |
| Hand 2 Processing | Local logic only | AI + Local fallback |
| Dynamic Gestures | Not recognized | ✅ Detected via motion tracking |
| AI Call Frequency | Every 60 frames (~1x/sec) | Every 10 frames (~6x/sec) |
| Motion Analysis | None | ✅ Compares landmarks across frames |
| Gesture Types | Static only | Static + Dynamic (waving, pointing, rotating, etc.) |

### Cost Impact
- **Free Tier**: Still includes first 50 requests/day
- **Per 10 frames** with 2 hands: ~12 API calls/sec when both hands visible
- **Monthly estimate** (8 hrs/day usage): ~3.5M API calls = ~$2.60 with gemini-1.5-flash

### Optimize Cost:
Change `_aiCallCount % 10` to:
- `% 20` - Less frequent (3 calls/sec)
- `% 30` - Very conservative (2 calls/sec)
- `% 60` - Back to original (1 call/sec)


---

## 📚 Current Model

- **Model**: `gemini-1.5-flash` (fastest & cheapest)
- **Alternatives**:
  - `gemini-1.5-pro` (more accurate, higher cost)
  - `gemini-2.0-flash` (if available in your region)

---

## ✅ Status (Updated)

- **Local Gesture Recognition**: ✅ Active (BIMGestureLogic) - Now FALLBACK only
- **AI Primary Detection**: ✅ Active for BOTH hands (every 10 frames ~6x/second)
- **Dynamic Gesture Support**: ✅ NEW - Motion tracking + AI analysis
- **Dual Hand Support**: ✅ BOTH hands use AI + local fallback
- **Motion Context**: ✅ NEW - Previous frame landmarks analyzed for motion intent
- **Cost Optimization**: ✅ Every 10 frames (not every frame) to balance accuracy & cost

---

## 🚀 Next Steps

1. Get your API key from Google AI Studio
2. Run with: `flutter run --dart-define=API_KEY=your_key`
3. Test with hand gestures
4. Monitor console for `✅ Gemini Response` or `❌ Gemini API Error`
5. Adjust throttle/prompts as needed

Good luck! 🎉
