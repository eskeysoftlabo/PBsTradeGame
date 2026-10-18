-- Full campaign balance probe with the production counterattack roll and realtime defense AI.
-- Acquisitions use the same portfolio abstraction as simulate_campaign.lua; incoming attacks,
-- funding consumption, defections and lost properties are resolved through Engine itself.
unpack=unpack or table.unpack
for _,f in ipairs({"Config","Data","World","HubData","Hub","Tactics","Story","Model","LiveCatalog","Engine"}) do
    dofile("PBsTradeGame/"..f..".lua")
end
local C,D,M,E=PBTrade.Config,PBTrade.Data,PBTrade.Model,PBTrade.Engine
local requestedProfile=arg[1]
local firstSeed=tonumber(arg[2]) or 1
local lastSeed=tonumber(arg[3]) or 8
local maximumPeriods=tonumber(arg[4]) or 1000
local function rng(seed)
    return function() seed=(seed*48271+11)%2147483647; return seed/2147483647 end
end
local profiles={{name="慎重",interval=3},{name="標準",interval=2},{name="積極",interval=1}}
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
local function acquire(s,p)
    p.owner=C.playerId; p.independenceRisk=math.min(p.independenceRisk,C.independence.reacquireRisk)
    s.wins=s.wins+1; M.Unlock(s); M.Takeover(s,p.id)
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
local function simulate(profile,seed)
    local s=M.New(); local random=rng(seed); local reached={}; local attacks,lost=0,0
    for period=1,maximumPeriods do
        if period%profile.interval==0 then local p=target(s); if p then acquire(s,p) end end
        local attack=M.RollCounterattack(s,random)
        if attack then
            attacks=attacks+1
            if defend(s,attack,random)~="won" then lost=lost+1 end
        end
        if M.CanRebuild(s) then M.Rebuild(s) end
        M.RivalTurn(s,random); M.SettleCycle(s)
        local opened=M.AdvanceCampaign(s)
        if opened then
            if opened.ending then
                reached[5]={cycle=s.cycles,assets=M.Assets(s),owned=#M.Owned(s),cash=s.cash,funding=M.FundingPower(s)}; break
            end
            reached[opened.id-1]={cycle=s.cycles,assets=M.Assets(s),owned=#M.Owned(s),cash=s.cash,funding=M.FundingPower(s)}
            M.CheckTakeovers(s); M.MolagTakeover(s,random)
        end
    end
    return reached,s,attacks,lost
end
print("profile\tseed\tchapter\tcycle\tassets\towned\tattacks\tdefenseLosses\tcash\tfundingPower")
for _,profile in ipairs(profiles) do
    if not requestedProfile or requestedProfile==profile.name then
    for seed=firstSeed,lastSeed do
        local reached,s,attacks,lost=simulate(profile,seed)
        for chapter=1,5 do local row=reached[chapter]
            print(table.concat({profile.name,seed,chapter,row and row.cycle or "-",row and M.FormatMoney(row.assets) or "-",
                row and row.owned or "-",attacks,lost,row and M.FormatMoney(row.cash) or "-",row and M.FormatMoney(row.funding) or "-"},"\t"))
        end
        if not s.campaignComplete then
            io.stderr:write(profile.name.." seed "..seed.." incomplete at "..s.cycles.." (chapter "..s.chapter..")\n")
        end
    end
    end
end
