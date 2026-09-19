import base64
import struct

path = 'game/levels/level_1/level_1.tscn'
with open(path, 'r', encoding='utf-8') as f:
    for line in f:
        if 'tile_map_data = PackedByteArray' in line:
            start = line.find('("') + 2
            end = line.find('")')
            b64_data = line[start:end]
            data = base64.b64decode(b64_data)
            
            # length of data = 6848 bytes
            print(f"Data length: {len(data)}")
            
            # If 12 bytes per cell, 6848 / 12 = 570.66 (not divisible!)
            # If 16 bytes per cell, 6848 / 16 = 428 cells (divisible!)
            
            # Let's decode as 16-bit integers
            ints = list(struct.unpack(f"<{len(data)//2}h", data))
            
            print("12-byte groups (6 int16s):")
            for i in range(0, 36, 6):
                print(ints[i:i+6])
                
            print("16-byte groups (8 int16s):")
            for i in range(0, 48, 8):
                print(ints[i:i+8])
                
            # print all cells near x=45-55 (assuming 16-byte groups)
            print("Cells near x=45-55 (assuming 8 int16s/cell):")
            for i in range(0, len(ints), 8):
                x = ints[i]
                y = ints[i+1]
                if 48 <= x <= 56:
                    print(f"cell x={x}, y={y}, data={ints[i:i+8]}")
