import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import '../services/api_service.dart';
import '../services/database_helper.dart';
import '../services/connectivity_service.dart';

class CourseRepository {
  final ApiService _apiService = ApiService();
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;
  final ConnectivityService _connectivity = ConnectivityService();

  Future<Map<String, dynamic>?> getUser() async {
    final isOnline = await _connectivity.isOnline();
    
    if (isOnline) {
      final user = await _apiService.getUser();
      try {
        final db = await _dbHelper.database;
        await db.insert('courses', {
          'id': 'user_profile',
          'list_type': 'user',
          'data': jsonEncode(user),
          'updated_at': DateTime.now().millisecondsSinceEpoch,
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      } catch (e) {
        debugPrint('Cache user error: $e');
      }
      return user;
    } else {
      try {
        final db = await _dbHelper.database;
        final result = await db.query('courses', where: 'id = ?', whereArgs: ['user_profile']);
        if (result.isNotEmpty) {
          final dataString = result.first['data'] as String;
          return jsonDecode(dataString) as Map<String, dynamic>;
        }
      } catch (e) {
        debugPrint('Read cached user error: $e');
      }
      return null;
    }
  }

  Future<Map<String, dynamic>?> getDashboardStats() async {
    final isOnline = await _connectivity.isOnline();
    
    if (isOnline) {
      final stats = await _apiService.getDashboardStats();
      try {
        final db = await _dbHelper.database;
        await db.insert('courses', {
          'id': 'dashboard_stats',
          'list_type': 'stats',
          'data': jsonEncode(stats),
          'updated_at': DateTime.now().millisecondsSinceEpoch,
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      } catch (e) {
        debugPrint('Cache stats error: $e');
      }
      return stats;
    } else {
      try {
        final db = await _dbHelper.database;
        final result = await db.query('courses', where: 'id = ?', whereArgs: ['dashboard_stats']);
        if (result.isNotEmpty) {
          final dataString = result.first['data'] as String;
          return jsonDecode(dataString) as Map<String, dynamic>;
        }
      } catch (e) {
        debugPrint('Read cached stats error: $e');
      }
      return null;
    }
  }

  Future<List<dynamic>> getStudentCourses({bool includeCompleted = true}) async {
    final isOnline = await _connectivity.isOnline();
    
    if (isOnline) {
      final courses = await _apiService.getStudentCourses(includeCompleted: includeCompleted);
      // Cache the result
      try {
        final db = await _dbHelper.database;
        await db.insert('courses', {
          'id': 'overview',
          'list_type': 'all',
          'data': jsonEncode(courses),
          'updated_at': DateTime.now().millisecondsSinceEpoch,
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      } catch (e) {
        debugPrint('Cache courses error: $e');
      }
      return courses;
    } else {
      // Offline fallback
      try {
        final db = await _dbHelper.database;
        final result = await db.query('courses', where: 'id = ?', whereArgs: ['overview']);
        if (result.isNotEmpty) {
          final dataString = result.first['data'] as String;
          return jsonDecode(dataString) as List<dynamic>;
        }
      } catch (e) {
        debugPrint('Read cached courses error: $e');
      }
      return [];
    }
  }

  Future<Map<String, dynamic>?> getStudentCourseTree(String courseId) async {
    final isOnline = await _connectivity.isOnline();
    
    if (isOnline) {
      final tree = await _apiService.getStudentCourseTree(courseId);
      if (tree != null) {
        try {
          final db = await _dbHelper.database;
          await db.insert('course_trees', {
            'course_id': courseId,
            'data': jsonEncode(tree),
            'updated_at': DateTime.now().millisecondsSinceEpoch,
          }, conflictAlgorithm: ConflictAlgorithm.replace);
        } catch (e) {
          debugPrint('Cache course tree error: $e');
        }
      }
      return tree;
    } else {
      // Offline fallback
      try {
        final db = await _dbHelper.database;
        final result = await db.query('course_trees', where: 'course_id = ?', whereArgs: [courseId]);
        if (result.isNotEmpty) {
          final dataString = result.first['data'] as String;
          return jsonDecode(dataString) as Map<String, dynamic>;
        }
      } catch (e) {
        debugPrint('Read cached course tree error: $e');
      }
      return null;
    }
  }

  Future<Map<String, dynamic>?> getStudentActivityDetail({
    required String courseId,
    required String activityId,
  }) async {
    final isOnline = await _connectivity.isOnline();
    
    if (isOnline) {
      final activity = await _apiService.getStudentActivityDetail(courseId: courseId, activityId: activityId);
      if (activity != null) {
        try {
          final db = await _dbHelper.database;
          await db.insert('activities', {
            'activity_id': activityId,
            'course_id': courseId,
            'data': jsonEncode(activity),
            'updated_at': DateTime.now().millisecondsSinceEpoch,
          }, conflictAlgorithm: ConflictAlgorithm.replace);
        } catch (e) {
          debugPrint('Cache activity error: $e');
        }
      }
      return activity;
    } else {
      // Offline fallback
      try {
        final db = await _dbHelper.database;
        final result = await db.query('activities', where: 'activity_id = ?', whereArgs: [activityId]);
        if (result.isNotEmpty) {
          final dataString = result.first['data'] as String;
          return jsonDecode(dataString) as Map<String, dynamic>;
        }
      } catch (e) {
        debugPrint('Read cached activity error: $e');
      }
      return null;
    }
  }

  Future<void> downloadCourse(String courseId) async {
    final isOnline = await _connectivity.isOnline();
    if (!isOnline) return;

    // 1. Fetch course tree
    final tree = await getStudentCourseTree(courseId);
    if (tree == null) return;

    // 2. Extract all activity IDs
    final List<String> activityIds = [];
    final units = tree['units'] as List<dynamic>? ?? [];
    for (var unit in units) {
      final activities = unit['activities'] as List<dynamic>? ?? [];
      for (var activity in activities) {
        final id = activity['activity_id']?.toString();
        if (id != null) {
          activityIds.add(id);
        }
      }
    }

    // 3. Fetch all activity details
    for (var activityId in activityIds) {
      await getStudentActivityDetail(courseId: courseId, activityId: activityId);
      // Wait a bit to not overwhelm the API
      await Future.delayed(const Duration(milliseconds: 100));
    }
  }

  Future<bool> isCourseDownloaded(String courseId) async {
    try {
      final db = await _dbHelper.database;
      final result = await db.query('course_trees', where: 'course_id = ?', whereArgs: [courseId]);
      return result.isNotEmpty;
    } catch (e) {
      return false;
    }
  }
}


