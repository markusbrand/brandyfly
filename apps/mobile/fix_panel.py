import os

with open('/home/markus/Projects/private/brandyfly/apps/mobile/lib/widgets/layout/widget_inspector_panel.dart', 'r') as f:
    lines = f.readlines()

new_lines = []
for i, line in enumerate(lines):
    if line.strip() == ') {' and i < 20:
        continue
    new_lines.append(line)

with open('/home/markus/Projects/private/brandyfly/apps/mobile/lib/widgets/layout/widget_inspector_panel.dart', 'w') as f:
    f.writelines(new_lines)
