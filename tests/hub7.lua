unpack=unpack or table.unpack
for _,f in ipairs({'Config','Data','World','HubData','Hub','Tactics','Story','Model','LiveCatalog','Engine','Coins','Audio','Controller','HubController'}) do dofile('PBsTradeGame/'..f..'.lua') end
local C,D,H,K,M,E,A=PBTrade.Config,PBTrade.Data,PBTrade.Hub,PBTrade.HubData,PBTrade.Model,PBTrade.Engine,PBTrade.Controller
local n=0
local function test(name,fn) fn();n=n+1;print('PASS '..name) end
local function close(a,b,eps) assert(math.abs(a-b)<=(eps or 1e-7),tostring(a)..' != '..tostring(b)) end
-- Puts finished facilities straight onto the hub (no construction) for a given state.
local function place(s,list)
    local id=#H.All(s.hub)
    for _,spec in ipairs(list) do
        id=id+1
        s.hub.buildings[#s.hub.buildings+1]={id=id,type=spec[1],x=spec[2],y=spec[3],level=spec[4] or 1,paidCost=spec[5] or 1e8,remainingPeriods=0}
    end
    s.hub.nextBuildingId=id+1
end
local function battleFor(s,stanceId)
    local e=E.New(s,function() return .5 end)
    local id; for _,d in ipairs(D.properties) do local p=s.properties[d.id]
        if p.owner~='player' and p.owner~='neutral' and s.companies[p.owner] and M.IsAvailable(s,p) and not M.IsCriticalProperty(s,p) and not p.canonical then id=d.id; break end end
    assert(id,'no negotiable property')
    s.unlocked[s.properties[id].zone]=true; s.properties[id].canonical=nil
    local orig=M.NegotiationStances; M.NegotiationStances=function() return {stanceId} end
    local ok,why=e:Start(id); M.NegotiationStances=orig; assert(ok,why)
    return e
end

test('each stance is eased by the ability that answers it, up to the cap',function()
 local s=M.New(); s.chapter=4
 for sid,ability in pairs(K.stanceAbility) do local r=M.HubStanceRelief(s,sid); close(r,0) end
 place(s,{{'bank',1,1},{'bank',2,1},{'market',1,2},{'guildhall',2,2}})
 local capital,ability,have=M.HubStanceRelief(s,'vault'); assert(ability=='capital' and have>0 and capital>0 and capital<K.stanceReliefMax)
 close(capital,K.stanceReliefMax*have/(have+K.battle.threshold[4]))
 local none=M.HubStanceRelief(s,'courier'); assert(none==0,'no logistics buildings, no courier relief')
 local wall=H.BattleProfile(s.hub,4,M.HubSupply(s),'wealth',true,false); close(wall.stanceRelief.vault,capital)
 assert(M.HubStanceRelief(M.New(),'vault')==0,'no relief before the hub unlocks')
end)

test('relief softens the discount, the courier pace and the money ceiling in a real negotiation',function()
 local s=M.New(); s.chapter=4
 local bare=battleFor(s,'vault'); close(bare:FundWeight('treasury'),.45); local capBare=bare:PressureCap()
 place(s,{{'bank',1,1},{'bank',2,1},{'exchange',1,2},{'embassy',2,2}})
 local eased=battleFor(s,'vault')
 local relief=eased.battle.stances[1].relief; assert(relief>0)
 close(eased:FundWeight('treasury'),.45+.55*relief)
 assert(eased:FundWeight('treasury')>.45 and eased:PressureCap()>capBare)
 place(s,{{'gate',3,1},{'warehouse',3,2},{'warehouse',4,1}})
 local courier=battleFor(s,'courier'); local rel=courier.battle.stances[1].relief; assert(rel>0)
 local bareCourier=battleFor(M.New(),'courier')
 assert(courier:EnemyWaitFactor()>bareCourier:EnemyWaitFactor() and courier:EnemyWaitFactor()<1)
 close(courier:EnemyWaitFactor(),1+(D.stanceById.courier.enemyWait-1)*(1-rel))
 -- breaking still removes the stance entirely
 courier:HitStances(function(st) return st.breakers.falseMessenger end); courier:HitStances(function(st) return st.breakers.falseMessenger end)
 close(courier:EnemyWaitFactor(),1)
end)

test('the start dialog shows what the hub already does for the stance',function()
 local a=A.New(function() return .5 end); a.modal=nil; local s=a.state; s.chapter=4
 local text=a:StanceAdvice({'vault'}); assert(text:find('交易拠点：資本力 0 → 構えを0%緩和',1,true) and text:find('育てると',1,true))
 place(s,{{'bank',1,1},{'bank',2,1}})
 text=a:StanceAdvice({'vault'}); assert(text:find('資本力',1,true) and not text:find('資本力 0 ',1,true))
end)

test('the hub counts toward total assets: ordering a facility is wealth-neutral',function()
 local s=M.New(); s.chapter=3; s.cash=1e10
 local before=M.Assets(s)
 local ok,cost=H.Build(s.hub,{chapter=3,cash=s.cash,average=M.HubCostBase(s)},'market',1,1); assert(ok and cost>0)
 s.cash=s.cash-cost
 close(M.Assets(s),before,1); close(M.HubValue(s),cost)
 close(M.CoreAssets(s),before-cost,1)
 -- the campaign objective sees the same figure
 assert(M.CampaignStatus(s).assets==M.Assets(s))
 -- demolishing returns only the refund; the rest is written off
 local id=H.At(s.hub,1,1).id
 H.Settle(s.hub,1,3); H.Settle(s.hub,2,3)
 local ok2,q=H.Change(s.hub,{chapter=3,cash=s.cash},'demolish',id); assert(ok2)
 s.cash=s.cash+q.refund
 close(M.Assets(s),before-cost+q.refund,1)
end)

test('hub prices follow the company\'s own wealth, not the market mean',function()
 local s=M.New(); s.chapter=5; s.cash=1e14
 local base=M.HubCostBase(s); close(base,M.CoreAssets(s))
 local price=H.Cost('market',base)
 -- one stratospheric stronghold moves the market mean, never the hub price
 local hi; for _,d in ipairs(D.properties) do local p=s.properties[d.id]; if p.owner~='player' and not p.canonical then hi=p; break end end
 local mean=M.MarketAverage(s); hi.marketValue=hi.marketValue+1e22
 assert(M.MarketAverage(s)>mean*10)
 assert(H.Cost('market',M.HubCostBase(s))==price)
 -- same share of wealth at any scale
 local rich=M.New(); rich.cash=1e16; local poor=M.New(); poor.cash=1e12
 local ratioRich=H.Cost('bank',M.HubCostBase(rich))/M.HubCostBase(rich)
 local ratioPoor=H.Cost('bank',M.HubCostBase(poor))/M.HubCostBase(poor)
 close(ratioRich/ratioPoor,1,1e-3); close(ratioRich,K.costShare*K.byId.bank.cost,1e-6)
 -- Filling a whole chapter-3 quarter (15 market stalls) costs about 4% of the company's wealth,
 -- i.e. roughly a quarter of its cash when cash is the usual sixth of total assets.
 local early=M.New(); early.chapter=3; early.cash=1e12
 local unit=H.Cost('market',M.HubCostBase(early)); local wealth=M.HubCostBase(early)
 close(unit/wealth,K.costShare,1e-6)
 local quarter=unit*H.Capacity(3); assert(quarter/wealth>.03 and quarter/wealth<.05)
end)

test('capacity is 60% of the plots and only new buildings are refused',function()
 close(H.Capacity(3),15); close(H.Capacity(4),30); close(H.Capacity(5),49)
 local s=M.New(); s.chapter=3; s.cash=1e15; local c=function() return {chapter=3,cash=s.cash,average=M.HubCostBase(s)} end
 local n=0
 for y=1,5 do for x=1,5 do if n<15 then
   local ok=H.Build(s.hub,c(),'market',x,y); assert(ok); n=n+1; H.Settle(s.hub,n*2-1,3); H.Settle(s.hub,n*2,3)
 end end end
 local ok,why=H.Build(s.hub,c(),'bank',5,5); assert(not ok and why:find('15棟',1,true))
 -- upgrade, move and demolish still work at capacity; demolishing frees a slot
 local first=H.At(s.hub,1,1)
 assert(H.Change(s.hub,c(),'upgrade',first.id))
 H.Settle(s.hub,100,3); H.Settle(s.hub,101,3); H.Settle(s.hub,102,3)
 assert(H.Change(s.hub,c(),'move',first.id,5,5)); H.Settle(s.hub,103,3); H.Settle(s.hub,104,3)
 assert(H.At(s.hub,5,5) and not H.At(s.hub,1,1))
 assert(H.Change(s.hub,c(),'demolish',H.At(s.hub,2,1).id))
 assert(H.Build(s.hub,c(),'bank',1,1))
 -- a legacy save above the cap keeps everything but cannot add more
 local old=H.New(20); for i=1,25 do old.buildings[i]={id=i,x=(i-1)%5+1,y=math.ceil(i/5),type='market',paidCost=5e6,remainingPeriods=0,level=1} end
 local loaded=H.Load(old,20,3); assert(#H.All(loaded)==25)
 assert(not H.Build(loaded,{chapter=3,cash=1e15,average=1e12},'bank',1,1))
end)

test('the facility detail names the stance its main ability eases',function()
 local a=A.New(function() return .5 end); a.modal=nil; a.state.chapter=3; a.state.cash=1e12
 a:OpenHub(); a.modal=nil
 assert(H.Capacity(3)==15 and a:HubDetail():find('構えへの効果',1,true))
end)
print(n..' phase7 tests passed')
