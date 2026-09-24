import os

with open('/home/markus/Projects/private/brandyfly/apps/mobile/lib/widgets/layout/widget_edit_frame.dart', 'r') as f:
    lines = f.readlines()

new_lines = []
for line in lines:
    if line.strip() == "}":
        if len(new_lines) > 450: # The bad EOF brace
            continue
    new_lines.append(line)

new_lines.extend([
    "      ),\n",
    "    );\n",
    "  }\n",
    "}\n"
])

with open('/home/markus/Projects/private/brandyfly/apps/mobile/lib/widgets/layout/widget_edit_frame.dart', 'w') as f:
    f.writelines(new_lines)

