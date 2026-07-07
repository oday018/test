-- ENVY HUB - MOBILE BUTTONS ONLY
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local HttpService = game:GetService("HttpService")

local LP = Players.LocalPlayer
if not LP then LP = Players.PlayerAdded:Wait() end

local gui = Instance.new("ScreenGui")
gui.Name = "EnvyHubMobileButtons"
gui.ResetOnSpawn = false
gui.DisplayOrder = 95
gui.IgnoreGuiInset = true
if not pcall(function() gui.Parent = game:GetService("CoreGui") end) then
	gui.Parent = LP:WaitForChild("PlayerGui")
end

-- ==================== MOBILE PANEL ====================
local BTN_SIZE = 58
local BTN_GAP  = 14
local PADDING  = 6
local COLS     = 2
local ROWS     = 4
local PANEL_W  = PADDING * 2 + COLS * BTN_SIZE + (COLS - 1) * BTN_GAP
local PANEL_H  = PADDING * 2 + ROWS * BTN_SIZE + (ROWS - 1) * BTN_GAP

local MobilePanel = Instance.new("Frame")
MobilePanel.Name = "MobileButtonsPanel"
MobilePanel.Size = UDim2.new(0, PANEL_W, 0, PANEL_H)
MobilePanel.Position = UDim2.new(1, -(PANEL_W + 20), 0, 20)  -- الفوق يمين
MobilePanel.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
MobilePanel.BackgroundTransparency = 1
MobilePanel.BorderSizePixel = 0
MobilePanel.ZIndex = 95
MobilePanel.Parent = gui

-- Draggable function
local function makeDraggable(frame)
	local dragging, dragInput, dragStart, startPos = false, nil, nil, nil
	frame.InputBegan:Connect(function(inp)
		if inp.UserInputType == Enum.UserInputType.MouseButton1 or inp.UserInputType == Enum.UserInputType.Touch then
			dragging = true
			dragStart = inp.Position
			startPos = frame.Position
			inp.Changed:Connect(function()
				if inp.UserInputState == Enum.UserInputState.End then dragging = false end
			end)
		end
	end)
	frame.InputChanged:Connect(function(inp)
		if inp.UserInputType == Enum.UserInputType.MouseMovement or inp.UserInputType == Enum.UserInputType.Touch then
			dragInput = inp
		end
	end)
	game:GetService("UserInputService").InputChanged:Connect(function(inp)
		if inp == dragInput and dragging then
			local d = inp.Position - dragStart
			frame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset+d.X, startPos.Y.Scale, startPos.Y.Offset+d.Y)
		end
	end)
end

makeDraggable(MobilePanel)

-- Colors
local Q_OFF      = Color3.fromRGB(0,   0,   0)
local Q_ON       = Color3.fromRGB(255, 255, 255)
local Q_TEXT_OFF = Color3.fromRGB(255, 255, 255)
local Q_TEXT_ON  = Color3.fromRGB(0,   0,   0)

-- State
local State = {
	dropActive = false,
	autoLeftEnabled = false,
	autoBatEnabled = false,
	autoRightEnabled = false,
	speedToggled = false,
	laggerEnabled = false,
}

-- Speed variables
local NS = 60  -- Normal Speed
local CS = 30  -- Carry Speed
local LS = 15  -- Lagger Speed
local LS2 = 24.5  -- Lagger Carry Speed

-- Animation points
local AP = {
	L1=Vector3.new(-476.48,-6.28,92.73),
	L2=Vector3.new(-483.12,-4.95,94.80),
	R1=Vector3.new(-476.16,-6.52,25.62),
	R2=Vector3.new(-483.06,-5.03,25.48),
}

local Conns = {
	autoLeft = nil,
	autoRight = nil,
	batAimbot = nil,
}

-- ==================== FUNCTIONS ====================

-- Drop Brainrot
local function runDrop()
	if State.dropActive then return end
	local char = LP.Character
	if not char then return end
	local root = char:FindFirstChild("HumanoidRootPart")
	if not root then return end
	
	State.dropActive = true
	local t0 = tick()
	local dc
	dc = RunService.Heartbeat:Connect(function()
		local r = char and char:FindFirstChild("HumanoidRootPart")
		if not r then
			dc:Disconnect()
			State.dropActive = false
			return
		end
		if tick() - t0 >= 0.2 then
			dc:Disconnect()
			local rp = RaycastParams.new()
			rp.FilterDescendantsInstances = {char}
			rp.FilterType = Enum.RaycastFilterType.Exclude
			local rr = workspace:Raycast(r.Position, Vector3.new(0, -2000, 0), rp)
			if rr then
				local hum = char:FindFirstChildOfClass("Humanoid")
				local off = (hum and hum.HipHeight or 2) + (r.Size.Y / 2)
				r.CFrame = CFrame.new(r.Position.X, rr.Position.Y + off, r.Position.Z)
				r.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
			end
			State.dropActive = false
			return
		end
		r.AssemblyLinearVelocity = Vector3.new(r.AssemblyLinearVelocity.X, 150, r.AssemblyLinearVelocity.Z)
	end)
end

-- TP Down
local function runTPDown()
	local char = LP.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if not root then return end
	
	local rp = RaycastParams.new()
	rp.FilterDescendantsInstances = {char}
	rp.FilterType = Enum.RaycastFilterType.Exclude
	local result = workspace:Raycast(root.Position, Vector3.new(0, -1000, 0), rp)
	if result then
		local hum = char:FindFirstChildOfClass("Humanoid")
		local hipOffset = (hum and hum.HipHeight or 2) + (root.Size.Y / 2)
		local targetPos = result.Position + Vector3.new(0, hipOffset, 0)
		root.CFrame = CFrame.new(targetPos) * root.CFrame.Rotation
	end
end

-- Auto Left
local function stopAutoLeft()
	if Conns.autoLeft then
		Conns.autoLeft:Disconnect()
		Conns.autoLeft = nil
	end
	local char = LP.Character
	if char then
		local hum = char:FindFirstChildOfClass("Humanoid")
		if hum then hum:Move(Vector3.zero, false) end
	end
end

local function startAutoLeft()
	if Conns.autoLeft then Conns.autoLeft:Disconnect() end
	
	local phase = 1
	Conns.autoLeft = RunService.Heartbeat:Connect(function()
		if not State.autoLeftEnabled then return end
		
		local char = LP.Character
		if not char then return end
		local hrp = char:FindFirstChild("HumanoidRootPart")
		local hum = char:FindFirstChildOfClass("Humanoid")
		if not hrp or not hum then return end
		
		local spd = NS
		
		if phase == 1 then
			local tgt = Vector3.new(AP.L1.X, hrp.Position.Y, AP.L1.Z)
			if (tgt - hrp.Position).Magnitude < 1 then
				phase = 2
				local d = AP.L2 - hrp.Position
				local mv = Vector3.new(d.X, 0, d.Z).Unit
				hum:Move(mv, false)
				hrp.AssemblyLinearVelocity = Vector3.new(mv.X*spd, hrp.AssemblyLinearVelocity.Y, mv.Z*spd)
				return
			end
			local d = AP.L1 - hrp.Position
			local mv = Vector3.new(d.X, 0, d.Z).Unit
			hum:Move(mv, false)
			hrp.AssemblyLinearVelocity = Vector3.new(mv.X*spd, hrp.AssemblyLinearVelocity.Y, mv.Z*spd)
		elseif phase == 2 then
			local tgt = Vector3.new(AP.L2.X, hrp.Position.Y, AP.L2.Z)
			if (tgt - hrp.Position).Magnitude < 1 then
				hum:Move(Vector3.zero, false)
				hrp.AssemblyLinearVelocity = Vector3.zero
				State.autoLeftEnabled = false
				if Conns.autoLeft then
					Conns.autoLeft:Disconnect()
					Conns.autoLeft = nil
				end
				phase = 1
				return
			end
			local d = AP.L2 - hrp.Position
			local mv = Vector3.new(d.X, 0, d.Z).Unit
			hum:Move(mv, false)
			hrp.AssemblyLinearVelocity = Vector3.new(mv.X*spd, hrp.AssemblyLinearVelocity.Y, mv.Z*spd)
		end
	end)
end

-- Auto Right
local function stopAutoRight()
	if Conns.autoRight then
		Conns.autoRight:Disconnect()
		Conns.autoRight = nil
	end
	local char = LP.Character
	if char then
		local hum = char:FindFirstChildOfClass("Humanoid")
		if hum then hum:Move(Vector3.zero, false) end
	end
end

local function startAutoRight()
	if Conns.autoRight then Conns.autoRight:Disconnect() end
	
	local phase = 1
	Conns.autoRight = RunService.Heartbeat:Connect(function()
		if not State.autoRightEnabled then return end
		
		local char = LP.Character
		if not char then return end
		local hrp = char:FindFirstChild("HumanoidRootPart")
		local hum = char:FindFirstChildOfClass("Humanoid")
		if not hrp or not hum then return end
		
		local spd = NS
		
		if phase == 1 then
			local tgt = Vector3.new(AP.R1.X, hrp.Position.Y, AP.R1.Z)
			if (tgt - hrp.Position).Magnitude < 1 then
				phase = 2
				local d = AP.R2 - hrp.Position
				local mv = Vector3.new(d.X, 0, d.Z).Unit
				hum:Move(mv, false)
				hrp.AssemblyLinearVelocity = Vector3.new(mv.X*spd, hrp.AssemblyLinearVelocity.Y, mv.Z*spd)
				return
			end
			local d = AP.R1 - hrp.Position
			local mv = Vector3.new(d.X, 0, d.Z).Unit
			hum:Move(mv, false)
			hrp.AssemblyLinearVelocity = Vector3.new(mv.X*spd, hrp.AssemblyLinearVelocity.Y, mv.Z*spd)
		elseif phase == 2 then
			local tgt = Vector3.new(AP.R2.X, hrp.Position.Y, AP.R2.Z)
			if (tgt - hrp.Position).Magnitude < 1 then
				hum:Move(Vector3.zero, false)
				hrp.AssemblyLinearVelocity = Vector3.zero
				State.autoRightEnabled = false
				if Conns.autoRight then
					Conns.autoRight:Disconnect()
					Conns.autoRight = nil
				end
				phase = 1
				return
			end
			local d = AP.R2 - hrp.Position
			local mv = Vector3.new(d.X, 0, d.Z).Unit
			hum:Move(mv, false)
			hrp.AssemblyLinearVelocity = Vector3.new(mv.X*spd, hrp.AssemblyLinearVelocity.Y, mv.Z*spd)
		end
	end)
end

-- Bat Aimbot
local function stopBatAimbot()
	if Conns.batAimbot then
		Conns.batAimbot:Disconnect()
		Conns.batAimbot = nil
	end
	local c = LP.Character
	local root = c and c:FindFirstChild("HumanoidRootPart")
	if root then
		root.AssemblyLinearVelocity = Vector3.zero
		root.AssemblyAngularVelocity = Vector3.zero
	end
end

local function findBat()
	local char = LP.Character
	if not char then return nil end
	
	for _, tool in ipairs(char:GetChildren()) do
		if tool:IsA("Tool") and (tool.Name:lower():find("bat") or tool.Name:lower():find("slap")) then
			return tool
		end
	end
	
	local bp = LP:FindFirstChild("Backpack")
	if bp then
		for _, tool in ipairs(bp:GetChildren()) do
			if tool:IsA("Tool") and (tool.Name:lower():find("bat") or tool.Name:lower():find("slap")) then
				return tool
			end
		end
	end
	return nil
end

local function getClosestTarget()
	local root = LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
	if not root then return nil end
	
	local closest, minDist = nil, math.huge
	for _, plr in ipairs(Players:GetPlayers()) do
		if plr ~= LP and plr.Character then
			local tRoot = plr.Character:FindFirstChild("HumanoidRootPart")
			local hum = plr.Character:FindFirstChildOfClass("Humanoid")
			if tRoot and hum and hum.Health > 0 then
				local dist = (tRoot.Position - root.Position).Magnitude
				if dist < minDist then
					minDist = dist
					closest = tRoot
				end
			end
		end
	end
	return closest
end

local function startBatAimbot()
	if Conns.batAimbot then Conns.batAimbot:Disconnect() end
	
	Conns.batAimbot = RunService.RenderStepped:Connect(function()
		if not State.autoBatEnabled then return end
		
		local char = LP.Character
		if not char then return end
		local root = char:FindFirstChild("HumanoidRootPart")
		if not root then return end
		local hum = char:FindFirstChildOfClass("Humanoid")
		if not hum then return end
		
		if not char:FindFirstChildOfClass("Tool") then
			local bat = findBat()
			if bat then pcall(function() hum:EquipTool(bat) end) end
		end
		
		local target = getClosestTarget()
		if not target then return end
		
		local targetVel = target.AssemblyLinearVelocity
		local myPos = root.Position
		local targetPos = target.Position
		
		local predictPos = targetPos + targetVel * 0.14
		predictPos = predictPos + target.CFrame.LookVector * 0.3
		
		local direction = predictPos - myPos
		local flatDir = Vector3.new(direction.X, 0, direction.Z).Unit
		local chaseSpeed = 58
		
		local desiredHeight = targetPos.Y + 3.7
		local yVel = (desiredHeight - myPos.Y) * 19.5 + targetVel.Y * 0.8
		if hum.FloorMaterial ~= Enum.Material.Air then
			yVel = math.max(yVel, 13)
		end
		yVel = math.clamp(yVel, -70, 110)
		
		local desiredVel = Vector3.new(flatDir.X * chaseSpeed, yVel, flatDir.Z * chaseSpeed)
		root.AssemblyLinearVelocity = root.AssemblyLinearVelocity:Lerp(desiredVel, 0.8)
		
		local speed3 = targetVel.Magnitude
		local predictTime = math.clamp(speed3 / 150, 0.05, 0.2)
		local predictedPos = targetPos + targetVel * predictTime
		local toPredict = predictedPos - myPos
		if toPredict.Magnitude > 0.1 then
			local goalCF = CFrame.lookAt(myPos, predictedPos)
			local curCF = root.CFrame
			local diffCF = curCF:Inverse() * goalCF
			local rx, ry, rz = diffCF:ToEulerAnglesXYZ()
			rx = math.clamp(rx, -2.5, 2.5)
			ry = math.clamp(ry, -2.5, 2.5)
			rz = math.clamp(rz, -2.5, 2.5)
			local tiltSpeed = 42
			root.AssemblyAngularVelocity = root.CFrame:VectorToWorldSpace(
				Vector3.new(rx * tiltSpeed, ry * tiltSpeed, rz * tiltSpeed)
			)
		end
	end)
end

-- Create Button
local function createMobileButton(name, displayText, col, row, isToggle, onAction)
	local xPos = PADDING + col * (BTN_SIZE + BTN_GAP)
	local yPos = PADDING + row * (BTN_SIZE + BTN_GAP)

	local btn = Instance.new("TextButton")
	btn.Name = "Btn_" .. name
	btn.Size = UDim2.new(0, BTN_SIZE, 0, BTN_SIZE)
	btn.Position = UDim2.new(0, xPos, 0, yPos)
	btn.BackgroundColor3 = Q_OFF
	btn.Text = displayText
	btn.TextColor3 = Q_TEXT_OFF
	btn.TextScaled = false
	btn.TextSize = 11
	btn.Font = Enum.Font.GothamBold
	btn.TextWrapped = true
	btn.LineHeight = 1.2
	btn.BorderSizePixel = 0
	btn.AutoButtonColor = false
	btn.ZIndex = 99
	btn.Parent = MobilePanel
	Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 12)

	local isOn = false
	local function setter(s)
		isOn = s
		TweenService:Create(btn, TweenInfo.new(0.15), {
			BackgroundColor3 = s and Q_ON or Q_OFF,
			TextColor3 = s and Q_TEXT_ON or Q_TEXT_OFF,
		}):Play()
	end

	local function flash()
		TweenService:Create(btn, TweenInfo.new(0.08), {BackgroundColor3=Color3.fromRGB(200,200,200), TextColor3=Q_TEXT_ON}):Play()
		task.delay(0.22, function()
			TweenService:Create(btn, TweenInfo.new(0.15), {BackgroundColor3=Q_OFF, TextColor3=Q_TEXT_OFF}):Play()
		end)
	end

	btn.Activated:Connect(function()
		if isToggle then
			isOn = not isOn
			setter(isOn)
			if onAction then onAction(isOn) end
		else
			flash()
			if onAction then onAction() end
		end
	end)

	return btn, setter
end

-- ==================== CREATE BUTTONS ====================

-- Row 0: DROP | AUTO LEFT
createMobileButton("Drop", "DROP\nBR", 0, 0, false, function()
	task.spawn(runDrop)
end)

local _, setAutoLeft = createMobileButton("AutoLeft", "AUTO\nLEFT", 1, 0, true, function(on)
	State.autoLeftEnabled = on
	if on then
		if State.autoRightEnabled then
			State.autoRightEnabled = false
			stopAutoRight()
		end
		if State.autoBatEnabled then
			State.autoBatEnabled = false
			stopBatAimbot()
		end
		startAutoLeft()
	else
		stopAutoLeft()
	end
end)

-- Row 1: BAT AIMBOT | AUTO RIGHT
local _, setAutoBat = createMobileButton("AutoBat", "BAT\nAIMBOT", 0, 1, true, function(on)
	State.autoBatEnabled = on
	if on then startBatAimbot() else stopBatAimbot() end
end)

local _, setAutoRight = createMobileButton("AutoRight", "AUTO\nRIGHT", 1, 1, true, function(on)
	State.autoRightEnabled = on
	if on then
		if State.autoLeftEnabled then
			State.autoLeftEnabled = false
			stopAutoLeft()
		end
		if State.autoBatEnabled then
			State.autoBatEnabled = false
			stopBatAimbot()
		end
		startAutoRight()
	else
		stopAutoRight()
	end
end)

-- Row 2: TP DOWN | CARRY SPD
createMobileButton("TPDown", "TP\nDOWN", 0, 2, false, function()
	task.spawn(runTPDown)
end)

local _, setCarrySpeed = createMobileButton("Speed", "CARRY\nSPD", 1, 2, true, function(on)
	State.speedToggled = on
end)

-- Row 3: LAGGER | LAGGER CARRY
local _, setLagger = createMobileButton("Lagger", "LAGGER\nMODE", 0, 3, true, function(on)
	State.laggerEnabled = on
end)

local _, setLaggerCarry = createMobileButton("LaggerCarry", "LAGGER\nCARRY", 1, 3, true, function(on)
	State.laggerEnabled = on
end)

print("[Envy Hub Mobile] تم التحديث! الأزرار في الفوق يمين 🎮")
