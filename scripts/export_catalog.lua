for _,file in ipairs({"Config","Data","World"}) do dofile("PBsTradeGame/"..file..".lua") end
local D=PBTrade.Data
local file=assert(io.open("docs/PROPERTY_CATALOG.md","w"))
file:write("# 物件カタログ\n\n"..#D.zones.."交易地域 / "..#D.properties.."物件。30の個別設計物件、地域・業種・経営特性から確定生成した1,272物件、最終拠点1件。\n")
file:write("起動ごとの乱数生成ではなく、ID・名称・性能は固定です。全データはData.luaとWorld.luaで管理します。\n\n")
for _,z in ipairs(D.zones) do
    file:write("## "..z.name.." (`"..z.id.."`)\n\n")
    file:write("| ID | 名称 | 業種 | 所有 | 評価額 | 予想収益 | 負担/増分 | 加速 | 特性 |\n|---|---|---|---|---:|---:|---|---:|---|\n")
    for _,id in ipairs(D.propertyIdsByZone[z.id]) do
        local p=D.propertyById[id]
        file:write("| "..table.concat({p.id,p.name,D.categories[p.category],D.companies[p.owner].name,p.marketValue,p.expectedProfit,
            p.independenceRisk.." / +"..p.independenceIncrease,p.gaugeAcceleration,p.profileName or "個別設計"}," | ").." |\n")
    end
    file:write("\n")
end
file:close()
print("docs/PROPERTY_CATALOG.md: "..#D.zones.." zones, "..#D.properties.." properties")
