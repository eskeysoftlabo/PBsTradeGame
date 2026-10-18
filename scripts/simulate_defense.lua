-- Repeatable defense-battle probe.  It builds representative standard-pace campaign states,
-- then lets a simple competent defender use property funding and gap-closing treasury bids.
-- This is a balance diagnostic, not an optimal solver.
unpack=unpack or table.unpack
for _,f in ipairs({"Config","Data","World","HubData","Hub","Tactics","Story","Model","LiveCatalog","Engine"}) do
    dofile("PBsTradeGame/"..f..".lua")
end
local C,D,M,E=PBTrade.Config,PBTrade.Data,PBTrade.Model,PBTrade.Engine
local function rng(seed)
    return function() seed=(seed*48271+11)%2147483647; return seed/2147483647 end
end
local function target(s)
    local objective=D.campaigns[s.chapter].objective
    for _,id in ipairs(objective.targets or {}) do local p=s.properties[id]
        if p.owner~=C.playerId and M.IsAvailable(s,p) and s.unlocked[p.zone] then return p end
    end
    local best
    for _,definition in ipairs(D.properties) do local p=s.properties[definition.id]
        if p.owner~=C.playerId and M.IsAvailable(s,p) and s.unlocked[p.zone]
            and (not best or p.marketValue>best.marketValue) then best=p end
    end
    return best
end
local snapshots={}
local s=M.New(); local worldRandom=rng(72)
for period=1,520 do
    if period%2==0 then local p=target(s); if p then p.owner=C.playerId; M.Unlock(s) end end
    M.RivalTurn(s,worldRandom); M.SettleCycle(s)
    local opened=M.AdvanceCampaign(s)
    if opened and not opened.ending then M.CheckTakeovers(s); M.MolagTakeover(s,worldRandom) end
    if not snapshots[s.chapter] then snapshots[s.chapter]=M.Export(s) end
    if s.campaignComplete then break end
end
local function defend(state,attack,random)
    local e=E.New(state,random); assert(e:Start(attack.propertyId,attack.companyId))
    local commitmentLimit=e.battle.baseValue*.70
    while e.battle and not e.battle.result do
        if e:Ready() then
            local b=e.battle; local gap=b.enemyBid-b.playerBid
            -- Spend treasury only to answer a material deficit; otherwise preserve it and call
            -- the strongest available property.  This resembles a competent, non-perfect player.
            if gap>b.baseValue*.08 and state.cash>0 and b.playerBid<commitmentLimit then
                e:Treasury(math.min(state.cash,math.max(1,math.floor(math.min(gap+b.baseValue*.03,commitmentLimit-b.playerBid)))))
            else
                local best,quote
                if b.playerBid<commitmentLimit then
                    for _,p in ipairs(M.Owned(state)) do local q=e:Quote(p.id); if q>(quote or 0) then best,quote=p,q end end
                end
                if best then e:Request(best.id) end
            end
        end
        e:Step(1/30)
    end
    return e.battle.result
end
print("chapter\twins\tlosses\tlossRate\tattackRate\tenemyCommit\tplayerFunds")
for chapter=1,5 do
    local wins,losses,attacks,enemyRatio,playerRatio=0,0,0,0,0
    for trial=1,120 do
        local state=M.Load(snapshots[chapter]); state.chapter=chapter
        local random=rng(chapter*10000+trial)
        local attack=M.RollCounterattack(state,random)
        if attack then
            attacks=attacks+1
            local probe=E.New(M.Load(M.Export(state)),random); assert(probe:Start(attack.propertyId,attack.companyId))
            enemyRatio=enemyRatio+(probe.battle.enemyBid+probe.battle.enemyBudget)/probe.battle.baseValue
            playerRatio=playerRatio+M.FundingPower(state)/probe.battle.baseValue
            if defend(state,attack,random)=="won" then wins=wins+1 else losses=losses+1 end
        end
    end
    print(table.concat({chapter,wins,losses,string.format("%.1f%%",losses/math.max(1,attacks)*100),
        string.format("%.1f%%",attacks/120*100),string.format("enemy %.2fx",enemyRatio/math.max(1,attacks)),
        string.format("player %.2fx",playerRatio/math.max(1,attacks))},"\t"))
end
