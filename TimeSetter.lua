local ffi = require 'ffi'
ffi.cdef[[
    typedef unsigned char uint8_t;
]]

script_name("TimeSetter with Transition")
script_description("/sw - change weather, /st - change time")
script_version_number(2)
script_version("v2.0")
script_author("ANDRE")
script_dependencies('SAMP v0.3.7')

-- general var
local time = {hour = nil, minute = nil}
local transition_active = false
local target_time = {hour = nil, minute = 0}
local Minutes = ffi.cast("uint8_t*", 0xB70152) 

function main()
    if not isSampLoaded() or not isSampfuncsLoaded() then return end
    while not isSampAvailable() do wait(100) end

    sampRegisterChatCommand("st", cmdSetTime)
    
    while true do
        wait(0)
        if time.hour then
            setTimeOfDay(time.hour, Minutes[0])
        end
    end
end

function cmdSetTime(param)
    local hour = tonumber(param)

    if hour == nil or hour < 0 or hour > 23 then
        sampAddChatMessage("{a25ed6}[V+]:{FFFFFF} Invalid hour. Please enter a value between 0 and 23.", -1)
        return
    end

    if hour == 24 then
        hour = 0
    end

    if hour == 0 and time.hour == 24 then
        hour = 24
    end

    if time.hour == hour then
        sampAddChatMessage("{a25ed6}[V+]:{FFFFFF} The time is already set to " .. hour .. ".", -1)
        return
    end

    if transition_active then
        sampAddChatMessage("{a25ed6}[V+]:{FFFFFF} Wait for the current transition to finish before using the command again.", -1)
        return
    end

    if time.hour ~= nil then
        target_time.hour = hour
        target_time.minute = math.random(0, 59)
        startTimeTransition()
    else
        time.hour = hour
        time.minute = math.random(0, 59) 
        patch_samp_time_set(true)
    end

local am_pm = (hour >= 12) and "PM" or "AM"
local display_hour = (hour % 12 == 0) and 12 or (hour % 12)
local minutes = string.format("%02d", target_time.minute) 
local formatted_time = string.format("%d:%s %s", display_hour, minutes, am_pm)


   
    local message = ""
    if hour >= 6 and hour < 12 then
        message = "{FFD700}Morning-Time{FFFFFF} has been set. The time is now " .. formatted_time .. "."
    elseif hour >= 12 and hour < 18 then
        message = "{FFA500}Afternoon-Time{FFFFFF} has been set. The time is now " .. formatted_time .. "."
    elseif hour >= 18 and hour < 21 then
        message = "{FF4500}Evening-Time{FFFFFF} has been set. The time is now " .. formatted_time .. "."
    elseif hour >= 21 or hour < 6 then
        message = "{1E90FF}Night-Time{FFFFFF} has been set. The time is now " .. formatted_time .. "."
    end

    sampAddChatMessage("{a25ed6}[V+]:{FFFFFF} " .. message, -1)
end

function patch_samp_time_set(enable)
    if enable and default == nil then
        default = readMemory(sampGetBase() + 0x9C0A0, 4, true)
        writeMemory(sampGetBase() + 0x9C0A0, 4, 0x000008C2, true)
    elseif enable == false and default ~= nil then
        writeMemory(sampGetBase() + 0x9C0A0, 4, default, true)
        default = nil
    end
end
function startTimeTransition()
    transition_active = true

    local hour_diff = math.abs(target_time.hour - time.hour)
    local step
    local base_delay = 2  
    local delay

   
    if hour_diff > 12 then
        delay = base_delay * 0.5 
    elseif hour_diff > 8 then
        delay = base_delay * 0.75
    else
        delay = base_delay 
    end

   
    if hour_diff > 12 then
        step = (target_time.hour > time.hour) and -1 or 1
    else
        step = (target_time.hour > time.hour) and 1 or -1
    end

    lua_thread.create(function()
        
        if (time.hour == 23 and target_time.hour == 0) or (time.hour == 0 and target_time.hour == 23) then
            setTimeOfDay(23, 59)
            wait(0)
            setTimeOfDay(0, 0) 
            transition_active = false
            return
        end

        while time.hour ~= target_time.hour do
            if step == 1 then
                while tonumber(Minutes[0]) < 59 do
                    Minutes[0] = Minutes[0] + 1
                    setTimeOfDay(time.hour, tonumber(Minutes[0]))
                    wait(delay) 
                end
            elseif step == -1 then
                while tonumber(Minutes[0]) > 0 do
                    Minutes[0] = Minutes[0] - 1
                    setTimeOfDay(time.hour, tonumber(Minutes[0]))
                    wait(delay) 
                end
            end
                
            Minutes[0] = (step == 1) and 0 or 59
            time.hour = time.hour + step

            if time.hour > 23 then 
                time.hour = 0 
            elseif time.hour < 0 then
                time.hour = 23 
            end

            setTimeOfDay(time.hour, tonumber(Minutes[0]))
        end

        transition_active = false
    end)

end
