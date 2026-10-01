// Whether a native/JS MapLibre renderer is available on this platform.
export 'map_renderer_availability_stub.dart'
    if (dart.library.js_interop) 'map_renderer_availability_web.dart';
