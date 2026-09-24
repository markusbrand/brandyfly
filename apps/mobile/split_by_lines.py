import os

with open('/home/markus/Projects/private/brandyfly/apps/mobile/lib/widgets/layout/layout_strategy_container.dart', 'r') as f:
    lines = f.readlines()

# Task 1.1 (1023 to 1488, 0-indexed)
frame_lines = lines[1023:1488]
frame_code = "".join(frame_lines)
frame_code = frame_code.replace('_WidgetEditFrameState', 'WidgetEditFrameState').replace('_WidgetEditFrame', 'WidgetEditFrame')
frame_code = frame_code.replace('_showConfigDialog', 'showWidgetConfigDialog')

with open('/home/markus/Projects/private/brandyfly/apps/mobile/lib/widgets/layout/widget_edit_frame.dart', 'w') as f:
    f.write('''import 'package:flutter/material.dart';
import '../../models/ui_config.dart';
import '../../services/screen_manager_service.dart';
import 'widget_config_dialog.dart';

''')
    f.write(frame_code)

# Task 1.2 (1488 to 2462, 0-indexed)
dialog_lines = lines[1488:2462]
dialog_code = "".join(dialog_lines)

dialog_code = dialog_code.replace('  static void _showConfigDialog', 'void showWidgetConfigDialog')
dialog_code = dialog_code.replace('  static Widget _buildSectionTitle', 'Widget buildSectionTitle')
dialog_code = dialog_code.replace('  static Widget _styleChip', 'Widget styleChip')
dialog_code = dialog_code.replace('  static Widget _durationChip', 'Widget durationChip')
dialog_code = dialog_code.replace('_buildSectionTitle', 'buildSectionTitle')
dialog_code = dialog_code.replace('_styleChip', 'styleChip')
dialog_code = dialog_code.replace('_durationChip', 'durationChip')
dialog_code = '\n'.join([line[2:] if line.startswith('  ') else line for line in dialog_code.split('\n')])

with open('/home/markus/Projects/private/brandyfly/apps/mobile/lib/widgets/layout/widget_config_dialog.dart', 'w') as f:
    f.write('''import 'package:flutter/material.dart';
import '../../models/ui_config.dart';
import '../../services/screen_manager_service.dart';

''')
    f.write(dialog_code)

# Task 1.3 (223 to 511, 0-indexed)
panel_lines = lines[223:511]
panel_code = "".join(panel_lines)

# Transform _buildInspectorPanel into a build method
panel_code = panel_code.replace(
'''  Widget _buildInspectorPanel(
    BuildContext context,
    WidgetPlacementModel model,
  ) {''',
'''  @override
  Widget build(BuildContext context) {'''
)
panel_code = panel_code.replace('_WidgetEditFrameState._showConfigDialog', 'showWidgetConfigDialog')

with open('/home/markus/Projects/private/brandyfly/apps/mobile/lib/widgets/layout/widget_inspector_panel.dart', 'w') as f:
    f.write('''import 'package:flutter/material.dart';
import '../../models/ui_config.dart';
import '../../services/screen_manager_service.dart';
import 'widget_config_dialog.dart';

class WidgetInspectorPanel extends StatelessWidget {
  const WidgetInspectorPanel({
    super.key,
    required this.model,
    required this.screenManager,
  });

  final WidgetPlacementModel model;
  final ScreenManagerService screenManager;

''')
    f.write(panel_code)
    f.write('}\n')

# Task 1.4: update layout_strategy_container.dart
new_lines = []
imports_added = False
for i, line in enumerate(lines):
    if not imports_added and not line.startswith('import ') and not line.startswith('//') and line.strip() != '' and 'package:' not in line:
        new_lines.insert(len(new_lines)-1, "import 'widget_edit_frame.dart';\nimport 'widget_inspector_panel.dart';\nimport 'widget_config_dialog.dart';\n")
        imports_added = True
    
    if 223 <= i < 511:
        continue
    if 1023 <= i < 2462:
        continue
        
    line = line.replace('_WidgetEditFrame(', 'WidgetEditFrame(')
    line = line.replace('_buildInspectorPanel(context, selectedWidget)', 'WidgetInspectorPanel(model: selectedWidget, screenManager: screenManager)')
    new_lines.append(line)

with open('/home/markus/Projects/private/brandyfly/apps/mobile/lib/widgets/layout/layout_strategy_container.dart', 'w') as f:
    f.writelines(new_lines)

