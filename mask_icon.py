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
    result = img.copy()
    result.putalpha(mask)
    return result

def main():
    if len(sys.argv) < 3:
        print("Usage: python mask_icon.py <input> <output>")
        return

    in_path = sys.argv[1]
    out_path = sys.argv[2]
    
    try:
        img = Image.open(in_path).convert("RGBA")
        width, height = img.size
        
        # We need to crop to exactly the icon bounds. 
        # For the recent 1024x1024 generation, the icon covers a central area.
        # Let's crop the center 680x680 area which matches the icon
        crop_size = 680
        left = (width - crop_size) / 2
        top = (height - crop_size) / 2
        right = (width + crop_size) / 2
        bottom = (height + crop_size) / 2
        img_cropped = img.crop((left, top, right, bottom))
        
        # Resize to 1024x1024
        img_final = img_cropped.resize((1024, 1024), Image.LANCZOS)
        
        # macOS squircle radius for 1024x1024 is approximately 22.5% of the size = ~230 pixels
        img_masked = add_squircle_mask(img_final, 230)
        
        img_masked.save(out_path, "PNG")
        print("Successfully created transparent squircle image.")
    except Exception as e:
        print(f"Error: {e}")

if __name__ == "__main__":
    main()
