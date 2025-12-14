local buffs = {}
local Bridge = exports['community_bridge']:Bridge()


local function DebugPrint(msg)
    if Config.Debug then
        print("^6[BUFFS]^7 " .. msg)
    end
end



-- Store remaining seconds (not absolute expiry)
local function serializeBuffsForDB(src)
    local out = {}
    local plyBuffs = buffs[src]
    if not plyBuffs then return "{}" end

    local now = os.time()

    for buffName, info in pairs(plyBuffs) do
        if info.expires then
            local remaining = info.expires - now
            if remaining > 0 then
                out[buffName] = remaining -- store seconds left
            end
        end
    end

    return json.encode(out)
end

local function deserializeBuffs(jsonString)
    local ok, decoded = pcall(json.decode, jsonString or "{}")
    if ok and type(decoded) == "table" then
        return decoded
    end
    return {}
end

local function savePlayerBuffsToDB(src)
    local player = Bridge.Framework.GetPlayer(src)
    if not player then
        DebugPrint(("savePlayerBuffsToDB: no player for src %s"):format(src))
        return
    end

    local citizenid = Bridge.Framework.GetPlayerIdentifier(src)
    if not citizenid then
        DebugPrint(("savePlayerBuffsToDB: no citizenid for %s"):format(src))
        return
    end

    local buffJson = serializeBuffsForDB(src)

    if buffJson == "{}" then
        MySQL.query('DELETE FROM player_buffs WHERE citizenid = ?', { citizenid })
        DebugPrint(("Deleted empty buff record for %s"):format(citizenid))
        return
    end

    local ok = MySQL.insert.await(
        'REPLACE INTO player_buffs (citizenid, buffs) VALUES (?, ?)',
        { citizenid, buffJson }
    )

    DebugPrint(("Saved buffs for %s → %s"):format(citizenid, buffJson))
end



local function removeStrengthWeight(src)
    local ox = exports.ox_inventory
    if not ox or not ox.SetMaxWeight then return end
    ox:SetMaxWeight(src, 85000)
end

local function applyStrengthBuff(src)
    local ox = exports.ox_inventory
    if not ox or not ox.SetMaxWeight then return end
    ox:SetMaxWeight(src, 85000 + (Config.BuffEffects.strength * 1000))
end



local function expireBuff(src, buffName)
    if buffs[src] and buffs[src][buffName] then
        if buffName == "strength" then
            removeStrengthWeight(src)
        end

        buffs[src][buffName] = nil
        TriggerClientEvent('buffs:client:expired', src, buffName)
        savePlayerBuffsToDB(src)

        DebugPrint(("Expired buff '%s' for %s"):format(buffName, src))
    end
end



local function activateBuff(src, buffName, duration)
    local player = Bridge.Framework.GetPlayer(src)
    if not player then return end

    if not Config.BuffDurations[buffName] then
        DebugPrint(("Invalid buff '%s' for %s"):format(buffName, src))
        return
    end

    duration = duration or Config.BuffDurations[buffName]
    local expiresAt = os.time() + duration

    buffs[src] = buffs[src] or {}

-- if already active, extend existing expiry instead of replacing
    if buffs[src][buffName] then
        local remaining = buffs[src][buffName].expires - os.time()
        buffs[src][buffName].expires = os.time() + remaining + duration
        DebugPrint(("Extended buff '%s' for %s by %ds (now expires in %ds)"):format(
            buffName, src, duration, buffs[src][buffName].expires - os.time()
        ))
    else
        buffs[src][buffName] = { expires = expiresAt }
        DebugPrint(("Activated new buff '%s' for %s (%ds)"):format(buffName, src, duration))
    end

    if buffName == "strength" then
        applyStrengthBuff(src)
    end

    TriggerClientEvent('buffs:client:activate', src, buffName, duration)
    savePlayerBuffsToDB(src)

    DebugPrint(("Activated '%s' for %s (%ds)"):format(buffName, src, duration))
end

exports('ActivateBuff', activateBuff)



local function getRemainingTime(src, buffName)
    if not buffs[src] or not buffs[src][buffName] then return 0 end
    local remaining = buffs[src][buffName].expires - os.time()
    return math.max(0, remaining)
end

local function isBuffActive(src, buffName)
    return getRemainingTime(src, buffName) > 0
end

exports('GetBuffTime', getRemainingTime)
exports('IsBuffActive', isBuffActive)



CreateThread(function()
    while true do
        Wait(1000)
        local now = os.time()

        for src, playerBuffs in pairs(buffs) do
            local expired = {}
            for buffName, info in pairs(playerBuffs) do
                if now >= info.expires then
                    table.insert(expired, buffName)
                end
            end
            for _, buffName in ipairs(expired) do
                expireBuff(src, buffName)
            end
        end
    end
end)



RegisterNetEvent("aura:retrievebuffs", function()
    local src = source
    local citizenid = Bridge.Framework.GetPlayerIdentifier(src)
    if not citizenid then return end

    buffs[src] = {}

    local result = MySQL.single.await('SELECT buffs FROM player_buffs WHERE citizenid = ?', { citizenid })
    if not result or not result.buffs then return end

    local decoded = deserializeBuffs(result.buffs)

    for buffName, remainingSeconds in pairs(decoded) do
        if remainingSeconds > 0 then
            local expiresAt = os.time() + remainingSeconds
            buffs[src][buffName] = { expires = expiresAt }

            if buffName == "strength" then
                applyStrengthBuff(src)
            end

            TriggerClientEvent('buffs:client:activate', src, buffName, remainingSeconds)
            DebugPrint(("Restored %s for %s (%ds left)"):format(buffName, src, remainingSeconds))
        end
    end
end)



AddEventHandler('playerDropped', function()
    local src = source
    local player = Bridge.Framework.GetPlayer(src)
    if not player then return end

    local citizenid = Bridge.Framework.GetPlayerIdentifier(src)
    if not citizenid then return end

    savePlayerBuffsToDB(src)

    if buffs[src] and buffs[src].strength then
        removeStrengthWeight(src)
    end

    buffs[src] = nil
    DebugPrint(("Saved and cleared buffs for disconnected player %s"):format(src))
end)



CreateThread(function()
    while true do
        Wait(3 * 60 * 1000)

        local now = os.time()
        local saved = 0

        for src, playerBuffs in pairs(buffs) do
            if next(playerBuffs) then
                for buffName, info in pairs(playerBuffs) do
                    if now >= info.expires then
                        expireBuff(src, buffName)
                    end
                end
                savePlayerBuffsToDB(src)
                saved = saved + 1
            end
        end

        if saved > 0 then
            DebugPrint(("Synced active buffs for %s players."):format(saved))
        end
    end
end)



CreateThread(function()
    while true do
        Wait(5 * 60 * 1000)

        DebugPrint("Running automatic database cleanup...")

        local results = MySQL.query.await('SELECT citizenid, buffs FROM player_buffs')
        if results and #results > 0 then
            local cleanedRows, cleanedBuffs = 0, 0

            for _, row in ipairs(results) do
                local cid = row.citizenid
                if cid and row.buffs then
                    local ok, decoded = pcall(json.decode, row.buffs)
                    if ok and type(decoded) == "table" then
                        local changed = false
                        for buffName, remaining in pairs(decoded) do
                            remaining = remaining - 300 -- 5 min passed
                            if remaining <= 0 then
                                decoded[buffName] = nil
                                changed = true
                                cleanedBuffs = cleanedBuffs + 1
                            else
                                decoded[buffName] = remaining
                                changed = true
                            end
                        end

                        if next(decoded) == nil then
                            MySQL.query('DELETE FROM player_buffs WHERE citizenid = ?', { cid })
                            cleanedRows = cleanedRows + 1
                        elseif changed then
                            local newJson = json.encode(decoded)
                            MySQL.update('UPDATE player_buffs SET buffs = ? WHERE citizenid = ?', { newJson, cid })
                            cleanedRows = cleanedRows + 1
                        end
                    end
                end
            end

            DebugPrint(("Cleanup complete: %s buffs cleaned across %s players."):format(cleanedBuffs, cleanedRows))
        else
            DebugPrint("No buff records to clean.")
        end
    end
end)



if Config.DebugCommands then
    lib.addCommand('buff', {
        help = 'Apply a buff to a player',
        params = {
            { name = 'buff', type = 'string', help = 'Buff name' },
            { name = 'target', type = 'playerId', help = 'Target player ID' },
            { name = 'time', type = 'number', help = 'Duration in seconds' },
        },
        restricted = 'group.admin'
    }, function(source, args)
        local buffName = string.lower(args.buff or "")
        local duration = tonumber(args.time) or Config.BuffDurations[buffName]
        local target = tonumber(args.target) or source

        if not Config.BuffDurations[buffName] then
            Bridge.Notify.SendNotify(source, "Invalid buff name!", "error", 8000)
            return
        end

        activateBuff(target, buffName, duration)
        Bridge.Notify.SendNotify(source, ('Buff "%s" applied to player %s (%ds)'):format(buffName, target, duration), "success", 8000)
    end)
end



RegisterNetEvent('buffs:server:requestBuff', function(buffName, duration)
    local src = source
    local ply = Bridge.Framework.GetPlayer(src)
    if not ply then return end

    buffName = string.lower(buffName or "")
    if not Config.BuffDurations[buffName] then
        DebugPrint(("%s tried invalid buff '%s'"):format(src, buffName))
        return
    end

    local time = tonumber(duration) or Config.BuffDurations[buffName]
    activateBuff(src, buffName, time)
end)

RegisterNetEvent('buffs:server:clearPlayerBuffs', function()
    local src = source
    local citizenid = Bridge.Framework.GetPlayerIdentifier(src)
    if not citizenid then return end

    buffs[src] = nil

    DebugPrint(("Player %s logged out — buffs cleared from memory & DB."):format(src))
end)