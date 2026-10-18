-- Phase 6 economic upper bound: ALL acquisitions are abstract/free; defenses use Engine.
-- Important acquisitions are tested separately in simulate_hub_combat.lua.
-- Not a prediction of player clear time or real player win rates.
-- Acquisitions use the same portfolio abstraction as simulate_campaign.lua; incoming attacks,
-- funding consumption, defections and lost properties are resolved through Engine itself.
unpack=unpack or table.unpack
for _,f in ipairs({"Config","Data","World","HubData","Hub","Tactics","Story","Model","LiveCatalog","Engine"}) do
    dofile("PBsTradeGame/"..f..".lua")
end
local C,D,M,E=PBTrade.Config,PBTrade.Data,PBTrade.Model,PBTrade.Engine
local requestedProfile=arg[1]
local H,K=PBTrade.Hub,PBTrade.HubData
local started=os.clock()
local firstSeed=tonumber(arg[2]) or 1
local lastSeed=tonumber(arg[3]) or 8
local maximumPeriods=tonumber(arg[4]) or 1000
local function rng(seed)
    return function() seed=(seed*48271+11)%2147483647; return seed/2147483647 end
end
local profiles={{name="empty",interval=2},{name="single",interval=2},{name="mixed",interval=2},{name="specialist",interval=2}}
local function target(s)
    local objective=D.campaigns[s.chapter].objective
    for _,id in ipairs(objective.targets or {}) do local p=s.properties[id]
        if p.owner~=C.playerId and M.IsAvailable(s,p) and s.unlocked[p.zone] then return p end
    end
    local best,bestScore
    for _,definition in ipairs(D.properties) do local p=s.properties[definition.id]
        if p.owner~=C.playerId and M.IsAvailable(s,p) and s.unlocked[p.zone]
            and M.IsPropertyVisited(s,p) and not M.IsCriticalProperty(s,p) then
            local score=p.expectedProfit+p.marketValue*.03
            if not bestScore or score>bestScore then best,bestScore=p,score end
        end
    end
    return best
end
local function acquire(s,p,random)
    p.owner=C.playerId; p.independenceRisk=math.min(p.independenceRisk,C.independence.reacquireRisk)
    s.wins=s.wins+1; M.Unlock(s); M.Takeover(s,p.id)
    local e=E.New(s,random);e.battle={mode="acquisition",learnedTactics={},log={}};e:TryLearnTactics("won")
end
-- A competent but non-perfect defense: answer material deficits, use the best available holding,
-- and stop committing after 70% of the target value.  Players can beat this by spending more or
-- using groups, alliances and tactics, but doing so carries the intended long-term cost.
local function defend(s,attack,random)
    local e=E.New(s,random); local ok=assert(e:Start(attack.propertyId,attack.companyId))
    local limit=e.battle.baseValue*.70
    while not e.battle.result do
        if e:Ready() then
            local b=e.battle; local gap=b.enemyBid-b.playerBid
            if gap>b.baseValue*.08 and s.cash>0 and b.playerBid<limit then
                local amount=math.floor(math.min(gap+b.baseValue*.03,limit-b.playerBid,s.cash))
                if amount>0 then e:Treasury(amount) end
            elseif b.playerBid<limit then
                local best,quote
                for _,p in ipairs(M.Owned(s)) do local q=e:Quote(p.id); if q>(quote or 0) then best,quote=p,q end end
                if best then e:Request(best.id) end
            end
        end
        e:Step(C.battle.step)
    end
    return e.battle.result
end
local function develop(s,profile,stats)
    if s.chapter<3 or profile.name=='empty' then return end
    M.RefreshHub(s)
    local types=H.Catalogue(s.chapter);local index=#s.hub.buildings+1
    local kind=types[(index-1)%#types+1].id
    if profile.name=='single' then kind='market' end
    if profile.name=='specialist' then
        local p=target(s);local style=p and s.companies[p.owner] and s.companies[p.owner].personality
        local ability=K.battle.styles[style] or 'influence';local best=-1
        for _,f in ipairs(types) do local score=(f.abilities[ability] or 0)/f.cost
            if score>best then kind,best=f.id,score end
        end
    end
    local size=H.Size(s.chapter)
    local cost=H.Cost(kind,M.HubCostBase(s))
    if cost>s.cash*.10 then return end -- preserve 90% of liquid funds for battle
    for y=1,size do for x=1,size do if not H.At(s.hub,x,y) then
        local ok,paid=H.Build(s.hub,{chapter=s.chapter,cash=s.cash,average=M.HubCostBase(s)},kind,x,y)
        if ok then s.cash=s.cash-paid;stats.spent=stats.spent+paid;stats.operations=stats.operations+1 end
        return
    end end end
end
local function simulate(profile,seed)
    local s=M.New(); local random=rng(seed); local reached={}; local attacks,lost=0,0
    local stats={spent=0,net=0,operations=0,}
    for period=1,maximumPeriods do
        if period%profile.interval==0 then local p=target(s); if p then
            acquire(s,p,random)
        end end
        develop(s,profile,stats)
        local attack=M.RollCounterattack(s,random)
        if attack then
            attacks=attacks+1
            if defend(s,attack,random)~="won" then lost=lost+1 end
        end
        if M.CanRebuild(s) then M.Rebuild(s) end
        M.RivalTurn(s,random); local report=M.SettleCycle(s);stats.net=stats.net+report.hub.net
        local opened=M.AdvanceCampaign(s)
        if opened then
            if opened.ending then
                reached[5]={cycle=s.cycles,assets=M.Assets(s),owned=#M.Owned(s),cash=s.cash,funding=M.FundingPower(s),attacks=attacks,lost=lost,spent=stats.spent,net=stats.net,operations=stats.operations,buildings=#s.hub.buildings,districts=#H.Effects(s.hub,s.chapter).districts}; break
            end
            reached[opened.id-1]={cycle=s.cycles,assets=M.Assets(s),owned=#M.Owned(s),cash=s.cash,funding=M.FundingPower(s),attacks=attacks,lost=lost,spent=stats.spent,net=stats.net,operations=stats.operations,buildings=#s.hub.buildings,districts=#H.Effects(s.hub,s.chapter).districts}
            M.CheckTakeovers(s); M.MolagTakeover(s,random)
        end
    end
    return reached,s,attacks,lost,stats
end
print("profile\tseed\tchapter\tcycle\tassets\towned\tattacks\tdefenseLosses\tcash\tfundingPower\thubSpent\thubNet\thubOperations\tfacilities\tdistricts\trunFinalAssets\trunFinalChapter\tcpuSeconds")
for _,profile in ipairs(profiles) do
    if not requestedProfile or requestedProfile==profile.name then
    for seed=firstSeed,lastSeed do
        started=os.clock()
        local reached,s,attacks,lost,stats=simulate(profile,seed)
        for chapter=1,5 do local row=reached[chapter]
            print(table.concat({profile.name,seed,chapter,row and row.cycle or "-",row and M.FormatMoney(row.assets) or "-",
                row and row.owned or "-",row and row.attacks or "-",row and row.lost or "-",row and M.FormatMoney(row.cash) or "-",row and M.FormatMoney(row.funding) or "-",row and row.spent or "-",row and row.net or "-",row and row.operations or "-",
                row and row.buildings or "-",row and row.districts or "-",M.Assets(s),s.chapter,os.clock()-started},"\t"))
        end
        if not s.campaignComplete then
            io.stderr:write(profile.name.." seed "..seed.." incomplete at "..s.cycles.." (chapter "..s.chapter..")\n")
        end
    end
    end
end
