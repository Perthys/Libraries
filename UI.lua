--[[    UI Library
        6/20/2020

        Library:
            .new(<string> Name, <Vector3> Size)
            :Create(<string> Class, <dictionary> Properties)

	Toggle:
	Slider:
	Dropdown:
	Keybind:

]]--

local Library = {}

local Services = {
	Players = game:GetService("Players"),
	RunService = game:GetService("RunService"),
	CoreGui = game:GetService("CoreGui"),
	InsertService = game:GetService("InsertService"),
	UserInputService = game:GetService("UserInputService"),
	TweenService = game:GetService("TweenService"),
	HttpService = game:GetService("HttpService")
}

local LocalPlayer = Services.Players.LocalPlayer
local LocalMouse = LocalPlayer:GetMouse()
local RenderStepped = Services.RunService.RenderStepped
local Tween = function(...) return Services.TweenService:Create(...) end

local EMPTY_FUNCTION = function()end
local MOUSEBUTTON1 = Enum.UserInputType.MouseButton1
local TOGGLE_KEYCODE = Enum.KeyCode.RightShift
local UNKNOWN_KEYCODE = Enum.KeyCode.Unknown
-- TweenInfo.new(time, Enum.EasingStyle, Enum.EasingDirection)
local OPENCLOSE_INFO = TweenInfo.new(0.6)

local Dragger = {}
do
    -- // credits to Ririchi / Inori for this cute drag function :)
    function Dragger.new(frame, affects)
        local s, event = pcall(function()
            return frame.MouseEnter
        end)
    
        if s then
            frame.Active = true
            
            event:Connect(function()
                local input = frame.InputBegan:Connect(function(Input)
                    if Input.UserInputType == MOUSEBUTTON1 then
                        local objectPosition = Vector2.new(LocalMouse.X - frame.AbsolutePosition.X, LocalMouse.Y - frame.AbsolutePosition.Y)
                        while Services.UserInputService:IsMouseButtonPressed(MOUSEBUTTON1) do
                            RenderStepped:Wait()
                            pcall(function()
                                affects:TweenPosition(UDim2.new(0, LocalMouse.X - objectPosition.X, 0, LocalMouse.Y - objectPosition.Y), 'Out', 'Linear', 0.1, true)
                            end)
                        end
                    end
                end)
    
                local leave;
                leave = frame.MouseLeave:Connect(function()
                    input:Disconnect();
                    leave:Disconnect();
                end)
            end)
        end
    end
end

local RenderStepped = Services.RunService.RenderStepped

local DefaultSettings = {
	["Name"] = "Unnamed",
	["Discord"] = "https://discord.gg/%s",
	["Settings"] = {
		--["Mode"] = "One", -- Modes = {"Tabs", "One"}
		["Font"] = Enum.Font.Code,
		["Background Color"] = Color3.fromRGB(40, 40, 40)
	}
}

local ElevatedContext = pcall(game.GetChildren, Services.CoreGui)

local LoadLocalAsset -- game.GetObjects
if ElevatedContext then
	LoadLocalAsset = function(AssetId)
		return Services.InsertService:LoadLocalAsset(AssetId)
	end
end

function Library.new(LibrarySettings)
	LibrarySettings = setmetatable(LibrarySettings or {}, {__index = DefaultSettings})
	local ScreenGui = LoadLocalAsset and LoadLocalAsset("rbxassetid://5201271925") or game.StarterGui.New:Clone()
	ScreenGui.Name = Services.HttpService:GenerateGUID(false)
	ScreenGui.Enabled = true

	if syn and syn.protect_gui then
		syn.protect_gui(ScreenGui)
	end

	local self = setmetatable({
		Settings = LibrarySettings,
		Templates = ScreenGui.Templates,
		Container = ScreenGui.Main.Container.Content
	}, {__index = Library})

	do
		local Main = ScreenGui.Main
			local Container = Main.Container
			local Top = Main.Top
			Top.Title.Text = LibrarySettings.Name

			local function Toggle()
				Main.Visible = not Main.Visible
			end
            Top.Close.MouseButton1Click:Connect(Toggle)
			
			Top.Settings.MouseButton1Click:Connect(function()
				Container.Content.Visible = not Container.Content.Visible
				Container.Settings.Visible = not Container.Settings.Visible
			end)

			Dragger.new(Top, Main)
		Services.UserInputService.InputBegan:Connect(function(Input)
			if Input.KeyCode == TOGGLE_KEYCODE then
				Toggle()
			end
		end)
	end
	
	self.UpdateContainer = function(_, Container, Abs)
		Abs = Abs or 0

		for _, Element in ipairs(self.Container:GetChildren()) do
			if Element:IsA("Frame") then
				Abs = Abs + Element.AbsoluteSize.Y
				print(Abs, Element.Name)
			end
		end

		Container.CanvasSize = UDim2.new(1, 0, 0, Abs)
	end

	ScreenGui.Parent = ElevatedContext and Services.CoreGui or LocalPlayer:WaitForChild("PlayerGui")
	return self
end

local format = string.format

local function Create(Container, Templates, Class, Properties)
	assert(Templates[Class .. "Element"], format("Invalid Class %s", Class))
	local Object = Templates[Class .. "Element"]:Clone()
	Object.Visible = true
	
	local Callback = Properties.Callback or EMPTY_FUNCTION
	
	local Me = {
		Hook = function(_, func)
			Callback = func
		end,
		Destroy = function()
			Object:Destroy()
		end
	}

	if Class == "Tab" then
		Me.Hook = nil
		print"hah lol i didn't want to actually >:|"
	elseif Class == "Toggle" then
		Object.Label.Text = Properties.Name
		local Toggled = Properties.Value or false
		local BG = Object.Button.BG
		BG.Visible = Toggled

		Object.Button.MouseButton1Click:Connect(function()
			Toggled = not Toggled
			BG.Visible = Toggled
			Callback(Toggled)
		end)
	elseif Class == "Slider" then
		Object.Label.Text = Properties.Name
		local Min, Max = Properties.Min, Properties.Max
		local Value = nil
		local Slide = Object.Slide
		local ValueObj = Slide.BG.Value

		local function Set(Percent)
			local New = math.clamp(math.floor((Min + (Max - Min) * Percent) + 0.5), Min, Max)
			if New ~= Value then
				Value = New
				Slide.BG.Size = UDim2.new(Percent, 0, 1, 0)
				ValueObj.Text = tostring(Value)
				Callback(Value)
			end
		end
		Set(Properties.Value / Max)
		
		local TextFadeIn = Tween(ValueObj, OPENCLOSE_INFO, {TextTransparency = 0})
		local TextFadeOut = Tween(ValueObj, OPENCLOSE_INFO, {TextTransparency = 1})

		Slide.MouseEnter:Connect(function()
			local InputConnection;InputConnection = Slide.InputBegan:Connect(function(Input)
				if Input.UserInputType == MOUSEBUTTON1 then
					TextFadeIn:Play()
					while Services.UserInputService:IsMouseButtonPressed(MOUSEBUTTON1) do
						RenderStepped:Wait()
						local MouseRelativeToSlider = LocalMouse.X - Slide.AbsolutePosition.X
						local Percent = math.clamp(MouseRelativeToSlider / Slide.AbsoluteSize.X, 0, 1) -- Don't want negatives / value > 1
						Set(Percent)
					end
					TextFadeOut:Play()
					InputConnection:Disconnect()
				end
			end)
		end)
	elseif Class == "Dropdown" then
		local Background = Object.Background
		Object.Label.Text = Properties.Name
		local SelectedLabel = Background:FindFirstChild("Selected")

		local ObjectOptions = {}
		local function Set(Value)
			if Value ~= "" then
				Background.Options.Visible = false
				SelectedLabel.Text = Value
				Callback(Value)
			end
		end
		Set(Properties.Value or "")

		local Scroller = Background.Options.Scroller
		local OptionTemplate = Scroller.Option:Clone()
		Scroller.Option:Destroy()

		--local CloseTween = Tween(Object, OPENCLOSE_INFO, {Size = UDim2.new(1, 0, 0, 30)})
		--local OpenTween = Tween(Object, OPENCLOSE_INFO, {Size = UDim2.new(1, 0, 0, 30 + (#Scroller:GetChildren()-2)*25)})

		Background.MouseButton1Click:Connect(function()
			Scroller.Parent.Visible = not Scroller.Parent.Visible
			--CloseTween.Play(State and OpenTween or CloseTween)
		end)

		Me.Update = function(_, Options)
			for _, Obj in ipairs(Scroller:GetChildren()) do
				if Obj:IsA("TextButton") then
					Obj:Destroy()
				end
			end

			for _, OptionName in ipairs(Options) do
				local OptionObject = OptionTemplate:Clone()
				ObjectOptions[OptionName] = OptionObject

				OptionObject.Text = OptionName
				OptionObject.MouseButton1Click:Connect(function()
					Set(OptionName)
				end)

				OptionObject.Visible = true
				OptionObject.Parent = Scroller
			end
			--OpenTween = Tween(Object, OPENCLOSE_INFO, {Size = UDim2.new(1, 0, 0, 30 + Size)})
			--Object.Options.Size = UDim2.new(1, 0, 0, #Options * 25)
			Scroller.CanvasSize = UDim2.new(1, 0, 0, #Options * 25)
		end
		Me:Update(Properties.Options)
	elseif Class == "Keybind" then
		local Button = Object.Button
		local Selection = Object.Button.Label
		Object.Label.Text = Properties.Name
		local BindedCode = UNKNOWN_KEYCODE

		local function Set(KeyCode)
			BindedCode = KeyCode or UNKNOWN_KEYCODE
			Selection.Text = (KeyCode == UNKNOWN_KEYCODE and "N/A" or tostring(KeyCode):sub(14))
		end
		Set(Properties.Key or UNKNOWN_KEYCODE)

		Button.MouseButton1Up:Connect(function()
			Selection.Text = "Waiting..."
			local InputConnection;InputConnection = Services.UserInputService.InputBegan:Connect(function(Input)
				Set(Input.KeyCode)
				InputConnection:Disconnect()
			end)
		end)

		Services.UserInputService.InputBegan:Connect(function(Input)
			if BindedCode ~= UNKNOWN_KEYCODE and Input.KeyCode == BindedCode then
				Callback(true)
			end
		end)

		Services.UserInputService.InputBegan:Connect(function(Input)
			if BindedCode ~= UNKNOWN_KEYCODE and Input.KeyCode == BindedCode then
				Callback(false)
			end
		end)

		Me.Update = function(_, KeyCode)
			Set(KeyCode)
		end
	elseif Class == "Input" then
		Object.Label.Text = Properties.Name

		local Field = Object.Background.Field
		Field.FocusLost:Connect(function()
			if Field.Text ~= "" then
				Callback(Field.Text)
			end
		end)
	end

	Object.Parent = Container
	return Me, Object.AbsoluteSize.Y
end

function Library:Create(Class, Properties)
	local Me, AbsSizeY = Create(self.Container, self.Templates, Class, Properties)
	
	self:UpdateContainer(self.Container, AbsSizeY)
	
	return Me
end

return Library
