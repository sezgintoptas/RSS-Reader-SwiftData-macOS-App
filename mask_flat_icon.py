import sys
from PIL import Image, ImageDraw

def add_squircle_mask(img, radius):
    # Create an alpha mask with the given radius
    mask = Image.new("L", img.size, 0)
    draw = ImageDraw.Draw(mask)
    width, height = img.size
    
    # Draw a rounded rectangle mask
    draw.rounded_rectangle((0, 0, width, height), radius=radius, fill=255)
    
    # Put alpha channel into image
    result = img.convert("RGBA")
    result.putalpha(mask)
    return result

def main():
    if len(sys.argv) < 3:
        print("Usage: python mask_flat_icon.py <input> <output>")
        return

    in_path = sys.argv[1]
    out_path = sys.argv[2]
    
    try:
        img = Image.open(in_path).convert("RGBA")
        
        # Original is 1024x1024, let's just make it a squircle
        # To make it look like a nice app icon, we sometimes add a gentle padding 
        # But this image is already centered. We'll simply apply the mask directly.
        # Scale to 1024x1024 explicitly just in case.
        img_final = img.resize((1024, 1024), Image.LANCZOS)
        
        # radius ~230 pixels for 1024x1024 macOS app icon
        img_masked = add_squircle_mask(img_final, 230)
        
        img_masked.save(out_path, "PNG")
        print("Successfully created transparent squircle image from flat design.")
    except Exception as e:
        print(f"Error: {e}")

if __name__ == "__main__":
    main()
