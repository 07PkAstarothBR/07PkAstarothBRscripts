-- project_final.lua
-- ==========================================
-- Script completo com sistema de chaves implementado
-- Alterações: LoginFrame maior + botão Mostrar Key + botão 📑 copiar key
-- ==========================================

-- Script fix.lua
-- 07AstarothGUI + Sistema de Chave GitHub integrado
-- Mantém o Auto Generator ORIGINAL e toda a sua GUI. Login só com key remota do GitHub.

-- ========================= CONFIG / VARIÁVEIS GLOBAIS =========================
local HttpService = game:GetService("HttpService")

local SAVE_FILE = "07AstarothGui.json"
local VERSION   = "1.0.0 Beta"

-- >>> URL da chave remota (GitHub RAW)
local KEY_URL = "https://raw.githubusercontent.com/07PkAstarothBR/07PkAstarothBRscripts/main/key.lua"

getgenv().ScriptActive   = true             -- controle para encerrar script pelo botão X do login
getgenv().AutoGenEnabled = false            -- será carregado do JSON se existir
getgenv().AutoGenDelay   = 2.0              -- idem

-- ========================= PERSISTÊNCIA =========================
local function safe_write(tbl)
    if writefile then
        local ok, enc = pcall(function() return HttpService:JSONEncode(tbl) end)
        if ok then pcall(function() writefile(SAVE_FILE, enc) end) end
    end
end

local function safe_read()
    if isfile and isfile(SAVE_FILE) then
        local ok, data = pcall(function() return HttpService:JSONDecode(readfile(SAVE_FILE)) end)
        if ok and type(data) == "table" then return data end
    end
    return {}
end

local Settings = safe_read()

-- Estado inicial carregado
getgenv().AutoGenEnabled = Settings.AutoGenEnabled or false
getgenv().AutoGenDelay   = Settings.AutoGenDelay   or 2.0
local UsageCondition     = Settings.UsageCondition or "Safe"     -- Safe | LowRisk | HighRisk
local UseSavedPassword   = Settings.UseSavedPassword or false
local SavedPassword      = Settings.SavedPassword or ""

local FramePos = Settings.FramePos or {ScaleX=0.30, OffsetX=0, ScaleY=0.25, OffsetY=0}
local ReopenPos= Settings.ReopenPos or {ScaleX=0.02, OffsetX=10, ScaleY=0.75, OffsetY=0}

-- Tema por partes
local Theme = Settings.Theme or {
    Bg     = {20,20,20},
    Text   = {255,255,255},
    Accent = {0,170,255},
    Button = {60,60,60},
    Flags  = { BgRGB=false, TextRGB=false, AccentRGB=false, ButtonRGB=false }
}

local function C3(t) return Color3.fromRGB(t[1],t[2],t[3]) end

-- ========================= HELPERS: REDE / KEY REMOTA =========================
local function trim(s)
    return s and (s:match("^%s*(.-)%s*$")) or s
end

local function http_get_raw(url)
    -- Tenta compat com executores
    local req
    if syn and syn.request then
        req = syn.request
    elseif http_request then
        req = http_request
    elseif request then
        req = request
    end

    if req then
        local ok, res = pcall(req, {Url = url, Method = "GET"})
        if ok and res and res.StatusCode == 200 and res.Body then
            return res.Body, 200
        else
            return nil, (res and res.StatusCode) or -1
        end
    end

    -- Fallback: HttpGet do Roblox (normalmente funciona em muitos executores)
    local ok2, body = pcall(function()
        return game:HttpGet(url, true)
    end)
    if ok2 and body then return body, 200 end
    return nil, -1
end

local RemoteKeyCache = { value = nil, at = 0 }
local function fetchRemoteKey(force)
    local now = tick()
    -- cache curto pra evitar rate (5s)
    if not force and RemoteKeyCache.value and (now - RemoteKeyCache.at) < 5 then
        return RemoteKeyCache.value
    end

    local body, status = http_get_raw(KEY_URL)
    if status ~= 200 or not body then
        return nil, ("Falha ao buscar key (HTTP %s)"):format(tostring(status))
    end

    -- O arquivo key.lua pode conter só a key, ou algo tipo: return "chave..."
    -- Vamos extrair a primeira string útil (sem espaços/linhas).
    local raw = trim(body or "")
    -- Se vier 'return "xxxxx"' tenta capturar
    local byReturn = raw:match('return%s*["\'](.-)["\']')
    local byAssign = raw:match('Key%s*=%s*["\'](.-)["\']')
    local candidate = byReturn or byAssign or raw

    candidate = trim(candidate)
    -- Remove quebras de linha
    candidate = candidate and candidate:gsub("[\r\n]", "") or candidate

    if not candidate or candidate == "" then
        return nil, "Key vazia no GitHub"
    end

    RemoteKeyCache.value = candidate
    RemoteKeyCache.at = now
    return candidate
end

-- ========================= SOURCE ORIGINAL (MANTIDA) =========================
-- Loop original do usuário para acionar os geradores. Apenas usa getgenv().AutoGenEnabled e getgenv().AutoGenDelay.
task.spawn(function()
    while getgenv().ScriptActive do
        if getgenv().AutoGenEnabled then
            local map = workspace:FindFirstChild("Map") 
                and workspace.Map:FindFirstChild("Ingame") 
                and workspace.Map.Ingame:FindFirstChild("Map")

            if map then
                for _, gen in pairs(map:GetChildren()) do
                    if gen:IsA("Model") and gen.Name == "Generator" then
                        local re = gen:FindFirstChild("Remotes") and gen.Remotes:FindFirstChild("RE")
                        if re then
                            re:FireServer()
                        end
                    end
                end
            end
        end
        task.wait(getgenv().AutoGenDelay)
    end
end)
-- ============================================================================

-- ========================= GUI BASE =========================
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "AstarothGui"
ScreenGui.ResetOnSpawn = false
ScreenGui.Parent = (game:GetService("CoreGui") or game:GetService("Players").LocalPlayer:WaitForChild("PlayerGui"))

local MainFrame, ReopenButton
local Panels = {}

local function SaveAll()
    local mfPos = FramePos
    local roPos = ReopenPos
    if MainFrame then
        mfPos = {ScaleX=MainFrame.Position.X.Scale, OffsetX=MainFrame.Position.X.Offset, ScaleY=MainFrame.Position.Y.Scale, OffsetY=MainFrame.Position.Y.Offset}
    end
    if ReopenButton then
        roPos = {ScaleX=ReopenButton.Position.X.Scale, OffsetX=ReopenButton.Position.X.Offset, ScaleY=ReopenButton.Position.Y.Scale, OffsetY=ReopenButton.Position.Y.Offset}
    end
    local dump = {
        AutoGenEnabled   = getgenv().AutoGenEnabled,
        AutoGenDelay     = getgenv().AutoGenDelay,
        FramePos         = mfPos,
        ReopenPos        = roPos,
        UsageCondition   = UsageCondition,
        UseSavedPassword = UseSavedPassword,
        SavedPassword    = SavedPassword,
        Theme            = Theme,
    }
    safe_write(dump)
end

-- ========================= TEMA / RGB =========================
local RGBThreads = {}
local function ApplyTheme(root)
    if not root then return end
    for _, obj in ipairs(root:GetDescendants()) do
        if obj:IsA("TextLabel") or obj:IsA("TextButton") or obj:IsA("TextBox") then
            obj.TextColor3 = C3(Theme.Text)
        end
        if obj:IsA("Frame") then
            if obj.Name == "MainFrame" or obj.Name == "Header" or obj.Name == "Sidebar" or obj.Parent == Panels.Content then
                obj.BackgroundColor3 = C3(Theme.Bg)
            end
        end
        if obj:IsA("TextButton") then
            if obj.Name ~= "CloseButton" and obj.Name ~= "OpenTheme" and obj.Name ~= "RGBBtn" then
                obj.BackgroundColor3 = C3(Theme.Button)
            end
        end
    end
    if MainFrame then MainFrame.BackgroundColor3 = C3(Theme.Bg) end
end

local function startRGB(key, applyFunc)
    if RGBThreads[key] then RGBThreads[key] = nil end
    Theme.Flags[key.."RGB"] = true
    RGBThreads[key] = true
    task.spawn(function()
        while RGBThreads[key] do
            local t = tick()*2
            local r = math.floor((math.sin(t)+1)*127.5)
            local g = math.floor((math.sin(t+2)+1)*127.5)
            local b = math.floor((math.sin(t+4)+1)*127.5)
            Theme[key] = {r,g,b}
            if applyFunc then applyFunc() else ApplyTheme(MainFrame) end
            task.wait(0.08)
        end
    end)
end

local function stopRGB(key)
    Theme.Flags[key.."RGB"] = false
    RGBThreads[key] = nil
end

-- ========================= LOGIN (AGORA COM KEY DO GITHUB) =========================
local LoginFrame = Instance.new("Frame")
LoginFrame.Name = "LoginFrame"
LoginFrame.Size = UDim2.new(0, 360, 0, 230)
LoginFrame.Position = UDim2.new(0.5, -180, 0.5, -115) -- centralizado fixo
LoginFrame.BackgroundColor3 = C3(Theme.Bg)
LoginFrame.Active = true
LoginFrame.Draggable = false -- fixo
LoginFrame.Parent = ScreenGui
local UICornerLogin = Instance.new("UICorner"); UICornerLogin.CornerRadius = UDim.new(0, 12); UICornerLogin.Parent = LoginFrame

local LoginTitle = Instance.new("TextLabel")
LoginTitle.Size = UDim2.new(1, -40, 0, 34)
LoginTitle.Position = UDim2.new(0, 10, 0, 6)
LoginTitle.BackgroundTransparency = 1
LoginTitle.Text = "Login - 07AstarothGui"
LoginTitle.TextColor3 = C3(Theme.Text)
LoginTitle.Font = Enum.Font.SourceSansBold
LoginTitle.TextSize = 20
LoginTitle.TextXAlignment = Enum.TextXAlignment.Left
LoginTitle.Parent = LoginFrame

local CloseLogin = Instance.new("TextButton")
CloseLogin.Size = UDim2.new(0, 30, 0, 30)
CloseLogin.Position = UDim2.new(1, -36, 0, 6)
CloseLogin.BackgroundColor3 = Color3.fromRGB(200,0,0)
CloseLogin.Text = "X"
CloseLogin.TextColor3 = Color3.fromRGB(255,255,255)
CloseLogin.Font = Enum.Font.SourceSansBold
CloseLogin.TextSize = 16
CloseLogin.Parent = LoginFrame
local UICloseLogin = Instance.new("UICorner"); UICloseLogin.CornerRadius = UDim.new(0, 8); UICloseLogin.Parent = CloseLogin

local PasswordBox = Instance.new("TextBox")
PasswordBox.Size = UDim2.new(0.8, 0, 0, 32)
PasswordBox.Position = UDim2.new(0.1, 0, 0, 60)
PasswordBox.PlaceholderText = "Digite a KEY (GitHub)"
PasswordBox.Text = (UseSavedPassword and SavedPassword or "")
PasswordBox.BackgroundColor3 = Color3.fromRGB(40,40,40)
PasswordBox.TextColor3 = Color3.fromRGB(255,255,255)
PasswordBox.Font = Enum.Font.SourceSans
PasswordBox.TextSize = 18
PasswordBox.Parent = LoginFrame
local UICornerBox = Instance.new("UICorner"); UICornerBox.CornerRadius = UDim.new(0, 8); UICornerBox.Parent = PasswordBox

local SavePassCheck = Instance.new("TextButton")
SavePassCheck.Size = UDim2.new(0.8, 0, 0, 28)
SavePassCheck.Position = UDim2.new(0.1, 0, 0, 100)
SavePassCheck.Text = UseSavedPassword and "✅ Salvar key" or "❌️ Salvar key"
SavePassCheck.BackgroundColor3 = Color3.fromRGB(45,45,45)
SavePassCheck.TextColor3 = Color3.fromRGB(255,255,255)
SavePassCheck.Font = Enum.Font.SourceSans
SavePassCheck.TextSize = 16
SavePassCheck.Parent = LoginFrame
local UICornerCheck = Instance.new("UICorner"); UICornerCheck.CornerRadius = UDim.new(0, 8); UICornerCheck.Parent = SavePassCheck

local RefreshKeyBtn = Instance.new("TextButton")
RefreshKeyBtn.Size = UDim2.new(0.8, 0, 0, 28)
RefreshKeyBtn.Position = UDim2.new(0.1, 0, 0, 134)
RefreshKeyBtn.Text = "Atualizar Key do GitHub"
RefreshKeyBtn.BackgroundColor3 = Color3.fromRGB(45,45,45)
RefreshKeyBtn.TextColor3 = Color3.fromRGB(255,255,255)
RefreshKeyBtn.Font = Enum.Font.SourceSansBold
RefreshKeyBtn.TextSize = 16
RefreshKeyBtn.Parent = LoginFrame
local UICornerRef = Instance.new("UICorner"); UICornerRef.CornerRadius = UDim.new(0, 8); UICornerRef.Parent = RefreshKeyBtn

local LoginButton = Instance.new("TextButton")
LoginButton.Size = UDim2.new(0.8, 0, 0, 30)
LoginButton.Position = UDim2.new(0.1, 0, 0, 170)
LoginButton.Text = "Entrar"
LoginButton.BackgroundColor3 = Color3.fromRGB(0,200,0)
LoginButton.TextColor3 = Color3.fromRGB(255,255,255)
LoginButton.Font = Enum.Font.SourceSansBold
LoginButton.TextSize = 18
LoginButton.Parent = LoginFrame
local UICornerLoginBtn = Instance.new("UICorner"); UICornerLoginBtn.CornerRadius = UDim.new(0, 8); UICornerLoginBtn.Parent = LoginButton

local VersionLogin = Instance.new("TextLabel")
VersionLogin.Size = UDim2.new(1, -10, 0, 20)
VersionLogin.Position = UDim2.new(0, 6, 1, -24)
VersionLogin.BackgroundTransparency = 1
VersionLogin.Text = "Versão: "..VERSION
VersionLogin.TextColor3 = C3(Theme.Text)
VersionLogin.Font = Enum.Font.SourceSans
VersionLogin.TextSize = 14
VersionLogin.TextXAlignment = Enum.TextXAlignment.Left
VersionLogin.Parent = LoginFrame

SavePassCheck.MouseButton1Click:Connect(function()
    UseSavedPassword = not UseSavedPassword
    SavePassCheck.Text = UseSavedPassword and "✅ Salvar key" or "❌️ Salvar key"
end)

CloseLogin.MouseButton1Click:Connect(function()
    -- Fecha tudo
    getgenv().ScriptActive = false
    if ScreenGui then ScreenGui:Destroy() end
    warn("[07AstarothGui] Script fechado. Reexecute para tentar novamente.")
end)

RefreshKeyBtn.MouseButton1Click:Connect(function()
    RefreshKeyBtn.Text = "Atualizando..."
    local key, err = fetchRemoteKey(true)
    if key then
        RefreshKeyBtn.Text = "Key atualizada ✔"
        task.delay(1.5, function()
            if RefreshKeyBtn then RefreshKeyBtn.Text = "Atualizar Key do GitHub" end
        end)
    else
        RefreshKeyBtn.Text = "Falha: "..(err or "erro")
        task.delay(2.0, function()
            if RefreshKeyBtn then RefreshKeyBtn.Text = "Atualizar Key do GitHub" end
        end)
    end
end)

-- ========================= CONSTRUÇÃO DO MAIN =========================
local function BuildMain()
    -- Frame principal
    MainFrame = Instance.new("Frame")
    MainFrame.Name = "MainFrame"
    MainFrame.Size = UDim2.new(0, 520, 0, 380)
    MainFrame.Position = UDim2.new(FramePos.ScaleX, FramePos.OffsetX, FramePos.ScaleY, FramePos.OffsetY)
    MainFrame.BackgroundColor3 = C3(Theme.Bg)
    MainFrame.Active = true
    MainFrame.Draggable = true
    MainFrame.Parent = ScreenGui
    local UICornerMain = Instance.new("UICorner"); UICornerMain.CornerRadius = UDim.new(0, 14); UICornerMain.Parent = MainFrame

    -- Header
    local Header = Instance.new("Frame")
    Header.Name = "Header"
    Header.Size = UDim2.new(1, 0, 0, 40)
    Header.BackgroundColor3 = Color3.fromRGB(45,45,45)
    Header.Parent = MainFrame
    local UICornerHead = Instance.new("UICorner"); UICornerHead.CornerRadius = UDim.new(0, 14); UICornerHead.Parent = Header

    local Title = Instance.new("TextLabel")
    Title.Size = UDim2.new(1, -40, 1, 0)
    Title.Position = UDim2.new(0, 10, 0, 0)
    Title.BackgroundTransparency = 1
    Title.Text = "Auto generator by 07PkAstarothBR | "..VERSION
    Title.TextColor3 = C3(Theme.Text)
    Title.Font = Enum.Font.SourceSansBold
    Title.TextSize = 17
    Title.TextXAlignment = Enum.TextXAlignment.Left
    Title.Parent = Header

    local CloseButton = Instance.new("TextButton")
    CloseButton.Name = "CloseButton"
    CloseButton.Size = UDim2.new(0, 30, 0, 30)
    CloseButton.Position = UDim2.new(1, -36, 0.5, -15)
    CloseButton.BackgroundColor3 = Color3.fromRGB(200,0,0)
    CloseButton.Text = "X"
    CloseButton.TextColor3 = Color3.fromRGB(255,255,255)
    CloseButton.Font = Enum.Font.SourceSansBold
    CloseButton.TextSize = 16
    CloseButton.Parent = Header
    local UICornerClose = Instance.new("UICorner"); UICornerClose.CornerRadius = UDim.new(0, 8); UICornerClose.Parent = CloseButton

    ReopenButton = Instance.new("TextButton")
    ReopenButton.Size = UDim2.new(0, 70, 0, 28)
    ReopenButton.Position = UDim2.new(ReopenPos.ScaleX, ReopenPos.OffsetX, ReopenPos.ScaleY, ReopenPos.OffsetY)
    ReopenButton.BackgroundColor3 = Color3.fromRGB(50,50,200)
    ReopenButton.Text = "Abrir"
    ReopenButton.TextColor3 = Color3.fromRGB(255,255,255)
    ReopenButton.Font = Enum.Font.SourceSansBold
    ReopenButton.TextSize = 14
    ReopenButton.Visible = false
    ReopenButton.Active = true
    ReopenButton.Draggable = true
    ReopenButton.Parent = ScreenGui

    CloseButton.MouseButton1Click:Connect(function()
        MainFrame.Visible = false
        ReopenButton.Visible = true
        SaveAll()
    end)
    ReopenButton.MouseButton1Click:Connect(function()
        MainFrame.Visible = true
        ReopenButton.Visible = false
    end)

    MainFrame:GetPropertyChangedSignal("Position"):Connect(SaveAll)
    ReopenButton:GetPropertyChangedSignal("Position"):Connect(SaveAll)

    -- Sidebar de categorias
    local Sidebar = Instance.new("Frame")
    Sidebar.Name = "Sidebar"
    Sidebar.Size = UDim2.new(0, 140, 1, -50)
    Sidebar.Position = UDim2.new(0, 10, 0, 45)
    Sidebar.BackgroundColor3 = Color3.fromRGB(30,30,30)
    Sidebar.Parent = MainFrame
    local UICornerSide = Instance.new("UICorner"); UICornerSide.CornerRadius = UDim.new(0, 10); UICornerSide.Parent = Sidebar

    local function catBtn(text, order)
        local b = Instance.new("TextButton")
        b.Size = UDim2.new(1, -12, 0, 30)
        b.Position = UDim2.new(0, 6, 0, (order-1)*36 + 8)
        b.BackgroundColor3 = C3(Theme.Button)
        b.Text = text
        b.TextColor3 = C3(Theme.Text)
        b.Font = Enum.Font.SourceSansBold
        b.TextSize = 15
        b.Parent = Sidebar
        local uc = Instance.new("UICorner"); uc.CornerRadius = UDim.new(0, 8); uc.Parent = b
        return b
    end

    -- Ordem: Funções (1), Temas (2), Info (3), Secret (4), Config (5)
    local BTN_FUN   = catBtn("Funções", 1)
    local BTN_THEME = catBtn("Temas",   2)
    local BTN_INFO  = catBtn("Info",    3)
    local BTN_SECRET= catBtn("Secret",  4)
    local BTN_CONF  = catBtn("Config",  5)

    -- Content
    local Content = Instance.new("Frame")
    Content.Name = "Content"
    Content.Size = UDim2.new(1, -170, 1, -50)
    Content.Position = UDim2.new(0, 160, 0, 45)
    Content.BackgroundColor3 = Color3.fromRGB(25,25,25)
    Content.Parent = MainFrame
    local UICornerCont = Instance.new("UICorner"); UICornerCont.CornerRadius = UDim.new(0, 10); UICornerCont.Parent = Content

    local function newPanel(name)
        local p = Instance.new("Frame")
        p.Name = name
        p.Size = UDim2.new(1, -20, 1, -20)
        p.Position = UDim2.new(0, 10, 0, 10)
        p.BackgroundColor3 = Color3.fromRGB(20,20,20)
        p.Visible = false
        p.Parent = Content
        local uc = Instance.new("UICorner"); uc.CornerRadius = UDim.new(0, 10); uc.Parent = p
        return p
    end

    local PFun    = newPanel("PFun")
    local PTheme  = newPanel("PTheme")
    local PInfo   = newPanel("PInfo")
    local PSecret = newPanel("PSecret")
    local PConf   = newPanel("PConf")
    Panels.Content = Content

    local function show(panel)
        PFun.Visible, PTheme.Visible, PInfo.Visible, PSecret.Visible, PConf.Visible = false,false,false,false,false
        panel.Visible = true
    end

    -- ===== Funções =====
    do
        local TitleF = Instance.new("TextLabel")
        TitleF.Size = UDim2.new(1, -10, 0, 28)
        TitleF.Position = UDim2.new(0, 10, 0, 8)
        TitleF.BackgroundTransparency = 1
        TitleF.Text = "Funções"
        TitleF.TextColor3 = C3(Theme.Text)
        TitleF.Font = Enum.Font.SourceSansBold
        TitleF.TextSize = 18
        TitleF.Parent = PFun

        local AutoBtn = Instance.new("TextButton")
        AutoBtn.Size = UDim2.new(0.6, 0, 0, 32)
        AutoBtn.Position = UDim2.new(0, 10, 0, 44)
        AutoBtn.Text = getgenv().AutoGenEnabled and "Desativar Auto Generator" or "Ativar Auto Generator"
        AutoBtn.BackgroundColor3 = getgenv().AutoGenEnabled and Color3.fromRGB(200,0,0) or Color3.fromRGB(0,200,0)
        AutoBtn.TextColor3 = Color3.fromRGB(255,255,255)
        AutoBtn.Font = Enum.Font.SourceSansBold
        AutoBtn.TextSize = 16
        AutoBtn.Parent = PFun
        local UCAuto = Instance.new("UICorner"); UCAuto.CornerRadius = UDim.new(0, 8); UCAuto.Parent = AutoBtn

        local Line1 = Instance.new("Frame")
        Line1.Size = UDim2.new(0.95, 0, 0, 2)
        Line1.Position = UDim2.new(0, 10, 0, 84)
        Line1.BackgroundColor3 = Color3.fromRGB(60,60,60)
        Line1.Parent = PFun

        local DelayLbl = Instance.new("TextLabel")
        DelayLbl.Size = UDim2.new(0.95, 0, 0, 20)
        DelayLbl.Position = UDim2.new(0, 10, 0, 92)
        DelayLbl.BackgroundTransparency = 1
        DelayLbl.Text = ("Delay: %.1fs"):format(getgenv().AutoGenDelay)
        DelayLbl.TextColor3 = C3(Theme.Text)
        DelayLbl.Font = Enum.Font.SourceSans
        DelayLbl.TextSize = 16
        DelayLbl.Parent = PFun

        local Slider = Instance.new("Frame")
        Slider.Size = UDim2.new(0.95, 0, 0, 12)
        Slider.Position = UDim2.new(0, 10, 0, 116)
        Slider.BackgroundColor3 = Color3.fromRGB(60,60,60)
        Slider.Parent = PFun
        local UCSlider = Instance.new("UICorner"); UCSlider.CornerRadius = UDim.new(0, 6); UCSlider.Parent = Slider

        local function delayToAlpha(d) return (math.clamp(d,0.1,5.0)-0.1)/4.9 end
        local Fill = Instance.new("Frame")
        Fill.Size = UDim2.new(delayToAlpha(getgenv().AutoGenDelay), 0, 1, 0)
        Fill.BackgroundColor3 = C3(Theme.Accent)
        Fill.Parent = Slider
        local UCFill = Instance.new("UICorner"); UCFill.CornerRadius = UDim.new(0, 6); UCFill.Parent = Fill

        local UIS = game:GetService("UserInputService")
        local sliding = false
        local function setDrag(en) MainFrame.Draggable = en end
        Slider.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                sliding = true; setDrag(false)
            end
        end)
        Slider.InputEnded:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                sliding = false; setDrag(true)
            end
        end)
        UIS.InputChanged:Connect(function(input)
            if sliding and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
                local rel = math.clamp((input.Position.X - Slider.AbsolutePosition.X) / Slider.AbsoluteSize.X, 0, 1)
                local d = math.floor(((rel * 4.9) + 0.1) * 10) / 10
                getgenv().AutoGenDelay = d
                Fill.Size = UDim2.new(rel, 0, 1, 0)
                DelayLbl.Text = ("Delay: %.1fs"):format(d)
                SaveAll()
            end
        end)

        AutoBtn.MouseButton1Click:Connect(function()
            getgenv().AutoGenEnabled = not getgenv().AutoGenEnabled
            AutoBtn.Text = getgenv().AutoGenEnabled and "Desativar Auto Generator" or "Ativar Auto Generator"
            AutoBtn.BackgroundColor3 = getgenv().AutoGenEnabled and Color3.fromRGB(200,0,0) or Color3.fromRGB(0,200,0)
            SaveAll()
        end)
    end

    -- ===== Temas =====
    do
        local TitleT = Instance.new("TextLabel")
        TitleT.Size = UDim2.new(1, -10, 0, 28)
        TitleT.Position = UDim2.new(0, 10, 0, 8)
        TitleT.BackgroundTransparency = 1
        TitleT.Text = "Temas"
        TitleT.TextColor3 = C3(Theme.Text)
        TitleT.Font = Enum.Font.SourceSansBold
        TitleT.TextSize = 18
        TitleT.Parent = PTheme

        local OpenTheme = Instance.new("TextButton")
        OpenTheme.Name = "OpenTheme"
        OpenTheme.Size = UDim2.new(0.6, 0, 0, 32)
        OpenTheme.Position = UDim2.new(0, 10, 0, 44)
        OpenTheme.BackgroundColor3 = C3(Theme.Button)
        OpenTheme.Text = "Abrir Temas (cores por parte)"
        OpenTheme.TextColor3 = Color3.fromRGB(255,255,255)
        OpenTheme.Font = Enum.Font.SourceSansBold
        OpenTheme.TextSize = 16
        OpenTheme.Parent = PTheme
        local UCOpen = Instance.new("UICorner"); UCOpen.CornerRadius = UDim.new(0, 8); UCOpen.Parent = OpenTheme

        -- Submenu com scroll
        local ThemeMenu = Instance.new("Frame")
        ThemeMenu.Size = UDim2.new(0, 280, 0, 230)
        ThemeMenu.Position = UDim2.new(0.5, -140, 0.5, -115)
        ThemeMenu.BackgroundColor3 = Color3.fromRGB(20,20,20)
        ThemeMenu.Visible = false
        ThemeMenu.Parent = MainFrame
        local UCTMenu = Instance.new("UICorner"); UCTMenu.CornerRadius = UDim.new(0, 12); UCTMenu.Parent = ThemeMenu

        local CloseTheme = Instance.new("TextButton")
        CloseTheme.Size = UDim2.new(0, 28, 0, 24)
        CloseTheme.Position = UDim2.new(1, -32, 0, 6)
        CloseTheme.BackgroundColor3 = Color3.fromRGB(200,0,0)
        CloseTheme.Text = "X"
        CloseTheme.TextColor3 = Color3.fromRGB(255,255,255)
        CloseTheme.Font = Enum.Font.SourceSansBold
        CloseTheme.TextSize = 14
        CloseTheme.Parent = ThemeMenu
        local UCCloseTheme = Instance.new("UICorner"); UCCloseTheme.CornerRadius = UDim.new(0,6); UCCloseTheme.Parent = CloseTheme

        local TargetLabel = Instance.new("TextLabel")
        TargetLabel.Size = UDim2.new(1, -10, 0, 22)
        TargetLabel.Position = UDim2.new(0, 5, 0, 6)
        TargetLabel.BackgroundTransparency = 1
        TargetLabel.Text = "Editar: Fundo"
        TargetLabel.TextColor3 = Color3.fromRGB(255,255,255)
        TargetLabel.Font = Enum.Font.SourceSansBold
        TargetLabel.TextSize = 16
        TargetLabel.Parent = ThemeMenu

        local Selector = Instance.new("Frame")
        Selector.Size = UDim2.new(1, -10, 0, 28)
        Selector.Position = UDim2.new(0, 5, 0, 30)
        Selector.BackgroundTransparency = 1
        Selector.Parent = ThemeMenu

        local comps = {
            {key="Bg",     label="Fundo"},
            {key="Text",   label="Texto"},
            {key="Accent", label="Realce"},
            {key="Button", label="Botões"},
        }
        local currentKey = "Bg"

        local function smallBtn(text, x)
            local b = Instance.new("TextButton")
            b.Size = UDim2.new(0, 64, 0, 24)
            b.Position = UDim2.new(0, x, 0, 2)
            b.BackgroundColor3 = Color3.fromRGB(50,50,50)
            b.Text = text
            b.TextColor3 = Color3.fromRGB(255,255,255)
            b.Font = Enum.Font.SourceSansBold
            b.TextSize = 14
            b.Parent = Selector
            local uc = Instance.new("UICorner"); uc.CornerRadius = UDim.new(0,6); uc.Parent = b
            return b
        end

        local xoff = 0
        for _, c in ipairs(comps) do
            local b = smallBtn(c.label, xoff)
            b.MouseButton1Click:Connect(function()
                currentKey = c.key
                TargetLabel.Text = "Editar: "..c.label
            end)
            xoff = xoff + 68
        end

        local Scroll = Instance.new("ScrollingFrame")
        Scroll.Size = UDim2.new(1, -10, 0, 150)
        Scroll.Position = UDim2.new(0, 5, 0, 62)
        Scroll.BackgroundTransparency = 1
        Scroll.CanvasSize = UDim2.new(0, 0, 0, 360)
        Scroll.ScrollBarThickness = 6
        Scroll.Parent = ThemeMenu

        -- Bloqueia arrastar o MainFrame ao rolar
        local function setDraggable(en) MainFrame.Draggable = en end
        Scroll.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseWheel then
                setDraggable(false)
            end
        end)
        Scroll.InputEnded:Connect(function()
            setDraggable(true)
        end)

        local List = Instance.new("UIListLayout")
        List.Padding = UDim.new(0,6)
        List.Parent = Scroll

        local palette = {
            {name="Preto",    col={20,20,20}},
            {name="Roxo",     col={80,0,120}},
            {name="Amarelo",  col={220,220,0}},
            {name="Verde",    col={0,200,0}},
            {name="Vermelho", col={200,0,0}},
            {name="Azul",     col={0,120,220}},
            {name="Branco",   col={255,255,255}},
            {name="Cinza",    col={130,130,130}},
        }

        local function applyThemeAndSave()
            ApplyTheme(MainFrame)
            SaveAll()
        end

        local function colorBtn(label, rgb)
            local b = Instance.new("TextButton")
            b.Size = UDim2.new(1, -8, 0, 28)
            b.BackgroundColor3 = Color3.fromRGB(60,60,60)
            b.Text = label
            b.TextColor3 = Color3.fromRGB(255,255,255)
            b.Font = Enum.Font.SourceSansBold
            b.TextSize = 16
            b.Parent = Scroll
            local uc = Instance.new("UICorner"); uc.CornerRadius = UDim.new(0,6); uc.Parent = b
            b.MouseButton1Click:Connect(function()
                stopRGB(currentKey)
                Theme[currentKey] = rgb
                applyThemeAndSave()
            end)
            return b
        end

        for _, p in ipairs(palette) do
            colorBtn(p.name, p.col)
        end

        local RGBBtn = colorBtn("Colorido (RGB)", {255,255,255})
        RGBBtn.Name = "RGBBtn"
        RGBBtn.MouseButton1Click:Connect(function()
            startRGB(currentKey, function() ApplyTheme(MainFrame) end)
            SaveAll()
        end)

        OpenTheme.MouseButton1Click:Connect(function()
            ThemeMenu.Visible = true
        end)
        CloseTheme.MouseButton1Click:Connect(function()
            ThemeMenu.Visible = false
            SaveAll()
        end)
    end

    -- ===== Info =====
    do
        local TitleI = Instance.new("TextLabel")
        TitleI.Size = UDim2.new(1, -10, 0, 28)
        TitleI.Position = UDim2.new(0, 10, 0, 8)
        TitleI.BackgroundTransparency = 1
        TitleI.Text = "Info"
        TitleI.TextColor3 = C3(Theme.Text)
        TitleI.Font = Enum.Font.SourceSansBold
        TitleI.TextSize = 18
        TitleI.Parent = PInfo

        local Insta = Instance.new("TextLabel")
        Insta.Size = UDim2.new(1, -20, 0, 20)
        Insta.Position = UDim2.new(0, 10, 0, 44)
        Insta.BackgroundTransparency = 1
        Insta.Text = "Instagram: @Luiz_1sst"
        Insta.TextColor3 = C3(Theme.Text)
        Insta.Font = Enum.Font.SourceSans
        Insta.TextSize = 14
        Insta.TextXAlignment = Enum.TextXAlignment.Left
        Insta.Parent = PInfo

        local Legend = Instance.new("TextLabel")
        Legend.Size = UDim2.new(0.9, 0, 0, 20)
        Legend.Position = UDim2.new(0, 10, 0, 70)
        Legend.BackgroundTransparency = 1
        Legend.Text = "Condições: 🟢 Seguro | 🟡 Baixo risco | 🔴 Alto risco"
        Legend.TextColor3 = C3(Theme.Text)
        Legend.Font = Enum.Font.SourceSans
        Legend.TextSize = 14
        Legend.TextXAlignment = Enum.TextXAlignment.Left
        Legend.Parent = PInfo

        local CondCircle = Instance.new("Frame")
        CondCircle.Name = "CondCircle"
        CondCircle.Size = UDim2.new(0, 18, 0, 18)
        CondCircle.Position = UDim2.new(0, 10, 0, 98)
        CondCircle.BackgroundColor3 = Color3.fromRGB(0,200,0)
        CondCircle.Parent = PInfo
        local RoundCond = Instance.new("UICorner"); RoundCond.CornerRadius = UDim.new(1,0); RoundCond.Parent = CondCircle

        local CondTxt = Instance.new("TextLabel")
        CondTxt.Size = UDim2.new(0.7, 0, 0, 20)
        CondTxt.Position = UDim2.new(0, 34, 0, 98)
        CondTxt.BackgroundTransparency = 1
        CondTxt.Text = "Condição de uso"
        CondTxt.TextColor3 = C3(Theme.Text)
        CondTxt.Font = Enum.Font.SourceSans
        CondTxt.TextSize = 14
        CondTxt.TextXAlignment = Enum.TextXAlignment.Left
        CondTxt.Parent = PInfo

        local function UpdateConditionInfo()
            if UsageCondition == "Safe" then
                CondCircle.BackgroundColor3 = Color3.fromRGB(0,200,0)
            elseif UsageCondition == "LowRisk" then
                CondCircle.BackgroundColor3 = Color3.fromRGB(200,200,0)
            else
                CondCircle.BackgroundColor3 = Color3.fromRGB(200,0,0)
            end
        end
        PInfo:SetAttribute("UpdateCond", true)
        PInfo:GetAttributeChangedSignal("UpdateCond"):Connect(UpdateConditionInfo)
        UpdateConditionInfo()
    end

    -- ===== Secret (Admin) — mantém o painel, mas o login é só por Key GitHub =====
    do
        local TitleS = Instance.new("TextLabel")
        TitleS.Size = UDim2.new(1, -10, 0, 28)
        TitleS.Position = UDim2.new(0, 10, 0, 8)
        TitleS.BackgroundTransparency = 1
        TitleS.Text = "Secret (Admin)"
        TitleS.TextColor3 = C3(Theme.Text)
        TitleS.Font = Enum.Font.SourceSansBold
        TitleS.TextSize = 18
        TitleS.Parent = PSecret

        local AdminPanel = Instance.new("Frame")
        AdminPanel.Name = "AdminPanel"
        AdminPanel.Size = UDim2.new(1, -20, 0, 44)
        AdminPanel.Position = UDim2.new(0, 10, 0, 44)
        AdminPanel.BackgroundColor3 = Color3.fromRGB(28,28,28)
        AdminPanel.Parent = PSecret
        local UCAp = Instance.new("UICorner"); UCAp.CornerRadius = UDim.new(0, 10); UCAp.Parent = AdminPanel

        local SafeBtn = Instance.new("TextButton")
        SafeBtn.Size = UDim2.new(0, 84, 0, 28)
        SafeBtn.Position = UDim2.new(0, 6, 0, 8)
        SafeBtn.BackgroundColor3 = Color3.fromRGB(0,180,0)
        SafeBtn.Text = "Seguro"
        SafeBtn.TextColor3 = Color3.fromRGB(255,255,255)
        SafeBtn.Font = Enum.Font.SourceSansBold
        SafeBtn.TextSize = 14
        SafeBtn.Parent = AdminPanel

        local LowBtn = Instance.new("TextButton")
        LowBtn.Size = UDim2.new(0, 110, 0, 28)
        LowBtn.Position = UDim2.new(0, 98, 0, 8)
        LowBtn.BackgroundColor3 = Color3.fromRGB(200,200,0)
        LowBtn.Text = "Baixo risco"
        LowBtn.TextColor3 = Color3.fromRGB(0,0,0)
        LowBtn.Font = Enum.Font.SourceSansBold
        LowBtn.TextSize = 14
        LowBtn.Parent = AdminPanel

        local HighBtn = Instance.new("TextButton")
        HighBtn.Size = UDim2.new(0, 110, 0, 28)
        HighBtn.Position = UDim2.new(0, 218, 0, 8)
        HighBtn.BackgroundColor3 = Color3.fromRGB(200,0,0)
        HighBtn.Text = "Alto risco"
        HighBtn.TextColor3 = Color3.fromRGB(255,255,255)
        HighBtn.Font = Enum.Font.SourceSansBold
        HighBtn.TextSize = 14
        HighBtn.Parent = AdminPanel

        local function UpdateInfoPanels()
            -- Atualiza Info
            local infoPanel = Panels.Content and Panels.Content:FindFirstChild("PInfo")
            local circle = infoPanel and infoPanel:FindFirstChild("CondCircle")
            if circle then
                if UsageCondition == "Safe" then
                    circle.BackgroundColor3 = Color3.fromRGB(0,200,0)
                elseif UsageCondition == "LowRisk" then
                    circle.BackgroundColor3 = Color3.fromRGB(200,200,0)
                else
                    circle.BackgroundColor3 = Color3.fromRGB(200,0,0)
                end
            end
            -- Atualiza Config mini indicador
            local pc = Panels.Content and Panels.Content:FindFirstChild("PConf")
            if pc and pc:FindFirstChild("CondMini") then
                local c = pc.CondMini
                if UsageCondition == "Safe" then c.BackgroundColor3 = Color3.fromRGB(0,200,0)
                elseif UsageCondition == "LowRisk" then c.BackgroundColor3 = Color3.fromRGB(200,200,0)
                else c.BackgroundColor3 = Color3.fromRGB(200,0,0) end
            end
        end

        local function setCond(c)
            UsageCondition = c
            UpdateInfoPanels()
            SaveAll()
        end

        SafeBtn.MouseButton1Click:Connect(function() setCond("Safe") end)
        LowBtn.MouseButton1Click:Connect(function() setCond("LowRisk") end)
        HighBtn.MouseButton1Click:Connect(function() setCond("HighRisk") end)
    end

    -- ===== Config =====
    do
        local TitleC = Instance.new("TextLabel")
        TitleC.Size = UDim2.new(1, -10, 0, 28)
        TitleC.Position = UDim2.new(0, 10, 0, 8)
        TitleC.BackgroundTransparency = 1
        TitleC.Text = "Configurações"
        TitleC.TextColor3 = C3(Theme.Text)
        TitleC.Font = Enum.Font.SourceSansBold
        TitleC.TextSize = 18
        TitleC.Parent = PConf

        local ResetBtn = Instance.new("TextButton")
        ResetBtn.Size = UDim2.new(0.5, 0, 0, 30)
        ResetBtn.Position = UDim2.new(0, 10, 0, 44)
        ResetBtn.BackgroundColor3 = Color3.fromRGB(200,50,50)
        ResetBtn.Text = "Restaurar Padrão"
        ResetBtn.TextColor3 = C3(Theme.Text)
        ResetBtn.Font = Enum.Font.SourceSansBold
        ResetBtn.TextSize = 16
        ResetBtn.Parent = PConf
        local UCReset = Instance.new("UICorner"); UCReset.CornerRadius = UDim.new(0,8); UCReset.Parent = ResetBtn

        local Ver = Instance.new("TextLabel")
        Ver.Size = UDim2.new(0.35, 0, 0, 20)
        Ver.Position = UDim2.new(0.55, 0, 0, 44)
        Ver.BackgroundTransparency = 1
        Ver.Text = "Versão: "..VERSION
        Ver.TextColor3 = C3(Theme.Text)
        Ver.Font = Enum.Font.SourceSans
        Ver.TextSize = 14
        Ver.TextXAlignment = Enum.TextXAlignment.Left
        Ver.Parent = PConf

        local CondMini = Instance.new("Frame")
        CondMini.Name = "CondMini"
        CondMini.Size = UDim2.new(0, 16, 0, 16)
        CondMini.Position = UDim2.new(0.55, 0, 0, 66)
        CondMini.BackgroundColor3 = Color3.fromRGB(0,200,0)
        CondMini.Parent = PConf
        local RoundMini = Instance.new("UICorner"); RoundMini.CornerRadius = UDim.new(1,0); RoundMini.Parent = CondMini

        local CondTxt = Instance.new("TextLabel")
        CondTxt.Size = UDim2.new(0.35, 0, 0, 20)
        CondTxt.Position = UDim2.new(0.55, 22, 0, 64)
        CondTxt.BackgroundTransparency = 1
        CondTxt.Text = "Condição"
        CondTxt.TextColor3 = C3(Theme.Text)
        CondTxt.Font = Enum.Font.SourceSans
        CondTxt.TextSize = 14
        CondTxt.TextXAlignment = Enum.TextXAlignment.Left
        CondTxt.Parent = PConf

        local function SyncMini()
            if UsageCondition == "Safe" then
                CondMini.BackgroundColor3 = Color3.fromRGB(0,200,0)
            elseif UsageCondition == "LowRisk" then
                CondMini.BackgroundColor3 = Color3.fromRGB(200,200,0)
            else
                CondMini.BackgroundColor3 = Color3.fromRGB(200,0,0)
            end
        end
        SyncMini()

        ResetBtn.MouseButton1Click:Connect(function()
            getgenv().AutoGenEnabled = false
            getgenv().AutoGenDelay = 2.0
            UsageCondition = "Safe"
            Theme = {
                Bg={20,20,20}, Text={255,255,255}, Accent={0,170,255}, Button={60,60,60},
                Flags={BgRGB=false,TextRGB=false,AccentRGB=false,ButtonRGB=false}
            }
            ApplyTheme(MainFrame)
            SyncMini()
            -- Info circle
            local circle = Panels.Content.PInfo and Panels.Content.PInfo:FindFirstChild("CondCircle")
            if circle then circle.BackgroundColor3 = Color3.fromRGB(0,200,0) end
            SaveAll()
        end)
    end

    -- Tabs
    local function openFun()   show(PFun)   end
    local function openTheme() show(PTheme) end
    local function openInfo()  show(PInfo)  end
    local function openSecret()show(PSecret)end
    local function openConf()  show(PConf)  end

    -- liga botões
    BTN_FUN.MouseButton1Click:Connect(openFun)
    BTN_THEME.MouseButton1Click:Connect(openTheme)
    BTN_INFO.MouseButton1Click:Connect(openInfo)
    BTN_SECRET.MouseButton1Click:Connect(openSecret)
    BTN_CONF.MouseButton1Click:Connect(openConf)

    -- Iniciar com Funções
    show(PFun)
    ApplyTheme(MainFrame)
end

-- ========================= LOGIN LÓGICA (SOMENTE KEY DO GITHUB) =========================
local function TryLogin()
    LoginButton.Text = "Verificando..."
    LoginButton.AutoButtonColor = false
    local typed = PasswordBox.Text or ""

    -- Busca a key remota (com cache curto)
    local remoteKey, err = fetchRemoteKey(false)
    if not remoteKey then
        LoginButton.Text = "Falha ao buscar key"
        LoginTitle.Text = "Erro: "..(err or "desconhecido")
        LoginTitle.TextColor3 = Color3.fromRGB(255,0,0)
        task.delay(2.0, function()
            if LoginButton then LoginButton.Text = "Entrar" end
            if LoginTitle then
                LoginTitle.Text = "Login - 07AstarothGui"
                LoginTitle.TextColor3 = C3(Theme.Text)
            end
        end)
        return
    end

    if trim(typed) == trim(remoteKey) then
        if UseSavedPassword then
            SavedPassword = typed
        else
            SavedPassword = ""
        end
        SaveAll()

        LoginFrame.Visible = false
        BuildMain()
    else
        LoginButton.Text = "Entrar"
        LoginTitle.Text = "Key incorreta!"
        LoginTitle.TextColor3 = Color3.fromRGB(255,0,0)
        task.delay(1.6, function()
            if LoginTitle then
                LoginTitle.Text = "Login - 07AstarothGui"
                LoginTitle.TextColor3 = C3(Theme.Text)
            end
        end)
    end
end

LoginButton.MouseButton1Click:Connect(TryLogin)

-- Preenche com key salva, se houver
if UseSavedPassword and SavedPassword and SavedPassword ~= "" then
    PasswordBox.Text = SavedPassword
end

-- Aplica tema inicial ao login também
ApplyTheme(LoginFrame)

-- 🔑 Sistema de exibição da key atual + botão copiar
local ShowKeyButton = Instance.new("TextButton")
ShowKeyButton.Size = UDim2.new(0.8, 0, 0, 30)
ShowKeyButton.Position = UDim2.new(0.1, 0, 0, 200) -- logo abaixo do botão Entrar, dentro do LoginFrame
ShowKeyButton.Text = "🔑 Mostrar Key Atual"
ShowKeyButton.BackgroundColor3 = Color3.fromRGB(0,180,0)
ShowKeyButton.TextColor3 = Color3.fromRGB(255,255,255)
ShowKeyButton.Font = Enum.Font.SourceSansBold
ShowKeyButton.TextSize = 16
ShowKeyButton.Parent = LoginFrame
local UICornerShow = Instance.new("UICorner"); UICornerShow.CornerRadius = UDim.new(0, 8); UICornerShow.Parent = ShowKeyButton

-- Label para exibir a key
local KeyLabel = Instance.new("TextLabel")
KeyLabel.Size = UDim2.new(0.65, 0, 0, 24)
KeyLabel.Position = UDim2.new(0.1, 0, 0, 240) -- ajustado para acompanhar dentro do LoginFrame
KeyLabel.BackgroundTransparency = 1
KeyLabel.Text = ""
KeyLabel.TextColor3 = Color3.fromRGB(0,255,0)
KeyLabel.Font = Enum.Font.SourceSansBold
KeyLabel.TextSize = 14
KeyLabel.Parent = LoginFrame

-- Botão 📑 copiar
local CopyKeyButton = Instance.new("TextButton")
CopyKeyButton.Size = UDim2.new(0, 40, 0, 24)
CopyKeyButton.Position = UDim2.new(0.8, 0, 0, 220)
CopyKeyButton.Text = "📑"
CopyKeyButton.BackgroundColor3 = Color3.fromRGB(50,50,50)
CopyKeyButton.TextColor3 = Color3.fromRGB(255,255,255)
CopyKeyButton.Font = Enum.Font.SourceSansBold
CopyKeyButton.TextSize = 16
CopyKeyButton.Parent = LoginFrame
local UICornerCopy = Instance.new("UICorner"); UICornerCopy.CornerRadius = UDim.new(0, 6); UICornerCopy.Parent = CopyKeyButton

-- Evento do botão mostrar key
ShowKeyButton.MouseButton1Click:Connect(function()
    local success, result = pcall(function()
        return game:HttpGet("https://raw.githubusercontent.com/07PkAstarothBR/07PkAstarothBRscripts/main/key.lua")
    end)
    if success and result then
        local currentKey = result:match('\"(.-)\"') or result:match('"(.+)"') or result
        KeyLabel.Text = "Key: " .. tostring(currentKey)
        CopyKeyButton.MouseButton1Click:Connect(function()
            setclipboard(currentKey)
            print("[07AstarothGui] Key copiada: " .. currentKey)
        end)
    else
        KeyLabel.Text = "Erro ao carregar key"
    end
end)

-- Ajuste de tamanho do LoginFrame para comportar os novos botões
LoginFrame.Size = UDim2.new(0, 360, 0, 270)
