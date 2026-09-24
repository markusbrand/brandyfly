import os

with open('/home/markus/Projects/private/brandyfly/apps/mobile/lib/widgets/layout/widget_config_dialog.dart', 'r') as f:
    lines = f.readlines()

new_lines = []
for line in lines:
    if line.strip() == ');' or (line.strip() == '}' and len(new_lines) < 10):
        continue
    new_lines.append(line)

with open('/home/markus/Projects/private/brandyfly/apps/mobile/lib/widgets/layout/widget_config_dialog.dart', 'w') as f:
    f.writelines(new_lines)

