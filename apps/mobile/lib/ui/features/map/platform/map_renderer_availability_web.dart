import 'dart:js_interop';
import 'dart:js_interop_unsafe';

/// On the web the maplibre-gl JS library must be loaded by the host page.
/// Without it the plugin never creates a map and throws when disposed, so the
/// map widget renders its overlays on a plain background instead.
bool get isMapRendererAvailable => globalContext.has('maplibregl');
