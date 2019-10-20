local CM = ClickMorph

local addons = {
	"MogIt",
	"TakusMorphCatalog",
	"rIngameModelViewer",
	"AtlasLootClassic",
}

function OnEvent(self, event, isInitialLogin, isReloadingUi)
	if isInitialLogin or isReloadingUi then
		for _, addon in pairs(addons) do
			if IsAddOnLoaded(addon) then
				CM[addon](CM)
			end
		end
	end
end

local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_ENTERING_WORLD")
f:SetScript("OnEvent", OnEvent)

function CM:MogIt()
	hooksecurefunc(MogIt, "UpdateGUI", function(frame, resize)
		if not resize then -- models have been initialized
			for _, model in pairs(MogIt.models) do
				local oldOnClick = model:GetScript("OnClick")
				model:SetScript("OnClick", function(frame, button)
					-- prevent cycling through items when pressing alt
					if IsAltKeyDown() then
						self:MorphMogItCatalogue(frame)
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

local hookedTmc

function CM:TakusMorphCatalog()
	for _, child in pairs({UIParent:GetChildren()}) do
		if child.Collection and child.ModelPreview then -- found TMCFrame
			-- models
			hooksecurefunc(child.Gallery, "Load", function()
				if not hookedTmc then
					for idx, button in pairs({child.Gallery:GetChildren()}) do
						local oldOnClick = button:GetScript("OnClick")
						button:SetScript("OnClick", function(frame, btn)
							if IsAltKeyDown() then
								CM:MorphModel("player", frame.ModelFrame.DisplayInfo)
								child:Hide() -- hide the window when clickmorphing
							else
								oldOnClick(frame, btn)
							end
						end)
					end
					hookedTmc = true
				end
			end)
			-- preview
			local oldOnClick = child.ModelPreview:GetScript("OnMouseDown")
			child.ModelPreview:SetScript("OnMouseDown", function(frame, button)
				if IsAltKeyDown() then
					self:MorphModel("player", frame.ModelFrame.DisplayInfo)
					child:Hide()
				else
					oldOnClick(frame, button)
				end
			end)
			break
		end
	end
end

local hookedRimv
local modelHooks = {}

local function UpdateRimvHooks(frame)
	for idx, model in pairs(frame.M) do
		if not modelHooks[idx] then
			local oldOnClick = model:GetScript("OnMouseDown")
			model:SetScript("OnMouseDown", function(frame, button)
				-- dont click the frame away if morphing
				if IsAltKeyDown() then
					CM:MorphModel("player", model.displayIndex)
					frame:GetParent():Disable()
				else
					oldOnClick(frame, button)
				end
			end)
			modelHooks[idx] = true
		end
	end
end

function CM:rIngameModelViewer()
	if self.isClassic then -- missing model in classic
		rIngameModelViewerMurlocButton:SetDisplayInfo(31)
	end
	rIngameModelViewerMurlocButton:HookScript("OnMouseDown", function()
		if not hookedRimv then
			for _, child in pairs({UIParent:GetChildren()}) do
				if child.isCanvas and child.canvasPage then -- found canvas frame
					-- models
					UpdateRimvHooks(child) -- initial hooks
					hooksecurefunc(child, "UpdateAllModels", UpdateRimvHooks)
					-- overlay
					hooksecurefunc(child, "CreateOverlay", function()
						-- not directly accessible on posthook
						C_Timer.After(.1, function()
							local oldOnClick = child.overlay.model:GetScript("OnMouseDown")
							child.overlay.model:SetScript("OnMouseDown", function(frame, button)
								if IsAltKeyDown() then
									CM:MorphModel("player", frame.displayIndex)
									child:Disable()
								else
									oldOnClick(frame, button)
								end
							end)
						end)
					end)
					break
				end
			end
			hookedRimv = true
		end
	end)
end

local shownAtlasLootMessage
local SEC_BUTTON_COUNT = 0

function CM:AtlasLootClassic()
	_G["AtlasLoot_GUI-Frame"]:HookScript("OnShow", function()
		if not shownAtlasLootMessage then
			self:PrintChat("For AtlasLoot you need to press |cff71D5FFAlt+Shift|r while clicking")
			shownAtlasLootMessage = true
		end
	end)
	-- items / itemsets
	for i = 1, 30 do
		local btn = _G["AtlasLoot_Button_"..i]
		local origOnClick = btn:GetScript("OnClick")
		btn:SetScript("OnClick", function(frame, button, down)
			if IsAltKeyDown() and IsShiftKeyDown() then
				if type(frame.SetID) == "number" then
					-- delegate to iMorph .itemset instead of iterating over items field
					self:MorphItemSet(frame.SetID)
				elseif frame.ItemID then
					self.MorphItem(frame.ItemID)
				end
			else
				origOnClick(frame, button, down)
			end
		end)
	end
	-- itemset items
	hooksecurefunc(AtlasLoot.Button, "CreateSecOnly", function()
		SEC_BUTTON_COUNT = SEC_BUTTON_COUNT + 1
		local btn = _G["AtlasLoot_SecButton_"..SEC_BUTTON_COUNT]
		local origOnClick = btn:GetScript("OnClick")
		btn:SetScript("OnClick", function(frame, button, down)
			if IsAltKeyDown() and IsShiftKeyDown() then
				if frame.ItemID then
					self.MorphItem(frame.ItemID)
				end
			else
				origOnClick(frame, button, down)
			end
		end)
	end)
end
