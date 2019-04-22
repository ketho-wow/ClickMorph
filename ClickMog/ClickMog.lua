
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

function CM:PrintChat(msg, color)
	color = color or "FFFFFF"
	print(string.format("|cffff7d0a[|r|cff7fff00ClickMog|r|cffff7d0a]: |r|cff%s%s", color, msg))
end

function CM:HasLucidMorph()
	if lm then
		return true
	else
		self:PrintChat("LucidMorph commands are not registered!", "FF0033")
		self:PrintChat("To enable the use of this addon please click 'Filter' > 'commands' in LucidMorph.", "2F6BE5")
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
		PlaySound(62542)
		CM:PrintChat(format("Morphed mount to ID |cffFFFFFF%d|r %s", displayID, GetSpellLink(spellID)), "FF6600")
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
		PlaySound(62542) -- ui_transmogrify_apply.ogg
		CM:PrintChat(format("Morphed to set |cffFFFFFF%d: %s|r", setID, name), "FF6600")
	end
end

function CM.MorphItem(frame, button)
	if IsLeftAltKeyDown() and CM:HasLucidMorph() then
		local transmogType = WardrobeCollectionFrame.ItemsCollectionFrame.transmogType
		local activeSlot = WardrobeCollectionFrame.ItemsCollectionFrame.activeSlot
		local slotID = GetInventorySlotInfo(activeSlot)
		
		if transmogType == LE_TRANSMOG_TYPE_ILLUSION then
			local visualID, name, link = C_TransmogCollection.GetIllusionSourceInfo(frame.visualInfo.sourceID)
			
			if activeSlot == "MAINHANDSLOT" then
				lm("mainhand", nil, nil, frame.visualInfo.visualID)
				lm("morph")
			elseif activeSlot == "SECONDARYHANDSLOT" then					
				lm("offhand", nil, nil, frame.visualInfo.visualID)
				lm("morph")
			end
			CM:PrintChat(format("Morphed %s to enchant |cffFFFFFF%d|r %s", SlotNames[slotID], visualID, link), "FF6600")
			
		elseif transmogType == LE_TRANSMOG_TYPE_APPEARANCE then
			local sources = WardrobeCollectionFrame_GetSortedAppearanceSources(frame.visualInfo.visualID)		
			
			for k, v in pairs(sources) do
				-- get the index the arrow is pointing at
				if k == WardrobeCollectionFrame.tooltipSourceIndex then
					lm(SlotNames[slotID], v.itemID, v.itemModID)
					lm("morph")
					local itemLink = select(6, C_TransmogCollection.GetAppearanceSourceInfo(v.sourceID))
					CM:PrintChat(format("Morphed %s to item |cffFFFFFF%d:%d|r %s", SlotNames[slotID], v.itemID, v.itemModID, itemLink), "FF6600")
				end
			end
		end
		PlaySound(62542)
	end
end