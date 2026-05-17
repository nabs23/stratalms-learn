# Article Activity — Supplementary Features Integration Plan

Mirrors the web `_student-article-view.tsx` which exposes four supplementary features for
ARTICLE activities. All data is already returned by the existing API endpoint
`GET /api/student/courses/{course}/activities/{activity}` — **no backend changes needed**.

## API data available

| Feature | Source field | Notes |
|---|---|---|
| Flashcards | `activity.ai_flashcards` — `[{question, answer}]` | Filtered for non-empty pairs |
| Explainer video | `activity.url` | YouTube, Mux, or generic external |
| Mindmap | `activity.mindmap` — `{name, children: [...]}` JSON tree | Nullable |
| Slides | `activity.slides` — typed array, sorted by `order` | Already returned for ARTICLE |

## New files

### `lib/screens/flashcards_player_screen.dart`
- Fullscreen `Scaffold`
- Flip card animation: `AnimatedSwitcher` + `Transform.rotateY` on tap
- Prev / next navigation with slide transition
- Header: `index + 1 / total`; footer: Prev, Reveal Answer, Next

### `lib/screens/slides_player_screen.dart`
- Fullscreen `Scaffold`, slides sorted by `order`
- Slide types: `TITLE_CARD`, `TEXT_AND_IMAGE`, `MULTIPLE_CHOICE_QUIZ`, `SUMMARY`
- Shows `image_url` (network image) + text fields per type
- Bottom "X / N" indicator with prev/next chevron buttons
- `MULTIPLE_CHOICE_QUIZ`: tap option to reveal correct answer

### `lib/screens/video_viewer_screen.dart`
- Fullscreen `Scaffold`
- Detects URL: YouTube → embedded `WebViewWidget`; otherwise `launchUrl` externally
- Uses `webview_flutter` package

### `lib/screens/mindmap_viewer_screen.dart`
- Fullscreen `Scaffold`
- Parses `{name, children}` JSON tree recursively
- Renders via `InteractiveViewer` + recursive `CustomPaint` or `Column`/`Row` widget tree
- No additional package required — uses Flutter-native widgets

## Changes to `activity_viewer_screen.dart`

In `_buildActivityBody()` ARTICLE case, add a button row above the markdown content:

```
[ 🃏 Flashcards (N) ]  [ ▶ Video ]  [ 🌐 Mindmap ]  [ 🖼 Slides (N) ]
```

Each button navigates (push) to the corresponding new screen.
Buttons are shown conditionally — only when data exists.

## `pubspec.yaml` additions

```yaml
webview_flutter: ^4.11.0   # YouTube embed in VideoViewerScreen
```

## Implementation order

1. ✅ Plan saved (this file)
2. `flashcards_player_screen.dart` — simplest, pure Flutter, no deps
3. `slides_player_screen.dart` — images + text, network images
4. `video_viewer_screen.dart` — URL detection + webview
5. `mindmap_viewer_screen.dart` — recursive tree rendering
6. Wire button row into `activity_viewer_screen.dart`
