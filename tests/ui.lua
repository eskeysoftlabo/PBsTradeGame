-- Contract smoke harness, not an emulation of the ESO client.
-- Emits the actual native-control layout for an offline visual check.
unpack=unpack or table.unpack
math.randomseed(20260923) -- reproducible runs
local controls={}
CT_BACKDROP="box"; CT_LABEL="text"; CT_CONTROL="panel"; CT_TEXTURE="texture"
TOPLEFT="tl"; TOPRIGHT="tr"; CENTER="center"; DL_BACKGROUND=0; DL_CONTROLS=1; DL_TEXT=2; DL_OVERLAY=3
DT_LOW=0; DT_MEDIUM=1; DT_HIGH=2
KEYBIND_STRIP_ALIGN_CENTER=1; TEXT_ALIGN_CENTER=1; TEXT_ALIGN_RIGHT=2; SCENE_SHOWING=1; SCENE_SHOWN=2; SCENE_HIDING=3
TEXT_TYPE_ALL=1; VIRTUAL_KEYBOARD_TYPE_DEFAULT=1
ZO_DI_LEFT_STICK=1; ZO_DI_DPAD=3
FRAGMENT_GROUP={GAMEPAD_DRIVEN_UI_WINDOW={}}
local Control={}; Control.__index=Control
local function control(kind,parent)
    local c=setmetatable({kind=kind,parent=parent,w=0,h=0,x=0,y=0,color={1,1,1,1}},Control)
    controls[#controls+1]=c; return c
end
function Control:SetAnchor(point,relative,to,x,y) self.anchor={point,relative,to,x or 0,y or 0} end
function Control:SetDimensions(w,h) assert(w>=0 and h>=0); self.w,self.h=w,h end
function Control:SetCenterColor(...) self.color={...} end
function Control:SetColor(...) self.color={...} end
function Control:SetEdgeColor(...) self.edge={...} end
function Control:SetEdgeTexture() end
local knownFonts={18,20,22,25,27,34,36,42,54,61}
for _,size in ipairs(knownFonts) do
    _G["ZoFontGamepad"..size]={GetFontInfo=function() return "EsoUI/Fonts/LocalizedJapanese.ttf",size end}
end
function Control:SetFont(font)
    local size=tonumber(font:match("|(%d+)|"))
    if not size then
        assert(_G[font],"Unknown ESO font: "..font)
        size=tonumber(font:match("%d+"))
    end
    self.font=size; self.fontDescriptor=font
end
function Control:SetText(text) assert(type(text)=="string"); self.text=text end
function Control:SetHidden(value) self.hidden=value end
function Control:SetHorizontalAlignment(align) self.align=align end
-- Edit box (ZO_DefaultEditForBackdrop): focus and text only.
function Control:SetMaxInputChars(n) self.maxChars=n end
function Control:SetTextType(kind) self.textType=kind end
function Control:SetVirtualKeyboardType(kind) self.keyboardType=kind end
function Control:TakeFocus() self.focused=true; self.focusCount=(self.focusCount or 0)+1 end
-- ZO_DefaultEditForBackdrop_Gamepad: losing focus (Accept / Cancel) calls focusLostCallback.
function Control:LoseFocus() if self.focused then self.focused=false; if self.focusLostCallback then self.focusLostCallback(self) end end end
function Control:HasFocus() return self.focused==true end
function Control:GetText() return self.text or "" end
function Control:SetAlpha(value) assert(value>=0 and value<=1.0001); self.alpha=value end
function Control:SetWidth(value) assert(value>=0); self.w=value end
function Control:SetAnchorFill(relative) self.fill=relative end
function Control:ClearAnchors() self.anchor=nil end
function Control:SetMouseEnabled() end
function Control:SetHandler(name,fn) self[name]=fn end
function Control:SetTexture(path) local f=assert(io.open(path,"rb")); f:close(); self.texture=path end
function Control:IsTextureLoaded() return self.texture~=nil end
function Control:GetTextureFileDimensions() return unpack(self.pbtradeExpected or {0,0}) end
function Control:GetDimensions() return self.w,self.h end
function Control:IsHidden() return self.hidden or (self.parent and self.parent:IsHidden()) or false end
function Control:GetAlpha() return self.alpha or 1 end
function Control:GetDrawTier() return self.tier or (self.parent and self.parent:GetDrawTier()) or DT_MEDIUM end
function Control:SetDrawTier(tier) assert(tier~=nil); self.tier=tier end
function Control:GetDrawLayer() return self.layer or DL_CONTROLS end
function Control:GetDrawLevel() return self.level or 0 end
function Control:GetType() return self.kind end
function Control:SetDrawLayer(layer) assert(layer~=nil); self.layer=layer end
function Control:SetDrawLevel(level) self.level=level end
-- Only real ESO texture methods belong in this mock: absent methods must fail.
function Control:SetTextureCoords(left,right,top,bottom)
    assert(self.kind=="texture")
    assert(left>=0 and right<=1 and left<right and top>=0 and bottom<=1 and top<bottom)
    self.uv={left,right,top,bottom}
end
function Control:SetScale(scale) self.scale=scale end
function Control:GetWidth() return self.w end
function Control:GetHeight() return self.h end
GuiRoot=control("panel"); GuiRoot.w=1920; GuiRoot.h=1080
WINDOW_MANAGER={CreateControl=function(_,_,parent,kind) return control(kind,parent) end,
    CreateControlFromVirtual=function(_,name,parent,template) assert(template=="ZO_DefaultEditForBackdrop_Gamepad"); return control("edit",parent) end,CreateTopLevelWindow=function() return control("panel",GuiRoot) end}
KEYBIND_STRIP={groups=0,AddKeybindButtonGroup=function(self) self.groups=self.groups+1 end,RemoveKeybindButtonGroup=function(self) self.groups=self.groups-1 end}
DIRECTIONAL_INPUT={Activate=function(self,obj) self.obj=obj end,Deactivate=function(self) self.obj=nil end,GetXY=function(_,device,...) assert(device==ZO_DI_LEFT_STICK and select("#",...)==0,"private IsKeyDown DPAD path must not be queried"); return 0,0 end}
local audioCalls=0
SOUNDS={ITEM_MONEY_CHANGED="Money_Transact"}
PlaySound=function() audioCalls=audioCalls+1 end
local time=0
function GetFrameTimeSeconds() return time end
local scene
ZO_Scene={New=function()
    scene={AddFragment=function() end,AddFragmentGroup=function() end,RegisterCallback=function(self,_,cb) self.callback=cb end}
    return scene
end}
ZO_SimpleSceneFragment={New=function() return {} end}; ZO_ActionLayerFragment=ZO_SimpleSceneFragment
SCENE_MANAGER={Hide=function() scene.callback(nil,SCENE_HIDING) end}
for _,f in ipairs({"Config","Assets","Data","World","HubData","Hub","Tactics","Story","Model","LiveCatalog","Engine","Coins","Audio","Controller","HubController","HubUI","UI","Menu"}) do dofile("PBsTradeGame/"..f..".lua") end
local app=PBTrade.Controller.New(); local ui=PBTrade.UI.New(app)
ui.root:SetHidden(false)
scene.callback(nil,SCENE_SHOWING); scene.callback(nil,SCENE_SHOWN)
assert(KEYBIND_STRIP.groups==1 and DIRECTIONAL_INPUT.obj==ui)
-- Title screen first; a new player must found a company and name it before the tutorial.
assert(app.screen=="title" and not ui.titlePanel.hidden and ui.titleName.text==PBTrade.Config.displayTitle)
assert(#app:Rows()==1 and app:Rows()[1].command=="found" and ui.titleRows[1].text.text:find("新しい商会を興す",1,true))
ui:Action("back"); assert(app.screen=="title" or not ui.active)
scene.callback(nil,SCENE_SHOWING); scene.callback(nil,SCENE_SHOWN)
-- Founding reveals one complete character immediately.
ui:Action("confirm"); assert(app.screen=="opening" and not ui.openingPanel.hidden and ui.titlePanel.hidden)
assert(ui.openingArt.texture:find("atlas",1,true) and ui.openingPage.text=="1 / "..#PBTrade.Data.opening)
assert(ui.openingText.h>0 and ui.openingText.fontDescriptor:find("LocalizedJapanese",1,true))
assert(#ui.openingText.text>0 and ui.openingText.text==PBTrade.Data.opening[1].text:sub(1,#ui.openingText.text))
assert(ui.openingPanel.kind==CT_CONTROL and ui.titlePanel.kind==CT_CONTROL)
assert(ui.gameplay.hidden and ui.openingText.layer==DL_TEXT and ui.openingHint.layer==DL_TEXT)
assert(ui.openingArt.layer==DL_BACKGROUND)
-- Defaults must not decide whether the shade can cover text. Check explicit
-- native priorities, independently of the offline preview's creation order.
assert(ui.openingPanel.tier==DT_MEDIUM)
for _,c in ipairs(controls) do
    if c.parent==ui.openingPanel then
        assert(c.tier==(c.kind==CT_LABEL and DT_HIGH or DT_MEDIUM))
    end
end
assert(ui:DescribeDisplay():find("screen=opening",1,true) and ui:DescribeDisplay():find(ui.openingText.text,1,true))
-- Every visible stage backdrop/image stays below every stage label. The old
-- all-OVERLAY hierarchy cannot pass this check, even if text exists in the mock.
for _,c in ipairs(controls) do
    local parent=c.parent
    while parent and parent~=ui.openingPanel and parent~=ui.titlePanel do parent=parent.parent end
    if parent then
        if c.kind==CT_LABEL then assert(c.layer==DL_TEXT)
        elseif c.kind==CT_BACKDROP or c.kind==CT_TEXTURE then assert(c.layer==DL_BACKGROUND) end
    end
end
assert(math.abs(ui.openingPanel.w-PBTrade.Config.ui.width*ui.sx)<.001
    and math.abs(ui.openingPanel.h-PBTrade.Config.ui.height*ui.sy)<.001)
-- Closing/reopening the Game Center scene must resume the same opening page and timing.
do
    local opening=app.opening
    scene.callback(nil,SCENE_HIDING); scene.callback(nil,SCENE_SHOWING); scene.callback(nil,SCENE_SHOWN)
    assert(app.screen=="opening" and app.opening==opening and not ui.openingPanel.hidden)
end
time=time+.4; ui:Tick(.4); local typed=ui.openingText.text
assert(#typed>0 and #typed<#PBTrade.Data.opening[1].text and ui.openingNext.hidden)
assert(ui.openingText.font==34 and ui.openingText.tier==DT_HIGH)
local u0=ui.openingArt.uv[1]; time=time+3; ui:Tick(3); assert(ui.openingArt.uv[1]>u0) -- slow push-in
ui:Action("confirm"); assert(app.opening.page==1)
assert(ui.openingText.text==PBTrade.Data.opening[1].text and not ui.openingNext.hidden)
ui:Action("confirm"); ui:Tick(.05); assert(ui.openingPage.text:find("^2 /") and ui.openingArt.texture:find("treasury",1,true))
assert(ui.openingArt.alpha==1) -- never depend on the scene update callback for a visible background
ui:Action("back"); assert(app.screen=="naming" and app.pendingName==nil and ui.openingPanel.hidden)
local rows=app:Rows(); assert(rows[#rows].command=="accept" and rows[#rows].enabled==false)
app.index=#rows; ui:Action("confirm"); assert(app.screen=="naming" and not app.state.companyName)
-- Keyboard entry: focus once (no forced refocus), controller input ignored while typing.
app.index=1; ui:Action("confirm"); assert(ui.editing and not ui.nameEditBox.hidden and ui.nameEdit.focused)
assert(ui.nameEdit.textType==TEXT_TYPE_ALL and ui.nameEdit.keyboardType==VIRTUAL_KEYBOARD_TYPE_DEFAULT)
assert(ui.nameEdit.focusCount==1 and ui.titleNotice.text:find("確定",1,true))
time=time+2; ui:Tick(2); assert(ui.editing and ui.nameEdit.focusCount==1) -- the keyboard is left alone
ui:Action("confirm"); assert(ui.editing)
-- Cancel (template restores the old empty text) or an empty name keeps the naming screen.
ui.nameEdit.text=""; ui.nameEdit:LoseFocus(); assert(ui.editing) -- IME commit is deliberately deferred
time=time+.4; ui:Tick(.4); assert(not ui.editing and app.screen=="naming" and not app.state.companyName)
-- Japanese composition may reach the edit box after focus is lost; the delayed read preserves it.
app.index=1; ui:Action("confirm"); ui.nameEdit.text=""; ui.nameEdit:LoseFocus(); ui.nameEdit.text="灰塵の商会"
time=time+.4; ui:Tick(.4); assert(not ui.editing and app.state.companyName=="灰塵の商会" and app.screen=="map")
assert(not ui.gameplay.hidden and ui.openingPanel.hidden and ui.titlePanel.hidden)
local tutorialModal=app.modal; assert(tutorialModal and tutorialModal.action=="tutorial") -- first naming starts the tutorial
-- Rename from the title: a typed name is applied at once, no second confirmation to miss.
app.modal=nil; app:ShowTitle(); app.index=2; ui:Action("confirm"); assert(app.screen=="naming")
app.index=1; ui:Action("confirm"); ui.nameEdit.text="  　白銀の天秤商会\n  "; ui.nameEdit:LoseFocus(); time=time+.4; ui:Tick(.4)
assert(not ui.editing and app.state.companyName=="白銀の天秤商会" and app.screen=="title")
-- Candidates still work without a keyboard; typed names are capped.
app.index=2; ui:Action("confirm"); assert(app.screen=="naming")
app.index=2; ui:Action("confirm"); assert(app.pendingName==PBTrade.Config.campaign.companyNameCandidates[1])
local rows=app:Rows(); app.index=#rows; ui:Action("confirm"); assert(app.state.companyName==PBTrade.Config.campaign.companyNameCandidates[1])
app.index=2; ui:Action("confirm"); app:SubmitTypedName(string.rep("金",30)); assert(#app.state.companyName==16*3)
app.index=2; ui:Action("confirm"); app:SubmitTypedName("白銀の天秤商会")
app.index=1; ui:Action("confirm"); assert(app.state.companyName=="白銀の天秤商会" and app.screen=="map")
assert(app.state.companies.player.name=="白銀の天秤商会" and ui.subtitle.text:find("白銀の天秤商会",1,true))
assert(ui.titlePanel.hidden)
-- Console path: use ESO's standard parametric gamepad text field, which owns the platform IME.
do
    local registered,shown,parametric={},nil,{}
    GAMEPAD_DIALOGS={PARAMETRIC=1}
    ZO_GenericGamepadDialog_GetControl=function() return parametric end
    ZO_Dialogs_RegisterCustomDialog=function(name,info) registered.name,registered.info=name,info end
    ZO_Dialogs_ShowGamepadDialog=function(name,data) shown={name=name,data=data}; parametric.data=data end
    ZO_Dialogs_ReleaseDialogOnButtonPress=function() end
    ZO_GetDefaultParametricListEditBoxNarrationText=function() end
    app.screen="naming"; app.pendingName="白銀の天秤商会"; ui:RegisterCompanyNameDialog(); ui:OpenKeyboard()
    assert(registered.name=="PBTRADE_COMPANY_NAME_GAMEPAD" and shown.data.name=="白銀の天秤商会")
    local template=registered.info.parametricList[1].templateData
    local submit=registered.info.parametricList[2].templateData
    assert(registered.info.parametricList[2].template=="ZO_GamepadTextFieldSubmitItem" and submit.finishedSelector)
    local edit=control("edit"); local field={editBoxControl=edit}; template.setup(field,template)
    edit.text="日本語商会"; template.textChangedCallback(edit)
    assert(shown.data.name=="日本語商会" and edit.textType==TEXT_TYPE_ALL)
    -- PS5 Japanese IME may commit only as focus is lost. The focus callback must capture the
    -- live value before ESO refreshes and re-runs setup with the cached dialog data.
    edit.text="暁の羅針盤商会"; edit.focused=true; edit:LoseFocus()
    assert(shown.data.name=="暁の羅針盤商会")
    edit.text="古い値"
    template.setup(field,template)
    assert(edit.text=="暁の羅針盤商会")
    -- The standard ESO submit row confirms with ×, without relying on □ being delivered.
    edit.text="東雲交易社"
    parametric.entryList={GetTargetData=function() return submit end,GetTargetControl=function() return field end}
    registered.info.buttons[1].callback(parametric)
    assert(app.state.companyName=="東雲交易社")
    ZO_Dialogs_RegisterCustomDialog=nil; ZO_Dialogs_ShowGamepadDialog=nil
    ZO_GenericGamepadDialog_GetControl=nil; ZO_Dialogs_ReleaseDialogOnButtonPress=nil
    ZO_GetDefaultParametricListEditBoxNarrationText=nil; GAMEPAD_DIALOGS=nil
    ui.companyNameDialogRegistered=nil; app.screen="map"; app.pendingName=nil
end
app.modal=tutorialModal; ui:Refresh()
assert(app.modal and app.modal.action=="tutorial")
-- Reopening during a negotiation skips the title; reopening from the ledger shows it.
do
    local saved=app.modal; app.modal=nil
    app.engine.battle=nil; assert(app.engine:Start("gra_inn")); app.screen="battle"
    scene.callback(nil,SCENE_HIDING); scene.callback(nil,SCENE_SHOWING); scene.callback(nil,SCENE_SHOWN)
    assert(app.screen=="battle" and ui.titlePanel.hidden)
    app.engine:Finish("withdrawn"); app.engine.battle=nil; app.screen="map"
    scene.callback(nil,SCENE_HIDING); scene.callback(nil,SCENE_SHOWING); scene.callback(nil,SCENE_SHOWN)
    assert(app.screen=="title" and not ui.titlePanel.hidden and ui.titleRows[1].text.text:find("交易を続ける",1,true))
    assert(ui.titleCompany.text:find("東雲交易社",1,true) and ui.titleStatus.text:find("第1期",1,true))
    ui:Action("confirm"); assert(app.screen=="map" and ui.titlePanel.hidden)
    app.modal=saved; app.introShown=true
end
for _=1,4 do ui:Action("confirm") end
assert(app.modal and app.modal.campaign and app.modal.background=="chapter_1")
ui:Action("back")
-- Ten-period strategy and routine delegation use the same gamepad-first ledger layout.
do
    app.modal=nil; app.state.cycles=10; app.strategySeason=PBTrade.Model.BeginStrategicSeason(app.state,function() return 0 end)
    app.screen="strategy"; app.index=1; ui:Refresh()
    assert(not ui.ledger.hidden and ui.ledgerHeading.text:find("交易会議",1,true) and #app:Rows()==#PBTrade.Data.tradePolicies)
    app.state.chapter=2; app.state.cash=PBTrade.Config.Money(100000000); PBTrade.Model.Unlock(app.state)
    app.screen="management"; local delegate
    for i,row in ipairs(app:Rows()) do if row.command=="delegate" then delegate=i end end
    assert(delegate); app.index=delegate; ui:Action("confirm"); ui:Refresh()
    assert(app.screen=="delegate_pick" and not ui.ledger.hidden and ui.ledgerHeading.text:find("委任",1,true))
    app.screen="map"; app.index=1; ui:Refresh()
    print("PASS trade council and delegated acquisition ledger screens")
end
-- D-pad events: immediate step, held repeat after the first delay, release stops.
do
    local startIndex=app.index
    ui:DirectionKey("down",true); assert(app.index==startIndex+1)
    ui:UpdateDirectionalInput(); assert(app.index==startIndex+1)
    time=time+PBTrade.Config.input.firstRepeat; ui:UpdateDirectionalInput(); assert(app.index==startIndex+2)
    ui:DirectionKey("down",false); time=time+1; ui:UpdateDirectionalInput(); assert(app.index==startIndex+2)
    ui:DirectionKey("right",true); ui:DirectionKey("right",false); assert(app.index==startIndex+2+(app.screen=="map" and PBTrade.Config.ui.mapPageSize or PBTrade.Config.ui.pageSize))
    app.index=startIndex; ui:Refresh()
    print("PASS D-pad via binding events without private DPAD polling")
end
local function rect(c)
    if c.fill then return rect(c.fill) end
    if not c.anchor then return c.x,c.y,c.w,c.h,c.scale or 1 end
    local a=c.anchor; local x,y,w,h,parentScale=rect(a[2])
    local scale=parentScale*(c.scale or 1)
    if a[3]==TOPRIGHT then x=x+w elseif a[3]==CENTER then x=x+w/2; y=y+h/2 end
    if a[1]==TOPRIGHT then x=x-c.w*scale elseif a[1]==CENTER then x=x-c.w*scale/2; y=y-c.h*scale/2 end
    return x+a[4]*parentScale,y+a[5]*parentScale,c.w*scale,c.h*scale,scale
end
-- Fullscreen bounds remain correct at 720p, 1080p, ultrawide and 4K.
for _,size in ipairs({{1280,720},{1920,1080},{2560,1080},{3840,2160}}) do
    GuiRoot.w,GuiRoot.h=size[1],size[2]; ui:Resize(); ui:Refresh()
    local x,y,w,h=rect(ui.content)
    assert(x==0 and y==0); assert(math.abs(w-size[1])<.001)
    assert(math.abs(h-(size[2]-PBTrade.Config.ui.keybindHeight))<.001)
    for _,item in ipairs(ui.layout) do
        local rx,ry,rw,rh=rect(item.control)
        assert(rx>=0 and ry>=0 and rx+rw<=size[1]+.01 and ry+rh<=size[2]+.01)
    end
end
GuiRoot.w,GuiRoot.h=1920,1080; ui:Resize(); ui:Refresh()
local function visible(c) return not c.hidden and (not c.parent or visible(c.parent)) end
local function dump(name)
    local file=assert(io.open("tests/"..name..".layout","w"))
    file:write("canvas\t"..GuiRoot.w.."\t"..GuiRoot.h.."\n")
    local ordered={}
    for _,c in ipairs(controls) do ordered[#ordered+1]=c end
    if name=="opening" or name=="hub" or name=="hub_full" or name=="hub_district" or name=="hub_expanded" or name=="hub_advanced" or name=="hub_operations" then
        local index={}; for i,c in ipairs(controls) do index[c]=i end
        table.sort(ordered,function(a,b)
            if a:GetDrawTier()~=b:GetDrawTier() then return a:GetDrawTier()<b:GetDrawTier() end
            if a:GetDrawLayer()~=b:GetDrawLayer() then return a:GetDrawLayer()<b:GetDrawLayer() end
            if a:GetDrawLevel()~=b:GetDrawLevel() then return a:GetDrawLevel()<b:GetDrawLevel() end
            return index[a]<index[b]
        end)
    end
    for _,c in ipairs(ordered) do
        if visible(c) and c.kind~="panel" then
            local x,y,w,h,scale=rect(c)
            local clip={0,0,GuiRoot.w,GuiRoot.h}
            local ancestor=c.parent
            while ancestor do
                if ancestor.clips then local cx,cy,cw,ch=rect(ancestor); clip={cx,cy,cw,ch}; break end
                ancestor=ancestor.parent
            end
            local text=(c.text or c.texture or ""):gsub("\n","\\n")
            file:write(table.concat({c.kind,x,y,w,h,table.concat(c.color,","),(c.font or 22)*scale,table.concat(c.edge or {0,0,0,0},","),table.concat(clip,","),table.concat(c.uv or {0,1,0,1},","),c.align==TEXT_ALIGN_CENTER and "center" or (c.align==TEXT_ALIGN_RIGHT and "right" or "left"),text},"\t").."\n")
        end
    end
    file:close()
end
dump("map")
do
    local savedApp=ui.app
    local a=PBTrade.Controller.New(nil,{})
    a.state.chapter=3; a.state.cash=1e15; a.state.hub.introSeen=true
    a:StartAdministration(); a.index=2
    ui.app=a; ui:Action("confirm")
    assert(a.screen=="hub" and not ui.hubView.root.hidden and ui.ledger.hidden and ui.battle.hidden)
    for _,c in ipairs(ui.hubView.cells) do
        assert(c.caption.tier==DT_MEDIUM and c.caption.layer==DL_OVERLAY)
        assert(c.tile.tier==DT_MEDIUM and c.tile.layer==DL_OVERLAY and c.tile.level==1)
        assert(c.building.level>1 and c.building.level<c.caption.level)
    end
    ui:Action("confirm"); assert(a.modal.action=="hubBuild")
    ui:Action("confirm"); assert(#a.state.hub.buildings==1 and a.admin.left==3)
    assert(#ui.hubView.cells==25)
    local decorations=0
    for _,c in ipairs(ui.hubView.cells) do
        if PBTrade.Hub.At(a.state.hub,c.x,c.y) then assert(c.decoration.hidden)
        elseif not c.decoration.hidden then decorations=decorations+1 end
    end
    assert(decorations>0 and decorations<24)
    local count=#controls
    ui:DirectionKey("right",true); ui:DirectionKey("right",false)
    assert(a.hubCursor.x==2 and a.hubCursor.y==1)
    ui:Action("next"); assert(a.hubFacility==2)
    ui:Action("confirm"); ui:Action("confirm")
    PBTrade.Model.SettleCycle(a.state); PBTrade.Model.SettleCycle(a.state)
    a:HubMove(0,1); ui:Action("next"); ui:Action("confirm"); ui:Action("confirm")
    for _,size in ipairs({{1280,720},{1920,1080},{2560,1080},{3840,2160}}) do
        GuiRoot.w,GuiRoot.h=size[1],size[2]; ui:Resize(); ui:Refresh()
        for _,c in ipairs(ui.hubView.cells) do
            local x,y,w,h=rect(c.panel)
            assert(x>=0 and y>=0 and x+w<=size[1] and y+h<=size[2])
        end
    end
    GuiRoot.w,GuiRoot.h=1920,1080; ui:Resize(); ui:Refresh(); dump("hub")
    ui:Action("detail"); assert(a.modal and a.modal.text:find("隊商倉庫",1,true))
    ui:Action("back")
    -- Fully populated city: every asset, all depth rows, and the farthest selectable cell.
    a.state.hub.buildings={}
    for y=1,5 do for x=1,5 do
        local n=(y-1)*5+x
        a.state.hub.buildings[n]={id=n,type=PBTrade.HubData.facilities[(n-1)%5+1].id,x=x,y=y,level=1,paidCost=5000000,remainingPeriods=0}
    end end
    a:HubMove(99,99); assert(a.hubCursor.x==5 and a.hubCursor.y==5)
    ui:Refresh(); dump("hub_full")
    for _,c in ipairs(ui.hubView.cells) do assert(not c.building.hidden and c.decoration.hidden and c.building.texture:find("hub_",1,true)) end
    a.state.chapter=4; a.hubCursor={x=3,y=3}
    ui:Refresh(); assert(#PBTrade.Hub.Effects(a.state.hub,4).districts==2)
    assert(ui.hubView.detail.text:find("交易区",1,true)); dump("hub_district")
    for chapter=4,5 do
        a.state.chapter=chapter; a.state.hub.buildings={}
        local size=PBTrade.Hub.Size(chapter)
        for y=1,size do for x=1,size do
            local n=(y-1)*size+x
            a.state.hub.buildings[n]={id=n,type=PBTrade.HubData.facilities[(n-1)%5+1].id,x=x,y=y,level=1,paidCost=5000000,remainingPeriods=0}
        end end
        a:HubMove(99,99); assert(a.hubCursor.x==size and a.hubCursor.y==size)
        for _,resolution in ipairs({{1280,720},{1920,1080},{2560,1080},{3840,2160}}) do
            GuiRoot.w,GuiRoot.h=resolution[1],resolution[2];ui:Resize();ui:Refresh()
            local found=false
            for _,cell in ipairs(ui.hubView.cells) do
                assert(cell.x>=size-4 and cell.x<=size and cell.y>=size-4 and cell.y<=size)
                local x,y,w,h=rect(cell.panel);assert(x>=0 and x+w<=GuiRoot.w and y+h<=GuiRoot.h)
                if cell.x==size and cell.y==size then found=true;assert(not cell.building.hidden) end
            end
            assert(found and #ui.hubView.cells==25 and #controls==count)
        end
    end
    GuiRoot.w,GuiRoot.h=1920,1080;ui:Resize();ui:Refresh();dump("hub_expanded")
    a.state.hub.buildings={}; a.hubCursor={x=2,y=2}
    for i,f in ipairs(PBTrade.Hub.Catalogue(5)) do
        a.state.hub.buildings[i]={id=i,type=f.id,x=(i-1)%4+1,y=math.floor((i-1)/4)+1,level=1,paidCost=5000000,remainingPeriods=0}
    end
    ui:Refresh();dump("hub_advanced")
    for _,f in ipairs(PBTrade.Hub.Catalogue(5)) do
        local seen=false
        for _,c in ipairs(ui.hubView.cells) do
            local b=PBTrade.Hub.At(a.state.hub,c.x,c.y)
            if b and b.type==f.id then assert(not c.building.hidden and c.building.texture:find("hub_"..(f.asset or f.id)..".dds",1,true));seen=true end
        end
        assert(seen)
    end
    ui:Action("info");assert(a.modal.hubPolicy);ui:Action("next");dump("hub_operations")
    ui:Action("detail");assert(a.hubGuide);ui:Action("back")
    ui:Action("back"); assert(a.screen=="admin" and ui.hubView.root.hidden)
    assert(#controls==count)
    ui.app=savedApp; ui:Refresh()
    print("PASS hub gamepad building, details, modal cancellation, fixed pool and four resolutions")
end
do
    local modal=app.modal; app.modal=nil
    app:ShowOpening("title"); app.opening.page=3; app.opening.pageTime=4; app.opening.time=999; ui:Refresh(); dump("opening")
    -- True ending: Ember's pages show a framed portrait and her name; the recap and the
    -- closing page do not. The story ends on the title screen.
    local company=app.state.companyName; app.state.companyName=company or "銀河郵便局"
    app:ShowOpening("title","trueEnding"); ui:Refresh()
    local function card(hidden) for _,c in ipairs(ui.openingCard) do assert(c.hidden==hidden,"card hidden state") end end
    card(true)
    local firstEmber; for i,pg in ipairs(app.opening.pages) do if pg.portrait and not firstEmber then firstEmber=i end end
    app.opening.page=firstEmber; app.opening.pageTime=4; app.opening.time=999; ui:Refresh()
    card(false)
    assert(ui.openingPortrait.texture:find("ember.dds",1,true) and ui.openingSpeaker.text=="エンバー")
    assert(ui.openingPortrait.layer==DL_BACKGROUND and ui.openingSpeaker.layer==DL_TEXT and ui.openingSpeaker.tier==DT_HIGH)
    assert(ui.openingText.text:find("「",1,true))
    dump("ending_ember")
    app.opening.page=#app.opening.pages; app.opening.time=0; ui:Refresh(); card(true)
    app.opening.time=999; ui:Refresh(); app:Act("confirm"); eq_screen=app.screen; assert(app.screen=="title" and not app.opening)
    app:ShowOpening("title"); app.opening.page=3; app.opening.pageTime=4; app.opening.time=999; ui:Refresh(); card(true)
    app:ShowTitle(); ui:Refresh(); dump("title")
    app:Act("confirm"); app:Act("confirm"); app:Act("back")
    app.screen="naming"; app.index=3; app.pendingName="白銀の天秤商会"; ui:Refresh(); dump("naming")
    app.screen="map"; app.index=1; app.modal=modal; ui:Refresh()
end
local startingControlCount=#controls
for i=1,#PBTrade.Data.zones do app.index=i; ui:Refresh() end
assert(ui.mapPage==5); assert(ui.pins[3].box.hidden==false and ui.pins[4].box.hidden==true)
assert(#controls==startingControlCount); app.index=1; ui:Refresh()
ui:Action("confirm"); app.index=2; ui:Refresh(); dump("property")
-- Real places carry ◎ (visited, buyable) or ○ (not yet visited) in the region list.
do
    local list=app:Rows(); local real
    for i,row in ipairs(list) do if row.property and row.property.canonical then real=i; break end end
    if real then
        app.index=real; ui:Refresh()
        local text=ui.rows[(real-1)%PBTrade.Config.ui.pageSize+1].text.text
        assert(text:find("◎",1,true) or text:find("○",1,true))
    end
    app.index=2; ui:Refresh()
end
ui:Action("confirm"); assert(app.modal); ui:Action("confirm"); assert(app.screen=="battle")
ui:Action("confirm"); for _=1,120 do time=time+1/60; ui:Tick(1/60) end
if app.modal then ui:Action("back") end
-- Representative later negotiation with both piles visible; rendering values only.
app.engine.battle.playerBid=6000; app.engine.battle.enemyBid=4200; app.engine.battle.gauge=-28
ui:Refresh()
assert(ui.leftBid.text=="相手の拠出　4200 ゴールド")
-- The redundant speed/acceleration/wait/result status row is not created.
assert(ui.status==nil)
-- Command panel shows the four categories and the active one.
assert(ui.commandTabs.text:find("◆ 資金要求",1,true) and ui.commandTabs.text:find("グループ要求",1,true)
    and ui.commandTabs.text:find("駆け引き",1,true) and ui.commandTabs.text:find("自社資金",1,true))
ui:Action("next"); ui:Action("next"); ui:Action("next")
-- Player leads 6,000 to 4,200 here, so the menu opens on the lead-extending amount.
assert(ui.commandTabs.text:find("◆ 自社資金",1,true) and ui.command.text:find("リードを広げる",1,true))
assert(ui.commandHint.text:find("1800 リード",1,true))
ui:Action("next"); assert(ui.commandTabs.text:find("◆ 資金要求",1,true))
assert(ui.rightBid.text=="自社の拠出　6000 ゴールド")
-- Large sums read in Japanese units rather than long digit strings.
app.engine.battle.enemyBid=123456789; ui:Refresh(); assert(ui.leftBid.text=="相手の拠出　1億2345万 ゴールド")
app.engine.battle.enemyBid=4200; ui:Refresh()
-- The vault captions and crests above the coin bays are gone; popups own that space.
assert(ui.depthLabels==nil)
for _,c in ipairs(controls) do assert(not (c.texture and c.texture:find("crest") and c.parent==ui.battle)) end
assert(ui.battleTitle.text:find("日目",1,true))
assert(ui.bands[1].own.w>ui.bands[1].enemy.w)
assert(not ui.bands[1].enemyTip.hidden and not ui.bands[1].ownTip.hidden)
assert(math.abs((ui.bands[1].enemyTip.anchor[4]+ui.bands[1].enemyTip.w)-ui.bands[1].ownTip.anchor[4])<.001)
-- Battle draw order is explicit: bands, then coin/plinth, then every other UI surface.
for _,band in ipairs(ui.bands) do
    for _,name in ipairs({"enemy","own","enemyTip","ownTip","enemyGlow","ownGlow"}) do
        assert(band[name].tier==DT_MEDIUM and band[name].layer==DL_BACKGROUND)
    end
end
for _,floor in ipairs(ui.floors) do assert(floor.tier==DT_MEDIUM and floor.layer==DL_CONTROLS) end
-- List copy sits inside the engraved row rather than touching its top/left rules.
assert(ui.rows[1].text.anchor[4]>0 and ui.rows[1].text.anchor[5]>0)
for _,pair in ipairs(ui.bidFrames) do
    assert(pair.frame.layer==DL_OVERLAY and pair.art.layer==DL_OVERLAY)
end
for _,frame in ipairs(ui.commandFrames) do assert(frame.layer==DL_OVERLAY) end
for _,textControl in ipairs({ui.battleTitle,ui.leftBid,ui.rightBid,ui.commandTabs,ui.command,ui.commandHint,ui.log}) do
    assert(textControl.tier==DT_MEDIUM and textControl.layer==DL_OVERLAY and textControl.level==3)
end
for _,pair in ipairs(ui.bidFrames) do assert(ui.leftBid.level>pair.art.level and ui.rightBid.level>pair.art.level) end
for _,frame in ipairs(ui.commandFrames) do assert(ui.command.level>frame.level and ui.log.level>frame.level) end
local redBefore=ui.bands[1].enemyGlow.anchor[4]
local blueBefore=ui.bands[1].ownGlow.anchor[4]
ui.bandFxTime=(ui.bandFxTime or 0)+.2; ui:UpdateBattleBands((app.engine.battle.gauge+PBTrade.Config.battle.gaugeLimit)/(2*PBTrade.Config.battle.gaugeLimit))
assert(ui.bands[1].enemyGlow.anchor[4]>redBefore)
assert(ui.bands[1].ownGlow.anchor[4]<blueBefore)
for _=1,20 do ui.coins:Tick(.25); ui:Refresh() end; dump("battle")
-- Tactic banner: two lines over the title row only, UTF-8 typing, verdict line, auto-clear.
do
    local battle=app.engine.battle; battle.playerWait=0; app.state.learnedTactics.smile=true
    app:SelectBattleCommand("tactic","smile")
    ui:Action("confirm"); assert(app.tacticScene and not ui.cutin.hidden)
    -- Stays clear of the gauge bands, coin bays and bid plaques.
    assert(ui.cutin.anchor[5]+ui.cutin.h<=ui.bands[1].enemy.anchor[5]+.01)
    assert(ui.cutinLine.text:find(app.tacticScene.tactic.name,1,true))
    time=time+.3; ui:Tick(.3); local typed=ui.cutinLine.text
    local full="◆ 駆け引き「"..app.tacticScene.tactic.name.."」  "..app.tacticScene.act
    assert(#typed<#full and full:sub(1,#typed)==typed)
    assert(not ui.coinAreas[1].hidden and not ui.leftBid.hidden)
    local elapsed=battle.elapsed
    local S=PBTrade.Config.tacticScene
    time=time+S.intro+S.react; ui:Tick(S.intro+S.react); assert(battle.elapsed>elapsed)
    assert(ui.cutinVerdict.text:find(app.tacticScene.verdict,1,true) and ui.cutinVerdict.text:find("抵抗"))
    dump("tactic")
    time=time+S.result; ui:Tick(S.result); assert(not app.tacticScene and ui.cutinVerdict.hidden)
    -- Once the cut-in ends the strip is free: either hidden or showing a queued day summary.
    assert(ui.cutin.hidden or ui.cutinLine.text:find("日目",1,true))
    print("PASS tactic cut-in: single strip, trade stays visible and running, verdict, auto-clear")
end
-- Group funding: sound, "<group>を知るもの来たれ！" banner, and coins held until it ends.
do
    local battle=app.engine.battle; local S=app.state
    -- Keep this negotiation open while the test waits: no result can be reached in this block.
    local limit=PBTrade.Config.battle.gaugeLimit; PBTrade.Config.battle.gaugeLimit=1e9
    local played={}; local play=PBTrade.Audio.Play; PBTrade.Audio.Play=function(kind) played[#played+1]=kind; return true end
    local borrowed={}
    for _,id in ipairs(PBTrade.Data.propertyIdsByZone.auridon) do
        if #borrowed<4 and S.properties[id].owner~="player" then borrowed[#borrowed+1]={id=id,owner=S.properties[id].owner}; S.properties[id].owner="player" end
    end
    S.learnedGroups.region_auridon=true; battle.playerWait=0; app.modal=nil
    for _,p in ipairs(PBTrade.Model.GroupMembers(S,"region_auridon")) do p.independenceRisk=0 end
    for _=1,40 do time=time+.25; ui:Tick(.25) end -- let earlier popups finish
    local before=battle.playerBid; local target=ui.coins.sides[2].target
    assert(app:SelectBattleCommand("group","region_auridon")); ui:Action("confirm")
    local called=false; for _,kind in ipairs(played) do if kind=="groupCall" then called=true end end
    assert(app.groupCall and battle.playerBid>before and called)
    time=time+.1; ui:Tick(.1)
    assert(not ui.cutin.hidden and not ui.cutinVerdict.hidden and ui.cutinVerdict.text=="◆ オーリドン交易連合を知るもの来たれ！")
    assert(ui.cutinVerdict.scale>1 and ui.lanes.player.box.hidden)
    eq=eq or function(x,y) assert(x==y,tostring(x).." ~= "..tostring(y)) end
    assert(math.abs(ui.coins.sides[2].target-target)<1e-9) -- no new coins yet
    for _=1,20 do time=time+.1; ui:Tick(.1) end
    assert(not app.groupCall and ui.coins.sides[2].target>target) -- the pour begins after the call
    PBTrade.Audio.Play=play
    for _,lane in pairs(ui.lanes) do lane.queue={}; lane.current=nil end; ui.wide.queue={}; ui.wide.current=nil
    -- Leave the negotiation as it was for the tests that follow.
    for _,r in ipairs(borrowed) do S.properties[r.id].owner=r.owner end
    battle.playerBid=before; battle.gauge=0; battle.velocity=0; battle.momentum=0; battle.effects={}
    PBTrade.Config.battle.gaugeLimit=limit
    assert(app.screen=="battle" and not battle.result)
    print("PASS group call: fanfare, banner, coins start after the call")
end
-- Popups: side lanes above each coin bay, day summary across both, three turns per day.
do
    local battle=app.engine.battle
    for _=1,40 do time=time+.25; ui:Tick(.25) end
    ui.lanes.player.queue={}; ui.lanes.player.current=nil; ui.wide.queue={}; ui.wide.current=nil
    local statusSounds={}; local popupPlay=PBTrade.Audio.Play
    PBTrade.Audio.Play=function(kind) statusSounds[#statusSounds+1]=kind; return true end
    local day=battle.day
    battle.playerWait=0; app.state.cash=PBTrade.Config.Money(100000)
    app:SelectBattleCommand("treasury"); ui:Action("confirm")
    -- A day summary may take the strip first; the lane waits for it, then fades in.
    for _=1,200 do time=time+.05; ui:Tick(.05); if not ui.lanes.player.box.hidden then break end end
    assert(not ui.lanes.player.box.hidden and ui.lanes.player.text.text:find("商会資金を投入",1,true))
    assert(statusSounds[#statusSounds]=="statusPositive")
    assert(ui.lanes.player.box.alpha<1)
    time=time+.3; ui:Tick(.3); assert(ui.lanes.player.box.alpha==1)
    -- Enemy moves appear in the left lane.
    app.engine:Notify("enemy","追加出資  +1,000（計 5,200）","fund")
    for _=1,200 do time=time+.05; ui:Tick(.05); if ui.lanes.enemy.text.text=="追加出資  +1,000（計 5,200）" then break end end
    assert(ui.lanes.enemy.text.text=="追加出資  +1,000（計 5,200）" and not ui.lanes.enemy.box.hidden)
    assert(statusSounds[#statusSounds]=="statusNegative")
    -- Lanes sit above the coin bays and below the title.
    for _,lane in pairs(ui.lanes) do
        assert(lane.box.anchor[5]>=ui.battleTitle.anchor[5] and lane.box.anchor[5]+lane.box.h<=ui.bands[1].enemy.anchor[5]+.01)
    end
    local turns=battle.turns
    while battle.turns%PBTrade.Config.battle.turnsPerDay~=0 or battle.turns==turns do
        battle.playerWait=0; ui:Action("confirm")
    end
    assert(battle.day>day)
    time=time+3; ui:Tick(3)
    for _=1,20 do if ui.cutinLine.text:find(battle.day.."日目",1,true) and not ui.cutin.hidden then break end; time=time+.25; ui:Tick(.25) end
    assert(not ui.cutin.hidden and ui.cutinLine.text:find(battle.day.."日目",1,true) and ui.cutinLine.text:find("自社",1,true))
    assert(ui.lanes.player.box.hidden and ui.lanes.enemy.box.hidden)
    assert(ui.battleTitle.text:find(battle.day.."日目",1,true))
    PBTrade.Audio.Play=popupPlay
    print("PASS battle popups: side lanes, fades, day summary after three turns")
end
-- The completed negotiation remains visible behind an opaque, top-tier result
-- dialog.  Native sibling-tree ordering must never put coins or strips above it.
do
    local battle=app.engine.battle
    app.screen="result"; battle.result="won"; app.modal=nil; ui:Refresh()
    assert(not ui.modal.hidden and ui.modalText.text:find("契約締結",1,true))
    for _,c in ipairs({ui.modal,ui.modalArt,ui.campaignBackdrop,ui.campaignShade,ui.modalText}) do
        assert(c.tier==DT_HIGH and c.layer==DL_OVERLAY)
    end
    assert(ui.modal.level<ui.modalArt.level and ui.modalArt.level<ui.modalText.level)
    for _,pool in ipairs(ui.coinControls) do for _,coin in ipairs(pool) do assert(ui.modal.tier>coin.tier) end end
    assert(ui.modal.tier>ui.cutin:GetDrawTier())
    app.screen="battle"; battle.result=nil; ui:Refresh()
    print("PASS result dialog stays above coins, panels and negotiation effects")
end
assert(audioCalls>0)
local before=app.engine.battle.elapsed
ui:Action("info"); ui:Tick(.2); assert(app.engine.battle.elapsed>before); before=app.engine.battle.elapsed
ui:Action("back"); scene.callback(nil,SCENE_HIDING); local hiddenAudio=audioCalls; ui:Tick(.2)
assert(audioCalls==hiddenAudio)
assert(math.abs(app.engine.battle.elapsed-before)<1e-8)
assert(KEYBIND_STRIP.groups==0 and not DIRECTIONAL_INPUT.obj,"groups="..KEYBIND_STRIP.groups.." directional="..tostring(DIRECTIONAL_INPUT.obj))
scene.callback(nil,SCENE_SHOWING); scene.callback(nil,SCENE_SHOWN); ui:Tick(.1); assert(app.engine.battle.elapsed>before)
-- More than eight owned rows must page without creating additional controls.
local n=#controls; app.engine:Finish("withdrawn"); app.screen="owned"
app:StartAdministration(); ui:Refresh()
assert(not ui.ledger.hidden and ui.ledgerHeading.text:find("内政",1,true) and ui.rows[1].text.text:find("内政を終えて",1,true) and ui.rows[2].text.text:find("◆ 増資",1,true) and not ui.rows[8].box.hidden)
assert(ui.detail.text:find("設備投資",1,true)); dump("admin")
app:FinishAdministration()
app:ShowRankings(); ui:Refresh(); assert(not ui.ledger.hidden); assert(ui.battle.hidden); assert(ui.detail.text:find("資金力"))
assert(ui.ledgerHeading.text:find("^第%d+期  商会資金力ランキング") and ui.detail.text:find("期の決算へ",1,true))
-- Ledger captions must sit inside the engraved artwork: the heading shares the
-- detail panel's top inset and each single-line row has equal top/bottom space.
assert(ui.ledgerHeading.anchor[5]==24 and ui.ledgerHeading.anchor[5]+ui.ledgerHeading.h<=ui.rows[1].box.anchor[5])
assert(ui.rows[1].text.anchor[5]==7 and ui.rows[1].text.anchor[5]+ui.rows[1].text.h<ui.rows[1].box.h)
dump("rankings"); app.screen="owned"
app.state.chapter=5; PBTrade.Model.Unlock(app.state)
for _,p in pairs(app.state.properties) do p.owner="player" end
for i=1,#PBTrade.Data.properties,8 do app.index=i; ui:Refresh() end
app.index=#PBTrade.Data.properties; ui:Refresh()
assert(#controls==n); assert(ui.page==math.floor((#PBTrade.Data.properties-1)/PBTrade.Config.ui.pageSize))
ZO_GamepadEntryData={New=function(_,name,icon) return {name=name,icon=icon,SetIconTintOnSelection=function() end,SetEnabled=function() end} end}
ZO_MENU_ENTRIES={{data={name="設定",scene="gamepad_options_root"}}}
PBTrade.EnsureMenu(); PBTrade.EnsureMenu(); assert(#ZO_MENU_ENTRIES==2); assert(#ZO_MENU_ENTRIES[1].subMenu==1)
ZO_MENU_ENTRIES[1].subMenu[#ZO_MENU_ENTRIES[1].subMenu+1]={id="anotherGame",data={name="Another game"}}
PBTrade.EnsureMenu(); assert(#ZO_MENU_ENTRIES[1].subMenu==2)
print("PASS UI construction, navigation, realtime modals, hidden pause, resume, paging, fixed control pool, idempotent shared menu")
-- Existing PX category must keep both sibling games, regardless of load order.
local siblings={
    {id="PBsTetris",data={name="タムリエル de テトリス",scene="tetrisModeMenu"}},
    {id="PBsWarTable",data={name="PBs WarTable",scene="warTableModeMenu"}},
}
local px={id="PBsPX",data={name="ゲームセンターPX",subMenu={siblings[1].data,siblings[2].data}},subMenu={siblings[1],siblings[2]}}
ZO_MENU_ENTRIES={px,{data={name="設定",scene="gamepad_options_root"}}}
PBTrade.HookMenu() -- Menu singleton is not ready yet.
assert(not PBTrade.mainMenuHooked)
MAIN_MENU_GAMEPAD={}; local hooks=0; local refreshHook
ZO_PreHook=function(object,method,callback)
    assert(object==MAIN_MENU_GAMEPAD and method=="RefreshMainList")
    hooks=hooks+1; refreshHook=callback
end
PBTrade.HookMenu(); PBTrade.HookMenu(); refreshHook()
assert(hooks==1 and #ZO_MENU_ENTRIES==2 and #px.subMenu==3 and #px.data.subMenu==3)
assert(px.subMenu[1]==siblings[1] and px.subMenu[2]==siblings[2])
local trade=px.subMenu[3]
assert(trade.id==PBTrade.Config.addonId and trade.data.scene==PBTrade.Config.scene)
assert(trade.data.customTemplate=="ZO_GamepadMenuEntryTemplateWithArrow")
-- A main-menu rebuild is repopulated through the same single hook.
ZO_MENU_ENTRIES={{data={name="設定",scene="gamepad_options_root"}}}; refreshHook(); refreshHook()
assert(#ZO_MENU_ENTRIES==2 and #ZO_MENU_ENTRIES[1].subMenu==1)
print("PASS PX shared category, sibling preservation, scene launch entry, delayed hook and menu rebuild")

-- Exercise the real RenderCoins path without any imaginary parent clipping API.
local croppedTop,croppedBottom=false,false
ui.coins=PBTrade.Coins.New(4000); ui.coins:SetBid(1,1000000000); ui.coins:SetBid(2,10000)
for _,size in ipairs({{1280,720},{1920,1080},{2560,1080},{3840,2160}}) do
    GuiRoot.w,GuiRoot.h=size[1],size[2]; ui:Resize()
    for _=1,120 do
        ui.coins:Tick(1/60); ui:RenderCoins()
        for side,pool in ipairs(ui.coinControls) do
            local vp=ui.coinAreas[side]
            local items={ui.floors[side]}; for _,c in ipairs(pool) do items[#items+1]=c end
            for _,c in ipairs(items) do
                if not c.hidden then
                    assert(c.tier==DT_MEDIUM and c.layer==DL_CONTROLS)
                    local x,y=c.anchor[4],c.anchor[5]
                    assert(x>=0 and y>=0 and x+c.w<=vp.w+.00001 and y+c.h<=vp.h+.00001)
                    assert(c.uv)
                    croppedTop=croppedTop or c.uv[3]>0
                    croppedBottom=croppedBottom or c.uv[4]<1
                end
            end
        end
    end
end
assert(croppedTop and croppedBottom)
-- The billion-gold pile continues beyond the bottom of the bay: its plinth may
-- leave the screen, while a dense vertical slice remains. Text stays above it.
do
    local frame=ui.coins:Frame(1)
    assert(frame.floorY>PBTrade.Config.coins.viewportHeight)
    assert(ui.floors[1].hidden)
    assert(#frame.coins>=PBTrade.Config.coins.columns*3)
    assert(ui.leftBid.layer==DL_OVERLAY and ui.command.layer==DL_OVERLAY)
end
print("PASS ESO-compatible texture crop: top, bottom, plinth, huge stacks and four resolutions")
-- Load the actual entry point after UI construction checks, then open through its scene.
EVENT_ADD_ON_LOADED=101; EVENT_PLAYER_COMBAT_STATE=102; EVENT_CONTROLLER_DISCONNECTED=103
EVENT_PLAYER_DEACTIVATED=104; EVENT_PLAYER_ACTIVATED=105
local events,updates={},{}
EVENT_MANAGER={
    RegisterForEvent=function(_,name,event,callback) events[event]=callback end,
    UnregisterForEvent=function(_,name,event) events[event]=nil end,
    RegisterForUpdate=function(_,name,interval,callback) updates[name]=callback end,
}
SLASH_COMMANDS={}; IsUnitInCombat=function() return false end
local savedName
ZO_SavedVars={NewAccountWide=function(_,name,version,namespace,defaults)
    savedName=name; assert(version==1 and namespace==nil); return defaults
end}
SCENE_MANAGER.Show=function(_,name)
    assert(name==PBTrade.Config.scene)
    scene.callback(nil,SCENE_SHOWING); scene.callback(nil,SCENE_SHOWN)
end
dofile('PBsTradeGame/Main.lua')
events[EVENT_ADD_ON_LOADED](EVENT_ADD_ON_LOADED,'UnrelatedAddon'); assert(not PBTrade.ui)
events[EVENT_ADD_ON_LOADED](EVENT_ADD_ON_LOADED,PBTrade.Config.addonId)
assert(PBTrade.ui and not events[EVENT_ADD_ON_LOADED])
assert(savedName==PBTrade.Config.savedVariables and PBTrade.saved)
-- Load must stay light for the shared console add-on CPU budget.
assert(not PBTrade.app and #PBTrade.ui.coinControls[1]==0 and #PBTrade.ui.coinControls[2]==0)
events[EVENT_PLAYER_ACTIVATED](); PBTrade.Open(); updates[PBTrade.Config.addonId]()
assert(PBTrade.ui.active and PBTrade.app==PBTrade.ui.app)
events[EVENT_PLAYER_DEACTIVATED](); assert(not PBTrade.ui.active and PBTrade.saved.state)
local chatLines={}; CHAT_ROUTER={AddSystemMessage=function(_,text) chatLines[#chatLines+1]=text end}
SLASH_COMMANDS["/pbtrade"]("here"); assert(#chatLines>=1 and chatLines[1]:find("交易戦",1,true)); CHAT_ROUTER=nil
PBTrade.app.screen="management"; PBTrade.app.index=1
local hereRow; for i,row in ipairs(PBTrade.app:Rows()) do if row.command=="here" then hereRow=i end end
assert(hereRow); PBTrade.app.index=hereRow; PBTrade.app.modal=nil; PBTrade.app:Act("confirm")
assert(PBTrade.app.modal and PBTrade.app.modal.text:find("現在地の確認",1,true))
print('PASS actual Main.lua initialization, PX scene open, update and scene hide')
