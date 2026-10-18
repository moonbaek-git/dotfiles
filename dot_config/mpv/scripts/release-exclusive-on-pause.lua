-- release-exclusive-on-pause.lua
-- Keeps WASAPI exclusive mode only while a video is actually playing.
-- When mpv is paused (or sitting at the end of a file with keep-open), exclusive
-- mode is released after a short delay so Firefox and other apps get their sound
-- back. Pressing play takes exclusive mode again.
-- Your mpv.conf is not changed; this only toggles the option while mpv runs.

local RELEASE_DELAY = 2  -- seconds of pause before exclusive mode is released

-- do nothing if exclusive mode is not enabled in the config
if mp.get_property_native("audio-exclusive") ~= true then
    return
end

local function set_exclusive(on)
    if mp.get_property_native("audio-exclusive") == on then return end
    local ok, err = mp.set_property_native("audio-exclusive", on)
    if ok == nil or ok == false then
        mp.msg.warn("could not change audio-exclusive: " .. tostring(err))
    else
        mp.msg.info("audio-exclusive = " .. tostring(on))
    end
end

local release_timer = mp.add_timeout(RELEASE_DELAY, function()
    set_exclusive(false)
end)
release_timer:kill()

mp.observe_property("pause", "bool", function(_, paused)
    if paused then
        release_timer:resume()
    else
        release_timer:kill()
        set_exclusive(true)
    end
end)
