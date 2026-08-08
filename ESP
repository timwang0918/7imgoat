
getgenv().chams = {
    enabled = false, 
    outlineColor = Color3.fromRGB(255, 255, 255),
    fillColor = Color3.fromRGB(0, 0, 0), 
    fillTransparency = 1, 
    outlineTransparency = 0, 
    teamCheck = false 
}




local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local activeHighlights = {} 

local function isOnSameTeam(player)
    if getgenv().chams.teamCheck then
        return player.TeamColor == LocalPlayer.TeamColor
    end
    return false
end

local function createHighlight(character)
    local highlight = Instance.new("Highlight")
    highlight.Adornee = character
    highlight.FillTransparency = getgenv().chams.fillTransparency
    highlight.FillColor = getgenv().chams.fillColor
    highlight.OutlineColor = getgenv().chams.outlineColor
    highlight.OutlineTransparency = getgenv().chams.outlineTransparency
    highlight.Parent = character
    return highlight
end

local function removeHighlight(character)
    local highlight = character:FindFirstChildOfClass("Highlight")
    if highlight then
        highlight:Destroy()
    end
end

local function applyHighlight(player)
    if player == LocalPlayer or isOnSameTeam(player) then return end

    local character = player.Character
    if character then
        removeHighlight(character) 
        local highlight = createHighlight(character)
        activeHighlights[player] = highlight
    end
end

local function removeAllHighlights()
    for player, _ in pairs(activeHighlights) do
        if player.Character then
            removeHighlight(player.Character)
        end
    end
    activeHighlights = {}
end

local function monitorPlayers()

    for _, player in ipairs(Players:GetPlayers()) do
        if getgenv().chams.enabled then
            applyHighlight(player)
        else
            if player.Character then
                removeHighlight(player.Character)
            end
        end
    end
end


local function onPlayerAdded(player)
    player.CharacterAdded:Connect(function(character)
        if getgenv().chams.enabled then
            applyHighlight(player)
        end
    end)

    if player.Character and getgenv().chams.enabled then
        applyHighlight(player)
    end
end

local function onPlayerRemoving(player)
    if player.Character then
        removeHighlight(player.Character)
    end
    activeHighlights[player] = nil
end


task.spawn(function()
    while task.wait(0.1) do
        if getgenv().chams.enabled then
            monitorPlayers()
        else
            removeAllHighlights()
        end
    end
end)


for _, player in ipairs(Players:GetPlayers()) do
    onPlayerAdded(player)
end

Players.PlayerAdded:Connect(onPlayerAdded)
Players.PlayerRemoving:Connect(onPlayerRemoving)
