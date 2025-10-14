--// UI Library
local Library = loadstring(game:HttpGetAsync("https://github.com/ActualMasterOogway/Fluent-Renewed/releases/latest/download/Fluent.luau"))()

local Window = Library:CreateWindow{
    Title = "gag",
    SubTitle = "V-0.1.1",
    TabWidth = 160,
    Size = UDim2.fromOffset(830, 525),
    Resize = true,
    MinSize = Vector2.new(470, 380),
    Acrylic = true,
    Theme = "Dark",
    MinimizeKey = Enum.KeyCode.LeftControl
}

local Tabs = {
    Main = Window:CreateTab{
        Title = "Shop",
        Icon = "nil"
    }
}

--// Toggle
local Toggle1 = Tabs.Main:CreateToggle("MyToggle", {Title = "Auto Harvest", Default = false})

-- ensure the guard var exists (preserve the library's interaction behavior)
local Toggle1Interacted = false

--// Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local LocalPlayer = Players.LocalPlayer
local GameEvents = ReplicatedStorage:WaitForChild("GameEvents")

--// Helper: find player's farm (works even if farm is added later)
local function GetPlayerFarm(player)
    for _, farm in pairs(workspace.Farm:GetChildren()) do
        local important = farm:FindFirstChild("Important")
        if important and important:FindFirstChild("Data") then
            local owner = important.Data:FindFirstChild("Owner")
            if owner and owner.Value == player.Name then
                return farm
            end
        end
    end
    return nil
end

--// Harvest helpers
local function HarvestPlant(Plant)
    if not Plant then return end
    local Prompt = Plant:FindFirstChild("ProximityPrompt", true)
    if Prompt and Prompt.Enabled then
        -- use pcall in case fireproximityprompt errors on some exploit environments
        pcall(function() fireproximityprompt(Prompt) end)
    end
end

local function CollectHarvestableFromFolder(folder, outTable)
    if not folder then return end
    for _, Plant in pairs(folder:GetChildren()) do
        if not Plant then continue end

        local Prompt = Plant:FindFirstChild("ProximityPrompt", true)
        if Prompt and Prompt.Enabled then
            table.insert(outTable, Plant)
        end

        local Fruits = Plant:FindFirstChild("Fruits")
        if Fruits then
            for _, Fruit in pairs(Fruits:GetChildren()) do
                local FruitPrompt = Fruit:FindFirstChild("ProximityPrompt", true)
                if FruitPrompt and FruitPrompt.Enabled then
                    table.insert(outTable, Fruit)
                end
            end
        end
    end
end

local function GetHarvestablePlantsForPlayer(player)
    local harvestable = {}
    local farm = GetPlayerFarm(player)
    if not farm then return harvestable end

    local important = farm:FindFirstChild("Important")
    if not important then return harvestable end

    local plantsPhysical = important:FindFirstChild("Plants_Physical")
    if plantsPhysical then
        CollectHarvestableFromFolder(plantsPhysical, harvestable)
    end

    return harvestable
end

--// Auto Harvest Logic (smooth one-by-one)
local AutoHarvesting = false

local function StartAutoHarvest()
    if AutoHarvesting then return end
    AutoHarvesting = true

    -- spawn a coroutine so UI thread isn't blocked
    task.spawn(function()
        while AutoHarvesting do
            -- refresh plant list each cycle (keeps it robust to changes)
            local plants = GetHarvestablePlantsForPlayer(LocalPlayer)
            for _, plant in ipairs(plants) do
                if not AutoHarvesting then break end
                HarvestPlant(plant)
                task.wait(0.1) -- wait 0.1s between each harvest to avoid spam/lag
            end

            -- small pause before next scan to prevent constant rescanning
            -- tweak this if you want more/less responsiveness
            task.wait(1)
        end
    end)
end

local function StopAutoHarvest()
    AutoHarvesting = false
end

--// Preserve your guard and use it in the toggle handler
Toggle1:OnChanged(function(state)
    if not Toggle1Interacted then
        Toggle1Interacted = true
        return
    end

    if state then
        StartAutoHarvest()
    else
        StopAutoHarvest()
    end
end)

local Toggle3Interacted = false
local BuyGearEnabled = false

local Toggle3 = Tabs.Main:CreateToggle("MyToggle", {
    Title = "Auto Buy",
    Default = false
})

Toggle3:OnChanged(function(state)
    if not Toggle3Interacted then
        Toggle3Interacted = true
        return
    end

    BuyGearEnabled = state

    if BuyGearEnabled then
        task.spawn(function()
            while BuyGearEnabled do
                -- get the UI element
                local title = workspace:WaitForChild("Interaction")
                    :WaitForChild("UpdateItems")
                    :WaitForChild("WitchesBrewEvent")
                    :WaitForChild("WitchesBrewCauldron")
                    :WaitForChild("CauldronProgressUI")
                    :WaitForChild("ProgressBillboard")
                    :WaitForChild("Title")

                -- check if it's visible before firing
                if title.Visible then
                    local args = {
                        "All"
                    }

                    game:GetService("ReplicatedStorage")
                        :WaitForChild("GameEvents")
                        :WaitForChild("WitchesBrew")
                        :WaitForChild("SubmitItemToCauldron")
                        :InvokeServer(unpack(args))
                end

                task.wait(0.1)
            end
        end)
    end
end)
