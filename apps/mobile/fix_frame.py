import os

with open('/home/markus/Projects/private/brandyfly/apps/mobile/lib/widgets/layout/widget_edit_frame.dart', 'r') as f:
    lines = f.readlines()

new_lines = []
for line in lines:
    if line.strip() == "}":
        if len(new_lines) < 8:
            continue
    if 'const _WidgetEditFrame({' in line:
        line = line.replace('const _WidgetEditFrame({', 'const WidgetEditFrame({')
    new_lines.append(line)

with open('/home/markus/Projects/private/brandyfly/apps/mobile/lib/widgets/layout/widget_edit_frame.dart', 'w') as f:
    f.writelines(new_lines)

