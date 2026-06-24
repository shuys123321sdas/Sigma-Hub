--[[ SigmaUI — Fishing + Quest tabs ]]

local SigmaUI = {}

local function uiLog(opts, msg)
	if opts and opts.log then
		opts.log(msg)
	elseif getgenv().SigmaHubLog then
		getgenv().SigmaHubLog(msg)
	else
		print("[SigmaUI]", msg)
	end
end

local function safeStatusText(Fish)
	if not Fish or not Fish.getStatus then
		return "Main.lua: not loaded"
	end
	local ok, result = pcall(function()
		return Fish.getStatus()
	end)
	if not ok then
		return "Status error: " .. tostring(result)
	end
	local s = result
	return table.concat({
		"Auto Spawn: " .. (s.autoSpawn and "ON" or "OFF"),
		"Anti AFK: " .. (s.antiAfk and "ON" or "OFF"),
		"Auto Fish: " .. (s.autoFish and "ON" or "OFF"),
		"Rod quest: " .. tostring(s.rodPhase or "-"),
		"Has rod: " .. (s.hasRod and "yes" or "no"),
		"Auto Quest: " .. (s.autoQuest and "ON" or "OFF"),
		"Picked: " .. tostring(s.questPick ~= "" and s.questPick or "-"),
		"Auto Expertise: " .. (s.autoExpertise and "ON" or "OFF"),
		"Active quest: " .. tostring(s.questActive or "-"),
		"Auto Cook+Sell: " .. (s.autoCookSell and "ON" or "OFF"),
		"Sell at: " .. tostring(s.sellAt or "?"),
		"Minigame: " .. (s.inMinigame and "active" or "idle"),
	}, "\n")
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

	local cfg = getgenv().SigmaFishConfig or {}
	cfg.AutoFish = cfg.AutoFish == true
	cfg.AutoQuest = cfg.AutoQuest == true
	cfg.AutoExpertise = cfg.AutoExpertise == true
	cfg.AutoCookSell = cfg.AutoCookSell ~= false
	cfg.AutoSpawn = cfg.AutoSpawn ~= false
	cfg.AntiAfk = cfg.AntiAfk ~= false
	cfg.SellAt = tonumber(cfg.SellAt) or 40
	cfg.QuestPick = cfg.QuestPick or {}
	getgenv().SigmaFishConfig = cfg

	local questOptions = (Fish and Fish.getQuestList and Fish.getQuestList()) or {}

	uiLog(opts, "CreateWindow...")
	local Window = hub:CreateWindow({
		Title = "Sigma Hub",
		Author = "One Piece: Final",
		Icon = "fish",
		Folder = "SigmaHub",
		Theme = "Sigma",
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

	if Window.ConfigManager then
		local c = Window.ConfigManager:Config("sigma-fish")
		if c and c.SetAsCurrent then c:SetAsCurrent() end
	end

	uiLog(opts, "Creating tabs...")
	local MainTab = Window:Tab({ Title = "Main", Icon = "house" })
	local FishTab = Window:Tab({ Title = "Fishing", Icon = "fish" })
	local QuestTab = Window:Tab({ Title = "Quest", Icon = "list" })
	local SettingsTab = Window:Tab({ Title = "Settings", Icon = "settings" })

	uiLog(opts, "Populating tab controls (sync)...")
	local autoFishToggle, autoCookToggle, autoQuestToggle, autoExpertiseToggle, questDropdown
	local autoSpawnToggle, antiAfkToggle
	local populateOk, populateErr = pcall(function()
		local statusPara = MainTab:Paragraph({
			Title = "Status",
			Desc = safeStatusText(Fish),
			Buttons = {
				{
					Title = "Refresh",
					Icon = "refresh-cw",
					Callback = function()
						if statusPara and statusPara.SetDesc then
							statusPara:SetDesc(safeStatusText(Fish))
						end
					end,
				},
			},
		})

		MainTab:Section({ Title = "General", Icon = "shield", Box = true, BoxBorder = true })

		autoSpawnToggle = MainTab:Toggle({
			Title = "Auto Spawn",
			Desc = "Tự bấm Spawn khi vào game (màn Load)",
			Value = cfg.AutoSpawn ~= false,
			Default = true,
			Flag = "Sigma_AutoSpawn",
			Callback = function(v)
				getgenv().SigmaFishConfig = getgenv().SigmaFishConfig or {}
				getgenv().SigmaFishConfig.AutoSpawn = v == true
				if Fish and Fish.setAutoSpawn then Fish.setAutoSpawn(v) end
				notify(hub, "Auto Spawn", v and "ON" or "OFF", "play", 2)
				if statusPara and statusPara.SetDesc then statusPara:SetDesc(safeStatusText(Fish)) end
			end,
		})

		antiAfkToggle = MainTab:Toggle({
			Title = "Anti AFK",
			Desc = "Chống kick AFK (VirtualUser + chặn hop + nhảy định kỳ)",
			Value = cfg.AntiAfk ~= false,
			Default = true,
			Flag = "Sigma_AntiAfk",
			Callback = function(v)
				getgenv().SigmaFishConfig = getgenv().SigmaFishConfig or {}
				getgenv().SigmaFishConfig.AntiAfk = v == true
				if Fish and Fish.setAntiAfk then Fish.setAntiAfk(v) end
				notify(hub, "Anti AFK", v and "ON" or "OFF", "shield", 2)
				if statusPara and statusPara.SetDesc then statusPara:SetDesc(safeStatusText(Fish)) end
			end,
		})

		FishTab:Section({ Title = "Fishing", Icon = "fish", Box = true, BoxBorder = true })

		autoFishToggle = FishTab:Toggle({
			Title = "Auto Fish",
			Desc = "Câu tại chỗ + tự làm quest rod (Package→Wood→Task→Sturdy→Challenge→Super) + equip rod tốt nhất",
			Value = cfg.AutoFish,
			Flag = "Sigma_AutoFish",
			Callback = function(v)
				if not Fish or not Fish.setAutoFish then
					notify(hub, "Fishing", "Main.lua chưa load", "triangle-alert")
					return
				end
				getgenv().SigmaFishConfig = getgenv().SigmaFishConfig or {}
				getgenv().SigmaFishConfig.AutoFish = v == true
				Fish.setAutoFish(v)
				notify(hub, "Auto Fish", v and "ON" or "OFF", "fish", 2)
				if statusPara and statusPara.SetDesc then statusPara:SetDesc(safeStatusText(Fish)) end
			end,
		})

		autoCookToggle = FishTab:Toggle({
			Title = "Auto Cook + Sell",
			Desc = "Cook + sell từ xa (không TP bếp/Cooker)",
			Value = cfg.AutoCookSell,
			Flag = "Sigma_AutoCookSell",
			Callback = function(v)
				getgenv().SigmaFishConfig = getgenv().SigmaFishConfig or {}
				getgenv().SigmaFishConfig.AutoCookSell = v == true
				if Fish and Fish.setAutoCookSell then Fish.setAutoCookSell(v) end
				notify(hub, "Cook+Sell", v and "ON" or "OFF", "utensils", 2)
				if statusPara and statusPara.SetDesc then statusPara:SetDesc(safeStatusText(Fish)) end
			end,
		})

		FishTab:Slider({
			Title = "Cook + Sell Every Fish",
			Desc = "Số cá tối thiểu để auto cook + sell",
			Value = { Min = 5, Max = 80, Default = cfg.SellAt },
			Flag = "Sigma_FishSellAt",
			Callback = function(v)
				if Fish and Fish.setSellAt then Fish.setSellAt(v) end
				getgenv().SigmaFishConfig.SellAt = v
			end,
		})

		FishTab:Button({
			Title = "Cook Fish + Sell Fish",
			Icon = "utensils",
			Color = PRIMARY,
			Callback = function()
				if not Fish or not Fish.cookSell then
					notify(hub, "Fishing", "Main.lua chưa load", "triangle-alert")
					return
				end
				Fish.cookSell()
				notify(hub, "Cook+Sell", "Done", "utensils", 2)
				if statusPara and statusPara.SetDesc then statusPara:SetDesc(safeStatusText(Fish)) end
			end,
		})

		QuestTab:Section({ Title = "Auto Quest", Icon = "list", Box = true, BoxBorder = true })

		questDropdown = QuestTab:Dropdown({
			Title = "Select Quests",
			Desc = "Chọn nhiều quest — bật Auto Quest để tự làm",
			Values = questOptions,
			Value = cfg.QuestPick,
			Multi = true,
			Flag = "Sigma_QuestPick",
			Callback = function(v)
				getgenv().SigmaFishConfig = getgenv().SigmaFishConfig or {}
				getgenv().SigmaFishConfig.QuestPick = v
				if Fish and Fish.setQuestPick then Fish.setQuestPick(v) end
				if statusPara and statusPara.SetDesc then statusPara:SetDesc(safeStatusText(Fish)) end
			end,
		})

		autoQuestToggle = QuestTab:Toggle({
			Title = "Auto Quest",
			Desc = "Tự accept / deliver / claim quest đã chọn (quest kill mob cần farm tay)",
			Value = cfg.AutoQuest,
			Flag = "Sigma_AutoQuest",
			Callback = function(v)
				if not Fish or not Fish.setAutoQuest then
					notify(hub, "Quest", "Main.lua chưa load", "triangle-alert")
					return
				end
				getgenv().SigmaFishConfig = getgenv().SigmaFishConfig or {}
				getgenv().SigmaFishConfig.AutoQuest = v == true
				Fish.setAutoQuest(v)
				notify(hub, "Auto Quest", v and "ON" or "OFF", "list", 2)
				if statusPara and statusPara.SetDesc then statusPara:SetDesc(safeStatusText(Fish)) end
			end,
		})

		QuestTab:Section({ Title = "Expertise", Icon = "book-open", Box = true, BoxBorder = true })

		autoExpertiseToggle = QuestTab:Toggle({
			Title = "Auto Expertise",
			Desc = "Chỉ làm quest Old Beggar (Humble Man #1) — giao trái cây từ xa",
			Value = cfg.AutoExpertise,
			Flag = "Sigma_AutoExpertise",
			Callback = function(v)
				if not Fish or not Fish.setAutoExpertise then
					notify(hub, "Expertise", "Main.lua chưa load", "triangle-alert")
					return
				end
				getgenv().SigmaFishConfig = getgenv().SigmaFishConfig or {}
				getgenv().SigmaFishConfig.AutoExpertise = v == true
				Fish.setAutoExpertise(v)
				notify(hub, "Expertise", v and "ON — Old Beggar" or "OFF", "book-open", 2)
				if statusPara and statusPara.SetDesc then statusPara:SetDesc(safeStatusText(Fish)) end
			end,
		})

		QuestTab:Paragraph({
			Title = "Ghi chú",
			Desc = table.concat({
				"Auto Fish: tự quest rod Fisherman (clone chưa rod → Package trước).",
				"Auto Quest: Joe, Demon Hunter... (kill mob) cần farm combat riêng.",
				"Auto Expertise: chỉ Old Beggar, tách khỏi Auto Quest.",
			}, "\n"),
		})

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
		warn("[SigmaUI] populate error:", populateErr)
		warn(debug.traceback(tostring(populateErr), 2))
		error("SigmaUI populate failed: " .. tostring(populateErr))
	end

	local counts = {
		Main = countElements(MainTab),
		Fishing = countElements(FishTab),
		Quest = countElements(QuestTab),
		Settings = countElements(SettingsTab),
	}
	uiLog(opts, string.format(
		"Elements — Main:%d Fishing:%d Quest:%d Settings:%d",
		counts.Main, counts.Fishing, counts.Quest, counts.Settings
	))

	getgenv().__SIGMA_UI_COUNTS = counts

	task.spawn(function()
		task.wait(0.85)
		if not Fish or not Fish.applyConfig then return end
		local c = getgenv().SigmaFishConfig or {}
		if autoFishToggle and autoFishToggle.Value ~= nil then
			c.AutoFish = autoFishToggle.Value == true
		end
		if autoQuestToggle and autoQuestToggle.Value ~= nil then
			c.AutoQuest = autoQuestToggle.Value == true
		end
		if autoExpertiseToggle and autoExpertiseToggle.Value ~= nil then
			c.AutoExpertise = autoExpertiseToggle.Value == true
		end
		if autoCookToggle and autoCookToggle.Value ~= nil then
			c.AutoCookSell = autoCookToggle.Value ~= false
		end
		if autoSpawnToggle and autoSpawnToggle.Value ~= nil then
			c.AutoSpawn = autoSpawnToggle.Value == true
		end
		if antiAfkToggle and antiAfkToggle.Value ~= nil then
			c.AntiAfk = antiAfkToggle.Value == true
		end
		if questDropdown and questDropdown.Value ~= nil then
			c.QuestPick = questDropdown.Value
		end
		getgenv().SigmaFishConfig = c
		Fish.applyConfig()
		uiLog(opts, "Config synced from UI toggles")
	end)

	task.spawn(function()
		task.wait(0.15)
		hideEmptyPlaceholder(MainTab)
		hideEmptyPlaceholder(FishTab)
		hideEmptyPlaceholder(QuestTab)
		hideEmptyPlaceholder(SettingsTab)

		if Window.SelectTab and MainTab.Index then
			Window:SelectTab(MainTab.Index)
		end
	end)

	return Window
end

return SigmaUI
