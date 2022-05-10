------------------------------------------------
-- English localization
------------------------------------------------

local strings = {
	SI_BMU_GAMEPAD_CATEGORY_DELVES		= "Delves and open Dungeons",
	
	SI_BMU_GAMEPAD_PAN					= "Focus in on map pin",
	SI_BMU_GAMEPAD_PAN_TOOLTIP			= "Enabled: If a destination has a map pin, on selection the map will auto-focus in on the pin.",
	
	SI_BMU_GAMEPAD_PAN_TO_GROUP			= "Focus in on group member",
	SI_BMU_GAMEPAD_PAN_TO_GROUP_TOOLTIP	= "Enabled: on selection of a group member, the map will auto-focus in on them.",
	
	SI_BMU_GAMEPAD_MANAGE_FAVORITES		= 'Manage Favorites',
}

for stringId, stringValue in pairs(strings) do
	ZO_CreateStringId(stringId, stringValue)
	SafeAddVersion(stringId, 1)
end
