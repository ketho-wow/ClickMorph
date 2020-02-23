local CM = ClickMorph
local db 
CM.db_callbacks = {}

local defaults = {
	db_version = 5,
	imorphlua = {},
	imorphv1 = {}, -- hack together something for imorph v1
}

local f = CreateFrame("Frame")

function f:OnEvent(event, addon)
	if addon == "ClickMorph" then
		if not ClickMorphDB or ClickMorphDB.db_version < defaults.db_version then
			ClickMorphDB = CopyTable(defaults)
		end
		db = ClickMorphDB
		for _, func in pairs(CM.db_callbacks) do
			func()
		end
		self:UnregisterEvent(event)
	end
end

f:RegisterEvent("ADDON_LOADED")
f:SetScript("OnEvent", f.OnEvent)
