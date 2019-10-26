local CM = ClickMorph

local StdUi = LibStub("StdUi")
local window = StdUi:Window(UIParent, 200, 250, "ClickMorph")
window:SetPoint("CENTER")
window:Hide() -- visible by default

window.name = "ClickMorph"
InterfaceOptions_AddCategory(window)

-- race, gender
local races = {}
for i = 1, 9 do
	tinsert(races, {
		value = i,
		text = C_CreatureInfo.GetRaceInfo(i).raceName,
	})
end

local race_dd = StdUi:Dropdown(window, 100, 20, races, select(3, UnitRace("player")))
race_dd:SetPoint("TOPLEFT", 20, -60)

local genders = {
	{value = 1, text = MALE},
	{value = 2, text = FEMALE},
}

local sex_dd = StdUi:Dropdown(window, 100, 20, genders, UnitSex("player")-1)
StdUi:GlueBelow(sex_dd, race_dd, 0, -10)

race_dd.OnValueChanged = function(self, raceId)
	CM:MorphRace("player", raceId, sex_dd.value)
end

sex_dd.OnValueChanged = function(self, sexId)
	CM:MorphRace("player", race_dd.value, sexId)
end

-- model
local model_eb = StdUi:NumericBox(window, 100, 20, 0)
StdUi:GlueBelow(model_eb, sex_dd, 0, -30, "LEFT")

local model_text = ".morph |cffFFFFFF%d|r"
local model_fs = StdUi:FontString(window, model_text:format(0))
StdUi:GlueTop(model_fs, model_eb, 0, 15)

model_eb.OnValueChanged = function(self, displayID)
	model_fs:SetText(model_text:format(displayID))
	CM:MorphModel("player", displayID, nil, nil, true)
end

-- scale
local scale_slider = StdUi:Slider(window, 100, 20, 1, false, .5, 3)
StdUi:GlueBelow(scale_slider, model_eb, 0, -30, "LEFT")

local scale_text = ".scale |cffFFFFFF%.1f|r"
local scale_fs = StdUi:FontString(window, scale_text:format(1))
StdUi:GlueTop(scale_fs, scale_slider, 0, 15)

scale_slider.OnValueChanged = function(self, value)
	scale_fs:SetText(scale_text:format(value))
	CM:MorphScale("player", value)
end

-- reset
local reset_btn = StdUi:Button(window, 100, 20, "|cffFF0000"..RESET.."|r")
StdUi:GlueBottom(reset_btn, window, -10, 10, "RIGHT")

reset_btn:SetScript("OnClick", function()
	-- todo: reset race/sex dropdowns
	model_fs:SetText(model_text:format(0))
	model_eb:SetText(0)
	scale_slider:SetValue(1)
	CM:ResetMorph()
end)

SLASH_CLICKMORPH1 = "/cm"
SLASH_CLICKMORPH2 = "/clickmorph"

function SlashCmdList.CLICKMORPH()
	if window:IsShown() then
		window:Hide()
	else
		window:Show()
	end
end
