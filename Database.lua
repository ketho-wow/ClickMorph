local CM = ClickMorph
local db

local defaults = {
	db_version = 1,
}

local f = CreateFrame("Frame")

function f:OnEvent(event, addon)
	if addon == "ClickMorph" then
		if not ClickMorphDB or ClickMorphDB.db_version < defaults.db_version then
			ClickMorphDB = CopyTable(defaults)
		end
		db = ClickMorphDB
		self:UnregisterEvent(event)
	end
end

f:RegisterEvent("ADDON_LOADED")
f:SetScript("OnEvent", f.OnEvent)
