import 'attendance_status.dart';

class AttendanceRecord {
  final String id;
  final String studentName;
  final String rollNo;
  final double studentLat;
  final double studentLng;
  final double distanceMeters;
  final double bearingToStudent;
  final bool isMocked;
  final bool isInFrontSector;
  final DateTime timestamp;
  AttendanceStatus status;
  String? remarks;

  // Layer 1 — BLE verification fields
  final bool bleVerified;   // true if student passed the number challenge
  final int? bleCodeUsed;   // the 2-digit code that was matched (audit trail)

  // Layer 3 — Face verification fields
  final bool faceVerified;  // true if live camera scan matched profile photo
  final String? photoBase64; // thumbnail of verified student photo

  AttendanceRecord({
    required this.id,
    required this.studentName,
    required this.rollNo,
    required this.studentLat,
    required this.studentLng,
    required this.distanceMeters,
    required this.bearingToStudent,
    required this.isMocked,
    required this.isInFrontSector,
    required this.timestamp,
    required this.status,
    this.remarks,
    this.bleVerified = false,
    this.bleCodeUsed,
    this.faceVerified = false,
    this.photoBase64,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'studentName': studentName,
        'rollNo': rollNo,
        'studentLat': studentLat,
        'studentLng': studentLng,
        'distanceMeters': distanceMeters,
        'bearingToStudent': bearingToStudent,
        'isMocked': isMocked,
        'isInFrontSector': isInFrontSector,
        'timestamp': timestamp.millisecondsSinceEpoch,
        'status': status.firebaseKey,
        'remarks': remarks ?? '',
        'bleVerified': bleVerified,
        'bleCodeUsed': bleCodeUsed,
        'faceVerified': faceVerified,
        if (photoBase64 != null) 'photoBase64': photoBase64,
      };

  factory AttendanceRecord.fromJson(String id, Map<dynamic, dynamic> json) {
    return AttendanceRecord(
      id: id,
      studentName: json['studentName'] as String? ?? 'Unknown',
      rollNo: json['rollNo'] as String? ?? 'N/A',
      studentLat: (json['studentLat'] as num?)?.toDouble() ?? 0.0,
      studentLng: (json['studentLng'] as num?)?.toDouble() ?? 0.0,
      distanceMeters: (json['distanceMeters'] as num?)?.toDouble() ?? 0.0,
      bearingToStudent:
          (json['bearingToStudent'] as num?)?.toDouble() ?? 0.0,
      isMocked: json['isMocked'] as bool? ?? false,
      isInFrontSector: json['isInFrontSector'] as bool? ?? true,
      timestamp: DateTime.fromMillisecondsSinceEpoch(
          (json['timestamp'] as int?) ?? DateTime.now().millisecondsSinceEpoch),
      status:
          AttendanceStatusX.fromKey(json['status'] as String? ?? 'approved'),
      remarks: json['remarks'] as String?,
      bleVerified: json['bleVerified'] as bool? ?? false,
      bleCodeUsed: json['bleCodeUsed'] as int?,
      faceVerified: json['faceVerified'] as bool? ?? false,
      photoBase64: json['photoBase64'] as String?,
    );
  }
}
