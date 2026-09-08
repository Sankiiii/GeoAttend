import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import '../models/attendance_session.dart';
import '../models/attendance_record.dart';
import '../models/attendance_status.dart';

class FirebaseService {
  final FirebaseDatabase _db = FirebaseDatabase.instance;

  DatabaseReference get _sessionRef => _db.ref('activeSession');
  DatabaseReference get _recordsRef => _db.ref('attendanceRecords');

  /// Stream of Firebase connection status (true = connected, false = offline).
  Stream<bool> get isConnectedStream {
    return _db.ref('.info/connected').onValue.map((event) {
      return event.snapshot.value == true;
    });
  }

  /// Stream of the active attendance session.
  Stream<AttendanceSession?> get activeSessionStream {
    return _sessionRef.onValue.map((event) {
      final data = event.snapshot.value;
      if (data == null || data is! Map) return null;
      try {
        return AttendanceSession.fromJson(data);
      } catch (e) {
        debugPrint('Firebase activeSession parse error: $e');
        return null;
      }
    });
  }

  /// Stream of student attendance records, sorted newest first.
  Stream<List<AttendanceRecord>> get attendanceRecordsStream {
    return _recordsRef.onValue.map((event) {
      final data = event.snapshot.value;
      if (data == null || data is! Map) return <AttendanceRecord>[];

      final records = <AttendanceRecord>[];
      for (final entry in data.entries) {
        try {
          records.add(AttendanceRecord.fromJson(
            entry.key.toString(),
            entry.value as Map<dynamic, dynamic>,
          ));
        } catch (e) {
          debugPrint('Firebase record parse error: $e');
        }
      }
      records.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      return records;
    });
  }

  /// Creates a new session (wipes old submissions).
  Future<void> createSession(AttendanceSession session) async {
    await _recordsRef.remove();
    await _sessionRef.set(session.toJson());
  }

  /// Deactivates current session.
  Future<void> endSession() async {
    await _sessionRef.update({'isActive': false});
  }

  /// Submits student attendance record.
  Future<void> submitAttendance(AttendanceRecord record) async {
    await _recordsRef.child(record.id).set(record.toJson());
  }

  /// Faculty manual review action (Approve / Reject).
  Future<void> updateRecordStatus(
      String recordId, AttendanceStatus status, String remarks) async {
    await _recordsRef.child(recordId).update({
      'status': status.firebaseKey,
      'remarks': remarks,
    });
  }
}
