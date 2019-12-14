local CM = ClickMorph
if not CM.isClassic then return end
local db
local state

local VERSION = 1
local debug_mode
local initTime

local SEX_MALE = 1
local SEX_FEMALE = 2

local EnchantSlots = {
	[1] = INVSLOT_MAINHAND,
	[2] = INVSLOT_OFFHAND,
}

--local FLAG_SMARTMORPH = 2
local playerClass = select(2, UnitClass("player"))
local canShapeshift = playerClass == "DRUID" or playerClass == "SHAMAN"
local shapeshifted

CM.override = true
if CM.override then -- temporary dummy table
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
	self[event](self, ...)
end

iMorphLua:RegisterEvent("PLAYER_ENTERING_WORLD")
iMorphLua:SetScript("OnEvent", iMorphLua.OnEvent)

-- when imorph is already injected
function iMorphLua:PLAYER_ENTERING_WORLD(isInitialLogin, isReloadingUi)
	initTime = time()
	C_Timer.After(0, function() -- imorph api is not yet registered
		if GetClickMorph() then
			print("ClickMorph: overriding iMorph")
		end
		
		if isInitialLogin then
			print("PLAYER_ENTERING_WORLD isInitialLogin")
			self:Initialize()
		elseif not isReloadingUi then -- zoning between instance maps
			print("zoning")
			self:Remorph()
		end
	end)
end

-- fires 2 times when shapeshifting into a form and 3 times when shifting back
function iMorphLua:UPDATE_SHAPESHIFT_FORM()
	local form, formid = GetShapeshiftForm(), GetShapeshiftFormID()
	Spew("UPDATE_SHAPESHIFT_FORM", GetTime(), form, formid)
	shapeshifted = true
end

-- usually fires right after UPDATE_SHAPESHIFT_FORM
function iMorphLua:UNIT_MODEL_CHANGED(target)
	Spew("UNIT_MODEL_CHANGED", GetTime(), target, shapeshifted)
	if shapeshifted then
		-- morphing triggers UNIT_MODEL_CHANGED again, avoid an infinite loop
		shapeshifted = false
		local form, formid = GetShapeshiftForm(), GetShapeshiftFormID()
		--print(form, formid, state.form[form])
		if form and state.form[form] then
			print("morphed to form", form, formid)
			Morph(state.form[form])
		elseif form == 0 and state.morph then
			print("morphed back to humanoid form", form, formid)
			Morph(state.morph)
		end
	end
end

tinsert(CM.db_callbacks, function()
	db = ClickMorphDB
	db.version = VERSION
	state = db.state
	state.form = state.form or {}
end)

-- when imorph is injecting
function iMorphLua:Initialize()
	print("iMorphLua:Initialize")
	if Morph then
		print("iMorphLua:Initialize remorphing")
		self:Remorph()
		-- UPDATE_SHAPESHIFT_FORM can fire before imorph is registered
		if canShapeshift then
			iMorphLua:RegisterEvent("UPDATE_SHAPESHIFT_FORM")
		end
		iMorphLua:RegisterEvent("UNIT_MODEL_CHANGED")
	end
end

-- gets called when imorph injects and on /reload
function iMorphLua:OnInject()
	if time() > initTime + 1 then
		print("iMorphLua:OnInject")
		self:Remorph()
	end
end

function iMorphLua:Remorph()
	print("iMorphLua:Remorph")
	if Morph then
		if state.race or state.sex then
			local race = state.race or select(3, UnitRace("player"))
			local sex = state.sex or UnitSex("player")-1
			SetRace(race, sex)
		end
		if state.morph then
			--print("morph", state.morph)
			Morph(state.morph)
		end
		if state.scale then
			SetScale(state.scale)
		end
	end
end

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
			if canShapeshift then
				local form = GetShapeshiftForm()
				if form > 0 then
					state.form[form] = id
				end
			else
				state.morph = id
			end
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
	--[[
	-- smart morphing
	shapeshift = function(form, displayID)
		form, displayID = tonumber(form), tonumber(displayID)
		if form and displayID then
			--SetShapeshiftForm(form, displayID)
			state.form[form] = displayID
		end
	end,
	enablesm = function()
		SetFlag(FLAG_SMARTMORPH, 1)
	end,
	disablesm = function()
		SetFlag(FLAG_SMARTMORPH, 0)
	end,
	]]
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
