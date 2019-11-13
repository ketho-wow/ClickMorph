local CM = ClickMorph
local StdUi = LibStub("StdUi")
local version = format("|cff71D5FF%s|r", GetAddOnMetadata("ClickMorph", "Version"))
local gui

function CM:CreateGUI()
	gui = StdUi:Window(UIParent, 350, 250, "ClickMorph "..version)
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
		CM:MorphRace("player", raceId, sex_dd.value)
	end

	sex_dd.OnValueChanged = function(widget, sexId)
		CM:MorphRace("player", race_dd.value, sexId)
	end

	-- model
	local model_eb = StdUi:NumericBox(gui, 100, 20, 0)
	StdUi:GlueBelow(model_eb, race_dd, 0, -30, "LEFT")

	local model_fs = StdUi:FontString(gui, ".morph")
	StdUi:GlueTop(model_fs, model_eb, 0, 15)

	model_eb.OnValueChanged = function(widget, displayID)
		CM:MorphModel("player", displayID, nil, nil, true)
	end

	local or_fs = StdUi:Label(gui, "OR")
	StdUi:GlueRight(or_fs, model_eb, 10, 0)

	-- npc
	local npcNames = {}
	local npcIds = self:GetDisplayIDs()
	for id, tbl in pairs(npcIds) do
		tinsert(npcNames, {
			value = id,
			text = tbl[2],
		})
	end

	local npc_eb = StdUi:Autocomplete(gui, 170, 20, nil, nil, nil, npcNames)
	StdUi:GlueRight(npc_eb, or_fs, 10, 0)

	local npc_fs = StdUi:FontString(gui, ".npc")
	StdUi:GlueTop(npc_fs, npc_eb, 0, 15)

	npc_eb.OnValueChanged = function(widget, npcId, name)
		npcId = npcId or tonumber(name)
		if npcId then
			local npcInfo = npcIds[npcId]
			if npcInfo then
				CM:MorphNpcByID(npcId)
				local displayId = npcInfo[1]
				model_eb:SetText(displayId)
				return
			end
		end
		CM:PrintChat("Could not find NPC "..name)
	end

	-- scale
	local scale_slider = StdUi:Slider(gui, 150, 20, 1, false, .5, 3)
	StdUi:GlueBelow(scale_slider, model_eb, 0, -30, "LEFT")

	local scale_text = ".scale |cffFFFFFF%.1f|r"
	local scale_fs = StdUi:FontString(gui, scale_text:format(1))
	StdUi:GlueTop(scale_fs, scale_slider, 0, 15)

	scale_slider.OnValueChanged = function(widget, value)
		scale_fs:SetText(scale_text:format(value))
		CM:MorphScale("player", value)
	end

	-- reset
	local reset_btn = StdUi:Button(gui, 100, 20, "|cffFF0000"..RESET.."|r")
	StdUi:GlueBottom(reset_btn, gui, -10, 10, "RIGHT")

	reset_btn:SetScript("OnClick", function()
		-- todo: reset race/sex dropdowns
		model_eb:SetText(0)
		npc_eb:SetText("")
		scale_slider:SetValue(1)
		CM:ResetMorph()
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
