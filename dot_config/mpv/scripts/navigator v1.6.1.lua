local utils = require("mp.utils")
local mpopts = require("mp.options")
local assdraw = require("mp.assdraw")

-- mp.input (mpv 0.38+) gives us a text prompt through mpv's built-in console.
-- Do NOT set load-console=no in mpv.conf, or the terminal prompt cannot open.
-- It is only loaded the first time the terminal or filter is used, to keep startup fast.
local input = nil
local function ensure_input()
  if input then return true end
  local ok, m = pcall(require, "mp.input")
  if ok and m then
    input = m
    return true
  end
  return false
end

ON_WINDOWS = (package.config:sub(1,1) ~= "/")
WINDOWS_ROOTDIR = false
WINDOWS_ROOT_DESC = "Select drive"
SEPARATOR_WINDOWS = "\\"

SEPARATOR = "/"

local windows_desktop = ON_WINDOWS and utils.join_path(os.getenv("USERPROFILE"), "Desktop"):gsub(SEPARATOR, SEPARATOR_WINDOWS)..SEPARATOR_WINDOWS or nil
local userhome = (ON_WINDOWS and os.getenv("USERPROFILE")) or os.getenv("HOME") or (ON_WINDOWS and "C:\\" or "/")

local settings = {
  --navigation keybinds override arrowkeys and enter when activating navigation menu, false means keys are always actíve
  dynamic_binds = true,
  navigator_mainkey = "Alt+f", --the key to bring up navigator's menu, can be bound on input.conf aswell

  --dynamic binds, should not be bound in input.conf unless dynamic binds is false
  key_navfavorites = "f",
  key_navup = "UP",
  key_navdown = "DOWN",
  key_navback = "LEFT",
  key_navforward = "RIGHT",
  key_navopen = "ENTER",
  key_navclose = "ESC",
  key_navpageup = "PGUP",
  key_navpagedown = "PGDWN",
  key_navterminal = "t", --opens the built-in terminal prompt while the navigator is shown
  key_navfilter = "/",   --type part of a name to narrow the list (Enter keeps it, Esc clears it)

  --only show folders, video files and subtitle files. set to false to show everything again
  only_media = true,

  --fast_scan lists a folder with one directory read and only checks "is this a folder?" for names
  --that have no known file extension. Much faster in big folders (Downloads). The only catch: a
  --folder whose name ends in a common file extension (like "Reports.pdf") would be treated as a file.
  --set to false for an exact (but slower) scan
  fast_scan = true,

  --fallback if no file is open, should be a string that points to a path in your system
  defaultpath = windows_desktop or os.getenv("HOME") or "/",
  forcedefault = false, --force navigation to start from defaultpath instead of currently playing file
  --favorites in format { 'Path to directory, notice trailing /' }
  --on windows use double backslash c:\\my\\directory\\
  favorites = ON_WINDOWS and {
    userhome.."\\Videos\\",
    userhome.."\\Downloads\\",
    userhome.."\\Desktop\\",
  } or {
    userhome.."/Videos/",
    userhome.."/Downloads/",
    userhome.."/",
  },
  --list of paths to ignore. the value is anything that returns true for if-statement.
  --directory ignore entries must end with a trailing slash,
  --but files and all symlinks (even to dirs) must be without slash!
  --to help you with the format, simply run "ls -1p <parent folder>" in a terminal,
  --and you will see if the file/folder to ignore is listed as "file" or "folder/" (trailing slash).
  --you can ignore children without ignoring their parent.
  ignorePaths = {
    --general linux system paths (some are used by macOS too):
    ['/bin/']='1',['/boot/']='1',['/cdrom/']='1',['/dev/']='1',['/etc/']='1',['/lib/']='1',['/lib32/']='1',['/lib64/']='1',['/tmp/']='1',
    ['/srv/']='1',['/sys/']='1',['/snap/']='1',['/root/']='1',['/sbin/']='1',['/proc/']='1',['/opt/']='1',['/usr/']='1',['/run/']='1',
    --useless macOS system paths (some of these standard folders are actually files (symlinks) into /private/ subpaths, hence some repetition):
    ['/cores/']='1',['/etc']='1',['/installer.failurerequests']='1',['/net/']='1',['/private/']='1',['/tmp']='1',['/var']='1'
  },
  --ignore folders and files that match patterns regardless of where they exist on disk.
  --make sure you use ^ (start of string) and $ (end of string) to catch the whole str instead of risking partial false positives.
  --read about patterns at https://www.lua.org/pil/20.2.html or http://lua-users.org/wiki/PatternsTutorial
  ignorePatterns = {
    '^initrd%..*/?$', --hide files and folders folders starting with "initrd.<something>"
    '^vmlinuz.*/?$', --hide files and folders starting with "vmlinuz<something>"
    '^lost%+found/?$', --hide files and folders named "lost+found"
    '^.*%.log$', --ignore files with extension .log
    '^%$.*$', --ignore files starting with $
    '^System Volume Information/?$', --windows system folder
  },

  subtitleformats = {
    'srt', 'ass', 'ssa', 'sub', 'idx', 'sup', 'vtt', 'ttml', 'dfxp', 'smi', 'sami',
    'sbv', 'lrc', 'txt', 'rt', 'jss', 'aqt', 'pjs', 'psb', 'sbt', 'scc', 'stl',
    'mpl', 'mpl2', 'usf', 'ssf', 'cap', 'mks', 'dks', 'son', 'ttxt'
  },

  videoformats = {
    --common
    'mkv', 'mp4', 'm4v', 'avi', 'mov', 'qt', 'wmv', 'asf', 'flv', 'f4v', 'f4p', 'webm',
    --mpeg family and transport streams
    'mpg', 'mpeg', 'mpe', 'mpv', 'm1v', 'm2v', 'ts', 'm2ts', 'mts', 'tp', 'trp', 'tsv', 'vob', 'evo', 'dvr-ms', 'wtv',
    --mobile, web and misc containers
    '3gp', '3g2', '3gpp', 'ogv', 'ogm', 'ogx', 'rm', 'rmvb', 'divx', 'xvid', 'mk3d', 'mxf', 'nut', 'nsv', 'amv', 'mj2',
    --raw / elementary video streams
    'h264', '264', 'h265', '265', 'hevc', 'avc', 'av1', 'ivf', 'vp9', 'y4m', 'yuv', 'mjpeg', 'mjpg', 'dv',
    --game / other video and disc images
    'bik', 'smk', 'roq', 'iso'
  },

  navigator_menu_favkey = "f", --this key will always be bound when the menu is open, and is the key you use to cycle your favorites list!
  menu_timeout = true,         --menu timeouts and closes itself after navigator_duration seconds, else will be toggled by keybind
  navigator_duration = 13,     --osd duration before the navigator closes, if timeout is set to true
  visible_item_count = 10,     --how many menu items to show per screen

  --terminal output shown under the file list
  terminal_output_lines = 12,  --max lines of command output to show
  terminal_line_width = 110,   --max characters per output line

  --colours of the list, as RRGGBB hex (set to "" to use the default text colour)
  color_video = "4DA6FF",     --video files: blue
  color_subtitle = "5CE65C",  --subtitle files: green
  color_folder = "FFFFFF",    --folders: white
  color_other = "A0A0A0",     --any other file (only visible when only_media=false): grey
  color_queued = "1E3FD6",    --video appended to the playlist from the menu: dark blue
  color_subloaded = "009900", --subtitle loaded from the menu: dark green
  bold_selected = true,       --draw the selected item in bold

  --font size scales by window, if false requires larger font and padding sizes
  scale_by_window = true,
  --paddings from top left corner
  text_padding_x = 10,
  text_padding_y = 30,
  --ass style overrides inside curly brackets, \keyvalue is one field, extra \ for escape in lua
  --example {\\fnUbuntu\\fs10\\b0\\bord1} equals: font=Ubuntu, size=10, bold=no, border=1
  --read http://docs.aegisub.org/3.2/ASS_Tags/ for reference of tags
  --undeclared tags will use default osd settings
  --these styles will be used for the whole navigator
  style_ass_tags = "{}",
  --you can also use the ass tags mentioned above. For example:
  --selection_prefix="{\\c&HFF00FF&}● " - to add a color for selected file. However, if you
  --use ass tags you need to set them for both name and selection prefix (see https://github.com/jonniek/mpv-playlistmanager/issues/20)
  name_prefix = "○ ",
  selection_prefix = "● ",
}

mpopts.read_options(settings)

--RRGGBB (or #RRGGBB) to an ASS colour tag, ASS wants the bytes in BGR order
local function asscolor(rgb)
  local r, g, b = tostring(rgb or ""):match("^#?(%x%x)(%x%x)(%x%x)$")
  if not r then return "" end
  return "{\\1c&H"..b..g..r.."&}"
end
local col_video = asscolor(settings.color_video)
local col_subtitle = asscolor(settings.color_subtitle)
local col_folder = asscolor(settings.color_folder)
local col_other = asscolor(settings.color_other)
local col_queued = asscolor(settings.color_queued)
local col_subloaded = asscolor(settings.color_subloaded)

--escape a file or directory path for use in shell arguments
function escapepath(dir, escapechar)
  return string.gsub(dir, escapechar, '\\'..escapechar)
end

local sub_lookup = {}
for _, ext in ipairs(settings.subtitleformats) do
  sub_lookup[ext] = true
end

local video_lookup = {}
for _, ext in ipairs(settings.videoformats) do
  video_lookup[ext] = true
end

--common file extensions that are never folders; used by fast_scan to skip a stat() per file
local known_file_ext = {}
for ext in ([[pdf doc docx xls xlsx ppt pptx odt ods odp rtf csv tsv json xml yaml yml toml ini cfg conf log md
  html htm css js py lua sh bat cmd ps1 c cpp h java cs go rs php sql db sqlite bak tmp dll exe msi apk jar bin
  dat img dmg deb rpm zip rar 7z tar gz bz2 xz zst cab torrent jpg jpeg png gif bmp webp tif tiff svg ico heic
  raw psd ai mp3 flac wav aac m4a ogg opus wma aiff mid epub mobi azw3 djvu ttf otf woff lnk url crdownload
  part pkl npy pyc]]):gmatch("%S+") do
  known_file_ext[ext] = true
end


--ensures directories never accidentally end in "//" due to our added slash
function stripdoubleslash(dir)
  if (string.sub(dir, -2) == "//") then
    return string.sub(dir, 1, -2) --negative 2 removes the last character
  else
    return dir
  end
end

function os.capture(cmd, raw)
  local f = assert(io.popen(cmd, 'r'))
  local s = assert(f:read('*a'))
  f:close()
  return string.sub(s, 0, -2)
end

---------------------------------------------------------------------------
-- small helpers
---------------------------------------------------------------------------

local function trim(s)
  return (s:gsub("^%s+", ""):gsub("%s+$", ""))
end

--escape text so libass shows it literally (same method mpv's own escape-ass uses)
local function esc(s)
  s = tostring(s or "")
  s = s:gsub("[\\{}]", function(c)
    if c == "\\" then return "\\\239\187\191" end
    return "\\"..c
  end)
  s = s:gsub("\r?\n", "\\N")
  return s
end

--cut a string to n utf-8 characters
local function clip(s, n)
  local count, out = 0, {}
  for ch in s:gmatch("[\1-\127\194-\244][\128-\191]*") do
    count = count + 1
    if count > n then
      out[#out + 1] = "..."
      break
    end
    out[#out + 1] = ch
  end
  return table.concat(out)
end

local function withsep(p)
  local sep = ON_WINDOWS and SEPARATOR_WINDOWS or SEPARATOR
  if p:sub(-1) ~= sep then return p..sep end
  return p
end

--collapse "." and ".." in a windows path, always uses backslashes
local function normpath_win(p)
  p = p:gsub("/", "\\")
  local prefix, rest = "", p
  local drive = p:match("^(%a:)")
  if drive then
    prefix = drive
    rest = p:sub(3)
  elseif p:sub(1, 2) == "\\\\" then
    local server, share, r = p:match("^\\\\([^\\]+)\\([^\\]+)(.*)$")
    if not server then return p end
    prefix = "\\\\"..server.."\\"..share
    rest = r
  end
  local abs = rest:sub(1, 1) == "\\"
  local parts = {}
  for seg in rest:gmatch("[^\\]+") do
    if seg == "." then
      -- skip
    elseif seg == ".." then
      if #parts > 0 and parts[#parts] ~= ".." then
        table.remove(parts)
      elseif not abs then
        parts[#parts + 1] = ".."
      end
    else
      parts[#parts + 1] = seg
    end
  end
  return prefix..(abs and "\\" or "")..table.concat(parts, "\\")
end

local function normpath_posix(p)
  local parts = {}
  for seg in p:gmatch("[^/]+") do
    if seg == "." then
      -- skip
    elseif seg == ".." then
      table.remove(parts)
    else
      parts[#parts + 1] = seg
    end
  end
  return "/"..table.concat(parts, "/")
end

--make a path absolute relative to the folder shown in the navigator
local function abspath(p)
  if ON_WINDOWS then
    p = p:gsub("/", "\\")
    if p:match("^%a:\\") or p:match("^\\\\") then return normpath_win(p) end
    if p:match("^%a:") then return normpath_win(p:sub(1, 2).."\\"..p:sub(3)) end
    if p:sub(1, 1) == "\\" then return normpath_win(path:sub(1, 2)..p) end
    return normpath_win(withsep(path)..p)
  end
  if p:sub(1, 1) == "/" then return normpath_posix(p) end
  return normpath_posix(withsep(path)..p)
end

--split a command line into words, honours "double" and 'single' quotes
local function tokenize(line)
  local tokens, cur, quote, has = {}, {}, nil, false
  for i = 1, #line do
    local c = line:sub(i, i)
    if quote then
      if c == quote then quote = nil else cur[#cur + 1] = c end
    elseif c == '"' or (c == "'" and #cur == 0 and not has) then
      quote = c
      has = true
    elseif c:match("%s") then
      if #cur > 0 or has then
        tokens[#tokens + 1] = table.concat(cur)
        cur, has = {}, false
      end
    else
      cur[#cur + 1] = c
    end
  end
  if quote then return nil, "unterminated quote" end
  if #cur > 0 or has then tokens[#tokens + 1] = table.concat(cur) end
  return tokens
end

---------------------------------------------------------------------------
-- marks: files appended to the playlist (red) and subtitles loaded (dark green)
---------------------------------------------------------------------------

marks_video = {}
marks_sub = {}

--comparable form of a path (windows ignores case and slash direction)
function keyof(p)
  if ON_WINDOWS then
    return (p:gsub("/", "\\"):lower())
  end
  return p
end

function fullpath_of(name)
  local fp = utils.join_path(path, name)
  if ON_WINDOWS then fp = fp:gsub(SEPARATOR, SEPARATOR_WINDOWS) end
  return fp
end

--forget marks for files that are no longer in the playlist / no longer loaded as subtitles
function prune_marks()
  if next(marks_video) then
    local keep = {}
    for _, e in ipairs(mp.get_property_native("playlist") or {}) do
      if e.filename then keep[keyof(e.filename)] = true end
    end
    for k in pairs(marks_video) do
      if not keep[k] then marks_video[k] = nil end
    end
  end
  if next(marks_sub) then
    local keep = {}
    for _, t in ipairs(mp.get_property_native("track-list") or {}) do
      if t.type == "sub" and t.external and t["external-filename"] then
        keep[keyof(t["external-filename"])] = true
      end
    end
    for k in pairs(marks_sub) do
      if not keep[k] then marks_sub[k] = nil end
    end
  end
end

---------------------------------------------------------------------------
-- file type filter
---------------------------------------------------------------------------

local function extension(file)
  local ext = file:match("^.+%.(.+)$")
  return ext and ext:lower()
end

function issubtitle(file)
  local ext = file:match("^.+%.(.+)$")
  return ext and sub_lookup[ext:lower()]
end

function isvideo(file)
  local ext = extension(file)
  return ext and video_lookup[ext]
end

local function wanted(name, isdirectory)
  if isdirectory or not settings.only_media then return true end
  return isvideo(name) or issubtitle(name)
end

local function ignored(name, isdirectory, searchdir)
  for _, pattern in pairs(settings.ignorePatterns) do
    if name:find(pattern) or (isdirectory and (name.."/"):find(pattern)) then
      return true --don't waste time scanning further patterns
    end
  end
  local sep = ON_WINDOWS and SEPARATOR_WINDOWS or SEPARATOR
  local base = withsep(searchdir)
  if settings.ignorePaths[base..name] then return true end
  if isdirectory and settings.ignorePaths[base..name..sep] then return true end
  return false
end

--sort key so that "ep2" comes before "ep10"
local function sortkey(name)
  return (name:lower():gsub("%d+", function(n)
    if #n < 12 then return ("0"):rep(12 - #n)..n end
    return n
  end))
end

---------------------------------------------------------------------------
-- state and drawing
---------------------------------------------------------------------------

dir = nil
isdir = {}
path = nil
cursor = 0
length = 0
nav_visible = false
term_open = false
term_output = ""
filter_text = ""
filter_open = false

--draws the menu (no keybind or timer changes, so it is safe while the prompt is open)
function render()
  --the terminal prompt owns the screen while it is open, so the menu stays hidden to avoid overlapping text
  if term_open then return end
  local ass = assdraw.ass_new()
  ass:new_event()
  ass:pos(settings.text_padding_x, settings.text_padding_y)
  ass:append(settings.style_ass_tags)
  ass:append(esc(path).."\\N")
  if filter_text ~= "" then
    ass:append("filter: "..esc(filter_text).."  ("..length.." found)\\N")
  end
  ass:append("\\N")
  local b = cursor - math.floor(settings.visible_item_count / 2)
  if b > 0 then ass:append("...\\N") end
  if b < 0 then b=0 end
  if length == 0 then
    ass:append((settings.only_media and "(no videos, subtitles or folders here)" or "(empty)").."\\N")
  end
  for a=b,(b+settings.visible_item_count),1 do
    if a==length then break end
    local prefix = (a == cursor and settings.selection_prefix or settings.name_prefix)
    local name = dir[a]
    local color
    if isdir[a] then
      color = col_folder
      name = name..(ON_WINDOWS and SEPARATOR_WINDOWS or SEPARATOR)
    elseif issubtitle(name) then
      color = col_subtitle
    elseif isvideo(name) then
      color = col_video
    else
      color = col_other
    end
    if not isdir[a] and (next(marks_video) or next(marks_sub)) and not (ON_WINDOWS and WINDOWS_ROOTDIR) then
      local k = keyof(fullpath_of(name))
      if marks_sub[k] and col_subloaded ~= "" then
        color = col_subloaded
      elseif marks_video[k] and col_queued ~= "" then
        color = col_queued
      end
    end
    local bold = ""
    if settings.bold_selected then bold = (a == cursor) and "{\\b1}" or "{\\b0}" end
    ass:append(color..bold..prefix..esc(name).."\\N")
    if a == (b+settings.visible_item_count) then
      ass:append("...")
    end
  end
  if term_output ~= "" then
    ass:append("{\\1c&HFFFFFF&\\b0}\\N{\\fscx85\\fscy85}--- terminal ---\\N")
    for line in (term_output.."\n"):gmatch("(.-)\n") do
      ass:append(esc(line).."\\N")
    end
  end
  local w, h = mp.get_osd_size()
  if settings.scale_by_window then w,h = 0, 0 end
  mp.set_osd_ass(w, h, ass.text)
end

--osd handler that displays your navigation and information
function handler()
  add_keybinds()
  timer:kill()
  nav_visible = true

  if not path then
    if mp.get_property('path') and not settings.forcedefault then
      --determine path from currently playing file...
      local workingdir = mp.get_property("working-directory")
      local playfilename = mp.get_property("filename") --just the filename, without path
      local playpath = mp.get_property("path") --can be relative or absolute depending on what args mpv was given
      local firstchar = string.sub(playpath, 1, 1)
      --first we need to remove the filename (may give us empty path if mpv was started in same dir as file)
      path = string.sub(playpath, 1, string.len(playpath)-string.len(playfilename))
      if (firstchar ~= "/" and not ON_WINDOWS) then --the path of the playing file wasn't absolute, so we need to add mpv's working dir to it
        path = workingdir.."/"..path
      end
      --now resolve that path (to resolve things like "/home/anon/Movies/../Movies/foo.mkv")
      path = resolvedir(path)
      --lastly, check if the folder exists, and if not then fall back to the current mpv working dir
      if (not isfolder(path)) then
        if ON_WINDOWS then
          path = workingdir..SEPARATOR_WINDOWS
        else
          path = workingdir
        end
      end
    else path = withsep(settings.defaultpath) end
    dir,length = scandirectory(path)
  end
  render()
  if settings.menu_timeout and not term_open and not filter_open then
    timer:resume()
  end
end

function navdown()
  if cursor~=length-1 then
    cursor = cursor+1
  else
    cursor = 0
  end
  handler()
end

function navup()
  if cursor~=0 then
    cursor = cursor-1
  else
    cursor = length-1
  end
  handler()
end

function movepageup()
  if cursor == 0 then return end
  local prev_cursor = cursor
  cursor = cursor - settings.visible_item_count
  if cursor < 0 then cursor = 0 end
  handler()
end

function movepagedown()
  if cursor == length-1 then return end
  local prev_cursor = cursor
  cursor = cursor + settings.visible_item_count
  if cursor >= length then cursor = length-1 end
  handler()
end

--moves into selected directory, or appends to playlist incase of file
function childdir()
  local item = dir[cursor]

  -- windows only
  if ON_WINDOWS then
    if WINDOWS_ROOTDIR then
      WINDOWS_ROOTDIR = false
    end
    if item then
      local newdir = utils.join_path(path, item):gsub(SEPARATOR, SEPARATOR_WINDOWS)..SEPARATOR_WINDOWS
      local info, error = utils.file_info(newdir)

      if info and info.is_dir then
        changepath(newdir)
      else
        append_or_load(item)
        handler()
      end
    end

    return
  end

  if item then
    if isfolder(utils.join_path(path, item)) then
      local newdir = stripdoubleslash(utils.join_path(path, dir[cursor].."/"))
      changepath(newdir)
    else
      append_or_load(item)
      handler()
    end
  end
end

function loadsubs(file)
  local k = keyof(file)
  if marks_sub[k] then
    --already loaded: select that track instead of adding a duplicate
    for _, t in ipairs(mp.get_property_native("track-list") or {}) do
      if t.type == "sub" and t.external and t["external-filename"] and keyof(t["external-filename"]) == k then
        mp.set_property_number("sid", t.id)
        mp.osd_message("Subtitle already loaded, selected: "..file)
        return
      end
    end
  end
  mp.commandv("sub_add", file)
  marks_sub[k] = true
  mp.osd_message("Loaded subtitle: "..file)
end

--Right arrow on a file: subtitles are loaded, anything else is appended to the playlist
function append_or_load(item)
  local fp = fullpath_of(item)
  if issubtitle(item) then
    loadsubs(fp)
    return
  end
  local k = keyof(fp)
  if marks_video[k] then
    mp.osd_message("Already in playlist: "..item)
    return
  end
  mp.commandv("loadfile", fp, "append-play")
  marks_video[k] = true
  mp.osd_message("Appended file to playlist: "..item)
end

--replace current playlist with directory or file
--if directory, mpv will recursively queue all items found in the directory and its subfolders
function opendir()
  local item = dir[cursor]

  if item then
    local filepath = utils.join_path(path, item)
    if ON_WINDOWS then
      filepath = filepath:gsub(SEPARATOR, SEPARATOR_WINDOWS)
    end

    if issubtitle(item) then
      remove_keybinds()
      return loadsubs(filepath)
    end

    --start loading first, closing the menu can wait
    mp.commandv("loadfile", filepath, "replace")
    remove_keybinds()
  end
end

--changes the directory to the path in argument
function changepath(args)
  path = args
  filter_text = ""
  if WINDOWS_ROOTDIR then
    path = WINDOWS_ROOT_DESC
  end
  dir,length = scandirectory(path)
  cursor=0
  handler()
end

--move up to the parent directory
function parentdir()
  -- windows only
  if ON_WINDOWS then
    if path:sub(-1) == SEPARATOR_WINDOWS then
      path = path:sub(1, -2)
    end
    local parent = utils.split_path(path)
    if path == parent then
      WINDOWS_ROOTDIR = true
    end
    changepath(parent)
    return
  end

  changepath(withsep(normpath_posix(withsep(path).."..")))
end

--resolves relative paths such as "/home/foo/../foo/Music" (to "/home/foo/Music") if the folder exists!
function resolvedir(dir)
  -- windows only (pure lua, no cmd.exe process needed)
  if ON_WINDOWS then
    local workingdir = mp.get_property("working-directory") or ""
    local p = dir:gsub("/", "\\")
    if not (p:match("^%a:\\") or p:match("^\\\\")) then
      p = withsep(workingdir)..p
    end
    return withsep(normpath_win(p))
  end

  return withsep(normpath_posix(dir))
end

--true if path exists and is a folder, otherwise false
function isfolder(dir)
  -- windows only
  if ON_WINDOWS then
    local info, error = utils.file_info(dir)
    return info and info.is_dir or nil
  end

  local info = utils.file_info(dir)
  return info and info.is_dir or false
end

function scandirectory_raw(searchdir)
  local directory = {}
  isdir = {}
  --folders and files are listed with mpv's own readdir on every OS (no ls, no shell, safe for any file name)
  --hidden files ("." prefix) are skipped on Linux/macOS, since they never contain media

  -- windows only: the drive list (checks A: to Z: directly, no wmic needed)
  if ON_WINDOWS and WINDOWS_ROOTDIR then
    local i = 0
    for c = 65, 90 do
      local drive = string.char(c)..":"
      if utils.file_info(drive..SEPARATOR_WINDOWS) then
        directory[i] = drive
        isdir[i] = true
        i = i + 1
      end
    end
    return directory, i
  end

  --one directory read, no stat() per entry
  local names, rerr = utils.readdir(searchdir, "all")
  if not names then
    mp.msg.error("Could not scan for files :"..(rerr or ""))
    return directory, 0
  end

  local base = withsep(searchdir)
  local dirset = nil
  if not settings.fast_scan then
    --exact mode: ask mpv which entries are folders (one stat per entry)
    dirset = {}
    for _, n in ipairs(utils.readdir(searchdir, "dirs") or {}) do dirset[n] = true end
  end

  local entries = {}
  for _, name in ipairs(names) do
    if name ~= "." and name ~= ".." and (ON_WINDOWS or name:sub(1, 1) ~= ".") then
      local isdirectory
      if dirset then
        isdirectory = dirset[name] or false
      else
        local ext = extension(name)
        if ext and (video_lookup[ext] or sub_lookup[ext] or known_file_ext[ext]) then
          isdirectory = false --known file type, no need to ask the file system
        else
          local info = utils.file_info(base..name)
          isdirectory = info and info.is_dir or false
        end
      end
      if wanted(name, isdirectory) and not ignored(name, isdirectory, searchdir) then
        entries[#entries + 1] = { name = name, dir = isdirectory, key = sortkey(name) }
      end
    end
  end
  table.sort(entries, function(a, b)
    if a.dir ~= b.dir then return a.dir end
    return a.key < b.key
  end)

  local i = 0
  for _, e in ipairs(entries) do
    directory[i] = e.name
    isdir[i] = e.dir
    i = i + 1
  end
  return directory, i
end

--the last folder listing is kept, and reused while the folder's modified time is unchanged
scan_cache = nil
function invalidate_scan() scan_cache = nil end

--same as scandirectory_raw (but cached), and only keeps names containing every word of the filter
function scandirectory(searchdir)
  local d, n
  if ON_WINDOWS and WINDOWS_ROOTDIR then
    d, n = scandirectory_raw(searchdir)
  else
    local info = utils.file_info(searchdir)
    local mtime = info and info.mtime
    if scan_cache and mtime and scan_cache.path == searchdir and scan_cache.mtime == mtime then
      d, n, isdir = scan_cache.dir, scan_cache.n, scan_cache.isdir
    else
      d, n = scandirectory_raw(searchdir)
      scan_cache = mtime and { path = searchdir, mtime = mtime, dir = d, n = n, isdir = isdir } or nil
    end
  end
  if filter_text == "" then return d, n end
  local terms = {}
  for w in filter_text:lower():gmatch("%S+") do terms[#terms + 1] = w end
  if #terms == 0 then return d, n end
  local out, outdir, j = {}, {}, 0
  for i = 0, n - 1 do
    local lname = d[i]:lower()
    local ok = true
    for _, t in ipairs(terms) do
      if not lname:find(t, 1, true) then
        ok = false
        break
      end
    end
    if ok then
      out[j] = d[i]
      outdir[j] = isdir[i]
      j = j + 1
    end
  end
  isdir = outdir
  return out, j
end

favcursor = 1
function cyclefavorite()
  local firstpath = settings.favorites[1]
  if not firstpath then return end
  local favpath = nil
  local favlen = 0
  for key, fav in pairs(settings.favorites) do
    favlen = favlen + 1
    if key == favcursor then favpath = fav end
  end
  if favpath then
    changepath(favpath)
    favcursor = favcursor + 1
  else
    changepath(firstpath)
    favcursor = 2
  end
end

---------------------------------------------------------------------------
-- built-in terminal
---------------------------------------------------------------------------

local HELP_TEXT = table.concat({
  "cd <dir> | cd .. | cd ~ | cd - | D:      change folder",
  "ls [-l] [-a]                             list files",
  "cp [-r] <src...> <dest>                  copy",
  "mv <src...> <dest>                       move / rename",
  "rm [-r] [-f] <file...>                   delete",
  "mkdir <dir...>   touch <file...>   cat <file>   pwd   clear   exit",
  "Anything else runs in "..(ON_WINDOWS and "PowerShell" or "sh").." in the current folder.",
  "Wildcards (*.srt) work. Use \"quotes\" for names with spaces.",
  "Tab = complete name, Up/Down = history, Esc = back to menu.",
  "In the menu: / = filter the list by name.",
}, "\n")

local term_submitted = false
local term_exit = false
local prev_path = nil

--keeps output short enough to fit on screen
local function format_output(text)
  text = text:gsub("^\239\187\191", ""):gsub("\r", ""):gsub("\t", "    ")
  text = text:gsub("%s+$", "")
  local lines, total = {}, 0
  for line in (text.."\n"):gmatch("(.-)\n") do
    total = total + 1
    if total <= settings.terminal_output_lines then
      lines[#lines + 1] = clip(line, settings.terminal_line_width)
    end
  end
  if total > settings.terminal_output_lines then
    lines[#lines + 1] = "... ("..(total - settings.terminal_output_lines).." more lines)"
  end
  return table.concat(lines, "\n")
end

local term_pending = nil
local term_cmd_echo = nil
local term_clear_log = false

--push what the last command printed into the console's own log (shown above the prompt)
local function flush_term_log()
  if not term_open or not input then return end
  if term_clear_log then
    term_clear_log = false
    if input.set_log then pcall(input.set_log, {}) end
  end
  if not input.log then return end
  if term_cmd_echo then
    pcall(input.log, "> "..term_cmd_echo)
    term_cmd_echo = nil
  end
  if term_pending and term_pending ~= "" then
    for line in (term_pending.."\n"):gmatch("(.-)\n") do
      pcall(input.log, line)
    end
  end
  term_pending = nil
end

local function set_output(text)
  term_output = format_output(text or "")
  term_pending = term_output
  flush_term_log()
end

--re-read the current folder after a command changed something
local function rescan()
  invalidate_scan()
  dir, length = scandirectory(path)
  if cursor >= length then cursor = length - 1 end
  if cursor < 0 then cursor = 0 end
end

local function home_dir()
  return withsep(userhome)
end

local function cmd_cd(rest)
  if rest:lower():match("^/d%s") or rest:lower() == "/d" then
    rest = trim(rest:sub(3))
  end
  if #rest >= 2 and rest:match('^".*"$') then rest = rest:sub(2, -2) end

  local target
  if rest == "" or rest == "~" then
    target = home_dir()
  elseif rest == "-" then
    target = prev_path
    if not target then set_output("cd: no previous folder") return end
  elseif rest:match("^~[\\/]") then
    target = home_dir()..rest:sub(3)
  elseif ON_WINDOWS and rest:match("^%a:$") then
    target = rest..SEPARATOR_WINDOWS
  else
    target = rest
  end

  local full
  if ON_WINDOWS and WINDOWS_ROOTDIR then
    local t = target:gsub("/", "\\")
    if not t:match("^%a:") then
      set_output("cd: pick a drive first, for example: cd C:")
      return
    end
    full = abspath(t)
  else
    full = abspath(target)
  end

  if not isfolder(withsep(full)) then
    set_output("cd: no such folder: "..rest)
    return
  end

  if not WINDOWS_ROOTDIR then prev_path = path end
  WINDOWS_ROOTDIR = false
  path = withsep(full)
  filter_text = ""
  dir, length = scandirectory(path)
  cursor = 0
  term_output = ""
end

--quote a string for a PowerShell single-quoted literal
local function psq(s)
  local r = s:gsub("'", "''")
  --PowerShell also treats curly quotes as quote characters
  r = r:gsub("\226\128[\152-\155]", function(c) return c..c end)
  return "'"..r.."'"
end

--quote a string for sh
local function shq(s)
  local r = s:gsub("'", "'\\''")
  return "'"..r.."'"
end

--turns "-rf", "-la", "--force" into flags and returns the remaining words
local function parse_args(tokens)
  local flags, ops = {}, {}
  local no_more_flags = false
  for _, t in ipairs(tokens) do
    if not no_more_flags and t == "--" then
      no_more_flags = true
    elseif not no_more_flags and t:match("^%-%a+$") then
      for c in t:sub(2):gmatch(".") do flags[c] = true end
    elseif not no_more_flags and t:match("^%-%-%a[%w-]*$") then
      flags[t:sub(3)] = true
    else
      ops[#ops + 1] = t
    end
  end
  if flags.recursive or flags.R then flags.r = true end
  if flags.force then flags.f = true end
  if flags.all then flags.a = true end
  return flags, ops
end

--PowerShell expression that returns the files an argument list refers to
local function ps_items(ops)
  local parts = {}
  for _, o in ipairs(ops) do
    if o:find("[*?]") then
      parts[#parts + 1] = "(Get-ChildItem -Path "..psq(o).." -Force)"
    else
      parts[#parts + 1] = "(Get-Item -LiteralPath "..psq(o).." -Force)"
    end
  end
  return "@("..table.concat(parts, "; ")..")"
end

local function ps_mapped(body)
  return "$ErrorActionPreference='Stop'; try{ "..body.." }catch{ [Console]::Error.WriteLine($_.Exception.Message); exit 1 }"
end

--refuse to delete things like C:\ or the user folder
local function is_protected(p)
  local n = normpath_win(p):lower():gsub("\\+$", "")
  if n:match("^%a:$") then return true end
  for _, var in ipairs({ "USERPROFILE", "WINDIR", "PROGRAMFILES", "SYSTEMROOT" }) do
    local v = os.getenv(var)
    if v then
      local vn = normpath_win(v):lower():gsub("\\+$", "")
      if n == vn then return true end
    end
  end
  return false
end

--linux/macOS: refuse to delete system folders or the home folder (best effort, literal paths only)
local function is_protected_posix(p)
  p = normpath_posix(p)
  local list = { "/", "/home", "/usr", "/etc", "/boot", "/bin", "/sbin", "/lib", "/lib64",
                 "/var", "/opt", "/root", "/dev", "/sys", "/proc", userhome }
  for _, v in ipairs(list) do
    if normpath_posix(v) == p then return true end
  end
  return false
end

--translates common unix commands to PowerShell, returns script or nil, error
local function build_ps(cmd, flags, ops)
  if cmd == "ls" then
    local segs = {}
    if #ops == 0 then ops = { "." } end
    for _, o in ipairs(ops) do
      local param = o:find("[*?]") and "-Path " or "-LiteralPath "
      local seg = "Get-ChildItem "..param..psq(o)..(flags.a and " -Force" or "")
      if flags.l then
        seg = seg.." | Format-Table Mode,LastWriteTime,Length,Name -AutoSize | Out-String -Width 200"
      else
        seg = seg.." | ForEach-Object { if($_.PSIsContainer){$_.Name+'\\'}else{$_.Name} }"
      end
      segs[#segs + 1] = seg
    end
    return ps_mapped(table.concat(segs, "; "))

  elseif cmd == "cp" or cmd == "mv" then
    if #ops < 2 then
      return nil, "usage: "..cmd.." "..(cmd == "cp" and "[-r] " or "").."<source...> <destination>"
    end
    local dest = table.remove(ops)
    local body = "$s="..ps_items(ops).."; if($s.Count -eq 0){throw 'no matching files'}; "
    body = body.."if($s.Count -gt 1 -and -not (Test-Path -LiteralPath "..psq(dest).." -PathType Container)){throw 'target is not a folder'}; "
    if cmd == "cp" then
      if not flags.r then
        body = body.."if($s | Where-Object {$_.PSIsContainer}){throw 'omitting folder (use cp -r)'}; "
      end
      body = body.."$s | Copy-Item -Destination "..psq(dest).." -Force"..(flags.r and " -Recurse" or "")
    else
      body = body.."$s | Move-Item -Destination "..psq(dest).." -Force"
    end
    return ps_mapped(body)

  elseif cmd == "rm" then
    if #ops == 0 then return nil, "usage: rm [-r] [-f] <file...>" end
    for _, o in ipairs(ops) do
      local target = o
      if o:find("[*?]") then target = o:match("^(.*)[\\/][^\\/]*$") or "." end
      if is_protected(abspath(target)) then
        return nil, "rm: refusing to remove protected folder: "..o
      end
    end
    local body = "$s="..ps_items(ops).."; "
    if not flags.f then body = body.."if($s.Count -eq 0){throw 'no matching files'}; " end
    if flags.r then
      body = body.."foreach($i in $s){ Remove-Item -LiteralPath $i.FullName -Recurse -Force }"
    else
      body = body.."foreach($i in $s){ if($i.PSIsContainer){throw ('is a folder (use rm -r): '+$i.Name)}; Remove-Item -LiteralPath $i.FullName -Force }"
    end
    return ps_mapped(body)

  elseif cmd == "mkdir" then
    if #ops == 0 then return nil, "usage: mkdir <folder...>" end
    local segs = {}
    for _, o in ipairs(ops) do
      segs[#segs + 1] = "New-Item -ItemType Directory -Force -Path "..psq(o).." | Out-Null"
    end
    return ps_mapped(table.concat(segs, "; "))

  elseif cmd == "touch" then
    if #ops == 0 then return nil, "usage: touch <file...>" end
    local segs = {}
    for _, o in ipairs(ops) do
      segs[#segs + 1] = "if(Test-Path -LiteralPath "..psq(o).."){(Get-Item -LiteralPath "..psq(o)..").LastWriteTime=Get-Date}else{New-Item -ItemType File -Path "..psq(o).." | Out-Null}"
    end
    return ps_mapped(table.concat(segs, "; "))

  elseif cmd == "cat" then
    if #ops == 0 then return nil, "usage: cat <file...>" end
    local segs = {}
    for _, o in ipairs(ops) do
      segs[#segs + 1] = "Get-Content -LiteralPath "..psq(o).." -Encoding UTF8"
    end
    return ps_mapped(table.concat(segs, "; "))
  end
end

--runs a program without blocking mpv, shows its output when it finishes
local function run_async(args)
  set_output("running...")
  mp.command_native_async({
    name = "subprocess",
    args = args,
    capture_stdout = true,
    capture_stderr = true,
    playback_only = false,
  }, function(success, res, err)
    local out
    if not success or not res then
      out = "failed to start: "..tostring(err)
    else
      out = res.stdout or ""
      local e = res.stderr or ""
      if e ~= "" then out = out..(out ~= "" and "\n" or "")..e end
      if res.error_string and res.error_string ~= "" then
        out = out.."\n["..res.error_string.."]"
      end
      if out:match("^%s*$") then
        out = (res.status == 0) and "done" or ("exit code "..tostring(res.status))
      elseif res.status ~= 0 then
        out = out.."\n[exit code "..tostring(res.status).."]"
      end
    end
    set_output(out)
    rescan()
    if nav_visible then render() end --does nothing while the prompt is open
  end)
end

local function run_ps(body)
  local script = "try{[Console]::OutputEncoding=[Text.Encoding]::UTF8}catch{}; $ProgressPreference='SilentlyContinue'; "
    .."Set-Location -LiteralPath "..psq(path).."; "..body
  run_async({ "powershell.exe", "-NoLogo", "-NoProfile", "-NonInteractive", "-ExecutionPolicy", "Bypass", "-Command", script })
end

--instant rename in lua, returns a message or nil when powershell should handle it
local function fast_move(ops)
  if #ops ~= 2 or ops[1]:find("[*?]") or ops[2]:find("[*?]") then return nil end
  local src, dst = abspath(ops[1]), abspath(ops[2])
  if not utils.file_info(src) then return nil end
  local dinfo = utils.file_info(dst)
  if dinfo and dinfo.is_dir then
    dst = withsep(dst)..(src:match("([^\\/]+)[\\/]*$") or "")
    dinfo = utils.file_info(dst)
  end
  if dinfo then return nil end --destination exists, let PowerShell overwrite properly
  if os.rename(src, dst) then return "moved: "..ops[1].." -> "..ops[2] end
  return nil
end

--runs one line typed into the terminal prompt
function run_command(line)
  line = trim(line)
  if line == "" then return end
  local cmd = line:match("^(%S+)")
  local rest = trim(line:sub(#cmd + 1))
  local lcmd = cmd:lower()

  if lcmd == "cd" or lcmd == "chdir" then return cmd_cd(rest) end
  if lcmd == "cd.." then return cmd_cd("..") end
  if ON_WINDOWS and lcmd:match("^%a:$") then return cmd_cd(lcmd) end
  if lcmd == "pwd" then set_output(WINDOWS_ROOTDIR and "(drive list)" or path) return end
  if lcmd == "clear" or lcmd == "cls" then
    term_output = ""
    term_pending = nil
    term_clear_log = true
    return
  end
  if lcmd == "help" or lcmd == "?" then set_output(HELP_TEXT) return end
  if lcmd == "exit" or lcmd == "quit" then term_exit = true return end

  if ON_WINDOWS and WINDOWS_ROOTDIR then
    set_output("pick a drive first, for example: cd C:")
    return
  end

  if ON_WINDOWS then
    local tokens, terr = tokenize(rest)
    if not tokens then set_output(terr) return end
    local flags, ops = parse_args(tokens)
    if lcmd == "mv" then
      local msg = fast_move(ops)
      if msg then
        set_output(msg)
        rescan()
        return
      end
    end
    local script, err = build_ps(lcmd, flags, ops)
    if err then set_output(err) return end
    --not a mapped command: run the line as typed in PowerShell
    run_ps(script or line)
  else
    if lcmd == "rm" then
      local tokens = tokenize(rest) or {}
      local _, ops = parse_args(tokens)
      for _, o in ipairs(ops) do
        if o == "~" or o:sub(1, 2) == "~/" then o = userhome..o:sub(2) end
        local target = o
        if o:find("[*?]") then
          target = o:match("^(.*)/[^/]*$") or "."
          if target == "" then target = "/" end
        end
        if is_protected_posix(abspath(target)) then
          set_output("rm: refusing to remove protected folder: "..o)
          return
        end
      end
    end
    run_async({ "/bin/sh", "-c", "cd "..shq(path).." && "..line })
  end
end

--tab completion for names in the current folder
local function complete_names(before)
  local space = before:match("^.*()%s")
  local word_start = (space or 0) + 1
  local word = before:sub(word_start)
  local quoted = word:sub(1, 1) == '"'
  if quoted then word = word:sub(2) end

  local dirpart = word:match("^(.*[\\/])") or ""
  local prefix = word:sub(#dirpart + 1)
  local base = path
  if dirpart ~= "" then base = abspath(dirpart) end
  if ON_WINDOWS and WINDOWS_ROOTDIR then return {}, word_start end

  local names = {}
  for _, n in ipairs(utils.readdir(base, "all") or {}) do
    if n ~= "." and n ~= ".." then names[#names + 1] = n end
  end
  local sep = ON_WINDOWS and SEPARATOR_WINDOWS or SEPARATOR
  local out = {}
  local lp = ON_WINDOWS and prefix:lower() or prefix
  for _, n in ipairs(names) do
    local cmpn = ON_WINDOWS and n:lower() or n
    if cmpn:sub(1, #lp) == lp then
      local info = utils.file_info(withsep(base)..n) --only matching names are checked
      local cand = dirpart..n..((info and info.is_dir) and sep or "")
      if quoted or n:find("%s") then cand = '"'..cand end
      out[#out + 1] = cand
    end
  end
  table.sort(out, function(a, b) return a:lower() < b:lower() end)
  return out, word_start
end

--opens the terminal prompt (uses mpv's console), keeps reopening after each command
function open_terminal(fresh)
  if not ensure_input() then
    mp.osd_message("Terminal needs mpv 0.38 or newer (mp.input).", 4)
    return
  end
  term_open = true
  term_submitted = false
  term_exit = false
  timer:kill()
  mp.set_osd_ass(0, 0, "") --hide the menu while typing

  local shown = WINDOWS_ROOTDIR and "drives" or path
  shown = clip(shown:sub(-40), 60)

  input.get({
    prompt = shown.."> ",
    id = "navigator-terminal",
    submit = function(text)
      term_submitted = true
      term_cmd_echo = trim(text or "")
      if term_cmd_echo == "" then term_cmd_echo = nil end
      local ok, err = pcall(run_command, text or "")
      if not ok then set_output("error: "..tostring(err)) end
      input.terminate()
    end,
    complete = function(before)
      local ok, cands, pos = pcall(complete_names, before)
      if ok then return cands, pos end
      return {}, 1
    end,
    closed = function()
      if not term_open then return end
      term_open = false
      if term_submitted and not term_exit then
        open_terminal(false) --keep the prompt going, the menu stays hidden
      else
        handler() --back to the menu: redraw it and restore its keys
      end
    end,
  })

  if fresh then
    --start with an empty console log so old lines never sit under the prompt
    term_pending = nil
    term_clear_log = true
  end
  flush_term_log()
end

function start_terminal()
  if not nav_visible or not path then handler() end
  open_terminal(true)
end

---------------------------------------------------------------------------
-- filter
---------------------------------------------------------------------------

local filter_submitted = false

local function refilter()
  dir, length = scandirectory(path)
  cursor = 0
end

--type part of a name and the list narrows live. Enter keeps the filter, Esc clears it
function open_filter()
  if not ensure_input() then
    mp.osd_message("Filter needs mpv 0.38 or newer (mp.input).", 4)
    return
  end
  if not nav_visible or not path then handler() end
  filter_open = true
  filter_submitted = false
  timer:kill()

  input.get({
    prompt = "filter: ",
    id = "navigator-filter",
    default_text = filter_text,
    edited = function(text)
      filter_text = text or ""
      refilter()
      render()
    end,
    submit = function(text)
      filter_submitted = true
      filter_text = trim(text or "")
      refilter()
      input.terminate()
    end,
    closed = function()
      if not filter_open then return end
      filter_open = false
      if not filter_submitted then
        filter_text = ""
        refilter()
      end
      handler() --redraw the menu and restore its keys
    end,
  })
  if input.set_log then pcall(input.set_log, {}) end --no stale console lines under the list
end

---------------------------------------------------------------------------
-- keybinds
---------------------------------------------------------------------------

function add_keybinds()
  mp.add_forced_key_binding(settings.key_navdown, "navdown", navdown, "repeatable")
  mp.add_forced_key_binding(settings.key_navup, "navup", navup, "repeatable")
  mp.add_forced_key_binding(settings.key_navopen, "navopen", opendir)
  mp.add_forced_key_binding(settings.key_navforward, "navforward", childdir)
  mp.add_forced_key_binding(settings.key_navback, "navback", parentdir)
  mp.add_forced_key_binding(settings.key_navfavorites, "navfavorites", cyclefavorite)
  mp.add_forced_key_binding(settings.key_navclose, "navclose", remove_keybinds)
  mp.add_forced_key_binding(settings.key_navpageup, 'navpageup', movepageup, "repeatable")
  mp.add_forced_key_binding(settings.key_navpagedown, 'navpagedown', movepagedown, "repeatable")
  mp.add_forced_key_binding(settings.key_navterminal, "navterminal", start_terminal)
  mp.add_forced_key_binding(settings.key_navfilter, "navfilter", open_filter)
end

function remove_keybinds()
  timer:kill()
  nav_visible = false
  mp.set_osd_ass(0, 0, "")
  if settings.dynamic_binds then
    mp.remove_key_binding('navdown')
    mp.remove_key_binding('navup')
    mp.remove_key_binding('navopen')
    mp.remove_key_binding('navforward')
    mp.remove_key_binding('navback')
    mp.remove_key_binding('navfavorites')
    mp.remove_key_binding('navclose')
    mp.remove_key_binding('navpageup')
    mp.remove_key_binding('navpagedown')
    mp.remove_key_binding('navterminal')
    mp.remove_key_binding('navfilter')
  end
  --a filter only lasts while the menu is open
  if filter_text ~= "" then
    filter_text = ""
    if path then
      dir, length = scandirectory(path)
      cursor = 0
    end
  end
end

timer = mp.add_periodic_timer(settings.navigator_duration, remove_keybinds)
timer:kill()

if not settings.dynamic_binds then
  add_keybinds()
end

active=false
function activate()
  prune_marks()
  --opening the menu again: one cheap check of the folder's modified time, rescans only if it changed
  if path and not nav_visible and not (ON_WINDOWS and WINDOWS_ROOTDIR) then
    dir, length = scandirectory(path)
    if cursor >= length then cursor = length - 1 end
    if cursor < 0 then cursor = 0 end
  end
  if settings.menu_timeout then
    handler()
  else
    if active then
      remove_keybinds()
      active=false
    else
      handler()
      active=true
    end
  end
end

mp.add_key_binding(settings.navigator_mainkey, "navigator", activate)
--can be bound in input.conf: key script-binding navigator-terminal
mp.add_key_binding(nil, "navigator-terminal", start_terminal)
--key script-binding navigator-filter
mp.add_key_binding(nil, "navigator-filter", open_filter)
