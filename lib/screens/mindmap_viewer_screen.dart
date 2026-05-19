import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

// ─── Data model ──────────────────────────────────────────────────────────────

class _MindNode {
  _MindNode({required this.name, required this.children, required this.depth});

  final String name;
  final List<_MindNode> children;
  final int depth;

  bool collapsed = false;

  /// Which horizontal side children are placed on: -1 = left, 1 = right.
  int side = 1;

  /// Centre position on the canvas, assigned during layout.
  Offset center = Offset.zero;

  /// 1-based order among the root's direct children (null for all other nodes).
  int? ordinal;
}

// ─── Layout constants ─────────────────────────────────────────────────────────

const double _kNodeW = 172.0; // fixed node width used for positioning
const double _kNodeH = 48.0; // spacing unit (approximate rendered height)
const double _kHGap = 48.0; // horizontal gap between node edges
const double _kVGap = 14.0; // vertical gap between siblings
const double _kCanvasW = 4800.0;
const double _kCanvasH = 4800.0;

const List<Color> _kColors = [
  Color(0xFF4F46E5),
  Color(0xFF0EA5E9),
  Color(0xFF10B981),
  Color(0xFFF59E0B),
  Color(0xFFEF4444),
  Color(0xFF8B5CF6),
];

Color _colorFor(int depth) => _kColors[depth % _kColors.length];

// ─── Screen ──────────────────────────────────────────────────────────────────

class MindmapViewerScreen extends StatefulWidget {
  const MindmapViewerScreen({
    super.key,
    required this.activityTitle,
    required this.mindmapData,
  });

  final String activityTitle;
  final Map<String, dynamic> mindmapData;

  @override
  State<MindmapViewerScreen> createState() => _MindmapViewerScreenState();
}

class _MindmapViewerScreenState extends State<MindmapViewerScreen> {
  late _MindNode _root;
  final TransformationController _tx = TransformationController();

  @override
  void initState() {
    super.initState();
    _root = _buildTree(widget.mindmapData, 0);
    _collapseDeep(_root, 0);
    WidgetsBinding.instance.addPostFrameCallback((_) => _fitView());
  }

  @override
  void dispose() {
    _tx.dispose();
    super.dispose();
  }

  // ── Tree construction ──────────────────────────────────────────────────────

  _MindNode _buildTree(Map<String, dynamic> data, int depth) {
    final children = (data['children'] as List<dynamic>? ?? [])
        .whereType<Map<String, dynamic>>()
        .map((c) => _buildTree(c, depth + 1))
        .toList();
    return _MindNode(
      name: data['name']?.toString() ?? '',
      children: children,
      depth: depth,
    );
  }

  /// Collapse every node at depth ≥ 1 on first render, mirroring markmap fold:1.
  void _collapseDeep(_MindNode node, int depth) {
    if (depth >= 1 && node.children.isNotEmpty) node.collapsed = true;
    for (final c in node.children) {
      _collapseDeep(c, depth + 1);
    }
  }

  // ── Layout ─────────────────────────────────────────────────────────────────

  /// Total vertical space (px) occupied by this subtree when visible.
  double _subtreeH(_MindNode node) {
    if (node.collapsed || node.children.isEmpty) return _kNodeH;
    final childH = node.children.fold(0.0, (s, c) => s + _subtreeH(c));
    return childH + (node.children.length - 1) * _kVGap;
  }

  void _layout() {
    _root.center = const Offset(_kCanvasW / 2, _kCanvasH / 2);
    if (_root.collapsed || _root.children.isEmpty) return;

    // Assign 1-based ordinals to all direct children in their original order.
    for (var i = 0; i < _root.children.length; i++) {
      _root.children[i].ordinal = i + 1;
    }

    // First ceil(n/2) → right, top-to-bottom.
    // Remaining → left, reversed so they read bottom-to-top from the root.
    final mid = (_root.children.length / 2).ceil();
    final rightChildren = _root.children.sublist(0, mid);
    final leftChildren = _root.children.sublist(mid).reversed.toList();
    _placeChildren(_root, rightChildren, side: 1);
    _placeChildren(_root, leftChildren, side: -1);
  }

  void _placeChildren(_MindNode parent, List<_MindNode> children, {required int side}) {
    if (children.isEmpty) return;
    final totalH =
        children.fold(0.0, (s, c) => s + _subtreeH(c)) + (children.length - 1) * _kVGap;
    double y = parent.center.dy - totalH / 2;
    final x = parent.center.dx + side * (_kNodeW / 2 + _kHGap + _kNodeW / 2);

    for (final child in children) {
      final h = _subtreeH(child);
      child.side = side;
      child.center = Offset(x, y + h / 2);
      _placeSubtree(child);
      y += h + _kVGap;
    }
  }

  void _placeSubtree(_MindNode node) {
    if (node.collapsed || node.children.isEmpty) return;
    final totalH = node.children.fold(0.0, (s, c) => s + _subtreeH(c)) +
        (node.children.length - 1) * _kVGap;
    double y = node.center.dy - totalH / 2;
    final x = node.center.dx + node.side * (_kNodeW / 2 + _kHGap + _kNodeW / 2);

    for (final child in node.children) {
      final h = _subtreeH(child);
      child.side = node.side;
      child.center = Offset(x, y + h / 2);
      _placeSubtree(child);
      y += h + _kVGap;
    }
  }

  // ── Collection ─────────────────────────────────────────────────────────────

  void _collectNodes(_MindNode node, List<_MindNode> out) {
    out.add(node);
    if (node.collapsed) return;
    for (final c in node.children) {
      _collectNodes(c, out);
    }
  }

  void _collectEdges(
    _MindNode node,
    List<({Offset from, Offset to, Color color})> out,
  ) {
    if (node.collapsed) return;
    for (final c in node.children) {
      // Connect from the horizontal edge of the parent to the horizontal edge
      // of the child, so lines don't overlap node content.
      final goRight = c.side >= 0;
      final fromX = node.center.dx + (goRight ? _kNodeW / 2 : -_kNodeW / 2);
      final toX = c.center.dx + (goRight ? -_kNodeW / 2 : _kNodeW / 2);
      out.add((
        from: Offset(fromX, node.center.dy),
        to: Offset(toX, c.center.dy),
        color: _colorFor(c.depth),
      ));
      _collectEdges(c, out);
    }
  }

  // ── Camera ─────────────────────────────────────────────────────────────────

  void _fitView() {
    final size = context.size;
    if (size == null) return;
    const scale = 0.52;
    final tx = size.width / 2 - _kCanvasW / 2 * scale;
    final ty = size.height / 2 - _kCanvasH / 2 * scale;
    _tx.value = Matrix4.diagonal3Values(scale, scale, 1)
      ..setTranslationRaw(tx, ty, 0);
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    _layout();

    final nodes = <_MindNode>[];
    _collectNodes(_root, nodes);

    final edges = <({Offset from, Offset to, Color color})>[];
    _collectEdges(_root, edges);

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.activityTitle,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const Text(
              'Tap a node to expand / collapse',
              style: TextStyle(fontSize: 11, color: Colors.grey),
            ),
          ],
        ),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.fit_screen_rounded),
            tooltip: 'Fit to screen',
            onPressed: _fitView,
          ),
        ],
      ),
      body: InteractiveViewer(
        constrained: false,
        transformationController: _tx,
        boundaryMargin: const EdgeInsets.all(400),
        minScale: 0.08,
        maxScale: 4.0,
        child: SizedBox(
          width: _kCanvasW,
          height: _kCanvasH,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // Edge layer — drawn first, sits behind nodes.
              CustomPaint(
                size: const Size(_kCanvasW, _kCanvasH),
                painter: _EdgePainter(edges),
              ),
              // Node layer
              for (final node in nodes)
                Positioned(
                  left: node.center.dx - _kNodeW / 2,
                  top: node.center.dy - _kNodeH / 2,
                  width: _kNodeW,
                  child: _NodeWidget(
                    node: node,
                    side: node.side,
                    onTap: node.children.isEmpty
                        ? null
                        : () => setState(() => node.collapsed = !node.collapsed),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Node widget ──────────────────────────────────────────────────────────────

class _NodeWidget extends StatelessWidget {
  const _NodeWidget({required this.node, required this.side, this.onTap});

  final _MindNode node;
  /// -1 = left branch, 1 = right branch, 1 = root (treated as right).
  final int side;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final color = _colorFor(node.depth);
    final isRoot = node.depth == 0;
    final isFirstLevel = node.depth == 1;
    final isLeft = side < 0;
    final hPad = isRoot ? 14.0 : 10.0;
    final vPad = isRoot ? 9.0 : 6.0;

    // Ordinal badge — pill shown on the inner (root-facing) edge of depth-1 nodes.
    final ordinalBadge = node.ordinal != null
        ? Padding(
            padding: EdgeInsets.only(
              left: isLeft ? 4 : 0,
              right: isLeft ? 0 : 4,
            ),
            child: Container(
              width: 20,
              height: 20,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: isRoot ? Colors.white.withValues(alpha: 0.2) : color,
                shape: BoxShape.circle,
              ),
              child: Text(
                '${node.ordinal}',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: isRoot ? Colors.white : Colors.white,
                  height: 1,
                ),
              ),
            ),
          )
        : null;

    final textWidget = Expanded(
      child: MarkdownBody(
        data: node.name,
        shrinkWrap: true,
        styleSheet: MarkdownStyleSheet(
          p: TextStyle(
            fontSize: isRoot ? 13 : 11.5,
            fontWeight: isRoot ? FontWeight.w700 : FontWeight.w500,
            color: isRoot ? Colors.white : color,
            height: 1.3,
          ),
          strong: TextStyle(
            fontWeight: FontWeight.w800,
            color: isRoot ? Colors.white : color,
          ),
          em: TextStyle(
            fontStyle: FontStyle.italic,
            color: isRoot ? Colors.white70 : color.withValues(alpha: 0.85),
          ),
          code: TextStyle(
            fontSize: 10.5,
            fontFamily: 'monospace',
            color: isRoot ? Colors.white : color,
            backgroundColor: color.withValues(alpha: isRoot ? 0.25 : 0.12),
          ),
          // Remove default paragraph margin
          blockSpacing: 0,
          pPadding: EdgeInsets.zero,
        ),
      ),
    );

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: _kNodeW,
        constraints: isFirstLevel
            ? const BoxConstraints(minWidth: _kNodeW, minHeight: 60.0)
            : null,
        alignment: isFirstLevel ? Alignment.center : null,
        padding: EdgeInsets.symmetric(horizontal: hPad, vertical: vPad),
        decoration: BoxDecoration(
          color: isRoot ? color : color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(isRoot ? 12 : 20),
          border: isRoot
              ? null
              : Border.all(color: color.withValues(alpha: 0.5), width: 1.5),
          boxShadow: isRoot
              ? [
                  BoxShadow(
                    color: color.withValues(alpha: 0.32),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.max,
          crossAxisAlignment: CrossAxisAlignment.center,
          // Right-branch: [ordinal?, text]  — ordinal on inner (left) edge
          // Left-branch:  [text, ordinal?]  — ordinal on inner (right) edge
          children: isLeft
              ? [textWidget, ?ordinalBadge]
              : [?ordinalBadge, textWidget],
        ),
      ),
    );
  }
}

// ─── Edge painter ─────────────────────────────────────────────────────────────

class _EdgePainter extends CustomPainter {
  const _EdgePainter(this.edges);

  final List<({Offset from, Offset to, Color color})> edges;

  @override
  void paint(Canvas canvas, Size size) {
    for (final e in edges) {
      final paint = Paint()
        ..color = e.color.withValues(alpha: 0.4)
        ..strokeWidth = 1.8
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;

      // Horizontal bezier: control points pull horizontally from each endpoint.
      final dx = (e.to.dx - e.from.dx).abs() * 0.5;
      final goRight = e.to.dx >= e.from.dx;
      final path = Path()
        ..moveTo(e.from.dx, e.from.dy)
        ..cubicTo(
          e.from.dx + (goRight ? dx : -dx),
          e.from.dy,
          e.to.dx + (goRight ? -dx : dx),
          e.to.dy,
          e.to.dx,
          e.to.dy,
        );
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(_EdgePainter old) => old.edges != edges;
}

