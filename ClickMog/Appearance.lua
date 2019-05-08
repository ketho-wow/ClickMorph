
local CM = ClickMog
local f = CreateFrame("Frame")
local VerifyFrame = CreateFrame("Frame")
local ItemsCollection

local active, unlocked
local visualCache, catCache, illusionCache
local startupTimer
local startupUnlockTime
local IsWardRobeSortLoaded -- WardRobeSort actually gets screwed by this addon
local FileData

local verifyIterations
local needsRefresh
local needsModelUpdate
local ScanningModel

local MAX_SOURCE_ID = 1.1e5 -- highest ID is 104339 (8.1.5)
local MAX_ILLUSION_ID = 1e4 -- highest ID is 6096 (8.1.5)
local MAX_ITEM_VISUAL_ID = 254 -- highest ID is 254 (8.1.5)

local weaponSlots = {
	MAINHANDSLOT = true,
	SECONDARYHANDSLOT = true,
}

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

-- 8.1.5 (29281)
CM.ItemVisuals = {
	[1] = "deathknight_frozenruneweapon_state",
	[2] = "blueglow_med",
	[24] = "blueglow_high",
	[25] = "redflame_low",
	[26] = "poisondrip",
	[27] = "blueflame_low",
	[28] = "sparkle_a",
	[29] = "yellowglow_low",
	[30] = "rune_intellect",
	[31] = "redglow_low",
	[32] = "shaman_fire",
	[33] = "shaman_frost",
	[42] = "blueglow_low",
	[61] = "shaman_rock",
	[81] = "shaman_wind",
	[101] = "redglow_high",
	[102] = "yellowglow_high",
	[103] = "whiteglow_low",
	[104] = "whiteglow_high",
	[105] = "purpleglow_high",
	[106] = "greenglow_high",
	[107] = "purpleglow_low",
	[123] = "blackglow_low",
	[124] = "blackglow_high",
	[125] = "greenglow_low",
	[126] = "whiteflame_low",
	[127] = "greenflame_low",
	[128] = "purpleflame_low",
	[129] = "yellowflame_low",
	[130] = "blackflame_low",
	[131] = "shaman_purple",
	[132] = "shaman_green",
	[133] = "shaman_red",
	[134] = "shaman_yellow",
	[135] = "fireshot_missile",
	[137] = "lightning_precast_low_hand",
	[138] = "shadow_strikes_state_hand",
	[139] = "fire_blue_precast_uber_hand",
	[140] = "shamanisticrage_state_hand",
	[141] = "fel_fire_precast_uber_hand",
	[142] = "faeriefire",
	[143] = "fire_blue_precast_uber_hand",
	[145] = "fear_state_head",
	[146] = "fire_smoketrail",
	[147] = "infernal_smoke_rec",
	[148] = "conjureitem",
	[149] = "dispel_low_recursive",
	[150] = "detectmagic_recursive",
	[151] = "holy_precast_low_hand",
	[152] = "vengeance_state_hand",
	[153] = "summon_precast_hand",
	[154] = "slowingstrike_cast_hand",
	[155] = "mongooseglow_high",
	[156] = "redglow_low",
	[157] = "soulfrostglow_high",
	[158] = "sunfireglow_high",
	[159] = "battlemasterglow_high",
	[160] = "spellsurgeglow_high",
	[161] = "skullballs",
	[162] = "disintigrateglow_high",
	[164] = "executionerglow_high",
	[165] = "disintigrateglow_high",
	[166] = "whiteglow_high",
	[167] = "fire_precast_uber_hand",
	[168] = "shadow_strikes_state_hand",
	[169] = "greenflame_low",
	[170] = "acidliquidbreath",
	[171] = "poisonshot_missile",
	[172] = "fire_blue_precast_uber_hand",
	[174] = "lightning_precast_low_hand",
	[175] = "shamanisticrage_state_hand",
	[176] = "disintigrateglow_high",
	[178] = "redglow_high",
	[179] = "lightningbolt_missile",
	[180] = "blueflame_low",
	[181] = "dragonbreath_fire",
	[183] = "fireshot_missile",
	[184] = "blueflame_low",
	[185] = "holy_precast_low_hand",
	[186] = "blueflame_low",
	[189] = "twilight_fire_precast_hand",
	[191] = "vr_sack_02_q",
	[192] = "frost_high",
	[193] = "purpleglow_high",
	[194] = "nature_high",
	[195] = "sunfireglow_high",
	[196] = "fire_high",
	[197] = "blueflame_low",
	[198] = "fire_high",
	[199] = "whiteglow_low",
	[200] = "battlemasterglow_high",
	[201] = "greenflame_low",
	[213] = "yellowflame_low",
	[219] = "shaman_lavaburst_missile",
	[220] = "shaman_lavaburst_missile_noflash",
	[221] = "shaman_lavaburst_missile_noflash_xs",
	[222] = "shaman_lavaburst_missile_noflash_xs",
	[229] = "shaman_red",
	[235] = "blueflame_low",
	[236] = "purpleglow_high",
	[237] = "blueflame_low",
	[238] = "jadespirit_high",
	[239] = "blueflame_low",
	[242] = "sunfireglow_high",
	[243] = "holy_missile_low",
	[244] = "sonicboom_missile_high",
	[245] = "shaman_lavaburst_missile_noflash_xs",
	[246] = "monk_cracklinglightning_precast_blue",
	[247] = "shaman_frost_missile",
	[248] = "shaman_lightning_precast_v2",
	[249] = "sonicwave_missile_h",
	[250] = "shamanisticrage_state_hand",
	[251] = "sha_precast_uber_hand",
	[252] = "soulfrostglow_high",
	[253] = "sonicwave_missile_v3",
	[255] = "leishen_lightning_precast",
	[257] = "weaponenchant_pvppandarias2",
	[258] = "shaman_lightning_precast_v2",
	[263] = "shaman_yellow",
	[264] = "leishen_lightning_burst_missile",
	[265] = "shaman_lavaburst_missile_noflash_xs",
	[266] = "earthen_high",
	[267] = "amberspirit_high",
	[270] = "shaman_frost",
	[271] = "holy_precast_low_hand",
	[272] = "holy_missile_low",
	[273] = "shaman_fire",
	[274] = "shaman_lavaburst_missile_noflash_xs",
	[275] = "battlemasterglow_high",
	[276] = "blueflame_high",
	[280] = "void_precast_hand",
	[281] = "6_0_weaponenchant_multistrike_high",
	[282] = "leishen_lightning_fill",
	[283] = "blueflame_low",
	[284] = "6_0_weaponenchant_armor_high",
	[285] = "6_0_weaponenchant_multistrike_high",
	[286] = "savageryglow_high",
	[287] = "6_0_weaponenchant_damage_high",
	[290] = "mongooseglow_high",
	[291] = "sparktrail",
	[292] = "monk_jade_precast_right_low",
	[294] = "immolate_state_v2_fel",
	[295] = "6_0_weaponenchant_armor_high",
	[296] = "6_0_weaponenchant_armor_low",
	[297] = "6_0_weaponenchant_multistrike_low",
	[298] = "void_eyes",
	[299] = "6_0_weaponenchant_multistrike_low",
	[300] = "6_0_weaponenchant_multistrike_low",
	[301] = "6_0_weaponenchant_damage_high",
	[302] = "6_0_weaponenchant_damage_low",
	[303] = "leishen_lightning_fill",
	[304] = "wind_chakram_missile_reverse",
	[305] = "6_0_weaponenchant_pvp",
	[306] = "shaman_frost",
	[307] = "6fx_torchfire_doodad_fel",
	[308] = "faeriefire",
	[310] = "state_arcane_chest_burn",
	[311] = "hunter_traplauncher_firemissile",
	[312] = "shamanisticrage_state_hand",
	[313] = "6_0_weaponenchant_pvp",
	[314] = "6_0_flamesofragnaros_enchant",
	[315] = "shaman_water_precast",
	[316] = "state_arcane_chest_burn",
	[317] = "cast_arcane_01",
	[320] = "holy_precast_high_hand",
	[321] = "felmag_empowered_aurafel",
	[322] = "state_arcane_chest_burn",
	[323] = "mage_fingersoffrost_hand",
	[324] = "ogre_gemdust_precast_hand",
	[325] = "weaponenchant_pvppandarias2",
	[327] = "7fx_weaponenchant_energyfel",
	[328] = "mage_combustion_state_chest_fel",
	[329] = "mage_combustion_state_chest_fel",
	[330] = "shaman_lavaburst_fel",
	[332] = "leishen_lightning_burst_missile",
	[333] = "shadow_strikes_state_hand",
	[334] = "holy_precast_low_hand",
	[335] = "shadow_strikes_state_hand",
	[336] = "7fx_weaponenchant_energyfel",
	[337] = "7fx_weaponenchant_energyfire",
	[338] = "whiteflame_low",
	[339] = "frost_high",
	[340] = "holy_precast_low_hand",
	[341] = "holy_precast_low_hand",
	[342] = "weaponenchant_pvppandarias2",
	[343] = "6_0_weaponenchant_healing_low",
	[344] = "purpleflame_low",
	[345] = "greenflame_low",
	[346] = "7fx_weaponenchant_nightmare",
	[347] = "7fx_weaponenchant_arcane",
	[348] = "weaponenchant_pvplegions3",
	[453] = "8fx_islands_carryingazerite_large_statechest",
	[454] = "7fx_weaponenchant_energyshadow",
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
			-- needed when showing the wardrobe again after using the search function
			if needsRefresh then
				VerifyFrame:SetScript("OnUpdate", self.VerifyModels)
			end
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
		CM:PrintChat("Loading data..")
		self:RegisterEvent("TRANSMOG_COLLECTION_ITEM_UPDATE")
		self:GetAppearances()
		self:HookWardrobe()
		self:UpdateWardrobe() -- initial update
		FileData = self:LoadFileData("ClickMogData")
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
		CM:PrintChat("Unlocked Appearances Tab!")
	end
end

function f:GetAppearances()
	if not visualCache then
		visualCache, catCache, illusionCache = {}, {}, {}
		local hasVisual = {}
		for i = 0, 29 do -- init category tables
			catCache[i] = {}
		end
		
		for i = 1, MAX_SOURCE_ID do
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
		
		local t = {}
		
		for k, v in pairs(C_TransmogCollection.GetIllusions()) do
			v.isCollected = true
			v.isUsable = true
			v.uiOrder = v.visualID
			t[v.visualID] = v
		end
		
		for i = 1, MAX_ILLUSION_ID do
			local id, name, link = C_TransmogCollection.GetIllusionSourceInfo(i)
			if id and id > 0 and not t[id] and CM.ItemVisuals[id] then
				t[id] = {
					isCollected = true,
					isUsable = true,
					sourceID = i,
					visualID = id,
					uiOrder = id,
				}
			end
		end
		
		for k, v in pairs(CM.ItemVisuals) do
			if not t[k] then
				t[k] = {
					isCollected = true,
					isUsable = true,
					visualID = k,
					uiOrder = k,
				}
			end
		end
		
		for k, v in pairs(t) do
			tinsert(illusionCache, v)
		end
		
		sort(illusionCache, function(a, b)
			return a.visualID > b.visualID 
		end)
	end
end

function f:HookWardrobe()
	local searchAppearanceIDs, activeSearch = {}

	-- appearances
	function C_TransmogCollection.GetCategoryAppearances(categoryID)
		return activeSearch and searchAppearanceIDs or catCache[categoryID]
	end
		
	function C_TransmogCollection.GetAppearanceSources(appearanceID)
		return visualCache[appearanceID]
	end
	
	-- illusions
	function C_TransmogCollection.GetIllusions()
		return illusionCache
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
				for _, visuals in pairs(catCache[ItemsCollection:GetActiveCategory()]) do
					for _, source in pairs(visualCache[visuals.visualID]) do
						-- cache stuff on the go and pray nobody pastes in a whole name instead of typing
						-- yeah this is disgusting and it doesnt even work properly, gotta rework this
						if not source.name then
							local newSource = C_TransmogCollection.GetSourceInfo(source.sourceID)
							source.name = newSource.name
							source.quality = newSource.quality
						end
						-- also search through texture name
						if source.name and source.name:lower():find(text) or (FileData[visuals.visualID] or ""):find(text) then
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
			-- when you have an active search from items, and switch to sets then back to items, only the previously shown models get updated
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

function f:UpdateModelCamera()
	if not ItemsCollection:GetActiveCategory() then return end
	
	for _, model in pairs(ItemsCollection.Models) do
		if model:IsShown() then
			-- cant use C_TransmogCollection.GetAppearanceCameraID since it doesnt return an ID for non-class proficiency appearances
			-- todo: gives an error on when showing to the illusions category
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
	needsRefresh = false
	
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
				local visuals = catCache[ItemsCollection:GetActiveCategory()]

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
	for _, model in pairs(ItemsCollection.Models) do
		if model:IsShown() then
			local visualID = model.visualInfo.visualID
			local sources = C_TransmogCollection.GetAppearanceSources(visualID)
			local reason = ScanningModel:TryOn(sources[1].sourceID)
			local debugname = model:GetDebugName():match(".+%.(.+)")
			
			if reason == Enum.ItemTryOnReason.DataPending then
				if #sources == 1 then
					if not weaponSlots[ItemsCollection:GetActiveSlot()] then -- weapons can still be shown
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
		local total = #catCache[category]
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
	if ItemsCollection:GetActiveCategory() then
		GameTooltip:AddLine(FileData[frame.visualInfo.visualID]) -- appearances
	else
		if not GameTooltip:GetOwner() then
			GameTooltip:SetOwner(frame, "ANCHOR_RIGHT")
		end
		GameTooltip:AddLine(CM.ItemVisuals[frame.visualInfo.visualID]) -- illusions
	end
	GameTooltip:AddLine("|cffFFFFFF"..frame.visualInfo.visualID.."|r")
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

function f:LoadFileData(addon)
	local loaded, reason = LoadAddOn(addon)
	if not loaded then
		if reason == "DISABLED" then
			EnableAddOn(addon, true)
			LoadAddOn(addon)
		else
			error(addon..": "..reason)
		end
	end
	return _G[addon]:GetFileData()
end
