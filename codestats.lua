local cfg = {}
cfg.baseUrl = "https://codestats.net/api/"
cfg.token = plugin:GetSetting("Token") or ""

local currentdata = {}
currentdata.xp = 0

local http = game:GetService("HttpService")

local toolbar = plugin:CreateToolbar("Code::Stats")

local widgetbtn = toolbar:CreateButton("Toggle Widget", "Toggles visiblity of Code::Stats widget", "rbxassetid://12474703887")
widgetbtn.ClickableWhenViewportHidden = true

local widgetinfo = DockWidgetPluginGuiInfo.new(
	Enum.InitialDockState.Float,
	false,
	false,
	150,
	150,
	150,
	150
)

local tokenwidgetinfo = DockWidgetPluginGuiInfo.new(
	Enum.InitialDockState.Float,
	false,
	false,
	300,
	200,
	300,
	200
)

local studio = settings().Studio
local theme = studio.Theme
local colors = Enum.StudioStyleGuideColor

local tweens = game:GetService("TweenService")

local widget = plugin:CreateDockWidgetPluginGui("Code::Stats", widgetinfo)
widget.Title = "Code::Stats"

widgetbtn.Click:Connect(function()
	widget.Enabled = not widget.Enabled
end)

local tokenwidget = plugin:CreateDockWidgetPluginGui("C::S Token Setter", tokenwidgetinfo)
tokenwidget.Title = "Set Code::Stats Token"

local tokenbtn = toolbar:CreateButton("Set Token", "Sets the machine token to send the xp to", "rbxassetid://12489849699")
tokenbtn.ClickableWhenViewportHidden = true

tokenbtn.Click:Connect(function()
	tokenwidget.Enabled = true
end)

local tokenbox = Instance.new("TextBox")
do
	tokenbox.Size = UDim2.fromScale(1, 1)
	tokenbox.BackgroundTransparency = 1
	tokenbox.TextScaled = true
	tokenbox.Font = Enum.Font.Ubuntu
	tokenbox.PlaceholderText = "Token goes here"
	tokenbox.Text = ""
	tokenbox.FocusLost:Connect(function(entered)
		if not entered then
			return
		end
		tokenwidget.Enabled = false
		local text = tokenbox.Text
		tokenbox.Text = ""
		cfg.token = text
		plugin:SetSetting("Token", text)
	end)

	tokenbox.Parent = tokenwidget
end

local count = Instance.new("TextLabel")
do
	count.Text = "0"
	count.Size = UDim2.fromScale(1, 1)
	count.BackgroundTransparency = 1
	count.TextScaled = true
	count.Font = Enum.Font.Ubuntu

	count.Parent = widget
end

local function getcolors()
	return theme:GetColor(colors.MainText), theme:GetColor(colors.MainBackground), theme:GetColor(colors.DimmedText)
end

local resettween

local function synctheme()
	local text, back, dimtext = getcolors()
	count.TextColor3 = text
	count.BackgroundColor3 = back
	tokenbox.TextColor3 = text
	tokenbox.PlaceholderColor3 = dimtext
	resettween = tweens:Create(count, TweenInfo.new(1), {TextColor3 = text, BackgroundColor3 = back})
end

synctheme()

studio.ThemeChanged:Connect(synctheme)

local function validtoken()
	return not (not cfg.token or cfg.token == "" or not cfg.token:match("(%w+)%.(%w+)%.(%w+)"))
end

local function request(options)
	local s, res = pcall(function()
		return http:RequestAsync(options)
	end)
	if not s then
		warn("Http request error: " .. tostring(res))
		return
	end
	return res
end

local function timestamp()
	local off = tonumber(os.date("%z"))
	if not off then
		error("Could not get timezone offset.")
	end
	local prefix = if off < 0 then "-" else "+"
	off = math.abs(off / 100) * 3600
	return os.date("%Y-%m-%dT%H:%M:%S") .. prefix .. os.date("%H:%M", 21600 + off)
end

local function url(suffix)
	return cfg.baseUrl .. suffix
end

local function sendpulse(amt, timestamp)
	if not validtoken() then
		error("Invalid token.")
	end
	amt = math.round(amt)

	if amt < 0 then
		error("Invalid amount")
	end

	local res = request({
		Url = url("my/pulses"),
		Method = "POST",
		Headers = {
			["Content-Type"] = "application/json",
			["X-API-Token"] = cfg.token
		},
		Body = http:JSONEncode({
			["coded_at"] = timestamp,
			["xps"] = {
				{
					["language"] = "Lua",
					["xp"] = amt
				}
			}
		})
	})
	if not res then
		warn("Pulse request failed.")
		return false
	end
	return true
end

local function pulsecolor(col)
	count.TextColor3 = col
	resettween:Cancel()
	resettween:Play()
end

local function updatecount()
	count.Text = tostring(currentdata.xp)
end

task.defer(function()
	while true do
		task.wait(10)
		if currentdata.xp > 0 and validtoken() then
			if sendpulse(currentdata.xp, timestamp()) then
				currentdata.xp = 0
				updatecount()
				pulsecolor(Color3.new(0, 1, 0))
			else
				pulsecolor(Color3.new(1, 0, 0))
			end
		end
	end
end)

game:GetService("ScriptEditorService").TextDocumentDidChange:Connect(function(doc, changes)
	currentdata.xp += 1
	updatecount()
end)
