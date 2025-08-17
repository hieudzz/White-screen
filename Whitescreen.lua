-- Whiteout Overlay – LocalScript + Auto Respawn + Timer
local Players = game:GetService("Players")
local UIS = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local MPS = game:GetService("MarketplaceService")
local lp = Players.LocalPlayer

-- GUI
local gui = Instance.new("ScreenGui")
gui.Name = "WhiteoutOverlay"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 999999
gui.Parent = lp:WaitForChild("PlayerGui")

local frame = Instance.new("Frame")
frame.Size = UDim2.fromScale(1, 1)
frame.Position = UDim2.fromScale(0, 0)
frame.BackgroundColor3 = Color3.new(1, 1, 1)
frame.BorderSizePixel = 0
frame.BackgroundTransparency = 0
frame.Parent = gui

-- Lấy tên game
local gameName = "Unknown"
do
	local ok, info = pcall(function()
		return MPS:GetProductInfo(game.PlaceId, Enum.InfoType.Asset)
	end)
	if ok and info and typeof(info) == "table" and info.Name then
		gameName = info.Name
	end
end

-- Label hiển thị
local infoLabel = Instance.new("TextLabel")
infoLabel.Size = UDim2.new(1, 0, 0, 260)
infoLabel.Position = UDim2.new(0.5, 0, 0.5, 0)
infoLabel.AnchorPoint = Vector2.new(0.5, 0.5)
infoLabel.BackgroundTransparency = 1
infoLabel.TextColor3 = Color3.new(0, 0, 0)
infoLabel.TextStrokeTransparency = 0.3
infoLabel.Font = Enum.Font.SourceSansBold
infoLabel.TextSize = 44
infoLabel.TextXAlignment = Enum.TextXAlignment.Center
infoLabel.TextYAlignment = Enum.TextYAlignment.Center
infoLabel.LineHeight = 1.1
infoLabel.Parent = gui

-- Biến
local visible = true -- auto bật
local transparency = 0
local mapHidden = false
local storedParents = {}
local whiteoutStartTime = os.clock() -- lưu thời gian bật whiteout

-- Ẩn map (trừ nhân vật + camera)
local function hideMap()
	if mapHidden then return end
	mapHidden = true
	storedParents = {}
	for _, obj in ipairs(workspace:GetChildren()) do
		if not obj:IsDescendantOf(lp.Character) and obj ~= workspace.CurrentCamera and obj.Name ~= "Terrain" then
			storedParents[obj] = obj.Parent
			obj.Parent = nil
		end
	end
end

-- Hiện map lại
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

-- Áp dụng trạng thái
local function apply()
	frame.Visible = visible
	frame.BackgroundTransparency = transparency
	infoLabel.Visible = visible
	if visible then
		hideMap()
		whiteoutStartTime = os.clock() -- reset timer khi bật lại
	else
		showMap()
	end
end

-- Hiển thị ban đầu (FPS=0, Timer=0)
infoLabel.Text = string.format(
	"Game: %s\nPlayer: %s (@%s)\nFPS: %d\nWhiteout On: 0s",
	gameName,
	lp.DisplayName,
	lp.Name,
	0
)

-- Chạy auto bật khi load
apply()

-- Cập nhật FPS + Timer
local lastUpdate = os.clock()
local frames = 0
RunService.Heartbeat:Connect(function()
	frames += 1
	local now = os.clock()
	if now - lastUpdate >= 1 then
		local fps = frames / (now - lastUpdate)
		frames = 0
		lastUpdate = now

		local elapsed = math.floor(now - whiteoutStartTime)
		local timerText = visible and string.format("Whiteout On: %ds", elapsed) or "Whiteout Off"

		infoLabel.Text = string.format(
			"Game: %s\nPlayer: %s (@%s)\nFPS: %d\n%s",
			gameName,
			lp.DisplayName,
			lp.Name,
			math.floor(fps + 0.5),
			timerText
		)
	end
end)

-- Auto bật lại khi respawn
lp.CharacterAdded:Connect(function()
	task.wait(1) -- chờ nhân vật load xong
	visible = true
	apply()
end)

-- Phím tắt
UIS.InputBegan:Connect(function(input, gp)
	if gp then return end
	if input.KeyCode == Enum.KeyCode.RightShift then
		visible = not visible
		apply()
	elseif input.KeyCode == Enum.KeyCode.LeftBracket then
		transparency = math.clamp(transparency + 0.05, 0, 1)
		apply()
	elseif input.KeyCode == Enum.KeyCode.RightBracket then
		transparency = math.clamp(transparency - 0.05, 0, 1)
		apply()
	end
end)
