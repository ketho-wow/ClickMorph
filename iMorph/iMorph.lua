local CM = ClickMorph

CM.override = true
if CM.override then -- temporary dummy table
	IMorphInfo = IMorphInfo or {}
else
	return
end

local help = {
	"|cff7fff00iMorph|r commands:",
	".reset",
	".race |cffFFDAE9<1-9>|r, .gender",
	".morph |cffFFDAE9<id>|r, .npc |cffFFDAE9<id/name>|r",
	".morphpet |cffFFDAE9<id>|r",
	".mount |cffFFDAE9<id>|r",
	".item |cffFFDAE9<1-19> <id>|r, .itemset |cffFFDAE9<id>|r",
	".enchant |cffFFDAE9<1-2> <id>|r",
	".scale |cffFFDAE9<0.5-3.0>|r, .scalepet |cffFFDAE9<scale>|r",
	".title |cffFFDAE9<0-19>|r, .medal |cffFFDAE9<0-8>|r",
	".skin |cffFFDAE9<id>|r, .face |cffFFDAE9<id>|r, .features |cffFFDAE9<id>|r",
	".hair |cffFFDAE9<id>|r, .haircolor |cffFFDAE9<id>|r",
	".shapeshift |cffFFDAE9<form id> <display id>|r",
	".weather |cffFFDAE9<id> <0.0-1.0>|r",
	".disablesm, .enablesm",
}

-- all commands take numbers except .npc
-- so we have to sanitize each command separately
local commands = {
	help = function()
		for _, v in pairs(help) do
			print(v)
		end
	end,
	morph = function(id)
		id = tonumber(id)
		if id then
			Morph(id)
		end
	end,
}

local SendText = ChatEdit_SendText
ChatEdit_SendText = function(editBox, addHistory)
	local text = editBox:GetText()
	local cmd = text:match("^%.(%a+)")
	local func = commands[cmd]
	if Morph and func then
		local params = text:match("^%.%a+ (.+)") or ""
		func(strsplit(" ", params))
	else
		SendText(editBox, addHistory)
	end
end
