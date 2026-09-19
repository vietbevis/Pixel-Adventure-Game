import base64
import struct

path = 'game/levels/level_1/level_1.tscn'
with open(path, 'r', encoding='utf-8') as f:
    lines = f.readlines()

new_lines = []
for line in lines:
    if 'tile_map_data = PackedByteArray' in line:
        start = line.find('("') + 2
        end = line.find('")')
        b64_data = line[start:end]
        
        data = base64.b64decode(b64_data)
        ints = list(struct.unpack(f"<{len(data)//2}h", data))
        
        new_ints = []
        for i in range(0, len(ints), 8):
            cell = ints[i:i+8]
            x = cell[0]
            y = cell[1]
            
            # Remove the floating platform blocking the player.
            if 42 <= x <= 62 and 9 <= y <= 11:
                print(f"Removing cell x={x}, y={y}")
                continue
            new_ints.extend(cell)
            
        new_data = struct.pack(f"<{len(new_ints)}h", *new_ints)
        new_b64 = base64.b64encode(new_data).decode('utf-8')
        new_lines.append(f'tile_map_data = PackedByteArray("{new_b64}")\n')
    else:
        new_lines.append(line)

with open(path, 'w', encoding='utf-8') as f:
    f.writelines(new_lines)

print("Done modifying level_1.tscn")
