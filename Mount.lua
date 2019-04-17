
local _, ns = ...
local CM = ns.ClickMog

local f = CreateFrame("Frame")
local UM = {}

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

if IsAddOnLoaded("Blizzard_Collections") then
    f:Initialize()
else
    f:RegisterEvent("ADDON_LOADED")
    f:SetScript("OnEvent", function(self, event, addon)
        if addon == "Blizzard_Collections" then
            self:Initialize()
            self:UnregisterEvent(event)
        end
    end)
end

local function PrintChat(msg, color)
	color = color or "FFFFFF"
	print(string.format("|cffff7d0a[|r|cff7fff00ClickMog|r|cffff7d0a]: |r|cff%s%s", color, msg))
end

local function HasLucidMorph()
	if lm then
		return true
	else
		PrintChat("LucidMorph commands are not registered!", "FF0033")
		PrintChat("To enable the use of this addon please click 'Filter' > 'commands' in LucidMorph.", "2F6BE5")
	end
end

function f:Initialize()
	-- item sets model
	WardrobeCollectionFrame.SetsCollectionFrame.Model:HookScript("OnMouseDown", UM.MorphItemSet)
	
	-- item models
	for _, model in pairs(WardrobeCollectionFrame.ItemsCollectionFrame.Models) do
		model:HookScript("OnMouseDown", UM.MorphItem)
	end
	
	-- mount journal
	MountJournal.MountDisplay.ModelScene:HookScript("OnMouseDown", UM.MorphMount)
	UM:UnlockMounts()
	PrintChat("for LucidMorph loaded!", "FA7268")
end

function UM.MorphItemSet(frame, button)
	if IsLeftAltKeyDown() and HasLucidMorph() then
		local setID = WardrobeCollectionFrame.SetsCollectionFrame.selectedSetID
		local name = C_TransmogSets.GetSetInfo(setID).name
		
		for _, v in pairs(WardrobeSetsDataProviderMixin:GetSortedSetSources(setID)) do
			local source = C_TransmogCollection.GetSourceInfo(v.sourceID)
			lm(SlotNames[C_Transmog.GetSlotForInventoryType(v.invType)], source.itemID, source.itemModID)
		end
		lm("morph")
		PlaySound(62542)
		PrintChat(format("Morphed to set |cffFFFFFF%d: %s|r", setID, name), "FF6600")
	end
end

function UM.MorphItem(frame, button)
	if IsLeftAltKeyDown() and HasLucidMorph() then
		local transmogType = WardrobeCollectionFrame.ItemsCollectionFrame.transmogType
		local activeSlot = WardrobeCollectionFrame.ItemsCollectionFrame.activeSlot
		local slotID = GetInventorySlotInfo(activeSlot)
		
		if transmogType == LE_TRANSMOG_TYPE_ILLUSION then
			local visualID, name, link = C_TransmogCollection.GetIllusionSourceInfo(frame.visualInfo.sourceID)
			print(frame.visualInfo.sourceID)
			if activeSlot == "MAINHANDSLOT" then
				lm("mainhand", nil, nil, frame.visualInfo.visualID)
				lm("morph")
			elseif activeSlot == "SECONDARYHANDSLOT" then					
				lm("offhand", nil, nil, frame.visualInfo.visualID)
				lm("morph")
			end
			PrintChat(format("Morphed %s to enchant |cffFFFFFF%d|r %s", SlotNames[slotID], visualID, link), "FF6600")
			
		elseif transmogType == LE_TRANSMOG_TYPE_APPEARANCE then
			local sources = WardrobeCollectionFrame_GetSortedAppearanceSources(frame.visualInfo.visualID)		
			
			for k, v in pairs(sources) do
				-- only PrintChat the current source index the arrow is pointing at
				if k == WardrobeCollectionFrame.tooltipSourceIndex then
					lm(SlotNames[slotID], v.itemID, v.itemModID)
					lm("morph")
					local itemLink = select(6, C_TransmogCollection.GetAppearanceSourceInfo(v.sourceID))
					PrintChat(format("Morphed %s to item |cffFFFFFF%d:%d|r %s", SlotNames[slotID], v.itemID, v.itemModID, itemLink), "FF6600")
				end
			end
		end
		PlaySound(62542)
	end
end

function UM.MorphMount(frame, button)
	if IsLeftAltKeyDown() and HasLucidMorph() then
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
		PrintChat(format("Morphed mount to ID |cffFFFFFF%d|r %s", displayID, GetSpellLink(spellID)), "FF6600")
	end
end

function UM:UnlockMounts()
	local mountIDs = C_MountJournal.GetMountIDs()
	local searchMountIDs, activeSearch = {}
	
	-- sort alphabetically
	sort(mountIDs, function(a, b)
		local name1, _, _, _, _, _, isFavorite1 = C_MountJournal.GetMountInfoByID(a)
		local name2, _, _, _, _, _, isFavorite2 = C_MountJournal.GetMountInfoByID(b)
		
		-- show favorites first, cant favorite an uncollected mount btw
		if isFavorite1 ~= isFavorite2 then
			return isFavorite1
		else
			return name1 < name2
		end
	end)
	
	-- replace C_MountJournal functions, pray nothing explodes
	local function GetMountIDs()
		return activeSearch and searchMountIDs or mountIDs
	end
	
	function C_MountJournal.GetNumDisplayedMounts()
		return #GetMountIDs()
	end
	
	function C_MountJournal.GetDisplayedMountInfo(index)
		local ids = GetMountIDs()
		local args = {C_MountJournal.GetMountInfoByID(ids[index])}
		args[5] = true -- fake isUsable
		return unpack(args)
	end
	
	-- set mount count fontstring
	local function UpdateMountCount()
		MountJournal.MountCount.Count:SetText(#mountIDs)
	end
	
	hooksecurefunc("MountJournal_UpdateMountList", UpdateMountCount)
	hooksecurefunc(MountJournal.ListScrollFrame, "update", UpdateMountCount) -- OnMouseWheel
	
	-- roll our own search function since default search (server side) is restricted to the normal subset
	MountJournal.searchBox:HookScript("OnTextChanged", function(self)
		wipe(searchMountIDs)
		local text = self:GetText():trim()
		
		if #text > 0 then
			activeSearch = true
			for _, v in pairs(mountIDs) do
				-- should probably optimize this with a cache
				if C_MountJournal.GetMountInfoByID(v):lower():find(text:lower()) then
					tinsert(searchMountIDs, v)
				end
			end
			-- dont wait for MOUNT_JOURNAL_SEARCH_UPDATED
			MountJournal_UpdateMountList()
		else
			activeSearch = false
		end
	end)
	
	local function ClearSearch()
		wipe(searchMountIDs)
		activeSearch = false
	end
	
	MountJournal.searchBox:HookScript("OnHide", ClearSearch)
	MountJournal.searchBox.clearButton:HookScript("OnClick", ClearSearch)
end

function ClickMogTest(someStr)
	CM.Test(CM, someStr)
	return 123
end
