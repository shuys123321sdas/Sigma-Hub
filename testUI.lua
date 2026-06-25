--[[ KyokaUI (SigmaUI.lua) — Fishing + Quest + Haki tabs ]]
-- KYOKA_MODULE=ui

local KyokaUI = {}

local function uiLog(_opts, _msg)
end

local function formatUptime(seconds)
	local s = math.max(0, math.floor(seconds or 0))
	local h = math.floor(s / 3600)
	local m = math.floor((s % 3600) / 60)
	local sec = s % 60
	if h > 0 then
		return string.format("%02d:%02d:%02d", h, m, sec)
	end
	return string.format("%02d:%02d", m, sec)
end

local function themeNames(hub)
	local names = {}
	if hub and hub.GetThemes then
		local themes = hub:GetThemes()
		if type(themes) == "table" then
			for key in pairs(themes) do
				names[#names + 1] = key
			end
		end
	end
	if #names < 1 then
		names = { "Kyoka", "Dark", "Violet", "Light" }
	end
	table.sort(names)
	return names
end

local function hideEmptyPlaceholder(tab)
	if not tab or not tab.UIElements or not tab.UIElements.ContainerFrame then
		return
	end
	local scroll = tab.UIElements.ContainerFrame
	for _, child in ipairs(scroll:GetChildren()) do
		if child:IsA("Frame") and child:FindFirstChildOfClass("UIListLayout") then
			for _, label in ipairs(child:GetDescendants()) do
				if label:IsA("TextLabel") and label.Text == "This tab is Empty" then
					child.Visible = false
					return
				end
			end
		end
	end
end

local function countElements(tab)
	if not tab or not tab.Elements then
		return 0
	end
	return #tab.Elements
end

function KyokaUI.build(hub, Fish, opts)
	opts = opts or {}
	local notify = opts.notify or function(_, title, content)
		hub:Notify({ Title = title, Content = content, Duration = 3 })
	end
	local PRIMARY = opts.primary or Color3.fromRGB(139, 92, 246)
	local uiOpenAt = os.clock()

	local cfg = getgenv().KyokaFishConfig or {}
	cfg.AutoFish = cfg.AutoFish == true
	cfg.AutoQuest = cfg.AutoQuest == true
	cfg.AutoExpertise = cfg.AutoExpertise == true
	cfg.AutoCookSell = cfg.AutoCookSell ~= false
	cfg.AutoSpawn = cfg.AutoSpawn ~= false
	cfg.AntiAfk = cfg.AntiAfk ~= false
	cfg.AutoReloadConfig = cfg.AutoReloadConfig ~= false
	cfg.AutoKenbunshoku = cfg.AutoKenbunshoku == true
	cfg.AutoBusoshoku = cfg.AutoBusoshoku == true
	cfg.FastHaki = cfg.FastHaki == true
	cfg.AutoRayleigh = cfg.AutoRayleigh == true
	cfg.AutoAffinity = cfg.AutoAffinity == true
	cfg.HideName = cfg.HideName ~= false
	cfg.AutoClaimSam = cfg.AutoClaimSam == true
	cfg.AutoDropCompass = cfg.AutoDropCompass == true
	cfg.AutoFindSam = cfg.AutoFindSam == true
	cfg.AutoSkill = cfg.AutoSkill == true
	cfg.SkillHoldSec = tonumber(cfg.SkillHoldSec) or 0.5
	cfg.SkillKeys = cfg.SkillKeys or {}
	cfg.AutoWhitelistRejoin = cfg.AutoWhitelistRejoin == true
	cfg.RejoinWhitelist = tostring(cfg.RejoinWhitelist or "")
	cfg.CacheUsePick = cfg.CacheUsePick or {}
	cfg.CacheDropPick = cfg.CacheDropPick or {}
	cfg.AutoCacheDrop = cfg.AutoCacheDrop == true
	cfg.AutoUseConsumables = cfg.AutoUseConsumables ~= false
	cfg.AffinityMelee = cfg.AffinityMelee
	cfg.AffinitySword = cfg.AffinitySword
	cfg.AffinitySniper = cfg.AffinitySniper
	cfg.AffinityDefense = cfg.AffinityDefense
	cfg.SellAt = tonumber(cfg.SellAt) or 40
	cfg.QuestPick = cfg.QuestPick or {}
	cfg.Theme = cfg.Theme or "Kyoka"
	getgenv().KyokaFishConfig = cfg
	getgenv().__KYOKA_SUPPRESS_UI_CALLBACKS = false

	local function uiCallback(fn)
		return function(...)
			if getgenv().__KYOKA_SUPPRESS_UI_CALLBACKS then return end
			return fn(...)
		end
	end

	local questOptions = (Fish and Fish.getQuestList and Fish.getQuestList()) or {}
	local themes = themeNames(hub)
	if not table.find(themes, cfg.Theme) then
		cfg.Theme = themes[1] or "Kyoka"
	end

	uiLog(opts, "CreateWindow...")
	local Window = hub:CreateWindow({
		Title = "Kyoka Hub",
		Author = "One Piece: Final",
		Icon = "fish",
		Folder = "KyokaHub",
		Theme = cfg.Theme,
		Size = UDim2.new(0, 620, 0, 480),
		ToggleKey = Enum.KeyCode.RightShift,
		Resizable = true,
		Transparent = false,
		Acrylic = false,
		ScrollBarEnabled = true,
		User = { Enabled = true },
		OpenButton = {
			Enabled = true,
			OnlyMobile = false,
			Title = "Kyoka Hub",
			Icon = "fish",
			Draggable = true,
			OnlyIcon = false,
			Position = UDim2.new(0.5, 0, 0, 48),
			Color = ColorSequence.new({
				ColorSequenceKeypoint.new(0, Color3.fromHex("#8b5cf6")),
				ColorSequenceKeypoint.new(1, Color3.fromHex("#6d28d9")),
			}),
		},
	})

	getgenv().__KYOKA_UI_WINDOW = Window
	local Players = game:GetService("Players")
	local HIDE_ALIAS = "Kyoka Hub"

	local function applyUiHideName()
		local hide = (getgenv().KyokaFishConfig or {}).HideName ~= false
		if Window.User and Window.User.SetAnonymous then
			Window.User:SetAnonymous(hide)
			if hide then
				task.defer(function()
					for _, d in ipairs(Players.LocalPlayer.PlayerGui:GetDescendants()) do
						if d:IsA("TextLabel") then
							if d.Name == "DisplayName" and d.Text == "Anonymous" then
								d.Text = HIDE_ALIAS
							elseif d.Name == "UserName" and d.Text == "anonymous" then
								d.Text = "kyokahub"
							end
						end
					end
				end)
			end
		end
		if Window.EditOpenButton then
			pcall(function()
				Window:EditOpenButton({ Title = hide and HIDE_ALIAS or "Kyoka Hub" })
			end)
		end
	end
	getgenv().KyokaApplyUiHideName = applyUiHideName

	local function copyConfigTable(src)
		local out = {}
		if type(src) ~= "table" then return out end
		for k, v in pairs(src) do
			if type(v) == "table" then
				local nested = {}
				for k2, v2 in pairs(v) do nested[k2] = v2 end
				out[k] = nested
			else
				out[k] = v
			end
		end
		return out
	end

	local function normalizeKyokaConfig(raw)
		local base = getgenv().KyokaFishConfig or {}
		local c = copyConfigTable(type(raw) == "table" and raw or base)
		c.AutoFish = c.AutoFish == true
		c.AutoQuest = c.AutoQuest == true
		c.AutoExpertise = c.AutoExpertise == true
		c.AutoCookSell = c.AutoCookSell ~= false
		c.AutoSpawn = c.AutoSpawn ~= false
		c.AntiAfk = c.AntiAfk ~= false
		c.AutoReloadConfig = c.AutoReloadConfig ~= false
		c.AutoKenbunshoku = c.AutoKenbunshoku == true
		c.AutoBusoshoku = c.AutoBusoshoku == true
		c.FastHaki = c.FastHaki == true
		c.AutoRayleigh = c.AutoRayleigh == true
		c.AutoAffinity = c.AutoAffinity == true
		c.HideName = c.HideName ~= false
		c.AutoClaimSam = c.AutoClaimSam == true
		c.AutoDropCompass = c.AutoDropCompass == true
		c.AutoFindSam = c.AutoFindSam == true
		c.AutoSkill = c.AutoSkill == true
		c.AutoWhitelistRejoin = c.AutoWhitelistRejoin == true
		c.AutoCacheDrop = c.AutoCacheDrop == true
		c.AutoUseConsumables = c.AutoUseConsumables ~= false
		c.SkillHoldSec = tonumber(c.SkillHoldSec) or 0.5
		c.SkillKeys = c.SkillKeys or {}
		c.RejoinWhitelist = tostring(c.RejoinWhitelist or "")
		c.CacheUsePick = c.CacheUsePick or {}
		c.CacheDropPick = c.CacheDropPick or {}
		c.SellAt = tonumber(c.SellAt) or 40
		c.QuestPick = c.QuestPick or {}
		c.Theme = c.Theme or cfg.Theme or "Kyoka"
		c.HideUiFirstLoad = c.HideUiFirstLoad == true
		c.UiPanelBackground = c.UiPanelBackground == true
		c.UiTransparent = c.UiTransparent == true
		c.UiTransparency = math.clamp(tonumber(c.UiTransparency) or 55, 10, 95)
		return c
	end

	local uiFirstMinimizeDone = false

	local function applyUiAppearance(c)
		c = normalizeKyokaConfig(c or getgenv().KyokaFishConfig or cfg)
		if Window.SetPanelBackground then
			pcall(function() Window:SetPanelBackground(c.UiPanelBackground == true) end)
		end
		if Window.SetBackgroundTransparency then
			pcall(function()
				if c.UiTransparent then
					Window:SetBackgroundTransparency(c.UiTransparency / 100)
				else
					Window:SetBackgroundTransparency(0)
				end
			end)
		elseif Window.ToggleTransparency then
			pcall(function() Window:ToggleTransparency(c.UiTransparent == true) end)
		end
	end
	getgenv().KyokaApplyUiAppearance = applyUiAppearance

	local function tryFirstLoadMinimize(c)
		if uiFirstMinimizeDone then return end
		c = normalizeKyokaConfig(c or getgenv().KyokaFishConfig or cfg)
		if c.HideUiFirstLoad ~= true then return end
		if not Window or not Window.Close then return end
		task.defer(function()
			task.wait(0.4)
			if uiFirstMinimizeDone then return end
			if not Window or Window.Destroyed or not Window.Close then return end
			if Window.Closed then
				uiFirstMinimizeDone = true
				return
			end
			pcall(function() Window:Close() end)
			uiFirstMinimizeDone = true
		end)
	end
	getgenv().KyokaTryFirstLoadMinimize = tryFirstLoadMinimize

	local configFile
	local syncConfigFromUi
	local applyConfigToUi
	local applyBackendFromConfig
	local collectConfigFromUi
	local readConfigSnapshotFromFile

	local ELEMENT_FLAG_KEYS = {
		Kyoka_AutoFish = "AutoFish",
		Kyoka_AutoQuest = "AutoQuest",
		Kyoka_AutoExpertise = "AutoExpertise",
		Kyoka_AutoCookSell = "AutoCookSell",
		Kyoka_AutoSpawn = "AutoSpawn",
		Kyoka_AntiAfk = "AntiAfk",
		Kyoka_AutoKenbunshoku = "AutoKenbunshoku",
		Kyoka_AutoBusoshoku = "AutoBusoshoku",
		Kyoka_FastHaki = "FastHaki",
		Kyoka_AutoRayleigh = "AutoRayleigh",
		Kyoka_AutoAffinity = "AutoAffinity",
		Kyoka_HideName = "HideName",
		Kyoka_AutoClaimSam = "AutoClaimSam",
		Kyoka_AutoDropCompass = "AutoDropCompass",
		Kyoka_AutoFindSam = "AutoFindSam",
		Kyoka_AutoSkill = "AutoSkill",
		Kyoka_AutoWhitelistRejoin = "AutoWhitelistRejoin",
		Kyoka_AutoCacheDrop = "AutoCacheDrop",
		Kyoka_AutoUseConsumables = "AutoUseConsumables",
	}

	local function readConfigFileData()
		if not configFile or not configFile.Path then return nil end
		if type(isfile) ~= "function" or not isfile(configFile.Path) then return nil end
		if type(readfile) ~= "function" then return nil end
		local ok, data = pcall(function()
			return game:GetService("HttpService"):JSONDecode(readfile(configFile.Path))
		end)
		if ok and type(data) == "table" then return data end
		return nil
	end

	readConfigSnapshotFromFile = function()
		local data = readConfigFileData()
		if type(data) ~= "table" then return nil end
		local custom = data.__custom
		if type(custom) == "table" and type(custom.KyokaFishConfig) == "table" then
			return copyConfigTable(custom.KyokaFishConfig)
		end
		local elements = data.__elements
		if type(elements) ~= "table" then return nil end
		local fromFlags = {}
		for flag, key in pairs(ELEMENT_FLAG_KEYS) do
			local el = elements[flag] or elements[tostring(flag)]
			if type(el) == "table" and el.value ~= nil then
				fromFlags[key] = el.value == true
			end
		end
		if next(fromFlags) then
			return normalizeKyokaConfig(fromFlags)
		end
		return nil
	end

	local function reinforceLoadedConfig(c)
		if type(c) ~= "table" then return end
		c = normalizeKyokaConfig(c)
		cfg = c
		getgenv().KyokaFishConfig = c
		getgenv().__KYOKA_SUPPRESS_UI_CALLBACKS = true
		if applyConfigToUi then applyConfigToUi(c) end
		getgenv().__KYOKA_SUPPRESS_UI_CALLBACKS = false
		if applyBackendFromConfig then applyBackendFromConfig(c) end
	end

	if Window.ConfigManager then
		configFile = Window.ConfigManager:Config("kyoka-fish")
		if configFile and configFile.SetAsCurrent then
			configFile:SetAsCurrent()
		end
		if configFile and configFile.SetAutoLoad then
			configFile:SetAutoLoad(false)
		end
	end

	local function persistConfigMeta()
		if not configFile then return end
		local snap = normalizeKyokaConfig(getgenv().KyokaFishConfig or cfg)
		cfg = snap
		getgenv().KyokaFishConfig = snap
		getgenv().__KYOKA_SUPPRESS_UI_CALLBACKS = true
		if applyConfigToUi then applyConfigToUi(snap) end
		getgenv().__KYOKA_SUPPRESS_UI_CALLBACKS = false
		if configFile.Set then
			configFile:Set("Theme", snap.Theme or (hub.GetCurrentTheme and hub:GetCurrentTheme()) or "Kyoka")
			configFile:Set("AutoReloadConfig", snap.AutoReloadConfig == true)
			configFile:Set("KyokaFishConfig", snap)
		end
	end

	local function saveConfig()
		if not configFile or not configFile.Save then
			notify(hub, "Config", "Config system unavailable", "triangle-alert")
			return false
		end
		persistConfigMeta()
		local ok, err = pcall(function()
			configFile:Save()
		end)
		if ok then
			notify(hub, "Config", "Saved kyoka-fish.json", "save", 3)
			return true
		end
		notify(hub, "Config", "Save failed: " .. tostring(err), "triangle-alert", 4)
		return false
	end

	applyBackendFromConfig = function(c)
		if not c then return end
		c = normalizeKyokaConfig(c)
		cfg = c
		getgenv().KyokaFishConfig = c
		if Fish and Fish.applyConfig then
			pcall(function() Fish.applyConfig() end)
		end
		applyUiHideName()
	end

	local function loadConfig(silent)
		if not configFile then
			if not silent then
				notify(hub, "Config", "Config system unavailable", "triangle-alert")
			end
			return false
		end

		local snap = readConfigSnapshotFromFile()
		if type(snap) ~= "table" and configFile.Get then
			local fromCustom = configFile:Get("KyokaFishConfig")
			if type(fromCustom) == "table" then
				snap = copyConfigTable(fromCustom)
			end
		end

		if type(snap) ~= "table" then
			if not silent then
				notify(hub, "Config", "No saved config found", "triangle-alert", 3)
			end
			return false
		end

		local merged = normalizeKyokaConfig(snap)
		local fileData = readConfigFileData()
		local fileCustom = type(fileData) == "table" and fileData.__custom or nil
		if type(fileCustom) == "table" then
			if fileCustom.Theme and hub.SetTheme then
				hub:SetTheme(fileCustom.Theme)
				merged.Theme = fileCustom.Theme
			end
			if fileCustom.AutoReloadConfig ~= nil then
				merged.AutoReloadConfig = fileCustom.AutoReloadConfig == true
			end
		end
		if configFile.Get then
			local theme = configFile:Get("Theme")
			if theme and hub.SetTheme then
				hub:SetTheme(theme)
				merged.Theme = theme
			end
			local autoLoad = configFile:Get("AutoReloadConfig")
			if autoLoad ~= nil then
				merged.AutoReloadConfig = autoLoad == true
			end
		end

		reinforceLoadedConfig(merged)
		for _, delaySec in ipairs({ 0.45, 1.0, 1.75, 2.5 }) do
			task.delay(delaySec, function()
				reinforceLoadedConfig(getgenv().KyokaFishConfig or merged)
			end)
		end

		if not silent then
			notify(hub, "Config", "Config loaded", "folder-open", 3)
		end
		return true
	end

	uiLog(opts, "Creating tabs...")
	local MainTab = Window:Tab({ Title = "Main", Icon = "house" })
	local FishTab = Window:Tab({ Title = "Fishing", Icon = "fish" })
	local QuestTab = Window:Tab({ Title = "Quest", Icon = "list" })
	local HakiTab = Window:Tab({ Title = "Haki", Icon = "zap" })
	local CompassTab = Window:Tab({ Title = "Compass", Icon = "compass" })
	local AutoSkillTab = Window:Tab({ Title = "Auto Skill", Icon = "keyboard" })
	local LucyTab = Window:Tab({ Title = "Lucy", Icon = "sparkles" })
	local SettingsTab = Window:Tab({ Title = "Settings", Icon = "settings" })

	uiLog(opts, "Populating tab controls (sync)...")
	local autoFishToggle, autoCookToggle, autoQuestToggle, autoExpertiseToggle, questDropdown
	local autoSpawnToggle, antiAfkToggle, themeDropdown, autoReloadToggle
	local autoKenToggle, autoBusoToggle, fastHakiToggle, autoRayleighToggle
	local autoAffinityToggle, hideNameToggle, hakiStatusPara
	local autoClaimSamToggle, autoDropCompassToggle, autoFindSamToggle, hubHealthPara
	local autoSkillToggle, skillKeysDropdown, skillHoldInput
	local autoWhitelistToggle, rejoinWhitelistInput
	local cacheCountPara, cacheUseDropdown, cacheDropDropdown
	local autoCacheDropToggle, autoUseConsumablesToggle, sellAtSlider
	local hideUiFirstLoadToggle, uiPanelBackgroundToggle, uiTransparentToggle, uiTransparencySlider
	local populateOk, populateErr = pcall(function()
		local uptimePara = MainTab:Paragraph({
			Title = "Session",
			Desc = formatUptime(0),
		})

		task.spawn(function()
			while uptimePara and uptimePara.SetDesc do
				uptimePara:SetDesc(formatUptime(os.clock() - uiOpenAt))
				task.wait(1)
			end
		end)

		MainTab:Section({ Title = "General", Icon = "shield", Box = true, BoxBorder = true })

		autoSpawnToggle = MainTab:Toggle({
			Title = "Auto Spawn",
			Value = cfg.AutoSpawn ~= false,
			Default = true,
			Flag = "Kyoka_AutoSpawn",
			Callback = uiCallback(function(v)
				getgenv().KyokaFishConfig = getgenv().KyokaFishConfig or {}
				getgenv().KyokaFishConfig.AutoSpawn = v == true
				if Fish and Fish.setAutoSpawn then Fish.setAutoSpawn(v) end
				notify(hub, "Auto Spawn", v and "ON" or "OFF", "play", 2)
			end),
		})

		antiAfkToggle = MainTab:Toggle({
			Title = "Anti AFK",
			Value = cfg.AntiAfk ~= false,
			Default = true,
			Flag = "Kyoka_AntiAfk",
			Callback = uiCallback(function(v)
				getgenv().KyokaFishConfig = getgenv().KyokaFishConfig or {}
				getgenv().KyokaFishConfig.AntiAfk = v == true
				if Fish and Fish.setAntiAfk then Fish.setAntiAfk(v) end
				notify(hub, "Anti AFK", v and "ON" or "OFF", "shield", 2)
			end),
		})

		hideNameToggle = MainTab:Toggle({
			Title = "Hide Name (Kyoka Hub)",
			Value = cfg.HideName ~= false,
			Default = true,
			Flag = "Kyoka_HideName",
			Callback = uiCallback(function(v)
				getgenv().KyokaFishConfig = getgenv().KyokaFishConfig or {}
				getgenv().KyokaFishConfig.HideName = v ~= false
				if Fish and Fish.setHideName then Fish.setHideName(v) end
				applyUiHideName()
				notify(hub, "Hide Name", v and "Kyoka Hub" or "OFF", "user", 2)
			end),
		})

		getgenv().KyokaHubNotify = function(title, content, icon, duration)
			notify(hub, title, content, icon or "bell", duration or 3)
		end

		FishTab:Section({ Title = "Fishing", Icon = "fish", Box = true, BoxBorder = true })

		autoFishToggle = FishTab:Toggle({
			Title = "Auto Fish",
			Value = cfg.AutoFish,
			Flag = "Kyoka_AutoFish",
			Callback = uiCallback(function(v)
				if not Fish or not Fish.setAutoFish then
					notify(hub, "Fishing", "Backend not loaded", "triangle-alert")
					return
				end
				getgenv().KyokaFishConfig = getgenv().KyokaFishConfig or {}
				getgenv().KyokaFishConfig.AutoFish = v == true
				Fish.setAutoFish(v)
				notify(hub, "Auto Fish", v and "ON" or "OFF", "fish", 2)
			end),
		})

		autoCookToggle = FishTab:Toggle({
			Title = "Auto Cook + Sell",
			Value = cfg.AutoCookSell,
			Flag = "Kyoka_AutoCookSell",
			Callback = uiCallback(function(v)
				getgenv().KyokaFishConfig = getgenv().KyokaFishConfig or {}
				getgenv().KyokaFishConfig.AutoCookSell = v == true
				if Fish and Fish.setAutoCookSell then Fish.setAutoCookSell(v) end
				notify(hub, "Cook + Sell", v and "ON" or "OFF", "utensils", 2)
			end),
		})

		sellAtSlider = FishTab:Slider({
			Title = "Cook + Sell Threshold",
			Value = { Min = 5, Max = 80, Default = cfg.SellAt },
			Flag = "Kyoka_FishSellAt",
			Callback = uiCallback(function(v)
				if Fish and Fish.setSellAt then Fish.setSellAt(v) end
				getgenv().KyokaFishConfig = getgenv().KyokaFishConfig or {}
				getgenv().KyokaFishConfig.SellAt = v
			end),
		})

		FishTab:Button({
			Title = "Cook + Sell Now",
			Icon = "utensils",
			Color = PRIMARY,
			Callback = function()
				if not Fish or not Fish.cookSell then
					notify(hub, "Fishing", "Backend not loaded", "triangle-alert")
					return
				end
				Fish.cookSell()
				notify(hub, "Cook + Sell", "Done", "utensils", 2)
			end,
		})

		FishTab:Section({ Title = "Backpack Cache", Icon = "package", Box = true, BoxBorder = true })

		local cacheKeyOptions = { "Copper", "Silver", "Gold", "Platinum", "Compass" }

		local function formatCacheCounts()
			local FishMod = Fish or getgenv().KyokaFish
			if not FishMod or not FishMod.getCacheCounts then return "—" end
			local ok, counts = pcall(FishMod.getCacheCounts)
			if not ok or type(counts) ~= "table" then return "—" end
			return string.format(
				"Copper: %d | Silver: %d | Gold: %d | Platinum: %d | Compass: %d",
				counts.Copper or 0, counts.Silver or 0, counts.Gold or 0,
				counts.Platinum or 0, counts.Compass or 0
			)
		end

		cacheCountPara = FishTab:Paragraph({
			Title = "Cache",
			Desc = formatCacheCounts(),
		})

		task.spawn(function()
			while cacheCountPara and cacheCountPara.SetDesc do
				cacheCountPara:SetDesc(formatCacheCounts())
				task.wait(1.5)
			end
		end)

		cacheUseDropdown = FishTab:Dropdown({
			Title = "Use Cache",
			Values = cacheKeyOptions,
			Value = cfg.CacheUsePick or {},
			Multi = true,
			Flag = "Kyoka_CacheUsePick",
			Callback = uiCallback(function(v)
				getgenv().KyokaFishConfig = getgenv().KyokaFishConfig or {}
				getgenv().KyokaFishConfig.CacheUsePick = v
				if Fish and Fish.setCacheUsePick then Fish.setCacheUsePick(v) end
			end),
		})

		cacheDropDropdown = FishTab:Dropdown({
			Title = "Drop Cache",
			Values = cacheKeyOptions,
			Value = cfg.CacheDropPick or {},
			Multi = true,
			Flag = "Kyoka_CacheDropPick",
			Callback = uiCallback(function(v)
				getgenv().KyokaFishConfig = getgenv().KyokaFishConfig or {}
				getgenv().KyokaFishConfig.CacheDropPick = v
				if Fish and Fish.setCacheDropPick then Fish.setCacheDropPick(v) end
			end),
		})

		autoCacheDropToggle = FishTab:Toggle({
			Title = "Auto Drop Selected",
			Value = cfg.AutoCacheDrop == true,
			Default = false,
			Flag = "Kyoka_AutoCacheDrop",
			Callback = uiCallback(function(v)
				getgenv().KyokaFishConfig = getgenv().KyokaFishConfig or {}
				getgenv().KyokaFishConfig.AutoCacheDrop = v == true
				if Fish and Fish.setAutoCacheDrop then Fish.setAutoCacheDrop(v) end
				notify(hub, "Auto Drop Cache", v and "ON" or "OFF", "package-minus", 2)
			end),
		})

		autoUseConsumablesToggle = FishTab:Toggle({
			Title = "Auto Use Fruits/Drinks",
			Desc = "Lemonade, Coconut, Prickly Pear, + drinks, etc.",
			Value = cfg.AutoUseConsumables ~= false,
			Default = true,
			Flag = "Kyoka_AutoUseConsumables",
			Callback = uiCallback(function(v)
				getgenv().KyokaFishConfig = getgenv().KyokaFishConfig or {}
				getgenv().KyokaFishConfig.AutoUseConsumables = v ~= false
				if Fish and Fish.setAutoUseConsumables then Fish.setAutoUseConsumables(v) end
				notify(hub, "Auto Use Fruits/Drinks", v and "ON" or "OFF", "cup-soda", 2)
			end),
		})

		FishTab:Button({
			Title = "Drop Selected Now",
			Icon = "package-minus",
			Color = PRIMARY,
			Callback = function()
				if not Fish or not Fish.dropCacheSelected then
					notify(hub, "Drop Cache", "Backend not loaded", "triangle-alert")
					return
				end
				local ok = Fish.dropCacheSelected()
				notify(hub, "Drop Cache", ok and "Dropped" or "Nothing to drop", "package-minus", 2)
			end,
		})

		QuestTab:Section({ Title = "Auto Quest", Icon = "list", Box = true, BoxBorder = true })

		questDropdown = QuestTab:Dropdown({
			Title = "Quest List",
			Values = questOptions,
			Value = cfg.QuestPick,
			Multi = true,
			Flag = "Kyoka_QuestPick",
			Callback = uiCallback(function(v)
				getgenv().KyokaFishConfig = getgenv().KyokaFishConfig or {}
				getgenv().KyokaFishConfig.QuestPick = v
				if Fish and Fish.setQuestPick then Fish.setQuestPick(v) end
			end),
		})

		autoQuestToggle = QuestTab:Toggle({
			Title = "Auto Quest",
			Value = cfg.AutoQuest,
			Flag = "Kyoka_AutoQuest",
			Callback = uiCallback(function(v)
				if not Fish or not Fish.setAutoQuest then
					notify(hub, "Quest", "Backend not loaded", "triangle-alert")
					return
				end
				getgenv().KyokaFishConfig = getgenv().KyokaFishConfig or {}
				getgenv().KyokaFishConfig.AutoQuest = v == true
				Fish.setAutoQuest(v)
				notify(hub, "Auto Quest", v and "ON" or "OFF", "list", 2)
			end),
		})

		QuestTab:Section({ Title = "Expertise", Icon = "book-open", Box = true, BoxBorder = true })

		autoExpertiseToggle = QuestTab:Toggle({
			Title = "Auto Expertise",
			Value = cfg.AutoExpertise,
			Flag = "Kyoka_AutoExpertise",
			Callback = uiCallback(function(v)
				if not Fish or not Fish.setAutoExpertise then
					notify(hub, "Expertise", "Backend not loaded", "triangle-alert")
					return
				end
				getgenv().KyokaFishConfig = getgenv().KyokaFishConfig or {}
				getgenv().KyokaFishConfig.AutoExpertise = v == true
				Fish.setAutoExpertise(v)
				notify(hub, "Auto Expertise", v and "ON" or "OFF", "book-open", 2)
			end),
		})

		HakiTab:Section({ Title = "Haki Toggle", Icon = "eye", Box = true, BoxBorder = true })

		autoKenToggle = HakiTab:Toggle({
			Title = "Auto Kenbunshoku",
			Value = cfg.AutoKenbunshoku,
			Flag = "Kyoka_AutoKenbunshoku",
			Callback = uiCallback(function(v)
				getgenv().KyokaFishConfig = getgenv().KyokaFishConfig or {}
				getgenv().KyokaFishConfig.AutoKenbunshoku = v == true
				if Fish and Fish.setAutoKenbunshoku then Fish.setAutoKenbunshoku(v) end
				notify(hub, "Kenbunshoku", v and "ON" or "OFF", "eye", 2)
			end),
		})

		autoBusoToggle = HakiTab:Toggle({
			Title = "Auto Busoshoku",
			Value = cfg.AutoBusoshoku,
			Flag = "Kyoka_AutoBusoshoku",
			Callback = uiCallback(function(v)
				getgenv().KyokaFishConfig = getgenv().KyokaFishConfig or {}
				getgenv().KyokaFishConfig.AutoBusoshoku = v == true
				if Fish and Fish.setAutoBusoshoku then Fish.setAutoBusoshoku(v) end
				notify(hub, "Busoshoku", v and "ON" or "OFF", "shield", 2)
			end),
		})

		HakiTab:Section({ Title = "Farm", Icon = "zap", Box = true, BoxBorder = true })

		hakiStatusPara = HakiTab:Paragraph({
			Title = "Haki Status",
			Desc = "—",
		})

		getgenv().KyokaHakiMaxCallback = function(maxed, lv, stop)
			if not hakiStatusPara or not hakiStatusPara.SetDesc then return end
			if maxed then
				hakiStatusPara:SetDesc(string.format("MAX — Lv %d (stop %d)", lv or 0, stop or 0))
			else
				hakiStatusPara:SetDesc(string.format("Lv %d / stop %d", lv or 0, stop or 0))
			end
		end

		task.spawn(function()
			while hakiStatusPara and hakiStatusPara.SetDesc do
				local FishMod = getgenv().KyokaFish
				if FishMod and FishMod.getHakiStatus then
					local ok, st = pcall(FishMod.getHakiStatus)
					if ok and st and type(getgenv().KyokaHakiMaxCallback) == "function" then
						pcall(getgenv().KyokaHakiMaxCallback, st.maxed, st.level, st.stop)
					end
				end
				task.wait(2)
			end
		end)

		fastHakiToggle = HakiTab:Toggle({
			Title = "Fast Haki",
			Value = cfg.FastHaki,
			Flag = "Kyoka_FastHaki",
			Callback = uiCallback(function(v)
				getgenv().KyokaFishConfig = getgenv().KyokaFishConfig or {}
				getgenv().KyokaFishConfig.FastHaki = v == true
				if Fish and Fish.setFastHaki then Fish.setFastHaki(v) end
				notify(hub, "Fast Haki", v and "ON" or "OFF", "zap", 2)
			end),
		})

		autoRayleighToggle = HakiTab:Toggle({
			Title = "Auto Rayleigh",
			Value = cfg.AutoRayleigh,
			Flag = "Kyoka_AutoRayleigh",
			Callback = uiCallback(function(v)
				getgenv().KyokaFishConfig = getgenv().KyokaFishConfig or {}
				getgenv().KyokaFishConfig.AutoRayleigh = v == true
				if Fish and Fish.setAutoRayleigh then Fish.setAutoRayleigh(v) end
				notify(hub, "Auto Rayleigh", v and "ON" or "OFF", "sparkles", 2)
			end),
		})

		CompassTab:Section({ Title = "Sam / Compass", Icon = "compass", Box = true, BoxBorder = true })

		CompassTab:Paragraph({
			Title = "Note",
			Content = "Auto Find Sam and Auto Drop Compass are mutually exclusive.",
		})

		hubHealthPara = CompassTab:Paragraph({
			Title = "Hub health",
			Desc = "Starting…",
		})

		autoClaimSamToggle = CompassTab:Toggle({
			Title = "Auto Claim Sam",
			Value = cfg.AutoClaimSam == true,
			Default = false,
			Flag = "Kyoka_AutoClaimSam",
			Callback = uiCallback(function(v)
				getgenv().KyokaFishConfig = getgenv().KyokaFishConfig or {}
				getgenv().KyokaFishConfig.AutoClaimSam = v == true
				if Fish and Fish.setAutoClaimSam then Fish.setAutoClaimSam(v) end
				notify(hub, "Auto Claim Sam", v and "ON" or "OFF", "compass", 2)
			end),
		})

		autoDropCompassToggle = CompassTab:Toggle({
			Title = "Auto Drop Compass",
			Value = cfg.AutoDropCompass == true,
			Default = false,
			Flag = "Kyoka_AutoDropCompass",
			Callback = uiCallback(function(v)
				getgenv().KyokaFishConfig = getgenv().KyokaFishConfig or {}
				if v == true then
					getgenv().KyokaFishConfig.AutoFindSam = false
					if autoFindSamToggle and autoFindSamToggle.Set then
						pcall(function() autoFindSamToggle:Set(false) end)
					end
					if Fish and Fish.setAutoFindSam then Fish.setAutoFindSam(false) end
				end
				getgenv().KyokaFishConfig.AutoDropCompass = v == true
				if Fish and Fish.setAutoDropCompass then Fish.setAutoDropCompass(v) end
				notify(hub, "Auto Drop Compass", v and "ON" or "OFF", "package-minus", 2)
			end),
		})

		autoFindSamToggle = CompassTab:Toggle({
			Title = "Auto Find Sam (Compass Hunt)",
			Value = cfg.AutoFindSam == true,
			Default = false,
			Flag = "Kyoka_AutoFindSam",
			Callback = uiCallback(function(v)
				getgenv().KyokaFishConfig = getgenv().KyokaFishConfig or {}
				if v == true then
					getgenv().KyokaFishConfig.AutoDropCompass = false
					if autoDropCompassToggle and autoDropCompassToggle.Set then
						pcall(function() autoDropCompassToggle:Set(false) end)
					end
					if Fish and Fish.setAutoDropCompass then Fish.setAutoDropCompass(false) end
				end
				getgenv().KyokaFishConfig.AutoFindSam = v == true
				if Fish and Fish.setAutoFindSam then Fish.setAutoFindSam(v) end
				notify(hub, "Auto Find Sam", v and "ON" or "OFF", "search", 2)
			end),
		})

		task.spawn(function()
			local FishMod = Fish or getgenv().KyokaFish
			while hubHealthPara and hubHealthPara.SetDesc do
				local text = "Hub idle"
				if FishMod and FishMod.getDiagnostics then
					local ok, diag = pcall(FishMod.getDiagnostics)
					if ok and type(diag) == "table" then
						text = diag.summary or text
					end
				end
				pcall(function() hubHealthPara:SetDesc(text) end)
				task.wait(15)
			end
		end)

		AutoSkillTab:Section({ Title = "Skill Spam", Icon = "keyboard", Box = true, BoxBorder = true })

		local skillKeyOptions = { "Z", "X", "C", "V", "B", "N", "F", "G", "H", "J", "K", "L" }

		local function applySkillHoldFromUI()
			if not skillHoldInput then return end
			local raw = skillHoldInput.Value
			if type(raw) == "string" then raw = raw:match("^%s*(.-)%s*$") end
			local n = tonumber(raw)
			if n == nil or n < 0 then return end
			getgenv().KyokaFishConfig = getgenv().KyokaFishConfig or {}
			getgenv().KyokaFishConfig.SkillHoldSec = n
			if Fish and Fish.setSkillHoldSec then Fish.setSkillHoldSec(n) end
		end

		local function applySkillKeysFromUI()
			if not skillKeysDropdown then return end
			local v = skillKeysDropdown.Value
			if v == nil then return end
			getgenv().KyokaFishConfig = getgenv().KyokaFishConfig or {}
			getgenv().KyokaFishConfig.SkillKeys = v
			if Fish and Fish.setSkillKeys then Fish.setSkillKeys(v) end
		end

		local skillPick = {}
		if type(cfg.SkillKeys) == "table" then
			if cfg.SkillKeys[1] then
				skillPick = cfg.SkillKeys
			else
				for _, k in ipairs(skillKeyOptions) do
					if cfg.SkillKeys[k] == true then skillPick[#skillPick + 1] = k end
				end
			end
		end

		skillKeysDropdown = AutoSkillTab:Dropdown({
			Title = "Skill Keys",
			Values = skillKeyOptions,
			Value = skillPick,
			Multi = true,
			Flag = "Kyoka_SkillKeys",
			Callback = uiCallback(function(v)
				getgenv().KyokaFishConfig = getgenv().KyokaFishConfig or {}
				getgenv().KyokaFishConfig.SkillKeys = v
				applySkillHoldFromUI()
				if Fish and Fish.setSkillKeys then Fish.setSkillKeys(v) end
				if getgenv().KyokaFishConfig.AutoSkill and Fish and Fish.setAutoSkill then
					Fish.setAutoSkill(true)
				end
			end),
		})

		skillHoldInput = AutoSkillTab:Input({
			Title = "Hold (seconds)",
			Placeholder = "0.5",
			Value = tostring(cfg.SkillHoldSec or 0.5),
			Flag = "Kyoka_SkillHoldSec",
			Callback = uiCallback(function(v)
				if type(v) == "string" then v = v:match("^%s*(.-)%s*$") end
				local n = tonumber(v)
				if n == nil or n < 0 then return end
				getgenv().KyokaFishConfig = getgenv().KyokaFishConfig or {}
				getgenv().KyokaFishConfig.SkillHoldSec = n
				if Fish and Fish.setSkillHoldSec then Fish.setSkillHoldSec(n) end
			end),
		})

		autoSkillToggle = AutoSkillTab:Toggle({
			Title = "Auto Skill",
			Value = cfg.AutoSkill == true,
			Default = false,
			Flag = "Kyoka_AutoSkill",
			Callback = uiCallback(function(v)
				getgenv().KyokaFishConfig = getgenv().KyokaFishConfig or {}
				getgenv().KyokaFishConfig.AutoSkill = v == true
				applySkillHoldFromUI()
				applySkillKeysFromUI()
				if Fish and Fish.setSkillKeys then
					Fish.setSkillKeys(getgenv().KyokaFishConfig.SkillKeys)
				end
				if Fish and Fish.setAutoSkill then Fish.setAutoSkill(v) end
				notify(hub, "Auto Skill", v and "ON" or "OFF", "zap", 2)
			end),
		})

		LucyTab:Section({ Title = "Affinity Roll", Icon = "sparkles", Box = true, BoxBorder = true })

		LucyTab:Paragraph({
			Title = "Note",
			Desc = "Auto roll slot 1 (Reroll1).",
		})

		local function affinityInput(stat, placeholder)
			local cfgKey = "Affinity" .. stat
			local val = cfg[cfgKey]
			LucyTab:Input({
				Title = stat,
				Placeholder = placeholder,
				Value = val ~= nil and tostring(val) or "",
				Flag = "Kyoka_Affinity_" .. stat,
				Callback = uiCallback(function(v)
					getgenv().KyokaFishConfig = getgenv().KyokaFishConfig or {}
					local n = tonumber(v)
					if v == "" or v == nil then
						getgenv().KyokaFishConfig[cfgKey] = nil
					elseif n and n > 0 then
						getgenv().KyokaFishConfig[cfgKey] = n
					else
						return
					end
					if Fish and Fish.setAffinityTarget then
						Fish.setAffinityTarget(stat, getgenv().KyokaFishConfig[cfgKey])
					end
				end),
			})
		end

		affinityInput("Melee", "1.7")
		affinityInput("Sword", "1.3")
		affinityInput("Sniper", "1.3")
		affinityInput("Defense", "1.3")

		autoAffinityToggle = LucyTab:Toggle({
			Title = "Auto Affinity",
			Value = cfg.AutoAffinity,
			Flag = "Kyoka_AutoAffinity",
			Callback = uiCallback(function(v)
				getgenv().KyokaFishConfig = getgenv().KyokaFishConfig or {}
				getgenv().KyokaFishConfig.AutoAffinity = v == true
				if Fish and Fish.setAutoAffinity then Fish.setAutoAffinity(v) end
				notify(hub, "Auto Affinity", v and "ON (slot 1)" or "OFF", "sparkles", 2)
			end),
		})

		SettingsTab:Section({ Title = "Auto Rejoin", Icon = "shield-check", Box = true, BoxBorder = true })

		SettingsTab:Paragraph({
			Title = "Whitelist",
			Desc = "Allowed player names (comma-separated). Kicks you from the server if anyone else is present.",
		})

		rejoinWhitelistInput = SettingsTab:Input({
			Title = "Player Whitelist",
			Placeholder = "Friend1, Friend2, AltAccount",
			Value = cfg.RejoinWhitelist or "",
			Flag = "Kyoka_RejoinWhitelist",
			Callback = uiCallback(function(v)
				getgenv().KyokaFishConfig = getgenv().KyokaFishConfig or {}
				getgenv().KyokaFishConfig.RejoinWhitelist = tostring(v or "")
				if Fish and Fish.setRejoinWhitelist then Fish.setRejoinWhitelist(v) end
			end),
		})

		autoWhitelistToggle = SettingsTab:Toggle({
			Title = "Auto Whitelist Kick",
			Value = cfg.AutoWhitelistRejoin == true,
			Default = false,
			Flag = "Kyoka_AutoWhitelistRejoin",
			Callback = uiCallback(function(v)
				getgenv().KyokaFishConfig = getgenv().KyokaFishConfig or {}
				getgenv().KyokaFishConfig.AutoWhitelistRejoin = v == true
				if rejoinWhitelistInput and rejoinWhitelistInput.Value ~= nil then
					getgenv().KyokaFishConfig.RejoinWhitelist = tostring(rejoinWhitelistInput.Value or "")
					if Fish and Fish.setRejoinWhitelist then
						Fish.setRejoinWhitelist(rejoinWhitelistInput.Value)
					end
				end
				if Fish and Fish.setAutoWhitelistRejoin then Fish.setAutoWhitelistRejoin(v) end
				notify(hub, "Whitelist Kick", v and "ON" or "OFF", "shield-check", 2)
			end),
		})

		SettingsTab:Button({
			Title = "Rejoin Server",
			Icon = "refresh-cw",
			Color = PRIMARY,
			Callback = function()
				if not Fish or not Fish.rejoinServer then
					notify(hub, "Rejoin", "Backend not loaded", "triangle-alert")
					return
				end
				local ok = Fish.rejoinServer()
				notify(hub, "Rejoin", ok and "Teleporting..." or "Already pending", "refresh-cw", 2)
			end,
		})

		SettingsTab:Section({ Title = "Appearance", Icon = "palette", Box = true, BoxBorder = true })

		themeDropdown = SettingsTab:Dropdown({
			Title = "Theme",
			Values = themes,
			Value = cfg.Theme,
			Flag = "Kyoka_Theme",
			Callback = uiCallback(function(v)
				cfg.Theme = v
				getgenv().KyokaFishConfig = cfg
				if hub.SetTheme then hub:SetTheme(v) end
				if configFile and configFile.Set then configFile:Set("Theme", v) end
			end),
		})

		hideUiFirstLoadToggle = SettingsTab:Toggle({
			Title = "Hide UI on First Load",
			Value = cfg.HideUiFirstLoad == true,
			Default = false,
			Flag = "Kyoka_HideUiFirstLoad",
			Callback = uiCallback(function(v)
				getgenv().KyokaFishConfig = getgenv().KyokaFishConfig or {}
				getgenv().KyokaFishConfig.HideUiFirstLoad = v == true
				cfg = getgenv().KyokaFishConfig
			end),
		})

		uiTransparentToggle = SettingsTab:Toggle({
			Title = "See-through Window",
			Value = cfg.UiTransparent == true,
			Default = false,
			Flag = "Kyoka_UiTransparent",
			Callback = uiCallback(function(v)
				getgenv().KyokaFishConfig = getgenv().KyokaFishConfig or {}
				getgenv().KyokaFishConfig.UiTransparent = v == true
				cfg = getgenv().KyokaFishConfig
				applyUiAppearance(getgenv().KyokaFishConfig)
			end),
		})

		uiTransparencySlider = SettingsTab:Slider({
			Title = "Window Transparency",
			Value = { Min = 10, Max = 95, Default = cfg.UiTransparency or 55 },
			Flag = "Kyoka_UiTransparency",
			Callback = uiCallback(function(v)
				local n = math.clamp(tonumber(v) or 55, 10, 95)
				getgenv().KyokaFishConfig = getgenv().KyokaFishConfig or {}
				getgenv().KyokaFishConfig.UiTransparency = n
				cfg = getgenv().KyokaFishConfig
				if getgenv().KyokaFishConfig.UiTransparent then
					applyUiAppearance(getgenv().KyokaFishConfig)
				end
			end),
		})

		uiPanelBackgroundToggle = SettingsTab:Toggle({
			Title = "Panel Background",
			Value = cfg.UiPanelBackground == true,
			Default = false,
			Flag = "Kyoka_UiPanelBackground",
			Callback = uiCallback(function(v)
				getgenv().KyokaFishConfig = getgenv().KyokaFishConfig or {}
				getgenv().KyokaFishConfig.UiPanelBackground = v == true
				cfg = getgenv().KyokaFishConfig
				applyUiAppearance(getgenv().KyokaFishConfig)
			end),
		})

		SettingsTab:Section({ Title = "Config", Icon = "save", Box = true, BoxBorder = true })

		SettingsTab:Button({
			Title = "Save Config",
			Icon = "save",
			Color = PRIMARY,
			Callback = function()
				saveConfig()
			end,
		})

		SettingsTab:Button({
			Title = "Load Config",
			Icon = "folder-open",
			Callback = function()
				loadConfig(false)
			end,
		})

		autoReloadToggle = SettingsTab:Toggle({
			Title = "Auto Load Config",
			Value = cfg.AutoReloadConfig ~= false,
			Default = true,
			Flag = "Kyoka_AutoReloadConfig",
			Callback = uiCallback(function(v)
				cfg.AutoReloadConfig = v == true
				getgenv().KyokaFishConfig = cfg
				if configFile and configFile.SetAutoLoad then
					configFile:SetAutoLoad(false)
				end
				if configFile and configFile.Set then
					configFile:Set("AutoReloadConfig", v == true)
				end
				if v and configFile and configFile.Save then
					persistConfigMeta()
					pcall(function() configFile:Save() end)
				end
			end),
		})

		SettingsTab:Section({ Title = "Hub", Icon = "refresh-cw", Box = true, BoxBorder = true })

		SettingsTab:Button({
			Title = "Reload Hub",
			Icon = "refresh-cw",
			Color = PRIMARY,
			Callback = function()
				task.defer(function()
					if getgenv().ReloadKyokaHub then getgenv().ReloadKyokaHub() end
				end)
			end,
		})
	end)

	if not populateOk then
		uiLog(opts, "POPULATE FAILED: " .. tostring(populateErr))
		error("KyokaUI populate failed: " .. tostring(populateErr))
	end

	local counts = {
		Main = countElements(MainTab),
		Fishing = countElements(FishTab),
		Quest = countElements(QuestTab),
		Haki = countElements(HakiTab),
		Compass = countElements(CompassTab),
		AutoSkill = countElements(AutoSkillTab),
		Lucy = countElements(LucyTab),
		Settings = countElements(SettingsTab),
	}
	uiLog(opts, string.format(
		"Elements — Main:%d Fishing:%d Quest:%d Haki:%d Compass:%d AutoSkill:%d Lucy:%d Settings:%d",
		counts.Main, counts.Fishing, counts.Quest, counts.Haki, counts.Compass, counts.AutoSkill, counts.Lucy, counts.Settings
	))

	getgenv().__KYOKA_UI_COUNTS = counts

	applyConfigToUi = function(c)
		if type(c) ~= "table" then return end
		local function setToggle(toggle, on)
			if toggle and toggle.Set then
				pcall(function() toggle:Set(on == true) end)
			end
		end
		setToggle(autoFishToggle, c.AutoFish)
		setToggle(autoQuestToggle, c.AutoQuest)
		setToggle(autoExpertiseToggle, c.AutoExpertise)
		setToggle(autoCookToggle, c.AutoCookSell ~= false)
		setToggle(autoSpawnToggle, c.AutoSpawn ~= false)
		setToggle(antiAfkToggle, c.AntiAfk ~= false)
		setToggle(autoReloadToggle, c.AutoReloadConfig ~= false)
		setToggle(autoKenToggle, c.AutoKenbunshoku)
		setToggle(autoBusoToggle, c.AutoBusoshoku)
		setToggle(fastHakiToggle, c.FastHaki)
		setToggle(autoRayleighToggle, c.AutoRayleigh)
		setToggle(autoAffinityToggle, c.AutoAffinity)
		setToggle(hideNameToggle, c.HideName ~= false)
		setToggle(autoClaimSamToggle, c.AutoClaimSam)
		setToggle(autoDropCompassToggle, c.AutoDropCompass)
		setToggle(autoFindSamToggle, c.AutoFindSam)
		setToggle(autoSkillToggle, c.AutoSkill)
		setToggle(autoWhitelistToggle, c.AutoWhitelistRejoin)
		setToggle(autoCacheDropToggle, c.AutoCacheDrop)
		setToggle(autoUseConsumablesToggle, c.AutoUseConsumables ~= false)
		if themeDropdown and themeDropdown.Set and c.Theme then
			pcall(function() themeDropdown:Set(c.Theme) end)
		end
		if questDropdown and questDropdown.Set and c.QuestPick ~= nil then
			pcall(function() questDropdown:Set(c.QuestPick) end)
		end
		if skillKeysDropdown and skillKeysDropdown.Set and c.SkillKeys ~= nil then
			pcall(function() skillKeysDropdown:Set(c.SkillKeys) end)
		end
		if skillHoldInput and skillHoldInput.Set and c.SkillHoldSec ~= nil then
			pcall(function() skillHoldInput:Set(tostring(c.SkillHoldSec)) end)
		end
		if rejoinWhitelistInput and rejoinWhitelistInput.Set and c.RejoinWhitelist ~= nil then
			pcall(function() rejoinWhitelistInput:Set(tostring(c.RejoinWhitelist)) end)
		end
		if cacheUseDropdown and cacheUseDropdown.Set and c.CacheUsePick ~= nil then
			pcall(function() cacheUseDropdown:Set(c.CacheUsePick) end)
		end
		if cacheDropDropdown and cacheDropDropdown.Set and c.CacheDropPick ~= nil then
			pcall(function() cacheDropDropdown:Set(c.CacheDropPick) end)
		end
		if sellAtSlider and sellAtSlider.Set and c.SellAt ~= nil then
			pcall(function() sellAtSlider:Set(tonumber(c.SellAt) or c.SellAt) end)
		end
		setToggle(hideUiFirstLoadToggle, c.HideUiFirstLoad)
		setToggle(uiTransparentToggle, c.UiTransparent)
		setToggle(uiPanelBackgroundToggle, c.UiPanelBackground)
		if uiTransparencySlider and uiTransparencySlider.Set and c.UiTransparency ~= nil then
			pcall(function() uiTransparencySlider:Set(tonumber(c.UiTransparency) or c.UiTransparency) end)
		end
		applyUiAppearance(c)
	end

	syncConfigFromUi = function(applyBackend)
		local c = getgenv().KyokaFishConfig or {}
		if autoFishToggle and autoFishToggle.Value ~= nil then c.AutoFish = autoFishToggle.Value == true end
		if autoQuestToggle and autoQuestToggle.Value ~= nil then c.AutoQuest = autoQuestToggle.Value == true end
		if autoExpertiseToggle and autoExpertiseToggle.Value ~= nil then c.AutoExpertise = autoExpertiseToggle.Value == true end
		if autoCookToggle and autoCookToggle.Value ~= nil then c.AutoCookSell = autoCookToggle.Value ~= false end
		if autoSpawnToggle and autoSpawnToggle.Value ~= nil then c.AutoSpawn = autoSpawnToggle.Value == true end
		if antiAfkToggle and antiAfkToggle.Value ~= nil then c.AntiAfk = antiAfkToggle.Value == true end
		if autoReloadToggle and autoReloadToggle.Value ~= nil then c.AutoReloadConfig = autoReloadToggle.Value == true end
		if themeDropdown and themeDropdown.Value ~= nil then c.Theme = themeDropdown.Value end
		if questDropdown and questDropdown.Value ~= nil then c.QuestPick = questDropdown.Value end
		if autoKenToggle and autoKenToggle.Value ~= nil then c.AutoKenbunshoku = autoKenToggle.Value == true end
		if autoBusoToggle and autoBusoToggle.Value ~= nil then c.AutoBusoshoku = autoBusoToggle.Value == true end
		if fastHakiToggle and fastHakiToggle.Value ~= nil then c.FastHaki = fastHakiToggle.Value == true end
		if autoRayleighToggle and autoRayleighToggle.Value ~= nil then c.AutoRayleigh = autoRayleighToggle.Value == true end
		if autoAffinityToggle and autoAffinityToggle.Value ~= nil then c.AutoAffinity = autoAffinityToggle.Value == true end
		if hideNameToggle and hideNameToggle.Value ~= nil then c.HideName = hideNameToggle.Value ~= false end
		if autoClaimSamToggle and autoClaimSamToggle.Value ~= nil then c.AutoClaimSam = autoClaimSamToggle.Value == true end
		if autoDropCompassToggle and autoDropCompassToggle.Value ~= nil then c.AutoDropCompass = autoDropCompassToggle.Value == true end
		if autoFindSamToggle and autoFindSamToggle.Value ~= nil then c.AutoFindSam = autoFindSamToggle.Value == true end
		if autoSkillToggle and autoSkillToggle.Value ~= nil then c.AutoSkill = autoSkillToggle.Value == true end
		if skillKeysDropdown and skillKeysDropdown.Value ~= nil then c.SkillKeys = skillKeysDropdown.Value end
		if skillHoldInput and skillHoldInput.Value ~= nil then
			local n = tonumber(skillHoldInput.Value)
			if n and n >= 0 then c.SkillHoldSec = n end
		end
		if autoWhitelistToggle and autoWhitelistToggle.Value ~= nil then
			c.AutoWhitelistRejoin = autoWhitelistToggle.Value == true
		end
		if rejoinWhitelistInput and rejoinWhitelistInput.Value ~= nil then
			c.RejoinWhitelist = tostring(rejoinWhitelistInput.Value or "")
		end
		if cacheUseDropdown and cacheUseDropdown.Value ~= nil then c.CacheUsePick = cacheUseDropdown.Value end
		if cacheDropDropdown and cacheDropDropdown.Value ~= nil then c.CacheDropPick = cacheDropDropdown.Value end
		if autoCacheDropToggle and autoCacheDropToggle.Value ~= nil then c.AutoCacheDrop = autoCacheDropToggle.Value == true end
		if autoUseConsumablesToggle and autoUseConsumablesToggle.Value ~= nil then
			c.AutoUseConsumables = autoUseConsumablesToggle.Value ~= false
		end
		if sellAtSlider and sellAtSlider.Value ~= nil then
			local n = tonumber(sellAtSlider.Value)
			if n then c.SellAt = n end
		end
		if hideUiFirstLoadToggle and hideUiFirstLoadToggle.Value ~= nil then
			c.HideUiFirstLoad = hideUiFirstLoadToggle.Value == true
		end
		if uiTransparentToggle and uiTransparentToggle.Value ~= nil then
			c.UiTransparent = uiTransparentToggle.Value == true
		end
		if uiTransparencySlider and uiTransparencySlider.Value ~= nil then
			local n = tonumber(uiTransparencySlider.Value)
			if n then c.UiTransparency = math.clamp(n, 10, 95) end
		end
		if uiPanelBackgroundToggle and uiPanelBackgroundToggle.Value ~= nil then
			c.UiPanelBackground = uiPanelBackgroundToggle.Value == true
		end
		cfg = c
		getgenv().KyokaFishConfig = normalizeKyokaConfig(c)
		if applyBackend then applyBackendFromConfig(getgenv().KyokaFishConfig) end
		return getgenv().KyokaFishConfig
	end

	task.spawn(function()
		getgenv().__KYOKA_SUPPRESS_UI_CALLBACKS = true
		if cfg.AutoReloadConfig ~= false then
			loadConfig(true)
		else
			applyBackendFromConfig(getgenv().KyokaFishConfig or cfg)
		end
		task.wait(2.75)
		getgenv().__KYOKA_SUPPRESS_UI_CALLBACKS = false
		if getgenv().KyokaFishConfig then
			reinforceLoadedConfig(getgenv().KyokaFishConfig)
		end
		tryFirstLoadMinimize(getgenv().KyokaFishConfig or cfg)
		uiLog(opts, "Config synced")
	end)

	task.spawn(function()
		task.wait(0.15)
		hideEmptyPlaceholder(MainTab)
		hideEmptyPlaceholder(FishTab)
		hideEmptyPlaceholder(QuestTab)
		hideEmptyPlaceholder(HakiTab)
		hideEmptyPlaceholder(CompassTab)
		hideEmptyPlaceholder(AutoSkillTab)
		hideEmptyPlaceholder(LucyTab)
		hideEmptyPlaceholder(SettingsTab)

		if Window.SelectTab and MainTab.Index then
			Window:SelectTab(MainTab.Index)
		end

		applyUiAppearance(getgenv().KyokaFishConfig or cfg)
		tryFirstLoadMinimize(getgenv().KyokaFishConfig or cfg)
	end)

	applyUiAppearance(cfg)
	tryFirstLoadMinimize(cfg)

	return Window
end

return KyokaUI
