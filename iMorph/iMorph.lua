local CM = ClickMorph
if not CM.isClassic then return end
local db
local state

local SEX_MALE = 1
local SEX_FEMALE = 2

local FLAG_SMARTMORPH = 2

CM.override = true
if CM.override then -- temporary dummy table
	print("ClickMorph: overriding iMorph")
	IMorphInfo = IMorphInfo or {
		items = {},
		enchants = {},
		styles = {},
		forms = {}
	}
else
	return
end

local iMorphLua = CreateFrame("Frame")
_G.iMorphLua = iMorphLua

function iMorphLua:OnEvent(event, ...)
	C_Timer.After(0, function()	-- imorph api is not yet registered
		if state.race or state.sex then
			local race = state.race or select(3, UnitRace("player"))
			local sex = state.sex or UnitSex("player")-1
			SetRace(race, sex)
		end
		if state.morph then
			Morph(state.morph)
		end
		if state.scale then
			SetScale(state.scale)
		end
	end)
end

iMorphLua:RegisterEvent("PLAYER_ENTERING_WORLD")
iMorphLua:SetScript("OnEvent", iMorphLua.OnEvent)

tinsert(CM.db_callbacks, function()
	db = ClickMorphDB
	state = db.state
end)

local EnchantSlots = {
	[1] = INVSLOT_MAINHAND,
	[2] = INVSLOT_OFFHAND,
}

function iMorphLua:Reset()
	SetRace(select(3, UnitRace("player")), UnitSex("player")-1)
	for slot in pairs(CM.SlotNames) do
		SetItem(slot, GetInventoryItemID("player", slot) or 0)
	end
	SetScale(1)
	wipe(state)
end

local help = {
	"|cff7fff00iMorph|r commands:",
	".reset",
	".race |cffFFDAE9<1-9>|r, .gender",
	".morph |cffFFDAE9<id>|r, .morphpet |cffFFDAE9<id>|r",
	".npc |cffFFDAE9<id/name>|r",
	".mount |cffFFDAE9<id>|r",
	".item |cffFFDAE9<1-19> <id>|r, .itemset |cffFFDAE9<id>|r",
	".enchant |cffFFDAE9<1-2> <id>|r",
	".scale |cffFFDAE9<0.5-3.0>|r, .scalepet |cffFFDAE9<scale>|r",
	".title |cffFFDAE9<0-19>|r, .medal |cffFFDAE9<0-8>|r",
	".skin |cffFFDAE9<id>|r, .face |cffFFDAE9<id>|r, .features |cffFFDAE9<id>|r",
	".hair |cffFFDAE9<id>|r, .haircolor |cffFFDAE9<id>|r",
	".weather |cffFFDAE9<id> <0.0-1.0>|r",
	".shapeshift |cffFFDAE9<form id> <display id>|r", ".disablesm, .enablesm",
}

-- cast strings to numbers for each command since .npc also accepts strings
-- on another note, imorph also tries to cast strings to integers
local commands = {
	help = function()
		for _, line in pairs(help) do
			print(line)
		end
	end,
	reset = function()
		iMorphLua:Reset()
	end,
	-- todo: fix hostile races bug
	--  own faction is hostile and "cant speak in that language"
	race = function(raceID)
		raceID = tonumber(raceID)
		local sex = state.sex or UnitSex("player")-1
		if raceID then
			SetRace(raceID, sex)
			state.race = raceID
			state.morph = nil
		end
	end,
	gender = function(sexID)
		sexID = tonumber(sexID)
		local race = state.race or select(3, UnitRace("player"))
		if sexID then
			SetRace(race, sexID)
			state.sex = sexID
		else -- toggle between genders
			local sex = state.sex or UnitSex("player")-1
			if sex == SEX_MALE then
				SetRace(race, SEX_FEMALE)
				state.sex = SEX_FEMALE
			elseif sex == SEX_FEMALE then
				SetRace(race, SEX_MALE)
				state.sex = SEX_MALE
			end
		end
		state.morph = nil
	end,
	morph = function(id)
		id = tonumber(id)
		if id then
			Morph(id)
			state.morph = id
			state.race, state.sex = nil, nil
		end
	end,
	morphpet = function(id)
		id = tonumber(id)
		if id then
			MorphPet(id)
		end
	end,
	npc = function(...)
		local args = {...}
		CM:MorphNpc(table.concat(args, " "))
	end,
	mount = function(id)
		id = tonumber(id)
		if id then
			SetMount(id)
		end
	end,
	item = function(slot, item)
		slot, item = tonumber(slot), tonumber(item)
		if slot and item then
			SetItem(slot, item)
		end
	end,
	itemset = function(id)
		id = tonumber(id)
		if id then
			CM:MorphItemSet(id, true)
		end
	end,
	enchant = function(weapon, enchant)
		weapon, enchant = tonumber(weapon), tonumber(enchant)
		if weapon and enchant then
			SetEnchant(EnchantSlots[weapon], enchant)
		end
	end,
	scale = function(id)
		id = tonumber(id)
		if id then
			SetScale(id)
			state.scale = id
		end
	end,
	scalepet = function(id)
		id = tonumber(id)
		if id then
			SetScalePet(id)
		end
	end,
	title = function(id)
		id = tonumber(id)
		if id then
			SetTitle(id)
		end
	end,
	medal = function(id)
		id = tonumber(id)
		if id then
			SetMedal(id)
		end
	end,
	skin = function(id)
		id = tonumber(id)
		if id then
			SetSkinColor(id)
		end
	end,
	face = function(id)
		id = tonumber(id)
		if id then
			SetFace(id)
		end
	end,
	hair = function(id)
		id = tonumber(id)
		if id then
			SetHairStyle(id)
		end
	end,
	haircolor = function(id)
		id = tonumber(id)
		if id then
			SetHairColor(id)
		end
	end,
	features = function(id)
		id = tonumber(id)
		if id then
			SetFeatures(id)
		end
	end,
	weather = function(id, intensity)
		id, intensity = tonumber(id), tonumber(intensity)
		if id and intensity then
			SetWeather(id, intensity)
		end
	end,
	-- smart morphing
	shapeshift = function(form, displayID)
		form, displayID = tonumber(form), tonumber(displayID)
		if form and displayID then
			SetShapeshiftForm(form, displayID)
		end
	end,
	enablesm = function()
		SetFlag(FLAG_SMARTMORPH, 1)
	end,
	disablesm = function()
		SetFlag(FLAG_SMARTMORPH, 0)
	end,
}

local SendText = ChatEdit_SendText
ChatEdit_SendText = function(editBox, addHistory)
	local text = editBox:GetText()
	local cmd = text:match("^%.(%a+)")
	local func = commands[cmd]
	if Morph and func then
		local params = text:match("^%.%a+ (.+)") or ""
		func(strsplit(" ", params))
	else
		SendText(editBox, addHistory)
	end
end
