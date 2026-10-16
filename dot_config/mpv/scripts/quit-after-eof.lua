mp.register_event("end-file", function(e)
    if e.reason == "eof" then
        mp.add_timeout(0.2, function()
            if mp.get_property_bool("idle-active") then
                mp.command("quit")
            end
        end)
    end
end)