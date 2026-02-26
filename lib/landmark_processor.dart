import 'gestures_logic.dart';

class LandmarkProcessor {
  // MediaPipe hand landmark indices
  static const _wrist = 0;
  static const _thumbTip = 4;
  static const _indexTip = 8;
  static const _middleTip = 12;
  static const _ringTip = 16;
  static const _pinkyTip = 20;
  static const _thumbMCP = 2;
  static const _indexMCP = 5;
  static const _middleMCP = 9;
  static const _ringMCP = 13;
  static const _pinkyMCP = 17;
  static const _indexPIP = 6;
  static const _middlePIP = 10;
  static const _ringPIP = 14;
  static const _pinkyPIP = 18;

  static String process(List<Point3D> landmarks) {
    if (landmarks.length < 21) return 'invalid';

    final wrist = landmarks[_wrist];

    // Check if each finger is extended or curled
    final thumbExtended = _isThumbExtended(landmarks);
    final indexExtended = _isFingerExtended(landmarks, _indexTip, _indexMCP);
    final middleExtended = _isFingerExtended(landmarks, _middleTip, _middleMCP);
    final ringExtended = _isFingerExtended(landmarks, _ringTip, _ringMCP);
    final pinkyExtended = _isFingerExtended(landmarks, _pinkyTip, _pinkyMCP);

    // Finger spread — are index and middle separated?
    final indexMiddleSpread = _spread(landmarks[_indexTip], landmarks[_middleTip]);
    final indexPinkySpread = _spread(landmarks[_indexTip], landmarks[_pinkyTip]);

    // Thumb position relative to palm
    final thumbUp = landmarks[_thumbTip].y < wrist.y;
    final thumbAcrossPalm = landmarks[_thumbTip].x > landmarks[_indexMCP].x;

    // Curl amounts (0.0 = fully extended, 1.0 = fully curled)
    final indexCurl = _curlAmount(landmarks, _indexTip, _indexPIP, _indexMCP);
    final middleCurl = _curlAmount(landmarks, _middleTip, _middlePIP, _middleMCP);

    // Create a simplified "signature" that's stable across frames
    final signature = _createGestureSignature(
      thumbExtended,
      indexExtended,
      middleExtended,
      ringExtended,
      pinkyExtended,
      thumbUp,
      thumbAcrossPalm,
      indexMiddleSpread > 0.02,
      indexPinkySpread > 0.04,
    );

    // Return the signature (this is what gets compared for stability)
    return signature;
  }

  // Create a stable gesture signature that doesn't change every frame
  static String _createGestureSignature(
    bool thumbExt,
    bool indexExt,
    bool middleExt,
    bool ringExt,
    bool pinkyExt,
    bool thumbUp,
    bool thumbAcross,
    bool indexMiddleSpread,
    bool indexPinkySpread,
  ) {
    // Create a simple code like "ECCC-US"
    // Each letter = E (extended) or C (curled)
    // Thumb direction = U (up) or D (down)
    // Spread = S (spread) or N (not spread)
    
    final t = thumbExt ? 'E' : 'C';
    final i = indexExt ? 'E' : 'C';
    final m = middleExt ? 'E' : 'C';
    final r = ringExt ? 'E' : 'C';
    final p = pinkyExt ? 'E' : 'C';
    
    final thumbDir = thumbUp ? 'U' : 'D'; // U = up, D = down
    final spread = indexMiddleSpread ? 'S' : 'N'; // S = spread, N = not spread
    
    return '$t$i$m$r$p-$thumbDir$spread';
  }

  static bool _isFingerExtended(List<Point3D> lm, int tip, int mcp) {
    // Tip is higher than MCP (lower y value = higher on screen)
    return lm[tip].y < lm[mcp].y;
  }

  static bool _isThumbExtended(List<Point3D> lm) {
    return (lm[_thumbTip].x - lm[_thumbMCP].x).abs() > 0.05;
  }

  static double _spread(Point3D a, Point3D b) {
    final dx = a.x - b.x;
    final dy = a.y - b.y;
    return (dx * dx + dy * dy).clamp(0, 1).toDouble();
  }

  static double _curlAmount(List<Point3D> lm, int tip, int pip, int mcp) {
    // How much is the finger curled — tip below PIP means curled
    return (lm[tip].y - lm[pip].y).clamp(0.0, 1.0);
  }
}