unpack=unpack or table.unpack
for _,f in ipairs({'Config','Data','World','HubData','Hub','Tactics','Story','Model','LiveCatalog','Engine','Coins','Audio','Controller','HubController'}) do dofile('PBsTradeGame/'..f..'.lua') end
local H,K,M,A=PBTrade.Hub,PBTrade.HubData,PBTrade.Model,PBTrade.Controller
local count=0
local function test(name,fn) fn();count=count+1;print('PASS '..name) end
local function building(id,kind,x,y) return {id=id,type=kind,x=x,y=y,level=1,paidCost=1e7,remainingPeriods=0} end
local function context(chapter) return {chapter=chapter,cash=1e15,average=1e8} end
test('chapter catalogue 5 8 11 and backend rejects locked facilities without mutation',function()
 for chapter,n in pairs({[3]=5,[4]=8,[5]=11}) do assert(#H.Catalogue(chapter)==n) end
 local h=H.New(0);assert(not H.Build(h,context(3),'exchange',1,1));assert(#h.buildings==0 and h.nextBuildingId==1)
 assert(not H.Build(h,context(4),'gate',1,1));assert(H.Build(h,context(4),'exchange',1,1))
 assert(H.Build(h,context(5),'gate',2,1));assert(h.buildings[1].remainingPeriods==3 and h.buildings[2].remainingPeriods==4)
 for _,f in ipairs(K.facilities) do local one=H.New(0); assert(H.Build(one,context(5),f.id,1,1))
  for cycle=1,f.periods do assert(H.Settle(one,cycle,5).net==0) end
  assert(H.Settle(one,f.periods+1,5).net>0)
  assert(H.Load(one,f.periods+1,5).buildings[1].type==f.id)
 end
end)
test('new districts and adjacencies work without double membership',function()
 local h=H.New(0);h.buildings={building(1,'gate',1,1),building(2,'aether',2,1),building(3,'pact',2,2),building(4,'warehouse',1,2)}
 local e=H.Effects(h,5);assert(e.districts[1].id=='arcane' and #e.pairs==1)
 h.buildings[2].remainingPeriods=1;assert(#H.Effects(h,5).districts==0)
 h.buildings={building(1,'embassy',1,1),building(2,'bureau',2,1),building(3,'guildhall',2,2)}
 assert(H.Effects(h,4).districts[1].id=='diplomatic')
end)
test('policy changes only on settlement and applies exactly once',function()
 local h=H.New(0);h.buildings={building(1,'market',1,1)}
 assert(not H.QueuePolicy(h,2,'commerce') and not H.QueuePolicy(h,3,'bad'))
 assert(H.QueuePolicy(h,3,'commerce'));assert(h.policy=='balanced' and H.Operating(h).income==1)
 h=H.Load(h,0,3);assert(h.pendingPolicy=='commerce')
 local r=H.Settle(h,1,3);assert(r.policy=='商業振興' and r.gross==198000 and r.upkeep==69000)
 assert(h.pendingPolicy==nil and H.Abilities(h).commerce==13)
 assert(H.Settle(h,1,3).net==0)
end)
test('security halves adverse event effects without changing ownership or investments',function()
 local h=H.New(0);h.buildings={building(1,'bank',1,1)};h.activeEvent={id='repairs',remaining=2}
 assert(H.Operating(h).income==.85)
 h.policy='security';assert(math.abs(H.Operating(h).income-.95*.925)<1e-8)
 local cost=h.buildings[1].paidCost;H.Settle(h,1,3);H.Settle(h,2,3)
 assert(not h.activeEvent and h.buildings[1].paidCost==cost and #h.buildings==1)
end)
test('event RNG and remaining durations survive reload; UI reads do not reroll',function()
 local h=H.New(0);h.buildings={building(1,'market',1,1)}
 local resumed=H.Load(h,0,3);local events=0;local last=-100
 for cycle=1,500 do
  local a=H.Settle(h,cycle,3)
  for _=1,5 do H.Effects(resumed,3);H.Operating(resumed) end
  local b=H.Settle(resumed,cycle,3)
  assert(a.net==b.net and h.eventSeed==resumed.eventSeed)
  assert((a.event and a.event.id)==(b.event and b.event.id))
  if a.event then assert(cycle-last>=K.eventGap);last=cycle;events=events+1 end
  resumed=H.Load(resumed,cycle,3)
 end
 assert(events>0 and #h.eventLog<=K.eventLogLimit and #h.buildings==1)
end)
test('corrupt operation state is sanitized and empty town has no events',function()
 local h=H.Load({policy='missing',pendingPolicy='missing',eventSeed=0/0,lastEventCycle=math.huge,
 activeEvent={id='repairs',remaining=999},eventLog={{id='bad',cycle=1},false}},5,3)
 assert(h.policy=='balanced' and not h.pendingPolicy and not h.activeEvent and #h.eventLog==0)
 local seed=h.eventSeed;for cycle=6,100 do assert(not H.Settle(h,cycle,3).event) end
 assert(seed==h.eventSeed)
end)
test('gamepad cycles chapter catalogue and policy is read-only outside administration',function()
 local a=A.New(nil,{});a.state.chapter=4;a.state.hub.introSeen=true;a:StartAdministration();a.index=2;a:Act('confirm')
 local names={};for _=1,8 do names[a:HubCandidate().id]=true;a:Act('next') end
 assert(names.exchange and names.bureau and names.embassy and not names.gate)
 local cash=a.state.cash;a:Act('info');assert(a.modal.hubPolicy)
 a:Act('next');a:Act('confirm');assert(a.state.hub.pendingPolicy=='commerce' and a.state.hub.policy=='balanced')
 assert(a.saved.state.hub.pendingPolicy=='commerce' and a.state.cash==cash)
 a:Act('detail');assert(a.hubGuide);a:Act('back');a:Act('back')
 a.screen='management';a:OpenHub();a:Act('info');a:Act('next');a:Act('confirm')
 assert(a.state.hub.pendingPolicy=='commerce')
end)
print(count..' phase5 tests passed')
