local addon = IJA_BMU_GAMEPAD_PLUGIN
local TeleportClass_Shared = addon.subclassTable.list_Shared

---------------------------------------------------------------------------------------------------------------
-- Teleport list
---------------------------------------------------------------------------------------------------------------
local g_selectedData = nil
local g_onWorldMapChanged_SetMapToTarget = false

local CATEGORY_TYPE_BMU = 7

local function matchWithPreviousData(entry)
	if g_selectedData then
		if entry.zoneId and not entry.currentZone then
			return g_selectedData.zoneId == entry.zoneId
		end
		return g_selectedData.displayName == entry.displayName
	end
	return false
end

local function hasDataChanged(selectedData)
	if g_selectedData then
		if selectedData.zoneId then
			return g_selectedData.zoneId ~= selectedData.zoneId
		end
		return g_selectedData.displayName ~= selectedData.displayName
	end
	return true
end

local function getCollectibleData(collectibleId)
	return ZO_COLLECTIBLE_DATA_MANAGER:GetCollectibleDataById(collectibleId)
end

local function tryToPort(data)
	-- check if porting is possible
	if CanLeaveCurrentLocationViaTeleport() and not IsUnitDead("player") then
		if data.displayName ~= '' then
			BMU.PortalToPlayer(data.displayName, data.sourceIndexLeading, data.zoneName, data.zoneId, data.category, true, true, true)
			return true
		elseif data.houseId then
			local collectibleData = getCollectibleData(data.collectibleId)
			if data.forceOutside then
				local TRAVEL_OUTSIDE = true
				RequestJumpToHouse(collectibleData:GetReferenceId(), TRAVEL_OUTSIDE)
			else
				jo_callLaterOnNextScene(addonData.prefix, function()
					ZO_Dialogs_ShowGamepadDialog("GAMEPAD_TRAVEL_TO_HOUSE_OPTIONS_DIALOG", collectibleData)
				end)
			end
			return true
	--	elseif then
		else
		end
	end
	return false
end

local function getMostUsedModifier()
	local mostUsed = 0

	local portCounterPerZone = BMU.savedVarsAcc.portCounterPerZone or {}
	for zoneId, timesUsed in pairs(BMU.savedVarsAcc.portCounterPerZone) do
		if timesUsed > mostUsed then
			mostUsed = timesUsed
		end
	end

	if mostUsed > 0 then
		mostUsed = mostUsed * 0.9
	end

	return mostUsed
end

local DEFAULT_SORT_KEYS = {
	sortOrder = { tiebreaker = "originalSort", isNumeric = true },
	originalSort = { isNumeric = true },
}

local function sortFunction(data1, data2)
	return ZO_TableOrderingFunction(data1, data2, 'sortOrder', DEFAULT_SORT_KEYS, ZO_SORT_ORDER_UP)
end

local function isTargetPlayer(socialData)
	return socialData.displayName ~= nil and socialData.displayName ~= ''
end

---------------------------------------------------------------------------------------------------------------
-- 
---------------------------------------------------------------------------------------------------------------
local teleportList = TeleportClass_Shared:Subclass()

function teleportList:Initialize(owner, control)
	TeleportClass_Shared.Initialize(self, control)

	self.container = control
	self.owner = owner

	self.noItemsLabel:SetText(GetString(SI_TELE_UI_NO_MATCHES))

	self:RegisterCallbacks()

	self.fragment:RegisterCallback("StateChange",  function(oldState, newState)
		if newState == SCENE_SHOWING then
			self:Activate()
			KEYBIND_STRIP:AddKeybindButtonGroup(self.keybindStripDescriptor)
			self.lastSelectedIndex = 1
			self:Refresh()
		elseif newState == SCENE_SHOWN then
			self:UpdateTooltip(self:GetTargetData())
		elseif newState == SCENE_HIDDEN then
			KEYBIND_STRIP:RemoveKeybindButtonGroup(self.keybindStripDescriptor)
			self:Deactivate()
			self.owner.OnHideTeleportList()
		end
	end)
end

function teleportList:InitializeKeybindDescriptor()
	self.keybindStripDescriptor = {
		alignment = KEYBIND_STRIP_ALIGN_LEFT,
		{ -- select item
	--		name = GetString(SI_GAMEPAD_SELECT_OPTION),
			name = function()
				local targetData = self:GetTargetData()

				if targetData then
					if targetData.categoryType == CATEGORY_TYPE_BMU then
						return GetString(SI_GUILD_BROWSER_GUILD_LIST_VIEW_GUILD_INFO_KEYBIND)
					end
				end
				return GetString(SI_GAMEPAD_WORLD_MAP_TRAVEL)
			end,
			keybind = "UI_SHORTCUT_PRIMARY",
			callback = function()
				local targetData = self:GetTargetData()

				if targetData then
					if targetData.categoryType == CATEGORY_TYPE_BMU then
						ZO_LinkHandler_OnLinkClicked("|H1:guild:" .. targetData.guildId .. "|hGuild|h", 1, nil)
					else
						if tryToPort(targetData) then
							SCENE_MANAGER:ShowBaseScene()
						end
					end
				end
			end,
			enabled = function()
				local targetData = self:GetTargetData()

				if targetData then
					if targetData.categoryType == CATEGORY_TYPE_BMU then
						return not targetData.hideButton
					else
						return targetData ~= nil
					end
				end
			end,
			visible = function() return true end,
		},
		{ -- group rally point
			name = GetString(SI_TOOLTIP_UNIT_MAP_RALLY_POINT),
			keybind = "UI_SHORTCUT_SECONDARY",
			callback = function()
				local targetData = self:GetTargetData()

				targetData:Ping()
				PlaySound(SOUNDS.MAP_LOCATION_CLICKED)
			end,
			enabled = function()
				local targetData = self:GetTargetData()
				if targetData ~= nil then
					return targetData.pinInfo or targetData.unitTag ~= nil
				end
				return false
			end,
			visible = function()
				local targetData = self:GetTargetData()
				if targetData ~= nil then
					return targetData.categoryType ~= CATEGORY_TYPE_BMU
				end
			end,
		--	visible = function() return IsUnitGroupLeader("player") end,
		},
		{ -- show options
			name = GetString(SI_GAMEPAD_OPTIONS_MENU),
			keybind = "UI_SHORTCUT_TERTIARY",
			enabled = function()
				return self:HasAnyShownOptions()
			end,
			callback = function()
				return self:ShowOptionsDialog()
			end,
			visible = function()
				local targetData = self:GetTargetData()
				if targetData ~= nil then
					return targetData.categoryType ~= CATEGORY_TYPE_BMU
				end
			end,
		},
	}

	local function backButton()
		PlaySound(SOUNDS.GAMEPAD_MENU_BACK)
		self.owner.OnHideTeleportList()
	end

	ZO_Gamepad_AddBackNavigationKeybindDescriptors(self.keybindStripDescriptor, GAME_NAVIGATION_TYPE_BUTTON, backButton)
	ZO_Gamepad_AddListTriggerKeybindDescriptors(self.keybindStripDescriptor, self)
end

function teleportList:RegisterCallbacks()
	local function onWorldMapChanged()
		if g_onWorldMapChanged_SetMapToTarget then
			if self.owner.savedVars.panAndZoom then
				self:PanAndZoomToPin()
			end
		end
		g_onWorldMapChanged_SetMapToTarget = false
	end
	CALLBACK_MANAGER:RegisterCallback("OnWorldMapChanged", onWorldMapChanged)
end

function teleportList:GetCurrentCategory()
	return self.owner.categoryList:GetTargetData()
end

function teleportList:OnSelectedDataChangedCallback(selectedData)
	if hasDataChanged(selectedData) then
		g_selectedData = selectedData

		self:SetMapToTarget(selectedData)
		d( selectedData.zoneName)
	end
	
	self:UpdateTooltip(selectedData)
end

---------------------------------------------------------------------------------------------------------------
-- 
---------------------------------------------------------------------------------------------------------------
function teleportList:BuildOptionsList()
	local function ShouldAddPlayerOption()
		return self:ShouldAddPlayerOption()
	end
	self:BuildGroupOptionsList()
	self:BuildPlayerOptionsList()

	local groupIdFavorites = self:AddOptionTemplateGroup(function() return GetString(SI_TELE_UI_SUBMENU_FAVORITES) end)
	local function toggleFavoritPlayer()
		local filterData = {
			filterName = GetString(SI_TELE_UI_FAVORITE_PLAYER),
			callback = function(data)
				self:ToggleBUISetting('favoriteListPlayers', data.checked, self.socialData.displayName)
			end,
			checked = function() return self:GetBUISetting('favoriteListPlayers', self.socialData.displayName) end,
		}
		return filterData
	end

	self:AddOptionTemplate(groupIdFavorites, function() return self:BuildCheckbox(nil, label, toggleFavoritPlayer, icon) end, ShouldAddPlayerOption)

	local function toggleFavoritZone()
		local filterData = {
			filterName = GetString(SI_TELE_UI_FAVORITE_ZONE),
			callback = function(data)
				self:ToggleBUISetting('favoriteListZones', data.checked, self.socialData.zoneId)
			end,
			checked = function() return self:GetBUISetting('favoriteListZones', self.socialData.zoneId) end,
		}
		return filterData
	end

	self:AddOptionTemplate(groupIdFavorites, function() return self:BuildCheckbox(nil, label, toggleFavoritZone, icon) end, function() return self.socialData.zoneId ~= nil end)

	-- TODO: create string 'Manage Favorites'
	local function manageFavoritesSetup()
		local function callback()
			ZO_Dialogs_ShowGamepadDialog("BMU_GAMEPAD_MANAGE_FAVORITES_DIALOG")
			ZO_Dialogs_ReleaseDialogOnButtonPress("BMU_GAMEPAD_SOCIAL_OPTIONS_DIALOG")
		end

		return self:BuildOptionEntry(nil, SI_BMU_GAMEPAD_MANAGE_FAVORITES, callback)
	end
	self:AddOptionTemplate(groupIdFavorites, manageFavoritesSetup)
end

function teleportList:BuildPlayerOptionsList()
	local function ShouldAddPlayerOption()
		return self:ShouldAddPlayerOption()
	end
	
	local function BuildIgnoreOption()
		local callback = function()
			ZO_Dialogs_ReleaseAllDialogsOfName("BMU_GAMEPAD_SOCIAL_OPTIONS_DIALOG")
			ZO_Dialogs_ShowGamepadDialog("CONFIRM_IGNORE_FRIEND", self.socialData, {mainTextParams={ ZO_FormatUserFacingDisplayName(self.socialData.displayName) }})
		end
		return self:BuildOptionEntry(nil, SI_FRIEND_MENU_IGNORE, callback)
	end

	local function BuildAddFriendOption()
		local callback = function()
			ZO_Dialogs_ReleaseAllDialogsOfName("BMU_GAMEPAD_SOCIAL_OPTIONS_DIALOG")
			ZO_Dialogs_ShowGamepadDialog("GAMEPAD_SOCIAL_ADD_FRIEND_DIALOG", { displayName = self.socialData.displayName, })
		end
		return self:BuildOptionEntry(nil, SI_SOCIAL_MENU_ADD_FRIEND, callback)
	end

	local groupId = self:AddOptionTemplateGroup(function() return self.socialData.displayName end)

	local function ShouldAddInviteToGroupOptionAndCanSelectedDataBeInvited()
		return self:ShouldAddInviteToGroupOption() and (self:SelectedDataIsLoggedIn() and not IsPlayerInGroup(self.socialData.displayName))
	end

	self:AddOptionTemplate(groupId, self.BuildWhisperOption, ShouldAddPlayerOption)
	self:AddOptionTemplate(groupId, ZO_SocialOptionsDialogGamepad.BuildInviteToGroupOption, ShouldAddInviteToGroupOptionAndCanSelectedDataBeInvited)
	self:AddOptionTemplate(groupId, ZO_SocialOptionsDialogGamepad.BuildVisitPlayerHouseOption, ShouldAddPlayerOption)

	self:AddOptionTemplate(groupId, BuildAddFriendOption, ShouldAddPlayerOption)
	self:AddOptionTemplate(groupId, self.BuildSendMailOption, ShouldAddPlayerOption)

	self:AddOptionTemplate(groupId, BuildIgnoreOption, ShouldAddPlayerOption)

	self:AddInviteToGuildOptionTemplates()
end

function teleportList:BuildGroupOptionsList(groupId)
	if not IsUnitGrouped("player") then return end

	local groupId = self:AddOptionTemplateGroup(function() return GetString(SI_INSTANCEDISPLAYTYPE5) end)

	local function CanKickMember()
		return IsGroupModificationAvailable() and not DoesGroupModificationRequireVote() and IsUnitGroupLeader("player") and not self:SelectedDataIsPlayer()
	end

	local function CanVoteForKickMember()
		return IsGroupModificationAvailable() and DoesGroupModificationRequireVote() and not self:SelectedDataIsPlayer()
	end

	local function ShouldAddPromoteOption()
		return IsUnitGroupLeader("player") and self.socialData.online and not self:SelectedDataIsPlayer()
	end
	self:AddOptionTemplate(groupId, self.BuildPromoteToLeaderOption, ShouldAddPromoteOption)
	self:AddOptionTemplate(groupId, self.BuildKickMemberOption, CanKickMember)
	self:AddOptionTemplate(groupId, self.BuildVoteKickMemberOption, CanVoteForKickMember)

	local function BuilLeaveGroupOption()
		local callback = function()
			ZO_Dialogs_ReleaseAllDialogsOfName("BMU_GAMEPAD_SOCIAL_OPTIONS_DIALOG")
			ZO_Dialogs_ShowGamepadDialog("GROUP_LEAVE_DIALOG")
		end
		return self:BuildOptionEntry(nil, SI_GROUP_LIST_MENU_LEAVE_GROUP, callback)
	end

	self:AddOptionTemplate(groupId, BuilLeaveGroupOption, ZO_SocialOptionsDialogGamepad.ShouldAddSendMailOption)
end

function teleportList:BuildPromoteToLeaderOption()
	local callback = function()
		GroupPromote(self.socialData.unitTag)
	end
	return self:BuildOptionEntry(nil, SI_GROUP_LIST_MENU_PROMOTE_TO_LEADER, callback)
end

function teleportList:BuildKickMemberOption()
	local callback = function()
		ZO_Dialogs_ReleaseAllDialogsOfName("BMU_GAMEPAD_SOCIAL_OPTIONS_DIALOG")
		GroupKick(self.socialData.unitTag)
	end
	return self:BuildOptionEntry(nil, SI_GROUP_LIST_MENU_KICK_FROM_GROUP, callback)
end

function teleportList:BuildVoteKickMemberOption()
	local callback = function()
		ZO_Dialogs_ReleaseAllDialogsOfName("BMU_GAMEPAD_SOCIAL_OPTIONS_DIALOG")
		BeginGroupElection(GROUP_ELECTION_TYPE_KICK_MEMBER, ZO_GROUP_ELECTION_DESCRIPTORS.NONE, self.socialData.unitTag)
	end
	return self:BuildOptionEntry(nil, SI_GROUP_LIST_MENU_VOTE_KICK_FROM_GROUP, callback)
end

function teleportList:AddInviteToGuildOptionTemplates()
    local guildCount = GetNumGuilds()

    if guildCount > 0 then
        local guildInviteGroupingId = self:AddOptionTemplateGroup(function() return GetString(SI_GAMEPAD_CONTACTS_INVITE_TO_GUILD_HEADER) end)
        for i = 1, guildCount do
            local guildId = GetGuildId(i)
            local buildFunction = function() return self:BuildGuildInviteOption(nil, guildId) end
			local function visibleFunction()
				if guildId ~= 0 and DoesPlayerHaveGuildPermission(guildId, GUILD_PERMISSION_INVITE) and self.socialData.displayName ~= '' then
					return GetGuildMemberIndexFromDisplayName(guildId, self.socialData.displayName) == nil
				end

				return false
			end
            self:AddOptionTemplate(guildInviteGroupingId, buildFunction, visibleFunction)
		end
	end
end

function teleportList:BuildGuildInviteOption(header, guildId)
    local inviteFunction = function()
            ZO_TryGuildInvite(guildId, self.socialData.displayName)
        end

    return self:BuildOptionEntry(header, GetGuildName(guildId), inviteFunction, nil, GetLargeAllianceSymbolIcon(GetGuildAlliance(guildId)))
end

function teleportList:ShouldAddPlayerOption()
	return self.socialData.displayName ~= nil and self.socialData.displayName ~= ''
end

---------------------------------------------------------------------------------------------------------------
-- 
---------------------------------------------------------------------------------------------------------------
function teleportList:ToggleBUISetting(index, checked, key)
	local savedVars = BMU.savedVarsServ[index]

	if key then
		savedVars[key] = checked or nil
	else
		savedVars = checked or nil
	end
	BMU.savedVarsServ[index] = savedVars

	self.owner:UpdatePortalPlayers()
--	self:RefreshVisible()
	self:Refresh()
end

function teleportList:GetBUISetting(index, key)
	local setting = BMU.savedVarsServ[index]
	return setting[key]
end

function teleportList:Refresh()
	if self.fragment:IsHidden() then return end
	g_selectedData = self:GetTargetData()

	local orig_Callback = self.onSelectedDataChangedCallback
	
	self:Clear()
	local selectedIndex

	local teleportPlayers = self.owner.portalPlayers
--	local myZoneId = GetUnitZone("player")

	local mostUsedModifier = getMostUsedModifier()
	-- Now lets update additional data for each entry to use for sorting.
	for i, entry in ipairs(teleportPlayers) do
		-- Use originalSort to maintain the sort order from BMU within each respective subcategory.
		entry.originalSort = i
		entry:Update(mostUsedModifier)
	end
	table.sort(teleportPlayers, sortFunction)

	local lastHeader
	for i, entry in ipairs(teleportPlayers) do
		local header = entry:GetHeader()
		if matchWithPreviousData(entry) then
			selectedIndex = i
		end

		-- only add the header to the first entry for that subcategory.
		if lastHeader ~= header then
			lastHeader = header
			entry:SetHeader(header)
			self:AddEntry("ZO_GamepadMenuEntryTemplateLowercase42WithHeader", entry)
		else
			self:AddEntry("ZO_GamepadMenuEntryTemplateLowercase42", entry)
		end
	end
	
    local DEFAULT_RESELECT = nil
    local BLOCK_SELECTION_CHANGED_CALLBACK = not self.isMoving and selectedIndex ~= nil
	-- In order to prevent the map from changing on data update we will block the callback unless selections are being made while updating.
	self:Commit(DEFAULT_RESELECT, BLOCK_SELECTION_CHANGED_CALLBACK)
	
	if selectedIndex then
		local ALLOW_IF_DISABLED = true
		self:SetSelectedIndex(selectedIndex, ALLOW_IF_DISABLED)
		self:RefreshVisible() -- Force the previous selection to take place immediately.
	else
		-- If the currently selected list item no longer exists, lets not reset to top.
	--	self:SetSelectedIndex(1)
	end

	self:RefreshNoEntriesLabel()
	self:RefreshKeybind()
end

---------------------------------------------------------------------------------------------------------------
-- 
---------------------------------------------------------------------------------------------------------------
function teleportList:PanAndZoomToPin()
	local selectedData = self.selectedData

	if selectedData then
		local pinInfo = selectedData.pinInfo

		if selectedData.unitTag and self.owner.savedVars.panToGroupMember then
			local delay, xLoc, yLoc, isInCurrentMap = selectedData:GetUnitMapPosition()

			zo_callLater(function()
				ZO_WorldMap_PanToNormalizedPosition(xLoc, yLoc)
			end, delay)
		elseif pinInfo then
			zo_callLater(function()
				local xLoc, yLoc = GetPOIMapInfo(pinInfo.poiZoneIndex, pinInfo.poiIndex)
				ZO_WorldMap_PanToNormalizedPosition(xLoc, yLoc)
			end, 100)
		end
	end
end

teleportList.SetMapToTarget = JO_UpdateBuffer_Simple('IJA_BMU_Gamepad_SetMapToTarget', function(self, selectedData)
	g_onWorldMapChanged_SetMapToTarget = true
	local mapId = selectedData.mapId or selectedData.parentMapId
	self.selectedData:SetMapToEntry(mapId)
end, 200)

---------------------------------------------------------------------------------------------------------------
-- 
---------------------------------------------------------------------------------------------------------------
addon.subclassTable.teleportList = teleportList


