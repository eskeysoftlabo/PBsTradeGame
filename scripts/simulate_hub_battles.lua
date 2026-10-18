-- Synthetic important encounters. Same starting budget and battle RNG, actual hub costs.
-- Only hub time advances during preparation; outside income/market/opponent are held fixed.
-- Treasury-only battle policy, NOT an estimate of real-player success or optimal play.
unpack=unpack or table.unpack
for _,f in ipairs({'Config','Data','World','HubData','Hub','Tactics','Story','Model','LiveCatalog','Engine'}) do dofile('PBsTradeGame/'..f..'.lua') end
local M,E,H,K,C,D=PBTrade.Model,PBTrade.Engine,PBTrade.Hub,PBTrade.HubData,PBTrade.Config,PBTrade.Data
local function rng(seed) return function() seed=(seed*48271+11)%2147483647;return seed/2147483647 end end
print('chapter,mode,strategy,preparation,budget_ratio,seed,result,seconds,spent,hub_income,buildings,districts,committed,pressure,value')
for chapter=3,5 do for _,defense in ipairs({false,true}) do for _,strategy in ipairs({'empty','single','mixed','specialist'}) do
 for _,periods in ipairs({5,20}) do for _,ratio in ipairs({.6,1,1.25,1.5,2,3,4,8}) do for seed=1,4 do
 local s=M.New();s.chapter=chapter
 local target
 for _,id in ipairs(D.campaigns[chapter].objective.targets or {}) do target=s.properties[id];if target then break end end
 assert(target,'chapter objective missing');s.unlocked[target.zone]=true
 local style=s.companies[target.owner] and s.companies[target.owner].personality
 local attacker=defense and target.owner or nil
 if defense then target.owner=C.playerId end
 local value=M.NegotiationValue(s,target,attacker);s.cash=value*ratio
 local spent,earned=0,0
 local types=H.Catalogue(chapter)
 for cycle=1,periods do
  if strategy~='empty' then
   local index=#s.hub.buildings+1;local kind=types[(index-1)%#types+1].id
   if strategy=='single' then kind='market' end
   if strategy=='specialist' then
    local ability=K.battle.styles[style] or 'influence';local best=-1
    for _,f in ipairs(types) do local score=(f.abilities[ability] or 0)/f.cost
     if score>best then kind,best=f.id,score end
    end
   end
   local size=H.Size(chapter);local x,y=(index-1)%size+1,math.floor((index-1)/size)+1
   local cost=H.Cost(kind,M.HubCostBase(s))
   if cost<=s.cash*.1 then
    local ok,paid=H.Build(s.hub,{chapter=chapter,cash=s.cash,average=M.HubCostBase(s)},kind,x,y)
    if ok then spent=spent+paid;s.cash=s.cash-paid end
   end
  end
  local net=H.Settle(s.hub,cycle,chapter).net;earned=earned+net;s.cash=s.cash+net
 end
 M.RefreshHub(s)
 local e=E.New(s,rng(seed));assert(e:Start(target.id,attacker))
 while not e.battle.result do
  if e:Ready() and s.cash>=1 then e:Treasury(math.min(s.cash,math.max(1,math.floor(value*.1)))) end
  e:Step(C.battle.step)
 end
 local b=e.battle
 print(table.concat({chapter,defense and 'defense' or 'acquisition',strategy,periods,ratio,seed,b.result,b.elapsed,spent,earned,
  #s.hub.buildings,#H.Effects(s.hub,chapter).districts,b.playerBid,b.hub.pressure,b.hub.value},','))
end end end end end end
