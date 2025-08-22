-- Whiteout Overlay + Polished Mini HUD (FPS | Ping | RAM | Instances)
-- Place into StarterGui/StarterPlayerScripts as a LocalScript

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local MarketplaceService = game:GetService("MarketplaceService")
local Stats = game:GetService("Stats")

local lp = Players.LocalPlayer
local playerGui = lp:WaitForChild("PlayerGui")

-- ====== Config ======
local HUD_WIDTH, HUD_HEIGHT = 230, 92
local HUD_MARGIN = 12
local UPDATE_INTERVAL = 1 -- seconds
local START_VISIBLE = true -- whiteout start state
-- ======================

-- Root ScreenGui
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "WhiteoutAndHUD"
screenGui.ResetOnSpawn = false
screenGui.IgnoreGuiInset = true
screenGui.Parent = playerGui

-- ---------- Whiteout Frame ----------
local whiteFrame = Instance.new("Frame")
whiteFrame.Name = "WhiteoutFrame"
whiteFrame.Size = UDim2.fromScale(1, 1)
whiteFrame.Position = UDim2.new(0, 0, 0, 0)
whiteFrame.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
whiteFrame.BorderSizePixel = 0
whiteFrame.BackgroundTransparency = 0 -- controlled by transparency var
whiteFrame.Visible = START_VISIBLE
whiteFrame.Parent = screenGui

-- Info label (center)
local infoLabel = Instance.new("TextLabel")
infoLabel.Name = "InfoLabel"
infoLabel.Size = UDim2.new(1, 0, 0, 260)
infoLabel.AnchorPoint = Vector2.new(0.5, 0.5)
infoLabel.Position = UDim2.new(0.5, 0, 0.5, 0)
infoLabel.BackgroundTransparency = 1
infoLabel.TextColor3 = Color3.fromRGB(20, 20, 20)
infoLabel.TextStrokeTransparency = 0.4
infoLabel.Font = Enum.Font.SourceSansBold
infoLabel.TextSize = 28
infoLabel.TextXAlignment = Enum.TextXAlignment.Center
infoLabel.TextYAlignment = Enum.TextYAlignment.Center
infoLabel.LineHeight = 1.08
infoLabel.Parent = screenGui

-- Toggle button (bottom center)
local toggleButton = Instance.new("TextButton")
toggleButton.Name = "ToggleWhiteout"
toggleButton.Size = UDim2.new(0, 200, 0, 44)
toggleButton.AnchorPoint = Vector2.new(0.5, 0.5)
toggleButton.Position = UDim2.new(0.5, 0, 0.92, 0)
toggleButton.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
toggleButton.TextColor3 = Color3.fromRGB(255, 255, 255)
toggleButton.Font = Enum.Font.SourceSansBold
toggleButton.TextSize = 20
toggleButton.Text = START_VISIBLE and "Whiteout: ON" or "Whiteout: OFF"
toggleButton.BorderSizePixel = 0
toggleButton.ZIndex = 1000
toggleButton.Parent = screenGui

-- ---------- Mini HUD ----------
local hudFrame = Instance.new("Frame")
hudFrame.Name = "MiniHUD"
hudFrame.Size = UDim2.new(0, HUD_WIDTH, 0, HUD_HEIGHT)
hudFrame.Position = UDim2.new(1, -HUD_WIDTH - HUD_MARGIN, 0, HUD_MARGIN) -- top-right
hudFrame.BackgroundColor3 = Color3.fromRGB(16, 16, 18)
hudFrame.BackgroundTransparency = 0.12
hudFrame.BorderSizePixel = 0
hudFrame.Parent = screenGui
hudFrame.ZIndex = 2000
hudFrame.Active = true -- for input
-- rounded corners
local hudCorner = Instance.new("UICorner")
hudCorner.CornerRadius = UDim.new(0, 12)
hudCorner.Parent = hudFrame
-- subtle stroke
local hudStroke = Instance.new("UIStroke")
hudStroke.Thickness = 1
hudStroke.Transparency = 0.6
hudStroke.Parent = hudFrame

local hudText = Instance.new("TextLabel")
hudText.Name = "HUDText"
hudText.Size = UDim2.new(1, -14, 1, -14)
hudText.Position = UDim2.new(0, 7, 0, 7)
hudText.BackgroundTransparency = 1
hudText.TextColor3 = Color3.fromRGB(160, 255, 200)
hudText.Font = Enum.Font.Code
hudText.TextSize = 15
hudText.TextXAlignment = Enum.TextXAlignment.Left
hudText.TextYAlignment = Enum.TextYAlignment.Top
hudText.Text = "HUD loading..."
hudText.Parent = hudFrame
hudText.ZIndex = 2001

-- make HUD draggable (custom, robust)
local dragging, dragInput, dragStart, startPos
local function updateHudPosition(input)
	if not dragging then return end
	local delta = input.Position - dragStart
	hudFrame.Position = UDim2.new(
		startPos.X.Scale,
		startPos.X.Offset + delta.X,
		startPos.Y.Scale,
		startPos.Y.Offset + delta.Y
	)
end

hudFrame.InputBegan:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		dragging = true
		dragStart = input.Position
		startPos = hudFrame.Position
		input.Changed:Connect(function()
			if input.UserInputState == Enum.UserInputState.End then
				dragging = false
			end
		end)
	elseif input.UserInputType == Enum.UserInputType.Touch then
		-- support touch
		dragging = true
		dragStart = input.Position
		startPos = hudFrame.Position
	end
end)

hudFrame.InputChanged:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
		dragInput = input
	end
end)

UserInputService.InputChanged:Connect(function(input)
	if input == dragInput then
		updateHudPosition(input)
	end
end)

-- ---------- Internal state ----------
local whiteVisible = START_VISIBLE
local whiteTransparency = 0 -- 0..1 (0 = solid white)
local mapHidden = false
local storedParents = {}
local whiteoutStartTime = os.clock()

-- FPS trackers
local fpsMin, fpsMax, fpsSum, fpsCount = math.huge, 0, 0, 0
local framesAccum = 0
local lastFpsTime = os.clock()

-- Helper: try get ping safely
local function getPing()
	local ok, pingVal = pcall(function()
		local item = Stats.Network and Stats.Network.ServerStatsItem and Stats.Network.ServerStatsItem["Data Ping"]
		if item then return item:GetValue() end
		return 0
	end)
	if ok and pingVal then return math.floor(pingVal) end
	return 0
end

-- Helper: get RAM MB (fallback)
local function getRamMb()
	local ok, val = pcall(function()
		if typeof(Stats.GetTotalMemoryUsageMb) == "function" then
			return Stats:GetTotalMemoryUsageMb()
		end
		-- fallback try workspace memory stat (some runtimes expose)
		if Stats.Workspace and Stats.Workspace.Memory and Stats.Workspace.Memory.CurrentlyUsed then
			return Stats.Workspace.Memory.CurrentlyUsed:GetValue() / 1024 / 1024
		end
		return 0
	end)
	if ok and val then return math.floor(val) end
	return 0
end

-- Hide map by detaching non-character children (safe-ish)
local function hideMap()
	if mapHidden then return end
	mapHidden = true
	storedParents = {}
	for _, obj in ipairs(workspace:GetChildren()) do
		-- keep camera, terrain, and player's character
		if not obj:IsDescendantOf(lp.Character) and obj ~= workspace.CurrentCamera and obj.Name ~= "Terrain" then
			storedParents[obj] = obj.Parent
			obj.Parent = nil
		end
	end
end

local function showMap()
	if not mapHidden then return end
	mapHidden = false
	for obj, parent in pairs(storedParents) do
		if obj and parent then
			obj.Parent = parent
		end
	end
	storedParents = {}
end

-- Apply whiteout state
local function applyWhiteout()
	whiteFrame.Visible = whiteVisible
	whiteFrame.BackgroundTransparency = whiteTransparency
	infoLabel.Visible = whiteVisible
	if whiteVisible then
		hideMap()
		whiteoutStartTime = os.clock()
	else
		showMap()
	end
	toggleButton.Text = whiteVisible and "Whiteout: ON" or "Whiteout: OFF"
end

-- Initial text
local gameName = "Unknown"
pcall(function()
	local ok, info = pcall(function()
		return MarketplaceService:GetProductInfo(game.PlaceId, Enum.InfoType.Asset)
	end)
	if ok and info and typeof(info) == "table" and info.Name then
		gameName = info.Name
	end
end)

infoLabel.Text = string.format(
	"Game: %s\nPlayer: %s (@%s)\nFPS: %d\nWhiteout On: 0s",
	gameName,
	lp.DisplayName or "Player",
	lp.Name or "player",
	0
)

-- Button click
toggleButton.MouseButton1Click:Connect(function()
	whiteVisible = not whiteVisible
	applyWhiteout()
end)

-- Hotkeys:
-- RightShift: toggle whiteout
-- M: toggle HUD visibility
-- [ and ] : increase/decrease transparency (on white frame)
local hudVisible = true
UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then return end
	if input.KeyCode == Enum.KeyCode.RightShift then
		whiteVisible = not whiteVisible
		applyWhiteout()
	elseif input.KeyCode == Enum.KeyCode.M then
		hudVisible = not hudVisible
		hudFrame.Visible = hudVisible
	elseif input.KeyCode == Enum.KeyCode.LeftBracket then
		whiteTransparency = math.clamp(whiteTransparency + 0.05, 0, 1)
		applyWhiteout()
	elseif input.KeyCode == Enum.KeyCode.RightBracket then
		whiteTransparency = math.clamp(whiteTransparency - 0.05, 0, 1)
		applyWhiteout()
	end
end)

-- Auto reapply on respawn
lp.CharacterAdded:Connect(function()
	task.wait(1)
	whiteVisible = true
	whiteTransparency = 0
	applyWhiteout()
end)

-- Stats updater (runs every UPDATE_INTERVAL seconds)
local lastUpdate = os.clock()
RunService.Heartbeat:Connect(function(dt)
	framesAccum = framesAccum + 1
	local now = os.clock()
	if now - lastUpdate >= UPDATE_INTERVAL then
		local fps = math.floor((framesAccum / (now - lastUpdate)) + 0.5)
		framesAccum = 0
		lastUpdate = now

		-- fps stats
		fpsCount = fpsCount + 1
		fpsSum = fpsSum + fps
		if fps < fpsMin then fpsMin = fps end
		if fps > fpsMax then fpsMax = fps end
		local fpsAvg = math.floor((fpsSum / fpsCount) + 0.5)

		-- ping, ram, instances
		local ping = getPing()
		local ram = getRamMb()
		local instances = Stats.InstanceCount or 0

		local elapsed = math.floor(now - whiteoutStartTime)
		local timerText = whiteVisible and string.format("Whiteout On: %ds", elapsed) or "Whiteout Off"

		-- update main info label (center)
		infoLabel.Text = string.format(
			"Game: %s\nPlayer: %s (@%s)\nFPS: %d | AVG: %d | MIN: %d | MAX: %d\nPing: %d ms\nRAM: %d MB | Instances: %d\n%s",
			gameName,
			lp.DisplayName or "Player",
			lp.Name or "player",
			fps, fpsAvg, fpsMin == math.huge and 0 or fpsMin, fpsMax,
			ping,
			ram,
			instances,
			timerText
		)

		-- update mini HUD
		if hudVisible then
			hudText.Text = string.format(
				"FPS: %d\nPing: %d ms\nRAM: %d MB\nInst: %d",
				fps, ping, ram, instances
			)
		end
	end
end)

-- initial apply
applyWhiteout()
hudFrame.Visible = hudVisible
