-- Mat Tooltip: price + verdict for crafting mats (every Trade Goods item). Read-only: no automation, no network.
local ADDON, ns = ...
local C, Core = ns.Compat, ns.Core
local L = Core.L

local CLASS_TRADEGOODS = 7 -- Trade Goods: leather, herbs, cloth, metal and stone, elemental, enchanting...
local SCHEMA = 1
local PROVIDER_FORMAT = 1

local DEFAULTS = { enabled = true, ahCut = 0.05, sellMargin = 1.10, staleDays = 3, bagnon = true }
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
  local classID = C.GetItemClass(itemID)
  return classID == CLASS_TRADEGOODS
end
M.IsMat = isMat

-- Newest price: the shared store (PriceLog, if installed) or this addon's own scans; then Auctionator's data.
function M.GetPriceRecord(itemID)
  local own = db and db.prices[itemID]
  local shared = ns.Hub.GetPrice(itemID, ADDON)
  if shared and (not own or (shared.t or 0) > (own.t or 0)) then return shared end
  if own then return own end
  local api = type(Auctionator) == "table" and Auctionator.API and Auctionator.API.v1
  if api and api.GetAuctionPriceByItemID then
    local ok, price = pcall(api.GetAuctionPriceByItemID, "MatTooltip", itemID)
    price = ok and C.SafeNumber(price)
    if price and price > 0 then return { p = price, t = 0, src = "Auctionator" } end
  end
end
-- Our own store is only needed when PriceLog isn't there to keep the prices.
local function priceLogKeepsPrices() return ns.Hub.prices.PriceLog ~= nil end

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

-- Verdict for one item without a tooltip (Bagnon overlay, LDB): nil if it isn't a trade good.
function M.ItemVerdict(itemID)
  if not (db and settings and itemID) or not isMat(itemID) then return nil end
  local info = C.GetItemInfo(itemID)
  local rec = M.GetPriceRecord(itemID)
  return M.Verdict(itemID, info and info.sellPrice, rec, C.Now(), settings, M.IsNeverVendor(itemID)), rec, info
end
function M.Settings() return settings end
-- For our other addons: our own scan prices (used only when PriceLog isn't installed) and the verdict per mat.
ns.Hub.RegisterPrices(ADDON, function(itemID) return db and db.prices[itemID] end)
ns.Hub.Provide("verdict", ADDON, function(itemID) return (M.ItemVerdict(itemID)) end)

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
    -- Skip the AH price if another of our addons (NeutralFlip) already showed it in this tooltip.
    if not tooltip.Claim or tooltip.Claim("price.auction") then
      tooltip:AddDoubleLine(rec and rec.src == "Auctionator" and "AH (Auctionator)" or "AH (your scan)", C.Money(rec and rec.p), 0.8, 0.8, 0.8, 1, 1, 1)
    end
    tooltip:AddDoubleLine("Vendor", C.Money(vendor), 0.8, 0.8, 0.8, 1, 1, 1)
    if never then tooltip:AddLine("|cffff4040NEVER VENDOR|r (scarce)") end
    tooltip:AddLine(COLORS[v] .. v .. "|r" .. (why and (" |cff999999(" .. why .. ")|r") or ""))
    local trend = ns.Hub.Ask("trend", itemID) -- from PriceLog, when it has a week of prices
    if trend then tooltip:AddLine(("|cff999999%s: %s (%+.0f%%)|r"):format(L["7-day trend"], trend.label, trend.change * 100)) end
  end
  for _, p in ipairs(providers.list) do
    local text = providers.Call(p, "getLine", itemID)
    if type(text) == "string" and text ~= "" then tooltip:AddLine(text) end
  end
end

local function OnItemTooltip(tooltip, data)
  if not db or not settings.enabled or not data then return end
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
    if priceLogKeepsPrices() then
      for _ in pairs(best) do k = k + 1 end
      scanning = false
      Core.Print(("%d %s"):format(k, L["mats priced; PriceLog keeps the prices, so MatTooltip stores none of its own."]))
      return
    end
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
    ns.Hub.AddTooltip(ADDON, 30, function(tt, _, data) OnItemTooltip(tt, data) end) -- after prices, in our shared block
  elseif event == "AUCTION_HOUSE_SHOW" then ahOpen = true
  elseif event == "AUCTION_HOUSE_CLOSED" then ahOpen = false
  elseif event == "REPLICATE_ITEM_LIST_UPDATE" and (scanning or (ns.Hub.ScanActive() and not priceLogKeepsPrices())) then
    scanning = true -- a scan another of our addons started feeds us too
    -- Fires repeatedly while item info streams in: process once, 2s after the last update.
    scanToken = scanToken + 1
    local token = scanToken
    C_Timer.After(2, function() if token == scanToken and scanning then ProcessScan() end end)
  end
end)

local function parseID(arg)
  return tonumber(arg) or tonumber((arg or ""):match("item:(%d+)"))
end

Core.Setup({ cmd = "/mattip",
  required = { "C_AuctionHouse.ReplicateItems", "C_AuctionHouse.GetNumReplicateItems", "C_AuctionHouse.GetReplicateItemInfo",
    "C_AuctionHouse.IsThrottledMessageSystemReady", "C_Item.GetItemInfo", "C_Item.GetItemInfoInstant", "TooltipDataProcessor.AddTooltipPostCall" },
  optional = { "KennyPriceLog", "Auctionator.API.v1.GetAuctionPriceByItemID", "LibStub", "Bagnon" },
  db = function() return db end,
  firstRun = { L["Welcome! MatTooltip adds an AH price and a SELL ON AH / VENDOR / HOLD verdict to every crafting mat."],
    L["At the AH: /mattip scan (once per 15 min). With PriceLog installed, its prices are used and shared."],
    L["/mattip never <item> keeps a scarce mat off the vendor list; /mattip debug checks your setup."] },
  debugLines = function()
    local n = 0
    for _ in pairs(db and db.prices or {}) do n = n + 1 end
    return { ("%s: %d (%s)"):format(L["own prices stored"], n, priceLogKeepsPrices() and L["PriceLog keeps prices"] or L["no PriceLog"]) }
  end })

SLASH_KENNYMATTOOLTIP1 = "/mattip"
SLASH_KENNYMATTOOLTIP2 = "/kmt"
SlashCmdList.KENNYMATTOOLTIP = function(msg)
  local cmd, arg = (msg or ""):match("^(%S*)%s*(.-)$")
  cmd = cmd:lower()
  if cmd == "scan" then
    if not ahOpen then Core.Print("open the auction house first.") return end
    if C.InCombat() then Core.Print("not in combat.") return end
    if not C.AHReady() then Core.Print("AH busy, try again shortly.") return end
    local mine, by, left = ns.Hub.ClaimScan(ADDON)
    if not mine then Core.Print(("%s %s; %s %d min. %s"):format(L["a full scan was already started by"], by or "?", L["next one in"], math.ceil(left / 60), L["Its results are recorded here too."])) return end
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
  elseif cmd == "bagnon" then
    settings.bagnon = not settings.bagnon
    Core.Print("Bagnon bag markers " .. (settings.bagnon and "on." or "off.") .. (M.RefreshBagnon and M.RefreshBagnon() and "" or " (Bagnon isn't loaded)"))
  elseif cmd == "list" then
    for id in pairs(SEED_NEVER) do if M.IsNeverVendor(id) then Core.Print("never vendor: " .. id .. " (seed)") end end
    for id, v in pairs(db.neverVendor) do if v and not SEED_NEVER[id] then Core.Print("never vendor: " .. id) end end
  elseif cmd == "debug" then Core.PrintDebug()
  elseif cmd == "plugins" then for _, l in ipairs(providers.Describe()) do Core.Print(l) end
  elseif cmd == "report" then
    local n = 0
    for _ in pairs(db.prices) do n = n + 1 end
    Core.ShowReport({ "schema " .. tostring(db.schema), "prices stored: " .. n, "enabled: " .. tostring(settings.enabled),
      "PriceLog loaded: " .. tostring(KennyPriceLog ~= nil), "providers: " .. #providers.list })
  else
    Core.Print("/mattip scan | never <id> | unnever <id> | list | margin <x> | toggle | bagnon | plugins | debug | report")
  end
end
