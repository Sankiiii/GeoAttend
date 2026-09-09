class AttendanceSession {
  final String title;
  final String facultyName;
  final double facultyLat;
  final double facultyLng;
  final double radiusMeters;
  final DateTime startTime;
  final DateTime endTime;
  bool isActive;

  // Directional geofence fields
  final bool directionalModeEnabled;
  final double facultyHeading; // 0–360° compass direction faculty faces
  final double frontSectorDegrees; // configurable arc width (30°–360°)

  // Layer 1 — BLE beacon fields
  final String bleSessionUuid; // random UUID per session, embedded in BLE packet
  final int? currentBleCode; // live 2-digit rotating code mirrored to Firebase
  final String roomNumber; // classroom or hall identifier

  AttendanceSession({
    required this.title,
    required this.facultyName,
    required this.facultyLat,
    required this.facultyLng,
    required this.radiusMeters,
    required this.startTime,
    required this.endTime,
    this.isActive = true,
    this.directionalModeEnabled = false,
    this.facultyHeading = 0.0,
    this.frontSectorDegrees = 180.0,
    this.bleSessionUuid = '',
    this.currentBleCode,
    this.roomNumber = 'LH-1',
  });

  bool get isExpired => DateTime.now().isAfter(endTime) || !isActive;

  Duration get remainingTime {
    if (isExpired) return Duration.zero;
    final diff = endTime.difference(DateTime.now());
    return diff.isNegative ? Duration.zero : diff;
  }

  Map<String, dynamic> toJson() => {
        'title': title,
        'facultyName': facultyName,
        'facultyLat': facultyLat,
        'facultyLng': facultyLng,
        'radiusMeters': radiusMeters,
        'startTime': startTime.millisecondsSinceEpoch,
        'endTime': endTime.millisecondsSinceEpoch,
        'isActive': isActive,
        'directionalModeEnabled': directionalModeEnabled,
        'facultyHeading': facultyHeading,
        'frontSectorDegrees': frontSectorDegrees,
        'bleSessionUuid': bleSessionUuid,
        'currentBleCode': currentBleCode,
        'roomNumber': roomNumber,
      };

  factory AttendanceSession.fromJson(Map<dynamic, dynamic> json) {
    return AttendanceSession(
      title: json['title'] as String? ?? 'Session',
      facultyName: json['facultyName'] as String? ?? 'Faculty',
      facultyLat: (json['facultyLat'] as num?)?.toDouble() ?? 0.0,
      facultyLng: (json['facultyLng'] as num?)?.toDouble() ?? 0.0,
      radiusMeters: (json['radiusMeters'] as num?)?.toDouble() ?? 50.0,
      startTime: DateTime.fromMillisecondsSinceEpoch(
          (json['startTime'] as int?) ?? DateTime.now().millisecondsSinceEpoch),
      endTime: DateTime.fromMillisecondsSinceEpoch(
          (json['endTime'] as int?) ??
              DateTime.now()
                  .add(const Duration(minutes: 5))
                  .millisecondsSinceEpoch),
      isActive: json['isActive'] as bool? ?? false,
      directionalModeEnabled:
          json['directionalModeEnabled'] as bool? ?? false,
      facultyHeading: (json['facultyHeading'] as num?)?.toDouble() ?? 0.0,
      frontSectorDegrees:
          (json['frontSectorDegrees'] as num?)?.toDouble() ?? 180.0,
      bleSessionUuid: json['bleSessionUuid'] as String? ?? '',
      currentBleCode: json['currentBleCode'] as int?,
      roomNumber: json['roomNumber'] as String? ?? 'LH-1',
    );
  }
}
