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
		local FileData = self:GetFileData()
		NpcDisplayIDs = FileData[CM.project].Npc or {}
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

function CM:MorphNpcByName(tbl)
	local npcID, displayID, name = unpack(tbl)
	self:MorphModel("player", displayID, npcID, name, true)
end

function CM:MorphNpcByUnit(unit)
	local guid = UnitGUID(unit)
	if guid then
		local ids = CM:GetDisplayIDs()
		local unitType, _, _, _, _, npcID = strsplit("-", guid)
		if CreatureTypes[unitType] then
			npcID = tonumber(npcID)
			local info = ids[npcID]
			local targetDisplayID = info[1]
			local name = info[2]
			self:MorphModel("player", targetDisplayID, npcID, name, true)
		end
	end
end

function CM:MorphNpc(text)
	local _, npcNames = self:GetDisplayIDs()
	local userNpcId = tonumber(text)
	-- morph directly by display ID
	if userNpcId then
		self:MorphNpcByID(userNpcId)
	-- search through npc names
	elseif #text > 0 then
		local textLower = text:lower()
		if npcNames[textLower] then -- lookup name
			self:MorphNpcByName(npcNames[textLower])
		else
			for name, tbl in pairs(npcNames) do -- iterate through npcs
				if name:find(textLower) then
					self:MorphNpcByName(tbl)
					return
				end
			end
			self:PrintChat("Could not find NPC "..text)
		end
	else
		self:MorphNpcByUnit("target")
	end
end

SLASH_CLICKMORPH_NPC1 = "/npc"

function SlashCmdList.CLICKMORPH_NPC(text)
	CM:MorphNpc(text)
end

TargetFrame:HookScript("OnClick", function(frame)
	if IsAltKeyDown() then
		CM:MorphNpcByUnit(frame.unit)
	end
end)
