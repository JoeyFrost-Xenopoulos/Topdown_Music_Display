import os
import re

thumbs = os.listdir('assets/covers_thumb')
print('First 5 thumbnails:')
for f in thumbs[:5]:
    print(f'  {f}')
print()
print('Total thumbnails:', len(thumbs))

with open('data/album_data.lua', 'r', encoding='utf-8') as f:
    content = f.read()

keys = re.findall(r'\["([^"]+)"\]', content)
print('First 5 album_data keys:')
for k in keys[:5]:
    print(f'  {k}')
print('Total keys:', len(keys))

# Check if thumb filenames match any keys
matches = 0
for t in thumbs[:20]:
    base = t.replace('.png', '')
    if base in keys or base.lower() in keys:
        matches += 1
        print(f'  MATCH: {base}')
    else:
        print(f'  NO MATCH: {base}')
print(f'Matches in first 20: {matches}/20')