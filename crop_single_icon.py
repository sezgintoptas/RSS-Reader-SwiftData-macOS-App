import sys
from PIL import Image

def main():
    if len(sys.argv) < 3:
        print("Usage: python crop_single_icon.py <input> <output>")
        return

    in_path = sys.argv[1]
    out_path = sys.argv[2]
    
    try:
        img = Image.open(in_path).convert("RGBA")
        width, height = img.size
        
        # Center crop 680x680 to get exactly the macOS icon boundary and make it clean
        crop_size = 680
        left = (width - crop_size) / 2
        top = (height - crop_size) / 2
        right = (width + crop_size) / 2
        bottom = (height + crop_size) / 2
        img_cropped = img.crop((left, top, right, bottom))
        
        # Apple standard requires transparent corners/squircle or the system does it 
        # but scaling to 1024x1024 is the format for ic10
        img_final = img_cropped.resize((1024, 1024), Image.LANCZOS)
        img_final.save(out_path, "PNG")
        print("Successfully created center cropped 1024x1024 image.")
    except Exception as e:
        print(f"Error: {e}")

if __name__ == "__main__":
    main()
