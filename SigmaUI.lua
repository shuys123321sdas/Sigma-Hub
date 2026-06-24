--[[ SigmaUI — Fishing tab (Auto Fish / Auto Chest / Cook+Sell) ]]

local SigmaUI = {}

local function statusText(Fish)
	if not Fish or not Fish.getStatus then
		return "Main.lua: not loaded"
	end
	local s = Fish.getStatus()
	return table.concat({
		"Auto Fish: " .. (s.autoFish and "ON" or "OFF"),
		"Auto Chest: " .. (s.autoSuperRod and "ON" or "OFF"),
		"Auto Cook+Sell: " .. (s.autoCookSell and "ON" or "OFF"),
		"Sell at: " .. tostring(s.sellAt or "?") .. " fish",
		"Sellable: " .. tostring(s.sellable or "?"),
		"Quest: " .. tostring(s.quest or "-"),
		"Minigame: " .. (s.inMinigame and "active" or "idle"),
	}, "\n")
end

function SigmaUI.build(hub, Fish, opts)
	opts = opts or {}
	local notify = opts.notify or function(_, title, content)
		hub:Notify({ Title = title, Content = content, Duration = 3 })
	end
	local PRIMARY = opts.primary or Color3.fromRGB(139, 92, 246)

	local cfg = getgenv().SigmaFishConfig or {}
	cfg.AutoFish = cfg.AutoFish == true
	cfg.AutoSuperRod = cfg.AutoSuperRod == true
	cfg.AutoCookSell = cfg.AutoCookSell ~= false
	cfg.SellAt = tonumber(cfg.SellAt) or 40
	getgenv().SigmaFishConfig = cfg

	local Window = hub:CreateWindow({
		Title = "Sigma Hub",
		Author = "One Piece: Final · Fishing",
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

	local MainTab = Window:Tab({ Title = "Main", Icon = "house" })
	local FishTab = Window:Tab({ Title = "Fishing", Icon = "fish" })
	local SettingsTab = Window:Tab({ Title = "Settings", Icon = "settings" })

	task.defer(function()
		local statusPara = MainTab:Paragraph({
			Title = "Status",
			Desc = statusText(Fish),
			Buttons = {
				{
					Title = "Refresh",
					Icon = "refresh-cw",
					Callback = function()
						if statusPara and statusPara.SetDesc then
							statusPara:SetDesc(statusText(Fish))
						end
					end,
				},
			},
		})

		FishTab:Section({ Title = "Fishing", Icon = "fish", Box = true, BoxBorder = true })

		FishTab:Toggle({
			Title = "Auto Fish",
			Desc = "Quăng câu tại chỗ đang đứng",
			Value = cfg.AutoFish,
			Flag = "Sigma_AutoFish",
			Callback = function(v)
				if not Fish or not Fish.setAutoFish then
					notify(hub, "Fishing", "Main.lua chưa load", "triangle-alert")
					return
				end
				Fish.setAutoFish(v)
				notify(hub, "Auto Fish", v and "ON" or "OFF", "fish", 2)
				if statusPara and statusPara.SetDesc then statusPara:SetDesc(statusText(Fish)) end
			end,
		})

		FishTab:Toggle({
			Title = "Auto Chest",
			Desc = "Super Rod quest — nhận/giao từ xa",
			Value = cfg.AutoSuperRod,
			Flag = "Sigma_AutoChest",
			Callback = function(v)
				if not Fish or not Fish.setAutoSuperRod then
					notify(hub, "Fishing", "Main.lua chưa load", "triangle-alert")
					return
				end
				Fish.setAutoSuperRod(v)
				getgenv().SigmaFishConfig.AutoSuperRod = v
				if v then getgenv().SigmaFishConfig.AutoFish = true end
				notify(hub, "Auto Chest", v and "ON" or "OFF", "sparkles", 2)
				if statusPara and statusPara.SetDesc then statusPara:SetDesc(statusText(Fish)) end
			end,
		})

		FishTab:Toggle({
			Title = "Auto Cook + Sell",
			Desc = "Tự cook + sell khi đủ cá",
			Value = cfg.AutoCookSell,
			Flag = "Sigma_AutoCookSell",
			Callback = function(v)
				if Fish and Fish.setAutoCookSell then Fish.setAutoCookSell(v) end
				getgenv().SigmaFishConfig.AutoCookSell = v
				notify(hub, "Cook+Sell", v and "ON" or "OFF", "utensils", 2)
				if statusPara and statusPara.SetDesc then statusPara:SetDesc(statusText(Fish)) end
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
				if statusPara and statusPara.SetDesc then statusPara:SetDesc(statusText(Fish)) end
			end,
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

		if Window.SelectTab and FishTab.Index then
			Window:SelectTab(FishTab.Index)
		end
	end)

	return Window
end

return SigmaUI
