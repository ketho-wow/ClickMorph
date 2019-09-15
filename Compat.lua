local CM = ClickMorph

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
	self:MorphItemBySource("player", source)
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
		CM:MorphItemBySource("player", v[2])
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