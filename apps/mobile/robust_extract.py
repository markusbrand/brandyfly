import re

def extract_block(text, start_pattern):
    match = re.search(start_pattern, text)
    if not match:
        return None
    start_idx = match.start()
    
    # Find the first '{' after start_idx
    open_idx = text.find('{', start_idx)
    if open_idx == -1:
        return None
        
    count = 1
    idx = open_idx + 1
    while count > 0 and idx < len(text):
        if text[idx] == '{':
            count += 1
        elif text[idx] == '}':
            count -= 1
        idx += 1
        
    return text[start_idx:idx]

with open('/home/markus/Projects/private/brandyfly/apps/mobile/lib/widgets/layout/layout_strategy_container.dart', 'r') as f:
    text = f.read()

# 1. Extract WidgetEditFrame
edit_frame_code = extract_block(text, r'class _WidgetEditFrame extends StatefulWidget')
edit_frame_state_code = extract_block(text, r'class _WidgetEditFrameState extends State<_WidgetEditFrame>')

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
    f.write('\n')

# 2. Extract Widget Config Dialog
m1 = extract_block(text, r'  static void _showConfigDialog\(')
m2 = extract_block(text, r'  static Widget _buildSectionTitle\(')
m3 = extract_block(text, r'  static Widget _styleChip<T>\(')
m4 = extract_block(text, r'  static Widget _durationChip\(')

dialog_code = m1 + '\n\n' + m2 + '\n\n' + m3 + '\n\n' + m4 + '\n'
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
    f.write('\n')

# 3. Extract Widget Inspector Panel
m_build = extract_block(text, r'  Widget _buildInspectorPanel\(')
m_btn1 = extract_block(text, r'  Widget _inspectorButton\(')
m_btn2 = extract_block(text, r'  Widget _inspectorTextButton\(')

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

# _buildInspectorPanel starts with:
#   Widget _buildInspectorPanel(
#     BuildContext context,
#     WidgetPlacementModel model,
#   ) {
# We want to remove this header and just keep the inside, or just do a regex sub:
build_body = re.sub(r'  Widget _buildInspectorPanel\([\s\S]*?\) \{\n', '', m_build, count=1)
panel_code += build_body

panel_code = panel_code.replace('_WidgetEditFrameState._showConfigDialog', 'showWidgetConfigDialog')

panel_code += '\n\n' + m_btn1 + '\n\n' + m_btn2 + '\n}\n'

with open('/home/markus/Projects/private/brandyfly/apps/mobile/lib/widgets/layout/widget_inspector_panel.dart', 'w') as f:
    f.write(panel_code)


# 4. Update layout_strategy_container.dart
new_text = text
new_text = new_text.replace(extract_block(text, r'class _WidgetEditFrame extends StatefulWidget'), '')
new_text = new_text.replace(extract_block(text, r'class _WidgetEditFrameState extends State<_WidgetEditFrame>'), '')
new_text = new_text.replace(m1, '')
new_text = new_text.replace(m2, '')
new_text = new_text.replace(m3, '')
new_text = new_text.replace(m4, '')
new_text = new_text.replace(m_build, '')
new_text = new_text.replace(m_btn1, '')
new_text = new_text.replace(m_btn2, '')

new_text = new_text.replace("import 'widget_picker_sheet.dart';", "import 'widget_picker_sheet.dart';\nimport 'widget_edit_frame.dart';\nimport 'widget_inspector_panel.dart';\nimport 'widget_config_dialog.dart';")
new_text = new_text.replace('_WidgetEditFrame(', 'WidgetEditFrame(')
new_text = new_text.replace('_buildInspectorPanel(context, selectedWidget)', 'WidgetInspectorPanel(model: selectedWidget, screenManager: screenManager)')
new_text = re.sub(r'\n\s*\n\s*\n', '\n\n', new_text)
# the trailing } of _WidgetEditFrameState might be left behind if our block matcher didn't grab the outer class's }. 
# But wait, we extracted _WidgetEditFrameState which IS the outer class.
# Let's fix the end of file manually if needed, or by finding class LayoutStrategyContainer and ensuring it closes properly.

with open('/home/markus/Projects/private/brandyfly/apps/mobile/lib/widgets/layout/layout_strategy_container.dart', 'w') as f:
    f.write(new_text)

print("Done")
