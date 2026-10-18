-- Reproduces docs/HUB_PHASE7_VALIDATION.md. Run from the repository root.
-- Controlled: identical negotiation, only the hub differs. Stances are removed to isolate the hub.
unpack=unpack or table.unpack
for _,f in ipairs({"Config","Data","World","HubData","Hub","Tactics","Story","Model","LiveCatalog","Engine"}) do dofile("PBsTradeGame/"..f..".lua") end
local C,D,M,E,H,K=PBTrade.Config,PBTrade.Data,PBTrade.Model,PBTrade.Engine,PBTrade.Hub,PBTrade.HubData
local function fmt(n) return string.format("%.3g",n) end
-- kind: none | basic (5 types x1) | full (all unlocked types, level 1) | max (all, level 3) | wall (5 basics L3)
local function buildHub(s,kind,chapter)
    local h=s.hub; if kind=="none" then return end
    local cat=H.Catalogue(chapter); local x,y=1,1; local cycle=100
    local function tick() cycle=cycle+1; H.Settle(h,cycle,chapter) end
    local function retry(fn) for _=1,40 do local ok,why=fn(); if ok then return true end; tick() end error("retry failed") end
    local size=H.Size(chapter)
    local function put(f)
        retry(function() return H.Build(h,{chapter=chapter,cash=1e30,average=1e8},f.id,x,y) end)
        x=x+1; if x>size then x=1; y=y+1 end
    end
    for _,f in ipairs(cat) do
        if kind=="basic" or kind=="wall" then if not f.minChapter then put(f) end else put(f); put(f) end
    end
    for _=1,6 do tick() end
    if kind=="max" or kind=="wall" then
        for _=1,2 do
            for _,b in ipairs(H.All(h)) do
                if b.level<K.maxLevel then retry(function() if b.remainingPeriods>0 then return false end return H.Change(h,{chapter=chapter,cash=1e30},"upgrade",b.id) end) end
            end
            for _=1,6 do tick() end
        end
    end
end

local STANCE={ch4={"vault","capital"},}
local function run(kind,chapter,cashRatio,seed,stanceId)
    local x=seed*7919+1; local function rnd() x=(x*48271)%2147483647; return x/2147483647 end
    local s=M.New(); s.chapter=chapter; s.cycles=100
    buildHub(s,kind,chapter)
    local e=E.New(s,rnd)
    local id
    for _,d in ipairs(D.properties) do local p=s.properties[d.id]
        if p.owner~="player" and p.owner~="neutral" and s.companies[p.owner] and M.IsAvailable(s,p) and not M.IsCriticalProperty(s,p) and not p.canonical then id=d.id; break end end
    s.unlocked[s.properties[id].zone]=true
    local orig=M.NegotiationStances; M.NegotiationStances=function() return {stanceId} end
    local ok,why=e:Start(id); M.NegotiationStances=orig; assert(ok,why)
    local b=e.battle; local V=b.effectiveValue
    s.cash=V*cashRatio
    local t=0
    while not b.result do
        if e:Ready() then
            local need=b.enemyBid+b.effectiveValue*.35-e:PlayerForce()
            if need>0 and s.cash>0 then e:Treasury(math.max(1,math.min(math.floor(s.cash),math.ceil(need/e:FundWeight("treasury"))))) end
        end
        e:Tick(1/30); t=t+1/30
    end
    return b.result=="won",t,b.playerBid/V,b.stances[1].relief
end
for _,st in ipairs({{"vault","資本力"},{"courier","物流力"},{"bloc","影響力"},{"opinion","情報力"}}) do
    print("== 第4章・通常物件・構え「"..D.stanceById[st[1]].name.."」・資金だけで押す（対応能力＝"..st[2].."）")
    for _,ratio in ipairs({1.5,3}) do
        for _,kind in ipairs({"none","basic","full","max"}) do
            local won,time,spend,n,rel=0,0,0,60,0
            for seed=1,n do local w,t,sp,r=run(kind,4,ratio,seed,st[1]); rel=r; if w then won=won+1; time=time+t end; spend=spend+sp end
            print(("  資金%.1f倍 %-5s 緩和%3.0f%%  勝率%3.0f%%  勝ち平均%5.1f秒  投入%.2f×価値"):format(ratio,kind,rel*100,won*100/n,time/math.max(1,won),spend/n))
        end
    end
end
