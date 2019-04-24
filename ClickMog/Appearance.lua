
local CM = ClickMog
local f = CreateFrame("Frame")
local VerifyFrame = CreateFrame("Frame")
local ItemsCollection

local active, unlocked
local visualCache, catCache
local startupTimer
local startupUnlockTime
local IsWardRobeSortLoaded

local verifyIterations
local needsModelUpdate
local ScanningModel

local weaponCategories = {
	-- name, isWeapon, canEnchant, canMainHand, canOffHand
	[12] = {"Wands", true, true, true, false},
	[13] = {"One-Handed Axes", true, true, true, false},
	[14] = {"One-Handed Swords", true, true, true, false},
	[15] = {"One-Handed Maces", true, true, true, false},
	[16] = {"Daggers", true, true, true, false},
	[17] = {"Fist Weapons", true, true, true, true},
	[18] = {"Shields", true, false, false, true},
	[19] = {"Held In Off-hand", true, false, false, true},
	[20] = {"Two-Handed Axes", true, true, true, false},
	[21] = {"Two-Handed Swords", true, true, true, false},
	[22] = {"Two-Handed Maces", true, true, true, false},
	[23] = {"Staves", true, true, true, false},
	[24] = {"Polearms", true, true, true, false},
	[25] = {"Bows", true, false, true, false},
	[26] = {"Guns", true, false, true, false},
	[27] = {"Crossbows", true, false, true, false},
	[27] = {"Warglaives", true, true, true, true},
	[27] = {"Legion Artifacts", true, true, true, false},
}

local weaponSlots = {
	MAINHANDSLOT = true,
	SECONDARYHANDSLOT = true,
}

function f:OnEvent(event, arg1)
	if event == "ADDON_LOADED" and arg1 == "Blizzard_Collections" then
		self:InitWardrobe()
		self:UnregisterEvent(event)
	elseif event == "TRANSMOG_COLLECTION_ITEM_UPDATE" then
		if not unlocked then
			startupTimer = .6
			self:SetScript("OnUpdate", self.UnlockTimer)
		end
		if not IsWardRobeSortLoaded then
			-- when mouse scrolling the tooltip waits for uncached item info and gets refreshed
			self.UpdateMouseFocus()
		end
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
			self:UpdateModelCamera(ItemsCollection)
			return
		else
			active = true
		end
		
		ItemsCollection = WardrobeCollectionFrame.ItemsCollectionFrame
		IsWardRobeSortLoaded = IsAddOnLoaded("WardRobeSort")
		
		-- LucidMorph item sets model
		WardrobeCollectionFrame.SetsCollectionFrame.Model:HookScript("OnMouseUp", CM.MorphItemSet)
		
		-- LucidMorph item models
		for _, model in pairs(ItemsCollection.Models) do
			model:HookScript("OnMouseUp", CM.MorphItem)
		end
		
		ScanningModel = CreateFrame("DressUpModel")
		ScanningModel:SetUnit("player")
		
		self:CreateUnlockButton()
	end)
end

function f:CreateUnlockButton()
	local btn = CreateFrame("Button", nil, ItemsCollection, "UIPanelButtonTemplate")
	btn:SetPoint("TOPLEFT", WardrobeCollectionFrame.Tabs[1], "BOTTOMLEFT", -40, -55) -- topleft corner of the frame
	btn:SetWidth(100)
	btn:SetText(UNLOCK)
	
	btn:SetScript("OnClick", function(frame)
		startupUnlockTime = time()
		self:UnlockWardrobe()
		frame:Hide()
	end)
end

function f:UnlockWardrobe()
	if not unlocked then
		CM:PrintChat("Loading data..", "FFFFFF")
		self:RegisterEvent("TRANSMOG_COLLECTION_ITEM_UPDATE")
		self:GetAppearances()
		self:HookWardrobe()
		self:UpdateWardrobe() -- initial update before data is loaded
	end
end

-- wait until all initial TRANSMOG_COLLECTION_ITEM_UPDATE events have fired
function f:UnlockTimer(elapsed)
	startupTimer = startupTimer - elapsed
	-- between the first and second event there can be more than 2 seconds delay
	if startupTimer < 0 and time() > startupUnlockTime + 4 then
		self:SetScript("OnUpdate", nil)
		unlocked = true
		
		verifyIterations = 0
		VerifyFrame:SetScript("OnUpdate", self.VerifyModels)
		CM:PrintChat("Unlocked Appearances Tab!", "FFFFFF")
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
	
	local oldGetCategoryInfo = C_TransmogCollection.GetCategoryInfo
	
	function C_TransmogCollection.GetCategoryInfo(categoryID)
		local name = oldGetCategoryInfo(categoryID)
		local cats = weaponCategories[categoryID]
		if cats then
			cats[1] = name or cats[1] -- prioritizy any localized name
			return unpack(weaponCategories[categoryID])
		else
			return name
		end
	end
	
	-- update model camera on category changes
	hooksecurefunc(ItemsCollection, "SetActiveSlot", function(frame)
		if not ItemsCollection:GetActiveCategory() then return end -- ignore illusions
		self:UpdateModelCamera(frame)
	end)
	
	-- update items on page changes
	hooksecurefunc(ItemsCollection.PagingFrame, "SetCurrentPage", function(frame)
		verifyIterations = 0
		VerifyFrame:SetScript("OnUpdate", self.VerifyModels)
	end)
	
	-- fill progress bar
	hooksecurefunc(ItemsCollection, "UpdateProgressBar", self.UpdateProgressBar)
	
	-- show appearance information in tooltip
	if not IsWardRobeSortLoaded then -- avoid double functionality
		for _, model in pairs(ItemsCollection.Models) do
			model:HookScript("OnEnter", f.Model_OnEnter)
		end
	end
end

function f:UpdateModelCamera()
	for _, model in pairs(ItemsCollection.Models) do
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
		ItemsCollection:OnUnitModelChangedEvent()
		self:UpdateModelCamera()
	end
	
	ItemsCollection:RefreshVisualsList()
	ItemsCollection:UpdateItems()
	self.UpdateMouseFocus() -- update tooltip when scrolling
end

function f.VerifyModels()
	if not ItemsCollection:GetActiveCategory() then return end -- ignore illusions
	
	f:UpdateWardrobe() -- need to update first before verifying
	verifyIterations = verifyIterations + 1
	local needsRefresh
	
	for _, model in pairs(ItemsCollection.Models) do
		if model:IsShown() then
			local visualID = model.visualInfo.visualID
			local sources = C_TransmogCollection.GetAppearanceSources(visualID)
			local reason = ScanningModel:TryOn(sources[1].sourceID)
			
			-- refresh sources for when header source is invalid, and for updating the tooltip
			for k, v in pairs(sources) do
				if not v.name then
					local newSource = C_TransmogCollection.GetSourceInfo(v.sourceID)
					v.name = newSource.name
					v.quality = newSource.quality
				end
			end
			
			if reason == Enum.ItemTryOnReason.WrongRace then
				needsRefresh = true
				local _, catVisuals = f:GetAppearances()
				local visuals = catVisuals[ItemsCollection:GetActiveCategory()]

				for k, v in pairs(visuals) do
					if v.visualID == visualID then
						tremove(visuals, k) -- filter out undisplayable/unmorphable faction-specific gear
						verifyIterations = 0 -- any new visuals should get another iteration to get cached
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
	for _, model in pairs(ItemsCollection.Models) do
		if model:IsShown() then
			local visualID = model.visualInfo.visualID
			local sources = C_TransmogCollection.GetAppearanceSources(visualID)
			local reason = ScanningModel:TryOn(sources[1].sourceID)
			local debugname = model:GetDebugName():match(".+%.(.+)")
			
			if reason == Enum.ItemTryOnReason.DataPending then
				if #sources == 1 then
					if not weaponSlots[ItemsCollection:GetActiveSlot()] then
						model:SetModel("interface/buttons/talktomequestionmark.m2")
						Model_ApplyUICamera(model, 372) -- looks nice, maybe a bit too close
						needsModelUpdate = true
					end
				else
					for k, v in pairs(sources) do
						if v.name then
							model:TryOn(v.sourceID) -- update appearance
							break
						end
					end
				end
			end
		end
	end
end

function f.UpdateProgressBar()
	local category = ItemsCollection:GetActiveCategory()
	if category then
		local _, catvisuals = f:GetAppearances()
		local total = #catvisuals[ItemsCollection:GetActiveCategory()]
		WardrobeCollectionFrame_UpdateProgressBar(total, total)
	end
end

function f.Model_OnEnter(self)
	GameTooltip:AddLine("|cffFFFFFF"..self.visualInfo.visualID.."|r")
	GameTooltip:Show()
end

function f.UpdateMouseFocus()
	if not IsWardRobeSortLoaded then
		local focus = GetMouseFocus()
		if focus and focus:GetObjectType() == "DressUpModel" and focus:GetParent() == ItemsCollection then
			focus:GetScript("OnEnter")(focus)
		end
	end
end
