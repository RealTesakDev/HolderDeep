local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Lighting = game:GetService("Lighting")
local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer.PlayerGui
local camera = workspace.CurrentCamera

local function safeLoadModule(url)
    local success, module = pcall(function()
        local response = game:HttpGet(url)
        if not response then
            warn("No response from URL: " .. url)
            return nil
        end
        return loadstring(response)()
    end)
    
    if not success then
        warn("Failed to load module from: " .. url)
        warn("Error details: " .. tostring(module))
        return nil
    end
    
    return module
end

local ESP = safeLoadModule("https://raw.githubusercontent.com/RealTesakDev/HolderDeep/refs/heads/main/options.lua")
if not Options then return end

local function getInstancePosition(instance)
    if instance:IsA("BasePart") then
        return instance.Position
    elseif instance:IsA("Model") then
        return instance:GetPivot().Position
    else
        -- For other types, try to find a reference part
        local primaryPart = instance.PrimaryPart
        local lid = instance:FindFirstChild("Lid")
        local reference = primaryPart or lid or instance:FindFirstChildWhichIsA("BasePart")
        
        if reference then
            return reference.Position
        end
    end
    return nil
end

-- Utility Functions
local function getDistance(instance)
    local character = LocalPlayer.Character
    local rootPart = character and character:FindFirstChild("HumanoidRootPart")
    
    if not rootPart then return 0 end
    
    local targetPosition = getInstancePosition(instance)
    if not targetPosition then return 0 end
    
    return (rootPart.Position - targetPosition).Magnitude
end
local function createDrawing(class, properties)
    local drawing = Drawing.new(class)
    for property, value in pairs(properties) do
        drawing[property] = value
    end
    return drawing
end

local function createESP(instance, espType)
    if not instance:IsA("Model") and espType ~= "Chest" then return end
    
    local settings
    if espType == "Player" then
        settings = ESP.Players
    elseif espType == "Mob" then
        settings = ESP.Mobs
    else
        settings = ESP.Chests
    end
    
    local esp = {
        Drawings = {
            Info = nil,
            HealthBarOutline = nil,
            HealthBarBackground = nil,
            HealthBarFill = nil,
            Tracer = nil
        },
        Connection = nil
    }

    local function updateFont()
        if esp.Drawings.Info then
            esp.Drawings.Info.Font = settings.Text.Font
        end
    end
    
    -- Create Text ESP
    if settings.Text.Enabled then
        esp.Drawings.Info = createDrawing("Text", {
            Text = "",
            Size = settings.Text.Size,
            Center = true,
            Outline = settings.Text.Outline,
            OutlineColor = settings.Text.OutlineColor,
            Color = settings.Text.Color,
            Font = settings.Text.Font,
            Visible = false
        })
    end

    esp.UpdateFont = updateFont
    
    -- Create Health Bar (Players only)
    if espType == "Player" and settings.HealthBar.Enabled then
        esp.Drawings.HealthBarOutline = createDrawing("Square", {
            Thickness = 1,
            Color = settings.HealthBar.OutlineColor,
            Filled = false,
            Visible = false
        })
        
        esp.Drawings.HealthBarBackground = createDrawing("Square", {
            Color = settings.HealthBar.BackgroundColor,
            Filled = true,
            Visible = false
        })
        
        esp.Drawings.HealthBarFill = createDrawing("Square", {
            Color = settings.HealthBar.Color,
            Filled = true,
            Visible = false
        })
    end
    
    -- Create Tracer
    if settings.Tracer.Enabled then
        esp.Drawings.Tracer = createDrawing("Line", {
            Thickness = settings.Tracer.Thickness,
            Color = settings.Tracer.Color,
            Transparency = settings.Tracer.Transparency,
            Visible = false
        })
    end
    
    -- Modified Update Function with Toggle Checks
    local function updateESP()
        -- First check if main ESP and type-specific ESP are enabled
        if not ESP.Enabled or not settings.Enabled then
            -- Hide all drawings if ESP is disabled
            for _, drawing in pairs(esp.Drawings) do
                if drawing then
                    drawing.Visible = false
                end
            end
            return
        end
        
        if not instance:IsDescendantOf(workspace) then
            esp:Destroy()
            return
        end
        
        local root
        if espType == "Chest" then
            root = instance
        else
            root = instance:FindFirstChild("HumanoidRootPart") or instance.PrimaryPart
        end
        
        if not root then return end
        
        local position = getInstancePosition(instance)
        if not position then return end
        
        local screenPos, onScreen = workspace.CurrentCamera:WorldToViewportPoint(position)
        local distance = getDistance(instance)
        
        -- Check if player is on screen and within max distance
        local isVisible = onScreen and distance <= settings.MaxDistance
        
        -- Handle team check for players
        if espType == "Player" and settings.IgnoreTeammates then
            local player = Players:GetPlayerFromCharacter(instance)
            if player and player.Team == LocalPlayer.Team then
                isVisible = false
            end
        end
        
        if isVisible then
            local basePosition = Vector2.new(screenPos.X, screenPos.Y)
            local scaleFactor = 1 / (screenPos.Z * 0.75)
            local textOffset = Vector2.new(0, -45 * scaleFactor)
            
            -- Update Text ESP
            if esp.Drawings.Info and settings.Text.Enabled then
                esp.Drawings.Info.Position = basePosition + textOffset
                
                local infoText = ""
                if espType == "Chest" then
                    infoText = "Chest"
                    if settings.ShowDistance then
                        infoText = string.format("%s [%d]", infoText, distance)
                    end
                else
                    local humanoid = instance:FindFirstChild("Humanoid")
                    if humanoid then
                        local name = espType == "Player" and instance.Name or (instance:GetAttribute("MOB_rich_name") or instance.Name)
                        infoText = name
                        if settings.ShowHealth and humanoid then
                            infoText = string.format("%s [%d/%d]", infoText, humanoid.Health, humanoid.MaxHealth)
                        end
                        if settings.ShowDistance then
                            infoText = string.format("%s [%d]", infoText, distance)
                        end
                    end
                end
                
                esp.Drawings.Info.Text = infoText
                esp.Drawings.Info.Visible = true
            end
            
            -- Update Health Bar
            if espType == "Player" and settings.HealthBar.Enabled then
                local humanoid = instance:FindFirstChild("Humanoid")
                if humanoid and esp.Drawings.HealthBarOutline then
                    local healthBarWidth = settings.HealthBar.Width
                    local healthBarHeight = settings.HealthBar.Height * scaleFactor
                    local healthBarPosition = basePosition + Vector2.new(-30 * scaleFactor, -healthBarHeight/2)
                    
                    esp.Drawings.HealthBarOutline.Size = Vector2.new(healthBarWidth + 2, healthBarHeight + 2)
                    esp.Drawings.HealthBarOutline.Position = healthBarPosition - Vector2.new(1, 1)
                    esp.Drawings.HealthBarOutline.Visible = true
                    
                    esp.Drawings.HealthBarBackground.Size = Vector2.new(healthBarWidth, healthBarHeight)
                    esp.Drawings.HealthBarBackground.Position = healthBarPosition
                    esp.Drawings.HealthBarBackground.Visible = true
                    
                    local healthRatio = humanoid.Health / humanoid.MaxHealth
                    esp.Drawings.HealthBarFill.Size = Vector2.new(healthBarWidth, healthBarHeight * healthRatio)
                    esp.Drawings.HealthBarFill.Position = Vector2.new(
                        healthBarPosition.X,
                        healthBarPosition.Y + (healthBarHeight * (1 - healthRatio))
                    )
                    esp.Drawings.HealthBarFill.Visible = true
                end
            end
            
            -- Update Tracer
            if esp.Drawings.Tracer and settings.Tracer.Enabled then
                local origin
                if settings.Tracer.Origin == "Mouse" then
                    origin = Vector2.new(LocalPlayer:GetMouse().X, LocalPlayer:GetMouse().Y)
                elseif settings.Tracer.Origin == "Center" then
                    origin = Vector2.new(workspace.CurrentCamera.ViewportSize.X/2, workspace.CurrentCamera.ViewportSize.Y/2)
                else
                    origin = Vector2.new(workspace.CurrentCamera.ViewportSize.X/2, workspace.CurrentCamera.ViewportSize.Y)
                end
                
                esp.Drawings.Tracer.From = origin
                esp.Drawings.Tracer.To = basePosition
                esp.Drawings.Tracer.Visible = true
            end
        else
            -- Hide all drawings if not visible
            for _, drawing in pairs(esp.Drawings) do
                if drawing then
                    drawing.Visible = false
                end
            end
        end
    end
    
    -- Cleanup Function
    function esp:Destroy()
        for _, drawing in pairs(self.Drawings) do
            if drawing then
                drawing:Remove()
            end
        end
        if self.Connection then
            self.Connection:Disconnect()
        end
    end
    
    -- Connect update function
    esp.Connection = RunService.RenderStepped:Connect(updateESP)
    updateESP() -- Initial update
    
    return esp
end

-- Main ESP Management
local espObjects = {}

-- Chest ESP
local function onChestAdded(chest)
    if chest:IsA("Model") and chest:FindFirstChild("Lid") then
        espObjects[chest] = createESP(chest, "Chest")
    end
end

local function onChestRemoved(chest)
    if espObjects[chest] then
        espObjects[chest]:Destroy()
        espObjects[chest] = nil
    end
end

-- Mob ESP
local function onMobAdded(mob)
    if mob.Name:sub(1, 1) == "." then
        espObjects[mob] = createESP(mob, "Mob")
    end
end

local function onMobRemoved(mob)
    if espObjects[mob] then
        espObjects[mob]:Destroy()
        espObjects[mob] = nil
    end
end

-- Player ESP
local function onPlayerAdded(player)
    local function characterAdded(character)
        if character and player ~= LocalPlayer then
            espObjects[player] = createESP(character, "Player")
        end
    end
    
    player.CharacterAdded:Connect(characterAdded)
    if player.Character then
        characterAdded(player.Character)
    end
end

local function onPlayerRemoving(player)
    if espObjects[player] then
        espObjects[player]:Destroy()
        espObjects[player] = nil
    end
end

-- Initialize
for _, chest in pairs(workspace.Thrown:GetChildren()) do
    if chest:FindFirstChild("Lid") then
        onChestAdded(chest)
    end
end

for _, mob in pairs(workspace.Live:GetChildren()) do
    if mob.Name:sub(1, 1) == "." then
        onMobAdded(mob)
    end
end

for _, player in pairs(Players:GetPlayers()) do
    if player ~= LocalPlayer then
        onPlayerAdded(player)
    end
end

-- Connect events
workspace.Thrown.ChildAdded:Connect(onChestAdded)
workspace.Thrown.ChildRemoved:Connect(onChestRemoved)
workspace.Live.ChildAdded:Connect(onMobAdded)
workspace.Live.ChildRemoved:Connect(onMobRemoved)
Players.PlayerAdded:Connect(onPlayerAdded)
Players.PlayerRemoving:Connect(onPlayerRemoving)
