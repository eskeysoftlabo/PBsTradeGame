unpack=unpack or table.unpack
for _,f in ipairs({'Config','Data','World','HubData','Hub','Tactics','Story','Model','LiveCatalog','Engine','Coins','Audio','Controller','HubController'}) do dofile('PBsTradeGame/'..f..'.lua') end
local H,K,M,E,C,D=PBTrade.Hub,PBTrade.HubData,PBTrade.Model,PBTrade.Engine,PBTrade.Config,PBTrade.Data
local count=0
local function test(name,fn) fn();count=count+1;print('PASS '..name) end
local function facility(id,kind,x,y)
 return {id=id,type=kind,x=x,y=y,level=3,paidCost=1e7,remainingPeriods=0}
end
local function grown(s)
 s.hub.buildings={}
 for y=1,H.Size(s.chapter) do for x=1,H.Size(s.chapter) do
  local id=(y-1)*H.Size(s.chapter)+x
  s.hub.buildings[id]=facility(id,K.facilities[(id-1)%5+1].id,x,y)
 end end
end
local function opponent(s)
 for _,d in ipairs(D.properties) do local p=s.properties[d.id]
  if p.isHeadquarters and p.owner~=C.playerId and p.owner~=C.neutralId and M.IsAvailable(s,p) then
   s.unlocked[p.zone]=true; return p
  end
 end
 error('missing opponent')
end
test('chapter-sized construction, movement and save restoration through nine by nine',function()
 for chapter,size in pairs({[3]=5,[4]=7,[5]=9}) do
  local s=M.New();s.chapter=chapter; local c={chapter=chapter,cash=1e20,average=1e8}
  assert(H.Size(chapter)==size and H.Build(s.hub,c,'bank',size,size))
  assert(not H.Build(s.hub,c,'bank',size+1,size))
  local restored=M.Load(M.Export(s)); assert(H.At(restored.hub,size,size))
  restored.hub.buildings[1].remainingPeriods=0
  assert(H.Change(restored.hub,c,'move',1,size-1,size))
 end
end)
test('expansion restores legacy annex without losing investments or ids',function()
 local h=H.New(0)
 for y=1,8 do for x=1,8 do h.buildings[#h.buildings+1]=facility((y-1)*8+x,'bank',x,y) end end
 h=H.Load(h,0,3);assert(#h.buildings==25 and #h.annex==39)
 H.Expand(h,4);assert(#h.buildings==49 and #h.annex==15)
 H.Expand(h,5);assert(#h.buildings==64 and #h.annex==0)
 local ids={};for _,b in ipairs(h.buildings) do assert(not ids[b.id] and b.paidCost==1e7);ids[b.id]=true end
 assert(H.Expand(h,5)==0)
end)
test('blueprints persist after supplier loss but current supply bonus falls',function()
 local s=M.New();s.chapter=3;grown(s);M.RefreshHub(s)
 for _,p in pairs(s.properties) do p.owner=C.neutralId end
 local p=s.properties[D.properties[1].id];p.owner=C.playerId;p.category='port'
 M.RefreshHub(s);assert(s.hub.blueprints.warehouse)
 local before=H.Effects(s.hub,3,M.HubSupply(s)).abilities.logistics
 p.owner=C.neutralId
 local after=H.Effects(s.hub,3,M.HubSupply(s)).abilities.logistics
 assert(after<before and s.hub.blueprints.warehouse)
 assert(M.Load(M.Export(s)).hub.blueprints.warehouse)
end)
test('chapters one and two retain identity combat factors even with a developed hub',function()
 for chapter=1,2 do local s=M.New();s.chapter=chapter;grown(s)
  local r=M.HubProfile(s,opponent(s));assert(not r.enabled and r.pressure==1 and r.value==1 and r.playerWait==1 and r.resistance==0)
 end
end)
test('only important acquisition targets receive barriers, defense and neutral ordinary stay accessible',function()
 local s=M.New();s.chapter=5;local p=opponent(s)
 local r=M.HubProfile(s,p);assert(r.barrier and r.value==1.15 and r.pressure>0.8)
 local ordinary=M.Copy(p);ordinary.id='ordinary';ordinary.isHeadquarters=false;ordinary.finalStronghold=false;ordinary.finalAcquisition=false
 local o=M.HubProfile(s,ordinary);assert(not o.barrier and o.value==1)
 local d=M.HubProfile(s,p,p.owner);assert(not d.barrier and d.value==1)
 grown(s);local good=M.HubProfile(s,p)
 assert(good.pressure>r.pressure and good.pressure<=1.1 and good.value>=1 and good.value<r.value)
 assert(good.enemyWait<=1.1 and good.idle>=.9 and good.resistance<=.1)
end)
test('engine snapshot is frozen; treasury accounting and enemy budget do not use virtual funds',function()
 local s=M.New();s.chapter=5;s.cash=1e15;local p=opponent(s);grown(s)
 local plain=M.Copy(s);plain.hub=H.New(s.cycles)
 local e=E.New(s,function() return .5 end);local other=E.New(plain,function() return .5 end)
 assert(e:Start(p.id) and other:Start(p.id))
 assert(e.battle.enemyBudget==other.battle.enemyBudget and e.battle.enemyBid==other.battle.enemyBid)
 local snapshot=e.battle.hub.pressure; s.hub.buildings={}
 local cash=s.cash;assert(e:Treasury(1000));assert(s.cash==cash-1000 and e.battle.playerBid==1000)
 assert(e.battle.hub.pressure==snapshot and e.battle.effectiveValue==e.battle.baseValue*e.battle.hub.value)
 local tactic=D.tacticById.smile;p.negotiationResistances[tactic.resistanceKey]=1
 assert(e:TacticResistance(tactic,p)==1)
end)
test('defense support is bounded and no automatic victory at maximum development',function()
 local s=M.New();s.chapter=5;grown(s);local p=opponent(s);local attacker=p.owner;p.owner=C.playerId
 local e=E.New(s,function() return .5 end);assert(e:Start(p.id,attacker))
 assert(e.battle.hub.playerWait>=.9 and e.battle.hub.enemyTactic>=.9 and e.battle.hub.value==1)
 assert(not e.battle.result and e.battle.criticalStage==0)
 assert(math.abs(e:PlayerWaitDuration()-C.battle.playerWait*e.battle.hub.playerWait)<.0001)
end)
print(count..' phase4 tests passed')
