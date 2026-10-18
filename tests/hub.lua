unpack=unpack or table.unpack
for _,f in ipairs({"Config","Data","World","HubData","Hub","Tactics","Story","Model","LiveCatalog","Engine","Coins","Audio","Controller","HubController"}) do dofile("PBsTradeGame/"..f..".lua") end
local H,K,M,A=PBTrade.Hub,PBTrade.HubData,PBTrade.Model,PBTrade.Controller
local count=0
local function test(name,fn) fn();count=count+1; print("PASS "..name) end
local function context() return {chapter=3,cash=1e15,average=1e9} end
test("chapter gate, occupancy, limits and bad inputs preserve state",function()
 local h=H.New(0); local c=context(); c.chapter=2; assert(not H.Build(h,c,"bank",1,1)); c.chapter=3
 assert(not H.Build(h,c,"bank",0,1)); assert(not H.Build(h,c,"bank",0/0,1)); assert(not H.Build(h,c,"bogus",1,1))
 c.cash=0; assert(not H.Build(h,c,"bank",1,1)); c.cash=1e15
 assert(H.Build(h,c,"bank",1,1)); assert(not H.Build(h,c,"market",1,1)); assert(H.Build(h,c,"market",2,1))
 assert(not H.Build(h,c,"market",3,1)); assert(#h.buildings==2 and h.nextBuildingId==3)
end)
test("completion, abilities, next-period income and idempotent settlement",function()
 local h=H.New(100); assert(H.Build(h,context(),"bank",1,1)); assert(H.Abilities(h).capital==0)
 local r=H.Settle(h,101,3); assert(r.net==0 and #r.completed==0)
 H.Settle(h,101,3); assert(h.buildings[1].remainingPeriods==1)
 r=H.Settle(h,102,3); assert(r.net==0 and #r.completed==1 and H.Abilities(h).capital==12)
 r=H.Settle(h,103,3); assert(r.net>0 and h.growth==1)
 assert(H.Settle(h,103,3).net==0 and h.growth==1)
end)
test("old saves preserve cash ownership and cycles without historical payouts",function()
 local s=M.New(); s.chapter=4; s.cycles=300; local save=M.Export(s); save.hub=nil; save.schemaVersion=10
 local loaded=M.Load(save); assert(loaded.cash==s.cash and loaded.cycles==300 and loaded.chapter==4)
 assert(loaded.properties.aur_farm.owner==s.properties.aur_farm.owner)
 assert(loaded.hub.lastSettledCycle==300 and #loaded.hub.buildings==0)
end)
test("hub save is a deep copy, restores construction and rejects corrupt cells",function()
 local s=M.New(); s.chapter=3; H.Build(s.hub,context(),"bank",1,1)
 local save=M.Export(s); s.hub.buildings[1].remainingPeriods=0
 assert(save.hub.buildings[1].remainingPeriods==2)
 local loaded=M.Load(save); assert(loaded.hub.buildings[1].remainingPeriods==2)
 local corrupt=M.Copy(save.hub); corrupt.buildings[2]=M.Copy(corrupt.buildings[1]); corrupt.buildings[2].id=2
 corrupt.buildings[3]={id=3,type="missing",x=4,y=4,paidCost=0}; corrupt.buildings[4]=17
 assert(#H.Load(corrupt,0).buildings==1)
end)
test("build confirmation and cancellation are atomic, no admin action spent",function()
 local a=A.New(nil,{}); a.state.chapter=3; a.state.cash=1e15; a:StartAdministration()
 a.index=2; assert(a:Selected().command=="hub"); a:Act("confirm"); a:Act("confirm") -- dismiss introduction
 local before=a.state.cash; a:Act("confirm"); a:Act("back"); assert(a.state.cash==before and #a.state.hub.buildings==0)
 a:Act("confirm"); a:Act("confirm"); assert(a.state.cash<before and #a.state.hub.buildings==1 and a.admin.left==3)
 local after=a.state.cash; a:ConfirmHubBuild(); assert(a.state.cash==after)
 assert(a.saved.state.hub.buildings[1].remainingPeriods==2)
 a:Act("back"); assert(a.screen=="admin" and a.index==2)
end)
test("view-only ledger cannot construct; abilities cover all five fields",function()
 local a=A.New(); a.state.chapter=3; a.state.hub.introSeen=true; a.screen="management"; a:OpenHub(); a:Act("confirm")
 assert(not a.modal and #a.state.hub.buildings==0)
 for i,f in ipairs(H.Catalogue(3)) do
   local x=(i-1)%4+1; local y=math.floor((i-1)/4)+1
   assert(H.Build(a.state.hub,context(),f.id,x,y))
   for _=1,3 do a.state.cycles=a.state.cycles+1; H.Settle(a.state.hub,a.state.cycles,3) end
 end
 for _,ability in ipairs(K.abilities) do assert(H.Abilities(a.state.hub)[ability.id]>0) end
end)
test("real settlement includes hub net once and long unattended operation is bounded",function()
 local s=M.New(); s.chapter=3; H.Build(s.hub,context(),"market",1,1)
 M.SettleCycle(s); local r=M.SettleCycle(s); assert(#r.hub.completed==1 and r.hub.net==0)
 local control=M.Copy(s); control.hub=H.New(control.cycles)
 local before=s.cash; local base=control.cash
 r=M.SettleCycle(s); M.SettleCycle(control)
 assert(s.cash-before-(control.cash-base)==r.hub.net)
 for _=1,500 do M.SettleCycle(s) end
 assert(#s.hub.buildings==1 and s.hub.lastSettledCycle==s.cycles and s.hub.growth==501)
end)
test("five by five holds 15 buildings (60% capacity) and rejects outside construction",function()
 local h=H.New(0); local c=context(); local cycle=0; local n=0
 for y=1,5 do for x=1,5 do
   if n<H.Capacity(3) then
     assert(H.Build(h,c,"market",x,y)); n=n+1
     cycle=cycle+1; H.Settle(h,cycle,3); cycle=cycle+1; H.Settle(h,cycle,3)
   end
 end end
 assert(#h.buildings==15 and H.Capacity(3)==15 and H.At(h,5,3) and not H.At(h,5,4))
 local ok,why=H.Build(h,c,"bank",5,5); assert(not ok and why:find("上限",1,true))
 assert(not H.Build(h,c,"bank",6,5))
 assert(#H.Load(h,cycle).buildings==15)
end)
test("old 8x8 saves retain every building investment and income after shrinking",function()
 local old=H.New(20); old.version=1
 for y=1,8 do for x=1,8 do
   local id=(y-1)*8+x
   old.buildings[id]={id=id,x=x,y=y,type="market",paidCost=5000000,remainingPeriods=0,level=1}
 end end
 local h=H.Load(old,20)
 assert(#h.buildings==25 and #h.annex==39 and H.At(h,5,5).id==37)
 assert(H.Abilities(h).commerce==64*12)
 local again=H.Load(h,20); assert(#again.buildings==25 and #again.annex==39)
 assert(H.Settle(again,21,3).net==64*(90000-30000))
 local sparse=H.New(10); sparse.buildings={old.buildings[64]}; sparse.buildings[1].remainingPeriods=1
 local moved=H.Load(sparse,10); assert(#moved.buildings==1 and #moved.annex==0)
 assert(moved.buildings[1].id==64 and moved.buildings[1].remainingPeriods==1 and moved.buildings[1].x<=5)
end)
test("empty plot variations are mixed and stable through repeated reads and saves",function()
 local h=H.New(0); local types={}; local before={}
 for y=1,5 do for x=1,5 do local d,v=H.Decoration(h,x,y); types[d or "plain"]=true; before[x..":"..y]=(d or "plain")..v end end
 assert(types.plain and types.tree and types.cypress)
 local restored=H.Load(h,0)
 for y=1,5 do for x=1,5 do local d,v=H.Decoration(restored,x,y); assert(before[x..":"..y]==(d or "plain")..v) end end
 local c=context(); assert(H.Build(h,c,"bank",1,1)); local d,v=H.Decoration(h,1,1)
 assert(before["1:1"]==(d or "plain")..v)
end)
test("promenade connects four edges and keeps trees off its surface",function()
 local h=H.New(0); local count=0
 for y=1,5 do for x=1,5 do
   if H.Ground(x,y)=="hub_walkway" then
     count=count+1; assert(H.Decoration(h,x,y)==nil)
     assert(x==3 or y==3)
   else assert(x~=3 and y~=3) end
 end end
 assert(count==9)
 assert(H.Build(h,context(),"market",3,3)) -- paving does not reserve land
end)
local function ready(id,kind,x,y)
 return {id=id,type=kind,x=x,y=y,paidCost=10000000,remainingPeriods=0,level=1}
end
test("adjacency counts pairs once, ignores diagonal and construction, independent of list order",function()
 local h=H.New(0); h.buildings={ready(1,"market",1,1),ready(2,"warehouse",2,1),ready(3,"bank",3,2)}
 local e=H.Effects(h,3); assert(#e.pairs==1 and e.abilities.commerce==15 and e.abilities.logistics==15)
 h.buildings={h.buildings[3],h.buildings[2],h.buildings[1]}
 assert(H.Effects(h,3).abilities.commerce==15)
 h.buildings[2].remainingPeriods=1; assert(#H.Effects(h,3).pairs==0)
end)
test("district chapter gate, deterministic membership, loss after disconnect and overlap priority",function()
 local h=H.New(0); h.buildings={ready(1,"bank",1,1),ready(2,"bank",2,1),ready(3,"guildhall",2,2),ready(4,"tavern",3,2),ready(5,"tavern",3,3)}
 assert(#H.Effects(h,3).districts==0)
 local e=H.Effects(h,4); assert(#e.districts==1 and e.districts[1].id=="finance" and not e.membership[4])
 local orig=e.abilities.capital
 local reversed={}; for i=#h.buildings,1,-1 do reversed[#reversed+1]=h.buildings[i] end; h.buildings=reversed
 assert(H.Effects(h,4).abilities.capital==orig)
 H.Find(h,2).x=5; H.Find(h,2).y=5
 e=H.Effects(h,4); assert(#e.districts==1 and e.districts[1].id=="information")
end)
test("same district cannot multiply and income is capped and begins after construction",function()
 local h=H.New(0); h.buildings={ready(1,"market",1,1),ready(2,"market",2,1),ready(3,"warehouse",2,2),ready(4,"market",4,4),ready(5,"market",5,4),ready(6,"warehouse",5,5)}
 local e=H.Effects(h,4); assert(#e.districts==1 and e.districts[1].id=="trade")
 for _,v in pairs(e.income) do assert(v<=K.maximumLayoutIncome) end
 local expected=0; for _,b in ipairs(h.buildings) do expected=expected+math.floor(b.paidCost*K.incomeShare*(1+(e.income[b.id] or 0))) end
 assert(H.Settle(h,1,4).gross==expected)
 h.buildings[3].remainingPeriods=1
 e=H.Effects(h,4); local r=H.Settle(h,2,4); assert(#r.completed==1)
 expected=0; for _,b in ipairs(h.buildings) do if b.id~=3 then expected=expected+math.floor(b.paidCost*K.incomeShare*(1+(e.income[b.id] or 0))) end end
 assert(r.gross==expected)
end)
test("upgrade pauses output, persists pending level, completes once and caps at three",function()
 local h=H.New(0); h.buildings={ready(1,"bank",1,1)}; h.nextBuildingId=2
 local ok,q=H.Change(h,context(),"upgrade",1); assert(ok and q.cost==6500000)
 assert(H.Abilities(h).capital==0 and h.buildings[1].level==1 and h.buildings[1].targetLevel==2)
 h=H.Load(h,0); assert(h.buildings[1].targetLevel==2 and h.buildings[1].paidCost==16500000)
 assert(H.Settle(h,1,3).net==0); assert(H.Settle(h,2,3).net==0)
 assert(h.buildings[1].level==2 and H.Abilities(h).capital==19)
 assert(H.Settle(h,3,3).net>0)
 assert(H.Change(h,context(),"upgrade",1)); H.Settle(h,4,3); H.Settle(h,5,3)
 assert(h.buildings[1].level==3 and not H.Change(h,context(),"upgrade",1))
 assert(H.Load(h,5).buildings[1].level==3)
end)
test("move rejects occupied plots and lack of cash, pauses one period and never increases refund",function()
 local h=H.New(0); h.buildings={ready(1,"market",1,1),ready(2,"bank",2,1)}
 local c=context(); assert(not H.Change(h,c,"move",1,2,1)); c.cash=0
 assert(not H.Change(h,c,"move",1,4,4)); assert(H.At(h,1,1).id==1)
 c.cash=1e15; local ok,q=H.Change(h,c,"move",1,4,4)
 assert(ok and q.cost==1000000 and H.At(h,4,4).id==1 and not H.At(h,1,1))
 assert(H.Find(h,1).paidCost==10000000 and H.Find(h,1).remainingPeriods==1)
 local copy=H.Load(h,0); assert(H.At(copy,4,4).remainingPeriods==1)
 H.Settle(copy,1,3); assert(H.Quote(copy,c,"demolish",1).refund==4000000)
end)
test("demolition and construction cancellation refund once; slots and chapter gate protect edits",function()
 local h=H.New(0); h.buildings={ready(1,"bank",1,1),ready(2,"market",2,1),ready(3,"tavern",3,1)}
 local c=context(); c.chapter=2; assert(not H.Change(h,c,"demolish",1)); c.chapter=3
 assert(H.Change(h,c,"upgrade",1)); assert(H.Change(h,c,"move",2,5,5))
 assert(not H.Change(h,c,"upgrade",3))
 local ok,q=H.Change(h,c,"demolish",1); assert(ok and q.refund==4125000)
 assert(not H.Change(h,c,"demolish",1))
 assert(H.Change(h,c,"upgrade",3))
end)
test("controller gamepad upgrade move cancel demolish and readonly access",function()
 local a=A.New(nil,{}); a.state.chapter=4; a.state.cash=1e15; a.state.hub.introSeen=true
 a.state.hub.buildings={ready(1,"bank",1,1)}; a:StartAdministration(); a.index=2; a:Act("confirm")
 local cash=a.state.cash
 a:Act("confirm"); assert(a.modal.action=="hubChange"); a:Act("back"); a:ConfirmHubChange(); assert(a.state.cash==cash)
 a:Act("confirm"); a:Act("confirm"); assert(a.state.cash==cash-6500000 and a.admin.left==3)
 local after=a.state.cash; a:ConfirmHubChange(); assert(a.state.cash==after)
 H.Settle(a.state.hub,1,4); H.Settle(a.state.hub,2,4)
 a:Act("next"); a:Act("confirm"); assert(a.hubMoving==1)
 a:HubMove(1,0); a:Act("back"); assert(not a.hubMoving and H.At(a.state.hub,1,1))
 a:HubMove(-1,0); a:Act("confirm"); a:HubMove(1,0); a:Act("confirm"); assert(a.modal.action=="hubChange")
 a:Act("confirm"); assert(H.At(a.state.hub,2,1) and a.saved.state.hub.buildings[1].x==2)
 a:Act("next"); a:Act("confirm"); assert(a.modal.action=="hubChange"); a:Act("confirm"); assert(#a.state.hub.buildings==0)
 a:Act("back"); a.screen="management"; a:OpenHub(); a.state.hub.buildings={ready(9,"market",1,1)}
 a:Act("confirm"); assert(not a.modal and #a.state.hub.buildings==1)
end)
print(count.." hub tests passed")
