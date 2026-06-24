--[[ Main.lua — Sigma Hub fishing (stand still, cast in place) ]]

if type(getgenv) ~= "function" then getgenv = function() return _G end end
if type(task) ~= "table" then task = { wait = wait, spawn = function(f) coroutine.wrap(f)() end } end
if LPH_OBFUSCATED == nil then function LPH_NO_VIRTUALIZE(f) return f end end

CFG = getgenv().SigmaConfig or {}
getgenv().SigmaConfig = CFG

Players = game:GetService("Players")
ReplicatedFirst = game:GetService("ReplicatedFirst")
UserInputService = game:GetService("UserInputService")
GuiService = game:GetService("GuiService")
VirtualUser = game:GetService("VirtualUser")
VirtualInputManager = game:GetService("VirtualInputManager")
player = Players.LocalPlayer

UNC = {
	mobile = false,
	vim = VirtualInputManager ~= nil,
	fireSignal = type(firesignal) == "function",
	getConns = type(getconnections) == "function",
}
do
	local uis = UserInputService
	if uis.KeyboardEnabled and uis.MouseEnabled then
		UNC.mobile = false
	elseif uis.TouchEnabled and not uis.KeyboardEnabled and not uis.MouseEnabled then
		UNC.mobile = true
	elseif uis.PreferredInput == Enum.PreferredInput.Touch and not uis.MouseEnabled then
		UNC.mobile = true
	end
end

RUN = { id = 0 }
FISH = {
	ON = false, AUTO_SELL = true,
	SELL_AT = 40, LOOP_DELAY = 0.25,
	CAST_TIMEOUT = 4, BITE_TIMEOUT = 30, REEL_TIMEOUT = 4,
	MINI_CLICK = 0.38, MINI_SHUFFLE = 0.3, MINI_READY = 0.55, MINI_POLL = 0.12,
	MINI_DEBOUNCE = 0.4,
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
if UNC.mobile then
	FISH.MINI_CLICK = 0.45
	FISH.MINI_SHUFFLE = 0.36
	FISH.MINI_POLL = 0.14
	FISH.MINI_READY = 0.65
	FISH.MINI_DEBOUNCE = 0.5
end
STATE = {
	pause = false, loopRunning = false, inMini = false, solving = false,
	fishCount = nil, listeners = false, lastSell = 0, lastDeliver = 0,
	lastSolveAt = 0, miniTotal = nil, cooking = false, reachIdx = 0,
}

QUEST = {
	AUTO = false,
	EXPERTISE = false,
	PICK = {},
	RIDX = 1,
	DB = {
		["Joe"] = { quest = "Crab Hunter", kind = "mob", mobs = { "crab" } },
		["Chill Billy"] = { quest = "Make'em Chill", kind = "mob", mobs = { "freddy", "bob" } },
		["Bandits Leader"] = { quest = "No Good Time for Traitors", kind = "mob", mobs = { "bandit traitor" } },
		["Demon Hunter"] = { quest = "Demon Hunter #1", kind = "mob", mobs = { "cave demon [weakened]" } },
		["Guard Captain"] = { quest = "Thief Beater", kind = "mob", mobs = { "thief" } },
		["Fallen Captain"] = { quest = "Fallen Captain's Savior", kind = "mob", mobs = { "bandit" } },
		["Marge Nospmis"] = { quest = "Rescuing the Brat", kind = "talk", talkNPC = "Bart Nospmis", deliver = "Talk to Bart" },
		["Old Beggar"] = {
			quest = "Humble Man #1", kind = "collect",
			collectFolders = { "MapFolder.Fruits", "Barrels.Barrels", "Barrels.Crates" },
			deliverItems = { "Apple", "Banana", "Cantaloupe", "Coconut", "Green Apple", "Melon", "Pumpkin", "Golden Apple" },
		},
		["Mad Scientist"] = { quest = "Race Experiments", kind = "deliver", deliverItems = { "Whitebeard Essence" } },
		["Explorer"] = { quest = "Adventures", kind = "reachAll", folder = "Ignore.NPCs.Islands", noClaim = true },
		["Traceur"] = { quest = "Bridge Challenge", kind = "reach", pos = { -289, 303, -609 } },
		["Sam"] = { quest = "Help Sam", kind = "sam", mobs = { "thug" } },
		["Fisherman"] = { quest = "Fisherman's Favor", kind = "carry", carryItem = "Package" },
		["Gemologist"] = { quest = "Gem Hunter", kind = "reach", target = "Chests.Gemologist" },
	},
	COLLECT_BLOCK = { "grapple", "package", "melee", "essence", "compass" },
	COLLECT_WAIT = 0.03,
	COLLECT_BATCH = 8,
	COLLECT_TP_UP = 2,
	CARRY_SWEEP_WAIT = 0.35,
	ATTACK_RANGE = 5,
	ATTACK_CD = 0.15,
	ATTACK_BURST = 3.5,
	TARGET_SCAN = 800,
}

COMBAT = {
	ORDER = { "Sword", "Melee" },
	CAT_ALIASES = {
		Sword = { "Sword", "Swords" },
		Melee = { "Melee" },
		Sniper = { "Sniper", "Snipers" },
		Utility = { "Utility" },
	},
	PRIORITY = {
		Sword = { "Dagger", "Wakizashi", "Tachi", "Katana", "Crocodile's Hook", "Crocodiles Hook", "Kogatana", "Yoru", "Bisento" },
		Melee = { "Melee", "Black Leg", "Seastone Cestus", "Table Kick", "Krizma" },
		Sniper = { "Slingshot", "Crossbow", "Flintlock", "Stars" },
	},
	CATEGORY = {},
	RANK = {},
}
do
	for cat, list in pairs(COMBAT.PRIORITY) do
		for i, name in ipairs(list) do
			COMBAT.CATEGORY[name] = cat
			COMBAT.RANK[string.lower(name)] = { rank = i, category = cat }
		end
	end
end

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

function remoteNPC(model)
	if not model then return false end
	setMerchant(model)
	return true
end

function clickNPC(model)
	if not remoteNPC(model) then return end
	local part = model:FindFirstChild("HumanoidRootPart") or model:FindFirstChildWhichIsA("BasePart", true)
	if not part then return end
	local cd = part:FindFirstChildOfClass("ClickDetector") or part:FindFirstChildWhichIsA("ClickDetector", true)
	if cd and fireclickdetector then pcall(fireclickdetector, cd) end
	task.wait(0.05)
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

function rodUnlocked(rodName)
	local cat = getWeaponsCat(FISH.ROD_CAT)
	return cat and cat[rodName] == true
end

function rodEquippedName(rodName)
	return getEquippedName(FISH.ROD_CAT) == rodName
end

function bestRodName()
	for _, rodName in ipairs(FISH.RODS) do
		if rodUnlocked(rodName) or rodEquippedName(rodName) or findTool(rodName) then
			return rodName
		end
	end
	return select(2, findRod())
end

function ensureRodLoadout(rodName)
	if not rodName then return false end
	local hasTool = findTool(rodName) ~= nil
	local unlocked = rodUnlocked(rodName) or rodEquippedName(rodName)
	if not hasTool and not unlocked then return false end
	local _, curName = findRod()
	if curName == rodName and hasTool then return true end
	if unlocked or hasTool then
		exec("Equip", { rodName, equipCatKey(FISH.ROD_CAT) })
		task.wait(0.35)
	end
	return findTool(rodName) ~= nil
end

function ensureBestRodLoadout()
	local best = bestRodName()
	if best and ensureRodLoadout(best) then return true end
	for _, rodName in ipairs(FISH.RODS) do
		if rodUnlocked(rodName) or findTool(rodName) then
			if ensureRodLoadout(rodName) then return true end
		end
	end
	return findRod() ~= nil
end

function equipRod(name)
	if name then ensureRodLoadout(name) end
	return equipBestRod()
end

function ensureRodReady()
	local rod = findRod()
	local want = bestRodName()
	if want and (not rod or select(2, findRod()) ~= want) then
		ensureRodLoadout(want)
		rod = findRod()
	end
	if not rod then
		ensureBestRodLoadout()
		rod = findRod()
	end
	if not rod then return nil end
	if rodHeld(rod) then return rod end
	return equipBestRod()
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

function questActive(name)
	local q = getQuests()
	return q and q.Active == name
end

function rodQuestActive()
	return not qHist(FISH.Q_CHALLENGE)
end

function rodTaskPhase()
	return qHist(FISH.Q_FAVOR) and not qHist(FISH.Q_TASK)
end

function fishAllowed()
	if not FISH.ON then return false end
	if not qHist(FISH.Q_FAVOR) then return false end
	return true
end

function keepForQuest(name)
	if not FISH.ON or not rodTaskPhase() then return false end
	if not name then return false end
	if objNeed(name) then return true end
	local low = string.lower(name)
	return string.find(low, "medium", 1, true) or string.find(low, "large", 1, true)
end

function countSellable()
	local n = 0
	for _, t in ipairs(scanFish()) do
		if not keepForQuest(t.Name) then
			n += 1
		end
	end
	return n
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

function hasItem(name)
	for _, where in ipairs({ player.Character, player:FindFirstChild("Backpack") }) do
		if where and where:FindFirstChild(name) then return true end
	end
	return false
end

function normMob(s)
	s = string.lower(tostring(s or ""))
	s = string.gsub(s, "[^%w%s]", " ")
	s = string.gsub(s, "%s+", " ")
	return s
end

function findToolByName(name)
	local want = string.lower(name)
	for _, where in ipairs({ player.Character, player:FindFirstChild("Backpack") }) do
		if where then
			for _, t in ipairs(where:GetChildren()) do
				if t:IsA("Tool") and string.lower(t.Name) == want then return t end
			end
		end
	end
end

function getWeaponsCat(category)
	local d = getData()
	if not d or not d.Weapons then return nil, nil end
	local aliases = COMBAT.CAT_ALIASES[category] or { category }
	for _, key in ipairs(aliases) do
		if type(d.Weapons[key]) == "table" then return d.Weapons[key], key end
	end
	for key, tbl in pairs(d.Weapons) do
		if type(tbl) == "table" and string.lower(tostring(key)) == string.lower(tostring(category)) then
			return tbl, key
		end
	end
	return nil, nil
end

function getEquippedName(category)
	local d = getData()
	if not d or not d.Equipped then return nil end
	local aliases = COMBAT.CAT_ALIASES[category] or { category }
	for _, key in ipairs(aliases) do
		local v = d.Equipped[key]
		if type(v) == "string" and v ~= "" then return v end
	end
	for key, v in pairs(d.Equipped) do
		if type(v) == "string" and v ~= "" and string.lower(tostring(key)) == string.lower(tostring(category)) then
			return v
		end
	end
	return nil
end

function weaponCategoryFor(name, category)
	if category then return category end
	return COMBAT.CATEGORY[name]
end

function equipCatKey(category)
	local _, key = getWeaponsCat(category)
	return key or category
end

function weaponUnlocked(name, category)
	category = weaponCategoryFor(name, category)
	if not category then return false end
	local cat = getWeaponsCat(category)
	return cat and cat[name] == true
end

function weaponEquipped(name, category)
	category = weaponCategoryFor(name, category)
	if not category then return false end
	return getEquippedName(category) == name
end

function hasWeapon(name, category)
	category = weaponCategoryFor(name, category)
	if findToolByName(name) then return true end
	if category and weaponUnlocked(name, category) then return true end
	if category and weaponEquipped(name, category) then return true end
	return false
end

function ensureWeaponLoadout(name, category)
	category = weaponCategoryFor(name, category)
	if not name or not category then return false end
	if findToolByName(name) then return true end
	if not weaponUnlocked(name, category) and not weaponEquipped(name, category) then return false end
	exec("Equip", { name, equipCatKey(category) })
	task.wait(0.35)
	return findToolByName(name) ~= nil
end

function bestWeaponInCategory(category)
	local list = COMBAT.PRIORITY[category]
	if list then
		for i = #list, 1, -1 do
			local n = list[i]
			if hasWeapon(n, category) then return n, category end
		end
	end
	local cat = getWeaponsCat(category)
	if type(cat) ~= "table" then return nil, nil end
	local bestName, bestRank = nil, 0
	for n, ok in pairs(cat) do
		if ok then
			local info = COMBAT.RANK[string.lower(n)]
			local r = info and info.rank or 1
			if r >= bestRank then bestName, bestRank = n, r end
		end
	end
	if bestName then return bestName, category end
	return nil, nil
end

function bestCombatWeapon()
	for _, cat in ipairs(COMBAT.ORDER) do
		local n, c = bestWeaponInCategory(cat)
		if n then return n, c end
	end
	return nil, nil
end

function ensureBestCombatLoadout()
	local want, cat = bestCombatWeapon()
	if want and ensureWeaponLoadout(want, cat) then return true end
	for _, c in ipairs(COMBAT.ORDER) do
		local n = select(1, bestWeaponInCategory(c))
		if n and ensureWeaponLoadout(n, c) then return true end
	end
	return findToolByName(select(1, bestCombatWeapon())) ~= nil
end

function combatToolHeld(tool)
	return tool and player.Character and tool.Parent == player.Character
end

function equipCombatTool(name, category)
	if not name then return nil end
	category = weaponCategoryFor(name, category)
	ensureWeaponLoadout(name, category)
	local tool = findToolByName(name)
	if not tool then return nil end
	if combatToolHeld(tool) then return tool end
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not hum then return nil end
	for _, t in ipairs(char:GetChildren()) do
		if t:IsA("Tool") and t ~= tool then
			pcall(function() hum:UnequipTools() end)
			task.wait(0.06)
			break
		end
	end
	pcall(function() hum:EquipTool(tool) end)
	local t0 = os.clock()
	while isActive() and not combatToolHeld(tool) and os.clock() - t0 < 1.5 do
		task.wait(0.05)
	end
	if not combatToolHeld(tool) then
		pcall(function() tool.Parent = char end)
		task.wait(0.1)
		pcall(function() hum:EquipTool(tool) end)
		task.wait(0.08)
	end
	return combatToolHeld(tool) and tool or nil
end

function ensureCombatReady()
	local want, cat = bestCombatWeapon()
	if want then
		local tool = findToolByName(want)
		if not tool or getEquippedName(cat) ~= want then
			ensureWeaponLoadout(want, cat)
		end
	end
	if not findToolByName(want) then ensureBestCombatLoadout() end
	want, cat = bestCombatWeapon()
	if not want then
		local char = player.Character
		if char then
			for _, t in ipairs(char:GetChildren()) do
				if isCombatTool(t) then return t end
			end
		end
		local bp = player:FindFirstChild("Backpack")
		if bp then
			for _, t in ipairs(bp:GetChildren()) do
				if isCombatTool(t) then return equipCombatTool(t.Name, weaponCategoryFor(t.Name)) end
			end
		end
		return nil
	end
	return equipCombatTool(want, cat)
end

function isCombatTool(tool)
	if not tool or not tool:IsA("Tool") then return false end
	local low = string.lower(tool.Name)
	if string.find(low, "rod", 1, true) then return false end
	for _, b in ipairs(QUEST.COLLECT_BLOCK) do
		if string.find(low, b, 1, true) then return false end
	end
	for _, fish in ipairs(FISH.TASK_FISH) do
		if string.lower(fish) == low then return false end
	end
	for _, info in pairs(QUEST.DB) do
		if type(info.deliverItems) == "table" then
			for _, it in ipairs(info.deliverItems) do
				if string.lower(it) == low then return false end
			end
		end
		if info.carryItem and string.lower(info.carryItem) == low then return false end
	end
	return true
end

function equipCombat()
	return ensureCombatReady()
end

function getAliveRoot()
	return workspace:FindFirstChild("Alive")
		or (workspace:FindFirstChild("Terrain") and workspace.Terrain:FindFirstChild("Alive"))
		or workspace
end

function getAliveEnemies()
	local root = getAliveRoot()
	local skip = {}
	for npc in pairs(QUEST.DB) do skip[normMob(npc)] = true end
	for _, p in ipairs(Players:GetPlayers()) do
		skip[normMob(p.Name)] = true
		skip[normMob(p.DisplayName)] = true
	end
	local out, seen = {}, {}
	for _, m in root:GetDescendants() do
		if m:IsA("Model") and not seen[m] and m ~= player.Character then
			seen[m] = true
			local hum = m:FindFirstChildOfClass("Humanoid")
			local hrp = m:FindFirstChild("HumanoidRootPart") or m:FindFirstChildWhichIsA("BasePart", true)
			if hum and hrp and hum.Health > 0 then
				local n = normMob(m.Name)
				if not m:GetAttribute("DialogueModule") and not skip[n] then
					out[#out + 1] = m
				end
			end
		end
	end
	return out
end

function getMobGroups(info)
	local groups = {}
	if info and type(info.mobs) == "table" then
		for _, phrase in ipairs(info.mobs) do
			local words = {}
			for word in string.gmatch(normMob(phrase), "%w+") do words[#words + 1] = word end
			if #words > 0 then groups[#groups + 1] = words end
		end
	end
	return groups
end

function mobMatches(name, words)
	for _, w in ipairs(words) do
		if not string.find(name, w, 1, true) then return false end
	end
	return true
end

function isQuestMob(mob, groups)
	local n = normMob(mob.Name)
	for _, words in ipairs(groups) do
		if mobMatches(n, words) then return true end
	end
	return false
end

function nearestQuestMob(groups)
	local hrp = getHRP()
	if not hrp then return nil end
	local best, bestD = nil, nil
	for _, mob in ipairs(getAliveEnemies()) do
		if isQuestMob(mob, groups) then
			local pos = getPos(mob)
			if pos then
				local d = (hrp.Position - pos).Magnitude
				if d <= QUEST.TARGET_SCAN and (not bestD or d < bestD) then
					best, bestD = mob, d
				end
			end
		end
	end
	return best
end

function tpNearMob(mob)
	local hrp = getHRP()
	local mobRoot = mob and (mob:FindFirstChild("HumanoidRootPart") or mob:FindFirstChildWhichIsA("BasePart", true))
	if not hrp or not mobRoot then return false end
	local pos = mobRoot.Position
	local dir = hrp.Position - pos
	if dir.Magnitude < 0.5 then dir = Vector3.new(0, 0, 1) else dir = dir.Unit end
	local stand = pos + dir * QUEST.ATTACK_RANGE + Vector3.new(0, 2, 0)
	pcall(function() hrp.CFrame = CFrame.new(stand, Vector3.new(pos.X, stand.Y, pos.Z)) end)
	return true
end

function m1Attack()
	if VirtualUser then
		local cam = workspace.CurrentCamera
		if cam then
			pcall(function()
				VirtualUser:Button1Down(Vector2.new(0, 0), cam.CFrame)
				task.wait(0.03)
				VirtualUser:Button1Up(Vector2.new(0, 0), cam.CFrame)
			end)
			return
		end
	end
	local tool = player.Character and player.Character:FindFirstChildOfClass("Tool")
	if tool and isCombatTool(tool) then pcall(function() tool:Activate() end) end
end

function attackBurstOnMob(mob)
	local hum = mob and mob:FindFirstChildOfClass("Humanoid")
	if not hum or hum.Health <= 0 then return true end
	ensureCombatReady()
	tpNearMob(mob)
	local t0, lastHp, stall = tick(), hum.Health, 0
	while isActive() and tick() - t0 < QUEST.ATTACK_BURST do
		hum = mob:FindFirstChildOfClass("Humanoid")
		if not hum or hum.Health <= 0 then return true end
		tpNearMob(mob)
		ensureCombatReady()
		m1Attack()
		task.wait(QUEST.ATTACK_CD)
		if hum.Health <= 0 then return true end
		if hum.Health >= lastHp then
			stall += QUEST.ATTACK_CD
			if stall >= 2 then tpNearMob(mob) stall = 0 end
		else
			lastHp, stall = hum.Health, 0
		end
	end
	hum = mob:FindFirstChildOfClass("Humanoid")
	return not hum or hum.Health <= 0
end

function stepFarmQuest(npc, info)
	local groups = getMobGroups(info)
	if #groups < 1 then return false end
	ensureCombatReady()
	local mob = nearestQuestMob(groups)
	if not mob then return false end
	return attackBurstOnMob(mob)
end

function questInfoNeedsKill(info)
	if not info then return false end
	local kind = info.kind
	if kind == "mob" or kind == "sam" then
		return type(info.mobs) == "table" and #info.mobs > 0
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
	ensureBestRodLoadout()
	local bestName = bestRodName()
	local rod = (bestName and findTool(bestName)) or select(1, findRod())
	if not rod then return nil end
	if rodHeld(rod) then return rod end
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not hum then return nil end
	for _, t in ipairs(char:GetChildren()) do
		if t:IsA("Tool") and t ~= rod then
			pcall(function() hum:UnequipTools() end)
			task.wait(0.06)
			break
		end
	end
	pcall(function() hum:EquipTool(rod) end)
	local t0 = os.clock()
	while isActive() and FISH.ON and not rodHeld(rod) and os.clock() - t0 < 1.5 do
		task.wait(0.05)
	end
	if not rodHeld(rod) then
		pcall(function() rod.Parent = char end)
		task.wait(0.1)
		pcall(function() hum:EquipTool(rod) end)
		task.wait(0.08)
	end
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

function btnBgSum(btn)
	if not btn or not btn:IsA("GuiObject") then return 0 end
	if (btn.BackgroundTransparency or 0) > 0.5 then return 0 end
	local c = btn.BackgroundColor3
	return c.R + c.G + c.B
end

function surfaceBright(btn)
	if not btn then return 0 end
	local best = 0
	local function scan(inst, depth)
		if depth > 5 or not inst then return end
		if inst:IsA("GuiObject") and inst.BackgroundTransparency < 0.88 then
			local c = inst.BackgroundColor3
			best = math.max(best, c.R + c.G + c.B)
		end
		if inst:IsA("ImageLabel") or inst:IsA("ImageButton") then
			if inst.ImageTransparency < 0.88 then
				local c = inst.ImageColor3
				best = math.max(best, c.R + c.G + c.B)
			end
		end
		for _, ch in ipairs(inst:GetChildren()) do scan(ch, depth + 1) end
	end
	scan(btn, 0)
	return best
end

function miniGameButtons(gui)
	local bestRow, bestCount = nil, 0
	for _, d in ipairs(gui:GetDescendants()) do
		if d:IsA("Frame") then
			local btns = {}
			for _, ch in ipairs(d:GetChildren()) do
				if ch:IsA("TextButton") and ch:FindFirstChild("TextLabel") then
					table.insert(btns, ch)
				end
			end
			if #btns > bestCount then bestRow, bestCount = btns, #btns end
		end
	end
	if bestRow and bestCount >= 3 then return bestRow end
	local all = {}
	for _, d in ipairs(gui:GetDescendants()) do
		if d:IsA("TextButton") and d:FindFirstChild("TextLabel") then table.insert(all, d) end
	end
	return all
end

function readMiniCount(gui)
	local bestA, bestB
	for _, d in ipairs(gui:GetDescendants()) do
		if d:IsA("TextLabel") then
			local a, b = string.match(d.Text or "", "^%s*(%d+)%s*/%s*(%d+)%s*$")
			if a and b then
				a, b = tonumber(a), tonumber(b)
				if not bestA or a > bestA then bestA, bestB = a, b end
			end
		end
	end
	return bestA, bestB
end

function isHighlightBtn(btn)
	if not btn or not btn:IsA("GuiButton") or not btn.Visible then return false end
	local as = btn.AbsoluteSize
	if as.X <= 2 or as.Y <= 2 then return false end
	if math.min(as.X, as.Y) < 52 then return false end
	local bg = btnBgSum(btn)
	if bg >= 1.55 then return true end
	local lum = surfaceBright(btn)
	if lum >= 2.0 and bg >= 0.5 then return true end
	if lum >= 1.45 and bg >= 1.0 then return true end
	local stroke = btn:FindFirstChildOfClass("UIStroke")
	if stroke and stroke.Thickness >= 1.8 then
		local sc = stroke.Color.R + stroke.Color.G + stroke.Color.B
		if sc >= 2.0 and bg >= 0.8 then return true end
	end
	return false
end

function pickHighlightBtn(gui)
	local rows = {}
	for _, btn in ipairs(miniGameButtons(gui)) do
		if btn.Visible then
			local as = btn.AbsoluteSize
			local sz = math.min(as.X, as.Y)
			if sz > 40 then
				local stroke = btn:FindFirstChildOfClass("UIStroke")
				table.insert(rows, {
					btn = btn, size = sz, bg = btnBgSum(btn),
					stroke = stroke and stroke.Thickness or 0,
				})
			end
		end
	end
	if #rows < 3 then return nil, -999 end
	table.sort(rows, function(a, b)
		if math.abs(a.size - b.size) > 2 then return a.size > b.size end
		return a.bg > b.bg
	end)
	local top, second = rows[1], rows[2]
	if top.size - second.size >= 5 then return top.btn, 10 end
	table.sort(rows, function(a, b) return a.bg > b.bg end)
	top, second = rows[1], rows[2]
	local delta = top.bg - second.bg
	if top.bg >= 2.5 and delta >= 0.25 then return top.btn, 10 end
	if top.bg >= 1.55 and delta >= 0.3 then return top.btn, 9 end
	if top.stroke >= 1.8 and top.bg > second.bg + 0.2 then return top.btn, 8 end
	return nil, -999
end

function relativeHighlightBtn(gui)
	local rows = {}
	for _, btn in ipairs(miniGameButtons(gui)) do
		if btn.Visible then
			local as = btn.AbsoluteSize
			if as.X > 2 and as.Y > 2 then
				local lum = surfaceBright(btn)
				local bg = btn.BackgroundColor3
				table.insert(rows, {
					btn = btn, lum = lum,
					bgSum = bg.R + bg.G + bg.B,
					bt = btn.BackgroundTransparency or 0,
				})
			end
		end
	end
	if #rows < 3 then return nil, -999 end
	table.sort(rows, function(a, b) return a.lum > b.lum end)
	local top, second = rows[1], rows[2]
	local delta = top.lum - second.lum
	if top.lum >= 2.5 and delta >= 0.3 then return top.btn, 10 end
	if top.bgSum >= 2.4 and top.bt <= 0.2 and delta >= 0.25 then return top.btn, 10 end
	if top.lum >= 1.5 and delta >= 0.4 then return top.btn, 8 end
	if isHighlightBtn(top.btn) and delta >= 0.2 then return top.btn, 9 end
	return nil, -999
end

function mobileHighlightBtn(gui)
	local btns = miniGameButtons(gui)
	local rows = {}
	for _, btn in ipairs(btns) do
		if isHighlightBtn(btn) then
			local as = btn.AbsoluteSize
			table.insert(rows, { btn = btn, size = math.min(as.X, as.Y), lum = surfaceBright(btn) })
		end
	end
	if #rows == 0 then
		for _, btn in ipairs(btns) do
			local lum = surfaceBright(btn)
			local as = btn.AbsoluteSize
			table.insert(rows, { btn = btn, size = math.min(as.X, as.Y), lum = lum })
		end
		table.sort(rows, function(a, b)
			if a.lum ~= b.lum then return a.lum > b.lum end
			return a.size > b.size
		end)
		local top, second = rows[1], rows[2]
		if top and top.lum >= 2.1 and (not second or top.lum - second.lum >= 0.35) then
			return top.btn, 10
		end
		return nil, -999
	end
	if #rows > 1 then
		table.sort(rows, function(a, b)
			if a.lum ~= b.lum then return a.lum > b.lum end
			return a.size > b.size
		end)
		if rows[1].size - rows[2].size < 3 and rows[1].lum - rows[2].lum < 0.3 then
			return nil, -999
		end
	end
	return rows[1].btn, 10
end

function pickMiniBtn(gui)
	local btn, score = pickHighlightBtn(gui)
	if btn then return btn, score end
	btn, score = relativeHighlightBtn(gui)
	if btn then return btn, score end
	btn, score = mobileHighlightBtn(gui)
	if btn then return btn, score end
	return nil, -999
end

function tapGui(btn)
	if not btn then return false end
	local ap, as = btn.AbsolutePosition, btn.AbsoluteSize
	if as.X <= 2 or as.Y <= 2 then return false end
	local x, y = ap.X + as.X * 0.5, ap.Y + as.Y * 0.5
	if not UNC.mobile then
		local inset = GuiService:GetGuiInset()
		x += inset.X y += inset.Y
	end
	if UNC.vim then
		local ok = pcall(function()
			VirtualInputManager:SendMouseButtonEvent(x, y, 0, true, game, 1)
			task.wait(0.03)
			VirtualInputManager:SendMouseButtonEvent(x, y, 0, false, game, 1)
		end)
		if ok then return true end
	end
	if btn:IsA("GuiButton") and pcall(function() btn:Activate() end) then return true end
	return false
end

function clickGui(btn)
	if not btn then return false end
	if btn:IsA("GuiButton") and pcall(function() btn:Activate() end) then return true end
	if UNC.fireSignal then
		if pcall(firesignal, btn.MouseButton1Click) then return true end
		if btn:IsA("GuiButton") and pcall(firesignal, btn.Activated) then return true end
	end
	if UNC.getConns then
		local ok, fired = pcall(function()
			local n = 0
			for _, sig in ipairs({ btn.MouseButton1Click, btn.Activated }) do
				if sig then
					for _, c in ipairs(getconnections(sig)) do
						if c.Fire then c:Fire() n += 1
						elseif c.Function then c.Function() n += 1 end
					end
				end
			end
			return n > 0
		end)
		if ok and fired then return true end
	end
	return tapGui(btn)
end

function onMiniEvent(msg)
	if msg == "FishingMinigame" then
		solveMini()
	elseif msg == "FishingReeled" then
		STATE.inMini = false
		STATE.solving = false
		STATE.miniTotal = nil
	end
end

function solveMini()
	local now = os.clock()
	local debounce = FISH.MINI_DEBOUNCE or (UNC.mobile and 0.5 or 0.4)
	if STATE.solving or (now - STATE.lastSolveAt) < debounce then return end
	STATE.lastSolveAt = now
	STATE.solving = true
	STATE.inMini = true

	local clickIv = FISH.MINI_CLICK
	local shuffleWait = FISH.MINI_SHUFFLE
	local pollIv = FISH.MINI_POLL

	task.spawn(function()
		local pg = player:FindFirstChild("PlayerGui") or player:WaitForChild("PlayerGui", 5)
		local lastRemain, lastClickAt, lastShuffleAt = nil, 0, 0
		local sawEnabled, sawCounter = false, false

		while isActive() and fishAllowed() do
			local gui = pg and pg:FindFirstChild("FishingMinigame")
			if not gui or not gui.Enabled then
				if sawEnabled then break end
				task.wait(0.05)
			else
				local now2 = os.clock()
				if not sawEnabled then
					sawEnabled = true
					lastShuffleAt = now2
					local readyBy = now2 + FISH.MINI_READY
					while isActive() and FISH.ON and gui.Enabled and os.clock() < readyBy do
						local r = readMiniCount(gui)
						if r and r > 0 then sawCounter = true break end
						task.wait(0.08)
					end
					lastShuffleAt = os.clock()
				end

				local remain, total = readMiniCount(gui)
				if total then STATE.miniTotal = total end
				if remain and remain > 0 then sawCounter = true end

				if remain == 0 then
					if not sawCounter then
						task.wait(0.08)
					else
						break
					end
				else
					local btn, score = pickMiniBtn(gui)
					local settled = (now2 - lastShuffleAt) >= shuffleWait
					local canClick = (now2 - lastClickAt) >= clickIv
					if btn and score >= 8 and settled and canClick then
						if clickGui(btn) then
							lastClickAt = now2
							lastShuffleAt = now2
							task.wait(shuffleWait + 0.08)
						end
					end
					if remain then lastRemain = remain end
					task.wait(pollIv)
				end
			end
		end

		STATE.inMini = false
		STATE.solving = false
		STATE.miniTotal = nil
	end)
end

function hookListeners()
	if STATE.listeners then return end
	STATE.listeners = true

	local function listen(r)
		if not r then return end
		local ok, isEv = pcall(function() return r:IsA("RemoteEvent") end)
		if not ok or not isEv then
			ok, isEv = pcall(function() return r:IsA("UnreliableRemoteEvent") end)
		end
		if not ok or not isEv then return end
		if r.Name == "FishingEvent" then
			pcall(function()
				r.OnClientEvent:Connect(function(m) pcall(onMiniEvent, m) end)
			end)
		elseif r.Name == "DataEvent" then
			pcall(function()
				r.OnClientEvent:Connect(function(_, val, path)
					if path == "Stats.Fish" and type(val) == "number" then STATE.fishCount = val end
				end)
			end)
		end
	end

	for _, d in ipairs(game:GetDescendants()) do listen(d) end
	game.DescendantAdded:Connect(listen)

	task.spawn(function()
		local pg = player:WaitForChild("PlayerGui", 10)
		if not pg then return end
		local function hook(gui)
			if gui.Name ~= "FishingMinigame" then return end
			pcall(function()
				gui:GetPropertyChangedSignal("Enabled"):Connect(function()
					if gui.Enabled then solveMini() end
				end)
			end)
			if gui.Enabled then solveMini() end
		end
		for _, g in ipairs(pg:GetChildren()) do hook(g) end
		pg.ChildAdded:Connect(hook)
	end)
end

function miniOpen()
	local pg = player:FindFirstChild("PlayerGui")
	local g = pg and pg:FindFirstChild("FishingMinigame")
	return g and g.Enabled
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

function normQuest(s)
	return string.lower(string.gsub(tostring(s or ""), "[^%w%s]", ""))
end

function activeObjectiveTokens()
	local tokens, seen = {}, {}
	local q = getQuests()
	if q and type(q.Objectives) == "table" then
		for name in pairs(q.Objectives) do
			for word in string.gmatch(normQuest(name), "%w+") do
				if #word >= 3 and not seen[word] then
					seen[word] = true
					tokens[#tokens + 1] = word
				end
			end
		end
	end
	return tokens
end

function findPackageReceiver()
	local skip = {
		deliver = true, package = true, quest = true, fisherman = true,
		favor = true, friend = true, give = true, the = true, ["and"] = true,
	}
	local tokens = activeObjectiveTokens()
	local root = workspace:FindFirstChild("Ignore")
	root = root and root:FindFirstChild("NPCs")
	if not root then return nil end
	for _, m in root:GetDescendants() do
		if m:IsA("Model") and m.Name ~= FISH.FISHERMAN then
			local n = normQuest(m.Name)
			for _, tk in ipairs(tokens) do
				if not skip[tk] and string.find(n, tk, 1, true) then
					return m
				end
			end
		end
	end
	return nil
end

function packageReceiverList()
	local targets = receiverNPCs()
	local recv = findPackageReceiver()
	if not recv then return targets end
	local out = { { model = recv, name = recv.Name, d = 0 } }
	for _, t in ipairs(targets) do
		if t.model ~= recv then out[#out + 1] = t end
	end
	return out
end

function deliverPackage()
	if not hasItem("Package") then return false end
	if os.clock() - (STATE.lastDeliver or 0) < 0.5 then return false end
	STATE.lastDeliver = os.clock()
	equipItem("Package")
	for _, t in ipairs(packageReceiverList()) do
		if questDone() or not hasItem("Package") then break end
		local t0 = tick()
		while tick() - t0 < QUEST.CARRY_SWEEP_WAIT and isActive() do
			tpFace(t.model, 4, 1)
			useTool(player.Character and player.Character:FindFirstChild("Package"))
			task.wait(0.1)
			if questDone() or not hasItem("Package") then break end
		end
		if questDone() or not hasItem("Package") then return true end
	end
	return questDone()
end

function runFavorQuest()
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

function runTaskQuest()
	if qHist(FISH.Q_TASK) then return false end
	local q, fm = getQuests(), findNPC(FISH.FISHERMAN)
	if not q or not fm then return false end
	if q.Active == FISH.Q_TASK then
		if q.Completed then questExec(fm, "Claim") equipRod("Sturdy Rod") return true end
		if os.clock() - STATE.lastDeliver >= 3 then deliverQuestFish() end
		return false
	end
	questExec(fm, "Accept", FISH.Q_TASK)
	return true
end

function runChallengeQuest()
	if qHist(FISH.Q_CHALLENGE) then return false end
	local q, fm = getQuests(), findNPC(FISH.FISHERMAN)
	if not q or not fm then return false end
	if not qHist(FISH.Q_TASK) then return false end
	if q.Active == FISH.Q_CHALLENGE then
		if q.Completed then questExec(fm, "Claim") equipRod("Super Rod") return true end
		return false
	end
	questExec(fm, "Accept", FISH.Q_CHALLENGE)
	return true
end

function runRodQuestChain()
	if qHist(FISH.Q_CHALLENGE) then return false end
	if not qHist(FISH.Q_FAVOR) then return runFavorQuest() end
	if not qHist(FISH.Q_TASK) then return runTaskQuest() end
	return runChallengeQuest()
end

function questListAll()
	local out = {}
	for npc in pairs(QUEST.DB) do
		out[#out + 1] = npc
	end
	table.sort(out)
	return out
end

function normalizeQuestPick(raw)
	local out, seen = {}, {}
	if type(raw) == "string" and raw ~= "" then
		raw = { raw }
	end
	if type(raw) ~= "table" then return out end
	for _, v in ipairs(raw) do
		local name = type(v) == "table" and (v.Title or v[1]) or v
		name = tostring(name or "")
		if name ~= "" and QUEST.DB[name] and not seen[name] then
			seen[name] = true
			out[#out + 1] = name
		end
	end
	return out
end

function activeQuestInList(q, list)
	for _, npc in ipairs(list or {}) do
		local info = QUEST.DB[npc]
		if info and q.Active == info.quest then
			return npc, info
		end
	end
	return nil, nil
end

function tryAcceptQuestList(list)
	local n = #list
	if n < 1 then return false end
	for step = 0, n - 1 do
		local idx = ((QUEST.RIDX - 1 + step) % n) + 1
		local npc = list[idx]
		local info = QUEST.DB[npc]
		if info and info.kind ~= "sam" and info.kind ~= "skip" then
			local model = findNPC(npc)
			if model and questExec(model, "Accept", info.quest) then
				QUEST.RIDX = (idx % n) + 1
				return true
			end
		end
	end
	return false
end

function deliverQuestItems(npc, info)
	local model = findNPC(npc)
	if not model then return false end
	local any = false
	for _, item in ipairs(info.deliverItems or {}) do
		if hasItem(item) then
			questExec(model, "Deliver", item)
			any = true
		end
	end
	return any
end

function stepTalkQuest(npc, info)
	local target = findNPC(info.talkNPC)
	if not target then return false end
	tpNear(target)
	return questExec(target, "Deliver", info.deliver)
end

function collectNameBlocked(name)
	local low = string.lower(tostring(name or ""))
	for _, b in ipairs(QUEST.COLLECT_BLOCK) do
		if string.find(low, b, 1, true) then return true end
	end
	return false
end

function activeClickDetectors(item)
	local out = {}
	if item:IsA("ClickDetector") then
		if item.MaxActivationDistance > 0 then out[#out + 1] = item end
		return out
	end
	for _, d in ipairs(item:GetDescendants()) do
		if d:IsA("ClickDetector") and d.MaxActivationDistance > 0 then
			out[#out + 1] = d
		end
	end
	return out
end

function safeFireClick(cd)
	if not cd then return false end
	if fireclickdetector then
		if pcall(fireclickdetector, cd) then return true end
		if pcall(fireclickdetector, cd, 1) then return true end
	end
	return fireRemoteClick(cd)
end

function safeFirePrompt(pr)
	if not pr then return false end
	if fireproximityprompt then
		if pcall(fireproximityprompt, pr, 0) then return true end
		if pcall(fireproximityprompt, pr) then return true end
	end
	return false
end

function fireCollectAt(item)
	local cds = activeClickDetectors(item)
	local prompts = {}
	for _, d in ipairs(item:GetDescendants()) do
		if d:IsA("ProximityPrompt") then prompts[#prompts + 1] = d end
	end
	if #cds == 0 and #prompts == 0 then return false end
	local pos = getPos(item)
	local hrp = getHRP()
	if hrp and pos then
		pcall(function() hrp.CFrame = CFrame.new(pos + Vector3.new(0, QUEST.COLLECT_TP_UP, 0)) end)
	end
	for _, cd in ipairs(cds) do safeFireClick(cd) end
	for _, pr in ipairs(prompts) do safeFirePrompt(pr) end
	return true
end

function nearestCollectibles(info, limit)
	local hrp = getHRP()
	if not hrp then return {} end
	local arr = {}
	for _, fp in ipairs(info.collectFolders or {}) do
		local folder = resolvePath(fp)
		if folder then
			for _, item in ipairs(folder:GetChildren()) do
				if not collectNameBlocked(item.Name) then
					local pos = getPos(item)
					if pos then
						arr[#arr + 1] = { item = item, d = (hrp.Position - pos).Magnitude }
					end
				end
			end
		end
	end
	table.sort(arr, function(a, b) return a.d < b.d end)
	local out = {}
	limit = limit or QUEST.COLLECT_BATCH
	for i = 1, math.min(limit, #arr) do out[i] = arr[i].item end
	return out
end

function stepCollectQuest(npc, info)
	if questDone() then return false end
	local batch = nearestCollectibles(info, QUEST.COLLECT_BATCH)
	if #batch < 1 then return false end
	local n = 0
	for _, item in ipairs(batch) do
		if not isActive() or questDone() then break end
		if fireCollectAt(item) then n += 1 end
	end
	return n > 0
end

function stepReachQuest(info)
	local pos
	if type(info.pos) == "table" then
		pos = Vector3.new(info.pos[1], info.pos[2], info.pos[3])
	else
		local target = resolvePath(info.target)
		local p = target and getPos(target)
		if p then pos = p + Vector3.new(0, 4, 0) end
	end
	if not pos then return false end
	local hrp = getHRP()
	if hrp then pcall(function() hrp.CFrame = CFrame.new(pos) end) end
	return true
end

function stepReachAllQuest(info)
	local folder = resolvePath(info.folder)
	if not folder then return false end
	local hrp = getHRP()
	if not hrp then return false end
	local parts = {}
	for _, p in ipairs(folder:GetDescendants()) do
		if p:IsA("BasePart") then parts[#parts + 1] = p end
	end
	local idx = (STATE.reachIdx or 0) % math.max(#parts, 1)
	STATE.reachIdx = idx + 1
	local p = parts[idx + 1]
	if p then pcall(function() hrp.CFrame = CFrame.new(p.Position + Vector3.new(0, QUEST.COLLECT_TP_UP, 0)) end) end
	return #parts > 0
end

function activeQuestInDB(q)
	if not q or not q.Active or q.Active == "" then return nil, nil end
	for npc, info in pairs(QUEST.DB) do
		if info.quest == q.Active then return npc, info end
	end
	return nil, nil
end

function questWorkActive()
	if not (QUEST.AUTO or QUEST.EXPERTISE) then return false end
	local q = getQuests()
	if not q or not q.Active or q.Active == "" then return false end
	local _, info = activeQuestInDB(q)
	if not info then return false end
	if q.Completed then return not info.noClaim end
	return true
end

function stepActiveQuest(npc, info)
	local q = getQuests()
	if not q then return false end
	if q.Completed then
		if info.noClaim then return false end
		local model = findNPC(npc)
		if model then questExec(model, "Claim") end
		return true
	end
	local kind = info.kind or "mob"
	if kind == "deliver" then
		return deliverQuestItems(npc, info)
	elseif kind == "collect" then
		if not q.Completed then stepCollectQuest(npc, info) end
		return deliverQuestItems(npc, info)
	elseif kind == "talk" then
		return stepTalkQuest(npc, info)
	elseif kind == "carry" then
		if info.quest == FISH.Q_FAVOR then return runFavorQuest() end
		if hasItem(info.carryItem or "Package") then return deliverPackage() end
		local model = findNPC(npc)
		if model then questExec(model, "Accept", info.quest) end
		return true
	elseif kind == "reach" then
		return stepReachQuest(info)
	elseif kind == "reachAll" then
		return stepReachAllQuest(info)
	elseif questInfoNeedsKill(info) then
		return stepFarmQuest(npc, info)
	end
	return false
end

function runQuestList(list)
	list = normalizeQuestPick(list)
	local q = getQuests()
	if not q then return end
	local npc, info = activeQuestInDB(q)
	if npc then
		stepActiveQuest(npc, info)
		return
	end
	if #list < 1 then return end
	tryAcceptQuestList(list)
end

function stepExpertiseQuest()
	runQuestList({ "Old Beggar" })
end

function stepPickedQuests()
	runQuestList(QUEST.PICK)
end

function stashQuestFish()
	if not FISH.ON or not rodTaskPhase() then return {} end
	local keep = workspace:FindFirstChild("SigmaFishKeep_" .. player.UserId)
	if not keep then
		keep = Instance.new("Folder")
		keep.Name = "SigmaFishKeep_" .. player.UserId
		keep.Parent = workspace
	end
	local out = {}
	for _, t in ipairs(scanFish()) do
		if keepForQuest(t.Name) then pcall(function() t.Parent = keep end) table.insert(out, t) end
	end
	return out
end

function restoreFish(stashed)
	local bp = player:FindFirstChild("Backpack")
	if not bp then return end
	for _, t in ipairs(stashed) do if t and t.Parent then pcall(function() t.Parent = bp end) end end
end

function merchantExec(model, channel, args)
	if not model then return false end
	setMerchant(model)
	task.wait(0.05)
	return exec(channel, args or {})
end

function fireRemoteClick(cd)
	if not cd then return false end
	if fireclickdetector then
		for _ = 1, 3 do
			pcall(fireclickdetector, cd)
			task.wait(0.1)
		end
		return true
	end
	if UNC.getConns then
		local ok = pcall(function()
			for _, sig in ipairs({ cd.MouseClick, cd.MouseButton1Click }) do
				if sig then
					for _, c in ipairs(getconnections(sig)) do
						if c.Function then c.Function()
						elseif c.Fire then c:Fire() end
					end
				end
			end
		end)
		if ok then return true end
	end
	return false
end

function remoteCook()
	local station = resolvePath(FISH.COOK_PATH)
	if not station then return false end
	local cd = (station:IsA("ClickDetector") and station)
		or station:FindFirstChildOfClass("ClickDetector")
		or station:FindFirstChildWhichIsA("ClickDetector", true)
	if cd then return fireRemoteClick(cd) end
	return exec("CookFish", {}) or exec("CookAll", {})
end

function remoteSell()
	local cooker = findNPC(FISH.COOKER)
	if not cooker then return false end
	return merchantExec(cooker, "SellFish", {})
end
function cookAndSell(force)
	if STATE.cooking then return false end
	if not force then
		if not FISH.AUTO_SELL then return false end
		if countSellable() < FISH.SELL_AT then return false end
		if os.clock() - STATE.lastSell < 2 then return false end
	end
	if countSellable() < 1 and not force then return false end

	STATE.cooking = true
	local ok = pcall(function()
		local stashed = stashQuestFish()
		local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
		if hum then pcall(function() hum:UnequipTools() end) end
		task.wait(0.1)
		remoteCook()
		task.wait(0.35)
		remoteSell()
		restoreFish(stashed)
		ensureRodReady()
	end)
	STATE.cooking = false
	STATE.pause = false
	if ok then STATE.lastSell = os.clock() end
	return ok
end

function castLoop()
	if STATE.loopRunning then return end
	STATE.loopRunning = true
	task.spawn(function()
		while isActive() and fishAllowed() do
			if STATE.cooking then
				task.wait(0.15)
			elseif miniOpen() then
				if not STATE.solving then solveMini() end
				task.wait(0.18)
			elseif not ensureRodReady() then
				task.wait(1)
			else
				local rod = ensureRodReady()
				if rod and not lineOut() and not miniOpen() then
					clickRod(rod)
					waitUntil(function() return lineOut() or miniOpen() end, FISH.CAST_TIMEOUT)
				elseif lineOut() and not miniOpen() then
					local before = STATE.fishCount or 0
					waitUntil(function() return onHook() or miniOpen() or not lineOut() end, FISH.BITE_TIMEOUT)
					if onHook() and not miniOpen() then
						clickRod(ensureRodReady() or rod)
						waitUntil(function() return not lineOut() or miniOpen() or (STATE.fishCount or 0) > before end, FISH.REEL_TIMEOUT)
					elseif lineOut() then
						clickRod(ensureRodReady() or rod)
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

	if not qHist(FISH.Q_FAVOR) then
		if runFavorQuest() then
			castLoop()
			return
		end
	end

	if not findRod() then
		ensureBestRodLoadout()
		if not findRod() and not qHist(FISH.Q_FAVOR) then
			castLoop()
			return
		end
		if not findRod() then return end
	end

	if rodQuestActive() then
		runRodQuestChain()
	end
	ensureRodReady()

	if not fishAllowed() then
		castLoop()
		return
	end

	if not STATE.cooking and not lineOut() and not miniOpen() then
		task.spawn(function() cookAndSell(false) end)
	end
	castLoop()
end

function hubRunning()
	return FISH.ON or QUEST.AUTO or QUEST.EXPERTISE
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
	FISH.AUTO_SELL = cfg.AutoCookSell ~= false
	FISH.SELL_AT = tonumber(cfg.SellAt) or 40
	QUEST.AUTO = cfg.AutoQuest == true
	QUEST.EXPERTISE = cfg.AutoExpertise == true
	QUEST.PICK = normalizeQuestPick(cfg.QuestPick)
	if not STATE.cooking then
		STATE.pause = false
	end
end

function ensureLoopRunning()
	syncCfg()
	if not hubRunning() then
		stopLoop()
		return
	end
	if getgenv().__SIGMA_FISH_RUNNING then
		return
	end
	startLoop()
end

function hubTick()
	syncCfg()
	if not hubRunning() or not isActive() then return end
	if ensureSpawn() then return end
	if spawnOpen() or not worldReady() then return end
	if QUEST.EXPERTISE then
		stepExpertiseQuest()
	elseif QUEST.AUTO then
		stepPickedQuests()
	end
	if FISH.ON and not questWorkActive() then fishStep() end
end

function startLoop()
	syncCfg()
	if getgenv().__SIGMA_FISH_RUNNING then return end
	if not hubRunning() then return end
	RUN.id += 1
	local run = RUN.id
	getgenv().__SIGMA_FISH_RUNNING = true
	getgenv().__SIGMA_FISH_RUN_ID = run
	task.spawn(function()
		while getgenv().__SIGMA_FISH_RUNNING and getgenv().__SIGMA_FISH_RUN_ID == run do
			pcall(hubTick)
			task.wait(FISH.LOOP_DELAY)
		end
	end)
end

function stopLoop()
	getgenv().__SIGMA_FISH_RUNNING = false
	STATE.loopRunning = false
end

SigmaFish = {}

function SigmaFish.setAutoFish(on)
	local cfg = getgenv().SigmaFishConfig or {}
	cfg.AutoFish = on == true
	getgenv().SigmaFishConfig = cfg
	STATE.pause = false
	ensureLoopRunning()
end

function SigmaFish.setAutoQuest(on)
	local cfg = getgenv().SigmaFishConfig or {}
	cfg.AutoQuest = on == true
	getgenv().SigmaFishConfig = cfg
	STATE.pause = false
	STATE.cooking = false
	ensureLoopRunning()
end

function SigmaFish.setQuestPick(names)
	local cfg = getgenv().SigmaFishConfig or {}
	cfg.QuestPick = normalizeQuestPick(names)
	getgenv().SigmaFishConfig = cfg
	QUEST.PICK = cfg.QuestPick
	syncCfg()
end

function SigmaFish.setAutoExpertise(on)
	local cfg = getgenv().SigmaFishConfig or {}
	cfg.AutoExpertise = on == true
	getgenv().SigmaFishConfig = cfg
	STATE.pause = false
	ensureLoopRunning()
end

function SigmaFish.setQuestSelect(_)
	-- legacy no-op
end

function SigmaFish.setAutoCookSell(on)
	local cfg = getgenv().SigmaFishConfig or {}
	cfg.AutoCookSell = on == true
	getgenv().SigmaFishConfig = cfg
	STATE.cooking = false
	STATE.pause = false
	syncCfg()
	ensureLoopRunning()
end

function SigmaFish.applyConfig()
	local cfg = getgenv().SigmaFishConfig or {}
	cfg.QuestPick = normalizeQuestPick(cfg.QuestPick)
	getgenv().SigmaFishConfig = cfg
	STATE.cooking = false
	STATE.pause = false
	ensureLoopRunning()
end

function SigmaFish.setSellAt(n)
	getgenv().SigmaFishConfig = getgenv().SigmaFishConfig or {}
	getgenv().SigmaFishConfig.SellAt = tonumber(n)
	syncCfg()
end

function SigmaFish.getQuestList()
	return questListAll()
end

function SigmaFish.cookSell()
	return cookAndSell(true)
end

function SigmaFish.getStatus()
	syncCfg()
	local q = getQuests()
	return {
		autoFish = FISH.ON,
		autoQuest = QUEST.AUTO,
		autoExpertise = QUEST.EXPERTISE,
		questPick = table.concat(QUEST.PICK, ", "),
		rodPhase = (not qHist(FISH.Q_FAVOR) and "Favor/Package")
			or (not qHist(FISH.Q_TASK) and "Task")
			or (not qHist(FISH.Q_CHALLENGE) and "Challenge")
			or "Super Rod done",
		autoCookSell = FISH.AUTO_SELL,
		sellAt = FISH.SELL_AT,
		fishCount = STATE.fishCount,
		inMinigame = STATE.inMini or miniOpen(),
		questActive = q and q.Active,
		questDone = qHist(FISH.Q_CHALLENGE),
		sellable = countSellable(),
		hasRod = findRod() ~= nil,
		bestRod = bestRodName(),
		rodHeld = rodHeld(select(1, findRod())),
		bestWeapon = select(1, bestCombatWeapon()),
	}
end

function SigmaFish.isRunning()
	return getgenv().__SIGMA_FISH_RUNNING and hubRunning()
end

function SigmaFish.stop()
	getgenv().SigmaFishConfig = getgenv().SigmaFishConfig or {}
	getgenv().SigmaFishConfig.AutoFish = false
	getgenv().SigmaFishConfig.AutoQuest = false
	getgenv().SigmaFishConfig.AutoExpertise = false
	STATE.cooking = false
	STATE.pause = false
	syncCfg()
	stopLoop()
end

-- Reset loop khi reload Main.lua (tránh loop cũ chặn startLoop)
getgenv().__SIGMA_FISH_RUNNING = false
getgenv().__SIGMA_FISH_RUN_ID = nil

do
	local cfg = getgenv().SigmaFishConfig
	if type(cfg) ~= "table" then
		cfg = {}
		getgenv().SigmaFishConfig = cfg
	end
	if cfg.AutoCookSell == nil then cfg.AutoCookSell = true end
	if cfg.SellAt == nil then cfg.SellAt = 40 end
	if cfg.QuestPick == nil then cfg.QuestPick = {} end
	if cfg.AutoExpertise == nil then cfg.AutoExpertise = false end
	syncCfg()
end

getgenv().SigmaFish = SigmaFish
return SigmaFish
