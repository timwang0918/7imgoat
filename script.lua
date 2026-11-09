local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local CoreGui = game:GetService("CoreGui")
local Workspace = game:GetService("Workspace")
local TweenService = game:GetService("TweenService") 
local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera

-- 安全 GUI 父級容器
local TargetParent = (gethui and gethui()) or CoreGui or LocalPlayer:WaitForChild("PlayerGui")

-- ==========================================
-- 1. 核心配置
-- ==========================================
local ESPSettings = { 
    Box = false, 
    Skeleton = false, 
    Health = false, 
    HeadESP = false,    
    HeadESPColorIndex = 1, 
    HeadESPGradient = false,                        
    HeadESPColor1 = Color3.fromRGB(91, 168, 252),    
    HeadESPColor2 = Color3.fromRGB(255, 130, 240),   
    NameShow = false,         
    
    Aimbot = false,     
    AimbotWallCheck = true, 
    AimbotLockNearest = false, 
    AimbotFOV = 150,        
    AimbotMode = "Rage Lock", 
    CustomHeadChance = 50,    
    CustomBodyChance = 50,    
    AimbotSmoothness = 100,   

    SilentAim = false,
    SilentAimFOV = 150,
    SilentAimWallCheck = true,
    
    Ragebot = false,           
    RageAttackSpeed = 0.2,     
    RageHideVoid = 0.4,        
    RagebotHitPartIndex = 1, 
    
    Flight = false,
    Speed = false,
    SpeedValue = 50, 
    Spin = false,
    SpinSpeed = 20,
    Noclip = false,
    AutoJump = false,

    -- Misc 配置 (保留原本的)
    AutoRevive = false,
    VoidDodge = false,
    PlayerFOV = 600,
    SpoofSelf = false,
    SpoofSelfName = "fate",
    SpoofOthers = false,
    SpoofOthersName = " ",
    
    -- 🌫️ 新增：霧與光照配置
    Fog = false,
    LightingColorSwitch = false,
    LightingColor = Color3.fromRGB(255, 255, 255),
    
    -- 👁️ 新增：第三視角配置
    ThirdPerson = false,

    -- 🌟 保留原本的動作播放配置
    EmoteTrack = false,       
    EmoteID = "14884037146",  

    -- ❄️ 保留原本的世界環境配置
    Snow = false,                              
    SnowColor1 = Color3.fromRGB(255, 255, 255), 
    SnowColor2 = Color3.fromRGB(200, 225, 255)  
}

local HitParts = {"Head", "HumanoidRootPart", "LeftFoot"}
local HitPartNames = {"頭部 (Head)", "身體 (Body)", "腳部 (Foot)"}
local ESPColors = {Color3.fromRGB(91, 168, 252), Color3.fromRGB(255, 130, 240), Color3.fromRGB(50, 255, 180), Color3.fromRGB(255, 230, 100)}
local ESPColorNames = {"霓虹藍", "霓光粉", "極光綠", "活力黃"}

local ESPTable = {} 
local Connections = {} 
local isRightMouseDown = false 
local ragebotActiveThread = false 
local rageBtnGlobal = nil 

-- Emote 運行時變數
local CurrentAnimationTrack = nil

-- Void Dodge 虛擬本地代理分身
local VirtualProxy = nil
local VirtualGroundPos = Vector3.new(0, 10, 0)

-- Auto Revive 狀態鎖
local isDead = false
local canSpamRevive = false

-- FOV 圈圈
local FOVCircle = Drawing.new("Circle")
FOVCircle.Color = Color3.fromRGB(91, 168, 252)
FOVCircle.Thickness = 1.5
FOVCircle.NumSides = 60
FOVCircle.Filled = false
FOVCircle.Transparency = 0.6

local SilentFOVCircle = Drawing.new("Circle")
SilentFOVCircle.Color = Color3.fromRGB(255, 130, 240)
SilentFOVCircle.Thickness = 1.5
SilentFOVCircle.NumSides = 60
SilentFOVCircle.Filled = false
SilentFOVCircle.Transparency = 0.6

-- ❄️ 下雪系統：純視覺天氣特效，跟隨鏡頭產生大範圍降雪
local SnowEmitterPart = Instance.new("Part")
SnowEmitterPart.Name = "7imgoat_SnowEmitter"
SnowEmitterPart.Size = Vector3.new(120, 1, 120)
SnowEmitterPart.Transparency = 1
SnowEmitterPart.Anchored = true
SnowEmitterPart.CanCollide = false
SnowEmitterPart.CanQuery = false
SnowEmitterPart.CastShadow = false

local SnowEmitter = Instance.new("ParticleEmitter")
SnowEmitter.Name = "7imgoat_SnowParticles"
SnowEmitter.Texture = "rbxasset://textures/particles/sparkles_main.dds" -- ⚠️ 原本的 snow_storm.dds 不是有效的內建資源路徑,導致粒子無法渲染,已改為確認可用的內建材質
SnowEmitter.Rate = 0
SnowEmitter.Lifetime = NumberRange.new(4, 6)
SnowEmitter.Speed = NumberRange.new(2, 5)
SnowEmitter.SpreadAngle = Vector2.new(35, 35) -- 縮小擴散角度,讓雪花朝下飄落而非四散
SnowEmitter.Size = NumberSequence.new({
    NumberSequenceKeypoint.new(0, 0.35),
    NumberSequenceKeypoint.new(1, 0.35)
})
SnowEmitter.Transparency = NumberSequence.new({
    NumberSequenceKeypoint.new(0, 0.2),
    NumberSequenceKeypoint.new(1, 1)
})
SnowEmitter.Acceleration = Vector3.new(0, -8, 0)
SnowEmitter.RotSpeed = NumberRange.new(-30, 30)
SnowEmitter.EmissionDirection = Enum.NormalId.Bottom -- 確保從發射板的下方往下噴發
SnowEmitter.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0, ESPSettings.SnowColor1),
    ColorSequenceKeypoint.new(1, ESPSettings.SnowColor2)
})
SnowEmitter.Parent = SnowEmitterPart

local function UpdateSnowColors()
    SnowEmitter.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, ESPSettings.SnowColor1),
        ColorSequenceKeypoint.new(1, ESPSettings.SnowColor2)
    })
end

-- 主題漸層與排版輔助函式
local function ApplyThemeGradient(instance)
    local Gradient = Instance.new("UIGradient")
    Gradient.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(91, 168, 252)),  
        ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 130, 240))  
    })
    Gradient.Rotation = 45
    Gradient.Parent = instance
    return Gradient
end

-- ==========================================
-- 2. GUI 主面板 
-- ==========================================
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "7imgoat"
ScreenGui.Parent = TargetParent
ScreenGui.ResetOnSpawn = false

SnowEmitterPart.Parent = Workspace

local MainFrame = Instance.new("Frame")
MainFrame.Name = "Main"
MainFrame.Size = UDim2.new(0, 540, 0, 420) 
MainFrame.Position = UDim2.new(0.3, 0, 0.25, 0)
MainFrame.BackgroundColor3 = Color3.fromRGB(15, 16, 22)
MainFrame.BorderSizePixel = 0
MainFrame.Active = true
MainFrame.Draggable = true
MainFrame.ZIndex = 1
MainFrame.Visible = false 
MainFrame.Parent = ScreenGui

local MainCorner = Instance.new("UICorner")
MainCorner.CornerRadius = UDim.new(0, 8)
MainCorner.Parent = MainFrame

local MainStroke = Instance.new("UIStroke")
MainStroke.Thickness = 1
MainStroke.Color = Color3.fromRGB(45, 48, 60)
MainStroke.Transparency = 0.2
MainStroke.Parent = MainFrame

local Title = Instance.new("TextLabel")
Title.Size = UDim2.new(1, 0, 0, 40)
Title.BackgroundColor3 = Color3.fromRGB(22, 24, 33)
Title.BorderSizePixel = 0
Title.Text = "   7imgoat"
Title.TextColor3 = Color3.fromRGB(255, 255, 255)
Title.TextXAlignment = Enum.TextXAlignment.Left
Title.Font = Enum.Font.SourceSansBold
Title.TextSize = 15
Title.ZIndex = 2
Title.Parent = MainFrame

local TitleCorner = Instance.new("UICorner")
TitleCorner.CornerRadius = UDim.new(0, 8)
TitleCorner.Parent = Title

local TitleMask = Instance.new("Frame")
TitleMask.Size = UDim2.new(1, 0, 0, 10)
TitleMask.Position = UDim2.new(0, 0, 1, -10)
TitleMask.BackgroundColor3 = Color3.fromRGB(22, 24, 33)
TitleMask.BorderSizePixel = 0
TitleMask.ZIndex = 2
TitleMask.Parent = Title

local Sidebar = Instance.new("Frame")
Sidebar.Size = UDim2.new(0, 130, 1, -40)
Sidebar.Position = UDim2.new(0, 0, 0, 40)
Sidebar.BackgroundColor3 = Color3.fromRGB(18, 19, 26)
Sidebar.BorderSizePixel = 0
Sidebar.ZIndex = 2
Sidebar.Parent = MainFrame

local ContentContainer = Instance.new("Frame")
ContentContainer.Size = UDim2.new(1, -130, 1, -40)
ContentContainer.Position = UDim2.new(0, 130, 0, 40)
ContentContainer.BackgroundTransparency = 1
ContentContainer.ZIndex = 2
ContentContainer.Parent = MainFrame

local Pages = {}
local PageButtons = {}

local function CreatePage(pageName)
    local PageFrame = Instance.new("ScrollingFrame") 
    PageFrame.Size = UDim2.new(1, 0, 1, 0)
    PageFrame.BackgroundTransparency = 1
    PageFrame.Visible = false
    PageFrame.ZIndex = 3
    PageFrame.CanvasSize = UDim2.new(0, 0, 0, 550) -- 微調高度容納新功能
    PageFrame.ScrollBarThickness = 2
    PageFrame.Parent = ContentContainer
    Pages[pageName] = PageFrame
    return PageFrame
end

local VisualPage = CreatePage("Visual")
local AimPage = CreatePage("Lock Aim")
local SilentPage = CreatePage("Silent Aim")
local RagePage = CreatePage("Ragebot")
local MovementPage = CreatePage("Movement")
local WorldPage = CreatePage("World")
local MiscPage = CreatePage("Misc")

local tabIcons = {
    ["Visual"] = "👁️",
    ["Lock Aim"] = "🎯",
    ["Silent Aim"] = "🔇",
    ["Ragebot"] = "🔥",
    ["Movement"] = "🏃",
    ["World"] = "🌎",
    ["Misc"] = "🧩"
}
local tabNames = {"Visual", "Lock Aim", "Silent Aim", "Ragebot", "Movement", "World", "Misc"}
for i, name in ipairs(tabNames) do
    local Btn = Instance.new("TextButton")
    Btn.Size = UDim2.new(1, -12, 0, 32)
    Btn.Position = UDim2.new(0, 6, 0, 10 + (i - 1) * 36)
    Btn.BackgroundColor3 = Color3.fromRGB(24, 26, 35)
    Btn.BorderSizePixel = 0
    Btn.Text = "  " .. (tabIcons[name] or "•") .. "  " .. name
    Btn.TextColor3 = Color3.fromRGB(140, 145, 160)
    Btn.Font = Enum.Font.SourceSansBold
    Btn.TextSize = 13
    Btn.ZIndex = 4
    Btn.Parent = Sidebar
    
    local BtnCorner = Instance.new("UICorner")
    BtnCorner.CornerRadius = UDim.new(0, 6)
    BtnCorner.Parent = Btn

    local BtnStroke = Instance.new("UIStroke")
    BtnStroke.Thickness = 1
    BtnStroke.Color = Color3.fromRGB(45, 48, 62)
    BtnStroke.Parent = Btn
    
    PageButtons[name] = Btn
    
    Btn.MouseButton1Click:Connect(function()
        for pName, frame in pairs(Pages) do frame.Visible = (pName == name) end
        for pName, button in pairs(PageButtons) do
            local isCurrent = (pName == name)
            button.BackgroundColor3 = isCurrent and Color3.fromRGB(35, 38, 55) or Color3.fromRGB(24, 26, 35)
            button.TextColor3 = isCurrent and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(140, 145, 160)
            button:FindFirstChildOfClass("UIStroke").Color = isCurrent and Color3.fromRGB(91, 168, 252) or Color3.fromRGB(45, 48, 62)
        end
    end)
end

local ExitBtn = Instance.new("TextButton")
ExitBtn.Size = UDim2.new(1, -12, 0, 32)
ExitBtn.Position = UDim2.new(0, 6, 1, -42)
ExitBtn.BackgroundColor3 = Color3.fromRGB(35, 22, 26)
ExitBtn.BorderSizePixel = 0
ExitBtn.Text = "❌ UNLOAD"
ExitBtn.TextColor3 = Color3.fromRGB(255, 150, 150)
ExitBtn.Font = Enum.Font.SourceSansBold
ExitBtn.TextSize = 13
ExitBtn.ZIndex = 4
ExitBtn.Parent = Sidebar

local ExitCorner = Instance.new("UICorner")
ExitCorner.CornerRadius = UDim.new(0, 6)
ExitCorner.Parent = ExitBtn

-- 前端動作更新控制函式
local UpdateEmotePlayback

local function AddButton(displayName, settingKey, parentPage, yIndex, isSub)
    local Btn = Instance.new("TextButton")
    Btn.Size = isSub and UDim2.new(1, -30, 0, 32) or UDim2.new(1, -16, 0, 34)
    Btn.Position = isSub and UDim2.new(0, 20, 0, 12 + (yIndex - 1) * 38) or UDim2.new(0, 8, 0, 12 + (yIndex - 1) * 38)
    Btn.BorderSizePixel = 0
    Btn.Font = Enum.Font.SourceSansSemibold
    Btn.TextSize = 14
    Btn.Text = displayName
    Btn.ZIndex = 5
    Btn.Parent = parentPage

    local BtnCorner = Instance.new("UICorner")
    BtnCorner.CornerRadius = UDim.new(0, 6)
    BtnCorner.Parent = Btn

    local BtnStroke = Instance.new("UIStroke")
    BtnStroke.Thickness = 1
    BtnStroke.Parent = Btn

    local UIUiGradient = nil

    if settingKey == "Ragebot" then rageBtnGlobal = Btn end

    local function updateUI()
        local enabled = ESPSettings[settingKey]
        if settingKey == "Ragebot" then
            Btn.Text = enabled and "🔥 Ragebot [P]: ON" or "🔥 Ragebot [P]: OFF"
        else
            Btn.Text = displayName
        end

        if enabled then
            Btn.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
            Btn.TextColor3 = Color3.fromRGB(15, 15, 20)
            BtnStroke.Color = Color3.fromRGB(255, 255, 255)
            BtnStroke.Transparency = 0.8
            if not UIUiGradient then UIUiGradient = ApplyThemeGradient(Btn) end
        else
            Btn.BackgroundColor3 = Color3.fromRGB(22, 24, 32)
            Btn.TextColor3 = Color3.fromRGB(170, 175, 190)
            BtnStroke.Color = Color3.fromRGB(45, 48, 62)
            BtnStroke.Transparency = 0
            if UIUiGradient then UIUiGradient:Destroy() UIUiGradient = nil end
        end
    end

    Btn.MouseButton1Click:Connect(function()
        ESPSettings[settingKey] = not ESPSettings[settingKey]
        if settingKey == "VoidDodge" then
            if ESPSettings.VoidDodge and LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
                VirtualGroundPos = LocalPlayer.Character.HumanoidRootPart.Position
                if not VirtualProxy then
                    VirtualProxy = Instance.new("Part")
                    VirtualProxy.Name = "VirtualLocalProxy"
                    VirtualProxy.Size = Vector3.new(2, 2, 2)
                    VirtualProxy.Transparency = 0.6
                    VirtualProxy.Color = Color3.fromRGB(91, 168, 252)
                    VirtualProxy.Anchored = true
                    VirtualProxy.CanCollide = false
                    VirtualProxy.Parent = Workspace
                end
            else
                if VirtualProxy then VirtualProxy:Destroy() VirtualProxy = nil end
            end
        elseif settingKey == "EmoteTrack" then
            if UpdateEmotePlayback then UpdateEmotePlayback() end -- 當點擊動作開關時發送通知
        end
        updateUI()
    end)
    updateUI()
    return Btn
end

local function AddSlider(name, valueKey, min, max, parentPage, yIndex, isSub)
    local SliderFrame = Instance.new("Frame")
    SliderFrame.Size = isSub and UDim2.new(1, -30, 0, 36) or UDim2.new(1, -16, 0, 38)
    SliderFrame.Position = isSub and UDim2.new(0, 20, 0, 12 + (yIndex - 1) * 38) or UDim2.new(0, 8, 0, 12 + (yIndex - 1) * 38)
    SliderFrame.BackgroundColor3 = Color3.fromRGB(22, 24, 32)
    SliderFrame.BorderSizePixel = 0
    SliderFrame.ZIndex = 5
    SliderFrame.Parent = parentPage

    local SFCorner = Instance.new("UICorner")
    SFCorner.CornerRadius = UDim.new(0, 6)
    SFCorner.Parent = SliderFrame

    local SFStroke = Instance.new("UIStroke")
    SFStroke.Thickness = 1
    SFStroke.Color = Color3.fromRGB(45, 48, 62)
    SFStroke.Parent = SliderFrame

    local Label = Instance.new("TextLabel")
    Label.Size = UDim2.new(1, 0, 0, 14)
    Label.Position = UDim2.new(0, 8, 0, 2)
    Label.BackgroundTransparency = 1
    Label.Text = string.format("%s: %.1f", name, ESPSettings[valueKey])
    Label.TextColor3 = Color3.fromRGB(220, 220, 220)
    Label.Font = Enum.Font.SourceSansSemibold
    Label.TextSize = 13
    Label.TextXAlignment = Enum.TextXAlignment.Left
    Label.ZIndex = 6
    Label.Parent = SliderFrame

    local Container = Instance.new("Frame")
    Container.Size = UDim2.new(1, -16, 0, 5)
    Container.Position = UDim2.new(0, 8, 0, 22)
    Container.BackgroundColor3 = Color3.fromRGB(38, 40, 52)
    Container.BorderSizePixel = 0
    Container.ZIndex = 6
    Container.Parent = SliderFrame

    local Fill = Instance.new("Frame")
    local startRatio = (ESPSettings[valueKey] - min) / (max - min)
    Fill.Size = UDim2.new(startRatio, 0, 1, 0)
    Fill.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    Fill.BorderSizePixel = 0
    Fill.ZIndex = 6
    Fill.Parent = Container
    ApplyThemeGradient(Fill)

    local Trigger = Instance.new("TextButton")
    Trigger.Size = UDim2.new(1, 0, 1, 0)
    Trigger.BackgroundTransparency = 1
    Trigger.Text = ""
    Trigger.ZIndex = 7
    Trigger.Parent = Container

    local function UpdateSlider(input)
        local percentage = math.clamp((input.Position.X - Container.AbsolutePosition.X) / Container.AbsoluteSize.X, 0, 1)
        Fill.Size = UDim2.new(percentage, 0, 1, 0)
        local rawVal = min + (percentage * (max - min))
        if max > 10 then
            ESPSettings[valueKey] = math.round(rawVal)
            Label.Text = name .. ": " .. ESPSettings[valueKey]
        else
            ESPSettings[valueKey] = math.round(rawVal * 10) / 10
            Label.Text = string.format("%s: %.1fs", name, ESPSettings[valueKey])
        end
    end

    local dragging = false
    Trigger.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then dragging = true UpdateSlider(input) end
    end)
    table.insert(Connections, UserInputService.InputChanged:Connect(function(input)
        if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then UpdateSlider(input) end
    end))
    table.insert(Connections, UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then dragging = false end
    end))
    return SliderFrame
end

-- ==========================================
-- 2.5 新版卡片式元件 (僅供 Visual / Movement / World / Misc 使用)
-- ==========================================
local function AddToggle(displayName, settingKey, parentPage, yIndex, isSub)
    local Card = Instance.new("Frame")
    Card.Size = isSub and UDim2.new(1, -30, 0, 34) or UDim2.new(1, -16, 0, 36)
    Card.Position = isSub and UDim2.new(0, 20, 0, 12 + (yIndex - 1) * 38) or UDim2.new(0, 8, 0, 12 + (yIndex - 1) * 38)
    Card.BackgroundColor3 = Color3.fromRGB(22, 24, 32)
    Card.BorderSizePixel = 0
    Card.ZIndex = 5
    Card.Parent = parentPage

    local Corner = Instance.new("UICorner")
    Corner.CornerRadius = UDim.new(0, 8)
    Corner.Parent = Card

    local Stroke = Instance.new("UIStroke")
    Stroke.Thickness = 1
    Stroke.Color = Color3.fromRGB(45, 48, 62)
    Stroke.Parent = Card

    local Label = Instance.new("TextLabel")
    Label.Size = UDim2.new(1, -64, 1, 0)
    Label.Position = UDim2.new(0, 12, 0, 0)
    Label.BackgroundTransparency = 1
    Label.Text = displayName
    Label.TextColor3 = Color3.fromRGB(220, 222, 230)
    Label.Font = Enum.Font.SourceSansSemibold
    Label.TextSize = 14
    Label.TextXAlignment = Enum.TextXAlignment.Left
    Label.ZIndex = 6
    Label.Parent = Card

    local SwitchTrack = Instance.new("Frame")
    SwitchTrack.Size = UDim2.new(0, 42, 0, 22)
    SwitchTrack.AnchorPoint = Vector2.new(1, 0.5)
    SwitchTrack.Position = UDim2.new(1, -12, 0.5, 0)
    SwitchTrack.BackgroundColor3 = Color3.fromRGB(45, 48, 62)
    SwitchTrack.BorderSizePixel = 0
    SwitchTrack.ZIndex = 6
    SwitchTrack.Parent = Card

    local TrackCorner = Instance.new("UICorner")
    TrackCorner.CornerRadius = UDim.new(1, 0)
    TrackCorner.Parent = SwitchTrack

    local Knob = Instance.new("Frame")
    Knob.Size = UDim2.new(0, 16, 0, 16)
    Knob.Position = UDim2.new(0, 3, 0.5, -8)
    Knob.BackgroundColor3 = Color3.fromRGB(170, 175, 190)
    Knob.BorderSizePixel = 0
    Knob.ZIndex = 7
    Knob.Parent = SwitchTrack

    local KnobCorner = Instance.new("UICorner")
    KnobCorner.CornerRadius = UDim.new(1, 0)
    KnobCorner.Parent = Knob

    local Click = Instance.new("TextButton")
    Click.Size = UDim2.new(1, 0, 1, 0)
    Click.BackgroundTransparency = 1
    Click.Text = ""
    Click.ZIndex = 8
    Click.Parent = Card

    local function updateUI()
        local enabled = ESPSettings[settingKey]
        TweenService:Create(Knob, TweenInfo.new(0.15, Enum.EasingStyle.Quad), {
            Position = enabled and UDim2.new(1, -19, 0.5, -8) or UDim2.new(0, 3, 0.5, -8),
            BackgroundColor3 = enabled and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(170, 175, 190)
        }):Play()
        TweenService:Create(SwitchTrack, TweenInfo.new(0.15), {
            BackgroundColor3 = enabled and Color3.fromRGB(91, 168, 252) or Color3.fromRGB(45, 48, 62)
        }):Play()
        if enabled and not SwitchTrack:FindFirstChildOfClass("UIGradient") then ApplyThemeGradient(SwitchTrack) end
        if not enabled then
            local g = SwitchTrack:FindFirstChildOfClass("UIGradient")
            if g then g:Destroy() end
        end
    end

    Click.MouseButton1Click:Connect(function()
        ESPSettings[settingKey] = not ESPSettings[settingKey]
        if settingKey == "VoidDodge" then
            if ESPSettings.VoidDodge and LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
                VirtualGroundPos = LocalPlayer.Character.HumanoidRootPart.Position
                if not VirtualProxy then
                    VirtualProxy = Instance.new("Part")
                    VirtualProxy.Name = "VirtualLocalProxy"
                    VirtualProxy.Size = Vector3.new(2, 2, 2)
                    VirtualProxy.Transparency = 0.6
                    VirtualProxy.Color = Color3.fromRGB(91, 168, 252)
                    VirtualProxy.Anchored = true
                    VirtualProxy.CanCollide = false
                    VirtualProxy.Parent = Workspace
                end
            else
                if VirtualProxy then VirtualProxy:Destroy() VirtualProxy = nil end
            end
        elseif settingKey == "EmoteTrack" then
            if UpdateEmotePlayback then UpdateEmotePlayback() end
        end
        updateUI()
    end)
    updateUI()
    return Card
end

local function AddModernSlider(name, valueKey, min, max, parentPage, yIndex, isSub)
    local Card = Instance.new("Frame")
    Card.Size = isSub and UDim2.new(1, -30, 0, 36) or UDim2.new(1, -16, 0, 38)
    Card.Position = isSub and UDim2.new(0, 20, 0, 12 + (yIndex - 1) * 38) or UDim2.new(0, 8, 0, 12 + (yIndex - 1) * 38)
    Card.BackgroundColor3 = Color3.fromRGB(22, 24, 32)
    Card.BorderSizePixel = 0
    Card.ZIndex = 5
    Card.Parent = parentPage

    local Corner = Instance.new("UICorner")
    Corner.CornerRadius = UDim.new(0, 8)
    Corner.Parent = Card

    local Stroke = Instance.new("UIStroke")
    Stroke.Thickness = 1
    Stroke.Color = Color3.fromRGB(45, 48, 62)
    Stroke.Parent = Card

    local Label = Instance.new("TextLabel")
    Label.Size = UDim2.new(1, -16, 0, 14)
    Label.Position = UDim2.new(0, 10, 0, 3)
    Label.BackgroundTransparency = 1
    Label.Text = string.format("%s: %.1f", name, ESPSettings[valueKey])
    Label.TextColor3 = Color3.fromRGB(220, 222, 230)
    Label.Font = Enum.Font.SourceSansSemibold
    Label.TextSize = 13
    Label.TextXAlignment = Enum.TextXAlignment.Left
    Label.ZIndex = 6
    Label.Parent = Card

    local Track = Instance.new("Frame")
    Track.Size = UDim2.new(1, -24, 0, 4)
    Track.Position = UDim2.new(0, 12, 0, 25)
    Track.BackgroundColor3 = Color3.fromRGB(40, 42, 55)
    Track.BorderSizePixel = 0
    Track.ZIndex = 6
    Track.Parent = Card

    local TrackCorner = Instance.new("UICorner")
    TrackCorner.CornerRadius = UDim.new(1, 0)
    TrackCorner.Parent = Track

    local startRatio = (ESPSettings[valueKey] - min) / (max - min)
    local Fill = Instance.new("Frame")
    Fill.Size = UDim2.new(startRatio, 0, 1, 0)
    Fill.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    Fill.BorderSizePixel = 0
    Fill.ZIndex = 6
    Fill.Parent = Track
    local FillCorner = Instance.new("UICorner")
    FillCorner.CornerRadius = UDim.new(1, 0)
    FillCorner.Parent = Fill
    ApplyThemeGradient(Fill)

    local Thumb = Instance.new("Frame")
    Thumb.Size = UDim2.new(0, 12, 0, 12)
    Thumb.AnchorPoint = Vector2.new(0.5, 0.5)
    Thumb.Position = UDim2.new(startRatio, 0, 0.5, 0)
    Thumb.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    Thumb.BorderSizePixel = 0
    Thumb.ZIndex = 7
    Thumb.Parent = Track
    local ThumbCorner = Instance.new("UICorner")
    ThumbCorner.CornerRadius = UDim.new(1, 0)
    ThumbCorner.Parent = Thumb
    local ThumbStroke = Instance.new("UIStroke")
    ThumbStroke.Thickness = 2
    ThumbStroke.Color = Color3.fromRGB(91, 168, 252)
    ThumbStroke.Parent = Thumb

    local Trigger = Instance.new("TextButton")
    Trigger.Size = UDim2.new(1, 0, 0, 18)
    Trigger.Position = UDim2.new(0, 0, 0.5, -9)
    Trigger.BackgroundTransparency = 1
    Trigger.Text = ""
    Trigger.ZIndex = 8
    Trigger.Parent = Track

    local function UpdateSlider(input)
        local percentage = math.clamp((input.Position.X - Track.AbsolutePosition.X) / Track.AbsoluteSize.X, 0, 1)
        Fill.Size = UDim2.new(percentage, 0, 1, 0)
        Thumb.Position = UDim2.new(percentage, 0, 0.5, 0)
        local rawVal = min + (percentage * (max - min))
        if max > 10 then
            ESPSettings[valueKey] = math.round(rawVal)
            Label.Text = name .. ": " .. ESPSettings[valueKey]
        else
            ESPSettings[valueKey] = math.round(rawVal * 10) / 10
            Label.Text = string.format("%s: %.1fs", name, ESPSettings[valueKey])
        end
    end

    local dragging = false
    Trigger.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then dragging = true UpdateSlider(input) end
    end)
    table.insert(Connections, UserInputService.InputChanged:Connect(function(input)
        if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then UpdateSlider(input) end
    end))
    table.insert(Connections, UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then dragging = false end
    end))
    return Card
end

-- ==========================================
-- 3. 元件配置裝載
-- ==========================================
local function CreateHexColorInput(labelText, yIndex, settingKey, parentPage, onChange)
    local Frame = Instance.new("Frame")
    Frame.Size = UDim2.new(1, -30, 0, 36)
    Frame.Position = UDim2.new(0, 20, 0, 12 + (yIndex - 1) * 38)
    Frame.BackgroundColor3 = Color3.fromRGB(22, 24, 32)
    Frame.BorderSizePixel = 0
    Frame.ZIndex = 5
    Frame.Parent = parentPage

    local Corner = Instance.new("UICorner")
    Corner.CornerRadius = UDim.new(0, 6)
    Corner.Parent = Frame

    local Stroke = Instance.new("UIStroke")
    Stroke.Thickness = 1
    Stroke.Color = Color3.fromRGB(45, 48, 62)
    Stroke.Parent = Frame

    local Label = Instance.new("TextLabel")
    Label.Size = UDim2.new(0, 120, 1, 0)
    Label.Position = UDim2.new(0, 8, 0, 0)
    Label.BackgroundTransparency = 1
    Label.Text = labelText
    Label.TextColor3 = Color3.fromRGB(170, 175, 190)
    Label.Font = Enum.Font.SourceSansSemibold
    Label.TextSize = 13
    Label.TextXAlignment = Enum.TextXAlignment.Left
    Label.ZIndex = 6
    Label.Parent = Frame

    local Preview = Instance.new("Frame")
    Preview.Size = UDim2.new(0, 24, 0, 24)
    Preview.Position = UDim2.new(0, 132, 0.5, -12)
    Preview.BackgroundColor3 = ESPSettings[settingKey]
    Preview.BorderSizePixel = 0
    Preview.ZIndex = 6
    Preview.Parent = Frame

    local PreviewCorner = Instance.new("UICorner")
    PreviewCorner.CornerRadius = UDim.new(0, 4)
    PreviewCorner.Parent = Preview

    local PreviewStroke = Instance.new("UIStroke")
    PreviewStroke.Thickness = 1
    PreviewStroke.Color = Color3.fromRGB(60, 63, 78)
    PreviewStroke.Parent = Preview

    local HexBox = Instance.new("TextBox")
    HexBox.Size = UDim2.new(1, -172, 1, -10)
    HexBox.Position = UDim2.new(0, 164, 0, 5)
    HexBox.BackgroundColor3 = Color3.fromRGB(15, 16, 22)
    local c = ESPSettings[settingKey]
    HexBox.Text = string.format("%02X%02X%02X", math.floor(c.R * 255 + 0.5), math.floor(c.G * 255 + 0.5), math.floor(c.B * 255 + 0.5))
    HexBox.TextColor3 = Color3.fromRGB(255, 230, 100)
    HexBox.PlaceholderText = "輸入 HEX 色碼 (例如 FFFFFF)..."
    HexBox.PlaceholderColor3 = Color3.fromRGB(80, 85, 100)
    HexBox.Font = Enum.Font.SourceSansBold
    HexBox.TextSize = 13
    HexBox.BorderSizePixel = 0
    HexBox.ClearTextOnFocus = false
    HexBox.ZIndex = 6
    HexBox.Parent = Frame

    local HBCorner = Instance.new("UICorner")
    HBCorner.CornerRadius = UDim.new(0, 4)
    HBCorner.Parent = HexBox

    local HBStroke = Instance.new("UIStroke")
    HBStroke.Thickness = 1
    HBStroke.Color = Color3.fromRGB(35, 38, 50)
    HBStroke.Parent = HexBox

    HexBox.FocusLost:Connect(function()
        local hex = HexBox.Text:gsub("^#", ""):gsub("%s", "")
        if #hex == 6 and hex:match("^%x+$") then
            local r = tonumber(hex:sub(1, 2), 16)
            local g = tonumber(hex:sub(3, 4), 16)
            local b = tonumber(hex:sub(5, 6), 16)
            ESPSettings[settingKey] = Color3.fromRGB(r, g, b)
            Preview.BackgroundColor3 = ESPSettings[settingKey]
            HexBox.Text = hex:upper()
            if onChange then onChange() end
        else
            -- 無效色碼則還原顯示
            local cur = ESPSettings[settingKey]
            HexBox.Text = string.format("%02X%02X%02X", math.floor(cur.R * 255 + 0.5), math.floor(cur.G * 255 + 0.5), math.floor(cur.B * 255 + 0.5))
        end
    end)

    return Frame
end

-- Visual Page
AddToggle("視覺外框 (Box ESP)", "Box", VisualPage, 1, false)
AddToggle("血條狀態 (Health Status)", "Health", VisualPage, 2, false)
AddToggle("發光骨架 (Highlight)", "Skeleton", VisualPage, 3, false)
AddToggle("天際射線 (Head Sky Line)", "HeadESP", VisualPage, 4, false)
AddToggle("顯示玩家名稱 (Name Show)", "NameShow", VisualPage, 5, false) 

AddToggle("└─ 雙色漸層 (關閉則為單色)", "HeadESPGradient", VisualPage, 6, true)
CreateHexColorInput("└─ 射線顏色 1:", 7, "HeadESPColor1", VisualPage, nil)
local HeadESPColor2Row = CreateHexColorInput("└─ 射線顏色 2 (漸層用):", 8, "HeadESPColor2", VisualPage, nil)

-- Lock Aim Page
AddButton("Aimbot (滑鼠右鍵鎖定)", "Aimbot", AimPage, 1, false)
AddButton("├─ 障礙物檢查 (Wall Check)", "AimbotWallCheck", AimPage, 2, true)
AddButton("├─ 優先鎖定近敵 (Lock Nearest)", "AimbotLockNearest", AimPage, 3, true)
AddSlider("├─ 自瞄範圍大小 (Aimbot FOV)", "AimbotFOV", 1, 1000, AimPage, 4, true)

local ModeSwitchBtn = Instance.new("TextButton")
ModeSwitchBtn.Size = UDim2.new(1, -30, 0, 32)
ModeSwitchBtn.Position = UDim2.new(0, 20, 0, 12 + (5 - 1) * 38)
ModeSwitchBtn.BackgroundColor3 = Color3.fromRGB(35, 30, 45)
ModeSwitchBtn.BorderSizePixel = 0
ModeSwitchBtn.Font = Enum.Font.SourceSansBold
ModeSwitchBtn.TextSize = 14
ModeSwitchBtn.Text = "⚡ 自瞄分支狀態: " .. ESPSettings.AimbotMode
ModeSwitchBtn.TextColor3 = Color3.fromRGB(255, 215, 100)
ModeSwitchBtn.ZIndex = 5
ModeSwitchBtn.Parent = AimPage

local MSCorner = Instance.new("UICorner")
MSCorner.CornerRadius = UDim.new(0, 6)
MSCorner.Parent = ModeSwitchBtn
local MSStroke = Instance.new("UIStroke")
MSStroke.Thickness = 1
MSStroke.Color = Color3.fromRGB(91, 168, 252)
MSStroke.Parent = ModeSwitchBtn

local SlidersContainer = Instance.new("Frame")
SlidersContainer.Size = UDim2.new(1, 0, 0, 120)
SlidersContainer.Position = UDim2.new(0, 0, 0, 12 + (6 - 1) * 38)
SlidersContainer.BackgroundTransparency = 1
SlidersContainer.Parent = AimPage

local SliderHead = AddSlider("   └─ 命中頭部機率 (Head %)", "CustomHeadChance", 0, 100, SlidersContainer, 1, true)
local SliderBody = AddSlider("   └─ 命中身體機率 (Body %)", "CustomBodyChance", 0, 100, SlidersContainer, 2, true)
local SliderSmooth = AddSlider("   └─ 自瞄平滑度 (Smoothness)", "AimbotSmoothness", 0, 100, SlidersContainer, 3, true)

local function UpdateAimbotBranchUI()
    if ESPSettings.AimbotMode == "Rage Lock" then
        ModeSwitchBtn.Text = "⚡ 自瞄分支狀態: Rage Lock (1ms鎖頭)"
        ModeSwitchBtn.TextColor3 = Color3.fromRGB(255, 100, 100)
        MSStroke.Color = Color3.fromRGB(255, 50, 50)
        SlidersContainer.Visible = false
    else
        ModeSwitchBtn.Text = "⚙️ 自瞄分支狀態: Custom (自訂數據)"
        ModeSwitchBtn.TextColor3 = Color3.fromRGB(100, 255, 200)
        MSStroke.Color = Color3.fromRGB(50, 255, 150)
        SlidersContainer.Visible = true
    end
end

ModeSwitchBtn.MouseButton1Click:Connect(function()
    if ESPSettings.AimbotMode == "Rage Lock" then
        ESPSettings.AimbotMode = "Custom"
    else
        ESPSettings.AimbotMode = "Rage Lock"
    end
    UpdateAimbotBranchUI()
end)
UpdateAimbotBranchUI()

-- Silent Aim Page
AddButton("Silent Aim (動態光速對齊)", "SilentAim", SilentPage, 1, false)
AddButton("├─ 靜默障礙檢查 (Wall Check)", "SilentAimWallCheck", SilentPage, 2, true)
AddSlider("└─ 靜默自瞄範圍 (Silent FOV)", "SilentAimFOV", 1, 1000, SilentPage, 3, true)

-- Ragebot Page
AddButton("🔥 Ragebot [P]: OFF", "Ragebot", RagePage, 1, false)
local PartCycleBtn = Instance.new("TextButton")
PartCycleBtn.Size = UDim2.new(1, -30, 0, 32)
PartCycleBtn.Position = UDim2.new(0, 20, 0, 12 + (2 - 1) * 38)
PartCycleBtn.BackgroundColor3 = Color3.fromRGB(24, 22, 26)
PartCycleBtn.BorderSizePixel = 0
PartCycleBtn.Font = Enum.Font.SourceSansBold
PartCycleBtn.TextSize = 14
PartCycleBtn.Text = "├─ 鎖定部位: " .. HitPartNames[ESPSettings.RagebotHitPartIndex]
PartCycleBtn.TextColor3 = Color3.fromRGB(255, 140, 160)
PartCycleBtn.ZIndex = 5
PartCycleBtn.Parent = RagePage

local PCCorner = Instance.new("UICorner")
PCCorner.CornerRadius = UDim.new(0, 6)
PCCorner.Parent = PartCycleBtn
local PCStroke = Instance.new("UIStroke")
PCStroke.Thickness = 1
PCStroke.Color = Color3.fromRGB(45, 48, 62)
PCStroke.Parent = PartCycleBtn

PartCycleBtn.MouseButton1Click:Connect(function()
    ESPSettings.RagebotHitPartIndex = ESPSettings.RagebotHitPartIndex + 1
    if ESPSettings.RagebotHitPartIndex > #HitParts then ESPSettings.RagebotHitPartIndex = 1 end
    PartCycleBtn.Text = "├─ 鎖定部位: " .. HitPartNames[ESPSettings.RagebotHitPartIndex]
end)
AddSlider("├─ 突襲單點滯留 (Attack Speed)", "RageAttackSpeed", 0.1, 3.0, RagePage, 3, true)
AddSlider("└─ 虛空躲避間隔 (Hide In Void)", "RageHideVoid", 0.1, 3.0, RagePage, 4, true)

local TriggerStatusBtn = Instance.new("TextButton")
TriggerStatusBtn.Size = UDim2.new(1, -16, 0, 32)
TriggerStatusBtn.Position = UDim2.new(0, 8, 0, 12 + (5 - 1) * 38)
TriggerStatusBtn.BackgroundColor3 = Color3.fromRGB(18, 20, 26)
TriggerStatusBtn.BorderSizePixel = 0
TriggerStatusBtn.TextColor3 = Color3.fromRGB(140, 145, 160)
TriggerStatusBtn.Font = Enum.Font.SourceSansSemibold
TriggerStatusBtn.TextSize = 13
TriggerStatusBtn.Text = "Triggerbot: [按住滑鼠右鍵自動開槍]"
TriggerStatusBtn.ZIndex = 5
TriggerStatusBtn.Parent = RagePage

local TBCorner = Instance.new("UICorner")
TBCorner.CornerRadius = UDim.new(0, 6)
TBCorner.Parent = TriggerStatusBtn
local TBStroke = Instance.new("UIStroke")
TBStroke.Thickness = 1
TBStroke.Color = Color3.fromRGB(45, 48, 62)
TBStroke.Parent = TriggerStatusBtn

-- Movement Page
AddToggle("飛行模式 (Flight - Space/Shift)", "Flight", MovementPage, 1, false)
AddToggle("開啟 CFrame 速度修改", "Speed", MovementPage, 2, false)
AddModernSlider("角色移動速度 (CFrame Speed)", "SpeedValue", 1, 250, MovementPage, 3, false)
AddToggle("開啟伺服器陀螺 (Spinbot)", "Spin", MovementPage, 4, false)
AddModernSlider("陀螺旋轉速度 (Spin Speed)", "SpinSpeed", 1, 100, MovementPage, 5, false)
AddToggle("穿牆模式 (Noclip)", "Noclip", MovementPage, 6, false)
AddToggle("自動連跳 (Auto Jump)", "AutoJump", MovementPage, 7, false) 

-- World Page：世界環境 - 下雪系統
AddToggle("❄️ 全域下雪 (World Snow)", "Snow", WorldPage, 1, false)


CreateHexColorInput("└─ 雪花顏色 1:", 2, "SnowColor1", WorldPage, UpdateSnowColors)
CreateHexColorInput("└─ 雪花顏色 2:", 3, "SnowColor2", WorldPage, UpdateSnowColors)

-- Misc Page
-- Misc Page
AddToggle("自動復活 (Auto Revive)", "AutoRevive", MiscPage, 1, false)
AddToggle("虛空躲避 (Void Dodge)", "VoidDodge", MiscPage, 2, false)
AddModernSlider("玩家視角 (FOV)", "PlayerFOV", 10, 120, MiscPage, 3, false)
AddToggle("隱藏自己名字", "SpoofSelf", MiscPage, 4, false)
AddToggle("隱藏他人名字", "SpoofOthers", MiscPage, 5, false)

-- 新增的 Misc 按鈕 (霧、光顏色、第三視角)
AddToggle("🌫️ 霧氣開關 (Fog)", "Fog", MiscPage, 6, false)
AddToggle("💡 整體光顏色開關", "LightingColorSwitch", MiscPage, 7, false)
CreateHexColorInput("└─ 光線與霧氣顏色 (Hex):", 8, "LightingColor", MiscPage, nil)
AddToggle("👁️ 強制第三視角 (Third Person)", "ThirdPerson", MiscPage, 9, false)

-- 🌟 Misc Page：動作播放控制模組
AddToggle("自訂動作播放 (Emote Player)", "EmoteTrack", MiscPage, 6, false)

local EmoteInputFrame = Instance.new("Frame")
EmoteInputFrame.Size = UDim2.new(1, -30, 0, 36)
EmoteInputFrame.Position = UDim2.new(0, 20, 0, 12 + (7 - 1) * 38)
EmoteInputFrame.BackgroundColor3 = Color3.fromRGB(22, 24, 32)
EmoteInputFrame.BorderSizePixel = 0
EmoteInputFrame.ZIndex = 5
EmoteInputFrame.Parent = MiscPage

local EICorner = Instance.new("UICorner")
EICorner.CornerRadius = UDim.new(0, 6)
EICorner.Parent = EmoteInputFrame

local EIStroke = Instance.new("UIStroke")
EIStroke.Thickness = 1
EIStroke.Color = Color3.fromRGB(45, 48, 62)
EIStroke.Parent = EmoteInputFrame

local EmoteLabel = Instance.new("TextLabel")
EmoteLabel.Size = UDim2.new(0, 120, 1, 0)
EmoteLabel.Position = UDim2.new(0, 8, 0, 0)
EmoteLabel.BackgroundTransparency = 1
EmoteLabel.Text = "└─ 貼上動作 ID:"
EmoteLabel.TextColor3 = Color3.fromRGB(170, 175, 190)
EmoteLabel.Font = Enum.Font.SourceSansSemibold
EmoteLabel.TextSize = 13
EmoteLabel.TextXAlignment = Enum.TextXAlignment.Left
EmoteLabel.ZIndex = 6
EmoteLabel.Parent = EmoteInputFrame

local EmoteTextBox = Instance.new("TextBox")
EmoteTextBox.Size = UDim2.new(1, -140, 1, -10)
EmoteTextBox.Position = UDim2.new(0, 130, 0, 5)
EmoteTextBox.BackgroundColor3 = Color3.fromRGB(15, 16, 22)
EmoteTextBox.Text = ESPSettings.EmoteID
EmoteTextBox.TextColor3 = Color3.fromRGB(255, 230, 100)
EmoteTextBox.PlaceholderText = "輸入 Animation ID..."
EmoteTextBox.PlaceholderColor3 = Color3.fromRGB(80, 85, 100)
EmoteTextBox.Font = Enum.Font.SourceSansBold
EmoteTextBox.TextSize = 13
EmoteTextBox.BorderSizePixel = 0
EmoteTextBox.ClearTextOnFocus = false
EmoteTextBox.ZIndex = 6
EmoteTextBox.Parent = EmoteInputFrame

local ETBCorner = Instance.new("UICorner")
ETBCorner.CornerRadius = UDim.new(0, 4)
ETBCorner.Parent = EmoteTextBox

local ETBStroke = Instance.new("UIStroke")
ETBStroke.Thickness = 1
ETBStroke.Color = Color3.fromRGB(35, 38, 50)
ETBStroke.Parent = EmoteTextBox

-- 核心動作監聽與加載分支
UpdateEmotePlayback = function()
    if CurrentAnimationTrack then
        CurrentAnimationTrack:Stop()
        CurrentAnimationTrack = nil
    end

    if ESPSettings.EmoteTrack and LocalPlayer.Character then
        local humanoid = LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
        if humanoid and humanoid.Health > 0 then
            local cleanID = ESPSettings.EmoteID:gsub("%D", "") -- 過濾掉非數字字元
            if cleanID ~= "" then
                local success, err = pcall(function()
                    local anim = Instance.new("Animation")
                    anim.AnimationId = "rbxassetid://" .. cleanID
                    CurrentAnimationTrack = humanoid:LoadAnimation(anim)
                    CurrentAnimationTrack.Looped = true
                    CurrentAnimationTrack:Play()
                end)
                if not success then
                    warn("動作播放失敗 (無效的 ID 欄位):", err)
                end
            end
        end
    end
end

EmoteTextBox.FocusLost:Connect(function(enterPressed)
    ESPSettings.EmoteID = EmoteTextBox.Text
    UpdateEmotePlayback()
end)

table.insert(Connections, LocalPlayer.CharacterAdded:Connect(function()
    task.wait(1)
    if ESPSettings.EmoteTrack then UpdateEmotePlayback() end
end))

Pages["Visual"].Visible = true
PageButtons["Visual"].BackgroundColor3 = Color3.fromRGB(35, 38, 55)
PageButtons["Visual"].TextColor3 = Color3.fromRGB(255, 255, 255)
PageButtons["Visual"]:FindFirstChildOfClass("UIStroke").Color = Color3.fromRGB(91, 168, 252)

-- ==========================================
-- 4. 尋敵、自瞄檢查核心
-- ==========================================
local function IsPlayerVisible(targetChar)
    local localChar = LocalPlayer.Character
    local head = targetChar and targetChar:FindFirstChild("Head")
    if not localChar or not head then return false end
    local raycastParams = RaycastParams.new()
    raycastParams.FilterType = Enum.RaycastFilterType.Exclude
    raycastParams.FilterDescendantsInstances = {localChar, targetChar, ScreenGui}
    local result = Workspace:Raycast(Camera.CFrame.Position, head.Position - Camera.CFrame.Position, raycastParams)
    return result == nil
end

local function GetTarget(maxFOV, wallCheck, lockNearest)
    local closestPlayer = nil
    local shortestMouseDist = maxFOV
    local shortest3DDist = math.huge
    local localHrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")

    for _, player in pairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and player.Character and player.Character:FindFirstChild("Head") then
            local hum = player.Character:FindFirstChildOfClass("Humanoid")
            local targetHrp = player.Character:FindFirstChild("HumanoidRootPart")
            if hum and hum.Health > 0 and targetHrp then
                if not wallCheck or IsPlayerVisible(player.Character) then
                    local screenPos, onScreen = Camera:WorldToViewportPoint(player.Character.Head.Position)
                    if onScreen then
                        if lockNearest and localHrp then
                            local dist3D = (localHrp.Position - targetHrp.Position).Magnitude
                            if dist3D < shortest3DDist then shortest3DDist = dist3D closestPlayer = player end
                        else
                            local mouseLocation = UserInputService:GetMouseLocation()
                            local mouseDistance = (Vector2.new(screenPos.X, screenPos.Y) - mouseLocation).Magnitude
                            if mouseDistance < shortestMouseDist then shortestMouseDist = mouseDistance closestPlayer = player end
                        end
                    end
                end
            end
        end
    end
    return closestPlayer
end

-- ==========================================
-- 5. 核心循環
-- ==========================================
local coreLoopThread = task.spawn(function()
    local lastSelectedPart = "Head"
    local nextDecisionTime = 0

    while true do
        task.wait(0.001)
        if not ScreenGui or not ScreenGui.Parent then break end

        local myChar = LocalPlayer.Character
        local myHrp = myChar and myChar:FindFirstChild("HumanoidRootPart")
        local myHum = myChar and myChar:FindFirstChildOfClass("Humanoid")

        if ESPSettings.AutoJump and myHum and myHum.Health > 0 then
            if myHum.FloorMaterial ~= Enum.Material.Air then
                myHum:ChangeState(Enum.HumanoidStateType.Jumping)
            end
        end

        if ESPSettings.Aimbot and isRightMouseDown then
            local target = GetTarget(ESPSettings.AimbotFOV, ESPSettings.AimbotWallCheck, ESPSettings.AimbotLockNearest)
            if target and target.Character then
                if ESPSettings.AimbotMode == "Rage Lock" then
                    local head = target.Character:FindFirstChild("Head")
                    if head then
                        Camera.CFrame = CFrame.new(Camera.CFrame.Position, head.Position)
                    end
                else
                    if tick() > nextDecisionTime then
                        local total = ESPSettings.CustomHeadChance + ESPSettings.CustomBodyChance
                        if total > 0 then
                            local rolled = math.random(1, total)
                            if rolled <= ESPSettings.CustomHeadChance then
                                lastSelectedPart = "Head"
                            else
                                lastSelectedPart = "HumanoidRootPart"
                            end
                        else
                            lastSelectedPart = "Head"
                        end
                        nextDecisionTime = tick() + 0.1 
                    end

                    local aimTargetPart = target.Character:FindFirstChild(lastSelectedPart) or target.Character:FindFirstChild("Head")
                    if aimTargetPart then
                        local targetCF = CFrame.new(Camera.CFrame.Position, aimTargetPart.Position)
                        if ESPSettings.AimbotSmoothness >= 100 then
                            Camera.CFrame = targetCF
                        else
                            local t = math.clamp(ESPSettings.AimbotSmoothness / 100, 0.01, 1)
                            Camera.CFrame = Camera.CFrame:Lerp(targetCF, t)
                        end
                    end
                end
            end
        end

        if ESPSettings.SilentAim and UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) then
            local target = GetTarget(ESPSettings.SilentAimFOV, ESPSettings.SilentAimWallCheck, false)
            if target and target.Character and target.Character:FindFirstChild("Head") then
                Camera.CFrame = CFrame.new(Camera.CFrame.Position, target.Character.Head.Position)
            end
        end

        if isRightMouseDown and not ESPSettings.Ragebot then
            local mousePos = UserInputService:GetMouseLocation()
            local unitRay = Camera:ViewportPointToRay(mousePos.X, mousePos.Y)
            local raycastParams = RaycastParams.new()
            raycastParams.FilterType = Enum.RaycastFilterType.Exclude
            if myChar then raycastParams.FilterDescendantsInstances = {myChar, ScreenGui} end
            local rayResult = Workspace:Raycast(unitRay.Origin, unitRay.Direction * 1000, raycastParams)
            if rayResult and rayResult.Instance then
                local hitModel = rayResult.Instance:FindFirstAncestorOfClass("Model")
                local hitPlayer = hitModel and Players:GetPlayerFromCharacter(hitModel)
                if hitPlayer and hitPlayer ~= LocalPlayer and hitModel:FindFirstChildOfClass("Humanoid") and hitModel:FindFirstChildOfClass("Humanoid").Health > 0 then
                    mouse1click()
                end
            end
        end

        if ESPSettings.Ragebot and not ragebotActiveThread and myHrp and myHum and myHum.Health > 0 then
            task.spawn(function()
                ragebotActiveThread = true
                for _, player in pairs(Players:GetPlayers()) do
                    if not ESPSettings.Ragebot then break end
                    if player ~= LocalPlayer and player.Character then
                        local enemyHum = player.Character:FindFirstChildOfClass("Humanoid")
                        local enemyHrp = player.Character:FindFirstChild("HumanoidRootPart")
                        local activePartName = HitParts[ESPSettings.RagebotHitPartIndex]
                        local enemyTargetPart = player.Character:FindFirstChild(activePartName) or enemyHrp
                        
                        if enemyHum and enemyHum.Health > 0 and enemyHrp and enemyTargetPart then
                            local attackEndTime = tick() + ESPSettings.RageAttackSpeed
                            local Bind
                            Bind = RunService.RenderStepped:Connect(function()
                                if enemyHum.Health > 0 and ESPSettings.Ragebot and myHum.Health > 0 then
                                    myHrp.AssemblyLinearVelocity = Vector3.new(0,0,0)
                                    myHrp.CFrame = enemyHrp.CFrame * CFrame.new(0, 3.6, 0)
                                    Camera.CFrame = CFrame.new(Camera.CFrame.Position, enemyTargetPart.Position)
                                    mouse1click()
                                end
                            end)
                            while tick() < attackEndTime and enemyHum.Health > 0 and ESPSettings.Ragebot and myHum.Health > 0 do task.wait(0.01) end
                            if Bind then Bind:Disconnect() end
                            myHrp.CFrame = CFrame.new(myHrp.Position.X, -4500, myHrp.Position.Z)
                            task.wait(ESPSettings.RageHideVoid)
                        end
                    end
                end
                ragebotActiveThread = false
            end)
        end
    end
end)

-- ==========================================
-- 6. 死亡監聽與復活邏輯
-- ==========================================
local function MonitorDeath(char)
    if not char then return end
    local hum = char:WaitForChild("Humanoid", 5)
    if not hum then return end

    local function onDeathCheck()
        if (hum.Health <= 0 or char:GetAttribute("BleedingOut") or char:FindFirstChild("Downed")) and not isDead then
            isDead = true
            canSpamRevive = false
            task.wait(0.7)
            canSpamRevive = true
            task.spawn(function()
                while isDead and canSpamRevive and ScreenGui.Parent do
                    if UserInputService:IsKeyDown(Enum.KeyCode.Space) and ESPSettings.AutoRevive then
                        for _, v in pairs(game:GetDescendants()) do
                            if v:IsA("RemoteEvent") and (v.Name:lower():find("revive") or v.Name:lower():find("spawn") or v.Name:lower():find("reset")) then
                                pcall(function() v:FireServer() end)
                            end
                        end
                        pcall(function()
                            hum:ChangeState(Enum.HumanoidStateType.GettingUp)
                            hum.Health = hum.MaxHealth
                        end)
                    end
                    task.wait(0.01)
                end
            end)
        elseif hum.Health > 0 then
            isDead = false
            canSpamRevive = false
        end
    end
    table.insert(Connections, hum:GetPropertyChangedSignal("Health"):Connect(onDeathCheck))
    table.insert(Connections, char.AttributeChanged:Connect(onDeathCheck))
end
if LocalPlayer.Character then MonitorDeath(LocalPlayer.Character) end
table.insert(Connections, LocalPlayer.CharacterAdded:Connect(MonitorDeath))

-- ==========================================
-- 7. Name Spoof 攔截
-- ==========================================
local function ApplyNameSpoof()
    -- ⚠️ 效能修復：原本用 game:GetDescendants() 掃描「整個遊戲」的所有物件(可能數萬個,包含地圖、腳本等),
    -- 是造成開啟 Name Spoof 後卡頓的主因。改為只掃描真正會顯示名字文字的範圍：
    -- 自己的 PlayerGui(聊天、UI)以及各玩家角色底下的 GUI(暱稱牌等),範圍小很多。
    local scanRoots = {}
    local myPlayerGui = LocalPlayer:FindFirstChild("PlayerGui")
    if myPlayerGui then table.insert(scanRoots, myPlayerGui) end
    for _, p in pairs(Players:GetPlayers()) do
        if p.Character then table.insert(scanRoots, p.Character) end
    end

    for _, root in pairs(scanRoots) do
        for _, v in pairs(root:GetDescendants()) do
            if v:IsA("TextLabel") or v:IsA("TextButton") then
                if ESPSettings.SpoofSelf and (v.Text:find(LocalPlayer.Name, 1, true) or v.Text:find(LocalPlayer.DisplayName, 1, true)) then
                    v.Text = v.Text:gsub(LocalPlayer.Name, ESPSettings.SpoofSelfName):gsub(LocalPlayer.DisplayName, ESPSettings.SpoofSelfName)
                end
                if ESPSettings.SpoofOthers then
                    for _, p in pairs(Players:GetPlayers()) do
                        if p ~= LocalPlayer and (v.Text:find(p.Name, 1, true) or v.Text:find(p.DisplayName, 1, true)) then
                            v.Text = v.Text:gsub(p.Name, ESPSettings.SpoofOthersName):gsub(p.DisplayName, ESPSettings.SpoofOthersName)
                        end
                    end
                end
            end
        end
    end
end
-- ⚠️ 效能修復：原本掛在 Heartbeat 上,等於每秒掃描 30~60 次。文字替換不需要這麼高頻率,
-- 改為每秒掃描一次,大幅降低效能負擔,卡頓問題應可解決
task.spawn(function()
    while ScreenGui.Parent do
        if ESPSettings.SpoofSelf or ESPSettings.SpoofOthers then
            pcall(ApplyNameSpoof)
        end
        task.wait(1)
    end
end)

-- ==========================================
-- 8. ESP 渲染 
-- ==========================================
local function SetupESP(player)
    if player == LocalPlayer then return end
    local function CleanESP()
        if ESPTable[player] then 
            pcall(function() ESPTable[player].Highlight:Destroy() end)
            pcall(function() ESPTable[player].Box:Destroy() end)
            pcall(function() ESPTable[player].BarGui:Destroy() end)
            pcall(function() ESPTable[player].HeadLine:Destroy() end)
            pcall(function() ESPTable[player].HeadLineAnchor:Destroy() end)
            pcall(function() ESPTable[player].NameGui:Destroy() end) 
            ESPTable[player] = nil
        end
    end

    local function CreateElements(char)
        CleanESP() if not char then return end
        task.spawn(function()
            local head = char:WaitForChild("Head", 5)
            local hrp = char:WaitForChild("HumanoidRootPart", 5)
            if not hrp or not head then return end 

            local hl = Instance.new("Highlight")
            hl.FillTransparency = 0.5
            hl.OutlineColor = Color3.fromRGB(255, 255, 255)
            hl.Parent = char

            local bg = Instance.new("BillboardGui")
            bg.AlwaysOnTop = true
            bg.Size = UDim2.new(4.5, 0, 6, 0)
            bg.Adornee = hrp
            bg.Parent = ScreenGui

            local box = Instance.new("Frame")
            box.Size = UDim2.new(1, 0, 1, 0)
            box.BackgroundTransparency = 1
            box.Parent = bg
            local stroke = Instance.new("UIStroke")
            stroke.Thickness = 1.5
            stroke.Color = Color3.fromRGB(255, 255, 255)
            stroke.Parent = box

            -- ⚠️ 修復：血條原本是 Box ESP 的子物件,Box 關閉時血條也會被一併隱藏。
            -- 改為獨立的 BillboardGui,讓 Health 開關可以單獨運作,不受 Box ESP 影響
            local barGui = Instance.new("BillboardGui")
            barGui.Name = "HealthBarGui"
            barGui.AlwaysOnTop = true
            barGui.Size = UDim2.new(4.5, 0, 6, 0)
            barGui.Adornee = hrp
            barGui.Parent = ScreenGui

            local healthBar = Instance.new("Frame")
            healthBar.Size = UDim2.new(0.05, 0, 0.9, 0)
            healthBar.Position = UDim2.new(-0.1, 0, 0.05, 0)
            healthBar.BackgroundColor3 = Color3.fromRGB(91, 168, 252)
            healthBar.Parent = barGui

            -- 天際射線改用 Beam 實作：Beam 支援 ColorSequence,才能真正做出單色/雙色漸層效果
            local skyAnchorPart = Instance.new("Part")
            skyAnchorPart.Name = "SkyLineAnchor"
            skyAnchorPart.Anchored = true
            skyAnchorPart.CanCollide = false
            skyAnchorPart.CanQuery = false
            skyAnchorPart.Transparency = 1
            skyAnchorPart.Size = Vector3.new(0.1, 0.1, 0.1)
            skyAnchorPart.Parent = Workspace

            local bottomAtt = Instance.new("Attachment")
            bottomAtt.Name = "SkyBottomAtt"
            bottomAtt.Parent = hrp

            local topAtt = Instance.new("Attachment")
            topAtt.Name = "SkyTopAtt"
            topAtt.Parent = skyAnchorPart

            local cylinder = Instance.new("Beam")
            cylinder.Name = "SkyLine"
            cylinder.Attachment0 = bottomAtt
            cylinder.Attachment1 = topAtt
            cylinder.Width0 = 1.2
            cylinder.Width1 = 1.2
            cylinder.FaceCamera = true
            cylinder.LightEmission = 1
            cylinder.Color = ColorSequence.new(ESPSettings.HeadESPColor1)
            cylinder.Transparency = NumberSequence.new(1)
            cylinder.Parent = hrp

            local nameGui = Instance.new("BillboardGui")
            nameGui.AlwaysOnTop = true
            nameGui.Size = UDim2.new(0, 200, 0, 30)
            nameGui.ExtentsOffset = Vector3.new(0, 3.5, 0) 
            nameGui.Adornee = hrp
            nameGui.Parent = ScreenGui

            local nameLabel = Instance.new("TextLabel")
            nameLabel.Size = UDim2.new(1, 0, 1, 0)
            nameLabel.BackgroundTransparency = 1
            nameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
            nameLabel.Font = Enum.Font.SourceSansBold
            nameLabel.TextSize = 14
            nameLabel.Text = player.Name
            nameLabel.Parent = nameGui

            local nameStroke = Instance.new("UIStroke")
            nameStroke.Thickness = 2
            nameStroke.Color = Color3.fromRGB(0, 0, 0)
            nameStroke.Parent = nameLabel

            ESPTable[player] = { 
                Highlight = hl, 
                Box = bg, 
                Bar = healthBar, 
                BarGui = barGui,
                HeadLine = cylinder, 
                HeadLineAnchor = skyAnchorPart,
                NameGui = nameGui, 
                NameLabel = nameLabel, 
                Char = char 
            }
        end)
    end

    if player.Character then CreateElements(player.Character) end
    table.insert(Connections, player.CharacterAdded:Connect(function(char) task.wait(0.5) CreateElements(char) end))
    table.insert(Connections, player.CharacterRemoving:Connect(CleanESP))
end
for _, p in pairs(Players:GetPlayers()) do SetupESP(p) end
table.insert(Connections, Players.PlayerAdded:Connect(SetupESP))

-- ==========================================
-- 9. 運動與即時繪製
-- ==========================================
table.insert(Connections, RunService.Heartbeat:Connect(function(deltaTime)
    local char = LocalPlayer.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    local hum = char and char:FindFirstChildOfClass("Humanoid")

    if hum and hrp and hum.Health > 0 then
        if ESPSettings.VoidDodge then
            local moveVec = hum.MoveDirection
            local speed = ESPSettings.Speed and ESPSettings.SpeedValue or 16
            if moveVec.Magnitude > 0 then VirtualGroundPos = VirtualGroundPos + (moveVec * (speed * deltaTime)) end
            if VirtualProxy then VirtualProxy.CFrame = CFrame.new(VirtualGroundPos) end
            hrp.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
            hrp.CFrame = CFrame.new(VirtualGroundPos.X, -4500, VirtualGroundPos.Z)
            pcall(function() Camera.Focus = CFrame.new(VirtualGroundPos) end)
        end

        if ESPSettings.Flight and not ESPSettings.VoidDodge then
            hrp.AssemblyLinearVelocity = Vector3.new(0, 0, 0) 
            local camCF = Camera.CFrame
            local moveVec = Vector3.new()
            if not UserInputService:GetFocusedTextBox() then
                if UserInputService:IsKeyDown(Enum.KeyCode.W) then moveVec = moveVec + camCF.LookVector end
                if UserInputService:IsKeyDown(Enum.KeyCode.S) then moveVec = moveVec - camCF.LookVector end
                if UserInputService:IsKeyDown(Enum.KeyCode.A) then moveVec = moveVec - camCF.RightVector end
                if UserInputService:IsKeyDown(Enum.KeyCode.D) then moveVec = moveVec + camCF.RightVector end
                if UserInputService:IsKeyDown(Enum.KeyCode.Space) then moveVec = moveVec + Vector3.new(0, 1, 0) end
                if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then moveVec = moveVec - Vector3.new(0, 1, 0) end
            end
            if moveVec.Magnitude > 0 then hrp.CFrame = hrp.CFrame + (moveVec.Unit * (ESPSettings.SpeedValue * deltaTime * 2)) end
        end

        if ESPSettings.Speed and not ESPSettings.Flight and not ESPSettings.VoidDodge and hum.MoveDirection.Magnitude > 0 then
            hrp.CFrame = hrp.CFrame + (hum.MoveDirection * (ESPSettings.SpeedValue * deltaTime))
        end

        if ESPSettings.Spin then
            hum.AutoRotate = false 
            local bav = hrp:FindFirstChild("SpinbotBAV") or Instance.new("BodyAngularVelocity")
            if not bav.Parent then bav.Name = "SpinbotBAV" bav.MaxTorque = Vector3.new(0, math.huge, 0) bav.Parent = hrp end
            bav.AngularVelocity = Vector3.new(0, ESPSettings.SpinSpeed, 0)
        else
            hum.AutoRotate = true
            local bav = hrp:FindFirstChild("SpinbotBAV")
            if bav then bav:Destroy() end
        end
    end
end))

table.insert(Connections, RunService.RenderStepped:Connect(function()
    Camera.FieldOfView = ESPSettings.PlayerFOV
    FOVCircle.Visible = (ESPSettings.Aimbot and not ESPSettings.AimbotLockNearest)
    if FOVCircle.Visible then FOVCircle.Position = UserInputService:GetMouseLocation() FOVCircle.Radius = ESPSettings.AimbotFOV end
    SilentFOVCircle.Visible = ESPSettings.SilentAim
    if SilentFOVCircle.Visible then SilentFOVCircle.Position = UserInputService:GetMouseLocation() SilentFOVCircle.Radius = ESPSettings.SilentAimFOV end

    -- ❄️ 下雪效果：跟隨鏡頭位置，僅在開關開啟時發射粒子
    SnowEmitterPart.CFrame = CFrame.new(Camera.CFrame.Position + Vector3.new(0, 35, 0))
    SnowEmitter.Rate = ESPSettings.Snow and 150 or 0

    for player, v in pairs(ESPTable) do
        if v.Char and v.Char.Parent then
            local hum = v.Char:FindFirstChildOfClass("Humanoid")
            local head = v.Char:FindFirstChild("Head")
            if hum and hum.Health > 0 and head then
                v.Highlight.Enabled = ESPSettings.Skeleton
                v.Box.Enabled = ESPSettings.Box
                v.BarGui.Enabled = ESPSettings.Health
                
                v.NameGui.Enabled = ESPSettings.NameShow
                if ESPSettings.NameShow and v.NameLabel then
                    if ESPSettings.SpoofOthers then
                        v.NameLabel.Text = ESPSettings.SpoofOthersName
                    else
                        v.NameLabel.Text = player.Name
                    end
                end

                if ESPSettings.Health then
                    local hp = hum.Health / hum.MaxHealth
                    v.Bar.Size = UDim2.new(0.05, 0, hp * 0.9, 0)
                    v.Bar.BackgroundColor3 = Color3.fromRGB(91, 168, 252):Lerp(Color3.fromRGB(255, 130, 240), 1 - hp)
                end
                if ESPSettings.HeadESP then
                    v.HeadLine.Transparency = NumberSequence.new(0.4)
                    if ESPSettings.HeadESPGradient then
                        v.HeadLine.Color = ColorSequence.new({
                            ColorSequenceKeypoint.new(0, ESPSettings.HeadESPColor1),
                            ColorSequenceKeypoint.new(1, ESPSettings.HeadESPColor2)
                        })
                    else
                        v.HeadLine.Color = ColorSequence.new(ESPSettings.HeadESPColor1)
                    end
                    v.HeadLineAnchor.CFrame = CFrame.new(head.Position + Vector3.new(0, 500, 0))
                else v.HeadLine.Transparency = NumberSequence.new(1) end
            else v.Box.Enabled = false v.BarGui.Enabled = false v.Highlight.Enabled = false v.HeadLine.Transparency = NumberSequence.new(1) v.NameGui.Enabled = false end
        else pcall(function() v.Box.Enabled = false v.BarGui.Enabled = false v.Highlight.Enabled = false v.HeadLine.Transparency = NumberSequence.new(1) v.NameGui.Enabled = false end) end
    end

    -- Head Sky Line 漸層色2輸入欄：只有在開啟漸層模式時才顯示,單色模式下隱藏
    if HeadESPColor2Row then HeadESPColor2Row.Visible = ESPSettings.HeadESPGradient end
end))

table.insert(Connections, RunService.Stepped:Connect(function()
    if (ESPSettings.Noclip or ESPSettings.Ragebot or ESPSettings.VoidDodge) and LocalPlayer.Character then
        for _, part in pairs(LocalPlayer.Character:GetDescendants()) do
            if part:IsA("BasePart") and part.CanCollide then part.CanCollide = false end
        end
    end
end))

-- 輸入監聽
table.insert(Connections, UserInputService.InputBegan:Connect(function(input, gp)
    if gp then return end
    if input.UserInputType == Enum.UserInputType.MouseButton2 then 
        isRightMouseDown = true 
        TriggerStatusBtn.BackgroundColor3 = Color3.fromRGB(35, 38, 55)
        TriggerStatusBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
        if not TriggerStatusBtn:FindFirstChildOfClass("UIGradient") then ApplyThemeGradient(TriggerStatusBtn) end
    elseif input.KeyCode == Enum.KeyCode.RightShift then 
        MainFrame.Visible = not MainFrame.Visible 
    elseif input.KeyCode == Enum.KeyCode.P then
        ESPSettings.Ragebot = not ESPSettings.Ragebot
        if rageBtnGlobal then
            local enabled = ESPSettings.Ragebot
            rageBtnGlobal.Text = enabled and "🔥 Ragebot [P]: ON" or "🔥 Ragebot [P]: OFF"
            if enabled then
                rageBtnGlobal.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
                rageBtnGlobal.TextColor3 = Color3.fromRGB(15, 15, 20)
                if not rageBtnGlobal:FindFirstChildOfClass("UIGradient") then ApplyThemeGradient(rageBtnGlobal) end
            else
                rageBtnGlobal.BackgroundColor3 = Color3.fromRGB(22, 24, 32)
                rageBtnGlobal.TextColor3 = Color3.fromRGB(170, 175, 190)
                local grad = rageBtnGlobal:FindFirstChildOfClass("UIGradient")
                if grad then grad:Destroy() end
            end
        end
    end
end))

table.insert(Connections, UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton2 then 
        isRightMouseDown = false 
        TriggerStatusBtn.BackgroundColor3 = Color3.fromRGB(18, 20, 26)
        TriggerStatusBtn.TextColor3 = Color3.fromRGB(140, 145, 160)
        local grad = TriggerStatusBtn:FindFirstChildOfClass("UIGradient")
        if grad then grad:Destroy() end
    end
end))

local function UnloadScript()
    for _, conn in pairs(Connections) do if conn then conn:Disconnect() end end
    table.clear(Connections)
    if FOVCircle then FOVCircle:Remove() end
    if SilentFOVCircle then SilentFOVCircle:Remove() end
    if SnowEmitterPart then SnowEmitterPart:Destroy() end
    if ScreenGui then ScreenGui:Destroy() end
    if VirtualProxy then VirtualProxy:Destroy() end
    if CurrentAnimationTrack then CurrentAnimationTrack:Stop() end
    for _, player in pairs(Players:GetPlayers()) do
        if ESPTable[player] then
            pcall(function() ESPTable[player].Highlight:Destroy() end)
            pcall(function() ESPTable[player].Box:Destroy() end)
            pcall(function() ESPTable[player].BarGui:Destroy() end)
            pcall(function() ESPTable[player].HeadLine:Destroy() end)
            pcall(function() ESPTable[player].HeadLineAnchor:Destroy() end)
            pcall(function() ESPTable[player].NameGui:Destroy() end)
        end
    end
    print("【系統】7imgoat 已安全卸載。")
end
ExitBtn.MouseButton1Click:Connect(UnloadScript)

-- ==========================================
-- 🎬 10. 直接顯示主面板 (已移除開場動畫)
-- ==========================================
MainFrame.Visible = true

-- ==========================================
-- 🌟 獨立新增：進階霧氣、超強世界變色與第三視角邏輯
-- ==========================================
-- 自動建立一個色彩濾鏡，用來覆蓋整個世界
local ColorFilter = game.Lighting:FindFirstChild("7imgoat_WorldFilter")
if not ColorFilter then
    ColorFilter = Instance.new("ColorCorrectionEffect")
    ColorFilter.Name = "7imgoat_WorldFilter"
    ColorFilter.Parent = game.Lighting
end

game:GetService("RunService").RenderStepped:Connect(function()
    if not ESPSettings then return end
    
    -- 1. 霧氣邏輯
    if ESPSettings.Fog then
        game.Lighting.FogEnd = 300 
        game.Lighting.FogColor = ESPSettings.LightingColor
    else
        game.Lighting.FogEnd = 100000 
    end

    -- 2. 超強世界變色邏輯 (LightingColorSwitch)
    if ESPSettings.LightingColorSwitch then
        -- 改變基礎光照並關閉陰影，讓顏色更純粹
        game.Lighting.Ambient = ESPSettings.LightingColor
        game.Lighting.OutdoorAmbient = ESPSettings.LightingColor
        game.Lighting.GlobalShadows = false 
        
        -- 開啟濾鏡，強制把畫面上所有東西染成你選的顏色
        ColorFilter.Enabled = true
        ColorFilter.TintColor = ESPSettings.LightingColor
        ColorFilter.Saturation = 1.5 -- 數字越大顏色越濃烈 (可依喜好微調)
        ColorFilter.Contrast = 0.2   -- 稍微加點對比讓畫面不會完全糊掉
    else
        -- 關閉時恢復正常狀態
        game.Lighting.GlobalShadows = true
        ColorFilter.Enabled = false
    end

    -- 3. 第三視角邏輯
    local lp = game:GetService("Players").LocalPlayer
    if lp then
        if ESPSettings.ThirdPerson then
            lp.CameraMode = Enum.CameraMode.Classic
            lp.CameraMaxZoomDistance = 128
            lp.CameraMinZoomDistance = 10 
        else
            lp.CameraMinZoomDistance = 0.5 
        end
    end
end)
