import 'package:flutter/material.dart';
import 'course_content_screen.dart';
import '../repositories/course_repository.dart';

class CourseDetailScreen extends StatefulWidget {
  const CourseDetailScreen({
    super.key,
    required this.course,
    required this.isCompleted,
    required this.imageUrlBuilder,
  });

  final Map<String, dynamic> course;
  final bool isCompleted;
  final String Function(String?) imageUrlBuilder;

  @override
  State<CourseDetailScreen> createState() => _CourseDetailScreenState();
}

class _CourseDetailScreenState extends State<CourseDetailScreen> {
  final _courseRepo = CourseRepository();
  CourseDownloadStatus _downloadStatus = CourseDownloadStatus.notDownloaded;
  bool _isDownloading = false;

  @override
  void initState() {
    super.initState();
    _checkDownloadedStatus();
  }

  Future<void> _checkDownloadedStatus() async {
    final courseId = widget.course['course_id']?.toString();
    if (courseId != null) {
      final status = await _courseRepo.getCourseDownloadStatus(courseId);
      if (mounted) {
        setState(() {
          _downloadStatus = status;
        });
      }
    }
  }

  Future<void> _downloadCourse() async {
    final courseId = widget.course['course_id']?.toString();
    if (courseId == null) return;

    setState(() {
      _isDownloading = true;
    });

    try {
      await _courseRepo.downloadCourse(courseId);
      final status = await _courseRepo.getCourseDownloadStatus(courseId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              status == CourseDownloadStatus.fullyDownloaded
                  ? 'Course downloaded successfully'
                  : 'Course partially downloaded',
            ),
          ),
        );
        setState(() {
          _downloadStatus = status;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to download course')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isDownloading = false;
        });
      }
    }
  }

  String _readableType(String? type) {
    if (type == null || type.isEmpty) return 'General';
    return type
        .toLowerCase()
        .split('_')
        .map((word) => word.isEmpty
            ? ''
            : '${word[0].toUpperCase()}${word.substring(1)}')
        .join(' ');
  }

  Widget _buildInfoChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.grey.withOpacity(0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.grey[700]),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.grey[800],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.22)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(height: 10),
            Text(
              value,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
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
      ),
    );
  }

  Widget _buildSectionTitle(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 17,
        fontWeight: FontWeight.w700,
        color: Colors.black87,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.course['title']?.toString() ?? 'Untitled course';
    final courseId = widget.course['course_id']?.toString();
    final image = widget.course['image']?.toString();
    final progress = (widget.course['progress'] ?? 0).toDouble();
    final grade = widget.course['grade']?.toString();
    final instructor = widget.course['instructor_name']?.toString();
    final lastAccessed = widget.course['last_accessed_at']?.toString();
    final completedAt = widget.course['completed_at']?.toString();
    final enrolledAt = widget.course['enrolled_at']?.toString();
    final type = _readableType(widget.course['type']?.toString());
    final issuesCertificate = (widget.course['issues_certificate'] ?? false) == true;

    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 240,
            pinned: true,
            backgroundColor: Colors.deepPurple,
            actions: [
              if (_isDownloading)
                const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  ),
                )
              else if (_downloadStatus == CourseDownloadStatus.fullyDownloaded)
                const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Icon(Icons.offline_pin_rounded, color: Colors.white),
                )
              else if (_downloadStatus == CourseDownloadStatus.partiallyDownloaded)
                IconButton(
                  icon: const Icon(Icons.downloading_rounded, color: Colors.white),
                  onPressed: _downloadCourse,
                  tooltip: 'Continue Download',
                )
              else
                IconButton(
                  icon: const Icon(Icons.download_rounded, color: Colors.white),
                  onPressed: _downloadCourse,
                  tooltip: 'Download Course',
                ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              titlePadding: const EdgeInsets.only(left: 18, right: 18, bottom: 14),
              title: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
              background: Stack(
                fit: StackFit.expand,
                children: [
                  (image != null && image.isNotEmpty)
                      ? Image.network(
                          widget.imageUrlBuilder(image),
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            color: Colors.deepPurple,
                            child: const Icon(
                              Icons.image_outlined,
                              color: Colors.white70,
                              size: 48,
                            ),
                          ),
                        )
                      : Container(
                          color: Colors.deepPurple,
                          child: const Icon(
                            Icons.school_rounded,
                            color: Colors.white70,
                            size: 54,
                          ),
                        ),
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withOpacity(0.05),
                          Colors.black.withOpacity(0.6),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _buildInfoChip(
                        widget.isCompleted
                            ? Icons.verified_rounded
                            : Icons.play_circle_fill_rounded,
                        widget.isCompleted ? 'Completed' : 'Active',
                      ),
                      _buildInfoChip(Icons.category_rounded, type),
                      if (issuesCertificate)
                        _buildInfoChip(
                          Icons.workspace_premium_rounded,
                          'Certificate',
                        ),
                      if (instructor != null && instructor.isNotEmpty)
                        _buildInfoChip(Icons.person_rounded, instructor),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      _buildMetricCard(
                        title: 'Progress',
                        value: '${progress.toStringAsFixed(0)}%',
                        icon: Icons.trending_up_rounded,
                        color: const Color(0xFF4F46E5),
                      ),
                      const SizedBox(width: 10),
                      _buildMetricCard(
                        title: 'Grade',
                        value: grade != null ? '$grade%' : '--',
                        icon: Icons.emoji_events_rounded,
                        color: const Color(0xFF0EA5E9),
                      ),
                    ],
                  ),
                  const SizedBox(height: 22),
                  _buildSectionTitle('Learning Progress'),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.04),
                          blurRadius: 12,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: LinearProgressIndicator(
                            value: (progress / 100).clamp(0.0, 1.0),
                            minHeight: 10,
                            backgroundColor: Colors.grey[200],
                            valueColor: const AlwaysStoppedAnimation<Color>(
                              Colors.deepPurple,
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          widget.isCompleted
                              ? 'You have completed this course.'
                              : 'Keep going, you are making steady progress.',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey[700],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 22),
                  _buildSectionTitle('Course Timeline'),
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.grey.withOpacity(0.16)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (enrolledAt != null && enrolledAt.isNotEmpty)
                          Text(
                            'Enrolled: $enrolledAt',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey[800],
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        if (!widget.isCompleted &&
                            lastAccessed != null &&
                            lastAccessed.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text(
                            'Last active: $lastAccessed',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey[800],
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                        if (widget.isCompleted &&
                            completedAt != null &&
                            completedAt.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text(
                            'Completed: $completedAt',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey[800],
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 26),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: courseId == null || courseId.isEmpty
                          ? null
                          : () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => CourseContentScreen(
                                    courseId: courseId,
                                    courseTitle: title,
                                  ),
                                ),
                              );
                            },
                      icon: Icon(
                        widget.isCompleted
                            ? Icons.workspace_premium_rounded
                            : Icons.play_arrow_rounded,
                      ),
                      label: Text(
                        widget.isCompleted
                            ? 'View Course Content'
                            : 'Continue Learning',
                      ),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
