local CM = ClickMorph
local NpcDisplayIDs
local NpcDisplayNames

local CreatureTypes = {
	Creature = true,
	Vehicle = true,
	Pet = true,
}

function CM:GetDisplayIDs()
	if not NpcDisplayIDs then
		NpcDisplayIDs = select(3, CM:LoadFileData("ClickMorphData"))
		NpcDisplayNames = {}
		for id, tbl in pairs(NpcDisplayIDs) do
			NpcDisplayNames[tbl[2]:lower()] = {id, tbl[1], tbl[2]}
		end
	end
	return NpcDisplayIDs, NpcDisplayNames
end

function CM:MorphNpcByID(npcID)
	local ids = self:GetDisplayIDs()
	local info = ids[npcID]
	if info then
		local displayId, name = info[1], info[2]
		self:MorphModel("player", displayId, npcID, name, true)
	else
		self:PrintChat("Could not find NPC "..npcID)
	end
end

local function MorphNpcByName(tbl)
	local npcID, displayID, name = unpack(tbl)
	CM:MorphModel("player", displayID, npcID, name, true)
end

local function MorphNpcByUnit(unit)
	local guid = UnitGUID(unit)
	if guid then
		local ids = CM:GetDisplayIDs()
		local unitType, _, _, _, _, npcID = strsplit("-", guid)
		if CreatureTypes[unitType] then
			npcID = tonumber(npcID)
			local info = ids[npcID]
			local targetDisplayID = info[1]
			local name = info[2]
			CM:MorphModel("player", targetDisplayID, npcID, name, true)
		end
	end
end

SLASH_CLICKMORPH_NPC1 = "/npc"

function SlashCmdList.CLICKMORPH_NPC(text)
	local _, npcNames = CM:GetDisplayIDs()
	local userNpcId = tonumber(text)
	-- morph directly by display ID
	if userNpcId then
		CM:MorphNpcByID(userNpcId)
	-- search through npc names
	elseif #text > 0 then
		local textLower = text:lower()
		if npcNames[textLower] then
			MorphNpcByName(npcNames[textLower])
		else
			for name, tbl in pairs(npcNames) do
				if name:find(textLower) then
					MorphNpcByName(tbl)
					return
				end
			end
			CM:PrintChat("Could not find NPC "..text)
		end
	else
		MorphNpcByUnit("target")
	end
end

TargetFrame:HookScript("OnClick", function(frame)
	if IsAltKeyDown() then
		MorphNpcByUnit(frame.unit)
	end
end)
