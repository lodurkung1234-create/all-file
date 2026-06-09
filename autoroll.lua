-- ==========================================
-- 🎨 โหลด Obsidian Library
-- ==========================================
local repo = "https://raw.githubusercontent.com/deividcomsono/Obsidian/main/"
local Library = loadstring(game:HttpGet(repo .. "Library.lua"))()
local ThemeManager = loadstring(game:HttpGet(repo .. "addons/ThemeManager.lua"))()
local SaveManager = loadstring(game:HttpGet(repo .. "addons/SaveManager.lua"))()

local Options = Library.Options
local Toggles = Library.Toggles

local Window = Library:CreateWindow({
    Title = "Auto Roll & Smart Buy (PRO VERSION)",
    Footer = "PRO Edition",
    ShowCustomCursor = true,
    AutoShow = true,
})

local Tabs = {
    Main = Window:AddTab("Auto Roll", "play"),
    Buy = Window:AddTab("Auto Buy", "shopping-cart"),
    Webhook = Window:AddTab("Webhook", "bell"),
    Debug = Window:AddTab("Debug", "settings"),
    ["UI Settings"] = Window:AddTab("UI Settings", "settings"),
}

local RollGroup = Tabs.Main:AddLeftGroupbox("Auto Roll")
local StatusGroup = Tabs.Main:AddRightGroupbox("สถานะ")
local BuyGroup = Tabs.Buy:AddLeftGroupbox("ตั้งค่าการซื้อ")
local ListGroup = Tabs.Buy:AddRightGroupbox("รายการที่บันทึก")
local WebhookGroup = Tabs.Webhook:AddLeftGroupbox("Discord Webhook")
local WebhookLogGroup = Tabs.Webhook:AddRightGroupbox("Log การแจ้งเตือน")
local DebugGroup = Tabs.Debug:AddLeftGroupbox("Debug Priority")

local UI_StatusLabel = StatusGroup:AddLabel("สถานะ: หยุดทำงาน")
-- แสดงรายการแบบ dropdown แทน label เพื่อไม่ให้ล้นกรอบ
local UI_WebhookLog = WebhookLogGroup:AddLabel("ยังไม่มีการแจ้งเตือน")
ListGroup:AddDropdown("ListDropdown", { Text = "รายการทั้งหมด", Values = {"(ไม่มีรายการ)"}, Default = 1, Callback = function() end })

-- ==========================================
-- 🛡️ Anti-AFK
-- ==========================================
task.spawn(function()
    local VirtualUser = game:GetService("VirtualUser")
    game:GetService("Players").LocalPlayer.Idled:Connect(function()
        VirtualUser:CaptureController()
        VirtualUser:ClickButton2(Vector2.new())
        print("[Anti-AFK] ป้องกันการหลุดออกจากเซิร์ฟเวอร์!")
    end)
end)

-- ==========================================
-- ⚙️ ค่าเริ่มต้นระบบ
-- ==========================================
-- ใช้ local แทน getgenv() ป้องกัน shared ข้าม instance
local Config = { 
    AutoRoll = false, 
    RollDelay = 1, 
    MasterAutoBuy = false, 
    GodPriority = false,
    SecretPriority = false,
    MutDragonborn = false,
    MutBeast = false,
    MutArrancar = false,
    WebhookURL = "",
    WebhookEnabled = false,
}
local BuyList = {}
local TempName, TempRarity, TempMut = "Any", "Any", "Any"
local SelectedDeleteIndex = 1

local WaitingForPriority = false 
local CurrentPriorityLevel = 0 
local CurrentPriorityUnit = nil
local PriorityTargetName = ""

-- ==========================================
-- 💰 Helper Functions
-- ==========================================
local function parsePrice(text)
    if not text then return 0 end
    local ok, result = pcall(function()
        local clean = text:gsub("%$", ""):gsub(",", ""):gsub(" ", "")
        local num, suffix = clean:match("([%d%.]+)([KkMmBb]?)")
        num = tonumber(num) or 0
        suffix = suffix and suffix:upper() or ""
        if suffix == "K" then num = num * 1000
        elseif suffix == "M" then num = num * 1000000
        elseif suffix == "B" then num = num * 1000000000 end
        return num
    end)
    return ok and result or 0
end

local function getMoney()
    local cashLabel = game.Players.LocalPlayer.PlayerGui.MainUI.Frames.Cash.Amount
    if cashLabel then return parsePrice(cashLabel.Text) end
    return 0
end

local function getMyPlot()
    local player = game.Players.LocalPlayer
    for _, plot in pairs(workspace.Plots:GetChildren()) do
        local misc = plot:FindFirstChild("Misc")
        if misc then
            local billboard = misc:FindFirstChild("Billboard")
            if billboard then
                local bg = billboard:FindFirstChildWhichIsA("BillboardGui")
                if bg then
                    local text = bg:FindFirstChildWhichIsA("TextLabel")
                    -- exact match เท่านั้น ป้องกัน "Locky" match "Lockyyyyyyyy"
                    local t = text.Text:gsub("'s Base", ""):gsub("%s+", "")
                    local dn = player.DisplayName:gsub("%s+", "")
                    local pn = player.Name:gsub("%s+", "")
                    if t == dn or t == pn then
                        return plot
                    end
                end
            end
        end
    end
    return nil
end

local function getUnits()
    local names = {"Any"}
    local RS = game:GetService("ReplicatedStorage")
    local targetModule = RS:FindFirstChild("CharactersInfo", true) or RS:FindFirstChild("CharacterLevelInfo", true)
    if targetModule and targetModule:IsA("ModuleScript") then
        local success, rawData = pcall(function() return require(targetModule) end)
        if success and type(rawData) == "table" then
            local mainData = rawData["Characters"] or rawData
            for _, tierContent in pairs(mainData) do
                if type(tierContent) == "table" then
                    for charName, _ in pairs(tierContent) do
                        if type(charName) == "string" then table.insert(names, charName) end
                    end
                end
            end
        end
    end
    table.sort(names)
    return names
end

local function updateUI()
    -- แสดงรายการผ่าน dropdown เท่านั้น (ไม่ใช้ label เพราะล้นกรอบ)
    local opts = #BuyList == 0 and {"(ไม่มีรายการ)"} or {}
    for i, v in ipairs(BuyList) do
        table.insert(opts, string.format("%d. %s | %s | %s", i, tostring(v.Name), tostring(v.Rarity), tostring(v.Mutation)))
    end
    Options.DeleteDropdown:SetValues(opts)
    Options.ListDropdown:SetValues(opts)
    SelectedDeleteIndex = 1
end

-- ==========================================
-- 🔔 Discord Webhook
-- ==========================================
local webhookLogLines = {}

local function sendWebhook(unitName, rarity, mutation, price)
    if not Config.WebhookEnabled then return end
    local url = Config.WebhookURL
    if not url or url == "" then return end

    local player = game.Players.LocalPlayer
    local timestamp = os.date("%H:%M:%S")

    -- อัปเดต log ใน UI
    table.insert(webhookLogLines, 1, string.format("[%s] ✅ %s | %s | %s", timestamp, unitName, rarity, mutation))
    if #webhookLogLines > 5 then table.remove(webhookLogLines) end
    UI_WebhookLog:SetText(table.concat(webhookLogLines, "\n"))

    task.spawn(function()
        local HttpService = game:GetService("HttpService")
        local body = HttpService:JSONEncode({
            embeds = {{
                title = "✅ ซื้อตัวละครสำเร็จ!",
                color = 5814783,
                fields = {
                    { name = "👤 ตัวละคร", value = unitName, inline = true },
                    { name = "⭐ Rarity", value = rarity, inline = true },
                    { name = "💎 Mutation", value = mutation, inline = true },
                    { name = "💰 ราคา", value = tostring(price), inline = true },
                    { name = "🎮 ผู้เล่น", value = player.Name, inline = true },
                    { name = "🕐 เวลา", value = timestamp, inline = true },
                },
                footer = { text = "Auto Roll PRO" }
            }}
        })
        pcall(function()
            game:HttpGet(url .. " POST " .. body) -- placeholder: ใช้ syn.request หรือ http.request ตาม executor
        end)
        -- สำหรับ executor ที่รองรับ request():
        pcall(function()
            if request then
                request({
                    Url = url,
                    Method = "POST",
                    Headers = { ["Content-Type"] = "application/json" },
                    Body = body
                })
            elseif syn and syn.request then
                syn.request({
                    Url = url,
                    Method = "POST",
                    Headers = { ["Content-Type"] = "application/json" },
                    Body = body
                })
            end
        end)
    end)
end

-- ==========================================
-- 🛒 tryBuyChar [แก้ไข: หา Prompt ทั้ง model + log]
-- ==========================================
local function walkToPlot()
    local myPlot = getMyPlot()
    if not myPlot then return end
    local player = game.Players.LocalPlayer
    local char = player.Character
    if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hrp or not hum then return end

    -- หาตำแหน่ง plot
    local plotHRP = myPlot:FindFirstChild("HumanoidRootPart", true)
        or myPlot:FindFirstChild("Base", true)
        or myPlot.PrimaryPart
    if not plotHRP then return end

    -- เดินไปหา plot
    hum:MoveTo(plotHRP.Position)
    local dist = (hrp.Position - plotHRP.Position).Magnitude
    local timeout = 0
    while dist > 10 and timeout < 5 do
        task.wait(0.2)
        dist = (hrp.Position - plotHRP.Position).Magnitude
        timeout = timeout + 0.2
    end
end

local function tryBuyChar(charModel, unitName, rarity, mutation, price)
    -- เดินไปหา plot ก่อนซื้อ
    walkToPlot()

    local prompt = charModel:FindFirstChildWhichIsA("ProximityPrompt", true)
    if prompt then
        local oldDist = prompt.MaxActivationDistance
        prompt.MaxActivationDistance = 9999
        fireproximityprompt(prompt)
        task.wait(0.1)
        prompt.MaxActivationDistance = oldDist
        UI_StatusLabel:SetText("สถานะ: ✅ ซื้อ " .. (unitName or "?") .. " สำเร็จ!")
        sendWebhook(unitName or "Unknown", rarity or "?", mutation or "?", price or 0)
        print("[AutoBuy] ✅ ซื้อสำเร็จ:", unitName, rarity, mutation)
        return true
    end
    UI_StatusLabel:SetText("สถานะ: ❌ ซื้อไม่ได้ ไม่เจอ Prompt")
    print("[AutoBuy] ❌ ไม่เจอ ProximityPrompt ใน", charModel.Name)
    return false
end

-- ==========================================
-- 👑 Global Buyer Loop [แก้ไขแล้ว]
-- ==========================================
task.spawn(function()
    while true do
        if WaitingForPriority then
            if CurrentPriorityUnit and CurrentPriorityUnit.Parent then
                local charModel = CurrentPriorityUnit
                local priceLabel = charModel:FindFirstChild("Price", true)
                local price = (priceLabel and priceLabel.Text) and parsePrice(priceLabel.Text) or 0
                local currentMoney = getMoney()

                if currentMoney >= price then
                    UI_StatusLabel:SetText("สถานะ: เงินพอแล้ว! กำลังซื้อ " .. PriorityTargetName .. "...")
                    tryBuyChar(charModel, PriorityTargetName, "Priority", "Priority", price)
                    WaitingForPriority = false
                    CurrentPriorityLevel = 0
                    CurrentPriorityUnit = nil
                else
                    UI_StatusLabel:SetText(string.format(
                        "สถานะ: ⏸ รอเงินซื้อ %s... (%.1fK / %.1fK) [Roll หยุดชั่วคราว]",
                        PriorityTargetName, currentMoney/1000, price/1000
                    ))
                end
            else
                UI_StatusLabel:SetText("สถานะ: " .. PriorityTargetName .. " หายไปแล้ว กำลัง Roll ต่อ...")
                WaitingForPriority = false
                CurrentPriorityLevel = 0
                CurrentPriorityUnit = nil
            end
        end
        task.wait(0.5)
    end
end)

-- ==========================================
-- 🎯 Smart Priority Tiers
-- ==========================================
local function handlePriorityUnit(charModel, rarityText, mutationText)
    local unitLevel = 0
    local targetName = ""

    if Config.SecretPriority and rarityText == "Secret" then
        if (mutationText == "Dragonborn" and Config.MutDragonborn) or
           (mutationText == "Beast" and Config.MutBeast) or
           (mutationText == "Arrancar" and Config.MutArrancar) then
            unitLevel = 1
            targetName = "Secret (" .. mutationText .. ")"
        end
    end

    if Config.GodPriority and rarityText == "God" then
        unitLevel = 2
        targetName = "God"
    end

    if unitLevel > CurrentPriorityLevel then
        CurrentPriorityLevel = unitLevel
        CurrentPriorityUnit = charModel
        PriorityTargetName = targetName
        WaitingForPriority = true
    end
end

-- ==========================================
-- 🚀 Auto Roll Tab
-- ==========================================
RollGroup:AddToggle("AutoRollToggle", {
    Text = "เปิด Auto Roll",
    Default = false,
    Callback = function(V)
        Config.AutoRoll = V
        if V then
            task.spawn(function()
                while Config.AutoRoll do
                    if WaitingForPriority then
                        UI_StatusLabel:SetText("สถานะ: ⏸ หยุด Roll รอซื้อ " .. PriorityTargetName)
                        task.wait(0.5)
                        continue
                    end
                    UI_StatusLabel:SetText("สถานะ: กำลัง Roll...")
                    local myPlot = getMyPlot()
                    if myPlot then
                        local prompt = myPlot:FindFirstChild("RollPrompt", true)
                        if prompt then fireproximityprompt(prompt) end
                    end
                    task.wait(Config.RollDelay)
                end
                UI_StatusLabel:SetText("สถานะ: หยุดทำงาน")
            end)
        else
            WaitingForPriority = false
            CurrentPriorityLevel = 0
            CurrentPriorityUnit = nil
            UI_StatusLabel:SetText("สถานะ: หยุดทำงาน")
        end
    end
})

RollGroup:AddSlider("RollDelay", { Text = "ความเร็ว Roll", Default = 1, Min = 0.1, Max = 3, Rounding = 1, Callback = function(V) Config.RollDelay = V end })
RollGroup:AddDivider()

RollGroup:AddToggle("GodPriorityToggle", {
    Text = "God Priority (ระดับสูงสุด!)",
    Default = false,
    Callback = function(V) 
        Config.GodPriority = V 
        if not V and CurrentPriorityLevel == 2 then 
            WaitingForPriority = false
            CurrentPriorityLevel = 0
        end
    end
})

RollGroup:AddToggle("SecretPriorityToggle", {
    Text = "Secret Priority (รอซื้อ Secret)",
    Default = false,
    Callback = function(V) 
        Config.SecretPriority = V 
        if not V and CurrentPriorityLevel == 1 then 
            WaitingForPriority = false
            CurrentPriorityLevel = 0
        end
    end
})

RollGroup:AddLabel("เลือก Mutation สำหรับ Secret Priority:")
RollGroup:AddToggle("MutArrancarToggle", { Text = "✔️ Arrancar (สีม่วง)", Default = false, Callback = function(V) Config.MutArrancar = V end })
RollGroup:AddToggle("MutBeastToggle", { Text = "✔️ Beast (สีแดง)", Default = false, Callback = function(V) Config.MutBeast = V end })
RollGroup:AddToggle("MutDragonbornToggle", { Text = "✔️ Dragonborn (สีทอง)", Default = false, Callback = function(V) Config.MutDragonborn = V end })

-- ==========================================
-- 🛒 Auto Buy Tab
-- ==========================================
BuyGroup:AddDropdown("UnitDropdown", { Text = "ชื่อตัวละคร", Values = getUnits(), Default = 1, Searchable = true, Callback = function(V) TempName = V end })
BuyGroup:AddDropdown("RarityDropdown", { Text = "ระดับ (Rarity)", Values = {"Any", "Common", "Rare", "Epic", "Legendary", "Mythic", "Secret", "God"}, Default = 1, Callback = function(V) TempRarity = V end })
BuyGroup:AddDropdown("MutationDropdown", { Text = "Mutation", Values = {"Any", "Normal", "Gold", "Diamond", "Dragonborn", "Beast", "Arrancar", "Admin"}, Default = 1, Callback = function(V) TempMut = V end })

BuyGroup:AddButton({ Text = "เพิ่มรายการ", Func = function() table.insert(BuyList, { Name = TempName, Rarity = TempRarity, Mutation = TempMut }) updateUI() end })
BuyGroup:AddDivider()
BuyGroup:AddToggle("AutoBuyToggle", { Text = "เปิดระบบ Auto Buy", Default = false, Callback = function(V) Config.MasterAutoBuy = V end })
BuyGroup:AddDivider()

BuyGroup:AddDropdown("DeleteDropdown", { 
    Text = "เลือกรายการที่จะลบ", 
    Values = {"(ไม่มีรายการ)"}, 
    Default = 1, 
    Callback = function(V) 
        if type(V) ~= "string" then return end 
        local idx = tonumber(V:match("^(%d+)%.")) 
        if idx then SelectedDeleteIndex = idx end 
    end 
})
BuyGroup:AddButton({ Text = "ลบรายการที่เลือก", Func = function() local idx = SelectedDeleteIndex if #BuyList == 0 then return end if idx >= 1 and idx <= #BuyList then table.remove(BuyList, idx) updateUI() end end })
BuyGroup:AddButton({ Text = "ลบทั้งหมด", Func = function() BuyList = {} updateUI() end })

-- ==========================================
-- 🔔 Webhook Tab
-- ==========================================
WebhookGroup:AddToggle("WebhookEnabledToggle", {
    Text = "เปิดการแจ้งเตือน Discord",
    Default = false,
    Callback = function(V)
        Config.WebhookEnabled = V
    end
})

WebhookGroup:AddDivider()

WebhookGroup:AddInput("WebhookURLInput", {
    Text = "Discord Webhook URL",
    Default = "",
    Numeric = false,
    Finished = true,  -- อัปเดตเมื่อกด Enter
    Placeholder = "https://discord.com/api/webhooks/...",
    Callback = function(V)
        Config.WebhookURL = V
    end
})

WebhookGroup:AddButton({ 
    Text = "🧪 ทดสอบ Webhook", 
    Func = function()
        if Config.WebhookURL == "" then
            UI_WebhookLog:SetText("❌ กรุณาใส่ Webhook URL ก่อน")
            return
        end
        sendWebhook("TestUnit", "God", "Dragonborn", 999000)
        UI_WebhookLog:SetText("📤 ส่งทดสอบแล้ว ตรวจสอบ Discord ได้เลย")
    end 
})

WebhookGroup:AddDivider()
WebhookGroup:AddLabel("📋 วิธีใช้:")
WebhookGroup:AddLabel("1. เปิด Discord → Server Settings")
WebhookGroup:AddLabel("2. Integrations → Webhooks → New")
WebhookGroup:AddLabel("3. Copy URL แล้วใส่ในช่องด้านบน")
WebhookGroup:AddLabel("4. กด Enter แล้วกดทดสอบ")

-- ==========================================
-- 📡 Core Event Listener [แก้ไข task.wait + checkAndBuy]
-- ==========================================
local function checkAndBuy(charModel, name, rarity, mutation, price)
    if not Config.MasterAutoBuy then return end
    -- แก้ไข: ไม่ซื้อถ้ากำลังรอ Priority อยู่
    if WaitingForPriority then return end
    for _, item in ipairs(BuyList) do
        if (item.Name == "Any" or name == item.Name) and
           (item.Rarity == "Any" or rarity == item.Rarity) and
           (item.Mutation == "Any" or mutation == item.Mutation) then
            tryBuyChar(charModel, name, rarity, mutation, price)
            break
        end
    end
end

-- ==========================================
-- 📡 Listen เฉพาะ plot ของตัวเองเท่านั้น
-- ==========================================
task.spawn(function()
    -- รอจนหา plot ของตัวเองเจอก่อน
    local myPlot = nil
    repeat
        myPlot = getMyPlot()
        task.wait(1)
    until myPlot

    local charsFolder = myPlot:FindFirstChild("Characters") or myPlot:WaitForChild("Characters", 5)
    if not charsFolder then return end

    charsFolder.ChildAdded:Connect(function(char)
        -- รอ Head > CharacterUI > Frame โหลดเข้ามาจริงๆ
        local frame = nil
        local tries = 0
        repeat
            local head = char:FindFirstChild("Head")
            local charUI = head and head:FindFirstChild("CharacterUI")
            frame = charUI and charUI:FindFirstChild("Frame")
            if not frame then task.wait(0.1) end
            tries = tries + 1
        until frame or tries >= 15

        if frame then
            local uName = char.Name
            local rarityLabel = frame:FindFirstChild("Rarity")
            local mutLabel = frame:FindFirstChild("Mutation")
            local uRarity = rarityLabel and rarityLabel.Text or "Normal"
            local uMut = (mutLabel and mutLabel.Visible) and mutLabel.Text or "Normal"
            local priceLabel = frame:FindFirstChild("Price")
            local uPrice = (priceLabel and priceLabel.Text) and parsePrice(priceLabel.Text) or 0

            print("[Debug] Name:", uName, "| Rarity:", uRarity, "| Mut:", uMut, "| Price:", uPrice)

            checkAndBuy(char, uName, uRarity, uMut, uPrice)
            handlePriorityUnit(char, uRarity, uMut)
        end
    end)
end)

-- ==========================================
-- 🧪 Debug Priority Tab
-- ==========================================
DebugGroup:AddLabel("กดปุ่มด้านล่างเพื่อจำลอง Priority")
DebugGroup:AddDivider()

DebugGroup:AddButton({
    Text = "จำลอง: เจอ God ใน Plot",
    Func = function()
        local myPlot = getMyPlot()
        if not myPlot then
            UI_StatusLabel:SetText("สถานะ: [Debug] ไม่เจอ plot ของตัวเอง")
            return
        end
        local charsFolder = myPlot:FindFirstChild("Characters")
        local firstChar = charsFolder and charsFolder:GetChildren()[1]
        if not firstChar then
            UI_StatusLabel:SetText("สถานะ: [Debug] ไม่มีตัวใน plot ลอง Roll ก่อน")
            return
        end
        CurrentPriorityLevel = 2
        CurrentPriorityUnit = firstChar
        PriorityTargetName = "God [DEBUG:" .. firstChar.Name .. "]"
        WaitingForPriority = true
        UI_StatusLabel:SetText("สถานะ: [Debug] จำลอง God = " .. firstChar.Name)
    end
})

DebugGroup:AddButton({
    Text = "จำลอง: เจอ Secret ใน Plot",
    Func = function()
        local myPlot = getMyPlot()
        if not myPlot then
            UI_StatusLabel:SetText("สถานะ: [Debug] ไม่เจอ plot")
            return
        end
        local charsFolder = myPlot:FindFirstChild("Characters")
        local firstChar = charsFolder and charsFolder:GetChildren()[1]
        if not firstChar then
            UI_StatusLabel:SetText("สถานะ: [Debug] ไม่มีตัวใน plot")
            return
        end
        CurrentPriorityLevel = 1
        CurrentPriorityUnit = firstChar
        PriorityTargetName = "Secret [DEBUG:" .. firstChar.Name .. "]"
        WaitingForPriority = true
        UI_StatusLabel:SetText("สถานะ: [Debug] จำลอง Secret = " .. firstChar.Name)
    end
})

DebugGroup:AddDivider()

DebugGroup:AddButton({
    Text = "Reset Priority",
    Func = function()
        WaitingForPriority = false
        CurrentPriorityLevel = 0
        CurrentPriorityUnit = nil
        PriorityTargetName = ""
        UI_StatusLabel:SetText("สถานะ: [Debug] Reset Priority แล้ว")
    end
})

-- ==========================================
-- 🎨 UI Settings
-- ==========================================
local MenuGroup = Tabs["UI Settings"]:AddLeftGroupbox("Menu")
MenuGroup:AddLabel("Menu bind"):AddKeyPicker("MenuKeybind", { Default = "RightShift", NoUI = true, Text = "Menu keybind" })
MenuGroup:AddButton("Unload", function() Library:Unload() end)

ThemeManager:SetLibrary(Library)
SaveManager:SetLibrary(Library)
SaveManager:IgnoreThemeSettings()
SaveManager:SetIgnoreIndexes({"MenuKeybind", "DeleteDropdown", "WebhookURLInput"})

-- ==========================================
-- 💾 ระบบเซฟ
-- ==========================================
local HttpService = game:GetService("HttpService")

local oldSave = SaveManager.Save
SaveManager.Save = function(self, name)
    local success = oldSave(self, name) 
    if success and name then
        pcall(function()
            if not isfolder("AutoRollPRO/buylists") then 
                makefolder("AutoRollPRO/buylists") 
            end
            writefile("AutoRollPRO/buylists/" .. name .. ".json", HttpService:JSONEncode(BuyList))
            -- เซฟ webhook url แยก
            writefile("AutoRollPRO/buylists/" .. name .. "_webhook.txt", Config.WebhookURL or "")
        end)
    end
    return success
end

local oldLoad = SaveManager.Load
SaveManager.Load = function(self, name)
    local success = oldLoad(self, name) 
    if success and name then
        pcall(function()
            local path = "AutoRollPRO/buylists/" .. name .. ".json"
            if isfile(path) then
                BuyList = HttpService:JSONDecode(readfile(path))
            else
                BuyList = {}
            end
            -- โหลด webhook url
            local whPath = "AutoRollPRO/buylists/" .. name .. "_webhook.txt"
            if isfile(whPath) then
                Config.WebhookURL = readfile(whPath)
                Options.WebhookURLInput:SetValue(Config.WebhookURL)
            end
            updateUI() 
        end)
    end
    return success
end

ThemeManager:SetFolder("AutoRollPRO")
SaveManager:SetFolder("AutoRollPRO/game")
ThemeManager:ApplyToTab(Tabs["UI Settings"])
SaveManager:BuildConfigSection(Tabs["UI Settings"])
Library.ToggleKeybind = Options.MenuKeybind

-- โหลด config อัตโนมัติตอนเริ่ม
SaveManager:LoadAutoloadConfig()

-- ==========================================
-- 🌊 Auto Start Wave เมื่อเข้าเกม
-- ==========================================
task.spawn(function()
    task.wait(3) -- รอให้เกมโหลดก่อน
    local ok, err = pcall(function()
        game:GetService("ReplicatedStorage").Remotes.Start.StartWave:FireServer()
    end)
    if ok then
        print("[AutoStart] ส่ง StartWave สำเร็จ!")
    else
        print("[AutoStart] ส่งไม่ได้:", err)
    end
end)
