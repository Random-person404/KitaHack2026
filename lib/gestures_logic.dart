import 'dart:math';

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

  static String recognize(List<Point3D> landmarks) {
    if (landmarks.length < 21) return "";

    double palmSize = landmarks[HandLandmark.wrist.index]
        .distanceTo(landmarks[HandLandmark.middleMcp.index]);
    if (palmSize == 0) return "Detecting...";

    // ── Finger extension ──────────────────────────────────────────────────
    bool isThumbExt  = _isThumbExtended(landmarks, palmSize);
    bool isIndexExt  = _isFingerExtended(landmarks, HandLandmark.indexMcp,  HandLandmark.indexPip,  HandLandmark.indexTip);
    bool isMiddleExt = _isFingerExtended(landmarks, HandLandmark.middleMcp, HandLandmark.middlePip, HandLandmark.middleTip);
    bool isRingExt   = _isFingerExtended(landmarks, HandLandmark.ringMcp,   HandLandmark.ringPip,   HandLandmark.ringTip);
    bool isPinkyExt  = _isFingerExtended(landmarks, HandLandmark.pinkyMcp,  HandLandmark.pinkyPip,  HandLandmark.pinkyTip);

    // ── Curl amounts ──────────────────────────────────────────────────────
    double indexCurl  = _curlAmount(landmarks, HandLandmark.indexMcp,  HandLandmark.indexPip,  HandLandmark.indexTip);
    double middleCurl = _curlAmount(landmarks, HandLandmark.middleMcp, HandLandmark.middlePip, HandLandmark.middleTip);
    double ringCurl   = _curlAmount(landmarks, HandLandmark.ringMcp,   HandLandmark.ringPip,   HandLandmark.ringTip);
    double pinkyCurl  = _curlAmount(landmarks, HandLandmark.pinkyMcp,  HandLandmark.pinkyPip,  HandLandmark.pinkyTip);

    // ── Touch detections ──────────────────────────────────────────────────
    bool thumbIndexTouch   = _isTouching(landmarks[HandLandmark.thumbTip.index], landmarks[HandLandmark.indexTip.index],  palmSize, 0.5);
    bool thumbMiddleTouch  = _isTouching(landmarks[HandLandmark.thumbTip.index], landmarks[HandLandmark.middleTip.index], palmSize, 0.5);
    bool thumbRingTouch    = _isTouching(landmarks[HandLandmark.thumbTip.index], landmarks[HandLandmark.ringTip.index],   palmSize, 0.4);
    bool thumbPinkyTouch   = _isTouching(landmarks[HandLandmark.thumbTip.index], landmarks[HandLandmark.pinkyTip.index],  palmSize, 0.4);
    bool thumbToMiddleSide = _isTouching(landmarks[HandLandmark.thumbTip.index], landmarks[HandLandmark.middlePip.index], palmSize, 0.5);

    // K: thumb between index and middle base
    Point3D indexMiddleBase = Point3D(
      (landmarks[HandLandmark.indexMcp.index].x + landmarks[HandLandmark.middleMcp.index].x) / 2,
      (landmarks[HandLandmark.indexMcp.index].y + landmarks[HandLandmark.middleMcp.index].y) / 2,
      (landmarks[HandLandmark.indexMcp.index].z + landmarks[HandLandmark.middleMcp.index].z) / 2,
    );
bool thumbAtIndexMiddleBase = landmarks[HandLandmark.thumbTip.index]
    .distanceTo(indexMiddleBase) < palmSize * 0.5;

    // ── Spreads ───────────────────────────────────────────────────────────
    double indexMiddleSpread = landmarks[HandLandmark.indexTip.index]
        .distanceTo(landmarks[HandLandmark.middleTip.index]);
    double indexPinkySpread  = landmarks[HandLandmark.indexTip.index]
        .distanceTo(landmarks[HandLandmark.pinkyTip.index]);

    // ── Direction — AXES SWAPPED ──────────────────────────────────────────
    bool isSideways     = _isPointingSideways(landmarks);
    bool isPointingDown = _isPointingDownwards(landmarks, palmSize);

    // Palm vs back of hand facing camera
    // When palm faces camera: thumbMcp Y > indexMcp Y (in swapped axes)
    bool isPalmFacing = landmarks[HandLandmark.thumbMcp.index].y
    < landmarks[HandLandmark.indexMcp.index].y;

    // ── X detection ───────────────────────────────────────────────────────
    double indexAngle = _getAngle(
      landmarks[HandLandmark.indexMcp.index],
      landmarks[HandLandmark.indexPip.index],
      landmarks[HandLandmark.indexTip.index],
    );
    bool indexPartiallyBent = indexAngle > 65.0 && indexAngle < 120.0;
    bool othersFullyCurled  = middleCurl > 0.65 && ringCurl > 0.65 && pinkyCurl > 0.65;
    bool isX = indexPartiallyBent && othersFullyCurled;

    // =====================================================================
    // RECOGNITION
    // =====================================================================

    // ── Special combos ────────────────────────────────────────────────────
    if (isThumbExt && isIndexExt && !isMiddleExt && !isRingExt && isPinkyExt) return "I Love You ❤️";
    if (isThumbExt && isPinkyExt && !isIndexExt && !isMiddleExt && !isRingExt) return "Y";
    if (isPinkyExt && !isIndexExt && !isMiddleExt && !isRingExt && !isThumbExt) return "I";

    if (isThumbExt && isIndexExt && isMiddleExt && isRingExt && isPinkyExt) return "5";

    // 4: index+middle+ring+pinky, no thumb, back of hand
if (!isThumbExt && isIndexExt && isMiddleExt && isRingExt && isPinkyExt && !isPalmFacing) return "4";

// 5: all 4 fingers up, back of hand (already handled above with thumb)
if (!isThumbExt && isIndexExt && isMiddleExt && isRingExt && isPinkyExt) return "B";

    // ── F/9: Thumb+Index pinch, 3 fingers up ─────────────────────────────
    if (thumbIndexTouch && !isIndexExt && isMiddleExt && isRingExt && isPinkyExt) return "F / 9";

    // ── Number touches ────────────────────────────────────────────────────
    if (thumbPinkyTouch && isIndexExt && isMiddleExt && isRingExt && !isPinkyExt) return "6";
    if (thumbRingTouch  && isIndexExt && isMiddleExt && !isRingExt && isPinkyExt) return "7";
    if (thumbMiddleTouch && isIndexExt && !isMiddleExt && isRingExt && isPinkyExt) return "8";

    // W: index+middle+ring, no pinky, palm facing
if (!isThumbExt && isIndexExt && isMiddleExt && isRingExt && !isPinkyExt) return "W";

// 4: index+middle+ring+pinky, no thumb, back of hand
if (!isThumbExt && isIndexExt && isMiddleExt && isRingExt && isPinkyExt && !isPalmFacing) return "4";

    // ── P: index+middle+thumb pointing DOWN ──────────────────────────────
    if (isThumbExt && isIndexExt && isMiddleExt && !isRingExt && !isPinkyExt && isPointingDown) return "P";
    

    // ── 3: thumb+index+middle, back of hand OR no special touch ───────────
    if (isThumbExt && isIndexExt && isMiddleExt && !isRingExt && !isPinkyExt) {
      if (!isPalmFacing) return "3";
      return "3";
    }

    // ── Q: index+thumb pointing down ─────────────────────────────────────
    if (isThumbExt && isIndexExt && !isMiddleExt && !isRingExt && !isPinkyExt && isPointingDown) return "Q";

    // ── G: index+thumb sideways ───────────────────────────────────────────
    if (isThumbExt && isIndexExt && !isMiddleExt && !isRingExt && !isPinkyExt && isSideways) return "G";

    // ── L: index+thumb pointing up ────────────────────────────────────────
    if (isThumbExt && isIndexExt && !isMiddleExt && !isRingExt && !isPinkyExt) return "L";

    // ── H / R / V / 2 / U: index+middle, no thumb ────────────────────────
    if (!isThumbExt && isIndexExt && isMiddleExt && !isRingExt && !isPinkyExt) {
      if (!isPalmFacing) return "2";
      if (isSideways) return "H";
      if (_isCrossed(landmarks)) return "R";
      if (indexMiddleSpread > palmSize * 0.4) return "V";
      return "U";
    }

    // K: index+middle up, thumb between index and middle tips, palm facing
if (isIndexExt && isMiddleExt && !isRingExt && !isPinkyExt && thumbAtIndexMiddleBase && isPalmFacing) return "K";

    // ── X: hooked index ───────────────────────────────────────────────────
    if (isX) return "X";

    // ── D / 1: index only ─────────────────────────────────────────────────
    if (isIndexExt && !isMiddleExt && !isRingExt && !isPinkyExt) {
      if (isPalmFacing && thumbToMiddleSide) return "D";
      if (!isPalmFacing) return "1";
      return "D";
    }

    // ── Fist group: S, E, M, N, T, A ─────────────────────────────────────
    if (!isIndexExt && !isMiddleExt && !isRingExt && !isPinkyExt) {

      bool allCurled = indexCurl > 0.45 && middleCurl > 0.45
          && ringCurl > 0.45 && pinkyCurl > 0.45;

      Point3D midKnuckle = Point3D(
        (landmarks[HandLandmark.middlePip.index].x + landmarks[HandLandmark.ringPip.index].x) / 2,
        (landmarks[HandLandmark.middlePip.index].y + landmarks[HandLandmark.ringPip.index].y) / 2,
        (landmarks[HandLandmark.middlePip.index].z + landmarks[HandLandmark.ringPip.index].z) / 2,
      );
      double thumbToMid = landmarks[HandLandmark.thumbTip.index].distanceTo(midKnuckle) / palmSize;

      // S: thumb wraps OVER fingers — check first
// S thumb is close to middle knuckle area
bool thumbAboveFingers = landmarks[HandLandmark.thumbTip.index].y
    < landmarks[HandLandmark.indexPip.index].y;
if (allCurled && thumbAboveFingers && thumbToMid < 0.55) return "S";

// E: fingers curl over thumb — thumb is lower, NOT close to knuckles
bool thumbBelowFingers = landmarks[HandLandmark.thumbTip.index].y
    > landmarks[HandLandmark.indexPip.index].y;
bool veryTightlyCurled = indexCurl > 0.6 && middleCurl > 0.6
    && ringCurl > 0.6 && pinkyCurl > 0.6;
if (veryTightlyCurled && thumbBelowFingers && thumbToMid > 0.4) return "E";

// O / 0 — all fingers curled, pinky tip close to thumb tip
bool thumbPinkyClose = landmarks[HandLandmark.thumbTip.index]
    .distanceTo(landmarks[HandLandmark.pinkyTip.index]) < palmSize * 0.5;
if (thumbPinkyClose && middleCurl > 0.5 && ringCurl > 0.5 && pinkyCurl > 0.5) return "O / 0";

// ── C ─────────────────────────────────────────────────────────────────
    if (_isCurved(landmarks, palmSize)) return "C";

    // ── Thumb only = A ────────────────────────────────────────────────────
    if (isThumbExt && !isIndexExt && !isMiddleExt && !isRingExt && !isPinkyExt) return "A";

      // M, N, T, A
      double thumbScore  = _getThumbwardScore(landmarks[HandLandmark.thumbTip.index], landmarks);
      double indexScore  = _getThumbwardScore(landmarks[HandLandmark.indexMcp.index], landmarks);
      double middleScore = _getThumbwardScore(landmarks[HandLandmark.middleMcp.index], landmarks);
      double ringScore   = _getThumbwardScore(landmarks[HandLandmark.ringMcp.index], landmarks);

      if (thumbScore < ringScore)   return "M";
      if (thumbScore < middleScore) return "N";
      if (thumbScore < indexScore)  return "T";
      return "A";
    }

    return "Detecting...";
  }

  // =====================================================================
  // HELPERS
  // =====================================================================

  static double _getAngle(Point3D p1, Point3D p2, Point3D p3) {
    double v1x=p1.x-p2.x, v1y=p1.y-p2.y, v1z=p1.z-p2.z;
    double v2x=p3.x-p2.x, v2y=p3.y-p2.y, v2z=p3.z-p2.z;
    double dot=v1x*v2x+v1y*v2y+v1z*v2z;
    double m1=sqrt(v1x*v1x+v1y*v1y+v1z*v1z);
    double m2=sqrt(v2x*v2x+v2y*v2y+v2z*v2z);
    if (m1*m2==0) return 0;
    return acos((dot/(m1*m2)).clamp(-1.0,1.0))*(180.0/pi);
  }

  static bool _isFingerExtended(List<Point3D> lm, HandLandmark mcp, HandLandmark pip, HandLandmark tip) {
    return _getAngle(lm[mcp.index], lm[pip.index], lm[tip.index]) > 140.0;
  }

  static double _curlAmount(List<Point3D> lm, HandLandmark mcp, HandLandmark pip, HandLandmark tip) {
    return ((180.0 - _getAngle(lm[mcp.index], lm[pip.index], lm[tip.index])) / 180.0).clamp(0.0, 1.0);
  }

  static bool _isThumbExtended(List<Point3D> lm, double palmSize) {
    return lm[HandLandmark.thumbTip.index]
        .distanceTo(lm[HandLandmark.pinkyMcp.index]) > palmSize * 1.15;
  }

  static bool _isTouching(Point3D p1, Point3D p2, double palmSize, double t) {
    return p1.distanceTo(p2) < palmSize * t;
  }

  static bool _isCurved(List<Point3D> lm, double palmSize) {
    double ia=_getAngle(lm[HandLandmark.indexMcp.index], lm[HandLandmark.indexPip.index], lm[HandLandmark.indexTip.index]);
    double ma=_getAngle(lm[HandLandmark.middleMcp.index],lm[HandLandmark.middlePip.index],lm[HandLandmark.middleTip.index]);
    double ra=_getAngle(lm[HandLandmark.ringMcp.index],  lm[HandLandmark.ringPip.index],  lm[HandLandmark.ringTip.index]);
    double pa=_getAngle(lm[HandLandmark.pinkyMcp.index], lm[HandLandmark.pinkyPip.index], lm[HandLandmark.pinkyTip.index]);
    bool allCurved = ia>70&&ia<160 && ma>70&&ma<160 && ra>70&&ra<160 && pa>70&&pa<160;
    return allCurved && lm[HandLandmark.thumbTip.index]
    .distanceTo(lm[HandLandmark.indexTip.index]) > palmSize * 0.5;
  }

  static bool _isCrossed(List<Point3D> lm) {
  // R: index crosses IN FRONT of middle
  // Check both Z depth and X/Y proximity of the two finger tips
  double spread = lm[HandLandmark.indexTip.index]
      .distanceTo(lm[HandLandmark.middleTip.index]);
  double palmSize = lm[HandLandmark.wrist.index]
      .distanceTo(lm[HandLandmark.middleMcp.index]);
  // Fingers are crossed when tips are very close together
  return spread < palmSize * 0.25;
}

  static bool _isPointingSideways(List<Point3D> lm) {
    double dx = (lm[HandLandmark.indexTip.index].y - lm[HandLandmark.indexMcp.index].y).abs();
    double dy = (lm[HandLandmark.indexTip.index].x - lm[HandLandmark.indexMcp.index].x).abs();
    return dx > dy * 2.5;
  }

  static bool _isPointingDownwards(List<Point3D> lm, double palmSize) {
    return lm[HandLandmark.indexTip.index].x >
        lm[HandLandmark.wrist.index].x + (palmSize * 0.25);
  }

  static double _getThumbwardScore(Point3D target, List<Point3D> lm) {
    double vx=lm[HandLandmark.indexMcp.index].x-lm[HandLandmark.pinkyMcp.index].x;
    double vy=lm[HandLandmark.indexMcp.index].y-lm[HandLandmark.pinkyMcp.index].y;
    double tx=target.x-lm[HandLandmark.pinkyMcp.index].x;
    double ty=target.y-lm[HandLandmark.pinkyMcp.index].y;
    return tx*vx+ty*vy;
  }
}

class GestureSmoother {
  final int bufferSize;
  final List<String> _buffer = [];
  GestureSmoother({this.bufferSize = 10});

  String getSmoothedGesture(String current) {
    if (current == "Detecting..." || current.isEmpty) return current;
    _buffer.add(current);
    if (_buffer.length > bufferSize) _buffer.removeAt(0);
    Map<String, int> counts = {};
    for (var g in _buffer) counts[g] = (counts[g] ?? 0) + 1;
    String best = current; int max = 0;
    counts.forEach((k, v) { if (v > max) { max = v; best = k; } });
    return best;
  }

  void clear() => _buffer.clear();
}