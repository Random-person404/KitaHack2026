import 'dart:math';

/// Standard MediaPipe / Google ML Kit Hand Landmark mapping
enum HandLandmark {
  wrist,
  thumbCmc, thumbMcp, thumbIp, thumbTip,
  indexMcp, indexPip, indexDip, indexTip,
  middleMcp, middlePip, middleDip, middleTip,
  ringMcp, ringPip, ringDip, ringTip,
  pinkyMcp, pinkyPip, pinkyDip, pinkyTip,
}

class Point3D {
  final double x;
  final double y;
  final double z;

  Point3D(this.x, this.y, this.z);

  double distanceTo(Point3D other) {
    return sqrt(pow(x - other.x, 2) + pow(y - other.y, 2) + pow(z - other.z, 2));
  }
}

class BIMGestureLogic {
  
  /// Main recognition function
  static String recognize(List<Point3D> landmarks) {
    if (landmarks.length < 21) return "";

    double palmSize = landmarks[HandLandmark.wrist.index].distanceTo(landmarks[HandLandmark.middleMcp.index]);
    if (palmSize == 0) return "Detecting...";

    // 1. Determine finger states using JOINT ANGLES (Highly Accurate)
    bool isThumbExt = _isThumbExtended(landmarks, palmSize);
    bool isIndexExt = _isFingerExtended(landmarks, HandLandmark.indexMcp, HandLandmark.indexPip, HandLandmark.indexTip);
    bool isMiddleExt = _isFingerExtended(landmarks, HandLandmark.middleMcp, HandLandmark.middlePip, HandLandmark.middleTip);
    bool isRingExt = _isFingerExtended(landmarks, HandLandmark.ringMcp, HandLandmark.ringPip, HandLandmark.ringTip);
    bool isPinkyExt = _isFingerExtended(landmarks, HandLandmark.pinkyMcp, HandLandmark.pinkyPip, HandLandmark.pinkyTip);

    // 2. Identify Finger Touching
    bool thumbIndexTouch = _isTouching(landmarks[HandLandmark.thumbTip.index], landmarks[HandLandmark.indexTip.index], palmSize);
    bool thumbMiddleTouch = _isTouching(landmarks[HandLandmark.thumbTip.index], landmarks[HandLandmark.middleTip.index], palmSize);
    bool thumbRingTouch = _isTouching(landmarks[HandLandmark.thumbTip.index], landmarks[HandLandmark.ringTip.index], palmSize);
    bool thumbPinkyTouch = _isTouching(landmarks[HandLandmark.thumbTip.index], landmarks[HandLandmark.pinkyTip.index], palmSize);

    // --- BASIC WORDS (Static Gestures) ---
    if (isThumbExt && isIndexExt && !isMiddleExt && !isRingExt && isPinkyExt) {
      return "I Love You";
    }

    if (isIndexExt && isMiddleExt && isRingExt && isPinkyExt && isThumbExt) {
      double spread = landmarks[HandLandmark.indexTip.index].distanceTo(landmarks[HandLandmark.pinkyTip.index]);
      if (spread > palmSize * 1.5) return "Stop (Berhenti) / 5";
    }

    if (isThumbExt && !isIndexExt && !isMiddleExt && !isRingExt && !isPinkyExt) {
      bool isPointingUp = landmarks[HandLandmark.thumbTip.index].y < landmarks[HandLandmark.wrist.index].y - (palmSize * 0.5);
      bool isPointingDown = landmarks[HandLandmark.thumbTip.index].y > landmarks[HandLandmark.wrist.index].y + (palmSize * 0.5);
      
      if (landmarks[HandLandmark.thumbTip.index].distanceTo(landmarks[HandLandmark.indexMcp.index]) > palmSize * 0.8) {
         if (isPointingUp) return "Good (Bagus)";
         if (isPointingDown) return "Bad (Teruk)";
      }
    }

    if (isIndexExt && !isMiddleExt && !isRingExt && !isPinkyExt && !isThumbExt) {
      double zDiff = landmarks[HandLandmark.indexTip.index].z - landmarks[HandLandmark.wrist.index].z;
      if (zDiff < -0.05) return "You (Awak)"; 
      if (zDiff > 0.05) return "Me (Saya)";   
    }

    // --- NUMBERS (BIM Specific 6-9) & SHARED ALPHABET ---
    if (thumbIndexTouch && isMiddleExt && isRingExt && isPinkyExt) return "F / 9";
    if (thumbPinkyTouch && isIndexExt && isMiddleExt && isRingExt) return "6";
    if (isIndexExt && isMiddleExt && isRingExt && !isPinkyExt && !isThumbExt) return "W";
    if (thumbRingTouch && isIndexExt && isMiddleExt && isPinkyExt) return "7";
    if (thumbMiddleTouch && isIndexExt && isRingExt && isPinkyExt) return "8";

    // --- ALPHABET & 1-5 ---
    if (thumbIndexTouch && thumbMiddleTouch && !isRingExt && !isPinkyExt) return "O / 0";
    if (isIndexExt && isMiddleExt && isRingExt && isPinkyExt && !isThumbExt) return "B / 4";

    // 1 / D / G (static gestures only)
    if (isIndexExt && !isMiddleExt && !isRingExt && !isPinkyExt) {
      if (thumbMiddleTouch) return "D";
      if (_isPointingSideways(landmarks)) return "G";
      return "1"; 
    }

    // 2 / H / K / P / Q / R / U / V (all static)
    if (isIndexExt && isMiddleExt && !isRingExt && !isPinkyExt) {
      if (_isCrossed(landmarks)) return "R";
      if (_isPointingSideways(landmarks)) return "H";
      if (_isPointingDownwards(landmarks, palmSize)) return "P";
      if (isThumbExt) return "K"; 
      
      double dist = landmarks[HandLandmark.indexTip.index].distanceTo(landmarks[HandLandmark.middleTip.index]);
      if (dist > palmSize * 0.4) return "V / 2";
      return "U";
    }

    if (isIndexExt && isMiddleExt && isThumbExt && !isRingExt && !isPinkyExt) return "3";
    if (_isCurved(landmarks, palmSize)) return "C";
    if (isPinkyExt && !isIndexExt && !isMiddleExt && !isRingExt && !isThumbExt) return "I";
    if (isIndexExt && isThumbExt && !isMiddleExt && !isRingExt && !isPinkyExt) return "L";
    if (isThumbExt && isPinkyExt && !isIndexExt && !isMiddleExt && !isRingExt) return "Y";

    // M, N, T, A, S, E (All main fingers folded)
    if (!isIndexExt && !isMiddleExt && !isRingExt && !isPinkyExt) {
      // Vector Math for Front/Back Camera Invariance
      double thumbX = _getThumbwardScore(landmarks[HandLandmark.thumbTip.index], landmarks);
      double indexX = _getThumbwardScore(landmarks[HandLandmark.indexMcp.index], landmarks);
      double middleX = _getThumbwardScore(landmarks[HandLandmark.middleMcp.index], landmarks);
      double ringX = _getThumbwardScore(landmarks[HandLandmark.ringMcp.index], landmarks);

      if (landmarks[HandLandmark.thumbTip.index].distanceTo(landmarks[HandLandmark.wrist.index]) < palmSize * 0.7) return "E";
      if (landmarks[HandLandmark.thumbTip.index].distanceTo(landmarks[HandLandmark.middlePip.index]) < palmSize * 0.45) return "S";

      if (thumbX < ringX) return "M";
      if (thumbX < middleX) return "N";
      if (thumbX < indexX) return "T";
      return "A";
    }

    if (_isHooked(landmarks, palmSize) && !isMiddleExt && !isRingExt) return "X";

    return "Detecting...";
  }

  // --- UPGRADED HELPER LOGIC (TRIGONOMETRY & VECTORS) ---

  /// Calculates the interior angle formed by three 3D points in degrees
  static double _getAngle(Point3D p1, Point3D p2, Point3D p3) {
    // Vector 1 (p2 -> p1)
    double v1x = p1.x - p2.x;
    double v1y = p1.y - p2.y;
    double v1z = p1.z - p2.z;
    
    // Vector 2 (p2 -> p3)
    double v2x = p3.x - p2.x;
    double v2y = p3.y - p2.y;
    double v2z = p3.z - p2.z;
    
    // Dot product and magnitudes
    double dotProduct = (v1x * v2x) + (v1y * v2y) + (v1z * v2z);
    double mag1 = sqrt((v1x * v1x) + (v1y * v1y) + (v1z * v1z));
    double mag2 = sqrt((v2x * v2x) + (v2y * v2y) + (v2z * v2z));
    
    if (mag1 * mag2 == 0) return 0;
    
    double cosTheta = dotProduct / (mag1 * mag2);
    // Clamp to prevent NaN due to floating point precision issues
    cosTheta = cosTheta.clamp(-1.0, 1.0);
    
    double angleRad = acos(cosTheta);
    return angleRad * (180.0 / pi); // Convert to degrees
  }

  /// Scale, orientation, and camera independent extension check using joint angles.
  /// If the angle at the PIP joint is close to 180 degrees, the finger is straight.
  static bool _isFingerExtended(List<Point3D> landmarks, HandLandmark mcp, HandLandmark pip, HandLandmark tip) {
    double angle = _getAngle(landmarks[mcp.index], landmarks[pip.index], landmarks[tip.index]);
    // A straight finger usually has a joint angle between 150 and 180 degrees.
    return angle > 145.0; 
  }

  static double _getThumbwardScore(Point3D target, List<Point3D> landmarks) {
    Point3D indexMcp = landmarks[HandLandmark.indexMcp.index];
    Point3D pinkyMcp = landmarks[HandLandmark.pinkyMcp.index];
    double vx = indexMcp.x - pinkyMcp.x;
    double vy = indexMcp.y - pinkyMcp.y;
    double tx = target.x - pinkyMcp.x;
    double ty = target.y - pinkyMcp.y;
    return tx * vx + ty * vy; 
  }

  static bool _isThumbExtended(List<Point3D> landmarks, double palmSize) {
    double dist = landmarks[HandLandmark.thumbTip.index].distanceTo(landmarks[HandLandmark.pinkyMcp.index]);
    return dist > palmSize * 1.1;
  }

  static bool _isTouching(Point3D p1, Point3D p2, double palmSize) {
    return p1.distanceTo(p2) < palmSize * 0.4;
  }

  static bool _isCurved(List<Point3D> landmarks, double palmSize) {
    // A 'C' shape means the angle is bent (e.g., ~100-130 degrees), but not tightly folded flat
    double indexAngle = _getAngle(
      landmarks[HandLandmark.indexMcp.index], 
      landmarks[HandLandmark.indexPip.index], 
      landmarks[HandLandmark.indexTip.index]
    );
    return indexAngle > 80.0 && indexAngle < 140.0;
  }

  static bool _isCrossed(List<Point3D> landmarks) {
    double indexScore = _getThumbwardScore(landmarks[HandLandmark.indexTip.index], landmarks);
    double middleScore = _getThumbwardScore(landmarks[HandLandmark.middleTip.index], landmarks);
    return indexScore < middleScore;
  }

  static bool _isHooked(List<Point3D> landmarks, double palmSize) {
    double indexAngle = _getAngle(
      landmarks[HandLandmark.indexMcp.index], 
      landmarks[HandLandmark.indexPip.index], 
      landmarks[HandLandmark.indexTip.index]
    );
    return indexAngle < 100.0 && landmarks[HandLandmark.indexTip.index].y > landmarks[HandLandmark.indexPip.index].y;
  }

  static bool _isPointingSideways(List<Point3D> landmarks) {
    double dx = (landmarks[HandLandmark.indexTip.index].x - landmarks[HandLandmark.indexMcp.index].x).abs();
    double dy = (landmarks[HandLandmark.indexTip.index].y - landmarks[HandLandmark.indexMcp.index].y).abs();
    return dx > dy * 1.5; 
  }

  static bool _isPointingDownwards(List<Point3D> landmarks, double palmSize) {
    return landmarks[HandLandmark.indexTip.index].y > landmarks[HandLandmark.wrist.index].y + (palmSize * 0.3);
  }
}

/// A helper class to debounce/smooth the gesture output.
/// Instead of returning a jittery result every single frame, it keeps track
/// of the last N frames and returns the most frequent gesture.
class GestureSmoother {
  final int bufferSize;
  final List<String> _buffer = [];

  GestureSmoother({this.bufferSize = 10});

  String getSmoothedGesture(String currentGesture) {
    if (currentGesture == "Detecting..." || currentGesture.isEmpty) return "Detecting...";

    _buffer.add(currentGesture);
    if (_buffer.length > bufferSize) {
      _buffer.removeAt(0);
    }

    // Count frequencies of each gesture in the buffer
    Map<String, int> counts = {};
    for (var gesture in _buffer) {
      counts[gesture] = (counts[gesture] ?? 0) + 1;
    }

    // Return the gesture with the highest count (Majority Vote)
    String mostFrequent = currentGesture;
    int maxCount = 0;
    counts.forEach((key, value) {
      if (value > maxCount) {
        maxCount = value;
        mostFrequent = key;
      }
    });

    return mostFrequent;
  }
}