-- Variables
local player = game.Players.LocalPlayer
local mouse = player:GetMouse()
local camera = game.Workspace.CurrentCamera
local UIS = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

local lockedOnPlayer = nil
local isLockedOn = false
local highlight = nil -- The highlight object for the locked-on player
local nonSelectedHighlights = {} -- Table to store non-selected player highlights
local lockTransitionTime = 0.2 -- Time in seconds for smooth transition
local transitionProgress = 0 -- Progress from 0 to 1 for transition
local rightMouseDown = false -- Tracks if right mouse button is being held down

-- Function to get the 2D screen position of a part
local function getScreenPosition(part)
    local screenPoint, onScreen = camera:WorldToViewportPoint(part.Position)
    return Vector2.new(screenPoint.X, screenPoint.Y), onScreen
end

-- Function to check if there is a wall or object blocking the view of a player
local function isPlayerVisible(player)
    if player and player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
        local humanoidRootPart = player.Character.HumanoidRootPart
        local direction = (humanoidRootPart.Position - camera.CFrame.Position).Unit
        local raycastParams = RaycastParams.new()
        raycastParams.FilterType = Enum.RaycastFilterType.Blacklist
        raycastParams.FilterDescendantsInstances = {player.Character, game.Players.LocalPlayer.Character}

        local raycastResult = game.Workspace:Raycast(camera.CFrame.Position, direction * (humanoidRootPart.Position - camera.CFrame.Position).Magnitude, raycastParams)
        if raycastResult and raycastResult.Instance and not humanoidRootPart:IsAncestorOf(raycastResult.Instance) then
            return false 
        else
            return true 
        end
    end
    return false
end

-- Function to clear all non-selected player highlights
local function clearNonSelectedHighlights()
    for _, highlight in pairs(nonSelectedHighlights) do
        highlight:Destroy()
    end
    nonSelectedHighlights = {}
end

-- Function to find the closest player to the center of the screen
local function findClosestPlayer()
    local screenSize = camera.ViewportSize
    local screenCenter = Vector2.new(screenSize.X / 2, screenSize.Y / 2)

    local players = {}
    for _, p in ipairs(game.Players:GetPlayers()) do
        if p ~= player and p.Character and p.Character:FindFirstChild("HumanoidRootPart") then
            table.insert(players, p)
        end
    end

    local closestPlayer = nil
    local shortestDistance = math.huge

    for _, p in ipairs(players) do
        if p.Character and p.Character:FindFirstChild("Head") then
            local head = p.Character.Head
            local screenPos, onScreen = getScreenPosition(head)
            
            if onScreen and isPlayerVisible(p) then
                local distanceToCenter = (screenCenter - screenPos).Magnitude
                if distanceToCenter < shortestDistance then
                    closestPlayer = p
                    shortestDistance = distanceToCenter
                end
            end
        end
    end

    return closestPlayer
end

-- Function to lock onto a player
local function lockOn(newPlayer)
    if highlight then
        highlight:Destroy()
        highlight = nil
    end

    if newPlayer then
        lockedOnPlayer = newPlayer
        isLockedOn = true

        highlight = Instance.new("Highlight")
        highlight.Adornee = lockedOnPlayer.Character
        highlight.FillColor = Color3.fromRGB(255, 255, 0)
        highlight.OutlineColor = Color3.fromRGB(0, 0, 0)
        highlight.FillTransparency = 0.5
        highlight.OutlineTransparency = 0
        highlight.Parent = lockedOnPlayer.Character

        transitionProgress = 0 

        local humanoid = lockedOnPlayer.Character:FindFirstChildOfClass("Humanoid")
        if humanoid then
            humanoid.Died:Connect(function()
                if highlight then
                    highlight:Destroy()
                    highlight = nil
                end
                lockedOnPlayer = nil
                isLockedOn = false
            end)
        end
    else
        lockedOnPlayer = nil
        isLockedOn = false
    end
end

-- Function to update the camera position when locked onto a player
local function updateCamera(deltaTime)
    if isLockedOn and lockedOnPlayer and lockedOnPlayer.Character and lockedOnPlayer.Character:FindFirstChild("Head") then
        local targetPosition = lockedOnPlayer.Character.Head.Position
        local currentCameraPosition = camera.CFrame.Position

        if transitionProgress < 1 then
            transitionProgress = math.min(transitionProgress + deltaTime / lockTransitionTime, 1)
        end

        local targetCFrame = CFrame.new(currentCameraPosition, targetPosition)
        camera.CFrame = camera.CFrame:Lerp(targetCFrame, transitionProgress)
    elseif rightMouseDown then
        local closestPlayer = findClosestPlayer()
        if closestPlayer then
            lockOn(closestPlayer)
        else
            lockOn(nil) 
        end
    end
end

UIS.InputBegan:Connect(function(input, gameProcessedEvent)
    if gameProcessedEvent then return end
    if input.UserInputType == Enum.UserInputType.MouseButton2 then 
        rightMouseDown = true
        local closestPlayer = findClosestPlayer()
        lockOn(closestPlayer)
    end
end)

UIS.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton2 then 
        if highlight then
            highlight:Destroy()
            highlight = nil
        end
        isLockedOn = false
        lockedOnPlayer = nil
        rightMouseDown = false
        clearNonSelectedHighlights()
    end
end)

RunService.RenderStepped:Connect(function(deltaTime)
    if rightMouseDown then
        for _, p in ipairs(game.Players:GetPlayers()) do
            if p ~= player and p ~= lockedOnPlayer and p.Character and p.Character:FindFirstChild("Head") and not nonSelectedHighlights[p] then
                local highlight = Instance.new("Highlight")
                highlight.Adornee = p.Character
                highlight.FillColor = Color3.fromRGB(0, 0, 255)
                highlight.FillTransparency = 0.6
                highlight.OutlineTransparency = 1 -- No stroke
                highlight.Parent = p.Character
                nonSelectedHighlights[p] = highlight
            end
        end
    end
    updateCamera(deltaTime)
end)
