-- ==========================================
-- 🎨 โหลด Obsidian Library
-- ==========================================
local repo = "https://raw.githubusercontent.com/deividcomsono/Obsidian/main/"
local Library = loadstring(game:HttpGet(repo .. "Library.lua"))()
local ThemeManager = loadstring(game:HttpGet(repo .. "addons/ThemeManager.lua"))()
local SaveManager = loadstring(game:HttpGet(repo .. "addons/SaveManager.lua"))()

local Options = Library.Options
local Toggles = Library.Toggles
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local Window = Library:CreateWindow({
    Title = "Auto Roll & Smart Buy (ULTIMATE PRO)",
    Footer = "PRO Edition + Tracker + Auto Boss + Auto Wave",
    ShowCustomCursor = true,
    AutoShow = true,
})

local Tabs = {
    Main = Window:AddTab("Auto Roll", "play"),
    Buy = Window:AddTab("Auto Buy", "shopping-cart"),
    Craft = Window:AddTab("Auto Craft", "hammer"),
    Spin = Window:AddTab("Auto Spin", "refresh-cw"), 
    Event = Window:AddTab("Auto Event", "star"),
    Tracker = Window:AddTab("Drop Tracker", "clipboard"),
    Webhook = Window:AddTab("Webhook", "bell"),
    Debug = Window:AddTab("Debug", "settings"),
    ["UI Settings"] = Window:AddTab("UI Settings", "settings"),
}

local RollGroup = Tabs.Main:AddLeftGroupbox("Auto Roll & Wave")
local StatusGroup = Tabs.Main:AddRightGroupbox("สถานะ")

local BuyGroup = Tabs.Buy:AddLeftGroupbox("ตั้งค่าการซื้อ")
local ListGroup = Tabs.Buy:AddRightGroupbox("รายการที่บันทึก")

local CraftGroup = Tabs.Craft:AddLeftGroupbox("ตั้งค่าการหลอม (Auto Fuse)")
local CraftStatusGroup = Tabs.Craft:AddRightGroupbox("สถานะการหลอม")

local SpinGroup = Tabs.Spin:AddLeftGroupbox("ตั้งค่า Auto Spin")
local SpinStatusGroup = Tabs.Spin:AddRightGroupbox("สถานะสปิน")
local EventGroup = Tabs.Event:AddLeftGroupbox("ตั้งค่ากิจกรรม & บอส")
local EventStatusGroup = Tabs.Event:AddRightGroupbox("สถานะกิจกรรม & บอส")
local UI_BossStatus = EventStatusGroup:AddLabel("สถานะบอส: 🔴 ปิดการทำงาน")
local TrackerLeftGroup = Tabs.Tracker:AddLeftGroupbox("ตั้งค่าบอทจด")
local TrackerRightGroup = Tabs.Tracker:AddRightGroupbox("สถิติ (Grand Total)")

local WebhookGroup = Tabs.Webhook:AddLeftGroupbox("Discord Webhook")
local WebhookLogGroup = Tabs.Webhook:AddRightGroupbox("Log การแจ้งเตือน")

local UI_StatusLabel = StatusGroup:AddLabel("สถานะ: หยุดทำงาน")
local UI_CraftStatus = CraftStatusGroup:AddLabel("สถานะ: 🔴 ปิดการทำงาน")
local UI_WebhookLog = WebhookLogGroup:AddLabel("ยังไม่มีการแจ้งเตือน")
ListGroup:AddDropdown("ListDropdown", { Text = "รายการทั้งหมด", Values = {"(ไม่มีรายการ)"}, Default = 1, Callback = function() end })

-- ==========================================
-- ⚙️ ค่าเริ่มต้นระบบต่างๆ และดึง DataService
-- ==========================================
local Config = { 
    AutoRoll = false, RollDelay = 1, MasterAutoBuy = false, 
    AutoCraft = false, CraftDelay = 0.5,
    GodPriority = false, SecretPriority = false, MutDragonborn = false, MutBeast = false, MutArrancar = false,
    WebhookURL = "", WebhookEnabled = false,
    -- Event Configs
    AutoBuharaEvent = false, AutoCollectOrb = false, AutoMakeWish = false, AutoChallengeBoss = false, AutoStartWave = false,
    AutoMeteor = false, -- เปลี่ยนชื่อตัวแปรภายในให้สอดคล้องกับระบบอุกกาบาต
    WishChoice = "MillionDollars"
}
local BuyList = {}
local TempName, TempRarity, TempMut = "Any", "Any", "Any"
local SelectedDeleteIndex = 1

local WaitingForPriority, IsDoingEvent = false, false 
local CurrentPriorityLevel, CurrentPriorityUnit = 0, nil
local PriorityTargetName = ""

-- ดึงตัวแปร client ออกมาให้เรียกใช้ได้เสถียรในทุกลูป
local client = nil
pcall(function()
    client = require(ReplicatedStorage:WaitForChild("Data"):WaitForChild("DataService")).client
end)

-- ==========================================
-- 🛡️ Anti-AFK & ระบบสกัดกั้นข้อความ V4
-- ==========================================
task.spawn(function()
    local VirtualUser = game:GetService("VirtualUser")
    player.Idled:Connect(function()
        VirtualUser:CaptureController()
        VirtualUser:ClickButton2(Vector2.new())
    end)
end)

pcall(function()
    local MS = game:GetService("MarketplaceService")
    if hookfunction then
        hookfunction(MS.PromptPurchase, function() return end)
        hookfunction(MS.PromptProductPurchase, function() return end)
        hookfunction(MS.PromptGamePassPurchase, function() return end)
    end
end)

getgenv().FragmentStatus = {
    ["Common Fragment"] = true, ["Rare Fragment"] = true, ["Epic Fragment"] = true,
    ["Legendary Fragment"] = true, ["Mythic Fragment"] = true, ["Secret Fragment"] = true,
}

task.spawn(function()
    local function checkAndSilence(v)
        if v:IsA("TextLabel") or v:IsA("TextButton") or v:IsA("TextBox") then
            local function process()
                local t1 = v.Text and string.lower(v.Text) or ""
                local t2 = v.ContentText and string.lower(v.ContentText) or ""
                
                if string.find(t1, "don't have enough") or string.find(t2, "don't have enough") then
                    for fragName, _ in pairs(getgenv().FragmentStatus) do
                        local ln = string.lower(fragName)
                        if string.find(t1, ln) or string.find(t2, ln) then getgenv().FragmentStatus[fragName] = false end
                    end
                    pcall(function()
                        v.Visible = false; v.TextTransparency = 1
                        if v.Parent and v.Parent:IsA("Frame") then v.Parent:Destroy() else v:Destroy() end
                    end)
                end
            end
            process()
            v:GetPropertyChangedSignal("Text"):Connect(process)
            v:GetPropertyChangedSignal("ContentText"):Connect(process)
        end
    end
    local pg = player:WaitForChild("PlayerGui")
    for _, obj in pairs(pg:GetDescendants()) do checkAndSilence(obj) end
    pg.DescendantAdded:Connect(checkAndSilence)
end)

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
    local cashLabel = player.PlayerGui.MainUI.Frames.Cash.Amount
    if cashLabel then return parsePrice(cashLabel.Text) end return 0
end

local function getMyPlot()
    for _, plot in pairs(workspace.Plots:GetChildren()) do
        for _, desc in pairs(plot:GetDescendants()) do
            if desc:IsA("TextLabel") and desc.Text ~= "" then
                local t = desc.Text:gsub("'s Base", ""):gsub("%s+", "")
                local dn = player.DisplayName:gsub("%s+", "")
                local pn = player.Name:gsub("%s+", "")
                if t == dn or t == pn then return plot end
            end
        end
    end return nil
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
-- 🚀 Auto Roll & Auto Start Wave Tab
-- ==========================================
RollGroup:AddToggle("AutoStartToggle", { 
    Text = "เปิด Auto Start Wave", Default = false, 
    Callback = function(V) Config.AutoStartWave = V end 
})
RollGroup:AddDivider()

RollGroup:AddToggle("AutoRollToggle", {
    Text = "เปิด Auto Roll", Default = false,
    Callback = function(V)
        Config.AutoRoll = V
        if V then
            task.spawn(function()
                while Config.AutoRoll do
                    if IsDoingEvent then 
                        UI_StatusLabel:SetText("สถานะ: 🏃‍♂️ วิ่งไปทำกิจกรรม/บอส (หยุด Roll)")
                        task.wait(1) 
                        continue 
                    end
                    if WaitingForPriority then 
                        task.wait(0.5) 
                        continue 
                    end
                    
                    UI_StatusLabel:SetText("สถานะ: กำลัง Roll...")
                    local myPlot = getMyPlot()
                    if myPlot then
                        local prompt = myPlot:FindFirstChild("RollPrompt", true)
                        if prompt and prompt.Parent:IsA("BasePart") then
                            local char = player.Character
                            local hrp = char and char:FindFirstChild("HumanoidRootPart")
                            local hum = char and char:FindFirstChildWhichIsA("Humanoid")
                            if hrp and hum then
                                local distance = (hrp.Position - prompt.Parent.Position).Magnitude
                                if distance > prompt.MaxActivationDistance then
                                    if distance > 30 then
                                        hrp.Velocity = Vector3.zero
                                        hrp.CFrame = prompt.Parent.CFrame * CFrame.new(math.random(-5, 5), 3, math.random(-15, -10))
                                        hrp.CFrame = CFrame.lookAt(hrp.Position, prompt.Parent.Position)
                                        task.wait(0.5)
                                    end
                                    hum:MoveTo(prompt.Parent.Position)
                                    local waited, lastPos = 0, hrp.Position
                                    repeat 
                                        task.wait(0.2); waited = waited + 0.2 
                                        if (hrp.Position - lastPos).Magnitude < 1 then hum.Jump = true end
                                        lastPos = hrp.Position; hum:MoveTo(prompt.Parent.Position)
                                    until (hrp.Position - prompt.Parent.Position).Magnitude <= prompt.MaxActivationDistance or waited >= 6
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

-- 🛡️ Auto Start Wave System
task.spawn(function()
    local checkStuck = 0 
    
    while true do
        task.wait(2)
        
        if IsDoingEvent then
            checkStuck = checkStuck + 1
            if checkStuck > 15 then 
                IsDoingEvent = false
                checkStuck = 0
                UI_StatusLabel:SetText("สถานะ: 🔄 ปลดล็อคสถานะค้าง!")
            end
        else
            checkStuck = 0
        end

        if Config.AutoStartWave and not IsDoingEvent and not WaitingForPriority then
            pcall(function()
                local Remotes = game:GetService("ReplicatedStorage"):FindFirstChild("Remotes")
                if Remotes and Remotes:FindFirstChild("Start") and Remotes.Start:FindFirstChild("StartWave") then
                    
                    local canStart = false
                    local playerGui = game:GetService("Players").LocalPlayer:FindFirstChild("PlayerGui")
                    
                    if playerGui then
                        for _, v in pairs(playerGui:GetDescendants()) do
                            if (v:IsA("TextLabel") or v:IsA("TextButton")) and v.Text == "Start" then
                                if v.Visible and v.Parent.Visible then
                                    canStart = true
                                    break
                                end
                            end
                        end
                    end
                    
                    if canStart then
                        Remotes.Start.StartWave:FireServer()
                        UI_StatusLabel:SetText("สถานะ: 🚀 Auto Start สั่งเริ่ม Wave!")
                    end
                end
            end)
        end
    end
end)

-- ==========================================
-- 🛒 Auto Buy Tab & Webhook Data
-- ==========================================
local function getGameData()
    local units, mutations = {}, {}
    local defaultMuts = {"Normal", "Gold", "Diamond", "Dragonborn", "Beast", "Arrancar", "Admin"}
    for _, v in ipairs(defaultMuts) do table.insert(mutations, v) end
    for _, obj in pairs(ReplicatedStorage:GetDescendants()) do
        if obj:IsA("ModuleScript") and (obj.Name:find("Info") or obj.Name:find("Data") or obj.Name:find("Character")) then
            local success, data = pcall(function() return require(obj) end)
            if success and type(data) == "table" then
                if data["Characters"] then
                    for _, chars in pairs(data["Characters"]) do
                        if type(chars) == "table" then for name, _ in pairs(chars) do if type(name) == "string" then table.insert(units, name) end end end
                    end
                end
                if data["Mutations"] or obj.Name:find("Mutation") then
                    local targetData = data["Mutations"] or data
                    for k, _ in pairs(targetData) do if type(k) == "string" and k ~= "Characters" then table.insert(mutations, k) end end
                end
            end
        end
    end
    local function clean(t)
        local hash, res = {}, {}
        for _, v in ipairs(t) do if not hash[v] then hash[v] = true; table.insert(res, v) end end table.sort(res)
        local final = {"Any"} for _, v in ipairs(res) do if v ~= "Any" then table.insert(final, v) end end return final
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

BuyGroup:AddDropdown("UnitDropdown", { Text = "ชื่อตัวละคร", Values = UnitList, Default = 1, Searchable = true, Callback = function(V) TempName = V end })
BuyGroup:AddDropdown("RarityDropdown", { Text = "ระดับ (Rarity)", Values = {"Any", "Common", "Rare", "Epic", "Legendary", "Mythic", "Secret", "God","Divine"}, Default = 1, Callback = function(V) TempRarity = V end })
BuyGroup:AddDropdown("MutationDropdown", { Text = "Mutation", Values = MutList, Default = 1, Searchable = true, Callback = function(V) TempMut = V end })
BuyGroup:AddButton({ Text = "เพิ่มรายการ", Func = function() table.insert(BuyList, { Name = TempName, Rarity = TempRarity, Mutation = TempMut }) updateUI() end })
BuyGroup:AddDivider()
BuyGroup:AddToggle("AutoBuyToggle", { Text = "เปิดระบบ Auto Buy", Default = false, Callback = function(V) Config.MasterAutoBuy = V end })
BuyGroup:AddDivider()
BuyGroup:AddInput("DeleteInput", { Text = "พิมพ์เลขที่จะลบ", Default = "", Numeric = true, Finished = false, Placeholder = "เลข...", Callback = function(V) local idx = tonumber(V) if idx then SelectedDeleteIndex = idx end end })
BuyGroup:AddButton({ Text = "ลบรายการที่พิมพ์", Func = function() local idx = SelectedDeleteIndex if #BuyList == 0 then return end if idx >= 1 and idx <= #BuyList then table.remove(BuyList, idx) updateUI() end end })
BuyGroup:AddButton({ Text = "ลบทั้งหมด", Func = function() BuyList = {} updateUI() end })

local webhookLogLines = {}
local function sendWebhook(unitName, rarity, mutation, price)
    if not Config.WebhookEnabled or not Config.WebhookURL or Config.WebhookURL == "" then return end
    local timestamp = os.date("%H:%M:%S")
    table.insert(webhookLogLines, 1, string.format("[%s] ✅ %s | %s | %s", timestamp, unitName, rarity, mutation))
    if #webhookLogLines > 5 then table.remove(webhookLogLines) end
    UI_WebhookLog:SetText(table.concat(webhookLogLines, "\n"))
    task.spawn(function()
        local body = HttpService:JSONEncode({
            embeds = {{
                title = "✅ ซื้อตัวละครสำเร็จ!", color = 5814783,
                fields = { { name = "👤 ตัวละคร", value = unitName, inline = true }, { name = "⭐ Rarity", value = rarity, inline = true }, { name = "💎 Mutation", value = mutation, inline = true }, { name = "💰 ราคา", value = tostring(price), inline = true }, { name = "🎮 ผู้เล่น", value = player.Name, inline = true } },
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
    end return false
end

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
                else UI_StatusLabel:SetText(string.format("สถานะ: ⏸ รอเงินซื้อ %s...", PriorityTargetName)) end
            else WaitingForPriority, CurrentPriorityLevel, CurrentPriorityUnit = false, 0, nil end
        end
        task.wait(0.5)
    end
end)

local function handlePriorityUnit(charModel, rarityText, mutationText)
    local unitLevel, targetName = 0, ""
    if Config.SecretPriority and rarityText == "Secret" then
        if (mutationText == "Dragonborn" and Config.MutDragonborn) or (mutationText == "Beast" and Config.MutBeast) or (mutationText == "Arrancar" and Config.MutArrancar) then unitLevel, targetName = 1, "Secret (" .. mutationText .. ")" end
    end
    if Config.GodPriority and rarityText == "God" then unitLevel, targetName = 2, "God" end
    if unitLevel > CurrentPriorityLevel then CurrentPriorityLevel, CurrentPriorityUnit, PriorityTargetName, WaitingForPriority = unitLevel, charModel, targetName, true end
end

local function checkAndBuy(charModel, name, rarity, mutation, price)
    if not Config.MasterAutoBuy or WaitingForPriority or IsDoingEvent then return end
    local n, r, m = tostring(name):lower(), tostring(rarity):lower(), tostring(mutation):lower()
    for _, item in ipairs(BuyList) do
        local iN, iR, iM = tostring(item.Name):lower(), tostring(item.Rarity):lower(), tostring(item.Mutation):lower()
        if (iN == "any" or n:find(iN, 1, true)) and (iR == "any" or r == iR) and (iM == "any" or m:find(iM, 1, true)) then
            tryBuyChar(charModel, name, rarity, mutation, price) break
        end
    end
end

task.spawn(function()
    local myPlot = nil
    repeat myPlot = getMyPlot() task.wait(1) until myPlot
    local charsFolder = myPlot:FindFirstChild("Characters") or myPlot:WaitForChild("Characters", 5)
    if not charsFolder then return end
    charsFolder.ChildAdded:Connect(function(char)
        local frame = nil; local tries = 0
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
-- 🔨 Auto Craft Tab
-- ==========================================
CraftGroup:AddToggle("AutoCraftToggle", { Text = "เปิด Auto Fuse (หลอมหิน)", Default = false, Callback = function(V) Config.AutoCraft = V end })
CraftGroup:AddSlider("CraftDelay", { Text = "ความเร็วในการหลอม (วินาที)", Default = 0.5, Min = 0.1, Max = 2, Rounding = 1, Callback = function(V) Config.CraftDelay = V end })
CraftGroup:AddDivider()
CraftGroup:AddToggle("Craft_Common", { Text = "Common Fragment", Default = true })
CraftGroup:AddToggle("Craft_Rare", { Text = "Rare Fragment", Default = true })
CraftGroup:AddToggle("Craft_Epic", { Text = "Epic Fragment", Default = true })
CraftGroup:AddToggle("Craft_Legendary", { Text = "Legendary Fragment", Default = false })
CraftGroup:AddToggle("Craft_Mythic", { Text = "Mythic Fragment", Default = false })
CraftGroup:AddToggle("Craft_Secret", { Text = "Secret Fragment", Default = false })

task.spawn(function()
    local fuseRemote = nil
    pcall(function() fuseRemote = game:GetService("ReplicatedStorage"):WaitForChild("Remotes"):WaitForChild("FragmentFusion"):WaitForChild("Request") end)
    task.spawn(function() while true do task.wait(1800) for k, _ in pairs(getgenv().FragmentStatus) do getgenv().FragmentStatus[k] = true end end end)
    while true do
        if Config.AutoCraft and fuseRemote then
            local fragmentsToFuse = {}
            if Toggles.Craft_Common.Value then table.insert(fragmentsToFuse, "Common Fragment") end
            if Toggles.Craft_Rare.Value then table.insert(fragmentsToFuse, "Rare Fragment") end
            if Toggles.Craft_Epic.Value then table.insert(fragmentsToFuse, "Epic Fragment") end
            if Toggles.Craft_Legendary.Value then table.insert(fragmentsToFuse, "Legendary Fragment") end
            if Toggles.Craft_Mythic.Value then table.insert(fragmentsToFuse, "Mythic Fragment") end
            if Toggles.Craft_Secret.Value then table.insert(fragmentsToFuse, "Secret Fragment") end

            local isFusingAnything = false
            for _, fragName in ipairs(fragmentsToFuse) do
                if not Config.AutoCraft then break end 
                if getgenv().FragmentStatus[fragName] then
                    UI_CraftStatus:SetText("สถานะ: ⚡ กำลังพยายามหลอม " .. fragName)
                    pcall(function() fuseRemote:FireServer(fragName) end)
                    isFusingAnything = true
                    task.wait(Config.CraftDelay)
                end
            end
            if not isFusingAnything then UI_CraftStatus:SetText("สถานะ: 💤 ของหมด... รอเช็คใหม่ใน 30 นาที") task.wait(2) end
        else
            if not fuseRemote and Config.AutoCraft then UI_CraftStatus:SetText("สถานะ: ❌ หาระบบหลอมหินไม่เจอ!") else UI_CraftStatus:SetText("สถานะ: 🔴 ปิดการทำงาน") end
            task.wait(1)
        end
    end
end)

-- ==========================================
-- 🎰 Auto Spin Tab
-- ==========================================
local isSpinning = false
local SpinTicketLabel = SpinStatusGroup:AddLabel("✨ กำลังดึงข้อมูลแต้ม...")
SpinGroup:AddToggle("AutoSpinToggle", {
    Text = "เปิดบอทสปิน", Default = false,
    Callback = function(V)
        isSpinning = V
        if V then
            task.spawn(function()
                while isSpinning do
                    pcall(function()
                        local spinRemote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("SpinWheel"):WaitForChild("Spin")
                        spinRemote:FireServer(1); spinRemote:FireServer("Spin"); spinRemote:FireServer("Single"); spinRemote:FireServer("x1"); spinRemote:FireServer(true)
                    end)
                    task.wait(1.8)
                end
            end)
        end
    end
})
task.spawn(function()
    while true do
        pcall(function()
            local mainUI = playerGui:FindFirstChild("MainUI")
            if mainUI then
                local spinWheel = mainUI.Frames:FindFirstChild("SpinWheel")
                if spinWheel then
                    for _, obj in pairs(spinWheel:GetDescendants()) do
                        if (obj:IsA("TextLabel") or obj:IsA("TextButton")) and string.find(obj.Text, "Spin") and string.find(obj.Text, "%(") then SpinTicketLabel:SetText("แต้มที่ใช้: " .. obj.Text) return end
                        if obj:IsA("TextLabel") and string.find(obj.Text, "Free") then SpinTicketLabel:SetText(obj.Text) return end
                    end
                end
            end
            local leaderstats = player:FindFirstChild("leaderstats")
            if leaderstats then
                local ticket = leaderstats:FindFirstChild("Spins") or leaderstats:FindFirstChild("Tickets") or leaderstats:FindFirstChild("Gems")
                if ticket then SpinTicketLabel:SetText(ticket.Name .. " คงเหลือ: " .. tostring(ticket.Value)) return end
            end
            SpinTicketLabel:SetText("🎰 บอทสปินกำลังทำงาน...")
        end)
        task.wait(1)
    end
end)

-- ==========================================
-- 🌟 Auto Event & Boss Tab
-- ==========================================
EventGroup:AddToggle("AutoBuharaToggle", { Text = "เปิดทำเควส Hunter Exam", Default = false, Callback = function(V) Config.AutoBuharaEvent = V end })
EventGroup:AddDivider()
EventGroup:AddToggle("AutoCollectOrbToggle", { Text = "Auto Collect ลูกแก้ว", Default = false, Callback = function(V) Config.AutoCollectOrb = V end })
EventGroup:AddToggle("AutoMakeWishToggle", { Text = "Auto Make a wish (ขอพร)", Default = false, Callback = function(V) Config.AutoMakeWish = V end })
EventGroup:AddDivider()
EventGroup:AddToggle("AutoChallengeBossToggle", { Text = "เปิดออโต้กด Challenge Boss", Default = false, Callback = function(V) Config.AutoChallengeBoss = V end })
EventGroup:AddDropdown("WishDropdown", { 
    Text = "เลือกพรที่ต้องการขอ", 
    Values = {
        "CashBoost", 
        "LuckBoost", 
        "ManyFragments", 
        "MeteorRain", 
        "MillionDollars", 
        "SkipCloningMachine", 
        "SkipCraftingMachine", 
        "UniqueTrait"
    }, 
    Default = 5, 
    Callback = function(V) 
        Config.WishChoice = V 
    end 
})

-- ⭐ ปรับปรุงการผูกชื่อปุ่ม Toggle ให้ตรงกับรูปภาพ UI ของคุณ (image_4970d3.png)
EventGroup:AddToggle("AutoMeteorToggle", { 
    Text = "Auto ตามเก็บอุกกาบาต & สปิน", 
    Default = false, 
    Callback = function(V) 
        Config.AutoMeteor = V 
    end 
})

-- 🚀 ลูป Event แบบรวมศูนย์ (เวอร์ชันแก้ไขการดักจับข้อความแฝง VIP Chest)
task.spawn(function()
    while true do
        task.wait(0.5)
        local hrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
        local hum = player.Character and player.Character:FindFirstChildWhichIsA("Humanoid")
        local Remotes = game:GetService("ReplicatedStorage"):FindFirstChild("Remotes")
        
        if (Config.AutoCollectOrb or Config.AutoMakeWish or Config.AutoMeteor) and hrp and hum then
            pcall(function()
                for _, obj in pairs(workspace:GetDescendants()) do
                    if obj:IsA("ProximityPrompt") then
                        local aText = string.lower(obj.ActionText or "")
                        local oName = string.lower(obj.Name or "")
                        
                        -- คำนวณตำแหน่ง CFrame ของวัตถุให้ถูกต้อง
                        local promptCF = obj.Parent:IsA("Attachment") and obj.Parent.WorldCFrame or 
                                         (obj.Parent:IsA("BasePart") and obj.Parent.CFrame or obj.Parent:GetPivot())
                        
                        -- 🟢 1. ระบบ Collect Orb
                        if Config.AutoCollectOrb and (aText == "collect" or oName == "collect") then
                            IsDoingEvent = true
                            hrp.Velocity = Vector3.zero
                            hrp.CFrame = promptCF * CFrame.new(0, 2, 0)
                            task.wait(0.3)
                            for i = 1, 3 do firePrompt(obj); task.wait(0.1) end
                            task.wait(1)
                            IsDoingEvent = false
                        end

                        -- 🐉 2. ระบบมังกร (Make a wish)
                        if Config.AutoMakeWish and (string.find(aText, "make a wish") or string.find(oName, "make a wish") or string.find(aText, "wish")) then
                            IsDoingEvent = true
                            pcall(function()
                                if Remotes and Remotes:FindFirstChild("SuperShenronEvent") and Remotes.SuperShenronEvent:FindFirstChild("ClaimWish") then
                                    local targetWish = Config.WishChoice or "MillionDollars"
                                    Remotes.SuperShenronEvent.ClaimWish:FireServer(targetWish)
                                    UI_StatusLabel:SetText("สถานะ: 🐉 ยิง Remote ขอพร [" .. targetWish .. "] สำเร็จ!")
                                    task.wait(0.5)
                                end
                            end)
                            IsDoingEvent = false
                        end

                        -- ☄️ 3. ระบบ Meteor & Auto Claim (เวอร์ชันตรวจเช็คสูงสุด สลัดบัคกล่อง VIP Chest ทิ้ง 100%)
                        if Config.AutoMeteor then
                            local modelName = obj.Parent and obj.Parent.Name or ""
                            local parentNameLower = string.lower(modelName)
                            
                            -- ⭐ เงื่อนไขหัวใจสำคัญ: คัดกรองคัตเอาท์โมเดลกล่องรับของสิทธิ์ VIP ออกจากการคำนวณทั้งหมดเพื่อป้องกันการวาร์ปค้างค่าย
                            if string.find(parentNameLower, "vip") or string.find(parentNameLower, "chest") or string.find(parentNameLower, "daily") or string.find(oName, "vip") then
                                -- สั่งข้ามผ่านทันที ห้ามหันตัวแปรไปแตะเด็ดขาด!
                            else
                                -- ตรวจสอบคุณสมบัติเมื่อตรงตามสเปกหินอุกกาบาตของจริง
                                if string.find(aText, "meteor") or string.find(oName, "meteor") or 
                                   (string.find(aText, "claim") and not string.find(aText, "daily")) or -- เจาะจงเฉพาะปุ่ม claim ที่ไม่มีคำว่า daily แฝงอยู่
                                   modelName == "Basic" or modelName == "Op" or modelName == "Godly" then
                                    
                                    IsDoingEvent = true
                                    hrp.Velocity = Vector3.zero
                                    hrp.CFrame = CFrame.new(promptCF.Position + Vector3.new(0, 1, 3))
                                    
                                    hum:ChangeState(Enum.HumanoidStateType.GettingUp)
                                    hum.Jump = true 
                                    task.wait(0.3)
                                    
                                    UI_StatusLabel:SetText("สถานะ: ☄️ พบอุกกาบาตเกรด [" .. modelName .. "] กำลังเก็บของรางวัล...")
                                    
                                    for i = 1, 5 do 
                                        firePrompt(obj) 
                                        task.wait(0.2) 
                                    end
                                    
                                    for i = 1, 12 do 
                                        for _, v in pairs(playerGui:GetDescendants()) do
                                            if v:IsA("TextButton") and string.find(string.lower(v.Text), "claim") and not string.find(string.lower(v.Text), "daily") then
                                                if getconnections then for _, c in pairs(getconnections(v.MouseButton1Click)) do c:Fire() end end
                                                v.MouseButton1Click:Fire()
                                            end
                                        end
                                        task.wait(0.2)
                                    end
                                    IsDoingEvent = false
                                end
                            end
                        end
                    end
                end
            end)
        end

        -- ==========================================
        -- 2. ลูปทำเควส Buhara
        -- ==========================================
        if Config.AutoBuharaEvent and hrp and hum then
            pcall(function()
                local mutationStuffs = workspace:FindFirstChild("MutationStuffs")
                local getData = game:GetService("ReplicatedStorage"):FindFirstChild("BuharaEventGetData", true)
                if mutationStuffs and getData then
                    local hasFood = false
                    for _, v in pairs(mutationStuffs:GetChildren()) do if v.Name == "FoodPickupItem" then hasFood = true break end end
                    if hasFood then
                        local success, result = pcall(function() return getData:InvokeServer() end)
                        if success and type(result) == "table" and result.FoodNeeded then
                            IsDoingEvent = true
                            local npc = mutationStuffs:FindFirstChild("Buhara")
                            if npc then
                                for foodName, isNeeded in pairs(result.FoodNeeded) do
                                    if isNeeded and Config.AutoBuharaEvent then
                                        local targetItem = nil
                                        for _, item in pairs(mutationStuffs:GetChildren()) do if item.Name == "FoodPickupItem" and item:GetAttribute("FoodName") == foodName then targetItem = item break end end
                                        if targetItem then
                                            local foodPrompt = targetItem:FindFirstChildWhichIsA("ProximityPrompt", true)
                                            if foodPrompt.Parent and foodPrompt.Parent:IsA("BasePart") then hrp.CFrame = foodPrompt.Parent.CFrame * CFrame.new(0, 0, 3) else hrp.CFrame = targetItem.CFrame * CFrame.new(0, 0, 3) end
                                            hrp.CFrame = CFrame.lookAt(hrp.Position, targetItem.Position)
                                            task.wait(0.3); hum.Jump = true; task.wait(0.5); firePrompt(foodPrompt); task.wait(1.5)
                                            
                                            local npcPrompt = npc:FindFirstChildWhichIsA("ProximityPrompt", true)
                                            local targetPos = npc:GetPivot().Position; local safeDistance = 15
                                            if npcPrompt then
                                                if npcPrompt.Parent:IsA("Attachment") then targetPos = npcPrompt.Parent.WorldPosition; safeDistance = 5
                                                elseif npcPrompt.Parent:IsA("BasePart") then targetPos = npcPrompt.Parent.Position; safeDistance = (math.max(npcPrompt.Parent.Size.X, npcPrompt.Parent.Size.Z) / 2) + 6 end
                                            end
                                            hrp.CFrame = CFrame.lookAt(targetPos + Vector3.new(0, 0, safeDistance), targetPos)
                                            task.wait(0.3); hum.Jump = true; task.wait(0.5); firePrompt(npcPrompt); task.wait(1.5)
                                        end
                                    end
                                end
                            end
                            IsDoingEvent = false
                        end
                    end
                end
            end)
        end

        -- ==========================================
        -- 3. ลูป Challenge Boss
        -- ==========================================
        if Config.AutoChallengeBoss and hrp then
            pcall(function()
                for _, obj in pairs(workspace:GetDescendants()) do
                    if obj:IsA("ProximityPrompt") and obj.Name == "ProximityPrompt" and obj.Parent and obj.Parent.Name == "Door" then
                        local restockGUI = obj.Parent.Parent:FindFirstChild("RestockGUI")
                        local timerLabel = restockGUI and restockGUI:FindFirstChild("TimerLabel")
                        
                        if timerLabel then
                            local textLower = string.lower(timerLabel.Text)
                            
                            if string.find(textLower, "challenge in") then
                                UI_BossStatus:SetText("สถานะบอส: ⏳ " .. timerLabel.Text)
                                if not string.find(UI_BossStatus.Text, "เข้าประตู") then 
                                    IsDoingEvent = false 
                                end
                                
                            elseif string.find(textLower, "now") or obj.Enabled == true then
                                IsDoingEvent = true
                                UI_BossStatus:SetText("สถานะบอส: ⚔️ บอสเปิดแล้ว! กำลังวาร์ปไปเข้าประตู...")
                                
                                hrp.Velocity = Vector3.zero
                                hrp.CFrame = obj.Parent.CFrame * CFrame.new(0, 0, 3)
                                task.wait(0.2)
                                
                                if Remotes and Remotes:FindFirstChild("Start") and Remotes.Start:FindFirstChild("EndWave") then 
                                    Remotes.Start.EndWave:FireServer() 
                                end
                                
                                UI_BossStatus:SetText("สถานะบอส: ⚡ กำลังกดเข้าประตูท้าทายบอสบิลส์!")
                                for i = 1, 15 do 
                                    firePrompt(obj) 
                                    task.wait(0.05) 
                                end
                                
                                UI_BossStatus:SetText("สถานะบอส: ✅ เข้าประตูสำเร็จแล้ว!")
                                task.wait(5) 
                            end
                        end
                        break 
                    end
                end
            end)
            
            pcall(function()
                local bSpinRemote = Remotes and Remotes:FindFirstChild("SpinWheel") and Remotes.SpinWheel:FindFirstChild("BeerusSpin")
                if bSpinRemote and client then
                    local currentSpins = client:get({"BeerusSpin"}) or 0
                    if tonumber(currentSpins) and tonumber(currentSpins) > 0 then
                        UI_BossStatus:SetText("สถานะบอส: 🎰 พบแต้มสปินบอส ["..tostring(currentSpins).."] แต้ม! กำลังรับของรางวัล...")
                        bSpinRemote:FireServer("Spin")
                        task.wait(0.5)
                        bSpinRemote:FireServer("Complete", {NotifyText = "AutoRollPRO Bypass"})
                        task.wait(0.5)
                    end
                end
            end)
        else
            UI_BossStatus:SetText("สถานะบอส: 🔴 ปิดการทำงาน")
        end

        task.wait(1)
    end
end)

-- ==========================================
-- 📊 ระบบ Drop Tracker
-- ==========================================
local isTracking, isResettingTracker, currentSessionRound, currentTrackerTotal = false, false, 1, 0
local currentStats, recentDrops = {}, {}
local logFileName, dataFileName = "AutoRollPRO/DropTracker_Log.txt", "AutoRollPRO/DropTracker_Data.json"
local globalTrackerData = { totalRounds = 0, grandTotalDrops = 0, grandStats = {} }
pcall(function() if not isfolder("AutoRollPRO") then makefolder("AutoRollPRO") end end)

local function loadGlobalTrackerData()
    if isfile and isfile(dataFileName) then
        local success, decoded = pcall(function() return HttpService:JSONDecode(readfile(dataFileName)) end)
        if success and type(decoded) == "table" then globalTrackerData = decoded end
    end
end
local function saveGlobalTrackerData()
    if writefile then
        local success, encoded = pcall(function() return HttpService:JSONEncode(globalTrackerData) end)
        if success then writefile(dataFileName, encoded) end
    end
end
loadGlobalTrackerData()

local TrackerStatusLabel = TrackerLeftGroup:AddLabel("🔴 สถานะ: ปิดการทำงาน")
local TrackerInfoLabel = TrackerLeftGroup:AddLabel("ประวัติสะสมทั้งหมด: " .. globalTrackerData.totalRounds .. " รอบ")
local TrackerGrandLabel = TrackerRightGroup:AddLabel("รอข้อมูลอัปเดต...")

local function updateGrandTotalLabel()
    if globalTrackerData.totalRounds == 0 then TrackerGrandLabel:SetText("ยังไม่มีข้อมูลสถิติ\nเปิดบอทเล่นให้จบสัก 1 รอบเพื่อดูผล") return end
    local txt = string.format("🎮 ยอดรวม %d รอบ\n📦 ไอเทมทั้งหมด: %d ชิ้น\n\n", globalTrackerData.totalRounds, globalTrackerData.grandTotalDrops)
    local sortedGrand = {}
    for item, count in pairs(globalTrackerData.grandStats) do table.insert(sortedGrand, {name = item, amount = count}) end
    table.sort(sortedGrand, function(a, b) return a.amount > b.amount end)
    for i, data in ipairs(sortedGrand) do
        if i > 8 then txt = txt .. "  ...และอื่นๆ\n" break end
        local grandRate = globalTrackerData.grandTotalDrops > 0 and (data.amount / globalTrackerData.grandTotalDrops) * 100 or 0
        txt = txt .. string.format("🏆 %s: %d (%.1f%%)\n", data.name, data.amount, grandRate)
    end
    TrackerGrandLabel:SetText(txt)
end
updateGrandTotalLabel()

TrackerLeftGroup:AddToggle("EnableTrackerToggle", {
    Text = "เปิดบอทจดของดรอป (Tracker)", Default = false,
    Callback = function(V)
        isTracking = V
        if V then TrackerStatusLabel:SetText("🟢 สถานะ: กำลังจด (รอบ Session: " .. currentSessionRound .. ")") else TrackerStatusLabel:SetText("🔴 สถานะ: ปิดการทำงาน") end
    end
})

TrackerLeftGroup:AddButton({
    Text = "📋 Copy Grand Total",
    Func = function()
        if globalTrackerData.totalRounds == 0 then Library:Notify("No data to copy yet.") return end
        local str = "=== 🏆 CURRENT GRAND TOTAL (" .. globalTrackerData.totalRounds .. " Rounds) ===\nTotal Items Dropped: " .. globalTrackerData.grandTotalDrops .. " pcs\n\n"
        local sortedStats = {}
        for item, count in pairs(globalTrackerData.grandStats) do table.insert(sortedStats, {name = item, amount = count}) end
        table.sort(sortedStats, function(a, b) return a.amount > b.amount end)
        for _, data in ipairs(sortedStats) do
            local rate = globalTrackerData.grandTotalDrops > 0 and (data.amount / globalTrackerData.grandTotalDrops) * 100 or 0
            str = str .. string.format("  - %-20s : %d pcs (%.2f%%)\n", data.name, data.amount, rate)
        end
        if setclipboard then setclipboard(str) Library:Notify("✅ ก๊อปปี้สถิติทั้งหมดลง Clipboard แล้ว!") else Library:Notify("❌ ตัวรันนี้ไม่รองรับระบบก๊อปปี้") end
    end
})

local function finalizeTrackerRound(waveNumber)
    globalTrackerData.totalRounds = globalTrackerData.totalRounds + 1
    globalTrackerData.grandTotalDrops = globalTrackerData.grandTotalDrops + currentTrackerTotal
    for item, count in pairs(currentStats) do globalTrackerData.grandStats[item] = (globalTrackerData.grandStats[item] or 0) + count end
    saveGlobalTrackerData()

    local logText = "\n" .. string.rep("=", 45) .. "\n" .. string.format("[ROUND INFO] Global: #%d | Session: #%d\nEnded at Wave: %s\nItems Dropped This Round: %d pcs\n", globalTrackerData.totalRounds, currentSessionRound, waveNumber, currentTrackerTotal)
    for item, count in pairs(currentStats) do
        local rate = currentTrackerTotal > 0 and (count / currentTrackerTotal) * 100 or 0
        logText = logText .. string.format("  - %-20s : %d pcs (%.1f%%)\n", item, count, rate)
    end
    if appendfile then appendfile(logFileName, logText) elseif writefile then local existingText = isfile(logFileName) and readfile(logFileName) or "=== 📊 DETAILED DROP RATE LOG ===\n" writefile(logFileName, existingText .. logText) end
    updateGrandTotalLabel(); currentStats = {}; currentTrackerTotal = 0; currentSessionRound = currentSessionRound + 1
    TrackerStatusLabel:SetText("🟢 สถานะ: กำลังจด (รอบ Session: " .. currentSessionRound .. ")"); TrackerInfoLabel:SetText("ประวัติสะสมทั้งหมด: " .. globalTrackerData.totalRounds .. " รอบ")
end

local function processTrackerText(rawText)
    if not isTracking then return end
    local cleanText = rawText:gsub("%<[^%>]+%>", "")
    local lowerText = string.lower(cleanText)
    local waveNum = string.match(lowerText, "you lost at wave (%d+)")
    if waveNum then
        if not isResettingTracker then isResettingTracker = true; finalizeTrackerRound(waveNum); task.delay(15, function() isResettingTracker = false end) end
        return
    end
    if not isResettingTracker and string.find(lowerText, "you got") then
        if not recentDrops[cleanText] then
            recentDrops[cleanText] = true
            local quantityStr, itemName = string.match(cleanText, "x(%d+)%s*(.-)!")
            local quantity = tonumber(quantityStr) or 1
            if not itemName then itemName = cleanText:gsub("You got ", ""):gsub("!", "") end
            currentStats[itemName] = (currentStats[itemName] or 0) + quantity
            currentTrackerTotal = currentTrackerTotal + quantity
            task.delay(1, function() recentDrops[cleanText] = nil end)
        end
    end
end

local playerGuiNode = player:WaitForChild("PlayerGui")
playerGuiNode.DescendantAdded:Connect(function(descendant)
    if descendant:IsA("TextLabel") or descendant:IsA("TextButton") or descendant:IsA("TextBox") then
        if descendant.Text and descendant.Text ~= "" then processTrackerText(descendant.Text) end
        descendant:GetPropertyChangedSignal("Text"):Connect(function() if descendant.Text and descendant.Text ~= "" then processTrackerText(descendant.Text) end end)
    end
end)

-- ==========================================
-- 🔔 Webhook
-- ==========================================
WebhookGroup:AddToggle("WebhookEnabledToggle", { Text = "เปิดการแจ้งเตือน Discord", Default = false, Callback = function(V) Config.WebhookEnabled = V end })
WebhookGroup:AddInput("WebhookURLInput", { Text = "Discord Webhook URL", Default = "", Finished = true, Callback = function(V) Config.WebhookURL = V end })
WebhookGroup:AddButton({ Text = "🧪 ทดสอบ Webhook", Func = function() sendWebhook("TestUnit", "God", "Dragonborn", 999000) end })

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

local oldSave = SaveManager.Save
SaveManager.Save = function(self, name)
    local success = oldSave(self, name) 
    if success and name then
        pcall(function()
            if not isfolder("AutoRollPRO/buylists") then makefolder("AutoRollPRO/buylists") end
            writefile("AutoRollPRO/buylists/" .. name .. ".json", HttpService:JSONEncode(BuyList))
            writefile("AutoRollPRO/buylists/" .. name .. "_webhook.txt", Config.WebhookURL or "")
        end)
    end return success
end
local oldLoad = SaveManager.Load
SaveManager.Load = function(self, name)
    local success = oldLoad(self, name) 
    if success and name then
        pcall(function()
            local path = "AutoRollPRO/buylists/" .. name .. ".json"
            if isfile(path) then BuyList = HttpService:JSONDecode(readfile(path)) else BuyList = {} end
            local whPath = "AutoRollPRO/buylists/" .. name .. "_webhook.txt"
            if isfile(whPath) then Config.WebhookURL = readfile(whPath); Options.WebhookURLInput:SetValue(Config.WebhookURL) end
            updateUI() 
        end)
    end return success
end

ThemeManager:SetFolder("AutoRollPRO")
SaveManager:SetFolder("AutoRollPRO/game")
ThemeManager:ApplyToTab(Tabs["UI Settings"])
SaveManager:BuildConfigSection(Tabs["UI Settings"])
Library.ToggleKeybind = Options.MenuKeybind
SaveManager:LoadAutoloadConfig()
