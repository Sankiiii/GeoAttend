import 'package:flutter/material.dart';

enum AttendanceStatus {
  approved,
  rejectedOutsideRadius,
  rejectedBehindFaculty,
  flaggedMockLocation,
  sessionExpired,
  manuallyApproved,
  manuallyRejected,
}

extension AttendanceStatusX on AttendanceStatus {
  String get firebaseKey => name;

  static AttendanceStatus fromKey(String key) {
    return AttendanceStatus.values.firstWhere(
      (e) => e.name == key,
      orElse: () => AttendanceStatus.approved,
    );
  }

  String get label {
    switch (this) {
      case AttendanceStatus.approved:
        return 'Approved';
      case AttendanceStatus.manuallyApproved:
        return 'Manually Approved';
      case AttendanceStatus.rejectedOutsideRadius:
        return 'Outside Bluetooth Range';
      case AttendanceStatus.rejectedBehindFaculty:
        return 'Behind Teacher';
      case AttendanceStatus.manuallyRejected:
        return 'Manually Rejected';
      case AttendanceStatus.sessionExpired:
        return 'Session Expired';
      case AttendanceStatus.flaggedMockLocation:
        return 'Mock GPS Detected';
    }
  }

  Color get color {
    switch (this) {
      case AttendanceStatus.approved:
      case AttendanceStatus.manuallyApproved:
        return Colors.green;
      case AttendanceStatus.rejectedOutsideRadius:
      case AttendanceStatus.manuallyRejected:
        return Colors.red;
      case AttendanceStatus.rejectedBehindFaculty:
        return Colors.deepOrange;
      case AttendanceStatus.sessionExpired:
        return Colors.grey;
      case AttendanceStatus.flaggedMockLocation:
        return Colors.orange;
    }
  }

  IconData get icon {
    switch (this) {
      case AttendanceStatus.approved:
      case AttendanceStatus.manuallyApproved:
        return Icons.check_circle_rounded;
      case AttendanceStatus.rejectedOutsideRadius:
      case AttendanceStatus.manuallyRejected:
        return Icons.cancel_rounded;
      case AttendanceStatus.rejectedBehindFaculty:
        return Icons.back_hand_rounded;
      case AttendanceStatus.sessionExpired:
        return Icons.timer_off_rounded;
      case AttendanceStatus.flaggedMockLocation:
        return Icons.warning_rounded;
    }
  }

  bool get canReview =>
      this == AttendanceStatus.flaggedMockLocation ||
      this == AttendanceStatus.rejectedOutsideRadius ||
      this == AttendanceStatus.rejectedBehindFaculty;
}
