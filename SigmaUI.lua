--[[
 SigmaUI — WindUI layout wired to sigma.lua (fishing backend)
 Loaded by SigmaHub.lua — no sample toggles.
]]

local SigmaUI = {}

local function statusText(Fish)
	if not Fish or not Fish.getStatus then
		return "sigma.lua: not loaded"
	end
	local s = Fish.getStatus()
	local lines = {
		"Auto Fish: " .. (s.autoFish and "ON" or "OFF"),
		"Auto Super Rod: " .. (s.autoSuperRod and "ON" or "OFF"),
		"Sell at: " .. tostring(s.sellAt or "?") .. " fish",
		"Stats.Fish: " .. tostring(s.fishCount or "?"),
		"Minigame: " .. (s.inMinigame and "active" or "idle"),
	}
	return table.concat(lines, "\n")
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
	cfg.SellAt = tonumber(cfg.SellAt) or (cfg.AutoSuperRod and 40 or 15)
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
		if c and c.SetAsCurrent then
			c:SetAsCurrent()
		end
	end

	local MainTab = Window:Tab({ Title = "Main", Icon = "house" })
	local FishTab = Window:Tab({ Title = "Fishing", Icon = "fish" })
	local SettingsTab = Window:Tab({ Title = "Settings", Icon = "settings" })

	task.defer(function()
		-- ═══ MAIN ═══
		MainTab:Paragraph({
			Title = "Sigma Hub",
			Desc = "Auto fish backend: sigma.lua (separate from a.lua)",
		})

		local statusPara = MainTab:Paragraph({
			Title = "Fishing Status",
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

		-- ═══ FISHING ═══
		FishTab:Section({ Title = "Auto Fish", Icon = "fish", Box = true, BoxBorder = true })

		FishTab:Toggle({
			Title = "Auto Fish",
			Desc = "Bật vòng lặp câu cá (sigma.lua)",
			Value = cfg.AutoFish,
			Flag = "Sigma_AutoFish",
			Callback = function(v)
				if not Fish or not Fish.setAutoFish then
					notify(hub, "Fishing", "sigma.lua chưa load", "triangle-alert")
					return
				end
				Fish.setAutoFish(v)
				notify(hub, "Auto Fish", v and "ON" or "OFF", "fish", 2)
				if statusPara and statusPara.SetDesc then
					statusPara:SetDesc(statusText(Fish))
				end
			end,
		})

		FishTab:Toggle({
			Title = "Auto Super Rod",
			Desc = "Quest Super Rod tại Fisherman (đứng sát NPC + câu quest fish)",
			Value = cfg.AutoSuperRod,
			Flag = "Sigma_AutoSuperRod",
			Callback = function(v)
				if not Fish or not Fish.setAutoSuperRod then
					notify(hub, "Fishing", "sigma.lua chưa load", "triangle-alert")
					return
				end
				Fish.setAutoSuperRod(v)
				getgenv().SigmaFishConfig.AutoSuperRod = v
				notify(hub, "Super Rod", v and "ON" or "OFF", "sparkles", 2)
				if statusPara and statusPara.SetDesc then
					statusPara:SetDesc(statusText(Fish))
				end
			end,
		})

		FishTab:Slider({
			Title = "Sell At (fish count)",
			Desc = "Đủ số cá → cook + sell (Super Rod mặc định 40)",
			Value = { Min = 5, Max = 80, Default = cfg.SellAt or 40 },
			Flag = "Sigma_FishSellAt",
			Callback = function(v)
				if Fish and Fish.setSellAt then
					Fish.setSellAt(v)
				end
				getgenv().SigmaFishConfig.SellAt = v
			end,
		})

		FishTab:Paragraph({
			Title = "Quest fish (Super Rod)",
			Desc = table.concat({
				"Fisherman's Favor → Wood Rod",
				"Fisherman's Task → Sturdy Rod",
				"Fisherman's Challenge → Super Rod",
			}, "\n"),
		})

		FishTab:Button({
			Title = "Stop Fishing",
			Icon = "square",
			Color = Color3.fromRGB(220, 80, 80),
			Callback = function()
				if Fish and Fish.stop then
					Fish.stop()
					notify(hub, "Fishing", "Stopped", "square", 2)
				end
				if statusPara and statusPara.SetDesc then
					statusPara:SetDesc(statusText(Fish))
				end
			end,
		})

		-- ═══ SETTINGS ═══
		SettingsTab:Section({ Title = "Hub", Icon = "settings" })

		SettingsTab:Button({
			Title = "Reload Hub",
			Icon = "refresh-cw",
			Color = PRIMARY,
			Callback = function()
				task.defer(function()
					if getgenv().ReloadSigmaHub then
						getgenv().ReloadSigmaHub()
					end
				end)
			end,
		})

		SettingsTab:Paragraph({
			Title = "Files",
			Desc = table.concat({
				"UI: SigmaHub.lua + SigmaUI.lua",
				"Backend: sigma.lua",
				"Library: " .. (hub.Build or "SigmaHub"),
			}, "\n"),
		})

		if Window.SelectTab and MainTab.Index then
			Window:SelectTab(MainTab.Index)
		end
	end)

	return Window
end

return SigmaUI
