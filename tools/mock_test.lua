-- Minimal mock of the WoW client to exercise load, tooltip hook, verdicts, scan and slash commands.
local hooks, frame, lines, now, combat = {}, nil, {}, 1000000, false
local items = { -- itemID -> {classID, subID, sellPrice}
  [2318]={7,6,15}, [2447]={7,9,10}, [249427]={7,6,500}, [249399]={7,9,300}, [2589]={7,5,13} }
Enum = { TooltipDataType = { Item = 0 } }
C_Item = { GetItemInfoInstant=function(id) local i=items[id]; if i then return id,"","","",0,i[1],i[2] end end,
  GetItemInfo=function(id) local i=items[id]; if i then return "n","l",1,1,1,"","",1,"",0,i[3],i[1],i[2] end end }
local repl = {}
C_AuctionHouse = { GetNumReplicateItems=function() return #repl end,
  GetReplicateItemInfo=function(i) local r=repl[i+1]; return "n",0,r[2],1,true,1,"",0,0,r[3],0,nil,nil,nil,nil,0,r[1],true end,
  IsThrottledMessageSystemReady=function() return true end, ReplicateItems=function() frame.fire("REPLICATE_ITEM_LIST_UPDATE") end }
C_Timer = { After=function(_, fn) fn() end }
TooltipDataProcessor = { AddTooltipPostCall=function(t, fn) hooks[t]=fn end }
GameTooltip = { AddLine=function(_, s) lines[#lines+1]=s end, AddDoubleLine=function(_, a, b) lines[#lines+1]=a..": "..b end }
ItemRefTooltip = {}
function GetMoneyString(c) return c.."c" end
function InCombatLockdown() return combat end
function time() return now end
SlashCmdList = {}
function CreateFrame() local ev, h = {}, nil
  frame = { RegisterEvent=function(_, e) ev[e]=true end, UnregisterEvent=function(_, e) ev[e]=nil end,
    SetScript=function(_, _, fn) h=fn end }
  frame.fire=function(e, ...) if ev[e] then h(frame, e, ...) end end; return frame end
local chunk = assert(loadfile("MatTooltip.lua")); chunk("MatTooltip")
frame.fire("ADDON_LOADED", "MatTooltip")
assert(hooks[0], "tooltip hook registered")
local function tip(id) lines = {}; hooks[0](GameTooltip, {id=id}); return table.concat(lines, " | ") end
local fails = 0
local function expect(id, pat) local s = tip(id); local ok = s:find(pat, 1, true) ~= nil
  print((ok and "PASS " or "FAIL ")..id..": "..s); if not ok then fails = fails + 1 end end
expect(2318, "HOLD"); expect(249427, "NEVER VENDOR"); expect(2589, "")
assert(tip(2589) == "", "non-mat cloth gets nothing")
assert(tip(nil) == "", "nil id safe")
SlashCmdList.MATTOOLTIP("scan") -- AH closed -> refused
frame.fire("AUCTION_HOUSE_SHOW")
repl = { {2318, 20, 400}, {2318, 5, 50}, {2447, 10, 50}, {249427, 1, 9000}, {2589, 1, 999} }
SlashCmdList.MATTOOLTIP("scan")
assert(MatTooltipDB.prices[2318].p == 10 and MatTooltipDB.prices[2318].n == 25, "min unit price")
assert(not MatTooltipDB.prices[2589], "non-mat not stored")
expect(2318, "VENDOR")      -- 10c*0.95 < 15c vendor
expect(2447, "VENDOR")      -- 5c*0.95 < 10c
expect(249427, "SELL ON AH") -- scarce
SlashCmdList.MATTOOLTIP("never 2318"); expect(2318, "SELL ON AH")
now = now + 4*86400; expect(249427, "price is old")
SlashCmdList.MATTOOLTIP("toggle"); assert(tip(249427) == "", "toggle off")
print(fails == 0 and "ALL MOCK TESTS PASSED" or (fails.." FAILED")); os.exit(fails == 0 and 0 or 1)
