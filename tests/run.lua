unpack=unpack or table.unpack
for _,f in ipairs({"Config","Data","World","HubData","Hub","Tactics","Story","Model","LiveCatalog","Engine","Coins","Audio","Controller","HubController","HubUI"}) do dofile("PBsTradeGame/"..f..".lua") end
local C,D,M,E,A=PBTrade.Config,PBTrade.Data,PBTrade.Model,PBTrade.Engine,PBTrade.Controller
local count=0
local function test(name,fn)
    local ok,err=pcall(fn); if not ok then error(name..": "..tostring(err)) end
    count=count+1; print("PASS "..name)
end
local function eq(a,b) assert(a==b,tostring(a).." ~= "..tostring(b)) end
local function new() local s=M.New(); local e=E.New(s,function() return .5 end); return s,e end
local function advance(e,t,fps) for _=1,math.floor(t*(fps or 60)+.5) do e:Tick(1/(fps or 60)) end end
test("all 1303 properties satisfy schema and references",function()
    eq(#D.properties,1303); eq(#D.zones,53)
    local zones,ids,categories={},{},{}
    for _,z in ipairs(D.zones) do zones[z.id]=true end
    for _,p in ipairs(D.properties) do
        assert(not ids[p.id]); ids[p.id]=true; assert(zones[p.zone]); assert(D.companies[p.owner]); assert(D.categories[p.category]); categories[p.category]=true
        for _,k in ipairs({"marketValue","expectedProfit","independenceRisk","independenceIncrease","gaugeAcceleration"}) do assert(type(p[k])=="number") end
        eq(type(p.isHeadquarters),"boolean"); eq(type(p.negotiationResistances),"table")
        for _,id in ipairs(p.groups) do assert(D.groups[id]) end
    end
    local n=0; for _ in pairs(categories) do n=n+1 end; eq(n,16)
end)
test("state is independent from definitions and other sessions",function()
    local s=new(); local other=M.New(); s.properties.aur_farm.groups[1]="changed"; s.properties.aur_farm.owner="neutral"
    eq(other.properties.aur_farm.owner,"player"); eq(D.properties[1].owner,"player"); eq(other.properties.aur_farm.groups[1],"region_auridon")
    eq(D.companies.ink.name,"メナント家"); eq(s.companies.ink.name,"メナント家")
    eq(s.companies.regional_alikr.name,"砂星物産会")
    eq(s.companies.regional_wrothgar.name,"エリック社"); eq(s.companies.regional_wrothgar.aggression,.82)
    eq(s.companies.regional_auridon.name,"フルブライト商会")
    eq(s.companies.amber.name,"ドフォーレ商会"); eq(s.companies.amber.minChapter,2)
end)
test("initial balance and accessible zones",function()
    local s=new(); eq(s.cash,C.campaign.startingCash); eq(#M.Owned(s),2)
    eq(M.Assets(s),s.cash+s.properties.aur_farm.marketValue+s.properties.gra_lumber.marketValue)
    assert(s.unlocked.auridon and s.unlocked.grahtwood and s.unlocked.stormhaven); assert(not s.unlocked.rift)
    assert(not M.IsAvailable(s,s.properties.str_hq))
    for _,p in pairs(s.properties) do if p.owner=="amber" then assert((p.minChapter or s.companies.amber.minChapter)>=2,p.id) end end
    s.chapter=2; assert(M.IsAvailable(s,s.properties.str_hq))
end)
test("start rejects missing, owned and locked targets",function()
    local s,e=new(); assert(not e:Start("missing")); assert(not e:Start("aur_farm")); assert(not e:Start("rif_tavern")); eq(e.battle,nil)
end)
test("no overlapping acquisition",function()
    local s,e=new(); assert(e:Start("gra_inn")); assert(not e:Start("aur_port")); eq(e.battle.targetId,"gra_inn")
end)
test("single funding spends reserves and increases risk",function()
    local s,e=new(); e:Start("gra_inn"); local before=s.properties.aur_farm.reserve; local quote=e:Quote("aur_farm")
    assert(e:Request("aur_farm")); eq(e.battle.playerBid,quote); eq(s.properties.aur_farm.reserve,before-quote); eq(s.properties.aur_farm.independenceRisk,16); eq(s.cash,C.campaign.startingCash)
end)
test("cooldown and invalid ownership cannot create free money",function()
    local s,e=new(); e:Start("gra_inn"); assert(not e:Request("aur_port")); eq(e.battle.playerWait,0)
    e:Request("aur_farm"); local bid=e.battle.playerBid
    assert(not e:Request("gra_lumber")); assert(not e:Treasury(C.Money(1000))); eq(e.battle.playerBid,bid)
end)
test("repeat requests have diminishing returns",function()
    local s,e=new(); e:Start("gra_inn"); local first=e:Quote("aur_farm"); e:Request("aur_farm"); advance(e,3)
    assert(e:Quote("aur_farm")<first); assert(e:Request("aur_farm"))
end)
test("depleted reserve cannot pay and does not consume cooldown",function()
    local s,e=new(); e:Start("gra_inn"); s.properties.aur_farm.reserve=0
    assert(not e:Request("aur_farm")); eq(e.battle.playerWait,0); eq(s.properties.aur_farm.independenceRisk,8)
end)
test("high risk funding can trigger actual defection",function()
    local s=M.New(); local e=E.New(s,function() return 0 end); e:Start("gra_inn"); s.properties.aur_farm.independenceRisk=125
    local ok,amount,info=e:Request("aur_farm"); assert(ok and amount>0 and info.defected)
    eq(s.properties.aur_farm.independenceRisk,128); eq(s.properties.aur_farm.owner,"neutral"); eq(M.RiskLabel(128),"離反")
end)
test("a group flashes only when usable and immediately replaces the single request",function()
    -- One member cannot produce a flash even when the probability roll is guaranteed.
    local lone=M.New(); local loneEngine=E.New(lone,function() return 0 end); loneEngine:Start("gra_inn")
    local ok,_,plain=loneEngine:Request("aur_farm"); assert(ok and #plain.discoveries==0 and not plain.group)
    -- Three Auridon members satisfy this group's own minimum. Requesting one of those members
    -- discovers the group and funds every member exactly once in the same command.
    local s=M.New(); s.properties.aur_port.owner="player"; s.properties.aur_jewel.owner="player"
    local e=E.New(s,function() return 0 end); e:Start("gra_inn")
    local status=M.GroupStatus(s,"region_auridon"); assert(status.count==3 and status.minimum==3)
    local base,risks,reserves=0,{},{}
    for _,p in ipairs(status.members) do base=base+e:Quote(p.id); risks[p.id]=p.independenceRisk; reserves[p.id]=p.reserve end
    local expected=math.floor(base*status.bonus)
    local success,amount,info=e:Request("aur_farm")
    assert(success and info.group and info.group.id=="region_auridon" and #info.discoveries==1)
    eq(info.discoveries[1],"region_auridon"); eq(amount,expected); eq(e.battle.playerBid,expected)
    assert(s.learnedGroups.region_auridon)
    for _,p in ipairs(status.members) do
        assert(p.reserve<reserves[p.id] and p.independenceRisk>risks[p.id])
        eq(e.battle.requests[p.id],1)
    end
end)
test("an automatic group flash pauses for its notice then plays the group call",function()
    local a=A.New(function() return 0 end); local s=a.state
    s.properties.aur_port.owner="player"; s.properties.aur_jewel.owner="player"
    assert(a.engine:Start("gra_inn")); a.screen="battle"; a.modal=nil
    a.engine.battle.playerWait=0; assert(a:SelectBattleCommand("request","aur_farm")); a:Act("confirm")
    assert(s.learnedGroups.region_auridon and a.groupCall and a.groupCall.name==D.groups.region_auridon.name)
    assert(a.modal and a.modal.pauseBattle and a.modal.text:find("そのまま発動",1,true))
    local elapsed=a.engine.battle.elapsed; local callTime=a.groupCall.time
    a:Tick(.5); eq(a.engine.battle.elapsed,elapsed); eq(a.groupCall.time,callTime)
    a:Act("confirm"); assert(not a.modal); a:Tick(.1)
    assert(a.groupCall.time>callTime and a.engine.battle.elapsed>elapsed)
end)
test("group funding multiplies pooled money and exposes every member to risk",function()
    local s=M.New(); s.properties.aur_port.owner="player"; s.properties.aur_jewel.owner="player"
    s.learnedGroups.region_auridon=true
    local e=E.New(s,function() return 1 end); e:Start("gra_inn")
    local members=M.GroupMembers(s,"region_auridon"); local base=0; local risks={}
    for _,p in ipairs(members) do base=base+e:Quote(p.id); risks[p.id]=p.independenceRisk end
    local ok,amount=e:RequestGroup("region_auridon"); assert(ok); eq(amount,math.floor(base*D.groups.region_auridon.bonus))
    for _,p in ipairs(members) do assert(p.independenceRisk>risks[p.id]) end
end)
test("stabilization spends treasury and protects the riskiest holding",function()
    local s,e=new(); e:Start("gra_inn"); s.properties.aur_farm.independenceRisk=90; s.properties.gra_lumber.independenceRisk=50
    local ok,p=e:Stabilize(); assert(ok); eq(p.id,"aur_farm"); eq(p.independenceRisk,58); eq(s.cash,C.campaign.startingCash-C.independence.stabilizeCost)
end)
test("company personalities create different realtime bidding cadence",function()
    local a,wealth=new(); local b,aggressive=new()
    assert(wealth:Start("aur_farm","amber")); assert(aggressive:Start("aur_farm","iron"))
    wealth.battle.enemyWait=0; aggressive.battle.enemyWait=0; wealth:Step(C.battle.step); aggressive:Step(C.battle.step)
    assert(aggressive.battle.enemyWait<wealth.battle.enemyWait)
    assert(wealth.battle.aiStyle=="wealth" and aggressive.battle.aiStyle=="aggressive")
end)
test("campaign progression is data-driven, has no period gates, and gates realms until chapter five",function()
    local expectedAssets={C.Money(500000),C.Money(25000000),C.Money(1000000000),
        C.Money(50000000000),C.Money(100000000000000)}
    assert(expectedAssets[5]>0)
    for i,chapter in ipairs(D.campaigns) do
        eq(chapter.objective.minimumCycles,nil)
        eq(chapter.objective.type=="assets" and chapter.objective.target or chapter.objective.assetTarget,expectedAssets[i])
    end
    local s=M.New(); assert(not M.IsAvailable(s,s.properties.coldharbour_trade_24))
    local active=0; for id,c in pairs(s.companies) do if id~="neutral" and not c.dissolved and (c.minChapter or 1)<=1 then active=active+1 end end
    eq(#M.Rankings(s),active)
    s.cash=C.campaign.chapterOneAssets
    local chapter=M.AdvanceCampaign(s); eq(chapter.id,2); eq(s.cycles,0)
    assert(M.IsAllied(s,"regional_auridon")); eq(s.alliances.regional_auridon.trust,C.alliance.startTrust)
    s.properties.str_hq.owner="player"; s.cash=D.campaigns[2].objective.assetTarget; eq(M.AdvanceCampaign(s).id,3)
    for _,id in ipairs(D.campaigns[3].objective.targets) do s.properties[id].owner="player" end
    s.cash=D.campaigns[3].objective.assetTarget; eq(M.AdvanceCampaign(s).id,4)
    for _,id in ipairs(D.campaigns[4].objective.targets) do s.properties[id].owner="player" end
    s.cash=D.campaigns[4].objective.assetTarget; eq(M.AdvanceCampaign(s).id,5); eq(s.cycles,0)
    assert(M.IsAvailable(s,s.properties.coldharbour_trade_24)); assert(s.unlocked.coldharbour==nil)
end)
test("chapter two automatically allies with Fullbright only while the company exists",function()
    local alive=M.New(); alive.cash=C.campaign.chapterOneAssets; eq(M.AdvanceCampaign(alive).id,2)
    assert(M.IsAllied(alive,"regional_auridon") and alive.alliances.regional_auridon.automatic)
    local gone=M.New(); gone.companies.regional_auridon.dissolved=true; gone.cash=C.campaign.chapterOneAssets
    eq(M.AdvanceCampaign(gone).id,2); assert(not M.IsAllied(gone,"regional_auridon"))
    local oldState=M.New(); oldState.properties.stormhaven_trade_01.owner="player"
    local old=M.Export(oldState); old.schemaVersion=9; old.chapter=2
    local migrated=M.Load(old); assert(M.IsAllied(migrated,"regional_auridon"))
    eq(migrated.properties.stormhaven_trade_01.owner,"player")
    eq(migrated.properties.stormhaven_trade_02.owner,"regional_stormhaven")
    eq(migrated.properties.stros_trade_01.owner,"amber")
    eq(migrated.properties.highisle_trade_23.owner,"dufort")
end)
test("balanced campaign reaches one-hundred kei without long chapter stalls",function()
    local s=M.New(); local seed=42
    local function random() seed=(seed*48271)%2147483647; return seed/2147483647 end
    local function target()
        local objective=D.campaigns[s.chapter].objective
        for _,id in ipairs(objective.targets or {}) do local p=s.properties[id]
            if p.owner~="player" and M.IsAvailable(s,p) and s.unlocked[p.zone] then return p end
        end
        local best
        for _,definition in ipairs(D.properties) do local p=s.properties[definition.id]
            if p.owner~="player" and M.IsAvailable(s,p) and s.unlocked[p.zone]
                and (not best or p.marketValue>best.marketValue) then best=p end
        end
        return best
    end
    for period=1,900 do
        -- A deliberately imperfect company closes only one acquisition every two periods.
        if period%2==0 then local p=target(); if p then p.owner="player"; M.Unlock(s) end end
        M.SettleCycle(s); local chapter=M.AdvanceCampaign(s)
        if chapter and not chapter.ending then M.MolagTakeover(s,random) end
        if s.campaignComplete then break end
    end
    assert(s.campaignComplete); assert(s.cycles>=350 and s.cycles<=450,"ended at "..s.cycles)
    assert(M.Assets(s)>=D.campaigns[5].objective.assetTarget)
    eq(D.campaigns[5].objective.assetTarget,C.Money(100000000000000))
end)
test("all thirteen tactics are data-driven and uniquely indexed",function()
    eq(#D.tactics,13); local seen={}
    for _,t in ipairs(D.tactics) do
        assert(not seen[t.id]); seen[t.id]=true; eq(D.tacticById[t.id],t)
        assert(type(t.cost)=="number" and t.effect.type and t.learn and t.resistanceKey and t.description)
    end
end)
test("tactics apply cost duration resistance and target filters",function()
    local s,e=new(); e:Start("gra_inn"); local before=s.cash
    assert(e:UseTactic("smile")); eq(s.cash,before); assert(e:EffectTotal("playerAcceleration",0)>0)
    e.battle.playerWait=0; s.learnedTactics.messenger=true; assert(e:UseTactic("messenger")); assert(e:PlayerWaitDuration()<C.battle.playerWait)
    e.battle.playerWait=0; s.learnedTactics.defection=true; assert(not e:UseTactic("defection")) -- neutral target
    local immuneState,immune=new(); immuneState.unlocked.stonefalls=true; immuneState.learnedTactics.gift=true; assert(immune:Start("sto_fighters"))
    local cash=immuneState.cash; local ok,info=immune:UseTactic("gift"); assert(ok); eq(info.resistance,1); eq(immuneState.cash,cash-D.tacticById.gift.cost)
    eq(immune:EffectTotal("playerAcceleration",0),0)
end)
test("value timing delayed banquet and roots change independent systems",function()
    local s,e=new(); e:Start("gra_inn"); s.learnedTactics.freeze=true; s.learnedTactics.banquet=true; s.learnedTactics.roots=true
    assert(e:UseTactic("freeze")); e:Step(C.battle.step); assert(e.battle.effectiveValue>e.battle.baseValue)
    e.battle.playerWait=0; assert(e:UseTactic("banquet")); eq(e:EffectTotal("playerAcceleration",0),0)
    for _=1,math.ceil(4/C.battle.step)+1 do e:Step(C.battle.step) end; assert(e:EffectTotal("playerAcceleration",0)>0)
    e.battle.playerWait=0; s.properties.aur_farm.independenceRisk=90; assert(e:UseTactic("roots")); eq(s.properties.aur_farm.independenceRisk,48)
end)
test("battle outcome teaches eligible category and failure tactics",function()
    local s=M.New(); local e=E.New(s,function() return 0 end); e:Start("gra_inn"); e:Finish("lost")
    assert(s.learnedTactics.justice and s.learnedTactics.roots)
    assert(#e.battle.learnedTactics>=2)
end)
test("enemy companies use their preferred tactics in realtime",function()
    local s=M.New(); local e=E.New(s,function() return 0 end); local old=C.tactics.aiUseChance; C.tactics.aiUseChance=1
    assert(e:Start("aur_farm","amber")); e.battle.enemyWait=0; local bid=e.battle.enemyBid; e:Step(C.battle.step)
    assert(e.battle.enemyBid>bid); assert(e.battle.log[#e.battle.log]:find("心づけ")); C.tactics.aiUseChance=old
end)
test("COM group techniques require a real portfolio and consume its reserves and loyalty",function()
    local s=M.New(); s.chapter=2; M.Unlock(s); local groups=M.CompanyGroups(s,"amber"); assert(#groups>0 and groups[1].count>=groups[1].minimum)
    local e=E.New(s,function() return 1 end); assert(e:Start("aur_jewel"))
    local reserve,risk=0,0
    for _,p in ipairs(groups[1].members) do reserve=reserve+p.reserve; risk=risk+p.independenceRisk end
    local beforeBid=e.battle.enemyBid; local ok,info=e:UseEnemyGroup(s.companies.amber)
    assert(ok and info.amount>info.spent and e.battle.enemyGroupUses==1)
    local afterReserve,afterRisk=0,0
    for _,p in ipairs(groups[1].members) do afterReserve=afterReserve+p.reserve; afterRisk=afterRisk+p.independenceRisk end
    eq(reserve-afterReserve,info.spent); assert(afterRisk>risk); eq(e.battle.enemyBid,beforeBid+info.amount)
    e.battle.enemyGroupUses=0; e.battle.enemyGroupsUsed={}
    e.battle.enemyBid=e:PlayerForce()+e.battle.baseValue*(C.enemyGroups.maximumEnemyLeadShare+.01)
    assert(not e:UseEnemyGroup(s.companies.amber),"COM must not pile a group call onto a commanding lead")
    local thin=M.New(); for _,p in pairs(thin.properties) do if p.owner=="amber" then p.owner="neutral" end end
    thin.properties.aur_jewel.owner="amber"; eq(#M.CompanyGroups(thin,"amber"),0)
end)
test("treasury validates amounts and balances",function()
    local s,e=new(); e:Start("gra_inn"); assert(not e:Treasury(-C.Money(100))); assert(not e:Treasury(1/0)); assert(not e:Treasury(0/0))
    s.cash=C.Money(249); assert(not e:Treasury(C.Money(250))); eq(s.cash,C.Money(249))
    s.cash=C.Money(1000); assert(e:Treasury(C.Money(1000))); eq(s.cash,0); eq(e.battle.playerBid,C.Money(1000))
end)
test("withdrawal retains expenditure and cannot settle twice",function()
    local s,e=new(); e:Start("gra_inn"); e:Treasury(C.Money(1000)); e:Finish("withdrawn"); e:Finish("won")
    eq(s.cash,C.campaign.startingCash-C.Money(1000)); eq(s.losses,1); eq(s.wins,0); eq(s.properties.gra_inn.owner,"neutral"); assert(not e:Request("aur_farm"))
end)
test("player advantage travels LEFT and enemy advantage RIGHT",function()
    local s,e=new(); e:Start("gra_inn"); e:Treasury(C.Money(2500)); advance(e,2); assert(e.battle.gauge<0)
    local _,enemy=new(); enemy:Start("gra_inn"); advance(enemy,4); assert(enemy.battle.gauge>0)
end)
test("bounded enemy expenditure",function()
    local _,e=new(); e:Start("gra_inn"); local opening=e.battle.enemyBid; local budget=e.battle.enemyBudget
    advance(e,120); assert(e.battle.enemyBid<=opening+budget); assert(e.battle.enemyBudget>=0)
end)
test("fixed step agrees at 30, 60 and 120fps",function()
    local gauges={}
    for _,fps in ipairs({30,60,120}) do local _,e=new(); e:Start("gra_inn"); e:Treasury(C.Money(2500)); advance(e,10,fps); gauges[#gauges+1]=e.battle.gauge end
    assert(math.abs(gauges[1]-gauges[2])<1e-8); assert(math.abs(gauges[2]-gauges[3])<1e-8)
end)
test("long frame, negative and NaN deltas cannot jump the clock",function()
    local _,e=new(); e:Start("gra_inn"); e:Tick(-1); e:Tick(0/0); eq(e.battle.elapsed,0)
    e:Tick(100); assert(e.battle.elapsed<=.251)
end)
test("playable first acquisition with initial portfolio",function()
    local s,e=new(); e:Start("gra_inn")
    for _=1,9000 do
        if e:Ready() then
            if e:Quote("aur_farm")>0 then e:Request("aur_farm")
            elseif e:Quote("gra_lumber")>0 then e:Request("gra_lumber")
            elseif s.cash>=C.Money(250) then e:Treasury(C.Money(250)) end
        end
        e:Tick(1/60); if e.battle.result then break end
    end
    eq(e.battle.result,"won"); eq(s.properties.gra_inn.owner,"player"); eq(s.wins,1)
end)
test("failure never transfers title",function()
    local s,e=new(); e:Start("gra_inn"); advance(e,151); assert(e.battle.result); assert(e.battle.result~="won"); eq(s.properties.gra_inn.owner,"neutral")
end)
test("time limit resolves a stalemate",function()
    local s,e=new(); e:Start("gra_inn"); e.battle.elapsed=C.battle.duration-C.battle.step/2
    e:Tick(C.battle.step); eq(e.battle.result,"timeout"); eq(s.losses,1)
end)
test("two acquisitions unlock next trade routes",function()
    local s,e=new(); e:Start("gra_inn"); e:Finish("won"); assert(not s.unlocked.greenshade)
    e:Start("aur_port"); e:Finish("won"); assert(s.unlocked.greenshade); assert(s.unlocked.alikr)
end)
test("new battle clears transient fatigue but not spent reserves",function()
    local s,e=new(); e:Start("gra_inn"); e:Request("aur_farm"); local reserve=s.properties.aur_farm.reserve
    e:Finish("withdrawn"); e:Start("aur_port"); eq(next(e.battle.requests),nil); eq(s.properties.aur_farm.reserve,reserve)
end)
test("controller map to purchase requires confirmation",function()
    local a=A.New(); a:Act("confirm"); eq(a.screen,"properties"); a.index=2; a:Act("confirm"); eq(a.modal.action,"start"); eq(a.engine.battle,nil)
    a:Act("back"); eq(a.modal,nil); a:Act("confirm"); a:Act("confirm"); eq(a.screen,"battle")
end)
test("visited real locations are bought only through the normal map",function()
    local a=A.New(); a.modal=nil; a.tutorialComplete=true; a.state.companyName="試験商会"
    local p=a.state.properties.gra_inn
    p.canonical=true; p.requiresVisit=true; a.state.visitedProperties[p.id]=true
    a:ShowTitle()
    local rows=a:Rows(); eq(rows[1].command,"continue"); eq(#rows,3)
    for _,row in ipairs(rows) do assert(row.command~="localAcquire") end
    a:Act("confirm"); eq(a.screen,"map"); a.modal=nil
    a.screen="properties"; a.zone=p.zone; a.index=1
    rows=a:Rows(); for i,row in ipairs(rows) do if row.id==p.id then a.index=i end end
    a:Act("confirm"); eq(a.modal.action,"start"); eq(a.pendingId,p.id)
    assert(not a.modal.text:find("現在地の実在物件",1,true))
    a:Act("confirm"); eq(a.screen,"battle"); eq(a.engine.battle.targetId,p.id)
end)
test("controller information stays realtime",function()
    local a=A.New(); a.engine:Start("gra_inn"); a.screen="battle"; a:Act("info"); a:Tick(1); assert(a.engine.battle.elapsed>0)
    a:Act("back"); a:Tick(.1); assert(a.engine.battle.elapsed>0)
end)
test("tabs cannot strand an active battle",function()
    local a=A.New(); a.engine:Start("gra_inn"); a.screen="battle"; a:Tab(1); eq(a.screen,"battle")
    a:Act("back"); assert(a.closeRequested); assert(not a.engine.battle.result)
end)
test("withdraw is a two-step controller action",function()
    local a=A.New(function() return 1 end); a.engine:Start("gra_inn"); a.screen="battle"; a:Act("info"); eq(a.modal.action,"withdraw")
    a:Act("confirm"); eq(a.screen,"result"); eq(a.engine.battle.result,"withdrawn"); a:Act("confirm"); eq(a.screen,"admin"); a:FinishAdministration(); eq(a.screen,"rankings"); a:Act("confirm"); eq(a.screen,"properties")
end)
test("controller wraps focus and selects all owned pages",function()
    local a=A.New(); a:Move(-1); eq(a.index,43); a:Move(1); eq(a.index,1)
    for _,p in pairs(a.state.properties) do p.owner="player" end
    a:Tab(1); for _=1,20 do a:Move(1) end; eq(a.index,21); assert(a:Selected().property)
end)
test("coin frames reuse their records instead of allocating per UI tick",function()
    local v=PBTrade.Coins.New(4000); v:SetBid(1,1000000); v:SetBid(2,60000)
    for _=1,30 do v:Tick(1/30); v:Frame(1); v:Frame(2) end
    local first=v:Frame(1); assert(#first.coins>100)
    collectgarbage("collect"); collectgarbage("stop"); local before=collectgarbage("count")
    for _=1,300 do v:Tick(1/30); assert(v:Frame(1)==first); v:Frame(2) end
    local grown=collectgarbage("count")-before; collectgarbage("restart")
    -- The previous per-coin tables allocated roughly 90KB per Frame call here.
    assert(grown<300,"coin frames allocated "..grown.."KB over 300 ticks")
end)
test("coins fall, land, and keep both stack tips in view",function()
    local v=PBTrade.Coins.New(4000); v:SetBid(1,25000); v:SetBid(2,250)
    v:Tick(.03); local frame=v:Frame(1); assert(#frame.coins>0); assert(frame.coins[1].falling)
    local y=frame.coins[1].y; v:Tick(.1); assert(v:Frame(1).coins[1].y>y)
    for _=1,240 do v:Tick(1/60) end
    frame=v:Frame(1); assert(frame.floorY>C.coins.viewportHeight); assert(frame.tipY>=C.coins.tipY-8)
    assert(frame.tipY<C.coins.viewportHeight); eq(v:Frame(2).camera,0)
end)
test("unbounded logical gold uses a bounded visible pool",function()
    local v=PBTrade.Coins.New(4000); v:SetBid(1,1000000000)
    for _=1,600 do
        v:Tick(1/60); local frame=v:Frame(1)
        assert(#frame.coins<=C.coins.limit); assert(#v.sides[1].falling<=C.coins.maxFalling)
    end
    assert(v.sides[1].landed>C.coins.limit*1000); eq(v.sides[1].landed,v.sides[1].target)
    assert(v:Frame(1).tipY>=C.coins.tipY-8)
end)
test("coin refresh cannot restart animations or enqueue duplicates",function()
    local v=PBTrade.Coins.New(4000); v:SetBid(1,500); v:Tick(.1)
    local target=v.sides[1].target; local emitted=v.sides[1].emitted; local first=v.sides[1].falling[1]
    v:SetBid(1,500); eq(v.sides[1].target,target); eq(v.sides[1].emitted,emitted); eq(v.sides[1].falling[1],first)
end)
test("coin pillars form three staggered depth ranks with rear-first occlusion",function()
    local v=PBTrade.Coins.New(4000); v:SetBid(1,8000)
    for _=1,420 do v:Tick(1/60) end
    local frame=v:Frame(1); local pillars={}; local depth=1
    for _,coin in ipairs(frame.coins) do
        assert(coin.depth>=depth); depth=coin.depth
        pillars[coin.pillar]=coin
    end
    local n=0; for _ in pairs(pillars) do n=n+1 end
    eq(n,16); eq(depth,3)
    assert(pillars[1].y<pillars[6].y and pillars[6].y<pillars[12].y)
    assert(pillars[1].scale<pillars[12].scale and pillars[1].shade<pillars[12].shade)
    assert(pillars[1].x~=pillars[6].x)
end)
test("a tiny payment settles once at the centre of the stone plinth",function()
    -- A high-value negotiation can make a small payment less than one visual unit.
    local v=PBTrade.Coins.New(1000000); v:SetBid(1,250)
    for _=1,240 do v:Tick(1/60) end
    local side=v.sides[1]; local frame=v:Frame(1)
    assert(side.target<1); eq(#side.resting,1); eq(#frame.coins,1)
    eq(frame.coins[1].pillar,1)
    -- First pillar is the horizontal centre of the five-column rear rank, not its edge.
    eq(frame.coins[1].x,C.coins.ranks[1].x+2*C.coins.pillarSpacing)
    local plinthLeft=(C.coins.pileWidth-C.coins.plinthWidth)/2
    assert(frame.coins[1].x>=plinthLeft and frame.coins[1].x+C.coins.width<=plinthLeft+C.coins.plinthWidth)
end)
test("depth sorting includes airborne coins without exceeding the viewport pool",function()
    local v=PBTrade.Coins.New(4000); v:SetBid(1,1000000000)
    for _=1,420 do
        v:Tick(1/60); local frame=v:Frame(1); local depth=1
        for _,coin in ipairs(frame.coins) do assert(coin.depth>=depth); depth=coin.depth end
        assert(#frame.coins<=C.coins.limit)
        assert(frame.tipY>=C.coins.tipY)
    end
end)
test("each payment lands exactly at its amount-scaled deadline at 30 60 and 120fps",function()
    local V=PBTrade.Coins
    -- Small payments are short, large ones long, capped at the configured maximum.
    local tiny,small,large,huge=V.DurationFor(1),V.DurationFor(10),V.DurationFor(100),V.DurationFor(1e9)
    assert(tiny<small and small<large and large<=huge)
    assert(tiny<1.6 and huge==C.coins.duration and tiny>=C.coins.minDuration)
    for _,fps in ipairs({30,60,120}) do
        for _,amount in ipairs({1,250,25000,1000000000}) do
            local v=V.New(4000); v:SetBid(1,amount)
            local deadline=v.sides[1].batches[1].ends
            eq(v.sides[1].batches[1].events[1].starts,0)
            while v.time+1/fps<deadline-1e-6 do v:Tick(1/fps) end
            assert(#v.sides[1].batches==1); assert(v.sides[1].landed<v.sides[1].target)
            while v.time<deadline-1e-9 do v:Tick(1/fps) end
            eq(#v.sides[1].batches,0); eq(#v.sides[1].falling,0)
            eq(v.sides[1].landed,v.sides[1].target)
            -- The drawn stack then settles on the (compressed) size of the landed total.
            for _=1,10*fps do v:Tick(1/fps) end
            assert(math.abs(v.sides[1].displayed-V.VisualCount(v.sides[1].target))<1e-6)
        end
    end
end)
test("a colossal payment lets the plinth leave while its tall stack remains visible",function()
    local V=PBTrade.Coins
    for _,bid in ipairs({20000,400000,1e9,1e15}) do
        local v=V.New(4000); v:SetBid(1,bid); local first=v:Frame(1); local last=first.floorY; local lastPlate=first.plinthY; local maxStep=0; local final=first
        for _=1,30*12 do
            v:Tick(1/30); local f=v:Frame(1); final=f
            maxStep=math.max(maxStep,f.floorY-last); last=f.floorY
            assert(f.floorY>=C.coins.floorY-1e-6)
            assert(f.plinthY<=f.floorY and f.floorY-f.plinthY<=C.coins.plinthMaxLag+1e-6)
            assert(f.plinthY>=lastPlate-1e-6); lastPlate=f.plinthY
            if f.camera>0 then assert(f.tipY>=0 and f.tipY<=C.coins.viewportHeight,"tip left the view: "..f.tipY) end
        end
        assert(maxStep<=C.coins.scrollMaxSpeed/30+C.coins.stackStep+1e-6,"plate jumped "..maxStep.."px for "..bid)
        if last>C.coins.viewportHeight then
            assert(final.plinthY+C.coins.plinthOffsetY>=C.coins.viewportHeight,
                "colossal pile should push its plinth fully out of view for "..bid)
            assert(#final.coins>=C.coins.columns*3,"too few coins remain visible for "..bid)
        end
    end
    -- Linear until the view is full, then logarithmic.
    eq(V.VisualCount(100),100); assert(V.VisualCount(1e9)<V.VisualCount(1e9)*1.0001 and V.VisualCount(1e9)<20000)
    assert(V.VisualCount(1e6)>V.VisualCount(1e4))
end)
test("payments open with an amount-scaled volley and thin out toward the deadline",function()
    local small=PBTrade.Coins.New(4000); small:SetBid(1,250)
    local big=PBTrade.Coins.New(4000); big:SetBid(1,250000)
    local function early(v)
        local batch=v.sides[1].batches[1]; local events=batch.events; local n=0
        local window=C.coins.volleyWindow*math.min(1,batch.duration/3)
        for _,e in ipairs(events) do if e.arrives<=events[1].arrives+window+1e-9 then n=n+1 end end
        return n/#events,events
    end
    local smallShare=early(small); local bigShare,events=early(big)
    assert(bigShare>smallShare and bigShare>=.65 and smallShare<.45)
    -- Faster first strike for large payments.
    assert(events[1].duration<small.sides[1].batches[1].events[1].duration)
    -- The tail gaps keep widening, so the last seconds are sparse.
    local n=#events
    assert(events[n].arrives-events[n-1].arrives>events[n-5].arrives-events[n-6].arrives)
    assert(events[n].arrives-events[n-1].arrives>.1)
    local lastSecond=0; for _,e in ipairs(events) do if e.arrives>C.coins.duration-1 then lastSecond=lastSecond+1 end end
    assert(small.sides[1].batches[1].ends<big.sides[1].batches[1].ends)
    assert(lastSecond<n*.15)
    eq(events[n].arrives,C.coins.duration)
    for _,e in ipairs(events) do assert(e.starts>=-1e-9 and e.duration>0) end
end)
test("overlapping payments each retain their own window",function()
    local v=PBTrade.Coins.New(4000); v:SetBid(1,1000)
    local first=v.sides[1].batches[1].ends
    for _=1,60 do v:Tick(1/60) end
    v:SetBid(1,2000); eq(#v.sides[1].batches,2)
    local second=v.sides[1].batches[2].ends; assert(second>first)
    while v.time<first+.01 do v:Tick(1/60) end
    eq(#v.sides[1].batches,1); assert(v.sides[1].landed<v.sides[1].target)
    while v.time<second+.01 do v:Tick(1/60) end
    eq(#v.sides[1].batches,0); eq(v.sides[1].landed,v.sides[1].target)
end)
test("every visible coin contact plays its impact sound and optional mute works",function()
    local v=PBTrade.Coins.New(4000); v:SetBid(1,250000); v:SetBid(2,250000)
    local calls={}; SOUNDS={ITEM_MONEY_CHANGED="Money_Transact"}
    PlaySound=function(sound) eq(sound,"Money_Transact"); calls[#calls+1]=v.time end
    local contacts=0
    for _=1,480 do local impacts=v:Tick(1/60); contacts=contacts+impacts; PBTrade.Audio.Impact(v,impacts) end
    eq(#calls,contacts); assert(#calls>5); assert(calls[1]>=C.coins.fastFlight)
    assert(calls[#calls]<=C.coins.duration+.00001)
    C.coins.soundEnabled=false; assert(not PBTrade.Audio.Impact(v,5)); C.coins.soundEnabled=true
    SOUNDS={}; assert(not PBTrade.Audio.Impact(v,5)); SOUNDS=nil; PlaySound=nil
end)
test("tactic banner stages move reaction verdict while the negotiation keeps running",function()
    local a=A.New(nil,nil); a.engine:Start("gra_inn"); a.screen="battle"; a.modal=nil
    a.engine.battle.playerWait=0; a.state.learnedTactics.smile=true
    local sounds={}; local play=PBTrade.Audio.Play; PBTrade.Audio.Play=function(kind) sounds[#sounds+1]=kind end
    a:SelectBattleCommand("tactic","smile")
    a:Act("confirm"); local scene=assert(a.tacticScene); eq(sounds[1],"tactic")
    assert(scene.act:find("笑み")); assert(scene.detail:find("押し込み")); assert(not scene.detail:find("\n"))
    eq((a:TacticStage()),"intro")
    local elapsed=a.engine.battle.elapsed
    a:Tick(C.tacticScene.intro+.01); eq((a:TacticStage()),"react"); assert(a.engine.battle.elapsed>elapsed)
    -- Input keeps driving the trade: moving the cursor works during the banner.
    local index=a.index; a:Act("previous"); a:Move(1); assert(a.index~=index or #a:Rows()==1); assert(a.tacticScene)
    a:Tick(C.tacticScene.react); eq((a:TacticStage()),"result"); eq(#sounds,2)
    assert(sounds[2]=="tacticSuccess" or sounds[2]=="tacticFail")
    a:Tick(.1); eq(#sounds,2)
    a:Tick(C.tacticScene.result); eq(a.tacticScene,nil)
    PBTrade.Audio.Play=play
end)
test("tactic verdicts cover void, backfire and every tactic has a script",function()
    for _,t in ipairs(D.tactics) do assert(t.scene and t.scene.act and t.scene.success and t.scene.resist,t.id) end
    local a=A.New(); a.engine:Start("gra_inn")
    local target=a.state.properties.gra_inn
    a:StartTacticScene({tactic=D.tacticById.gift,power=0,resistance=1,amount=0,target=target}); eq(a.tacticScene.kind,"void")
    eq(a.tacticScene.reaction,D.tacticById.gift.scene.resist)
    a:StartTacticScene({tactic=D.tacticById.justice,power=1,resistance=0,amount=4.5,direction=1,target=target}); eq(a.tacticScene.kind,"backfire")
    assert(a.tacticScene.detail:find("相手側へ"))
    a:StartTacticScene({tactic=D.tacticById.defection,power=.6,resistance=.4,amount=16.8,targetDefected=true,target=target}); eq(a.tacticScene.kind,"great")
    assert(a.tacticScene.detail:find("離反"))
    a:StartTacticScene({tactic=D.tacticById.rumor,power=.55,resistance=.45,amount=.5,target=target}); eq(a.tacticScene.kind,"good")
end)
test("the border creeps near the centre and races near the edges",function()
    local function moved(gauge)
        local s=M.New(); local e=E.New(s,function() return .5 end); e:Start("gra_inn")
        local b=e.battle; b.gauge=gauge; b.velocity=-2; b.enemyWait=999
        e:Step(1/60); return math.abs(b.gauge-gauge)
    end
    local centre,middle,edge=moved(0),moved(-50),moved(-95)
    assert(centre<middle and middle<edge)
    assert(math.abs(centre-2*C.battle.centerSpeed*C.battle.paceScale/60)<.002)
    assert(edge>2.5*centre)
end)
test("holding a lead of 30% of the value decides the negotiation in about 30 seconds",function()
    local s=M.New(); local e=E.New(s,function() return .5 end); e:Start("gra_inn")
    local b=e.battle; b.enemyBudget=0; b.playerBid=b.enemyBid+b.baseValue*.3
    -- The opponent keeps "moving" here, so idle pressure stays out of the benchmark.
    local t=0; while not b.result do b.lastEnemyAction=b.elapsed; e:Tick(1/30); t=t+1/30 end
    eq(b.result,"won"); assert(t>25 and t<35,"decided in "..t.."s")
end)
test("an idle side under attack is pushed harder until the negotiation ends",function()
    local function decide(enemyActive)
        local s=M.New(); local e=E.New(s,function() return .5 end); e:Start("gra_inn")
        local b=e.battle; b.enemyBudget=0; b.playerBid=b.enemyBid+b.baseValue*.3
        local t=0; while not b.result do if enemyActive then b.lastEnemyAction=b.elapsed end; e:Tick(1/30); t=t+1/30 end
        return t,b
    end
    local active=decide(true); local idle,b=decide(false)
    eq(b.result,"won"); assert(idle<active*.6,"idle "..idle.." vs active "..active)
    local logged=false; for _,line in ipairs(b.log) do if line:find("相手の手が止まった") then logged=true end end
    assert(logged)
    local favourable=false; for _,event in ipairs(b.events) do
        if event.lane=="enemy" and event.text:find("手が止まった",1,true) then favourable=event.sentiment=="positive" end
    end
    assert(favourable,"opponent idle must be favourable to the player")
    -- No boost inside the grace period, and none while the pressed side keeps acting.
    local s=M.New(); local e=E.New(s,function() return .5 end); e:Start("gra_inn")
    local battle=e.battle; battle.velocity=-1; battle.elapsed=C.battle.idleGrace-.1; battle.lastEnemyAction=0
    eq(e:IdlePressure(),0)
    battle.elapsed=C.battle.idleGrace+C.battle.idleRamp+1; assert(math.abs(e:IdlePressure()+C.battle.idleAcceleration)<1e-9)
    battle.lastEnemyAction=battle.elapsed; eq(e:IdlePressure(),0)
    -- The player idling while being pushed gets the same treatment in the other direction.
    battle.velocity=1; battle.lastPlayerAction=0; assert(e:IdlePressure()>0)
    local adverse=false; for _,event in ipairs(battle.events) do
        if event.text:find("押し込まれている",1,true) then adverse=event.sentiment=="negative" end
    end
    assert(adverse,"player idle must be adverse to the player")
    battle.playerWait=0; s.cash=C.Money(1000); assert(e:Treasury(C.Money(500))); eq(e:IdlePressure(),0)
end)
test("battle commands split into request group tactic and treasury categories",function()
    local a=A.New(); a.engine:Start("gra_inn"); a.screen="battle"; a.modal=nil; a.battleCategory=1
    local function commands() local set={}; for _,r in ipairs(a:Rows()) do set[r.command]=true end; return set end
    assert(commands().request and not commands().treasury)
    a:Move(1); local requestIndex=a.index
    a:Tab(1); eq(a.battleCategory,2); eq(a.screen,"battle")
    local group=a:Rows(); eq(#group,1); eq(group[1].enabled,false)
    a:MovePage(1); eq(a.battleCategory,3); assert(commands().tactic and commands().stabilize and not commands().withdraw)
    a:Tab(1); eq(a.battleCategory,4); assert(a:Selected().base)
    a:Tab(1); eq(a.battleCategory,1); eq(a.index,requestIndex)
end)
test("groups stay hidden until discovered, in the ledger, battle and property detail",function()
    local a=A.New(); a.tab=3; a.screen="groups"; a.modal=nil
    local rows=a:Rows(); eq(#rows,1); eq(rows[1].group,nil); assert(not rows[1].label:find("交易連合"))
    a:Act("confirm"); eq(a.modal,nil)
    local p=a.state.properties.aur_farm; assert(#p.groups>0)
    assert(a:Detail(p):find("系列：不明",1,true))
    for _,id in ipairs(p.groups) do assert(not a:Detail(p):find(D.groups[id].name,1,true)) end
    a.state.learnedGroups[p.groups[1]]=true
    rows=a:Rows(); eq(#rows,1); eq(rows[1].id,p.groups[1])
    assert(a:Detail(p):find(D.groups[p.groups[1]].name,1,true))
    a.engine:Start("gra_inn"); a.screen="battle"; a.battleCategory=2
    rows=a:Rows(); eq(#rows,1); eq(rows[1].id,p.groups[1])
end)
test("withdraw is a one-button special action during negotiations",function()
    local a=A.New(); a.engine:Start("gra_inn"); a.screen="battle"; a.modal=nil
    a:Act("info"); eq(a.modal.action,"withdraw")
    a:Act("info"); eq(a.modal,nil); eq(a.engine.battle.result,nil)
    a:Act("info"); a:Act("confirm"); eq(a.engine.battle.result,"withdrawn"); eq(a.screen,"result")
    -- Outside negotiations □ is still the guide.
    local b=A.New(); b.modal=nil; b:Act("info"); assert(b.modal.text:find("手引き"))
end)
test("treasury amounts centre on the bid gap with round steps either side",function()
    local a=A.New(); a.engine:Start("gra_inn"); a.screen="battle"; a.modal=nil
    local b=a.engine.battle; b.enemyBid=C.Money(3270); b.playerBid=0; a.state.cash=C.Money(100000)
    local options,gap=a:TreasuryOptions(); eq(gap,C.Money(3270))
    local amounts={}; for _,o in ipairs(options) do amounts[#amounts+1]=o.amount end
    eq(table.concat(amounts,","),table.concat({C.Money(2000),C.Money(2500),C.Money(3300),C.Money(5000),C.Money(10000)},","))
    assert(options[3].base and options[3].tag=="差額を埋める")
    b.enemyBid=C.Money(128400); options=a:TreasuryOptions(); amounts={}
    for _,o in ipairs(options) do amounts[#amounts+1]=o.amount end
    eq(table.concat(amounts,","),table.concat({C.Money(50000),C.Money(100000),C.Money(130000),C.Money(200000),C.Money(250000)},","))
    -- Leading: base extends the lead by a share of the value.
    b.enemyBid=0; b.playerBid=C.Money(5000); options,gap=a:TreasuryOptions(); assert(gap<0)
    local base; for _,o in ipairs(options) do if o.base then base=o end end
    eq(base.tag,"リードを広げる"); assert(base.amount>=C.battle.treasuryMinimum)
    -- Short on cash: whole balance offered first; unaffordable steps are refused.
    b.enemyBid=C.Money(3270); b.playerBid=0; a.state.cash=C.Money(1500); b.playerWait=0
    options=a:TreasuryOptions(); eq(options[1].amount,C.Money(1500)); eq(options[1].tag,"手元の全額")
    a.battleCategory=4; local rows=a:Rows(); eq(rows[#rows].enabled,false)
    a.index=#rows; a:Act("confirm"); eq(a.state.cash,C.Money(1500))
    a.index=1; a:Act("confirm"); eq(a.state.cash,0); eq(b.playerBid,C.Money(1500))
    local e=a.engine; b.playerWait=0; a.state.cash=C.Money(10); assert(not e:Treasury(1.5)); assert(not e:Treasury(0))
end)
test("entering chapter 5 hands 70 percent of the other properties to Molag Bal once",function()
    local s=M.New(); eq(M.MolagTakeover(s,function() return .5 end),nil)
    local before,beforePlayer=0,#M.Owned(s)
    for _,p in pairs(s.properties) do if p.owner~="molag" then before=before+1 end end
    s.chapter=5; math.randomseed(7)
    local r=assert(M.MolagTakeover(s,math.random))
    eq(r.candidates,before); eq(r.count,math.floor(before*.7+.5))
    eq(r.fromPlayer+r.fromRivals+r.fromNeutral,r.count)
    assert(r.fortification and #r.fortification.headquarters==4)
    local finalObjective=D.campaigns[5].objective
    local fortressTotal=0
    for i,id in ipairs(D.companyHeadquarters.molag) do
        local expected=math.min(C.economy.maximumPropertyValue,
            math.floor(finalObjective.assetTarget*C.campaign.molagHeadquartersAssetShares[i]+.5))
        eq(s.properties[id].marketValue,expected); fortressTotal=fortressTotal+expected
        assert(s.properties[id].expectedProfit>=math.floor(expected*C.campaign.molagHeadquartersProfitYield+.5))
    end
    eq(r.fortification.totalValue,fortressTotal)
    assert(s.companies.molag.cash>=math.floor(fortressTotal*C.campaign.molagTreasuryShare+.5))
    eq(M.FortifyMolagHeadquarters(s),nil)
    local remaining=0; for _,p in pairs(s.properties) do if p.owner~="molag" then remaining=remaining+1 end end
    eq(remaining,before-r.count); eq(#M.Owned(s),beforePlayer-r.fromPlayer)
    eq(M.MolagTakeover(s,math.random),nil)
    -- Persisted: a reload neither re-runs it nor loses the new owners.
    local loaded=M.Load(M.Export(s)); eq(loaded.molagTakeover,true); eq(loaded.molagFortified,true)
    for id,p in pairs(s.properties) do eq(loaded.properties[id].owner,p.owner) end
    -- A save already in chapter 5 from an older version receives it when the controller loads.
    local old=M.Export(M.New()); old.chapter=5; old.molagTakeover=nil
    local a=A.New(function() return .3 end,{state=old,tutorialComplete=true})
    assert(a.state.molagTakeover and a.molagReport and a.molagReport.count>0)
    a:ShowChapterIntro(); assert(a.modal.text:find("鎖の侵食",1,true)); eq(a.fx.kind,"defection"); eq(a.molagReport,nil)
    -- A chapter-5 save that already suffered the takeover receives only the new fortification.
    local legacy=M.Export(M.New()); legacy.chapter=5; legacy.molagTakeover=true
    legacy.molagFortified=true; legacy.molagFortificationVersion=nil
    legacy.companies.molag.dissolved=true
    for _,id in ipairs({"coldharbour_trade_24","deadlands_trade_24","fargrave_trade_24"}) do legacy.properties[id].owner="player" end
    local migrated=A.New(function() return .3 end,{state=legacy,tutorialComplete=true})
    assert(migrated.molagReport and migrated.molagReport.count==0 and migrated.molagReport.fortification)
    assert(not migrated.state.companies.molag.dissolved and M.IsAvailable(migrated.state,migrated.state.properties.molag_bal_citadel))
    migrated:ShowChapterIntro(); assert(migrated.modal.text:find("経済要塞化",1,true))
end)
test("Molag Bal's citadel is the locked final acquisition after the three outer headquarters",function()
    local s=M.New(); s.chapter=5; s.unlocked.coldharbour=true; s.unlocked.deadlands=true; s.unlocked.fargrave=true
    local citadel=s.properties.molag_bal_citadel
    assert(citadel and citadel.name=="モラグ・バルの居城" and citadel.finalStronghold)
    assert(not M.IsAvailable(s,citadel))
    local e=E.New(s,function() return .5 end)
    local ok,why=e:Start(citadel.id); assert(not ok and why)
    local outer={"coldharbour_trade_24","deadlands_trade_24","fargrave_trade_24"}
    for i=1,2 do local id=outer[i]; s.properties[id].owner="player"; assert(M.Takeover(s,id)==nil); assert(not M.IsAvailable(s,citadel)) end
    assert(e:Start(outer[3])); e:Finish("won")
    assert(e.battle.finalStrongholdUnlocked==citadel and e.battle.takeover==nil and not s.companies.molag.dissolved)
    assert(M.IsAvailable(s,citadel))
    assert(e:Start(citadel.id)); e:Finish("won")
    assert(e.battle.takeover and e.battle.takeover.company=="molag")
    assert(s.companies.molag.dissolved and citadel.owner=="player")
end)
test("each acquisition-defense-settlement cycle counts up the period shown with rankings",function()
    local a=A.New(function() return .99 end); a.modal=nil
    eq(M.CurrentPeriod(a.state),1)
    for period=1,3 do
        a.engine.battle=nil; assert(a.engine:Start("gra_inn")); a.screen="battle"; a.modal=nil
        a.engine:Finish("lost"); a.screen="result"
        a:Act("confirm"); while a.screen~="rankings" do
            if a.screen=="battle" then a.engine:Finish("won"); a.screen="result" end
            if a.screen=="admin" then a:FinishAdministration() else a.modal=nil; a:Act("confirm") end
        end
        eq(a.rankingPeriod,period); eq(a.fx.text,"第"..period.."期  資金力ランキング")
        a:Act("confirm"); eq(a.state.cycles,period); eq(M.CurrentPeriod(a.state),period+1)
        assert(a.modal.text:find("第"..period.."期 決算",1,true))
        a.modal=nil
    end
    local loaded=M.Load(M.Export(a.state)); eq(M.CurrentPeriod(loaded),4)
end)
test("company name is chosen once, saved, and used for the player's company",function()
    local a=A.New(); eq(a.state.companyName,nil)
    a:ShowTitle(); eq(a:Rows()[1].command,"found"); assert(a:TitleStatus():find("まだ"))
    a:Act("confirm"); eq(a.screen,"opening"); a:Act("back"); eq(a.screen,"naming")
    a:Act("back"); eq(a.screen,"title")
    a:Act("confirm"); a:Act("back"); a.index=3; a:Act("confirm"); eq(a.pendingName,C.campaign.companyNameCandidates[2])
    a:Act("confirm"); eq(a.state.companyName,C.campaign.companyNameCandidates[2]); eq(a.screen,"map")
    eq(M.CompanyName(a.state),a.state.companyName)
    local found=false; for _,r in ipairs(M.Rankings(a.state)) do if r.id=="player" then found=r.name==a.state.companyName end end
    assert(found)
    -- Persisted, re-applied on load, and the title now offers continue / rename.
    local loaded=A.New(nil,{state=M.Export(a.state),tutorialComplete=true})
    eq(loaded.state.companyName,a.state.companyName); eq(loaded.state.companies.player.name,a.state.companyName)
    loaded:ShowTitle(); eq(#loaded:Rows(),3); eq(loaded:Rows()[1].command,"continue"); eq(loaded:Rows()[3].command,"opening")
    assert(loaded:TitleStatus():find("第1期",1,true))
    loaded.index=2; loaded:Act("confirm"); eq(loaded.pendingName,a.state.companyName)
    loaded:SubmitTypedName("  ") ; eq(loaded.pendingName,a.state.companyName)
    loaded:SubmitTypedName("新・琥珀商会"); eq(loaded.screen,"title"); eq(loaded.state.companyName,"新・琥珀商会")
    loaded.index=1; loaded:Act("confirm"); eq(loaded.screen,"map")
    eq(M.NormalizeCompanyName("\t a\nb "),"a b"); eq(M.NormalizeCompanyName("　"),nil)
end)
test("a bankrupt company can always borrow enough to win back a foothold",function()
    local s=M.New()
    for _=1,300 do M.SettleCycle(s) end -- prices compound for 300 periods
    for _,p in ipairs(M.Owned(s)) do p.owner="neutral" end
    s.cash=0; eq(#M.Owned(s),0)
    local need,grant,cheapest=M.RebuildTerms(s)
    assert(cheapest and cheapest.marketValue>C.economy.rebuildGrant*2,"prices should have outgrown the flat loan")
    assert(M.CanRebuild(s) and grant>=cheapest.marketValue and need>C.economy.rebuildThreshold)
    local ok,amount=M.Rebuild(s); assert(ok and amount==grant and s.cash==grant and s.debt==grant)
    assert(not M.CanRebuild(s))
    -- The loan alone wins the cheapest negotiation by topping up from the treasury.
    local e=E.New(s,function() return .5 end); assert(e:Start(cheapest.id))
    local b=e.battle; local t=0
    while not b.result and t<150 do
        if e:Ready() then
            local need=b.enemyBid+b.effectiveValue*.35-b.playerBid
            if need>0 and s.cash>0 then e:Treasury(math.max(1,math.min(s.cash,math.ceil(need)))) end
        end
        e:Tick(1/30); t=t+1/30
    end
    eq(b.result,"won")
end)
test("rivals buy neutral and rival properties each settlement but leave campaign targets alone",function()
    local s=M.New(); s.chapter=5; M.Unlock(s)
    local seed=11; local function random() seed=(seed*48271)%2147483647; return seed/2147483647 end
    local before={}; for id,p in pairs(s.properties) do before[id]=p.owner end
    local cashBefore={}; for id,c in pairs(s.companies) do cashBefore[id]=c.cash end
    local deals=0
    for _=1,40 do deals=deals+#M.RivalTurn(s,random) end
    assert(deals>10,"rivals made "..deals.." deals")
    for id,p in pairs(s.properties) do
        if before[id]=="player" then eq(p.owner,"player") end
        if p.isHeadquarters then eq(p.owner,before[id]) end
    end
    for _,chapter in ipairs(D.campaigns) do for _,id in ipairs(chapter.objective.targets or {}) do eq(s.properties[id].owner,before[id]) end end
    local spent=false; for id,c in pairs(s.companies) do if id~="player" and id~="neutral" and c.cash<cashBefore[id] then spent=true end end
    assert(spent); eq(s.companies.player.cash,cashBefore.player)
    -- Chapter gating: companies not yet introduced do not trade.
    local early=M.New(); local owners={}; for id,p in pairs(early.properties) do owners[id]=p.owner end
    for _=1,40 do for _,d in ipairs(M.RivalTurn(early,random)) do assert((early.companies[d.buyer].minChapter or 1)<=1) end end
end)
test("withdraw confirmation cannot stop the realtime battle",function()
    local a=A.New(); a.engine:Start("gra_inn"); a.screen="battle"; a:Act("info")
    a.engine.battle.enemyWait=.01; local before=a.engine.battle.enemyBid
    a:Tick(.1); assert(a.engine.battle.enemyBid>before)
    a.engine.battle.elapsed=C.battle.duration; a:Tick(.1); eq(a.screen,"result"); eq(a.modal,nil)
end)
test("all zones have 24 or more uniquely named real properties",function()
    local names={}; local seen={}
    for _,z in ipairs(D.zones) do
        assert(#D.propertyIdsByZone[z.id]>=24,z.id)
        for _,id in ipairs(D.propertyIdsByZone[z.id]) do
            local p=D.propertyById[id]; assert(p); eq(p.zone,z.id); assert(not seen[id]); seen[id]=true
            assert(not names[p.name],p.name); names[p.name]=true
            for key,value in pairs(p.negotiationResistances) do assert(value>=0 and value<=1,key) end
        end
    end
    local n=0; for _ in pairs(seen) do n=n+1 end; eq(n,#D.properties)
end)
test("generated businesses have unique regional names and authored names stay fixed",function()
    local generated,katakana,names=0,0,{}
    for _,p in ipairs(D.properties) do
        assert(not names[p.name],p.name); names[p.name]=p.id
        if p.generatedName then
            generated=generated+1
            if p.katakanaName then katakana=katakana+1 end
            assert(p.id:find("_trade_",1,true),p.id)
            assert(not p.name:match("%d"),p.name)
        end
    end
    eq(generated,53*24)
    assert(katakana/generated>.4 and katakana/generated<.45,katakana.." / "..generated)
    eq(D.propertyById.aur_farm.name,"朝露の果樹園")
    eq(D.propertyById.str_hq.name,"ドフォーレ商会本社")
    eq(D.propertyById.molag_bal_citadel.name,"モラグ・バルの居城")
end)
test("ordinary companies own ten to twenty properties and their body is directly purchasable",function()
    local s=M.New(); local ordinary,bosses,bodies=0,0,0
    for id,c in pairs(s.companies) do
        if c.ordinaryCompany then
            ordinary=ordinary+1; local holdings=#M.Owned(s,id); assert(holdings>=10 and holdings<=20,id.." owns "..holdings)
            local headquarters=D.companyHeadquarters[id]; eq(#headquarters,1)
            local body=s.properties[headquarters[1]]; assert(body.companyBody and body.owner==id); bodies=bodies+1
            assert(not body.requiresProperties or #body.requiresProperties==0)
        elseif c.bossCompany then bosses=bosses+1; assert(#D.companyHeadquarters[id]>=3) end
    end
    eq(ordinary,54); eq(bosses,3); eq(bodies,54)
    local body=s.properties[D.companyHeadquarters.regional_auridon[1]]
    s.unlocked.auridon=true; assert(M.IsAvailable(s,body))
    local before=#M.Owned(s,"regional_auridon"); body.owner="player"
    local report=M.Takeover(s,body.id); assert(report and report.count==before-1 and s.companies.regional_auridon.dissolved)
    eq(#M.Owned(s,"regional_auridon"),0)
    eq(s.properties[D.companyHeadquarters.ink[1]].name,"メナント家本邸")
end)
test("named houses and companies are the principal owners in their home regions",function()
    local s=M.New()
    eq(s.companies.ash.name,"レイヴンウォッチ家")
    eq(s.companies.regional_telvanni.name,"テルヴァンニ家")
    local function regionalHoldings(zone,company)
        local owned,total=0,0
        for _,id in ipairs(D.propertyIdsByZone[zone]) do
            total=total+1
            if s.properties[id].owner==company then owned=owned+1 end
        end
        return owned,total
    end
    local raven,totalRivenspire=regionalHoldings("rivenspire","ash")
    local telvanni,totalTelvanni=regionalHoldings("telvanni","regional_telvanni")
    local menant,totalGlenumbra=regionalHoldings("glenumbra","ink")
    local alikr,totalAlikr=regionalHoldings("alikr","regional_alikr")
    local eric,totalWrothgar=regionalHoldings("wrothgar","regional_wrothgar")
    local fullbright,totalAuridon=regionalHoldings("auridon","regional_auridon")
    local verelois,totalHighIsle=regionalHoldings("highisle","regional_highisle")
    local dufort=regionalHoldings("highisle","dufort")
    local hlaalu,totalVvardenfell=regionalHoldings("vvardenfell","regional_vvardenfell")
    local redoran,totalStonefalls=regionalHoldings("stonefalls","iron")
    local indoril,totalDeshaan=regionalHoldings("deshaan","regional_deshaan")
    local mornard,totalGalen=regionalHoldings("galen","regional_galen")
    local goldCoast,totalGoldCoast=regionalHoldings("goldcoast","regional_goldcoast")
    local farolah,totalHewsBane=regionalHoldings("hewsbane","regional_hewsbane")
    local baandariNorth,totalNorth=regionalHoldings("northelsweyr","regional_northelsweyr")
    local baandariSouth,totalSouth=regionalHoldings("southelsweyr","regional_southelsweyr")
    local tamrith,totalStormhaven=regionalHoldings("stormhaven","regional_stormhaven")
    assert(raven>=15 and raven>totalRivenspire/2,raven.." / "..totalRivenspire)
    assert(telvanni>=16 and telvanni>totalTelvanni/2,telvanni.." / "..totalTelvanni)
    assert(menant>=16 and menant>totalGlenumbra/2,menant.." / "..totalGlenumbra)
    assert(alikr>=16 and alikr>totalAlikr/2,alikr.." / "..totalAlikr)
    assert(eric>=16 and eric>totalWrothgar/2,eric.." / "..totalWrothgar)
    assert(fullbright>=16 and fullbright>totalAuridon/2,fullbright.." / "..totalAuridon)
    assert(verelois>=10 and dufort>=10 and verelois+dufort>totalHighIsle*.8)
    assert(hlaalu>totalVvardenfell/2 and redoran>totalStonefalls/2 and indoril>totalDeshaan/2)
    assert(mornard>totalGalen/2 and goldCoast>totalGoldCoast/2)
    assert(farolah>totalHewsBane/2)
    assert(baandariNorth>totalNorth/2 and baandariSouth>totalSouth/2)
    assert(tamrith>totalStormhaven/2)
    eq(s.properties.riv_hq.name,"レイヴンウォッチ城館")
    eq(s.properties[D.companyHeadquarters.regional_telvanni[1]].name,"テルヴァンニ家")
    eq(s.properties[D.companyHeadquarters.ink[1]].name,"メナント家本邸")
    eq(s.properties[D.companyHeadquarters.regional_alikr[1]].name,"砂星物産会")
    eq(s.properties[D.companyHeadquarters.regional_wrothgar[1]].name,"エリック社")
    eq(s.properties[D.companyHeadquarters.regional_auridon[1]].name,"フルブライト商会")
    eq(s.companies.regional_highisle.name,"ヴェロイーズ商会"); eq(s.companies.dufort.name,"デュフォート家")
    eq(s.companies.regional_vvardenfell.name,"フラール家"); eq(s.companies.iron.name,"レドラン家")
    eq(s.companies.regional_deshaan.name,"インドル家"); eq(s.companies.regional_galen.name,"モーナード家")
    eq(s.companies.regional_goldcoast.name,"ゴールドコースト交易会社")
    eq(s.companies.regional_hewsbane.name,"ファロラー家")
    eq(s.properties[D.companyHeadquarters.regional_hewsbane[1]].name,"ファロラー家")
    eq(s.companies.regional_northelsweyr.name,"バーンダリ商人団")
    eq(s.companies.regional_southelsweyr.name,"バーンダリ商人団・南方支部")
    eq(s.companies.regional_stormhaven.name,"タムリス家")
end)
test("chapter five reveals every atlas page and last property page",function()
    local a=A.New(); a.state.chapter=5; M.Unlock(a.state); a:MovePage(1); eq(a.index,9)
    a.index=53; eq(a:Selected().id,"nightmarket")
    a.state.unlocked.nightmarket=true; a:Act("confirm"); eq(a.screen,"properties"); eq(#a:Rows(),24)
    a:MovePage(1); eq(a.index,11); a:MovePage(1); eq(a.index,21); a:Move(3); eq(a.index,24)
    local row=a:Selected(); eq(row.property.zone,"nightmarket"); a:Act("confirm"); a:Act("confirm"); eq(a.screen,"battle")
end)
test("economic profiles provide different yield, risk and momentum",function()
    local profiles={}
    for _,id in ipairs(D.propertyIdsByZone.auridon) do
        local p=D.propertyById[id]; if p.businessProfile then profiles[p.businessProfile]=p end
    end
    assert(profiles.steady and profiles.growth and profiles.network and profiles.anchor)
    assert(profiles.growth.expectedProfit/profiles.growth.marketValue>profiles.steady.expectedProfit/profiles.steady.marketValue)
    assert(profiles.growth.independenceIncrease>profiles.steady.independenceIncrease)
    assert(profiles.network.gaugeAcceleration>profiles.growth.gaugeAcceleration)
end)
test("no attack still produces a mandatory ranking",function()
    local a=A.New(function() return 1 end); a.engine:Start("gra_inn"); a.engine:Finish("won"); a.screen="result"
    a:Act("confirm"); eq(a.screen,"admin"); assert(a.counterattackChecked); a:FinishAdministration(); eq(a.screen,"rankings"); eq(#a.rankingRows,#M.Rankings(a.state))
    eq(a:Selected().id,"player"); a:Tab(1); eq(a.screen,"rankings")
end)
test("counterattack has an owned enemy source and an owned player target",function()
    local s=new(); local attack=M.RollCounterattack(s,function() return 0 end)
    assert(attack); eq(s.properties[attack.sourcePropertyId].owner,attack.companyId); eq(s.properties[attack.propertyId].owner,"player")
    assert(attack.threat and attack.funding>0)
    for id,c in pairs(s.companies) do if id~="player" then c.cash=0 end end
    eq(M.RollCounterattack(s,function() return 0 end),nil)
end)
test("counterattack AI becomes richer faster and more forceful in later chapters",function()
    local early=M.New(); early.unlocked.auridon=true; early.properties.aur_farm.owner="player"
    local late=M.Load(M.Export(early)); early.chapter=1; late.chapter=5
    early.companies.amber.cash=C.Money(100000000000000); late.companies.amber.cash=early.companies.amber.cash
    local e1=E.New(early,function() return .5 end); local e5=E.New(late,function() return .5 end)
    assert(e1:Start("aur_farm","amber")); assert(e5:Start("aur_farm","amber"))
    assert(e5.battle.enemyBid>e1.battle.enemyBid*2)
    assert(e5.battle.enemyBudget>e1.battle.enemyBudget*2.5)
    assert(e5.battle.assault.wait<e1.battle.assault.wait)
    assert(e5.battle.assaultAcceleration>e1.battle.assaultAcceleration)
    assert(C.tactics.aiUseChance+e5.battle.assault.tactic>C.tactics.aiUseChance+e1.battle.assault.tactic)
end)
test("offensive result enters defense before rankings and defense cannot cascade",function()
    local calls=0
    local a=A.New(function() calls=calls+1; return 0 end)
    a.engine:Start("gra_inn"); a.engine:Finish("won"); a.screen="result"; a:Act("confirm")
    eq(a.screen,"battle"); eq(a.engine.battle.mode,"defense"); assert(a.modal); eq(a.rankingRows,nil)
    a:Tick(.2); eq(a.engine.battle.elapsed,0); a:Act("confirm"); assert(not a.modal)
    a.engine:Finish("won"); a.screen="result"; local before=calls; a:Act("confirm")
    eq(a.screen,"admin"); eq(calls,before); eq(a.state.defensesWon,1)
end)
test("defense loss transfers property once and rankings include the transfer",function()
    local a=A.New(function() return 0 end); a.engine:Start("gra_inn"); a.engine:Finish("lost"); a.screen="result"; a:Act("confirm")
    local b=a.engine.battle; local id=b.targetId; local attacker=b.defender
    a:Act("confirm"); a.engine:Finish("lost"); a.engine:Finish("won"); a.screen="result"; a:Act("confirm")
    eq(a.state.properties[id].owner,attacker); eq(a.state.defensesLost,1); eq(a.state.defensesWon,0)
    eq(a.screen,"admin"); a:FinishAdministration()
    for _,r in ipairs(a.rankingRows) do if r.id=="player" then eq(r.propertyCount,1) end end
end)
test("defense timeout and withdrawal both transfer title",function()
    for _,result in ipairs({"timeout","withdrawn"}) do
        local s,e=new(); assert(e:Start("aur_farm","amber")); e:Finish(result); eq(s.properties.aur_farm.owner,"amber"); eq(s.defensesLost,1)
    end
end)
test("enemy commits actual treasury and cannot overspend",function()
    local s,e=new(); local budget=C.Money(300); s.companies.amber.cash=budget
    local _,reserves=M.CompanyAssets(s,"amber"); local available=budget+reserves
    assert(e:Start("aur_farm","amber")); advance(e,1)
    assert(s.companies.amber.cash>=0 and e.battle.groupReserve>=0)
    eq(s.companies.amber.cash+e.battle.groupReserve+e.battle.enemyBid,available)
    e:Finish("won")
    local _,remainingReserves=M.CompanyAssets(s,"amber")
    eq(s.companies.amber.cash+remainingReserves+e.battle.enemyBid,available)
    eq(PBTrade.Data.companies.amber.cash,C.Money(42000,"amber:cash"))
end)
test("rank funding power separates liquidity from property valuation",function()
    local s=new(); local ranks=M.Rankings(s)
    for _,r in ipairs(ranks) do if r.id=="player" then
        local reserves=s.properties.aur_farm.reserve+s.properties.gra_lumber.reserve
        eq(r.cash,s.cash); eq(r.reserves,reserves); eq(r.fundingPower,s.cash+reserves); eq(r.assets,M.Assets(s))
    end end
    for _,p in pairs(s.properties) do p.owner="neutral" end
    for id,c in pairs(s.companies) do c.cash=1000 end; s.cash=1000
    local first=M.Rankings(s); local second=M.Rankings(s)
    for i,r in ipairs(first) do eq(r.id,second[i].id); eq(r.rank,i) end
end)
test("no holdings or no enemy holdings suppresses counterattack safely",function()
    local s=new(); for _,p in pairs(s.properties) do p.owner="neutral" end
    eq(M.RollCounterattack(s,function() return 0 end),nil)
    s.properties.aur_farm.owner="player"; eq(M.RollCounterattack(s,function() return 0 end),nil)
end)
test("counterattacks never target a player property outside the current trade routes",function()
    local s=M.New()
    for _,p in pairs(s.properties) do p.owner="neutral" end
    s.properties.aur_jewel.owner="iron"
    s.properties.coldharbour_trade_24.owner="player"
    local attack,why=M.RollCounterattack(s,function() return 0 end)
    eq(attack,nil); assert(why:find("攻撃可能",1,true))
end)
test("settlement pays profits restores reserves and services debt",function()
    local s=M.New(); local p=s.properties.aur_farm
    p.reserve=0; s.debt=1000; local cash=s.cash
    local report=M.SettleCycle(s)
    assert(report.gross>0 and report.debtPayment>0 and report.reserveRecovered>0)
    eq(s.cash,cash+report.net); eq(s.debt,1000-report.debtPayment); eq(s.cycles,1)
    assert(p.reserve>0)
end)
test("every settlement compounds player neutral and hostile property values",function()
    local s=M.New(); local player=s.properties.aur_farm; local neutral=s.properties.aur_port; local enemy=s.properties.aur_jewel
    for _,p in ipairs({player,neutral,enemy}) do p.marketValue=10000; p.expectedProfit=1000 end
    local report=M.SettleCycle(s)
    -- Growth per period: market 2%, plus 0.4% (player) / 0.2% (neutral) / 0.8% (rivals).
    eq(player.marketValue,10240); eq(neutral.marketValue,10220); eq(enemy.marketValue,10280)
    eq(player.expectedProfit,1024); eq(neutral.expectedProfit,1022); eq(enemy.expectedProfit,1028)
    assert(report.marketGrowth>0 and report.highestValue>0)
end)
test("rebuild financing is gated by funding power and records debt",function()
    local s=M.New(); s.cash=0; for _,p in ipairs(M.Owned(s)) do p.reserve=0 end
    assert(M.CanRebuild(s)); local reputation=s.reputation
    local ok,value=M.Rebuild(s); assert(ok); eq(value,C.economy.rebuildGrant)
    eq(s.cash,value); eq(s.debt,value); eq(s.rebuilds,1); eq(s.reputation,reputation-C.economy.rebuildReputationCost)
    assert(not M.CanRebuild(s)); assert(not M.Rebuild(s))
end)
test("saved campaign state and compounded valuations round trip and migrate missing fields",function()
    local s=M.New(); s.cash=12345; s.properties.aur_farm.independenceRisk=77
    s.properties.aur_farm.reserve=321; s.properties.aur_farm.marketValue=123456789; s.properties.aur_farm.expectedProfit=7654321
    s.learnedTactics.gift=true; s.visitedProperties.test_place=true; s.cycles=9
    local restored=M.Load(M.Export(s))
    eq(restored.cash,12345); eq(restored.properties.aur_farm.independenceRisk,77)
    eq(restored.properties.aur_farm.reserve,321); eq(restored.properties.aur_farm.marketValue,123456789); eq(restored.properties.aur_farm.expectedProfit,7654321)
    assert(restored.learnedTactics.gift and restored.visitedProperties.test_place); eq(restored.cycles,9)
    local legacy=M.Load({cash=99,properties={aur_farm={owner="player",independenceRisk=999,reserve=-2}}})
    eq(legacy.cash,C.Money(99,"saved:cash")); eq(legacy.properties.aur_farm.independenceRisk,128); eq(legacy.properties.aur_farm.reserve,0)
    local old=M.Export(M.New()); old.schemaVersion=7
    -- v7 stored every amount in the former abstract unit.  Make this a real legacy
    -- payload before checking the v8 company-owner and v9 currency migrations together.
    old.cash=math.floor(old.cash/C.currencyScale); old.debt=math.floor((old.debt or 0)/C.currencyScale)
    for _,record in pairs(old.properties) do
        record.reserve=math.floor((record.reserve or 0)/C.currencyScale)
        record.marketValue=math.floor(record.marketValue/C.currencyScale)
        record.expectedProfit=math.floor(record.expectedProfit/C.currencyScale)
    end
    for _,record in pairs(old.companies) do record.cash=math.floor(record.cash/C.currencyScale) end
    old.properties.auridon_trade_01.owner="neutral"; old.properties.auridon_trade_03.owner="player"
    local migrated=M.Load(old)
    eq(migrated.properties.auridon_trade_01.owner,D.propertyById.auridon_trade_01.owner)
    eq(migrated.properties.auridon_trade_03.owner,"player")
    assert(migrated.cash>=C.Money(math.floor(C.campaign.startingCash/C.currencyScale),"saved:cash"))
end)
test("chapter five completion produces one ending and free management",function()
    local s=M.New(); s.chapter=5; s.cycles=1200; s.cash=D.campaigns[5].objective.assetTarget
    for _,id in ipairs(D.campaigns[5].objective.targets) do s.properties[id].owner="player" end
    local ending=M.AdvanceCampaign(s); assert(ending and ending.ending and s.campaignComplete)
    eq(M.AdvanceCampaign(s),nil)
end)
test("first-run tutorial completes once and persists",function()
    local saved={}; local a=A.New(function() return .5 end,saved); a:BeginSession()
    eq(a.modal.action,"tutorial"); for _=1,4 do a:Act("confirm") end
    assert(saved.tutorialComplete and saved.state and a.modal.campaign)
    local resumed=A.New(function() return .5 end,saved); resumed:BeginSession()
    assert(resumed.modal.campaign and not resumed.modal.action)
end)
test("live ESO catalog imports localized POIs houses and visited interiors",function()
    local L=PBTrade.LiveCatalog; L.imported=false; L.count=0
    POI_TYPE_STANDARD=1; POI_TYPE_HOUSE=2
    GetNumZones=function() return 2 end
    GetZoneNameByIndex=function(i) return i==1 and "オーリドン" or "グレナンブラ" end
    GetNumPOIs=function() return 1 end
    GetPOIInfo=function(zoneIndex) return zoneIndex==1 and "バルケルガード市場" or "ダガーフォール港",1,"交易の中心地","" end
    GetPOIType=function() return POI_TYPE_STANDARD end
    GetNumFastTravelNodes=function() return 2 end
    GetFastTravelNodeInfo=function(i) return false,i==1 and "酔いどれライオン" or "マーラの口付け",0,0,"",nil,POI_TYPE_HOUSE,false,false end
    GetFastTravelNodePOIIndicies=function(i) return i==1 and 2 or 1,1 end
    local before=#D.properties; eq(L.Import(),6); eq(#D.properties,before+6)
    local s=M.New(); GetUnitZoneIndex=function() return 1 end; local currentName="マーラの口付け"
    GetPlayerLocationName=function() return currentName end
    local canonical=D.propertyById.eso_house_1_2; assert(canonical and canonical.requiresVisit)
    local e=E.New(s,function() return .5 end)
    local ok,why=e:Start(canonical.id); assert(not ok and why:find("物件登録"))
    local captured=L.CaptureCurrent(s); eq(captured.id,canonical.id); assert(s.visitedProperties[canonical.id])
    -- Registration is permanent: after leaving the location and even the region, the normal
    -- trade map can start this acquisition without consulting the current-location APIs.
    currentName="ダガーフォール港"; GetUnitZoneIndex=function() return 2 end
    assert(e:Start(canonical.id)); e:Finish("withdrawn")
    currentName="パブ マーラの口付け"; L.CaptureCurrent(s)
    local found={}; for _,p in ipairs(D.properties) do if p.canonical then found[p.name]=p end end
    assert(found["酔いどれライオン"] and found["マーラの口付け"] and found["パブ マーラの口付け"])
    eq(found["酔いどれライオン"].canonicalSource,"eso_house"); assert(s.properties[found["パブ マーラの口付け"].id])
    assert(s.visitedProperties[found["パブ マーラの口付け"].id])
    -- Opening the title offers explicit registration, then removes the item.  Acquisition is
    -- still available only from the regional property list.
    local app=A.New(); app.state.companyName="試験商会"; GetUnitZoneIndex=function() return 1 end; currentName="オーリドン"; app:ShowTitle()
    eq(app:Rows()[1].command,"continue"); eq(#app:Rows(),3)
    for _,row in ipairs(app:Rows()) do assert(row.command~="localAcquire") end
    currentName="マーラの口付け"; app.modal=nil; app:ShowTitle()
    eq(app:Rows()[1].command,"registerCurrent"); eq(#app:Rows(),4)
    assert(not app.state.visitedProperties[canonical.id]); app:Act("confirm")
    eq(app:Rows()[1].command,"continue"); eq(#app:Rows(),3)
    assert(app.state.visitedProperties[canonical.id])
    -- The reported real-world failure case: the Rosy Lion in Glenumbra appears as an explicit
    -- registration command, and revisiting it after registration does not add the command again.
    GetUnitZoneIndex=function() return 2 end; currentName="酔いどれライオン"; app:ShowTitle()
    local lion=app:Rows()[1]; eq(lion.command,"registerCurrent"); assert(lion.label:find("酔いどれライオン",1,true))
    app:Act("confirm"); assert(app.state.visitedProperties.eso_house_2_1)
    eq(app:Rows()[1].command,"continue"); eq(#app:Rows(),3)
    app.screen="properties"; app.zone="auridon"
    local onMap=false; for _,row in ipairs(app:Rows()) do if row.id==canonical.id then onMap=true end end
    assert(onMap,"registered real place must appear in its regional property list")
    GetNumZones=nil; GetZoneNameByIndex=nil; GetNumPOIs=nil; GetPOIInfo=nil; GetPOIType=nil
    GetNumFastTravelNodes=nil; GetFastTravelNodeInfo=nil; GetFastTravelNodePOIIndicies=nil
    GetUnitZoneIndex=nil; GetPlayerLocationName=nil; POI_TYPE_STANDARD=nil; POI_TYPE_HOUSE=nil
end)
test("real places are recorded before the first open, inside interiors, and priced at market",function()
    local L=PBTrade.LiveCatalog
    -- Japanese names are compared whole: separators go, characters stay.
    eq(L.Key("ヴルカル・ガード"),L.Key("ヴルカルガード")); eq(L.Key("オーリドン"),"オーリドン")
    assert(L.Key("オーリドン")~=L.Key("グラーウッド"))
    local zoneNames={[1]="オーリドン",[2]="グレナンブラ",[3]="酔いどれライオン",[4]="星見の酒場"}
    GetZoneNameByIndex=function(i) return zoneNames[i] end
    local zoneIndex,location=1,"バルケルガード市場"
    GetUnitZoneIndex=function() return zoneIndex end; GetPlayerLocationName=function() return location end
    GetCurrentZoneHouseId=function() return zoneIndex==3 and 42 or 0 end
    -- 1) Outdoors before the ledger was ever opened: kept as a pending record in saved variables.
    local saved={tutorialComplete=true}
    L.RecordPending(saved,L.Observe()); L.RecordPending(saved,L.Observe()); eq(#saved.pendingVisits,1)
    -- 2) Inside a player house: its own zone. Matched by the house name across all regions.
    zoneIndex,location=3,""
    local house=D.propertyById.eso_house_2_1; eq(house.name,"酔いどれライオン")
    local record=L.Observe(); assert(record.interior and record.name=="酔いどれライオン" and record.zoneId=="auridon")
    L.RecordPending(saved,record)
    -- 3) An instanced tavern the client never listed: created in the last outdoor region.
    zoneIndex,location=4,""
    L.RecordPending(saved,L.Observe()); eq(#saved.pendingVisits,3)
    -- Opening the ledger previews the current place but does not silently register it.
    local a=A.New(function() return .5 end,saved)
    assert(saved.pendingVisits and #saved.pendingVisits==3)
    assert(a.currentRegistration and a.currentRegistration.name=="星見の酒場")
    assert(not a.state.visitedProperties.eso_poi_1_1 and not a.state.visitedProperties[house.id])
    a.currentLocationRecord=L.Observe(); assert(a:ConfirmCurrentRegistration())
    local tavern=L.Find("auridon","星見の酒場"); assert(tavern and tavern.canonicalSource=="eso_location" and a.state.visitedProperties[tavern.id])
    -- The inn room gets its own title registration command and is filed by the imported name.
    zoneIndex,location=3,""; a:RefreshCurrentLocation(); assert(a.currentRegistration and a.currentRegistration.name=="酔いどれライオン")
    assert(a:ConfirmCurrentRegistration()); assert(a.state.visitedProperties[house.id])
    -- Register the outdoor POI explicitly as well.
    zoneIndex,location=1,"バルケルガード市場"; a:RefreshCurrentLocation(); assert(a:ConfirmCurrentRegistration())
    assert(a.state.visitedProperties.eso_poi_1_1)
    -- Loading the add-on for the first time while already inside also works: resolve the
    -- interior's parent zone instead of requiring a previous outdoor observation.
    GetZoneId=function(index) return index==4 and 400 or index end
    GetParentZoneId=function(id) return id==400 and 100 or 0 end
    GetZoneNameById=function(id) return id==100 and "オーリドン" or "" end
    L.lastOutdoorZone=nil; zoneIndex,location=4,""
    local parentRecord=L.Observe(); eq(parentRecord.zoneId,"auridon"); assert(parentRecord.interior)
    local parentPlace=L.CaptureCurrent(a.state); eq(parentPlace.zone,"auridon"); eq(parentPlace.name,"星見の酒場")
    -- Housing uses its dedicated "found in zone" API before the unreliable parent chain.
    GetHouseFoundInZoneId=function(id) return id==1 and 100 or 0 end
    GetZoneNameById=function(id) return id==100 and "オーリドン" or "" end
    zoneNames[4]="住宅API試験室"; zoneIndex,location=4,""; GetCurrentZoneHouseId=function() return 1 end
    GetParentZoneId=function() return 0 end; L.lastOutdoorZone=nil
    local houseHere=L.ReadHere(); eq(houseHere.parentZone.id,"auridon"); eq(houseHere.tradeZoneSource,"housingApi")
    local houseRecord=L.Observe(); eq(houseRecord.zoneId,"auridon")
    eq(houseRecord.houseId,1)
    local stableHouse=L.CaptureCurrent(a.state); eq(stableHouse.id,"eso_houseid_1"); eq(stableHouse.name,"住宅API試験室")
    assert(stableHouse.canonical and stableHouse.id~="aur_farm")
    -- If the housing API is absent, stable house IDs 1 and 2 still resolve the two inn rooms.
    GetHouseFoundInZoneId=nil; eq((L.HouseTradeZone(1)).id,"auridon"); eq((L.HouseTradeZone(2)).id,"glenumbra")
    local e=a.engine; assert(e:Start(house.id)); e:Finish("withdrawn"); e.battle=nil
    -- 4) The location report says what the client sees and what it matched.
    GetCurrentZoneHouseId=function() return zoneIndex==3 and 42 or 0 end
    zoneIndex,location=3,""
    local report=L.Describe(a.state)
    assert(report:find("酔いどれライオン",1,true) and report:find("住宅ID 42",1,true) and report:find("登録済み・遠隔買収可",1,true))
    -- 5) A place first found after the market has grown enters at the grown market level.
    for _,q in pairs(a.state.properties) do if not q.canonical then q.marketValue=q.marketValue*20 end end
    zoneIndex,location=1,"月影の見張り塔"; a.state.cycles=300
    local p=L.CaptureCurrent(a.state); local sp=a.state.properties[p.id]
    assert(sp.marketValue>p.marketValue*10 and sp.reserve==sp.expectedProfit*C.battle.reserveProfitFactor)
    for _,q in pairs(a.state.properties) do if not q.canonical then q.marketValue=q.marketValue/20 end end
    -- 6) Saves keep only name + region for client-imported places, and follow renumbering.
    local out=M.Export(a.state)
    eq(out.canonicalProperties.eso_poi_1_1.marketValue,nil); assert(out.canonicalProperties[p.id].marketValue)
    a.state.properties.eso_poi_1_1.owner="player"; out=M.Export(a.state)
    out.properties.eso_poi_77_7=out.properties.eso_poi_1_1; out.properties.eso_poi_1_1=nil
    out.canonicalProperties.eso_poi_77_7=out.canonicalProperties.eso_poi_1_1; out.canonicalProperties.eso_poi_1_1=nil
    out.visitedProperties.eso_poi_77_7=true; out.visitedProperties.eso_poi_1_1=nil
    local loaded=M.Load(out)
    eq(loaded.properties.eso_poi_1_1.owner,"player"); assert(loaded.visitedProperties.eso_poi_1_1 and not loaded.visitedProperties.eso_poi_77_7)
    eq(D.propertyById.eso_poi_77_7,nil)
    GetZoneNameByIndex=nil; GetUnitZoneIndex=nil; GetPlayerLocationName=nil; GetCurrentZoneHouseId=nil
    GetZoneId=nil; GetParentZoneId=nil; GetZoneNameById=nil
    GetHouseFoundInZoneId=nil
end)
test("live location matching can never select a fictional campaign property",function()
    local L=PBTrade.LiveCatalog
    -- Even an exact name collision must create/resolve a canonical place, never return aur_farm.
    eq(L.Find("auridon","朝露の果樹園"),nil)
    local s=M.New(); local p=L.Apply(s,{zoneId="auridon",name="朝露の果樹園",interior=true,houseId=999})
    assert(p and p.canonical and p.id=="eso_houseid_999" and p.id~="aur_farm")
    eq(s.properties.aur_farm.owner,"player")
end)
test("a stale house ID can never replace the current house name or region",function()
    local L=PBTrade.LiveCatalog
    local s=M.New()
    -- Reproduce an old session/save that attached this house ID to the wrong inn.
    local stale=L.Apply(s,{zoneId="glenumbra",name="古い住宅誤登録",interior=true,houseId=8181})
    eq(stale.id,"eso_houseid_8181")
    stale.name="酔いどれライオン"
    -- ESO now reports the actual current house. The old implementation reused `stale`
    -- solely because the house ID matched and displayed the Rosy Lion on the title screen.
    local current=L.Apply(s,{zoneId="grahtwood",name="スナグポッド",interior=true,houseId=8181})
    eq(current.name,"スナグポッド"); eq(current.zone,"grahtwood")
    assert(current.id~="eso_houseid_8181" and current.id:find("eso_houseid_8181_",1,true)==1)
    assert(current~=stale and s.visitedProperties[current.id])
    -- Repeated polling resolves to the same corrected record instead of making duplicates.
    local again=L.Resolve(s,{zoneId="grahtwood",name="スナグポッド",interior=true,houseId=8181})
    eq(again.id,current.id); eq(again.name,"スナグポッド")
end)
test("textures retry once then restore primary after failure without disturbing loaded controls",function()
    dofile("PBsTradeGame/Assets.lua"); local Assets=PBTrade.Assets
    GetAddOnManager=function() return {GetNumAddOns=function() return 1 end,GetAddOnInfo=function() return "PBsTradeGame" end,
        GetAddOnRootDirectoryPath=function() return "percache:/AddOnsManaged/x/PBsTradeGame" end} end
    local function control(hidden)
        local c={hidden=hidden}
        function c:SetTexture(path) self.path=path end
        function c:IsControlHidden() return self.hidden end
        function c:IsTextureLoaded() return false end -- a client that never reports "loaded"
        return c
    end
    Assets.Initialize(); local a,b=control(false),control(true)
    Assets.Apply(a,"atlas"); Assets.Apply(b,"crest")
    eq(a.path,"PBsTradeGame/assets/atlas.dds"); eq(b.path,"PBsTradeGame/assets/crest.dds")
    for _=1,30*20 do Assets.PollAll(1/30) end
    eq(a.path,"PBsTradeGame/assets/atlas.dds"); eq(Assets.rootIndex,1)
    eq(b.path,"PBsTradeGame/assets/crest.dds") -- hidden controls wait until displayed
    b.hidden=false; Assets.PollAll(4.1)
    eq(b.path,"percache:/AddOnsManaged/x/PBsTradeGame/assets/crest.dds")
    local good=control(false)
    function good:IsTextureLoaded() return true end
    function good:GetTextureFileDimensions() return 1024,1024 end
    Assets.Apply(good,"atlas"); Assets.PollAll(2)
    eq(good.path,"PBsTradeGame/assets/atlas.dds")
    local placeholder=control(false)
    function placeholder:IsTextureLoaded() return true end
    function placeholder:GetTextureFileDimensions() return 1,1 end
    Assets.Apply(placeholder,"atlas"); Assets.PollAll(4.1)
    eq(placeholder.path,"percache:/AddOnsManaged/x/PBsTradeGame/assets/atlas.dds")
    Assets.PollAll(4.1)
    eq(placeholder.path,"PBsTradeGame/assets/atlas.dds")
    eq(b.path,"PBsTradeGame/assets/crest.dds")
    assert(placeholder.pbtradeLoadDone)
    -- A slow but successful primary request must not be discarded after one second.
    local slow=control(false)
    Assets.Apply(slow,"atlas"); Assets.PollAll(1.1)
    eq(slow.path,"PBsTradeGame/assets/atlas.dds")
    function slow:IsTextureLoaded() return true end
    function slow:GetTextureFileDimensions() return 1024,1024 end
    Assets.PollAll(10); eq(slow.path,"PBsTradeGame/assets/atlas.dds")
    -- A successful alternate path is retained (no unconditional rollback).
    local alternate=control(false)
    Assets.Apply(alternate,"atlas"); Assets.PollAll(4.1)
    function alternate:IsTextureLoaded() return self.path:find("^percache:")~=nil end
    function alternate:GetTextureFileDimensions() return 1024,1024 end
    Assets.PollAll(10)
    eq(alternate.path,"percache:/AddOnsManaged/x/PBsTradeGame/assets/atlas.dds")
    -- Manual switch moves every texture to the root the client reports, and back.
    eq(Assets.NextRoot(),2); eq(a.path,"percache:/AddOnsManaged/x/PBsTradeGame/assets/atlas.dds"); assert(b.path:find("^percache:"))
    eq(Assets.NextRoot(),1); eq(a.path,"PBsTradeGame/assets/atlas.dds")
    -- The saved choice is honoured at start-up; an unknown choice falls back to the add-on path.
    Assets.Initialize(2); local c=control(false); Assets.Apply(c,"coin"); assert(c.path:find("^percache:"))
    Assets.Initialize(5); eq(Assets.rootIndex,1)
    local report=Assets.Describe(); assert(report:find("PBsTradeGame/assets",1,true) and report:find("percache:",1,true))
    -- The ledger row toggles for this session only; nothing is saved.
    Assets.Initialize(); local saved={}; local app=A.New(nil,saved); app.modal=nil; app.screen="management"
    for i,row in ipairs(app:Rows()) do if row.command=="assetRoot" then app.index=i end end
    app:Act("confirm"); eq(Assets.rootIndex,2); eq(saved.assetRoot,nil); app:Act("confirm"); eq(Assets.rootIndex,1)
    GetAddOnManager=nil
end)
test("real places join theme groups and a landmark route, and strengthen group funding",function()
    local zone=D.zoneById.auridon
    local function place(id,name,category)
        local p={id=id,name=name,zone="auridon",category=category,marketValue=8000,expectedProfit=500,owner="neutral",
            independenceRisk=10,independenceIncrease=8,gaugeAcceleration=1,groups={},negotiationResistances={},
            isHeadquarters=false,canonical=true,requiresVisit=true,canonicalSource="eso_location",minChapter=1}
        D.properties[#D.properties+1]=p; D.AddProperty(p); return p
    end
    local tavern=place("test_real_tavern","試験の酒場","tavern")
    local port=place("test_real_port","試験の港","port")
    local shop=place("test_real_jewel","試験の宝飾店","jewelry")
    local function has(p,g) for _,id in ipairs(p.groups) do if id==g then return true end end end
    assert(has(tavern,"hospitality") and has(tavern,"region_auridon") and has(tavern,"industry_tavern") and has(tavern,"landmarks"))
    assert(has(port,"roads") and has(shop,"jewels"))
    -- Generated properties keep their groups and never join the landmark route.
    for _,p in ipairs(D.properties) do if not p.canonical then assert(not has(p,"landmarks")) end end
    local s=M.New()
    for _,id in ipairs({"test_real_tavern","test_real_port","test_real_jewel"}) do s.properties[id].owner="player"; s.visitedProperties[id]=true end
    s.learnedGroups.landmarks=true; s.learnedGroups.region_auridon=true
    local route=M.GroupStatus(s,"landmarks"); eq(route.count,3); assert(route.usable)
    eq(route.landmarks,3); assert(math.abs(route.bonus-(1.6+.3))<1e-9)
    local region=M.GroupStatus(s,"region_auridon"); assert(region.landmarks==3 and math.abs(region.bonus-region.baseBonus-.3)<1e-9)
    for i=1,10 do local p=place("test_real_extra_"..i,"試験の名所"..i,"market"); s.properties[p.id]=M.Copy(p); s.properties[p.id].reserve=7000; s.properties[p.id].owner="player" end
    assert(math.abs(M.GroupStatus(s,"landmarks").landmarkBonus-C.groups.landmarkBonusMax)<1e-9)
    eq(M.FormatRatio(1.35+.3),"1.65"); eq(M.FormatRatio(2),"2")
    -- The boosted multiplier is what the negotiation pays out.
    local e=E.New(s,function() return .99 end); assert(e:Start("gra_inn")); e.battle.playerWait=0
    local status=M.GroupStatus(s,"landmarks"); local base=0; for _,p in ipairs(status.members) do base=base+e:Quote(p.id) end
    local ok,amount=e:RequestGroup("landmarks"); assert(ok); eq(amount,math.floor(base*status.bonus))
    assert(A.GroupDetail({state=s},status):find("実在地点",1,true))
end)
test("discovering a group plays its own sound, even when a defection happens at once",function()
    local played={}; local play=PBTrade.Audio.Play; PBTrade.Audio.Play=function(kind) played[#played+1]=kind; return true end
    local a=A.New(function() return 0 end)
    a.state.properties.aur_port.owner="player"; a.state.properties.aur_jewel.owner="player"
    a.engine:Start("gra_inn"); a.screen="battle"; a.modal=nil
    a.engine.battle.playerWait=0
    local row=a:SelectBattleCommand("request"); assert(row)
    a.state.properties[row.id].independenceRisk=C.battle.riskMax-1
    a:Act("confirm")
    local group,defect=false,false
    for _,k in ipairs(played) do if k=="groupDiscovery" then group=true end; if k=="defection" then defect=true end end
    assert(group and defect,"sounds: "..table.concat(played,","))
    eq(C.uiSounds.groupDiscovery,"SKILL_LINE_ADDED"); eq(C.uiSounds.groupCall,"ANTIQUITIES_FANFARE_COMPLETED")
    PBTrade.Audio.Play=play
end)
test("story preserves Japanese when the client cannot split the byte pattern",function()
    local original=string.gmatch
    string.gmatch=function() return function() return nil end end
    local ok,timeline=pcall(PBTrade.Story.Timeline,"日本語の本文を消さない。")
    string.gmatch=original
    assert(ok); eq(table.concat(timeline.chars),"日本語の本文を消さない。")
    eq(PBTrade.Story.Visible(timeline,0),0)
end)
test("opening narration completes then advances on confirm and leads to naming",function()
    local played={}; local play=PBTrade.Audio.Play; PBTrade.Audio.Play=function(kind) played[#played+1]=kind; return true end
    local St=PBTrade.Story; eq(#D.opening,8)
    for _,page in ipairs(D.opening) do assert(PBTrade.Assets==nil or true); assert(page.bg and page.text~="") end
    -- Pauses after punctuation: the character after "。" appears later than a plain one would.
    local t=St.Timeline("あ。い"); eq(#t.chars,3); assert(t.times[3]-t.times[2]>t.times[2]-t.times[1]+.3)
    eq(St.Visible(t,0),0); eq(St.Visible(t,t.times[1]),1); eq(St.Visible(t,t.total),3)
    local a=A.New(); a:ShowTitle(); a:Act("confirm")
    eq(a.screen,"opening"); eq(a.opening.page,1); eq(played[#played],"openingStart")
    assert(a:ShowOpening("title","missing_story")==false); eq(a.screen,"opening")
    eq(a:OpeningPage().text,D.opening[1].text)
    local mixed=St.Timeline("A商会😀。")
    eq(#mixed.chars,5); eq(mixed.chars[4],"😀")
    eq(table.concat(mixed.chars),"A商会😀。")
    a:Act("confirm"); eq(a.opening.page,1)
    local _,timeline=a:OpeningPage(); eq(St.Visible(timeline,a.opening.time),#timeline.chars)
    a:Act("confirm"); eq(a.opening.page,2); eq(played[#played],"openingPage")
    for _=3,#D.opening do a:Tick(60); a:Act("confirm") end
    eq(a.opening.page,#D.opening); a:Tick(60); a:Act("confirm")
    eq(a.screen,"naming"); eq(a.opening,nil); eq(played[#played],"openingEnd"); assert(a.namingFirst)
    -- Replay from the title returns to the title; ○ skips at any point.
    M.SetCompanyName(a.state,"試験商会"); a:ShowTitle(); a.index=3; a:Act("confirm"); eq(a.screen,"opening")
    a:Act("back"); eq(a.screen,"title")
    a:ShowOpening("title"); a:ShowTitle(); eq(a.opening,nil)
    PBTrade.Audio.Play=play
end)
test("super-scale groups cover whole regions, the three alliances and all of Tamriel",function()
    for _,a in ipairs(D.alliances) do for _,z in ipairs(a.zones) do assert(D.zoneById[z],a.id.." has unknown zone "..z) end end
    local function has(p,g) for _,id in ipairs(p.groups) do if id==g then return true end end end
    local gra=D.propertyById.grahtwood_trade_01
    assert(has(gra,"grand_grahtwood") and has(gra,"alliance_dominion") and has(gra,"tamriel") and has(gra,"region_grahtwood"))
    assert(not has(D.propertyById.glenumbra_trade_01,"alliance_dominion") and has(D.propertyById.glenumbra_trade_01,"alliance_covenant"))
    assert(has(D.propertyById.cyrodiil_trade_01,"imperial_heartland") and not has(D.propertyById.coldharbour_trade_01,"tamriel"))
    eq(D.groups.grand_grahtwood.name,"グラーウッド大商圏"); eq(D.groups.alliance_dominion.name,"アルドメリ・ドミニオン交易同盟")
    assert(D.groups.alliance_dominion.bonus>D.groups.grand_grahtwood.bonus and D.groups.tamriel.bonus>D.groups.alliance_dominion.bonus)
    -- Owning most of Grahtwood makes the grand market usable; the one-pass status matches the per-group one.
    local s=M.New(); local n=0
    for _,id in ipairs(D.propertyIdsByZone.grahtwood) do local p=s.properties[id]; if M.IsAvailable(s,p) and n<10 then p.owner="player"; n=n+1 end end
    s.learnedGroups.grand_grahtwood=true
    local ids={"grand_grahtwood","alliance_dominion","tamriel","region_grahtwood"}
    local all=M.GroupStatusAll(s,ids)
    for _,id in ipairs(ids) do local one=M.GroupStatus(s,id); eq(all[id].count,one.count); eq(all[id].bonus,one.bonus) end
    assert(all.grand_grahtwood.usable and not all.alliance_dominion.usable)
    -- Discovery gate: an alliance cannot flash until it is already usable at its full minimum.
    local e=E.New(s,function() return 0 end); e.battle={log={},events={}}; local p=s.properties.grahtwood_trade_01; p.owner="player"
    for _=1,20 do e:DiscoverGroup(p) end; assert(not s.learnedGroups.alliance_dominion and not s.learnedGroups.tamriel)
    local owned=M.GroupStatus(s,"alliance_dominion").count
    for _,z in ipairs(D.alliances[1].zones) do for _,id in ipairs(D.propertyIdsByZone[z]) do
        local q=s.properties[id]; if owned<D.groups.alliance_dominion.minimum and q.owner~="player" and M.IsAvailable(s,q) then q.owner="player"; owned=owned+1 end end end
    for _=1,20 do e:DiscoverGroup(p) end; assert(s.learnedGroups.alliance_dominion)
    -- The battle list shows super-scale groups first with a tag.
    local a=A.New(); a.state=s; a.engine=E.New(s,function() return .5 end); a.engine:Start("auridon_trade_01"); a.screen="battle"; a.battleCategory=2
    local rows=a:Rows(); assert(rows[1].label:find("^【同盟】") or rows[1].label:find("^【大商圏】"))
end)
test("domestic affairs sit between defense and settlement with three costed actions",function()
    local a=A.New(function() return .99 end); a.modal=nil; local s=a.state; s.cash=C.Money(200000)
    a.engine:Start("gra_inn"); a.engine:Finish("lost"); a.screen="result"; a:Act("confirm")
    eq(a.screen,"admin"); eq(a.admin.left,C.admin.actions); assert(a.fx.text:find("内政",1,true))
    local function pick(command) for i,row in ipairs(a:Rows()) do if row.command==command then a.index=i; return row end end end
    -- 1) Invest: value and profit rise permanently; repeats cost more.
    local p=M.Owned(s)[1]; local value,profit,cost=p.marketValue,p.expectedProfit,M.InvestCost(s,p)
    pick("invest"); a:Act("confirm"); eq(a.screen,"admin_pick")
    for i,row in ipairs(a:Rows()) do if row.id==p.id then a.index=i end end
    local cash=s.cash; a:Act("confirm"); eq(a.screen,"admin"); eq(a.admin.left,2)
    eq(s.cash,cash-cost); eq(p.marketValue,math.floor(value*1.1)); eq(p.expectedProfit,math.floor(profit*1.12)); eq(p.investCount,1)
    assert(M.InvestCost(s,p)>cost)
    -- ○ in the picker returns without spending an action.
    pick("lobby"); a:Act("confirm"); eq(a.screen,"admin_pick"); a:Act("back"); eq(a.screen,"admin"); eq(a.admin.left,2)
    -- 2) Lobby: independence risk falls.
    p.independenceRisk=70; pick("lobby"); a:Act("confirm"); for i,row in ipairs(a:Rows()) do if row.id==p.id then a.index=i end end
    a:Act("confirm"); eq(p.independenceRisk,40); eq(a.admin.left,1)
    -- 3) Guard: halves the counterattack chance for two settlements.
    pick("guard"); a:Act("confirm"); eq(s.guardPeriods,2); eq(a.admin.left,0)
    -- Out of actions: every action is refused and the cursor waits on "finish".
    eq(a:Selected().command,"finish"); pick("invest"); local before=s.cash; a:Act("confirm"); eq(a.screen,"admin"); eq(s.cash,before)
    assert(a:Rows()[1].command=="finish" and a:Rows()[1].detailText:find("増資",1,true))
    pick("finish"); a:Act("confirm"); eq(a.screen,"rankings"); a:Act("confirm") -- settlement
    eq(s.guardPeriods,1); eq(s.cycles,1)
    -- Same rival (first draw 0), same roll .10: under its normal chance, over the halved one.
    local function sequence() local n=0; return function() n=n+1; return n==1 and 0 or .10 end end
    local plain=M.New(); local guarded=M.New(); guarded.guardPeriods=1
    local _,m1=M.RollCounterattack(plain,sequence()); local _,m2=M.RollCounterattack(guarded,sequence())
    assert(not m1:find("ありませんでした") and m2:find("ありませんでした"),m1.." / "..m2)
    -- 4) Repay appears only with debt, pays up to half the cash and raises reputation.
    s.debt=C.Money(10000); s.cash=C.Money(6000); a:StartAdministration(); local row=pick("repay"); assert(row)
    local rep=s.reputation; a:Act("confirm"); eq(s.debt,C.Money(7000)); eq(s.cash,C.Money(3000)); eq(s.reputation,rep+2)
    s.debt=0; a:StartAdministration(); eq(pick("repay").enabled,false)
    -- Saved: investment counts and the guard contract survive a reload.
    local loaded=M.Load(M.Export(s)); eq(loaded.properties[p.id].investCount,1); eq(loaded.guardPeriods,1)
end)
test("domestic affairs offer eight actions: divest, bonds, sabotage and hiring included",function()
    local a=A.New(function() return .1 end); a.modal=nil; local s=a.state; s.cash=C.Money(100000)
    a:StartAdministration()
    local commands={}; for _,row in ipairs(a:Rows()) do if row.command~="finish" then commands[#commands+1]=row.command end end
    eq(table.concat(commands,","),"invest,lobby,divest,guard,repay,bond,sabotage,hire,alliance")
    local function pick(command) for i,row in ipairs(a:Rows()) do if row.command==command then a.index=i; return row end end end
    -- Divest: the property leaves for 80% of its value.
    local p=M.Owned(s)[1]; local owned=#M.Owned(s); local cash=s.cash; local price=math.floor(p.marketValue*.8)
    pick("divest"); a:Act("confirm"); eq(a.screen,"admin_pick"); for i,row in ipairs(a:Rows()) do if row.id==p.id then a.index=i end end
    a:Act("confirm"); eq(p.owner,"neutral"); eq(#M.Owned(s),owned-1); eq(s.cash,cash+price); eq(a.admin.left,2)
    -- Bond: cash now, debt with interest; refused past the debt ceiling.
    cash=s.cash; local debt=s.debt; local amount=M.BondAmount(s)
    pick("bond"); a:Act("confirm"); eq(s.cash,cash+amount); eq(s.debt,debt+math.ceil(amount*1.1)); eq(a.admin.left,1)
    s.debt=10^12; assert(not M.Bond(s)); s.debt=debt+math.ceil(amount*1.1)
    -- Sabotage: success drains the rival; failure is a scandal that raises counterattack odds.
    pick("sabotage"); a:Act("confirm"); eq(a.screen,"admin_pick"); local row=a:Rows()[1]; local rival=row.company; local before=rival.cash
    a:Act("confirm"); eq(rival.cash,before-math.floor(before*.12)); eq(a.admin.left,0)
    local t=M.New(); t.cash=C.Money(5000); local ok,_,result=M.Sabotage(t,"amber",function() return .99 end)
    assert(ok and not result.success and t.scandalPeriods==1 and t.reputation==45)
    local function sequence(v) local n=0; return function() n=n+1; return n==1 and 0 or v end end
    -- The small-portfolio protection lowers both odds; .20 stays between the ordinary and
    -- scandal-modified chances and therefore proves that a failed operation still matters.
    local _,plain=M.RollCounterattack(M.New(),sequence(.2)); local _,bold=M.RollCounterattack(t,sequence(.2))
    assert(plain:find("ありませんでした") and not bold:find("ありませんでした"))
    M.SettleCycle(t); eq(t.scandalPeriods,0)
    -- Hire: the next negotiation opens with momentum and quicker messengers, once.
    local h=M.New(); h.cash=C.Money(5000); assert(M.Hire(h)); eq(h.envoyBattles,1); assert(not M.Hire(h))
    local e=E.New(h,function() return .5 end); assert(e:Start("gra_inn"))
    assert(e.battle.momentum>=C.admin.hireMomentum-1e-9 and e:PlayerWaitDuration()<C.battle.playerWait); eq(h.envoyBattles,0)
    e:Finish("withdrawn"); e.battle=nil; assert(e:Start("gra_inn")); eq(e.battle.momentum,0)
    local loaded=M.Load(M.Export(t)); eq(loaded.scandalPeriods,0)
end)
test("owning every headquarters of a rival dissolves it and brings all its properties under the player",function()
    local played={}; local play=PBTrade.Audio.Play; PBTrade.Audio.Play=function(kind) played[#played+1]=kind; return true end
    local s=M.New(); s.chapter=2; M.Unlock(s); s.unlocked.stros=true
    local amberCount=#M.Owned(s,"amber"); assert(amberCount>10)
    eq(D.headquartersOf.str_hq,"amber"); assert(D.propertyById.str_hq.companyHeadquarters=="amber")
    local e=E.New(s,function() return .5 end); assert(e:Start("str_hq")); local cash=s.companies.amber.cash
    local owned=#M.Owned(s); e:Finish("won")
    local t=e.battle.takeover; assert(t and t.company=="amber" and t.count==amberCount-1)
    eq(#M.Owned(s,"amber"),0); eq(#M.Owned(s),owned+amberCount); assert(s.companies.amber.dissolved)
    eq(t.cash,math.floor(cash*C.takeover.cashShare))
    for _,r in ipairs(M.Rankings(s)) do assert(r.id~="amber") end
    local deals=M.RivalTurn(s,function() return 0 end); for _,d in ipairs(deals) do assert(d.buyer~="amber") end
    local restored=M.Load(M.Export(s)); assert(restored.companies.amber.dissolved); eq(#M.Owned(restored,"amber"),0)
    -- Multi-headquarters rivals fall only once every headquarters is held.
    local v=M.New(); v.chapter=3; M.Unlock(v)
    v.properties.grahtwood_trade_24.owner="player"; v.properties.deshaan_trade_24.owner="player"
    eq(M.Takeover(v,"deshaan_trade_24"),nil); v.properties.rivenspire_trade_24.owner="player"
    assert(M.Takeover(v,"rivenspire_trade_24")); assert(v.companies.veil.dissolved)
    -- The controller flashes the takeover and sounds the horn for counterattacks.
    local a=A.New(function() return 0 end); a.state.chapter=2; a.state.unlocked.stros=true
    assert(a.engine:Start("str_hq")); a.screen="battle"; a.engine:Finish("won"); a:Tick(.1)
    eq(a.fx.kind,"takeover"); assert(played[#played]=="takeover")
    a:Act("confirm"); if a.screen=="battle" then
        assert(played[#played-1]=="counterattackWarning" and played[#played]=="counterattack")
    end
    eq(C.uiSounds.counterattackWarning,"GENERAL_ALERT_ERROR"); eq(C.uiSounds.counterattack,"AVA_KEEP_CAPTURED"); eq(C.uiSounds.takeover,"GUILD_KEEP_CLAIMED")
    PBTrade.Audio.Play=play
end)
test("ordinary takeovers are immediate, bosses wait for their chapter, and a period can pass without a negotiation",function()
    local s=M.New(); eq(s.chapter,1); s.properties.str_hq.owner="player"
    eq(M.Takeover(s,"str_hq"),nil); assert(not s.companies.amber.dissolved)
    s.chapter=2; local ordinary=M.Takeover(s,"str_hq"); assert(ordinary and ordinary.company=="amber" and s.companies.amber.dissolved)
    local v=M.New(); v.chapter=2
    for _,id in ipairs(D.companyHeadquarters.veil) do v.properties[id].owner="player" end
    eq(M.Takeover(v,D.companyHeadquarters.veil[1]),nil); assert(not v.companies.veil.dissolved)
    v.chapter=3; local reports=M.CheckTakeovers(v)
    eq(#reports,1); eq(reports[1].company,"veil"); assert(v.companies.veil.dissolved)
    eq(#M.CheckTakeovers(s),0)
    -- Skipping: counterattack check, domestic affairs, rankings and settlement still happen.
    local a=A.New(function() return .99 end); a.modal=nil; a.screen="management"
    for i,row in ipairs(a:Rows()) do if row.command=="skip" then a.index=i end end
    a:Act("confirm"); eq(a.screen,"admin"); a:FinishAdministration(); eq(a.screen,"rankings")
    a:Act("confirm"); eq(a.state.cycles,1)
end)
test("every landed coin stays visible: resting in its slot until the pile covers it",function()
    local V=PBTrade.Coins
    for _,bid in ipairs({250,20000,400000,1e9}) do
        local v=V.New(4000); v:SetBid(1,bid); local side=v.sides[1]
        local events=side.batches[1].events
        -- Each sprite targets exactly the drawn coin position of its slot.
        for _,e in ipairs(events) do eq(e.pillar,(e.k-1)%16+1); eq(e.level,math.floor((e.k-1)/16)) end
        local seenResting=false
        for _=1,30*6 do
            v:Tick(1/30); local frame=v:Frame(1)
            local resting={}; for _,c in ipairs(side.resting) do resting[c]=true; seenResting=true end
            local shown=math.floor(side.displayed)
            for _,e in ipairs(events) do
                if e.landed then assert(e.k<=shown or resting[e],"coin vanished for bid "..bid) end
            end
            assert(#frame.coins<=C.coins.limit)
        end
        assert(math.abs(side.displayed-V.VisualCount(side.target))<1e-6)
        -- A fractional final visual unit keeps one representative coin in the next slot.
        -- Integer piles are fully absorbed by the generated stack.
        assert(#side.resting<=1)
        if #side.resting==1 then assert(side.resting[1].k>math.floor(side.displayed)) end
        if bid>=20000 then assert(seenResting) end
    end
end)
test("a negotiation day passes after three commands or fifteen seconds, whichever comes first",function()
    local limit=C.battle.gaugeLimit; C.battle.gaugeLimit=1e9 -- keep the negotiation open while the clock runs
    local s=M.New(); s.cash=C.Money(100000); local e=E.New(s,function() return .5 end); assert(e:Start("gra_inn"))
    local b=e.battle; eq(b.day,1); b.enemyWait=999
    for _=1,2 do b.playerWait=0; assert(e:Treasury(C.Money(100))) end; eq(b.day,1)
    for _=1,60*10 do e:Step(1/60) end; eq(b.day,1)          -- 10 s and 2 commands: still day 1
    b.playerWait=0; assert(e:Treasury(C.Money(100))); eq(b.day,2)      -- third command
    for _=1,60*14 do e:Step(1/60) end; eq(b.day,2)
    for _=1,60 do e:Step(1/60) end; eq(b.day,3)               -- 15 s without three commands
    b.playerWait=0; assert(e:Treasury(C.Money(100))); b.playerWait=0; assert(e:Treasury(C.Money(100))); eq(b.day,3)
    for _=1,60*14 do e:Step(1/60) end; eq(b.day,3); b.playerWait=0; assert(e:Treasury(C.Money(100))); eq(b.day,4)
    C.battle.gaugeLimit=limit
end)
test("background music follows the screen, restores the previous mode, can be toggled, and survives a refusal",function()
    local Au=PBTrade.Audio; local current=0; local calls={}
    OVERRIDE_MUSIC_MODE_NONE=0; OVERRIDE_MUSIC_MODE_CHAMPION=1; OVERRIDE_MUSIC_MODE_TRIBUTE=2; OVERRIDE_MUSIC_MODE_DUELING=3; OVERRIDE_MUSIC_MODE_CREDITS=4
    SetOverrideMusicMode=function(mode) calls[#calls+1]=mode; current=mode end
    GetOverrideMusicMode=function() return current end
    Au.musicBroken=nil; Au.musicOn=nil; Au.musicYielded=nil; Au.musicEnabled=true
    current=9 -- whatever the zone had
    assert(Au.SyncMusic("title")); eq(current,4)
    Au.SyncMusic("map"); eq(current,2); Au.SyncMusic("admin"); eq(current,2); eq(#calls,2)
    Au.SyncMusic("battle"); eq(current,3); Au.SyncMusic("result"); eq(current,3)
    Au.StopMusic(); eq(current,9) -- handed back
    -- Another system takes the override: step aside instead of fighting it.
    Au.SyncMusic("map"); current=7; eq(Au.SyncMusic("battle"),false); eq(current,7); Au.StopMusic(); eq(current,7)
    local saved={}; local a=A.New(nil,saved); a.modal=nil; a.screen="management"
    for i,row in ipairs(a:Rows()) do if row.command=="music" then a.index=i end end
    a:Act("confirm"); eq(saved.music,false); assert(not Au.musicEnabled); eq(Au.SyncMusic("map"),false)
    a:Act("confirm"); eq(saved.music,true); Au.StopMusic()
    -- A client that refuses the call: no error escapes, music is disabled for the session.
    SetOverrideMusicMode=function() error("Attempt to access a private function") end
    eq(Au.SyncMusic("map"),false); assert(Au.musicBroken)
    SetOverrideMusicMode=nil; GetOverrideMusicMode=nil
    OVERRIDE_MUSIC_MODE_NONE=nil; OVERRIDE_MUSIC_MODE_CHAMPION=nil; OVERRIDE_MUSIC_MODE_TRIBUTE=nil; OVERRIDE_MUSIC_MODE_DUELING=nil; OVERRIDE_MUSIC_MODE_CREDITS=nil
    Au.musicBroken=nil; Au.musicOn=nil; Au.musicYielded=nil; Au.musicEnabled=true
end)
test("alliances: formed in domestic affairs, fund negotiations, never attack, and break when strained",function()
    local seq={}; local function rng() return table.remove(seq,1) or .5 end
    local a=A.New(rng); a.modal=nil; local s=a.state; s.chapter=2; M.Unlock(s); s.cash=C.Money(100000)
    a:StartAdministration()
    local function pick(command) for i,row in ipairs(a:Rows()) do if row.command==command then a.index=i; return row end end end
    pick("alliance"); a:Act("confirm"); eq(a.screen,"admin_pick")
    local amberIndex; for i,row in ipairs(a:Rows()) do if row.id=="amber" then amberIndex=i end end
    a.index=amberIndex; seq={0}; a:Act("confirm")
    assert(M.IsAllied(s,"amber")); eq(s.alliances.amber.trust,C.alliance.startTrust)
    -- Failure keeps the gift; Molag Bal refuses outright; the maximum is two.
    local t=M.New(); t.cash=C.Money(100000); local ok,_,formed=M.ProposeAlliance(t,"ash",function() return .99 end); assert(ok and not formed and t.cash<C.Money(100000))
    t.chapter=5; assert(not M.CanAlly(t,"molag"))
    M.ProposeAlliance(t,"ash",function() return 0 end); M.ProposeAlliance(t,"ink",function() return 0 end)
    local okMore=M.CanAlly(t,"iron"); assert(not okMore)
    -- Allies never counterattack.
    local u=M.New(); u.chapter=2; M.Unlock(u); for id in pairs(u.companies) do if id~="player" and id~="neutral" and id~="amber" then u.companies[id].cash=0 end end
    assert(M.RollCounterattack(u,function() return 0 end)); u.alliances.amber={trust=70}; eq(M.RollCounterattack(u,function() return 0 end),nil)
    -- Funding: the ally's cash backs our bid, once per negotiation, at a trust cost.
    local e=a.engine; e.battle=nil; assert(e:Start("gra_inn")); e.battle.playerWait=0; a.screen="battle"; a.modal=nil; a.battleCategory=2
    local row=a:Rows()[1]; eq(row.command,"ally"); assert(row.label:find("ドフォーレ商会",1,true))
    local cash=s.companies.amber.cash; local amount=M.AllianceFundAmount(s,"amber")
    a.index=1; a:Act("confirm"); eq(e.battle.playerBid,amount); eq(s.companies.amber.cash,cash-amount)
    eq(s.alliances.amber.trust,C.alliance.startTrust-C.alliance.fundTrust); eq(a:Rows()[1].enabled,false)
    -- Allied property display and warning; buying the ally's properties breaks the alliance.
    a.screen="properties"; a.zone="stros"; s.unlocked.stros=true
    local target; for _,id in ipairs(D.propertyIdsByZone.stros) do local p=s.properties[id]; if p.owner=="amber" and not p.isHeadquarters then target=p; break end end
    assert(a:Detail(target):find("同盟・信頼",1,true))
    e:Finish("withdrawn"); e.battle=nil
    for i,r in ipairs(a:Rows()) do if r.id==target.id then a.index=i end end
    a.modal=nil; a:Act("confirm"); assert(a.modal and a.modal.text:find("信頼 -35",1,true))
    a.modal=nil; assert(e:Start(target.id)); e:Finish("won"); assert(M.IsAllied(s,"amber")); eq(e.battle.allianceStrained,"amber")
    local second; for _,id in ipairs(D.propertyIdsByZone.stros) do local p=s.properties[id]; if p.owner=="amber" and not p.isHeadquarters then second=p; break end end
    e.battle=nil; assert(e:Start(second.id)); e:Finish("won"); eq(e.battle.allianceBroken,"amber"); assert(not M.IsAllied(s,"amber"))
    -- Trust recovers each settlement and survives a save.
    local w=M.New(); w.alliances.ash={trust=40}; M.SettleCycle(w); eq(w.alliances.ash.trust,46)
    local loaded=M.Load(M.Export(w)); eq(loaded.alliances.ash.trust,46)
end)
test("real places are priced by what they are: banks dear, taverns modest, unknowns at the market norm",function()
    local L=PBTrade.LiveCatalog
    local special,specialProfit,specialTier=L.BaseValue("special","トール・ドライオク",1)
    local specialValue=C.Money(100000000000000)
    eq(special,specialValue); eq(specialProfit,math.floor(specialValue*.06)); eq(specialTier.label,"最終物件"); assert(specialTier.finalAcquisition)
    eq(L.BaseValue("special2"," トール ドライオク ",999999999),specialValue)
    local bank=L.BaseValue("t1","ダガーフォール銀行"); local palace=L.BaseValue("t2","センチネル王宮")
    local tavern=L.BaseValue("t3","酔いどれライオン亭"); local camp=L.BaseValue("t4","盗賊の野営地")
    local unknown,_,tier=L.BaseValue("t5","ミストラルの囁き")
    eq(tier,nil); assert(bank>palace and palace>tavern*10 and tavern>camp and bank>unknown*15,bank.." "..palace.." "..tavern.." "..camp.." "..unknown)
    local roundingTolerance=60*C.currencyScale
    assert(unknown>=C.canonical.base*(1-C.canonical.jitter)-roundingTolerance and unknown<=C.canonical.base*(1+C.canonical.jitter)+roundingTolerance)
    eq(L.ValueTier("Vulkhel Guard Bank").label,"銀行"); eq(L.ValueTier("The Drunken Lion Tavern").label,"酒場")
    -- Descriptions do not sway the tier (flavour text often mentions ruins or towns).
    eq(L.ValueTier("月光の見晴らし"),nil)
    -- The reference price is the current average regular property: an unrecognised place sits
    -- near it, a bank far above it, and both follow the market as it grows.
    local s=M.New(); local avg=M.MarketAverage(s)
    local plain={id="t6",name="ミストラルの囁き",marketValue=1,expectedProfit=1,category="market"}; M.PriceCanonical(s,plain)
    assert(math.abs(plain.marketValue-avg)<=avg*C.canonical.jitter+roundingTolerance,plain.marketValue.." vs "..avg)
    for _,q in pairs(s.properties) do if not q.canonical then q.marketValue=q.marketValue*5 end end
    local later={id="t6",name="ミストラルの囁き",marketValue=1,expectedProfit=1,category="market"}; M.PriceCanonical(s,later)
    assert(math.abs(later.marketValue/plain.marketValue-5)<.05)
    local vault={id="t7",name="ダガーフォール銀行",marketValue=1,expectedProfit=1,category="market",investCount=1}; M.PriceCanonical(s,vault)
    assert(vault.marketValue>M.MarketAverage(s)*20 and vault.valueTier=="銀行")
    -- Old saves: real places are re-priced once by tier and market, owners kept.
    local z=D.zoneById.auridon
    local def={id="eso_location_auridon_1",name="オーリドン銀行",zone="auridon",category="market",marketValue=5000,expectedProfit=250,
        owner="neutral",independenceRisk=10,independenceIncrease=8,gaugeAcceleration=1,groups={},negotiationResistances={},
        isHeadquarters=false,canonical=true,requiresVisit=true,canonicalSource="eso_location",minChapter=1}
    local old=M.Export(M.New()); old.canonicalValuation=nil; old.cycles=50
    old.canonicalProperties[def.id]=def; old.properties[def.id]={owner="player",marketValue=5000,expectedProfit=250,reserve=100,independenceRisk=10}
    local loaded=M.Load(old); local q=loaded.properties[def.id]
    eq(q.owner,"player"); eq(q.valueTier,"銀行"); assert(q.marketValue>M.MarketAverage(loaded)*20); eq(loaded.canonicalValuation,C.canonical.version)
    local again=M.Load(M.Export(loaded)); eq(again.properties[def.id].marketValue,q.marketValue) -- only once
    -- A previously registered special place is migrated to its exact fixed baseline.
    local specialDef={id="eso_location_glenumbra_tor_dryoch",name="トール・ドライオク",zone="glenumbra",category="market",
        marketValue=12345,expectedProfit=500,owner="neutral",independenceRisk=10,independenceIncrease=8,gaugeAcceleration=1,
        groups={},negotiationResistances={},isHeadquarters=false,canonical=true,requiresVisit=true,canonicalSource="eso_location",minChapter=1}
    local specialOld=M.Export(M.New()); specialOld.canonicalValuation=2
    specialOld.canonicalProperties[specialDef.id]=specialDef
    specialOld.properties[specialDef.id]={owner="neutral",marketValue=12345,expectedProfit=500,reserve=100,independenceRisk=10}
    local specialLoaded=M.TrueEndingProperty(M.Load(specialOld))
    eq(specialLoaded.marketValue,specialValue); eq(specialLoaded.expectedProfit,math.floor(specialValue*.06)); eq(specialLoaded.valueTier,"最終物件"); assert(specialLoaded.finalAcquisition)
end)
test("catalog amounts use gold units with stable sub-ten-thousand remainders",function()
    local p=D.propertyById.aur_jewel
    eq(p.marketValue,C.Money(9500,"aur_jewel:value"))
    eq(p.expectedProfit,C.Money(480,"aur_jewel:profit"))
    assert(p.marketValue>=9500*C.currencyScale and p.marketValue<9501*C.currencyScale)
    assert(p.marketValue%C.currencyScale~=0)
    eq(C.campaign.startingCash,C.Money(6500,"player:cash"))
    eq(D.campaigns[5].objective.assetTarget,C.Money(100000000000000))
end)
test("real places: explicit registration moves them ahead of unvisited places",function()
    local function place(id,name)
        local p={id=id,name=name,zone="auridon",category="tavern",marketValue=8000,expectedProfit=500,owner="neutral",
            independenceRisk=10,independenceIncrease=8,gaugeAcceleration=1,groups={},negotiationResistances={},
            isHeadquarters=false,canonical=true,requiresVisit=true,canonicalSource="eso_location",minChapter=1}
        D.properties[#D.properties+1]=p; D.AddProperty(p); return p
    end
    local seen=place("order_seen","試験の港酒場"); local unseen=place("order_unseen","試験の丘酒場")
    local saved={tutorialComplete=true,pendingVisits={{key="auridon|x",zoneId="auridon",name="試験の港酒場"}}}
    local a=A.New(nil,saved)
    assert(not a.state.visitedProperties[seen.id])
    a.currentLocationRecord=saved.pendingVisits[1]; a.currentRegistration=seen
    assert(a:ConfirmCurrentRegistration()); eq(a.fx.kind,"discovery")
    a.modal=nil; a.screen="properties"; a.zone="auridon"
    local rows=a:Rows(); eq(rows[1].id,"order_seen"); eq(rows[#rows].id,"order_unseen")
    local total,visited=M.ZoneLandmarks(a.state,"auridon"); assert(total>=2 and visited>=1)
end)
test("company names keep every Japanese character intact, whatever their bytes",function()
    -- 銀 (E9 8A 80) and 局 (E5 B1 80) end in byte 0x80, like the full-width space.
    for _,name in ipairs({"銀河郵便局","銀の天秤商会","局","アバ商店","黒猫亭"}) do
        eq(M.NormalizeCompanyName(name),name); eq(M.NormalizeCompanyName("　 "..name.." 　"),name)
        eq(M.NormalizeCompanyName(M.NormalizeCompanyName(name)),name)
    end
    eq(M.NormalizeCompanyName("　　"),nil); eq(M.NormalizeCompanyName("a\nb"),"a b")
    eq(M.NormalizeCompanyName("PinkBanther商会"),"PinkBanther商会")
    -- The PS5 client did not return Japanese matches for the old byte-range gmatch.
    -- Name normalization must no longer call gmatch at all.
    local original=string.gmatch
    string.gmatch=function() error("console byte-range matcher unavailable") end
    local ok,normalized=pcall(M.NormalizeCompanyName,"PinkBanther商会")
    string.gmatch=original
    assert(ok); eq(normalized,"PinkBanther商会")
    -- Typing a name ending in 局 during the first naming no longer errors, and it sticks.
    local a=A.New(); a.modal=nil; a.namingFirst=true; a.screen="naming"
    assert(a:SubmitTypedName("銀河郵便局")); eq(a.state.companyName,"銀河郵便局"); eq(a.screen,"map")
    -- A name that cannot be stored keeps the naming screen instead of failing.
    local b=A.New(); b.modal=nil; b.namingFirst=true; b.screen="naming"; b.pendingName="　"
    eq(b:AcceptCompanyName(),false); eq(b.screen,"naming"); eq(b.state.companyName,nil)
end)
test("after chapter five: Tor Dryoch is the gated one-hundred-kei final acquisition",function()
    local a=A.New(function() return .5 end); a.modal=nil; local s=a.state
    M.SetCompanyName(s,"銀河郵便局"); s.chapter=5; M.Unlock(s)
    local final=M.TrueEndingProperty(s); assert(final and final.name=="トール・ドライオク")
    eq(final.marketValue,C.Money(100000000000000)); assert(final.finalAcquisition and M.IsCriticalProperty(s,final))
    assert(not M.IsAvailable(s,final),"the final acquisition must stay closed before chapter five completion")
    s.campaignComplete=true
    assert(M.IsAvailable(s,final)); assert(not M.CheckTrueEnding(s))
    -- The chapter ending offers the last acquisition; starting it does not confiscate holdings.
    local owned=#M.Owned(s)
    a.modal={campaign=true,action="endlessOffer",text="交易戦終結"}; a:Act("confirm")
    assert(s.endless and a.modal and a.modal.text:find("最後の大買収",1,true)); eq(#M.Owned(s),owned)
    local status=M.CampaignStatus(s); assert(status.endless and not status.registered and status.short:find("物件登録",1,true))
    assert(a:TitleStatus():find("最後の大買収",1,true)); eq(M.AdvanceCampaign(s),nil)
    eq(M.StartEndless(s,math.random),nil) -- once only
    -- Unregistered ownership cannot complete it; registration and the manual realtime purchase can.
    final.owner="player"; assert(not M.CheckTrueEnding(s)); final.owner="neutral"; s.visitedProperties[final.id]=true
    local canDelegate,why=M.CanDelegate(s,final); assert(not canDelegate and why:find("重要物件",1,true))
    status=M.CampaignStatus(s); assert(status.registered and status.short:find("100京",1,true))
    local loaded=M.Load(M.Export(s)); assert(loaded.endless and not loaded.trueEnding)
    a.modal=nil; a.engine.battle=nil; assert(a.engine:Start(final.id)); a.engine:Finish("won"); a.screen="result"; a:Act("confirm")
    assert(s.trueEnding); eq(a.screen,"opening"); eq(a.opening.story,"trueEnding"); eq(a.opening.next,"title")
    local page=a:OpeningPage(); assert(page.text~="")
    local last=a.opening.pages[#a.opening.pages].text; assert(last:find("銀河郵便局",1,true))
    -- Ember's farewell comes after the recap and before the closing page; the story ends on the title.
    local pages=a.opening.pages; local emberPages=0; local firstEmber
    for i,pg in ipairs(pages) do if pg.portrait=="ember" then emberPages=emberPages+1; firstEmber=firstEmber or i; eq(pg.speaker,"エンバー") end end
    assert(emberPages>=4 and firstEmber>1 and pages[#pages].portrait==nil and pages[firstEmber-1].portrait==nil)
    for i=firstEmber,firstEmber+emberPages-1 do assert(pages[i].portrait=="ember" and pages[i].text:find("「",1,true)) end
    assert(pages[firstEmber].text:find("銀河郵便局",1,true),"Ember greets the company by name")
    a:Act("back"); eq(a.screen,"title"); eq(a.opening,nil)
    -- Rewatch from the title; the ending only triggers once.
    a:ShowTitle(); local found; for i,row in ipairs(a:Rows()) do if row.command=="trueEnding" then found=i end end
    assert(found); a.index=found; a:Act("confirm"); eq(a.screen,"opening"); a:Act("back"); eq(a.screen,"title")
    eq(M.CheckTrueEnding(s),false)
    -- Starting later from the management ledger also opens the final challenge.
    local b=A.New(); b.modal=nil; b.state.campaignComplete=true; b.screen="management"
    for i,row in ipairs(b:Rows()) do if row.command=="endless" then b.index=i end end
    b:Act("confirm"); assert(b.state.endless)
end)
test("money reads in 兆・億・万 units, the two largest groups",function()
    local F=M.FormatMoney
    eq(F(6500),"6500"); eq(F(10000),"1万"); eq(F(16050),"1万6050"); eq(F(123456789),"1億2345万")
    eq(F(100000000),"1億"); eq(F(3412345678901),"3兆4123億"); eq(F(15e12),"15兆"); eq(F(-2500000),"-250万")
    eq(M.FormatCompact(99000),"9万9000")
end)
test("a rival's headquarters is defended with the weight of its whole group",function()
    local s=M.New(); s.chapter=2; M.Unlock(s); s.unlocked.stros=true; s.cash=C.Money(10^9)
    s.companies.amber.cash=C.Money(100) -- nearly out of cash: the group's properties must carry the defence
    local hq=s.properties.str_hq; local assets,reserves=M.CompanyAssets(s,"amber")
    local value,isHq=M.NegotiationValue(s,hq); assert(isHq and value==math.max(hq.marketValue,math.floor(assets*C.takeover.hqValueShare)))
    assert(value>hq.marketValue*3,"group value "..value.." vs hq "..hq.marketValue)
    -- An ordinary amber property is still valued alone.
    local other; for _,p in pairs(s.properties) do if p.owner=="amber" and not p.isHeadquarters then other=p; break end end
    eq(M.NegotiationValue(s,other),other.marketValue)
    -- The rival's bids can draw on property reserves beyond its cash, which then fall pro rata.
    local e=E.New(s,function() return .5 end); assert(e:Start("str_hq")); local b=e.battle
    eq(b.baseValue,value); assert(b.headquarters and b.enemyBid>100 and b.enemyBudget>0)
    b.enemyWait=0; e:Step(1/60); e:Finish("lost")
    local _,after=M.CompanyAssets(s,"amber"); assert(after<reserves,"reserves "..reserves.." -> "..after)
    -- The start dialog warns that the whole group defends its headquarters.
    local a=A.New(); a.modal=nil; a.state.chapter=2; M.Unlock(a.state); a.state.unlocked.stros=true
    a.screen="properties"; a.zone="stros"
    for i,r in ipairs(a:Rows()) do if r.id=="str_hq" then a.index=i end end
    a:Act("confirm"); assert(a.modal and a.modal.text:find("グループ全体が総力で守ります",1,true) and a.modal.text:find("交渉価値",1,true))
end)
test("saves are deferred to safe points and skip untouched real places",function()
    local saved={}; local a=A.New(function() return .5 end,saved); a.modal=nil
    a:Save(); eq(saved.state,nil); assert(a.saveDirty)                 -- marked, not written
    a.engine:Start("gra_inn"); a.screen="battle"; a.engine.battle.playerWait=0
    a:SelectBattleCommand("treasury"); a:Act("confirm"); eq(saved.state,nil)
    a.engine:Finish("withdrawn"); a:Tick(.1); eq(a.screen,"result"); assert(saved.state and not a.saveDirty) -- result flushes
    local first=saved.state; a:Save(); a:Tick(30); assert(saved.state==first); a:Tick(31); assert(saved.state~=first) -- 60 s backstop
    -- Untouched real places are not exported, yet come back on load.
    local s=M.New(); local L=PBTrade.LiveCatalog
    local p={id="eso_poi_untouched",name="試験の遺跡",zone="auridon",category="caravan",marketValue=5000,expectedProfit=300,
        owner="neutral",independenceRisk=10,independenceIncrease=8,gaugeAcceleration=1,groups={},negotiationResistances={},
        isHeadquarters=false,canonical=true,requiresVisit=true,canonicalSource="eso_poi",minChapter=1}
    D.properties[#D.properties+1]=p; D.AddProperty(p); L.Index(p); s.properties[p.id]=M.Copy(p)
    local out=M.Export(s); eq(out.properties[p.id],nil); eq(out.canonicalProperties[p.id],nil)
    s.visitedProperties[p.id]=true; out=M.Export(s); assert(out.properties[p.id] and out.canonicalProperties[p.id])
    s.visitedProperties[p.id]=nil; out=M.Export(s)
    local loaded=M.Load(out); assert(loaded.properties[p.id] and loaded.properties[p.id].owner=="neutral")
end)
test("ten-period trade councils combine market events with a chosen policy",function()
    local s=M.New(); s.cycles=10
    local season=assert(M.BeginStrategicSeason(s,function() return 0 end))
    eq(season.event.id,"harvest"); eq(M.BeginStrategicSeason(s,function() return .99 end).event.id,"harvest")
    local ok,policy=M.ChooseTradePolicy(s,"consolidation"); assert(ok); eq(policy.name,"基盤固め")
    assert(not s.strategyPending)
    eq(M.ActivePolicy(s),policy); eq(M.ActiveMarketEvent(s),season.event)
    eq(M.PassiveRecoveryAmount(s),C.independence.passiveRecovery+policy.riskRecovery)
    for _=1,C.strategy.interval do M.SettleCycle(s) end
    eq(s.cycles,20); eq(M.ActivePolicy(s),nil); eq(M.ActiveMarketEvent(s),nil)
    assert(M.BeginStrategicSeason(s,function() return .99 end))
    local loaded=M.Load(M.Export(s)); local a=A.New(function() return 0 end,{state=M.Export(loaded),tutorialComplete=true})
    a:BeginSession(); eq(a.screen,"strategy"); assert(a.strategySeason and a.strategySeason.event.id==loaded.marketEvent)
end)
test("delegation handles routine acquisitions but rejects every critical negotiation",function()
    local s=M.New(); s.chapter=2; s.cash=C.Money(100000000); M.Unlock(s)
    s.unlocked.grahtwood=true; s.unlocked.stros=true
    local routine=s.properties.gra_inn; local critical=s.properties.str_hq
    assert(M.CanDelegate(s,routine)); local ok,why=M.CanDelegate(s,critical)
    assert(not ok and why:find("プレイヤー自身",1,true))
    local before=s.cash; local accepted,report=M.DelegateAcquisition(s,routine.id,function() return 0 end)
    assert(accepted and report.success and routine.owner=="player" and s.cash<before and s.delegatedWins==1)
    local other=s.properties.gra_alchemy; before=s.cash
    accepted,report=M.DelegateAcquisition(s,other.id,function() return 1 end)
    assert(accepted and not report.success and other.owner~="player" and s.cash==before-report.cost and s.delegatedLosses==1)
end)
test("critical realtime negotiations escalate through funded defense phases",function()
    local s=M.New(); s.chapter=2; s.unlocked.stros=true
    local e=E.New(s,function() return .5 end); assert(e:Start("str_hq")); local b=e.battle
    assert(b.critical and b.headquarters and b.criticalStage==0)
    local bid=b.enemyBid; e:NextDay()
    assert(b.criticalStage==1 and b.enemyBid>bid and b.log[#b.log]:find("外郭契約",1,true))
    local ordinary=E.New(s,function() return .5 end); assert(ordinary:Start("str_market")); ordinary:NextDay()
    assert(not ordinary.battle.critical and ordinary.battle.criticalStage==0)
end)
test("the controller requires a policy choice after the tenth settlement",function()
    local a=A.New(function() return .99 end); a.modal=nil; a.state.cycles=9; a.screen="rankings"; a.rankingRows=M.Rankings(a.state)
    a:Act("confirm"); eq(a.state.cycles,10); eq(a.screen,"strategy"); assert(a.strategySeason and #a:Rows()==#D.tradePolicies)
    a.index=1; a:Act("confirm"); assert(a.state.activePolicy and a.modal and a.modal.text:find("採択方針",1,true))
end)
test("stances appear from chapter 2, are stable within a period and guard critical targets",function()
    local s=M.New(); local owned
    for _,d in ipairs(D.properties) do local p=s.properties[d.id]; if p.owner=="amber" and not M.IsCriticalProperty(s,p) then owned=p; break end end
    eq(#M.NegotiationStances(s,owned),0)
    s.chapter=2; local seen={}
    for cycle=1,40 do s.cycles=cycle
        local a,b=M.NegotiationStances(s,owned),M.NegotiationStances(s,owned)
        eq(#a,#b); if a[1] then eq(a[1],"vault"); eq(a[1],b[1]) end; seen[#a]=(seen[#a] or 0)+1
    end
    assert((seen[0] or 0)>0 and (seen[1] or 0)>0)
    local hq; for _,d in ipairs(D.properties) do local p=s.properties[d.id]; if p.companyHeadquarters=="iron" then hq=p; break end end
    for cycle=1,10 do s.cycles=cycle; eq(M.NegotiationStances(s,hq)[1],"courier") end
    s.companies.molag.personality="dominion"; owned.owner="molag"
    for cycle=1,20 do s.cycles=cycle; local list=M.NegotiationStances(s,owned); assert(#list==0 or #list==2) end
end)
test("defending our own property never faces a stance",function()
    local s=M.New(); s.chapter=5
    local p=M.Owned(s)[1]
    for cycle=1,20 do s.cycles=cycle; eq(#M.NegotiationStances(s,p,"molag"),0) end
end)
test("a standing stance discounts money, and the matching counter releases it in full",function()
    local s,e=new(); e:Start("gra_inn"); local b=e.battle; b.enemyWait=999
    b.stances={{id="vault",hits=1,broken=false}}
    local thousand=C.Money(1000); e:Treasury(thousand); eq(b.playerBid,thousand); assert(math.abs(e:PlayerForce()-thousand*.45)<1e-6)
    b.playerWait=0; s.learnedTactics.smile=true; e:UseTactic("smile"); assert(math.abs(e:PlayerForce()-thousand*.45)<1e-6)
    s.learnedTactics.gift=true; s.cash=s.cash+thousand; b.playerWait=0; local velocity=b.velocity
    local ok,info=e:UseTactic("gift"); assert(ok and info.brokenStances[1].id=="vault")
    eq(e:PlayerForce(),thousand); assert(b.velocity<velocity-C.stances.breakVelocity+1e-6)
    b.playerWait=0; e:Treasury(thousand); eq(e:PlayerForce(),thousand*2)
end)
test("critical stances need two counters; courier accelerates the rival until broken",function()
    local s,e=new(); e:Start("gra_inn"); local b=e.battle
    b.stances={{id="courier",hits=2,broken=false}}; b.enemyWait=0; e:Step(1/60)
    assert(math.abs(b.enemyWait-C.battle.enemyWait*b.aiProfile.wait*D.stanceById.courier.enemyWait)<1e-6)
    s.learnedTactics.falseMessenger=true; s.cash=C.Money(10000); b.playerWait=0
    local _,info=e:UseTactic("falseMessenger"); eq(#info.brokenStances,0); eq(info.shakenStance.id,"courier"); eq(b.stances[1].hits,1)
    b.playerWait=0; _,info=e:UseTactic("falseMessenger"); eq(info.brokenStances[1].id,"courier")
    b.enemyWait=0; e:Step(1/60); assert(math.abs(b.enemyWait-C.battle.enemyWait*b.aiProfile.wait)<1e-6)
end)
test("group funding cuts through a bloc stance while single requests are halved",function()
    local s,e=new(); e:Start("gra_inn"); local b=e.battle; b.enemyWait=999
    b.stances={{id="bloc",hits=1,broken=false}}
    local id=M.Owned(s)[1].id; local ok,amount=e:Request(id); assert(ok)
    assert(math.abs(e:PlayerForce()-amount*.5)<1e-6)
    eq(e:FundWeight("group"),1.3)
    e:HitStances(function(st) return st.breakByGroup end); eq(e:PlayerForce(),b.playerBid); eq(e:FundWeight("request"),1)
end)
test("start dialog and property detail explain the stance and the counters in hand",function()
    local a=A.New(function() return .5 end); a.modal=nil; local s=a.state; s.chapter=2
    local p; for _,d in ipairs(D.properties) do local q=s.properties[d.id]; if q.owner=="ink" then p=q; break end end
    local found
    for cycle=1,30 do s.cycles=cycle; if M.NegotiationStances(s,p)[1] then found=true; break end end
    assert(found)
    local text=a:Detail(p); assert(text:find("世論の盾",1,true) and text:find("手持ちの対抗手段：なし",1,true))
    s.learnedTactics.bard=true; assert(a:Detail(p):find("手持ちの対抗手段：吟遊詩人を雇う",1,true))
end)
print(string.format("\n%d core tests passed",count))
