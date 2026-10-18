-- Isolated investment probe: no outside income, prices fixed at ordering.
for _,f in ipairs({'Config','HubData','Hub'}) do dofile('PBsTradeGame/'..f..'.lua') end
local H,K=PBTrade.Hub,PBTrade.HubData
print('facility,policy,seed,cost,break_even,net_500,net_1000')
for _,f in ipairs(K.facilities) do for _,policy in ipairs(K.policies) do for seed=1,3 do
 local h=H.New(0);h.eventSeed=seed*719;h.policy=policy.id
 local ok,cost=H.Build(h,{chapter=5,cash=1e18,average=1e8},f.id,1,1);assert(ok)
 local net,breakeven,half=0,0,0
 for cycle=1,1000 do
  net=net+H.Settle(h,cycle,5).net
  if breakeven==0 and net>=cost then breakeven=cycle end
  if cycle==500 then half=net end
 end
 print(table.concat({f.id,policy.id,seed,cost,breakeven,half,net},','))
end end end
