
local _, ns = ...
local CM = ns.ClickMog

local visualCache, catCache
local timerTCIU
local needsRefresh
local InitMessages = {}

local DummyModel = CreateFrame("DressUpModel")
DummyModel:SetUnit("player")

local function GetAppearances()
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

-- replace api
function C_TransmogCollection.GetCategoryAppearances(categoryID)
	local _, cats = GetAppearances()
	return cats[categoryID]
end

function C_TransmogCollection.GetAppearanceSources(appearanceID)
	local sources = GetAppearances()
	return sources[appearanceID]
end

local f = CreateFrame("Frame")

function f:OnEvent(event, arg1)
	if event == "ADDON_LOADED" and arg1 == "Blizzard_Collections" then
		self:InitWardrobe()
		self:UnregisterEvent(event)
	elseif event == "TRANSMOG_COLLECTION_ITEM_UPDATE" then
		self:StartTimerTCIU(2)
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
	WardrobeCollectionFrame:HookScript("OnShow", function()
		if not active then
			active = true
		else
			self:UpdateModelCamera(WardrobeCollectionFrame.ItemsCollectionFrame)
			return
		end
		
		if not InitMessages.Start then
			print("ClickMog: Loading data...")
			InitMessages.Start = true
		end
		
		f:RegisterEvent("TRANSMOG_COLLECTION_ITEM_UPDATE")
		
		-- update model camera on category changes
		hooksecurefunc(WardrobeCollectionFrame.ItemsCollectionFrame, "SetActiveSlot", function(frame)
			if not WardrobeCollectionFrame.ItemsCollectionFrame:GetActiveCategory() then return end -- ignore illusions
			self:UpdateModelCamera(frame)
		end)
		self:UpdateModelCamera(WardrobeCollectionFrame.ItemsCollectionFrame)
		
		-- update items on page changes
		hooksecurefunc(WardrobeCollectionFrame.ItemsCollectionFrame.PagingFrame, "SetCurrentPage", function(frame)
			self:StartTimerTCIU(0) -- next OnUpdate
		end)
		
		-- prehook to update our cache on mouseover before the gametooltip is shown
		local oldGetSourceTooltipInfo = WardrobeCollectionFrameModel_GetSourceTooltipInfo
		
		function WardrobeCollectionFrameModel_GetSourceTooltipInfo(source)
			for k, v in pairs(GetAppearances()[source.visualID]) do
				if v.sourceID == source.sourceID then
					if not v.name then
						local newSource = C_TransmogCollection.GetSourceInfo(v.sourceID)
						v.name = newSource.name
						v.quality = newSource.quality
					end
				end
			end
			return oldGetSourceTooltipInfo(source)
		end
	end)
end

function f:StartTimerTCIU(seconds)
	timerTCIU = seconds
	self:SetScript("OnUpdate", self.WaitForTCIU)
end

-- wait until all initial TRANSMOG_COLLECTION_ITEM_UPDATE events have fired
function f:WaitForTCIU(elapsed)
	timerTCIU = timerTCIU - elapsed
	if timerTCIU < 0 then
		--print("timer passed")
		self:VerifyModels()
		self:SetScript("OnUpdate", nil)
	end
end

function f:UpdateModelCamera(frame)
	for _, model in pairs(frame.Models) do
		-- cant use C_TransmogCollection.GetAppearanceCameraID since it doesnt return an ID for non-class proficiency appearances
		local sources = C_TransmogCollection.GetAppearanceSources(model.visualInfo.visualID)
		Model_ApplyUICamera(model, C_TransmogCollection.GetAppearanceCameraIDBySource(sources[1].sourceID))
	end
end

-- only verify models when all appearance data is available
function f:VerifyModels()
	if not WardrobeCollectionFrame.ItemsCollectionFrame:GetActiveCategory() then return end -- ignore illusions
	
	local timers = {}
	for _, model in pairs(WardrobeCollectionFrame.ItemsCollectionFrame.Models) do
		if model:IsShown() then
			local visualID = model.visualInfo.visualID
			local sourceID = C_TransmogCollection.GetAppearanceSources(visualID)[1].sourceID
			DummyModel:TryOn(sourceID) -- query appearance
			
			timers[model] = true
			C_Timer.After(0, function() -- wait for next OnUpdate; try to reduce table garbage
				self:VerifyModelsDelayed(model, visualID, sourceID, timers)
			end)
		end
	end
end

function f:VerifyModelsDelayed(model, visualID, sourceID, timers)
	local reason = DummyModel:TryOn(sourceID) -- query appearance again
	--Spew("", model:GetDebugName():match(".+%.(.+)"), visualID, sourceID, reason)

	if reason == Enum.ItemTryOnReason.WrongRace then
		local _, catVisuals = GetAppearances()
		local cat = catVisuals[WardrobeCollectionFrame.ItemsCollectionFrame:GetActiveCategory()]
		
		for k, v in pairs(cat) do
			if v.visualID == visualID then
				local fake = tremove(cat, k)
				local sources = C_TransmogCollection.GetAppearanceSources(fake.visualID)
				local t = {} for k2, v2 in pairs(sources) do tinsert(t, v2.sourceID) end
				--Spew("", reason, k, model:GetDebugName():match(".+%.(.+)"), v.visualID, fake.visualID, sourceID, sources[1].name, table.concat(t, ", "))
				needsRefresh = true
				break
			end
		end
	end
	timers[model] = nil
	
	-- make sure all timers have fired; prefer this over a parallel timer
	if not next(timers) then
		if needsRefresh then
			--print("RefreshVisualsList")
			WardrobeCollectionFrame.ItemsCollectionFrame:RefreshVisualsList()
			WardrobeCollectionFrame.ItemsCollectionFrame:UpdateItems()
			if not InitMessages.Complete then
				print("ClickMog: Unlocked Appearances Tab!")
				InitMessages.Complete = true
			end
		end
	end
end
