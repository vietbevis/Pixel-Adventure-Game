import base64
import struct

path = 'game/levels/level_1/level_1.tscn'
with open(path, 'r', encoding='utf-8') as f:
    lines = f.readlines()

for line in lines:
    if 'tile_map_data = PackedByteArray' in line:
        start = line.find('("') + 2
        end = line.find('")')
        b64_data = line[start:end]
        data = base64.b64decode(b64_data)
        ints = list(struct.unpack(f"<{len(data)//2}h", data))
        
        # print first 10 cells
        for i in range(0, 80, 8):
            print(ints[i:i+8])
        print("...")
        # print last 10 cells
        for i in range(len(ints)-80, len(ints), 8):
            print(ints[i:i+8])
