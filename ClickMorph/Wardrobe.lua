-- the unlocked wardrobe is kind of buggy and messy
local CM = ClickMorph
if CM.isClassic then return end

local db
local cache = {}

local f = CreateFrame("Frame")
local VerifyFrame = CreateFrame("Frame")
local ItemsCollection

local active, unlocked
local startupTimer, startupUnlockTime
local IsWardRobeSortLoaded -- WardRobeSort actually gets screwed by this addon

local verifyIterations = 0
local needsRefresh
local needsModelUpdate
local ScanningModel

local MAX_SOURCE_ID = 1.1e5 -- highest ID is 104339 (8.1.5)
local MAX_ILLUSION_ID = 1e4 -- highest ID is 6096 (8.1.5)

local defaults = {
	version = 1,
	build = select(2, GetBuildInfo()),
}

local weaponSlots = {
	MAINHANDSLOT = true,
	SECONDARYHANDSLOT = true,
}

-- C_TransmogCollection.GetCategoryInfo is filtered by class proficiency
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
	[28] = {"Warglaives", true, true, true, true},
	[29] = {"Legion Artifacts", true, true, true, false},
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

-- wait until all initial TRANSMOG_COLLECTION_ITEM_UPDATE events have fired
function f:UnlockTimer(elapsed)
	startupTimer = startupTimer - elapsed
	-- between the first and second event there can be more than 2 seconds delay
	if startupTimer < 0 and time() > startupUnlockTime + 4 then
		self:SetScript("OnUpdate", nil)
		unlocked = true

		VerifyFrame:SetScript("OnUpdate", self.VerifyModels)
		CM:PrintChat("Unlocked Appearances Tab!")
	end
end

if IsAddOnLoaded("Blizzard_Collections") then
    f:InitWardrobe()
else
    f:RegisterEvent("ADDON_LOADED")
end

f:SetScript("OnEvent", f.OnEvent)

function f:InitWardrobe()
	-- only load once the appearances tab is opened
	WardrobeCollectionFrame:HookScript("OnShow", function(frame)
		if active then
			-- needed when showing the wardrobe after the first time
			self:UpdateModelCamera(ItemsCollection)
			-- needed when showing the wardrobe again after using the search function
			if needsRefresh then
				VerifyFrame:SetScript("OnUpdate", self.VerifyModels)
			end
			return
		end
		active = true

		ItemsCollection = WardrobeCollectionFrame.ItemsCollectionFrame
		IsWardRobeSortLoaded = IsAddOnLoaded("WardRobeSort")

		-- item sets
		WardrobeCollectionFrame.SetsCollectionFrame.Model:HookScript("OnMouseUp", CM.MorphTransmogSet)
		-- items
		for _, model in pairs(ItemsCollection.Models) do
			model:HookScript("OnMouseUp", CM.MorphTransmogItem)
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
		-- Load On Demand data from DBCs
		CM.ItemAppearance, CM.ItemVisuals = self:LoadFileData("ClickMorphData")
		self:InitializeData()
		self:HookWardrobe()
		self:UpdateWardrobe() -- initial update
	end
end

function f:InitializeData()
	-- clear cache on new game builds or db structure changes
	if not ClickMorphDataDB or ClickMorphDataDB.build < defaults.build or ClickMorphDataDB.version < defaults.version then
		ClickMorphDataDB = CopyTable(defaults)
	end
	db = ClickMorphDataDB

	local version = GetAddOnMetadata("ClickMorph", "Version")
	if not db.SourceInfo then
		CM:PrintChat(format("|cff71D5FFv%s|r Rebuilding data..", version))
		db.SourceInfo, db.IllusionSourceInfo = self:QueryData()
	else
		unlocked = true
		CM:PrintChat(format("|cff71D5FFv%s|r Unlocked Appearances Tab!", version))
		VerifyFrame:SetScript("OnUpdate", self.VerifyModels)
	end
	self:RegisterEvent("TRANSMOG_COLLECTION_ITEM_UPDATE")

	cache.CategoryVisuals = {}
	for i = 0, 29 do -- init category tables
		cache.CategoryVisuals[i] = {}
	end

	for visualID, sources in pairs(db.SourceInfo) do
		tinsert(cache.CategoryVisuals[sources[1].categoryID], {
			isCollected = true,
			isUsable = true,
			visualID = visualID,
			uiOrder = visualID,
		})
	end
end

function f:QueryData()
	local sources, illusions = {}, {}
	local enchants = {}

	for i = 1, MAX_SOURCE_ID do
		local source = C_TransmogCollection.GetSourceInfo(i)
		if source then
			sources[source.visualID] = sources[source.visualID] or {}
			tinsert(sources[source.visualID], source)
		end
	end

	for _, v in pairs(C_TransmogCollection.GetIllusions()) do
		v.isCollected = true
		v.isUsable = true
		v.uiOrder = v.visualID
		enchants[v.visualID] = v
	end

	for i = 1, MAX_ILLUSION_ID do
		local id = C_TransmogCollection.GetIllusionSourceInfo(i)
		if id and id > 0 and not enchants[id] and CM.ItemVisuals[id] then
			enchants[id] = {
				isCollected = true,
				isUsable = true,
				sourceID = i,
				visualID = id,
				uiOrder = id,
			}
		end
	end

	for k in pairs(CM.ItemVisuals) do
		if not enchants[k] then
			enchants[k] = {
				isCollected = true,
				isUsable = true,
				visualID = k,
				uiOrder = k,
			}
		end
	end

	for k, v in pairs(enchants) do
		tinsert(illusions, v)
	end

	sort(illusions, function(a, b)
		return a.visualID > b.visualID 
	end)
	
	return sources, illusions
end

function f:HookWardrobe()
	local searchAppearanceIDs, activeSearch = {}

	-- appearances
	function C_TransmogCollection.GetCategoryAppearances(categoryID)
		return activeSearch and searchAppearanceIDs or cache.CategoryVisuals[categoryID]
	end

	function C_TransmogCollection.GetAppearanceSources(appearanceID)
		return db.SourceInfo[appearanceID]
	end

	-- illusions
	function C_TransmogCollection.GetIllusions()
		return db.IllusionSourceInfo
	end

	-- categories
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

	-- update model camera on category/tab changes
	local function OnCategoryChange()
		if not ItemsCollection:GetActiveCategory() then return end -- ignore illusions
		WardrobeCollectionFrame.searchBox:GetScript("OnTextChanged")(WardrobeCollectionFrame.searchBox) -- redo any active search
		self:UpdateModelCamera()
	end

	hooksecurefunc(ItemsCollection, "SetActiveSlot", OnCategoryChange)
	hooksecurefunc("WardrobeCollectionFrame_SetTab", function(tabID)
		if tabID == 1 then -- Items
			OnCategoryChange()
		elseif tabID == 2 then -- Sets
			-- ...
		end
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
			-- for illusions, if the sourceId is not valid then show our own tooltip instead
			local pre = model:GetScript("OnEnter")
			model:SetScript("OnEnter", function(frame) f.Model_OnEnterPrehook(frame, pre) end)
			model:HookScript("OnEnter", f.Model_OnEnterPosthook)
			-- sanitize OnEnter handler when scrolling through unlocked illusions
			local oldOnEnter = model.OnEnter
			model.OnEnter = function(frame)
				if frame.visualInfo.sourceID then
					oldOnEnter(frame)
				else
					GameTooltip:ClearLines()
				end
				f.Model_OnEnterPosthook(frame)
			end
		end
	end

	-- fix search function
	WardrobeCollectionFrame.searchBox:HookScript("OnTextChanged", function(frame)
		local text = frame:GetText():trim():lower()
		local tab = WardrobeCollectionFrame.selectedCollectionTab

		if tab == 1 then -- Items tab
			if #text > 0 then
				wipe(searchAppearanceIDs)
				activeSearch = true
				for _, visuals in pairs(cache.CategoryVisuals[ItemsCollection:GetActiveCategory()]) do
					for _, source in pairs(db.SourceInfo[visuals.visualID]) do
						-- cache stuff on the go and pray nobody pastes in a whole name instead of typing
						-- yeah this is disgusting and it doesnt even work properly, gotta rework this
						if not source.name then
							local newSource = C_TransmogCollection.GetSourceInfo(source.sourceID)
							source.name = newSource.name
							source.quality = newSource.quality
						end
						-- also search through texture name
						if source.name and source.name:lower():find(text) or (CM.ItemAppearance[visuals.visualID] or ""):find(text) then
							tinsert(searchAppearanceIDs, { -- fake visual
								isCollected = true,
								isUsable = true,
								visualID = visuals.visualID,
								uiOrder = visuals.visualID,
							})
							break
						end
					end
				end
				-- update search models
				VerifyFrame:SetScript("OnUpdate", self.VerifyModels)
			else
				activeSearch = false
			end
			-- also fixes a blizzard bug:
			--  when you have an active search from items, and switch to sets then back to items,
			--  only the previously shown models get updated
			self:UpdateWardrobe()
			self:UpdateModelCamera() -- need to update model camera only after UpdateWardrobe
		elseif tab == 2 then -- Sets tab
			-- ...
		end
	end)

	local function ClearSearch()
		wipe(searchAppearanceIDs)
		activeSearch = false
		needsRefresh = true -- models need to be updated more than once after clearing a search
		self:UpdateWardrobe() -- prepare the wardrobe for the next time it gets shown again
	end

	WardrobeCollectionFrame.searchBox:HookScript("OnHide", ClearSearch)
	WardrobeCollectionFrame.searchBox.clearButton:HookScript("OnClick", ClearSearch)
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

function f:UpdateModelCamera()
	if not ItemsCollection:GetActiveCategory() then return end

	for _, model in pairs(ItemsCollection.Models) do
		if model:IsShown() then
			-- cant use C_TransmogCollection.GetAppearanceCameraID since it doesnt return an ID for non-class proficiency appearances
			local sources = C_TransmogCollection.GetAppearanceSources(model.visualInfo.visualID)
			Model_ApplyUICamera(model, C_TransmogCollection.GetAppearanceCameraIDBySource(sources[1].sourceID))
		end
	end
end

function f.VerifyModels()
	if not ItemsCollection:GetActiveCategory() then return end -- ignore illusions

	f:UpdateWardrobe() -- need to update first before verifying
	verifyIterations = verifyIterations + 1
	needsRefresh = false

	for _, model in pairs(ItemsCollection.Models) do
		if model:IsShown() then
			local visualID = model.visualInfo.visualID
			local sources = C_TransmogCollection.GetAppearanceSources(visualID)
			local reason = ScanningModel:TryOn(sources[1].sourceID)
			-- refresh sources for when header source is invalid, and for updating the tooltip
			for _, v in pairs(sources) do
				if not v.name then
					local newSource = C_TransmogCollection.GetSourceInfo(v.sourceID)
					v.name = newSource.name
					v.quality = newSource.quality
				end
			end

			if reason == Enum.ItemTryOnReason.WrongRace then
				needsRefresh = true
				local visuals = cache.CategoryVisuals[ItemsCollection:GetActiveCategory()]
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

	if verifyIterations > 25 then
		VerifyFrame:SetScript("OnUpdate", nil)
		error("VerifyModels Script ran too long.")
	elseif not needsRefresh and verifyIterations > 1 then
		-- do anything that would otherwise be overridden by UpdateWardrobe
		VerifyFrame:SetScript("OnUpdate", nil)
		f:OverrideUpdate()
	end
end

function f:OverrideUpdate()
	for _, model in pairs(ItemsCollection.Models) do
		if model:IsShown() then
			local sources = C_TransmogCollection.GetAppearanceSources(model.visualInfo.visualID)
			local reason = ScanningModel:TryOn(sources[1].sourceID)

			if reason == Enum.ItemTryOnReason.DataPending then
				if #sources == 1 then
					if not weaponSlots[ItemsCollection:GetActiveSlot()] then -- weapons can still be shown
						model:SetModel("interface/buttons/talktomequestionmark.m2")
						Model_ApplyUICamera(model, 372) -- looks nice, maybe a bit too close
						needsModelUpdate = true
					end
				else
					for _, v in pairs(sources) do
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
		local total = #cache.CategoryVisuals[category]
		WardrobeCollectionFrame_UpdateProgressBar(total, total)
	end
end

-- avoid an error for illusions if there is no sourceID
function f.Model_OnEnterPrehook(frame, func)
	if ItemsCollection:GetActiveCategory() or frame.visualInfo.sourceID then
		func(frame)
	end
end

function f.Model_OnEnterPosthook(frame)
	local visualID = frame.visualInfo.visualID
	-- dont update tooltip while unlocking,
	--  otherwise unlocked illusions are added multiple times to the tooltip
	if unlocked then
		if ItemsCollection:GetActiveCategory() then
			local source = db.SourceInfo[visualID][1] -- dunno yet how update the tooltip on item cycle
			GameTooltip:AddLine(CM.ItemAppearance[visualID]) -- appearances
			GameTooltip:AddDoubleLine("|cffFFFFFF"..visualID.."|r", format("|cff71D5FFitem %d:%d|r", source.itemID, source.itemModID))
		else
			if not GameTooltip:GetOwner() then
				GameTooltip:SetOwner(frame, "ANCHOR_RIGHT")
			end
			GameTooltip:AddLine(CM.ItemVisuals[visualID]) -- illusions
			GameTooltip:AddLine("|cffFFFFFF"..visualID.."|r")
		end
		GameTooltip:Show()
	end
end

function f.UpdateMouseFocus()
	if not IsWardRobeSortLoaded then
		local focus = GetMouseFocus()
		if focus and focus:GetObjectType() == "DressUpModel" and focus:GetParent() == ItemsCollection then
			focus:GetScript("OnEnter")(focus)
		end
	end
end

function f:LoadFileData(addon)
	local loaded, reason = LoadAddOn(addon)
	if not loaded then
		if reason == "DISABLED" then
			EnableAddOn(addon, true)
			LoadAddOn(addon)
		else
			self:SetScript("OnUpdate", nil)
			CM:PrintChat(format("The ClickMorphData folder could not be found! If you're using the GitHub .zip, please use the Curse .zip", version), 1, 1, 0)
			error(addon..": "..reason)
		end
	end
	local FD = _G[addon]
	return FD:GetItemAppearance(), FD:GetItemVisuals()
end
