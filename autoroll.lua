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
    Footer = "PRO Edition - Prompt Target Fix",
    ShowCustomCursor = true,
    AutoShow = true,
})

local Tabs = {
    Main = Window:AddTab("Auto Roll", "play"),
    Buy = Window:AddTab("Auto Buy", "shopping-cart"),
    Event = Window:AddTab("Auto Event", "star"),
    Webhook = Window:AddTab("Webhook", "bell"),
    Debug = Window:AddTab("Debug", "settings"),
    ["UI Settings"] = Window:AddTab("UI Settings", "settings"),
}

local RollGroup = Tabs.Main:AddLeftGroupbox("Auto Roll")
local StatusGroup = Tabs.Main:AddRightGroupbox("สถานะ")
local BuyGroup = Tabs.Buy:AddLeftGroupbox("ตั้งค่าการซื้อ")
local ListGroup = Tabs.Buy:AddRightGroupbox("รายการที่บันทึก")
local EventGroup = Tabs.Event:AddLeftGroupbox("ตั้งค่ากิจกรรม")
local WebhookGroup = Tabs.Webhook:AddLeftGroupbox("Discord Webhook")
local WebhookLogGroup = Tabs.Webhook:AddRightGroupbox("Log การแจ้งเตือน")
local DebugGroup = Tabs.Debug:AddLeftGroupbox("Debug Tools")

local UI_StatusLabel = StatusGroup:AddLabel("สถานะ: หยุดทำงาน")
local UI_WebhookLog = WebhookLogGroup:AddLabel("ยังไม่มีการแจ้งเตือน")
ListGroup:AddDropdown("ListDropdown", { Text = "รายการทั้งหมด", Values = {"(ไม่มีรายการ)"}, Default = 1, Callback = function() end })

-- ==========================================
-- 🛡️ Anti-AFK & Anti-Purchase Popups
-- ==========================================
task.spawn(function()
    local VirtualUser = game:GetService("VirtualUser")
    game:GetService("Players").LocalPlayer.Idled:Connect(function()
        VirtualUser:CaptureController()
        VirtualUser:ClickButton2(Vector2.new())
    end)
end)

-- บล็อกไม่ให้หน้าต่างซื้อ Robux เด้ง
pcall(function()
    local MS = game:GetService("MarketplaceService")
    if hookfunction then
        hookfunction(MS.PromptPurchase, function() return end)
        hookfunction(MS.PromptProductPurchase, function() return end)
        hookfunction(MS.PromptGamePassPurchase, function() return end)
    end
end)

-- ==========================================
-- ⚙️ ค่าเริ่มต้นระบบ
-- ==========================================
local Config = { 
    AutoRoll = false, 
    RollDelay = 1, 
    MasterAutoBuy = false, 
    AutoBuharaEvent = false,
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
local IsDoingEvent = false 
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
        for _, desc in pairs(plot:GetDescendants()) do
            if desc:IsA("TextLabel") and desc.Text ~= "" then
                local t = desc.Text:gsub("'s Base", ""):gsub("%s+", "")
                local dn = player.DisplayName:gsub("%s+", "")
                local pn = player.Name:gsub("%s+", "")
                if t == dn or t == pn then return plot end
            end
        end
    end
    return nil
end

local function firePrompt(prompt)
    if prompt and prompt:IsA("ProximityPrompt") then
        local oldDist = prompt.MaxActivationDistance
        prompt.MaxActivationDistance = 9999
        fireproximityprompt(prompt)
        task.wait(0.1)
        prompt.MaxActivationDistance = oldDist
    end
end

-- ==========================================
-- 🔍 Dynamic Data Fetcher 
-- ==========================================
local function getGameData()
    local units, mutations = {}, {}
    local RS = game:GetService("ReplicatedStorage")
    local defaultMuts = {"Normal", "Gold", "Diamond", "Dragonborn", "Beast", "Arrancar", "Admin"}
    for _, v in ipairs(defaultMuts) do table.insert(mutations, v) end

    for _, obj in pairs(RS:GetDescendants()) do
        if obj:IsA("ModuleScript") and (obj.Name:find("Info") or obj.Name:find("Data") or obj.Name:find("Character")) then
            local success, data = pcall(function() return require(obj) end)
            if success and type(data) == "table" then
                if data["Characters"] then
                    for _, chars in pairs(data["Characters"]) do
                        if type(chars) == "table" then
                            for name, _ in pairs(chars) do
                                if type(name) == "string" then table.insert(units, name) end
                            end
                        end
                    end
                end
                if data["Mutations"] or obj.Name:find("Mutation") then
                    local targetData = data["Mutations"] or data
                    for k, _ in pairs(targetData) do
                        if type(k) == "string" and k ~= "Characters" then table.insert(mutations, k) end
                    end
                end
            end
        end
    end
    
    local function clean(t)
        local hash, res = {}, {}
        for _, v in ipairs(t) do if not hash[v] then hash[v] = true; table.insert(res, v) end end
        table.sort(res)
        local final = {"Any"}
        for _, v in ipairs(res) do if v ~= "Any" then table.insert(final, v) end end
        return final
    end
    return clean(units), clean(mutations)
end

local UnitList, MutList = getGameData()

local function updateUI()
    local opts = #BuyList == 0 and {"(ไม่มีรายการ)"} or {}
    for i, v in ipairs(BuyList) do
        local name, rarity, mut = tostring(v.Name), tostring(v.Rarity):sub(1,4), tostring(v.Mutation):sub(1,4)
        table.insert(opts, string.format("%d.%s|%s|%s", i, name, rarity, mut))
    end
    Options.ListDropdown:SetValues(opts)
    SelectedDeleteIndex = 1
end

-- ==========================================
-- 🔔 Webhook
-- ==========================================
local webhookLogLines = {}
local function sendWebhook(unitName, rarity, mutation, price)
    if not Config.WebhookEnabled or not Config.WebhookURL or Config.WebhookURL == "" then return end
    local player = game.Players.LocalPlayer
    local timestamp = os.date("%H:%M:%S")

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
                },
                footer = { text = "Auto Roll PRO" }
            }}
        })
        pcall(function()
            if request then request({ Url = Config.WebhookURL, Method = "POST", Headers = { ["Content-Type"] = "application/json" }, Body = body })
            elseif syn and syn.request then syn.request({ Url = Config.WebhookURL, Method = "POST", Headers = { ["Content-Type"] = "application/json" }, Body = body })
            else game:HttpGet(Config.WebhookURL .. " POST " .. body) end
        end)
    end)
end

local function tryBuyChar(charModel, unitName, rarity, mutation, price)
    local prompt = charModel:FindFirstChildWhichIsA("ProximityPrompt", true)
    if prompt then
        firePrompt(prompt)
        UI_StatusLabel:SetText("สถานะ: ✅ ซื้อ " .. (unitName or "?") .. " สำเร็จ!")
        sendWebhook(unitName or "Unknown", rarity or "?", mutation or "?", price or 0)
        return true
    end
    return false
end

-- ==========================================
-- 👑 Priority Auto Buy Loop
-- ==========================================
task.spawn(function()
    while true do
        if WaitingForPriority and not IsDoingEvent then
            if CurrentPriorityUnit and CurrentPriorityUnit.Parent then
                local charModel = CurrentPriorityUnit
                local priceLabel = charModel:FindFirstChild("Price", true)
                local price = (priceLabel and priceLabel.Text) and parsePrice(priceLabel.Text) or 0
                local currentMoney = getMoney()

                if currentMoney >= price then
                    UI_StatusLabel:SetText("สถานะ: เงินพอแล้ว! กำลังซื้อ " .. PriorityTargetName .. "...")
                    tryBuyChar(charModel, PriorityTargetName, "Priority", "Priority", price)
                    WaitingForPriority, CurrentPriorityLevel, CurrentPriorityUnit = false, 0, nil
                else
                    UI_StatusLabel:SetText(string.format("สถานะ: ⏸ รอเงินซื้อ %s... (%.1fK/%.1fK)", PriorityTargetName, currentMoney/1000, price/1000))
                end
            else
                WaitingForPriority, CurrentPriorityLevel, CurrentPriorityUnit = false, 0, nil
            end
        end
        task.wait(0.5)
    end
end)

local function handlePriorityUnit(charModel, rarityText, mutationText)
    local unitLevel, targetName = 0, ""
    if Config.SecretPriority and rarityText == "Secret" then
        if (mutationText == "Dragonborn" and Config.MutDragonborn) or (mutationText == "Beast" and Config.MutBeast) or (mutationText == "Arrancar" and Config.MutArrancar) then
            unitLevel, targetName = 1, "Secret (" .. mutationText .. ")"
        end
    end
    if Config.GodPriority and rarityText == "God" then unitLevel, targetName = 2, "God" end

    if unitLevel > CurrentPriorityLevel then
        CurrentPriorityLevel, CurrentPriorityUnit, PriorityTargetName, WaitingForPriority = unitLevel, charModel, targetName, true
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
                    if IsDoingEvent then 
                        UI_StatusLabel:SetText("สถานะ: 🏃‍♂️ วิ่งไปทำกิจกรรม (หยุด Roll ชั่วคราว)")
                        task.wait(1) continue 
                    end
                    if WaitingForPriority then task.wait(0.5) continue end
                    
                    UI_StatusLabel:SetText("สถานะ: กำลัง Roll...")
                    local myPlot = getMyPlot()
                    if myPlot then
                        local prompt = myPlot:FindFirstChild("RollPrompt", true)
                        if prompt and prompt.Parent:IsA("BasePart") then
                            local char = game.Players.LocalPlayer.Character
                            local hrp, hum = char and char:FindFirstChild("HumanoidRootPart"), char and char:FindFirstChildWhichIsA("Humanoid")
                            
                            if hrp and hum then
                                local distance = (hrp.Position - prompt.Parent.Position).Magnitude
                                
                                if distance > prompt.MaxActivationDistance then
                                    if distance > 30 then
                                        -- [FIX] ถ้าอยู่ไกลมาก (กลับจากทำเควส) ให้วาปกลับ เพื่อข้ามแท่นซื้อ Robux
                                        hrp.Velocity = Vector3.zero
                                        hrp.CFrame = prompt.Parent.CFrame * CFrame.new(0, 0, 3)
                                        hrp.CFrame = CFrame.lookAt(hrp.Position, prompt.Parent.Position)
                                        if hum then hum.Jump = true end
                                        task.wait(0.3)
                                    else
                                        -- [FIX] ถ้าอยู่ใกล้ๆ (หลุดวงระยะสั้น) ให้เดินกลับปกติ
                                        hum:MoveTo(prompt.Parent.Position)
                                        local waited = 0
                                        repeat 
                                            task.wait(0.1)
                                            waited = waited + 0.1 
                                        until (hrp.Position - prompt.Parent.Position).Magnitude <= prompt.MaxActivationDistance or waited >= 5
                                    end
                                end
                            end
                            firePrompt(prompt)
                        end
                    end
                    task.wait(Config.RollDelay)
                end
                UI_StatusLabel:SetText("สถานะ: หยุดทำงาน")
            end)
        end
    end
})

RollGroup:AddSlider("RollDelay", { Text = "ความเร็ว Roll", Default = 1, Min = 0.1, Max = 3, Rounding = 1, Callback = function(V) Config.RollDelay = V end })
RollGroup:AddDivider()
RollGroup:AddToggle("GodPriorityToggle", { Text = "God Priority (ระดับสูงสุด!)", Default = false, Callback = function(V) Config.GodPriority = V if not V and CurrentPriorityLevel == 2 then WaitingForPriority = false CurrentPriorityLevel = 0 end end })
RollGroup:AddToggle("SecretPriorityToggle", { Text = "Secret Priority (รอซื้อ Secret)", Default = false, Callback = function(V) Config.SecretPriority = V if not V and CurrentPriorityLevel == 1 then WaitingForPriority = false CurrentPriorityLevel = 0 end end })
RollGroup:AddLabel("เลือก Mutation สำหรับ Secret Priority:")
RollGroup:AddToggle("MutArrancarToggle", { Text = "✔️ Arrancar", Default = false, Callback = function(V) Config.MutArrancar = V end })
RollGroup:AddToggle("MutBeastToggle", { Text = "✔️ Beast", Default = false, Callback = function(V) Config.MutBeast = V end })
RollGroup:AddToggle("MutDragonbornToggle", { Text = "✔️ Dragonborn", Default = false, Callback = function(V) Config.MutDragonborn = V end })

-- ==========================================
-- 🛒 Auto Buy Tab
-- ==========================================
BuyGroup:AddDropdown("UnitDropdown", { Text = "ชื่อตัวละคร", Values = UnitList, Default = 1, Searchable = true, Callback = function(V) TempName = V end })
BuyGroup:AddDropdown("RarityDropdown", { Text = "ระดับ (Rarity)", Values = {"Any", "Common", "Rare", "Epic", "Legendary", "Mythic", "Secret", "God"}, Default = 1, Callback = function(V) TempRarity = V end })
BuyGroup:AddDropdown("MutationDropdown", { Text = "Mutation", Values = MutList, Default = 1, Searchable = true, Callback = function(V) TempMut = V end })
BuyGroup:AddButton({ Text = "เพิ่มรายการ", Func = function() table.insert(BuyList, { Name = TempName, Rarity = TempRarity, Mutation = TempMut }) updateUI() end })
BuyGroup:AddDivider()
BuyGroup:AddToggle("AutoBuyToggle", { Text = "เปิดระบบ Auto Buy", Default = false, Callback = function(V) Config.MasterAutoBuy = V end })
BuyGroup:AddDivider()
BuyGroup:AddInput("DeleteInput", { Text = "พิมพ์เลขที่จะลบ", Default = "", Numeric = true, Finished = false, Placeholder = "เลข...", Callback = function(V) local idx = tonumber(V) if idx then SelectedDeleteIndex = idx end end })
BuyGroup:AddButton({ Text = "ลบรายการที่พิมพ์", Func = function() local idx = SelectedDeleteIndex if #BuyList == 0 then return end if idx >= 1 and idx <= #BuyList then table.remove(BuyList, idx) updateUI() end end })
BuyGroup:AddButton({ Text = "ลบทั้งหมด", Func = function() BuyList = {} updateUI() end })

-- ==========================================
-- 🌟 Auto Event Tab (Buhara) -> TARGET PROMPT FIX
-- ==========================================
EventGroup:AddToggle("AutoBuharaToggle", { 
    Text = "เปิดทำเควส Hunter Exam อัตโนมัติ", 
    Default = false, 
    Callback = function(V) Config.AutoBuharaEvent = V end 
})
EventGroup:AddLabel("สคริปต์จะหาตำแหน่งของ 'ปุ่ม E'\nและวาปไปยืนหน้าปุ่มโดยตรง (ป้องกัน NPC ยักษ์)")

task.spawn(function()
    while true do
        if Config.AutoBuharaEvent then
            local mutationStuffs = workspace:FindFirstChild("MutationStuffs")
            local getData = game:GetService("ReplicatedStorage"):FindFirstChild("BuharaEventGetData", true)
            
            if mutationStuffs and getData then
                local hasFood = false
                for _, v in pairs(mutationStuffs:GetChildren()) do
                    if v.Name == "FoodPickupItem" then hasFood = true break end
                end
                
                if hasFood then
                    local success, result = pcall(function() return getData:InvokeServer() end)
                    if success and type(result) == "table" and result.FoodNeeded then
                        IsDoingEvent = true -- บล็อก Auto Roll ชั่วคราว
                        local hrp = game.Players.LocalPlayer.Character and game.Players.LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
                        local hum = game.Players.LocalPlayer.Character and game.Players.LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
                        local npc = mutationStuffs:FindFirstChild("Buhara")
                        
                        if hrp and npc then
                            for foodName, isNeeded in pairs(result.FoodNeeded) do
                                if isNeeded == true and Config.AutoBuharaEvent then
                                    local targetItem = nil
                                    for _, item in pairs(mutationStuffs:GetChildren()) do
                                        if item.Name == "FoodPickupItem" and item:GetAttribute("FoodName") == foodName then
                                            targetItem = item break
                                        end
                                    end
                                    
                                    if targetItem then
                                        -- ============================================
                                        -- [FIX 1] วาปไปเก็บอาหาร (เล็งไปที่ปุ่ม E ของอาหารโดยตรง)
                                        -- ============================================
                                        local foodPrompt = targetItem:FindFirstChildWhichIsA("ProximityPrompt", true)
                                        local foodPromptPart = foodPrompt and foodPrompt.Parent
                                        hrp.Velocity = Vector3.zero
                                        
                                        if foodPromptPart and foodPromptPart:IsA("BasePart") then
                                            hrp.CFrame = foodPromptPart.CFrame * CFrame.new(0, 0, 3)
                                            hrp.CFrame = CFrame.lookAt(hrp.Position, foodPromptPart.Position)
                                        else
                                            hrp.CFrame = targetItem.CFrame * CFrame.new(0, 0, 3)
                                            hrp.CFrame = CFrame.lookAt(hrp.Position, targetItem.Position)
                                        end
                                        
                                        task.wait(0.1)
                                        if hum then hum.Jump = true end
                                        task.wait(0.3)
                                        firePrompt(foodPrompt)
                                        task.wait(0.5)
                                        
                                        -- ============================================
                                        -- [FIX 2] วาปไปหา NPC (เล็งไปที่ปุ่ม E ของ NPC โดยตรง)
                                        -- ============================================
                                        local npcPrompt = npc:FindFirstChildWhichIsA("ProximityPrompt", true)
                                        local npcPromptPart = npcPrompt and npcPrompt.Parent
                                        hrp.Velocity = Vector3.zero
                                        
                                        if npcPromptPart and npcPromptPart:IsA("BasePart") then
                                            -- ถ้าหาชิ้นส่วนที่ติดปุ่ม E เจอ ให้วาปไปตรงชิ้นส่วนนั้น
                                            hrp.CFrame = npcPromptPart.CFrame * CFrame.new(0, 0, 4)
                                            hrp.CFrame = CFrame.lookAt(hrp.Position, npcPromptPart.Position)
                                        else
                                            -- ถ้าหาไม่เจอ ให้วาปกะระยะห่างออกมา 10 ช่อง เผื่อ NPC ตัวใหญ่มาก
                                            local npcTargetCFrame = npc.PrimaryPart and npc.PrimaryPart.CFrame or npc:GetModelCFrame()
                                            hrp.CFrame = npcTargetCFrame * CFrame.new(0, 0, 10)
                                            hrp.CFrame = CFrame.lookAt(hrp.Position, npcTargetCFrame.Position)
                                        end
                                        
                                        task.wait(0.1)
                                        if hum then hum.Jump = true end
                                        task.wait(0.3)
                                        firePrompt(npcPrompt)
                                        task.wait(0.5)
                                    end
                                end
                            end
                        end
                        IsDoingEvent = false -- คืนค่าให้ Auto Roll กลับมาทำงาน
                        task.wait(5) -- กันสแปม
                    end
                end
            end
        end
        task.wait(2)
    end
end)

-- ==========================================
-- 🔔 Webhook Tab & 📡 Auto Buy Listener
-- ==========================================
WebhookGroup:AddToggle("WebhookEnabledToggle", { Text = "เปิดการแจ้งเตือน Discord", Default = false, Callback = function(V) Config.WebhookEnabled = V end })
WebhookGroup:AddInput("WebhookURLInput", { Text = "Discord Webhook URL", Default = "", Finished = true, Callback = function(V) Config.WebhookURL = V end })
WebhookGroup:AddButton({ Text = "🧪 ทดสอบ Webhook", Func = function() sendWebhook("TestUnit", "God", "Dragonborn", 999000) end })

local function checkAndBuy(charModel, name, rarity, mutation, price)
    if not Config.MasterAutoBuy or WaitingForPriority or IsDoingEvent then return end
    local n, r, m = tostring(name):lower(), tostring(rarity):lower(), tostring(mutation):lower()
    
    for _, item in ipairs(BuyList) do
        local iN, iR, iM = tostring(item.Name):lower(), tostring(item.Rarity):lower(), tostring(item.Mutation):lower()
        if (iN == "any" or n:find(iN, 1, true)) and (iR == "any" or r == iR) and (iM == "any" or m:find(iM, 1, true)) then
            tryBuyChar(charModel, name, rarity, mutation, price)
            break
        end
    end
end

task.spawn(function()
    local myPlot = nil
    repeat myPlot = getMyPlot() task.wait(1) until myPlot
    local charsFolder = myPlot:FindFirstChild("Characters") or myPlot:WaitForChild("Characters", 5)
    if not charsFolder then return end

    charsFolder.ChildAdded:Connect(function(char)
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
            local rarityLabel, mutLabel, priceLabel = frame:FindFirstChild("Rarity"), frame:FindFirstChild("Mutation"), frame:FindFirstChild("Price")
            local uRarity = rarityLabel and rarityLabel.Text or "Normal"
            local uMut = (mutLabel and mutLabel.Visible) and mutLabel.Text or "Normal"
            local uPrice = (priceLabel and priceLabel.Text) and parsePrice(priceLabel.Text) or 0
            checkAndBuy(char, uName, uRarity, uMut, uPrice)
            handlePriorityUnit(char, uRarity, uMut)
        end
    end)
end)

-- ==========================================
-- 🎨 UI Settings & SaveManager
-- ==========================================
local MenuGroup = Tabs["UI Settings"]:AddLeftGroupbox("Menu")
MenuGroup:AddLabel("Menu bind"):AddKeyPicker("MenuKeybind", { Default = "RightShift", NoUI = true, Text = "Menu keybind" })
MenuGroup:AddButton("Unload", function() Library:Unload() end)

ThemeManager:SetLibrary(Library)
SaveManager:SetLibrary(Library)
SaveManager:IgnoreThemeSettings()
SaveManager:SetIgnoreIndexes({"MenuKeybind", "DeleteDropdown", "WebhookURLInput", "UnitDropdown", "MutationDropdown", "RarityDropdown"})

local HttpService = game:GetService("HttpService")
local oldSave = SaveManager.Save
SaveManager.Save = function(self, name)
    local success = oldSave(self, name) 
    if success and name then
        pcall(function()
            if not isfolder("AutoRollPRO/buylists") then makefolder("AutoRollPRO/buylists") end
            writefile("AutoRollPRO/buylists/" .. name .. ".json", HttpService:JSONEncode(BuyList))
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
            if isfile(path) then BuyList = HttpService:JSONDecode(readfile(path)) else BuyList = {} end
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
SaveManager:LoadAutoloadConfig()
