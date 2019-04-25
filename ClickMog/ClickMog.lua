
ClickMog = {}
local CM = ClickMog

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
	DEFAULT_CHAT_FRAME:AddMessage(format("|cff7fff00ClickMog|r: |r%s", msg), r, g, b)
end

function CM:HasLucidMorph()
	if lm then
		return true
	else
		self:PrintChat("LucidMorph commands are not registered!", 255, 0, 51)
		self:PrintChat("To enable the use of this addon please click 'Filter' > 'commands' in LucidMorph.", 47, 107, 229)
	end
end

function CM.MorphMount(frame, button)
	if IsLeftAltKeyDown() and CM:HasLucidMorph() then
		local mountID = MountJournal.selectedMountID
		local _, spellID = C_MountJournal.GetMountInfoByID(mountID)
		local displayID = C_MountJournal.GetMountInfoExtraByID(mountID)
		
		if not displayID then
			local multipleIDs = C_MountJournal.GetMountAllCreatureDisplayInfoByID(mountID)
			displayID = multipleIDs[random(#multipleIDs)].creatureDisplayID
		end
		lm("mount", displayID)
		lm("morph")
		CM:PrintChat(format("Morphed mount to |cff71D5FF%d|r %s", displayID, GetSpellLink(spellID)))
	end
end

function CM.MorphItemSet(frame, button)
	if IsLeftAltKeyDown() and CM:HasLucidMorph() then
		local setID = WardrobeCollectionFrame.SetsCollectionFrame.selectedSetID
		local name = C_TransmogSets.GetSetInfo(setID).name
		
		for _, v in pairs(WardrobeSetsDataProviderMixin:GetSortedSetSources(setID)) do
			local source = C_TransmogCollection.GetSourceInfo(v.sourceID)
			lm(SlotNames[C_Transmog.GetSlotForInventoryType(v.invType)], source.itemID, source.itemModID)
		end
		lm("morph")
		CM:PrintChat(format("Morphed to set |cff71D5FF%d: %s|r", setID, name))
	end
end

function CM.MorphItem(frame, button)
	if IsLeftAltKeyDown() and CM:HasLucidMorph() then
		local transmogType = WardrobeCollectionFrame.ItemsCollectionFrame.transmogType
		local activeSlot = WardrobeCollectionFrame.ItemsCollectionFrame.activeSlot
		local slotID = GetInventorySlotInfo(activeSlot)
		local visualID = frame.visualInfo.visualID
		
		if transmogType == LE_TRANSMOG_TYPE_ILLUSION then
			if activeSlot == "MAINHANDSLOT" then
				lm("mainhand", nil, nil, visualID)
				lm("morph")
			elseif activeSlot == "SECONDARYHANDSLOT" then					
				lm("offhand", nil, nil, visualID)
				lm("morph")
			end
			
			local name
			if frame.visualInfo.sourceID then
				name = select(3, C_TransmogCollection.GetIllusionSourceInfo(frame.visualInfo.sourceID))
			end
			
			if not name or name == "" then
				name = CM.ItemVisuals[visualID]
			end
			
			CM:PrintChat(format("Morphed %s to enchant |cff71D5FF%d|r %s", SlotNames[slotID], visualID, name))
			
		elseif transmogType == LE_TRANSMOG_TYPE_APPEARANCE then
			local sources = WardrobeCollectionFrame_GetSortedAppearanceSources(visualID)		
			
			for k, v in pairs(sources) do
				-- get the index the arrow is pointing at
				if k == WardrobeCollectionFrame.tooltipSourceIndex then
					lm(SlotNames[slotID], v.itemID, v.itemModID)
					lm("morph")
					local itemLink = select(6, C_TransmogCollection.GetAppearanceSourceInfo(v.sourceID))
					CM:PrintChat(format("Morphed %s to item |cff71D5FF%d:%d|r %s", SlotNames[slotID], v.itemID, v.itemModID, itemLink))
				end
			end
		end
	end
end