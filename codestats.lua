local cfg = {}

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

local studio = settings().Studio
local theme = studio.Theme
local colors = Enum.StudioStyleGuideColor

local tweens = game:GetService("TweenService")

local widget = plugin:CreateDockWidgetPluginGui("Code::Stats", widgetinfo)
widget.Title = "Code::Stats"

widgetbtn.Click:Connect(function()
widget.Enabled = not widget.Enabled
end)

local tokenbtn = toolbar:CreateButton("Set Token", "Sets the machine token to send the xp to", "rbxassetid://12489849699")

tokenbtn.ClickableWhenViewportHidden = true

local tokenwidgetinfo = DockWidgetPluginGuiInfo.new(
Enum.InitialDockState.Float,
false,
false,
300,
200,
300,
200
)

local tokenwidget = plugin:CreateDockWidgetPluginGui("C::S Token Setter", tokenwidgetinfo)
tokenwidget.Title = "Set Code::Stats Token"

local tokenbox = Instance.new("TextBox")
tokenbox.Size = UDim2.fromScale(1, 1)
tokenbox.BackgroundTransparency = 1
tokenbox.TextScaled = true
tokenbox.Font = Enum.Font.Ubuntu
tokenbox.PlaceholderText = "Token goes here"

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

tokenbtn.Click:Connect(function()
tokenwidget.Enabled = true
end)

tokenbox.Parent = tokenwidget

local count = Instance.new("TextLabel")
count.Text = "0"

count.Size = UDim2.fromScale(1, 1)
count.BackgroundTransparency = 1
count.TextScaled = true
count.Font = Enum.Font.Ubuntu

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

count.Parent = widget
studio.ThemeChanged:Connect(synctheme)

cfg.baseUrl = "https://codestats.net/api/"
cfg.token = plugin:GetSetting("Token") or ""

local function isTokenValid()
     return not (not cfg.token or cfg.token == "" or not cfg.token:match("(%w+)%.(%w+)%.(%w+)"))
end

local function url(suffix)
     return cfg.baseUrl .. suffix
end

local http = game:GetService("HttpService")

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

local function timeStamp()
     local off = tonumber(os.date("%z"))
     if not off then
          error("Could not get timezone offset.")
     end
     local prefix = if off < 0 then "-" else "+"
     off = math.abs(off / 100) * 3600
     return os.date("%Y-%m-%dT%H:%M:%S") .. prefix .. os.date("%H:%M", 21600 + off)
end


local function sendPulse(amt, timestamp)
     if not isTokenValid() then
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

local currentdata = {}

currentdata.xp = 0

local function pulseColor(col)
     count.TextColor3 = col
     resettween:Cancel()
     resettween:Play()
end

local function updateCount()
     count.Text = tostring(currentdata.xp)
end

task.defer(function()
while true do
     task.wait(10)
     if currentdata.xp > 0 and isTokenValid() then
          if sendPulse(currentdata.xp, timeStamp()) then
               currentdata.xp = 0
               updateCount()
               pulseColor(Color3.new(0, 1, 0))
          else
               pulseColor(Color3.new(1, 0, 0))
          end
     else
          pulseColor(Color3.new(1, 0, 0))
     end
end
end)

game:GetService("ScriptEditorService").TextDocumentDidChange:Connect(function(doc, changes)
currentdata.xp += 1
updateCount()
end)
