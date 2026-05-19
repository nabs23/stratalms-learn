import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import '../services/api_service.dart';
import '../services/database_helper.dart';
import '../services/connectivity_service.dart';

enum CourseDownloadStatus {
  notDownloaded,
  partiallyDownloaded,
  fullyDownloaded,
}

class CourseRepository {
  final ApiService _apiService = ApiService();
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;
  final ConnectivityService _connectivity = ConnectivityService();

  Future<Map<String, dynamic>?> getUser() async {
    final isOnline = await _connectivity.isOnline();

    if (isOnline) {
      final user = await _apiService.getUser();
      if (!kIsWeb) {
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
      }
      return user;
    } else {
      if (kIsWeb) {
        return null;
      }
      try {
        final db = await _dbHelper.database;
        final result = await db.query(
          'courses',
          where: 'id = ?',
          whereArgs: ['user_profile'],
        );
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
      if (!kIsWeb) {
        try {
          final db = await _dbHelper.database;
          await db.insert('courses', {
            'id': 'dashboard_stats',
            'list_type': 'stats',
            'data': jsonEncode(stats),
            'updated_at': DateTime.now().millisecondsSinceEpoch,
          }, conflictAlgorithm: ConflictAlgorithm.replace);

          // Auto-download active courses in the background
          final activeCourses =
              stats?['active_courses'] as List<dynamic>? ?? [];
          for (var c in activeCourses) {
            final id = c['course_id']?.toString();
            if (id != null) {
              _autoDownloadCourse(id);
            }
          }
        } catch (e) {
          debugPrint('Cache stats error: $e');
        }
      }
      return stats;
    } else {
      if (kIsWeb) {
        return null;
      }
      try {
        final db = await _dbHelper.database;
        final result = await db.query(
          'courses',
          where: 'id = ?',
          whereArgs: ['dashboard_stats'],
        );
        if (result.isNotEmpty) {
          final dataString = result.first['data'] as String;
          return jsonDecode(dataString) as Map<String, dynamic>;
        }

        // Fallback: build stats from cached overview (all courses)
        final coursesResult = await db.query(
          'courses',
          where: 'id = ?',
          whereArgs: ['overview'],
        );
        if (coursesResult.isNotEmpty) {
          final courses =
              jsonDecode(coursesResult.first['data'] as String)
                  as List<dynamic>;
          if (courses.isNotEmpty) {
            return _buildStatsFromCourses(courses);
          }
        }

        // Ultimate fallback: check downloaded course trees
        final treesResult = await db.query('course_trees');
        if (treesResult.isNotEmpty) {
          final List<dynamic> extractedCourses = [];
          for (var row in treesResult) {
            try {
              final treeData = jsonDecode(row['data'] as String);
              final course = treeData['course'];
              if (course != null) {
                extractedCourses.add({
                  'course_id': course['id'] ?? row['course_id'],
                  'title': course['title'] ?? 'Downloaded Course',
                  'description': course['description'],
                  'image': course['image_path'] ?? course['thumbnail_path'],
                  'progress': treeData['progress'] ?? 0,
                  'is_completed': false,
                });
              }
            } catch (e) {}
          }
          if (extractedCourses.isNotEmpty) {
            return _buildStatsFromCourses(extractedCourses);
          }
        }
      } catch (e) {
        debugPrint('Read cached stats error: $e');
      }
      return null;
    }
  }

  Map<String, dynamic> _buildStatsFromCourses(List<dynamic> courses) {
    int activeCount = 0;
    int completedCount = 0;
    double totalProgress = 0;

    List<dynamic> activeCourses = [];
    List<dynamic> completedCourses = [];

    for (var course in courses) {
      final progress = (course['progress'] ?? 0).toDouble();
      totalProgress += progress;
      final isCompleted = course['is_completed'] == true || progress >= 100;

      if (isCompleted) {
        completedCount++;
        completedCourses.add(course);
      } else {
        activeCount++;
        activeCourses.add(course);
      }
    }

    double avgProgress = courses.isEmpty ? 0 : totalProgress / courses.length;

    return {
      'overview': {
        'total_enrollments': courses.length,
        'active_courses': activeCount,
        'completed_courses': completedCount,
        'avg_progress': avgProgress.round(),
      },
      'active_courses': activeCourses,
      'completed_courses': completedCourses,
      'recent_activity': [],
      'announcements': [],
    };
  }

  Future<List<dynamic>> getStudentCourses({
    bool includeCompleted = true,
  }) async {
    final isOnline = await _connectivity.isOnline();

    if (isOnline) {
      final courses = await _apiService.getStudentCourses(
        includeCompleted: includeCompleted,
      );
      // Cache the result
      try {
        final db = await _dbHelper.database;
        await db.insert('courses', {
          'id': 'overview',
          'list_type': 'all',
          'data': jsonEncode(courses),
          'updated_at': DateTime.now().millisecondsSinceEpoch,
        }, conflictAlgorithm: ConflictAlgorithm.replace);

        // Auto-download active courses in the background
        for (var c in courses) {
          final isCompleted =
              c['is_completed'] == true || (c['progress'] ?? 0) >= 100;
          if (!isCompleted) {
            final id = c['course_id']?.toString();
            if (id != null) {
              _autoDownloadCourse(id);
            }
          }
        }
      } catch (e) {
        debugPrint('Cache courses error: $e');
      }
      return courses;
    } else {
      // Offline fallback
      try {
        final db = await _dbHelper.database;
        final result = await db.query(
          'courses',
          where: 'id = ?',
          whereArgs: ['overview'],
        );
        if (result.isNotEmpty) {
          final dataString = result.first['data'] as String;
          return jsonDecode(dataString) as List<dynamic>;
        }

        // Ultimate fallback: return extracted courses from trees
        final treesResult = await db.query('course_trees');
        if (treesResult.isNotEmpty) {
          final List<dynamic> extractedCourses = [];
          for (var row in treesResult) {
            try {
              final treeData = jsonDecode(row['data'] as String);
              final course = treeData['course'];
              if (course != null) {
                extractedCourses.add({
                  'course_id': course['id'] ?? row['course_id'],
                  'title': course['title'] ?? 'Downloaded Course',
                  'description': course['description'],
                  'image': course['image_path'] ?? course['thumbnail_path'],
                  'progress': treeData['progress'] ?? 0,
                  'is_completed': false,
                });
              }
            } catch (e) {}
          }
          return extractedCourses;
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
        final result = await db.query(
          'course_trees',
          where: 'course_id = ?',
          whereArgs: [courseId],
        );
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
      final activity = await _apiService.getStudentActivityDetail(
        courseId: courseId,
        activityId: activityId,
      );
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
        final result = await db.query(
          'activities',
          where: 'activity_id = ?',
          whereArgs: [activityId],
        );
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
    final activityIds = _extractActivityIdsFromTree(tree);

    // 3. Fetch all activity details
    for (var activityId in activityIds) {
      await getStudentActivityDetail(
        courseId: courseId,
        activityId: activityId,
      );
      // Wait a bit to not overwhelm the API
      await Future.delayed(const Duration(milliseconds: 100));
    }
  }

  List<String> _extractActivityIdsFromTree(Map<String, dynamic> tree) {
    final activityIds = <String>{};

    final units = tree['units'] as List<dynamic>? ?? [];
    for (final unit in units) {
      final activities =
          (unit as Map<String, dynamic>)['activities'] as List<dynamic>? ?? [];
      for (final activity in activities) {
        final activityMap = activity as Map<String, dynamic>;
        final id =
            activityMap['id']?.toString() ??
            activityMap['activity_id']?.toString();
        if (id != null && id.isNotEmpty) {
          activityIds.add(id);
        }
      }
    }

    final sections = tree['sections'] as List<dynamic>? ?? [];
    for (final section in sections) {
      _collectSectionActivityIds(section as Map<String, dynamic>, activityIds);
    }

    return activityIds.toList();
  }

  void _collectSectionActivityIds(
    Map<String, dynamic> section,
    Set<String> activityIds,
  ) {
    final activities = section['activities'] as List<dynamic>? ?? [];
    for (final activity in activities) {
      final activityMap = activity as Map<String, dynamic>;
      final id =
          activityMap['id']?.toString() ??
          activityMap['activity_id']?.toString();
      if (id != null && id.isNotEmpty) {
        activityIds.add(id);
      }
    }

    final children = section['children'] as List<dynamic>? ?? [];
    for (final child in children) {
      _collectSectionActivityIds(child as Map<String, dynamic>, activityIds);
    }
  }

  Future<CourseDownloadStatus> getCourseDownloadStatus(String courseId) async {
    try {
      final db = await _dbHelper.database;
      final treeRows = await db.query(
        'course_trees',
        where: 'course_id = ?',
        whereArgs: [courseId],
      );

      if (treeRows.isEmpty) {
        return CourseDownloadStatus.notDownloaded;
      }

      final treeDataString = treeRows.first['data'] as String;
      final treeData = jsonDecode(treeDataString) as Map<String, dynamic>;
      final activityIds = _extractActivityIdsFromTree(treeData);

      if (activityIds.isEmpty) {
        return CourseDownloadStatus.fullyDownloaded;
      }

      final activityRows = await db.query(
        'activities',
        columns: ['activity_id'],
        where: 'course_id = ?',
        whereArgs: [courseId],
      );

      if (activityRows.isEmpty) {
        return CourseDownloadStatus.partiallyDownloaded;
      }

      final cachedActivityIds = activityRows
          .map((row) => row['activity_id']?.toString())
          .whereType<String>()
          .toSet();

      final hasAllActivities = activityIds.every(cachedActivityIds.contains);

      return hasAllActivities
          ? CourseDownloadStatus.fullyDownloaded
          : CourseDownloadStatus.partiallyDownloaded;
    } catch (e) {
      return CourseDownloadStatus.notDownloaded;
    }
  }

  Future<bool> isCourseDownloaded(String courseId) async {
    return (await getCourseDownloadStatus(courseId)) ==
        CourseDownloadStatus.fullyDownloaded;
  }

  // Helper for silent background downloads
  Future<void> _autoDownloadCourse(String courseId) async {
    try {
      if (await isCourseDownloaded(courseId)) {
        return; // Already downloaded
      }
      // Silently download
      await downloadCourse(courseId);
    } catch (e) {
      debugPrint('Auto download course $courseId failed: $e');
    }
  }
}
