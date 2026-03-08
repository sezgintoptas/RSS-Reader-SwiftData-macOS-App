import sys
import os
from PIL import Image

def main():
    if len(sys.argv) < 3:
        print("Usage: python crop_icon.py <input> <output_dir>")
        return

    in_path = sys.argv[1]
    out_dir = sys.argv[2]
    
    if not os.path.exists(out_dir):
         os.makedirs(out_dir)

    try:
        img = Image.open(in_path).convert("RGBA")
        width, height = img.size
        
        # Original generate_image returns 1024x1024, cropping a subrectangle in center:
        # We can crop the center 700x700
        crop_size = 700
        left = (width - crop_size) / 2
        top = (height - crop_size) / 2
        right = (width + crop_size) / 2
        bottom = (height + crop_size) / 2
        img_cropped = img.crop((left, top, right, bottom))
        
        # Sizes to generate for AppIcon.iconset
        sizes = [
            (16, "icon_16x16.png"),
            (32, "icon_16x16@2x.png"),
            (32, "icon_32x32.png"),
            (64, "icon_32x32@2x.png"),
            (128, "icon_128x128.png"),
            (256, "icon_128x128@2x.png"),
            (256, "icon_256x256.png"),
            (512, "icon_256x256@2x.png"),
            (512, "icon_512x512.png"),
            (1024, "icon_512x512@2x.png")
        ]
        
        for size, name in sizes:
            resized = img_cropped.resize((size, size), Image.LANCZOS)
            resized.save(os.path.join(out_dir, name), "PNG")
            
        print("Successfully created AppIcon.iconset files.")
    except Exception as e:
        print(f"Error: {e}")

if __name__ == "__main__":
    main()
