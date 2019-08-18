ClickMorph = {}
local CM = ClickMorph

-- LucidMorph: inventory type -> equipment slot -> slot name
local SlotNames = {
	[1] = "head",
	[3] = "shoulder",
	[4] = "shirt",
	[5] = "chest",
	[6] = "belt",
	[7] = "legs",
	[8] = "feet",
	[9] = "wrist",
	[10] = "hands",
	[15] = "cloak",
	[16] = "mainhand",
	[17] = "offhand",
	[19] = "tabard",
}

function CM:PrintChat(msg, r, g, b)
	DEFAULT_CHAT_FRAME:AddMessage(format("|cff7fff00ClickMorph|r: |r%s", msg), r, g, b)
end

function CM:GetJMorph()
	return jMorphLoaded and self.morphers.jMorph
end

function CM:GetLucidMorph()
	return lm and self.morphers.LucidMorph
end

function CM:CanMorph()
	-- todo: allow manually calling clickmorph functions while not holding alt
	if IsAltKeyDown() then
		local morph = self:GetJMorph() or self:GetLucidMorph()
		if morph then
			return morph
		else
			self:PrintChat("jMorph or LucidMorph is not loaded!", 1, 1, 0)
		end
	end
end

CM.morphers = {
	jMorph = {
		model = function(unit, displayID) -- .morph
			SetDisplayID(unit, displayID)
			UpdateModel(unit)
		end,
		race = function(unit, raceID)
			SetDisplayID(unit, 0)
			SetAlternateRace(unit, raceID)
			UpdateModel(unit)
		end,
		gender = function(unit, genderID, raceID)
			SetGender(unit, genderID)
			SetAlternateRace(unit, raceID)
			UpdateModel(unit)
		end,
		mount = function(displayID)
			SetMountDisplayID("player", displayID)
			if IsMounted() and not UnitOnTaxi("player") then
				MorphPlayerMount()
				return true
			else
				CM:PrintChat("You need to be mounted and not on a flight path", 1, 1, 0)
			end
		end,
		item = function(unit, slotID, itemID, itemModID)
			SetVisibleItem(unit, slotID, itemID, itemModID)
			-- dont automatically update for every item in an item set
		end,
		update = function(unit)
			UpdateModel(unit)
		end,
		enchant = function(unit, slotID, visualID)
			SetVisibleEnchant(unit, slotID, visualID)
			UpdateModel(unit)
		end,
		-- spell (nyi)
		-- title
		-- scale
		-- skin
		-- face
		-- hair
		-- haircolor
		-- piercings
		-- tattoos
		-- horns
		-- blindfold
		-- shapeshift
		-- weather
	},
	LucidMorph = {
		model = function(_, displayID)
			lm("model", displayID)
			lm("morph")
		end,
		mount = function(displayID)
			lm("mount", displayID)
			lm("morph")
			return true
		end,
		item = function(_, slotID, itemID, itemModID)
			lm(SlotNames[slotID], itemID, itemModID)
		end,
		update = function()
			lm("morph")
		end,
		enchant = function(_, slotID, visualID)
			lm(SlotNames[slotID], nil, nil, visualID)
			lm("morph")
		end,
	},
}

-- Mounts
function CM:MorphMount(unit, mountID)
	local morph = self:CanMorph()
	if morph and morph.mount then
		local _, spellID = C_MountJournal.GetMountInfoByID(mountID)
		local displayID = C_MountJournal.GetMountInfoExtraByID(mountID)
		if not displayID then
			local multipleIDs = C_MountJournal.GetMountAllCreatureDisplayInfoByID(mountID)
			displayID = multipleIDs[random(#multipleIDs)].creatureDisplayID
		end
		if morph.mount(displayID) then
			CM:PrintChat(format("Morphed mount to |cff71D5FF%d|r %s", displayID, GetSpellLink(spellID)))
		end
	end
end

function CM.MorphMountModelScene()
	local mountID = MountJournal.selectedMountID
	CM:MorphMount("player", mountID)
end

function CM.MorphMountScrollFrame(frame)
	local mountID = select(12, C_MountJournal.GetDisplayedMountInfo(frame.index))
	CM:MorphMount("player", mountID)
end

function CM:MorphItem(unit, source)
	local morph = self:CanMorph()
	if morph and morph.item then
		local slotID = C_Transmog.GetSlotForInventoryType(source.invType)
		local itemLink = select(6, C_TransmogCollection.GetAppearanceSourceInfo(source.sourceID))
		local itemText = itemLink:find("%[%]") and CM.ItemAppearance and CM.ItemAppearance[source.visualID] or itemLink
		morph.item(unit, slotID, source.itemID, source.itemModID)
		morph.update(unit)
		self:PrintChat(format("Morphed |cffFFFF00%s|r to item |cff71D5FF%d:%d|r %s", SlotNames[slotID], source.itemID, source.itemModID, itemText))
	end
end

function CM:MorphEnchant(unit, slotID, visualID, enchantName)
	local morph = self:CanMorph()
	if morph and morph.enchant then
		morph.enchant(unit, slotID, visualID)
		self:PrintChat(format("Morphed |cffFFFF00%s|r to enchant |cff71D5FF%d|r %s", SlotNames[slotID], visualID, enchantName))
	end
end

function CM:MorphModel(unit, displayID)
	local morph = self:CanMorph()
	if morph and morph.model then
		morph.model(unit, displayID)
		self:PrintChat(format("Morphed to model |cff71D5FF%d|r", displayID))
	end
end

-- Appearances
function CM.MorphTransmogSet()
	local morph = CM:CanMorph()
	if morph and morph.item then
		local setID = WardrobeCollectionFrame.SetsCollectionFrame.selectedSetID
		local setInfo = C_TransmogSets.GetSetInfo(setID)

		for _, v in pairs(WardrobeSetsDataProviderMixin:GetSortedSetSources(setID)) do
			local source = C_TransmogCollection.GetSourceInfo(v.sourceID)
			local slotID = C_Transmog.GetSlotForInventoryType(v.invType)
			morph.item("player", SlotNames[slotID], source.itemID, source.itemModID)
		end
		morph.update("player")
		CM:PrintChat(format("Morphed to set |cff71D5FF%d: %s|r (%s)", setID, setInfo.name, setInfo.description or ""))
	end
end

function CM.MorphTransmogItem(frame)
	local transmogType = WardrobeCollectionFrame.ItemsCollectionFrame.transmogType
	local visualID = frame.visualInfo.visualID

	if transmogType == LE_TRANSMOG_TYPE_ILLUSION then
		local activeSlot = WardrobeCollectionFrame.ItemsCollectionFrame.activeSlot
		local slotID = GetInventorySlotInfo(activeSlot)
		local name
		if frame.visualInfo.sourceID then
			local link = select(3, C_TransmogCollection.GetIllusionSourceInfo(frame.visualInfo.sourceID))
			name = #link > 0 and link
		end
		CM:MorphEnchant("player", slotID, visualID, name or CM.ItemVisuals[visualID])
	elseif transmogType == LE_TRANSMOG_TYPE_APPEARANCE then
		local sources = WardrobeCollectionFrame_GetSortedAppearanceSources(visualID)
		for idx, source in pairs(sources) do
			-- get the index the arrow is pointing at
			if idx == WardrobeCollectionFrame.tooltipSourceIndex then
				CM:MorphItem("player", source)
			end
		end
	end
end

-- MogIt
if IsAddOnLoaded("MogIt") then
	hooksecurefunc(MogIt, "UpdateGUI", function(frame, resize)
		if not resize then -- models have been initialized
			for _, model in pairs(MogIt.models) do
				local oldOnClick = model:GetScript("OnClick")
				model:SetScript("OnClick", function(frame, button)
					-- prevent cycling through items when pressing alt
					if IsAltKeyDown() then
						CM:MorphMogItCatalogue(frame)
					else
						oldOnClick(frame, button)
					end
				end)
			end
		end
	end)
	hooksecurefunc(MogIt, "CreatePreview", function()
		for _, prev in pairs(MogIt.previews) do
			prev.model:HookScript("OnClick", CM.MorphMogItPreview)
		end
	end)
end

function CM:MorphMogItCatalogue(frame)
	local data = frame.data
	local source = C_TransmogCollection.GetSourceInfo(data.value[data.cycle])
	self:MorphItem("player", source)
end

function CM.MorphMogItPreview(frame)
	local slots = {}
	-- not sure where mogit stores the preview sourceids, get it from the item instead
	for _, slot in pairs(frame.parent.slots) do
		if slot.item then
			local _, sourceID = C_TransmogCollection.GetItemInfo(slot.item)
			local source = C_TransmogCollection.GetSourceInfo(sourceID)
			local slotId = C_Transmog.GetSlotForInventoryType(source.invType)
			tinsert(slots, {slotId, source})
		end
	end

	sort(slots, function(a, b)
		return a[1] < b[1]
	end)
	for _, v in pairs(slots) do
		CM:MorphItem("player", v[2])
	end
end

-- Taku's Morph Catalog
if IsAddOnLoaded("TakusMorphCatalog") then
	for _, child in pairs({UIParent:GetChildren()}) do
		if child.Collection and child.ModelPreview then -- found TMCFrame
			local oldOnClick = child.ModelPreview:GetScript("OnMouseDown")
			child.ModelPreview:SetScript("OnMouseDown", function(frame, button)
				-- dont click the frame away if morphing
				if IsAltKeyDown() then
					CM:MorphModel("player", frame.ModelFrame.DisplayInfo)
				else
					oldOnClick(frame)
				end
			end)
			break
		end
	end
end
