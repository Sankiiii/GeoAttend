import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/attendance_record.dart';
import 'firebase_service.dart';

/// Item in the local persistent attendance queue.
class QueuedAttendance {
  final AttendanceRecord record;
  bool isSynced;
  DateTime? syncedAt;

  QueuedAttendance({
    required this.record,
    this.isSynced = false,
    this.syncedAt,
  });

  Map<String, dynamic> toJson() => {
        'record': record.toJson(),
        'isSynced': isSynced,
        'syncedAt': syncedAt?.millisecondsSinceEpoch,
      };

  factory QueuedAttendance.fromJson(Map<String, dynamic> json) {
    final recMap = json['record'] as Map<dynamic, dynamic>;
    final id = recMap['id']?.toString() ?? DateTime.now().millisecondsSinceEpoch.toString();
    final record = AttendanceRecord.fromJson(id, recMap);
    final isSynced = json['isSynced'] as bool? ?? false;
    final syncedAtMillis = json['syncedAt'] as int?;
    return QueuedAttendance(
      record: record,
      isSynced: isSynced,
      syncedAt: syncedAtMillis != null ? DateTime.fromMillisecondsSinceEpoch(syncedAtMillis) : null,
    );
  }
}

/// Offline-first queue and auto-synchronization manager.
///
/// Guaranteed to store attendance locally on the device (using SharedPreferences),
/// and automatically uploads to Firebase whenever internet connectivity is present.
class SyncQueueService {
  static const String _queueKey = 'geoattend_offline_attendance_queue';
  static final SyncQueueService _instance = SyncQueueService._internal();
  factory SyncQueueService() => _instance;

  SyncQueueService._internal();

  final FirebaseService _firebaseService = FirebaseService();
  final ValueNotifier<int> pendingCountNotifier = ValueNotifier<int>(0);
  final ValueNotifier<bool> isSyncingNotifier = ValueNotifier<bool>(false);

  /// Number of attendance records currently awaiting internet synchronization.
  int get pendingCount => pendingCountNotifier.value;

  Timer? _periodicSyncTimer;
  StreamSubscription<bool>? _connectionSub;
  bool _initialized = false;

  /// Initializes the queue, loads pending count, and starts auto-sync monitors.
  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    await _updatePendingCount();

    // 1. Periodically check and sync un-uploaded records every 10 seconds
    _periodicSyncTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      syncAllPending();
    });

    // 2. Listen to Firebase connection state
    _connectionSub = _firebaseService.isConnectedStream.listen((connected) {
      if (connected) {
        debugPrint('SyncQueueService: Firebase online -> triggering auto-sync');
        syncAllPending();
      }
    });

    // Run initial sync attempt
    syncAllPending();
  }

  /// Saves an attendance record locally to the persistent queue.
  /// If [isSynced] is true, records it as already delivered to Firebase.
  Future<QueuedAttendance> enqueue(AttendanceRecord record, {bool isSynced = false}) async {
    final prefs = await SharedPreferences.getInstance();
    final list = await getQueue();

    // Check if record already exists in queue
    final existingIdx = list.indexWhere((item) => item.record.id == record.id);
    final queuedItem = QueuedAttendance(
      record: record,
      isSynced: isSynced,
      syncedAt: isSynced ? DateTime.now() : null,
    );

    if (existingIdx >= 0) {
      list[existingIdx] = queuedItem;
    } else {
      list.insert(0, queuedItem); // newest first
    }

    final encoded = jsonEncode(list.map((e) => e.toJson()).toList());
    await prefs.setString(_queueKey, encoded);

    await _updatePendingCount();
    debugPrint('SyncQueueService: enqueued record ${record.id} (isSynced=$isSynced)');

    // Attempt instant sync if not yet marked synced
    if (!isSynced) {
      syncAllPending();
    }

    return queuedItem;
  }

  /// Retrieves the entire persistent queue.
  Future<List<QueuedAttendance>> getQueue() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_queueKey);
    if (raw == null || raw.isEmpty) return [];

    try {
      final decoded = jsonDecode(raw) as List<dynamic>;
      return decoded.map((e) => QueuedAttendance.fromJson(e as Map<String, dynamic>)).toList();
    } catch (e) {
      debugPrint('SyncQueueService: error decoding queue: $e');
      return [];
    }
  }

  /// Attempts to upload all pending attendance records to Firebase.
  /// Returns the number of newly synced records.
  Future<int> syncAllPending() async {
    if (isSyncingNotifier.value) return 0; // already syncing

    final list = await getQueue();
    final pendingItems = list.where((item) => !item.isSynced).toList();
    if (pendingItems.isEmpty) {
      pendingCountNotifier.value = 0;
      return 0;
    }

    isSyncingNotifier.value = true;
    int syncedCount = 0;

    try {
      final prefs = await SharedPreferences.getInstance();

      for (final item in pendingItems) {
        try {
          await _firebaseService.submitAttendance(item.record);
          item.isSynced = true;
          item.syncedAt = DateTime.now();
          syncedCount++;
          debugPrint('SyncQueueService: successfully synced record ${item.record.id}');
        } catch (e) {
          debugPrint('SyncQueueService: failed to sync record ${item.record.id}: $e');
          // If a record fails (e.g. still offline), break out and retry on next tick
          break;
        }
      }

      if (syncedCount > 0) {
        final encoded = jsonEncode(list.map((e) => e.toJson()).toList());
        await prefs.setString(_queueKey, encoded);
      }
    } finally {
      isSyncingNotifier.value = false;
      await _updatePendingCount();
    }

    return syncedCount;
  }

  Future<void> _updatePendingCount() async {
    final list = await getQueue();
    final count = list.where((item) => !item.isSynced).length;
    pendingCountNotifier.value = count;
  }

  void dispose() {
    _periodicSyncTimer?.cancel();
    _connectionSub?.cancel();
  }
}
