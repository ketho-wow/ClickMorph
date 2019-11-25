local CM = ClickMorph
if not CM.isClassic then return end
local MountIDs

function CM:GetClassicMountIDs()
	if not MountIDs then
		MountIDs = {}
		local fd = self:GetFileData()
		for id, tbl in pairs(fd.Classic.MountID) do
			tinsert(MountIDs, {
				value = id,
				text = tbl.name,
			})
		end
		sort(MountIDs, function(a, b)
			return a.text < b.text
		end)
	end
	return MountIDs
end
