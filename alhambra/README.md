# CodexAgent v2 — AI Coding Assistant

A complete, production-quality Flutter coding agent inspired by OpenAI Codex/Claude Code.
Streaming chat, multi-file diffs, an in-app code editor, a command palette, prompt snippets,
and full session import/export — all built on `flutter_riverpod` with **no `build_runner`**.

---

## What's new in v2

| Area | Improvement |
|---|---|
| **Editing & regen** | Double-click any of your messages to edit & resend (auto-discards stale replies). Regenerate any assistant reply in place. |
| **Cancellation** | Stop button actually cancels the in-flight stream (was previously a no-op). |
| **Command palette** | `Ctrl/⌘+K` opens a fuzzy search over sessions, actions, and snippets — arrow keys + Enter to navigate. |
| **Prompt snippets** | Reusable prompts triggered with `/shortcut` while typing, with autocomplete suggestions. Manage them in Settings → Prompt snippets. |
| **Session tools** | Rename inline, duplicate, pin, export single/all sessions to JSON, import from JSON (clipboard or file), bulk delete. |
| **Token awareness** | Live context-window usage pill in the input bar (color-coded), with per-message token estimates. |
| **Multi-file diffs** | "Apply all" button when a response touches multiple files. |
| **Resizable layout** | Drag the divider between chat and editor/diff panel; collapsible sidebar (`Ctrl/⌘+\`). |
| **Mobile layout** | Editor/diff reachable via draggable bottom sheets instead of being hidden entirely on narrow screens. |
| **Error taxonomy** | API errors are classified (auth/rate-limit/server/validation) with actionable messages instead of raw HTTP text. |
| **Robustness fixes** | Stream parser no longer sends an empty assistant turn to the API; SSE buffer correctly carries over partial frames; file attachments fall back to latin1 if not valid UTF-8 instead of silently failing. |

---

## Feature overview

- **Sessions** — persistent, searchable, pinnable, renameable, duplicable; export/import as portable JSON.
- **Streaming chat** — SSE token-by-token, cancellable mid-stream, auto-generated titles.
- **File context** — attach multiple files; Claude sees full content; edit files directly or let Claude propose diffs.
- **Diff viewer** — Myers line diff, gutter line numbers, context collapsing, Apply/Reject, Apply-all for multi-file changes.
- **Code editor** — tabbed per-file editor, syntax highlighting, inline edit mode, one-click copy.
- **Command palette** — universal `⌘K` launcher for sessions, actions, and snippets.
- **Prompt snippets** — `/explain`, `/refactor`, `/tests`, `/bugs`, `/optimize`, `/docs` ship by default; fully editable.
- **Settings** — API key, model + context-window display, max tokens, streaming toggle, font size, system prompt, data management (export/import/delete-all).
- **Keyboard shortcuts** — `⌘N` new session, `⌘K` palette, `⌘\` toggle sidebar, double-click to edit a message.

---

## Architecture

```
lib/
├── core/
│   ├── constants/app_constants.dart     # Storage keys, model context windows, token heuristic
│   ├── errors/app_error.dart            # Sealed AppError: Network/Api/Storage/Parse/Validation
│   ├── theme/app_theme.dart             # Dark GitHub-style palette + Google Fonts
│   └── utils/
│       ├── diff_engine.dart             # Myers line diff + response code-block extraction
│       ├── extensions.dart              # DateTime/String extensions, generateId()
│       ├── language_detector.dart       # Extension → highlight.js language map
│       └── result.dart                  # Result<T> = Success<T> | Failure<T>
│
├── domain/entities/entities.dart        # Session, Message, FileDiff, PromptSnippet, AppSettings…
│
├── data/
│   ├── models/json_models.dart          # Hand-written JSON (no codegen) + export/import bundles
│   ├── datasources/
│   │   ├── local_storage_datasource.dart
│   │   ├── snippets_datasource.dart     # Ships default snippet set
│   │   └── claude_api_datasource.dart   # SSE streaming, sanitizes empty/placeholder turns
│   └── repositories/
│       ├── session_repository.dart      # + rename/duplicate/export/import/truncate
│       ├── settings_repository.dart
│       └── snippets_repository.dart
│
└── presentation/
    ├── providers/
    │   ├── infrastructure_providers.dart
    │   ├── settings_provider.dart
    │   ├── sessions_provider.dart       # + export/import/duplicate/rename
    │   ├── snippets_provider.dart       # + shortcut matching
    │   └── chat_provider.dart           # + cancel/edit/regenerate/token estimate
    ├── screens/
    │   ├── home_screen.dart             # Resizable split, shortcuts, mobile bottom sheets
    │   ├── settings_screen.dart         # + data management section
    │   └── snippets_screen.dart         # CRUD UI for prompt snippets
    └── widgets/
        ├── chat/                        # Bubbles (editable), input bar (snippet autocomplete)
        ├── command_palette/             # ⌘K overlay
        ├── diff/                        # Line-level diff viewer
        ├── editor/                      # Tabbed editor + copy button
        ├── session/                     # Sidebar: rename/duplicate/export/import
        └── shared/                      # Buttons, badges, resizable split, token pill, banners
```

### Key design decisions

- **No `build_runner`** — all JSON (de)serialization is hand-written extension methods.
- **`Result<T>`** railway pattern — every repository/datasource method returns `Success<T>` or `Failure<AppError>`; no exceptions cross layer boundaries.
- **Sealed classes** — `AppError` and `Result<T>` support exhaustive `switch` handling.
- **StateNotifier** — single source of truth per concern (chat, sessions, settings, snippets); widgets only read/call.
- **Truncate-and-resend** — editing a message or regenerating a reply works by truncating the message list and re-dispatching, so history stays linear and consistent with what's actually sent to the API.
- **Sanitized API payloads** — the datasource strips system-role entries and empty/in-flight placeholders before building the request, so a cancelled or just-created turn never corrupts the next API call.

---

## Setup

```bash
cd coding_agent
flutter pub get
flutter run
```

1. Open **Settings** (gear icon) → paste your [Anthropic API key](https://console.anthropic.com) → **Save API key**.
2. Start a new session (`⌘N`) and type your first message, or try a snippet like `/explain`.

---

## Extending

| Want to… | Touch this |
|---|---|
| Add a new provider (e.g. OpenAI) | Implement a class with the same `streamCompletion`/`complete` shape as `ClaudeApiDatasource`; swap the override in `infrastructure_providers.dart`. |
| Add a file language | `core/utils/language_detector.dart` — extend `_map`. |
| Add a default snippet | `data/datasources/snippets_datasource.dart` — extend `kDefaultSnippets`. |
| Change context-window sizes | `core/constants/app_constants.dart` — `modelContextWindows`. |
| Add a command-palette action | `presentation/widgets/command_palette/command_palette.dart` — extend the `actions` list in `_buildEntries`. |

---

## Packages

| Package | Purpose |
|---|---|
| `flutter_riverpod` | Reactive state management |
| `shared_preferences` | Persistent local storage |
| `http` | HTTP client (SSE streaming + REST) |
| `diff_match_patch` | Myers diff algorithm |
| `flutter_markdown` | Render Claude markdown responses |
| `flutter_highlight` | Syntax highlighting in editor & code blocks |
| `google_fonts` | Inter (UI) + JetBrains Mono (code) |
| `file_picker` | Attach/import files |
| `intl` | Date formatting |
| `equatable` | Value equality on entities |
| `collection` | Misc collection helpers |

No `build_runner`, `json_serializable`, `freezed`, or `riverpod_generator` — everything is hand-written for zero codegen friction.

---

## License

MIT
