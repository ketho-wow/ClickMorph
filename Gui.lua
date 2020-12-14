local CM = ClickMorph
if CM.isClassic then return end
local StdUi = LibStub("StdUi")
local version = format("|cff71D5FF%s|r", GetAddOnMetadata("ClickMorph", "Version"))
local gui
local FileData

function CM:CreateGUI()
	FileData = self:GetFileData()
	gui = StdUi:Window(UIParent, 350, 300, "ClickMorph "..version)
	gui:SetPoint("CENTER", 320, 0)
	gui:Hide() -- visible by default

	gui.name = "ClickMorph"
	InterfaceOptions_AddCategory(gui)

	-- race, gender
	local races = {}
	for i = 1, 9 do
		tinsert(races, {
			value = i,
			text = C_CreatureInfo.GetRaceInfo(i).raceName,
		})
	end

	local race_dd = StdUi:Dropdown(gui, 100, 20, races, select(3, UnitRace("player")))
	race_dd:SetPoint("TOPLEFT", 20, -60)
	
	local genders = {
		{value = 1, text = MALE},
		{value = 2, text = FEMALE},
	}

	local sex_dd = StdUi:Dropdown(gui, 100, 20, genders, UnitSex("player")-1)
	StdUi:GlueRight(sex_dd, race_dd, 10, 0)

	race_dd.OnValueChanged = function(widget, raceId)
		self:MorphRace("player", raceId, sex_dd.value)
	end

	sex_dd.OnValueChanged = function(widget, sexId)
		self:MorphRace("player", race_dd.value, sexId)
	end

	-- model
	local model_eb = StdUi:NumericBox(gui, 100, 20, 0)
	StdUi:GlueBelow(model_eb, race_dd, 0, -30, "LEFT")

	local model_fs = StdUi:FontString(gui, ".morph")
	StdUi:GlueTop(model_fs, model_eb, 0, 15)

	model_eb.OnValueChanged = function(widget, displayID)
		self:MorphModel("player", displayID, nil, nil, true)
	end

	local or_fs = StdUi:Label(gui, "OR")
	StdUi:GlueRight(or_fs, model_eb, 10, 0)

	-- npc
	local npcNames = {}
	local npcIDs = self:GetDisplayIDs()
	for id, tbl in pairs(npcIDs) do
		tinsert(npcNames, {
			value = id,
			text = tbl[2],
		})
	end

	local npc_eb = StdUi:Autocomplete(gui, 170, 20, nil, nil, nil, npcNames)
	StdUi:GlueRight(npc_eb, or_fs, 10, 0)

	local npc_fs = StdUi:FontString(gui, ".npc")
	StdUi:GlueTop(npc_fs, npc_eb, 0, 15)

	npc_eb.OnValueChanged = function(widget, npcID, name)
		npcID = npcID or tonumber(name)
		if npcID then
			local npcInfo = npcIDs[npcID]
			if npcInfo then
				self:MorphNpcByID(npcID)
				local displayID = npcInfo[1]
				model_eb:SetText(displayID)
				return
			end
		end
		self:PrintChat("Could not find NPC "..name)
	end

	-- mount
	local mountNames = self.isClassic and self:GetClassicMountIDs() or {}
	local mount_eb = StdUi:Dropdown(gui, 210, 20, mountNames)
	StdUi:GlueBelow(mount_eb, model_eb, 0, -30, "LEFT")

	local mount_fs = StdUi:FontString(gui, ".mount")
	StdUi:GlueTop(mount_fs, mount_eb, 0, 15)

	mount_eb.OnValueChanged = function(widget, id, name)
		id = id or tonumber(name)
		local mountIDs = FileData[self.project].Mount[id]
		if mountIDs then
			self:MorphMountClassic("player", id, mountIDs.spell, true)
			return
		end
		self:PrintChat("Could not find mount "..name)
	end

	-- scale
	local scale_slider = StdUi:Slider(gui, 210, 20, 1, false, .5, 3)
	StdUi:GlueBelow(scale_slider, mount_eb, 0, -30, "LEFT")
	-- default slider is hard to see
	-- dont want to change color for all buttons instead of just slider thumb
	scale_slider:SetBackdropColor(.2, .2, .2)
	scale_slider.thumb:SetBackdropColor(.8, .8, .8)

	local scale_text = ".scale |cffFFFFFF%.1f|r"
	local scale_fs = StdUi:FontString(gui, scale_text:format(1))
	StdUi:GlueTop(scale_fs, scale_slider, 0, 15)

	scale_slider.OnValueChanged = function(widget, value)
		scale_fs:SetText(scale_text:format(value))
		self:MorphScale("player", value)
	end

	-- remember morph
	local remember = StdUi:Checkbox(gui, "Remorph on Inject/Relog")
	StdUi:GlueTop(remember, scale_slider, 0, -40, "LEFT")
	remember:SetChecked(ClickMorphDB.imorphv1.remember)

	remember.OnValueChanged = function(widget, state)
		ClickMorphDB.imorphv1.remember = state
	end

	-- silent mode
	local silent = StdUi:Checkbox(gui, "Silent Mode")
	StdUi:GlueTop(silent, remember, 0, -20, "LEFT")
	silent:SetChecked(ClickMorphDB.silent)

	silent.OnValueChanged = function(widget, state)
		ClickMorphDB.silent = state
	end

	-- reset
	local reset_btn = StdUi:Button(gui, 100, 20, "|cffFF0000"..RESET.."|r")
	StdUi:GlueBottom(reset_btn, gui, -10, 10, "RIGHT")

	reset_btn:SetScript("OnClick", function()
		race_dd:SetText(races[select(3, UnitRace("player"))].text)
		sex_dd:SetText(genders[UnitSex("player")-1].text)
		model_eb:SetText(0)
		npc_eb:SetText("")
		mount_eb:SetText("")
		scale_slider:SetValue(1) -- doesnt change scale if the slider value is already at 1
		self:MorphScale("player", 1)
		self:ResetMorph()
	end)
end

SLASH_CLICKMORPH1 = "/cm"
SLASH_CLICKMORPH2 = "/clickmorph"

function SlashCmdList.CLICKMORPH()
	if not gui then
		CM:CreateGUI()
	end
	if gui:IsShown() then
		gui:Hide()
	else
		gui:Show()
	end
end
