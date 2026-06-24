--[[ Main.lua — Sigma Hub BACKEND (fishing, quest, combat) — NOT SigmaUI.lua ]]
-- SIGMA_MODULE=backend

if type(getgenv) ~= "function" then getgenv = function() return _G end end
if type(task) ~= "table" then task = { wait = wait, spawn = function(f) coroutine.wrap(f)() end } end
if LPH_OBFUSCATED == nil then function LPH_NO_VIRTUALIZE(f) return f end end

CFG = getgenv().SigmaConfig or {}
getgenv().SigmaConfig = CFG

Players = game:GetService("Players")
ReplicatedFirst = game:GetService("ReplicatedFirst")
ReplicatedStorage = game:GetService("ReplicatedStorage")
UserInputService = game:GetService("UserInputService")
GuiService = game:GetService("GuiService")
VirtualUser = game:GetService("VirtualUser")
VirtualInputManager = game:GetService("VirtualInputManager")
TeleportService = game:GetService("TeleportService")
RunService = game:GetService("RunService")
player = Players.LocalPlayer

function sigmaLog(...) end

UNC = {
	mobile = false,
	vim = VirtualInputManager ~= nil,
	vuser = VirtualUser ~= nil,
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
HUB = {
	AUTO_SPAWN = true,
	ANTI_AFK = true,
	ANTI_AFK_JUMP = 180,
	LOOP_DELAY = 0.35,
	SPAWN_COOLDOWN = 10,
	HIDE_NAME = true,
	HIDE_NAME_LABEL = "Sigma Hub",
	REAL_NAME = nil,
	REAL_DISPLAY = nil,
	REAL_HAKI_NAME = nil,
}

GRAPPLE = {
	TOKENS = { "grapple" },
	DROP_INTERVAL = 1.5,
}
FISH = {
	ON = false, AUTO_SELL = true,
	SELL_AT = 40, LOOP_DELAY = 0.25,
	CAST_TIMEOUT = 4, BITE_TIMEOUT = 30, REEL_TIMEOUT = 4,
	MINI_CLICK = 0.2, MINI_SHUFFLE = 0.2, MINI_READY = 0.55, MINI_POLL = 0.12,
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

CACHE = {
	KEYS = { "Copper", "Silver", "Gold", "Platinum", "Compass" },
	NAMES = {
		Copper = { "Copper", "Copper Cache" },
		Silver = { "Silver", "Silver Cache" },
		Gold = { "Gold", "Gold Cache" },
		Platinum = { "Platinum", "Platinum Cache" },
		Compass = { "Compass", "Starter Compass" },
	},
	AUTO_CONSUME = true,
	AUTO_DROP = false,
	USE_CLICKS = 3,
	DROP_WAIT = 0.06,
	TICK = 0.4,
	_lastTick = 0,
	_dropBusy = false,
	CONSUME_MATCH = {
		"smoothie", "cider", "juice", "lemonade", "milk",
		"apple", "banana", "cantaloupe", "coconut", "melon", "pumpkin", "pear", "prickly",
	},
	CONSUME_BLOCK = {
		"grapple", "package", "melee", "essence", "compass", "cache", "rod",
	},
}
STATE = {
	pause = false, loopRunning = false, inMini = false, solving = false,
	fishCount = nil, listeners = false, lastSell = 0, lastDeliver = 0,
	lastSolveAt = 0, miniTotal = nil, cooking = false, reachIdx = 0,
	m1RunId = 0, antiAfkRunId = 0, lastGrappleDrop = 0, questRunId = 0,
	collectSweep = nil, spawnAt = 0,
	hakiFastRunning = false,
	hakiWasFull = false,
	hakiHoldCF = nil,
	hakiDrainAmount = nil,
	hakiDrainSince = nil,
	hakiFullStickySince = nil,
	hakiLastBarAmount = nil,
	hakiLastFastCast = 0,
	hakiMaxNotified = false,
	hideNameActive = false,
	hideNameGuiAt = 0,
	attackMob = nil,
	rejoinPending = false,
	whitelistKickAt = 0,
	kickPending = false,
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
	COLLECT_WAIT = 0.12,
	COLLECT_TP_UP = 2,
	CARRY_SWEEP_WAIT = 0.35,
	ATTACK_RANGE = 5,
	ATTACK_CD = 0.15,
	MOB_TP_Y = 1,
	MOB_RET_TP_DIST = 7,
	TARGET_SCAN = 800,
	TP_OFFSET = 2,
	_deliverAt = {},
	_actionAt = {},
}

HAKI = {
	AUTO_KEN = false,
	AUTO_BUSO = false,
	FAST = false,
	FULL_RATIO = 0.995,
	EMPTY_RATIO = 0.03,
	FAST_EMPTY = 0.015,
	FAST_CD = 0,
	DRAIN_RESET_SEC = 5,
	STUCK_FULL_SEC = 20,
	STOP_LEVEL = 0,
	MIN_MOB_LEVEL = 150,
	MIN_Y = 210.6,
	CLUSTER_RADIUS = 90,
	TP_INTERVAL = 0.25,
	HOLD_RETP_DIST = 24,
	SKILL_RETRY = 1.2,
	DEBUG_INTERVAL = 4,
	_logAt = {},
}

BRING = {
	RADIUS = 120,
	MAX = 12,
	STACK_Y = 0.12,
	MODE = "front",
	FRONT_DIST = 1.2,
	FRONT_PUSH = 0.8,
	FRONT_SPREAD = 1.6,
	FRONT_UP = 0,
	PLAYER_PUSH = 0.5,
	JITTER = 0.12,
	UNDER_Y = -3.5,
	HEAD_Y = 4.0,
	HOLD = true,
	HOLD_ANCHOR = true,
	HOLD_NOCLIP = false,
	MOB_HOLD = true,
	MOB_ANCHOR = true,
	MOB_SOFT = false,
	CLUSTER_RADIUS = 100,
	CLUSTER_TP_Y = 0,
	CLUSTER_CENTER_Y = 0,
	CLUSTER_TP_WAIT = 0.15,
	CLUSTER_STACK_WAIT = 0.2,
	CLUSTER_STACK_DIST = 5,
	NEAR_PULL = true,
	NEAR_PULL_IV = 0.35,
	holdCF = nil,
	holdActive = false,
	savedCol = {},
	mobHolds = {},
	nearBatch = {},
	nearFarmOpts = nil,
}

RAYLEIGH = {
	ON = false,
	SP4 = "Strange Powers #4",
	SP4_HAKI = 100,
	REQ = { Melee = 500, Sniper = 250, Sword = 250, Defense = 250 },
	CHESTS = "Chests",
	RINGS = "MapFolder.Rings",
	MEDITATE = "Meditate",
	CHEST_WAIT = 0.3,
	lastDbgAt = 0,
	_meditateTrack = nil,
}

SAM = {
	ON = false,
	PITY_STOP = 99,
	QUEST = "Help Sam",
	CLAIM_WAIT = 0.2,
	COMPASS_POS = Vector3.new(-1272, 221, -1368),
	DROP_WAIT = 0.3,
	DROP_TIMEOUT = 10,
	_actionAt = {},
	_tripBusy = false,
}

COMPASS = {
	FIND_ON = false,
	DROP_ON = false,
	LINE_WIDTH = 45,
	LINE_Y_BAND = 200,
	XZ_CELL = 40,
	REVERSE = true,
	MAX_RAY = 64,
	MAX_HOPS = 80,
	HARVEST_WAIT = 0.3,
	HARVEST_TRIES = 2,
	CLICK_INTERVAL = 0.06,
	FAIL_RETRY = 0.5,
	LOOP_DELAY = 0.5,
	TP_UP = 0.5,
	WATER_Y = 80,
	NEEDLE_AXIS = "up",
	_spawnerDB = nil,
	_mouseHeld = false,
	_noclip = { active = false, saved = {}, conns = {} },
}

SKILL = {
	ON = false,
	ALL_KEYS = { "Z", "X", "C", "V", "B", "N", "F", "G", "H", "J", "K", "L" },
	HOLD_SEC = 0.5,
	LOOP_WAIT = 0,
	KEY_GAP = 0,
	_keysDown = {},
}

REJOIN = {
	ON = false,
	CHECK_INTERVAL = 2,
	KICK_COOLDOWN = 12,
	_lastCheck = 0,
}

AFFINITY = {
	ON = false,
	STATS = { "Defense", "Melee", "Sniper", "Sword" },
	MAX_LOCKS = 3,
	SKIP_ANIM = true,
	ROLL_WAIT = 0.9,
	POLL = 0.05,
	MAX_ROLLS = 500,
	STABLE_WAIT = 0.06,
	LOCK_WAIT = 0.04,
	SYNC_WAIT = 0.05,
	TARGETS = {},
	sealed = {},
	_logAt = {},
}

BEGGAR = {
	AUTO_GOLDEN = true,
	KEEP_GOLDEN = 1,
	GOLDEN_CLICKS = 8,
	AUTO_PEAR = true,
	PEAR_CLICKS = 8,
}

COMBAT = {
	ORDER = { "Sword", "Melee" },
	M1_LOOP_WAIT = 0.15,
	M1_CLICK_GAP = 0.03,
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
	return getgenv().__SIGMA_HUB_RUNNING and getgenv().__SIGMA_HUB_RUN_ID == RUN.id
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

function questCooldownRemaining(name)
	local q = getQuests()
	if not q or type(q.Cooldowns) ~= "table" then return 0 end
	local v = q.Cooldowns[name]
	if type(v) ~= "table" then return 0 end
	return math.max(0, (tonumber(v.cd) or 0) - (os.time() - (tonumber(v.last) or 0)))
end

function questAcceptReady(questName)
	return questCooldownRemaining(questName) <= 0
end

function minCooldownInList(list)
	local best = 0
	for _, npc in ipairs(list or {}) do
		local info = QUEST.DB[npc]
		if info and info.quest then
			local cd = questCooldownRemaining(info.quest)
			if cd > best then best = cd end
		end
	end
	return best
end

function objectiveProgress(obj)
	if type(obj) ~= "table" then return 0, 1, false end
	local prog = tonumber(obj.Progress or obj.progress) or 0
	local req = tonumber(obj.Requirement or obj.Goal or obj.goal or obj.Max or obj.max) or 1
	if req <= 0 then req = 1 end
	return prog, req, prog >= req
end

function questObjectivesComplete(q)
	if not q then return false end
	if q.Completed == true then return true end
	if type(q.Objectives) ~= "table" then return false end
	for _, obj in pairs(q.Objectives) do
		local _, _, done = objectiveProgress(obj)
		if not done then return false end
	end
	return true
end

function questNeedsDeliverItem(q, itemName)
	if not q or type(q.Objectives) ~= "table" then return false end
	local want = string.lower(tostring(itemName or ""))
	for name, obj in pairs(q.Objectives) do
		local low = string.lower(tostring(name))
		if low == want or string.find(low, want, 1, true) then
			local prog, req, done = objectiveProgress(obj)
			if not done and prog < req then return true end
		end
	end
	return false
end

function questActionReady(key, interval)
	local now = os.clock()
	if now - (QUEST._actionAt[key] or 0) < (interval or 2.5) then return false end
	QUEST._actionAt[key] = now
	return true
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

function remoteQuestAccept(model, questName)
	if not questAcceptReady(questName) then return false end
	if not questActionReady("accept:" .. tostring(questName), 3) then return false end
	return questExec(model, "Accept", questName)
end

function remoteQuestClaim(model, questName)
	if not questActionReady("claim:" .. tostring(questName), 2.5) then return false end
	return questExec(model, "Claim")
end

function remoteQuestDeliver(model, itemName, questName)
	local key = "deliver:" .. tostring(questName or "") .. ":" .. tostring(itemName or "")
	if not questActionReady(key, 1.5) then return false end
	return questExec(model, "Deliver", itemName)
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

function hubRealName()
	if not HUB.REAL_NAME then
		HUB.REAL_NAME = player and player.Name or ""
		HUB.REAL_DISPLAY = player and player.DisplayName or HUB.REAL_NAME
	end
	return HUB.REAL_NAME
end

function hubDisplayName()
	return HUB.HIDE_NAME_LABEL or "Sigma Hub"
end

function notifyHub(title, content, icon, duration)
	local fn = getgenv().SigmaHubNotify
	if type(fn) == "function" then
		pcall(fn, title, content, icon, duration)
	end
end

function updateHakiMaxState()
	local maxed = hakiFarmStoppedByLevel()
	local lv, stop = statLevel("Haki"), hakiStopLevel()
	local cb = getgenv().SigmaHakiMaxCallback
	if type(cb) == "function" then
		pcall(cb, maxed, lv, stop)
	end
	if maxed and not STATE.hakiMaxNotified then
		STATE.hakiMaxNotified = true
		if stop and stop > 0 then
			notifyHub("Haki MAX", string.format("Haki Lv %d >= stop %d", lv, stop), "zap", 5)
		else
			notifyHub("Haki MAX", string.format("Haki Lv %d — maxed", lv), "zap", 5)
		end
	elseif not maxed then
		STATE.hakiMaxNotified = false
	end
end

function patchDataName(enabled)
	local d = getData()
	if not d then return end
	local alias, real = hubDisplayName(), hubRealName()
	if d.Name ~= nil then
		if enabled then
			if not HUB.REAL_DATA_NAME then HUB.REAL_DATA_NAME = d.Name end
			d.Name = alias
		elseif HUB.REAL_DATA_NAME then
			d.Name = HUB.REAL_DATA_NAME
		else
			d.Name = real
		end
	end
	local haki = d.Stats and d.Stats.Haki
	if type(haki) == "table" and haki.Name ~= nil then
		if enabled then
			if not HUB.REAL_HAKI_NAME then HUB.REAL_HAKI_NAME = haki.Name end
			haki.Name = alias
		elseif HUB.REAL_HAKI_NAME then
			haki.Name = HUB.REAL_HAKI_NAME
		else
			haki.Name = real
		end
	end
end

function patchCharacterName(enabled)
	local char = player and player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not hum then return end
	if enabled then
		hum.DisplayName = hubDisplayName()
	else
		hum.DisplayName = HUB.REAL_DISPLAY or hubRealName()
	end
end

function patchGuiNames(enabled)
	local pg = player and player:FindFirstChild("PlayerGui")
	if not pg then return end
	local alias, real = hubDisplayName(), hubRealName()
	local menu = pg:FindFirstChild("Menu")
	local statsFrame = menu and menu:FindFirstChild("Frame")
		and menu.Frame:FindFirstChild("MenuList")
		and menu.Frame.MenuList:FindFirstChild("Stats")
		and menu.Frame.MenuList.Stats:FindFirstChild("Frame")
	if statsFrame then
		local tag = statsFrame:FindFirstChild("Nametag")
		if tag and tag:IsA("TextLabel") then
			tag.Text = enabled and alias or real
		end
	end
	local lb = pg:FindFirstChild("Leaderboard")
	local list = lb and lb:FindFirstChild("PlayerListContainer")
	local row = list and list:FindFirstChild(real)
	if row then
		local pn = row:FindFirstChild("BGFrame") and row.BGFrame:FindFirstChild("PlayerName")
		if pn and pn:IsA("TextLabel") then
			pn.Text = enabled and alias or real
		end
	end
	for _, inst in ipairs(pg:GetDescendants()) do
		if (inst:IsA("TextLabel") or inst:IsA("TextButton")) and inst.Text == real then
			inst.Text = enabled and alias or real
		elseif (inst:IsA("TextLabel") or inst:IsA("TextButton")) and not enabled and inst.Text == alias then
			inst.Text = real
		end
	end
end

function restoreHideName()
	patchDataName(false)
	patchCharacterName(false)
	patchGuiNames(false)
end

function stepHideName()
	if HUB.HIDE_NAME == false then
		if STATE.hideNameActive then
			restoreHideName()
			STATE.hideNameActive = false
		end
		return
	end
	STATE.hideNameActive = true
	patchDataName(true)
	patchCharacterName(true)
	local now = os.clock()
	if not STATE.hideNameGuiAt or now - STATE.hideNameGuiAt > 1.5 then
		STATE.hideNameGuiAt = now
		patchGuiNames(true)
	end
	if type(getgenv().SigmaApplyUiHideName) == "function" then
		pcall(getgenv().SigmaApplyUiHideName)
	end
end

function samIsManagedActive(name)
	if not name or name == "" then return false end
	if RAYLEIGH.ON and (name == "Strange Powers #1" or name == "Strange Powers #2"
		or name == "Strange Powers #3" or name == RAYLEIGH.SP4) then
		return true
	end
	if SAM.ON and name == SAM.QUEST then return true end
	return false
end

function samActionReady(key, interval)
	local now = os.clock()
	local k = "sam:" .. tostring(key or "act")
	if now - (SAM._actionAt[k] or 0) < (interval or 2.5) then return false end
	SAM._actionAt[k] = now
	return true
end

function samFindNPC()
	local m = findNPC("Sam")
	if m then return m end
	for _, rootName in ipairs({ "Ignore", "MapFolder" }) do
		local root = workspace:FindFirstChild(rootName)
		if root then
			for _, inst in root:GetDescendants() do
				if inst:IsA("Model") then
					local dlg = inst:GetAttribute("DialogueModule")
					if inst.Name == "Sam" or dlg == "Sam" then return inst end
				end
			end
		end
	end
	return nil
end

function samCompassTokensReady(stats)
	if not stats then return false end
	local compass = tonumber(stats.Compass) or 0
	if compass < 1 then return false end
	local storage = tonumber(stats.CompassStorage)
	if storage and storage > 0 then return compass >= storage end
	return true
end

function samCloseDialogue()
	local pg = player:FindFirstChild("PlayerGui")
	local dlg = pg and pg:FindFirstChild("QuestGui") and pg.QuestGui:FindFirstChild("Dialogue")
	if dlg and dlg.Visible then
		pcall(function() dlg.Visible = false end)
		return true
	end
	return false
end

function samGetReturnCF()
	local hrp = getHRP()
	return hrp and hrp.CFrame
end

function samRestoreCF(cf)
	local hrp = getHRP()
	if hrp and cf then
		pcall(function() hrp.CFrame = cf end)
		task.wait(0.12)
		return true
	end
	return false
end

function samUnequipAllTools()
	local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if hum then pcall(function() hum:UnequipTools() end) end
	task.wait(0.08)
end

function dropSelectedCacheInPlace()
	if not CACHE.AUTO_DROP then return false end
	local pick = cacheDropPick()
	if #pick < 1 or not cacheDropPending(pick) then return false end
	while cacheDropPending(pick) and isActive() do
		if not cacheDropTypes(pick, 10) then break end
		task.wait(CACHE.DROP_WAIT)
	end
	return true
end

function samWithReturnTrip(samModel, workFn)
	if SAM._tripBusy then return false end
	SAM._tripBusy = true
	local savedCF = samGetReturnCF()
	samUnequipAllTools()
	if samModel then tpNear(samModel) end
	local ok = true
	if type(workFn) == "function" then
		ok = workFn() ~= false
	end
	samRestoreCF(savedCF)
	dropSelectedCacheInPlace()
	if FISH.ON and findRod() then
		equipBestRodNow()
	end
	SAM._tripBusy = false
	return ok
end

function samClickNPC(model)
	if not model then return false end
	setMerchant(model)
	local part = model:FindFirstChild("HumanoidRootPart") or model:FindFirstChildWhichIsA("BasePart", true)
	if part then
		local cd = part:FindFirstChildOfClass("ClickDetector") or part:FindFirstChildWhichIsA("ClickDetector", true)
		if cd and fireclickdetector then pcall(fireclickdetector, cd) end
	end
	task.wait(0.12)
	return true
end

function samClaimCompass()
	if not SAM.ON then return false end
	local stats = getData() and getData().Stats
	if not samCompassTokensReady(stats) then return false end
	if not samActionReady("claim", 2.5) then return false end
	local pity = tonumber(stats.GoldenCompassPity) or 0
	local remaining = SAM.PITY_STOP - pity
	if remaining <= 0 then
		hakiLog("sampity", string.format("[Sam] GoldenCompassPity %d/%d -> STOP claim", pity, SAM.PITY_STOP), 30)
		return false
	end
	local m = samFindNPC()
	if not m then
		hakiLog("samnpc", string.format("[Sam] ready %s/%s but NPC not found",
			tostring(stats.Compass), tostring(stats.CompassStorage or 1)), 10)
		return false
	end
	if BRING.holdActive or next(BRING.mobHolds) then BRING.releaseHold() end
	local canClaim = math.floor(tonumber(stats.Compass) or 0)
	local amount = math.min(canClaim, 10, remaining)
	if amount < 1 then return false end
	return samWithReturnTrip(m, function()
		samClickNPC(m)
		task.wait(SAM.CLAIM_WAIT)
		local ok = exec("Sam", { "ClaimAmount", m, amount })
		task.defer(samCloseDialogue)
		return ok ~= false
	end)
end

function samTryAccept(name, info)
	local stats = getData() and getData().Stats
	if not stats then return false end
	local cd = questCooldownRemaining(info.quest)
	local q = getQuests()
	local active = q and q.Active
	if active and active ~= "" and active ~= info.quest and not samIsManagedActive(active) then
		hakiLog("samforce", string.format("[Sam] active '%s' -> force accept/claim", active), 8)
	end
	if not stats.CompletedStarterCompass and cd <= 0 and (not q or q.Active ~= SAM.QUEST) then
		if not samActionReady("accept", 3) then return false end
		local m = samFindNPC()
		if not m then return false end
		return samWithReturnTrip(m, function()
			samClickNPC(m)
			exec("QuestEvents", { "Accept", info.quest })
			task.defer(samCloseDialogue)
			return true
		end)
	end
	return false
end

function stepSam()
	if not SAM.ON then return false end
	if SAM._tripBusy then return true end
	if samClaimCompass() then return true end
	local q = getQuests()
	if not q then return false end
	local info = QUEST.DB["Sam"]
	if not info then return false end
	if q.Active == SAM.QUEST then
		if q.Completed == true then
			if not samActionReady("questclaim", 2.5) then return true end
			local m = samFindNPC()
			if m then
				samWithReturnTrip(m, function()
					samClickNPC(m)
					exec("QuestEvents", { "Claim" })
					task.defer(samCloseDialogue)
					return true
				end)
			end
		else
			stepFarmQuest("Sam", info, "sam")
		end
		return true
	end
	return samTryAccept("Sam", info)
end

function samCountCompassTool()
	local n = 0
	for _, src in ipairs({ player.Character, player:FindFirstChild("Backpack") }) do
		if src then
			for _, t in ipairs(src:GetChildren()) do
				if t:IsA("Tool") and t.Name == "Compass" then n += 1 end
			end
		end
	end
	return n
end

function samNextCompassTool()
	for _, src in ipairs({ player.Character, player:FindFirstChild("Backpack") }) do
		if src then
			for _, t in ipairs(src:GetChildren()) do
				if t:IsA("Tool") and t.Name == "Compass" then return t end
			end
		end
	end
	return nil
end

function stepCompassDrop()
	if not COMPASS.DROP_ON then return false end
	if not samActionReady("drop", 2) then return false end
	return cacheDropTypes({ "Compass" }, 5)
end

function compassSendMouse(down)
	local cam = workspace.CurrentCamera
	if not cam then return end
	if UNC.vim then
		local vs = cam.ViewportSize
		pcall(function()
			VirtualInputManager:SendMouseButtonEvent(vs.X * 0.5, vs.Y * 0.5, 0, down, game, 0)
		end)
	elseif VirtualUser then
		pcall(function()
			if down then VirtualUser:Button1Down(Vector2.zero, cam.CFrame)
			else VirtualUser:Button1Up(Vector2.zero, cam.CFrame) end
		end)
	end
end

function compassHoldTool()
	local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	local tool = samNextCompassTool()
	if not tool or not hum then return false end
	if tool.Parent ~= player.Character then
		pcall(function() hum:EquipTool(tool) end)
		task.wait(0.06)
	end
	pcall(function() tool:Activate() end)
	if not COMPASS._mouseHeld then
		compassSendMouse(true)
		COMPASS._mouseHeld = true
	end
	return true
end

function compassReleaseMouse()
	if COMPASS._mouseHeld then
		compassSendMouse(false)
		COMPASS._mouseHeld = false
	end
end

function compassFlatUnit(v)
	local f = Vector3.new(v.X, 0, v.Z)
	if f.Magnitude < 0.02 then return nil end
	return f.Unit
end

function compassNeedlePart()
	local tool = samNextCompassTool() or (player.Character and player.Character:FindFirstChild("Compass"))
	if not tool then return nil end
	local n = tool:FindFirstChild("CompassNeedle") or tool:FindFirstChild("Needle")
	if n then return n end
	for _, d in ipairs(tool:GetDescendants()) do
		if d:IsA("BasePart") and string.find(string.lower(d.Name), "needle", 1, true) then
			return d
		end
	end
	return nil
end

function compassNeedleLook()
	local n = compassNeedlePart()
	if not n then return nil end
	local ok, raw = pcall(function()
		if COMPASS.NEEDLE_AXIS == "up" then return n.CFrame.UpVector end
		if COMPASS.NEEDLE_AXIS == "-up" then return -n.CFrame.UpVector end
		if COMPASS.NEEDLE_AXIS == "look" then return n.CFrame.LookVector end
		return n.CFrame.UpVector
	end)
	if not ok or not raw then return nil end
	local d = compassFlatUnit(raw)
	if COMPASS.REVERSE and d then d = -d end
	return d
end

function compassBuildSpawnerDB()
	if COMPASS._spawnerDB then return COMPASS._spawnerDB end
	local all = {}
	local trees = workspace.MapFolder and workspace.MapFolder:FindFirstChild("Trees")
	if trees then
		for _, tree in ipairs(trees:GetChildren()) do
			for _, d in ipairs(tree:GetDescendants()) do
				if d:IsA("BasePart") and d.Name == "Spawner" then
					all[#all + 1] = {
						sp = d, tree = tree.Name, treeInst = tree,
						pos = d.Position, x = d.Position.X, y = d.Position.Y, z = d.Position.Z,
					}
				end
			end
		end
	end
	COMPASS._spawnerDB = all
	return all
end

function compassRayPerp(origin, needle, x, z)
	local dx, dz = x - origin.X, z - origin.Z
	local along = dx * needle.X + dz * needle.Z
	local px, pz = dx - needle.X * along, dz - needle.Z * along
	return along, math.sqrt(px * px + pz * pz)
end

function compassBuildLine(origin, needle, refY)
	refY = refY or origin.Y
	local candidates = {}
	for _, e in ipairs(compassBuildSpawnerDB()) do
		if not e.sp.Parent or not e.treeInst then continue end
		local along, perp = compassRayPerp(origin, needle, e.x, e.z)
		if along > 0 and perp <= COMPASS.LINE_WIDTH and math.abs(e.y - refY) <= COMPASS.LINE_Y_BAND then
			candidates[#candidates + 1] = { entry = e, along = along, perp = perp }
		end
	end
	local byXZ, line, seenTree = {}, {}, {}
	for _, row in ipairs(candidates) do
		local key = math.floor(row.entry.x / COMPASS.XZ_CELL) .. "," .. math.floor(row.entry.z / COMPASS.XZ_CELL)
		local prev = byXZ[key]
		if not prev or math.abs(row.entry.y - refY) < math.abs(prev.entry.y - refY) then
			byXZ[key] = row
		end
	end
	for _, row in pairs(byXZ) do
		if not seenTree[row.entry.treeInst] then
			seenTree[row.entry.treeInst] = true
			line[#line + 1] = row
		end
	end
	table.sort(line, function(a, b) return a.along < b.along end)
	return line
end

function compassTpStandOn(sp, treeName)
	local hrp = getHRP()
	local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if not hrp or not sp or not sp.Parent then return false end
	local top = (sp.CFrame * CFrame.new(0, sp.Size.Y * 0.5, 0)).Position
	local hip = hum and hum.HipHeight or 2
	local y = top.Y + math.max(COMPASS.TP_UP, hip + 0.35)
	pcall(function() hrp.CFrame = CFrame.new(sp.Position.X, y, sp.Position.Z) end)
	BRING.zeroVel(hrp)
	return true
end

function compassTouchSpawner(sp)
	local hrp = getHRP()
	if not hrp or not sp then return end
	pcall(function()
		if firetouchinterest then
			firetouchinterest(hrp, sp, 0)
			task.wait(0.03)
			firetouchinterest(hrp, sp, 1)
		end
	end)
end

function compassWaitHarvest(sp, startC)
	local perTry = COMPASS.HARVEST_WAIT / COMPASS.HARVEST_TRIES
	for _ = 1, COMPASS.HARVEST_TRIES do
		if not getgenv().__SIGMA_COMPASS_FIND or samCountCompassTool() < startC then
			return samCountCompassTool() < startC
		end
		compassHoldTool()
		compassTouchSpawner(sp)
		local hrp = getHRP()
		if hrp and sp then
			pcall(function() hrp.CFrame = CFrame.new(sp.Position.X, hrp.Position.Y, sp.Position.Z) end)
			BRING.zeroVel(hrp)
		end
		task.wait(perTry)
	end
	return samCountCompassTool() < startC
end

function compassHuntOnce(startC)
	if not compassHoldTool() then return false end
	for _ = 1, 10 do compassHoldTool(); task.wait(0.1) end
	local hrp = getHRP()
	local origin = hrp and hrp.Position
	if not origin then return false end
	local needle = compassNeedleLook()
	if not needle then return false end
	local line = compassBuildLine(origin, needle, origin.Y)
	if #line < 1 then return false end
	local visited, hops = {}, 0
	while getgenv().__SIGMA_COMPASS_FIND and samCountCompassTool() >= startC and hops < COMPASS.MAX_HOPS do
		hops += 1
		compassHoldTool()
		hrp = getHRP()
		origin = hrp and hrp.Position
		if not origin then break end
		needle = compassNeedleLook() or needle
		line = compassBuildLine(origin, needle, origin.Y)
		local row = nil
		for i, r in ipairs(line) do
			if i > COMPASS.MAX_RAY then break end
			if not visited[r.entry.sp] then row = r break end
		end
		if not row then break end
		visited[row.entry.sp] = true
		compassTpStandOn(row.entry.sp, row.entry.tree)
		if compassWaitHarvest(row.entry.sp, startC) then
			return true
		end
	end
	return false
end

function compassBeginNoclip()
	if COMPASS._noclip.active then return end
	COMPASS._noclip.active = true
	local function apply()
		local char = player.Character
		if not char then return end
		for _, p in ipairs(char:GetDescendants()) do
			if p:IsA("BasePart") and COMPASS._noclip.saved[p] == nil then
				COMPASS._noclip.saved[p] = { cc = p.CanCollide }
				pcall(function() p.CanCollide = false end)
			end
		end
	end
	apply()
	COMPASS._noclip.conns.a = RunService.Stepped:Connect(function()
		if COMPASS._noclip.active then apply() end
	end)
end

function compassEndNoclip()
	COMPASS._noclip.active = false
	for _, c in pairs(COMPASS._noclip.conns) do
		if c then pcall(function() c:Disconnect() end) end
	end
	COMPASS._noclip.conns = {}
	for p, was in pairs(COMPASS._noclip.saved) do
		if p and p.Parent then pcall(function() p.CanCollide = was.cc end) end
	end
	COMPASS._noclip.saved = {}
end

function stopCompassFindLoop()
	getgenv().__SIGMA_COMPASS_FIND = false
	compassReleaseMouse()
	compassEndNoclip()
end

function refreshCompassFindLoop()
	if COMPASS.FIND_ON and isActive() then
		if getgenv().__SIGMA_COMPASS_FIND then return end
		getgenv().__SIGMA_COMPASS_FIND = true
		compassBeginNoclip()
		task.spawn(function()
			while getgenv().__SIGMA_COMPASS_FIND and COMPASS.FIND_ON and isActive() do
				compassHoldTool()
				task.wait(COMPASS.CLICK_INTERVAL)
			end
			compassReleaseMouse()
		end)
		task.spawn(function()
			while getgenv().__SIGMA_COMPASS_FIND and COMPASS.FIND_ON and isActive() do
				if samCountCompassTool() < 1 then
					task.wait(2)
				else
					local startC = samCountCompassTool()
					pcall(function() compassHuntOnce(startC) end)
					task.wait(samCountCompassTool() < startC and 1 or COMPASS.FAIL_RETRY)
				end
				task.wait(COMPASS.LOOP_DELAY)
			end
			stopCompassFindLoop()
		end)
	else
		stopCompassFindLoop()
	end
end

function compassModeEnabled()
	return SAM.ON or COMPASS.DROP_ON or COMPASS.FIND_ON
end

function stepCompassFeatures()
	if SAM.ON and stepSam() then return true end
	if COMPASS.DROP_ON and stepCompassDrop() then return true end
	return false
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
	if shouldDeferRodEquip() then return nil end
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
				if not bestD or d < bestD then
					best, bestD = mob, d
				end
			end
		end
	end
	return best
end

function mobGroupsForQuest(q, info)
	local groups = getMobGroups(info)
	if #groups > 0 then return groups end
	if not (q and type(q.Objectives) == "table") then return groups end
	for name, obj in pairs(q.Objectives) do
		local prog = tonumber(obj and (obj.Progress or obj.progress)) or 0
		local req = tonumber(obj and (obj.Requirement or obj.Goal or obj.goal or obj.Max or obj.max)) or 1
		if req <= 0 then req = 1 end
		if prog < req then
			local words = {}
			for word in string.gmatch(normMob(name), "%w+") do words[#words + 1] = word end
			if #words > 0 then groups[#groups + 1] = words end
		end
	end
	return groups
end

function questModeEnabled()
	return QUEST.AUTO or QUEST.EXPERTISE
end

function questPickEnabled()
	return QUEST.AUTO == true
end

function questExpertiseEnabled()
	return QUEST.EXPERTISE == true
end

function questModeOk(mode)
	if mode == "expertise" then return questExpertiseEnabled() end
	if mode == "pick" then return questPickEnabled() end
	if mode == "sam" then return SAM.ON end
	return questModeEnabled()
end

function currentQuestList()
	if QUEST.EXPERTISE then return { "Old Beggar" } end
	return QUEST.PICK
end

function stopQuestWork()
	stopM1Loop()
	setQuestMobKill(false)
	STATE.questRunId = (STATE.questRunId or 0) + 1
	STATE.collectSweep = nil
end

function clearCollectSweep()
	STATE.collectSweep = nil
end

function questRunAlive(runId, mode)
	if not isActive() or STATE.questRunId ~= runId then return false end
	return questModeOk(mode)
end

function zeroHRPVel(hrp)
	if not hrp then return end
	pcall(function()
		hrp.AssemblyLinearVelocity = Vector3.zero
		hrp.AssemblyAngularVelocity = Vector3.zero
	end)
end

function tpNearMob(mob, force)
	local hrp = getHRP()
	local mobRoot = mob and (mob:FindFirstChild("HumanoidRootPart") or mob:FindFirstChildWhichIsA("BasePart", true))
	if not hrp or not mobRoot then return false end
	local pos = mobRoot.Position
	local dist = (hrp.Position - pos).Magnitude
	if not force and dist <= QUEST.MOB_RET_TP_DIST then return true end
	local facing = mobRoot.CFrame.LookVector
	facing = Vector3.new(facing.X, 0, facing.Z)
	if facing.Magnitude < 0.5 then facing = Vector3.new(0, 0, 1) else facing = facing.Unit end
	local stand = pos - facing * QUEST.ATTACK_RANGE + Vector3.new(0, QUEST.MOB_TP_Y, 0)
	pcall(function()
		hrp.CFrame = CFrame.new(stand, Vector3.new(pos.X, stand.Y, pos.Z))
	end)
	zeroHRPVel(hrp)
	return true
end

function vuM1Click()
	if not VirtualUser then return false end
	local cam = workspace.CurrentCamera
	if not cam then return false end
	pcall(function()
		VirtualUser:Button1Down(Vector2.new(0, 0), cam.CFrame)
	end)
	task.wait(COMBAT.M1_CLICK_GAP)
	pcall(function()
		VirtualUser:Button1Up(Vector2.new(0, 0), cam.CFrame)
	end)
	return true
end

function m1AttackOnce()
	return vuM1Click()
end

function mobAttackOnce()
	return vuM1Click()
end

function startM1Loop(aliveFn, mob)
	if mob then STATE.attackMob = mob end
	local run = STATE.m1RunId + 1
	STATE.m1RunId = run
	task.spawn(function()
		while isActive() and STATE.m1RunId == run do
			if not aliveFn or aliveFn() then
				ensureCombatReady()
				vuM1Click()
			end
			task.wait(COMBAT.M1_LOOP_WAIT)
		end
	end)
	return run
end

function stopM1Loop()
	STATE.m1RunId += 1
	STATE.attackMob = nil
end

function m1Attack()
	m1AttackOnce()
end

function setQuestMobKill(on)
	getgenv().__SIGMA_QUEST_MOB_KILL = on == true
end

function questMobKillEnabled()
	return getgenv().__SIGMA_QUEST_MOB_KILL == true
end

function attackLoopOnMob(mob, mode)
	mode = mode or "pick"
	if not questMobKillEnabled() or not questModeOk(mode) then return false end
	local hum = mob and mob:FindFirstChildOfClass("Humanoid")
	if not hum or hum.Health <= 0 then return true end
	ensureCombatReady()
	tpNearMob(mob, true)
	local lastHp, stallAt = hum.Health, os.clock()
	while isActive() and questMobKillEnabled() and questModeOk(mode) do
		hum = mob:FindFirstChildOfClass("Humanoid")
		if not hum or hum.Health <= 0 then return true end
		local mobRoot = mob:FindFirstChild("HumanoidRootPart") or mob:FindFirstChildWhichIsA("BasePart", true)
		local hrp = getHRP()
		if mobRoot and hrp then
			local d = (hrp.Position - mobRoot.Position).Magnitude
			if d > QUEST.MOB_RET_TP_DIST then
				tpNearMob(mob, true)
			else
				zeroHRPVel(hrp)
			end
		end
		ensureCombatReady()
		task.wait(QUEST.ATTACK_CD)
		hum = mob:FindFirstChildOfClass("Humanoid")
		if not hum or hum.Health <= 0 then return true end
		if hum.Health < lastHp then
			lastHp, stallAt = hum.Health, os.clock()
		elseif os.clock() - stallAt >= 4 then
			tpNearMob(mob, true)
			stallAt = os.clock()
		end
	end
	return false
end

function attackBurstOnMob(mob, mode)
	mode = mode or "pick"
	local hum = mob and mob:FindFirstChildOfClass("Humanoid")
	if not hum or hum.Health <= 0 then return true end
	setQuestMobKill(true)
	local aliveFn = function()
		return questMobKillEnabled() and questModeOk(mode)
	end
	startM1Loop(aliveFn, mob)
	ensureCombatReady()
	local ok = attackLoopOnMob(mob, mode)
	stopM1Loop()
	setQuestMobKill(false)
	hum = mob:FindFirstChildOfClass("Humanoid")
	return ok or not hum or hum.Health <= 0
end

function stepFarmQuest(npc, info, mode)
	if not questModeOk(mode or "pick") then return false end
	local q = getQuests()
	local groups = mobGroupsForQuest(q, info)
	if #groups < 1 then return false end
	if not questModeOk(mode or "pick") then return false end
	ensureCombatReady()
	local mob = nearestQuestMob(groups)
	if not mob then return false end
	local hrp = getHRP()
	local pos = getPos(mob)
	if hrp and pos and (hrp.Position - pos).Magnitude > QUEST.TARGET_SCAN then
		if not questModeOk(mode or "pick") then return false end
		tpNearMob(mob, true)
		task.wait(0.2)
	end
	if not questModeOk(mode or "pick") then return false end
	return attackBurstOnMob(mob, mode)
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

function cacheDropPending(types)
	types = types or cacheDropPick()
	for _, typeKey in ipairs(types) do
		if #collectToolsByCacheType(typeKey) > 0 then return true end
	end
	return false
end

function shouldDeferRodEquip()
	if SAM._tripBusy then return true end
	if CACHE._dropBusy then return true end
	if CACHE.AUTO_DROP and #cacheDropPick() > 0 and cacheDropPending(cacheDropPick()) then
		return true
	end
	return false
end

function equipBestRodNow()
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

function equipBestRod()
	if shouldDeferRodEquip() then
		local bestName = bestRodName()
		return (bestName and findTool(bestName)) or select(1, findRod())
	end
	return equipBestRodNow()
end

function finishCacheDropSession(types)
	if cacheDropPending(types) then return end
	if FISH.ON and findRod() then
		task.defer(equipBestRodNow)
	end
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
		clickNPC(fm) questExec(fm, "Accept", FISH.Q_FAVOR) return true
	end
	if active ~= FISH.Q_FAVOR then clickNPC(fm) questExec(fm, "Accept", FISH.Q_FAVOR) return true end
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
	clickNPC(fm) questExec(fm, "Accept", FISH.Q_TASK)
	return true
end

function runChallengeQuest()
	if qHist(FISH.Q_CHALLENGE) then return false end
	local q, fm = getQuests(), findNPC(FISH.FISHERMAN)
	if not q or not fm then return false end
	if not qHist(FISH.Q_TASK) then return false end
	if q.Active == FISH.Q_CHALLENGE then
		if q.Completed then clickNPC(fm) questExec(fm, "Claim") equipRod("Super Rod") return true end
		return false
	end
	clickNPC(fm) questExec(fm, "Accept", FISH.Q_CHALLENGE)
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

function tryAcceptQuestList(list, mode)
	if not questModeOk(mode or "pick") then return false end
	local n = #list
	if n < 1 then return false end
	if not questActionReady("acceptlist:" .. (mode or "pick"), 2) then return false end
	for step = 0, n - 1 do
		if not questModeOk(mode or "pick") then return false end
		local idx = ((QUEST.RIDX - 1 + step) % n) + 1
		local npc = list[idx]
		local info = QUEST.DB[npc]
		if info and info.kind ~= "sam" and info.kind ~= "skip" then
			local cd = questCooldownRemaining(info.quest)
			if cd <= 0 then
				local model = findNPC(npc)
				if model and remoteQuestAccept(model, info.quest) then
					QUEST.RIDX = (idx % n) + 1
					return true
				end
			end
		end
	end
	return false
end

function deliverQuestItems(npc, info)
	local model = findNPC(npc)
	if not model then return false end
	local q = getQuests()
	local any = false
	for _, item in ipairs(info.deliverItems or {}) do
		if hasItem(item) then
			local okDeliver = q and (q.Completed == true or q.Active == info.quest or questNeedsDeliverItem(q, item))
			if okDeliver then
				if remoteQuestDeliver(model, item, info.quest) then
					any = true
				end
			end
		end
	end
	return any
end

function stepTalkQuest(npc, info, mode)
	if not questModeOk(mode or "pick") then return false end
	local target = findNPC(info.talkNPC)
	if not target then return false end
	if not questModeOk(mode or "pick") then return false end
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

function waitAlive(sec, aliveFn)
	local t0 = os.clock()
	while os.clock() - t0 < sec do
		if aliveFn and not aliveFn() then return false end
		task.wait(0.03)
	end
	return not aliveFn or aliveFn()
end

function fireCollectAt(item, aliveFn)
	if aliveFn and not aliveFn() then return false end
	local cds = activeClickDetectors(item)
	local prompts = {}
	for _, d in ipairs(item:GetDescendants()) do
		if d:IsA("ProximityPrompt") then prompts[#prompts + 1] = d end
	end
	if #cds == 0 and #prompts == 0 then return false end
	local pos = getPos(item)
	local hrp = getHRP()
	if hrp and pos then
		if aliveFn and not aliveFn() then return false end
		pcall(function() hrp.CFrame = CFrame.new(pos + Vector3.new(0, QUEST.COLLECT_TP_UP, 0)) end)
		if not waitAlive(QUEST.COLLECT_WAIT, aliveFn) then return false end
	end
	for _ = 1, 2 do
		if aliveFn and not aliveFn() then return false end
		for _, cd in ipairs(cds) do safeFireClick(cd) end
		for _, pr in ipairs(prompts) do safeFirePrompt(pr) end
		if not waitAlive(0.05, aliveFn) then return false end
	end
	return true
end

function countItem(itemName)
	local n = 0
	local char = player.Character
	if char then
		for _, c in ipairs(char:GetChildren()) do
			if c.Name == itemName then n += 1 end
		end
	end
	local bp = player:FindFirstChild("Backpack")
	if bp then
		for _, c in ipairs(bp:GetChildren()) do
			if c.Name == itemName then n += 1 end
		end
	end
	return n
end

function useToolClicks(tool, hum, clicks, delay)
	if not tool or not hum then return end
	pcall(function() hum:EquipTool(tool) end)
	local n = clicks or 1
	for i = 1, n do
		if not isActive() or not tool.Parent then break end
		if not pcall(function() tool:Activate() end) then vuM1Click() end
		if delay and delay > 0 then
			task.wait(delay)
		elseif i < n then
			task.wait(0.05)
		end
	end
end

function isGoldenAppleName(name)
	local low = string.lower(tostring(name or ""))
	return string.find(low, "golden apple", 1, true) ~= nil
end

function isPearName(name)
	local low = string.lower(tostring(name or ""))
	return low == "pear" or string.find(low, " pear", 1, true) or string.find(low, "pear ", 1, true)
end

function collectToolsByName(matchFn)
	local out = {}
	for _, where in ipairs({ player.Character, player:FindFirstChild("Backpack") }) do
		if where then
			for _, c in ipairs(where:GetChildren()) do
				if c:IsA("Tool") and matchFn(c.Name) then out[#out + 1] = c end
			end
		end
	end
	return out
end

function normalizeCachePick(picked)
	local out, seen = {}, {}
	if type(picked) ~= "table" then return out end
	local function add(raw)
		local k = tostring(raw or "")
		k = string.gsub(k, "^%s+", "")
		k = string.gsub(k, "%s+$", "")
		if k ~= "" and not seen[k] then
			for _, key in ipairs(CACHE.KEYS) do
				if key == k then
					seen[key] = true
					out[#out + 1] = key
					break
				end
			end
		end
	end
	for _, v in ipairs(picked) do add(v) end
	for k, v in pairs(picked) do
		if type(k) == "string" and v == true then add(k) end
	end
	return out
end

function cacheUsePick()
	return normalizeCachePick((getgenv().SigmaFishConfig or {}).CacheUsePick)
end

function cacheDropPick()
	return normalizeCachePick((getgenv().SigmaFishConfig or {}).CacheDropPick)
end

function cacheToolIsType(toolName, typeKey)
	local names = CACHE.NAMES[typeKey]
	if not names or not toolName then return false end
	local lower = string.lower(toolName)
	for _, n in ipairs(names) do
		if string.lower(n) == lower then return true end
	end
	if typeKey ~= "Compass" and lower == string.lower(typeKey .. " Cache") then
		return true
	end
	return false
end

function collectToolsByCacheType(typeKey)
	local out = {}
	for _, where in ipairs({ player.Character, player:FindFirstChild("Backpack") }) do
		if where then
			for _, c in ipairs(where:GetChildren()) do
				if c:IsA("Tool") and cacheToolIsType(c.Name, typeKey) then
					out[#out + 1] = c
				end
			end
		end
	end
	return out
end

function getCacheCounts()
	local counts = {}
	for _, key in ipairs(CACHE.KEYS) do counts[key] = 0 end
	for _, where in ipairs({ player.Character, player:FindFirstChild("Backpack") }) do
		if where then
			for _, c in ipairs(where:GetChildren()) do
				if c:IsA("Tool") then
					for _, key in ipairs(CACHE.KEYS) do
						if cacheToolIsType(c.Name, key) then
							counts[key] += 1
						end
					end
				end
			end
		end
	end
	return counts
end

function isFishRodTool(tool)
	if not tool then return false end
	for _, r in ipairs(FISH.RODS) do
		if tool.Name == r then return true end
	end
	return string.find(string.lower(tool.Name), "rod", 1, true) ~= nil
end

function isCacheTypeTool(tool)
	if not tool or not tool:IsA("Tool") then return false end
	for _, key in ipairs(CACHE.KEYS) do
		if cacheToolIsType(tool.Name, key) then return true end
	end
	return false
end

function isMiscConsumableName(name)
	name = tostring(name or "")
	if name == "" then return false end
	local low = string.lower(name)
	for _, b in ipairs(CACHE.CONSUME_BLOCK) do
		if string.find(low, b, 1, true) then return false end
	end
	for _, m in ipairs(CACHE.CONSUME_MATCH) do
		if string.find(low, m, 1, true) then return true end
	end
	if string.find(name, "+", 1, true) then return true end
	return false
end

function isMiscConsumableTool(tool)
	if not tool or not tool:IsA("Tool") then return false end
	if isGrappleTool(tool) or isFishRodTool(tool) then return false end
	if isCacheTypeTool(tool) then return false end
	return isMiscConsumableName(tool.Name)
end

function dropToolInPlace(tool, hum)
	if not tool or not hum or not tool.Parent then return false end
	if tool.Parent ~= player.Character then
		pcall(function() hum:EquipTool(tool) end)
		task.wait(CACHE.DROP_WAIT)
	end
	if tool.Parent == player.Character and tool.CanBeDropped then
		pcall(function() tool.Parent = workspace end)
		task.wait(CACHE.DROP_WAIT)
		return true
	end
	return false
end

function cacheDropTypes(types, maxPerTick)
	types = types or {}
	if #types < 1 then return false end
	local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if not hum then return false end
	maxPerTick = maxPerTick or 5
	CACHE._dropBusy = true
	local dropped = 0
	for _, typeKey in ipairs(types) do
		for _, tool in ipairs(collectToolsByCacheType(typeKey)) do
			if not isActive() then
				CACHE._dropBusy = false
				finishCacheDropSession(types)
				return dropped > 0
			end
			if dropped >= maxPerTick then
				CACHE._dropBusy = false
				return true
			end
			if dropToolInPlace(tool, hum) then dropped += 1 end
		end
	end
	CACHE._dropBusy = false
	finishCacheDropSession(types)
	return dropped > 0
end

function stepCacheUseSelected()
	local pick = cacheUsePick()
	if #pick < 1 then return false end
	local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if not hum then return false end
	local used = false
	for _, typeKey in ipairs(pick) do
		for _, tool in ipairs(collectToolsByCacheType(typeKey)) do
			if not isActive() then return used end
			useToolClicks(tool, hum, CACHE.USE_CLICKS)
			used = true
		end
	end
	return used
end

function stepCacheDropSelected()
	if not CACHE.AUTO_DROP then return false end
	return cacheDropTypes(cacheDropPick(), 5)
end

function stepMiscConsumables()
	if not CACHE.AUTO_CONSUME then return false end
	local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if not hum then return false end
	local used = false
	for _, where in ipairs({ player.Character, player:FindFirstChild("Backpack") }) do
		if where then
			for _, tool in ipairs(where:GetChildren()) do
				if isMiscConsumableTool(tool) then
					if not isActive() then return used end
					useToolClicks(tool, hum, CACHE.USE_CLICKS)
					used = true
				end
			end
		end
	end
	return used
end

function cacheModeEnabled()
	return #cacheUsePick() > 0 or CACHE.AUTO_DROP or CACHE.AUTO_CONSUME
end

function stepCacheFeatures()
	if not cacheModeEnabled() then return false end
	local now = os.clock()
	if now - (CACHE._lastTick or 0) < CACHE.TICK then return false end
	CACHE._lastTick = now
	if stepCacheUseSelected() then return true end
	if stepCacheDropSelected() then return true end
	if stepMiscConsumables() then return true end
	return false
end

function useGoldenApplesForOldBeggar()
	if not BEGGAR.AUTO_GOLDEN then return 0 end
	local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if not hum then return 0 end
	local tools = collectToolsByName(isGoldenAppleName)
	local canUse = math.max(0, #tools - BEGGAR.KEEP_GOLDEN)
	local used = 0
	for _, tool in ipairs(tools) do
		if used >= canUse or not isActive() then break end
		useToolClicks(tool, hum, BEGGAR.GOLDEN_CLICKS)
		used += 1
	end
	return used
end

function usePearsForOldBeggar()
	if not BEGGAR.AUTO_PEAR then return 0 end
	local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if not hum then return 0 end
	local tools = collectToolsByName(isPearName)
	local used = 0
	for _, tool in ipairs(tools) do
		if not isActive() then break end
		useToolClicks(tool, hum, BEGGAR.PEAR_CLICKS)
		used += 1
	end
	return used
end

function deliverCollectItems(npc, info)
	local q = getQuests()
	if not q then return false end
	if q.Active ~= info.quest and q.Completed ~= true then return false end
	if not questActionReady("collectDeliver:" .. tostring(info.quest), 2) then return false end
	local model = findNPC(npc)
	if not model then return false end
	local onQuest = q.Active == info.quest
	local any = false
	for _, it in ipairs(info.deliverItems or {}) do
		if countItem(it) > 0 then
			if q.Completed == true or onQuest or questNeedsDeliverItem(q, it) then
				if remoteQuestDeliver(model, it, info.quest) then
					any = true
				end
			end
		end
	end
	return any
end

function stepCollectQuest(npc, info, mode)
	mode = mode or (npc == "Old Beggar" and "expertise" or "pick")
	if npc == "Old Beggar" and mode ~= "expertise" then return false end
	if mode == "expertise" and not questExpertiseEnabled() then
		clearCollectSweep()
		return false
	end
	if not questModeOk(mode) then
		clearCollectSweep()
		return false
	end
	local runId = STATE.questRunId or 0
	local aliveFn = function()
		if mode == "expertise" and not questExpertiseEnabled() then return false end
		if mode == "pick" and not questPickEnabled() then return false end
		return isActive() and STATE.questRunId == runId
	end
	if not aliveFn() then
		clearCollectSweep()
		return false
	end
	if questDone() then
		clearCollectSweep()
		deliverCollectItems(npc, info)
		return false
	end

	local sw = STATE.collectSweep
	if not sw or sw.npc ~= npc or sw.mode ~= mode or sw.runId ~= runId then
		sw = {
			npc = npc,
			mode = mode,
			runId = runId,
			fi = 1,
			ii = 1,
			folders = info.collectFolders or {},
			children = nil,
		}
		STATE.collectSweep = sw
	end

	while sw.fi <= #sw.folders do
		if not aliveFn() then
			clearCollectSweep()
			return false
		end
		local folder = resolvePath(sw.folders[sw.fi])
		if not folder then
			sw.fi += 1
			sw.ii = 1
			sw.children = nil
		else
			if not sw.children or sw.childFolder ~= folder then
				sw.children = folder:GetChildren()
				sw.childFolder = folder
				sw.ii = 1
			end
			if sw.ii <= #sw.children then
				local item = sw.children[sw.ii]
				sw.ii += 1
				if not collectNameBlocked(item.Name) then
					fireCollectAt(item, aliveFn)
					if not aliveFn() then
						clearCollectSweep()
						return false
					end
					if npc == "Old Beggar" then
						useGoldenApplesForOldBeggar()
						usePearsForOldBeggar()
						deliverCollectItems(npc, info)
					end
					return true
				end
			else
				sw.fi += 1
				sw.ii = 1
				sw.children = nil
			end
		end
	end

	clearCollectSweep()
	deliverCollectItems(npc, info)
	return false
end

function stepReachQuest(npc, info, mode)
	if not questModeOk(mode or "pick") then return false end
	local pos
	if type(info.pos) == "table" then
		pos = Vector3.new(info.pos[1], info.pos[2], info.pos[3])
	else
		local target = resolvePath(info.target)
		local p = target and getPos(target)
		if p then pos = p + Vector3.new(0, QUEST.TP_OFFSET, 0) end
	end
	if not pos then return false end
	if not questModeOk(mode or "pick") then return false end
	local hrp = getHRP()
	if hrp then pcall(function() hrp.CFrame = CFrame.new(pos) end) end
	return true
end

function stepReachAllQuest(npc, info, mode)
	mode = mode or "pick"
	if not questModeOk(mode) then return false end
	local folder = resolvePath(info.folder)
	if not folder then return false end
	local parts = {}
	for _, c in ipairs(folder:GetDescendants()) do
		if c:IsA("BasePart") then parts[#parts + 1] = c end
	end
	local runId = STATE.questRunId or 0
	for _, p in ipairs(parts) do
		if not questRunAlive(runId, mode) or questDone() then break end
		local hrp = getHRP()
		if hrp then
			pcall(function() hrp.CFrame = CFrame.new(p.Position + Vector3.new(0, QUEST.TP_OFFSET, 0)) end)
		end
		task.wait(0.35)
	end
	return #parts > 0
end

function stepDeliverQuest(npc, info)
	local now = os.clock()
	if now - (QUEST._deliverAt[npc] or 0) < 2 then return false end
	QUEST._deliverAt[npc] = now
	return deliverQuestItems(npc, info)
end

function activeQuestInDB(q)
	if not q or not q.Active or q.Active == "" then return nil, nil end
	for npc, info in pairs(QUEST.DB) do
		if info.quest == q.Active then return npc, info end
	end
	return nil, nil
end

function questWorkActive()
	local q = getQuests()
	if not q or not q.Active or q.Active == "" then return false end
	if questExpertiseEnabled() then
		local _, info = activeQuestInList(q, { "Old Beggar" })
		if info then
			if q.Completed then return not info.noClaim end
			return true
		end
	end
	if questPickEnabled() then
		local _, info = activeQuestInList(q, QUEST.PICK)
		if info then
			if q.Completed then return not info.noClaim end
			return true
		end
	end
	if SAM.ON and q.Active == SAM.QUEST then
		if q.Completed then return true end
		return true
	end
	return false
end

function stepActiveQuest(npc, info, mode)
	mode = mode or (npc == "Old Beggar" and "expertise" or "pick")
	if not questModeOk(mode) then return false end
	local q = getQuests()
	if not q then return false end
	if q.Completed then
		if info.noClaim then return false end
		local model = findNPC(npc)
		if model then remoteQuestClaim(model, info.quest) end
		return true
	end
	local kind = info.kind or "mob"
	if kind == "deliver" then
		return stepDeliverQuest(npc, info)
	elseif kind == "collect" then
		if npc == "Old Beggar" and mode ~= "expertise" then return false end
		return stepCollectQuest(npc, info, mode)
	elseif kind == "talk" then
		return stepTalkQuest(npc, info, mode)
	elseif kind == "carry" then
		if info.quest == FISH.Q_FAVOR then return runFavorQuest() end
		if hasItem(info.carryItem or "Package") then return deliverPackage() end
		local model = findNPC(npc)
		if model and questAcceptReady(info.quest) then
			remoteQuestAccept(model, info.quest)
		end
		return true
	elseif kind == "reach" then
		return stepReachQuest(npc, info, mode)
	elseif kind == "reachAll" then
		return stepReachAllQuest(npc, info, mode)
	elseif questInfoNeedsKill(info) then
		return stepFarmQuest(npc, info, mode)
	end
	return false
end

function runQuestList(list, mode)
	mode = mode or "pick"
	if not questModeOk(mode) then return end
	list = normalizeQuestPick(list)
	if #list < 1 then return end
	local q = getQuests()
	if not q then return end
	local npc, info = activeQuestInList(q, list)
	if npc then
		stepActiveQuest(npc, info, mode)
		return
	end
	local cd = minCooldownInList(list)
	if cd > 0 then
		return
	end
	tryAcceptQuestList(list, mode)
end

function stepExpertiseQuest()
	if not questExpertiseEnabled() then
		clearCollectSweep()
		return
	end
	runQuestList({ "Old Beggar" }, "expertise")
end

function stepPickedQuests()
	runQuestList(QUEST.PICK, "pick")
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
	return FISH.ON or QUEST.AUTO or QUEST.EXPERTISE or hakiModeEnabled() or AFFINITY.ON
		or SAM.ON or COMPASS.DROP_ON or COMPASS.FIND_ON or SKILL.ON or REJOIN.ON
		or cacheModeEnabled()
end

function hakiModeEnabled()
	return HAKI.AUTO_KEN or HAKI.AUTO_BUSO or HAKI.FAST or RAYLEIGH.ON
end

function hakiDebugOn()
	if getgenv().SigmaHakiDebug == false then return false end
	return true
end

function hakiLog(tag, msg, interval)
end

function hakiDiagSnapshot()
	local char = player.Character
	local d = getData()
	local ratio, amount, cap = readHakiBar()
	return string.format(
		"ken=%s buso=%s fast=%s ray=%s | hubRun=%s world=%s active=%s | obsUnlocked=%s busoUnlocked=%s | obsAttr=%s hakiAttr=%s | bar=%s (%s/%s) hakiLv=%s stop=%s | keyObs=%s keyBuso=%s | quest=%s",
		tostring(HAKI.AUTO_KEN), tostring(HAKI.AUTO_BUSO), tostring(HAKI.FAST), tostring(RAYLEIGH.ON),
		tostring(hubRunning()), tostring(worldReady()), tostring(isActive()),
		tostring(hakiAbilityUnlocked("Observation")), tostring(hakiAbilityUnlocked("Haki")),
		tostring(char and char:GetAttribute("Observation")), tostring(char and char:GetAttribute("Haki")),
		tostring(ratio and math.floor(ratio * 100) or "nil"), tostring(amount or "?"), tostring(cap or "?"),
		tostring(statLevel("Haki")), tostring(hakiStopLevel()),
		tostring(getHakiActionKey("Observation")), tostring(getHakiActionKey("Haki")),
		tostring(d and d.Quests and d.Quests.Active or "no-data")
	)
end

function spawnOpen()
	local pg = player and player:FindFirstChild("PlayerGui")
	local load = pg and pg:FindFirstChild("Load")
	return load and load:IsA("ScreenGui") and load.Enabled
end

function ensureSpawn()
	if HUB.AUTO_SPAWN == false then return false end
	if not spawnOpen() then return false end
	if worldReady() and getData() then
		pcall(function()
			local pg = player and player:FindFirstChild("PlayerGui")
			local load = pg and pg:FindFirstChild("Load")
			if load then load.Enabled = false end
		end)
		return false
	end
	local now = os.clock()
	if STATE.spawnAt and now - STATE.spawnAt < HUB.SPAWN_COOLDOWN then
		return true
	end
	STATE.spawnAt = now
	exec("Load", { "Load" })
	local pg = player and player:FindFirstChild("PlayerGui")
	local load = pg and pg:FindFirstChild("Load")
	pcall(function() if load then load.Enabled = false end end)
	task.wait(0.4)
	pcall(function()
		local cam = workspace.CurrentCamera
		if cam then cam.CameraType = Enum.CameraType.Track end
	end)
	return true
end

function disableAntiAfk()
	STATE.antiAfkRunId = (STATE.antiAfkRunId or 0) + 1
	local old = getgenv().__SIGMA_AntiAfkConn
	if old then pcall(function() old:Disconnect() end) end
	getgenv().__SIGMA_AntiAfkConn = nil
end

function setupAntiAfk()
	if HUB.ANTI_AFK == false then
		disableAntiAfk()
		return
	end
	disableAntiAfk()
	STATE.antiAfkRunId = (STATE.antiAfkRunId or 0) + 1
	local myAfk = STATE.antiAfkRunId
	getgenv().__SIGMA_AntiAfkConn = player.Idled:Connect(function()
		if UNC.vuser then
			pcall(function()
				VirtualUser:CaptureController()
				VirtualUser:ClickButton2(Vector2.new())
			end)
		end
	end)
	pcall(function()
		if getgenv().__SIGMA_AntiAfkHopBlocked then return end
		for _, d in ipairs(ReplicatedStorage:GetDescendants()) do
			if d.Name == "RequestHop" and (d:IsA("RemoteEvent") or d:IsA("BindableEvent")) then
				if type(d.Fire) == "function" then d.Fire = function() end end
				getgenv().__SIGMA_AntiAfkHopBlocked = true
			end
		end
	end)
	task.spawn(function()
		while isActive() and STATE.antiAfkRunId == myAfk and HUB.ANTI_AFK do
			task.wait(HUB.ANTI_AFK_JUMP)
			if not (isActive() and STATE.antiAfkRunId == myAfk and HUB.ANTI_AFK) then break end
			local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
			if hum then pcall(function() hum.Jump = true end) end
		end
	end)
end

function refreshHubServices()
	syncCfg()
	if HUB.ANTI_AFK then setupAntiAfk() else disableAntiAfk() end
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
	-- QUEST.AUTO / QUEST.EXPERTISE: chỉ đổi qua setAutoQuest / setAutoExpertise (tránh WindUI config ghi đè)
	QUEST.PICK = normalizeQuestPick(cfg.QuestPick)
	HUB.AUTO_SPAWN = cfg.AutoSpawn ~= false
	HUB.ANTI_AFK = cfg.AntiAfk ~= false
	HUB.HIDE_NAME = cfg.HideName ~= false
	SAM.ON = cfg.AutoClaimSam == true
	COMPASS.DROP_ON = cfg.AutoDropCompass == true
	COMPASS.FIND_ON = cfg.AutoFindSam == true
	SKILL.ON = cfg.AutoSkill == true
	SKILL.HOLD_SEC = tonumber(cfg.SkillHoldSec) or 0.5
	if not COMPASS.FIND_ON then
		stopCompassFindLoop()
	else
		refreshCompassFindLoop()
	end
	if not SKILL.ON then
		stopSkillLoop()
	end
	REJOIN.ON = cfg.AutoWhitelistRejoin == true
	CACHE.AUTO_CONSUME = cfg.AutoUseConsumables ~= false
	CACHE.AUTO_DROP = cfg.AutoCacheDrop == true
	HAKI.AUTO_KEN = cfg.AutoKenbunshoku == true
	HAKI.AUTO_BUSO = cfg.AutoBusoshoku == true
	HAKI.FAST = cfg.FastHaki == true
	RAYLEIGH.ON = cfg.AutoRayleigh == true
	AFFINITY.ON = cfg.AutoAffinity == true
	AFFINITY.TARGETS = affinityTargetsFromCfg(cfg)
	if not AFFINITY.ON then
		stopAffinityLoop()
	end
	if not HAKI.FAST then
		STATE.hakiFastRunning = false
		STATE.hakiWasFull = false
		hakiClearDrainWatch()
		if hakiReleaseFarm then hakiReleaseFarm() end
	end
	if not RAYLEIGH.ON then
		RAYLEIGH._meditateTrack = nil
	end
	if not QUEST.EXPERTISE then
		clearCollectSweep()
	end
	if not STATE.cooking then
		STATE.pause = false
	end
end

function isGrappleTool(inst)
	if not inst or not inst:IsA("Tool") then return false end
	local n = string.lower(inst.Name)
	for _, t in ipairs(GRAPPLE.TOKENS) do
		if string.find(n, t, 1, true) then return true end
	end
	return false
end

function deleteGrappleTool(inst)
	if not isGrappleTool(inst) then return end
	task.defer(function()
		if inst and inst.Parent then pcall(function() inst:Destroy() end) end
	end)
end

function dropGrappleTools()
	local now = os.clock()
	if STATE.lastGrappleDrop and now - STATE.lastGrappleDrop < GRAPPLE.DROP_INTERVAL then return end
	STATE.lastGrappleDrop = now
	local function scan(parent)
		if not parent then return end
		for _, c in ipairs(parent:GetChildren()) do deleteGrappleTool(c) end
	end
	scan(player.Character)
	scan(player:FindFirstChild("Backpack"))
end

function destroySeat(inst)
	if inst and inst:IsA("Seat") then
		pcall(function() inst:Destroy() end)
	end
end

function setupGrappleCleaner()
	local old = getgenv().__SIGMA_GrappleConns
	if old then
		for _, cn in ipairs(old) do pcall(function() cn:Disconnect() end) end
	end
	local conns = {}
	local function onTool(inst) deleteGrappleTool(inst) end
	local function watch(container)
		if not container then return end
		for _, c in ipairs(container:GetChildren()) do onTool(c) end
		table.insert(conns, container.ChildAdded:Connect(onTool))
	end
	for _, d in ipairs(workspace:GetDescendants()) do destroySeat(d) end
	table.insert(conns, workspace.DescendantAdded:Connect(function(d)
		task.defer(function() destroySeat(d) end)
	end))
	watch(player:FindFirstChild("Backpack"))
	watch(player.Character)
	table.insert(conns, player.CharacterAdded:Connect(function(char)
		task.wait(0.3)
		watch(char)
		watch(player:FindFirstChild("Backpack"))
	end))
	getgenv().__SIGMA_GrappleConns = conns
end

function statLevel(name)
	local d = getData()
	local st = d and d.Stats and d.Stats[name]
	return (type(st) == "table" and tonumber(st.Level)) or 0
end

function getBeri()
	local d = getData()
	return d and d.Stats and tonumber(d.Stats.Beri) or 0
end

function hasDance(name)
	local d = getData()
	return d and type(d.Dances) == "table" and d.Dances[name] == true
end

function mobLevelFromName(name)
	local s = tostring(name or "")
	local lv = string.match(s, "[Ll][Vv][^%d]*(%d+)")
	if not lv then lv = string.match(s, "%[(%d+)%]") end
	if not lv then lv = string.match(s, "%s(%d+)%s*$") end
	return tonumber(lv)
end

function getSpecialWeapons()
	local d = getData()
	if not d or not d.Weapons then return nil end
	local tbl = d.Weapons.Special or d.Weapons.special
	if type(tbl) == "table" then return tbl end
	for key, val in pairs(d.Weapons) do
		if type(val) == "table" and string.lower(tostring(key)) == "special" then
			return val
		end
	end
	return nil
end

function specialSkillUnlocked(skillName)
	local special = getSpecialWeapons()
	if not special then return false end
	local want = string.lower(tostring(skillName or ""))
	for key, val in pairs(special) do
		if val == true then
			local low = string.lower(tostring(key))
			if low == want then return true end
			if want == "observation" and (string.find(low, "observ", 1, true) or string.find(low, "ken", 1, true)) then
				return true
			end
			if want == "haki" and (string.find(low, "haki", 1, true) or string.find(low, "buso", 1, true) or string.find(low, "armament", 1, true)) then
				return true
			end
		end
	end
	return false
end

function hakiAbilityUnlocked(skillName)
	local d = getData()
	if not d then return false end
	local abilities = d.Abilities
	local ab = abilities and (abilities[skillName] or abilities[string.lower(tostring(skillName))])
	if type(ab) == "table" then
		if ab.Unlocked == true then return true end
		if tonumber(ab.Level) and tonumber(ab.Level) > 0 then return true end
	end
	if skillName == "Haki" and statLevel("Haki") > 0 then return true end
	if specialSkillUnlocked(skillName) then return true end
	local kb = d.Keybinds
	if kb and kb[skillName] then return true end
	if skillName == "Observation" and kb then
		if kb.Ken or kb.Kenbun or kb.Kenbunshoku then return true end
	end
	if skillName == "Haki" and kb then
		if kb.Buso or kb.Armament or kb.Busoshoku then return true end
	end
	local char = player.Character
	if skillName == "Observation" and char and char:GetAttribute("Observation") ~= nil then return true end
	if skillName == "Haki" and char and char:GetAttribute("Haki") ~= nil then return true end
	return false
end

function normalizeSkillKeybind(raw)
	local key = tostring(raw or "")
	if key == "" or key == "Unknown" or key == "None" or key == "-" then return nil end
	local alias = {
		["Left Control"] = "LeftControl",
		["Left Alt"] = "LeftAlt",
		["Left Shift"] = "LeftShift",
		["Right Shift"] = "RightShift",
	}
	if alias[key] then return alias[key] end
	if #key == 1 then return string.upper(key) end
	key = key:gsub("%s+", "")
	if #key == 1 then return string.upper(key) end
	return key
end

function getHakiActionKey(skillName)
	local d = getData()
	local kb = d and d.Keybinds
	local raw = kb and kb[skillName]
	if not raw and skillName == "Observation" and kb then
		raw = kb.Ken or kb.Kenbun or kb.Kenbunshoku
	end
	if not raw and skillName == "Haki" and kb then
		raw = kb.Buso or kb.Armament or kb.Busoshoku
	end
	local key = normalizeSkillKeybind(raw)
	if not key then
		if skillName == "Observation" then key = "E" end
		if skillName == "Haki" then key = "Q" end
	end
	return key
end

function actionToKeyCode(action)
	local a = tostring(action or "")
	if a == "" or a == "MouseLeftButton" or a == "MouseRightButton" or a == "Touch" then return nil end
	local ok, kc = pcall(function() return Enum.KeyCode[a] end)
	if ok and kc and kc ~= Enum.KeyCode.Unknown then return kc end
	return nil
end

function pressKeyAction(action, hold)
	if not UNC.vim then return false end
	local kc = actionToKeyCode(action)
	if not kc then return false end
	hold = tonumber(hold) or 0.03
	local ok = pcall(function()
		VirtualInputManager:SendKeyEvent(true, kc, false, game)
		task.wait(hold)
	end)
	pcall(function()
		VirtualInputManager:SendKeyEvent(false, kc, false, game)
	end)
	return ok
end

function skillReleaseKey()
	skillReleaseAllKeys()
end

function skillReleaseAllKeys()
	if not UNC.vim then
		SKILL._keysDown = {}
		SKILL._keyDown = nil
		return
	end
	for key in pairs(SKILL._keysDown) do
		local kc = actionToKeyCode(key)
		if kc then
			pcall(function()
				VirtualInputManager:SendKeyEvent(false, kc, false, game)
			end)
		end
	end
	SKILL._keysDown = {}
	SKILL._keyDown = nil
end

function skillHoldSec()
	local cfg = getgenv().SigmaFishConfig or {}
	local n = tonumber(cfg.SkillHoldSec)
	if n ~= nil and n >= 0 then return n end
	return tonumber(SKILL.HOLD_SEC) or 0.5
end

function skillContext(mob)
	local hrp = getHRP()
	if not hrp then return nil end
	local cam = workspace.CurrentCamera
	local camCf = (cam and cam.CFrame) or hrp.CFrame
	local cf = hrp.CFrame
	local target = nil
	if mob and mob.Parent then
		target = mob:FindFirstChild("HumanoidRootPart") or mob:FindFirstChildWhichIsA("BasePart", true)
	end
	return {
		RayCFrame = cf,
		CameraCFrame = camCf,
		MouseCFrame = cf,
		RayCFrameIA = cf,
	}, target
end

function normalizeSkillKeys(picked)
	local out, seen = {}, {}
	if type(picked) ~= "table" then return out end
	local function add(raw)
		local k = string.upper(tostring(raw or ""))
		k = string.gsub(k, "^%s+", "")
		k = string.gsub(k, "%s+$", "")
		if #k == 1 and not seen[k] then
			seen[k] = true
			out[#out + 1] = k
		end
	end
	for _, v in ipairs(picked) do
		if type(v) == "string" or type(v) == "number" then add(v) end
	end
	for k, v in pairs(picked) do
		if type(k) == "string" then
			if v == true then add(k)
			elseif type(v) == "string" then add(v) end
		end
	end
	return out
end

function skillActiveKeys()
	local cfg = getgenv().SigmaFishConfig or {}
	return normalizeSkillKeys(cfg.SkillKeys)
end

function pressSkillKeysBatch(keys)
	if not UNC.vim or type(keys) ~= "table" or #keys < 1 then return false end
	skillReleaseAllKeys()
	local hold = skillHoldSec()
	local pressed = 0
	for _, key in ipairs(keys) do
		if not SKILL.ON or not isActive() then break end
		local kc = actionToKeyCode(key)
		if kc then
			pcall(function()
				VirtualInputManager:SendKeyEvent(true, kc, false, game)
			end)
			SKILL._keysDown[key] = true
			pressed += 1
		end
	end
	if pressed < 1 then return false end
	pcall(function() task.wait(hold) end)
	skillReleaseAllKeys()
	return true
end

function stepAutoSkillOnce()
	pressSkillKeysBatch(skillActiveKeys())
end

function stopSkillLoop()
	getgenv().__SIGMA_SKILL_LOOP = false
	skillReleaseAllKeys()
end

function refreshSkillLoop()
	getgenv().__SIGMA_SKILL_LOOP = false
	if not (SKILL.ON and isActive()) then return end
	if #skillActiveKeys() < 1 then return end
	local runId = (getgenv().__SIGMA_SKILL_RUN or 0) + 1
	getgenv().__SIGMA_SKILL_RUN = runId
	getgenv().__SIGMA_SKILL_LOOP = true
	task.spawn(function()
		while getgenv().__SIGMA_SKILL_LOOP and getgenv().__SIGMA_SKILL_RUN == runId
			and SKILL.ON and isActive() do
			local keys = skillActiveKeys()
			if #keys < 1 then break end
			stepAutoSkillOnce()
		end
		if getgenv().__SIGMA_SKILL_RUN == runId then
			getgenv().__SIGMA_SKILL_LOOP = false
		end
		skillReleaseAllKeys()
	end)
end

function pressSkillKey(key)
	return pressSkillKeysBatch({ key })
end

function pressHakiSkill(skillName)
	local key = getHakiActionKey(skillName)
	local viaVim = key and pressKeyAction(key, 0.03)
	if viaVim then
		hakiLog("press:" .. skillName, string.format("pressed %s via VIM key=%s", skillName, tostring(key)), 2)
		return true
	end
	local ctx, target = skillContext()
	if not ctx then return false end
	local ok = false
	if key then
		ok = exec("SkillCaller", { key, ctx, target, "Start" })
			or exec("SkillCaller", { key, ctx, target, "End" })
	end
	if not ok then
		ok = exec("SkillCaller", { skillName, ctx, target, "Start" })
	end
	hakiLog("press:" .. skillName, string.format(
		"press %s key=%s vim=%s skillCaller=%s vimAvail=%s",
		skillName, tostring(key), tostring(viaVim), tostring(ok), tostring(UNC.vim)
	), 2)
	return ok
end

function readHakiBar()
	local cap = math.max(1, statLevel("Haki") + 50)
	local amountAttr = tonumber(player:GetAttribute("HakiAmount"))
	if amountAttr == nil then
		local char = player.Character
		amountAttr = tonumber(char and char:GetAttribute("HakiAmount"))
	end
	if amountAttr ~= nil then
		local r = math.clamp(amountAttr / cap, 0, 1)
		return r, amountAttr, cap
	end
	local pg = player:FindFirstChild("PlayerGui")
	local hb = pg and pg:FindFirstChild("HealthBar")
	local frame = hb and hb:FindFirstChild("Frame")
	local haki = frame and frame:FindFirstChild("Haki")
	local fill = haki and haki:FindFirstChild("Frame")
	if fill and fill:IsA("Frame") then
		local r = math.clamp(tonumber(fill.Size.X.Scale) or 0, 0, 1)
		return r, math.floor(r * cap + 0.5), cap
	end
	return nil, nil, cap
end

function hakiStopLevel()
	local cfg = getgenv().SigmaFishConfig or {}
	local stop = tonumber(cfg.HakiStopLevel)
	if stop == nil then stop = HAKI.STOP_LEVEL end
	return stop
end

function hakiFarmStoppedByLevel()
	local stop = hakiStopLevel()
	if not stop or stop <= 0 then return false end
	return statLevel("Haki") >= stop
end

function sampleAliveMobNames(limit)
	limit = limit or 6
	local names = {}
	for _, mob in ipairs(getAliveEnemies()) do
		if #names >= limit then break end
		names[#names + 1] = mob.Name
	end
	return #names > 0 and table.concat(names, ", ") or "(none)"
end

function isCaveDemonForHaki(mob)
	local n = normMob(mob.Name)
	if string.find(n, "cave", 1, true) and string.find(n, "demon", 1, true) then
		if string.find(n, "weakened", 1, true) then return true end
		local lv = mobLevelFromName(mob.Name)
		if lv and lv < HAKI.MIN_MOB_LEVEL then return false end
		return true
	end
	if string.find(n, "demon", 1, true) then
		local lv = mobLevelFromName(mob.Name)
		if lv and lv >= HAKI.MIN_MOB_LEVEL then return true end
	end
	return false
end

function findHakiFarmMob()
	local hrp = getHRP()
	local candidates = {}
	for _, mob in ipairs(getAliveEnemies()) do
		if isCaveDemonForHaki(mob) then
			local pos = getPos(mob)
			if pos then
				candidates[#candidates + 1] = { mob = mob, pos = pos, pri = string.find(normMob(mob.Name), "cave", 1, true) and 2 or 1 }
			end
		end
	end
	if #candidates < 1 then return nil end
	table.sort(candidates, function(a, b)
		local da = hrp and (hrp.Position - a.pos).Magnitude or math.huge
		local db = hrp and (hrp.Position - b.pos).Magnitude or math.huge
		if a.pri ~= b.pri then return a.pri > b.pri end
		return da < db
	end)
	return candidates[1].mob
end

function findCaveDemonClusterTarget()
	local hrp = getHRP()
	local candidates = {}
	for _, mob in ipairs(getAliveEnemies()) do
		if isCaveDemonForHaki(mob) then
			local pos = getPos(mob)
			if pos then table.insert(candidates, { mob = mob, pos = pos }) end
		end
	end
	if #candidates < 1 then return findHakiFarmMob() end
	local best, bestCrowd, bestDist = nil, -1, math.huge
	for i, a in ipairs(candidates) do
		local crowd = 0
		for j, b in ipairs(candidates) do
			if i ~= j and (a.pos - b.pos).Magnitude <= HAKI.CLUSTER_RADIUS then crowd += 1 end
		end
		local d = hrp and (hrp.Position - a.pos).Magnitude or 0
		if crowd > bestCrowd or (crowd == bestCrowd and d < bestDist) then
			best, bestCrowd, bestDist = a.mob, crowd, d
		end
	end
	return best
end

function BRING.zeroVel(part)
	if not part then return end
	pcall(function()
		part.AssemblyLinearVelocity = Vector3.zero
		part.AssemblyAngularVelocity = Vector3.zero
	end)
end

function BRING._restoreNoclip()
	for part, was in pairs(BRING.savedCol) do
		if part and part.Parent then pcall(function() part.CanCollide = was end) end
	end
	BRING.savedCol = {}
end

function BRING._applyNoclip(on)
	local char = player.Character
	if not char then return end
	if not on then BRING._restoreNoclip(); return end
	for _, p in ipairs(char:GetDescendants()) do
		if p:IsA("BasePart") and BRING.savedCol[p] == nil then
			BRING.savedCol[p] = p.CanCollide
			pcall(function() p.CanCollide = false end)
		end
	end
end

function BRING.releaseMobHold(mob)
	local entry = BRING.mobHolds[mob]
	if not entry then return end
	BRING.mobHolds[mob] = nil
	local part = entry.part
	if part and part.Parent then pcall(function() part.Anchored = false end) end
	local hum = mob:FindFirstChildOfClass("Humanoid")
	if hum then pcall(function() hum.PlatformStand = false; hum.AutoRotate = true end) end
end

function BRING.releaseAllMobHolds()
	for mob in pairs(BRING.mobHolds) do BRING.releaseMobHold(mob) end
	BRING.mobHolds = {}
end

function BRING.releaseHold()
	BRING.holdActive = false
	BRING.holdCF = nil
	BRING.releaseAllMobHolds()
	local hrp = getHRP()
	if hrp then pcall(function() hrp.Anchored = false end) end
	local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if hum then pcall(function() hum.AutoRotate = true; hum.PlatformStand = false end) end
	if BRING.HOLD_NOCLIP then BRING._applyNoclip(false) end
end

function BRING.teleportToCF(cf)
	local hrp = getHRP()
	if not hrp or not cf then return false end
	if BRING.holdActive then
		BRING.holdActive = false
		pcall(function() hrp.Anchored = false end)
	end
	pcall(function() hrp.CFrame = cf end)
	BRING.zeroVel(hrp)
	BRING.holdCF = cf
	return true
end

function BRING.lockAnchorAt(cf)
	if not cf or not BRING.HOLD then BRING.releaseHold(); return false end
	local hrp = getHRP()
	if not hrp then return false end
	BRING.holdCF = cf
	pcall(function() hrp.CFrame = cf end)
	BRING.zeroVel(hrp)
	if BRING.HOLD_ANCHOR then pcall(function() hrp.Anchored = true end) end
	BRING.holdActive = true
	local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if hum then pcall(function() hum.AutoRotate = false; hum.PlatformStand = false end) end
	if BRING.HOLD_NOCLIP then BRING._applyNoclip(true) end
	BRING.ensureHoldLoop()
	return true
end

function BRING.clusterAtHead(anchorPos, index)
	local center = anchorPos + Vector3.new(0, BRING.HEAD_Y + (index - 1) * BRING.STACK_Y, 0)
	if BRING.JITTER > 0 then
		local a = index * 2.399963
		local r = BRING.JITTER * (0.3 + (index % 4) * 0.15)
		center = center + Vector3.new(math.cos(a) * r, 0, math.sin(a) * r)
	end
	return CFrame.new(center)
end

function BRING.clusterAtFront(hrp, index)
	local pull = math.max(0.4, BRING.FRONT_DIST - BRING.FRONT_PUSH)
	local spread = (index - 1) * 0.42
	local xOff = math.sin(spread) * BRING.FRONT_SPREAD * 0.45
	local zOff = -(pull + math.cos(spread) * 0.15)
	local center = (hrp.CFrame * CFrame.new(xOff, BRING.FRONT_UP + (index - 1) * BRING.STACK_Y, zOff)).Position
	if BRING.JITTER > 0 then
		local a = index * 2.399963
		local r = BRING.JITTER * (0.25 + (index % 3) * 0.12)
		center = center + Vector3.new(math.cos(a) * r, 0, math.sin(a) * r)
	end
	return CFrame.new(center, hrp.Position)
end

function BRING.clusterCF(hrp, index)
	if BRING.MODE == "head" then return BRING.clusterAtHead(hrp.Position, index) end
	return BRING.clusterAtFront(hrp, index)
end

function BRING.mobRoot(mob)
	if not mob then return nil end
	return mob:FindFirstChild("HumanoidRootPart") or mob:FindFirstChildWhichIsA("BasePart", true)
end

function BRING.applyMobHold(mob)
	local entry = BRING.mobHolds[mob]
	if not entry then return end
	if not mob.Parent then BRING.releaseMobHold(mob); return end
	local hum = mob:FindFirstChildOfClass("Humanoid")
	if not hum or hum.Health <= 0 then BRING.releaseMobHold(mob); return end
	local hrp = getHRP()
	local part = entry.part
	if not hrp or not part or not part.Parent then return end
	local cf = BRING.clusterCF(hrp, entry.index)
	pcall(function()
		if mob.PrimaryPart then mob:SetPrimaryPartCFrame(cf) else part.CFrame = cf end
	end)
	if not BRING.MOB_SOFT then BRING.zeroVel(part) end
	if BRING.MOB_ANCHOR then pcall(function() part.Anchored = true end) end
	if not BRING.MOB_SOFT then
		pcall(function() hum.AutoRotate = false; hum.WalkSpeed = 0; hum.PlatformStand = true end)
	end
end

function BRING.registerMobHold(mob, index)
	if not BRING.MOB_HOLD or not mob or not index then return end
	local part = BRING.mobRoot(mob)
	if not part then return end
	BRING.mobHolds[mob] = { index = index, part = part }
	BRING.applyMobHold(mob)
	BRING.ensureHoldLoop()
end

BRING.tickMobHolds = LPH_NO_VIRTUALIZE(function()
	if not next(BRING.mobHolds) then return end
	local kept = {}
	for mob in pairs(BRING.mobHolds) do
		if mob.Parent then
			local hum = mob:FindFirstChildOfClass("Humanoid")
			if hum and hum.Health > 0 then
				BRING.applyMobHold(mob)
				kept[mob] = true
			end
		end
		if not kept[mob] then BRING.releaseMobHold(mob) end
	end
end)

function BRING.setHold(cf)
	return BRING.lockAnchorAt(cf)
end

BRING.tickHold = LPH_NO_VIRTUALIZE(function()
	if not BRING.holdActive or not BRING.holdCF then return end
	local hrp = getHRP()
	if not hrp then return end
	pcall(function() hrp.CFrame = BRING.holdCF end)
	BRING.zeroVel(hrp)
	if BRING.HOLD_ANCHOR then pcall(function() hrp.Anchored = true end)
	else pcall(function() hrp.Anchored = false end) end
end)

function BRING.ensureHoldLoop()
	if getgenv().__SIGMA_BRING_HOLD_CONN then return end
	getgenv().__SIGMA_BRING_HOLD_CONN = RunService.Heartbeat:Connect(LPH_NO_VIRTUALIZE(function()
		if not isActive() or not HAKI.FAST then
			if BRING.holdActive or next(BRING.mobHolds) then BRING.releaseHold() end
			return
		end
		if BRING.holdActive then BRING.tickHold() end
		if next(BRING.mobHolds) then BRING.tickMobHolds() end
	end))
end

function BRING.tpAtMob(model)
	local mobRoot = model and BRING.mobRoot(model)
	if not mobRoot then return false end
	local cf = CFrame.new(mobRoot.Position)
	if not BRING.teleportToCF(cf) then return false end
	task.wait(0.06)
	local hrp = getHRP()
	if not hrp then return false end
	if (hrp.Position - mobRoot.Position).Magnitude > 10 then return false end
	return BRING.lockAnchorAt(cf)
end

function BRING.tpNearMob(model)
	local hrp = getHRP()
	local mobRoot = model and BRING.mobRoot(model)
	local pos = mobRoot and mobRoot.Position or getPos(model)
	if not hrp or not pos then return false end
	local cf
	if BRING.MODE == "head" then
		local y = pos.Y + BRING.UNDER_Y
		if y <= 209.5 then y = HAKI.MIN_Y end
		cf = CFrame.new(Vector3.new(pos.X, y, pos.Z), pos)
	else
		local facing = mobRoot and mobRoot.CFrame.LookVector or Vector3.new(0, 0, 1)
		facing = Vector3.new(facing.X, 0, facing.Z)
		if facing.Magnitude < 0.1 then facing = Vector3.new(0, 0, 1) else facing = facing.Unit end
		local standDist = math.max(0.3, BRING.FRONT_DIST - BRING.PLAYER_PUSH)
		local standPos = pos + facing * standDist + Vector3.new(0, BRING.FRONT_UP, 0)
		if standPos.Y <= 209.5 then standPos = Vector3.new(standPos.X, HAKI.MIN_Y, standPos.Z) end
		cf = CFrame.new(standPos, Vector3.new(pos.X, standPos.Y, pos.Z))
	end
	pcall(function() hrp.CFrame = cf end)
	BRING.zeroVel(hrp)
	BRING.setHold(cf)
	return true
end

function BRING.tpUnderMob(model)
	return BRING.tpNearMob(model)
end

function BRING.moveMob(mob, targetCF, index)
	local part = BRING.mobRoot(mob)
	if not part then return false end
	local ok = pcall(function()
		if mob.PrimaryPart then mob:SetPrimaryPartCFrame(targetCF) else part.CFrame = targetCF end
	end)
	if not ok then pcall(function() part.CFrame = targetCF end) end
	if not BRING.MOB_SOFT then BRING.zeroVel(part) end
	if index then BRING.registerMobHold(mob, index) end
	return true
end

function BRING.xzDistance(a, b)
	local dx, dz = a.X - b.X, a.Z - b.Z
	return math.sqrt(dx * dx + dz * dz)
end

function BRING.mobPassesNearFilter(mob, opts)
	opts = opts or {}
	if opts.haki and not isCaveDemonForHaki(mob) then return false end
	if opts.filter and not opts.filter(mob) then return false end
	return true
end

function BRING.stopNearPull()
	getgenv().__SIGMA_HAKI_NEAR_PULL_ACTIVE = false
	BRING.nearFarmOpts = nil
end

function BRING.startNearPull(opts)
	if not BRING.NEAR_PULL then return end
	getgenv().__SIGMA_HAKI_NEAR_PULL_ACTIVE = true
	BRING.nearFarmOpts = opts
	BRING.ensureNearPullLoop()
end

function BRING.pullMobsInRadius(opts)
	opts = opts or BRING.nearFarmOpts
	if not opts then return 0 end
	local hrp = getHRP()
	local alive = getAliveRoot()
	if not hrp or not alive then return 0 end
	local radius = opts.radius or BRING.CLUSTER_RADIUS
	local stackPos = hrp.CFrame * CFrame.new(0, 0, -BRING.CLUSTER_STACK_DIST)
	local held, nextIdx = {}, 0
	for mob, entry in pairs(BRING.mobHolds) do
		held[mob] = true
		if entry and entry.index then nextIdx = math.max(nextIdx, entry.index) end
	end
	local added = 0
	for _, mob in ipairs(alive:GetChildren()) do
		if not held[mob] and BRING.mobPassesNearFilter(mob, opts) then
			local root = mob:FindFirstChild("HumanoidRootPart")
			local hum = mob:FindFirstChildOfClass("Humanoid")
			if root and hum and hum.Health > 0
				and BRING.xzDistance(root.Position, hrp.Position) <= radius then
				for _, v in ipairs(mob:GetDescendants()) do
					if v:IsA("BasePart") then
						pcall(function() v.CanCollide = false; v.Massless = true end)
					end
				end
				pcall(function()
					root.CFrame = stackPos
					root.AssemblyLinearVelocity = Vector3.zero
					root.AssemblyAngularVelocity = Vector3.zero
				end)
				nextIdx += 1
				BRING.registerMobHold(mob, nextIdx)
				table.insert(BRING.nearBatch, mob)
				held[mob] = true
				added += 1
			end
		end
	end
	return added
end

function BRING.ensureNearPullLoop()
	if getgenv().__SIGMA_HAKI_NEAR_PULL_LOOP then return end
	getgenv().__SIGMA_HAKI_NEAR_PULL_LOOP = true
	task.spawn(function()
		while getgenv().__SIGMA_HUB_RUNNING do
			if getgenv().__SIGMA_HAKI_NEAR_PULL_ACTIVE and BRING.nearFarmOpts
				and HAKI.FAST and isActive() then
				pcall(function() BRING.pullMobsInRadius(BRING.nearFarmOpts) end)
			end
			task.wait(BRING.NEAR_PULL_IV)
		end
		getgenv().__SIGMA_HAKI_NEAR_PULL_LOOP = false
		getgenv().__SIGMA_HAKI_NEAR_PULL_ACTIVE = false
	end)
end

function BRING.stackClusterNear(seedMob, opts)
	opts = opts or {}
	local hrp = getHRP()
	if not hrp then return 0 end
	BRING.releaseHold()
	local seedRoot = seedMob and BRING.mobRoot(seedMob)
	if seedRoot then
		pcall(function()
			hrp.CFrame = CFrame.new(
				seedRoot.Position.X,
				seedRoot.Position.Y + BRING.CLUSTER_CENTER_Y,
				seedRoot.Position.Z
			)
		end)
		BRING.zeroVel(hrp)
		task.wait(BRING.CLUSTER_TP_WAIT)
	end
	local alive = getAliveRoot()
	if not alive then return 0 end
	local radius = opts.radius or BRING.CLUSTER_RADIUS
	local mobs, totalPos, count = {}, Vector3.zero, 0
	for _, mob in ipairs(alive:GetChildren()) do
		if BRING.mobPassesNearFilter(mob, opts) then
			local root = mob:FindFirstChild("HumanoidRootPart")
			local hum = mob:FindFirstChildOfClass("Humanoid")
			if root and hum and hum.Health > 0
				and BRING.xzDistance(root.Position, hrp.Position) <= radius then
				table.insert(mobs, { mob = mob, root = root })
				totalPos += root.Position
				count += 1
			end
		end
	end
	if count == 0 then
		if seedMob then BRING.tpUnderMob(seedMob) end
		return 0
	end
	local center = totalPos / count
	pcall(function()
		hrp.CFrame = CFrame.new(center.X, center.Y + BRING.CLUSTER_CENTER_Y, center.Z)
	end)
	BRING.zeroVel(hrp)
	BRING.setHold(hrp.CFrame)
	task.wait(BRING.CLUSTER_STACK_WAIT)
	local stackPos = hrp.CFrame * CFrame.new(0, 0, -BRING.CLUSTER_STACK_DIST)
	BRING.nearBatch = {}
	for i, data in ipairs(mobs) do
		local mob, root = data.mob, data.root
		for _, v in ipairs(mob:GetDescendants()) do
			if v:IsA("BasePart") then
				pcall(function() v.CanCollide = false; v.Massless = true end)
			end
		end
		pcall(function()
			root.CFrame = stackPos
			root.AssemblyLinearVelocity = Vector3.zero
			root.AssemblyAngularVelocity = Vector3.zero
		end)
		BRING.registerMobHold(mob, i)
		table.insert(BRING.nearBatch, mob)
	end
	return count
end

function BRING.run(opts)
	opts = opts or {}
	local hrp = getHRP()
	if not hrp then return 0 end
	local list = {}
	for _, mob in ipairs(getAliveEnemies()) do
		if opts.haki then
			if isCaveDemonForHaki(mob) then
				local m = BRING.mobRoot(mob)
				if m then
					local d = (hrp.Position - m.Position).Magnitude
					if d <= BRING.RADIUS then table.insert(list, { mob = mob, dist = d }) end
				end
			end
		else
			local m = BRING.mobRoot(mob)
			if m then
				local d = (hrp.Position - m.Position).Magnitude
				if d <= BRING.RADIUS then table.insert(list, { mob = mob, dist = d }) end
			end
		end
	end
	table.sort(list, function(a, b) return a.dist < b.dist end)
	local n = math.min(#list, BRING.MAX)
	local kept = {}
	if not opts.haki then BRING.nearBatch = {} end
	for i = 1, n do
		kept[list[i].mob] = true
		if not opts.haki then table.insert(BRING.nearBatch, list[i].mob) end
		BRING.moveMob(list[i].mob, BRING.clusterCF(hrp, i), i)
	end
	for mob in pairs(BRING.mobHolds) do
		if not kept[mob] then BRING.releaseMobHold(mob) end
	end
	return n
end

function hakiBringOpts()
	return { haki = true, radius = BRING.CLUSTER_RADIUS }
end

function hakiReleaseFarm()
	BRING.releaseHold()
	BRING.stopNearPull()
	STATE.hakiHoldMob = nil
	STATE.hakiHoldCF = nil
end

function hakiSetupAnchor(target)
	if not target then return false end
	local mobRoot = BRING.mobRoot(target)
	local hrp = getHRP()
	if not mobRoot or not hrp then return false end
	local cf = CFrame.new(mobRoot.Position)
	if not BRING.teleportToCF(cf) then return false end
	task.wait(0.08)
	hrp = getHRP()
	mobRoot = BRING.mobRoot(target)
	if not hrp or not mobRoot then return false end
	if (hrp.Position - mobRoot.Position).Magnitude > 10 then
		hakiLog("fast:tpfail", string.format("TP miss mob %s dist=%.1f", target.Name,
			(hrp.Position - mobRoot.Position).Magnitude), 2)
		return false
	end
	if not BRING.lockAnchorAt(cf) then return false end
	STATE.hakiHoldCF = BRING.holdCF
	STATE.hakiHoldMob = target
	return true
end

function hakiBringOnly()
	if not BRING.holdActive or not STATE.hakiHoldCF then
		return 0
	end
	BRING.startNearPull(hakiBringOpts())
	local n = BRING.run({ haki = true })
	if BRING.NEAR_PULL then
		n = math.max(n, BRING.pullMobsInRadius(hakiBringOpts()))
	end
	return n
end

function hakiNearHoldMob()
	local hrp = getHRP()
	local pos = STATE.hakiHoldCF and STATE.hakiHoldCF.Position
	if not pos then
		local mob = STATE.hakiHoldMob
		pos = mob and getPos(mob)
	end
	if not hrp or not pos then return false end
	return (hrp.Position - pos).Magnitude <= HAKI.HOLD_RETP_DIST
end

function hakiTryFarmReset()
	hakiClearDrainWatch()
	hakiClearFullSticky()
	BRING.releaseAllMobHolds()
	local target = hakiEnsureTarget()
	if target then
		hakiSetupAnchor(target)
		hakiBringOnly()
		return true
	end
	return false
end

function hakiEnsureTarget()
	local target = STATE.hakiHoldMob
	local hum = target and target:FindFirstChildOfClass("Humanoid")
	if not target or not hum or hum.Health <= 0 then
		local old = target
		target = findCaveDemonClusterTarget()
		if target ~= old then
			STATE.hakiHoldCF = nil
		end
		STATE.hakiHoldMob = target
	end
	return target
end

function hakiFarmBringTarget(target, needAnchor)
	if not target then return nil, 0 end
	local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if hum then pcall(function() hum:UnequipTools() end) end
	if needAnchor or not BRING.holdActive or not STATE.hakiHoldCF then
		if not hakiSetupAnchor(target) then
			return target, 0
		end
	end
	return target, hakiBringOnly()
end

function tpHakiNearMob(mob)
	return BRING.tpAtMob(mob)
end

function tpUnderMob(mob)
	return BRING.tpAtMob(mob)
end

function hakiGoToFarmSpot(forceTp)
	local now = os.clock()
	if not forceTp and (now - (STATE.hakiLastTp or 0)) < HAKI.TP_INTERVAL then return STATE.hakiHoldMob end
	local target = hakiEnsureTarget()
	if target then
		local needAnchor = forceTp or not BRING.holdActive or not STATE.hakiHoldCF
		hakiFarmBringTarget(target, needAnchor)
	else
		hakiLog("fast:nomob", string.format(
			"no farm mob Lv%d+ | Alive=%d | nearby: %s",
			HAKI.MIN_MOB_LEVEL, #getAliveEnemies(), sampleAliveMobNames(8)
		), 5)
	end
	STATE.hakiLastTp = now
	return target
end

function hakiBarLowForRejoin(ratio, amount, cap, pct)
	if pct <= 1 then return true end
	if amount and cap and amount <= math.max(1, math.ceil(cap * 0.01)) then return true end
	return ratio ~= nil and ratio <= HAKI.FAST_EMPTY
end

function hakiClearDrainWatch()
	STATE.hakiDrainAmount = nil
	STATE.hakiDrainSince = nil
end

function hakiClearFullSticky()
	STATE.hakiFullStickySince = nil
end

function hakiFastTanking()
	if not HAKI.FAST then return false end
	local ratio = select(1, readHakiBar())
	if ratio == nil or ratio < HAKI.FULL_RATIO then return false end
	if not BRING.holdActive or not STATE.hakiHoldCF then return false end
	return hakiNearHoldMob()
end

function stepFastHakiEnsureCast()
	if not hakiFastTanking() then return end
	local char = player.Character
	if not char or not hakiAbilityUnlocked("Haki") then return end
	local now = os.clock()
	if char:GetAttribute("Haki") ~= true then
		if now - (STATE.hakiLastFastCast or 0) >= HAKI.SKILL_RETRY then
			STATE.hakiLastFastCast = now
			local ok = pressHakiSkill("Haki")
			hakiLog("fast:cast", string.format("Busoshoku OFF -> press (ok=%s)", tostring(ok)), 2)
		end
	end
	if HAKI.AUTO_KEN and hakiAbilityUnlocked("Observation")
		and char:GetAttribute("Observation") ~= true then
		if now - (STATE.hakiLastKen or 0) >= HAKI.SKILL_RETRY then
			STATE.hakiLastKen = now
			pressHakiSkill("Observation")
		end
	end
end

function hakiFullStuck(ratio, amount, now)
	if amount ~= STATE.hakiLastBarAmount then
		STATE.hakiLastBarAmount = amount
		if ratio < HAKI.FULL_RATIO then
			hakiClearFullSticky()
		end
	end
	if ratio < HAKI.FULL_RATIO or not BRING.holdActive or not hakiNearHoldMob() then
		hakiClearFullSticky()
		return false
	end
	if not STATE.hakiFullStickySince then
		STATE.hakiFullStickySince = now
		return false
	end
	return (now - STATE.hakiFullStickySince) >= HAKI.STUCK_FULL_SEC
end

function hakiDrainStuck(amount, now)
	if amount == nil then
		hakiClearDrainWatch()
		return false
	end
	if STATE.hakiDrainAmount == nil then
		STATE.hakiDrainAmount = amount
		STATE.hakiDrainSince = now
		return false
	end
	if amount < STATE.hakiDrainAmount then
		STATE.hakiDrainAmount = amount
		STATE.hakiDrainSince = now
		return false
	end
	return (now - (STATE.hakiDrainSince or now)) >= HAKI.DRAIN_RESET_SEC
end

function tryHakiRejoin()
	if STATE.hakiFastPending or STATE.rejoinPending then return true end
	STATE.hakiFastPending = true
	STATE.hakiLastRejoin = os.clock()
	STATE.hakiFastRunning = false
	STATE.hakiWasFull = false
	hakiClearDrainWatch()
	hakiClearFullSticky()
	hakiReleaseFarm()
	return sigmaRejoinServer("fast-haki")
end

function stepHakiForceOff()
	local char = player.Character
	if not char then return end
	local fastTank = hakiFastTanking()
	local now = os.clock()
	if not HAKI.AUTO_KEN and not fastTank and char:GetAttribute("Observation") == true then
		if now - (STATE.hakiLastKenOff or 0) >= HAKI.SKILL_RETRY then
			STATE.hakiLastKenOff = now
			pressHakiSkill("Observation")
			hakiLog("ken:off", "Auto Ken OFF -> disable Observation", 2)
		end
	end
	if not HAKI.AUTO_BUSO and not fastTank and char:GetAttribute("Haki") == true then
		if now - (STATE.hakiLastBusoOff or 0) >= HAKI.SKILL_RETRY then
			STATE.hakiLastBusoOff = now
			pressHakiSkill("Haki")
			hakiLog("buso:off", "Auto Buso OFF -> disable Busoshoku", 2)
		end
	end
end

function stepAutoKenbunshoku()
	if not HAKI.AUTO_KEN then return end
	if not isActive() then
		hakiLog("ken:block", "Auto Ken OFF — hub loop not active (isActive=false)", 6)
		return
	end
	if not hakiAbilityUnlocked("Observation") then
		hakiLog("ken:lock", "Observation not unlocked (Abilities/Special/Keybinds)", 8)
		return
	end
	local char = player.Character
	if not char then
		hakiLog("ken:nchar", "no character", 6)
		return
	end
	if char:GetAttribute("Observation") == true then return end
	local now = os.clock()
	if now - (STATE.hakiLastKen or 0) < HAKI.SKILL_RETRY then return end
	STATE.hakiLastKen = now
	local ok = pressHakiSkill("Observation")
	hakiLog("ken:try", string.format("Observation OFF -> press (ok=%s attrNow=%s)", tostring(ok), tostring(char:GetAttribute("Observation"))), 2)
end

function stepAutoBusoshoku()
	if not HAKI.AUTO_BUSO then return end
	if not isActive() then
		hakiLog("buso:block", "Auto Buso OFF — hub loop not active (isActive=false)", 6)
		return
	end
	if not hakiAbilityUnlocked("Haki") then
		hakiLog("buso:lock", "Busoshoku not unlocked (Abilities/Special/Keybinds)", 8)
		return
	end
	local char = player.Character
	if not char then
		hakiLog("buso:nchar", "no character", 6)
		return
	end
	if char:GetAttribute("Haki") == true then return end
	local now = os.clock()
	if now - (STATE.hakiLastBuso or 0) < HAKI.SKILL_RETRY then return end
	STATE.hakiLastBuso = now
	local ok = pressHakiSkill("Haki")
	hakiLog("buso:try", string.format("Haki OFF -> press (ok=%s attrNow=%s)", tostring(ok), tostring(char:GetAttribute("Haki"))), 2)
end

function stepFastHaki()
	if not HAKI.FAST then
		if BRING.holdActive or next(BRING.mobHolds) then hakiReleaseFarm() end
		STATE.hakiFastRunning = false
		STATE.hakiWasFull = false
		hakiClearDrainWatch()
		return false
	end
	if not isActive() then
		hakiLog("fast:block", "Fast Haki — isActive=false", 6)
		return false
	end
	if hakiFarmStoppedByLevel() then
		local lv, stop = statLevel("Haki"), hakiStopLevel()
		updateHakiMaxState()
		hakiLog("fast:max", string.format("Haki Lv %d >= stop %d (set HakiStopLevel=0 to disable)", lv, stop), 15)
		return false
	end
	if not hakiAbilityUnlocked("Haki") then
		hakiLog("fast:lock", "Busoshoku not unlocked", 8)
		return false
	end
	local ratio, amount, cap = readHakiBar()
	if ratio == nil then
		hakiLog("fast:nobar", "cannot read haki bar (attr/ui)", 6)
		return false
	end
	local pct = math.floor(ratio * 100 + 0.5)
	local now = os.clock()
	if (STATE.hakiFastRunning or STATE.hakiWasFull) and hakiBarLowForRejoin(ratio, amount, cap, pct) then
		hakiLog("fast:rejoin", string.format("bar <= %d%% (%d/%d) -> Teleport rejoin", pct, amount or 0, cap or 0), 1)
		return tryHakiRejoin()
	end
	if (STATE.hakiFastRunning or STATE.hakiWasFull)
		and ratio < HAKI.FULL_RATIO
		and not hakiBarLowForRejoin(ratio, amount, cap, pct)
		and BRING.holdActive
		and hakiNearHoldMob()
		and hakiDrainStuck(amount, now) then
		return hakiTryFarmReset()
	end
	if ratio >= HAKI.FULL_RATIO and hakiFullStuck(ratio, amount, now) then
		return hakiTryFarmReset()
	end
	if not ((STATE.hakiFastRunning or STATE.hakiWasFull) and ratio < HAKI.FULL_RATIO) then
		hakiClearDrainWatch()
	end
	local target = hakiEnsureTarget()
	if not target then
		hakiLog("fast:nomob", string.format(
			"no Cave Demon Lv%d+ | Alive=%d | nearby: %s",
			HAKI.MIN_MOB_LEVEL, #getAliveEnemies(), sampleAliveMobNames(8)
		), 5)
		return false
	end
	if ratio >= HAKI.FULL_RATIO then
		STATE.hakiFastRunning = true
		STATE.hakiWasFull = true
		local needAnchor = not BRING.holdActive or not STATE.hakiHoldCF
		local _, brought = hakiFarmBringTarget(target, needAnchor)
		stepFastHakiEnsureCast()
		hakiLog("fast:full", string.format(
			"bar full %d%% (%d/%d) | bring=%d anchor=%s haki=%s mob=%s",
			pct, amount or 0, cap or 0, brought, tostring(BRING.holdActive),
			tostring(player.Character and player.Character:GetAttribute("Haki")), target.Name
		), 3)
		return true
	end
	local needAnchor = not BRING.holdActive or not STATE.hakiHoldCF
	local _, brought = hakiFarmBringTarget(target, needAnchor)
	hakiLog("fast:fill", string.format(
		"fill bar %d%% (%d/%d) | stack+bring=%d anchor=%s mob=%s",
		pct, amount or 0, cap or 0, brought, tostring(BRING.holdActive), target.Name
	), 4)
	return true
end

function questObjectiveByKeyword(q, keyword)
	if not (q and type(q.Objectives) == "table") then return nil, nil end
	local kw = string.lower(tostring(keyword or ""))
	for name, obj in pairs(q.Objectives) do
		if string.find(string.lower(tostring(name)), kw, 1, true) then
			return name, obj
		end
	end
	return nil, nil
end

function rayleighReqMet()
	for stat, lvl in pairs(RAYLEIGH.REQ) do
		if statLevel(stat) < lvl then return false end
	end
	return true
end

function findMeditateAnimId()
	local pg = player:FindFirstChild("PlayerGui")
	local menu = pg and pg:FindFirstChild("Menu")
	local emotes = menu and menu:FindFirstChild("Emotes")
	local frame = emotes and emotes:FindFirstChild("Frame")
	if not frame then return nil end
	for _, b in ipairs(frame:GetDescendants()) do
		if (b:IsA("TextButton") or b:IsA("ImageButton")) and b.Name == RAYLEIGH.MEDITATE then
			local a = b:FindFirstChild("Animation")
			if a and a.Value and a.Value ~= "" then return a.Value end
		end
	end
	return nil
end

function playMeditate()
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not hum then return false end
	if RAYLEIGH._meditateTrack then
		local okp = pcall(function() return RAYLEIGH._meditateTrack.IsPlaying end)
		if okp and RAYLEIGH._meditateTrack.IsPlaying then return true end
	end
	local animId = findMeditateAnimId()
	if not animId then return false end
	local anim = Instance.new("Animation")
	anim.AnimationId = animId
	local ok, track = pcall(function() return hum:LoadAnimation(anim) end)
	if ok and track then
		pcall(function() track.Looped = true; track:Play() end)
		RAYLEIGH._meditateTrack = track
		return true
	end
	return false
end

function rayClaim(qname)
	local model = findNPC("Rayleigh")
	if model then remoteQuestClaim(model, qname) end
end

function getWaterTPPos()
	local w = workspace:FindFirstChild("Water")
	if not w then return nil end
	if w:IsA("BasePart") then return w.Position + Vector3.new(0, -6, 0) end
	local part = w:IsA("Model") and (w.PrimaryPart or w:FindFirstChildWhichIsA("BasePart", true))
		or w:FindFirstChildWhichIsA("BasePart", true)
	if part then return part.Position + Vector3.new(0, -6, 0) end
	return nil
end

function stepSP4Phase(q)
	if not RAYLEIGH.ON or not q or q.Active ~= RAYLEIGH.SP4 then return false end
	if q.Completed == true then
		rayClaim(RAYLEIGH.SP4)
		return true
	end
	local _, dealObj = questObjectiveByKeyword(q, "deal")
	local _, takeObj = questObjectiveByKeyword(q, "take")
	local _, _, dealDone = objectiveProgress(dealObj)
	local _, _, takeDone = objectiveProgress(takeObj)
	if dealDone and takeDone then
		rayClaim(RAYLEIGH.SP4)
		return true
	end
	if dealDone and not takeDone then
		local pos = getWaterTPPos()
		local hrp = getHRP()
		if pos and hrp then
			pcall(function() hrp.CFrame = CFrame.new(pos) end)
			zeroHRPVel(hrp)
		end
		return true
	end
	return false
end

function stepRayleighSP4Farm()
	local q = getQuests()
	if not q or q.Active ~= RAYLEIGH.SP4 or q.Completed == true then return false end
	if stepSP4Phase(q) then return true end
	local mob
	for _, m in ipairs(getAliveEnemies()) do
		local hum = m:FindFirstChildOfClass("Humanoid")
		if hum and hum.Health > 0 then
			mob = m
			break
		end
	end
	if mob then attackBurstOnMob(mob, "pick") end
	return true
end

function rayleighAccept(qn)
	local model = findNPC("Rayleigh")
	if not model then return false end
	return remoteQuestAccept(model, qn)
end

function stepRayleigh()
	if not RAYLEIGH.ON then return false end
	if not isActive() then
		hakiLog("ray:block", "Auto Rayleigh — isActive=false", 6)
		return false
	end
	if not rayleighReqMet() then
		hakiLog("ray:req", string.format(
			"stats too low | Melee=%d Def=%d Sword=%d Sniper=%d (need 500/250/250/250)",
			statLevel("Melee"), statLevel("Defense"), statLevel("Sword"), statLevel("Sniper")
		), 10)
		return false
	end
	local q = getQuests()
	if not q then
		hakiLog("ray:nodata", "no quest data", 6)
		return false
	end
	local active = q.Active
	hakiLog("ray:tick", string.format("active='%s' completed=%s", tostring(active), tostring(q.Completed)), 6)

	if active == "Strange Powers #1" then
		if q.Completed then rayClaim("Strange Powers #1"); return true end
		if hasItem("Old Book") then
			local model = findNPC("Rayleigh")
			if model then remoteQuestDeliver(model, "Old Book", active) end
		else
			local folder = resolvePath(RAYLEIGH.CHESTS)
			if folder then
				for _, spawner in ipairs(folder:GetChildren()) do
					if not isActive() or hasItem("Old Book") then break end
					local chest = spawner:FindFirstChild("TreasureChest")
					local pos = chest and getPos(chest)
					local hrp = getHRP()
					if pos and hrp then
						pcall(function() hrp.CFrame = CFrame.new(pos + Vector3.new(0, 3, 0)) end)
						task.wait(RAYLEIGH.CHEST_WAIT)
					end
				end
			end
		end
		return true
	end

	if active == "Strange Powers #2" then
		if q.Completed then rayClaim("Strange Powers #2"); return true end
		if not hasDance(RAYLEIGH.MEDITATE) then
			if getBeri() >= 1000000 then
				local model = findNPC("Dancer")
				if model then clickNPC(model); exec("DancerBuy", { "BuyDance", model, RAYLEIGH.MEDITATE }) end
			end
			return true
		end
		playMeditate()
		return true
	end

	if active == "Strange Powers #3" then
		if q.Completed then rayClaim("Strange Powers #3"); return true end
		local folder = resolvePath(RAYLEIGH.RINGS)
		if folder then
			for _, ring in ipairs(folder:GetChildren()) do
				if not isActive() then break end
				q = getQuests() or q
				if q.Completed then break end
				local pos = getPos(ring)
				local hrp = getHRP()
				if pos and hrp then
					pcall(function() hrp.CFrame = CFrame.new(pos + Vector3.new(0, 3, 0)) end)
					task.wait(0.35)
				end
			end
		end
		return true
	end

	if active == RAYLEIGH.SP4 then
		return stepRayleighSP4Farm()
	end

	local cd1 = questCooldownRemaining("Strange Powers #1")
	local cd2 = questCooldownRemaining("Strange Powers #2")
	local cd3 = questCooldownRemaining("Strange Powers #3")
	local cd4 = questCooldownRemaining(RAYLEIGH.SP4)
	if cd1 <= 0 then return rayleighAccept("Strange Powers #1") end
	if cd1 > 0 and cd2 <= 0 then return rayleighAccept("Strange Powers #2") end
	if cd2 > 0 and cd3 <= 0 then return rayleighAccept("Strange Powers #3") end
	if cd3 > 0 and cd4 <= 0 and statLevel("Haki") >= RAYLEIGH.SP4_HAKI then
		return rayleighAccept(RAYLEIGH.SP4)
	end
	return false
end

function affinityLog(msg, interval)
end

function affinityTargetsFromCfg(cfg)
	cfg = cfg or getgenv().SigmaFishConfig or {}
	local t = {}
	local map = {
		Melee = cfg.AffinityMelee,
		Sword = cfg.AffinitySword,
		Sniper = cfg.AffinitySniper,
		Defense = cfg.AffinityDefense,
	}
	for stat, raw in pairs(map) do
		local v = tonumber(raw)
		if v and v > 0 then t[stat] = v end
	end
	return t
end

function affinityGetUI()
	local pg = player and player:FindFirstChild("PlayerGui")
	local mf = pg and pg:FindFirstChild("MerchantsFolder")
	return mf and mf:FindFirstChild("AffinityUI")
end

function affinityEnsureSkip(ui)
	if not ui or not AFFINITY.SKIP_ANIM then return false end
	local sv = ui.Frame and ui.Frame.Skip and ui.Frame.Skip:FindFirstChild("SkipAffinity")
	if not sv then return false end
	pcall(function() sv.Value = true end)
	return sv.Value == true
end

function affinityScaleToLevel(s)
	if s <= 0.05 then return nil end
	return (s / 2) + 1
end

function affinityReadUI(panel)
	local aff = {}
	for _, stat in ipairs(AFFINITY.STATS) do
		local row = panel:FindFirstChild(stat)
		local circle = row and row:FindFirstChild("Circle")
		if circle then
			local s = math.max(circle.Size.X.Scale, circle.Size.Y.Scale)
			local lv = affinityScaleToLevel(s)
			if lv then aff[stat] = lv end
		end
	end
	return aff
end

function affinityReadData(dfKey)
	local data = getData()
	local block = data and data[dfKey]
	local raw = block and block.Affinity
	if type(raw) ~= "table" then return nil end
	local aff = {}
	for _, stat in ipairs(AFFINITY.STATS) do
		local v = tonumber(raw[stat])
		if v and v > 0 then aff[stat] = v end
	end
	return next(aff) and aff or nil
end

function affinityMerge(a, b)
	local aff = {}
	for _, stat in ipairs(AFFINITY.STATS) do
		local v = math.max(a and a[stat] or 0, b and b[stat] or 0)
		if v > 0 then aff[stat] = v end
	end
	return aff
end

function affinityRead(panel, dfKey)
	return affinityMerge(affinityReadData(dfKey), affinityReadUI(panel))
end

function affinityReadStable(panel, dfKey)
	if AFFINITY.SKIP_ANIM then return affinityRead(panel, dfKey) end
	local a1 = affinityRead(panel, dfKey)
	task.wait(0.08)
	return affinityMerge(a1, affinityRead(panel, dfKey))
end

function affinityMarkSealed(aff)
	for stat, t in pairs(AFFINITY.TARGETS) do
		if (tonumber(aff[stat]) or 0) + 0.001 >= tonumber(t) then
			AFFINITY.sealed[stat] = true
		end
	end
end

function affinityLockOf(panel, stat)
	local row = panel:FindFirstChild(stat)
	return row and row:FindFirstChild("Lock")
end

function affinityIsLocked(lock)
	return lock and lock.ImageTransparency < 0.35
end

function affinityGetLockedUI(panel)
	local out = {}
	for _, stat in ipairs(AFFINITY.STATS) do
		if affinityIsLocked(affinityLockOf(panel, stat)) then
			table.insert(out, stat)
		end
	end
	return out
end

function affinityParseMoney(text, fallback)
	if not text then return fallback or 0 end
	local n = string.match(text, "([%d,]+)")
	if not n then return fallback or 0 end
	return tonumber((n:gsub(",", ""))) or fallback or 0
end

function affinityRollCost(panel)
	local btn = panel:FindFirstChild("Reroll1")
	if not btn then return 100000 end
	return affinityParseMoney(btn.Text, 100000)
end

function affinityGetBeri(ui)
	local cash = ui and ui.Frame and ui.Frame:FindFirstChild("Cash")
	if cash then
		local b = affinityParseMoney(cash.Text, 0)
		if b > 0 then return b end
	end
	local data = getData()
	return data and data.Stats and tonumber(data.Stats.Beri) or 0
end

function affinityPendingStats(aff)
	local out = {}
	for stat, t in pairs(AFFINITY.TARGETS) do
		local target = tonumber(t)
		local v = tonumber(aff[stat]) or 0
		if AFFINITY.sealed[stat] then
			if v + 0.12 < target then
				AFFINITY.sealed[stat] = nil
				table.insert(out, stat)
			end
		elseif v + 0.001 < target then
			table.insert(out, stat)
		end
	end
	return out
end

function affinitySetLock(panel, stat, on)
	local btn = affinityLockOf(panel, stat)
	if not btn then return end
	if affinityIsLocked(btn) == on then return end
	clickGui(btn)
	if affinityIsLocked(btn) ~= on then
		btn.ImageTransparency = on and 0 or 0.7
	end
	task.wait(AFFINITY.LOCK_WAIT)
end

function affinitySyncLocks(panel, aff, pending)
	local pendingSet = {}
	for _, s in ipairs(pending) do pendingSet[s] = true end
	for _, stat in ipairs(pending) do
		if not AFFINITY.sealed[stat] then
			affinitySetLock(panel, stat, false)
		end
	end
	local toLock = {}
	for stat in pairs(AFFINITY.TARGETS) do
		if AFFINITY.sealed[stat] or (not pendingSet[stat] and (tonumber(aff[stat]) or 0) + 0.001 >= tonumber(AFFINITY.TARGETS[stat])) then
			table.insert(toLock, { stat = stat, v = tonumber(aff[stat]) or 999 })
		end
	end
	table.sort(toLock, function(a, b) return a.v > b.v end)
	for i = 1, math.min(AFFINITY.MAX_LOCKS, #toLock) do
		affinitySetLock(panel, toLock[i].stat, true)
	end
	task.wait(AFFINITY.SYNC_WAIT)
	return affinityGetLockedUI(panel), affinityRollCost(panel)
end

function affinityPanelDfKey(panel, fallback)
	local df = panel:FindFirstChild("DevilFruit")
	if df and df:IsA("StringValue") and df.Value ~= "" then
		return df.Value
	end
	return fallback
end

function affinityGetSlot1(ui, data)
	local frame = ui and ui.Frame
	if not frame then return nil end
	local df2 = data and data.DevilFruit2
	local panel
	if df2 and df2.Name ~= "" then
		panel = frame.Affinities2a
	else
		panel = frame.Affinities
		if not panel then panel = frame.Affinities2a end
	end
	if not panel then return nil end
	local key = affinityPanelDfKey(panel, "DevilFruit1") or "DevilFruit1"
	return { panel = panel, key = key }
end

function affinityOpenUI()
	local ui = affinityGetUI()
	if not ui then return nil end
	if not ui.Enabled then
		ui.Enabled = true
		task.wait(0.1)
	end
	affinityEnsureSkip(ui)
	return ui.Enabled and ui or nil
end

function affinityRoll(panel, dfKey)
	local ui = affinityGetUI()
	local skip = affinityEnsureSkip(ui)
	local locked = affinityGetLockedUI(panel)
	if exec("Affinity", { locked, dfKey, "Beri", skip }) then return true end
	return clickGui(panel:FindFirstChild("Reroll1"))
end

function affinityAffChanged(a, b)
	for stat in pairs(AFFINITY.TARGETS) do
		if math.abs((a[stat] or 0) - (b[stat] or 0)) > 0.035 then
			return true
		end
	end
	return false
end

function affinityWaitRoll(panel, dfKey, before)
	local t0 = os.clock()
	local minWait = AFFINITY.SKIP_ANIM and 0.12 or 0.45
	while getgenv().__SIGMA_AFFINITY_RUN and os.clock() - t0 < AFFINITY.ROLL_WAIT do
		local aff = affinityRead(panel, dfKey)
		if affinityAffChanged(aff, before) and os.clock() - t0 >= minWait then
			task.wait(AFFINITY.STABLE_WAIT)
			return affinityRead(panel, dfKey)
		end
		task.wait(AFFINITY.POLL)
	end
	return affinityReadStable(panel, dfKey)
end

function affinityRunSlot1(entry, ui)
	local key, panel = entry.key, entry.panel
	local rolls = 0
	while getgenv().__SIGMA_AFFINITY_RUN and AFFINITY.ON and rolls < AFFINITY.MAX_ROLLS do
		if not next(AFFINITY.TARGETS) then return true end
		local aff = affinityReadStable(panel, key)
		affinityMarkSealed(aff)
		local pending = affinityPendingStats(aff)
		if #pending == 0 then
			affinityLog(string.format("slot1 done | %s", key), 2)
			return true
		end
		affinitySyncLocks(panel, aff, pending)
		local cost = affinityRollCost(panel)
		if affinityGetBeri(ui) < cost then
			affinityLog(string.format("waiting Beli (need %d)", cost), 6)
			task.wait(2)
			continue
		end
		local before = {}
		for s in pairs(AFFINITY.TARGETS) do before[s] = aff[s] end
		if not affinityRoll(panel, key) then
			task.wait(0.2)
			continue
		end
		rolls += 1
		affinityMarkSealed(affinityWaitRoll(panel, key, before))
	end
	return false
end

function affinityMain()
	if not AFFINITY.ON or not next(AFFINITY.TARGETS) then return end
	local ui = affinityOpenUI()
	if not ui then
		affinityLog("AffinityUI not found", 8)
		return
	end
	local entry = affinityGetSlot1(ui, getData())
	if not entry then
		affinityLog("slot1 panel not found", 8)
		return
	end
	affinityRunSlot1(entry, ui)
end

function stopAffinityLoop()
	getgenv().__SIGMA_AFFINITY_RUN = false
	AFFINITY.sealed = {}
end

function startAffinityLoop()
	if getgenv().__SIGMA_AFFINITY_LOOP then return end
	getgenv().__SIGMA_AFFINITY_LOOP = true
	getgenv().__SIGMA_AFFINITY_RUN = true
	task.spawn(function()
		while getgenv().__SIGMA_AFFINITY_LOOP and AFFINITY.ON do
			pcall(affinityMain)
			if not getgenv().__SIGMA_AFFINITY_LOOP or not AFFINITY.ON then break end
			local ui = affinityGetUI()
			task.wait((not ui or not ui.Enabled) and 1 or 0.12)
		end
		stopAffinityLoop()
		getgenv().__SIGMA_AFFINITY_LOOP = false
	end)
end

function refreshAffinityLoop()
	if AFFINITY.ON and next(AFFINITY.TARGETS) then
		startAffinityLoop()
	else
		stopAffinityLoop()
		getgenv().__SIGMA_AFFINITY_LOOP = false
	end
end

function stepHakiFeatures()
	updateHakiMaxState()
	local ok, err = pcall(function()
		if RAYLEIGH.ON and stepRayleigh() then return end
		if not hakiModeEnabled() then
			stepHakiForceOff()
			return
		end
		hakiLog("diag", hakiDiagSnapshot(), 8)
		stepHakiForceOff()
		stepAutoKenbunshoku()
		stepAutoBusoshoku()
		stepFastHaki()
	end)
	if not ok then
		sigmaLog("[Sigma Haki] ERROR:", err)
	end
end

function sigmaKickSelf()
	if STATE.kickPending then return false end
	STATE.kickPending = true
	pcall(function()
		player:Kick("Non-whitelisted player in server")
	end)
	return true
end

function sigmaRejoinServer(reason)
	if STATE.rejoinPending then return false end
	STATE.rejoinPending = true
	pcall(function() TeleportService:Teleport(game.PlaceId) end)
	return true
end

function rejoinWhitelistNormalize(name)
	name = string.lower(tostring(name or ""))
	name = string.gsub(name, "^%s+", "")
	name = string.gsub(name, "%s+$", "")
	return name
end

function rejoinWhitelistSet()
	local cfg = getgenv().SigmaFishConfig or {}
	local raw = cfg.RejoinWhitelist
	local set = {}
	local function add(s)
		s = rejoinWhitelistNormalize(s)
		if s ~= "" then set[s] = true end
	end
	if type(raw) == "string" then
		for part in string.gmatch(raw, "[^,\n;]+") do add(part) end
	elseif type(raw) == "table" then
		if raw[1] then
			for _, v in ipairs(raw) do add(v) end
		else
			for k, v in pairs(raw) do
				if v == true then add(k) end
			end
		end
	end
	add(player and player.Name or "")
	if player and player.DisplayName and player.DisplayName ~= player.Name then
		add(player.DisplayName)
	end
	return set
end

function rejoinPlayerAllowed(plr, wl)
	if not plr or plr == player then return true end
	wl = wl or rejoinWhitelistSet()
	local name = rejoinWhitelistNormalize(plr.Name)
	local disp = rejoinWhitelistNormalize(plr.DisplayName)
	return wl[name] == true or (disp ~= "" and wl[disp] == true)
end

function findWhitelistIntruder()
	if not REJOIN.ON then return nil end
	local wl = rejoinWhitelistSet()
	for _, plr in ipairs(Players:GetPlayers()) do
		if not rejoinPlayerAllowed(plr, wl) then
			return plr
		end
	end
	return nil
end

function tryWhitelistKick(intruder, source)
	intruder = intruder or findWhitelistIntruder()
	if not intruder then return false end
	local now = os.clock()
	if now - (STATE.whitelistKickAt or 0) < REJOIN.KICK_COOLDOWN then return false end
	STATE.whitelistKickAt = now
	return sigmaKickSelf()
end

function stepWhitelistKick()
	if not REJOIN.ON then return false end
	local now = os.clock()
	if now - (REJOIN._lastCheck or 0) < REJOIN.CHECK_INTERVAL then return false end
	REJOIN._lastCheck = now
	local intruder = findWhitelistIntruder()
	if intruder then return tryWhitelistKick(intruder, "poll") end
	return false
end

function setupWhitelistGuard()
	if getgenv().__SIGMA_WHITELIST_CONN then return end
	getgenv().__SIGMA_WHITELIST_CONN = Players.PlayerAdded:Connect(function(plr)
		task.defer(function()
			if not REJOIN.ON then return end
			if not rejoinPlayerAllowed(plr) then
				tryWhitelistKick(plr, "join")
			end
		end)
	end)
end

function serviceTick()
	if HUB.AUTO_SPAWN then
		if ensureSpawn() then return end
	end
	dropGrappleTools()
	if isActive() and worldReady() then
		stepCacheFeatures()
	end
end

function featureTick()
	if not hubRunning() then return end
	if spawnOpen() or not worldReady() then
		if hakiModeEnabled() or compassModeEnabled() then
			hakiLog("gate", string.format(
				"blocked | spawn=%s worldReady=%s data=%s",
				tostring(spawnOpen()), tostring(not spawnOpen() and worldReady()), tostring(getData() ~= nil)
			), 5)
		end
		return
	end
	if stepCompassFeatures() then return end
	stepHakiFeatures()
	if questExpertiseEnabled() then
		stepExpertiseQuest()
	else
		clearCollectSweep()
	end
	if questPickEnabled() then
		stepPickedQuests()
	end
	if FISH.ON and not questWorkActive() then fishStep() end
end

function hubTick()
	syncCfg()
	stepHideName()
	if REJOIN.ON then stepWhitelistKick() end
	if not isActive() then return end
	serviceTick()
	if spawnOpen() then return end
	featureTick()
end

function startHubLoop()
	syncCfg()
	if getgenv().__SIGMA_HUB_RUNNING then return end
	RUN.id += 1
	local run = RUN.id
	getgenv().__SIGMA_HUB_RUNNING = true
	getgenv().__SIGMA_HUB_RUN_ID = run
	getgenv().__SIGMA_FISH_RUNNING = true
	getgenv().__SIGMA_FISH_RUN_ID = run
	setupAntiAfk()
	setupGrappleCleaner()
	setupWhitelistGuard()
	if not getgenv().__SIGMA_HAKI_CHAR_CONN then
		getgenv().__SIGMA_HAKI_CHAR_CONN = player.CharacterAdded:Connect(function()
			STATE.hakiFastPending = false
			STATE.hakiFastRunning = false
			STATE.hakiWasFull = false
			STATE.hakiHoldCF = nil
			hakiClearDrainWatch()
			hakiClearFullSticky()
			if HUB.HIDE_NAME then
				task.wait(0.3)
				patchCharacterName(true)
				patchGuiNames(true)
			end
		end)
	end
	task.spawn(function()
		while getgenv().__SIGMA_HUB_RUNNING and getgenv().__SIGMA_HUB_RUN_ID == run do
			pcall(hubTick)
			local waitT = HUB.LOOP_DELAY
			if questWorkActive() then
				waitT = 0.05
			elseif HAKI.FAST then
				waitT = 0.12
			end
			task.wait(waitT)
		end
	end)
end

function ensureLoopRunning()
	syncCfg()
	startHubLoop()
end

function stopLoop()
	stopM1Loop()
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
	on = on == true
	local cfg = getgenv().SigmaFishConfig or {}
	cfg.AutoQuest = on
	getgenv().SigmaFishConfig = cfg
	QUEST.AUTO = on
	if not on then
		stopQuestWork()
	end
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
	on = on == true
	if not on then
		QUEST.EXPERTISE = false
		stopQuestWork()
		clearCollectSweep()
	end
	local cfg = getgenv().SigmaFishConfig or {}
	cfg.AutoExpertise = on
	getgenv().SigmaFishConfig = cfg
	if on then
		QUEST.EXPERTISE = true
		clearCollectSweep()
	end
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

function SigmaFish.setAutoSpawn(on)
	local cfg = getgenv().SigmaFishConfig or {}
	cfg.AutoSpawn = on ~= false
	getgenv().SigmaFishConfig = cfg
	syncCfg()
end

function SigmaFish.setAntiAfk(on)
	local cfg = getgenv().SigmaFishConfig or {}
	cfg.AntiAfk = on ~= false
	getgenv().SigmaFishConfig = cfg
	refreshHubServices()
end

function SigmaFish.setHideName(on)
	local cfg = getgenv().SigmaFishConfig or {}
	cfg.HideName = on ~= false
	getgenv().SigmaFishConfig = cfg
	HUB.HIDE_NAME = cfg.HideName
	if not HUB.HIDE_NAME then
		restoreHideName()
		STATE.hideNameActive = false
	end
	if type(getgenv().SigmaApplyUiHideName) == "function" then
		pcall(getgenv().SigmaApplyUiHideName)
	end
	ensureLoopRunning()
end

function SigmaFish.setAutoClaimSam(on)
	local cfg = getgenv().SigmaFishConfig or {}
	cfg.AutoClaimSam = on == true
	getgenv().SigmaFishConfig = cfg
	SAM.ON = cfg.AutoClaimSam
	ensureLoopRunning()
end

function SigmaFish.setAutoDropCompass(on)
	local cfg = getgenv().SigmaFishConfig or {}
	cfg.AutoDropCompass = on == true
	getgenv().SigmaFishConfig = cfg
	COMPASS.DROP_ON = cfg.AutoDropCompass
	ensureLoopRunning()
end

function SigmaFish.setAutoFindSam(on)
	local cfg = getgenv().SigmaFishConfig or {}
	cfg.AutoFindSam = on == true
	getgenv().SigmaFishConfig = cfg
	COMPASS.FIND_ON = cfg.AutoFindSam
	if COMPASS.FIND_ON then
		refreshCompassFindLoop()
	else
		stopCompassFindLoop()
	end
	ensureLoopRunning()
end

function SigmaFish.setAutoSkill(on)
	local cfg = getgenv().SigmaFishConfig or {}
	cfg.AutoSkill = on == true
	getgenv().SigmaFishConfig = cfg
	SKILL.ON = cfg.AutoSkill
	if SKILL.ON then refreshSkillLoop() else stopSkillLoop() end
	ensureLoopRunning()
end

function SigmaFish.setSkillKeys(keys)
	local cfg = getgenv().SigmaFishConfig or {}
	cfg.SkillKeys = keys or {}
	getgenv().SigmaFishConfig = cfg
	if SKILL.ON then refreshSkillLoop() end
end

function SigmaFish.setSkillHoldSec(sec)
	local cfg = getgenv().SigmaFishConfig or {}
	local n = tonumber(sec)
	if n == nil or n < 0 then return end
	cfg.SkillHoldSec = n
	getgenv().SigmaFishConfig = cfg
	SKILL.HOLD_SEC = n
end

function SigmaFish.setAutoWhitelistRejoin(on)
	local cfg = getgenv().SigmaFishConfig or {}
	cfg.AutoWhitelistRejoin = on == true
	getgenv().SigmaFishConfig = cfg
	REJOIN.ON = cfg.AutoWhitelistRejoin
	if REJOIN.ON then
		task.defer(function()
			local intruder = findWhitelistIntruder()
			if intruder then tryWhitelistKick(intruder, "enable") end
		end)
	end
	ensureLoopRunning()
end

function SigmaFish.setRejoinWhitelist(text)
	local cfg = getgenv().SigmaFishConfig or {}
	cfg.RejoinWhitelist = tostring(text or "")
	getgenv().SigmaFishConfig = cfg
end

function SigmaFish.rejoinServer()
	return sigmaRejoinServer("manual")
end

function SigmaFish.setAutoKenbunshoku(on)
	local cfg = getgenv().SigmaFishConfig or {}
	cfg.AutoKenbunshoku = on == true
	getgenv().SigmaFishConfig = cfg
	HAKI.AUTO_KEN = cfg.AutoKenbunshoku
	if not on then
		stepHakiForceOff()
	end
	ensureLoopRunning()
end

function SigmaFish.setAutoBusoshoku(on)
	local cfg = getgenv().SigmaFishConfig or {}
	cfg.AutoBusoshoku = on == true
	getgenv().SigmaFishConfig = cfg
	HAKI.AUTO_BUSO = cfg.AutoBusoshoku
	if not on then
		stepHakiForceOff()
	end
	ensureLoopRunning()
end

function SigmaFish.setFastHaki(on)
	local cfg = getgenv().SigmaFishConfig or {}
	cfg.FastHaki = on == true
	getgenv().SigmaFishConfig = cfg
	HAKI.FAST = cfg.FastHaki
	if not HAKI.FAST then
		if hakiReleaseFarm then hakiReleaseFarm() end
		STATE.hakiFastRunning = false
		STATE.hakiWasFull = false
		hakiClearDrainWatch()
	end
	ensureLoopRunning()
end

function SigmaFish.setAutoRayleigh(on)
	local cfg = getgenv().SigmaFishConfig or {}
	cfg.AutoRayleigh = on == true
	getgenv().SigmaFishConfig = cfg
	RAYLEIGH.ON = cfg.AutoRayleigh
	if not RAYLEIGH.ON then
		RAYLEIGH._meditateTrack = nil
	end
	ensureLoopRunning()
end

function SigmaFish.setAutoAffinity(on)
	local cfg = getgenv().SigmaFishConfig or {}
	cfg.AutoAffinity = on == true
	getgenv().SigmaFishConfig = cfg
	AFFINITY.ON = cfg.AutoAffinity
	AFFINITY.TARGETS = affinityTargetsFromCfg(cfg)
	if not AFFINITY.ON then
		stopAffinityLoop()
	end
	refreshAffinityLoop()
	ensureLoopRunning()
end

function SigmaFish.setAffinityTarget(stat, value)
	local cfg = getgenv().SigmaFishConfig or {}
	local key = "Affinity" .. tostring(stat)
	cfg[key] = value
	getgenv().SigmaFishConfig = cfg
	AFFINITY.TARGETS = affinityTargetsFromCfg(cfg)
	if AFFINITY.ON then refreshAffinityLoop() end
end

function SigmaFish.applyConfig()
	local cfg = getgenv().SigmaFishConfig or {}
	cfg.QuestPick = normalizeQuestPick(cfg.QuestPick)
	if cfg.AutoSpawn == nil then cfg.AutoSpawn = true end
	if cfg.AntiAfk == nil then cfg.AntiAfk = true end
	if cfg.HideName == nil then cfg.HideName = true end
	if cfg.AutoClaimSam == nil then cfg.AutoClaimSam = false end
	if cfg.AutoDropCompass == nil then cfg.AutoDropCompass = false end
	if cfg.AutoFindSam == nil then cfg.AutoFindSam = false end
	if cfg.AutoSkill == nil then cfg.AutoSkill = false end
	if cfg.SkillHoldSec == nil then cfg.SkillHoldSec = 0.5 end
	if cfg.SkillKeys == nil then cfg.SkillKeys = {} end
	if cfg.AutoWhitelistRejoin == nil then cfg.AutoWhitelistRejoin = false end
	if cfg.RejoinWhitelist == nil then cfg.RejoinWhitelist = "" end
	if cfg.CacheUsePick == nil then cfg.CacheUsePick = {} end
	if cfg.CacheDropPick == nil then cfg.CacheDropPick = {} end
	if cfg.AutoCacheDrop == nil then cfg.AutoCacheDrop = false end
	if cfg.AutoUseConsumables == nil then cfg.AutoUseConsumables = true end
	getgenv().SigmaFishConfig = cfg
	QUEST.PICK = cfg.QuestPick
	local wantAuto = cfg.AutoQuest == true
	local wantExp = cfg.AutoExpertise == true
	if wantAuto ~= QUEST.AUTO then
		SigmaFish.setAutoQuest(wantAuto)
	end
	if wantExp ~= QUEST.EXPERTISE then
		SigmaFish.setAutoExpertise(wantExp)
	end
	local wantKen = cfg.AutoKenbunshoku == true
	local wantBuso = cfg.AutoBusoshoku == true
	local wantFast = cfg.FastHaki == true
	local wantRay = cfg.AutoRayleigh == true
	if wantKen ~= HAKI.AUTO_KEN and SigmaFish.setAutoKenbunshoku then
		SigmaFish.setAutoKenbunshoku(wantKen)
	elseif wantKen then HAKI.AUTO_KEN = true end
	if wantBuso ~= HAKI.AUTO_BUSO and SigmaFish.setAutoBusoshoku then
		SigmaFish.setAutoBusoshoku(wantBuso)
	elseif wantBuso then HAKI.AUTO_BUSO = true end
	if wantFast ~= HAKI.FAST and SigmaFish.setFastHaki then
		SigmaFish.setFastHaki(wantFast)
	elseif wantFast then HAKI.FAST = true end
	if wantRay ~= RAYLEIGH.ON and SigmaFish.setAutoRayleigh then
		SigmaFish.setAutoRayleigh(wantRay)
	elseif wantRay then RAYLEIGH.ON = true end
	local wantAff = cfg.AutoAffinity == true
	if wantAff ~= AFFINITY.ON and SigmaFish.setAutoAffinity then
		SigmaFish.setAutoAffinity(wantAff)
	elseif wantAff then
		AFFINITY.ON = true
		AFFINITY.TARGETS = affinityTargetsFromCfg(cfg)
		refreshAffinityLoop()
	end
	if not wantAff then stopAffinityLoop() end
	AFFINITY.TARGETS = affinityTargetsFromCfg(cfg)
	local wantHide = cfg.HideName ~= false
	local wantSam = cfg.AutoClaimSam == true
	local wantDrop = cfg.AutoDropCompass == true
	local wantFind = cfg.AutoFindSam == true
	local wantSkill = cfg.AutoSkill == true
	if wantHide ~= (HUB.HIDE_NAME == true) and SigmaFish.setHideName then
		SigmaFish.setHideName(wantHide)
	elseif wantHide then HUB.HIDE_NAME = true end
	if wantSam ~= SAM.ON and SigmaFish.setAutoClaimSam then
		SigmaFish.setAutoClaimSam(wantSam)
	elseif wantSam then SAM.ON = true end
	if wantDrop ~= COMPASS.DROP_ON and SigmaFish.setAutoDropCompass then
		SigmaFish.setAutoDropCompass(wantDrop)
	elseif wantDrop then COMPASS.DROP_ON = true end
	if wantFind ~= COMPASS.FIND_ON and SigmaFish.setAutoFindSam then
		SigmaFish.setAutoFindSam(wantFind)
	elseif wantFind then
		COMPASS.FIND_ON = true
		refreshCompassFindLoop()
	end
	if wantSkill ~= SKILL.ON and SigmaFish.setAutoSkill then
		SigmaFish.setAutoSkill(wantSkill)
	elseif wantSkill then
		SKILL.ON = true
		SKILL.HOLD_SEC = tonumber(cfg.SkillHoldSec) or 0.5
		refreshSkillLoop()
	end
	if not wantSkill then stopSkillLoop() end
	if not wantFind then stopCompassFindLoop() end
	local wantWl = cfg.AutoWhitelistRejoin == true
	if wantWl ~= REJOIN.ON and SigmaFish.setAutoWhitelistRejoin then
		SigmaFish.setAutoWhitelistRejoin(wantWl)
	elseif wantWl then REJOIN.ON = true end
	STATE.cooking = false
	STATE.pause = false
	refreshHubServices()
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

function SigmaFish.getCacheCounts()
	return getCacheCounts()
end

function SigmaFish.setCacheUsePick(keys)
	local cfg = getgenv().SigmaFishConfig or {}
	cfg.CacheUsePick = keys or {}
	getgenv().SigmaFishConfig = cfg
	ensureLoopRunning()
end

function SigmaFish.setCacheDropPick(keys)
	local cfg = getgenv().SigmaFishConfig or {}
	cfg.CacheDropPick = keys or {}
	getgenv().SigmaFishConfig = cfg
	ensureLoopRunning()
end

function SigmaFish.setAutoCacheDrop(on)
	local cfg = getgenv().SigmaFishConfig or {}
	cfg.AutoCacheDrop = on == true
	getgenv().SigmaFishConfig = cfg
	CACHE.AUTO_DROP = cfg.AutoCacheDrop
	ensureLoopRunning()
end

function SigmaFish.setAutoUseConsumables(on)
	local cfg = getgenv().SigmaFishConfig or {}
	cfg.AutoUseConsumables = on ~= false
	getgenv().SigmaFishConfig = cfg
	CACHE.AUTO_CONSUME = cfg.AutoUseConsumables
	ensureLoopRunning()
end

function SigmaFish.dropCacheSelected()
	return cacheDropTypes(cacheDropPick(), 50)
end

function SigmaFish.getHakiStatus()
	local lv, stop = statLevel("Haki"), hakiStopLevel()
	return {
		level = lv,
		stop = stop,
		maxed = hakiFarmStoppedByLevel(),
	}
end

function SigmaFish.getStatus()
	syncCfg()
	local q = getQuests()
	return {
		autoSpawn = HUB.AUTO_SPAWN,
		antiAfk = HUB.ANTI_AFK,
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
	return getgenv().__SIGMA_HUB_RUNNING == true
end

function SigmaFish.stop()
	getgenv().SigmaFishConfig = getgenv().SigmaFishConfig or {}
	getgenv().SigmaFishConfig.AutoFish = false
	getgenv().SigmaFishConfig.AutoQuest = false
	getgenv().SigmaFishConfig.AutoExpertise = false
	getgenv().SigmaFishConfig.AutoKenbunshoku = false
	getgenv().SigmaFishConfig.AutoBusoshoku = false
	getgenv().SigmaFishConfig.FastHaki = false
	getgenv().SigmaFishConfig.AutoRayleigh = false
	getgenv().SigmaFishConfig.AutoAffinity = false
	getgenv().SigmaFishConfig.AutoClaimSam = false
	getgenv().SigmaFishConfig.AutoDropCompass = false
	getgenv().SigmaFishConfig.AutoFindSam = false
	getgenv().SigmaFishConfig.AutoSkill = false
	getgenv().SigmaFishConfig.AutoWhitelistRejoin = false
	SAM.ON = false
	COMPASS.DROP_ON = false
	COMPASS.FIND_ON = false
	SKILL.ON = false
	REJOIN.ON = false
	stopCompassFindLoop()
	stopSkillLoop()
	HAKI.AUTO_KEN = false
	HAKI.AUTO_BUSO = false
	HAKI.FAST = false
	RAYLEIGH.ON = false
	AFFINITY.ON = false
	stopAffinityLoop()
	STATE.cooking = false
	STATE.pause = false
	syncCfg()
	stopLoop()
end

-- Reset loop khi reload Main.lua
getgenv().__SIGMA_HUB_RUNNING = false
getgenv().__SIGMA_HUB_RUN_ID = nil
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
	if cfg.AutoQuest == nil then cfg.AutoQuest = false end
	if cfg.AutoSpawn == nil then cfg.AutoSpawn = true end
	if cfg.AntiAfk == nil then cfg.AntiAfk = true end
	if cfg.AutoKenbunshoku == nil then cfg.AutoKenbunshoku = false end
	if cfg.AutoBusoshoku == nil then cfg.AutoBusoshoku = false end
	if cfg.FastHaki == nil then cfg.FastHaki = false end
	if cfg.AutoRayleigh == nil then cfg.AutoRayleigh = false end
	if cfg.HideName == nil then cfg.HideName = true end
	if cfg.AutoClaimSam == nil then cfg.AutoClaimSam = false end
	if cfg.AutoDropCompass == nil then cfg.AutoDropCompass = false end
	if cfg.AutoFindSam == nil then cfg.AutoFindSam = false end
	if cfg.AutoSkill == nil then cfg.AutoSkill = false end
	if cfg.SkillHoldSec == nil then cfg.SkillHoldSec = 0.5 end
	if cfg.SkillKeys == nil then cfg.SkillKeys = {} end
	if cfg.AutoWhitelistRejoin == nil then cfg.AutoWhitelistRejoin = false end
	if cfg.RejoinWhitelist == nil then cfg.RejoinWhitelist = "" end
	if cfg.CacheUsePick == nil then cfg.CacheUsePick = {} end
	if cfg.CacheDropPick == nil then cfg.CacheDropPick = {} end
	if cfg.AutoCacheDrop == nil then cfg.AutoCacheDrop = false end
	if cfg.AutoUseConsumables == nil then cfg.AutoUseConsumables = true end
	QUEST.AUTO = cfg.AutoQuest == true
	QUEST.EXPERTISE = cfg.AutoExpertise == true
	syncCfg()
	startHubLoop()
end

getgenv().SigmaFish = SigmaFish
return SigmaFish
