--[[
 sigma.lua — Sigma Hub fishing backend (learn.lua style)
 Ported from a.lua logic. a.lua is NOT loaded or modified.
]]

if type(getgenv) ~= "function" then
	getgenv = function() return _G end
end
if type(task) ~= "table" or type(task.wait) ~= "function" then
	task = { wait = wait, spawn = function(f) coroutine.wrap(f)() end, defer = function(f) task.spawn(f) end }
end
if LPH_OBFUSCATED == nil then
	function LPH_NO_VIRTUALIZE(f) return f end
end

CFG = getgenv().SigmaConfig or {}
getgenv().SigmaConfig = CFG

Players = game:GetService("Players")
ReplicatedFirst = game:GetService("ReplicatedFirst")
UserInputService = game:GetService("UserInputService")
GuiService = game:GetService("GuiService")
VirtualUser = game:GetService("VirtualUser")
VirtualInputManager = game:GetService("VirtualInputManager")
player = Players.LocalPlayer

RUN = { id = 0 }
BRING = { releaseHold = function() end }
FARM = { USE_CLICKS = tonumber(CFG.FISH_USE_CLICKS) or 3, USE_DELAY = tonumber(CFG.FISH_USE_DELAY) or 0.05 }
TIMING = { TP_OFFSET = tonumber(CFG.TP_OFFSET) or 6 }
CARRY_SWEEP_WAIT = tonumber(CFG.CARRY_SWEEP_WAIT) or 0.3
FISHERMAN_RECEIVER = nil

FISH = {
	ON = false,
	SUPER = false,
	SELL_AT = tonumber(CFG.FISH_SELL_AT) or 15,
	MIXER_PATH = tostring(CFG.FISH_MIXER_PATH or "MapFolder.StrangeTent.Model.JuicingBowl.Mixer1"),
	COOK_PATH = "MapFolder.Island8.Kitchen.Cooking.CookingStation",
	COOKER_NPC = "Cooker",
	FISHERMAN = "Fisherman",
	CAST_TIMEOUT = tonumber(CFG.FISH_CAST_TIMEOUT) or 4,
	BITE_TIMEOUT = tonumber(CFG.FISH_BITE_TIMEOUT) or 30,
	REEL_TIMEOUT = tonumber(CFG.FISH_REEL_TIMEOUT) or 4,
	WIN_DELAY = tonumber(CFG.FISH_WIN_DELAY) or 0.3,
	LOOP_DELAY = tonumber(CFG.FISH_LOOP_DELAY) or 0.25,
	MINI_CLICK_INTERVAL = tonumber(CFG.FISHMINIGAME_CLICK_INTERVAL) or 0.2,
	MINI_RETRY_SAME = tonumber(CFG.FISHMINIGAME_RETRY_SAME) or 0.35,
	MINI_SHUFFLE_WAIT = tonumber(CFG.FISHMINIGAME_SHUFFLE_WAIT) or 0.15,
	MINI_READY_WAIT = tonumber(CFG.FISHMINIGAME_READY_WAIT) or 0.35,
	MINI_POLL = tonumber(CFG.FISHMINIGAME_POLL) or 0.06,
	MINI_DEBUG = CFG.FISHMINIGAME_DEBUG == true,
	MINI_STEP_LOG = CFG.FISHMINIGAME_STEP_LOG == true,
	MINI_TRY_CAUGHT = CFG.FISHMINIGAME_TRY_CAUGHT == false,
	RODS = { "Super Rod", "Sturdy Rod", "Wood Rod" },
	TYPES = {
		"Small Flooper", "Small Busser", "Small Lubber", "Small Jawber",
		"Medium Flooper", "Medium Busser", "Medium Lubber", "Medium Jawber",
		"Large Flooper", "Large Busser",
		"Huge Flooper", "Huge Busser", "Huge Lubber",
	},
	TASK_FISH = {
		"Small Flooper", "Small Busser", "Small Lubber", "Small Jawber",
		"Medium Flooper", "Medium Busser", "Medium Lubber", "Medium Jawber",
		"Large Flooper", "Large Busser", "Large Jawber", "Large Lubber",
	},
	QUEST_TASK = "Fisherman's Task",
	QUEST_CHALLENGE = "Fisherman's Challenge",
	QUEST_FAVOR = "Fisherman's Favor",
	ROD_CATEGORY = "Utility",
}

STATE = {
	pause = false,
	loopRunning = false,
	inMinigame = false,
	miniTotal = nil,
	solving = false,
	lastSolveAt = 0,
	fishCount = nil,
	listenersReady = false,
	lastSellAt = 0,
	lastCacheAt = 0,
	lastUseAt = 0,
	lastDeliverAt = 0,
	uncLogged = false,
	spotPos = nil,
	spotKind = nil,
	itemSession = nil,
}
FISH_STATE = STATE

function FISH.hasPendingItems()
	return false
end

function collectConsumables()
	return {}
end

function useAllConsumables()
	return 0, 0
end

function clickMixers()
end

function isActive()
	return getgenv().__SIGMA_FISH_RUNNING == true and getgenv().__SIGMA_FISH_RUN_ID == RUN.id
end

function isSpawnScreenOpen()
	local pg = player and player:FindFirstChild("PlayerGui")
	local load = pg and pg:FindFirstChild("Load")
	return load ~= nil and load:IsA("ScreenGui") and load.Enabled == true
end

function isWorldReady()
	if isSpawnScreenOpen() then return false end
	if not player or not player:FindFirstChild("PlayerGui") then return false end
	if not player.Character or not player.Character:FindFirstChild("HumanoidRootPart") then return false end
	if not getData() then return false end
	if not (workspace:FindFirstChild("Alive") or workspace:FindFirstChild("MapFolder")) then return false end
	return true
end

function uncHas(checkFn)
	local ok, v = pcall(checkFn)
	return ok and v == true
end

UNC = {
	fireClick = uncHas(function() return type(fireclickdetector) == "function" end),
	firePrompt = uncHas(function() return type(fireproximityprompt) == "function" end),
	fireSignal = uncHas(function() return type(firesignal) == "function" end),
	getConns = uncHas(function() return type(getconnections) == "function" end),
	vim = false,
	vuser = false,
	mobile = false,
	low = false,
}
pcall(function()
if VirtualInputManager and typeof(VirtualInputManager.SendMouseButtonEvent) == "function" then
	UNC.vim = true
end
end)
pcall(function()
if VirtualUser and typeof(VirtualUser.Button1Down) == "function" then
	UNC.vuser = true
end
end)
function detectMobileInput()
	if CFG.FORCE_MOBILE_INPUT == true then return true end
	if CFG.FORCE_PC_INPUT == true then return false end
	local uis = UserInputService
	-- PC (kể cả laptop màn hình cảm ứng): có chuột + bàn phím -> không dùng mobile path
	if uis.KeyboardEnabled and uis.MouseEnabled then
		return false
	end
	if uis.TouchEnabled and not uis.KeyboardEnabled and not uis.MouseEnabled then
		return true
	end
	if uis.PreferredInput == Enum.PreferredInput.Touch and not uis.MouseEnabled then
		return true
	end
	local execMobile = false
	pcall(function()
		if identifyexecutor then
			local n = string.lower(tostring(identifyexecutor()))
			if n:find("delta", 1, true) or n:find("mobile", 1, true)
				or n:find("ios", 1, true) or n:find("android", 1, true) then
				execMobile = true
			end
		end
	end)
	if execMobile and not uis.MouseEnabled then return true end
	return false
end

UNC.mobile = detectMobileInput()
UNC.low = CFG.UNC_LOW == true
or (not UNC.fireClick and not UNC.firePrompt and not UNC.vim and not UNC.fireSignal)
if UNC.low and not UNC.mobile then
FISH.LOOP_DELAY = math.max(FISH.LOOP_DELAY, tonumber(CFG.FISH_LOOP_DELAY_LOW) or 0.4)
FISH.MINI_CLICK_INTERVAL = math.max(FISH.MINI_CLICK_INTERVAL, tonumber(CFG.FISHMINIGAME_CLICK_INTERVAL_LOW) or 0.1)
FISH.MINI_RETRY_SAME = math.max(FISH.MINI_RETRY_SAME, 0.45)
end
if UNC.mobile then
FISH.MINI_CLICK_INTERVAL = tonumber(CFG.FISHMINIGAME_CLICK_INTERVAL_MOBILE) or 0.24
FISH.MINI_RETRY_SAME = tonumber(CFG.FISHMINIGAME_RETRY_SAME_MOBILE) or 0.55
FISH.MINI_POLL = tonumber(CFG.FISHMINIGAME_POLL_MOBILE) or 0.09
FISH.MINI_SHUFFLE_WAIT = tonumber(CFG.FISHMINIGAME_SHUFFLE_WAIT) or 0.18
FISH.LOOP_DELAY = math.max(FISH.LOOP_DELAY, tonumber(CFG.FISH_LOOP_DELAY_LOW) or 0.35)
end

function safeVirtualClick()
if not UNC.vuser then return false end
local cam = workspace.CurrentCamera
if not cam then return false end
return pcall(function()
	VirtualUser:Button1Down(Vector2.new(0, 0), cam.CFrame)
	VirtualUser:Button1Up(Vector2.new(0, 0), cam.CFrame)
end)
end

function safeFireClick(cd)
if not cd then return false end
if UNC.fireClick then
	if pcall(fireclickdetector, cd) then return true end
	if pcall(fireclickdetector, cd, 1) then return true end
end
return safeVirtualClick()
end

function safeFirePrompt(pr)
if not pr then return false end
if UNC.firePrompt then
	if pcall(fireproximityprompt, pr, 0) then return true end
	if pcall(fireproximityprompt, pr) then return true end
end
return false
end
function useToolClicks(tool, hum, clicks, delay)
if not tool or not hum then return end
pcall(function() hum:EquipTool(tool) end)
local n = clicks or 1
for i = 1, n do
	if not isActive() or not tool.Parent then break end
	if not pcall(function() tool:Activate() end) then safeVirtualClick() end
	if delay and delay > 0 then
		task.wait(delay)
	elseif i < n then
		task.wait()
	end
end
end

function akPrint(_) end

function log(_) end

local logEvent = log

local _lastLogMsg = {}
function logOnce(key, msg)
if _lastLogMsg[key] ~= msg then
	_lastLogMsg[key] = msg
	log(msg)
end
end

local _lastLogAt = {}
function logThrottle(key, msg, gap)
local now = os.clock()
if _lastLogMsg[key] ~= msg or (now - (_lastLogAt[key] or 0)) >= (gap or 10) then
	_lastLogMsg[key] = msg
	_lastLogAt[key] = now
	log(msg)
end
end

function logEvery(key, msg, gap)
local now = os.clock()
if (now - (_lastLogAt[key] or 0)) >= (gap or 15) then
	_lastLogAt[key] = now
	log(msg)
end
end
function resolveDataRoot()
if type(_G.Data) == "table" then return _G.Data end
if type(getrenv) == "function" then
local ok, renv = pcall(getrenv)
if ok and type(renv) == "table" and type(renv._G) == "table" and type(renv._G.Data) == "table" then
	return renv._G.Data
end
end
if type(getgenv) == "function" then
local ok, genv = pcall(getgenv)
if ok and type(genv) == "table" and type(genv.Data) == "table" then
	return genv.Data
end
end
return nil
end

function getData()
local data = resolveDataRoot()
if not data then return nil end
return data[player.UserId] or data[tostring(player.UserId)] or nil
end

function getQuests()
local d = getData()
return d and d.Quests or nil
end

getHRP = LPH_NO_VIRTUALIZE(function()
	local char = player.Character
	return char and char:FindFirstChild("HumanoidRootPart") or nil
end)

function getPos(inst)
if not inst then return nil end
if inst:IsA("BasePart") then return inst.Position end
if inst:IsA("Model") then
local ok, p = pcall(function() return inst:GetPivot().Position end)
if ok and p then return p end
local pp = inst.PrimaryPart or inst:FindFirstChild("HumanoidRootPart")
if pp and pp:IsA("BasePart") then return pp.Position end
end
local part = inst:FindFirstChildWhichIsA("BasePart", true)
return part and part.Position or nil
end

function tpNear(inst)
local hrp = getHRP()
local pos = getPos(inst)
if not hrp or not pos then return false end
if BRING.releaseHold then BRING.releaseHold() end
pcall(function()
hrp.CFrame = CFrame.new(pos + Vector3.new(0, TIMING.TP_OFFSET, 0))
end)
task.wait(0.1)
return true
end

function tpFaceNear(model, dist, up)
local hrp = getHRP()
local pos = getPos(model)
if not hrp or not pos then return false end
if BRING.releaseHold then BRING.releaseHold() end
dist = dist or 4
up = up or 1
local npcHRP = (typeof(model) == "Instance") and model:FindFirstChild("HumanoidRootPart") or nil
local facing = npcHRP and npcHRP.CFrame.LookVector or Vector3.new(0, 0, 1)
facing = Vector3.new(facing.X, 0, facing.Z)
if facing.Magnitude < 0.1 then facing = Vector3.new(0, 0, 1) else facing = facing.Unit end
local standPos = pos + facing * dist + Vector3.new(0, up, 0)
pcall(function()
hrp.CFrame = CFrame.new(standPos, Vector3.new(pos.X, standPos.Y, pos.Z))
end)
return true
end

function getMediator()
local mod = ReplicatedFirst:FindFirstChildOfClass("ModuleScript")
if not mod then return nil end
local ok, med = pcall(require, mod)
return ok and med or nil
end

function exec(channel, args)
local med = getMediator()
if not med then return false end
local fn = med["\t"] or med.Executor
if type(fn) ~= "function" then return false end
local ok = pcall(function()
fn(channel, args or {})
end)
return ok
end

function setCurrentMerchant(model)
local cur = player:FindFirstChild("CurrentMerchant")
if cur and cur:IsA("ObjectValue") then
cur.Value = model
end
end

function findNPC(npcName)
local npcRoot = workspace:FindFirstChild("Ignore")
npcRoot = npcRoot and npcRoot:FindFirstChild("NPCs") or nil
if not npcRoot then return nil end

local hrp = getHRP()
local best, bestD
for _, inst in npcRoot:GetDescendants() do
if inst:IsA("Model") then
	local dialogue = inst:GetAttribute("DialogueModule")
	if inst.Name == npcName or dialogue == npcName then
		if not hrp then return inst end
		local pos = getPos(inst)
		if pos then
			local d = (hrp.Position - pos).Magnitude
			if not bestD or d < bestD then
				best, bestD = inst, d
			end
		end
	end
end
end
return best
end

function clickNPC(model)
if not model then return false end
local part = model:FindFirstChild("HumanoidRootPart") or model:FindFirstChildWhichIsA("BasePart", true)
if not part then return false end
local cd = part:FindFirstChildOfClass("ClickDetector") or part:FindFirstChildWhichIsA("ClickDetector", true)
tpNear(part)
setCurrentMerchant(model)
if cd then
safeFireClick(cd)
task.wait(0.15)
end
return true
end
function normalize(s)
s = string.lower(tostring(s or ""))
s = s:gsub("[^%w%s]", " ")
s = s:gsub("%s+", " ")
return s
end
function findToolByName(name)
local want = string.lower(name)
function scan(parent, exact)
if not parent then return nil end
for _, c in ipairs(parent:GetChildren()) do
	if c:IsA("Tool") then
		local ln = string.lower(c.Name)
		if (exact and ln == want) or (not exact and ln:find(want, 1, true)) then return c end
	end
end
end
local char, bp = player.Character, player:FindFirstChild("Backpack")
return scan(char, true) or scan(bp, true) or scan(char, false) or scan(bp, false)
end
function hasItem(itemName)
local char = player.Character
local bp = player:FindFirstChild("Backpack")
if char then
for _, c in ipairs(char:GetChildren()) do if c.Name == itemName then return true end end
end
if bp then
for _, c in ipairs(bp:GetChildren()) do if c.Name == itemName then return true end end
end
return false
end

function activeObjectiveTokens()
local tokens, seen = {}, {}
local q = getQuests()
if q and type(q.Objectives) == "table" then
for name in pairs(q.Objectives) do
	for word in string.gmatch(normalize(name), "%w+") do
		if #word >= 3 and not seen[word] then
			seen[word] = true
			table.insert(tokens, word)
		end
	end
end
end
return tokens
end

function objectivesText()
local q = getQuests()
if not q or type(q.Objectives) ~= "table" then return "(no objective)" end
local parts = {}
for name, obj in pairs(q.Objectives) do
local prog = type(obj) == "table" and tostring(obj.Progress) or "?"
local req = type(obj) == "table" and tostring(obj.Requirement or obj.Goal or "?") or "?"
table.insert(parts, string.format("%s[%s] %s/%s", name, type(obj) == "table" and tostring(obj.Type) or "?", prog, req))
end
return #parts > 0 and table.concat(parts, " | ") or "(no objective)"
end

function listNearbyNPCs(limit)
local npcRoot = workspace:FindFirstChild("Ignore")
npcRoot = npcRoot and npcRoot:FindFirstChild("NPCs") or nil
if not npcRoot then return "(Ignore.NPCs not found)" end
local hrp = getHRP()
local arr = {}
for _, m in ipairs(npcRoot:GetDescendants()) do
if m:IsA("Model") and (m:GetAttribute("DialogueModule") or m:FindFirstChild("HumanoidRootPart")) then
	local pos = getPos(m)
	local d = (hrp and pos) and (hrp.Position - pos).Magnitude or 0
	table.insert(arr, { name = m.Name, d = d })
end
end
table.sort(arr, function(a, b) return a.d < b.d end)
local out = {}
for i = 1, math.min(limit or 8, #arr) do
table.insert(out, string.format("%s(%.0f)", arr[i].name, arr[i].d))
end
return #out > 0 and table.concat(out, ", ") or "(no NPC)"
end

function findReceiver()
if type(FISHERMAN_RECEIVER) == "string" and FISHERMAN_RECEIVER ~= "" then
return findNPC(FISHERMAN_RECEIVER), FISHERMAN_RECEIVER
end
local tokens = activeObjectiveTokens()
local skip = { deliver = true, package = true, quest = true, fisherman = true, favor = true, friend = true }
local npcRoot = workspace:FindFirstChild("Ignore")
npcRoot = npcRoot and npcRoot:FindFirstChild("NPCs") or nil
if not npcRoot then return nil, nil end
for _, m in ipairs(npcRoot:GetDescendants()) do
if m:IsA("Model") and m.Name ~= "Fisherman" then
	local n = normalize(m.Name)
	for _, tk in ipairs(tokens) do
		if not skip[tk] and n:find(tk, 1, true) then
			return m, m.Name
		end
	end
end
end
return nil, nil
end

FISHER_RECOVER_INTERVAL = tonumber(CFG.FISHER_RECOVER_INTERVAL) or 3
FISHER_RECOVER_TRIES = tonumber(CFG.FISHER_RECOVER_TRIES) or 3
FISHER_SKIP_SECONDS = tonumber(CFG.FISHER_SKIP_SECONDS) or 15
_carryRecoverState = {}

function equipItem(itemName)
local char = player.Character
local hum = char and char:FindFirstChildOfClass("Humanoid")
if not hum then return false end
if char:FindFirstChild(itemName) then return true end
local bp = player:FindFirstChild("Backpack")
local tool = bp and bp:FindFirstChild(itemName)
if tool then
pcall(function() hum:EquipTool(tool) end)
task.wait(0.05)
end
return char:FindFirstChild(itemName) ~= nil
end

function collectReceiverCandidates()
local npcRoot = workspace:FindFirstChild("Ignore")
npcRoot = npcRoot and npcRoot:FindFirstChild("NPCs") or nil
if not npcRoot then return {} end
local hrp = getHRP()
local arr, seen = {}, {}
for _, m in ipairs(npcRoot:GetDescendants()) do
if m:IsA("Model") and not seen[m] and m.Name ~= "Fisherman" then
	local pos = getPos(m)
	if pos and (m:GetAttribute("DialogueModule") or m:FindFirstChild("HumanoidRootPart") or m:FindFirstChildWhichIsA("BasePart", true)) then
		seen[m] = true
		table.insert(arr, { model = m, name = m.Name, d = hrp and (hrp.Position - pos).Magnitude or 0 })
	end
end
end
table.sort(arr, function(a, b) return a.d < b.d end)
return arr
end

function questCompleted()
local q = getQuests()
return q and q.Completed == true
end

function activateCarry(item)
local char = player.Character
local hum = char and char:FindFirstChildOfClass("Humanoid")
local tool = char and char:FindFirstChild(item)
if tool and tool:IsA("Tool") then
	useToolClicks(tool, hum, 1, 0)
else
	safeVirtualClick()
end
end
function resolvePath(pathStr)
local cur = workspace
for seg in string.gmatch(tostring(pathStr), "[^%.]+") do
	cur = cur and cur:FindFirstChild(seg)
	if not cur then return nil end
end
return cur
end
function FISH.log(_) end

function FISH.questHistory(name)
local q = getQuests()
local hist = q and q.History
return type(hist) == "table" and hist[name] == true
end

function FISH.questActive(name)
local q = getQuests()
return q and q.Active == name
end

function FISH.superRodQuestDone()
return FISH.questHistory(FISH.QUEST_CHALLENGE)
end

function FISH.rodQuestMode()
return FISH.SUPER and not FISH.superRodQuestDone()
end

function FISH.rodUnlocked(rodName)
local d = getData()
local cat = d and d.Weapons and d.Weapons[FISH.ROD_CATEGORY]
return cat and cat[rodName] == true
end

function FISH.bestRodName()
for _, rodName in ipairs(FISH.RODS) do
	if FISH.rodUnlocked(rodName) or findToolByName(rodName) then
		return rodName
	end
end
local _, name = FISH.findRod()
return name
end

function FISH.ensureRodLoadout(rodName)
if not rodName then return false end
local hasTool = findToolByName(rodName) ~= nil
local unlocked = FISH.rodUnlocked(rodName)
if not hasTool and not unlocked then return false end
local _, curName = FISH.findRod()
if curName == rodName and hasTool then return true end
if unlocked or hasTool then
	exec("Equip", { rodName, FISH.ROD_CATEGORY })
	task.wait(0.35)
end
return findToolByName(rodName) ~= nil
end

function FISH.ensureBestRodLoadout()
local best = FISH.bestRodName()
if best and FISH.ensureRodLoadout(best) then return true end
for _, rodName in ipairs(FISH.RODS) do
	if FISH.rodUnlocked(rodName) or findToolByName(rodName) then
		if FISH.ensureRodLoadout(rodName) then return true end
	end
end
return FISH.findRod() ~= nil
end

function FISH.isToolName(name)
if not name then return false end
local low = string.lower(name)
if low:find("rod", 1, true) then return false end
for _, sz in ipairs({ "small", "medium", "large", "huge" } ) do
if low:find(sz, 1, true) then
	for _, sp in ipairs({ "flooper", "busser", "lubber", "jawber" } ) do
		if low:find(sp, 1, true) then return true end
	end
end
end
return false
end

function FISH.scanTools()
local out = {}
function scan(parent)
if not parent then return end
for _, t in ipairs(parent:GetChildren()) do
	if t:IsA("Tool") and FISH.isToolName(t.Name) then
		table.insert(out, t)
	end
end
end
scan(player.Character)
scan(player:FindFirstChild("Backpack"))
return out
end

function FISH.countTools()
return #FISH.scanTools()
end

function FISH.shouldKeepForQuest()
if not FISH.rodQuestMode() then return false end
return not FISH.questHistory(FISH.QUEST_TASK)
end

function FISH.isMediumOrLarge(name)
if not name then return false end
local low = string.lower(name)
return low:find("medium", 1, true) ~= nil or low:find("large", 1, true) ~= nil
end

function FISH.isProtectedFish(name)
if not FISH.shouldKeepForQuest() or not name then return false end
if FISH.objectiveNeeded(name) then return true end
return FISH.isMediumOrLarge(name)
end

function FISH.countSellableTools()
local n = 0
for _, t in ipairs(FISH.scanTools()) do
if not FISH.isProtectedFish(t.Name) then n += 1 end
end
return n
end

function FISH.stashProtectedFish()
local stashed = {}
if not FISH.shouldKeepForQuest() then return stashed end
local keep = workspace:FindFirstChild("FishQuestKeep_" .. tostring(player.UserId))
if not keep then
keep = Instance.new("Folder")
keep.Name = "FishQuestKeep_" .. tostring(player.UserId)
keep.Parent = workspace
end
for _, t in ipairs(FISH.scanTools()) do
if FISH.isProtectedFish(t.Name) then
	pcall(function() t.Parent = keep end)
	table.insert(stashed, t)
end
end
if #stashed > 0 then
FISH.log(string.format("giữ %d cá cho quest (medium/large + còn thiếu)", #stashed))
end
return stashed
end

function FISH.restoreStashedFish(stashed)
local bp = player:FindFirstChild("Backpack")
if not bp then return end
for _, t in ipairs(stashed) do
if t and t.Parent then
	pcall(function() t.Parent = bp end)
end
end
end

function FISH.hasToolNamed(name)
for _, t in ipairs(FISH.scanTools()) do
if t.Name == name then return true end
end
return false
end

function FISH.findRod()
for _, rodName in ipairs(FISH.RODS) do
local t = findToolByName(rodName)
if t then return t, rodName end
end
local char, bp = player.Character, player:FindFirstChild("Backpack")
for _, where in ipairs({ char, bp } ) do
if where then
	for _, t in ipairs(where:GetChildren()) do
		if t:IsA("Tool") and string.find(string.lower(t.Name), "rod", 1, true) then
			return t, t.Name
		end
	end
end
end
return nil, nil
end

function FISH.rodHeld(rod)
return rod and player.Character and rod.Parent == player.Character
end

function FISH.ensureRodReady()
if FISH.hasPendingItems() or FISH_STATE.itemSession then return nil end
local rod = FISH.findRod()
local want = FISH.bestRodName()
if want and (not rod or select(2, FISH.findRod()) ~= want) then
FISH.ensureRodLoadout(want)
rod = FISH.findRod()
end
if not rod then
FISH.ensureBestRodLoadout()
rod = FISH.findRod()
end
if not rod then return nil end
if FISH.rodHeld(rod) then return rod end
return FISH.equipBestRod()
end

function FISH.equipBestRod()
FISH.ensureBestRodLoadout()
local bestName = FISH.bestRodName()
local rod = (bestName and findToolByName(bestName)) or select(1, FISH.findRod())
if not rod then return nil end
if FISH.rodHeld(rod) then return rod end
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
while isActive() and FISH.ON and not FISH.rodHeld(rod) and (os.clock() - t0) < 1.5 do
	task.wait(0.05)
end
if not FISH.rodHeld(rod) then
	pcall(function() rod.Parent = char end)
	task.wait(0.1)
	pcall(function() hum:EquipTool(rod) end)
	task.wait(0.08)
end
return FISH.rodHeld(rod) and rod or nil
end

function FISH.clickRod(rod)
if not FISH.rodHeld(rod) then return false end
if pcall(function() rod:Activate() end) then return true end
return safeVirtualClick()
end

function FISH.stateBrief()
local rod = FISH.findRod()
return string.format(
"held=%s lineOut=%s sparkles=%s inMini=%s fish=%s",
tostring(FISH.rodHeld(rod)), tostring(FISH.lineOut()), tostring(FISH.onHook()),
tostring(FISH_STATE.inMinigame), tostring(FISH_STATE.fishCount)
)
end

function FISH.isBusyFishing()
return FISH_STATE.inMinigame or FISH_STATE.solving or FISH.lineOut()
end

function FISH.getRope()
local rope = workspace:FindFirstChild("FishingRope_" .. tostring(player.UserId))
if rope then return rope end
for _, c in ipairs(workspace:GetChildren()) do
if string.sub(c.Name, 1, 12) == "FishingRope_" then return c end
end
return nil
end

FISH.getBobber = LPH_NO_VIRTUALIZE(function()
local rope = FISH.getRope()
return rope and rope:FindFirstChild("Bobber")
end)

FISH.lineOut = LPH_NO_VIRTUALIZE(function()
return FISH.getBobber() ~= nil
end)

FISH.onHook = LPH_NO_VIRTUALIZE(function()
local b = FISH.getBobber()
return b ~= nil and b:FindFirstChild("Sparkles") ~= nil
end)

function FISH.sendAction(action)
return exec("FishingEvent", { action })
end

FISH.waitUntil = LPH_NO_VIRTUALIZE(function(cond, timeout)
local t0 = os.clock()
while isActive() and FISH.ON and not cond() and (os.clock() - t0) < timeout do
task.wait(0.05)
end
return cond()
end)

function FISH.tapGui(btn)
if not btn then return false end
local ap, as = btn.AbsolutePosition, btn.AbsoluteSize
if as.X <= 2 or as.Y <= 2 then return false end
local x = ap.X + as.X * 0.5
local y = ap.Y + as.Y * 0.5
if not UNC.mobile then
local inset = GuiService:GetGuiInset()
x += inset.X
y += inset.Y
end
if UNC.vim then
local ok = pcall(function()
	VirtualInputManager:SendMouseButtonEvent(x, y, 0, true, game, 1)
	task.wait(0.03)
	VirtualInputManager:SendMouseButtonEvent(x, y, 0, false, game, 1)
end)
if ok then return true end
end
return safeVirtualClick()
end

function FISH.vimClick(btn)
if UNC.vim then
local okp = pcall(function()
	local ap, as = btn.AbsolutePosition, btn.AbsoluteSize
	local x = ap.X + as.X / 2
	local y = ap.Y + as.Y / 2
	if not UNC.mobile then
		local inset = GuiService:GetGuiInset()
		x += inset.X
		y += inset.Y
	end
	VirtualInputManager:SendMouseButtonEvent(x, y, 0, true, game, 0)
	VirtualInputManager:SendMouseButtonEvent(x, y, 0, false, game, 0)
end)
if okp then return true end
end
if btn and pcall(function() btn:Activate() end) then return true end
return safeVirtualClick()
end

FISH.clickButton = LPH_NO_VIRTUALIZE(function(btn)
if not btn then return false end
-- Thử Activate trước (PC + mobile GUI đều ăn)
if btn:IsA("GuiButton") and pcall(function() btn:Activate() end) then return true end
if pcall(function() btn:Activate() end) then return true end
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
-- PC: VIM + inset; mobile: tap tọa độ
if FISH.vimClick(btn) then return true end
if FISH.tapGui(btn) then return true end
return safeVirtualClick()
end)

FISH.readMiniCount = LPH_NO_VIRTUALIZE(function(gui)
local bestA, bestB, bestLbl
for _, d in ipairs(gui:GetDescendants()) do
if d:IsA("TextLabel") then
	local a, b = string.match(d.Text or "", "^%s*(%d+)%s*/%s*(%d+)%s*$")
	if a and b then
		a, b = tonumber(a), tonumber(b)
		if not bestA or a > bestA then
			bestA, bestB, bestLbl = a, b, d
		end
	end
end
end
return bestA, bestB, bestLbl
end)

FISH.surfaceBrightness = LPH_NO_VIRTUALIZE(function(btn)
if not btn then return 0 end
local best = 0
function scan(inst, depth)
if depth > 5 or not inst then return end
if inst:IsA("GuiObject") then
	if inst.BackgroundTransparency < 0.88 then
		local c = inst.BackgroundColor3
		best = math.max(best, c.R + c.G + c.B)
	end
	if inst:IsA("ImageLabel") or inst:IsA("ImageButton") then
		if inst.ImageTransparency < 0.88 then
			local c = inst.ImageColor3
			best = math.max(best, c.R + c.G + c.B)
		end
	end
end
for _, ch in ipairs(inst:GetChildren()) do
	scan(ch, depth + 1)
end
end
scan(btn, 0)
return best
end)

FISH.isClearlyBright = LPH_NO_VIRTUALIZE(function(btn)
return FISH.surfaceBrightness(btn) >= 2.35
end)

-- Đọc thẳng BackgroundColor3 nút (game set trực tiếp, không qua child)
FISH.btnBgSum = LPH_NO_VIRTUALIZE(function(btn)
if not btn or not btn:IsA("GuiObject") then return 0 end
if (btn.BackgroundTransparency or 0) > 0.5 then return 0 end
local c = btn.BackgroundColor3
return c.R + c.G + c.B
end)

-- Decompile RodLocalScript: highlight Size 88 + bg 230,230,230 | normal 78 + bg 25,25,25
FISH.pickHighlightButton = LPH_NO_VIRTUALIZE(function(gui)
local btns = FISH.miniGameButtons(gui)
if #btns < 3 then return nil, -999, nil end
local rows = {}
for _, btn in ipairs(btns) do
	if btn.Visible then
		local as = btn.AbsoluteSize
		local sz = math.min(as.X, as.Y)
		if sz > 40 then
			local stroke = btn:FindFirstChildOfClass("UIStroke")
			table.insert(rows, {
				btn = btn,
				size = sz,
				bg = FISH.btnBgSum(btn),
				stroke = stroke and stroke.Thickness or 0,
			})
		end
	end
end
if #rows < 3 then return nil, -999, nil end

table.sort(rows, function(a, b)
	if math.abs(a.size - b.size) > 2 then return a.size > b.size end
	return a.bg > b.bg
end)
local top, second = rows[1], rows[2]
if top.size - second.size >= 5 then
	return top.btn, 10, top.bg >= 2.65 and "white" or "grey"
end

table.sort(rows, function(a, b) return a.bg > b.bg end)
top, second = rows[1], rows[2]
local delta = top.bg - second.bg
if top.bg >= 2.5 and delta >= 0.25 then return top.btn, 10, "white" end
if top.bg >= 1.55 and delta >= 0.3 then return top.btn, 9, "grey" end
if top.stroke >= 1.8 and top.bg > second.bg + 0.2 then return top.btn, 8, "grey" end
return nil, -999, nil
end)

-- So sánh độ sáng giữa các nút — ăn cả theme tối (xám) lẫn PC trắng
FISH.relativeHighlightButton = LPH_NO_VIRTUALIZE(function(gui)
local btns = FISH.miniGameButtons(gui)
if #btns < 3 then return nil, -999 end
local rows = {}
for _, btn in ipairs(btns) do
	if btn.Visible then
		local as = btn.AbsoluteSize
		if as.X > 2 and as.Y > 2 then
			local lum = FISH.surfaceBrightness(btn)
			local bg = btn.BackgroundColor3
			local bgSum = bg.R + bg.G + bg.B
			local bt = btn.BackgroundTransparency or 0
			table.insert(rows, {
				btn = btn, lum = lum, bgSum = bgSum, bt = bt,
				size = math.min(as.X, as.Y),
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
if FISH.isHighlightBtn(top.btn) and delta >= 0.2 then return top.btn, 9 end
return nil, -999
end)

function FISH.miniLog(msg)
if FISH.MINI_DEBUG then FISH.log("[mini] " .. tostring(msg)) end
end

function FISH.logMiniStep(remain, total, lastRemain, extra)
if not FISH.MINI_STEP_LOG or not remain or not total then return end
local done = total - remain
if lastRemain == nil then
FISH.log(string.format("[mini] start | total=%d steps%s",
	total, extra and (" | " .. extra) or ""))
return
end
if remain < lastRemain then
FISH.log(string.format("[mini] step %d/%d | remain %d->%d%s",
	done, total, lastRemain, remain, extra and (" | " .. extra) or ""))
elseif remain > lastRemain then
FISH.log(string.format("[mini] counter tăng? remain %d->%d / %d%s",
	lastRemain, remain, total, extra and (" | " .. extra) or ""))
end
end

FISH.buttonScore = LPH_NO_VIRTUALIZE(function(btn, lum)
if (not btn.Visible) or (btn.AbsoluteSize.X <= 2) or (btn.AbsoluteSize.Y <= 2) then
return -999
end
lum = lum or FISH.surfaceBrightness(btn)
local score = 0
local bg = btn.BackgroundColor3
if lum >= 2.35 then
score += 10
elseif lum >= 1.8 then
score += 6
elseif bg.R >= 0.82 and bg.G >= 0.82 and bg.B >= 0.82 then
score += 8
elseif bg.R >= 0.65 and bg.G >= 0.65 and bg.B >= 0.65 then
score += 4
end
local as = btn.AbsoluteSize
if as.X >= 84 or as.Y >= 84 then score += 3 end
local stroke = btn:FindFirstChildOfClass("UIStroke")
if stroke then
local c = stroke.Color
if stroke.Thickness >= 1.8 then score += 2 end
if (c.R + c.G + c.B) >= 2.4 then score += 2 end
end
local label = btn:FindFirstChild("TextLabel")
if label and label:IsA("TextLabel") then
local tc = label.TextColor3
if (tc.R + tc.G + tc.B) <= 0.25 then score += 2 end
end
if lum >= 2.0 or (bg.R + bg.G + bg.B) >= 2.0 then score += 1 end
return score
end)

FISH.bestButton = LPH_NO_VIRTUALIZE(function(gui)
local rows = {}
for _, d in ipairs(gui:GetDescendants()) do
if d:IsA("TextButton") or d:IsA("ImageButton") then
	local lum = FISH.surfaceBrightness(d)
	local s = FISH.buttonScore(d, lum)
	if s > -999 then
		table.insert(rows, { btn = d, score = s, lum = lum })
	end
end
end
if #rows == 0 then return nil, -999 end
table.sort(rows, function(a, b)
if a.lum ~= b.lum then return a.lum > b.lum end
return a.score > b.score
end)
local top = rows[1]
local secondLum = (#rows >= 2) and rows[2].lum or 0
if top.lum >= 2.35 and (top.lum - secondLum) >= 0.55 then
return top.btn, math.max(top.score, 8)
end
local best, bestScore = top.btn, top.score
for _, row in ipairs(rows) do
if row.score > bestScore then best, bestScore = row.btn, row.score end
end
return best, bestScore
end)

FISH.miniGameButtons = LPH_NO_VIRTUALIZE(function(gui)
local bestRow, bestCount = nil, 0
for _, d in ipairs(gui:GetDescendants()) do
if d:IsA("Frame") then
	local btns = {}
	for _, ch in ipairs(d:GetChildren()) do
		if ch:IsA("TextButton") and ch:FindFirstChild("TextLabel") then
			table.insert(btns, ch)
		end
	end
	if #btns > bestCount then
		bestRow, bestCount = btns, #btns
	end
end
end
if bestRow and bestCount >= 3 then return bestRow end
local all = {}
for _, d in ipairs(gui:GetDescendants()) do
if d:IsA("TextButton") and d:FindFirstChild("TextLabel") then
	table.insert(all, d)
end
end
return all
end)

FISH.isHighlightBtn = LPH_NO_VIRTUALIZE(function(btn)
if not btn or not btn:IsA("GuiButton") or not btn.Visible then return false end
local as = btn.AbsoluteSize
if as.X <= 2 or as.Y <= 2 then return false end
local minSz = math.min(as.X, as.Y)
if minSz < 52 then return false end
local bgSum = FISH.btnBgSum(btn)
if bgSum >= 1.55 then return true end
local lum = FISH.surfaceBrightness(btn)
if lum >= 2.0 and bgSum >= 0.5 then return true end
if lum >= 1.45 and bgSum >= 1.0 then return true end
local stroke = btn:FindFirstChildOfClass("UIStroke")
if stroke and stroke.Thickness >= 1.8 then
	local sc = stroke.Color.R + stroke.Color.G + stroke.Color.B
	if sc >= 2.0 and bgSum >= 0.8 then return true end
end
return false
end)

FISH.mobileHighlightButton = LPH_NO_VIRTUALIZE(function(gui)
local btns = FISH.miniGameButtons(gui)
local rows = {}
for _, btn in ipairs(btns) do
	if FISH.isHighlightBtn(btn) then
		local as = btn.AbsoluteSize
		table.insert(rows, { btn = btn, size = math.min(as.X, as.Y), lum = FISH.surfaceBrightness(btn), strict = true })
	end
end
if #rows == 0 then
	for _, btn in ipairs(btns) do
		local lum = FISH.surfaceBrightness(btn)
		local as = btn.AbsoluteSize
		table.insert(rows, { btn = btn, size = math.min(as.X, as.Y), lum = lum, strict = false })
	end
	table.sort(rows, function(a, b)
		if a.lum ~= b.lum then return a.lum > b.lum end
		return a.size > b.size
	end)
	local top = rows[1]
	local second = rows[2]
	if top and top.lum >= 2.1 and (not second or (top.lum - second.lum) >= 0.35) then
		return top.btn, 10
	end
	return nil, -999
end
if #rows > 1 then
	table.sort(rows, function(a, b)
		if a.strict ~= b.strict then return a.strict end
		if a.lum ~= b.lum then return a.lum > b.lum end
		return a.size > b.size
	end)
	if rows[1].size - rows[2].size < 3 and rows[1].lum - rows[2].lum < 0.3 then
		return nil, -999
	end
end
return rows[1].btn, 10
end)

FISH.pickMiniButton = LPH_NO_VIRTUALIZE(function(gui)
local pBtn, pScore, theme = FISH.pickHighlightButton(gui)
if pBtn then return pBtn, pScore, theme end
local rBtn, rScore = FISH.relativeHighlightButton(gui)
if rBtn then return rBtn, rScore, "lum" end
local hBtn, hScore = FISH.mobileHighlightButton(gui)
if hBtn then return hBtn, hScore, UNC.mobile and "mobile" or "grey" end
local b, s = FISH.bestButton(gui)
return b, s, nil
end)

FISH.buttonLabel = LPH_NO_VIRTUALIZE(function(btn)
if not btn then return "nil" end
local lb = btn:FindFirstChild("TextLabel")
if lb and lb:IsA("TextLabel") and lb.Text and lb.Text ~= "" then
return btn.Name .. ":" .. lb.Text
end
return btn.Name
end)

function FISH.solveMinigame()
local now = os.clock()
local debounce = UNC.mobile and 0.35 or 0.2
if FISH_STATE.solving or (now - FISH_STATE.lastSolveAt) < debounce then return end
FISH_STATE.lastSolveAt = now
FISH_STATE.solving = true
FISH_STATE.inMinigame = true
task.spawn(LPH_NO_VIRTUALIZE(function()
local pg = player:FindFirstChildOfClass("PlayerGui")
FISH.log("FishingMinigame -> solver ON")
local lastBtn, lastRemain, lastClickAt = nil, nil, 0
local lastShuffleAt = 0
local lastPrintedRemain = nil
local lastNoBtnLog = 0
local lastDetectLog = 0
local sawEnabled = false
local sawCounter = false
local lastWaitLogAt = 0
while isActive() and FISH.ON do
	local gui = pg and pg:FindFirstChild("FishingMinigame")
	local now2 = os.clock()
	if not gui then
		if sawEnabled then
			FISH.miniLog("GUI removed after enabled -> stop solver")
			break
		end
		if FISH.MINI_DEBUG and (now2 - lastWaitLogAt) >= 0.8 then
			FISH.miniLog("waiting GUI object...")
			lastWaitLogAt = now2
		end
		task.wait(0.05)
	elseif not gui.Enabled then
		if sawEnabled then
			FISH.miniLog("GUI disabled after enabled -> stop solver")
			break
		end
		if FISH.MINI_DEBUG and (now2 - lastWaitLogAt) >= 0.8 then
			FISH.miniLog("waiting GUI enabled...")
			lastWaitLogAt = now2
		end
		task.wait(0.05)
	else
		if not sawEnabled then
			sawEnabled = true
			lastShuffleAt = now2
			FISH.miniLog("GUI enabled -> chờ counter reset...")
			local readyBy = now2 + FISH.MINI_READY_WAIT
			while isActive() and FISH.ON and gui.Enabled and os.clock() < readyBy do
				local r, t = FISH.readMiniCount(gui)
				if r and t and r > 0 then
					sawCounter = true
					FISH.miniLog(string.format("counter ready %d/%d", r, t))
					break
				end
				task.wait(0.05)
			end
			lastShuffleAt = os.clock()
			FISH.miniLog("start solving")
		end
		local remain, total = FISH.readMiniCount(gui)
		if total then FISH_STATE.miniTotal = total end
		if remain and remain > 0 then sawCounter = true end
		if remain == 0 then
			if not sawCounter then
				if FISH.MINI_DEBUG and (now2 - lastNoBtnLog) >= 0.4 then
					FISH.miniLog("counter 0/? (stale) — chờ game set 10/10...")
					lastNoBtnLog = now2
				end
				task.wait(0.08)
				continue
			end
			FISH.log(string.format("[mini] xong | 0/%d steps", total or FISH_STATE.miniTotal or 0))
			break
		end
		if remain and remain ~= lastPrintedRemain then
			FISH.logMiniStep(remain, total, lastPrintedRemain)
			lastPrintedRemain = remain
		elseif not remain and FISH.MINI_STEP_LOG and (now2 - lastNoBtnLog) >= 1 then
			FISH.log("[mini] WARN: không đọc được counter x/y trên GUI")
			lastNoBtnLog = now2
		end
		local btn, score, theme
		btn, score, theme = FISH.pickMiniButton(gui)
		local clickIv = UNC.mobile and (tonumber(CFG.FISHMINIGAME_CLICK_INTERVAL_MOBILE) or 0.24)
			or FISH.MINI_CLICK_INTERVAL
		local shuffleWait = UNC.mobile and (tonumber(CFG.FISHMINIGAME_SHUFFLE_WAIT) or 0.18)
			or FISH.MINI_SHUFFLE_WAIT
		local pollIv = UNC.mobile and (tonumber(CFG.FISHMINIGAME_POLL_MOBILE) or 0.09) or FISH.MINI_POLL
		local counterDecreased = (remain and lastRemain and remain < lastRemain) and true or false
		if counterDecreased then lastShuffleAt = now2 end
		local bgSum = btn and FISH.btnBgSum(btn) or 0
		local shouldClick, reason = false, "hold"

		local canByInterval = (now2 - lastClickAt) >= clickIv
		local settled = (now2 - lastShuffleAt) >= shuffleWait
		if btn and score >= 8 and settled and canByInterval then
			shouldClick = true
			if theme == "white" then reason = "white-pc"
			elseif theme == "grey" then reason = "grey-pc"
			elseif UNC.mobile then reason = "mobile"
			else reason = "slow" end
		elseif not settled then
			reason = "shuffle-wait"
		end

		if FISH.MINI_STEP_LOG and (now2 - lastDetectLog) >= 0.35 then
			local sz = btn and math.min(btn.AbsoluteSize.X, btn.AbsoluteSize.Y) or 0
			FISH.log(string.format("[mini] theme=%s score=%d bg=%.2f sz=%.0f iv=%.2fs | %s click=%s | %s/%s btn=%s",
				tostring(theme), tonumber(score) or -999, bgSum, sz, clickIv,
				reason, tostring(shouldClick), tostring(remain), tostring(total), FISH.buttonLabel(btn)))
			lastDetectLog = now2
		end

		if shouldClick and btn then
			local okClick = FISH.clickButton(btn)
			if okClick then
				lastBtn = btn
				lastClickAt = now2
				lastShuffleAt = now2
				task.wait(shuffleWait)
			end
			if remain then lastRemain = remain end
			FISH.log(string.format("[mini] >>> click=%s ok=%s theme=%s score=%d bg=%.2f | %s/%s | %s",
				reason, tostring(okClick), tostring(theme), score, bgSum,
				tostring(remain), tostring(total), FISH.buttonLabel(btn)))
			FISH.miniLog(string.format("click=%s btn=%s score=%d counter=%s/%s",
				tostring(okClick), FISH.buttonLabel(btn), score,
				tostring(remain), tostring(total)))
		else
			if remain then lastRemain = remain end
			if FISH.MINI_DEBUG and (now2 - lastNoBtnLog) >= 0.6 then
				FISH.miniLog(string.format("wait btn=%s score=%s counter=%s/%s dt=%.2f",
					FISH.buttonLabel(btn), tostring(score),
					tostring(remain), tostring(total), now2 - lastClickAt))
				lastNoBtnLog = now2
			end
		end
		task.wait(pollIv)
	end
end
FISH_STATE.inMinigame = false
FISH_STATE.solving = false
FISH_STATE.miniTotal = nil
FISH.log("FishingMinigame -> solver OFF")
end))
end

function FISH.onEventMsg(msg)
if msg == "FishingMinigame" then
if FISH.MINI_TRY_CAUGHT then
	task.delay(FISH.WIN_DELAY, function() FISH.sendAction("Caught") end)
end
FISH.solveMinigame()
elseif msg == "FishingReeled" then
FISH_STATE.inMinigame = false
FISH_STATE.miniTotal = nil
end
end

function FISH.onData(_, value, statPath)
if statPath == "Stats.Fish" and type(value) == "number" then
if FISH_STATE.fishCount ~= nil and value > FISH_STATE.fishCount then
	FISH.log(string.format(">>> TRÚNG CÁ! Stats.Fish = %d", value))
end
FISH_STATE.fishCount = value
end
end

function FISH.setupListeners()
if FISH_STATE.listenersReady then return end
FISH_STATE.listenersReady = true
if not FISH_STATE.uncLogged then
FISH_STATE.uncLogged = true
FISH.log(string.format(
	"env mobile=%s kb=%s mouse=%s touch=%s pref=%s | low=%s vim=%s | clickIv=%.2f retry=%.2f poll=%.3f",
	tostring(UNC.mobile),
	tostring(UserInputService.KeyboardEnabled),
	tostring(UserInputService.MouseEnabled),
	tostring(UserInputService.TouchEnabled),
	tostring(UserInputService.PreferredInput),
	tostring(UNC.low), tostring(UNC.vim),
	FISH.MINI_CLICK_INTERVAL, FISH.MINI_RETRY_SAME, FISH.MINI_POLL))
end
function listen(r)
local ok, isEv = pcall(function() return r:IsA("RemoteEvent") end)
if not (ok and isEv) then
	ok, isEv = pcall(function() return r:IsA("UnreliableRemoteEvent") end)
end
if not (ok and isEv) then return end
if r.Name == "FishingEvent" then
	pcall(function() r.OnClientEvent:Connect(function(m) pcall(FISH.onEventMsg, m) end) end)
elseif r.Name == "DataEvent" then
	pcall(function() r.OnClientEvent:Connect(function(...) pcall(FISH.onData, ...) end) end)
end
end
task.defer(function()
if not isActive() or not FISH.ON then return end
for _, d in ipairs(game:GetDescendants()) do
	if not isActive() then break end
	listen(d)
end
end)
game.DescendantAdded:Connect(listen)
task.spawn(function()
local pg = player:WaitForChild("PlayerGui", 10)
if not pg then return end
function hook(gui)
	if gui.Name ~= "FishingMinigame" then return end
	pcall(function()
		gui:GetPropertyChangedSignal("Enabled"):Connect(function()
			if gui.Enabled then FISH.solveMinigame() end
		end)
	end)
	if gui.Enabled then FISH.solveMinigame() end
end
for _, g in ipairs(pg:GetChildren()) do hook(g) end
pg.ChildAdded:Connect(hook)
end)
end

function FISH.useCacheTools()
if FISH.isBusyFishing() or FISH_STATE.pause then return 0 end
local char = player.Character
local hum = char and char:FindFirstChildOfClass("Humanoid")
if not hum then return 0 end
local used = 0
local bp = player:FindFirstChild("Backpack")
local list = {}
for _, where in ipairs({ char, bp } ) do
if where then
	for _, t in ipairs(where:GetChildren()) do
		if t:IsA("Tool") and string.find(string.lower(t.Name), "cache", 1, true) then
			table.insert(list, t)
		end
	end
end
end
for _, tool in ipairs(list) do
if not isActive() then break end
useToolClicks(tool, hum, FARM.USE_CLICKS, FARM.USE_DELAY)
used += 1
task.wait(0.05)
end
if used > 0 then FISH.equipBestRod() end
return used
end

function FISH.objectiveNeeded(fishName)
local q = getQuests()
if not q or q.Active ~= FISH.QUEST_TASK then return false end
local obj = q.Objectives and q.Objectives[fishName]
if not obj then return false end
local prog = tonumber(type(obj) == "table" and obj.Progress) or 0
local req = tonumber(type(obj) == "table" and (obj.Requirement or obj.Goal)) or 1
return prog < req
end

function FISH.questActiveNow()
local q = getQuests()
local a = q and q.Active
return a == FISH.QUEST_TASK or a == FISH.QUEST_CHALLENGE
end

function FISH.nearPos(pos, dist)
local hrp = getHRP()
return hrp and pos and (hrp.Position - pos).Magnitude <= (dist or 14)
end

function FISH.rememberSpot(inst)
local pos = getPos(inst)
if pos then FISH_STATE.spotPos = pos end
end

function FISH.setupMixerSpot()
local mixer = resolvePath(FISH.MIXER_PATH)
if not mixer then
logOnce("fish:mixer", "[Fish] mixer not found: " .. FISH.MIXER_PATH)
return false
end
local pos = getPos(mixer)
if not pos then return false end
if not FISH.nearPos(pos, 18) then
tpNear(mixer)
end
local hrp = getHRP()
FISH_STATE.spotPos = hrp and hrp.Position or pos
FISH.log("fish spot -> mixer (đứng đây câu)")
return true
end

function FISH.refreshFishSpot()
if FISH.rodQuestMode() then
if FISH_STATE.spotKind ~= "fisherman" then
	FISH_STATE.spotPos = nil
	FISH_STATE.spotKind = "fisherman"
end
if not FISH_STATE.spotPos then
	local fm = findNPC(FISH.FISHERMAN)
	if fm then
		FISH.rememberSpot(fm)
		FISH.log("fish spot -> Fisherman")
	end
end
else
if FISH_STATE.spotKind ~= "mixer" then
	FISH_STATE.spotPos = nil
	FISH_STATE.spotKind = "mixer"
end
if not FISH_STATE.spotPos then
	FISH.setupMixerSpot()
end
end
end

function FISH.stayAtSpot()
if not FISH_STATE.spotPos then return end
if FISH_STATE.pause then return end
if FISH.nearPos(FISH_STATE.spotPos, 18) then return end
local hrp = getHRP()
if hrp then
pcall(function() hrp.CFrame = CFrame.new(FISH_STATE.spotPos + Vector3.new(0, 2, 0)) end)
end
end

function FISH.useConsumablesInPlace()
useAllConsumables()
end

function FISH.stepConsumables()
clickMixers()
useAllConsumables()
end

function FISH.clickCookingStation()
local station = resolvePath(FISH.COOK_PATH)
if not station then
logOnce("fish:cook", "[Fish] CookingStation not found")
return false
end
local cd = (station:IsA("ClickDetector") and station)
or station:FindFirstChildOfClass("ClickDetector")
or station:FindFirstChildWhichIsA("ClickDetector", true)
tpNear(station)
if cd then
for _ = 1, 3 do
	safeFireClick(cd)
	task.wait(0.15)
end
return true
end
return safeVirtualClick()
end

function FISH.sellToCooker()
local cooker = findNPC(FISH.COOKER_NPC)
if not cooker then
logOnce("fish:cooker", "[Fish] Cooker NPC not found")
return false
end
clickNPC(cooker)
task.wait(0.2)
exec("SellFish", {})
FISH.log("sold fish to Cooker")
FISH_STATE.lastSellAt = os.clock()
return true
end

function FISH.cookAndSell()
FISH_STATE.pause = true
local stashed = FISH.stashProtectedFish()
if FISH.countTools() < FISH.SELL_AT then
FISH.restoreStashedFish(stashed)
FISH_STATE.pause = false
return false
end
local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
if hum then pcall(function() hum:UnequipTools() end) end
task.wait(0.15)
FISH.clickCookingStation()
task.wait(0.35)
FISH.sellToCooker()
task.wait(0.25)
FISH.restoreStashedFish(stashed)
FISH.equipBestRod()
FISH_STATE.pause = false
if FISH_STATE.spotPos then FISH.stayAtSpot() end
return true
end

function FISH.deliverTaskFish()
local fm = findNPC(FISH.FISHERMAN)
if not fm then return false end
local any = false
for _, fishName in ipairs(FISH.TASK_FISH) do
if FISH.objectiveNeeded(fishName) and FISH.hasToolNamed(fishName) then
	any = true
	break
end
end
if not any then return false end
FISH.rememberSpot(fm)
if not FISH.nearPos(FISH_STATE.spotPos or getPos(fm), 16) then
clickNPC(fm)
FISH.rememberSpot(fm)
else
setCurrentMerchant(fm)
end
for _, fishName in ipairs(FISH.TASK_FISH) do
if FISH.objectiveNeeded(fishName) and FISH.hasToolNamed(fishName) then
	exec("QuestEvents", { "Deliver", fishName })
end
end
FISH_STATE.lastDeliverAt = os.clock()
task.wait(0.15)
return true
end

function FISH.stepFavorQuest()
if FISH.questHistory(FISH.QUEST_FAVOR) then return false end
local q = getQuests()
if not q then return false end
local fm = findNPC(FISH.FISHERMAN)
if not fm then return false end
local active = q.Active

if active == FISH.QUEST_FAVOR and q.Completed == true then
clickNPC(fm)
exec("QuestEvents", { "Claim" })
FISH.log("claimed Wood Rod (Fisherman's Favor)")
task.wait(0.3)
FISH.ensureRodLoadout("Wood Rod")
return true
end

if active == FISH.QUEST_FAVOR and hasItem("Package") then
FISH.rememberSpot(fm)
for _, t in ipairs(collectReceiverCandidates()) do
	if not isActive() or not FISH.ON then break end
	if questCompleted() or not hasItem("Package") then break end
	equipItem("Package")
	tpFaceNear(t.model, 4, 1)
	activateCarry("Package")
	task.wait(CARRY_SWEEP_WAIT)
end
if questCompleted() then
	FISH.log("delivered Package -> claim Wood Rod")
end
return true
end

if active == FISH.QUEST_FAVOR and not hasItem("Package") and q.Completed ~= true then
clickNPC(fm)
exec("QuestEvents", { "Accept", FISH.QUEST_FAVOR })
FISH.log("re-accept Fisherman's Favor (lost Package?)")
return true
end

if active ~= FISH.QUEST_FAVOR then
clickNPC(fm)
exec("QuestEvents", { "Accept", FISH.QUEST_FAVOR })
FISH.log("accepted Fisherman's Favor (Package -> Wood Rod)")
return true
end
return false
end

function FISH.stepFishermanQuest()
local q = getQuests()
if not q then return false end
local active = q.Active
local fm = findNPC(FISH.FISHERMAN)
if not fm then return false end

if active == FISH.QUEST_CHALLENGE then
FISH.rememberSpot(fm)
if q.Completed == true then
	clickNPC(fm)
	exec("QuestEvents", { "Claim" })
	FISH.log("claimed Super Rod quest")
	FISH.ensureBestRodLoadout()
	return true
end
return false
end

if active == FISH.QUEST_TASK then
FISH.rememberSpot(fm)
if q.Completed == true then
	clickNPC(fm)
	exec("QuestEvents", { "Claim" })
	FISH.log("claimed Sturdy Rod quest")
	FISH.ensureBestRodLoadout()
	return true
end
local now = os.clock()
if (now - (FISH_STATE.lastDeliverAt or 0)) >= 3 then
	FISH.deliverTaskFish()
end
return false
end

if FISH.questHistory(FISH.QUEST_FAVOR) and not FISH.questHistory(FISH.QUEST_TASK) then
if active ~= FISH.QUEST_FAVOR and active ~= FISH.QUEST_TASK then
	clickNPC(fm)
	FISH.rememberSpot(fm)
	exec("QuestEvents", { "Accept", FISH.QUEST_TASK })
	FISH.log("accepted Fisherman's Task")
	return true
end
end

if FISH.questHistory(FISH.QUEST_TASK) and not FISH.questHistory(FISH.QUEST_CHALLENGE) then
if active ~= FISH.QUEST_CHALLENGE and active ~= FISH.QUEST_TASK then
	clickNPC(fm)
	FISH.rememberSpot(fm)
	exec("QuestEvents", { "Accept", FISH.QUEST_CHALLENGE })
	FISH.log("accepted Fisherman's Challenge")
	return true
end
end

return false
end

function FISH.shouldSell()
if (os.clock() - (FISH_STATE.lastSellAt or 0)) < 2 then return false end
if FISH.countSellableTools() < FISH.SELL_AT then return false end
return true
end

function FISH.ensureLoop()
if FISH_STATE.loopRunning then return end
FISH_STATE.loopRunning = true
task.spawn(LPH_NO_VIRTUALIZE(function()
local casts, catches = 0, 0
while isActive() and FISH.ON do
	if FISH_STATE.pause then
		task.wait(0.15)
	elseif not FISH.findRod() then
		FISH.log("no rod in backpack (need Wood/Sturdy/Super Rod)")
		task.wait(2)
	else
		local rod = FISH.equipBestRod()
		if not rod then
			FISH.log("Chưa cầm được cần lên tay, thử lại...")
			task.wait(0.6)
		elseif FISH_STATE.inMinigame then
	
			task.wait(0.15)
		elseif not FISH.lineOut() then
			casts += 1
			FISH.log(string.format("[#%d] Cast... (%s)", casts, FISH.stateBrief()))
			FISH.clickRod(rod)
			if not FISH.waitUntil(function() return FISH.lineOut() or FISH_STATE.inMinigame end, FISH.CAST_TIMEOUT) then
				FISH.log("[warn] cast timeout: không thấy Bobber sau " .. tostring(FISH.CAST_TIMEOUT) .. "s | " .. FISH.stateBrief())
			end
		else
			local before = FISH_STATE.fishCount or 0
			FISH.waitUntil(function() return FISH.onHook() or FISH_STATE.inMinigame or not FISH.lineOut() end, FISH.BITE_TIMEOUT)
			if FISH_STATE.inMinigame then
		
			elseif FISH.onHook() then
				FISH.log("Sparkles! cá cắn -> giật")
				rod = FISH.equipBestRod() or rod
				FISH.clickRod(rod)
				local reeled = FISH.waitUntil(function()
					return not FISH.lineOut() or FISH_STATE.inMinigame or (FISH_STATE.fishCount or 0) > before
				end, FISH.REEL_TIMEOUT)
				if (FISH_STATE.fishCount or 0) > before then
					catches += 1
					FISH.log(string.format("(đã trúng %d/%d lần quăng)", catches, casts))
				elseif not reeled then
					FISH.log("[warn] reel timeout sau Sparkles | " .. FISH.stateBrief())
				end
			elseif FISH.lineOut() then
				FISH.log("[warn] không cắn trong " .. tostring(FISH.BITE_TIMEOUT) .. "s -> reel lại | " .. FISH.stateBrief())
				rod = FISH.equipBestRod() or rod
				FISH.clickRod(rod)
				if not FISH.waitUntil(function() return not FISH.lineOut() end, FISH.REEL_TIMEOUT) then
					FISH.log("[warn] reel timeout sau bite-timeout | " .. FISH.stateBrief())
				end
			end
		end
		task.wait(FISH.LOOP_DELAY)
	end
end
FISH_STATE.loopRunning = false
end))
end

function FISH.step()
if not FISH.ON then return end

FISH.setupListeners()

if not FISH.questHistory(FISH.QUEST_FAVOR) then
if FISH.stepFavorQuest() then
	FISH.ensureLoop()
	return
end
end
if not FISH.findRod() then
FISH.ensureBestRodLoadout()
if not FISH.findRod() and not FISH.questHistory(FISH.QUEST_FAVOR) then
	FISH.ensureLoop()
	return
end
if not FISH.findRod() then
	logThrottle("fish:norod", "[Fish] chưa có rod — làm Fisherman's Favor hoặc Equip Utility", 6)
	FISH.ensureLoop()
	return
end
end

if not FISH_STATE.pause and not FISH.isBusyFishing() then
FISH.equipBestRod()
end

if FISH_STATE.inMinigame or FISH_STATE.solving then
FISH.ensureLoop()
return
end

FISH.refreshFishSpot()
if FISH_STATE.spotPos and not FISH_STATE.pause then
FISH.stayAtSpot()
end

if not FISH.isBusyFishing() and not FISH_STATE.pause then
local now = os.clock()
if (now - (FISH_STATE.lastCacheAt or 0)) >= 2.5 then
	FISH_STATE.lastCacheAt = now
	if FISH.useCacheTools() > 0 then
		FISH.useConsumablesInPlace()
		FISH.equipBestRod()
	end
end
if (now - (FISH_STATE.lastUseAt or 0)) >= 8 then
	FISH_STATE.lastUseAt = now

	FISH.useConsumablesInPlace()
	FISH.equipBestRod()
end

if FISH.rodQuestMode() then
	FISH.stepFishermanQuest()
end
FISH.ensureBestRodLoadout()
if not FISH_STATE.pause and not FISH.isBusyFishing() then
	FISH.equipBestRod()
end

if FISH.shouldSell() then
	FISH.log(string.format(">= %d cá bán được -> cook + sell (giữ quest: %d)",
		FISH.SELL_AT, FISH.countTools() - FISH.countSellableTools()))
	FISH.cookAndSell()
end
elseif FISH.rodQuestMode() and not FISH.lineOut() then
FISH.stepFishermanQuest()
end

FISH.ensureLoop()
end

function syncFishConfig()
	local cfg = getgenv().SigmaFishConfig or {}
	FISH.ON = cfg.AutoFish == true
	FISH.SUPER = cfg.AutoSuperRod == true
	local sell = tonumber(cfg.SellAt) or tonumber(CFG.FISH_SELL_AT)
	FISH.SELL_AT = sell or (FISH.SUPER and 40 or 15)
	STATE.pause = not FISH.ON
end

function fishTick()
	syncFishConfig()
	if not FISH.ON or not isActive() then return end
	if not isWorldReady() then return end
	FISH.step()
end

function startFishLoop()
	if getgenv().__SIGMA_FISH_RUNNING then
		syncFishConfig()
		return
	end
	RUN.id += 1
	local myRun = RUN.id
	getgenv().__SIGMA_FISH_RUNNING = true
	getgenv().__SIGMA_FISH_RUN_ID = myRun
	syncFishConfig()
	task.spawn(LPH_NO_VIRTUALIZE(function()
		while getgenv().__SIGMA_FISH_RUNNING and getgenv().__SIGMA_FISH_RUN_ID == myRun do
			pcall(fishTick)
			task.wait(FISH.LOOP_DELAY)
		end
	end))
end

function stopFishLoop()
	getgenv().__SIGMA_FISH_RUNNING = false
	FISH.ON = false
	STATE.pause = true
	STATE.loopRunning = false
end

SigmaFish = {}

function SigmaFish.setAutoFish(on)
	getgenv().SigmaFishConfig = getgenv().SigmaFishConfig or {}
	getgenv().SigmaFishConfig.AutoFish = on == true
	syncFishConfig()
	if on then startFishLoop() else stopFishLoop() end
end

function SigmaFish.setAutoSuperRod(on)
	getgenv().SigmaFishConfig = getgenv().SigmaFishConfig or {}
	getgenv().SigmaFishConfig.AutoSuperRod = on == true
	syncFishConfig()
	if getgenv().SigmaFishConfig.AutoFish then startFishLoop() end
end

function SigmaFish.setSellAt(n)
	getgenv().SigmaFishConfig = getgenv().SigmaFishConfig or {}
	getgenv().SigmaFishConfig.SellAt = tonumber(n)
	syncFishConfig()
end

function SigmaFish.isRunning()
	return getgenv().__SIGMA_FISH_RUNNING == true and FISH.ON == true
end

function SigmaFish.getStatus()
	syncFishConfig()
	return {
		autoFish = FISH.ON,
		autoSuperRod = FISH.SUPER,
		sellAt = FISH.SELL_AT,
		fishCount = STATE.fishCount,
		inMinigame = STATE.inMinigame,
	}
end

function SigmaFish.stop()
	stopFishLoop()
end

getgenv().SigmaFish = SigmaFish
return SigmaFish
