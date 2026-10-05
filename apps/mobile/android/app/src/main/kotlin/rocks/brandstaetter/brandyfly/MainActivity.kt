package rocks.brandstaetter.brandyfly

import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import org.maplibre.android.MapLibre

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // All map sources (vector, terrain, KK7 thermals) are served by the
        // app's loopback tile server, which falls back to local data or a
        // transparent tile itself. Without this override MapLibre pauses every
        // tile request while Android reports no connectivity (airplane mode,
        // no reception), so even fully offline map data would not render.
        MapLibre.getInstance(applicationContext)
        MapLibre.setConnected(true)
    }
}
