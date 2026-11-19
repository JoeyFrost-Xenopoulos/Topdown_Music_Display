import os
from PIL import Image

SRC_DIR = "assets/covers"
DST_DIR = "assets/covers_thumb"
THUMB_SIZE = 160

os.makedirs(DST_DIR, exist_ok=True)

files = [f for f in os.listdir(SRC_DIR) if f.lower().endswith(".png")]
print(f"Processing {len(files)} covers...")

for i, fname in enumerate(files):
    src = os.path.join(SRC_DIR, fname)
    dst = os.path.join(DST_DIR, fname)
    
    try:
        with Image.open(src) as img:
            img.thumbnail((THUMB_SIZE, THUMB_SIZE), Image.Resampling.LANCZOS)
            # Save as PNG (lossless) or WebP for smaller size
            img.save(dst, "PNG", optimize=True)
    except Exception as e:
        print(f"  Failed {fname}: {e}")
        continue
    
    if (i + 1) % 50 == 0:
        print(f"  {i + 1}/{len(files)}")

print(f"Done! Thumbnails saved to {DST_DIR}")