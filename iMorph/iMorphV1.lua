local CM = ClickMorph
if not CM.isClassic then return end

iMorphV1 = CreateFrame("Frame")

iMorphV1:RegisterEvent("PLAYER_ENTERING_WORLD")
iMorphV1:RegisterEvent("PLAYER_LOGOUT")
iMorphV1:RegisterEvent("ADDON_LOADED")
iMorphV1:SetScript("OnEvent", function(self, event, ...)
	self[event](self, event, ...)
end)

function iMorphV1:ADDON_LOADED(event, addon)
	if addon == "ClickMorph" then
		ClickMorph_iMorphV1 = ClickMorph_iMorphV1 or {}
		self:UnregisterEvent(event)
	end
end

-- imorph seems to already maintain morph when zoning between map instances
-- cant immediately remorph on initial login since IMorphInfo is not yet loaded, even after relog
-- also IMorphInfo gets wiped between exiting the game / uninjecting 
function iMorphV1:PLAYER_ENTERING_WORLD(event, isInitialLogin, isReloadingUi)
	--[[
	if isInitialLogin then
		self:Remorph()
	end
	]]
end

-- store morph info before logging out
function iMorphV1:PLAYER_LOGOUT()
	-- workaround for scale
	local scale = ClickMorph_iMorphV1.state.scale
	ClickMorph_iMorphV1.state = CopyTable(IMorphInfo)
	ClickMorph_iMorphV1.state.scale = scale
end

function iMorphV1:Remorph()
	-- need to wait for IMorphInfo to be loaded
	C_Timer.After(1, function()
		local state = ClickMorph_iMorphV1.state
		if not IMorphInfo or not state then return end

		if state.shouldMorphRace and state.race and state.gender then
			SetRace(state.race, state.gender)
		elseif state.displayId then
			Morph(state.displayId)
		end
		if next(state.items) then
			for slotID, itemID in pairs(state.items) do
				SetItem(slotID, itemID)
			end
		end
		if state.scale then
			SetScale(state.scale)
		end
		--ClickMorph:PrintChat("Remorphed")
	end)
end
