import 'dart:ui';
import 'package:flutter/material.dart';
import '../../models/ui_config.dart';
import '../../services/screen_manager_service.dart';

class TopNavBarOverlay extends StatefulWidget {
  const TopNavBarOverlay({
    super.key,
    required this.screenManager,
    required this.child,
  });

  final ScreenManagerService screenManager;
  final Widget child;

  @override
  State<TopNavBarOverlay> createState() => _TopNavBarOverlayState();
}

class _TopNavBarOverlayState extends State<TopNavBarOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
      value: widget.screenManager.isNavBarVisible ? 1.0 : 0.0,
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, -1.2),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));

    widget.screenManager.addListener(_onScreenManagerChange);
  }

  @override
  void dispose() {
    widget.screenManager.removeListener(_onScreenManagerChange);
    _controller.dispose();
    super.dispose();
  }

  void _onScreenManagerChange() {
    if (!mounted) return;
    setState(() {});
    if (widget.screenManager.isNavBarVisible) {
      _controller.forward();
    } else {
      _controller.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    final style = widget.screenManager.config.navBarStyle;

    return GestureDetector(
      onVerticalDragUpdate: (details) {
        // Detect swipe down from top edge (primary delta > 8)
        if (details.primaryDelta != null &&
            details.primaryDelta! > 8 &&
            details.globalPosition.dy < 120 &&
            !widget.screenManager.isNavBarVisible &&
            !widget.screenManager.isEditMode) {
          widget.screenManager.toggleNavBar(true);
        }
      },
      child: Stack(
        children: [
          widget.child,

          // Invisible drag trigger handle at top of screen for swipe down
          if (!widget.screenManager.isNavBarVisible &&
              !widget.screenManager.isEditMode)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: 32,
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onVerticalDragUpdate: (details) {
                  if (details.primaryDelta != null &&
                      details.primaryDelta! > 4) {
                    widget.screenManager.toggleNavBar(true);
                  }
                },
                child: Center(
                  child: Container(
                    width: 48,
                    height: 4,
                    margin: const EdgeInsets.only(top: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withAlpha(80),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ),
            ),

          // Tap outside dismiss barrier when nav bar is visible
          if (widget.screenManager.isNavBarVisible)
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => widget.screenManager.toggleNavBar(false),
                onVerticalDragUpdate: (details) {
                  if (details.primaryDelta != null &&
                      details.primaryDelta! < -4) {
                    widget.screenManager.toggleNavBar(false);
                  }
                },
                child: Container(color: Colors.black.withAlpha(80)),
              ),
            ),

          // Top Nav Bar widget animated slide down
          SlideTransition(
            position: _slideAnimation,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                child: Material(
                  color: Colors.transparent,
                  child: _buildNavBarContent(context, style),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavBarContent(BuildContext context, NavBarStyle style) {
    switch (style) {
      case NavBarStyle.translucentDrawer:
        return _buildTranslucentDrawer(context);
      case NavBarStyle.floatingPill:
        return _buildFloatingPill(context);
      case NavBarStyle.cornerMenu:
        return _buildCornerMenu(context);
    }
  }

  // Option 1: Translucent Drawer (Full width backdrop blur)
  Widget _buildTranslucentDrawer(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxHeight: 380),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.blueGrey.shade900.withAlpha(210),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withAlpha(30)),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black45,
                  blurRadius: 16,
                  offset: Offset(0, 8),
                ),
              ],
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildHeader(context, "BrandyFly Navigation"),
                  const Divider(color: Colors.white24, height: 24),
                  _buildScreenSelector(context),
                  const SizedBox(height: 16),
                  _buildActionButtons(context),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // Option 2: Floating Action Pill
  Widget _buildFloatingPill(BuildContext context) {
    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 420),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.blueGrey.shade900.withAlpha(235),
          borderRadius: BorderRadius.circular(32),
          border: Border.all(color: Colors.blueAccent.withAlpha(100)),
          boxShadow: const [
            BoxShadow(
              color: Colors.black54,
              blurRadius: 12,
              offset: Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            IconButton(
              icon: const Icon(Icons.close, color: Colors.white70),
              tooltip: 'Close',
              onPressed: () => widget.screenManager.toggleNavBar(false),
            ),
            Expanded(
              child: Center(child: _buildScreenSelectorDropdown(context)),
            ),
            IconButton(
              icon: const Icon(Icons.flight, color: Colors.lightGreenAccent),
              tooltip: 'Flights',
              onPressed: () => widget.screenManager.toggleFlightsScreen(true),
            ),
            IconButton(
              icon: const Icon(Icons.edit_note, color: Colors.cyanAccent),
              tooltip: 'Edit Mode',
              onPressed: () => widget.screenManager.toggleEditMode(true),
            ),
            IconButton(
              icon: const Icon(Icons.settings, color: Colors.white),
              tooltip: 'Settings',
              onPressed: () => widget.screenManager.toggleSettingsPanel(true),
            ),
          ],
        ),
      ),
    );
  }

  // Option 3: Corner Menu Button / Compact Bar
  Widget _buildCornerMenu(BuildContext context) {
    return Align(
      alignment: Alignment.topRight,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.grey.shade900.withAlpha(240),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white24),
          boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 10)],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Navigation',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 12),
                IconButton(
                  onPressed: () => widget.screenManager.toggleNavBar(false),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  tooltip: 'Close Navigation',
                  icon: const Icon(
                    Icons.close,
                    color: Colors.white70,
                    size: 20,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildScreenSelector(context),
            const SizedBox(height: 12),
            _buildActionButtons(context),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, String title) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            const Icon(Icons.flight_takeoff, color: Colors.lightBlueAccent),
            const SizedBox(width: 8),
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        IconButton(
          icon: const Icon(Icons.close, color: Colors.white70),
          tooltip: 'Close',
          onPressed: () => widget.screenManager.toggleNavBar(false),
        ),
      ],
    );
  }

  Widget _buildScreenSelector(BuildContext context) {
    final screens = widget.screenManager.config.screens;
    final activeId = widget.screenManager.config.activeScreenId;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          ...screens.map((screen) {
            final isActive = screen.id == activeId;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(screen.name),
                selected: isActive,
                selectedColor: Colors.blueAccent,
                backgroundColor: Colors.white.withAlpha(20),
                labelStyle: TextStyle(
                  color: isActive ? Colors.white : Colors.white70,
                  fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                ),
                onSelected: (selected) {
                  if (selected) {
                    widget.screenManager.setActiveScreen(screen.id);
                    widget.screenManager.toggleNavBar(false);
                  }
                },
              ),
            );
          }),
          IconButton(
            icon: const Icon(
              Icons.add_to_photos,
              color: Colors.lightBlueAccent,
            ),
            tooltip: 'Add Screen',
            onPressed: () => _promptAddScreen(context),
          ),
        ],
      ),
    );
  }

  Widget _buildScreenSelectorDropdown(BuildContext context) {
    final screens = widget.screenManager.config.screens;
    final activeId = widget.screenManager.config.activeScreenId;

    return DropdownButton<String>(
      value: activeId,
      dropdownColor: Colors.blueGrey.shade900,
      underline: const SizedBox(),
      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
      icon: const Icon(Icons.arrow_drop_down, color: Colors.white70),
      items: screens.map((screen) {
        return DropdownMenuItem<String>(
          value: screen.id,
          child: Text(screen.name),
        );
      }).toList(),
      onChanged: (newId) {
        if (newId != null) {
          widget.screenManager.setActiveScreen(newId);
          widget.screenManager.toggleNavBar(false);
        }
      },
    );
  }

  Widget _buildActionButtons(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.spaceEvenly,
      spacing: 8,
      runSpacing: 8,
      children: [
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.teal.shade700,
            foregroundColor: Colors.white,
          ),
          icon: const Icon(Icons.flight),
          label: const Text('Flights'),
          onPressed: () {
            widget.screenManager.toggleNavBar(false);
            widget.screenManager.toggleFlightsScreen(true);
          },
        ),
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.cyan.shade700,
            foregroundColor: Colors.white,
          ),
          icon: const Icon(Icons.dashboard_customize),
          label: const Text('Edit Mode'),
          onPressed: () {
            widget.screenManager.toggleNavBar(false);
            widget.screenManager.toggleEditMode(true);
          },
        ),
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blueGrey.shade700,
            foregroundColor: Colors.white,
          ),
          icon: const Icon(Icons.settings),
          label: const Text('Settings'),
          onPressed: () {
            widget.screenManager.toggleNavBar(false);
            widget.screenManager.toggleSettingsPanel(true);
          },
        ),
      ],
    );
  }

  void _promptAddScreen(BuildContext context) {
    final controller = TextEditingController();

    void submit(BuildContext ctx) {
      final name = controller.text.trim();
      if (name.isNotEmpty) {
        widget.screenManager.addScreen(name);
      }
      Navigator.pop(ctx);
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add New Screen'),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => submit(ctx),
          decoration: const InputDecoration(
            hintText: 'Screen Name (e.g. Thermaling, Navigation)',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => submit(ctx),
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }
}
