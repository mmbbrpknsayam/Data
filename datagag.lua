--------------------------------------------------------
-- ⚙️ SERVICES
--------------------------------------------------------
local Players = game:GetService("Players")
local PathfindingService = game:GetService("PathfindingService")
local LocalPlayer = Players.LocalPlayer

local Character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
local Humanoid = Character:WaitForChild("Humanoid")
local HumanoidRootPart = Character:WaitForChild("HumanoidRootPart")

--------------------------------------------------------
-- 🧭 PATHFINDING FUNCTION
--------------------------------------------------------
local function moveTo(targetPart)
	if not targetPart or not targetPart.Position then return end

	local path = PathfindingService:CreatePath({
		AgentRadius = 2,
		AgentHeight = 5,
		AgentCanJump = true
	})

	path:ComputeAsync(HumanoidRootPart.Position, targetPart.Position)
	if path.Status == Enum.PathStatus.Success then
		for _, waypoint in ipairs(path:GetWaypoints()) do
			if waypoint.Action == Enum.PathWaypointAction.Jump then
				Humanoid.Jump = true
			end
			Humanoid:MoveTo(waypoint.Position)
			Humanoid.MoveToFinished:Wait()
		end
	else
		-- fallback direct move
		Humanoid:MoveTo(targetPart.Position)
		Humanoid.MoveToFinished:Wait()
	end

	-- ensure humanoid is close enough
	repeat task.wait(0.1) until (HumanoidRootPart.Position - targetPart.Position).Magnitude < 5
end

--------------------------------------------------------
-- 🔧 AUTO REPAIR LOGIC
--------------------------------------------------------
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
			task.wait(4)
			if repairing and progress.Value < 100 then
				pcall(function()
					re:FireServer()
				end)
			end
		end
	end)
end

--------------------------------------------------------
-- 🔍 FIND NEAREST GENERATOR
--------------------------------------------------------
local function getNearestGeneratorBelow100()
	local mapFolder = workspace:FindFirstChild("Map")
	if not mapFolder then return nil end

	local ingame = mapFolder:FindFirstChild("Ingame")
	if not ingame then return nil end

	local map = ingame:FindFirstChild("Map")
	if not map then return nil end

	local nearest = nil
	local shortest = math.huge

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

--------------------------------------------------------
-- 🤖 AUTO REPAIR LOOP (CENTER → RIGHT → LEFT)
--------------------------------------------------------
local function autoRepairLoop()
	print("🧠 Waiting for map and generators...")
	local map = workspace:WaitForChild("Map"):WaitForChild("Ingame"):WaitForChild("Map")

	-- Wait until at least one generator exists
	repeat
		task.wait(1)
	until map:FindFirstChild("Generator")

	print("✅ Generators found! Starting auto repair loop...")

	while task.wait(1) do
		if repairing then continue end

		local gen = getNearestGeneratorBelow100()
		if not gen then
			print("✅ All generators repaired! Waiting for match reset...")
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
				print("🧭 Moving to", posName, "position of generator:", gen:GetFullName())
				moveTo(targetPart)

				-- Fire prompt when in range
				fireproximityprompt(prompt)

				-- Check if PuzzleUI appeared
				task.wait(0.5)
				if Players.LocalPlayer.PlayerGui:FindFirstChild("PuzzleUI") then
					print("✅ PuzzleUI detected! Starting auto repair.")
					startAutoRepair(gen)
					break
				end
			end
		end
	end
end

--------------------------------------------------------
-- 🔁 AUTO RESTART ON MAP RESET
--------------------------------------------------------
local function onMapReset()
	print("🔄 Map reset detected — restarting auto generator system...")
	stopAutoRepair()

	task.wait(6) -- Wait for new map to fully load
	Character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
	Humanoid = Character:WaitForChild("Humanoid")
	HumanoidRootPart = Character:WaitForChild("HumanoidRootPart")

	task.spawn(autoRepairLoop)
end

--------------------------------------------------------
-- 🚀 INITIALIZE SYSTEM
--------------------------------------------------------
local function initAutoSystem()
	print("✅ Auto Generator System initialized.")
	task.spawn(autoRepairLoop)

	workspace.Map.Ingame.ChildRemoved:Connect(function(child)
		if child.Name == "Map" then
			onMapReset()
		end
	end)
end

-- Wait for player character & update references
LocalPlayer.CharacterAdded:Connect(function(char)
	Character = char
	Humanoid = char:WaitForChild("Humanoid")
	HumanoidRootPart = char:WaitForChild("HumanoidRootPart")
end)

task.spawn(initAutoSystem)
