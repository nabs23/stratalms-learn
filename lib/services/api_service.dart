import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter/foundation.dart';
import '../constants/app_constants.dart';

class ApiService {
  final _storage = const FlutterSecureStorage();

  Future<Map<String, String>?> _authorizedHeaders() async {
    final token = await getToken();
    if (token == null) return null;

    return {
      'Accept': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  // Login
  Future<bool> login(String email, String password) async {
    final url = Uri.parse('${AppConstants.baseUrl}/api/login');
    
    try {
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          'email': email,
          'password': password,
          'device_name': 'mobile_device',
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final token = data['token'];
        
        // Save the token securely
        await _storage.write(key: 'auth_token', value: token);
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('Login error: $e');
      return false;
    }
  }

  // Get current token
  Future<String?> getToken() async {
    return await _storage.read(key: 'auth_token');
  }

  // Logout
  Future<bool> logout() async {
    final token = await getToken();
    if (token == null) return true;

    final url = Uri.parse('${AppConstants.baseUrl}/api/logout');

    try {
      await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );
      
      // Clear token locally regardless of server success
      await _storage.delete(key: 'auth_token');
      return true;
    } catch (e) {
      debugPrint('Logout error: $e');
      await _storage.delete(key: 'auth_token');
      return true;
    }
  }

  // Get user details
  Future<Map<String, dynamic>?> getUser() async {
    final headers = await _authorizedHeaders();
    if (headers == null) return null;

    final url = Uri.parse('${AppConstants.baseUrl}/api/user');

    try {
      final response = await http.get(
        url,
        headers: headers,
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return null;
    } catch (e) {
      debugPrint('Get user error: $e');
      return null;
    }
  }

  // Get dashboard stats
  Future<Map<String, dynamic>?> getDashboardStats() async {
    final headers = await _authorizedHeaders();
    if (headers == null) return null;

    final url = Uri.parse('${AppConstants.baseUrl}/api/student/dashboard/stats');

    try {
      final response = await http.get(
        url,
        headers: headers,
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return null;
    } catch (e) {
      debugPrint('Get dashboard stats error: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>?> getStudentCoursesOverview() async {
    return await getDashboardStats();
  }

  Future<List<dynamic>> getStudentCourses({
    bool includeCompleted = true,
  }) async {
    final data = await getStudentCoursesOverview();
    if (data == null) return [];

    final activeCourses = data['active_courses'] as List<dynamic>? ?? [];
    if (!includeCompleted) {
      return activeCourses;
    }

    final completedCourses = data['completed_courses'] as List<dynamic>? ?? [];

    return [...activeCourses, ...completedCourses];
  }

  Future<Map<String, dynamic>?> getStudentCourseTree(String courseId) async {
    final headers = await _authorizedHeaders();
    if (headers == null) return null;

    final url = Uri.parse(
      '${AppConstants.baseUrl}/api/student/courses/$courseId/tree',
    );

    try {
      final response = await http.get(url, headers: headers);

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }

      debugPrint(
        'Get student course tree failed: ${response.statusCode} ${response.body}',
      );
      return null;
    } catch (e) {
      debugPrint('Get student course tree error: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>?> getStudentActivityDetail({
    required String courseId,
    required String activityId,
  }) async {
    final headers = await _authorizedHeaders();
    if (headers == null) return null;

    final url = Uri.parse(
      '${AppConstants.baseUrl}/api/student/courses/$courseId/activities/$activityId',
    );

    try {
      final response = await http.get(url, headers: headers);

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }

      debugPrint(
        'Get student activity detail failed: ${response.statusCode} ${response.body}',
      );
      return null;
    } catch (e) {
      debugPrint('Get student activity detail error: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>?> startStudentActivityProgress({
    required String courseId,
    required String activityId,
  }) async {
    final headers = await _authorizedHeaders();
    if (headers == null) return null;

    final url = Uri.parse(
      '${AppConstants.baseUrl}/api/student/courses/$courseId/activities/$activityId/progress/start',
    );

    try {
      final response = await http.post(url, headers: headers);

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }

      return null;
    } catch (e) {
      debugPrint('Start student activity progress error: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>?> updateStudentActivityProgress({
    required String courseId,
    required String activityId,
    required int timeSpent,
  }) async {
    final headers = await _authorizedHeaders();
    if (headers == null) return null;

    final url = Uri.parse(
      '${AppConstants.baseUrl}/api/student/courses/$courseId/activities/$activityId/progress',
    );

    try {
      final response = await http.put(
        url,
        headers: {
          ...headers,
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'timeSpent': timeSpent}),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }

      return null;
    } catch (e) {
      debugPrint('Update student activity progress error: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>?> completeStudentActivityProgress({
    required String courseId,
    required String activityId,
    required int timeSpent,
  }) async {
    final headers = await _authorizedHeaders();
    if (headers == null) return null;

    final url = Uri.parse(
      '${AppConstants.baseUrl}/api/student/courses/$courseId/activities/$activityId/progress/complete',
    );

    try {
      final response = await http.post(
        url,
        headers: {
          ...headers,
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'timeSpent': timeSpent}),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }

      return null;
    } catch (e) {
      debugPrint('Complete student activity progress error: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>?> getAssignmentSubmissions({
    required String courseId,
    required String activityId,
  }) async {
    final headers = await _authorizedHeaders();
    if (headers == null) return null;

    final url = Uri.parse(
      '${AppConstants.baseUrl}/api/student/courses/$courseId/activities/$activityId/assignment/submissions',
    );

    try {
      final response = await http.get(url, headers: headers);
      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }

      return null;
    } catch (e) {
      debugPrint('Get assignment submissions error: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>?> getAssignmentUploadUrl({
    required String courseId,
    required String activityId,
    required String filename,
    required int size,
    String? type,
  }) async {
    final headers = await _authorizedHeaders();
    if (headers == null) return null;

    final url = Uri.parse(
      '${AppConstants.baseUrl}/api/student/courses/$courseId/activities/$activityId/assignment/upload-url',
    );

    try {
      final response = await http.post(
        url,
        headers: {
          ...headers,
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'filename': filename,
          'size': size,
          'type': type,
        }),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }

      debugPrint('Get assignment upload URL failed: ${response.body}');
      return null;
    } catch (e) {
      debugPrint('Get assignment upload URL error: $e');
      return null;
    }
  }

  Future<bool> uploadFileToSignedUrl({
    required String uploadUrl,
    required Uint8List bytes,
    required String contentType,
  }) async {
    try {
      final response = await http.put(
        Uri.parse(uploadUrl),
        headers: {
          'Content-Type': contentType,
        },
        body: bytes,
      );

      return response.statusCode >= 200 && response.statusCode < 300;
    } catch (e) {
      debugPrint('Upload file to signed URL error: $e');
      return false;
    }
  }

  Future<Map<String, dynamic>?> submitAssignment({
    required String courseId,
    required String activityId,
    required String fileUrl,
    required String fileName,
    required int fileSize,
    String? fileType,
    String? note,
  }) async {
    final headers = await _authorizedHeaders();
    if (headers == null) return null;

    final url = Uri.parse(
      '${AppConstants.baseUrl}/api/student/courses/$courseId/activities/$activityId/assignment/submissions',
    );

    try {
      final response = await http.post(
        url,
        headers: {
          ...headers,
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'file_url': fileUrl,
          'file_name': fileName,
          'file_size': fileSize,
          'file_type': fileType,
          'note': note,
        }),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }

      debugPrint('Submit assignment failed: ${response.body}');
      return null;
    } catch (e) {
      debugPrint('Submit assignment error: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>?> sendAssessmentOtp({
    required String courseId,
    required String activityId,
  }) async {
    final headers = await _authorizedHeaders();
    if (headers == null) return null;

    final url = Uri.parse(
      '${AppConstants.baseUrl}/api/student/assessment/$courseId/$activityId/otp/send',
    );

    try {
      final response = await http.post(url, headers: headers);
      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }

      debugPrint('Send assessment OTP failed: ${response.body}');
      return null;
    } catch (e) {
      debugPrint('Send assessment OTP error: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>?> startAssessment({
    required String courseId,
    required String activityId,
    String? otp,
  }) async {
    final headers = await _authorizedHeaders();
    if (headers == null) return null;

    final url = Uri.parse(
      '${AppConstants.baseUrl}/api/student/assessment/$courseId/$activityId/start',
    );

    try {
      final response = await http.post(
        url,
        headers: {
          ...headers,
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          if (otp != null && otp.isNotEmpty) 'otp': otp,
        }),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }

      debugPrint('Start assessment failed: ${response.body}');
      return null;
    } catch (e) {
      debugPrint('Start assessment error: $e');
      return null;
    }
  }
}
