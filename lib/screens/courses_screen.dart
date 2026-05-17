import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../constants/app_constants.dart';
import '../utils/responsive.dart';
import 'course_detail_screen.dart';

class CoursesScreen extends StatefulWidget {
  const CoursesScreen({super.key});

  @override
  State<CoursesScreen> createState() => _CoursesScreenState();
}

class _CoursesScreenState extends State<CoursesScreen> {
  final _apiService = ApiService();
  final _searchController = TextEditingController();

  bool _isLoading = true;
  String _query = '';
  Map<String, dynamic>? _overview;
  List<dynamic> _activeCourses = [];
  List<dynamic> _completedCourses = [];

  @override
  void initState() {
    super.initState();
    _loadCourses();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadCourses() async {
    final data = await _apiService.getStudentCoursesOverview();

    if (!mounted) return;

    setState(() {
      _overview = data?['overview'] as Map<String, dynamic>?;
      _activeCourses = data?['active_courses'] as List<dynamic>? ?? [];
      _completedCourses = data?['completed_courses'] as List<dynamic>? ?? [];
      _isLoading = false;
    });
  }

  String _getImageUrl(String? imagePath) {
    if (imagePath == null || imagePath.isEmpty) return '';
    if (imagePath.startsWith('http')) return imagePath;
    final prefix = imagePath.startsWith('/') ? '' : '/';
    return '${AppConstants.baseUrl}$prefix$imagePath';
  }

  List<dynamic> _filterCourses(List<dynamic> source) {
    if (_query.trim().isEmpty) return source;

    final lowerQuery = _query.toLowerCase().trim();

    return source.where((course) {
      final title = (course['title'] ?? '').toString().toLowerCase();
      final instructor =
          (course['instructor_name'] ?? '').toString().toLowerCase();
      return title.contains(lowerQuery) || instructor.contains(lowerQuery);
    }).toList();
  }

  Widget _buildTopStats() {
    final active = _overview?['active_courses']?.toString() ?? '0';
    final completed = _overview?['completed_courses']?.toString() ?? '0';
    final avgProgress = '${_overview?['avg_progress'] ?? 0}%';

    return Row(
      children: [
        Expanded(
          child: _buildMiniStatCard(
            title: 'Active',
            value: active,
            icon: Icons.play_circle_fill_rounded,
            color: const Color(0xFF3B82F6),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildMiniStatCard(
            title: 'Completed',
            value: completed,
            icon: Icons.verified_rounded,
            color: const Color(0xFF10B981),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildMiniStatCard(
            title: 'Avg Progress',
            value: avgProgress,
            icon: Icons.trending_up_rounded,
            color: const Color(0xFF8B5CF6),
          ),
        ),
      ],
    );
  }

  Widget _buildMiniStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 10),
          Text(
            value,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 2),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[700],
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCourseCard(Map<String, dynamic> course, {required bool isDone}) {
    final progress = (course['progress'] ?? 0).toDouble();
    final grade = course['grade'];

    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => CourseDetailScreen(
              course: course,
              isCompleted: isDone,
              imageUrlBuilder: _getImageUrl,
            ),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              child: Container(
                height: 130,
                width: double.infinity,
                color: Colors.grey[200],
                child: (course['image'] != null &&
                        course['image'].toString().isNotEmpty)
                    ? Image.network(
                        _getImageUrl(course['image'].toString()),
                        fit: BoxFit.cover,
                        errorBuilder: (_, error, stackTrace) {
                          debugPrint('Course image load error (${_getImageUrl(course["image"].toString())}): $error');
                          return const Icon(
                            Icons.image_outlined,
                            size: 36,
                            color: Colors.grey,
                          );
                        },
                      )
                    : const Icon(
                        Icons.image_outlined,
                        size: 36,
                        color: Colors.grey,
                      ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          course['title']?.toString() ?? 'Untitled course',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Colors.black87,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: (isDone ? Colors.green : Colors.blue)
                              .withOpacity(0.1),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          isDone ? 'Completed' : 'Active',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: isDone ? Colors.green[700] : Colors.blue[700],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    course['instructor_name']?.toString().isNotEmpty == true
                        ? 'By ${course['instructor_name']}'
                        : 'Instructor unavailable',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey[700],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 14),
                  if (!isDone) ...[
                    Row(
                      children: [
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: (progress / 100).clamp(0.0, 1.0),
                              minHeight: 7,
                              backgroundColor: Colors.grey[200],
                              valueColor: const AlwaysStoppedAnimation<Color>(
                                Colors.deepPurple,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          '${progress.toStringAsFixed(0)}%',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Colors.deepPurple,
                          ),
                        ),
                      ],
                    ),
                  ] else
                    Row(
                      children: [
                        Icon(
                          Icons.emoji_events_rounded,
                          size: 16,
                          color: Colors.amber[700],
                        ),
                        const SizedBox(width: 6),
                        Text(
                          grade != null
                              ? 'Final grade: ${grade.toString()}%'
                              : 'Course completed',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[700],
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCoursesList(List<dynamic> courses, {required bool isDone}) {
    if (courses.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 42, horizontal: 20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.grey.withOpacity(0.15)),
        ),
        child: Column(
          children: [
            Icon(
              isDone ? Icons.task_alt_rounded : Icons.school_outlined,
              size: 42,
              color: Colors.grey[500],
            ),
            const SizedBox(height: 10),
            Text(
              isDone ? 'No completed courses yet' : 'No active courses found',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: Colors.grey[800],
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Try changing your search or check back later.',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.zero,
      itemCount: courses.length,
      itemBuilder: (context, index) {
        return _buildCourseCard(
          courses[index] as Map<String, dynamic>,
          isDone: isDone,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final filteredActive = _filterCourses(_activeCourses);
    final filteredCompleted = _filterCourses(_completedCourses);

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: Colors.grey[50],
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _loadCourses,
                child: SafeArea(
                  child: Responsive.constrainedWidth(
                    child: Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(18, 18, 18, 10),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'My Courses',
                                style: TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.black87,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Continue learning and track your achievements',
                                style: TextStyle(
                                  color: Colors.grey[700],
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 16),
                              _buildTopStats(),
                              const SizedBox(height: 14),
                              TextField(
                                controller: _searchController,
                                onChanged: (value) {
                                  setState(() {
                                    _query = value;
                                  });
                                },
                                decoration: InputDecoration(
                                  hintText: 'Search by course or instructor',
                                  prefixIcon: const Icon(
                                    Icons.search_rounded,
                                    size: 20,
                                  ),
                                  filled: true,
                                  fillColor: Colors.white,
                                  contentPadding: const EdgeInsets.symmetric(
                                    vertical: 14,
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(14),
                                    borderSide: BorderSide.none,
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(14),
                                    borderSide: BorderSide(
                                      color: Colors.grey.withOpacity(0.2),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              Container(
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: Colors.grey.withOpacity(0.18),
                                  ),
                                ),
                                child: const TabBar(
                                  indicatorSize: TabBarIndicatorSize.tab,
                                  dividerColor: Colors.transparent,
                                  labelStyle: TextStyle(
                                    fontWeight: FontWeight.w700,
                                  ),
                                  tabs: [
                                    Tab(text: 'Active'),
                                    Tab(text: 'Completed'),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(18, 0, 18, 0),
                            child: TabBarView(
                              children: [
                                _buildCoursesList(filteredActive, isDone: false),
                                _buildCoursesList(
                                  filteredCompleted,
                                  isDone: true,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
      ),
    );
  }
}
