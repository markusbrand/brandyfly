import re

with open('/home/markus/Projects/private/brandyfly/apps/mobile/lib/widgets/layout/layout_strategy_container.dart', 'r') as f:
    text = f.read()

# 1. Extract WidgetEditFrame
edit_frame_match = re.search(r'(class _WidgetEditFrame extends StatefulWidget \{.*?\n\})', text, re.DOTALL)
edit_frame_state_match = re.search(r'(class _WidgetEditFrameState extends State<_WidgetEditFrame> \{.*?  \}\n)\}', text, re.DOTALL)

edit_frame_code = edit_frame_match.group(1)
edit_frame_state_code = edit_frame_state_match.group(1) + "}\n"

# Rename and replace in edit frame
edit_frame_code = edit_frame_code.replace('_WidgetEditFrame', 'WidgetEditFrame')
edit_frame_state_code = edit_frame_state_code.replace('_WidgetEditFrameState', 'WidgetEditFrameState').replace('_WidgetEditFrame', 'WidgetEditFrame')
edit_frame_state_code = edit_frame_state_code.replace('_showConfigDialog', 'showWidgetConfigDialog')

with open('/home/markus/Projects/private/brandyfly/apps/mobile/lib/widgets/layout/widget_edit_frame.dart', 'w') as f:
    f.write('''import 'package:flutter/material.dart';
import '../../models/ui_config.dart';
import '../../services/screen_manager_service.dart';
import 'widget_config_dialog.dart';

''')
    f.write(edit_frame_code)
    f.write('\n\n')
    f.write(edit_frame_state_code)


# 2. Extract Widget Config Dialog
def extract_method(name):
    m = re.search(r'(  static (?:void|Widget) ' + name + r'(?:<T>)?\(.*?  \}\n)', text, re.DOTALL)
    if not m:
        print(f"Could not find {name}")
        exit(1)
    return m.group(1)

m1 = extract_method('_showConfigDialog')
m2 = extract_method('_buildSectionTitle')
m3 = extract_method('_styleChip')
m4 = extract_method('_durationChip')

dialog_code = m1 + '\n' + m2 + '\n' + m3 + '\n' + m4 + '\n'
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

# 3. Extract Widget Inspector Panel
m_build = re.search(r'(  Widget _buildInspectorPanel\(.*?  \}\n)', text, re.DOTALL)
m_btn1 = re.search(r'(  Widget _inspectorButton\(.*?  \}\n)', text, re.DOTALL)
m_btn2 = re.search(r'(  Widget _inspectorTextButton\(.*?  \}\n)', text, re.DOTALL)

panel_code = '''import 'package:flutter/material.dart';
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

  @override
  Widget build(BuildContext context) {
'''
build_body = m_build.group(1)
build_body = re.sub(r'  Widget _buildInspectorPanel\([\s\S]*?\) \{\n', '', build_body, count=1)
panel_code += build_body

panel_code = panel_code.replace('_WidgetEditFrameState._showConfigDialog', 'showWidgetConfigDialog')

panel_code += '\n' + m_btn1.group(1) + '\n' + m_btn2.group(1) + '}\n'

with open('/home/markus/Projects/private/brandyfly/apps/mobile/lib/widgets/layout/widget_inspector_panel.dart', 'w') as f:
    f.write(panel_code)


# 4. Update layout_strategy_container.dart
new_text = text
new_text = new_text.replace(edit_frame_match.group(1), '')
new_text = new_text.replace(edit_frame_state_match.group(1) + "}", '')
new_text = new_text.replace(m1, '')
new_text = new_text.replace(m2, '')
new_text = new_text.replace(m3, '')
new_text = new_text.replace(m4, '')
new_text = new_text.replace(m_build.group(1), '')
new_text = new_text.replace(m_btn1.group(1), '')
new_text = new_text.replace(m_btn2.group(1), '')

new_text = new_text.replace("import 'widget_picker_sheet.dart';", "import 'widget_picker_sheet.dart';\nimport 'widget_edit_frame.dart';\nimport 'widget_inspector_panel.dart';\nimport 'widget_config_dialog.dart';")
new_text = new_text.replace('_WidgetEditFrame(', 'WidgetEditFrame(')
new_text = new_text.replace('_buildInspectorPanel(context, selectedWidget)', 'WidgetInspectorPanel(model: selectedWidget, screenManager: screenManager)')
new_text = re.sub(r'\n\s*\n\s*\n', '\n\n', new_text)

with open('/home/markus/Projects/private/brandyfly/apps/mobile/lib/widgets/layout/layout_strategy_container.dart', 'w') as f:
    f.write(new_text)

print("Done")
