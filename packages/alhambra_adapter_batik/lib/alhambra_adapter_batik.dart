/// Alhambra adapter for Batik — bridges Alhambra A2UI and Batik's
/// agent-driven UI generation framework.
///
/// ## Architecture
///
/// ```
/// Andalus / any LLM
///      ↓  (AndalusAdapter / OpenAIAdapter / AnthropicAdapter)
///   Batik AgentUIResponse
///      ↓  (BatikToA2UiConverter)
///   Alhambra UiSurface
///      ↓  (UiSurfaceView + A2UiActionGuard)
///   Flutter widgets
/// ```
///
/// Or in the other direction (Alhambra → Batik renderer):
///
/// ```
/// Alhambra UiSurface
///      ↓  (A2UiToBatikConverter)
///   Batik AgentUIResponse
///      ↓  (Batik renderer)
///   Flutter widgets
/// ```
library;

export 'src/a2ui_to_batik_converter.dart';
export 'src/batik_to_a2ui_converter.dart';
export 'src/alhambra_action_handler.dart';
export 'src/batik_surface_view.dart';
export 'src/andalus_adapter.dart';
