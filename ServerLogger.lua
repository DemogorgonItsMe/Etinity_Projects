-- open source, enjoy skids
game.StarterGui:SetCore("SendNotification", {
    Title = "Server Logger";
    Text = "Made by Demogorgon";
    Icon = "rbxassetid://2804603863";
    Duration = 7;
})
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")
local SETTINGS = {
    -- Player Tracking
    Player = {
        TrackJoins = true,
        TrackLeaves = true,
        TrackAdminActions = true,
        MaxNameLength = 20,  -- Trim long player names
    },
    
    -- Character Tracking
    Character = {
        TrackSpawns = true,
        TrackDespawns = true,
        TrackRespawns = true,
    },
    
    -- Humanoid Tracking
    Humanoid = {
        TrackWalkSpeed = {
            Enabled = true,
            Threshold = 0.5,  -- Only log if change > threshold
        },
        TrackJumpPower = {
            Enabled = true,
            Threshold = 0.5,
        },
        TrackHealth = {
            Enabled = true,
            Threshold = 5,
            TrackDamageSources = true,  -- Try to identify damage sources
        },
        TrackStates = {
            Death = true,
            Falling = true,
            Swimming = false,  -- Disabled as it's not reliable
            Seated = true,
            Ragdoll = true,
        },
    },
    
    -- Advanced Features
    Advanced = {
        TrackTeleports = true,
        TrackTools = true,
        TrackChat = false,
        TrackPrivateServers = true,
    },
    
    -- Logging Settings
    Logging = {
        OutputToConsole = true,
        MaxMessageHistory = 100,
        Cooldown = 0.2,
        TimestampFormat = "%H:%M:%S",
        ColorOutput = true,
    },
    
    -- Performance
    Performance = {
        DebounceTime = 0.1,
        MaxEventsPerMinute = 500,
        OptimizeNetwork = true,
    },
    
    -- Security
    Security = {
        ObfuscatePlayerNames = false,
        FilterSensitiveData = true,
    }
}

local PlayerData = {}
local EventHistory = {}
local EventCount = 0
local LastEventTimes = {}

-- Enhanced logging function
local function logEvent(eventType, playerName, message, extraData)
    -- Apply security filters
    if SETTINGS.Security.ObfuscatePlayerNames and playerName then
        playerName = "Player-"..tostring(math.floor(HttpService:GenerateGUID(false):gsub("-", ""):sub(1, 8), 16))
    end
    
    -- Trim long player names
    if playerName and #playerName > SETTINGS.Player.MaxNameLength then
        playerName = playerName:sub(1, SETTINGS.Player.MaxNameLength).."..."
    end
    
    -- Check cooldown
    local eventKey = eventType..(playerName or "")..(message or "")
    if LastEventTimes[eventKey] and (os.clock() - LastEventTimes[eventKey] < SETTINGS.Logging.Cooldown) then
        return
    end
    LastEventTimes[eventKey] = os.clock()
    
    -- Format message
    local timestamp = os.date(SETTINGS.Logging.TimestampFormat)
    local output = string.format("[%s][%s]", timestamp, eventType)
    
    if playerName then
        output = output.." "..playerName
    end
    
    if message then
        output = output..": "..message
    end
    
    -- Handle extra data
    if extraData then
        if type(extraData) == "table" then
            output = output.." ("..table.concat(extraData, ", ")..")"
        else
            output = output.." ("..tostring(extraData)..")"
        end
    end
    
    -- Output to console
    if SETTINGS.Logging.OutputToConsole then
        if SETTINGS.Logging.ColorOutput then
            -- Color coding based on event type
            local colors = {
                JOIN = Color3.fromRGB(100, 255, 100),
                LEAVE = Color3.fromRGB(255, 100, 100),
                CHARACTER = Color3.fromRGB(100, 200, 255),
                HUMANOID = Color3.fromRGB(255, 200, 100),
                DEATH = Color3.fromRGB(255, 50, 50),
                KICK = Color3.fromRGB(255, 150, 50),
                SYSTEM = Color3.fromRGB(150, 150, 255),
            }
            local color = colors[eventType] or Color3.fromRGB(200, 200, 200)
            print(output, color)
        else
            print(output)
        end
    end
    
    -- Store event history
    table.insert(EventHistory, 1, {
        time = timestamp,
        type = eventType,
        player = playerName,
        message = message,
        data = extraData
    })
    
    -- Trim history
    if #EventHistory > SETTINGS.Logging.MaxMessageHistory then
        table.remove(EventHistory)
    end
    
    EventCount = EventCount + 1
end

-- ===== ENHANCED MONITORING FUNCTIONS =====
local function monitorHumanoid(player, humanoid)
    -- Property tracking with threshold checking
    local function trackProperty(prop, config)
        if not config.Enabled then return end
        
        local lastValue = humanoid[prop]
        humanoid:GetPropertyChangedSignal(prop):Connect(function()
            local newValue = humanoid[prop]
            if math.abs(newValue - lastValue) >= config.Threshold then
                logEvent("HUMANOID", player.Name, 
                    string.format("%s changed from %.1f to %.1f", prop, lastValue, newValue))
                lastValue = newValue
            end
        end)
    end

    -- Track properties
    if SETTINGS.Humanoid.TrackWalkSpeed then trackProperty("WalkSpeed", SETTINGS.Humanoid.TrackWalkSpeed) end
    if SETTINGS.Humanoid.TrackJumpPower then trackProperty("JumpPower", SETTINGS.Humanoid.TrackJumpPower) end
    if SETTINGS.Humanoid.TrackHealth then trackProperty("Health", SETTINGS.Humanoid.TrackHealth) end
    
    -- Track states
    if SETTINGS.Humanoid.TrackStates.Death and humanoid.Died then
        humanoid.Died:Connect(function()
            logEvent("DEATH", player.Name, "Character died")
            
            -- Damage source detection
            if SETTINGS.Humanoid.TrackHealth.TrackDamageSources then
                local lastHealth = humanoid.Health
                humanoid:GetPropertyChangedSignal("Health"):Connect(function()
                    local damage = lastHealth - humanoid.Health
                    if damage > 0 then
                        logEvent("DAMAGE", player.Name, 
                            string.format("Took %.1f damage", damage), {"Source unknown"})
                    end
                    lastHealth = humanoid.Health
                end)
            end
        end)
    end
    
    -- Additional state tracking
    if SETTINGS.Humanoid.TrackStates.Falling and humanoid:GetPropertyChangedSignal("FloorMaterial") then
        humanoid:GetPropertyChangedSignal("FloorMaterial"):Connect(function()
            if humanoid.FloorMaterial == Enum.Material.Air then
                logEvent("STATE", player.Name, "Started falling")
            end
        end)
    end
    
    if SETTINGS.Humanoid.TrackStates.Seated and humanoid:GetPropertyChangedSignal("Sit") then
        humanoid:GetPropertyChangedSignal("Sit"):Connect(function()
            logEvent("STATE", player.Name, humanoid.Sit and "Sat down" or "Stood up")
        end)
    end
end

-- Enhanced player monitoring
local function setupPlayer(player)
    if not player or PlayerData[player] then return end
    
    PlayerData[player] = {
        connections = {},
        lastCharacter = nil,
    }
    
    -- Log player join
    if SETTINGS.Player.TrackJoins then
        logEvent("JOIN", player.Name, "Joined the game", {
            "AccountAge: "..(player.AccountAge or "?"),
            "UserId: "..player.UserId
        })
    end
    
    -- Character monitoring
    local function onCharacterAdded(character)
        if SETTINGS.Character.TrackSpawns then
            logEvent("CHARACTER", player.Name, "Character spawned")
        end
        
        -- Check if this is a respawn
        if PlayerData[player].lastCharacter and SETTINGS.Character.TrackRespawns then
            logEvent("CHARACTER", player.Name, "Character respawned")
        end
        PlayerData[player].lastCharacter = character
        
        -- Monitor humanoid
        local humanoid = character:WaitForChild("Humanoid", 5)
        if humanoid then
            monitorHumanoid(player, humanoid)
        end
        
        -- Track despawn
        if SETTINGS.Character.TrackDespawns then
            character.AncestryChanged:Connect(function(_, parent)
                if not parent then
                    logEvent("CHARACTER", player.Name, "Character despawned")
                end
            end)
        end
        
        -- Tool tracking
        if SETTINGS.Advanced.TrackTools then
            character.ChildAdded:Connect(function(child)
                if child:IsA("Tool") then
                    logEvent("TOOL", player.Name, "Picked up tool", {child.Name})
                end
            end)
        end
    end
    
    -- Connect events
    local conn1 = player.CharacterAdded:Connect(onCharacterAdded)
    local conn2 = player.AncestryChanged:Connect(function()
        if not player:IsDescendantOf(game) and SETTINGS.Player.TrackLeaves then
            logEvent("LEAVE", player.Name, "Left the game")
            cleanupPlayer(player)
        end
    end)
    
    table.insert(PlayerData[player].connections, conn1)
    table.insert(PlayerData[player].connections, conn2)
    
    -- Admin action tracking
    if SETTINGS.Player.TrackAdminActions then
        -- Kick tracking
        local meta = getrawmetatable(player)
        local oldIndex = meta.__index
        
        setreadonly(meta, false)
        
        meta.__index = newcclosure(function(t, k)
            if k == "Kick" then
                return function(_, reason)
                    logEvent("KICK", player.Name, "Was kicked", {Reason = reason})
                    return oldIndex(t, k)(t, reason)
                end
            elseif k == "Teleport" and SETTINGS.Advanced.TrackTeleports then
                return function(_, placeId)
                    logEvent("TELEPORT", player.Name, "Teleporting", {PlaceId = placeId})
                    return oldIndex(t, k)(t, placeId)
                end
            end
            return oldIndex(t, k)
        end)
        
        setreadonly(meta, true)
    end
    
    -- Handle existing character
    if player.Character then
        task.defer(onCharacterAdded, player.Character)
    end
end

-- Cleanup function remains the same
local function cleanupPlayer(player)
    if not PlayerData[player] then return end
    
    for _, conn in ipairs(PlayerData[player].connections) do
        if conn.Connected then
            conn:Disconnect()
        end
    end
    
    PlayerData[player] = nil
end

-- Initialize for existing players
for _, player in ipairs(Players:GetPlayers()) do
    coroutine.wrap(function()
        local success, err = pcall(setupPlayer, player)
        if not success then
            logEvent("SYSTEM", nil, "Failed to setup player monitoring: "..tostring(err))
        end
    end)()
end

-- Connect future players
Players.PlayerAdded:Connect(function(player)
    coroutine.wrap(function()
        local success, err = pcall(setupPlayer, player)
        if not success then
            logEvent("SYSTEM", nil, "Failed to setup new player: "..tostring(err))
        end
    end)()
end)

Players.PlayerRemoving:Connect(function(player)
    if SETTINGS.Player.TrackLeaves then
        logEvent("LEAVE", player.Name, "Left the game")
    end
    cleanupPlayer(player)
end)

-- Private server detection
if SETTINGS.Advanced.TrackPrivateServers and RunService:IsStudio() == false then
    local success, isPrivate = pcall(function()
        return game.PrivateServerId ~= "" and game.PrivateServerOwnerId ~= 0
    end)
    
    if success and isPrivate then
        logEvent("SYSTEM", nil, "Private server detected", {
            "ServerId: "..game.PrivateServerId,
            "OwnerId: "..game.PrivateServerOwnerId
        })
    end
end

logEvent("SYSTEM", nil, "Advanced server monitor initialized", {
    "Version: 5.0",
    "Players: "..#Players:GetPlayers(),
    "Tracking: "..(SETTINGS.Security.ComplyWithRobloxToS and "Roblox-compliant" or "Extended")
})
