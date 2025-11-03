local Players = game:GetService("Players")
local PathfindingService = game:GetService("PathfindingService")
local LocalPlayer = Players.LocalPlayer
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local module_upvr = require(ReplicatedStorage.Systems.Character.Game.Sprinting)

if not module_upvr.DefaultsSet then
    module_upvr.Init()
end

local Character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
local Humanoid = Character:WaitForChild("Humanoid")
local HumanoidRootPart = Character:WaitForChild("HumanoidRootPart")

local function moveTo(targetPart)
	if not targetPart or not targetPart.Position then return end

	local path = PathfindingService:CreatePath({
		AgentRadius = 2,
		AgentHeight = 5,
		AgentCanJump = false
	})

	path:ComputeAsync(HumanoidRootPart.Position, targetPart.Position)
	if path.Status == Enum.PathStatus.Success then
		for _, waypoint in ipairs(path:GetWaypoints()) do
			Humanoid:MoveTo(waypoint.Position)
			Humanoid.MoveToFinished:Wait()
		end
	else
		Humanoid:MoveTo(targetPart.Position)
		Humanoid.MoveToFinished:Wait()
	end

	repeat task.wait(0.1) until (HumanoidRootPart.Position - targetPart.Position).Magnitude < 5
end

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

	task.spawn(function()
		while repairing and currentGen == generator do
			local puzzleUI = Players.LocalPlayer.PlayerGui:FindFirstChild("PuzzleUI")
			if not puzzleUI and progress.Value < 100 then
				local positions = generator:FindFirstChild("Positions")
				local main = generator:FindFirstChild("Main")
				local prompt = main and (main:FindFirstChild("Prompt") or main:FindFirstChildWhichIsA("ProximityPrompt"))
				if positions and prompt then
					local retryTarget = positions:FindFirstChild("Center") or positions:FindFirstChildWhichIsA("BasePart")
					if retryTarget then
						moveTo(retryTarget)
						fireproximityprompt(prompt)
					end
				end
			end
			task.wait(0.3)
		end
	end)

	repairThread = task.spawn(function()
		-- fast watcher for instant completion
		task.spawn(function()
			while repairing and currentGen == generator do
				if progress.Value >= 100 then
					stopAutoRepair()
					break
				end
				task.wait(0.2)
			end
		end)

		while repairing and currentGen == generator do
			task.wait(4)
			if repairing and progress.Value < 100 then
				pcall(function()
					re:FireServer()
				end)
			end
		end
	end)
end

local function getNearestGeneratorBelow100()
	local mapFolder = workspace:FindFirstChild("Map")
	if not mapFolder then return nil end

	local ingame = mapFolder:FindFirstChild("Ingame")
	if not ingame then return nil end

	local map = ingame:FindFirstChild("Map")
	if not map then return nil end

	local nearest, shortest = nil, math.huge

	for _, gen in ipairs(map:GetChildren()) do
		if gen.Name == "Generator" then
			local progress = gen:FindFirstChild("Progress")
			local positions = gen:FindFirstChild("Positions")
			if progress and progress:IsA("NumberValue") and progress.Value < 100 and positions then
				local center = positions:FindFirstChild("Center")
				if center then
					local dist = (HumanoidRootPart.Position - center.Position).Magnitude
					if dist < shortest then
						shortest = dist
						nearest = gen
					end
				end
			end
		end
	end

	return nearest
end

local function autoRepairLoop()
	local map = workspace:WaitForChild("Map"):WaitForChild("Ingame"):WaitForChild("Map")

	repeat task.wait(1) until map:FindFirstChild("Generator")

	while task.wait(1) do
		if repairing then continue end

		local gen = getNearestGeneratorBelow100()
		if not gen then
			break
		end

		local positionsFolder = gen:FindFirstChild("Positions")
		local main = gen:FindFirstChild("Main")
		local prompt = main and (main:FindFirstChild("Prompt") or main:FindFirstChildWhichIsA("ProximityPrompt"))
		if not positionsFolder or not prompt then continue end

		local positions = {"Center", "Right", "Left"}
		for _, posName in ipairs(positions) do
			local targetPart = positionsFolder:FindFirstChild(posName)
			if targetPart then
				moveTo(targetPart)

				fireproximityprompt(prompt)
				task.wait(0.5)

				if Players.LocalPlayer.PlayerGui:FindFirstChild("PuzzleUI") then
					startAutoRepair(gen)
					break
				end
			end
		end
	end
end

local function toggleSprintAfterDelay()

    task.wait(6)

    module_upvr.__sprintedEvent:Fire(true)
end

local function onMapReset()
	stopAutoRepair()

	task.wait(6)
	Character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
	Humanoid = Character:WaitForChild("Humanoid")
	HumanoidRootPart = Character:WaitForChild("HumanoidRootPart")

	task.spawn(autoRepairLoop)

end

workspace.Map.Ingame.ChildAdded:Connect(function(child)
    if child.Name == "Map" then
        task.spawn(toggleSprintAfterDelay)
    end
end)

local function initAutoSystem()
	task.spawn(autoRepairLoop)

	workspace.Map.Ingame.ChildRemoved:Connect(function(child)
		if child.Name == "Map" then
			onMapReset()
		end
	end)
end

LocalPlayer.CharacterAdded:Connect(function(char)
	Character = char
	Humanoid = char:WaitForChild("Humanoid")
	HumanoidRootPart = char:WaitForChild("HumanoidRootPart")
end)

task.spawn(initAutoSystem)
