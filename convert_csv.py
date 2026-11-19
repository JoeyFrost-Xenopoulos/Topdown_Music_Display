import csv
import json

albums = {}
with open('Albums_clean.csv', 'r', encoding='utf-8') as f:
    reader = csv.DictReader(f)
    for row in reader:
        album = row['album']
        artist = row['artist']
        year = int(row['year'])
        key = f"{artist} - {album}"
        albums[key] = {"album": album, "artist": artist, "year": year}
        albums[key.lower()] = albums[key]

with open('album_data.lua', 'w', encoding='utf-8') as f:
    f.write('return {\n')
    for k, v in albums.items():
        # Escape quotes and backslashes
        key_escaped = k.replace('\\', '\\\\').replace('"', '\\"')
        album_escaped = v['album'].replace('\\', '\\\\').replace('"', '\\"')
        artist_escaped = v['artist'].replace('\\', '\\\\').replace('"', '\\"')
        f.write(f'  ["{key_escaped}"] = {{ album = "{album_escaped}", artist = "{artist_escaped}", year = {v["year"]} }},\n')
    f.write('}\n')

print(f'Generated album_data.lua with {len(albums)} entries')