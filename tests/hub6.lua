unpack=unpack or table.unpack
for _,f in ipairs({'Config','Data','World','HubData','Hub','Tactics','Story','Model','LiveCatalog','Engine','Coins','Audio','Controller','HubController'}) do dofile('PBsTradeGame/'..f..'.lua') end
local H,K,M,A=PBTrade.Hub,PBTrade.HubData,PBTrade.Model,PBTrade.Controller
local n=0
local function test(name,fn) fn();n=n+1;print('PASS '..name) end
local function b(id,x,y,kind) return {id=id,x=x,y=y,type=kind or 'market',level=1,paidCost=1e8,remainingPeriods=0} end
local function close(a,b) assert(math.abs(a-b)<1e-7,tostring(a)..' != '..tostring(b)) end
test('only orthogonal open roads qualify, diagonals and occupied roads do not',function()
 local h=H.New(0);h.buildings={b(1,2,2)}
 assert(H.RoadAccess(h,2,2,3));assert(not H.RoadAccess(h,1,1,3))
 h.buildings[2]=b(2,3,2);h.buildings[3]=b(3,2,3);h.buildings[3].remainingPeriods=1
 assert(not H.RoadAccess(h,2,2,3));h.buildings[3]=nil;assert(H.RoadAccess(h,2,2,3))
end)
test('multiple road sides award once and only active buildings earn',function()
 local h=H.New(0);h.buildings={b(1,2,2)}
 local e=H.Effects(h,3);assert(e.roadAccess[1]);close(e.income[1],K.roadIncome)
 local r=H.Settle(h,1,3);assert(math.abs(r.gross-1890000)<=1 and r.upkeep==600000)
 h.buildings[1].remainingPeriods=1;assert(not H.Effects(h,3).roadAccess[1]);assert(H.Settle(h,2,3).net==0)
 assert(math.abs(H.Settle(h,3,3).gross-1890000)<=1)
end)
test('chapter expansion and reload recalculate road access without a saved bonus',function()
 local h=H.New(0);h.buildings={b(1,2,2)}
 assert(H.Effects(h,3).roadAccess[1]);assert(not H.Effects(h,4).roadAccess[1])
 local loaded=H.Load(h,0,4);assert(not H.Effects(loaded,4).roadAccess[1])
 loaded.buildings[1].x=3;assert(H.Effects(loaded,4).roadAccess[1])
end)
test('roads respect layout cap, never grant combat stats, never benefit annex',function()
 local h=H.New(0);h.buildings={b(1,2,2)};h.annex={b(2,2,2)}
 local e=H.Effects(h,3);assert(not e.roadAccess[2]);assert(e.abilities.commerce==24)
 local old=K.roadIncome;K.roadIncome=1;local capped=H.Effects(h,3);K.roadIncome=old
 close(capped.income[1],K.maximumLayoutIncome)
end)
test('policy event and road modifiers use the same settlement formula',function()
 local h=H.New(0);h.buildings={b(1,2,2)};h.policy='commerce';h.activeEvent={id='merchants',remaining=3}
 local r=H.Settle(h,1,3)
 assert(math.abs(r.gross-math.floor(1e8*K.incomeShare*1.05*1.1*1.15))<=1);assert(H.Settle(h,1,3).net==0)
end)
test('expensive specialist facilities pay back within 110 periods without events or roads',function()
 for _,id in ipairs({'bureau','embassy','gate'}) do
  local h=H.New(0);local ok,cost=H.Build(h,{chapter=5,cash=1e12,average=1e8},id,1,1);assert(ok)
  h.lastEventCycle=1000;local earned=0
  for cycle=1,110 do earned=earned+H.Settle(h,cycle,5).net end
  assert(earned>=cost,id)
 end
end)
test('settlement skips second layout calculation unless construction completes',function()
 local h=H.New(0);h.buildings={b(1,1,1)};local real=H.Effects;local calls=0
 H.Effects=function(...) calls=calls+1;return real(...) end
 H.Settle(h,1,3);assert(calls==1)
 calls=0;h.buildings[1].remainingPeriods=1;H.Settle(h,2,3);assert(calls==2)
 H.Effects=real
end)
test('candidate detail describes the road income before committing funds',function()
 local a=A.New(nil,{});a.state.chapter=3;a.hubCursor={x=2,y=2};a.hubFacility=2
 assert(a:HubDetail():find('道路沿い：収益+5%',1,true))
end)
print(n..' phase6 tests passed')
