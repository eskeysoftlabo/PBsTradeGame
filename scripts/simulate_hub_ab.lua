-- Reproduces docs/HUB_PHASE7_VALIDATION.md. Run from the repository root.
-- A/B: same bot, with or without building the trade hub (real Controller, real Engine battles).
-- usage: luajit hubab.lua <seed> <none|hub> [maxPeriods]
unpack=unpack or table.unpack
for _,f in ipairs({"Config","Data","World","HubData","Hub","Tactics","Story","Model","LiveCatalog","Engine","Controller","HubController"}) do dofile("PBsTradeGame/"..f..".lua") end
local C,D,M,A,H,K=PBTrade.Config,PBTrade.Data,PBTrade.Model,PBTrade.Controller,PBTrade.Hub,PBTrade.HubData
PBTrade.Audio={Play=function() end,SyncMusic=function() end,StopMusic=function() end}
local seedArg=tonumber(arg[1] or 1); local mode=arg[2] or "none"; local maxPeriods=tonumber(arg[3] or 900)
local seed=seedArg*7919+13
local function random() seed=(seed*48271)%2147483647; return seed/2147483647 end
local a=A.New(random); a.modal=nil; a.tutorialComplete=true; a.introShown=true
M.SetCompanyName(a.state,"試算商会")
local s=a.state
local origSettle=M.SettleCycle
local acc={gross=0,hubNet=0,byChapter={}}
M.SettleCycle=function(state)
    local r=origSettle(state)
    acc.gross=acc.gross+r.gross; acc.hubNet=acc.hubNet+(r.hub and r.hub.net or 0)
    local c=acc.byChapter[state.chapter] or {gross=0,hub=0,n=0}; c.gross=c.gross+r.gross; c.hub=c.hub+(r.hub and r.hub.net or 0); c.n=c.n+1; acc.byChapter[state.chapter]=c
    return r
end
local st={battles=0,won=0,defenses=0,defLost=0,chapterAt={},hubSpent=0,hubNet=0,hubBuilt=0,gross=0,critN=0,critW=0}
local D_=D
local function candidates()
    local list={}
    for _,d in ipairs(D.properties) do local p=s.properties[d.id]
        if p.owner~=C.playerId and s.unlocked[p.zone] and M.IsAvailable(s,p) and M.IsPropertyVisited(s,p) then list[#list+1]=p end end
    return list
end
local function counterable(p)
    for _,sid in ipairs(M.NegotiationStances(s,p)) do local def=D.stanceById[sid]; local has=false
        for tid in pairs(def.breakers) do if s.learnedTactics[tid] then has=true end end
        if def.breakByGroup then for gid in pairs(s.learnedGroups) do local g=M.GroupStatus(s,gid); if g and g.usable then has=true end end end
        if not has then return false end end
    return true
end
local function pickTarget()
    local objective=D.campaigns[s.chapter] and D.campaigns[s.chapter].objective
    local power=M.FundingPower(s)
    if objective and objective.targets then
        for _,id in ipairs(objective.targets) do local p=s.properties[id]
            if p.owner~=C.playerId and s.unlocked[p.zone] and M.IsAvailable(s,p) and M.IsPropertyVisited(s,p) and p.marketValue<=power*2.5 then return p end end
    end
    local best,cheapest
    for _,p in ipairs(candidates()) do
        if counterable(p) then
            if not cheapest or p.marketValue<cheapest.marketValue then cheapest=p end
            if p.marketValue<=power*.6 and (not best or p.marketValue>best.marketValue) then best=p end
        end
    end
    if not best and not cheapest then for _,p in ipairs(candidates()) do if not cheapest or p.marketValue<cheapest.marketValue then cheapest=p end end end
    return best or cheapest
end
local function fight()
    local e=a.engine; local guard=0
    while a.screen=="battle" do
        if a.modal then a.modal=nil end
        local b=e.battle; local acted=false
        if e:Ready() then
            for _,stance in ipairs(e:StandingStances()) do
                local def=D.stanceById[stance.id]
                for tid in pairs(def.breakers) do
                    local t=D.tacticById[tid]
                    if not acted and s.learnedTactics[tid] and s.cash>=t.cost then local ok=e:UseTactic(tid); if ok then acted=true end end
                end
                if not acted and def.breakByGroup then
                    for gid in pairs(s.learnedGroups) do local g=M.GroupStatus(s,gid)
                        if not acted and g and g.usable then if e:RequestGroup(gid) then acted=true end end end
                end
                if not acted and def.breakByAlly then
                    for cid in pairs(s.alliances or {}) do if not acted and M.IsAllied(s,cid) and cid~=b.defender then if e:RequestAlly(cid) then acted=true end end end
                end
            end
            if not acted then
                local need=b.enemyBid+b.effectiveValue*.35-e:PlayerForce()
                if need>0 then
                    local bestId,bestQuote=nil,0
                    for _,p in ipairs(M.Owned(s)) do
                        if p.independenceRisk<50 then local q=e:Quote(p.id); if q>bestQuote then bestId,bestQuote=p.id,q end end
                    end
                    local spare=math.floor(s.cash*.7)
                    local w=e:FundWeight("treasury")
                    if bestId and bestQuote>=math.min(need,spare)*.5 then e:Request(bestId)
                    elseif spare>0 then e:Treasury(math.max(1,math.min(spare,math.ceil(need/w))))
                    elseif bestId then e:Request(bestId) end
                else
                    local risky; for _,p in ipairs(M.Owned(s)) do if p.independenceRisk>70 then risky=p end end
                    if risky and s.cash>=C.independence.stabilizeCost*4 then e:Stabilize() end
                end
            end
        end
        a:Tick(1/30); guard=guard+1; if guard>30*400 then break end
    end
    return e.battle.result
end
-- Hub policy: one build per period, spending at most 25% of cash, cheapest unlocked type first that
-- we do not yet own, then repeating; place next to an open walkway.
local function hubTurn()
    if mode~="hub" or s.chapter<K.minChapter then return end
    M.RefreshHub(s)
    local size=H.Size(s.chapter); local cat=H.Catalogue(s.chapter)
    local owned={}; for _,b in ipairs(H.All(s.hub)) do owned[b.type]=(owned[b.type] or 0)+1 end
    table.sort(cat,function(x,y) local ox,oy=owned[x.id] or 0,owned[y.id] or 0; if ox~=oy then return ox<oy end; return x.cost<y.cost end)
    local ctx={chapter=s.chapter,cash=s.cash,average=M.HubCostBase(s)}
    for _,f in ipairs(cat) do
        local cost=H.Cost(f.id,ctx.average)
        if cost*4<=s.cash then
            local spot
            for y=1,size do for x=1,size do
                if not spot and not H.At(s.hub,x,y) and H.Ground(x,y,size)~="hub_walkway" and H.RoadAccess(s.hub,x,y,s.chapter) then spot={x,y} end
            end end
            if not spot then for y=1,size do for x=1,size do if not spot and not H.At(s.hub,x,y) and H.Ground(x,y,size)~="hub_walkway" then spot={x,y} end end end end
            if spot then
                local ok,paid=H.Build(s.hub,ctx,f.id,spot[1],spot[2])
                if ok then s.cash=s.cash-paid; st.hubSpent=st.hubSpent+paid; st.hubBuilt=st.hubBuilt+1 end
            end
            return
        end
    end
end
local safety=0
local function settle()
    local before=s.cycles
    while a.screen~="rankings" do
        if a.screen=="admin" or a.screen=="admin_pick" then a:FinishAdministration()
        elseif a.screen=="strategy" then a.modal=nil; a.index=1; a:Act("confirm")
        else a.modal=nil; a:Act("confirm") end
        safety=safety+1; if safety>200000 then error("stuck at "..a.screen) end
    end
    local chapterBefore=s.chapter
    a.modal=nil; a:Act("confirm")
    if s.chapter~=chapterBefore then st.chapterAt[s.chapter]={period=s.cycles,assets=M.Assets(s),cash=s.cash,avg=M.HubCostBase(s)} end
end
while not s.campaignComplete and s.cycles<maxPeriods do
    safety=safety+1; if safety>200000 then error("loop") end
    repeat
    if a.screen=="strategy" then a.modal=nil; a.index=1; a:Act("confirm") end
    a.screen="map"; a.modal=nil
    hubTurn()
    local p=pickTarget()
    if not p then
        a:SkipPeriod()
        if a.screen=="battle" then st.defenses=st.defenses+1; a.modal=nil; fight(); a.modal=nil; a:Act("confirm") end
        settle(); break
    end
    if M.CanRebuild(s) then M.Rebuild(s) end
    a.pendingId=p.id; a.modal={action="start"}; a:Act("confirm")
    if a.screen=="battle" then
        local crit=a.engine.battle and a.engine.battle.critical
        local r=fight(); st.battles=st.battles+1
        if crit then st.critN=st.critN+1; if r=="won" then st.critW=st.critW+1 end end
        if r=="won" then st.won=st.won+1 end
        a.modal=nil; a:Act("confirm")
        if a.screen=="battle" then st.defenses=st.defenses+1; a.modal=nil; local r2=fight(); if r2~="won" then st.defLost=st.defLost+1 end; a.modal=nil; a:Act("confirm") end
    else a:ShowRankings() end
    settle()
    until true
    if s.cycles%150==0 then io.stderr:write(("%s seed %d period %d ch %d assets %.3g cash %.3g owned %d hub %d\n"):format(mode,seedArg,s.cycles,s.chapter,M.Assets(s),s.cash,#M.Owned(s),#H.All(s.hub))) end
end
local function fmt(n) local u={{1e16,"京"},{1e12,"兆"},{1e8,"億"},{1e4,"万"}} for _,x in ipairs(u) do if n>=x[1] then return string.format("%.2f%s",n/x[1],x[2]) end end return tostring(math.floor(n)) end
local line={}
for ch=2,5 do local c=st.chapterAt[ch]; line[#line+1]=c and ("第"..ch.."章 "..c.period.."期(資産"..fmt(c.assets)..")") or ("第"..ch.."章未到達") end
print(("[%s] seed %d: %s / %d期 / 最終総資産 %s / 所有%d / 交渉%d(勝%d) 重要%d(勝%d) 防衛%d(失%d)"):format(mode,seedArg,s.campaignComplete and "ED到達" or "未到達",s.cycles,fmt(M.Assets(s)),#M.Owned(s),st.battles,st.won,st.critN,st.critW,st.defenses,st.defLost))
print("   "..table.concat(line," → "))
print(("   拠点: 建設%d件 累計投資%s 現在施設%d 方針%s"):format(st.hubBuilt,fmt(st.hubSpent),#H.All(s.hub),s.hub.policy))

for ch=3,5 do local c=acc.byChapter[ch]; if c then print(("   第%d章 決算%d回 平均総収入%s / 拠点純収益%s（%.1f%%）"):format(ch,c.n,fmt(c.gross/c.n),fmt(c.hub/c.n),100*c.hub/math.max(1,c.gross))) end end
print(("   全期間 拠点純収益 %s / 総収入 %s（%.1f%%） 累計投資 %s"):format(fmt(acc.hubNet),fmt(acc.gross),100*acc.hubNet/math.max(1,acc.gross),fmt(st.hubSpent)))

for ch=3,5 do local c=st.chapterAt[ch]; if c then
  local basic=H.Cost("market",c.avg); local top=H.Cost(ch==3 and "guildhall" or (ch==4 and "exchange" or "pact"),c.avg)
  print(("   第%d章開始: 現金%s 平均物件価格%s → 市場1棟%s(現金の%.2f%%) 最上位%s(%.2f%%) / 5×5満杯(基本5種×5)=%s"):format(ch,fmt(c.cash),fmt(c.avg),fmt(basic),100*basic/c.cash,fmt(top),100*top/c.cash,fmt(basic*25))) end end
