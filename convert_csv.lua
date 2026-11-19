local csv = io.open('Albums_clean.csv', 'r')
local header = csv:read() -- skip header
local albums = {}
for line in csv:lines() do
    local album, artist, year = line:match('^"([^"]+)","([^"]+)","(%d+)"$')
    if album and artist then
        local key = artist .. ' - ' .. album
        albums[key] = { album = album, artist = artist, year = tonumber(year) }
        albums[key:lower()] = albums[key]
    end
end
csv:close()

local out = io.open('album_data.lua', 'w')
out:write('return {\n')
for k, v in pairs(albums) do
    out:write(string.format('  ["%s"] = { album = "%s", artist = "%s", year = %d },\n',
        k:gsub('"', '\\"'):gsub('\\', '\\\\'), v.album:gsub('"', '\\"'), v.artist:gsub('"', '\\"'), v.year))
end
out:write('}\n')
out:close()
print('Generated album_data.lua with ' .. #albums .. ' entries')