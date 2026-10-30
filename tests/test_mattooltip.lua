package.path = "tests/?.lua;" .. package.path
local W = require("mock_wow"); W.install()
local check = W.check
-- v0.1.0 SavedVariables (flat layout) must migrate to schema 1
MatTooltipDB = { enabled = true, ahCut = 0.05, sellMargin = 1.5, staleDays = 3,
  neverVendor = { [249427] = true, [249399] = true, [2318] = true }, prices = { [2447] = { p = 40, t = W.now, n = 9 } } }
local ns = W.loadAddon(".", "MatTooltip")
local db = KennyMatTooltipDB
check(db.schema == 1, "migrated to schema 1")
check(MatTooltipDB == nil, "legacy MatTooltipDB cleared")
check(db.settings.sellMargin == 1.5 and db.settings.ahCut == nil, "only non-default settings stored")
check(db.neverVendor[2318] == true and db.neverVendor[249427] == nil, "custom never-vendor kept, seeds not stored")
check(db.prices[2447].p == 40, "prices kept")
check(#W.hooks == 1, "one tooltip hook")

local t = W.tooltip(2318)
check(t:find("NEVER VENDOR", 1, true) and t:find("HOLD", 1, true), "2318 never-vendor + HOLD without price: " .. t)
t = W.tooltip(2447) -- 40c*0.95=38 vs vendor 10*1.5=15 -> sell
check(t:find("SELL ON AH", 1, true) and t:find("AH (your scan): 40c", 1, true), "2447 sell: " .. t)
check(W.tooltip(25) == "", "a weapon gets no mat lines")
check(W.tooltip(2589):find("HOLD", 1, true), "cloth is a mat now (all Trade Goods)")
check(W.tooltip(nil) == "", "nil id safe")
W.secret[249399] = true
check(W.tooltip(249399) == "", "secret item id treated as unknown")
W.secret[249399] = nil

-- appends without clobbering other addons' lines
W.tooltipLines = { "Other addon line" }
W.hooks[1][2](GameTooltip, { id = 2318 })
check(W.tooltipLines[1] == "Other addon line" and #W.tooltipLines > 1, "appends after existing lines")

-- provider plugins: good, broken (disabled after 3 errors), rejected format
local M = KennyMatTooltip
check(M.RegisterProvider({ id = "good", format = 1, getLine = function(id) return id == 25 and "Good plugin" or nil end }), "good provider registered")
check(M.RegisterProvider({ id = "bad", format = 1, priority = 1, getLine = function() error("boom") end }), "bad provider registered")
local ok, why = M.RegisterProvider({ id = "future", format = 9, getLine = function() end })
check(not ok and why:find("format", 1, true), "newer format rejected")
check(not M.RegisterProvider({ id = "good", format = 1, getLine = function() end }), "duplicate id rejected")
for _ = 1, 4 do t = W.tooltip(25) end
check(t == "Good plugin", "good plugin line shown, bad plugin contained: " .. t)
check(#ns.Core.errors <= 5 and ns.Core.errors[#ns.Core.errors].msg:find("boom", 1, true), "plugin errors recorded in ring buffer")

-- scan only via slash command with the AH open; debounced
SlashCmdList.KENNYMATTOOLTIP("scan")
check(not W.replicateRequested, "scan refused with AH closed")
W.fire("AUCTION_HOUSE_SHOW")
W.combat = true; SlashCmdList.KENNYMATTOOLTIP("scan"); W.combat = false
check(not W.replicateRequested, "scan refused in combat")
SlashCmdList.KENNYMATTOOLTIP("scan")
check(W.replicateRequested == 1, "ReplicateItems requested once")
W.replicate = { { 2318, 20, 400 }, { 2318, 5, 50 }, { 25, 1, 999 }, { 249427, 1, 9000 } }
W.fire("REPLICATE_ITEM_LIST_UPDATE"); W.fire("REPLICATE_ITEM_LIST_UPDATE")
W.runTimers()
check(db.prices[2318].p == 10 and db.prices[2318].n == 25, "lowest unit price + quantity")
check(db.prices[25] == nil, "non-trade-good not stored")
check(W.tooltip(249427):find("SELL ON AH", 1, true), "scarce mat sells on AH")

-- never / unnever, including removing a seed
SlashCmdList.KENNYMATTOOLTIP("unnever 249427")
check(db.neverVendor[249427] == false and not M.IsNeverVendor(249427), "seed can be removed")
SlashCmdList.KENNYMATTOOLTIP("never 249427")
check(db.neverVendor[249427] == nil and M.IsNeverVendor(249427), "re-adding a seed stores nothing")

-- stale price
W.now = W.now + 4 * 86400
check(W.tooltip(249427):find("price is old", 1, true), "stale price flagged")
SlashCmdList.KENNYMATTOOLTIP("toggle")
check(W.tooltip(249427) == "", "toggle off")
check(db.settings.enabled == false, "toggle stored")
SlashCmdList.KENNYMATTOOLTIP("toggle")
check(db.settings.enabled == nil, "back to default stores nil")
SlashCmdList.KENNYMATTOOLTIP("report")
local rep = _G["KennyMatTooltipReportWindow"]
check(rep and rep.shown, "report window shown")
-- 0.4.0: working with our other addons
local hub = KennyAddonsHub
hub.AddTooltip("NeutralFlip", 20, function(tt) if tt.Claim("price.auction") then tt:AddLine("NF price") end end)
local tx = W.tooltip(2318)
check(tx:find("NF price", 1, true) and not tx:find("AH (", 1, true) and tx:find("Vendor", 1, true), "AH price shown once (by NeutralFlip), verdict still shown: " .. tx)
hub.Provide("trend", "PriceLog", function(id) if id == 2318 then return { label = "RISING", change = 0.2 } end end)
check(W.tooltip(2318):find("RISING", 1, true), "PriceLog trend shown with the verdict")
hub.RegisterPrices("PriceLog", function(id) if id == 2318 then return { p = 1, t = W.now + 5 } end end)
check(M.GetPriceRecord(2318).p == 1, "shared PriceLog price used when newer")
W.done("MatTooltip")
