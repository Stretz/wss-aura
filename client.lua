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
local activeBuffs = {}
local effectsRunning = false


local function DebugPrint(msg)
    if Config.Debug then
        print("^6[BUFFS-CLIENT]^7 " .. msg)
    end
end


RegisterNetEvent('buffs:client:activate', function(buffName, duration)
    if not buffName or not duration then return end

    local now = GetGameTimer()
    local expireTime = now + (duration * 1000)

    if activeBuffs[buffName] then
        -- ⏱ Extend existing buff duration
        local remaining = activeBuffs[buffName] - now
        activeBuffs[buffName] = now + remaining + (duration * 1000)
        DebugPrint(("Extended buff '%s' by %ds (new total: %ds left)"):format(
            buffName, duration, math.floor((activeBuffs[buffName] - now) / 1000)
        ))
        SendNUIMessage({ action = "extend", buff = buffName, duration = duration })
        return
    end

    -- New buff activation
    activeBuffs[buffName] = expireTime
    Bridge.Notify.SendNotify(("Buff activated: %s (%ds)"):format(buffName, duration), "success", 5000)

    SendNUIMessage({ action = "add", buff = buffName, duration = duration })
    SetNuiFocus(false, false)

    if not effectsRunning then
        effectsRunning = true
        StartBuffEffects()
    end

    DebugPrint(("Activated buff '%s' (%ds total)"):format(buffName, duration))
end)



RegisterNetEvent('buffs:client:expired', function(buffName)
    if not activeBuffs[buffName] then return end

    activeBuffs[buffName] = nil
    Bridge.Notify.SendNotify(buffName .. " buff expired.", "error", 5000)
    SendNUIMessage({ action = "remove", buff = buffName })

    DebugPrint(("Buff '%s' expired and removed"):format(buffName))

    -- Reset speed multiplier immediately when speed buff expires
    if buffName == "speed" then
        local ply = PlayerId()
        SetRunSprintMultiplierForPlayer(ply, 1.0)
        DebugPrint("Speed buff expired")
    end

    if next(activeBuffs) == nil then
        effectsRunning = false
        -- Ensure speed is reset when all buffs expire
        local ply = PlayerId()
        SetRunSprintMultiplierForPlayer(ply, 1.0)
    end
end)


CreateThread(function()
    while true do
        Wait(1000)
        local now = GetGameTimer()
        for buffName, expireTime in pairs(activeBuffs) do
            if now >= expireTime then
                TriggerEvent('buffs:client:expired', buffName)
            end
        end
    end
end)


function StartBuffEffects()
    CreateThread(function()
        DebugPrint("Starting buff effect loop...")

        local lastSpeedState = false

        while effectsRunning do
            local ped = PlayerPedId()
            local ply = PlayerId()

      
            local expire = activeBuffs["speed"]
            local hasSpeed = expire ~= nil and GetGameTimer() < expire

            if hasSpeed and not lastSpeedState then
       
                SetRunSprintMultiplierForPlayer(ply, Config.BuffEffects.speed)
                DebugPrint(("Speed buff applied (x%.2f)"):format(Config.BuffEffects.speed))
                lastSpeedState = true
            elseif (not hasSpeed) and lastSpeedState then
 
                SetRunSprintMultiplierForPlayer(ply, 1.0)
                DebugPrint("Speed buff removed (reset to 1.0)")
                lastSpeedState = false
            end

    
            if activeBuffs["stamina"] then
                RestorePlayerStamina(ply, Config.BuffEffects.stamina)
            end

   
            if next(activeBuffs) == nil then
                effectsRunning = false

          
                SetRunSprintMultiplierForPlayer(ply, 1.0)
                DebugPrint("No buffs left — all multipliers reset.")
                break
            end

            Wait(250)
        end
    end)
end




local function isBuffActive(buffName)
    local expire = activeBuffs[buffName]
    if not expire then return false end
    if GetGameTimer() >= expire then
        activeBuffs[buffName] = nil
        return false
    end
    return true
end

local function getBuffTime(buffName)
    local expire = activeBuffs[buffName]
    if not expire then return 0 end
    local remaining = math.floor((expire - GetGameTimer()) / 1000)
    return remaining > 0 and remaining or 0
end

-- === Exports === --
exports('IsSpeedActive', function() return isBuffActive('speed') end)
exports('IsStaminaActive', function() return isBuffActive('stamina') end)
exports('IsFocusActive', function() return isBuffActive('focus') end)
exports('IsIntelligenceActive', function() return isBuffActive('intelligence') end)
exports('IsStrengthActive', function() return isBuffActive('strength') end)

exports('HasBuff', isBuffActive)
exports('GetBuffTime', getBuffTime)

-- Intelligence buff helper for minigame durations
exports('GetBuffedIntelligenceDuration', function(baseDuration)
    local duration = baseDuration
    if isBuffActive('intelligence') then
        duration = math.floor(baseDuration * Config.BuffEffects.intelligence)
    end
    
    return duration
end)

RegisterCommand('buffcheck', function()
    DebugPrint("=== Buff Debug Info ===")
    for buffName, expire in pairs(activeBuffs) do
        local remaining = math.floor((expire - GetGameTimer()) / 1000)
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

    -- Clear all buffs and stop loops
    for buffName, _ in pairs(activeBuffs) do
        SendNUIMessage({ action = "remove", buff = buffName })
    end
    activeBuffs = {}
    effectsRunning = false

    -- Inform the server to clear DB buffs
    TriggerServerEvent('buffs:server:clearPlayerBuffs')

    DebugPrint("All buffs cleared on logout.")
end)

