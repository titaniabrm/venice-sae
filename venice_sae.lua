--[[===================================================================
    VENICE HUB  ·  STEAL AN EGG  ·  v1.1.0
    -------------------------------------------------------------------
    LOADER (cole no executor):
        loadstring(game:HttpGet("URL_RAW_DO_SEU_GITHUB"))()

    Painel: botao flutuante "V" no canto da tela
            ou tecla de atalho (padrao: RightShift)
    -------------------------------------------------------------------
    Auto Steal · Auto Place/Hatch/Sell/Equip/Upgrade · ESP · Fly ·
    Noclip · Speed · Suite anti-ban completa
=====================================================================]]

--=====================================================================
-- 0. CONFIGURACAO  (TROQUE PELA SUA URL DO GITHUB)
--=====================================================================
local SCRIPT_URL = "https://raw.githubusercontent.com/titaniabrm/venice-sae/main/venice_sae.lua"
local HUB_VER    = "1.1.0"

--=====================================================================
-- 1. SERVICOS
--=====================================================================
local Players           = game:GetService("Players")
local RunService        = game:GetService("RunService")
local UIS               = game:GetService("UserInputService")
local TweenService      = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TeleportService   = game:GetService("TeleportService")
local HttpService       = game:GetService("HttpService")
local Lighting          = game:GetService("Lighting")
local VirtualUser       = game:GetService("VirtualUser")
local Stats             = game:GetService("Stats")
local Workspace         = workspace

local LP   = Players.LocalPlayer
local GENV = (getgenv and getgenv()) or _G

if GENV.VENICE_SAE_UNLOAD then pcall(GENV.VENICE_SAE_UNLOAD) end

--=====================================================================
-- 2. ESTADO
--=====================================================================
local Flags = {
    -- FARM
    AutoSteal=false, MoveMode="Tween", MoveSpeed=380, Priority="Raridade",
    MinRarity="Off", OnlyNames="", Humanize=true, Reach=70, Attempts=4,
    InstantGrab=false,
    AutoPlace=false, AutoHatch=false, AutoEquipBest=false, AutoSellPets=false,
    AutoSellEggs=false, AutoUpgradeBase=false, AutoUpgradeTreadmill=false,
    AutoClaim=false, AutoServerHop=false, HopEmpty=false, AntiGuard=false,
    WebhookRare=false,
    -- PLAYER
    SpeedOn=false, SpeedValue=60, JumpOn=false, JumpValue=60, InfJump=false,
    Fly=false, FlySpeed=95, Noclip=false, Godmode=false, AntiRagdoll=false,
    AntiFling=false, AntiVoid=false, AntiTrap=false, AntiKnockback=false,
    -- VISUAL
    EggESP=false, ESPName=true, ESPRarity=true, ESPDist=true, ESPValue=true,
    ESPWeight=false, GuardESP=false, TrapESP=false, Fullbright=false,
    NoFog=false, FPSBoost=false, NoParticles=false,
    -- ANTI-BAN
    AntiAFK=false, AntiKick=false, AntiCrash=false, Stealth=false, IdleBlock=false,
    -- MISC
    Notify=true, Keybind="RightShift", Webhook="",
    -- STATS
    Steals=0, Found=0, Failed=0, StartTime=os.clock(),
}

local CONN = {}
local function bind(sig, fn)
    local c = sig:Connect(fn)
    table.insert(CONN, c)
    return c
end
local function safe(fn, ...)
    local ok, res = pcall(fn, ...)
    return ok and res or nil
end

--=====================================================================
-- 3. HELPERS GERAIS
--=====================================================================
local function getChar() return LP.Character end
local function getHRP()
    local c = getChar()
    return c and c:FindFirstChild("HumanoidRootPart")
end
local function getHum()
    local c = getChar()
    return c and c:FindFirstChildOfClass("Humanoid")
end
local function attr(obj, list)
    if not obj then return nil end
    for _, n in ipairs(list) do
        local ok, v = pcall(function() return obj:GetAttribute(n) end)
        if ok and v ~= nil then return v end
    end
    return nil
end
local function getPos(obj)
    if not obj or not obj.Parent then return nil end
    if obj:IsA("BasePart") then return obj.Position end
    if obj:IsA("Model") then
        local ok, p = pcall(function() return obj:GetPivot().Position end)
        if ok and p then return p end
        local pp = obj.PrimaryPart or obj:FindFirstChildWhichIsA("BasePart", true)
        if pp then return pp.Position end
    end
    return nil
end
local function insideOf(obj, ancestor)
    if not obj or not ancestor then return false end
    local a = obj
    while a and a ~= Workspace do
        if a == ancestor then return true end
        a = a.Parent
    end
    return false
end
local function isInCharacter(obj)
    local c = getChar()
    return c and insideOf(obj, c) or false
end

-- Raridades: ordem importa (uncommon ANTES de common)
local RARITY_LIST = {
    {"heavenly",13}, {"celestial",12}, {"exotic",11}, {"godly",10},
    {"secret",9}, {"eternal",8}, {"divine",7}, {"mythical",6}, {"mythic",6},
    {"legendary",5}, {"epic",4}, {"uncommon",2}, {"rare",3}, {"common",1},
}
local function rarityRank(r)
    if r == nil then return 0 end
    local s = string.lower(tostring(r))
    for _, pair in ipairs(RARITY_LIST) do
        if string.find(s, pair[1], 1, true) then return pair[2] end
    end
    local n = tonumber(s)
    if n then return n end
    return 0.5
end
local function rarityColor(r)
    local n = rarityRank(r)
    if n >= 12 then return Color3.fromRGB(255, 60, 60)   end
    if n >= 10 then return Color3.fromRGB(255, 180, 40)  end
    if n >= 8  then return Color3.fromRGB(255, 110, 255) end
    if n >= 7  then return Color3.fromRGB(185, 135, 255) end
    if n >= 6  then return Color3.fromRGB(255, 140, 60)  end
    if n >= 5  then return Color3.fromRGB(255, 220, 90)  end
    if n >= 4  then return Color3.fromRGB(160, 90, 255)  end
    if n >= 3  then return Color3.fromRGB(90, 160, 255)  end
    if n >= 2  then return Color3.fromRGB(90, 220, 140)  end
    return Color3.fromRGB(190, 190, 200)
end
local function getRarity(o)
    if not o then return nil end
    local v = attr(o, {"Rarity","rarity","Tier","RarityName"})
    if v then return tostring(v) end
    local s = o:FindFirstChild("Rarity") or o:FindFirstChild("Tier")
    if s and (s:IsA("StringValue") or s:IsA("NumberValue")) then
        return tostring(s.Value)
    end
    return nil
end
local function getValue(o)
    return tonumber(attr(o, {"Income","Value","CashPerSecond","IncomePerSecond",
                             "Earnings","ValuePerSecond"})) or 0
end
local function getWeight(o)
    return tonumber(attr(o, {"Weight","KG","Mass","Kilos"})) or 0
end

local function firePrompt(p)
    if not p then return false end
    if fireproximityprompt then
        if pcall(fireproximityprompt, p) then return true end
    end
    return (pcall(function()
        p:InputHoldBegin()
        task.wait(0.03)
        p:InputHoldEnd()
    end))
end
local function fireClick(part)
    if fireclickdetector and part then
        local cd = part:FindFirstChildWhichIsA("ClickDetector")
        if cd then pcall(fireclickdetector, cd) end
    end
end

--=====================================================================
-- 4. UI
--=====================================================================
local Theme = {
    Bg=Color3.fromRGB(16,16,21), Panel=Color3.fromRGB(26,26,34),
    Stroke=Color3.fromRGB(48,48,62), Text=Color3.fromRGB(236,236,244),
    Sub=Color3.fromRGB(150,150,168), Accent=Color3.fromRGB(140,88,255),
    Accent2=Color3.fromRGB(90,205,255), Bad=Color3.fromRGB(255,95,95),
}
local function new(class, props)
    local i = Instance.new(class)
    local parent
    for k, v in pairs(props or {}) do
        if k == "Parent" then parent = v else i[k] = v end
    end
    if parent then i.Parent = parent end
    return i
end
local function corner(o, r)
    new("UICorner", {CornerRadius = UDim.new(0, r or 8), Parent = o})
end
local function stroke(o, c, t)
    new("UIStroke", {Color = c or Theme.Stroke, Thickness = t or 1, Parent = o})
end

local Screen
do
    local ok = pcall(function()
        Screen = new("ScreenGui", {Name="VeniceHub_SAE", ResetOnSpawn=false,
            IgnoreGuiInset=true, ZIndexBehavior=Enum.ZIndexBehavior.Sibling,
            Parent=(gethui and gethui()) or game:GetService("CoreGui")})
    end)
    if not ok then
        Screen = new("ScreenGui", {Name="VeniceHub_SAE", ResetOnSpawn=false,
            IgnoreGuiInset=true, ZIndexBehavior=Enum.ZIndexBehavior.Sibling,
            Parent=LP:WaitForChild("PlayerGui")})
    end
end

local ToggleBtn = new("TextButton", {
    Name="ToggleBtn", Size=UDim2.fromOffset(54,54),
    Position=UDim2.new(0,20,0.5,-27), BackgroundColor3=Theme.Accent,
    Text="V", TextColor3=Color3.new(1,1,1), Font=Enum.Font.GothamBold,
    TextSize=24, AutoButtonColor=false, ZIndex=50, Parent=Screen})
corner(ToggleBtn, 27)
stroke(ToggleBtn, Theme.Accent2, 2)

local Win = new("Frame", {
    Name="Window", Size=UDim2.fromOffset(640,440),
    Position=UDim2.new(0.5,-320,0.5,-220), BackgroundColor3=Theme.Bg,
    Visible=false, ZIndex=40, Parent=Screen})
corner(Win, 12)
stroke(Win, Theme.Stroke, 1)

local Title = new("Frame", {Size=UDim2.new(1,0,0,34),
    BackgroundColor3=Theme.Panel, ZIndex=41, Parent=Win})
corner(Title, 12)
new("TextLabel", {Size=UDim2.new(1,-110,1,0), Position=UDim2.new(0,14,0,0),
    BackgroundTransparency=1, Text="  VENICE HUB  ·  Steal An Egg  ·  v"..HUB_VER,
    TextColor3=Theme.Text, Font=Enum.Font.GothamBold, TextSize=14,
    TextXAlignment=Enum.TextXAlignment.Left, ZIndex=42, Parent=Title})

local CloseBtn = new("TextButton", {Size=UDim2.fromOffset(26,26),
    Position=UDim2.new(1,-34,0.5,-13), BackgroundColor3=Theme.Bad, Text="x",
    TextColor3=Color3.new(1,1,1), Font=Enum.Font.GothamBold, TextSize=15,
    AutoButtonColor=false, ZIndex=43, Parent=Title})
corner(CloseBtn, 6)

local TabBar = new("Frame", {Size=UDim2.new(1,-12,0,30),
    Position=UDim2.new(0,6,0,40), BackgroundTransparency=1, ZIndex=41, Parent=Win})
new("UIListLayout", {FillDirection=Enum.FillDirection.Horizontal,
    Padding=UDim.new(0,6), SortOrder=Enum.SortOrder.LayoutOrder, Parent=TabBar})

local ContentHolder = new("Frame", {Size=UDim2.new(1,-12,1,-84),
    Position=UDim2.new(0,6,0,76), BackgroundTransparency=1, ZIndex=41, Parent=Win})

-- Notificacoes
local function notify(t, msg, dur)
    if not Flags.Notify or not Screen.Parent then return end
    local box = new("Frame", {Size=UDim2.fromOffset(290,60),
        Position=UDim2.new(1,-310,0,20), BackgroundColor3=Theme.Panel,
        ZIndex=100, Parent=Screen})
    corner(box, 8)
    stroke(box, Theme.Accent, 1)
    new("TextLabel", {Size=UDim2.new(1,-16,0,20), Position=UDim2.new(0,10,0,8),
        BackgroundTransparency=1, Text=t, TextColor3=Theme.Accent2,
        Font=Enum.Font.GothamBold, TextSize=13,
        TextXAlignment=Enum.TextXAlignment.Left, ZIndex=101, Parent=box})
    new("TextLabel", {Size=UDim2.new(1,-16,0,24), Position=UDim2.new(0,10,0,28),
        BackgroundTransparency=1, Text=msg, TextColor3=Theme.Text,
        Font=Enum.Font.Gotham, TextSize=12, TextWrapped=true,
        TextXAlignment=Enum.TextXAlignment.Left, ZIndex=101, Parent=box})
    task.delay(dur or 3, function()
        if box.Parent then
            TweenService:Create(box, TweenInfo.new(0.25),
                {BackgroundTransparency=1}):Play()
            task.wait(0.3)
            box:Destroy()
        end
    end)
end

-- Drag com guarda anti-clique
local function draggable(frame, handle, guard)
    local drag, startPos, startInput, lastPos, moved = false, nil, nil, nil, 0
    bind(handle.InputBegan, function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1
        or i.UserInputType == Enum.UserInputType.Touch then
            drag = true
            startInput, lastPos, moved = i.Position, i.Position, 0
            startPos = frame.Position
        end
    end)
    bind(UIS.InputChanged, function(i)
        if drag and (i.UserInputType == Enum.UserInputType.MouseMovement
        or i.UserInputType == Enum.UserInputType.Touch) then
            moved = moved + (i.Position - lastPos).Magnitude
            lastPos = i.Position
            local d = i.Position - startInput
            frame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X,
                                       startPos.Y.Scale, startPos.Y.Offset + d.Y)
        end
    end)
    bind(UIS.InputEnded, function(i)
        if not drag then return end
        if i.UserInputType == Enum.UserInputType.MouseButton1
        or i.UserInputType == Enum.UserInputType.Touch then
            drag = false
            if guard and moved > 4 then
                guard.Dragged = true
                task.delay(0.12, function() guard.Dragged = false end)
            end
        end
    end)
end

local ToggleGuard = {}
draggable(Win, Title)
draggable(ToggleBtn, ToggleBtn, ToggleGuard)

local function setOpen(v)
    Win.Visible = v
    TweenService:Create(ToggleBtn, TweenInfo.new(0.15),
        {BackgroundColor3 = v and Theme.Accent2 or Theme.Accent}):Play()
end
bind(ToggleBtn.MouseButton1Click, function()
    if ToggleGuard.Dragged then return end
    setOpen(not Win.Visible)
end)
bind(CloseBtn.MouseButton1Click, function() setOpen(false) end)
bind(UIS.InputBegan, function(i, gpe)
    if gpe then return end
    if UIS:GetFocusedTextBox() then return end
    if i.KeyCode ~= Enum.KeyCode.Unknown and i.KeyCode.Name == Flags.Keybind then
        setOpen(not Win.Visible)
    end
end)

-- Construtor de elementos
local Tabs = {}
local firstTabShown = false
local function makeTab(name)
    local btn = new("TextButton", {Size=UDim2.fromOffset(96,28),
        BackgroundColor3=Theme.Panel, Text=name, TextColor3=Theme.Sub,
        Font=Enum.Font.GothamSemibold, TextSize=12, AutoButtonColor=false,
        ZIndex=42, Parent=TabBar})
    corner(btn, 6)
    stroke(btn, Theme.Stroke)
    local content = new("ScrollingFrame", {Size=UDim2.new(1,0,1,0),
        BackgroundTransparency=1, BorderSizePixel=0, ScrollBarThickness=4,
        ScrollBarImageColor3=Theme.Accent, CanvasSize=UDim2.new(0,0,0,0),
        Visible=false, ZIndex=42, Parent=ContentHolder})
    local layout = new("UIListLayout", {Padding=UDim.new(0,6),
        SortOrder=Enum.SortOrder.LayoutOrder, Parent=content})
    new("UIPadding", {PaddingTop=UDim.new(0,6), PaddingBottom=UDim.new(0,16),
        PaddingLeft=UDim.new(0,6), PaddingRight=UDim.new(0,6), Parent=content})
    bind(layout:GetPropertyChangedSignal("AbsoluteContentSize"), function()
        content.CanvasSize = UDim2.new(0,0,0, layout.AbsoluteContentSize.Y + 24)
    end)
    local tab = {Content = content, Button = btn}
    Tabs[name] = tab
    btn.MouseButton1Click:Connect(function()
        for _, t in pairs(Tabs) do
            t.Content.Visible = false
            TweenService:Create(t.Button, TweenInfo.new(0.12),
                {TextColor3 = Theme.Sub}):Play()
        end
        content.Visible = true
        TweenService:Create(btn, TweenInfo.new(0.12),
            {TextColor3 = Theme.Accent2}):Play()
    end)
    if not firstTabShown then
        firstTabShown = true
        content.Visible = true
        btn.TextColor3 = Theme.Accent2
    end
    return tab
end

local function section(parent, text)
    new("TextLabel", {Size=UDim2.new(1,0,0,22), BackgroundTransparency=1,
        Text=text, TextColor3=Theme.Accent2, Font=Enum.Font.GothamBold,
        TextSize=12, TextXAlignment=Enum.TextXAlignment.Left, Parent=parent})
end
local function label(parent, text, h)
    new("TextLabel", {Size=UDim2.new(1,0,0,h or 20), BackgroundTransparency=1,
        Text=text, TextColor3=Theme.Text, Font=Enum.Font.Gotham, TextSize=13,
        TextXAlignment=Enum.TextXAlignment.Left, TextWrapped=true, Parent=parent})
end

local function makeToggle(parent, o)
    local row = new("Frame", {Size=UDim2.new(1,0,0,30),
        BackgroundTransparency=1, Parent=parent})
    new("TextLabel", {Size=UDim2.new(1,-56,1,0), BackgroundTransparency=1,
        Text=o.Text, TextColor3=Theme.Text, Font=Enum.Font.Gotham, TextSize=13,
        TextXAlignment=Enum.TextXAlignment.Left, Parent=row})
    local sw = new("TextButton", {Size=UDim2.fromOffset(42,20),
        Position=UDim2.new(1,-42,0.5,-10), BackgroundColor3=Theme.Panel,
        Text="", AutoButtonColor=false, Parent=row})
    corner(sw, 10)
    stroke(sw, Theme.Stroke)
    local knob = new("Frame", {Size=UDim2.fromOffset(16,16),
        Position=UDim2.new(0,2,0.5,-8), BackgroundColor3=Theme.Sub, Parent=sw})
    corner(knob, 8)
    local state = o.Default and true or false
    local obj = {}
    local function render()
        TweenService:Create(sw, TweenInfo.new(0.14),
            {BackgroundColor3 = state and Theme.Accent or Theme.Panel}):Play()
        TweenService:Create(knob, TweenInfo.new(0.14), {
            Position = state and UDim2.new(1,-18,0.5,-8) or UDim2.new(0,2,0.5,-8),
            BackgroundColor3 = state and Color3.new(1,1,1) or Theme.Sub}):Play()
    end
    function obj.Set(v)
        state = v and true or false
        if o.Flag then Flags[o.Flag] = state end
        render()
        if o.Callback then task.spawn(o.Callback, state) end
    end
    bind(sw.MouseButton1Click, function() obj.Set(not state) end)
    if o.Flag then Flags[o.Flag] = state end
    render()
    return obj
end

local function makeSlider(parent, o)
    local row = new("Frame", {Size=UDim2.new(1,0,0,40),
        BackgroundTransparency=1, Parent=parent})
    new("TextLabel", {Size=UDim2.new(1,-60,0,18), BackgroundTransparency=1,
        Text=o.Text, TextColor3=Theme.Text, Font=Enum.Font.Gotham, TextSize=13,
        TextXAlignment=Enum.TextXAlignment.Left, Parent=row})
    local val = new("TextLabel", {Size=UDim2.new(0,54,0,18),
        Position=UDim2.new(1,-54,0,0), BackgroundTransparency=1,
        Text=tostring(o.Default), TextColor3=Theme.Accent2,
        Font=Enum.Font.GothamBold, TextSize=12,
        TextXAlignment=Enum.TextXAlignment.Right, Parent=row})
    local bar = new("TextButton", {Size=UDim2.new(1,0,0,8),
        Position=UDim2.new(0,0,0,24), BackgroundColor3=Theme.Panel,
        Text="", AutoButtonColor=false, Parent=row})
    corner(bar, 4)
    stroke(bar, Theme.Stroke)
    local fill = new("Frame", {Size=UDim2.new(0,0,1,0),
        BackgroundColor3=Theme.Accent, Parent=bar})
    corner(fill, 4)
    local dragging = false
    local function apply(x)
        local rel = math.clamp((x - bar.AbsolutePosition.X)
            / math.max(bar.AbsoluteSize.X, 1), 0, 1)
        local v = math.floor(o.Min + (o.Max - o.Min) * rel + 0.5)
        fill.Size = UDim2.new(rel, 0, 1, 0)
        val.Text = tostring(v)
        if o.Flag then Flags[o.Flag] = v end
        if o.Callback then task.spawn(o.Callback, v) end
    end
    bind(bar.InputBegan, function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1
        or i.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            apply(i.Position.X)
        end
    end)
    bind(UIS.InputChanged, function(i)
        if dragging and (i.UserInputType == Enum.UserInputType.MouseMovement
        or i.UserInputType == Enum.UserInputType.Touch) then
            apply(i.Position.X)
        end
    end)
    bind(UIS.InputEnded, function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1
        or i.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end)
    if o.Flag then Flags[o.Flag] = o.Default end
    task.defer(function()
        local rel = (o.Default - o.Min) / math.max(o.Max - o.Min, 1)
        fill.Size = UDim2.new(rel, 0, 1, 0)
    end)
    return {}
end

local function makeButton(parent, o)
    local b = new("TextButton", {Size=UDim2.new(1,0,0,28),
        BackgroundColor3=Theme.Panel, Text=o.Text, TextColor3=Theme.Text,
        Font=Enum.Font.GothamSemibold, TextSize=12, AutoButtonColor=false,
        Parent=parent})
    corner(b, 6)
    stroke(b, Theme.Stroke)
    bind(b.MouseButton1Click, function()
        if o.Callback then task.spawn(o.Callback) end
    end)
    return b
end

local function makeDropdown(parent, o)
    local row = new("Frame", {Size=UDim2.new(1,0,0,30),
        BackgroundTransparency=1, Parent=parent})
    new("TextLabel", {Size=UDim2.new(1,-160,1,0), BackgroundTransparency=1,
        Text=o.Text, TextColor3=Theme.Text, Font=Enum.Font.Gotham, TextSize=13,
        TextXAlignment=Enum.TextXAlignment.Left, Parent=row})
    local idx = 1
    for i, v in ipairs(o.Options) do
        if v == o.Default then idx = i end
    end
    local b = new("TextButton", {Size=UDim2.fromOffset(150,24),
        Position=UDim2.new(1,-150,0.5,-12), BackgroundColor3=Theme.Panel,
        Text=o.Options[idx], TextColor3=Theme.Accent2,
        Font=Enum.Font.GothamSemibold, TextSize=12, AutoButtonColor=false,
        Parent=row})
    corner(b, 6)
    stroke(b, Theme.Stroke)
    local obj = {}
    function obj.Set(i)
        idx = ((i - 1) % #o.Options) + 1
        b.Text = o.Options[idx]
        if o.Flag then Flags[o.Flag] = o.Options[idx] end
        if o.Callback then task.spawn(o.Callback, o.Options[idx]) end
    end
    bind(b.MouseButton1Click, function() obj.Set(idx + 1) end)
    if o.Flag then Flags[o.Flag] = o.Options[idx] end
    return obj
end

local function makeInput(parent, o)
    local row = new("Frame", {Size=UDim2.new(1,0,0,30),
        BackgroundTransparency=1, Parent=parent})
    new("TextLabel", {Size=UDim2.new(1,-190,1,0), BackgroundTransparency=1,
        Text=o.Text, TextColor3=Theme.Text, Font=Enum.Font.Gotham, TextSize=13,
        TextXAlignment=Enum.TextXAlignment.Left, Parent=row})
    local box = new("TextBox", {Size=UDim2.fromOffset(180,24),
        Position=UDim2.new(1,-180,0.5,-12), BackgroundColor3=Theme.Panel,
        Text=o.Default or "", PlaceholderText=o.Placeholder or "",
        TextColor3=Theme.Text, PlaceholderColor3=Theme.Sub,
        Font=Enum.Font.Gotham, TextSize=12, ClearTextOnFocus=false, Parent=row})
    corner(box, 6)
    stroke(box, Theme.Stroke)
    bind(box.FocusLost, function()
        if o.Flag then Flags[o.Flag] = box.Text end
        if o.Callback then task.spawn(o.Callback, box.Text) end
    end)
    if o.Flag then Flags[o.Flag] = o.Default end
    return box
end

--=====================================================================
-- 5. DESCOBERTA DO JOGO (SCAN UNICO)
--=====================================================================
local SCAN = {Eggs={}, Traps={}, Guards={}, Particles={}, T=0}

local function findOwnPlot()
    for _, n in ipairs({"Plots","Plot","Bases","Base","PlayerPlots","Houses"}) do
        local folder = Workspace:FindFirstChild(n)
        if folder then
            for _, p in ipairs(folder:GetChildren()) do
                local o = attr(p, {"Owner","owner","PlayerName","Username"})
                if o == LP.Name or tostring(o) == tostring(LP.UserId) then return p end
                if p.Name == LP.Name or p.Name == LP.DisplayName then return p end
                local ov = p:FindFirstChild("Owner")
                if ov and (ov.Value == LP.Name or ov.Value == LP.UserId) then return p end
                if p:FindFirstChild(LP.Name) then return p end
            end
        end
    end
    return Workspace:FindFirstChild(LP.Name)
end

local PlotCache, PlotTime = nil, 0
local function getOwnPlot()
    if PlotCache and PlotCache.Parent and os.clock() - PlotTime < 4 then
        return PlotCache
    end
    PlotCache = findOwnPlot()
    PlotTime = os.clock()
    return PlotCache
end

local function isEggModel(obj)
    if not (obj:IsA("Model") or obj:IsA("BasePart")) then return false end
    local n = string.lower(obj.Name)
    if string.find(n, "pet", 1, true) then return false end
    if string.find(n, "egg", 1, true) then return true end
    if getRarity(obj) and obj:FindFirstChildWhichIsA("ProximityPrompt", true) then
        return true
    end
    return false
end

local function scanWorld()
    local plot  = getOwnPlot()
    local char  = getChar()
    local eggs, traps, guards, parts = {}, {}, {}, {}

    for _, obj in ipairs(Workspace:GetDescendants()) do
        -- ovos
        if isEggModel(obj) then
            local real = obj
            local a = obj.Parent
            while a and a ~= Workspace and a:IsA("Model") and isEggModel(a) do
                real = a
                a = a.Parent
            end
            if not (plot and insideOf(real, plot))
            and not (char and insideOf(real, char)) then
                local dup = false
                for _, e in ipairs(eggs) do
                    if e == real then dup = true break end
                end
                if not dup then
                    local prompt = real:FindFirstChildWhichIsA("ProximityPrompt", true)
                    if Flags.InstantGrab and prompt then
                        pcall(function()
                            prompt.HoldDuration = 0
                            if prompt.MaxActivationDistance < Flags.Reach then
                                prompt.MaxActivationDistance = Flags.Reach
                            end
                        end)
                    end
                    eggs[#eggs + 1] = real
                end
            end
        end

        -- traps e particulas
        if obj:IsA("BasePart") then
            local n = string.lower(obj.Name)
            if string.find(n, "trap", 1, true)
            or string.find(n, "spike", 1, true)
            or string.find(n, "saw", 1, true)
            or string.find(n, "laser", 1, true) then
                traps[#traps + 1] = obj
            end
        elseif obj:IsA("ParticleEmitter") then
            parts[#parts + 1] = obj
        elseif obj:IsA("Model") then
            local n = string.lower(obj.Name)
            if string.find(n, "guard", 1, true)
            or string.find(n, "beast", 1, true) then
                guards[#guards + 1] = obj
            end
        end
    end

    SCAN.Eggs, SCAN.Traps, SCAN.Guards, SCAN.Particles = eggs, traps, guards, parts
    SCAN.T = os.clock()
    Flags.Found = #eggs
end

local function getEggs()
    if os.clock() - SCAN.T > 0.7 then pcall(scanWorld) end
    return SCAN.Eggs
end

local function passesFilter(egg)
    if Flags.MinRarity ~= "Off"
    and rarityRank(getRarity(egg)) < rarityRank(Flags.MinRarity) then
        return false
    end
    if Flags.OnlyNames ~= "" then
        local n = string.lower(egg.Name)
        local hit = false
        for part in string.gmatch(string.lower(Flags.OnlyNames), "[^,]+") do
            part = part:gsub("^%s+", ""):gsub("%s+$", "")
            if part ~= "" and string.find(n, part, 1, true) then hit = true break end
        end
        if not hit then return false end
    end
    return true
end

local function scoreEgg(egg)
    local hrp = getHRP()
    local pos = getPos(egg)
    local dist = (hrp and pos) and (hrp.Position - pos).Magnitude or 9999
    if Flags.Priority == "Renda" then return getValue(egg) * 1000 - dist * 0.01 end
    if Flags.Priority == "Peso"  then return getWeight(egg) * 1000 - dist * 0.01 end
    if Flags.Priority == "Perto" then return -dist end
    return rarityRank(getRarity(egg)) * 1e7 + getValue(egg) * 100 + getWeight(egg)
end

local function pickTarget()
    local best, bs
    for _, egg in ipairs(getEggs()) do
        if egg and egg.Parent and passesFilter(egg) then
            local s = scoreEgg(egg)
            if Flags.Humanize then s = s * (0.98 + math.random() * 0.04) end
            if not bs or s > bs then best, bs = egg, s end
        end
    end
    return best
end

local function getHomePos()
    local plot = getOwnPlot()
    if plot then
        local ok, piv = pcall(function() return plot:GetPivot().Position end)
        if ok and piv then return piv + Vector3.new(0, 6, 0) end
        local bp = plot:FindFirstChildWhichIsA("BasePart", true)
        if bp then return bp.Position + Vector3.new(0, 8, 0) end
    end
    local sp = Workspace:FindFirstChildWhichIsA("SpawnLocation", true)
    return sp and (sp.Position + Vector3.new(0, 6, 0)) or nil
end

local function clickGUI(patterns)
    local pg = LP:FindFirstChildOfClass("PlayerGui")
    if not pg then return 0 end
    local hits = 0
    for _, d in ipairs(pg:GetDescendants()) do
        if d:IsA("GuiButton") and d.Visible then
            local ok, t = pcall(function() return d.Text end)
            local txt = string.lower((ok and t or "") .. " " .. d.Name)
            for _, p in ipairs(patterns) do
                if string.find(txt, string.lower(p), 1, true) then
                    pcall(function() d.Activated:Fire() end)
                    pcall(function() d.MouseButton1Click:Fire() end)
                    hits = hits + 1
                    break
                end
            end
        end
    end
    return hits
end

--=====================================================================
-- 6. MOVIMENTO
--=====================================================================
local Move = {Active=false, Cancel=false}

local function moveTo(pos, speed, timeout)
    speed = speed or Flags.MoveSpeed
    timeout = timeout or 14
    local hrp = getHRP()
    if not hrp or not pos then return false end
    Move.Cancel = false

    if Flags.MoveMode == "Instant" or Flags.MoveMode == "Teleport" then
        pcall(function() hrp.CFrame = CFrame.new(pos) end)
        pcall(function() hrp.AssemblyLinearVelocity = Vector3.zero end)
        task.wait(Flags.MoveMode == "Teleport" and 0.12 or 0.05)
        local h = getHum()
        if h then pcall(function() h:ChangeState(Enum.HumanoidStateType.Running) end) end
        return true
    end

    local start = hrp.Position
    local dist = (pos - start).Magnitude
    if dist < 3 then return true end

    local hum = getHum()
    local oldWS = hum and hum.WalkSpeed or 16
    if hum then pcall(function() hum.WalkSpeed = 0 end) end

    Move.Active = true
    local dur = math.max(dist / math.max(speed, 25), 0.06)
    local t0 = os.clock()

    while true do
        if Move.Cancel or not hrp.Parent then break end
        local el = os.clock() - t0
        if el >= dur or el > timeout then break end
        local cur = start:Lerp(pos, math.min(el / dur, 1))
        local ok = pcall(function()
            hrp.CFrame = CFrame.new(cur)
            hrp.AssemblyLinearVelocity = Vector3.zero
        end)
        if not ok then break end
        RunService.Heartbeat:Wait()
    end

    pcall(function()
        hrp.CFrame = CFrame.new(pos)
        hrp.AssemblyLinearVelocity = Vector3.zero
    end)
    if hum then pcall(function() hum.WalkSpeed = oldWS end) end
    if hum then pcall(function() hum:ChangeState(Enum.HumanoidStateType.Running) end) end
    Move.Active = false
    return true
end

--=====================================================================
-- 7. ACOES
--=====================================================================
local function isCarryingAny()
    local char = getChar()
    if char then
        for _, d in ipairs(char:GetDescendants()) do
            if d:IsA("Model") or d:IsA("BasePart") then
                local n = string.lower(d.Name)
                if string.find(n, "egg", 1, true) then return true end
                if getRarity(d) then return true end
            end
        end
    end
    for _, n in ipairs({"Inventory","Eggs","Carried","EggInventory"}) do
        local f = LP:FindFirstChild(n)
        if f and #f:GetChildren() > 0 then return true end
    end
    return false
end

local function grabEgg(egg)
    local prompt = egg:FindFirstChildWhichIsA("ProximityPrompt", true)
    if prompt then
        pcall(function()
            prompt.MaxActivationDistance =
                math.max(prompt.MaxActivationDistance, Flags.Reach)
        end)
        if firePrompt(prompt) then return true end
    end
    local part = egg:IsA("BasePart") and egg
        or egg:FindFirstChildWhichIsA("BasePart", true)
    if part then
        fireClick(part)
        return true
    end
    return false
end

local function placeEggs()
    local plot = getOwnPlot()
    if plot then
        for _, d in ipairs(plot:GetDescendants()) do
            if d:IsA("ProximityPrompt") then
                local a = string.lower(tostring(d.ActionText or "") .. " " .. d.Name)
                if string.find(a, "place", 1, true)
                or string.find(a, "drop", 1, true)
                or string.find(a, "pen", 1, true) then
                    pcall(function()
                        d.MaxActivationDistance =
                            math.max(d.MaxActivationDistance, Flags.Reach)
                    end)
                    firePrompt(d)
                end
            end
        end
    end
    clickGUI({"place all", "place egg", "drop egg"})
end

local function hatchEggs()
    local plot = getOwnPlot()
    if plot then
        for _, d in ipairs(plot:GetDescendants()) do
            if d:IsA("ProximityPrompt")
            and string.find(string.lower(d.ActionText or ""), "hatch", 1, true) then
                firePrompt(d)
            end
        end
    end
    clickGUI({"hatch all", "hatch egg"})
end

local function sellStuff()
    if Flags.AutoSellPets then clickGUI({"sell pet", "sell all pet"}) end
    if Flags.AutoSellEggs then clickGUI({"sell egg", "sell all egg"}) end
end

local function equipBest() clickGUI({"equip best", "auto equip", "best pet"}) end
local function upgradeStuff()
    if Flags.AutoUpgradeBase then clickGUI({"upgrade base", "upgrade plot"}) end
    if Flags.AutoUpgradeTreadmill then clickGUI({"upgrade treadmill"}) end
end
local function claimStuff()
    clickGUI({"claim offline", "claim index", "claim reward", "collect offline"})
end

local function hopServer()
    if not pcall(function() TeleportService:Teleport(game.PlaceId, LP) end) then
        pcall(function()
            TeleportService:TeleportToPlaceInstance(game.PlaceId, game.JobId, LP)
        end)
    end
end

local function findEmptyServer()
    if not game.HttpGet then return false end
    local ok, res = pcall(function()
        return game:HttpGet("https://games.roblox.com/v1/games/" .. game.PlaceId
            .. "/servers/Public?sortOrder=Asc&limit=100")
    end)
    if not ok or not res then return false end
    local ok2, data = pcall(function() return HttpService:JSONDecode(res) end)
    if not ok2 or not data or not data.data then return false end
    for _, s in ipairs(data.data) do
        if s.playing <= 3 and s.id ~= game.JobId then
            pcall(function()
                TeleportService:TeleportToPlaceInstance(game.PlaceId, s.id, LP)
            end)
            return true
        end
    end
    return false
end

local function sendWebhook(title, msg, color)
    if Flags.Webhook == "" then return end
    local req = (syn and syn.request) or (http and http.request)
        or http_request or request
    if not req then return end
    pcall(req, {
        Url = Flags.Webhook, Method = "POST",
        Headers = {["Content-Type"] = "application/json"},
        Body = HttpService:JSONEncode({embeds = {{
            title = title, description = msg,
            color = color or 5793266,
        }}}),
    })
end

--=====================================================================
-- 8. CICLO DE ROUBO
--=====================================================================
local StealBusy = false

local function stealCycle()
    if StealBusy then return end
    StealBusy = true

    local egg = pickTarget()
    if not egg then
        StealBusy = false
        if Flags.AutoServerHop then
            if Flags.HopEmpty then
                if not findEmptyServer() then hopServer() end
            else
                hopServer()
            end
            task.wait(3)
        end
        return
    end

    local pos = getPos(egg)
    if pos then
        moveTo(pos + Vector3.new(0, 2.5, 0), Flags.MoveSpeed)

        local carried = false
        for _ = 1, Flags.Attempts do
            if isCarryingAny() then carried = true break end
            if not egg.Parent then break end
            grabEgg(egg)

            local t0 = os.clock()
            while os.clock() - t0 < 1.2 do
                task.wait(0.06)
                if isCarryingAny() or isInCharacter(egg) then
                    carried = true
                    break
                end
                if not egg:IsDescendantOf(Workspace) then
                    carried = true
                    break
                end
            end
            if carried then break end
            moveTo(pos + Vector3.new(0, 1.5, 0), Flags.MoveSpeed, 6)
        end

        if carried then
            Flags.Steals = Flags.Steals + 1
            if Flags.Humanize then task.wait(0.05 + math.random() * 0.1) end
            local home = getHomePos()
            if home then moveTo(home, Flags.MoveSpeed, 16) end
            task.wait(0.1)
            if Flags.AutoPlace then placeEggs() end
            if Flags.AutoHatch then hatchEggs() end

            if Flags.WebhookRare and rarityRank(getRarity(egg)) >= 4 then
                task.spawn(sendWebhook, "Ovo roubado",
                    string.format("**%s** [%s]  ·  $%d/s  ·  total: %d",
                        egg.Name, tostring(getRarity(egg) or "?"),
                        math.floor(getValue(egg)), Flags.Steals))
            end
        else
            Flags.Failed = Flags.Failed + 1
        end
    end

    StealBusy = false
end

--=====================================================================
-- 9. ANTI-BAN
--=====================================================================
local NoclipCache = {}
local ParticleOrig = {}

local function setupAntiBan()
    bind(LP.Idled, function()
        if not Flags.AntiAFK then return end
        pcall(function()
            VirtualUser:CaptureController()
            VirtualUser:ClickButton2(Vector2.new())
        end)
    end)

    bind(LP.OnTeleport, function(state)
        if state ~= Enum.TeleportState.Started then return end
        if not Flags.AntiKick then return end
        if not queue_on_teleport then return end
        pcall(queue_on_teleport,
            'task.wait(3) loadstring(game:HttpGet("' .. SCRIPT_URL .. '"))()')
    end)
end

local function maintenance()
    local char = getChar()
    if not char then return end
    local hum = getHum()
    local hrp = getHRP()
    if not hum or not hrp then return end

    if Flags.Godmode then
        pcall(function()
            hum.MaxHealth = math.max(hum.MaxHealth, 100)
            if hum.Health < hum.MaxHealth then hum.Health = hum.MaxHealth end
        end)
    end

    if Flags.AntiRagdoll then
        pcall(function()
            hum:SetStateEnabled(Enum.HumanoidStateType.FallingDown, false)
            hum:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, false)
            local st = hum:GetState()
            if st == Enum.HumanoidStateType.FallingDown
            or st == Enum.HumanoidStateType.Ragdoll then
                hum:ChangeState(Enum.HumanoidStateType.Running)
            end
            hum.PlatformStand = false
        end)
    end

    if Flags.AntiFling then
        local v = hrp.AssemblyLinearVelocity
        if v.Magnitude > 400 then
            pcall(function() hrp.AssemblyLinearVelocity = v.Unit * 60 end)
        end
    end

    if Flags.AntiKnockback and not Move.Active then
        local v = hrp.AssemblyLinearVelocity
        if Vector3.new(v.X, 0, v.Z).Magnitude > 120 then
            pcall(function()
                hrp.AssemblyLinearVelocity = Vector3.new(v.X*0.2, v.Y, v.Z*0.2)
            end)
        end
    end

    if Flags.AntiVoid and hrp.Position.Y < -80 then
        local home = getHomePos()
        if home then pcall(function() hrp.CFrame = CFrame.new(home) end) end
    end

    if Flags.AntiTrap and not Move.Active then
        for _, d in ipairs(SCAN.Traps) do
            if d.Parent and (d.Position - hrp.Position).Magnitude < 9 then
                pcall(function()
                    hrp.AssemblyLinearVelocity =
                        Vector3.new(hrp.AssemblyLinearVelocity.X, 65,
                                    hrp.AssemblyLinearVelocity.Z)
                end)
                break
            end
        end
    end

    if Flags.Noclip then
        for _, p in ipairs(char:GetDescendants()) do
            if p:IsA("BasePart") then
                if NoclipCache[p] == nil then NoclipCache[p] = p.CanCollide end
                p.CanCollide = false
            end
        end
    elseif next(NoclipCache) then
        for p, v in pairs(NoclipCache) do
            if p.Parent then pcall(function() p.CanCollide = v end) end
        end
        NoclipCache = {}
    end

    if Flags.SpeedOn then pcall(function() hum.WalkSpeed = Flags.SpeedValue end) end
    if Flags.JumpOn then
        pcall(function()
            hum.UseJumpPower = true
            hum.JumpPower = Flags.JumpValue
        end)
    end
end

--=====================================================================
-- 10. FLY / VISUAL
--=====================================================================
local function updateFly(dt)
    if not Flags.Fly or Move.Active then return end
    local hrp = getHRP()
    local cam = Workspace.CurrentCamera
    if not hrp or not cam then return end
    local dir = Vector3.zero
    local cf = cam.CFrame
    if UIS:IsKeyDown(Enum.KeyCode.W) then dir = dir + cf.LookVector end
    if UIS:IsKeyDown(Enum.KeyCode.S) then dir = dir - cf.LookVector end
    if UIS:IsKeyDown(Enum.KeyCode.A) then dir = dir - cf.RightVector end
    if UIS:IsKeyDown(Enum.KeyCode.D) then dir = dir + cf.RightVector end
    if UIS:IsKeyDown(Enum.KeyCode.Space) then dir = dir + Vector3.yAxis end
    if UIS:IsKeyDown(Enum.KeyCode.LeftControl) then dir = dir - Vector3.yAxis end
    pcall(function()
        hrp.AssemblyLinearVelocity = dir.Magnitude > 0
            and dir.Unit * Flags.FlySpeed or Vector3.zero
    end)
end

local function applyVisuals()
    if Flags.Fullbright then
        pcall(function()
            Lighting.Brightness = 3
            Lighting.ClockTime = 14
            Lighting.Ambient = Color3.fromRGB(180,180,180)
            Lighting.OutdoorAmbient = Color3.fromRGB(180,180,180)
        end)
    end
    if Flags.NoFog then
        pcall(function()
            Lighting.FogEnd = 100000
            Lighting.FogStart = 100000
        end)
    end
    if Flags.NoParticles or Flags.FPSBoost then
        for _, p in ipairs(SCAN.Particles) do
            if p.Parent then
                if ParticleOrig[p] == nil then ParticleOrig[p] = p.Enabled end
                p.Enabled = false
            end
        end
    else
        for p, v in pairs(ParticleOrig) do
            if p.Parent then pcall(function() p.Enabled = v end) end
        end
        ParticleOrig = {}
    end
end

local ESPFolder, ESPItems = nil, {}
local function ensureESP()
    if ESPFolder and ESPFolder.Parent then return end
    ESPFolder = new("Folder", {Name="VeniceHub_ESP",
        Parent=(gethui and gethui()) or Screen.Parent or Workspace})
end
local function clearESP()
    for _, v in pairs(ESPItems) do
        if v.bill then v.bill:Destroy() end
        if v.hl then v.hl:Destroy() end
    end
    ESPItems = {}
end

local function updateESP()
    ensureESP()
    local hrp = getHRP()
    if not hrp then return end
    local seen = {}
    local list = {}

    if Flags.EggESP then
        for _, e in ipairs(SCAN.Eggs) do list[#list+1] = {obj=e, kind="egg"} end
    end
    if Flags.GuardESP then
        for _, g in ipairs(SCAN.Guards) do list[#list+1] = {obj=g, kind="guard"} end
    end
    if Flags.TrapESP then
        for _, t in ipairs(SCAN.Traps) do list[#list+1] = {obj=t, kind="trap"} end
    end

    for _, item in ipairs(list) do
        local obj = item.obj
        if obj.Parent and not seen[obj] then
            seen[obj] = true
            local rec = ESPItems[obj]
            if not rec then
                local part = obj:IsA("BasePart") and obj
                    or obj:FindFirstChildWhichIsA("BasePart", true)
                if part then
                    local bill = new("BillboardGui", {Size=UDim2.fromOffset(200,50),
                        StudsOffset=Vector3.new(0,3,0), AlwaysOnTop=true,
                        Adornee=part, MaxDistance=900, Parent=ESPFolder})
                    local lbl = new("TextLabel", {Size=UDim2.new(1,0,1,0),
                        BackgroundTransparency=1, Text="", Font=Enum.Font.GothamBold,
                        TextSize=12, TextStrokeTransparency=0.4, Parent=bill})
                    local hl = new("Highlight", {Adornee=obj, FillTransparency=0.7,
                        OutlineTransparency=0.3, Parent=ESPFolder})
                    rec = {bill=bill, hl=hl, label=lbl, obj=obj}
                    ESPItems[obj] = rec
                end
            end
            if rec then
                local col
                if item.kind == "egg" then
                    col = rarityColor(getRarity(obj))
                elseif item.kind == "guard" then
                    col = Color3.fromRGB(255,120,120)
                else
                    col = Color3.fromRGB(120,255,180)
                end
                rec.hl.FillColor = col
                rec.hl.OutlineColor = col

                local pos = getPos(obj)
                local dist = pos and (hrp.Position - pos).Magnitude or 0
                local lines = {}
                if Flags.ESPName then lines[#lines+1] = obj.Name end
                if Flags.ESPRarity and item.kind == "egg" then
                    lines[#lines+1] = "[" .. tostring(getRarity(obj) or "?") .. "]"
                end
                if Flags.ESPValue and item.kind == "egg" then
                    lines[#lines+1] = "$" .. math.floor(getValue(obj)) .. "/s"
                end
                if Flags.ESPWeight and item.kind == "egg" then
                    lines[#lines+1] = math.floor(getWeight(obj)) .. " kg"
                end
                if Flags.ESPDist then
                    lines[#lines+1] = string.format("%.0f studs", dist)
                end
                rec.label.Text = table.concat(lines, "  ")
                rec.label.TextColor3 = col
            end
        end
    end

    for obj, rec in pairs(ESPItems) do
        if not obj.Parent or not seen[obj] then
            if rec.bill then rec.bill:Destroy() end
            if rec.hl then rec.hl:Destroy() end
            ESPItems[obj] = nil
        end
    end
end

--=====================================================================
-- 11. ABAS DO PAINEL
--=====================================================================
local TabFarm    = makeTab("Farm")
local TabPlayer  = makeTab("Jogador")
local TabVisual  = makeTab("Visual")
local TabAntiBan = makeTab("Anti-Ban")
local TabMisc    = makeTab("Misc")
local TabConfig  = makeTab("Config")

-- FARM -------------------------------------------------------------
section(TabFarm.Content, "ROUBO AUTOMATICO")
makeToggle(TabFarm.Content, {Text="Auto Steal (master)", Flag="AutoSteal"})
makeDropdown(TabFarm.Content, {Text="Modo de movimento", Flag="MoveMode",
    Options={"Tween","Instant","Teleport"}, Default="Tween"})
makeSlider(TabFarm.Content, {Text="Velocidade de movimento", Flag="MoveSpeed",
    Min=100, Max=1500, Default=380})
makeDropdown(TabFarm.Content, {Text="Prioridade", Flag="Priority",
    Options={"Raridade","Renda","Peso","Perto"}, Default="Raridade"})
makeDropdown(TabFarm.Content, {Text="Raridade minima", Flag="MinRarity",
    Options={"Off","Common","Uncommon","Rare","Epic","Legendary","Mythic",
             "Divine","Eternal","Secret"}, Default="Off"})
makeInput(TabFarm.Content, {Text="So estes ovos (virgula)", Flag="OnlyNames",
    Placeholder="ex: dragon, void"})
makeSlider(TabFarm.Content, {Text="Reach (distancia do prompt)", Flag="Reach",
    Min=10, Max=200, Default=70})
makeSlider(TabFarm.Content, {Text="Tentativas por ovo", Flag="Attempts",
    Min=1, Max=10, Default=4})
makeToggle(TabFarm.Content, {Text="Instant Grab (HoldDuration = 0)", Flag="InstantGrab"})
makeToggle(TabFarm.Content, {Text="Humanizar acoes (anti-detect)", Flag="Humanize", Default=true})

section(TabFarm.Content, "BASE / PETS")
makeToggle(TabFarm.Content, {Text="Auto Place ovos", Flag="AutoPlace"})
makeToggle(TabFarm.Content, {Text="Auto Hatch", Flag="AutoHatch"})
makeToggle(TabFarm.Content, {Text="Auto Equip Best", Flag="AutoEquipBest"})
makeToggle(TabFarm.Content, {Text="Auto Sell Pets", Flag="AutoSellPets"})
makeToggle(TabFarm.Content, {Text="Auto Sell Eggs", Flag="AutoSellEggs"})
makeToggle(TabFarm.Content, {Text="Auto Upgrade Base", Flag="AutoUpgradeBase"})
makeToggle(TabFarm.Content, {Text="Auto Upgrade Treadmill", Flag="AutoUpgradeTreadmill"})
makeToggle(TabFarm.Content, {Text="Auto Claim (Index / Offline)", Flag="AutoClaim"})

section(TabFarm.Content, "SERVIDOR")
makeToggle(TabFarm.Content, {Text="Auto Server Hop (sem ovos)", Flag="AutoServerHop"})
makeToggle(TabFarm.Content, {Text="Hop para servidor vazio", Flag="HopEmpty"})
makeToggle(TabFarm.Content, {Text="Webhook: avisar roubos raros", Flag="WebhookRare"})
makeButton(TabFarm.Content, {Text="Roubar uma vez agora", Callback=function()
    task.spawn(stealCycle)
end})
makeButton(TabFarm.Content, {Text="Place / Hatch agora", Callback=function()
    placeEggs()
    task.wait(0.3)
    hatchEggs()
end})

-- JOGADOR ----------------------------------------------------------
section(TabPlayer.Content, "MOVIMENTO")
makeToggle(TabPlayer.Content, {Text="Speed Hack", Flag="SpeedOn"})
makeSlider(TabPlayer.Content, {Text="WalkSpeed", Flag="SpeedValue",
    Min=16, Max=500, Default=60})
makeToggle(TabPlayer.Content, {Text="Jump Power", Flag="JumpOn"})
makeSlider(TabPlayer.Content, {Text="Forca do pulo", Flag="JumpValue",
    Min=50, Max=500, Default=60})
makeToggle(TabPlayer.Content, {Text="Pulo Infinito", Flag="InfJump"})
makeToggle(TabPlayer.Content, {Text="Fly (WASD + Space/Ctrl)", Flag="Fly"})
makeSlider(TabPlayer.Content, {Text="Velocidade do Fly", Flag="FlySpeed",
    Min=30, Max=400, Default=95})
makeToggle(TabPlayer.Content, {Text="Noclip", Flag="Noclip"})

section(TabPlayer.Content, "PROTECAO")
makeToggle(TabPlayer.Content, {Text="Godmode (client)", Flag="Godmode"})
makeToggle(TabPlayer.Content, {Text="Anti Ragdoll", Flag="AntiRagdoll"})
makeToggle(TabPlayer.Content, {Text="Anti Fling", Flag="AntiFling"})
makeToggle(TabPlayer.Content, {Text="Anti Knockback", Flag="AntiKnockback"})
makeToggle(TabPlayer.Content, {Text="Anti Trap", Flag="AntiTrap"})
makeToggle(TabPlayer.Content, {Text="Anti Guard Knockback", Flag="AntiGuard"})
makeToggle(TabPlayer.Content, {Text="Anti Void (cair do mapa)", Flag="AntiVoid"})
makeButton(TabPlayer.Content, {Text="Resetar personagem", Callback=function()
    local c = getChar()
    if c then c:BreakJoints() end
end})

-- VISUAL -----------------------------------------------------------
section(TabVisual.Content, "ESP")
makeToggle(TabVisual.Content, {Text="Egg ESP", Flag="EggESP"})
makeToggle(TabVisual.Content, {Text="Mostrar nome", Flag="ESPName", Default=true})
makeToggle(TabVisual.Content, {Text="Mostrar raridade", Flag="ESPRarity", Default=true})
makeToggle(TabVisual.Content, {Text="Mostrar renda", Flag="ESPValue", Default=true})
makeToggle(TabVisual.Content, {Text="Mostrar peso", Flag="ESPWeight"})
makeToggle(TabVisual.Content, {Text="Mostrar distancia", Flag="ESPDist", Default=true})
makeToggle(TabVisual.Content, {Text="Guard ESP", Flag="GuardESP"})
makeToggle(TabVisual.Content, {Text="Trap ESP", Flag="TrapESP"})

section(TabVisual.Content, "GRAFICOS")
makeToggle(TabVisual.Content, {Text="Fullbright", Flag="Fullbright"})
makeToggle(TabVisual.Content, {Text="Remover neblina", Flag="NoFog"})
makeToggle(TabVisual.Content, {Text="Remover particulas", Flag="NoParticles"})
makeToggle(TabVisual.Content, {Text="FPS Boost", Flag="FPSBoost"})
makeButton(TabVisual.Content, {Text="Limpar ESP", Callback=clearESP})

-- ANTI-BAN ---------------------------------------------------------
section(TabAntiBan.Content, "ANTI-BAN / ANTI-KICK")
makeToggle(TabAntiBan.Content, {Text="Anti AFK", Flag="AntiAFK"})
makeToggle(TabAntiBan.Content, {Text="Bloquear idle disconnect", Flag="IdleBlock"})
makeToggle(TabAntiBan.Content, {Text="Anti Kick + Auto Reconectar", Flag="AntiKick"})
makeToggle(TabAntiBan.Content, {Text="Anti Crash (limpar cache)", Flag="AntiCrash"})
makeToggle(TabAntiBan.Content, {Text="Modo Stealth (movimento suave)", Flag="Stealth"})
label(TabAntiBan.Content,
    "Stealth joga a velocidade do tween para 250 e usa delays aleatorios, "
    .. "deixando o movimento parecer humano. Use em servidor cheio se tomar kick.",
    50)

-- MISC -------------------------------------------------------------
section(TabMisc.Content, "SERVIDOR")
makeButton(TabMisc.Content, {Text="Server Hop agora", Callback=hopServer})
makeButton(TabMisc.Content, {Text="Entrar em servidor vazio", Callback=function()
    if not findEmptyServer() then
        notify("Venice", "Nenhum servidor vazio encontrado")
    end
end})
makeButton(TabMisc.Content, {Text="Rejoin (mesmo servidor)", Callback=function()
    pcall(function()
        TeleportService:TeleportToPlaceInstance(game.PlaceId, game.JobId, LP)
    end)
end})

section(TabMisc.Content, "TELEPORTES")
makeButton(TabMisc.Content, {Text="Ir para o meu plot", Callback=function()
    local h = getHomePos()
    if h then moveTo(h, Flags.MoveSpeed) end
end})
makeButton(TabMisc.Content, {Text="Ir para o ovo mais raro", Callback=function()
    local e = pickTarget()
    local p = e and getPos(e)
    if p then moveTo(p + Vector3.new(0,3,0), Flags.MoveSpeed) end
end})

section(TabMisc.Content, "DISCORD WEBHOOK")
makeInput(TabMisc.Content, {Text="URL do Webhook", Flag="Webhook",
    Placeholder="https://discord.com/api/webhooks/..."})
makeButton(TabMisc.Content, {Text="Testar webhook", Callback=function()
    if Flags.Webhook == "" then
        return notify("Venice", "Cole a URL do webhook primeiro")
    end
    sendWebhook("Venice Hub", "Conectado em Steal An Egg.", 5793266)
    notify("Venice", "Webhook enviado")
end})

section(TabMisc.Content, "OUTROS")
makeToggle(TabMisc.Content, {Text="Notificacoes", Flag="Notify", Default=true})
makeDropdown(TabMisc.Content, {Text="Tecla do painel", Flag="Keybind",
    Options={"RightShift","LeftShift","RightControl","F1","F2","F3","F4",
             "Insert","Home"}, Default="RightShift"})
makeButton(TabMisc.Content, {Text="Salvar config", Callback=function()
    if not writefile then return notify("Venice", "Executor sem writefile") end
    local data = {}
    for k, v in pairs(Flags) do
        local t = type(v)
        if t == "boolean" or t == "number" or t == "string" then data[k] = v end
    end
    pcall(writefile, "venice_sae_config.json", HttpService:JSONEncode(data))
    notify("Venice", "Config salva")
end})
makeButton(TabMisc.Content, {Text="Carregar config", Callback=function()
    if not (isfile and readfile and isfile("venice_sae_config.json")) then
        return notify("Venice", "Nenhuma config salva")
    end
    local ok, d = pcall(function()
        return HttpService:JSONDecode(readfile("venice_sae_config.json"))
    end)
    if ok and type(d) == "table" then
        for k, v in pairs(d) do Flags[k] = v end
        notify("Venice", "Config carregada")
    end
end})
makeButton(TabMisc.Content, {Text="Descarregar script", Callback=function()
    if GENV.VENICE_SAE_UNLOAD then GENV.VENICE_SAE_UNLOAD() end
end})

-- CONFIG -----------------------------------------------------------
section(TabConfig.Content, "ESTATISTICAS")
local S_FPS   = new("TextLabel", {Size=UDim2.new(1,0,0,20), BackgroundTransparency=1,
    Text="FPS: --", TextColor3=Theme.Text, Font=Enum.Font.Gotham, TextSize=13,
    TextXAlignment=Enum.TextXAlignment.Left, Parent=TabConfig.Content})
local S_PING  = new("TextLabel", {Size=UDim2.new(1,0,0,20), BackgroundTransparency=1,
    Text="Ping: --", TextColor3=Theme.Text, Font=Enum.Font.Gotham, TextSize=13,
    TextXAlignment=Enum.TextXAlignment.Left, Parent=TabConfig.Content})
local S_INFO  = new("TextLabel", {Size=UDim2.new(1,0,0,20), BackgroundTransparency=1,
    Text="Ovos visiveis: 0", TextColor3=Theme.Text, Font=Enum.Font.Gotham,
    TextSize=13, TextXAlignment=Enum.TextXAlignment.Left, Parent=TabConfig.Content})
local S_STEAL = new("TextLabel", {Size=UDim2.new(1,0,0,20), BackgroundTransparency=1,
    Text="Roubados: 0", TextColor3=Theme.Text, Font=Enum.Font.Gotham,
    TextSize=13, TextXAlignment=Enum.TextXAlignment.Left, Parent=TabConfig.Content})
local S_UP    = new("TextLabel", {Size=UDim2.new(1,0,0,20), BackgroundTransparency=1,
    Text="Uptime: 0s", TextColor3=Theme.Text, Font=Enum.Font.Gotham,
    TextSize=13, TextXAlignment=Enum.TextXAlignment.Left, Parent=TabConfig.Content})
local S_PLOT  = new("TextLabel", {Size=UDim2.new(1,0,0,20), BackgroundTransparency=1,
    Text="Plot: nao encontrado", TextColor3=Theme.Text, Font=Enum.Font.Gotham,
    TextSize=13, TextXAlignment=Enum.TextXAlignment.Left, Parent=TabConfig.Content})
local S_STAT  = new("TextLabel", {Size=UDim2.new(1,0,0,20), BackgroundTransparency=1,
    Text="Status: parado", TextColor3=Theme.Sub, Font=Enum.Font.Gotham,
    TextSize=13, TextXAlignment=Enum.TextXAlignment.Left, Parent=TabConfig.Content})

section(TabConfig.Content, "INFO")
label(TabConfig.Content,
    "Venice Hub v" .. HUB_VER .. "  ·  PlaceId " .. tostring(game.PlaceId)
    .. "\nBotao flutuante 'V' ou tecla " .. Flags.Keybind .. " abre/fecha o painel.", 44)

--=====================================================================
-- 12. LOOPS
--=====================================================================
task.spawn(function()
    while Screen.Parent do
        pcall(stealCycle)
        task.wait(Flags.Humanize and (0.06 + math.random() * 0.08) or 0.05)
    end
end)

task.spawn(function()
    while Screen.Parent do
        task.wait(1.2)
        if Flags.AutoPlace then pcall(placeEggs) end
        if Flags.AutoHatch then pcall(hatchEggs) end
        if Flags.AutoEquipBest then pcall(equipBest) end
        if Flags.AutoSellPets or Flags.AutoSellEggs then pcall(sellStuff) end
        if Flags.AutoUpgradeBase or Flags.AutoUpgradeTreadmill then pcall(upgradeStuff) end
        if Flags.AutoClaim then pcall(claimStuff) end
    end
end)

task.spawn(function()
    while Screen.Parent do
        pcall(scanWorld)
        task.wait(0.7)
    end
end)

local lastT, frames, acc = os.clock(), 0, 0
task.spawn(function()
    while Screen.Parent do
        task.wait(0.4)
        pcall(updateESP)
        frames = frames + 1
        local now = os.clock()
        if now - lastT >= 1 then
            local fps = math.floor(frames / (now - lastT))
            frames, lastT = 0, now
            local ping = 0
            pcall(function()
                ping = math.floor(
                    Stats.Network.ServerStatsItem["Data Ping"]:GetValue())
            end)
            local plot = getOwnPlot()
            S_FPS.Text   = "FPS: " .. fps
            S_PING.Text  = "Ping: " .. ping .. " ms"
            S_INFO.Text  = "Ovos visiveis: " .. Flags.Found
                .. "  (falhas: " .. Flags.Failed .. ")"
            S_STEAL.Text = "Roubados: " .. Flags.Steals
            S_UP.Text    = "Uptime: " .. math.floor(os.clock() - Flags.StartTime) .. "s"
            S_PLOT.Text  = "Plot: " .. (plot and plot.Name or "nao encontrado")
            S_STAT.Text  = "Status: " .. (Flags.AutoSteal
                and (Move.Active and "movendo" or "procurando") or "parado")
        end
    end
end)

--=====================================================================
-- 13. HOOKS
--=====================================================================
setupAntiBan()

bind(RunService.Heartbeat, function(dt)
    pcall(maintenance)
    pcall(updateFly, dt)
    acc = acc + dt
    if acc >= 0.5 then
        acc = 0
        pcall(applyVisuals)
    end
end)

bind(UIS.JumpRequest, function()
    if not Flags.InfJump then return end
    local hrp = getHRP()
    if hrp then
        pcall(function()
            hrp.AssemblyLinearVelocity = Vector3.new(
                hrp.AssemblyLinearVelocity.X, 55, hrp.AssemblyLinearVelocity.Z)
        end)
    end
end)

task.spawn(function()
    while Screen.Parent do
        task.wait(1)
        if Flags.Stealth and Flags.MoveSpeed > 250 then Flags.MoveSpeed = 250 end
    end
end)

--=====================================================================
-- 14. UNLOAD
--=====================================================================
GENV.VENICE_SAE_UNLOAD = function()
    for _, c in ipairs(CONN) do pcall(function() c:Disconnect() end) end
    clearESP()
    if ESPFolder then pcall(function() ESPFolder:Destroy() end) end
    if Screen then pcall(function() Screen:Destroy() end) end
    GENV.VENICE_SAE_LOADED = false
end
GENV.VENICE_SAE_LOADED = true

task.wait(0.4)
notify("VENICE HUB v" .. HUB_VER,
    "Carregado! Botao 'V' ou tecla " .. Flags.Keybind .. " abre o painel.", 5)
print("[Venice Hub] v" .. HUB_VER .. " carregado em " .. tostring(game.PlaceId))
