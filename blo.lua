local Library = loadstring(game:HttpGetAsync("https://github.com/ActualMasterOogway/Fluent-Renewed/releases/latest/download/Fluent.luau"))()

local Window = Library:CreateWindow{
    Title = 'Forsaken by Cloud',
    SubTitle = "https://discord.gg/tkA8JkqS8",
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
        Title = "Main",
        Icon = "nil"
    }
}

local staminainput = require(game.ReplicatedStorage.Systems.Character.Game.Sprinting)

local Toggle1 Tabs.Main:CreateToggle("MyToggle", {Title = "inf stamina", Default = false})

Toggle1:OnChanged(function()
    if not Toggle1Interacted then
        Toggle1Interacted = true
        return
    end

    infstam = not infstam

    if infstam then
        staminainput.StaminaLossDisabled = true
	else
		staminainput.StaminaLossDisabled = false
	end
end)

Tabs.Main:CreateButton({
    Title = "auto generators",
    Description = "",
    Callback = function()
        local repairing = false
        local currentGen = nil
        local repairThread = nil
        local genConnections = {}

        local function stopAutoRepair()
            if repairThread then
                pcall(task.cancel, repairThread)
                repairThread = nil
            end
            repairing = false
            currentGen = nil
        end

        local function startAutoRepair(generator)
            stopAutoRepair()
            if not generator or not generator.Parent then return end

            local progress = generator:FindFirstChild("Progress")
            local remotes = generator:FindFirstChild("Remotes")
            if not (progress and progress:IsA("NumberValue")) then return end
            if not remotes then return end

            local re = remotes:FindFirstChild("RE")
            if not (re and re:IsA("RemoteEvent")) then return end

            currentGen = generator
            repairing = true

            local progressConn
            progressConn = progress:GetPropertyChangedSignal("Value"):Connect(function()
                if progress.Value >= 100 then
                    progressConn:Disconnect()
                    stopAutoRepair()
                end
            end)
            table.insert(genConnections, progressConn)

            repairThread = task.spawn(function()
                while repairing and currentGen == generator do
                    if progress.Value >= 100 then
                        stopAutoRepair()
                        break
                    end
                    task.wait(gentime)
                    if repairing and progress.Value < 100 then
                        pcall(function()
                            re:FireServer()
                        end)
                    end
                end
            end)
        end

        local function setupGenerator(gen)
            if not gen or not gen:IsA("Model") then return end
            if genConnections[gen] then return end

            local prompt
            local main = gen:FindFirstChild("Main")
            if main then
                prompt = main:FindFirstChildWhichIsA("ProximityPrompt", true) or main:FindFirstChild("Prompt")
            end
            if not prompt then
                prompt = gen:FindFirstChildWhichIsA("ProximityPrompt", true)
            end

            if prompt then
                local conn = prompt.Triggered:Connect(function()
                    local progress = gen:FindFirstChild("Progress")
                    if progress and progress.Value < 100 then
                        startAutoRepair(gen)
                    end
                end)
                table.insert(genConnections, conn)
                genConnections[gen] = true
            end
        end

        local function setupMap()

            for _, conn in ipairs(genConnections) do
                pcall(function() conn:Disconnect() end)
            end
            genConnections = {}

            local map = workspace:WaitForChild("Map"):WaitForChild("Ingame"):WaitForChild("Map")
            for _, g in ipairs(map:GetChildren()) do
                pcall(setupGenerator, g)
            end

            map.ChildAdded:Connect(function(child)
                pcall(setupGenerator, child)
            end)
        end

        setupMap()

        workspace.Map.Ingame.ChildRemoved:Connect(function(child)
            if child.Name == "Map" then

                task.spawn(function()
                    local newMap = workspace.Map.Ingame:WaitForChild("Map")
                    setupMap()
                end)
            end
        end)
    end
})

local Toggle9 = Tabs.Main:CreateToggle("MyToggle", {Title = "auto block", Default = false})

local blockEnabled = false
local Toggle9Interacted = false
local humConnections = {}

Toggle9:OnChanged(function()
    if not Toggle9Interacted then
        Toggle9Interacted = true
        return
    end

    blockEnabled = not blockEnabled

    local Players = game:GetService("Players")
    local ReplicatedStorage = game:GetService("ReplicatedStorage")
    local workspace = game:GetService("Workspace")

    local LocalPlayer = Players.LocalPlayer
    local KillersFolder = workspace:WaitForChild("Players"):WaitForChild("Killers")
    local RANGE = 13

    local TARGET_ANIM_BY_NAME = {
        ["c00lkidd"] = {
            ["18885909645"] = {}
        },
        ["JohnDoe"] = {
            ["105458270463374"] = {}
        },
        ["Noli"] = {
            ["106538427162796"] = {}
        },
        ["1x1x1x1"] = {
            ["83829782357897"] = {}
        },
        ["Slasher"] = {
            ["126355327951215"] = {},
            ["121086746534252"] = {},
            ["126830014841198"] = {}
        }
    }

    local function fireSkill()
        local args = { "UseActorAbility", { buffer.fromstring("\"Block\"") } }
        ReplicatedStorage.Modules.Network.RemoteEvent:FireServer(unpack(args))
        print("Fired UseActorAbility")
    end

    local function hookHumanoid(humanoid, model)
        local targetAnims = TARGET_ANIM_BY_NAME[model.Name]
        if not targetAnims then return end

        local myHRP = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
        local targetHRP = model:FindFirstChild("HumanoidRootPart")

        local function onAnim(track)
            if not blockEnabled then return end
            local anim = track.Animation
            local animId = anim and anim.AnimationId and tostring(anim.AnimationId):match("%d+")
            if animId and targetAnims[animId] then
                if myHRP and targetHRP then
                    local distance = (myHRP.Position - targetHRP.Position).Magnitude
                    if distance <= RANGE then
                        local animData = targetAnims[animId]
                        if animData.delay then
                            task.delay(animData.delay, fireSkill)
                        else
                            fireSkill()
                        end
                    end
                end
            end
        end

        local animator = humanoid:FindFirstChildOfClass("Animator")
        local conn
        if animator then
            conn = animator.AnimationPlayed:Connect(onAnim)
        else
            conn = humanoid.AnimationPlayed:Connect(onAnim)
        end
        table.insert(humConnections, conn)
    end

    if blockEnabled then

        for _, killer in ipairs(KillersFolder:GetChildren()) do
            local hum = killer:FindFirstChildOfClass("Humanoid")
            if hum then
                hookHumanoid(hum, killer)
            end
        end

        local descConn
        descConn = KillersFolder.DescendantAdded:Connect(function(desc)
            if not blockEnabled then
                descConn:Disconnect()
                return
            end
            if desc:IsA("Humanoid") then
                local model = desc.Parent
                if model and model:IsA("Model") then
                    hookHumanoid(desc, model)
                end
            end
        end)
        table.insert(humConnections, descConn)
    else

        for _, conn in ipairs(humConnections) do
            if conn and conn.Disconnect then
                conn:Disconnect()
            end
        end
        humConnections = {}
    end
end)

local Tabs = {
    Main = Window:CreateTab{
        Title = "esp",
        Icon = "nil"
    }
}

local Toggle2 = Tabs.Main:CreateToggle("MyToggle", {Title = "esp generator", Default = false})

Toggle2:OnChanged(function()
    if not Toggle2Interacted then
        Toggle2Interacted = true
        return
    end

    espGenerator = not espGenerator
    local connections = {}

    local function updateHighlight(generator, highlight)
        local numVal = generator:FindFirstChildWhichIsA("NumberValue")
        if numVal then
            if numVal.Value < 100 then
                highlight.FillColor = Color3.fromRGB(0, 0, 255)
                highlight.OutlineColor = Color3.fromRGB(0, 0, 127)
            else
                highlight.FillColor = Color3.fromRGB(0, 255, 0)
                highlight.OutlineColor = Color3.fromRGB(0, 170, 0)
            end
        end
    end

    local function createHighlight(generator)
        if generator:FindFirstChild("CustomHighlight") then return end
        if not generator:IsA("Model") then return end
        if generator.Name ~= "Generator" then return end

        local highlight = Instance.new("Highlight")
        highlight.Name = "CustomHighlight"
        highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
        highlight.FillTransparency = 0.5
        highlight.OutlineTransparency = 0
        highlight.Parent = generator

        updateHighlight(generator, highlight)

        local numVal = generator:FindFirstChildWhichIsA("NumberValue")
        if numVal then
            table.insert(connections, numVal:GetPropertyChangedSignal("Value"):Connect(function()
                updateHighlight(generator, highlight)
            end))
        end
    end

    local function applyToMap(map)
        -- Apply to all current generators
        for _, obj in ipairs(map:GetChildren()) do
            if obj.Name == "Generator" then
                createHighlight(obj)
            end
        end

        table.insert(connections, map.ChildAdded:Connect(function(child)
            if child.Name == "Generator" then
                createHighlight(child)
            end
        end))
    end

    if espGenerator then

        local function hookMap(map)
            if map.Name == "Map" then
                applyToMap(map)
            end
        end

        local ingame = workspace:WaitForChild("Map"):WaitForChild("Ingame")
        for _, child in ipairs(ingame:GetChildren()) do
            hookMap(child)
        end

        table.insert(connections, ingame.ChildAdded:Connect(hookMap))
    else

        for _, c in ipairs(connections) do
            c:Disconnect()
        end
        table.clear(connections)

        local currentMap = workspace:FindFirstChild("Map") and workspace.Map.Ingame:FindFirstChild("Map")
        if currentMap then
            for _, obj in ipairs(currentMap:GetChildren()) do
                if obj.Name == "Generator" then
                    local hl = obj:FindFirstChild("CustomHighlight")
                    if hl then
                        hl:Destroy()
                    end
                end
            end
        end
    end
end)

local Toggle3 = Tabs.Main:CreateToggle("MyToggle", {Title = "esp survivor", Default = false})

Toggle3:OnChanged(function()
    if not Toggle3Interacted then
        Toggle3Interacted = true
        return
    end

    espSurvivor = not espSurvivor

    local SurvivorFolder = workspace.Players.Survivors

    local function createHighlight(model)
        local highlight = Instance.new("Highlight")
        highlight.Name = "CustomHighlight"
        highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
        highlight.FillColor = Color3.fromRGB(255, 191, 0)
        highlight.FillTransparency = 0.5
        highlight.OutlineColor = Color3.fromRGB(255, 191, 0)
        highlight.OutlineTransparency = 0
        highlight.Parent = model
    end

    if espSurvivor then

        for _, model in ipairs(SurvivorFolder:GetChildren()) do
            if model:IsA("Model") then
                createHighlight(model)
            end
        end

        SurvivorFolder.ChildAdded:Connect(function(child)
            if child:IsA("Model") then
                createHighlight(child)
            end
        end)
    else

        for _, model in ipairs(SurvivorFolder:GetChildren()) do
            local hl = model:FindFirstChild("CustomHighlight")
            if hl then
                hl:Destroy()
            end
        end
    end
end)

local Toggle4 = Tabs.Main:CreateToggle("MyToggle", {Title = "esp killer", Default = false})

Toggle4:OnChanged(function()
    if not Toggle4Interacted then
        Toggle4Interacted = true
        return
    end

    espKiller = not espKiller

    local KillerFolder = workspace.Players.Killers

    local function createHighlight(model)
        local highlight = Instance.new("Highlight")
        highlight.Name = "CustomHighlight"
        highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
        highlight.FillColor = Color3.fromRGB(255, 0, 0)
        highlight.FillTransparency = 0.5
        highlight.OutlineColor = Color3.fromRGB(170, 0, 0)
        highlight.OutlineTransparency = 0
        highlight.Parent = model
    end

    if espKiller then

        for _, model in ipairs(KillerFolder:GetChildren()) do
            if model:IsA("Model") then
                createHighlight(model)
            end
        end

        KillerFolder.ChildAdded:Connect(function(child)
            if child:IsA("Model") then
                createHighlight(child)
            end
        end)
    else

        for _, model in ipairs(KillerFolder:GetChildren()) do
            local hl = model:FindFirstChild("CustomHighlight")
            if hl then
                hl:Destroy()
            end
        end
    end
end)

local Tabs = {
    Main = Window:CreateTab{
        Title = "Setting",
        Icon = "nil"
    }
}

local staminainput = require(game.ReplicatedStorage.Systems.Character.Game.Sprinting)

local Input = Tabs.Main:CreateInput("Input", {
    Title = "Stamina",
    Default = "",
    Placeholder = "",
    Numeric = true,
    Finished = false,
    Callback = function(Value)

        local num = tonumber(Value)
        if num then

            staminainput.DefaultConfig.MaxStamina = num
            staminainput.MaxStamina = num
            staminainput.Stamina = num
        end
    end
})

local Input = Tabs.Main:CreateInput("Input", {
    Title = "Generator time",
    Default = "3.5",
    Placeholder = "",
    Numeric = true,
    Finished = false,
    Callback = function(Value)

        local num = tonumber(Value)
        if num then

            gentime = num
        end
    end
})
