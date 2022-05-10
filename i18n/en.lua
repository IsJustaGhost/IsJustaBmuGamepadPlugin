------------------------------------------------
-- English localization
------------------------------------------------

local strings = {
	SI_BMU_GAMEPAD_CATEGORY_DELVES		= "Delves and open Dungeons",
	
	SI_BMU_GAMEPAD_PAN					= "Focus in on map pin",
	SI_BMU_GAMEPAD_PAN_TOOLTIP			= "Focus in on map pin",
	
	SI_BMU_GAMEPAD_PAN_TO_GROUP			= "Focus in on group member",
	SI_BMU_GAMEPAD_PAN_TO_GROUP_TOOLTIP	= "Focus in on group member",
}

for stringId, stringValue in pairs(strings) do
	ZO_CreateStringId(stringId, stringValue)
	SafeAddVersion(stringId, 1)
end
