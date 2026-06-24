--[[ SigmaUI — Fishing + Quest + Haki tabs ]]
-- SIGMA_MODULE=ui

local SigmaUI = {}

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
		names = { "Sigma", "Dark", "Violet", "Light" }
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

function SigmaUI.build(hub, Fish, opts)
	opts = opts or {}
	local notify = opts.notify or function(_, title, content)
		hub:Notify({ Title = title, Content = content, Duration = 3 })
	end
	local PRIMARY = opts.primary or Color3.fromRGB(139, 92, 246)
	local uiOpenAt = os.clock()

	local cfg = getgenv().SigmaFishConfig or {}
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
	cfg.Theme = cfg.Theme or "Sigma"
	getgenv().SigmaFishConfig = cfg

	local questOptions = (Fish and Fish.getQuestList and Fish.getQuestList()) or {}
	local themes = themeNames(hub)
	if not table.find(themes, cfg.Theme) then
		cfg.Theme = themes[1] or "Sigma"
	end

	uiLog(opts, "CreateWindow...")
	local Window = hub:CreateWindow({
		Title = "Sigma Hub",
		Author = "One Piece: Final",
		Icon = "fish",
		Folder = "SigmaHub",
		Theme = cfg.Theme,
		Size = UDim2.new(0, 620, 0, 480),
		ToggleKey = Enum.KeyCode.RightShift,
		Resizable = true,
		Transparent = false,
		Acrylic = true,
		ScrollBarEnabled = true,
		User = { Enabled = true },
		OpenButton = {
			Enabled = true,
			OnlyMobile = false,
			Title = "Sigma Hub",
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

	getgenv().__SIGMA_UI_WINDOW = Window
	local Players = game:GetService("Players")
	local HIDE_ALIAS = "Sigma Hub"

	local function applyUiHideName()
		local hide = (getgenv().SigmaFishConfig or {}).HideName ~= false
		if Window.User and Window.User.SetAnonymous then
			Window.User:SetAnonymous(hide)
			if hide then
				task.defer(function()
					for _, d in ipairs(Players.LocalPlayer.PlayerGui:GetDescendants()) do
						if d:IsA("TextLabel") then
							if d.Name == "DisplayName" and d.Text == "Anonymous" then
								d.Text = HIDE_ALIAS
							elseif d.Name == "UserName" and d.Text == "anonymous" then
								d.Text = "sigmahub"
							end
						end
					end
				end)
			end
		end
		if Window.EditOpenButton then
			pcall(function()
				Window:EditOpenButton({ Title = hide and HIDE_ALIAS or "Sigma Hub" })
			end)
		end
	end
	getgenv().SigmaApplyUiHideName = applyUiHideName

	local configFile
	local syncConfigFromUi

	if Window.ConfigManager then
		configFile = Window.ConfigManager:Config("sigma-fish")
		if configFile and configFile.SetAsCurrent then
			configFile:SetAsCurrent()
		end
		if configFile and configFile.SetAutoLoad then
			configFile:SetAutoLoad(cfg.AutoReloadConfig == true)
		end
	end

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

	local function persistConfigMeta()
		if not configFile then return end
		if syncConfigFromUi then syncConfigFromUi(false) end
		local snap = copyConfigTable(getgenv().SigmaFishConfig or cfg)
		cfg = snap
		getgenv().SigmaFishConfig = snap
		if configFile.Set then
			configFile:Set("Theme", snap.Theme or (hub.GetCurrentTheme and hub:GetCurrentTheme()) or "Sigma")
			configFile:Set("AutoReloadConfig", snap.AutoReloadConfig == true)
			configFile:Set("SigmaFishConfig", snap)
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
			notify(hub, "Config", "Saved sigma-fish.json", "save", 3)
			return true
		end
		notify(hub, "Config", "Save failed: " .. tostring(err), "triangle-alert", 4)
		return false
	end

	local function loadConfig(silent)
		if not configFile or not configFile.Load then
			if not silent then
				notify(hub, "Config", "Config system unavailable", "triangle-alert")
			end
			return false
		end
		local ok, err = pcall(function()
			configFile:Load()
		end)
		if not ok then
			if not silent then
				notify(hub, "Config", "Load failed: " .. tostring(err), "triangle-alert", 4)
			end
			return false
		end
		task.wait(0.35)
		local snap = configFile.Get and configFile:Get("SigmaFishConfig")
		if type(snap) == "table" then
			local merged = copyConfigTable(getgenv().SigmaFishConfig or cfg)
			for k, v in pairs(snap) do
				if type(v) == "table" then
					local nested = {}
					for k2, v2 in pairs(v) do nested[k2] = v2 end
					merged[k] = nested
				else
					merged[k] = v
				end
			end
			cfg = merged
			getgenv().SigmaFishConfig = merged
		end
		local theme = configFile.Get and configFile:Get("Theme")
		if theme and hub.SetTheme then
			hub:SetTheme(theme)
			cfg.Theme = theme
		end
		local autoLoad = configFile.Get and configFile:Get("AutoReloadConfig")
		if autoLoad ~= nil then
			cfg.AutoReloadConfig = autoLoad == true
		end
		if syncConfigFromUi then
			syncConfigFromUi(true)
		elseif Fish and Fish.applyConfig then
			pcall(function() Fish.applyConfig() end)
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
	local autoClaimSamToggle, autoDropCompassToggle, autoFindSamToggle
	local autoSkillToggle, skillKeysDropdown, skillHoldInput
	local autoWhitelistToggle, rejoinWhitelistInput
	local cacheCountPara, cacheUseDropdown, cacheDropDropdown
	local autoCacheDropToggle, autoUseConsumablesToggle, sellAtSlider
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
			Flag = "Sigma_AutoSpawn",
			Callback = function(v)
				getgenv().SigmaFishConfig = getgenv().SigmaFishConfig or {}
				getgenv().SigmaFishConfig.AutoSpawn = v == true
				if Fish and Fish.setAutoSpawn then Fish.setAutoSpawn(v) end
				notify(hub, "Auto Spawn", v and "ON" or "OFF", "play", 2)
			end,
		})

		antiAfkToggle = MainTab:Toggle({
			Title = "Anti AFK",
			Value = cfg.AntiAfk ~= false,
			Default = true,
			Flag = "Sigma_AntiAfk",
			Callback = function(v)
				getgenv().SigmaFishConfig = getgenv().SigmaFishConfig or {}
				getgenv().SigmaFishConfig.AntiAfk = v == true
				if Fish and Fish.setAntiAfk then Fish.setAntiAfk(v) end
				notify(hub, "Anti AFK", v and "ON" or "OFF", "shield", 2)
			end,
		})

		hideNameToggle = MainTab:Toggle({
			Title = "Hide Name (Sigma Hub)",
			Value = cfg.HideName ~= false,
			Default = true,
			Flag = "Sigma_HideName",
			Callback = function(v)
				getgenv().SigmaFishConfig = getgenv().SigmaFishConfig or {}
				getgenv().SigmaFishConfig.HideName = v ~= false
				if Fish and Fish.setHideName then Fish.setHideName(v) end
				applyUiHideName()
				notify(hub, "Hide Name", v and "Sigma Hub" or "OFF", "user", 2)
			end,
		})

		getgenv().SigmaHubNotify = function(title, content, icon, duration)
			notify(hub, title, content, icon or "bell", duration or 3)
		end

		FishTab:Section({ Title = "Fishing", Icon = "fish", Box = true, BoxBorder = true })

		autoFishToggle = FishTab:Toggle({
			Title = "Auto Fish",
			Value = cfg.AutoFish,
			Flag = "Sigma_AutoFish",
			Callback = function(v)
				if not Fish or not Fish.setAutoFish then
					notify(hub, "Fishing", "Backend not loaded", "triangle-alert")
					return
				end
				getgenv().SigmaFishConfig = getgenv().SigmaFishConfig or {}
				getgenv().SigmaFishConfig.AutoFish = v == true
				Fish.setAutoFish(v)
				notify(hub, "Auto Fish", v and "ON" or "OFF", "fish", 2)
			end,
		})

		autoCookToggle = FishTab:Toggle({
			Title = "Auto Cook + Sell",
			Value = cfg.AutoCookSell,
			Flag = "Sigma_AutoCookSell",
			Callback = function(v)
				getgenv().SigmaFishConfig = getgenv().SigmaFishConfig or {}
				getgenv().SigmaFishConfig.AutoCookSell = v == true
				if Fish and Fish.setAutoCookSell then Fish.setAutoCookSell(v) end
				notify(hub, "Cook + Sell", v and "ON" or "OFF", "utensils", 2)
			end,
		})

		sellAtSlider = FishTab:Slider({
			Title = "Cook + Sell Threshold",
			Value = { Min = 5, Max = 80, Default = cfg.SellAt },
			Flag = "Sigma_FishSellAt",
			Callback = function(v)
				if Fish and Fish.setSellAt then Fish.setSellAt(v) end
				getgenv().SigmaFishConfig = getgenv().SigmaFishConfig or {}
				getgenv().SigmaFishConfig.SellAt = v
			end,
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
			local FishMod = Fish or getgenv().SigmaFish
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
			Flag = "Sigma_CacheUsePick",
			Callback = function(v)
				getgenv().SigmaFishConfig = getgenv().SigmaFishConfig or {}
				getgenv().SigmaFishConfig.CacheUsePick = v
				if Fish and Fish.setCacheUsePick then Fish.setCacheUsePick(v) end
			end,
		})

		cacheDropDropdown = FishTab:Dropdown({
			Title = "Drop Cache",
			Values = cacheKeyOptions,
			Value = cfg.CacheDropPick or {},
			Multi = true,
			Flag = "Sigma_CacheDropPick",
			Callback = function(v)
				getgenv().SigmaFishConfig = getgenv().SigmaFishConfig or {}
				getgenv().SigmaFishConfig.CacheDropPick = v
				if Fish and Fish.setCacheDropPick then Fish.setCacheDropPick(v) end
			end,
		})

		autoCacheDropToggle = FishTab:Toggle({
			Title = "Auto Drop Selected",
			Value = cfg.AutoCacheDrop == true,
			Default = false,
			Flag = "Sigma_AutoCacheDrop",
			Callback = function(v)
				getgenv().SigmaFishConfig = getgenv().SigmaFishConfig or {}
				getgenv().SigmaFishConfig.AutoCacheDrop = v == true
				if Fish and Fish.setAutoCacheDrop then Fish.setAutoCacheDrop(v) end
				notify(hub, "Auto Drop Cache", v and "ON" or "OFF", "package-minus", 2)
			end,
		})

		autoUseConsumablesToggle = FishTab:Toggle({
			Title = "Auto Use Fruits/Drinks",
			Desc = "Lemonade, Coconut, Prickly Pear, + drinks, etc.",
			Value = cfg.AutoUseConsumables ~= false,
			Default = true,
			Flag = "Sigma_AutoUseConsumables",
			Callback = function(v)
				getgenv().SigmaFishConfig = getgenv().SigmaFishConfig or {}
				getgenv().SigmaFishConfig.AutoUseConsumables = v ~= false
				if Fish and Fish.setAutoUseConsumables then Fish.setAutoUseConsumables(v) end
				notify(hub, "Auto Use Fruits/Drinks", v and "ON" or "OFF", "cup-soda", 2)
			end,
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
			Flag = "Sigma_QuestPick",
			Callback = function(v)
				getgenv().SigmaFishConfig = getgenv().SigmaFishConfig or {}
				getgenv().SigmaFishConfig.QuestPick = v
				if Fish and Fish.setQuestPick then Fish.setQuestPick(v) end
			end,
		})

		autoQuestToggle = QuestTab:Toggle({
			Title = "Auto Quest",
			Value = cfg.AutoQuest,
			Flag = "Sigma_AutoQuest",
			Callback = function(v)
				if not Fish or not Fish.setAutoQuest then
					notify(hub, "Quest", "Backend not loaded", "triangle-alert")
					return
				end
				getgenv().SigmaFishConfig = getgenv().SigmaFishConfig or {}
				getgenv().SigmaFishConfig.AutoQuest = v == true
				Fish.setAutoQuest(v)
				notify(hub, "Auto Quest", v and "ON" or "OFF", "list", 2)
			end,
		})

		QuestTab:Section({ Title = "Expertise", Icon = "book-open", Box = true, BoxBorder = true })

		autoExpertiseToggle = QuestTab:Toggle({
			Title = "Auto Expertise",
			Value = cfg.AutoExpertise,
			Flag = "Sigma_AutoExpertise",
			Callback = function(v)
				if not Fish or not Fish.setAutoExpertise then
					notify(hub, "Expertise", "Backend not loaded", "triangle-alert")
					return
				end
				getgenv().SigmaFishConfig = getgenv().SigmaFishConfig or {}
				getgenv().SigmaFishConfig.AutoExpertise = v == true
				Fish.setAutoExpertise(v)
				notify(hub, "Auto Expertise", v and "ON" or "OFF", "book-open", 2)
			end,
		})

		HakiTab:Section({ Title = "Haki Toggle", Icon = "eye", Box = true, BoxBorder = true })

		autoKenToggle = HakiTab:Toggle({
			Title = "Auto Kenbunshoku",
			Value = cfg.AutoKenbunshoku,
			Flag = "Sigma_AutoKenbunshoku",
			Callback = function(v)
				getgenv().SigmaFishConfig = getgenv().SigmaFishConfig or {}
				getgenv().SigmaFishConfig.AutoKenbunshoku = v == true
				if Fish and Fish.setAutoKenbunshoku then Fish.setAutoKenbunshoku(v) end
				notify(hub, "Kenbunshoku", v and "ON" or "OFF", "eye", 2)
			end,
		})

		autoBusoToggle = HakiTab:Toggle({
			Title = "Auto Busoshoku",
			Value = cfg.AutoBusoshoku,
			Flag = "Sigma_AutoBusoshoku",
			Callback = function(v)
				getgenv().SigmaFishConfig = getgenv().SigmaFishConfig or {}
				getgenv().SigmaFishConfig.AutoBusoshoku = v == true
				if Fish and Fish.setAutoBusoshoku then Fish.setAutoBusoshoku(v) end
				notify(hub, "Busoshoku", v and "ON" or "OFF", "shield", 2)
			end,
		})

		HakiTab:Section({ Title = "Farm", Icon = "zap", Box = true, BoxBorder = true })

		hakiStatusPara = HakiTab:Paragraph({
			Title = "Haki Status",
			Desc = "—",
		})

		getgenv().SigmaHakiMaxCallback = function(maxed, lv, stop)
			if not hakiStatusPara or not hakiStatusPara.SetDesc then return end
			if maxed then
				hakiStatusPara:SetDesc(string.format("MAX — Lv %d (stop %d)", lv or 0, stop or 0))
			else
				hakiStatusPara:SetDesc(string.format("Lv %d / stop %d", lv or 0, stop or 0))
			end
		end

		task.spawn(function()
			while hakiStatusPara and hakiStatusPara.SetDesc do
				local FishMod = getgenv().SigmaFish
				if FishMod and FishMod.getHakiStatus then
					local ok, st = pcall(FishMod.getHakiStatus)
					if ok and st and type(getgenv().SigmaHakiMaxCallback) == "function" then
						pcall(getgenv().SigmaHakiMaxCallback, st.maxed, st.level, st.stop)
					end
				end
				task.wait(2)
			end
		end)

		fastHakiToggle = HakiTab:Toggle({
			Title = "Fast Haki",
			Value = cfg.FastHaki,
			Flag = "Sigma_FastHaki",
			Callback = function(v)
				getgenv().SigmaFishConfig = getgenv().SigmaFishConfig or {}
				getgenv().SigmaFishConfig.FastHaki = v == true
				if Fish and Fish.setFastHaki then Fish.setFastHaki(v) end
				notify(hub, "Fast Haki", v and "ON" or "OFF", "zap", 2)
			end,
		})

		autoRayleighToggle = HakiTab:Toggle({
			Title = "Auto Rayleigh",
			Value = cfg.AutoRayleigh,
			Flag = "Sigma_AutoRayleigh",
			Callback = function(v)
				getgenv().SigmaFishConfig = getgenv().SigmaFishConfig or {}
				getgenv().SigmaFishConfig.AutoRayleigh = v == true
				if Fish and Fish.setAutoRayleigh then Fish.setAutoRayleigh(v) end
				notify(hub, "Auto Rayleigh", v and "ON" or "OFF", "sparkles", 2)
			end,
		})

		CompassTab:Section({ Title = "Sam / Compass", Icon = "compass", Box = true, BoxBorder = true })

		CompassTab:Paragraph({
			Title = "Note",
		})

		autoClaimSamToggle = CompassTab:Toggle({
			Title = "Auto Claim Sam",
			Value = cfg.AutoClaimSam == true,
			Default = false,
			Flag = "Sigma_AutoClaimSam",
			Callback = function(v)
				getgenv().SigmaFishConfig = getgenv().SigmaFishConfig or {}
				getgenv().SigmaFishConfig.AutoClaimSam = v == true
				if Fish and Fish.setAutoClaimSam then Fish.setAutoClaimSam(v) end
				notify(hub, "Auto Claim Sam", v and "ON" or "OFF", "compass", 2)
			end,
		})

		autoDropCompassToggle = CompassTab:Toggle({
			Title = "Auto Drop Compass",
			Value = cfg.AutoDropCompass == true,
			Default = false,
			Flag = "Sigma_AutoDropCompass",
			Callback = function(v)
				getgenv().SigmaFishConfig = getgenv().SigmaFishConfig or {}
				getgenv().SigmaFishConfig.AutoDropCompass = v == true
				if Fish and Fish.setAutoDropCompass then Fish.setAutoDropCompass(v) end
				notify(hub, "Auto Drop Compass", v and "ON" or "OFF", "package-minus", 2)
			end,
		})

		autoFindSamToggle = CompassTab:Toggle({
			Title = "Auto Find Sam (Compass Hunt)",
			Value = cfg.AutoFindSam == true,
			Default = false,
			Flag = "Sigma_AutoFindSam",
			Callback = function(v)
				getgenv().SigmaFishConfig = getgenv().SigmaFishConfig or {}
				getgenv().SigmaFishConfig.AutoFindSam = v == true
				if Fish and Fish.setAutoFindSam then Fish.setAutoFindSam(v) end
				notify(hub, "Auto Find Sam", v and "ON" or "OFF", "search", 2)
			end,
		})

		AutoSkillTab:Section({ Title = "Skill Spam", Icon = "keyboard", Box = true, BoxBorder = true })

		local skillKeyOptions = { "Z", "X", "C", "V", "B", "N", "F", "G", "H", "J", "K", "L" }

		local function applySkillHoldFromUI()
			if not skillHoldInput then return end
			local raw = skillHoldInput.Value
			if type(raw) == "string" then raw = raw:match("^%s*(.-)%s*$") end
			local n = tonumber(raw)
			if n == nil or n < 0 then return end
			getgenv().SigmaFishConfig = getgenv().SigmaFishConfig or {}
			getgenv().SigmaFishConfig.SkillHoldSec = n
			if Fish and Fish.setSkillHoldSec then Fish.setSkillHoldSec(n) end
		end

		local function applySkillKeysFromUI()
			if not skillKeysDropdown then return end
			local v = skillKeysDropdown.Value
			if v == nil then return end
			getgenv().SigmaFishConfig = getgenv().SigmaFishConfig or {}
			getgenv().SigmaFishConfig.SkillKeys = v
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
			Flag = "Sigma_SkillKeys",
			Callback = function(v)
				getgenv().SigmaFishConfig = getgenv().SigmaFishConfig or {}
				getgenv().SigmaFishConfig.SkillKeys = v
				applySkillHoldFromUI()
				if Fish and Fish.setSkillKeys then Fish.setSkillKeys(v) end
				if getgenv().SigmaFishConfig.AutoSkill and Fish and Fish.setAutoSkill then
					Fish.setAutoSkill(true)
				end
			end,
		})

		skillHoldInput = AutoSkillTab:Input({
			Title = "Hold (seconds)",
			Placeholder = "0.5",
			Value = tostring(cfg.SkillHoldSec or 0.5),
			Flag = "Sigma_SkillHoldSec",
			Callback = function(v)
				if type(v) == "string" then v = v:match("^%s*(.-)%s*$") end
				local n = tonumber(v)
				if n == nil or n < 0 then return end
				getgenv().SigmaFishConfig = getgenv().SigmaFishConfig or {}
				getgenv().SigmaFishConfig.SkillHoldSec = n
				if Fish and Fish.setSkillHoldSec then Fish.setSkillHoldSec(n) end
			end,
		})

		autoSkillToggle = AutoSkillTab:Toggle({
			Title = "Auto Skill",
			Value = cfg.AutoSkill == true,
			Default = false,
			Flag = "Sigma_AutoSkill",
			Callback = function(v)
				getgenv().SigmaFishConfig = getgenv().SigmaFishConfig or {}
				getgenv().SigmaFishConfig.AutoSkill = v == true
				applySkillHoldFromUI()
				applySkillKeysFromUI()
				if Fish and Fish.setSkillKeys then
					Fish.setSkillKeys(getgenv().SigmaFishConfig.SkillKeys)
				end
				if Fish and Fish.setAutoSkill then Fish.setAutoSkill(v) end
				notify(hub, "Auto Skill", v and "ON" or "OFF", "zap", 2)
			end,
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
				Flag = "Sigma_Affinity_" .. stat,
				Callback = function(v)
					getgenv().SigmaFishConfig = getgenv().SigmaFishConfig or {}
					local n = tonumber(v)
					if v == "" or v == nil then
						getgenv().SigmaFishConfig[cfgKey] = nil
					elseif n and n > 0 then
						getgenv().SigmaFishConfig[cfgKey] = n
					else
						return
					end
					if Fish and Fish.setAffinityTarget then
						Fish.setAffinityTarget(stat, getgenv().SigmaFishConfig[cfgKey])
					end
				end,
			})
		end

		affinityInput("Melee", "1.7")
		affinityInput("Sword", "1.3")
		affinityInput("Sniper", "1.3")
		affinityInput("Defense", "1.3")

		autoAffinityToggle = LucyTab:Toggle({
			Title = "Auto Affinity",
			Value = cfg.AutoAffinity,
			Flag = "Sigma_AutoAffinity",
			Callback = function(v)
				getgenv().SigmaFishConfig = getgenv().SigmaFishConfig or {}
				getgenv().SigmaFishConfig.AutoAffinity = v == true
				if Fish and Fish.setAutoAffinity then Fish.setAutoAffinity(v) end
				notify(hub, "Auto Affinity", v and "ON (slot 1)" or "OFF", "sparkles", 2)
			end,
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
			Flag = "Sigma_RejoinWhitelist",
			Callback = function(v)
				getgenv().SigmaFishConfig = getgenv().SigmaFishConfig or {}
				getgenv().SigmaFishConfig.RejoinWhitelist = tostring(v or "")
				if Fish and Fish.setRejoinWhitelist then Fish.setRejoinWhitelist(v) end
			end,
		})

		autoWhitelistToggle = SettingsTab:Toggle({
			Title = "Auto Whitelist Kick",
			Value = cfg.AutoWhitelistRejoin == true,
			Default = false,
			Flag = "Sigma_AutoWhitelistRejoin",
			Callback = function(v)
				getgenv().SigmaFishConfig = getgenv().SigmaFishConfig or {}
				getgenv().SigmaFishConfig.AutoWhitelistRejoin = v == true
				if rejoinWhitelistInput and rejoinWhitelistInput.Value ~= nil then
					getgenv().SigmaFishConfig.RejoinWhitelist = tostring(rejoinWhitelistInput.Value or "")
					if Fish and Fish.setRejoinWhitelist then
						Fish.setRejoinWhitelist(rejoinWhitelistInput.Value)
					end
				end
				if Fish and Fish.setAutoWhitelistRejoin then Fish.setAutoWhitelistRejoin(v) end
				notify(hub, "Whitelist Kick", v and "ON" or "OFF", "shield-check", 2)
			end,
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
			Flag = "Sigma_Theme",
			Callback = function(v)
				cfg.Theme = v
				getgenv().SigmaFishConfig = cfg
				if hub.SetTheme then hub:SetTheme(v) end
				if configFile and configFile.Set then configFile:Set("Theme", v) end
			end,
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
			Flag = "Sigma_AutoReloadConfig",
			Callback = function(v)
				cfg.AutoReloadConfig = v == true
				getgenv().SigmaFishConfig = cfg
				if configFile and configFile.SetAutoLoad then
					configFile:SetAutoLoad(v == true)
				end
				if configFile and configFile.Set then
					configFile:Set("AutoReloadConfig", v == true)
				end
				if v and configFile and configFile.Save then
					persistConfigMeta()
					pcall(function() configFile:Save() end)
				end
			end,
		})

		SettingsTab:Section({ Title = "Hub", Icon = "refresh-cw", Box = true, BoxBorder = true })

		SettingsTab:Button({
			Title = "Reload Hub",
			Icon = "refresh-cw",
			Color = PRIMARY,
			Callback = function()
				task.defer(function()
					if getgenv().ReloadSigmaHub then getgenv().ReloadSigmaHub() end
				end)
			end,
		})
	end)

	if not populateOk then
		uiLog(opts, "POPULATE FAILED: " .. tostring(populateErr))
		error("SigmaUI populate failed: " .. tostring(populateErr))
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

	getgenv().__SIGMA_UI_COUNTS = counts

	syncConfigFromUi = function(applyBackend)
		local c = getgenv().SigmaFishConfig or {}
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
		cfg = c
		getgenv().SigmaFishConfig = c
		if not applyBackend or not Fish then return c end
		if Fish.setAutoQuest then Fish.setAutoQuest(c.AutoQuest == true) end
		if Fish.setAutoExpertise then Fish.setAutoExpertise(c.AutoExpertise == true) end
		if Fish.setAutoFish then Fish.setAutoFish(c.AutoFish == true) end
		if Fish.setAutoCookSell then Fish.setAutoCookSell(c.AutoCookSell ~= false) end
		if Fish.setAutoSpawn then Fish.setAutoSpawn(c.AutoSpawn ~= false) end
		if Fish.setAntiAfk then Fish.setAntiAfk(c.AntiAfk ~= false) end
		if Fish.setSellAt then Fish.setSellAt(c.SellAt) end
		if Fish.setAutoKenbunshoku then Fish.setAutoKenbunshoku(c.AutoKenbunshoku == true) end
		if Fish.setAutoBusoshoku then Fish.setAutoBusoshoku(c.AutoBusoshoku == true) end
		if Fish.setFastHaki then Fish.setFastHaki(c.FastHaki == true) end
		if Fish.setAutoRayleigh then Fish.setAutoRayleigh(c.AutoRayleigh == true) end
		if Fish.setAutoAffinity then Fish.setAutoAffinity(c.AutoAffinity == true) end
		if Fish.setHideName then Fish.setHideName(c.HideName ~= false) end
		if Fish.setAutoClaimSam then Fish.setAutoClaimSam(c.AutoClaimSam == true) end
		if Fish.setAutoDropCompass then Fish.setAutoDropCompass(c.AutoDropCompass == true) end
		if Fish.setAutoFindSam then Fish.setAutoFindSam(c.AutoFindSam == true) end
		if Fish.setAutoSkill then Fish.setAutoSkill(c.AutoSkill == true) end
		if Fish.setSkillKeys then Fish.setSkillKeys(c.SkillKeys) end
		if Fish.setSkillHoldSec then Fish.setSkillHoldSec(c.SkillHoldSec) end
		if Fish.setRejoinWhitelist then Fish.setRejoinWhitelist(c.RejoinWhitelist) end
		if Fish.setAutoWhitelistRejoin then Fish.setAutoWhitelistRejoin(c.AutoWhitelistRejoin == true) end
		if Fish.setCacheUsePick then Fish.setCacheUsePick(c.CacheUsePick) end
		if Fish.setCacheDropPick then Fish.setCacheDropPick(c.CacheDropPick) end
		if Fish.setAutoCacheDrop then Fish.setAutoCacheDrop(c.AutoCacheDrop == true) end
		if Fish.setAutoUseConsumables then Fish.setAutoUseConsumables(c.AutoUseConsumables ~= false) end
		if Fish.applyConfig then Fish.applyConfig() end
		applyUiHideName()
		return c
	end

	task.spawn(function()
		if cfg.AutoReloadConfig ~= false then
			loadConfig(true)
		else
			task.wait(0.85)
			syncConfigFromUi(true)
		end
		uiLog(opts, "Config synced from UI toggles")
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
	end)

	return Window
end

return SigmaUI
