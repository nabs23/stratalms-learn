import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../services/api_service.dart';
import '../services/database_helper.dart';
import '../services/connectivity_service.dart';

class ProgressSyncRepository {
  final ApiService _apiService = ApiService();
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;
  final ConnectivityService _connectivity = ConnectivityService();

  Future<Map<String, dynamic>?> startStudentActivityProgress({
    required String courseId,
    required String activityId,
  }) async {
    final isOnline = await _connectivity.isOnline();
    if (isOnline) {
      return await _apiService.startStudentActivityProgress(courseId: courseId, activityId: activityId);
    } else {
      await _queueSyncAction(courseId, activityId, 'start', {});
      return {'status': 'queued'};
    }
  }

  Future<Map<String, dynamic>?> updateStudentActivityProgress({
    required String courseId,
    required String activityId,
    required int timeSpent,
  }) async {
    final isOnline = await _connectivity.isOnline();
    if (isOnline) {
      return await _apiService.updateStudentActivityProgress(courseId: courseId, activityId: activityId, timeSpent: timeSpent);
    } else {
      await _queueSyncAction(courseId, activityId, 'update', {'timeSpent': timeSpent});
      return {'status': 'queued'};
    }
  }

  Future<Map<String, dynamic>?> completeStudentActivityProgress({
    required String courseId,
    required String activityId,
    required int timeSpent,
  }) async {
    final isOnline = await _connectivity.isOnline();
    if (isOnline) {
      return await _apiService.completeStudentActivityProgress(courseId: courseId, activityId: activityId, timeSpent: timeSpent);
    } else {
      await _queueSyncAction(courseId, activityId, 'complete', {'timeSpent': timeSpent});
      return {'status': 'queued'};
    }
  }

  Future<void> _queueSyncAction(String courseId, String activityId, String action, Map<String, dynamic> payload) async {
    try {
      final db = await _dbHelper.database;
      await db.insert('progress_sync_queue', {
        'course_id': courseId,
        'activity_id': activityId,
        'action': action,
        'payload': jsonEncode(payload),
        'created_at': DateTime.now().millisecondsSinceEpoch,
      });
    } catch (e) {
      debugPrint('Queue sync action error: $e');
    }
  }

  Future<void> syncPendingProgress() async {
    final isOnline = await _connectivity.isOnline();
    if (!isOnline) return;

    try {
      final db = await _dbHelper.database;
      final pending = await db.query('progress_sync_queue', orderBy: 'created_at ASC');
      
      for (final row in pending) {
        final id = row['id'] as int;
        final courseId = row['course_id'] as String;
        final activityId = row['activity_id'] as String;
        final action = row['action'] as String;
        final payloadStr = row['payload'] as String;
        final payload = jsonDecode(payloadStr) as Map<String, dynamic>;

        bool success = false;
        if (action == 'start') {
          final res = await _apiService.startStudentActivityProgress(courseId: courseId, activityId: activityId);
          success = res != null;
        } else if (action == 'update') {
          final res = await _apiService.updateStudentActivityProgress(courseId: courseId, activityId: activityId, timeSpent: payload['timeSpent']);
          success = res != null;
        } else if (action == 'complete') {
          final res = await _apiService.completeStudentActivityProgress(courseId: courseId, activityId: activityId, timeSpent: payload['timeSpent']);
          success = res != null;
        }

        if (success) {
          await db.delete('progress_sync_queue', where: 'id = ?', whereArgs: [id]);
        }
      }
    } catch (e) {
      debugPrint('Sync pending progress error: $e');
    }
  }
}
