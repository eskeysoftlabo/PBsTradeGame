-- Deterministic campaign balance probe.
--
-- This is deliberately a portfolio-level autoplay rather than a battle cheat sheet.  It uses
-- the production model for availability, company takeovers, rival trading, market growth,
-- settlement income, chapter progression and the chapter-five takeover.  The three profiles
-- differ only in how often they close an acquisition, which makes the report useful when
-- choosing gates that do not require one exact play style.

unpack=unpack or table.unpack
for _,f in ipairs({"Config","Data","World","HubData","Hub","Tactics","Story","Model","LiveCatalog","Engine","Coins","Audio","Controller","HubController","HubUI"}) do
    dofile("PBsTradeGame/"..f..".lua")
end

local C,D,M=PBTrade.Config,PBTrade.Data,PBTrade.Model

-- Optional command line: five <asset target in current gold> values. Campaign chapters have
-- no calendar gate; this lets balance work compare asset curves without editing production data.
if #arg==5 then
    for chapter=1,5 do
        local objective=D.campaigns[chapter].objective
        local assets=assert(tonumber(arg[chapter]))
        if objective.type=="assets" then objective.target=assets else objective.assetTarget=assets end
    end
end

local function rng(seed)
    return function()
        seed=(seed*48271)%2147483647
        return seed/2147483647
    end
end

local profiles={
    {name="慎重",interval=3},
    {name="標準",interval=2},
    {name="積極",interval=1},
}

local function target(state)
    local objective=D.campaigns[state.chapter].objective
    for _,id in ipairs(objective.targets or {}) do
        local p=state.properties[id]
        if p.owner~=C.playerId and M.IsAvailable(state,p) and state.unlocked[p.zone] then return p end
    end
    local best,bestScore
    for _,definition in ipairs(D.properties) do
        local p=state.properties[definition.id]
        if p.owner~=C.playerId and M.IsAvailable(state,p) and state.unlocked[p.zone]
            and M.IsPropertyVisited(state,p) and not M.IsCriticalProperty(state,p) then
            -- Prefer profit, with a small value bias so the bot still builds capital rather
            -- than buying only the cheapest catalogue entries.
            local score=p.expectedProfit+p.marketValue*.03
            if not bestScore or score>bestScore then best,bestScore=p,score end
        end
    end
    return best
end

local function acquire(state,p)
    p.owner=C.playerId
    p.independenceRisk=math.min(p.independenceRisk,C.independence.reacquireRisk)
    state.wins=state.wins+1
    M.Unlock(state)
    M.Takeover(state,p.id)
end

local function simulate(profile,seed)
    local state=M.New()
    local random=rng(seed)
    local reached={}
    for period=1,1400 do
        if period%profile.interval==0 then
            local p=target(state)
            if p then acquire(state,p) end
        end
        M.RivalTurn(state,random)
        M.SettleCycle(state)
        local opened=M.AdvanceCampaign(state)
        if opened then
            if opened.ending then
                reached[5]={cycle=state.cycles,assets=M.Assets(state),owned=#M.Owned(state)}
                break
            end
            reached[opened.id-1]={cycle=state.cycles,assets=M.Assets(state),owned=#M.Owned(state)}
            M.CheckTakeovers(state)
            M.MolagTakeover(state,random)
        end
    end
    return reached,state
end

print("profile\tseed\tchapter\tcycle\tassets\towned")
for _,profile in ipairs(profiles) do
    for seed=1,8 do
        local reached,state=simulate(profile,seed)
        for chapter=1,5 do
            local row=reached[chapter]
            print(table.concat({profile.name,seed,chapter,row and row.cycle or "-",
                row and M.FormatMoney(row.assets) or "-",row and row.owned or "-"},"\t"))
        end
        if not state.campaignComplete then
            io.stderr:write(profile.name.." seed "..seed.." incomplete at "..state.cycles
                .." (chapter "..state.chapter..", assets "..M.FormatMoney(M.Assets(state))..")\n")
        end
    end
end
