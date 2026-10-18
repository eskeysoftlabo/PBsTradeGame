-- Controlled Engine probe, not a campaign-duration or optimal-player simulation.
unpack=unpack or table.unpack
for _,f in ipairs({'Config','Data','World','HubData','Hub','Tactics','Story','Model','LiveCatalog','Engine'}) do dofile('PBsTradeGame/'..f..'.lua') end
local M,E,H,K,C,D=PBTrade.Model,PBTrade.Engine,PBTrade.Hub,PBTrade.HubData,PBTrade.Config,PBTrade.Data
local function rng(seed) return function() seed=(seed*48271+11)%2147483647;return seed/2147483647 end end
print('chapter,mode,hub,budget_ratio,seed,result,seconds,committed,pressure_factor,value_factor')
for chapter=3,5 do for _,defense in ipairs({false,true}) do for _,developed in ipairs({false,true}) do for _,ratio in ipairs({.6,2.0,8.0}) do for seed=1,4 do
 local s=M.New();s.chapter=chapter
 local target
 for _,id in ipairs(D.campaigns[chapter].objective.targets or {}) do target=s.properties[id];if target then break end end
 if not target then for _,p in ipairs(D.properties) do if p.isHeadquarters and p.owner~='player' and p.owner~='neutral' and M.IsAvailable(s,s.properties[p.id]) then target=s.properties[p.id];break end end end
 assert(target);s.unlocked[target.zone]=true
 local attacker=defense and target.owner or nil
 if defense then target.owner=C.playerId end
 local value=M.NegotiationValue(s,target,attacker)
 s.cash=value*ratio
 if developed then
  for y=1,H.Size(chapter) do for x=1,H.Size(chapter) do local id=(y-1)*H.Size(chapter)+x
   s.hub.buildings[id]={id=id,type=K.facilities[(id-1)%5+1].id,x=x,y=y,level=3,paidCost=1e7,remainingPeriods=0}
  end end
 end
 M.RefreshHub(s)
 local e=E.New(s,rng(seed));assert(e:Start(target.id,attacker))
 while not e.battle.result do
  if e:Ready() and s.cash>=1 then e:Treasury(math.min(s.cash,math.max(1,math.floor(value*.10)))) end
  e:Step(1/30)
 end
 local b=e.battle
 print(string.format('%d,%s,%s,%.1f,%d,%s,%.2f,%.0f,%.4f,%.4f',chapter,defense and 'defense' or 'acquisition',developed and 'developed' or 'empty',ratio,seed,b.result,b.elapsed,b.playerBid,b.hub.pressure,b.hub.value))
end end end end end
