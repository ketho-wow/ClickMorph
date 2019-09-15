local CM = ClickMorph
local f = CreateFrame("Frame")

local InvSlotsOrder = {
	INVSLOT_HEAD, -- 1
	INVSLOT_SHOULDER, -- 3
	INVSLOT_BODY, -- 4
	INVSLOT_CHEST, -- 5
	INVSLOT_WAIST, -- 6
	INVSLOT_LEGS, -- 7
	INVSLOT_FEET, -- 8
	INVSLOT_WRIST, -- 9
	INVSLOT_HAND, -- 10
	INVSLOT_BACK, -- 15
	INVSLOT_MAINHAND, -- 16
	INVSLOT_OFFHAND, -- 17
	INVSLOT_RANGED, -- 18
	INVSLOT_TABARD, -- 19
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
			CM:ResetMorph()
			local unit = InspectFrame.unit
			local class = UnitClassBase(unit)
			local fullName = GetUnitName(unit, true)
			local unitLink
			local hex = select(4, GetClassColor(class))
			local unitLink = "|c"..TEXT_MODE_A_STRING_DEST_UNIT:format(hex, UnitGUID(unit), fullName, fullName)
			CM:PrintChat(format("Morphing to %s", unitLink))
			local items = {}

			if CM.isClassic then
				for _, slotID in pairs(InvSlotsOrder) do
					local itemLink = GetInventoryItemLink(InspectFrame.unit, slotID)
					if itemLink then
						tinsert(items, {slotID, itemLink})
					end
				end
			else
				for _, slotID in pairs(InvSlotsOrder) do
					local itemID, itemModID = GetInventoryItemID(InspectFrame.unit, slotID) -- GetInventoryItemID returns the transmogged item
					local itemLink = GetInventoryItemLink(InspectFrame.unit, slotID) -- GetInventoryItemLink returns the actual item (link)
					if itemID then
						local _, sourceID = C_TransmogCollection.GetItemInfo(itemID, itemModID)
						if sourceID then
							local source = C_TransmogCollection.GetSourceInfo(sourceID)
							tinsert(items, {slotID, source})
						else
							-- some items dont return a sourceID:
							-- * some artifacts
							-- * items with suffixes like "of the Fireflash", mostly with itemModID 5
							-- * class specific gear, like 157685:0 [Spellsculptor's Leggings]
							CM:PrintChat(format("Error: Could not find sourceID for inventorySlot %d, itemID %d:%d, %s",
								slot, itemID, itemModID, itemLink), 1, 1, 0)
						end
					end
				end
			end
			-- sort by Inventory Slot
			sort(items, function(a, b)
				return a[1] < b[1]
			end)
			if CM.isClassic then
				for _, v in pairs(items) do
					CM.MorphItemByLink(v[2])
				end
			else
				for _, v in pairs(items) do
					CM:MorphItemBySource("player", v[2])
				end
			end
		end
	end)
end
