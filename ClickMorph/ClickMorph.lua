
ClickMorph = {}
local CM = ClickMorph

-- inventory type -> equipment slot -> slot name
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

function CM:HasLucidMorph()
	if lm then
		return true
	else
		self:PrintChat("LucidMorph commands are not registered!", 1, 1, 0)
		self:PrintChat("To enable the use of this addon please click \"Filter\" > \"Commands\" in LucidMorph.")
	end
end

function CM:CanMorph()
	return IsAltKeyDown() and self:HasLucidMorph()
end

function CM:MorphMount(mountID)
	if self:CanMorph() then
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

function CM:MorphAppearance(source)
	if self:CanMorph() then
		local slotName = SlotNames[C_Transmog.GetSlotForInventoryType(source.invType)]
		local itemLink = select(6, C_TransmogCollection.GetAppearanceSourceInfo(source.sourceID))
		local itemText = itemLink:find("%[%]") and CM.ItemAppearance and CM.ItemAppearance[source.visualID] or itemLink
		
		lm(slotName, source.itemID, source.itemModID)
		lm("morph")
		self:PrintChat(format("Morphed |cffFFFF00%s|r to item |cff71D5FF%d:%d|r %s", slotName, source.itemID, source.itemModID, itemText))
	end
end

function CM:MorphIllusion(slotName, visualID, enchantName)
	if self:CanMorph() then
		lm(slotName, nil, nil, visualID)
		lm("morph")
		self:PrintChat(format("Morphed |cffFFFF00%s|r to enchant |cff71D5FF%d|r %s", slotName, visualID, enchantName))
	end
end

function CM:MorphModel(displayID)
	if self:CanMorph() then
		lm("model", displayID)
		lm("morph")
		self:PrintChat(format("Morphed to model |cff71D5FF%d|r", displayID))
	end
end

-- Mounts
function CM.MorphMountModelScene()
	local mountID = MountJournal.selectedMountID
	CM:MorphMount(mountID)
end

function CM.MorphMountScrollFrame(frame)
	local mountID = select(12, C_MountJournal.GetDisplayedMountInfo(frame.index))
	CM:MorphMount(mountID)
end

-- Appearances
function CM.MorphTransmogSet()
	if CM:CanMorph() then
		local setID = WardrobeCollectionFrame.SetsCollectionFrame.selectedSetID
		local setInfo = C_TransmogSets.GetSetInfo(setID)
		
		for _, v in pairs(WardrobeSetsDataProviderMixin:GetSortedSetSources(setID)) do
			local source = C_TransmogCollection.GetSourceInfo(v.sourceID)
			local slotID = C_Transmog.GetSlotForInventoryType(v.invType)
			lm(SlotNames[slotID], source.itemID, source.itemModID)
		end
		lm("morph")
		CM:PrintChat(format("Morphed to set |cff71D5FF%d: %s|r (%s)", setID, setInfo.name, setInfo.description or ""))
	end
end

function CM.MorphTransmogItem(frame)
	local transmogType = WardrobeCollectionFrame.ItemsCollectionFrame.transmogType
	local visualID = frame.visualInfo.visualID
	
	if transmogType == LE_TRANSMOG_TYPE_ILLUSION then
		local activeSlot = WardrobeCollectionFrame.ItemsCollectionFrame.activeSlot
		local slotName = SlotNames[GetInventorySlotInfo(activeSlot)]
		local name
		if frame.visualInfo.sourceID then
			local link = select(3, C_TransmogCollection.GetIllusionSourceInfo(frame.visualInfo.sourceID))
			name = #link > 0 and link
		end
		CM:MorphIllusion(slotName, visualID, name or CM.ItemVisuals[visualID])
		
	elseif transmogType == LE_TRANSMOG_TYPE_APPEARANCE then
		local sources = WardrobeCollectionFrame_GetSortedAppearanceSources(visualID)		
		for idx, source in pairs(sources) do
			-- get the index the arrow is pointing at
			if idx == WardrobeCollectionFrame.tooltipSourceIndex then
				CM:MorphAppearance(source)
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
	self:MorphAppearance(source)
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
		CM:MorphAppearance(v[2])
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
					CM:MorphModel(frame.ModelFrame.DisplayInfo)
				else
					oldOnClick(frame)
				end
			end)
			break
		end
	end
end
