import 'package:flutter/material.dart';
import 'activity_viewer_screen.dart';
import '../repositories/course_repository.dart';

class CourseContentScreen extends StatefulWidget {
  const CourseContentScreen({
    super.key,
    required this.courseId,
    required this.courseTitle,
  });

  final String courseId;
  final String courseTitle;

  @override
  State<CourseContentScreen> createState() => _CourseContentScreenState();
}

class _CourseContentScreenState extends State<CourseContentScreen> {
  final _courseRepo = CourseRepository();
  bool _isLoading = true;
  Map<String, dynamic>? _tree;

  int _orderValue(Map<String, dynamic> item) {
    final parsed = int.tryParse(item['order']?.toString() ?? '');
    return parsed ?? 0;
  }

  bool _isCompletedStatus(Map<String, dynamic> activity) {
    return activity['progress']?['status']?.toString() == 'COMPLETED';
  }

  List<Map<String, dynamic>> _sortedActivities(List<Map<String, dynamic>> source) {
    final items = [...source];
    items.sort((a, b) => _orderValue(a).compareTo(_orderValue(b)));
    return items;
  }

  List<Map<String, dynamic>> _collectOrderedSectionActivities(
    List<Map<String, dynamic>> sections,
  ) {
    final sortedSections = [...sections]
      ..sort((a, b) => _orderValue(a).compareTo(_orderValue(b)));

    final ordered = <Map<String, dynamic>>[];

    for (final section in sortedSections) {
      final activities = _sortedActivities(
        (section['activities'] as List<dynamic>? ?? [])
            .cast<Map<String, dynamic>>(),
      );
      ordered.addAll(activities);

      final children = (section['children'] as List<dynamic>? ?? [])
          .cast<Map<String, dynamic>>();

      if (children.isNotEmpty) {
        ordered.addAll(_collectOrderedSectionActivities(children));
      }
    }

    return ordered;
  }

  Map<String, bool> _buildActivityUnlockMap({
    required List<Map<String, dynamic>> units,
    required List<Map<String, dynamic>> sections,
  }) {
    final orderedActivities = <Map<String, dynamic>>[];

    if (units.isNotEmpty) {
      final sortedUnits = [...units]
        ..sort((a, b) => _orderValue(a).compareTo(_orderValue(b)));

      for (final unit in sortedUnits) {
        final unitActivities = _sortedActivities(
          (unit['activities'] as List<dynamic>? ?? [])
              .cast<Map<String, dynamic>>(),
        );
        orderedActivities.addAll(unitActivities);
      }
    } else {
      orderedActivities.addAll(_collectOrderedSectionActivities(sections));
    }

    final unlockMap = <String, bool>{};
    var previousCompleted = true;

    for (final activity in orderedActivities) {
      final activityId = activity['id']?.toString();
      if (activityId == null || activityId.isEmpty) {
        continue;
      }

      unlockMap[activityId] = previousCompleted;
      previousCompleted = _isCompletedStatus(activity);
    }

    return unlockMap;
  }

  Map<String, bool> _buildUnitUnlockMap(List<Map<String, dynamic>> units) {
    final unlockMap = <String, bool>{};
    final sortedUnits = [...units]
      ..sort((a, b) => _orderValue(a).compareTo(_orderValue(b)));

    var previousUnitsCompleted = true;

    for (final unit in sortedUnits) {
      final unitId = unit['id']?.toString();
      if (unitId == null || unitId.isEmpty) {
        continue;
      }

      unlockMap[unitId] = previousUnitsCompleted;

      final activities = _sortedActivities(
        (unit['activities'] as List<dynamic>? ?? [])
            .cast<Map<String, dynamic>>(),
      );

      final unitCompleted = activities.isEmpty
          ? true
          : activities.every(_isCompletedStatus);

      previousUnitsCompleted = previousUnitsCompleted && unitCompleted;
    }

    return unlockMap;
  }

  @override
  void initState() {
    super.initState();
    _loadTree();
  }

  Future<void> _loadTree() async {
    final data = await _courseRepo.getStudentCourseTree(widget.courseId);

    if (!mounted) return;

    setState(() {
      _tree = data;
      _isLoading = false;
    });
  }

  IconData _activityIcon(String? type) {
    switch (type) {
      case 'VIDEO':
        return Icons.play_circle_fill_rounded;
      case 'ASSESSMENT':
        return Icons.quiz_rounded;
      case 'FILE':
        return Icons.attach_file_rounded;
      case 'EXTERNAL_LINK':
        return Icons.link_rounded;
      case 'ARTICLE':
      default:
        return Icons.article_rounded;
    }
  }

  Color _progressColor(String? status) {
    switch (status) {
      case 'COMPLETED':
        return Colors.green;
      case 'IN_PROGRESS':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  Widget _buildActivityTile(
    Map<String, dynamic> activity, {
    required bool isUnlocked,
  }) {
    final status = activity['progress']?['status']?.toString();

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isUnlocked ? Colors.white : Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isUnlocked
              ? Colors.grey.withOpacity(0.14)
              : Colors.grey.withOpacity(0.22),
        ),
      ),
      child: ListTile(
        onTap: () {
          if (!isUnlocked) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Complete the previous activity first to unlock this one.',
                ),
              ),
            );
            return;
          }

          final activityId = activity['id']?.toString();
          if (activityId == null || activityId.isEmpty) {
            return;
          }

          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => ActivityViewerScreen(
                courseId: widget.courseId,
                courseTitle: widget.courseTitle,
                activityId: activityId,
                initialActivity: activity,
              ),
            ),
          );
        },
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        leading: Icon(
          isUnlocked
              ? _activityIcon(activity['type']?.toString())
              : Icons.lock_outline_rounded,
          color: isUnlocked ? Colors.deepPurple : Colors.grey[600],
        ),
        title: Text(
          activity['title']?.toString() ?? 'Activity',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 14,
            color: isUnlocked ? Colors.black87 : Colors.grey[700],
          ),
        ),
        subtitle: activity['description']?.toString().isNotEmpty == true
            ? Text(
                activity['description'].toString(),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: isUnlocked ? Colors.grey[700] : Colors.grey[500],
                ),
              )
            : !isUnlocked
            ? const Text(
                'Locked until previous activity is completed',
                style: TextStyle(fontSize: 12),
              )
            : null,
        trailing: SizedBox(
          width: 48,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                !isUnlocked
                    ? Icons.lock_rounded
                    : status == 'COMPLETED'
                    ? Icons.check_circle_rounded
                    : status == 'IN_PROGRESS'
                    ? Icons.timelapse_rounded
                    : Icons.radio_button_unchecked_rounded,
                size: 16,
                color: !isUnlocked ? Colors.grey : _progressColor(status),
              ),
              Text(
                !isUnlocked
                    ? 'Lock'
                    : status == 'COMPLETED'
                    ? 'Done'
                    : status == 'IN_PROGRESS'
                    ? 'Ongoing'
                    : 'Todo',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 9,
                  height: 1,
                  fontWeight: FontWeight.w700,
                  color: !isUnlocked ? Colors.grey : _progressColor(status),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionNode(
    Map<String, dynamic> section,
    Map<String, bool> activityUnlockById, {
    int depth = 0,
  }) {
    final activities = _sortedActivities(
      (section['activities'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>(),
    );
    final children = (section['children'] as List<dynamic>? ?? [])
        .cast<Map<String, dynamic>>();

    return Container(
      margin: EdgeInsets.only(left: depth * 12.0, bottom: 10),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.withOpacity(0.16)),
      ),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
        childrenPadding: const EdgeInsets.fromLTRB(10, 0, 10, 8),
        shape: const Border(),
        title: Text(
          section['name']?.toString() ?? 'Section',
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
        ),
        subtitle: Text(
          '${activities.length} activities',
          style: TextStyle(fontSize: 12, color: Colors.grey[700]),
        ),
        children: [
          for (final activity in activities)
            _buildActivityTile(
              activity,
              isUnlocked: activityUnlockById[activity['id']?.toString() ?? ''] ??
                  true,
            ),
          for (final child in children)
            _buildSectionNode(
              child,
              activityUnlockById,
              depth: depth + 1,
            ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_tree == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off_rounded, size: 42, color: Colors.grey),
              const SizedBox(height: 10),
              const Text(
                'Unable to load course content',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              Text(
                'Pull down to retry.',
                style: TextStyle(fontSize: 12, color: Colors.grey[700]),
              ),
            ],
          ),
        ),
      );
    }

    final units = (_tree!['units'] as List<dynamic>? ?? [])
        .cast<Map<String, dynamic>>();
    final sections = (_tree!['sections'] as List<dynamic>? ?? [])
        .cast<Map<String, dynamic>>();
    final activityUnlockById = _buildActivityUnlockMap(
      units: units,
      sections: sections,
    );
    final unitUnlockById = _buildUnitUnlockMap(units);

    if (units.isEmpty && sections.isEmpty) {
      return Center(
        child: Text(
          'No content is currently available for this course.',
          style: TextStyle(color: Colors.grey[700]),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (units.isNotEmpty)
          ...units.map((unit) {
            final activities = _sortedActivities(
              (unit['activities'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>(),
            );
            final unitId = unit['id']?.toString() ?? '';
            final isUnitUnlocked = unitUnlockById[unitId] ?? true;

            if (!isUnitUnlocked) {
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.grey.withOpacity(0.22)),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.lock_outline_rounded,
                      size: 18,
                      color: Colors.grey,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            unit['title']?.toString() ?? 'Unit',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: Colors.grey[700],
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Locked until previous unit is completed',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      '${activities.length}',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              );
            }

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.grey.withOpacity(0.16)),
              ),
              child: ExpansionTile(
                tilePadding: const EdgeInsets.symmetric(horizontal: 12),
                childrenPadding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
                shape: const Border(),
                title: Text(
                  unit['title']?.toString() ?? 'Unit',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                subtitle: Text(
                  '${activities.length} activities',
                  style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                ),
                children: [
                  for (final activity in activities)
                    _buildActivityTile(
                      activity,
                      isUnlocked:
                          activityUnlockById[activity['id']?.toString() ?? ''] ??
                              true,
                    ),
                ],
              ),
            );
          }),
        if (sections.isNotEmpty)
          ...sections.map(
            (section) => _buildSectionNode(section, activityUnlockById),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.courseTitle)),
      backgroundColor: Colors.grey[50],
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(onRefresh: _loadTree, child: _buildBody()),
    );
  }
}
