# UI Mockup Options

This document outlines the proposed visual styles (mockups) for various UI components in BrandyFly.

### 1. Numeric/Text Widgets (Groundspeed, Altitude, Wind Speed, Height Above Ground, Glide Ratio)
*   **Option 1: Minimalist Text** - Large bold number, small unit and label below it, transparent background. Clean and simple.
*   **Option 2: High-Contrast Box** - Value and unit inside a semi-transparent dark/light box with a clear icon on the left. High readability in sunlight.
*   **Option 3: Circular Gauge** - A circular arc indicating relative min/max with the current value in the middle.
*   **Option 4: Retro Digital** - LCD-style segment font for numbers, mimicking classic hardware variometers.

### 2. Wind Direction Widget
*   **Option 1: Relative Arrow** - A simple, bold arrow pointing the wind direction relative to your current flight path.
*   **Option 2: Mini Compass Rose** - A small compass circle with your heading at the top and the wind vector highlighted.
*   **Option 3: Windsock Indicator** - A windsock icon that rotates and changes shape/color based on direction and strength.

### 3. Visual Lift/Sink Rate Bar (Vario)
*   **Option 1: Vertical Edge Bar** - Classic paragliding vario style. A tall vertical bar on the side of the screen; green grows upwards for lift, red downwards for sink.
*   **Option 2: Analog Dial** - A circular gauge with a needle sweeping right for lift and left for sink.
*   **Option 3: Screen Edge Glow** - The outer edges of the screen glow green or red (with varying intensity) depending on lift/sink, minimizing widget clutter.

### 4. Flight Height Line Chart
*   **Option 1: Minimal Sparkline** - A smooth, simple line showing the last 5 minutes of altitude, no gridlines or axes.
*   **Option 2: Filled Area Graph** - Gradient fill under the altitude line. If terrain data is available, shows terrain profile underneath.
*   **Option 3: Detailed Grid** - Includes faint grid lines, time markers, and tags for min/max altitude reached.

### 5. Base Map Widget
*   **Option 1: Full-Screen Backdrop** - The map covers the entire screen, with all other widgets floating transparently on top (HUD style).
*   **Option 2: Resizable Floating Panel** - The map is just another widget box that can be resized and moved around a solid or gradient background.
*   **Option 3: Split Layout** - Screen is distinctly split: map takes up a large portion (e.g., 70%), and instruments take up a dedicated opaque panel (30%).

### 6. Normal Flight Screen Layout Strategy
*   **Option 1: Freeform HUD** - Complete freedom. Widgets can be placed anywhere over the map, overlapping if desired.
*   **Option 2: Snap-to-Grid** - Widgets snap to an invisible grid over the map, ensuring neat alignment.
*   **Option 3: Sidebar Dashboard** - A dedicated instrument sidebar on the left or right, leaving the map completely unobstructed.

### 7. Thermaling Screen (Auto-transition)
*   **Option 1: Zoomed Radar** - Map automatically zooms in tight on your position, highlighting your thermal track, drift, and core estimate.
*   **Option 2: Focus Mode** - Non-essential widgets fade out. The vario bar, altitude, and wind info become prominent.
*   **Option 3: Assistant Display** - Displays a visual turn suggestion (e.g., "tighten turn") and highly visible average climb rate.

### 8. Navigation Bar (Swipe-to-reveal from top)
*   **Option 1: Full-Width Translucent Drawer** - Slides down from the top edge with large, easy-to-tap icons for Edit Mode, Settings, etc.
*   **Option 2: Floating Action Pill** - A compact, rounded pill that drops down in the top center, offering a modern, minimalistic look.
*   **Option 3: Corner Menu Button** - Swiping down reveals a compact menu anchored to the top-right corner, avoiding the center of the screen.

### 9. Settings Screen
*   **Option 1: Modal Overlay Dialog** - Settings pop up in a centered dialog box while the flight screen remains visible and blurred in the background.
*   **Option 2: Full-Screen Categorized List** - Traditional mobile settings menu (like iOS/Android system settings) categorized into rows.
*   **Option 3: Card-Based Dashboard** - Settings are grouped into large, distinct visual cards (e.g., "Sensors", "UI", "Account") that expand when tapped.
