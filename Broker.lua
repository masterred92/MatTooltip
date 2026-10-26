-- LibDataBroker display (Titan Panel, ChocolateBar, Bazooka...): what the mats in your bags are worth and what to do.
local _, ns = ...
local M = KennyMatTooltip
local C = ns.Compat
local obj

-- Mats in your bags: list of { id, n, verdict, value } and the AH value of the SELL ones (after the cut).
function M.BagSummary()
  local out, sellValue = {}, 0
  local st = M.Settings()
  for id, n in pairs(C.GetBagCounts()) do
    local verdict, rec = M.ItemVerdict(id)
    if verdict then
      local value = rec and rec.p and math.floor(rec.p * n * (1 - (st and st.ahCut or 0.05))) or 0
      if verdict == "SELL ON AH" then sellValue = sellValue + value end
      out[#out + 1] = { id = id, n = n, verdict = verdict, value = value }
    end
  end
  table.sort(out, function(a, b) if a.value ~= b.value then return a.value > b.value end return a.id < b.id end)
  return out, sellValue
end

function M.UpdateBroker()
  if not obj then return end
  local list, sell = M.BagSummary()
  obj.text = #list == 0 and "no mats" or ("mats " .. C.Money(sell))
end

function M.InstallBroker()
  if obj then return obj end
  local ldb = type(LibStub) == "table" and LibStub("LibDataBroker-1.1", true)
  if not ldb then return nil end
  obj = ldb:NewDataObject("MatTooltip", {
    type = "data source", text = "Mat Tooltip", label = "Mats",
    icon = "Interface\\AddOns\\MatTooltip\\media\\icon",
    OnClick = function() SlashCmdList.KENNYMATTOOLTIP("toggle") end,
    OnTooltipShow = function(tt)
      local list, sell = M.BagSummary()
      tt:AddLine("Mat Tooltip: mats in your bags")
      if #list == 0 then tt:AddLine("No Skinning or Herbalism mats in your bags.", 1, 1, 1) end
      for i = 1, math.min(10, #list) do
        local e = list[i]
        tt:AddDoubleLine(("%dx %s"):format(e.n, C.GetItemName(e.id) or ("item " .. e.id)), e.verdict .. (e.value > 0 and ("  " .. C.Money(e.value)) or ""), 1, 1, 1, 0.8, 0.8, 0.8)
      end
      tt:AddDoubleLine("Worth selling on the AH", C.Money(sell), 0.2, 1, 0.2, 1, 1, 1)
      tt:AddLine("Your own scan prices, after the AH cut. Click: tooltip lines on/off.", 0.6, 0.6, 0.6, true)
    end,
  })
  M.UpdateBroker()
  return obj
end

local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_LOGIN")
f:RegisterEvent("BAG_UPDATE_DELAYED")
f:SetScript("OnEvent", function(_, event)
  if event == "PLAYER_LOGIN" then M.InstallBroker() elseif not C.InCombat() then M.UpdateBroker() end
end)
