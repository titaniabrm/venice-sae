--[[===================================================================
    VENICE HUB  ·  STEAL AN EGG  ·  v3.0.0
    -------------------------------------------------------------------
    LOADER (cole no executor):
      loadstring(game:HttpGet("https://raw.githubusercontent.com/titaniabrm/venice-sae/main/venice_sae.lua"))()

    Loop principal: roubar ovo -> voltar pra base -> colocar pro jogador pegar
    Anti-ban completo (tudo ON por padrao, tudo desligavel)
    Bypass: CFrame interpolado, getgc kick neutralize, delivery guard
=====================================================================]]

--=====================================================================
-- 0. CONFIGURACAO
--=====================================================================
local CONFIG = {
    VERSION    = "3.0.0",
    SCRIPT_URL = "https://raw.githubusercontent.com/titaniabrm/venice-sae/main/venice_sae.lua",
    LOGO_URL   = "https://raw.githubusercontent.com/titaniabrm/venice-sae/main/logo.png",
    ICON_URL   = "https://raw.githubusercontent.com/titaniabrm/venice-sae/main/icon.png",
    PLACE_ID   = 107778070777162,
}

--=====================================================================
-- 1. SERVICOS / AMBIENTE
--=====================================================================
local Players          = game:GetService("Players")
local RunService       = game:GetService("RunService")
local Workspace        = game:GetService("Workspace")
local Lighting         = game:GetService("Lighting")
local UserInputService = game:GetService("UserInputService")
local VirtualUser      = game:GetService("VirtualUser")
local ContentProvider  = game:GetService("ContentProvider")
local CoreGui          = game:GetService("CoreGui")

local LP   = Players.LocalPlayer
local GENV = (type(getgenv) == "function" and getgenv()) or _G

if GENV.VENICE_SAE_UNLOAD then pcall(GENV.VENICE_SAE_UNLOAD) end
local MY_TAG = {}
GENV.VENICE_SAE_TAG = MY_TAG
GENV.VENICE_SAE_LOADED = true

local CONN = {}
local function bind(sig, fn)
    local c = sig:Connect(fn); table.insert(CONN, c); return c
end

local Orig = {
    Brightness = Lighting.Brightness,
    FogEnd     = Lighting.FogEnd,
    FogStart   = Lighting.FogStart,
    GlobalShadows = Lighting.GlobalShadows,
}

--=====================================================================
-- 2. ESTADO (Flags) — anti-ban TUDO ON por padrao
--=====================================================================
local Flags = {
    -- FARM
    AutoSteal    = true,
    AutoReturn   = true,
    AutoPlace    = true,
    Priority     = "Raro",
    TargetRarity = "Todos",
    SearchRange  = 900,
    Cooldown     = 0.35,
    DeliverWait  = 0.25,

    -- MOVIMENTO
    TravelSpeed  = 320,
    InstantTP    = false,

    -- ANTI-BAN (ON por padrao, desligavel)
    AntiAFK          = true,
    AntiKick         = true,
    AntiRagdoll      = true,
    AntiFling        = true,
    AntiTrap         = true,
    AntiVoid         = true,
    AntiHookDetect   = true,
    AntiRemoteSpy    = true,
    AntiPositionFlag = true,
    Stealth          = false,

    -- JOGADOR
    Speed      = true,
    SpeedValue = 60,
    Jump       = true,
    JumpValue  = 80,
    Fly        = false,
    FlySpeed   = 90,
    Noclip     = false,
    Godmode    = false,

    -- VISUAL
    ESP        = false,
    ESPRange   = 900,
    Fullbright = false,
    NoParticles= false,
    FPSBoost   = false,

    -- EXTRAS
    AutoHatch  = false,
    AutoSell   = false,
    AutoEquip  = false,
    Keybind    = "RightShift",

    -- STATUS
    Status = "parado", Found = 0, Stolen = 0, Failed = 0, ScanCost = 0,
}

--=====================================================================
-- 3. HELPERS
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

local function isEggName(n)
    n = string.lower(tostring(n))
    return string.find(n, "egg") ~= nil or string.find(n, "ovo") ~= nil
end

local function attr(o, names)
    for _, n in ipairs(names) do
        local v = o:GetAttribute(n)
        if v ~= nil then return v end
    end
    return nil
end

local RARITY_MATCH = {"mythical","mythic","secret","legendary","epic","uncommon","rare","common"}
local RARITY_RANK  = {common=1, uncommon=2, rare=3, epic=4, legendary=5, mythic=6, mythical=7, secret=8}

local function getRarity(o)
    local s = attr(o, {"Rarity","rarity"})
    if s then return string.lower(tostring(s)) end
    local n = string.lower(o.Name)
    for _, r in ipairs(RARITY_MATCH) do
        if string.find(n, r) then return r end
    end
    return "common"
end
local function rarityRank(r) return RARITY_RANK[r] or 0 end
local function getValue(o)
    return tonumber(attr(o, {"Value","Cash","Price","EarnRate"})) or 0
end

local function getPos(o)
    if not o then return nil end
    if o:IsA("BasePart") then return o.Position end
    if o:IsA("Model") then
        local p = o.PrimaryPart or o:FindFirstChildWhichIsA("BasePart")
        if p then return p.Position end
        local ok, cf = pcall(function() return o:GetPivot().Position end)
        return ok and cf or nil
    end
    return nil
end

local function firePrompt(p)
    if not p then return false end
    if type(fireproximityprompt) == "function" then
        if pcall(fireproximityprompt, p) then return true end
    end
    return (pcall(function()
        p:InputHoldBegin(); task.wait(0.03); p:InputHoldEnd()
    end))
end

--=====================================================================
-- 4. UI — tema + construtores
--=====================================================================
local Theme = {
    Bg      = Color3.fromRGB(16,16,21),
    Panel   = Color3.fromRGB(24,24,32),
    Stroke  = Color3.fromRGB(46,46,60),
    Text    = Color3.fromRGB(235,235,245),
    Dim     = Color3.fromRGB(150,150,165),
    Accent  = Color3.fromRGB(140,90,255),
    Accent2 = Color3.fromRGB(90,200,255),
    Green   = Color3.fromRGB(80,220,130),
}

local function new(class, props)
    local inst = Instance.new(class)
    for k, v in pairs(props or {}) do inst[k] = v end
    return inst
end
local function corner(inst, r)
    new("UICorner", {CornerRadius = UDim.new(0, r or 8), Parent = inst})
end
local function stroke(inst, c, t)
    new("UIStroke", {Color = c or Theme.Stroke, Thickness = t or 1, Parent = inst})
end

local Screen = new("ScreenGui", {
    Name = "VeniceHubSAE", ResetOnSpawn = false,
    ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
})
pcall(function() Screen.Parent = CoreGui end)
if not Screen.Parent then Screen.Parent = LP:WaitForChild("PlayerGui") end

-- painel principal
local Main = new("Frame", {
    Size = UDim2.new(0, 640, 0, 440),
    Position = UDim2.new(0.5, -320, 0.5, -220),
    BackgroundColor3 = Theme.Bg, BorderSizePixel = 0, Visible = false, Active = true,
})
corner(Main, 12); stroke(Main, Theme.Stroke, 1); Main.Parent = Screen

local Header = new("Frame", {
    Size = UDim2.new(1, 0, 0, 40), BackgroundColor3 = Theme.Panel,
    BorderSizePixel = 0, Parent = Main,
})
corner(Header, 12)

local Logo = new("ImageLabel", {
    Size = UDim2.new(0, 24, 0, 24), Position = UDim2.new(0, 12, 0.5, -12),
    BackgroundTransparency = 1, Image = CONFIG.ICON_URL, Parent = Header,
})
new("TextLabel", {
    Size = UDim2.new(1, -90, 1, 0), Position = UDim2.new(0, 44, 0, 0),
    BackgroundTransparency = 1, Text = "VENICE HUB  ·  Steal An Egg  ·  v" .. CONFIG.VERSION,
    TextColor3 = Theme.Text, Font = Enum.Font.GothamBold, TextSize = 14,
    TextXAlignment = Enum.TextXAlignment.Left, Parent = Header,
})
local CloseBtn = new("TextButton", {
    Size = UDim2.new(0, 28, 0, 28), Position = UDim2.new(1, -36, 0.5, -14),
    BackgroundColor3 = Theme.Bg, Text = "X", TextColor3 = Theme.Text,
    Font = Enum.Font.GothamBold, TextSize = 14, BorderSizePixel = 0, Parent = Header,
})
corner(CloseBtn, 8)
CloseBtn.MouseButton1Click:Connect(function() Main.Visible = false end)

local TabBar = new("Frame", {
    Size = UDim2.new(1, -16, 0, 34), Position = UDim2.new(0, 8, 0, 44),
    BackgroundTransparency = 1, Parent = Main,
})
new("UIListLayout", {
    FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 4),
    VerticalAlignment = Enum.VerticalAlignment.Center, Parent = TabBar,
})

local Body = new("Frame", {
    Size = UDim2.new(1, 0, 1, -82), Position = UDim2.new(0, 0, 0, 82),
    BackgroundTransparency = 1, Parent = Main,
})

local Tabs = {}
local function makeTab(name)
    local btn = new("TextButton", {
        Size = UDim2.new(0, #name * 8 + 22, 1, -8),
        BackgroundColor3 = Theme.Panel, Text = name, TextColor3 = Theme.Dim,
        Font = Enum.Font.GothamBold, TextSize = 12, BorderSizePixel = 0, Parent = TabBar,
    })
    corner(btn, 6)
    local content = new("ScrollingFrame", {
        Size = UDim2.new(1, -20, 1, -14), Position = UDim2.new(0, 10, 0, 4),
        BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 4,
        CanvasSize = UDim2.new(0, 0, 0, 0), AutomaticCanvasSize = Enum.AutomaticSize.Y,
        Visible = false, Parent = Body,
    })
    new("UIListLayout", {Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder, Parent = content})
    local tab = {button = btn, content = content}
    table.insert(Tabs, tab)
    btn.MouseButton1Click:Connect(function()
        for _, t in ipairs(Tabs) do
            t.content.Visible = false
            t.button.BackgroundColor3 = Theme.Panel
            t.button.TextColor3 = Theme.Dim
        end
        content.Visible = true
        btn.BackgroundColor3 = Theme.Accent
        btn.TextColor3 = Color3.new(1,1,1)
    end)
    return tab
end

local function section(parent, text)
    return new("TextLabel", {
        Size = UDim2.new(1, 0, 0, 22), BackgroundTransparency = 1,
        Text = string.upper(text), TextColor
