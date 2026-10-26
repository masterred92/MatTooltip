-- Bagnon bag markers: a small SELL / VEND / ? tag on Skinning and Herbalism mats in Bagnon's bags.
-- Only if Bagnon (BagBrother 12.x) is loaded. It hooks BagBrother.Item:Update after the fact (hooksecurefunc),
-- so Bagnon's own code runs unchanged. Turn it off with /mattip bagnon.
local _, ns = ...
local M = KennyMatTooltip
local C = ns.Compat

local TAGS = { ["SELL ON AH"] = { "SELL", 0.2, 1, 0.2 }, VENDOR = { "VEND", 1, 0.82, 0 }, HOLD = { "?", 0.4, 0.8, 1 } }
local buttons = setmetatable({}, { __mode = "k" })

local function mark(button)
  local fs = button.KennyMatTooltipTag
  local st = M.Settings()
  local id = button.info and C.SafeNumber(button.info.itemID)
  local verdict = st and st.enabled and st.bagnon and id and M.ItemVerdict(id)
  local tag = verdict and TAGS[verdict]
  if not tag then if fs then fs:Hide() end return end
  if not fs then
    fs = button:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmall")
    fs:SetPoint("TOPLEFT", button, "TOPLEFT", 2, -2)
    button.KennyMatTooltipTag = fs
  end
  fs:SetText(tag[1])
  fs:SetTextColor(tag[2], tag[3], tag[4])
  fs:Show()
end

local function onUpdate(button)
  buttons[button] = true
  pcall(mark, button)
end

local hooked = false
function M.HookBagnon()
  if hooked then return true end
  local addon = _G.BagBrother
  local Item = type(addon) == "table" and addon.Item
  if type(Item) ~= "table" or type(Item.Update) ~= "function" then return false end
  hooksecurefunc(Item, "Update", onUpdate)
  hooked = true
  return true
end

function M.RefreshBagnon()
  if not hooked then return false end
  for b in pairs(buttons) do pcall(mark, b) end
  return true
end

local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_LOGIN")
f:RegisterEvent("ADDON_LOADED")
f:SetScript("OnEvent", function(self, event)
  if M.HookBagnon() then self:UnregisterAllEvents() return end
  if event == "PLAYER_LOGIN" then self:UnregisterEvent("PLAYER_LOGIN") end
end)
