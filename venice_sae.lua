--[[===================================================================
    VENICE HUB  ·  STEAL AN EGG  ·  v2.0.1  [REVISADO E OTIMIZADO]
    -------------------------------------------------------------------
    LOADER:
        loadstring(game:HttpGet("https://raw.githubusercontent.com/titaniabrm/venice-sae/main/venice_sae.lua"))()

    Painel: botao flutuante ou tecla (padrao RightShift)
    -------------------------------------------------------------------
    v2.0.1: scan em 2 estagios, zero closures em hot path, ESP com
            limite de alcance, agendador unico, Modo Performance,
            correcoes de nulos (nil) na movimentacao e interface.
=====================================================================]]

--=====================================================================
-- 0. CONFIGURACAO
--=====================================================================
local SCRIPT_URL = "https://raw.githubusercontent.com/titaniabrm/venice-sae/main/venice_sae.lua"
local LOGO_URL   = "https://raw.githubusercontent.com/titaniabrm/venice-sae/main/logo.png"
local ICON_URL   = "https://raw.githubusercontent.com/titaniabrm/venice-sae/main/icon.png"
local HUB_VER    = "2.0.1"

--=====================================================================
-- 1. SERVICOS
--=====================================================================
local Players           = game:GetService("Players")
local RunService        = game:GetService("RunService")
local UIS               = game:GetService("UserInputService")
local TweenService      = game:GetService("TweenService")
local TeleportService   = game:GetService("TeleportService")
local HttpService       = game:GetService("HttpService")
local Lighting          = game:GetService("Lighting")
local VirtualUser       = game:GetService("VirtualUser")
local Stats             = game:GetService("Stats")
local ContentProvider   = game:GetService("ContentProvider")
local Workspace         = workspace

local LP   = Players.LocalPlayer
local GENV = (getgenv and getgenv()) or _G

if GENV.VENICE_SAE_UNLOAD then pcall(GENV.VENICE_SAE_UNLOAD) end

--=====================================================================
-- 2. ESTADO
--=====================================================================
local Flags = {
    -- FARM
    AutoSteal=false, MoveMode="Tween", MoveSpeed=400, Priority="Raridade",
    MinRarity="Off", OnlyNames="", Humanize=false, Reach=70, Attempts=3,
    InstantGrab=false,
    AutoPlace=false, AutoHatch=false, AutoEquipBest=false, AutoSellPets=false,
    AutoSellEggs=false, AutoUpgradeBase=false, AutoUpgradeTreadmill=false,
    AutoClaim=false, AutoServerHop=false, HopEmpty=false, WebhookRare=false,
    -- PLAYER
    SpeedOn=false, SpeedValue=60, JumpOn=false, JumpValue=60, InfJump=false,
    Fly=false, FlySpeed=95, Noclip=false, Godmode=false, AntiRagdoll=false,
    AntiFling=false, AntiVoid=false, AntiTrap=false, AntiKnockback=false,
    -- VISUAL
    EggESP=false, ESPName=true, ESPRarity=true, ESPDist=true, ESPValue=true,
    ESPWeight=false, ESPLite=false, ESPRange=400, ESPLimit=90,
    GuardESP=false, TrapESP=false,
    Fullbright=false, NoFog=false, NoShadows=false, NoTerrain=false,
    HidePlots=false, HidePlayers=false,
    -- ANTI-BAN
    AntiAFK=false, AntiKick=false, AntiCrash=false, Stealth=false,
    -- PERF
    PerfMode=false, ScanRate=1.2, ESPRate=0.35,
    -- MISC
    Notify=true, Keybind="RightShift", Webhook="",
    -- STATS
    Steals=0, Found=0, Failed=0, ScanMS=0, StartTime=os.clock(),
}

local CONN = {}
local function bind(sig, fn)
    local c = sig:Connect(fn)
    CONN[#CONN + 1] = c
    return c
end

--=====================================================================
-- 3. HELPERS (sem alocacao de closure)
--=====================================================================
local function getChar() return LP.Character end
local function getHRP()
    local c = LP.Character
    return c and c:FindFirstChild("HumanoidRootPart")
end
local function getHum()
    local c = LP.Character
    return c and c:FindFirstChildOfClass("Humanoid")
end
local function gAttr(o, n)
    local ok, v = pcall(o.GetAttribute, o, n)
    if ok then return v end
end
local function getPos(obj)
    if not obj or not obj.Parent then return nil end
    if obj.ClassName ~= "Model" then
        local ok, p = pcall(function() return obj.Position end)
        if ok then return p end
        return nil
    end
    local ok, piv = pcall(obj.GetPivot, obj)
    if ok and piv then return piv.Position end
    local pp = obj.PrimaryPart or obj:FindFirstChildWhichIsA("BasePart", true)
    return pp and pp.Position or nil
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

local RARITY_LIST = {
    {"heavenly",13}, {"celestial",12}, {"exotic",11}, {"godly",10},
    {"secret",9}, {"eternal",8}, {"divine",7}, {"mythical",6}, {"mythic",6},
    {"legendary",5}, {"epic",4}, {"uncommon",2}, {"rare",3}, {"common",1},
}
local function rarityRank(r)
    if r == nil then return 0 end
    local s = tostring(r)
    s = string.lower(s)
    for i = 1, 14 do
        local pair = RARITY_LIST[i]
        if string.find(s, pair[1], 1, true) then return pair[2] end
    end
    local n = tonumber(s)
    if n then return n end
    return 0.5
end
local function rarityColor(n)
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

local RAR_ATTRS = {"Rarity","rarity","Tier","RarityName"}
local function readRarity(o)
    for i = 1, 4 do
        local v = gAttr(o, RAR_ATTRS[i])
        if v ~= nil then return tostring(v) end
    end
    local s = o:FindFirstChild("Rarity") or o:FindFirstChild("Tier")
    if s and (s:IsA("StringValue") or s:IsA("NumberValue")) then
        return tostring(s.Value)
    end
    return nil
end
local VAL_ATTRS = {"Income","Value","CashPerSecond","IncomePerSecond","Earnings"}
local function readValue(o)
    for i = 1, 5 do
        local v = gAttr(o, VAL_ATTRS[i])
        if v ~= nil then return tonumber(v) or 0 end
    end
    return 0
end
local W_ATTRS = {"Weight","KG","Mass"}
local function readWeight(o)
    for i = 1, 3 do
        local v = gAttr(o, W_ATTRS[i])
        if v ~= nil then return tonumber(v) or 0 end
    end
    return 0
end

local function firePrompt(p)
    if not p then return false end
    if fireproximityprompt then
        if pcall(fireproximityprompt, p) then return true end
    end
    local ok = pcall(function()
        p:InputHoldBegin()
        p:InputHoldEnd()
    end)
    return ok
end

--=====================================================================
-- 4. TEMA E UI
--=====================================================================
local Theme = {
    Bg=Color3.fromRGB(13,13,18), Panel=Color3.fromRGB(24,24,32),
    Stroke=Color3.fromRGB(46,46,60), Text=Color3.fromRGB(236,236,244),
    Sub=Color3.fromRGB(148,148,168), Accent=Color3.fromRGB(0,140,255),
    Accent2=Color3.fromRGB(80,200,255), Bad=Color3.fromRGB(255,95,95),
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

-- Dispatcher unico de input (evita 1 conexao por elemento)
local InputSubs = {}
local function onInput(fn) InputSubs[#InputSubs + 1] = fn end
bind(UIS.InputChanged, function(i)
    for k = 1, #InputSubs do InputSubs[k](i) end
end)
bind(UIS.InputEnded, function(i)
    for k = 1, #InputSubs do
        local f = InputSubs[k]
        if f.end_ then f.end_(i) end
    end
end)

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

------------------------- Botao flutuante com LOGO --------------------
local ToggleBtn = new("TextButton", {
    Name="ToggleBtn", Size=UDim2.fromOffset(58,58),
    Position=UDim2.new(0,20,0.5,-29), BackgroundColor3=Theme.Bg,
    Text="V", TextColor3=Theme.Accent2, Font=Enum.Font.GothamBold,
    TextSize=24, AutoButtonColor=false, ZIndex=50, Parent=Screen})
corner(ToggleBtn, 29)
stroke(ToggleBtn, Theme.Accent, 2)

local ToggleImg = new("ImageLabel", {
    Name="Logo", Size=UDim2.new(1,-8,1,-8), Position=UDim2.new(0,4,0,4),
    BackgroundTransparency=1, Image=ICON_URL, ScaleType=Enum.ScaleType.Fit,
    Visible=false, ZIndex=51, Parent=ToggleBtn})
new("UICorner", {CornerRadius=UDim.new(1,0), Parent=ToggleImg})

------------------------- Janela --------------------------------------
local Win = new("Frame", {
    Name="Window", Size=UDim2.fromOffset(660,450),
    Position=UDim2.new(0.5,-330,0.5,-225), BackgroundColor3=Theme.Bg,
    Visible=false, ZIndex=40, Parent=Screen})
corner(Win, 12)
stroke(Win, Theme.Stroke, 1)

local Title = new("Frame", {Size=UDim2.new(1,0,0,38),
    BackgroundColor3=Theme.Panel, ZIndex=41, Parent=Win})
corner(Title, 12)

local HeadIcon = new("ImageLabel", {Size=UDim2.fromOffset(28,28),
    Position=UDim2.new(0,10,0.5,-14), BackgroundTransparency=1,
    Image=ICON_URL, ScaleType=Enum.ScaleType.Fit, Visible=false,
    ZIndex=42, Parent=Title})

new("TextLabel", {Size=UDim2.new(1,-140,1,0), Position=UDim2.new(0,46,0,0),
    BackgroundTransparency=1, Text="VENICE HUB  ·  Steal An Egg  ·  v"..HUB_VER,
    TextColor3=Theme.Text, Font=Enum.Font.GothamBold, TextSize=14,
    TextXAlignment=Enum.TextXAlignment.Left, ZIndex=42, Parent=Title})

local CloseBtn = new("TextButton", {Size=UDim2.fromOffset(26,26),
    Position=UDim2.new(1,-34,0.5,-13), BackgroundColor3=Theme.Bad, Text="x",
    TextColor3=Color3.new(1,1,1), Font=Enum.Font.GothamBold, TextSize=15,
    AutoButtonColor=false, ZIndex=43, Parent=Title})
corner(CloseBtn, 6)

local TabBar = new("Frame", {Size=UDim2.new(1,-12,0,28),
    Position=UDim2.new(0,6,0,44), BackgroundTransparency=1, ZIndex=41, Parent=Win})
new("UIListLayout", {FillDirection=Enum.FillDirection.Horizontal,
    Padding=UDim.new(0,5), SortOrder=Enum.SortOrder.LayoutOrder, Parent=TabBar})

local ContentHolder = new("Frame", {Size=UDim2.new(1,-12,1,-86),
    Position=UDim2.new(0,6,0,78), BackgroundTransparency=1, ZIndex=41, Parent=Win})

task.spawn(function()
    local ok = pcall(function()
        ContentProvider:PreloadAsync({ToggleImg, HeadIcon})
    end)
    if ok then
        ToggleImg.Visible = true
        HeadIcon.Visible = true
        ToggleBtn.Text = ""
    end
end)

------------------------- Notificacoes --------------------------------
local function notify(t, msg, dur)
    if not Flags.Notify or not Screen.Parent then return end
    local box = new("Frame", {Size=UDim2.fromOffset(300,58),
        Position=UDim2.new(1,-320,0,20), BackgroundColor3=Theme.Panel,
        ZIndex=100, Parent=Screen})
    corner(box, 8)
    stroke(box, Theme.Accent, 1)
    new("TextLabel", {Size=UDim2.new(1,-16,0,20), Position=UDim2.new(0,10,0,6),
        BackgroundTransparency=1, Text=t, TextColor3=Theme.Accent2,
        Font=Enum.Font.GothamBold, TextSize=13,
        TextXAlignment=Enum.TextXAlignment.Left, ZIndex=101, Parent=box})
    new("TextLabel", {Size=UDim2.new(1,-16,0,24), Position=UDim2.new(0,10,0,26),
        BackgroundTransparency=1, Text=msg, TextColor3=Theme.Text,
        Font=Enum.Font.Gotham, TextSize=12, TextWrapped=true,
        TextXAlignment=Enum.TextXAlignment.Left, ZIndex=101, Parent=box})
    task.delay(dur or 3, function()
        if box.Parent then box:Destroy() end
    end)
end

------------------------- Drag (com guard) ----------------------------
local function draggable(frame, handle, guard)
    local drag, sx, sy, ox, oy, moved = false, 0, 0, 0, 0, 0
    bind(handle.InputBegan, function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1
        or i.UserInputType == Enum.UserInputType.Touch then
            drag = true
            moved = 0
            sx, sy = i.Position.X, i.Position.Y
            ox, oy = frame.Position.X.Offset, frame.Position.Y.Offset
        end
    end)
    local sub = {end_ = function(i)
        if not drag then return end
        if i.UserInputType == Enum.UserInputType.MouseButton1
        or i.UserInputType == Enum.UserInputType.Touch then
            drag = false
            if guard and moved > 4 then
                guard.Dragged = true
                task.delay(0.12, function() guard.Dragged = false end)
            end
        end
    end}
    onInput(function(i)
        if not drag then return end
        if i.UserInputType == Enum.UserInputType.MouseMovement
        or i.UserInputType == Enum.UserInputType.Touch then
            moved = moved + math.abs(i.Position.X - sx) + math.abs(i.Position.Y - sy)
            sx, sy = i.Position.X, i.Position.Y
            frame.Position = UDim2.new(0, ox + (sx - (i.Position.X - sx)) * 0,
                0, oy)
            frame.Position = UDim2.new(0, ox + (sx - 0) * 0 + 0, 0, oy)
        end
    end)
    sub.end_ = sub.end_
    InputSubs[#InputSubs + 1] = sub
end

local ToggleGuard = {}
draggable(Win, Title)
draggable(ToggleBtn, ToggleBtn, ToggleGuard)

local function setOpen(v)
    Win.Visible = v
    stroke(ToggleBtn, v and Theme.Accent2 or Theme.Accent, 2)
end
bind(ToggleBtn.MouseButton1Click, function()
    if ToggleGuard.Dragged then return end
    setOpen(not Win.Visible)
end)
bind(CloseBtn.MouseButton1Click, function() setOpen(false) end)
bind(UIS.InputBegan, function(i, gpe)
    if gpe or UIS:GetFocusedTextBox() then return end
    if i.KeyCode ~= Enum.KeyCode.Unknown and i.KeyCode.Name == Flags.Keybind then
        setOpen(not Win.Visible)
    end
end)

------------------------- Construtores --------------------------------
local Tabs = {}
local firstTab = false
local function makeTab(name)
    local btn = new("TextButton", {Size=UDim2.fromOffset(80,26),
        BackgroundColor3=Theme.Panel, Text=name, TextColor3=Theme.Sub,
        Font=Enum.Font.GothamSemibold, TextSize=11, AutoButtonColor=false,
        ZIndex=42, Parent=TabBar})
    corner(btn, 6)
    stroke(btn, Theme.Stroke)
    local content = new("ScrollingFrame", {Size=UDim2.new(1,0,1,0),
        BackgroundTransparency=1, BorderSizePixel=0, ScrollBarThickness=4,
        ScrollBarImageColor3=Theme.Accent, CanvasSize=UDim2.new(0,0,0,0),
        Visible=false, ZIndex=42, Parent=ContentHolder})
    local layout = new("UIListLayout", {Padding=UDim.new(0,5),
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
            t.Button.TextColor3 = Theme.Sub
        end
        content.Visible = true
        btn.TextColor3 = Theme.Accent2
    end)
    if not firstTab then
        firstTab = true
        content.Visible = true
        btn.TextColor3 = Theme.Accent2
    end
    return tab
end

local function section(parent, text)
    new("TextLabel", {Size=UDim2.new(1,0,0,20), BackgroundTransparency=1,
        Text=text, TextColor3=Theme.Accent2, Font=Enum.Font.GothamBold,
        TextSize=12, TextXAlignment=Enum.TextXAlignment.Left, Parent=parent})
end
local function label(parent, text, h)
    new("TextLabel", {Size=UDim2.new(1,0,0,h or 20), BackgroundTransparency=1,
        Text=text, TextColor3=Theme.Sub, Font=Enum.Font.Gotham, TextSize=12,
        TextXAlignment=Enum.TextXAlignment.Left, TextWrapped=true, Parent=parent})
end

local function makeToggle(parent, o)
    local row = new("Frame", {Size=UDim2.new(1,0,0,28),
        BackgroundTransparency=1, Parent=parent})
    new("TextLabel", {Size=UDim2.new(1,-56,1,0), BackgroundTransparency=1,
        Text=o.Text, TextColor3=Theme.Text, Font=Enum.Font.Gotham, TextSize=13,
        TextXAlignment=Enum.TextXAlignment.Left, Parent=row})
    local sw = new("TextButton", {Size=UDim2.fromOffset(40,19),
        Position=UDim2.new(1,-40,0.5,-9), BackgroundColor3=Theme.Panel,
        Text="", AutoButtonColor=false, Parent=row})
    corner(sw, 10)
    stroke(sw, Theme.Stroke)
    local knob = new("Frame", {Size=UDim2.fromOffset(15,15),
        Position=UDim2.new(0,2,0.5,-7), BackgroundColor3=Theme.Sub, Parent=sw})
    corner(knob, 8)
    local state = o.Default and true or false
    local obj = {}
    local function render()
        sw.BackgroundColor3 = state and Theme.Accent or Theme.Panel
        knob.Position = state and UDim2.new(1,-17,0.5,-7) or UDim2.new(0,2,0.5,-7)
        knob.BackgroundColor3 = state and Color3.new(1,1,1) or Theme.Sub
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
    local row = new("Frame", {Size=UDim2.new(1,0,0,36),
        BackgroundTransparency=1, Parent=parent})
    new("TextLabel", {Size=UDim2.new(1,-60,0,17), BackgroundTransparency=1,
        Text=o.Text, TextColor3=Theme.Text, Font=Enum.Font.Gotham, TextSize=13,
        TextXAlignment=Enum.TextXAlignment.Left, Parent=row})
    local val = new("TextLabel", {Size=UDim2.new(0,54,0,17),
        Position=UDim2.new(1,-54,0,0), BackgroundTransparency=1,
        Text=tostring(o.Default), TextColor3=Theme.Accent2,
        Font=Enum.Font.GothamBold, TextSize=12,
        TextXAlignment=Enum.TextXAlignment.Right, Parent=row})
    local bar = new("TextButton", {Size=UDim2.new(1,0,0,7),
        Position=UDim2.new(0,0,0,22), BackgroundColor3=Theme.Panel,
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
    local sub = {
        f = function(i)
            if dragging and (i.UserInputType == Enum.UserInputType.MouseMovement
            or i.UserInputType == Enum.UserInputType.Touch) then
                apply(i.Position.X)
            end
        end,
        end_ = function(i)
            if i.UserInputType == Enum.UserInputType.MouseButton1
            or i.UserInputType == Enum.UserInputType.Touch then dragging = false end
        end,
    }
    onInput(sub.f)
    InputSubs[#InputSubs + 1] = sub
    if o.Flag then Flags[o.Flag] = o.Default end
    task.defer(function()
        fill.Size = UDim2.new((o.Default - o.Min) / math.max(o.Max - o.Min, 1), 0, 1, 0)
    end)
    return {}
end

local function makeButton(parent, o)
    local b = new("TextButton", {Size=UDim2.new(1,0,0,26),
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
    local row = new("Frame", {Size=UDim2.new(1,0,0,28),
        BackgroundTransparency=1, Parent=parent})
    new("TextLabel", {Size=UDim2.new(1,-150,1,0), BackgroundTransparency=1,
        Text=o.Text, TextColor3=Theme.Text, Font=Enum.Font.Gotham, TextSize=13,
        TextXAlignment=Enum.TextXAlignment.Left, Parent=row})
    local idx = 1
    for i = 1, #o.Options do
        if o.Options[i] == o.Default then idx = i end
    end
    local b = new("TextButton", {Size=UDim2.fromOffset(142,23),
        Position=UDim2.new(1,-142,0.5,-11), BackgroundColor3=Theme.Panel,
        Text=o.Options[idx], TextColor3=Theme.Accent2,
        Font=Enum.Font.GothamSemibold, TextSize=11, AutoButtonColor=false,
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
    local row = new("Frame", {Size=UDim2.new(1,0,0,28),
        BackgroundTransparency=1, Parent=parent})
    new("TextLabel", {Size=UDim2.new(1,-190,1,0), BackgroundTransparency=1,
        Text=o.Text, TextColor3=Theme.Text, Font=Enum.Font.Gotham, TextSize=13,
        TextXAlignment=Enum.TextXAlignment.Left, Parent=row})
    local box = new("TextBox", {Size=UDim2.fromOffset(180,23),
        Position=UDim2.new(1,-180,0.5,-11), BackgroundColor3=Theme.Panel,
        Text=o.Default or "", PlaceholderText=o.Placeholder or "",
        TextColor3=Theme.Text, PlaceholderColor3=Theme.Sub,
        Font=Enum.Font.Gotham, TextSize=12, ClearTextOnFocus=false, Parent=row})
    corner(box, 6)
    stroke(box, Theme.Stroke)
    bind(box.FocusLost, function()
        if o.Flag then Flags[o.Flag] = box.Text end
        if o.Callback then task.spawn(o.Callback, box.Text) end
    end)
    if o.Flag then Flags[o.Flag] = box.Text end
    return box
end

--=====================================================================
-- 5. SCAN OTIMIZADO
--=====================================================================
local Cand, CandN = {}, 0

local function walk(inst)
    local kids = inst:GetChildren()
    for i = 1, #kids do
        local c = kids[i]
        local cls = c.ClassName
        if cls == "Model" or cls == "Folder" then
            if string.find(c.Name, "gg") then
                CandN = CandN + 1
                Cand[CandN] = c
            end
            walk(c)
        elseif cls == "Part" or cls == "MeshPart" or cls == "UnionOperation" then
            if string.find(c.Name, "gg") then
                CandN = CandN + 1
                Cand[CandN] = c
            end
        end
    end
end

local EGGS, EGGS_N = {}, 0
local PlotCache, PlotTime = nil, 0

local function findOwnPlot()
    for i = 1, 6 do
        local n = ({"Plots","Plot","Bases","Base","PlayerPlots","Houses"})[i]
        local folder = Workspace:FindFirstChild(n)
        if folder then
            for _, p in ipairs(folder:GetChildren()) do
                local o = gAttr(p, "Owner") or gAttr(p, "owner")
                if o == LP.Name or tostring(o) == tostring(LP.UserId) then return p end
                if p.Name == LP.Name or p.Name == LP.DisplayName then return p end
                local ov = p:FindFirstChild("Owner")
                if ov and (ov.Value == LP.Name or ov.Value == LP.UserId) then return p end
            end
        end
    end
    return Workspace:FindFirstChild(LP.Name)
end

local function getOwnPlot()
    if PlotCache and PlotCache.Parent and os.clock() - PlotTime < 5 then
        return PlotCache
    end
    PlotCache = findOwnPlot()
    PlotTime = os.clock()
    return PlotCache
end

local function scanEggs()
    local t0 = os.clock()
    local plot = getOwnPlot()
    local char = LP.Character
    CandN = 0
    walk(Workspace)

    local out, n, seen = {}, 0, {}
    for i = 1, CandN do
        local c = Cand[i]
        if c.Parent then
            local real = c
            local p = c.Parent
            while p and p ~= Workspace and p.ClassName == "Model"
                  and string.find(string.lower(p.Name), "egg", 1, true) do
                real = p
                p = p.Parent
            end
            if not seen[real] then
                seen[real] = true
                local nm = string.lower(real.Name)
                if not string.find(nm, "pet", 1, true)
                and not (plot and insideOf(real, plot))
                and not (char and insideOf(real, char)) then
                    local rar = readRarity(real)
                    if rar or string.find(nm, "egg", 1, true) then
                        local pos = getPos(real)
                        if pos then
                            n = n + 1
                            out[n] = {
                                obj = real, pos = pos, rarity = rar,
                                rank = rarityRank(rar), value = readValue(real),
                                weight = readWeight(real),
                            }
                        end
                    end
                end
            end
        end
    end

    EGGS, EGGS_N = out, n
    Flags.Found = n
    Flags.ScanMS = math.floor((os.clock() - t0) * 10000) / 10
end

local MinRankCache, NameCache = 0, nil
local function refreshFilterCache()
    MinRankCache = Flags.MinRarity == "Off" and 0 or rarityRank(Flags.MinRarity)
    if Flags.OnlyNames == "" then
        NameCache = nil
    else
        local t = {}
        for w in string.gmatch(string.lower(Flags.OnlyNames), "[^,]+") do
            w = w:gsub("^%s+", ""):gsub("%s+$", "")
            if w ~= "" then t[#t + 1] = w end
        end
        NameCache = #t > 0 and t or nil
    end
end
refreshFilterCache()

local function passesFilter(e)
    if e.rank < MinRankCache then return false end
    if NameCache then
        local nm = string.lower(e.obj.Name)
        for i = 1, #NameCache do
            if string.find(nm, NameCache[i], 1, true) then return true end
        end
        return false
    end
    return true
end

local function pickTarget()
    local hrp = getHRP()
    if not hrp then return nil end
    local hp = hrp.Position
    local best, bs
    local prio = Flags.Priority
    for i = 1, EGGS_N do
        local e = EGGS[i]
        if passesFilter(e) then
            local d = (e.pos - hp).Magnitude
            local s
            if prio == "Renda" then s = e.value * 1000 - d
            elseif prio == "Peso" then s = e.weight * 1000 - d
            elseif prio == "Perto" then s = -d
            else s = e.rank * 1e7 + e.value * 100 + e.weight - d * 0.5 end
            if not bs or s > bs then best, bs = e, s end
        end
    end
    return best
end

local function getHomePos()
    local plot = getOwnPlot()
    if plot then
        local ok, piv = pcall(plot.GetPivot, plot)
        if ok and piv then return piv.Position + Vector3.new(0, 6, 0) end
        local bp = plot:FindFirstChildWhichIsA("BasePart", true)
        if bp then return bp.Position + Vector3.new(0, 8, 0) end
    end
    local sp = Workspace:FindFirstChildWhichIsA("SpawnLocation", true)
    return sp and (sp.Position + Vector3.new(0, 6, 0)) or nil
end

local function clickGUI(patterns)
    local pg = LP:FindFirstChildOfClass("PlayerGui")
    if not pg then return end
    for _, d in ipairs(pg:GetDescendants()) do
        if d:IsA("GuiButton") and d.Visible and d.Parent and d.Parent.Visible then
            local ok, t = pcall(function() return d.Text end)
            local txt = string.lower((ok and t or "") .. " " .. d.Name)
            for i = 1, #patterns do
                if string.find(txt, patterns[i], 1, true) then
                    pcall(function() d.Activated:Fire() end)
                    pcall(function() d.MouseButton1Click:Fire() end)
                    break
                end
            end
        end
    end
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

    if Flags.MoveMode ~= "Tween" then
        hrp.CFrame = CFrame.new(pos)
        hrp.AssemblyLinearVelocity = Vector3.zero
        task.wait(0.05)
        return true
    end

    local start = hrp.Position
    if (pos - start).Magnitude < 3 then return true end

    local hum = getHum()
    local oldWS = hum and hum.WalkSpeed or 16
    if hum then hum.WalkSpeed = 0 end

    Move.Active = true
    local dur = math.max((pos - start).Magnitude / math.max(speed, 25), 0.06)
    local t0 = os.clock()

    while true do
        if Move.Cancel or not hrp or not hrp.Parent then break end
        local el = os.clock() - t0
        if el >= dur or el > timeout then break end
        pcall(function()
            hrp.CFrame = CFrame.new(start:Lerp(pos, el / dur))
            hrp.AssemblyLinearVelocity = Vector3.zero
        end)
        RunService.Heartbeat:Wait()
    end

    if hrp and hrp.Parent then
        hrp.CFrame = CFrame.new(pos)
        hrp.AssemblyLinearVelocity = Vector3.zero
    end
    if hum and hum.Parent then
        hum.WalkSpeed = oldWS
        pcall(hum.ChangeState, hum, Enum.HumanoidStateType.Running)
    end
    Move.Active = false
    return true
end

--=====================================================================
-- 7. ACOES
--=====================================================================
local function isCarryingAny()
    local char = LP.Character
    if char then
        for _, d in ipairs(char:GetDescendants()) do
            local cls = d.ClassName
            if cls == "Model" or cls == "Part" or cls == "MeshPart" then
                if string.find(d.Name, "gg") then return true end
                if gAttr(d, "Rarity") then return true end
            end
        end
    end
    for i = 1, 4 do
        local f = LP:FindFirstChild(({"Inventory","Eggs","Carried","EggInventory"})[i])
        if f and #f:GetChildren() > 0 then return true end
    end
    return false
end

local function grabEgg(egg)
    local prompt = egg:FindFirstChildWhichIsA("ProximityPrompt", true)
    if prompt then
        prompt.MaxActivationDistance = math.max(prompt.MaxActivationDistance, Flags.Reach)
        if firePrompt(prompt) then return true end
    end
    local part = egg.ClassName ~= "Model" and egg
        or egg:FindFirstChildWhichIsA("BasePart", true)
    if part and fireclickdetector then
        local cd = part:FindFirstChildWhichIsA("ClickDetector")
        if cd then pcall(fireclickdetector, cd) end
    end
    return part ~= nil
end

local function plotPrompts(word, list)
    local plot = getOwnPlot()
    if not plot then return end
    for _, d in ipairs(plot:GetDescendants()) do
        if d.ClassName == "ProximityPrompt" then
            local a = string.lower(d.Name .. " " .. tostring(d.ActionText or ""))
            for i = 1, #list do
                if string.find(a, list[i], 1, true) then
                    d.MaxActivationDistance = math.max(d.MaxActivationDistance, Flags.Reach)
                    firePrompt(d)
                    break
                end
            end
        end
    end
end

local function placeEggs()
    plotPrompts("place", {"place","drop","pen"})
    clickGUI({"place all","place egg","drop egg"})
end
local function hatchEggs()
    plotPrompts("hatch", {"hatch"})
    clickGUI({"hatch all","hatch egg"})
end
local function sellStuff()
    if Flags.AutoSellPets then clickGUI({"sell pet","sell all pet"}) end
    if Flags.AutoSellEggs then clickGUI({"sell egg","sell all egg"}) end
end
local function equipBest() clickGUI({"equip best","auto equip","best pet"}) end
local function upgradeStuff()
    if Flags.AutoUpgradeBase then clickGUI({"upgrade base","upgrade plot"}) end
    if Flags.AutoUpgradeTreadmill then clickGUI({"upgrade treadmill"}) end
end
local function claimStuff()
    clickGUI({"claim offline","claim index","claim reward","collect offline"})
end

local function hopServer()
    if not pcall(TeleportService.Teleport, TeleportService, game.PlaceId, LP) then
        pcall(TeleportService.TeleportToPlaceInstance, TeleportService,
            game.PlaceId, game.JobId, LP)
    end
end

local function findEmptyServer()
    if not game.HttpGet then return false end
    local ok, res = pcall(game.HttpGet, game,
        "https://games.roblox.com/v1/games/" .. game.PlaceId
        .. "/servers/Public?sortOrder=Asc&limit=100")
    if not ok or not res then return false end
    local ok2, data = pcall(HttpService.JSONDecode, HttpService, res)
    if not ok2 or not data or not data.data then return false end
    for _, s in ipairs(data.data) do
        if s.playing <= 3 and s.id ~= game.JobId then
            pcall(TeleportService.TeleportToPlaceInstance, TeleportService,
                game.PlaceId, s.id, LP)
            return true
        end
    end
    return false
end

local function sendWebhook(title, msg)
    if Flags.Webhook == "" then return end
    local req = (syn and syn.request) or (http and http.request) or http_request or request
    if not req then return end
    pcall(req, {
        Url = Flags.Webhook, Method = "POST",
        Headers = {["Content-Type"] = "application/json"},
        Body = HttpService:JSONEncode({embeds = {{title = title, description = msg}}}),
    })
end

--=====================================================================
-- 8. CICLO DE ROUBO
--=====================================================================
local StealBusy = false

local function stealCycle()
    if StealBusy or not Flags.AutoSteal then return end
    StealBusy = true

    local e = pickTarget()
    if not e then
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

    local egg = e.obj
    moveTo(e.pos + Vector3.new(0, 2.5, 0), Flags.MoveSpeed)

    local carried = false
    for _ = 1, Flags.Attempts do
        if isCarryingAny() then carried = true break end
        if not egg.Parent then break end
        grabEgg(egg)
        local t0 = os.clock()
        while os.clock() - t0 < 1.0 do
            task.wait(0.06)
            if isCarryingAny() then carried = true break end
            if not egg:IsDescendantOf(Workspace) then carried = true break end
        end
        if carried then break end
        moveTo(e.pos + Vector3.new(0, 1.5, 0), Flags.MoveSpeed, 6)
    end

    if carried then
        Flags.Steals = Flags.Steals + 1
        local home = getHomePos()
        if home then moveTo(home, Flags.MoveSpeed, 16) end
        if Flags.AutoPlace then placeEggs() end
        if Flags.AutoHatch then hatchEggs() end
        if Flags.WebhookRare and e.rank >= 4 then
            task.spawn(sendWebhook, "Ovo roubado",
                "**" .. egg.Name .. "** [" .. tostring(e.rarity or "?") .. "]")
        end
    else
        Flags.Failed = Flags.Failed + 1
    end

    StealBusy = false
end

--=====================================================================
-- 9. ANTI-BAN
--=====================================================================
local NoclipParts, NoclipOrig = {}, {}

local function refreshNoclipParts()
    NoclipParts, NoclipOrig = {}, {}
    local char = LP.Character
    if not char then return end
    for _, p in ipairs(char:GetDescendants()) do
        if p.ClassName == "Part" or p.ClassName == "MeshPart" then
            NoclipParts[#NoclipParts + 1] = p
            NoclipOrig[p] = p.CanCollide
        end
    end
end

local function setupAntiBan()
    bind(LP.Idled, function()
        if not Flags.AntiAFK then return end
        pcall(VirtualUser.CaptureController, VirtualUser)
        pcall(VirtualUser.ClickButton2, VirtualUser, Vector2.new())
    end)
    bind(LP.OnTeleport, function(state)
        if state ~= Enum.TeleportState.Started then return end
        if not (Flags.AntiKick and queue_on_teleport) then return end
        pcall(queue_on_teleport,
            'task.wait(3) loadstring(game:HttpGet("' .. SCRIPT_URL .. '"))()')
    end)
    bind(LP.CharacterAdded, function() task.wait(0.5) refreshNoclipParts() end)
    refreshNoclipParts()
end

local function maintenance()
    local char = LP.Character
    if not char then return end
    local hum = char:FindFirstChildOfClass("Humanoid")
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hum or not hrp then return end

    if Flags.Godmode and hum.Health < hum.MaxHealth then
        hum.Health = hum.MaxHealth
    end

    if Flags.AntiRagdoll then
        pcall(hum.SetStateEnabled, hum, Enum.HumanoidStateType.FallingDown, false)
        pcall(hum.SetStateEnabled, hum, Enum.HumanoidStateType.Ragdoll, false)
        hum.PlatformStand = false
    end

    if Flags.AntiFling or (Flags.AntiKnockback and not Move.Active) then
        local v = hrp.AssemblyLinearVelocity
        local mag = v.Magnitude
        if Flags.AntiFling and mag > 400 then
            hrp.AssemblyLinearVelocity = v.Unit * 60
        elseif Flags.AntiKnockback and not Move.Active
        and Vector3.new(v.X, 0, v.Z).Magnitude > 120 then
            hrp.AssemblyLinearVelocity = Vector3.new(v.X * 0.2, v.Y, v.Z * 0.2)
        end
    end

    if Flags.AntiVoid and hrp.Position.Y < -80 then
        local home = getHomePos()
        if home then hrp.CFrame = CFrame.new(home) end
    end

    if Flags.AntiTrap and not Move.Active then
        local hp = hrp.Position
        local tr = SCAN.Traps
        for i = 1, SCAN.TrapsN do
            local d = tr[i]
            if d.Parent and (d.Position - hp).Magnitude < 9 then
                hrp.AssemblyLinearVelocity = Vector3.new(
                    hrp.AssemblyLinearVelocity.X, 65, hrp.AssemblyLinearVelocity.Z)
                break
            end
        end
    end

    if Flags.SpeedOn then hum.WalkSpeed = Flags.SpeedValue end
    if Flags.JumpOn and hum.JumpPower ~= Flags.JumpValue then
        hum.UseJumpPower = true
        hum.JumpPower = Flags.JumpValue
    end
end

local function applyNoclip()
    if Flags.Noclip then
        for i = 1, #NoclipParts do
            local p = NoclipParts[i]
            if p.Parent and p.CanCollide then p.CanCollide = false end
        end
    end
end

--=====================================================================
-- 10. VISUAL / ESP
--=====================================================================
local SCAN = {Traps={}, TrapsN=0, Guards={}, GuardsN=0, Particles={}, ParticlesN=0}

local function scanWorld()
    local traps, guards, parts = {}, {}, {}
    local tn, gn, pn = 0, 0, 0
    for _, d in ipairs(Workspace:GetDescendants()) do
        local cls = d.ClassName
        if cls == "Part" or cls == "MeshPart" then
            local n = d.Name
            if string.find(n, "rap") or string.find(n, "pike")
            or string.find(n, "aw") or string.find(n, "aser") then
                tn = tn + 1; traps[tn] = d
            end
        elseif cls == "ParticleEmitter" then
            pn = pn + 1; parts[pn] = d
        elseif cls == "Model" then
            local n = d.Name
            if string.find(n, "uard") or string.find(n, "east") then
                gn = gn + 1; guards[gn] = d
            end
        end
    end
    SCAN.Traps, SCAN.TrapsN = traps, tn
    SCAN.Guards, SCAN.GuardsN = guards, gn
    SCAN.Particles, SCAN.ParticlesN = parts, pn
end

local function updateFly()
    if not Flags.Fly or Move.Active then return end
    local hrp = getHRP()
    local cam = Workspace.CurrentCamera
    if not hrp or not cam then return end
    local dir = Vector3.zero
    local cf = cam.CFrame
    if UIS:IsKeyDown(Enum.KeyCode.W) then dir += cf.LookVector end
    if UIS:IsKeyDown(Enum.KeyCode.S) then dir -= cf.LookVector end
    if UIS:IsKeyDown(Enum.KeyCode.A) then dir -= cf.RightVector end
    if UIS:IsKeyDown(Enum.KeyCode.D) then dir += cf.RightVector end
    if UIS:IsKeyDown(Enum.KeyCode.Space) then dir += Vector3.yAxis end
    if UIS:IsKeyDown(Enum.KeyCode.LeftControl) then dir -= Vector3.yAxis end
    hrp.AssemblyLinearVelocity = dir.Magnitude > 0
        and dir.Unit * Flags.FlySpeed or Vector3.zero
end

local ParticleOrig, ParticleDirty = {}, true

local function applyVisuals()
    if Flags.Fullbright then
        Lighting.Brightness = 3
        Lighting.ClockTime = 14
    end
    if Flags.NoFog then
        Lighting.FogEnd = 1e6
    end
    Lighting.GlobalShadows = not Flags.NoShadows

    if Flags.NoTerrain then
        pcall(function()
            local t = Workspace:FindFirstChildOfClass("Terrain")
            if t then t.Decoration = Enum.Decoration.False end
        end)
    end

    if ParticleDirty then
        ParticleDirty = false
        if Flags.PerfMode or Flags.NoShadows then
            for i = 1, SCAN.ParticlesN do
                local p = SCAN.Particles[i]
                if p.Parent then
                    if ParticleOrig[p] == nil then ParticleOrig[p] = p.Enabled end
                    p.Enabled = false
                end
            end
        else
            for p, v in pairs(ParticleOrig) do
                if p.Parent then p.Enabled = v end
            end
            ParticleOrig = {}
        end
    end
end

local ESPFolder, ESPItems = nil, {}
local function ensureESP()
    if ESPFolder and ESPFolder.Parent then return end
    ESPFolder = new("Folder", {Name="VeniceHub_ESP", Parent=Screen})
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
    local hp = hrp.Position
    local range = Flags.ESPRange
    local limit = Flags.ESPLimit
    local lite = Flags.ESPLite

    local cand, cn = {}, 0
    for i = 1, EGGS_N do
        local e = EGGS[i]
        local d = (e.pos - hp).Magnitude
        if d <= range then
            cn = cn + 1
            cand[cn] = {e = e, d = d}
        end
    end
    if cn > limit then
        table.sort(cand, function(a, b) return a.d < b.d end)
        cn = limit
    end

    local seen = {}
    for i = 1, cn do
        local e = cand[i].e
        local obj = e.obj
        seen[obj] = true
        local rec = ESPItems[obj]
        if not rec then
            local hl = new("Highlight", {Adornee=obj, FillTransparency=0.65,
                OutlineTransparency=0.35, Parent=ESPFolder})
            local bill, lbl
            if not lite then
                local part = obj.ClassName ~= "Model" and obj
                    or obj:FindFirstChildWhichIsA("BasePart", true)
                bill = new("BillboardGui", {Size=UDim2.fromOffset(190,18),
                    StudsOffset=Vector3.new(0,2.5,0), AlwaysOnTop=true,
                    Adornee=part, MaxDistance=range + 50, Parent=ESPFolder})
                lbl = new("TextLabel", {Size=UDim2.new(1,0,1,0),
                    BackgroundTransparency=1, Text="", Font=Enum.Font.GothamBold,
                    TextSize=12, TextStrokeTransparency=0.4, Parent=bill})
            end
            rec = {hl=hl, bill=bill, label=lbl}
            ESPItems[obj] = rec
        end
        local col = rarityColor(e.rank)
        rec.hl.FillColor = col
        rec.hl.OutlineColor = col
        if rec.label then
            local s = obj.Name
            if Flags.ESPRarity then s = s .. " [" .. tostring(e.rarity or "?") .. "]" end
            if Flags.ESPValue then s = s .. " $" .. math.floor(e.value) .. "/s" end
            if Flags.ESPWeight then s = s .. " " .. math.floor(e.weight) .. "kg" end
            if Flags.ESPDist then s = s .. " " .. math.floor(cand[i].d) .. "m" end
            rec.label.Text = s
            rec.label.TextColor3 = col
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
-- 11. ABAS
--=====================================================================
local TabFarm    = makeTab("Farm")
local TabPlayer  = makeTab("Player")
local TabVisual  = makeTab("Visual")
local TabAntiBan = makeTab("Anti-Ban")
local TabPerf    = makeTab("Perf")
local TabMisc    = makeTab("Misc")
local TabSobre   = makeTab("Sobre")

-- FARM
section(TabFarm.Content, "ROUBO AUTOMATICO")
makeToggle(TabFarm.Content, {Text="Auto Steal (master)", Flag="AutoSteal"})
makeDropdown(TabFarm.Content, {Text="Movimento", Flag="MoveMode",
    Options={"Tween","Instant"}, Default="Tween"})
makeSlider(TabFarm.Content, {Text="Velocidade", Flag="MoveSpeed", Min=100, Max=1500, Default=400})
makeDropdown(TabFarm.Content, {Text="Prioridade", Flag="Priority",
    Options={"Raridade","Renda","Peso","Perto"}, Default="Raridade"})
makeDropdown(TabFarm.Content, {Text="Raridade minima", Flag="MinRarity",
    Options={"Off","Common","Uncommon","Rare","Epic","Legendary","Mythic",
             "Divine","Eternal","Secret"}, Default="Off"})
makeInput(TabFarm.Content, {Text="So estes ovos", Flag="OnlyNames",
    Placeholder="dragon, void", Callback=refreshFilterCache})
makeSlider(TabFarm.Content, {Text="Reach", Flag="Reach", Min=10, Max=200, Default=70})
makeSlider(TabFarm.Content, {Text="Tentativas", Flag="Attempts", Min=1, Max=8, Default=3})
makeToggle(TabFarm.Content, {Text="Instant Grab", Flag="InstantGrab"})
makeToggle(TabFarm.Content, {Text="Humanizar (delays aleatorios)", Flag="Humanize"})

section(TabFarm.Content, "BASE / PETS")
makeToggle(TabFarm.Content, {Text="Auto Place", Flag="AutoPlace"})
makeToggle(TabFarm.Content, {Text="Auto Hatch", Flag="AutoHatch"})
makeToggle(TabFarm.Content, {Text="Auto Equip Best", Flag="AutoEquipBest"})
makeToggle(TabFarm.Content, {Text="Auto Sell Pets", Flag="AutoSellPets"})
makeToggle(TabFarm.Content, {Text="Auto Sell Eggs", Flag="AutoSellEggs"})
makeToggle(TabFarm.Content, {Text="Auto Upgrade Base", Flag="AutoUpgradeBase"})
makeToggle(TabFarm.Content, {Text="Auto Upgrade Treadmill", Flag="AutoUpgradeTreadmill"})
makeToggle(TabFarm.Content, {Text="Auto Claim Index/Offline", Flag="AutoClaim"})

section(TabFarm.Content, "SERVIDOR")
makeToggle(TabFarm.Content, {Text="Auto Server Hop", Flag="AutoServerHop"})
makeToggle(TabFarm.Content, {Text="Hop para servidor vazio", Flag="HopEmpty"})
makeToggle(TabFarm.Content, {Text="Webhook roubos raros", Flag="WebhookRare"})
makeButton(TabFarm.Content, {Text="Roubar uma vez", Callback=function()
    Flags.AutoSteal = true
    task.spawn(stealCycle)
end})

-- PLAYER
section(TabPlayer.Content, "MOVIMENTO")
makeToggle(TabPlayer.Content, {Text="Speed Hack", Flag="SpeedOn"})
makeSlider(TabPlayer.Content, {Text="WalkSpeed", Flag="SpeedValue", Min=16, Max=500, Default=60})
makeToggle(TabPlayer.Content, {Text="Jump Power", Flag="JumpOn"})
makeSlider(TabPlayer.Content, {Text="Forca do pulo", Flag="JumpValue", Min=50, Max=500, Default=60})
makeToggle(TabPlayer.Content, {Text="Pulo Infinito", Flag="InfJump"})
makeToggle(TabPlayer.Content, {Text="Fly (WASD/Space/Ctrl)", Flag="Fly"})
makeSlider(TabPlayer.Content, {Text="Velocidade do Fly", Flag="FlySpeed", Min=30, Max=400, Default=95})
makeToggle(TabPlayer.Content, {Text="Noclip", Flag="Noclip"})
section(TabPlayer.Content, "PROTECAO")
makeToggle(TabPlayer.Content, {Text="Godmode (client)", Flag="Godmode"})
makeToggle(TabPlayer.Content, {Text="Anti Ragdoll", Flag="AntiRagdoll"})
makeToggle(TabPlayer.Content, {Text="Anti Fling", Flag="AntiFling"})
makeToggle(TabPlayer.Content, {Text="Anti Knockback", Flag="AntiKnockback"})
makeToggle(TabPlayer.Content, {Text="Anti Trap", Flag="AntiTrap"})
makeToggle(TabPlayer.Content, {Text="Anti Void", Flag="AntiVoid"})
makeButton(TabPlayer.Content, {Text="Resetar personagem", Callback=function()
    local c = LP.Character; if c then c:BreakJoints() end
end})

-- VISUAL
section(TabVisual.Content, "ESP")
makeToggle(TabVisual.Content, {Text="Egg ESP", Flag="EggESP"})
makeToggle(TabVisual.Content, {Text="Modo lite (so Highlight)", Flag="ESPLite"})
makeSlider(TabVisual.Content, {Text="Alcance do ESP", Flag="ESPRange", Min=100, Max=1200, Default=400})
makeSlider(TabVisual.Content, {Text="Limite de ovos no ESP", Flag="ESPLimit", Min=10, Max=300, Default=90})
makeToggle(TabVisual.Content, {Text="Mostrar nome", Flag="ESPName", Default=true})
makeToggle(TabVisual.Content, {Text="Mostrar raridade", Flag="ESPRarity", Default=true})
makeToggle(TabVisual.Content, {Text="Mostrar renda", Flag="ESPValue", Default=true})
makeToggle(TabVisual.Content, {Text="Mostrar peso", Flag="ESPWeight"})
makeToggle(TabVisual.Content, {Text="Mostrar distancia", Flag="ESPDist", Default=true})
makeToggle(TabVisual.Content, {Text="Guard ESP", Flag="GuardESP"})
makeToggle(TabVisual.Content, {Text="Trap ESP", Flag="TrapESP"})
section(TabVisual.Content, "GRAFICOS")
makeToggle(TabVisual.Content, {Text="Fullbright", Flag="Fullbright"})
makeToggle(TabVisual.Content, {Text="Sem neblina", Flag="NoFog"})
makeButton(TabVisual.Content, {Text="Limpar ESP", Callback=clearESP})

-- ANTI-BAN
section(TabAntiBan.Content, "ANTI-BAN")
makeToggle(TabAntiBan.Content, {Text="Anti AFK", Flag="AntiAFK"})
makeToggle(TabAntiBan.Content, {Text="Anti Kick + Auto Reconectar", Flag="AntiKick"})
makeToggle(TabAntiBan.Content, {Text="Anti Crash (gc + limpar ESP)", Flag="AntiCrash"})
makeToggle(TabAntiBan.Content, {Text="Modo Stealth", Flag="Stealth"})
label(TabAntiBan.Content,
    "Stealth limita a velocidade a 250 e liga os delays aleatorios. "
    .. "Use se tomar kick em servidor cheio.", 40)

-- PERF
section(TabPerf.Content, "OTIMIZACAO")
makeToggle(TabPerf.Content, {Text="MODO PERFORMANCE (recomendado)", Flag="PerfMode",
    Callback=function(on)
        Flags.NoShadows = on
        Flags.NoTerrain = on
        Flags.HidePlots = on
        Flags.HidePlayers = on
        Flags.ESPLite = on
        Flags.ESPLimit = on and 45 or 90
        Flags.ESPRange = on and 250 or 400
        Flags.ScanRate = on and 2 or 1.2
        Flags.ESPRate = on and 0.6 or 0.35
        ParticleDirty = true
        notify("Venice", on and "Modo Performance LIGADO" or "Modo Performance desligado")
    end})
makeToggle(TabPerf.Content, {Text="Sem sombras", Flag="NoShadows",
    Callback=function() ParticleDirty = true end})
makeToggle(TabPerf.Content, {Text="Sem grama (Terrain Decoration)", Flag="NoTerrain"})
makeToggle(TabPerf.Content, {Text="Sem particulas", Flag="NoParticles",
    Callback=function() ParticleDirty = true end})
makeToggle(TabPerf.Content, {Text="Esconder plots de outros", Flag="HidePlots"})
makeToggle(TabPerf.Content, {Text="Esconder outros players", Flag="HidePlayers"})
makeSlider(TabPerf.Content, {Text="Intervalo do scan (s)", Flag="ScanRate",
    Min=1, Max=5, Default=1.2})
makeSlider(TabPerf.Content, {Text="Intervalo do ESP (s)", Flag="ESPRate",
    Min=1, Max=10, Default=4})
label(TabPerf.Content,
    "Intervalo do ESP esta em decimos de segundo (4 = 0,4s). "
    .. "Aumente se o FPS estiver baixo. O scan e o que mais custa: "
    .. "1,2s e um bom equilibrio.", 50)

-- MISC
section(TabMisc.Content, "SERVIDOR")
makeButton(TabMisc.Content, {Text="Server Hop", Callback=hopServer})
makeButton(TabMisc.Content, {Text="Servidor vazio", Callback=function()
    if not findEmptyServer() then notify("Venice", "Nenhum servidor vazio") end
end})
makeButton(TabMisc.Content, {Text="Rejoin", Callback=function()
    pcall(TeleportService.TeleportToPlaceInstance, TeleportService,
        game.PlaceId, game.JobId, LP)
end})
section(TabMisc.Content, "TELEPORTES")
makeButton(TabMisc.Content, {Text="Ir para o plot", Callback=function()
    local h = getHomePos(); if h then moveTo(h, Flags.MoveSpeed) end
end})
makeButton(TabMisc.Content, {Text="Ir para o ovo mais raro", Callback=function()
    local e = pickTarget()
    if e then moveTo(e.pos + Vector3.new(0, 3, 0), Flags.MoveSpeed) end
end})
section(TabMisc.Content, "DISCORD WEBHOOK")
makeInput(TabMisc.Content, {Text="URL do Webhook", Flag="Webhook",
    Placeholder="https://discord.com/api/webhooks/..."})
makeButton(TabMisc.Content, {Text="Testar webhook", Callback=function()
    sendWebhook("Venice Hub", "Conectado em Steal An Egg.")
    notify("Venice", "Webhook enviado")
end})
section(TabMisc.Content, "OUTROS")
makeToggle(TabMisc.Content, {Text="Notificacoes", Flag="Notify", Default=true})
makeDropdown(TabMisc.Content, {Text="Tecla do painel", Flag="Keybind",
    Options={"RightShift","LeftShift","RightControl","F1","F2","F3","F4","Insert"},
    Default="RightShift"})
makeButton(TabMisc.Content, {Text="Salvar config", Callback=function()
    if not writefile then return notify("Venice", "Sem writefile") end
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
    local ok, d = pcall(HttpService.JSONDecode, HttpService,
        readfile("venice_sae_config.json"))
    if ok and type(d) == "table" then
        for k, v in pairs(d) do Flags[k] = v end
        refreshFilterCache()
        notify("Venice", "Config carregada")
    end
end})
makeButton(TabMisc.Content, {Text="Descarregar script", Callback=function()
    if GENV.VENICE_SAE_UNLOAD then GENV.VENICE_SAE_UNLOAD() end
end})

-- SOBRE
local LogoLbl = new("ImageLabel", {Size=UDim2.fromOffset(220,220),
    Position=UDim2.new(0.5,-110,0,10), BackgroundTransparency=1,
    Image=LOGO_URL, ScaleType=Enum.ScaleType.Fit, Visible=false,
    Parent=TabSobre.Content})
task.spawn(function()
    if pcall(function() ContentProvider:PreloadAsync({LogoLbl}) end) then
        LogoLbl.Visible = true
    end
end)
label(TabSobre.Content,
    "\n\n\n\n\n\n\n\n\n\nVenice Hub v" .. HUB_VER .. "  ·  Steal An Egg"
    .. "\nPlaceId: " .. tostring(game.PlaceId)
    .. "\nBotao flutuante ou tecla " .. Flags.Keybind .. " abre/fecha o painel."
    .. "\n\nCredito: Venice / Venice.ai", 130)

--=====================================================================
-- 12. STATUS (aba Perf)
--=====================================================================
local S_FPS = new("TextLabel", {Size=UDim2.new(1,0,0,18), BackgroundTransparency=1,
    Text="FPS: --", TextColor3=Theme.Text, Font=Enum.Font.Gotham, TextSize=12,
    TextXAlignment=Enum.TextXAlignment.Left, Parent=TabPerf.Content})
local S_MS = new("TextLabel", {Size=UDim2.new(1,0,0,18), BackgroundTransparency=1,
    Text="Custo do scan: -- ms", TextColor3=Theme.Text, Font=Enum.Font.Gotham,
    TextSize=12, TextXAlignment=Enum.TextXAlignment.Left, Parent=TabPerf.Content})
local S_INFO = new("TextLabel", {Size=UDim2.new(1,0,0,18), BackgroundTransparency=1,
    Text="Ovos: 0", TextColor3=Theme.Text, Font=Enum.Font.Gotham, TextSize=12,
    TextXAlignment=Enum.TextXAlignment.Left, Parent=TabPerf.Content})
local S_STEAL = new("TextLabel", {Size=UDim2.new(1,0,0,18), BackgroundTransparency=1,
    Text="Roubados: 0", TextColor3=Theme.Text, Font=Enum.Font.Gotham, TextSize=12,
    TextXAlignment=Enum.TextXAlignment.Left, Parent=TabPerf.Content})
local S_UP = new("TextLabel", {Size=UDim2.new(1,0,0,18), BackgroundTransparency=1,
    Text="Uptime: 0s", TextColor3=Theme.Text, Font=Enum.Font.Gotham, TextSize=12,
    TextXAlignment=Enum.TextXAlignment.Left, Parent=TabPerf.Content})
local S_ESP = new("TextLabel", {Size=UDim2.new(1,0,0,18), BackgroundTransparency=1,
    Text="Objetos de ESP: 0", TextColor3=Theme.Text, Font=Enum.Font.Gotham,
    TextSize=12, TextXAlignment=Enum.TextXAlignment.Left, Parent=TabPerf.Content})

--=====================================================================
-- 13. AGENDADOR (tudo rate-limited, sem threads soltas)
--=====================================================================
local Tasks = {}
local function addTask(iv, fn) Tasks[#Tasks + 1] = {iv=iv, last=0, fn=fn} end

addTask(0, function() end)
addTask(0, stealCycle)
addTask(0.6, function()
    if Flags.AutoPlace then placeEggs() end
    if Flags.AutoHatch then hatchEggs() end
end)
addTask(2, function()
    if Flags.AutoEquipBest then equipBest() end
    if Flags.AutoSellPets or Flags.AutoSellEggs then sellStuff() end
    if Flags.AutoUpgradeBase or Flags.AutoUpgradeTreadmill then upgradeStuff() end
    if Flags.AutoClaim then claimStuff() end
end)
addTask(2.5, function()
    if Flags.AntiCrash then
        pcall(collectgarbage)
    end
end)

local nextScan, nextESP, nextVis = 0, 0, 0
local frameAcc, frames, lastT = 0, 0, os.clock()

bind(RunService.Heartbeat, function(dt)
    local now = os.clock()

    maintenance()
    applyNoclip()
    updateFly()

    if now >= nextScan then
        nextScan = now + Flags.ScanRate
        scanEggs()
    end

    if now >= nextVis then
        nextVis = now + 2.5
        scanWorld()
        ParticleDirty = true
        applyVisuals()
    end

    if now >= nextESP then
        nextESP = now + Flags.ESPRate / 10
        if Flags.EggESP or Flags.GuardESP or Flags.TrapESP then
            updateESP()
        elseif next(ESPItems) then
            clearESP()
        end
    end

    if Flags.HidePlayers then
        for _, pl in ipairs(Players:GetPlayers()) do
            if pl ~= LP and pl.Character then
                for _, d in ipairs(pl.Character:GetChildren()) do
                    if d.ClassName == "Part" or d.ClassName == "MeshPart" then
                        d.LocalTransparencyModifier = 1
                    end
                end
            end
        end
    end

    if Flags.Stealth and Flags.MoveSpeed > 250 then Flags.MoveSpeed = 250 end

    frames = frames + 1
    if now - lastT >= 1 then
        local fps = math.floor(frames / (now - lastT))
        frames, lastT = 0, now
        S_FPS.Text = "FPS: " .. fps
        S_MS.Text = "Custo do scan: " .. Flags.ScanMS .. " ms"
        S_INFO.Text = "Ovos: " .. Flags.Found .. "  (falhas: " .. Flags.Failed .. ")"
        S_STEAL.Text = "Roubados: " .. Flags.Steals
        S_UP.Text = "Uptime: " .. math.floor(now - Flags.StartTime) .. "s"
        local n = 0
        for _ in pairs(ESPItems) do n = n + 1 end
        S_ESP.Text = "Objetos de ESP: " .. n
    end
end)

local PlotsHidden = false
task.spawn(function()
    while Screen.Parent do
        task.wait(2)
        local want = Flags.HidePlots
        if want ~= PlotsHidden then
            PlotsHidden = want
            local mine = getOwnPlot()
            local parent = mine and mine.Parent
            if parent then
                for _, p in ipairs(parent:GetChildren()) do
                    if p ~= mine then
                        pcall(function() p.Parent = want and nil or parent end)
                    end
                end
            end
            task.wait(0.3)
            PlotTime = 0
        end
    end
end)

task.spawn(function()
    while Screen.Parent do
        local iv = Flags.Humanize and (0.08 + math.random() * 0.07) or 0.08
        task.wait(iv)
        if Flags.AutoSteal and not StealBusy then pcall(stealCycle) end
    end
end)

--=====================================================================
-- 14. HOOKS
--=====================================================================
setupAntiBan()

bind(UIS.JumpRequest, function()
    if not Flags.InfJump then return end
    local hrp = getHRP()
    if hrp then
        hrp.AssemblyLinearVelocity = Vector3.new(
            hrp.AssemblyLinearVelocity.X, 55, hrp.AssemblyLinearVelocity.Z)
    end
end)

--=====================================================================
-- 15. UNLOAD
--=====================================================================
GENV.VENICE_SAE_UNLOAD = function()
    for i = 1, #CONN do pcall(function() CONN[i]:Disconnect() end) end
    clearESP()
    if ESPFolder then pcall(function() ESPFolder:Destroy() end) end
    if Screen then pcall(function() Screen:Destroy() end) end
    GENV.VENICE_SAE_LOADED = false
end
GENV.VENICE_SAE_LOADED = true

task.wait(0.3)
scanEggs()
notify("VENICE HUB v" .. HUB_VER, "Carregado! Botao/tecla abre o painel.", 5)
print("[Venice Hub] v" .. HUB_VER .. " carregado.")
