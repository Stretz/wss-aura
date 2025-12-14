# 📚 WSS Aura - Complete Documentation

# – Buff System

![Buff UI Preview](image.png)
Complete documentation for the WSS Aura buff system, including all exports, callbacks, events, and integration examples.

---

## 📋 Table of Contents

1. [Overview](#overview)
2. [Available Buffs](#available-buffs)
3. [Configuration](#configuration)
4. [Client-Side Exports](#client-side-exports)
5. [Server-Side Exports](#server-side-exports)
6. [Server Callbacks](#server-callbacks)
7. [Client Events](#client-events)
8. [Server Events](#server-events)
9. [Integration Examples](#integration-examples)
10. [Database Schema](#database-schema)
11. [Commands](#commands)
12. [Troubleshooting](#troubleshooting)

---

## 🎯 Overview

WSS Aura is a server-authoritative buff system for FiveM that provides temporary player bonuses. All buff data is stored server-side for security, and buffs persist through disconnects and reconnects.

### Key Features

- ✅ **Server-Authoritative**: All buff state managed server-side
- ✅ **Persistent**: Buffs survive disconnects and reconnects
- ✅ **Automatic Effects**: Buffs apply their effects automatically
- ✅ **Extendable**: Re-applying a buff extends its duration
- ✅ **Secure**: Client-side validation prevents exploitation
- ✅ **Database Persistence**: Buffs saved to MySQL database

---

## 🧬 Available Buffs

| Buff Name | Default Duration | Effect | Multiplier |
|-----------|------------------|--------|------------|
| **speed** | 120 seconds | Increases run & sprint speed | 1.25x |
| **stamina** | 180 seconds | Continuously regenerates stamina | 1.0 |
| **focus** | 150 seconds | Reduces progress bar duration | 0.75x (25% faster) |
| **intelligence** | 180 seconds | Increases minigame time | 1.2x (20% more time) |
| **strength** | 240 seconds | Increases inventory carry weight | +10,000 weight |

> **Note**: All durations and effects are configurable in `config.lua`

---

## ⚙️ Configuration

Edit `config.lua` to customize buff durations and effects:

```lua
Config.BuffDurations = {
    speed = 120,        -- Duration in seconds
    stamina = 180,
    focus = 150,
    intelligence = 180,
    strength = 240
}

Config.BuffEffects = {
    speed = 1.25,       -- Run speed multiplier
    stamina = 1.0,      -- Stamina restore amount
    focus = 0.75,       -- Progress bar time multiplier (lower = faster)
    intelligence = 1.2, -- Minigame time multiplier
    strength = 10.0     -- Weight increase (multiplied by 1000)
}

Config.Debug = false              -- Enable debug prints
Config.DebugCommands = true       -- Enable admin commands
Config.AllowedGroups = { 'admin', 'god' }  -- Groups with access
```

---

## 🖥️ Client-Side Exports

All client exports query the server for current buff state. Use these in your client scripts.

### Check Specific Buff Status

```lua
-- Returns: boolean
exports['wss-aura']:IsSpeedActive()
exports['wss-aura']:IsStaminaActive()
exports['wss-aura']:IsFocusActive()
exports['wss-aura']:IsIntelligenceActive()
exports['wss-aura']:IsStrengthActive()
```

**Example:**
```lua
if exports['wss-aura']:IsSpeedActive() then
    print("Player has speed buff active!")
end
```

### Generic Buff Checks

```lua
-- Check if any buff is active
-- Returns: boolean
exports['wss-aura']:HasBuff(buffName)

-- Get remaining time for a buff
-- Returns: number (seconds remaining, 0 if not active)
exports['wss-aura']:GetBuffTime(buffName)
```

**Example:**
```lua
local hasStamina = exports['wss-aura']:HasBuff('stamina')
local timeLeft = exports['wss-aura']:GetBuffTime('stamina')

if hasStamina then
    print("Stamina buff active for " .. timeLeft .. " more seconds")
end
```

### Intelligence Helper (Minigames)

```lua
-- Calculate buffed duration for minigames
-- Returns: number (adjusted duration in milliseconds)
exports['wss-aura']:GetBuffedIntelligenceDuration(baseDuration)
```

**Example:**
```lua
local baseTime = 5000  -- 5 seconds in milliseconds
local buffedTime = exports['wss-aura']:GetBuffedIntelligenceDuration(baseTime)
-- If intelligence buff is active, buffedTime will be 6000 (20% more time)
```

---

## 🗄️ Server-Side Exports

Use these exports in your server scripts to manage player buffs.

### Activate a Buff

```lua
-- Activate or extend a buff for a player
exports['wss-aura']:ActivateBuff(source, buffName, duration)
```

**Parameters:**
- `source` (number): Player server ID
- `buffName` (string): Name of the buff ('speed', 'stamina', etc.)
- `duration` (number, optional): Duration in seconds. If omitted, uses default from config

**Example:**
```lua
-- Give player a speed buff for 60 seconds
exports['wss-aura']:ActivateBuff(source, 'speed', 60)

-- Give player default duration stamina buff
exports['wss-aura']:ActivateBuff(source, 'stamina')
```

### Check Buff Status

```lua
-- Check if a buff is active for a player
-- Returns: boolean
exports['wss-aura']:IsBuffActive(source, buffName)

-- Get remaining time for a buff
-- Returns: number (seconds remaining, 0 if not active)
exports['wss-aura']:GetBuffTime(source, buffName)
```

**Example:**
```lua
local playerId = source
if exports['wss-aura']:IsBuffActive(playerId, 'speed') then
    local timeLeft = exports['wss-aura']:GetBuffTime(playerId, 'speed')
    print("Player has speed buff for " .. timeLeft .. " more seconds")
end
```

---

## 🔄 Server Callbacks

Callbacks provide secure client-to-server communication. Use `lib.callback.await()` on client or `lib.callback()` on server.

### Get Active Buffs

```lua
-- Client-side usage
local activeBuffs = lib.callback.await('buffs:server:getActiveBuffs', false)
-- Returns: table { buffName = remainingSeconds, ... }

-- Server-side usage
local activeBuffs = lib.callback('buffs:server:getActiveBuffs', source, targetSrc)
-- targetSrc is optional - defaults to calling player
```

**Example:**
```lua
-- Client
local buffs = lib.callback.await('buffs:server:getActiveBuffs', false)
for buffName, remaining in pairs(buffs) do
    print(buffName .. ": " .. remaining .. " seconds left")
end

-- Server (get buffs for specific player)
local targetBuffs = lib.callback('buffs:server:getActiveBuffs', source, targetPlayerId)
```

### Request Buff Activation

```lua
-- Client-side usage (validated server-side)
local success = lib.callback.await('buffs:server:requestActivation', false, buffName, duration)
-- Returns: boolean (true if activation succeeded)
```

**Parameters:**
- `buffName` (string): Name of the buff
- `duration` (number, optional): Duration in seconds (max 3600, defaults to config)

**Example:**
```lua
-- Request a speed buff for 120 seconds
local success = lib.callback.await('buffs:server:requestActivation', false, 'speed', 120)
if success then
    print("Buff activated successfully!")
else
    print("Failed to activate buff")
end
```

---

## 📡 Client Events

These events are triggered by the server. You can listen to them in your client scripts.

### Buff Activated

```lua
RegisterNetEvent('buffs:client:activate', function(buffName, duration)
    -- buffName: string - Name of the buff
    -- duration: number - Duration in seconds
end)
```

**Example:**
```lua
RegisterNetEvent('buffs:client:activate', function(buffName, duration)
    print("Buff activated: " .. buffName .. " for " .. duration .. " seconds")
    -- Your custom logic here
end)
```

### Buff Expired

```lua
RegisterNetEvent('buffs:client:expired', function(buffName)
    -- buffName: string - Name of the expired buff
end)
```

**Example:**
```lua
RegisterNetEvent('buffs:client:expired', function(buffName)
    print("Buff expired: " .. buffName)
    -- Your custom logic here
end)
```

---

## 📨 Server Events

These events can be triggered from client or server scripts.

### Request Buff (Client → Server)

```lua
-- Trigger from client
TriggerServerEvent('buffs:server:requestBuff', buffName, duration)
```

**Parameters:**
- `buffName` (string): Name of the buff
- `duration` (number, optional): Duration in seconds

**Example:**
```lua
-- Client script
TriggerServerEvent('buffs:server:requestBuff', 'speed', 120)
```

### Clear Player Buffs (Client → Server)

```lua
-- Trigger from client (usually on disconnect)
TriggerServerEvent('buffs:server:clearPlayerBuffs')
```

### Retrieve Buffs (Server → Client)

```lua
-- Trigger from server to restore buffs on player connect
TriggerClientEvent('aura:retrievebuffs', source)
```

---

## 💡 Integration Examples

### Example 1: Item Consumption (Client → Server)

When a player consumes an item that gives a buff:

```lua
-- Client script
RegisterNetEvent('inventory:client:useItem', function(item)
    if item.name == 'energy_drink' then
        -- Request speed buff for 60 seconds
        TriggerServerEvent('buffs:server:requestBuff', 'speed', 60)
    elseif item.name == 'protein_bar' then
        -- Request strength buff with default duration
        TriggerServerEvent('buffs:server:requestBuff', 'strength')
    end
end)
```

### Example 2: Shop Purchase (Server-Side)

When a player purchases a buff from a shop:

```lua
-- Server script
RegisterNetEvent('shop:server:purchaseBuff', function(buffName, duration)
    local src = source
    -- Check if player has enough money, etc.
    
    -- Apply the buff
    exports['wss-aura']:ActivateBuff(src, buffName, duration)
end)
```

### Example 3: Progress Bar with Focus Buff

Make progress bars faster when focus buff is active:

```lua
-- Client script
local function doAction(duration, label)
    local focusActive = exports['wss-aura']:IsFocusActive()
    local adjustedDuration = duration
    
    if focusActive then
        -- Focus buff makes progress 25% faster (0.75 multiplier)
        adjustedDuration = duration * 0.75
    end
    
    lib.progressBar({
        duration = adjustedDuration,
        label = label,
        canCancel = true,
    })
end
```

### Example 4: Minigame with Intelligence Buff

Give players more time in minigames:

```lua
-- Client script
local function startMinigame()
    local baseTime = 5000  -- 5 seconds base time
    local time = exports['wss-aura']:GetBuffedIntelligenceDuration(baseTime)
    
    -- Start your minigame with adjusted time
    StartMinigame(time)
end
```

### Example 5: Conditional Speed Check

Only allow certain actions if speed buff is active:

```lua
-- Client script
RegisterCommand('sprint', function()
    if exports['wss-aura']:IsSpeedActive() then
        -- Allow enhanced sprinting
        SetRunSprintMultiplierForPlayer(PlayerId(), 1.5)
    else
        -- Normal sprinting
        SetRunSprintMultiplierForPlayer(PlayerId(), 1.0)
    end
end)
```

### Example 6: Server-Side Reward System

Give buffs as rewards for completing tasks:

```lua
-- Server script
RegisterNetEvent('missions:server:complete', function(missionType)
    local src = source
    
    if missionType == 'race' then
        -- Reward with speed buff
        exports['wss-aura']:ActivateBuff(src, 'speed', 300)  -- 5 minutes
    elseif missionType == 'heist' then
        -- Reward with multiple buffs
        exports['wss-aura']:ActivateBuff(src, 'intelligence', 600)
        exports['wss-aura']:ActivateBuff(src, 'focus', 600)
    end
end)
```

### Example 7: Check All Active Buffs

Get a list of all active buffs:

```lua
-- Client script
local function printActiveBuffs()
    local buffs = lib.callback.await('buffs:server:getActiveBuffs', false)
    
    if next(buffs) == nil then
        print("No active buffs")
        return
    end
    
    print("Active Buffs:")
    for buffName, remaining in pairs(buffs) do
        print("  - " .. buffName .. ": " .. remaining .. " seconds")
    end
end
```

---

## 🗃️ Database Schema

The resource uses a MySQL table to persist buffs. Create this table in your database:

```sql
CREATE TABLE IF NOT EXISTS `player_buffs` (
  `citizenid` varchar(50) NOT NULL,
  `buffs` longtext DEFAULT NULL,
  PRIMARY KEY (`citizenid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
```

**Table Structure:**
- `citizenid` (VARCHAR): Player's citizen ID (primary key)
- `buffs` (LONGTEXT): JSON string containing active buffs with remaining time

**Example Data:**
```json
{
  "speed": 45,
  "stamina": 120,
  "strength": 180
}
```

---

## ⌨️ Commands

### Client Commands

#### `/buffcheck`
Displays all active buffs and their remaining time in the console (requires debug mode).

**Usage:**
```
/buffcheck
```

### Server Commands (Admin Only)

#### `/buff [buff] [target] [time]`
Apply a buff to a player (requires admin permissions).

**Parameters:**
- `buff` (string): Buff name (speed, stamina, focus, intelligence, strength)
- `target` (number, optional): Target player ID (defaults to yourself)
- `time` (number, optional): Duration in seconds (defaults to config)

**Examples:**
```
/buff speed 1 120        -- Give player 1 a speed buff for 120 seconds
/buff stamina            -- Give yourself default stamina buff
/buff strength 5 300     -- Give player 5 a strength buff for 5 minutes
```

> **Note**: This command only appears if `Config.DebugCommands = true`

---

## 🔧 Troubleshooting

### Buffs Not Appearing

1. **Check Database**: Ensure the `player_buffs` table exists
2. **Check Dependencies**: Verify all required resources are started
3. **Check Console**: Enable `Config.Debug = true` to see debug messages
4. **Check Permissions**: Ensure player has proper framework permissions

### Buffs Not Persisting

1. **Check Database Connection**: Verify MySQL connection is working
2. **Check Citizen ID**: Ensure player has a valid citizen ID
3. **Check Server Logs**: Look for database errors

### Buff Effects Not Working

1. **Speed Buff**: Check if `SetRunSprintMultiplierForPlayer` is being overridden
2. **Stamina Buff**: Verify `RestorePlayerStamina` is available
3. **Strength Buff**: Ensure `ox_inventory` is installed and running

### Callback Errors

If callbacks are not working:

1. **Check ox_lib**: Ensure `ox_lib` is installed and updated
2. **Check Resource Name**: Verify you're using the correct resource name
3. **Check Server Logs**: Look for callback registration errors

---

## 📝 Notes

### Buff Extension Behavior

- If a buff is already active and you apply it again, the duration is **extended** (added to remaining time)
- Example: If speed buff has 30 seconds left and you apply it for 60 seconds, it will have 90 seconds total

### Server-Side Validation

- All buff activations are validated server-side
- Invalid buff names are rejected
- Duration is capped at 3600 seconds (1 hour) for security
- Client events are validated against server state

### Performance Considerations

- Buff effects loop queries server every 250ms
- Server checks for expired buffs every 1 second
- Database syncs every 3 minutes
- Database cleanup runs every 5 minutes

### Security Features

- All buff state stored server-side
- Client events validated against server state
- Callbacks require valid player session
- Duration limits prevent abuse

---

## 📞 Support

For issues or questions:

1. Check this documentation first
2. Enable debug mode (`Config.Debug = true`)
3. Check server/client console for errors
4. Contact server administrators

---

## 📄 License

This resource is licensed under the GNU General Public License v3.0.

---

**Developed by WSS-Development**  
**Buff System by zStretz**  
**Version 0.0.1**

