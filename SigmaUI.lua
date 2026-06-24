--[[
 Sigma Hub — entry loader (One Piece: Final)

 Execute in executor (all modules from GitHub):
   loadstring(game:HttpGet("https://raw.githubusercontent.com/shuys123321sdas/Sigma-Hub/refs/heads/main/SigmaHub.lua", true))()

 Or local:
   loadstring(readfile("UI/UX Syc Hub/SigmaHub.lua"))()

 Debug log: bật/tắt bằng getgenv().SigmaHubDebug = true/false (mặc định true)
]]

local SIGMA_SOURCE_URL = "https://raw.githubusercontent.com/shuys123321sdas/Sigma-Hub/refs/heads/main/Sigma.lua"
local SIGMA_FISH_URL = "https://raw.githubusercontent.com/shuys123321sdas/Sigma-Hub/refs/heads/main/Main.lua"
local SIGMA_UI_URL = "https://raw.githubusercontent.com/shuys123321sdas/Sigma-Hub/refs/heads/main/SigmaUI.lua"

local SAMPLE_PRIMARY = Color3.fromRGB(139, 92, 246)
local LOG_PREFIX = "[Sigma Hub]"

-- ── Logging ────────────────────────────────────────────────────────────────

local function debugEnabled()
	if getgenv().SigmaHubDebug == false then
		return false
	end
	return true
end

local function log(level, ...)
	local msg = table.concat({ ... }, " ")
	if level == "warn" then
		warn(LOG_PREFIX, msg)
	elseif level == "err" then
		warn(LOG_PREFIX, "ERROR:", msg)
	else
		print(LOG_PREFIX, msg)
	end
end

local function logStep(step, detail)
	if not debugEnabled() then return end
	if detail and detail ~= "" then
		log("info", string.format("[%s] %s", step, detail))
	else
		log("info", string.format("[%s]", step))
	end
end

local function logOk(step, detail)
	log("info", string.format("✓ %s — %s", step, detail or "ok"))
end

local function logFail(step, err)
	log("err", string.format("%s — %s", step, tostring(err)))
end

local function formatTraceback(err)
	local tb = debug.traceback(tostring(err), 2)
	return tb
end

local function detectExecutor()
	if identifyexecutor then
		local ok, name = pcall(identifyexecutor)
		if ok and name then return tostring(name) end
	end
	if getexecutorname then
		local ok, name = pcall(getexecutorname)
		if ok and name then return tostring(name) end
	end
	if syn then return "Synapse X" end
	if fluxus then return "Fluxus" end
	if KRNL_LOADED then return "Krnl" end
	return "Unknown"
end

local function logEnvironment()
	if not debugEnabled() then return end
	local lp = game:GetService("Players").LocalPlayer
	log("info", "── Startup ──")
	log("info", "Executor:", detectExecutor())
	log("info", "PlaceId:", game.PlaceId, "| Game:", game:GetService("MarketplaceService") and "loaded" or "?")
	if lp then
		log("info", "Player:", lp.Name, "| UserId:", lp.UserId)
	end
	log("info", "WindUI URL:", SIGMA_SOURCE_URL)
	log("info", "Main.lua URL:", SIGMA_FISH_URL)
	log("info", "SigmaUI URL:", SIGMA_UI_URL)
end

local function describeModule(mod, label)
	if mod == nil then
		return label .. ": nil"
	end
	local t = type(mod)
	if t ~= "table" then
		return label .. ": type=" .. t
	end
	local keys = {}
	for k in pairs(mod) do
		keys[#keys + 1] = tostring(k)
	end
	table.sort(keys)
	local preview = #keys > 0 and table.concat(keys, ", ") or "(empty table)"
	if #preview > 120 then
		preview = preview:sub(1, 117) .. "..."
	end
	return label .. ": table keys=[" .. preview .. "]"
end

local function checkFishBackend(Fish)
	if not Fish then
		return false, "Main.lua not loaded (nil)"
	end
	local required = {
		"setAutoFish", "setAutoQuest", "setQuestPick", "setAutoExpertise",
		"setAutoCookSell", "setSellAt", "cookSell", "getStatus", "getQuestList", "applyConfig",
	}
	local missing = {}
	for _, name in ipairs(required) do
		if type(Fish[name]) ~= "function" then
			missing[#missing + 1] = name
		end
	end
	if type(Fish.build) == "function" and type(Fish.setAutoFish) ~= "function" then
		return false, "Main.lua SAI FILE trên GitHub — đang là SigmaUI.lua (chỉ có .build). Upload đúng Main.lua backend (~2400 dòng)."
	end
	if #missing > 0 then
		return false, "Main.lua missing APIs: " .. table.concat(missing, ", ")
	end
	return true, "all fishing APIs present"
end

local function validateMainLuaSource(src)
	if type(src) ~= "string" or src == "" then
		return false, "Main.lua: empty response"
	end
	if string.find(src, "SigmaUI.build", 1, true)
		and not string.find(src, "function SigmaFish.setAutoFish", 1, true) then
		return false, "GitHub Main.lua = SigmaUI.lua (upload nhầm). Thay bằng file backend Main.lua (~2400 dòng)."
	end
	if not string.find(src, "function SigmaFish.setAutoFish", 1, true)
		and not string.find(src, "startHubLoop", 1, true) then
		return false, "Main.lua không phải backend SigmaFish — kiểm tra lại file upload."
	end
	return true
end

-- ── Loaders ────────────────────────────────────────────────────────────────

local function httpLoad(url, label, opts)
	opts = opts or {}
	logStep("HttpGet", label .. " ← " .. url)

	local ok, result = pcall(function()
		local t0 = os.clock()
		local src = game:HttpGet(url, true)
		local elapsed = os.clock() - t0

		if type(src) ~= "string" then
			error(label .. ": HttpGet returned " .. type(src))
		end
		if src == "" then
			error(label .. ": empty response (0 bytes)")
		end

		if opts.validateSource then
			local vok, verr = opts.validateSource(src)
			if not vok then
				error(verr)
			end
		end

		logStep("HttpGet", string.format("%s — %d bytes in %.2fs", label, #src, elapsed))

		local fn, loadErr = loadstring(src, label)
		if not fn then
			error(label .. ": loadstring failed — " .. tostring(loadErr))
		end

		logStep("loadstring", label .. " — compile ok, running...")
		local mod = fn()
		return mod
	end)

	if ok then
		logOk("Loaded", label .. " (" .. type(result) .. ")")
		if debugEnabled() then
			log("info", describeModule(result, label))
		end
		return result
	end

	logFail("Load failed", label)
	logFail("Reason", result)
	log("warn", "URL:", url)
	if debugEnabled() then
		log("warn", formatTraceback(result))
	end
	return nil
end

local function loadFishBackend()
	logStep("Backend", "loading Main.lua (fishing)")
	local mod = httpLoad(SIGMA_FISH_URL, "Main.lua", { validateSource = validateMainLuaSource })
	local ok, detail = checkFishBackend(mod)
	if ok then
		logOk("Backend", detail)
		return mod
	end
	log("warn", detail)
	log("warn", "Fishing/Quest disabled — upload đúng Main.lua backend lên GitHub rồi ReloadSigmaHub()")
	return mod -- vẫn trả mod nếu có (partial), nil nếu load fail
end

local function loadSigmaUI()
	logStep("UI module", "loading SigmaUI.lua")
	local mod = httpLoad(SIGMA_UI_URL, "SigmaUI.lua")
	if type(mod) ~= "table" then
		error("SigmaUI.lua: expected table, got " .. type(mod))
	end
	if type(mod.build) ~= "function" then
		error("SigmaUI.lua: missing SigmaUI.build() — file outdated or wrong module?")
	end
	logOk("UI module", "SigmaUI.build found")
	return mod
end

local function notify(hub, title, content, icon, duration)
	if not hub or type(hub.Notify) ~= "function" then
		log("warn", "Notify skipped (hub invalid):", title, "-", content)
		return
	end
	hub:Notify({
		Title = title or "Sigma Hub",
		Content = content or "",
		Duration = duration or 3,
		Icon = icon or "info",
	})
end

-- ── Build ──────────────────────────────────────────────────────────────────

local function buildSigmaHub()
	logEnvironment()

	-- 1) WindUI / Sigma.lua
	logStep("1/4", "WindUI library (Sigma.lua)")
	local hub = httpLoad(SIGMA_SOURCE_URL, "Sigma.lua")
	if type(hub) ~= "table" then
		error("Sigma.lua: expected table, got " .. type(hub))
	end
	if type(hub.CreateWindow) ~= "function" then
		error("Sigma.lua: missing CreateWindow — wrong file or corrupt download?")
	end
	if type(hub.Notify) ~= "function" then
		log("warn", "Sigma.lua: Notify missing — in-game toasts may not work")
	end
	getgenv().SigmaHub = hub
	getgenv().WindUI = hub
	logOk("1/4", "WindUI ready (CreateWindow ok)")

	-- 2) Main.lua backend
	logStep("2/4", "Fishing backend (Main.lua)")
	local Fish = loadFishBackend()

	-- 3) SigmaUI.lua
	logStep("3/4", "UI builder (SigmaUI.lua)")
	local SigmaUI = loadSigmaUI()

	-- 4) Build window
	logStep("4/4", "SigmaUI.build() — creating tabs & controls")
	local buildOk, buildResult = pcall(function()
		return SigmaUI.build(hub, Fish, {
			notify = notify,
			primary = SAMPLE_PRIMARY,
			log = function(msg)
				log("info", "[SigmaUI]", msg)
			end,
		})
	end)

	if not buildOk then
		logFail("SigmaUI.build", buildResult)
		log("warn", formatTraceback(buildResult))
		error("UI build crashed: " .. tostring(buildResult))
	end

	local Window = buildResult
	if not Window then
		error("SigmaUI.build returned nil — check SigmaUI.lua task.defer / tab population")
	end

	getgenv().SigmaFishBackend = Fish
	getgenv().SigmaWindow = Window

	logOk("4/4", "Window created")

	local counts = getgenv().__SIGMA_UI_COUNTS
	if counts then
		log("info", string.format(
			"UI elements — Main:%d Fishing:%d Quest:%d Settings:%d",
			counts.Main or 0, counts.Fishing or 0, counts.Quest or 0, counts.Settings or 0
		))
		local total = (counts.Main or 0) + (counts.Fishing or 0) + (counts.Quest or 0) + (counts.Settings or 0)
		if total == 0 then
			log("warn", "Tab trống — SigmaUI populate trả 0 element, xem log [SigmaUI] phía trên")
		end
	else
		log("warn", "Không có __SIGMA_UI_COUNTS — SigmaUI.lua cũ trên GitHub?")
	end

	log("info", "── Ready ──")
	log("info", "Player:", game:GetService("Players").LocalPlayer.Name)
	log("info", "Fish backend:", Fish and "yes" or "no")
	log("info", "Tip: tab trống → upload SigmaUI.lua mới + ReloadSigmaHub()")

	notify(hub, "Sigma Hub", "Loaded (GitHub remote)", "fish", 4)
	return hub, Window, Fish
end

local function reloadSigmaHub()
	log("info", "── Reload ──")
	if getgenv().SigmaFish and getgenv().SigmaFish.stop then
		local ok, err = pcall(function() getgenv().SigmaFish.stop() end)
		if not ok then
			log("warn", "stop fish backend:", err)
		end
	end
	if getgenv().SigmaHub and getgenv().SigmaHub.Window then
		local ok, err = pcall(function()
			getgenv().SigmaHub.Window:Destroy()
		end)
		if not ok then
			log("warn", "destroy old window:", err)
		end
		getgenv().SigmaHub.Window = nil
	end
	getgenv().__SIGMA_HUB_LOADED = nil
	return buildSigmaHub()
end

getgenv().ReloadSigmaHub = reloadSigmaHub
getgenv().SigmaHubLog = function(...)
	log("info", ...)
end

if getgenv().__SIGMA_HUB_LOADED then
	warn(LOG_PREFIX, "Already loaded — run ReloadSigmaHub() to refresh")
	return
end
getgenv().__SIGMA_HUB_LOADED = true

local ok, err = pcall(buildSigmaHub)
if not ok then
	getgenv().__SIGMA_HUB_LOADED = nil
	warn(LOG_PREFIX, "══════════════════════════════════════")
	warn(LOG_PREFIX, "STARTUP FAILED")
	warn(LOG_PREFIX, tostring(err))
	warn(LOG_PREFIX, formatTraceback(err))
	warn(LOG_PREFIX, "══════════════════════════════════════")
	warn(LOG_PREFIX, "Checklist:")
	warn(LOG_PREFIX, "  1) GitHub đã upload Sigma.lua, Main.lua, SigmaUI.lua?")
	warn(LOG_PREFIX, "  2) URL raw.githubusercontent.com mở được trên máy?")
	warn(LOG_PREFIX, "  3) SigmaUI.lua có SigmaUI.build và task.defer không lỗi?")
	warn(LOG_PREFIX, "  4) Tắt log chi tiết: getgenv().SigmaHubDebug = false")
end
