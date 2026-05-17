import 'dart:async';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/api_service.dart';
import 'flashcards_player_screen.dart';
import 'mindmap_viewer_screen.dart';
import 'slides_player_screen.dart';
import 'video_viewer_screen.dart';

const _inactivityTimeout = Duration(minutes: 5);
const _syncInterval = Duration(seconds: 30);

class ActivityViewerScreen extends StatefulWidget {
  const ActivityViewerScreen({
    super.key,
    required this.courseId,
    required this.courseTitle,
    required this.activityId,
    this.initialActivity,
  });

  final String courseId;
  final String courseTitle;
  final String activityId;
  final Map<String, dynamic>? initialActivity;

  @override
  State<ActivityViewerScreen> createState() => _ActivityViewerScreenState();
}

class _ActivityViewerScreenState extends State<ActivityViewerScreen>
    with WidgetsBindingObserver {
  final _apiService = ApiService();

  bool _isLoading = true;
  bool _hasAppFocus = true;
  bool _isInactive = false;
  bool _isCompleting = false;
  bool _isSendingOtp = false;
  bool _isStartingAssessment = false;
  bool _isUploadingAssignment = false;

  Map<String, dynamic>? _detail;
  String? _status;
  int _timeSpent = 0;
  int _lastSyncedTimeSpent = 0;
  int _minimumSeconds = 0;

  DateTime _lastActivityAt = DateTime.now();

  Timer? _tickTimer;
  Timer? _syncTimer;
  Timer? _inactivityTimer;

  PlatformFile? _selectedAssignmentFile;
  String _assignmentNote = '';
  String _assessmentOtp = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadActivity();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _tickTimer?.cancel();
    _syncTimer?.cancel();
    _inactivityTimer?.cancel();
    unawaited(_flushProgress());
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final hasFocus = state == AppLifecycleState.resumed;

    if (mounted) {
      setState(() {
        _hasAppFocus = hasFocus;
      });
    }
  }

  Future<void> _loadActivity() async {
    final data = await _apiService.getStudentActivityDetail(
      courseId: widget.courseId,
      activityId: widget.activityId,
    );

    if (!mounted) return;

    if (data == null) {
      setState(() {
        _detail = null;
        _isLoading = false;
      });
      return;
    }

    final progress = data['progress'] as Map<String, dynamic>?;
    final minimumMinutes = (data['minimumArticleReadingTime'] ?? 0) as int;

    setState(() {
      _detail = data;
      _status = progress?['status']?.toString();
      _timeSpent = (progress?['time_spent'] ?? 0) as int;
      _lastSyncedTimeSpent = _timeSpent;
      _minimumSeconds = minimumMinutes * 60;
      _isLoading = false;
    });

    if (_status != 'COMPLETED') {
      final startResponse = await _apiService.startStudentActivityProgress(
        courseId: widget.courseId,
        activityId: widget.activityId,
      );

      if (mounted && startResponse != null) {
        final startedProgress = startResponse['progress'] as Map<String, dynamic>?;
        setState(() {
          _status = startedProgress?['status']?.toString() ?? _status;
          _timeSpent = (startedProgress?['time_spent'] ?? _timeSpent) as int;
          _lastSyncedTimeSpent = _timeSpent;
        });
      }
    }

    _startTimers();

    final activity = data['activity'] as Map<String, dynamic>?;
    if (activity?['type']?.toString() == 'ASSIGNMENT') {
      final submissions = await _apiService.getAssignmentSubmissions(
        courseId: widget.courseId,
        activityId: widget.activityId,
      );

      if (!mounted || submissions == null) {
        return;
      }

      setState(() {
        _detail = {
          ...?_detail,
          'assignment_submissions': submissions['submissions'] ?? [],
        };
      });
    }
  }

  void _startTimers() {
    _tickTimer?.cancel();
    _syncTimer?.cancel();
    _inactivityTimer?.cancel();

    _tickTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!_canTrackTime()) {
        return;
      }

      setState(() {
        _timeSpent += 1;
      });

      _handleAutoCompleteIfNeeded();
    });

    _syncTimer = Timer.periodic(_syncInterval, (_) {
      unawaited(_flushProgress());
    });

    _inactivityTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      final inactive = DateTime.now().difference(_lastActivityAt) >= _inactivityTimeout;
      if (inactive != _isInactive && mounted) {
        setState(() {
          _isInactive = inactive;
        });
      }
    });
  }

  bool _canTrackTime() {
    return _status != 'COMPLETED' && _hasAppFocus && !_isInactive;
  }

  Future<void> _flushProgress() async {
    if (_status == 'COMPLETED') {
      return;
    }

    if (_timeSpent == _lastSyncedTimeSpent) {
      return;
    }

    final response = await _apiService.updateStudentActivityProgress(
      courseId: widget.courseId,
      activityId: widget.activityId,
      timeSpent: _timeSpent,
    );

    if (!mounted || response == null) {
      return;
    }

    final progress = response['progress'] as Map<String, dynamic>?;
    setState(() {
      _status = progress?['status']?.toString() ?? _status;
      _timeSpent = (progress?['time_spent'] ?? _timeSpent) as int;
      _lastSyncedTimeSpent = _timeSpent;
    });
  }

  Future<void> _markComplete() async {
    if (_status == 'COMPLETED' || _isCompleting) {
      return;
    }

    setState(() {
      _isCompleting = true;
    });

    final response = await _apiService.completeStudentActivityProgress(
      courseId: widget.courseId,
      activityId: widget.activityId,
      timeSpent: _timeSpent,
    );

    if (!mounted) {
      return;
    }

    setState(() {
      _isCompleting = false;
      if (response != null) {
        final progress = response['progress'] as Map<String, dynamic>?;
        _status = progress?['status']?.toString() ?? _status;
        _timeSpent = (progress?['time_spent'] ?? _timeSpent) as int;
        _lastSyncedTimeSpent = _timeSpent;
      }
    });
  }

  void _handleAutoCompleteIfNeeded() {
    final activity = _detail?['activity'] as Map<String, dynamic>?;
    if (activity == null || _status == 'COMPLETED') {
      return;
    }

    final type = activity['type']?.toString();
    if (type == 'ARTICLE' && (_minimumSeconds == 0 || _timeSpent >= _minimumSeconds)) {
      unawaited(_markComplete());
    }
  }

  Future<void> _pickAssignmentFile() async {
    final result = await FilePicker.pickFiles(
      allowMultiple: false,
      withData: true,
    );

    if (!mounted || result == null || result.files.isEmpty) {
      return;
    }

    setState(() {
      _selectedAssignmentFile = result.files.first;
    });
  }

  Future<void> _submitAssignment() async {
    final file = _selectedAssignmentFile;
    if (file == null || file.bytes == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a file first.')),
      );
      return;
    }

    setState(() {
      _isUploadingAssignment = true;
    });

    final uploadMeta = await _apiService.getAssignmentUploadUrl(
      courseId: widget.courseId,
      activityId: widget.activityId,
      filename: file.name,
      size: file.size,
      type: file.extension,
    );

    if (uploadMeta == null) {
      if (!mounted) return;
      setState(() {
        _isUploadingAssignment = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to prepare upload.')),
      );
      return;
    }

    final uploaded = await _apiService.uploadFileToSignedUrl(
      uploadUrl: uploadMeta['upload_url']?.toString() ?? '',
      bytes: file.bytes!,
      contentType: 'application/octet-stream',
    );

    if (!uploaded) {
      if (!mounted) return;
      setState(() {
        _isUploadingAssignment = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('File upload failed.')),
      );
      return;
    }

    final submission = await _apiService.submitAssignment(
      courseId: widget.courseId,
      activityId: widget.activityId,
      fileUrl: uploadMeta['file_url']?.toString() ?? '',
      fileName: file.name,
      fileSize: file.size,
      fileType: file.extension,
      note: _assignmentNote.trim().isEmpty ? null : _assignmentNote.trim(),
    );

    if (!mounted) return;

    if (submission == null) {
      setState(() {
        _isUploadingAssignment = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to save assignment submission.')),
      );
      return;
    }

    final refreshed = await _apiService.getAssignmentSubmissions(
      courseId: widget.courseId,
      activityId: widget.activityId,
    );

    setState(() {
      _isUploadingAssignment = false;
      _selectedAssignmentFile = null;
      _assignmentNote = '';
      if (refreshed != null) {
        _detail = {
          ...?_detail,
          'assignment_submissions': refreshed['submissions'] ?? [],
        };
      }
    });

    await _markComplete();

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Assignment submitted successfully.')),
    );
  }

  Future<void> _sendOtp() async {
    setState(() {
      _isSendingOtp = true;
    });

    final response = await _apiService.sendAssessmentOtp(
      courseId: widget.courseId,
      activityId: widget.activityId,
    );

    if (!mounted) return;

    setState(() {
      _isSendingOtp = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          response?['message']?.toString() ??
              'Unable to send OTP right now.',
        ),
      ),
    );
  }

  Future<void> _startAssessment() async {
    setState(() {
      _isStartingAssessment = true;
    });

    final response = await _apiService.startAssessment(
      courseId: widget.courseId,
      activityId: widget.activityId,
      otp: _assessmentOtp.trim().isEmpty ? null : _assessmentOtp.trim(),
    );

    if (!mounted) return;

    setState(() {
      _isStartingAssessment = false;
    });

    final redirectTo = response?['redirect_to']?.toString();
    if (redirectTo == null || redirectTo.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to start assessment.')),
      );
      return;
    }

    await _openUrl(redirectTo);
  }

  Future<void> _openUrl(String? url) async {
    if (url == null || url.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No URL available for this activity.')),
      );
      return;
    }

    final uri = Uri.tryParse(url);
    if (uri == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid URL.')),
      );
      return;
    }

    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to open this link right now.')),
      );
    }
  }

  String _formatTime(int seconds) {
    if (seconds < 60) {
      return '${seconds}s';
    }

    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;

    if (minutes < 60) {
      return remainingSeconds > 0 ? '${minutes}m ${remainingSeconds}s' : '${minutes}m';
    }

    final hours = minutes ~/ 60;
    final remainingMinutes = minutes % 60;
    return remainingMinutes > 0 ? '${hours}h ${remainingMinutes}m' : '${hours}h';
  }

  bool _canManuallyComplete(String type) {
    if (_status == 'COMPLETED') {
      return false;
    }

    return type == 'FILE' ||
        type == 'EXTERNAL_LINK' ||
        type == 'ASSIGNMENT' ||
        type == 'ASSESSMENT';
  }

  Widget _buildContentCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color tint,
    required List<Widget> children,
  }) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
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
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: tint.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: tint, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: Colors.grey[700],
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        ...children,
      ],
    );
  }

  Widget _buildActivityBody() {
    final activity = _detail?['activity'] as Map<String, dynamic>?;
    if (activity == null) {
      return const Center(child: Text('Activity not found.'));
    }

    final type = activity['type']?.toString() ?? 'ARTICLE';
    final title = activity['title']?.toString() ?? 'Activity';
    final description = activity['description']?.toString();
    final url = activity['url']?.toString();

    switch (type) {
      case 'VIDEO':
        return _buildContentCard(
          title: title,
          subtitle: 'Video • ${widget.courseTitle}',
          icon: Icons.play_circle_fill_rounded,
          tint: const Color(0xFF0EA5E9),
          children: [
            _buildTextPanel(
              description?.isNotEmpty == true
                  ? description!
                  : 'Tap below to open this video using your device browser/player.',
            ),
            const SizedBox(height: 12),
            _buildOpenLinkButton(url, 'Play Video'),
          ],
        );
      case 'FILE':
        return _buildContentCard(
          title: title,
          subtitle: 'File • ${widget.courseTitle}',
          icon: Icons.attach_file_rounded,
          tint: const Color(0xFF10B981),
          children: [
            _buildTextPanel(
              description?.isNotEmpty == true
                  ? description!
                  : 'Open this file from the link below.',
            ),
            const SizedBox(height: 12),
            _buildOpenLinkButton(url, 'Open File'),
          ],
        );
      case 'EXTERNAL_LINK':
        return _buildContentCard(
          title: title,
          subtitle: 'External Link • ${widget.courseTitle}',
          icon: Icons.link_rounded,
          tint: const Color(0xFFF59E0B),
          children: [
            _buildTextPanel(
              description?.isNotEmpty == true
                  ? description!
                  : 'Open the external resource from the link below.',
            ),
            const SizedBox(height: 12),
            _buildOpenLinkButton(url, 'Open Link'),
          ],
        );
      case 'ASSESSMENT':
        final questions = (_detail?['questions'] as List<dynamic>? ?? []);
        final submissions = (_detail?['submissions'] as List<dynamic>? ?? []);
        final requiresOtp = activity['assessment_require_otp'] == true;

        return _buildContentCard(
          title: title,
          subtitle: 'Assessment • ${widget.courseTitle}',
          icon: Icons.quiz_rounded,
          tint: const Color(0xFFEF4444),
          children: [
            _buildInfoGrid([
              ('Questions', questions.length.toString(), Icons.help_outline_rounded),
              ('Attempts', submissions.length.toString(), Icons.refresh_rounded),
            ]),
            const SizedBox(height: 12),
            _buildTextPanel(
              description?.isNotEmpty == true
                  ? description!
                  : 'Assessment details are available. Use OTP (if required) then launch assessment.',
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.withOpacity(0.16)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (requiresOtp) ...[
                    TextField(
                      decoration: const InputDecoration(
                        labelText: 'OTP Code',
                        hintText: 'Enter 6-digit OTP',
                      ),
                      keyboardType: TextInputType.number,
                      onChanged: (value) {
                        _assessmentOtp = value;
                      },
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _isSendingOtp ? null : _sendOtp,
                        icon: _isSendingOtp
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.email_outlined),
                        label: const Text('Send OTP'),
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _isStartingAssessment ? null : _startAssessment,
                      icon: _isStartingAssessment
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.play_arrow_rounded),
                      label: const Text('Start Assessment'),
                    ),
                  ),
                ],
              ),
            ),
            if (url?.isNotEmpty == true) ...[
              const SizedBox(height: 12),
              _buildOpenLinkButton(url, 'Open Assessment Link'),
            ],
          ],
        );
      case 'ASSIGNMENT':
        final assignmentSubmissions =
            (_detail?['assignment_submissions'] as List<dynamic>? ?? []);

        return _buildContentCard(
          title: title,
          subtitle: 'Assignment • ${widget.courseTitle}',
          icon: Icons.assignment_rounded,
          tint: const Color(0xFF8B5CF6),
          children: [
            _buildInfoGrid([
              ('Submissions', assignmentSubmissions.length.toString(), Icons.upload_file_rounded),
            ]),
            const SizedBox(height: 12),
            _buildTextPanel(
              description?.isNotEmpty == true
                  ? description!
                  : 'Upload your assignment file and submit it here.',
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.withOpacity(0.16)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  OutlinedButton.icon(
                    onPressed: _isUploadingAssignment ? null : _pickAssignmentFile,
                    icon: const Icon(Icons.attach_file_rounded),
                    label: Text(
                      _selectedAssignmentFile == null
                          ? 'Select file'
                          : _selectedAssignmentFile!.name,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    minLines: 2,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      labelText: 'Note (optional)',
                      hintText: 'Add a note for your instructor',
                    ),
                    onChanged: (value) {
                      _assignmentNote = value;
                    },
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _isUploadingAssignment ? null : _submitAssignment,
                      icon: _isUploadingAssignment
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.upload_rounded),
                      label: const Text('Submit Assignment'),
                    ),
                  ),
                ],
              ),
            ),
            if (assignmentSubmissions.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey.withOpacity(0.16)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Previous submissions',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 8),
                    ...assignmentSubmissions.map((submission) {
                      final fileUrl = submission['file_url']?.toString();
                      final fileName = submission['file_name']?.toString() ?? 'File';

                      return ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        title: Text(fileName),
                        subtitle: Text(
                          submission['submitted_at']?.toString() ?? '',
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.open_in_new_rounded),
                          onPressed: () => _openUrl(fileUrl),
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ],
          ],
        );
      case 'ARTICLE':
      default:
        final articleContent = activity['content']?.toString();
        final slides = (activity['slides'] as List<dynamic>? ?? [])
            .whereType<Map<String, dynamic>>()
            .toList();
        final flashcards = (activity['ai_flashcards'] as List<dynamic>? ?? [])
            .whereType<Map<String, dynamic>>()
            .where(
              (f) =>
                  f['question']?.toString().trim().isNotEmpty == true &&
                  f['answer']?.toString().trim().isNotEmpty == true,
            )
            .toList();
        final mindmapRaw = activity['mindmap'];
        final mindmap = mindmapRaw is Map<String, dynamic> &&
                mindmapRaw['name'] != null
            ? mindmapRaw
            : null;
        final videoUrl = activity['url']?.toString();
        final hasVideo = videoUrl != null && videoUrl.isNotEmpty;

        return _buildContentCard(
          title: title,
          subtitle: 'Article • ${widget.courseTitle}',
          icon: Icons.article_rounded,
          tint: const Color(0xFF4F46E5),
          children: [
            if (flashcards.isNotEmpty || hasVideo || mindmap != null || slides.isNotEmpty)
              _buildArticleSupplementsRow(
                flashcards: flashcards,
                videoUrl: hasVideo ? videoUrl : null,
                mindmap: mindmap,
                slides: slides,
                activityTitle: title,
              ),
            if (flashcards.isNotEmpty || hasVideo || mindmap != null || slides.isNotEmpty)
              const SizedBox(height: 12),
            _buildArticleMarkdownPanel(
              articleContent: articleContent,
              fallbackDescription: description,
            ),
            if (url?.isNotEmpty == true) ...[
              const SizedBox(height: 12),
              _buildOpenLinkButton(url, 'Open Article Source'),
            ],
          ],
        );
    }
  }

  Widget _buildArticleSupplementsRow({
    required List<Map<String, dynamic>> flashcards,
    required String? videoUrl,
    required Map<String, dynamic>? mindmap,
    required List<Map<String, dynamic>> slides,
    required String activityTitle,
  }) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        if (flashcards.isNotEmpty)
          OutlinedButton.icon(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => FlashcardsPlayerScreen(
                  activityTitle: activityTitle,
                  flashcards: flashcards,
                ),
              ),
            ),
            icon: const Icon(Icons.style_rounded, size: 16),
            label: Text('Flashcards (${flashcards.length})'),
          ),
        if (videoUrl != null)
          OutlinedButton.icon(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => VideoViewerScreen(
                  activityTitle: activityTitle,
                  videoUrl: videoUrl,
                ),
              ),
            ),
            icon: const Icon(Icons.play_circle_outline_rounded, size: 16),
            label: const Text('Explainer Video'),
          ),
        if (mindmap != null)
          OutlinedButton.icon(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => MindmapViewerScreen(
                  activityTitle: activityTitle,
                  mindmapData: mindmap,
                ),
              ),
            ),
            icon: const Icon(Icons.account_tree_outlined, size: 16),
            label: const Text('Mindmap'),
          ),
        if (slides.isNotEmpty)
          OutlinedButton.icon(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => SlidesPlayerScreen(
                  activityTitle: activityTitle,
                  slides: slides,
                ),
              ),
            ),
            icon: const Icon(Icons.view_carousel_outlined, size: 16),
            label: Text('Slides (${slides.length})'),
          ),
      ],
    );
  }

  Widget _buildArticleMarkdownPanel({
    required String? articleContent,
    required String? fallbackDescription,
  }) {
    final markdown = articleContent?.trim().isNotEmpty == true
        ? articleContent!.trim()
        : fallbackDescription?.trim().isNotEmpty == true
        ? fallbackDescription!.trim()
        : 'No article body is currently available in this API response.';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.withOpacity(0.16)),
      ),
      child: MarkdownBody(
        data: markdown,
        selectable: true,
        onTapLink: (text, href, title) {
          if (href != null && href.isNotEmpty) {
            _openUrl(href);
          }
        },
        styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
          p: TextStyle(fontSize: 14, color: Colors.grey[800], height: 1.45),
        ),
      ),
    );
  }

  Widget _buildTextPanel(String text) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.withOpacity(0.16)),
      ),
      child: Text(
        text,
        style: TextStyle(fontSize: 14, color: Colors.grey[800], height: 1.4),
      ),
    );
  }

  Widget _buildInfoGrid(List<(String, String, IconData)> items) {
    return Row(
      children: items
          .map(
            (item) => Expanded(
              child: Container(
                margin: EdgeInsets.only(right: item == items.last ? 0 : 10),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.grey.withOpacity(0.16)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(item.$3, size: 16, color: Colors.deepPurple),
                    const SizedBox(height: 8),
                    Text(
                      item.$2,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      item.$1,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[700],
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          )
          .toList(),
    );
  }

  Widget _buildOpenLinkButton(String? url, String label) {
    return SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        onPressed: () => _openUrl(url),
        icon: const Icon(Icons.open_in_new_rounded),
        label: Text(label),
      ),
    );
  }

  void _recordInteraction() {
    _lastActivityAt = DateTime.now();
    if (_isInactive && mounted) {
      setState(() {
        _isInactive = false;
      });
    }
  }

  void _navigateNext() {
    final nextActivity = _detail?['nextActivity'] as Map<String, dynamic>?;
    if (nextActivity == null || (nextActivity['id']?.toString().isEmpty ?? true)) {
      Navigator.of(context).pop();
      return;
    }

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => ActivityViewerScreen(
          courseId: widget.courseId,
          courseTitle: widget.courseTitle,
          activityId: nextActivity['id'].toString(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final activity = _detail?['activity'] as Map<String, dynamic>?;
    final activityType = activity?['type']?.toString() ?? 'ARTICLE';
    final activityTitle =
        activity?['title']?.toString() ?? widget.initialActivity?['title']?.toString() ?? 'Activity';

    final minimumRemaining = (_minimumSeconds - _timeSpent).clamp(0, _minimumSeconds);
    final showPauseOverlay = _status != 'COMPLETED' && (_isInactive || !_hasAppFocus);

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: _recordInteraction,
      onPanDown: (_) => _recordInteraction(),
      child: Scaffold(
        backgroundColor: Colors.grey[50],
        appBar: AppBar(title: Text(activityTitle)),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _detail == null
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.cloud_off_rounded, size: 42, color: Colors.grey),
                      const SizedBox(height: 8),
                      const Text(
                        'Unable to load activity',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 8),
                      FilledButton(
                        onPressed: () {
                          setState(() {
                            _isLoading = true;
                          });
                          _loadActivity();
                        },
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              )
            : Stack(
                children: [
                  Column(
                    children: [
                      Expanded(
                        child: Opacity(
                          opacity: showPauseOverlay ? 0.3 : 1,
                          child: IgnorePointer(
                            ignoring: showPauseOverlay,
                            child: _buildActivityBody(),
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.fromLTRB(12, 10, 12, 14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          border: Border(
                            top: BorderSide(color: Colors.grey.withOpacity(0.2)),
                          ),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: _status == 'COMPLETED'
                                  ? Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 8,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.green.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(999),
                                      ),
                                      child: const Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.check_circle_rounded,
                                            size: 16,
                                            color: Colors.green,
                                          ),
                                          SizedBox(width: 6),
                                          Text(
                                            'Completed',
                                            style: TextStyle(
                                              fontWeight: FontWeight.w700,
                                              color: Colors.green,
                                            ),
                                          ),
                                        ],
                                      ),
                                    )
                                  : Text(
                                      activityType == 'ARTICLE' && _minimumSeconds > 0
                                          ? '${_formatTime(minimumRemaining)} remaining'
                                          : 'Time spent: ${_formatTime(_timeSpent)}',
                                      style: TextStyle(
                                        color: Colors.grey[800],
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                            ),
                            const SizedBox(width: 10),
                            if (_canManuallyComplete(activityType))
                              OutlinedButton(
                                onPressed: _isCompleting ? null : _markComplete,
                                child: _isCompleting
                                    ? const SizedBox(
                                        width: 14,
                                        height: 14,
                                        child: CircularProgressIndicator(strokeWidth: 2),
                                      )
                                    : const Text('Mark Complete'),
                              ),
                            const SizedBox(width: 8),
                            FilledButton.icon(
                              onPressed: _status == 'COMPLETED' ? _navigateNext : null,
                              icon: const Icon(Icons.arrow_forward_rounded),
                              label: const Text('Next'),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (showPauseOverlay)
                    Positioned.fill(
                      child: Container(
                        color: Colors.white.withOpacity(0.9),
                        child: Center(
                          child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.pause_circle_outline_rounded,
                                  size: 42,
                                  color: Colors.grey,
                                ),
                                const SizedBox(height: 10),
                                const Text(
                                  'Timer Paused',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 18,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  _isInactive
                                      ? 'You have been inactive. Interact with the screen to continue.'
                                      : 'Return to the app to continue tracking progress.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: Colors.grey[700]),
                                ),
                                const SizedBox(height: 12),
                                FilledButton(
                                  onPressed: () {
                                    _recordInteraction();
                                  },
                                  child: const Text('Resume'),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
      ),
    );
  }
}
