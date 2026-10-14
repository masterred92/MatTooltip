-- Mat Tooltip: price + verdict for Skinning/Herbalism mats. No automation, no network.
local ADDON = ...
local CLASS_TRADEGOODS, SUB_LEATHER, SUB_HERB = 7, 6, 9 -- Enum.ItemClass.Tradegoods; leather/herb subclasses

local DEFAULTS = {
  enabled = true,
  ahCut = 0.05,          -- faction AH cut
  sellMargin = 1.10,     -- AH net must beat vendor by 10%
  staleDays = 3,
  neverVendor = { [249427] = true, [249399] = true }, -- Pristine Leather, Frilled Lichen
  prices = {},           -- [itemID] = { p = min unit buyout (copper), t = scan time, n = qty }
}

local db
local f = CreateFrame("Frame")

local function copyDefaults(src, dst)
  for k, v in pairs(src) do
    if type(v) == "table" then dst[k] = dst[k] or {}; copyDefaults(v, dst[k])
    elseif dst[k] == nil then dst[k] = v end
  end
end

local function isMat(itemID)
  local _, _, _, _, _, classID, subClassID = C_Item.GetItemInfoInstant(itemID)
  return classID == CLASS_TRADEGOODS and (subClassID == SUB_LEATHER or subClassID == SUB_HERB)
end

local function money(c) return c and c > 0 and GetMoneyString(c, true) or "-" end

-- Pure decision logic (exercised by the mock harness).
local function Verdict(itemID, vendor, rec, now, cfg)
  local never = cfg.neverVendor[itemID]
  local ah = rec and rec.p
  local stale = rec and (now - rec.t) > cfg.staleDays * 86400
  if not ah then
    if never or not vendor or vendor == 0 then return "HOLD", "no AH scan yet" end
    return "HOLD", "scan the AH first"
  end
  local net = ah * (1 - cfg.ahCut)
  if never then return "SELL ON AH", stale and "price is old" or nil end
  if not vendor or vendor == 0 or net >= vendor * cfg.sellMargin then
    return "SELL ON AH", stale and "price is old" or nil
  end
  return "VENDOR", nil
end

local COLORS = { ["SELL ON AH"] = "|cff33ff33", VENDOR = "|cffffd100", HOLD = "|cff66ccff" }

local function OnItemTooltip(tooltip, data)
  if not db or not db.enabled or not data or tooltip ~= GameTooltip and tooltip ~= ItemRefTooltip then return end
  local itemID = data.id
  if type(itemID) ~= "number" or (issecretvalue and issecretvalue(itemID)) or not isMat(itemID) then return end
  local vendor = select(11, C_Item.GetItemInfo(itemID))
  local rec = db.prices[itemID]
  local v, why = Verdict(itemID, vendor, rec, time(), db)
  tooltip:AddDoubleLine("AH (your scan)", money(rec and rec.p), 0.8, 0.8, 0.8, 1, 1, 1)
  tooltip:AddDoubleLine("Vendor", money(vendor), 0.8, 0.8, 0.8, 1, 1, 1)
  if db.neverVendor[itemID] then tooltip:AddLine("|cffff4040NEVER VENDOR|r (scarce)") end
  tooltip:AddLine(COLORS[v] .. v .. "|r" .. (why and (" |cff999999(" .. why .. ")|r") or ""))
end

-- AH scan: started only by you via /mattip scan while the AH is open; processed in chunks, out of combat.
local ahOpen, scanning = false, false
local function ProcessScan()
  local n = C_AuctionHouse.GetNumReplicateItems()
  local best, i, now = {}, 0, time()
  local function step()
    if InCombatLockdown() then C_Timer.After(1, step) return end
    local stop = math.min(i + 500, n)
    while i < stop do
      local _, _, count, _, _, _, _, _, _, buyout, _, _, _, _, _, _, itemID, hasAll = C_AuctionHouse.GetReplicateItemInfo(i)
      if hasAll and itemID and buyout and buyout > 0 and count and count > 0 and isMat(itemID) then
        local unit = math.floor(buyout / count)
        local b = best[itemID]
        if not b then best[itemID] = { p = unit, t = now, n = count }
        else b.n = b.n + count; if unit < b.p then b.p = unit end end
      end
      i = i + 1
    end
    if i < n then C_Timer.After(0, step) else
      local k = 0
      for id, r in pairs(best) do db.prices[id] = r; k = k + 1 end
      scanning = false
      print("|cff33ff33MatTooltip|r: saved prices for " .. k .. " mats.")
    end
  end
  step()
end

f:RegisterEvent("ADDON_LOADED")
f:RegisterEvent("AUCTION_HOUSE_SHOW")
f:RegisterEvent("AUCTION_HOUSE_CLOSED")
f:RegisterEvent("REPLICATE_ITEM_LIST_UPDATE")
f:SetScript("OnEvent", function(_, event, arg1)
  if event == "ADDON_LOADED" and arg1 == ADDON then
    MatTooltipDB = MatTooltipDB or {}
    copyDefaults(DEFAULTS, MatTooltipDB)
    db = MatTooltipDB
    TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, OnItemTooltip)
  elseif event == "AUCTION_HOUSE_SHOW" then ahOpen = true
  elseif event == "AUCTION_HOUSE_CLOSED" then ahOpen = false
  elseif event == "REPLICATE_ITEM_LIST_UPDATE" and scanning then
    f:UnregisterEvent("REPLICATE_ITEM_LIST_UPDATE") -- fires repeatedly; process once
    ProcessScan()
    f:RegisterEvent("REPLICATE_ITEM_LIST_UPDATE")
  end
end)

SLASH_MATTOOLTIP1 = "/mattip"
SlashCmdList.MATTOOLTIP = function(msg)
  local cmd, arg = (msg or ""):match("^(%S*)%s*(.-)$")
  cmd = cmd:lower()
  if cmd == "scan" then
    if not ahOpen then print("MatTooltip: open the auction house first.") return end
    if InCombatLockdown() then print("MatTooltip: not in combat.") return end
    if not C_AuctionHouse.IsThrottledMessageSystemReady() then print("MatTooltip: AH busy, try again shortly.") return end
    scanning = true
    C_AuctionHouse.ReplicateItems()
    print("MatTooltip: full scan requested (Blizzard limits this to about once every 15 minutes).")
  elseif cmd == "never" or cmd == "unnever" then
    local id = tonumber(arg) or tonumber(arg:match("item:(%d+)"))
    if not id then print("Usage: /mattip never <itemID or link>") return end
    db.neverVendor[id] = (cmd == "never") or nil
    print("MatTooltip: " .. id .. (cmd == "never" and " added to" or " removed from") .. " never-vendor list.")
  elseif cmd == "margin" and tonumber(arg) then db.sellMargin = tonumber(arg); print("MatTooltip: margin " .. db.sellMargin)
  elseif cmd == "toggle" then db.enabled = not db.enabled; print("MatTooltip: " .. (db.enabled and "on" or "off"))
  elseif cmd == "list" then for id in pairs(db.neverVendor) do print("  never vendor: " .. id) end
  else
    print("MatTooltip: /mattip scan | never <id> | unnever <id> | list | margin <x> | toggle")
  end
end

MatTooltip = { Verdict = Verdict } -- exposed for the test harness
