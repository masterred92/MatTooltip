-- Mat Tooltip: price + verdict for Skinning/Herbalism mats. Read-only: no automation, no network.
local ADDON, ns = ...
local C, Core = ns.Compat, ns.Core

local CLASS_TRADEGOODS, SUB_LEATHER, SUB_HERB = 7, 6, 9 -- trade goods; leather / herb subclasses
local SCHEMA = 1
local PROVIDER_FORMAT = 1

local DEFAULTS = { enabled = true, ahCut = 0.05, sellMargin = 1.10, staleDays = 3 }
-- Seeded never-vendor mats (IDs checked against auctionhouse.fyi Forever item data, build 1.60.1.70009).
-- Users override per item in db.neverVendor ([id] = true / false); new seeds reach old users.
local SEED_NEVER = { [249427] = true, [249399] = true } -- Pristine Leather, Frilled Lichen

local db, settings
local M = {}
KennyMatTooltip = M

local migrations = {
  -- schema 0 -> 1: v0.1.0 kept everything flat in MatTooltipDB.
  [1] = function(old)
    local new = { settings = {}, neverVendor = {}, prices = old.prices or {} }
    for k, def in pairs(DEFAULTS) do
      if old[k] ~= nil and old[k] ~= def then new.settings[k] = old[k] end
    end
    for id, v in pairs(old.neverVendor or {}) do
      if v and not SEED_NEVER[id] then new.neverVendor[id] = true end
    end
    return new
  end,
}

function M.IsNeverVendor(itemID)
  local o = db and db.neverVendor[itemID]
  if o ~= nil then return o end
  return SEED_NEVER[itemID] == true
end

local function isMat(itemID)
  local classID, subClassID = C.GetItemClass(itemID)
  return classID == CLASS_TRADEGOODS and (subClassID == SUB_LEATHER or subClassID == SUB_HERB)
end
M.IsMat = isMat

-- Newest price from this addon's scans or from PriceLog (if installed): one scan feeds both.
function M.GetPriceRecord(itemID)
  local own = db and db.prices[itemID]
  local pl = KennyPriceLog and KennyPriceLog.GetLatest and KennyPriceLog.GetLatest(itemID)
  if pl and (not own or (pl.t or 0) > (own.t or 0)) then return pl end
  return own
end

-- Pure decision logic.
function M.Verdict(_, vendor, rec, now, cfg, never)
  local ah = rec and rec.p
  local stale = rec and (now - rec.t) > cfg.staleDays * 86400
  if not ah then
    return "HOLD", (never or not vendor or vendor == 0) and "no AH scan yet" or "scan the AH first"
  end
  local net = ah * (1 - cfg.ahCut)
  if never or not vendor or vendor == 0 or net >= vendor * cfg.sellMargin then
    return "SELL ON AH", stale and "price is old" or nil
  end
  return "VENDOR", nil
end

-- Tooltip providers (plugin API): getLine(itemID) -> text or nil.
local providers = Core.NewRegistry("provider", PROVIDER_FORMAT, { "getLine" })
function M.RegisterProvider(spec) return providers.Register(spec) end

local COLORS = { ["SELL ON AH"] = "|cff33ff33", VENDOR = "|cffffd100", HOLD = "|cff66ccff" }

-- Appends lines only; never clears or rewrites other addons' tooltip lines.
local function addLines(tooltip, itemID)
  if isMat(itemID) then
    local info = C.GetItemInfo(itemID)
    local vendor = info and info.sellPrice
    local rec = M.GetPriceRecord(itemID)
    local never = M.IsNeverVendor(itemID)
    local v, why = M.Verdict(itemID, vendor, rec, C.Now(), settings, never)
    tooltip:AddDoubleLine("AH (your scan)", C.Money(rec and rec.p), 0.8, 0.8, 0.8, 1, 1, 1)
    tooltip:AddDoubleLine("Vendor", C.Money(vendor), 0.8, 0.8, 0.8, 1, 1, 1)
    if never then tooltip:AddLine("|cffff4040NEVER VENDOR|r (scarce)") end
    tooltip:AddLine(COLORS[v] .. v .. "|r" .. (why and (" |cff999999(" .. why .. ")|r") or ""))
  end
  for _, p in ipairs(providers.list) do
    local text = providers.Call(p, "getLine", itemID)
    if type(text) == "string" and text ~= "" then tooltip:AddLine(text) end
  end
end

local function OnItemTooltip(tooltip, data)
  if not db or not settings.enabled or not data then return end
  if tooltip ~= GameTooltip and tooltip ~= ItemRefTooltip then return end
  local itemID = C.SafeNumber(data.id)
  if not itemID then return end
  Core.SafeCall("tooltip", addLines, tooltip, itemID)
end

-- AH scan: started only by you via /mattip scan at an open AH; processed in chunks, out of combat.
local ahOpen, scanning, scanToken = false, false, 0
local function ProcessScan()
  local n = C.AHNumReplicate()
  local best, i, now = {}, 0, C.Now()
  local function step()
    if C.InCombat() then C_Timer.After(1, step) return end
    local stop = math.min(i + 500, n)
    while i < stop do
      local itemID, _, count, buyout = C.AHReplicateRow(i)
      if itemID and isMat(itemID) then
        local unit = math.floor(buyout / count)
        local b = best[itemID]
        if not b then best[itemID] = { p = unit, t = now, n = count }
        else b.n = b.n + count; if unit < b.p then b.p = unit end end
      end
      i = i + 1
    end
    if i < n then C_Timer.After(0, step) return end
    local k = 0
    for id, r in pairs(best) do db.prices[id] = r; k = k + 1 end
    scanning = false
    Core.Print("saved prices for " .. k .. " mats.")
  end
  Core.SafeCall("scan", step)
end

local f = CreateFrame("Frame")
f:RegisterEvent("ADDON_LOADED")
f:RegisterEvent("AUCTION_HOUSE_SHOW")
f:RegisterEvent("AUCTION_HOUSE_CLOSED")
f:RegisterEvent("REPLICATE_ITEM_LIST_UPDATE")
f:SetScript("OnEvent", function(_, event, arg1)
  if event == "ADDON_LOADED" and arg1 == ADDON then
    local src = KennyMatTooltipDB
    if src == nil and MatTooltipDB ~= nil then src = MatTooltipDB end -- v0.1.0 data
    local ok
    db, ok = Core.Migrate(src, migrations, SCHEMA)
    db.neverVendor, db.prices = db.neverVendor or {}, db.prices or {}
    KennyMatTooltipDB = db
    if ok then MatTooltipDB = nil end
    settings = Core.Settings(db.settings, DEFAULTS)
    TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, OnItemTooltip)
  elseif event == "AUCTION_HOUSE_SHOW" then ahOpen = true
  elseif event == "AUCTION_HOUSE_CLOSED" then ahOpen = false
  elseif event == "REPLICATE_ITEM_LIST_UPDATE" and scanning then
    -- Fires repeatedly while item info streams in: process once, 2s after the last update.
    scanToken = scanToken + 1
    local token = scanToken
    C_Timer.After(2, function() if token == scanToken and scanning then ProcessScan() end end)
  end
end)

local function parseID(arg)
  return tonumber(arg) or tonumber((arg or ""):match("item:(%d+)"))
end

SLASH_KENNYMATTOOLTIP1 = "/mattip"
SLASH_KENNYMATTOOLTIP2 = "/kmt"
SlashCmdList.KENNYMATTOOLTIP = function(msg)
  local cmd, arg = (msg or ""):match("^(%S*)%s*(.-)$")
  cmd = cmd:lower()
  if cmd == "scan" then
    if not ahOpen then Core.Print("open the auction house first.") return end
    if C.InCombat() then Core.Print("not in combat.") return end
    if not C.AHReady() then Core.Print("AH busy, try again shortly.") return end
    scanning = true
    C.AHReplicate()
    Core.Print("full scan requested (Blizzard allows about one every 15 minutes).")
  elseif cmd == "never" or cmd == "unnever" then
    local id = parseID(arg)
    if not id then Core.Print("usage: /mattip never <itemID or link>") return end
    local want = (cmd == "never")
    if want == (SEED_NEVER[id] == true) then db.neverVendor[id] = nil else db.neverVendor[id] = want end
    Core.Print(id .. (want and " added to" or " removed from") .. " never-vendor list.")
  elseif cmd == "margin" and tonumber(arg) then settings.sellMargin = tonumber(arg); Core.Print("margin " .. settings.sellMargin)
  elseif cmd == "toggle" then settings.enabled = not settings.enabled; Core.Print(settings.enabled and "on" or "off")
  elseif cmd == "list" then
    for id in pairs(SEED_NEVER) do if M.IsNeverVendor(id) then Core.Print("never vendor: " .. id .. " (seed)") end end
    for id, v in pairs(db.neverVendor) do if v and not SEED_NEVER[id] then Core.Print("never vendor: " .. id) end end
  elseif cmd == "plugins" then for _, l in ipairs(providers.Describe()) do Core.Print(l) end
  elseif cmd == "report" then
    local n = 0
    for _ in pairs(db.prices) do n = n + 1 end
    Core.ShowReport({ "schema " .. tostring(db.schema), "prices stored: " .. n, "enabled: " .. tostring(settings.enabled),
      "PriceLog loaded: " .. tostring(KennyPriceLog ~= nil), "providers: " .. #providers.list })
  else
    Core.Print("/mattip scan | never <id> | unnever <id> | list | margin <x> | toggle | plugins | report")
  end
end
