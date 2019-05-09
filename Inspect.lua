
local CM = ClickMorph
local f = CreateFrame("Frame")

local InventorySlots = {
	INVSLOT_HEAD = 1,
	INVSLOT_SHOULDER = 3,
	INVSLOT_BODY = 4,
	INVSLOT_CHEST = 5,
	INVSLOT_WAIST = 6,
	INVSLOT_LEGS = 7,
	INVSLOT_FEET = 8,
	INVSLOT_WRIST = 9,
	INVSLOT_HAND = 10,
	INVSLOT_BACK = 15,
	INVSLOT_MAINHAND = 16,
	INVSLOT_OFFHAND = 17,
	INVSLOT_RANGED = 18,
	INVSLOT_TABARD = 19,
}

function f:OnEvent(event, addon)
	if addon == "Blizzard_InspectUI" then
		self:InitializeInspect()
		self:UnregisterEvent(event)
	end
end

if IsAddOnLoaded("Blizzard_InspectUI") then
	f:InitializeInspect()
else
	f:RegisterEvent("ADDON_LOADED")
	f:SetScript("OnEvent", f.OnEvent)
end

function f:InitializeInspect()
	InspectModelFrame:HookScript("OnMouseUp", function()
		if IsAltKeyDown() then
			local unit = InspectFrame.unit
			local class = UnitClassBase(unit)
			local fullName = GetUnitName(unit, true)
			local unitLink = TEXT_MODE_A_STRING_DEST_UNIT:format(C_ClassColor.GetClassColor(class):GenerateHexColorMarkup(), UnitGUID(unit), fullName, fullName)
			CM:PrintChat(format("Morphing to %s", unitLink))
			
			local items = {}
			
			for _, slot in pairs(InventorySlots) do
				local itemID, itemModID = GetInventoryItemID(InspectFrame.unit, slot) -- GetInventoryItemID returns the transmogged item
				local itemLink = GetInventoryItemLink(InspectFrame.unit, slot) -- GetInventoryItemLink returns the actual item (link)
				
				if itemID then
					local _, sourceID = C_TransmogCollection.GetItemInfo(itemID, itemModID)
					if sourceID then
						local source = C_TransmogCollection.GetSourceInfo(sourceID)
						tinsert(items, {slot, source})
					else
						-- some items dont return a sourceID:
						-- * some artifacts
						-- * items with suffixes like "of the Fireflash", mostly with itemModID 5
						-- * class specific gear, like 157685:0 [Spellsculptor's Leggings]
						CM:PrintChat(format("Error: Could not find sourceID for inventorySlot %d, itemID %d:%d, %s", slot, itemID, itemModID, itemLink), 1, 1, 0)
					end
				end
			end
			
			-- sort by Inventory Slot
			sort(items, function(a, b)
				return a[1] < b[1]
			end)
			
			for _, v in pairs(items) do
				CM:MorphAppearance(v[2])
			end
		end
	end)
end
