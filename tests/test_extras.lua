package.path = "tests/?.lua;" .. package.path
local W = require("mock_wow"); W.install()
local check = W.check
local ldbObjs = {}
LibStub = setmetatable({}, { __call = function(_, name, silent) if name == "LibDataBroker-1.1" then return { NewDataObject = function(_, n, o) ldbObjs[n] = o; return o end } end assert(silent) end })
local tt = { lines = {} }
function tt:AddLine(s) self.lines[#self.lines + 1] = tostring(s) end
function tt:AddDoubleLine(a, b) self.lines[#self.lines + 1] = tostring(a) .. ": " .. tostring(b) end
local function ttText(o) tt.lines = {}; o.OnTooltipShow(tt); return table.concat(tt.lines, " | ") end
-- Bagnon (BagBrother) Item class with an Update method, as in BagBrother core/classes/item.lua
local hooks = {}
hooksecurefunc = function(t, k, fn) local orig = t[k]; t[k] = function(...) orig(...); fn(...) end; hooks[#hooks + 1] = k end
local Item = { Update = function(self, info) self.info = info end }
BagBrother = { Item = Item }
W.loadAddon(".", "MatTooltip")
W.fire("PLAYER_LOGIN"); W.runTimers()
local M = KennyMatTooltip
check(#hooks == 1 and hooks[1] == "Update", "hooked BagBrother.Item:Update")
local function newButton()
  local b = { CreateFontString = function() local fs = { shown = false }
    function fs:SetPoint() end function fs:SetText(t) self.text = t end function fs:SetTextColor() end
    function fs:Show() self.shown = true end function fs:Hide() self.shown = false end return fs end }
  return setmetatable(b, { __index = Item })
end
local b = newButton()
b:Update({ itemID = 2447 })
check(b.KennyMatTooltipTag and b.KennyMatTooltipTag.text == "?", "mat with no scan: ? tag")
KennyMatTooltipDB.prices[2447] = { p = 500, t = W.now }
b:Update({ itemID = 2447 })
check(b.KennyMatTooltipTag.text == "SELL", "scanned mat worth selling: SELL tag")
b:Update({ itemID = 25 })
check(not b.KennyMatTooltipTag.shown, "non-trade-good: tag hidden")
local b2 = newButton(); b2:Update({}); check(b2.KennyMatTooltipTag == nil, "empty slot: no tag")
W.secret[2447] = true; b:Update({ itemID = 2447 }); W.secret[2447] = nil
check(not b.KennyMatTooltipTag.shown, "secret itemID: no tag")
b:Update({ itemID = 2447 })
SlashCmdList.KENNYMATTOOLTIP("bagnon")
check(not b.KennyMatTooltipTag.shown, "/mattip bagnon turns markers off and refreshes")
SlashCmdList.KENNYMATTOOLTIP("bagnon")
check(b.KennyMatTooltipTag.shown, "and back on")
-- LDB
W.bags[0] = { [1] = { 2447, 10 }, [2] = { 2589, 3 } }
local o = ldbObjs.MatTooltip
M.UpdateBroker()
check(o and o.text == "mats 4750c", "LDB text: AH value of SELL mats after cut")
check(ttText(o):find("10x Peacebloom: SELL ON AH"), "LDB tooltip lists bag mats")
W.done("MatTooltip extras")
