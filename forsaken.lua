--// Services
local Players = game:GetService("Players")
local PathfindingService = game:GetService("PathfindingService")

local LocalPlayer = Players.LocalPlayer
local Character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
local Humanoid = Character:WaitForChild("Humanoid")
local RootPart = Character:WaitForChild("HumanoidRootPart")

Humanoid.UseJumpPower = true
Humanoid.JumpPower = 0

--// Folders
local MAP_ROOT = workspace:WaitForChild("Map"):WaitForChild("Ingame")

--// Movement
local function moveTo(pos)
	if not pos then return end
	local path = PathfindingService:CreatePath({
		AgentRadius = 2,
		AgentHeight = 5,
		AgentCanJump = false,
	})
	path:ComputeAsync(RootPart.Position, pos)
	if path.Status == Enum.PathStatus.Success then
		for _, wp in ipairs(path:GetWaypoints()) do
			Humanoid:MoveTo(wp.Position)
			Humanoid.MoveToFinished:Wait()
		end
	else
		Humanoid:MoveTo(pos)
		Humanoid.MoveToFinished:Wait()
	end
end

--// Auto Repair
local repairing = false
local currentGen = nil
local repairThread = nil

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
	if not (progress and remotes) then return end

	local re = remotes:FindFirstChild("RE")
	if not (re and re:IsA("RemoteEvent")) then return end

	currentGen = generator
	repairing = true

	print("[AUTO REPAIR] Started:", generator:GetFullName())

	local progressConn
	progressConn = progress:GetPropertyChangedSignal("Value"):Connect(function()
		if progress.Value >= 100 then
			progressConn:Disconnect()
			stopAutoRepair()
		end
	end)

	repairThread = task.spawn(function()
		while repairing and currentGen == generator do
			if progress.Value >= 100 then
				stopAutoRepair()
				break
			end
			task.wait(4)
			if repairing then
				pcall(re.FireServer, re)
			end
		end
	end)
end

--// RF Hooking
local hookedRF = {}
local rfToGenerator = {}

local function hookGeneratorRF(gen)
	local remotes = gen:FindFirstChild("Remotes")
	if not remotes then return end
	local rf = remotes:FindFirstChild("RF")
	if not rf or hookedRF[rf] then return end

	rfToGenerator[rf] = gen

	local old = hookfunction(rf.InvokeServer, function(self, ...)
		local args = {...}
		if args[1] == "enter" then
			local g = rfToGenerator[self]
			if g then
				print("[RF DETECTED] enter →", g.Name)
				startAutoRepair(g)
			end
		end
		return old(self, ...)
	end)

	hookedRF[rf] = old
end

local function hookAllGenerators()
	local map = MAP_ROOT:FindFirstChild("Map")
	if not map then return end
	for _, gen in ipairs(map:GetChildren()) do
		if gen.Name == "Generator" then
			hookGeneratorRF(gen)
		end
	end
end

MAP_ROOT.ChildAdded:Connect(function(child)
	if child.Name == "Map" then
		child.ChildAdded:Connect(function(g)
			if g.Name == "Generator" then
				hookGeneratorRF(g)
			end
		end)
		hookAllGenerators()
	end
end)

hookAllGenerators()

--// Helper
local function getNearestGeneratorBelow100()
	local map = MAP_ROOT:FindFirstChild("Map")
	if not map then return nil end
	local nearest, shortest = nil, math.huge
	for _, gen in ipairs(map:GetChildren()) do
		if gen.Name == "Generator" then
			local progress = gen:FindFirstChild("Progress")
			local positions = gen:FindFirstChild("Positions")
			if progress and progress.Value < 100 and positions and positions:FindFirstChild("Center") then
				local dist = (RootPart.Position - positions.Center.Position).Magnitude
				if dist < shortest then
					shortest = dist
					nearest = gen
				end
			end
		end
	end
	return nearest
end

local function tryEnterGenerator(generator)
	if not generator then return end
	local positions = generator:FindFirstChild("Positions")
	if not positions then return end
	local order = {"Center", "Left", "Right"}

	for _, name in ipairs(order) do
		local pos = positions:FindFirstChild(name)
		if pos then
			moveTo(pos.Position)
			task.wait(0.2)
			for _, desc in ipairs(generator:GetDescendants()) do
				if desc:IsA("ProximityPrompt") then
					pcall(fireproximityprompt, desc)
				end
			end
		end
	end
end

--// Main Auto Match Loop
task.spawn(function()
	while true do
		local map = MAP_ROOT:WaitForChild("Map", 60)
		if not map then task.wait(1) continue end

		hookAllGenerators()

		while true do
			local gen = getNearestGeneratorBelow100()
			if not gen then break end
			tryEnterGenerator(gen)
			repeat task.wait(0.5) until not repairing
		end

		-- Wait for map reset between matches
		local rootMap = MAP_ROOT:FindFirstChild("Map")
		if rootMap then
			repeat task.wait(0.5) until not rootMap.Parent or not rootMap:IsDescendantOf(workspace)
		end
		task.wait(1)
	end
end)

print("[SYSTEM] Auto Generator: Running (instant RF detection, no timeout).")
