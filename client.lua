   -- Buff System For FiveM
   --  Copyright (C) 2025  zStretz

   --  This program is free software: you can redistribute it and/or modify
   --  it under the terms of the GNU General Public License as published by
   --  the Free Software Foundation, either version 3 of the License, or
   --  (at your option) any later version.

   --  This program is distributed in the hope that it will be useful,
   --  but WITHOUT ANY WARRANTY; without even the implied warranty of
   --  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
   --  GNU General Public License for more details.

   --  You should have received a copy of the GNU General Public License
   --  along with this program.  If not, see <https://www.gnu.org/licenses/>.


local Bridge = exports['community_bridge']:Bridge()
local effectsRunning = false


local function DebugPrint(msg)
    if Config.Debug then
        print("^6[BUFFS-CLIENT]^7 " .. msg)
    end
end


RegisterNetEvent('buffs:client:activate', function(buffName, duration)
    if not buffName or not duration then return end

    -- Validate with server that this buff is actually active
    local activeBuffs = Bridge.Callback.Trigger('buffs:server:getActiveBuffs') or {}
    local serverBuffTime = activeBuffs[buffName] or 0
    
    -- Only proceed if server confirms the buff is active
    if serverBuffTime <= 0 then
        DebugPrint(("Received activation for '%s' but server doesn't have it active - ignoring"):format(buffName))
        return
    end

    -- Use server's actual remaining time for accuracy
    local actualDuration = math.min(duration, serverBuffTime)
    
    Bridge.Notify.SendNotify(("Buff activated: %s (%ds)"):format(buffName, actualDuration), "success", 5000)
    SendNUIMessage({ action = "add", buff = buffName, duration = actualDuration })
    SetNuiFocus(false, false)

    if not effectsRunning then
        effectsRunning = true
        StartBuffEffects()
    end

    DebugPrint(("Activated buff '%s' (%ds total)"):format(buffName, actualDuration))
end)



RegisterNetEvent('buffs:client:expired', function(buffName)
    Bridge.Notify.SendNotify(buffName .. " buff expired.", "error", 5000)
    SendNUIMessage({ action = "remove", buff = buffName })

    DebugPrint(("Buff '%s' expired and removed"):format(buffName))

    -- Reset speed multiplier immediately when speed buff expires
    if buffName == "speed" then
        local ply = PlayerId()
        SetRunSprintMultiplierForPlayer(ply, 1.0)
        DebugPrint("Speed buff expired")
    end
end)


-- Expiration checking is handled server-side


function StartBuffEffects()
    CreateThread(function()
        DebugPrint("Starting buff effect loop...")

        local lastSpeedState = false

        while effectsRunning do
            local ped = PlayerPedId()
            local ply = PlayerId()

            -- Query server for active buffs
            local activeBuffs = Bridge.Callback.Trigger('buffs:server:getActiveBuffs') or {}
            
            local hasSpeed = activeBuffs["speed"] ~= nil and activeBuffs["speed"] > 0

            if hasSpeed and not lastSpeedState then
                SetRunSprintMultiplierForPlayer(ply, Config.BuffEffects.speed)
                DebugPrint(("Speed buff applied (x%.2f)"):format(Config.BuffEffects.speed))
                lastSpeedState = true
            elseif (not hasSpeed) and lastSpeedState then
                SetRunSprintMultiplierForPlayer(ply, 1.0)
                DebugPrint("Speed buff removed (reset to 1.0)")
                lastSpeedState = false
            end

            if activeBuffs["stamina"] and activeBuffs["stamina"] > 0 then
                RestorePlayerStamina(ply, Config.BuffEffects.stamina)
            end

            -- Check if any buffs are still active
            local hasAnyBuffs = false
            for _, remaining in pairs(activeBuffs) do
                if remaining > 0 then
                    hasAnyBuffs = true
                    break
                end
            end

            if not hasAnyBuffs then
                effectsRunning = false
                SetRunSprintMultiplierForPlayer(ply, 1.0)
                DebugPrint("No buffs left — all multipliers reset.")
                break
            end

            Wait(250)
        end
    end)
end




-- === Exports === --
exports('IsSpeedActive', function()
    local activeBuffs = Bridge.Callback.Trigger('buffs:server:getActiveBuffs') or {}
    return activeBuffs['speed'] ~= nil and activeBuffs['speed'] > 0
end)

exports('IsStaminaActive', function()
    local activeBuffs = Bridge.Callback.Trigger('buffs:server:getActiveBuffs') or {}
    return activeBuffs['stamina'] ~= nil and activeBuffs['stamina'] > 0
end)

exports('IsFocusActive', function()
    local activeBuffs = Bridge.Callback.Trigger('buffs:server:getActiveBuffs') or {}
    return activeBuffs['focus'] ~= nil and activeBuffs['focus'] > 0
end)

exports('IsIntelligenceActive', function()
    local activeBuffs = Bridge.Callback.Trigger('buffs:server:getActiveBuffs') or {}
    return activeBuffs['intelligence'] ~= nil and activeBuffs['intelligence'] > 0
end)

exports('IsStrengthActive', function()
    local activeBuffs = Bridge.Callback.Trigger('buffs:server:getActiveBuffs') or {}
    return activeBuffs['strength'] ~= nil and activeBuffs['strength'] > 0
end)

exports('HasBuff', function(buffName)
    local activeBuffs = Bridge.Callback.Trigger('buffs:server:getActiveBuffs') or {}
    return activeBuffs[buffName] ~= nil and activeBuffs[buffName] > 0
end)

exports('GetBuffTime', function(buffName)
    local activeBuffs = Bridge.Callback.Trigger('buffs:server:getActiveBuffs') or {}
    return activeBuffs[buffName] or 0
end)

-- Intelligence buff helper for minigame durations
exports('GetBuffedIntelligenceDuration', function(baseDuration)
    local duration = baseDuration
    local activeBuffs = Bridge.Callback.Trigger('buffs:server:getActiveBuffs') or {}
    if activeBuffs['intelligence'] and activeBuffs['intelligence'] > 0 then
        duration = math.floor(baseDuration * Config.BuffEffects.intelligence)
    end
    
    return duration
end)

RegisterCommand('buffcheck', function()
    DebugPrint("=== Buff Debug Info ===")
    local activeBuffs = Bridge.Callback.Trigger('buffs:server:getActiveBuffs') or {}
    for buffName, remaining in pairs(activeBuffs) do
        DebugPrint(("Buff: %s | %ds left"):format(buffName, remaining))
    end
    if next(activeBuffs) == nil then
        DebugPrint("No active buffs.")
    end
end)

AddEventHandler('playerDropped', function ()
    DebugPrint("Logout detected — clearing all active buffs...")

    local ply = PlayerId()
    SetRunSprintMultiplierForPlayer(ply, 1.0) -- always reset run speed

    -- Get active buffs from server to clear UI
    local activeBuffs = Bridge.Callback.Trigger('buffs:server:getActiveBuffs') or {}
    for buffName, _ in pairs(activeBuffs) do
        SendNUIMessage({ action = "remove", buff = buffName })
    end
    
    effectsRunning = false

    -- Inform the server to clear DB buffs
    TriggerServerEvent('buffs:server:clearPlayerBuffs')

    DebugPrint("All buffs cleared on logout.")
end)

RegisterCommand("buff:test", function()

end)