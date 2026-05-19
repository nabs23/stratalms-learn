import 'package:flutter/material.dart';

import '../../../repositories/course_repository.dart';

typedef ImageUrlBuilder = String Function(String? imagePath);
typedef CourseTapCallback = void Function(Map<String, dynamic> course);

class ActiveCoursesSection extends StatelessWidget {
  const ActiveCoursesSection({
    super.key,
    required this.courses,
    required this.courseDownloadStatuses,
    required this.imageUrlBuilder,
    this.onCourseTap,
  });

  final List<dynamic> courses;
  final Map<String, CourseDownloadStatus> courseDownloadStatuses;
  final ImageUrlBuilder imageUrlBuilder;
  final CourseTapCallback? onCourseTap;

  List<Color> _placeholderPaletteFor(Map<String, dynamic> course) {
    const palettes = [
      [Color(0xFF6366F1), Color(0xFF8B5CF6)],
      [Color(0xFF0EA5E9), Color(0xFF06B6D4)],
      [Color(0xFF10B981), Color(0xFF34D399)],
      [Color(0xFFF59E0B), Color(0xFFF97316)],
      [Color(0xFFEF4444), Color(0xFFF43F5E)],
      [Color(0xFF14B8A6), Color(0xFF22D3EE)],
    ];

    final seed =
        (course['course_id'] ?? course['id'] ?? course['title'] ?? 'course')
            .toString();
    final index = seed.hashCode.abs() % palettes.length;
    return palettes[index];
  }

  Widget _buildCoursePlaceholder(Map<String, dynamic> course) {
    final palette = _placeholderPaletteFor(course);
    final title = (course['title'] ?? 'Course').toString();
    final initials = title
        .split(' ')
        .where((part) => part.isNotEmpty)
        .take(2)
        .map((part) => part[0].toUpperCase())
        .join();

    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: palette,
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            right: -16,
            top: -14,
            child: Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.16),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Positioned(
            left: -24,
            bottom: -28,
            child: Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.school_rounded, size: 30, color: Colors.white),
                const SizedBox(height: 8),
                Text(
                  initials.isEmpty ? 'CR' : initials,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                    letterSpacing: 0.8,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (courses.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 20),
        child: Center(
          child: Text(
            'No active courses.',
            style: TextStyle(color: Colors.grey),
          ),
        ),
      );
    }

    return SizedBox(
      height: 248,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        clipBehavior: Clip.none,
        itemCount: courses.length,
        itemBuilder: (context, index) {
          final screenWidth = MediaQuery.of(context).size.width;
          final cardWidth = (screenWidth - 64).clamp(230.0, 300.0).toDouble();
          final rawCourse = courses[index];
          final courseData = rawCourse is Map<String, dynamic>
              ? rawCourse
              : Map<String, dynamic>.from(rawCourse as Map);
          final courseId = courseData['course_id']?.toString();
          final downloadStatus = courseId == null
              ? CourseDownloadStatus.notDownloaded
              : (courseDownloadStatuses[courseId] ??
                    CourseDownloadStatus.notDownloaded);
          final isFullyDownloaded =
              downloadStatus == CourseDownloadStatus.fullyDownloaded;
          final isPartiallyDownloaded =
              downloadStatus == CourseDownloadStatus.partiallyDownloaded;
          final progressValue = ((courseData['progress'] ?? 0) as num)
              .clamp(0, 100)
              .toDouble();

          return Container(
            width: cardWidth,
            margin: const EdgeInsets.only(right: 20),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(22),
                onTap: () => onCourseTap?.call(courseData),
                child: Ink(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: const Color(0xFFEDE9FE)),
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
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(22),
                        ),
                        child: Stack(
                          children: [
                            SizedBox(
                              height: 118,
                              width: double.infinity,
                              child:
                                  (courseData['image'] != null &&
                                      courseData['image'].toString().isNotEmpty)
                                  ? Image.network(
                                      imageUrlBuilder(
                                        courseData['image']?.toString(),
                                      ),
                                      fit: BoxFit.cover,
                                      errorBuilder: (context, error, stackTrace) {
                                        debugPrint(
                                          'Home image load error (${imageUrlBuilder(courseData['image']?.toString())}): $error',
                                        );
                                        return _buildCoursePlaceholder(
                                          courseData,
                                        );
                                      },
                                    )
                                  : _buildCoursePlaceholder(courseData),
                            ),
                            Positioned.fill(
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [
                                      Colors.black.withOpacity(0.0),
                                      Colors.black.withOpacity(0.35),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            const Positioned(
                              right: 10,
                              bottom: 10,
                              child: Icon(
                                Icons.play_circle_fill_rounded,
                                color: Colors.white,
                                size: 22,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (isFullyDownloaded || isPartiallyDownloaded)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 5),
                          color: isFullyDownloaded
                              ? Colors.deepPurple
                              : Colors.orange,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                isFullyDownloaded
                                    ? Icons.offline_pin_rounded
                                    : Icons.downloading_rounded,
                                size: 11,
                                color: Colors.white,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                isFullyDownloaded
                                    ? 'Downloaded'
                                    : 'Partially Downloaded',
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                courseData['title']?.toString() ??
                                    'Course Title',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 15,
                                  color: Color(0xFF111827),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const Spacer(),
                              Row(
                                children: [
                                  Expanded(
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(999),
                                      child: LinearProgressIndicator(
                                        value: progressValue / 100,
                                        minHeight: 8,
                                        backgroundColor: Colors.grey[200],
                                        valueColor:
                                            const AlwaysStoppedAnimation<Color>(
                                              Colors.deepPurple,
                                            ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Text(
                                    '${progressValue.toInt()}%',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.deepPurple,
                                    ),
                                  ),
                                ],
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
          );
        },
      ),
    );
  }
}
