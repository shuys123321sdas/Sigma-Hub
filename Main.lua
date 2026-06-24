--[[ Main.lua — Sigma Hub fishing (stand still, cast in place) ]]

if type(getgenv) ~= "function" then getgenv = function() return _G end end
if type(task) ~= "table" then task = { wait = wait, spawn = function(f) coroutine.wrap(f)() end } end
if LPH_OBFUSCATED == nil then function LPH_NO_VIRTUALIZE(f) return f end end

CFG = getgenv().SigmaConfig or {}
getgenv().SigmaConfig = CFG

Players = game:GetService("Players")
ReplicatedFirst = game:GetService("ReplicatedFirst")
GuiService = game:GetService("GuiService")
VirtualUser = game:GetService("VirtualUser")
VirtualInputManager = game:GetService("VirtualInputManager")
player = Players.LocalPlayer

RUN = { id = 0 }
FISH = {
	ON = false, SUPER = false, AUTO_SELL = true,
	SELL_AT = 40, LOOP_DELAY = 0.25,
	CAST_TIMEOUT = 4, BITE_TIMEOUT = 30, REEL_TIMEOUT = 4,
	COOK_PATH = "MapFolder.Island8.Kitchen.Cooking.CookingStation",
	FISHERMAN = "Fisherman", COOKER = "Cooker", ROD_CAT = "Utility",
	RODS = { "Super Rod", "Sturdy Rod", "Wood Rod" },
	Q_FAVOR = "Fisherman's Favor", Q_TASK = "Fisherman's Task", Q_CHALLENGE = "Fisherman's Challenge",
	TASK_FISH = {
		"Small Flooper", "Small Busser", "Small Lubber", "Small Jawber",
		"Medium Flooper", "Medium Busser", "Medium Lubber", "Medium Jawber",
		"Large Flooper", "Large Busser", "Large Jawber", "Large Lubber",
	},
}
STATE = {
	pause = false, loopRunning = false, inMini = false, solving = false,
	fishCount = nil, listeners = false, lastSell = 0, lastDeliver = 0,
}

function isActive()
	return getgenv().__SIGMA_FISH_RUNNING and getgenv().__SIGMA_FISH_RUN_ID == RUN.id
end

function getData()
	local root = _G.Data
	if not root and getrenv then
		local ok, r = pcall(getrenv)
		if ok and r and r._G then root = r._G.Data end
	end
	if not root and getgenv then
		local ok, g = pcall(getgenv)
		if ok and g and g.Data then root = g.Data end
	end
	if not root or not player then return nil end
	return root[player.UserId] or root[tostring(player.UserId)]
end

function getQuests()
	return getData() and getData().Quests
end

function qHist(name)
	local q = getQuests()
	return q and q.History and q.History[name] == true
end

function exec(ch, args)
	local mod = ReplicatedFirst:FindFirstChildOfClass("ModuleScript")
	if not mod then return false end
	local ok, med = pcall(require, mod)
	if not ok or not med then return false end
	local fn = med["\t"] or med.Executor
	if type(fn) ~= "function" then return false end
	return pcall(fn, ch, args or {})
end

function getHRP()
	local c = player and player.Character
	return c and c:FindFirstChild("HumanoidRootPart")
end

function getPos(inst)
	if not inst then return nil end
	if inst:IsA("BasePart") then return inst.Position end
	if inst:IsA("Model") then
		local ok, p = pcall(function() return inst:GetPivot().Position end)
		if ok and p then return p end
		local pp = inst.PrimaryPart or inst:FindFirstChild("HumanoidRootPart")
		if pp then return pp.Position end
	end
	local p = inst:FindFirstChildWhichIsA("BasePart", true)
	return p and p.Position
end

function tpNear(inst)
	local hrp, pos = getHRP(), getPos(inst)
	if not hrp or not pos then return false end
	pcall(function() hrp.CFrame = CFrame.new(pos + Vector3.new(0, 6, 0)) end)
	task.wait(0.12)
	return true
end

function resolvePath(path)
	local cur = workspace
	for seg in string.gmatch(path, "[^%.]+") do
		cur = cur and cur:FindFirstChild(seg)
	end
	return cur
end

function findNPC(name)
	local root = workspace:FindFirstChild("Ignore")
	root = root and root:FindFirstChild("NPCs")
	if not root then return nil end
	local hrp, best, bestD = getHRP(), nil, nil
	for _, m in root:GetDescendants() do
		if m:IsA("Model") and (m.Name == name or m:GetAttribute("DialogueModule") == name) then
			local pos = getPos(m)
			if pos then
				local d = hrp and (hrp.Position - pos).Magnitude or 0
				if not bestD or d < bestD then best, bestD = m, d end
			end
		end
	end
	return best
end

function setMerchant(model)
	local cur = player:FindFirstChild("CurrentMerchant")
	if cur and cur:IsA("ObjectValue") then cur.Value = model end
end

function questExec(fm, ...)
	if not fm then return false end
	setMerchant(fm)
	task.wait(0.05)
	return exec("QuestEvents", { ... })
end

function clickNPC(model)
	if not model then return end
	tpNear(model)
	local part = model:FindFirstChild("HumanoidRootPart") or model:FindFirstChildWhichIsA("BasePart", true)
	if not part then return end
	setMerchant(model)
	local cd = part:FindFirstChildOfClass("ClickDetector") or part:FindFirstChildWhichIsA("ClickDetector", true)
	if cd and fireclickdetector then pcall(fireclickdetector, cd) end
	task.wait(0.15)
end

function tpFace(model, dist, up)
	local hrp, pos = getHRP(), getPos(model)
	if not hrp or not pos then return false end
	dist, up = dist or 4, up or 1
	local npcHRP = model:FindFirstChild("HumanoidRootPart")
	local facing = npcHRP and npcHRP.CFrame.LookVector or Vector3.new(0, 0, 1)
	facing = Vector3.new(facing.X, 0, facing.Z)
	if facing.Magnitude < 0.1 then facing = Vector3.new(0, 0, 1) else facing = facing.Unit end
	local stand = pos + facing * dist + Vector3.new(0, up, 0)
	pcall(function() hrp.CFrame = CFrame.new(stand, Vector3.new(pos.X, stand.Y, pos.Z)) end)
	return true
end

function equipItem(name)
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not hum then return false end
	if char:FindFirstChild(name) then return true end
	local tool = player:FindFirstChild("Backpack") and player.Backpack:FindFirstChild(name)
	if tool then pcall(function() hum:EquipTool(tool) end) task.wait(0.05) end
	return char:FindFirstChild(name) ~= nil
end

function useTool(tool)
	if not tool or not tool:IsA("Tool") then return end
	local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if hum then pcall(function() hum:EquipTool(tool) end) end
	if not pcall(function() tool:Activate() end) and VirtualUser then
		local cam = workspace.CurrentCamera
		if cam then pcall(function() VirtualUser:Button1Down(Vector2.zero, cam.CFrame) VirtualUser:Button1Up(Vector2.zero, cam.CFrame) end) end
	end
end

function questDone()
	local q = getQuests()
	return q and q.Completed == true
end

function receiverNPCs()
	local root = workspace:FindFirstChild("Ignore")
	root = root and root:FindFirstChild("NPCs")
	if not root then return {} end
	local hrp, arr, seen = getHRP(), {}, {}
	for _, m in root:GetDescendants() do
		if m:IsA("Model") and not seen[m] and m.Name ~= FISH.FISHERMAN then
			local pos = getPos(m)
			if pos then
				seen[m] = true
				table.insert(arr, { model = m, name = m.Name, d = hrp and (hrp.Position - pos).Magnitude or 0 })
			end
		end
	end
	table.sort(arr, function(a, b) return a.d < b.d end)
	return arr
end

function findTool(name)
	local want = string.lower(name)
	for _, where in ipairs({ player.Character, player:FindFirstChild("Backpack") }) do
		if where then
			for _, t in ipairs(where:GetChildren()) do
				if t:IsA("Tool") and string.lower(t.Name) == want then return t end
			end
		end
	end
end

function findRod()
	for _, n in ipairs(FISH.RODS) do
		local t = findTool(n)
		if t then return t, n end
	end
	for _, where in ipairs({ player.Character, player:FindFirstChild("Backpack") }) do
		if where then
			for _, t in ipairs(where:GetChildren()) do
				if t:IsA("Tool") and string.find(string.lower(t.Name), "rod", 1, true) then
					return t, t.Name
				end
			end
		end
	end
end

function equipRod(name)
	if not name then return findRod() end
	if findTool(name) then exec("Equip", { name, FISH.ROD_CAT }) task.wait(0.3) end
	return findRod()
end

function isFishTool(name)
	if not name or string.find(string.lower(name), "rod", 1, true) then return false end
	local low = string.lower(name)
	for _, sz in ipairs({ "small", "medium", "large", "huge" }) do
		if string.find(low, sz, 1, true) then return true end
	end
	return false
end

function scanFish()
	local out = {}
	for _, where in ipairs({ player.Character, player:FindFirstChild("Backpack") }) do
		if where then
			for _, t in ipairs(where:GetChildren()) do
				if t:IsA("Tool") and isFishTool(t.Name) then table.insert(out, t) end
			end
		end
	end
	return out
end

function superMode()
	return FISH.SUPER and not qHist(FISH.Q_CHALLENGE)
end

function objNeed(fishName)
	local q = getQuests()
	if not q or q.Active ~= FISH.Q_TASK then return false end
	local obj = q.Objectives and q.Objectives[fishName]
	if not obj then return false end
	local p = type(obj) == "table" and tonumber(obj.Progress) or 0
	local r = type(obj) == "table" and tonumber(obj.Requirement or obj.Goal) or 1
	return p < r
end

function keepQuestFish()
	return superMode() and not qHist(FISH.Q_TASK)
end

function keepFish(name)
	if not keepQuestFish() or not name then return false end
	if objNeed(name) then return true end
	local low = string.lower(name)
	return string.find(low, "medium", 1, true) or string.find(low, "large", 1, true)
end

function countSellable()
	local n = 0
	for _, t in ipairs(scanFish()) do if not keepFish(t.Name) then n += 1 end end
	return n
end

function hasItem(name)
	for _, where in ipairs({ player.Character, player:FindFirstChild("Backpack") }) do
		if where and where:FindFirstChild(name) then return true end
	end
	return false
end

function getBobber()
	local rope = workspace:FindFirstChild("FishingRope_" .. tostring(player.UserId))
	if not rope then
		for _, c in ipairs(workspace:GetChildren()) do
			if string.sub(c.Name, 1, 12) == "FishingRope_" then rope = c break end
		end
	end
	return rope and rope:FindFirstChild("Bobber")
end

function lineOut() return getBobber() ~= nil end

function onHook()
	local b = getBobber()
	return b and b:FindFirstChild("Sparkles") ~= nil
end

function rodHeld(rod)
	return rod and player.Character and rod.Parent == player.Character
end

function equipBestRod()
	local rod = select(1, findRod())
	if not rod then return nil end
	if rodHeld(rod) then return rod end
	local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if hum then pcall(function() hum:EquipTool(rod) end) end
	task.wait(0.1)
	if not rodHeld(rod) then pcall(function() rod.Parent = player.Character hum:EquipTool(rod) end) end
	return rodHeld(rod) and rod or nil
end

function clickRod(rod)
	if not rodHeld(rod) then return false end
	if pcall(function() rod:Activate() end) then return true end
	if VirtualUser then
		local cam = workspace.CurrentCamera
		if cam then pcall(function() VirtualUser:Button1Down(Vector2.zero, cam.CFrame) VirtualUser:Button1Up(Vector2.zero, cam.CFrame) end) end
	end
	return false
end

function waitUntil(cond, timeout)
	local t0 = os.clock()
	while isActive() and FISH.ON and not cond() and os.clock() - t0 < timeout do
		task.wait(0.05)
	end
	return cond()
end

function btnBright(btn)
	if not btn or not btn:IsA("GuiObject") or (btn.BackgroundTransparency or 0) > 0.5 then return 0 end
	local c = btn.BackgroundColor3
	return c.R + c.G + c.B
end

function miniButtons(gui)
	local out = {}
	for _, d in ipairs(gui:GetDescendants()) do
		if d:IsA("TextButton") and d:FindFirstChild("TextLabel") and d.Visible then
			local s = math.min(d.AbsoluteSize.X, d.AbsoluteSize.Y)
			if s > 40 then table.insert(out, d) end
		end
	end
	return out
end

function pickMiniBtn(gui)
	local rows = {}
	for _, btn in ipairs(miniButtons(gui)) do
		table.insert(rows, { btn = btn, b = btnBright(btn), s = math.min(btn.AbsoluteSize.X, btn.AbsoluteSize.Y) })
	end
	if #rows < 3 then return nil end
	table.sort(rows, function(a, b)
		if math.abs(a.s - b.s) > 3 then return a.s > b.s end
		return a.b > b.b
	end)
	if rows[1].b >= 1.5 or rows[1].s - rows[2].s >= 5 then return rows[1].btn end
	if rows[1].b - rows[2].b >= 0.25 then return rows[1].btn end
	return nil
end

function clickGui(btn)
	if not btn then return false end
	if btn:IsA("GuiButton") and pcall(function() btn:Activate() end) then return true end
	if firesignal and btn.MouseButton1Click then pcall(firesignal, btn.MouseButton1Click) end
	if VirtualInputManager then
		local ap, as = btn.AbsolutePosition, btn.AbsoluteSize
		local x, y = ap.X + as.X * 0.5, ap.Y + as.Y * 0.5
		local inset = GuiService:GetGuiInset()
		x += inset.X y += inset.Y
		pcall(function()
			VirtualInputManager:SendMouseButtonEvent(x, y, 0, true, game, 1)
			task.wait(0.03)
			VirtualInputManager:SendMouseButtonEvent(x, y, 0, false, game, 1)
		end)
	end
	return true
end

function solveMini()
	if STATE.solving or STATE.inMini then return end
	STATE.solving, STATE.inMini = true, true
	task.spawn(function()
		local pg = player:WaitForChild("PlayerGui", 5)
		while isActive() and FISH.ON do
			local gui = pg and pg:FindFirstChild("FishingMinigame")
			if not gui or not gui.Enabled then break end
			local btn = pickMiniBtn(gui)
			if btn then clickGui(btn) task.wait(0.2) else task.wait(0.08) end
		end
		STATE.solving, STATE.inMini = false, false
	end)
end

function hookListeners()
	if STATE.listeners then return end
	STATE.listeners = true
	local function listen(r)
		if r and r:IsA("RemoteEvent") and r.Name == "DataEvent" then
			pcall(function()
				r.OnClientEvent:Connect(function(_, val, path)
					if path == "Stats.Fish" and type(val) == "number" then STATE.fishCount = val end
				end)
			end)
		end
	end
	for _, d in ipairs(game:GetDescendants()) do listen(d) end
	game.DescendantAdded:Connect(listen)
	local pg = player:WaitForChild("PlayerGui", 10)
	if pg then
		local function hook(g)
			if g.Name ~= "FishingMinigame" then return end
			g:GetPropertyChangedSignal("Enabled"):Connect(function()
				if g.Enabled then solveMini() end
			end)
			if g.Enabled then solveMini() end
		end
		for _, g in ipairs(pg:GetChildren()) do hook(g) end
		pg.ChildAdded:Connect(hook)
	end
end

function deliverQuestFish()
	local fm = findNPC(FISH.FISHERMAN)
	if not fm then return false end
	for _, fishName in ipairs(FISH.TASK_FISH) do
		if objNeed(fishName) and findTool(fishName) then
			questExec(fm, "Deliver", fishName)
			task.wait(0.08)
		end
	end
	STATE.lastDeliver = os.clock()
	return true
end

function deliverPackage()
	for _, t in ipairs(receiverNPCs()) do
		if questDone() or not hasItem("Package") then break end
		equipItem("Package")
		local t0 = tick()
		while tick() - t0 < 0.35 and isActive() do
			tpFace(t.model, 4, 1)
			useTool(player.Character and player.Character:FindFirstChild("Package"))
			task.wait(0.1)
			if questDone() or not hasItem("Package") then break end
		end
	end
	return questDone()
end

function stepFavor()
	if qHist(FISH.Q_FAVOR) then return false end
	local q, fm = getQuests(), findNPC(FISH.FISHERMAN)
	if not q or not fm then return false end
	local active = q.Active

	if active == FISH.Q_FAVOR and q.Completed then
		questExec(fm, "Claim")
		task.wait(0.3) equipRod("Wood Rod") return true
	end
	if active == FISH.Q_FAVOR and hasItem("Package") then return deliverPackage() end
	if active == FISH.Q_FAVOR and not hasItem("Package") and not q.Completed then
		questExec(fm, "Accept", FISH.Q_FAVOR) return true
	end
	if active ~= FISH.Q_FAVOR then questExec(fm, "Accept", FISH.Q_FAVOR) return true end
	return false
end

function stepSuperQuest()
	local q, fm = getQuests(), findNPC(FISH.FISHERMAN)
	if not q or not fm then return false end
	local active = q.Active

	if active == FISH.Q_CHALLENGE then
		if q.Completed then questExec(fm, "Claim") equipRod("Super Rod") return true end
		return false
	end
	if active == FISH.Q_TASK then
		if q.Completed then questExec(fm, "Claim") equipRod("Sturdy Rod") return true end
		if os.clock() - STATE.lastDeliver >= 3 then deliverQuestFish() end
		return false
	end
	if qHist(FISH.Q_FAVOR) and not qHist(FISH.Q_TASK) and active ~= FISH.Q_FAVOR and active ~= FISH.Q_TASK then
		questExec(fm, "Accept", FISH.Q_TASK) return true
	end
	if qHist(FISH.Q_TASK) and not qHist(FISH.Q_CHALLENGE) and active ~= FISH.Q_CHALLENGE and active ~= FISH.Q_TASK then
		questExec(fm, "Accept", FISH.Q_CHALLENGE) return true
	end
	return false
end

function stashQuestFish()
	if not keepQuestFish() then return {} end
	local keep = workspace:FindFirstChild("SigmaFishKeep_" .. player.UserId)
	if not keep then
		keep = Instance.new("Folder")
		keep.Name = "SigmaFishKeep_" .. player.UserId
		keep.Parent = workspace
	end
	local out = {}
	for _, t in ipairs(scanFish()) do
		if keepFish(t.Name) then pcall(function() t.Parent = keep end) table.insert(out, t) end
	end
	return out
end

function restoreFish(stashed)
	local bp = player:FindFirstChild("Backpack")
	if not bp then return end
	for _, t in ipairs(stashed) do if t and t.Parent then pcall(function() t.Parent = bp end) end end
end

function cookAndSell(force)
	if not force then
		if not FISH.AUTO_SELL then return false end
		if countSellable() < FISH.SELL_AT then return false end
		if os.clock() - STATE.lastSell < 2 then return false end
	end
	if countSellable() < 1 and not force then return false end

	STATE.pause = true
	local stashed = stashQuestFish()
	local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if hum then pcall(function() hum:UnequipTools() end) end
	task.wait(0.1)

	local station = resolvePath(FISH.COOK_PATH)
	if station then
		tpNear(station)
		local cd = station:FindFirstChildOfClass("ClickDetector") or station:FindFirstChildWhichIsA("ClickDetector", true)
		if cd and fireclickdetector then for _ = 1, 3 do pcall(fireclickdetector, cd) task.wait(0.12) end end
	end
	task.wait(0.3)

	local cooker = findNPC(FISH.COOKER)
	if cooker then clickNPC(cooker) exec("SellFish", {}) end

	STATE.lastSell = os.clock()
	restoreFish(stashed)
	equipBestRod()
	STATE.pause = false
	return true
end

function castLoop()
	if STATE.loopRunning then return end
	STATE.loopRunning = true
	task.spawn(function()
		while isActive() and FISH.ON do
			if STATE.pause or STATE.inMini then
				task.wait(0.12)
			elseif not findRod() then
				task.wait(1)
			else
				local rod = equipBestRod()
				if rod and not lineOut() and not STATE.inMini then
					clickRod(rod)
					waitUntil(function() return lineOut() or STATE.inMini end, FISH.CAST_TIMEOUT)
				elseif lineOut() and not STATE.inMini then
					local before = STATE.fishCount or 0
					waitUntil(function() return onHook() or STATE.inMini or not lineOut() end, FISH.BITE_TIMEOUT)
					if onHook() and not STATE.inMini then
						clickRod(equipBestRod() or rod)
						waitUntil(function() return not lineOut() or STATE.inMini or (STATE.fishCount or 0) > before end, FISH.REEL_TIMEOUT)
					elseif lineOut() then
						clickRod(equipBestRod() or rod)
						waitUntil(function() return not lineOut() end, FISH.REEL_TIMEOUT)
					end
				end
				task.wait(FISH.LOOP_DELAY)
			end
		end
		STATE.loopRunning = false
	end)
end

function fishStep()
	if not FISH.ON then return end
	hookListeners()

	if not qHist(FISH.Q_FAVOR) and stepFavor() then castLoop() return end
	if not findRod() then equipRod("Wood Rod") end
	if not findRod() then castLoop() return end

	if superMode() then stepSuperQuest() end

	if not STATE.pause and not lineOut() and not STATE.inMini then
		cookAndSell(false)
	end

	castLoop()
end

function spawnOpen()
	local pg = player and player:FindFirstChild("PlayerGui")
	local load = pg and pg:FindFirstChild("Load")
	return load and load:IsA("ScreenGui") and load.Enabled
end

function ensureSpawn()
	if not spawnOpen() then return false end
	exec("Load", { "Load" })
	local load = player.PlayerGui:FindFirstChild("Load")
	pcall(function() if load then load.Enabled = false end end)
	task.wait(0.4)
	return true
end

function worldReady()
	if spawnOpen() then return false end
	if not player or not player:FindFirstChild("PlayerGui") then return false end
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not hum or hum.Health <= 0 or not getHRP() then return false end
	if not getData() then return false end
	return workspace:FindFirstChild("Alive") or workspace:FindFirstChild("MapFolder")
end

function syncCfg()
	local cfg = getgenv().SigmaFishConfig or {}
	FISH.ON = cfg.AutoFish == true
	FISH.SUPER = cfg.AutoSuperRod == true
	FISH.AUTO_SELL = cfg.AutoCookSell ~= false
	FISH.SELL_AT = tonumber(cfg.SellAt) or 40
	STATE.pause = not FISH.ON
end

function fishTick()
	syncCfg()
	if not FISH.ON or not isActive() then return end
	if ensureSpawn() then return end
	if spawnOpen() or not worldReady() then return end
	fishStep()
end

function startLoop()
	syncCfg()
	if getgenv().__SIGMA_FISH_RUNNING then return end
	RUN.id += 1
	local run = RUN.id
	getgenv().__SIGMA_FISH_RUNNING = true
	getgenv().__SIGMA_FISH_RUN_ID = run
	task.spawn(function()
		while getgenv().__SIGMA_FISH_RUNNING and getgenv().__SIGMA_FISH_RUN_ID == run do
			pcall(fishTick)
			task.wait(FISH.LOOP_DELAY)
		end
	end)
end

function stopLoop()
	getgenv().__SIGMA_FISH_RUNNING = false
	FISH.ON = false
	STATE.pause = true
	STATE.loopRunning = false
end

SigmaFish = {}

function SigmaFish.setAutoFish(on)
	getgenv().SigmaFishConfig = getgenv().SigmaFishConfig or {}
	getgenv().SigmaFishConfig.AutoFish = on == true
	syncCfg()
	if on then startLoop() else stopLoop() end
end

function SigmaFish.setAutoSuperRod(on)
	getgenv().SigmaFishConfig = getgenv().SigmaFishConfig or {}
	getgenv().SigmaFishConfig.AutoSuperRod = on == true
	if on then getgenv().SigmaFishConfig.AutoFish = true end
	syncCfg()
	startLoop()
end

function SigmaFish.setAutoCookSell(on)
	getgenv().SigmaFishConfig = getgenv().SigmaFishConfig or {}
	getgenv().SigmaFishConfig.AutoCookSell = on == true
	syncCfg()
end

function SigmaFish.setSellAt(n)
	getgenv().SigmaFishConfig = getgenv().SigmaFishConfig or {}
	getgenv().SigmaFishConfig.SellAt = tonumber(n)
	syncCfg()
end

function SigmaFish.cookSell()
	return cookAndSell(true)
end

function SigmaFish.getStatus()
	syncCfg()
	return {
		autoFish = FISH.ON,
		autoSuperRod = FISH.SUPER,
		autoCookSell = FISH.AUTO_SELL,
		sellAt = FISH.SELL_AT,
		fishCount = STATE.fishCount,
		inMinigame = STATE.inMini,
		superMode = superMode(),
		quest = getQuests() and getQuests().Active,
		sellable = countSellable(),
	}
end

function SigmaFish.isRunning()
	return getgenv().__SIGMA_FISH_RUNNING and FISH.ON
end

function SigmaFish.stop()
	stopLoop()
end

getgenv().SigmaFish = SigmaFish
return SigmaFish
