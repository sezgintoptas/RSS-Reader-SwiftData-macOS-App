import os
import struct

def create_icns(png_path, icns_path):
    with open(png_path, "rb") as f:
        png_data = f.read()

    # The type for 1024x1024 png is 'ic10'
    chunk_type = b'ic10'
    chunk_size = 8 + len(png_data)
    
    total_size = 8 + chunk_size
    
    with open(icns_path, "wb") as f:
        # File header
        f.write(b'icns')
        f.write(struct.pack(">I", total_size))
        
        # Chunk header
        f.write(chunk_type)
        f.write(struct.pack(">I", chunk_size))
        
        # Data
        f.write(png_data)

if __name__ == "__main__":
    create_icns("AppIcon.png", "AppIcon.icns")
    print("Created AppIcon.icns")
