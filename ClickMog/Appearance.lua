
local CM = ClickMog
local f = CreateFrame("Frame")
local VerifyFrame = CreateFrame("Frame")

local active, unlocked
local visualCache, catCache
local startupTimer

local verifyIterations
local needsModelUpdate
local ScanningModel

function f:OnEvent(event, arg1)
	if event == "ADDON_LOADED" and arg1 == "Blizzard_Collections" then
		self:InitWardrobe()
		self:UnregisterEvent(event)
	elseif event == "TRANSMOG_COLLECTION_ITEM_UPDATE" then
		startupTimer = 1.7
		self:SetScript("OnUpdate", self.UnlockTimer)
	end
end

if IsAddOnLoaded("Blizzard_Collections") then
    f:InitWardrobe()
else
    f:RegisterEvent("ADDON_LOADED")
end

f:SetScript("OnEvent", f.OnEvent)

function f:InitWardrobe()
	-- only load once the wardrobe collections tab is used
	WardrobeCollectionFrame:HookScript("OnShow", function(frame)
		if active then
			-- needed when showing the wardrobe after the first time
			self:UpdateModelCamera(WardrobeCollectionFrame.ItemsCollectionFrame)
			return
		else
			active = true
		end
		
		-- LucidMorph item sets model
		WardrobeCollectionFrame.SetsCollectionFrame.Model:HookScript("OnMouseUp", CM.MorphItemSet)
		
		-- LucidMorph item models
		for _, model in pairs(WardrobeCollectionFrame.ItemsCollectionFrame.Models) do
			model:HookScript("OnMouseUp", CM.MorphItem)
		end
		
		ScanningModel = CreateFrame("DressUpModel")
		ScanningModel:SetUnit("player")
		
		self:PlaceUnlockButton(self.UnlockWardrobe)
	end)
end

function f:PlaceUnlockButton(func)
	local btn = CreateFrame("Button", "ClickMogWardrobeButton", WardrobeCollectionFrame.ItemsCollectionFrame, "UIPanelButtonTemplate")
	btn:SetPoint("TOPLEFT", WardrobeCollectionFrame.Tabs[1], "BOTTOMLEFT", -40, -55) -- topleft corner of the frame
	btn:SetWidth(100)
	btn:SetText(UNLOCK)
	
	btn:SetScript("OnClick", function(frame)
		func(self)
		if startupTimer and startupTimer > 0 then
			CM:PrintChat("Already unlocking...")
		end
	end)
end

function f:UnlockWardrobe()
	if not unlocked then
		unlocked = true
		CM:PrintChat("Loading data...", "FFFFFF")
		self:RegisterEvent("TRANSMOG_COLLECTION_ITEM_UPDATE")
		self:GetAppearances()
	end
end

-- wait until all initial TRANSMOG_COLLECTION_ITEM_UPDATE events have fired
function f:UnlockTimer(elapsed)
	startupTimer = startupTimer - elapsed
	if startupTimer < 0 then
		self:SetScript("OnUpdate", nil)
		self:UnregisterEvent("TRANSMOG_COLLECTION_ITEM_UPDATE")
		
		self:HookWardrobe()
		verifyIterations = 0
		VerifyFrame:SetScript("OnUpdate", self.VerifyModels)
		CM:PrintChat("Unlocked Appearances Tab!", "FFFFFF")
		
		ClickMogWardrobeButton:Hide()
	end
end

function f:GetAppearances()
	if not visualCache then
		visualCache, catCache = {}, {}
		local hasVisual = {}
		for i = 0, 29 do -- init category tables
			catCache[i] = {}
		end
		
		for i = 1, 1.1e5 do -- get source data; highest ID (8.1.5) is 104339
			local source = C_TransmogCollection.GetSourceInfo(i)
			if source then
				visualCache[source.visualID] = visualCache[source.visualID] or {}
				tinsert(visualCache[source.visualID], source)

				if not hasVisual[source.visualID] then
					tinsert(catCache[source.categoryID], { -- fake visual
						isCollected = true,
						isUsable = true,
						visualID = source.visualID,
						uiOrder = source.visualID,
					})
					hasVisual[source.visualID] = true
				end
			end
		end
	end
	return visualCache, catCache
end

function f:HookWardrobe()
	function C_TransmogCollection.GetCategoryAppearances(categoryID)
		local _, cats = self:GetAppearances()
		return cats[categoryID]
	end
	
	function C_TransmogCollection.GetAppearanceSources(appearanceID)
		local sources = self:GetAppearances()
		return sources[appearanceID]
	end
	
	-- update model camera on category changes
	hooksecurefunc(WardrobeCollectionFrame.ItemsCollectionFrame, "SetActiveSlot", function(frame)
		if not WardrobeCollectionFrame.ItemsCollectionFrame:GetActiveCategory() then return end -- ignore illusions
		self:UpdateModelCamera(frame)
	end)
	
	-- update items on page changes
	hooksecurefunc(WardrobeCollectionFrame.ItemsCollectionFrame.PagingFrame, "SetCurrentPage", function(frame)
		verifyIterations = 0
		VerifyFrame:SetScript("OnUpdate", self.VerifyModels)
	end)
	
	-- fill progress bar
	hooksecurefunc(WardrobeCollectionFrame.ItemsCollectionFrame, "UpdateProgressBar", self.UpdateProgressBar)
end

function f:UpdateModelCamera()
	for _, model in pairs(WardrobeCollectionFrame.ItemsCollectionFrame.Models) do
		if model:IsShown() then
			-- cant use C_TransmogCollection.GetAppearanceCameraID since it doesnt return an ID for non-class proficiency appearances
			local sources = C_TransmogCollection.GetAppearanceSources(model.visualInfo.visualID)
			Model_ApplyUICamera(model, C_TransmogCollection.GetAppearanceCameraIDBySource(sources[1].sourceID))
		end
	end
end

function f:UpdateWardrobe()
	if needsModelUpdate then
		needsModelUpdate = false
		-- this gives a noticeable delay when reloading the models
		WardrobeCollectionFrame.ItemsCollectionFrame:OnUnitModelChangedEvent()
		self:UpdateModelCamera()
	end
	
	WardrobeCollectionFrame.ItemsCollectionFrame:RefreshVisualsList()
	WardrobeCollectionFrame.ItemsCollectionFrame:UpdateItems()
end

function f.VerifyModels()
	if not WardrobeCollectionFrame.ItemsCollectionFrame:GetActiveCategory() then return end -- ignore illusions
	
	f:UpdateWardrobe() -- need to update first before verifying
	verifyIterations = verifyIterations + 1
	local needsRefresh
	
	for _, model in pairs(WardrobeCollectionFrame.ItemsCollectionFrame.Models) do
		if model:IsShown() then
			local visualID = model.visualInfo.visualID
			local sources = C_TransmogCollection.GetAppearanceSources(visualID)
			
			-- refresh sources for when header source is invalid, and for updating the tooltip
			for k, v in pairs(sources) do
				if not v.name then
					local newSource = C_TransmogCollection.GetSourceInfo(v.sourceID)
					v.name = newSource.name
					v.quality = newSource.quality
				end
			end
			
			local reason = ScanningModel:TryOn(sources[1].sourceID)
			
			if reason == Enum.ItemTryOnReason.WrongRace then
				needsRefresh = true
				local _, catVisuals = f:GetAppearances()
				local visuals = catVisuals[WardrobeCollectionFrame.ItemsCollectionFrame:GetActiveCategory()]

				for k, v in pairs(visuals) do
					if v.visualID == visualID then
						tremove(visuals, k) -- filter out undisplayable/unmorphable faction-specific gear
						break
					end
				end
			end
		end
	end
	
	f:UpdateWardrobe()
	
	-- do anything that would otherwise be overridden by UpdateWardrobe
	if not needsRefresh and verifyIterations > 1 then
		VerifyFrame:SetScript("OnUpdate", nil)
		f:OverrideUpdate()
	end
end

function f:OverrideUpdate()
	for _, model in pairs(WardrobeCollectionFrame.ItemsCollectionFrame.Models) do
		if model:IsShown() then
			local visualID = model.visualInfo.visualID
			local sources = C_TransmogCollection.GetAppearanceSources(visualID)
			local reason = ScanningModel:TryOn(sources[1].sourceID)
			
			if reason == Enum.ItemTryOnReason.DataPending then
				if #sources == 1 then
					model:SetModel("interface/buttons/talktomequestionmark.m2")
					Model_ApplyUICamera(model, 372) -- looks nice, maybe a bit too close
					needsModelUpdate = true
				else
					--needsRefresh = true
					for k, v in pairs(sources) do
						if v.name then
							model:TryOn(v.sourceID)
							break
						end
					end
				end
			end
		end
	end
end

function f.UpdateProgressBar()
	local category = WardrobeCollectionFrame.ItemsCollectionFrame:GetActiveCategory()
	if category then
		local _, catvisuals = f:GetAppearances()
		local total = #catvisuals[WardrobeCollectionFrame.ItemsCollectionFrame:GetActiveCategory()]
		WardrobeCollectionFrame_UpdateProgressBar(total, total)
	end
end
