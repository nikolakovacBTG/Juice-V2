import re

filepath = 'd:/Godot_projekti/juice-demo/Documentation/Port_Master_Tracker.md'
with open(filepath, 'r', encoding='utf-8') as f:
    lines = f.readlines()

new_lines = []
for line in lines:
    line = line.replace('❌ Tests', 'Tests').replace('| ------- |', '|-------|')
    
    parts = line.split('|')
    if len(parts) >= 5 and '✅' in parts[3]:
        test_col = parts[4].strip()
        if test_col and test_col != 'Tests':
            if '❌' not in test_col and '🧪' not in test_col:
                if 'TestVFXEffect' in test_col or 'TestCameraJuice' in test_col:
                    parts[4] = f' 🧪 {test_col} '
                elif 'Test' in test_col or 'Transport UI' in test_col:
                    parts[4] = f' ❌ {test_col} '
            
            line = '|'.join(parts)
    
    new_lines.append(line)

with open(filepath, 'w', encoding='utf-8') as f:
    f.writelines(new_lines)
print("Done")
