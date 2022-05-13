--[[
- - - 0.1
○









test category filter options
test player options




SI_BMU_GAMEPAD_MANAGE_FAVORITES = 'Manage Favorites',

]]



---------------------------------------------------------------------------------------------------------------
--
---------------------------------------------------------------------------------------------------------------
local addonData = {
	displayName = "|cFF00FFIsJusta|r |cffffffBeam Me Up Gamepad Plugin|r",
	name = "IsJustaBmuGamepadPlugin",
	prefix = "IJA_BMU",
	version = "0.1",
}

local defaults = {
	panAndZoom = true,
	panToGroupMember = true,
}

local svVersion = 1

---------------------------------------------------------------------------------------------------------------
--
---------------------------------------------------------------------------------------------------------------
local USES_RIGHT_SIDE_CONTENT = true

local playersPerZone = {}

---------------------------------------------------------------------------------------------------------------
--
---------------------------------------------------------------------------------------------------------------
local addon = ZO_InitializingObject:Subclass()

function addon:Initialize(control)
	self.control = control
	zo_mixin(self, addonData)

	self.portalPlayers = {}
	self.teleportMap = {}
	self.subclassTable = {}

	local function OnLoaded(_, name)
		if name ~= self.name then return end
		self.control:UnregisterForEvent(EVENT_ADD_ON_LOADED)

		self.savedVars = ZO_SavedVars:NewAccountWide("IJA_BMU_SavedVars", 1, nil, defaults, GetWorldName())

		self.categoryList = self.subclassTable.categoryList:New(self, control)
		self.teleportList = self.subclassTable.teleportList:New(self, IJA_BMU_TeleportList_Gamepad)
	--	self.subclassTable = nil

		self:InitializeCustomTabs()
		self:RegisterEvents()
		self:CreateSettings()
	end
	control:RegisterForEvent( EVENT_ADD_ON_LOADED, OnLoaded)

	local function onPlayerActivated()
		self.control:UnregisterForEvent(EVENT_PLAYER_ACTIVATED)
	--	d( self.displayName

	end
	control:RegisterForEvent(EVENT_PLAYER_ACTIVATED, onPlayerActivated)
end

function addon:InitializeCustomTabs()
	local mapInfo = GAMEPAD_WORLD_MAP_INFO
	local tabBarEntries = mapInfo.tabBarEntries
	self.orginalHeaderData = GAMEPAD_WORLD_MAP_INFO.baseHeaderData

	local newtab = {
		text = BMU.var.color.colLegendary .. BMU.var.appName .. BMU.var.color.colWhite.. " - Teleporter",
		callback = function() mapInfo:SwitchToFragment(self.categoryList.fragment, USES_RIGHT_SIDE_CONTENT) end,
	}
	table.insert(tabBarEntries, 1, newtab)

	mapInfo.tabBarEntries = tabBarEntries

	mapInfo.baseHeaderData = {
		tabBarEntries = mapInfo.tabBarEntries,
	}

	ZO_GamepadGenericHeader_Refresh(mapInfo.header, mapInfo.baseHeaderData)
	ZO_GamepadGenericHeader_SetActiveTabIndex(mapInfo.header, 1)

	local getTabHeader = function()
		local categoryData = self.categoryList:GetTargetData()

		if categoryData then
			return categoryData.name
		end

		return "Locations"
	end

	self.baseHeaderData = {
		tabBarEntries = {
			{
				text = getTabHeader,
				callback = function() mapInfo:SwitchToFragment(self.teleportList.fragment, USES_RIGHT_SIDE_CONTENT) end,
			}
		}
	}
	self.OnShowTeleportList = function()
		mapInfo.baseHeaderData = self.baseHeaderData
		ZO_GamepadGenericHeader_Refresh(mapInfo.header, mapInfo.baseHeaderData)
		ZO_GamepadGenericHeader_SetActiveTabIndex(mapInfo.header, 1)
	end

	self.OnHideTeleportList = function()
		mapInfo.baseHeaderData = self.orginalHeaderData
		GAMEPAD_WORLD_MAP_INFO:OnShowing()
		mapInfo:SwitchToFragment(self.categoryList.fragment, USES_RIGHT_SIDE_CONTENT)
		self:RefreshHeader()
	--	ZO_GamepadGenericHeader_Refresh(mapInfo.header, mapInfo.baseHeaderData)
	end
end

function addon:RefreshHeader()
	local mapInfo = GAMEPAD_WORLD_MAP_INFO
	local baseHeaderData = mapInfo.baseHeaderData

	local newTabData = {}
	zo_callLater(function()
		if mapInfo.fragment == self.categoryList.fragment or mapInfo.fragment == self.teleportList.fragment then
			newTabData = {
				tabBarEntries = baseHeaderData.tabBarEntries,

				data1HeaderText = GetString(SI_TELE_UI_GOLD),
				data1Text = BMU.formatGold(BMU.savedVarsAcc.savedGold),

				data2HeaderText = GetString(SI_TELE_UI_TOTAL_PORTS),
				data2Text = BMU.formatGold(BMU.savedVarsAcc.totalPortCounter),

				data3HeaderText = GetString(SI_TELE_UI_TOTAL),
				data3Text = #self.portalPlayers,
			}
		else
			newTabData = {
				tabBarEntries = baseHeaderData.tabBarEntries,
			}
		end

		mapInfo.baseHeaderData = newTabData
		ZO_GamepadGenericHeader_Refresh(mapInfo.header, mapInfo.baseHeaderData)
	end, 20)
end

function addon:CreateSettings()
	if not BMU.var.optionsTable then return end
	local controls = {
		{ -- "Can Research"
			type = "checkbox",
			name = GetString(SI_BMU_GAMEPAD_PAN),
			tooltip = GetString(SI_IJADECON_AUTOADD_TOOLTIP),
			getFunc = function()
				return self.savedVars.panAndZoom
			end,
			setFunc = function(value)
				self.savedVars.panAndZoom = value
			end,
			width = "full"
		},
		{ -- "Can Research"
			type = "checkbox",
			name = GetString(SI_BMU_GAMEPAD_PAN_TO_GROUP),
			tooltip = GetString(SI_IJADECON_AUTOADD_TOOLTIP),
			getFunc = function()
				return self.savedVars.panToGroupMember
			end,
			setFunc = function(value)
				self.savedVars.panToGroupMember = value
			end,
			disabled = function() return not self.savedVars.panAndZoom end,
			width = "full"
		},
	}
	
	local submenu = {
		type = "submenu",
		name = GetString(SI_GAMEPAD_SECTION_HEADER),
		controls = controls,
	}
	
	local optionsTable = BMU.var.optionsTable
	table.insert(optionsTable, submenu)
	
	BMU.LAM:RegisterOptionControls(BMU.var.appName .. "Options", optionsTable)
end

function addon:UpdatePortalPlayers()
	if not self.teleportList then return end
	local portalPlayers = {}
	playersPerZone = {}

	local categoryData = self.categoryList:GetTargetData()

	local myZoneId = GetUnitZone("player")
	local teleporterList = TeleporterList.lines or {}
	for k, data in pairs(teleporterList) do
		if data.category and data.category > 0 or data.guildId ~= nil then
			if not categoryData.categoryFilter or categoryData.categoryFilter(data) then

				data.categoryType = categoryData.categoryType

				if categoryData.filter.index > 9 then
					BMU_Gamepad_EntryData:CreateMultiEntry(data, dataTable)
				else
					local entry = BMU_Gamepad_EntryData:CreateNewEntry(data, data.zoneId == myZoneId)
					if entry then
						table.insert(portalPlayers, entry)
					end
				end

				if data.numberPlayers then
					local zoneIndex = data.zoneIndex or GetZoneIndex(data.zoneId)
					if not playersPerZone[zoneIndex] then
						playersPerZone[zoneIndex] = data.numberPlayers
					end
				end
			end
		end
	end

	self.portalPlayers = portalPlayers

--	GAMEPAD_WORLD_MAP_LOCATIONS.data.mapData = nil
	GAMEPAD_WORLD_MAP_LOCATIONS:BuildLocationList()
end

function addon:CreateTestList(filter)
	if not self.teleportList then return end
	
	local portalPlayers = {}
	playersPerZone = {}

	local categoryData = self.categoryList:GetTargetData()

	local myZoneId = GetUnitZone("player")
	
	local teleporterList = {}
		
	if filter.index == 0 then
		WORLD_MAP_HOUSES_DATA:RefreshHouseList()
		local houses = WORLD_MAP_HOUSES_DATA:GetHouseList()
		for i = 1, #houses do
			local house = houses[i]
			local entry = BMU.createBlankRecord()
			entry.isOwnHouse = house.unlocked
			entry.zoneId = GetHouseZoneId(house.houseId)
			entry.zoneNameUnformatted = GetZoneNameById(entry.zoneId)
			entry.textColorDisplayName = BMU.var.color.colTrash
			entry.zoneNameClickable = true
			entry.mapIndex = BMU.getMapIndex(entry.zoneId)
			entry.parentZoneId = BMU.getParentZoneId(entry.zoneId)
			entry.parentZoneName = BMU.formatName(GetZoneNameById(entry.parentZoneId))
			entry.category = BMU.categorizeZone(entry.zoneId)
			entry.collectibleId = GetCollectibleIdForHouse(entry.houseId)
			entry.houseCategoryType = GetString("SI_HOUSECATEGORYTYPE", GetHouseCategoryType(entry.houseId))
			entry.nickName = BMU.formatName(GetCollectibleNickname(entry.collectibleId))
			entry.zoneName = BMU.formatName(entry.zoneNameUnformatted, BMU.savedVarsAcc.formatZoneName)
			
			_, _, entry.houseIcon = GetCollectibleInfo(entry.collectibleId)
			entry.houseBackgroundImage = GetHousePreviewBackgroundImage(entry.houseId)
			entry.houseTooltip = {entry.zoneName, "\"" .. entry.nickName .. "\"", entry.parentZoneName, "", "", "|t75:75:" .. entry.houseIcon .. "|t", "", "", entry.houseCategoryType}
		
			if BMU.savedVarsAcc.houseNickNames then
				-- show nick name instead of real house name
				entry.zoneName = entry.nickName
			end
			
			table.insert(teleporterList, entry)
		end
	else
		for zoneIndex = 1, 3000 do
			local zoneId = GetZoneId(zoneIndex)
			local zoneName = GetZoneNameById(zoneId)
			
			if zoneName ~= '' then
				local entry = BMU.createBlankRecord()
				
				entry.zoneId = zoneId
				entry.zoneNameUnformatted = zoneName
				entry.textColorDisplayName = BMU.var.color.colTrash
				entry.zoneNameClickable = true
				entry.mapIndex = BMU.getMapIndex(zoneId)
				entry.parentZoneId = BMU.getParentZoneId(zoneId)
				entry.parentZoneName = BMU.formatName(GetZoneNameById(parentZoneId))
				entry.category = BMU.categorizeZone(zoneId)
				entry.zoneName = BMU.formatName(zoneName)
				entry.textColorZoneName = BMU.var.color.colWhite
				
				table.insert(teleporterList, entry)
			end
		end
	end

	for k, data in pairs(teleporterList) do
		if data.category and data.category > 0 or data.guildId ~= nil then
			if not categoryData.categoryFilter or categoryData.categoryFilter(data) then

				data.categoryType = categoryData.categoryType
				data.category = BMU.categorizeZone(data.zoneId) or 9
				if categoryData.filter.index > 9 then
					BMU_Gamepad_EntryData:CreateMultiEntry(data, dataTable)
				else
					local entry = BMU_Gamepad_EntryData:CreateNewEntry(data, data.zoneId == myZoneId)
					if entry then
						table.insert(portalPlayers, entry)
					end
				end
			end
		end
	end

	BMU.changeState(0)
	
	self.portalPlayers = portalPlayers

	self:RefreshHeader()

	if not self.categoryList.fragment:IsHidden() then
		self.categoryList:RefreshKeybind()
	elseif not self.teleportList.fragment:IsHidden() then
		self.teleportList:Refresh()
	end
			
--	GAMEPAD_WORLD_MAP_LOCATIONS.data.mapData = nil
	GAMEPAD_WORLD_MAP_LOCATIONS:BuildLocationList()
end

do
	local lastTime = 0
	local REFRESH_ON_EVENT_TIME_DELAY = 5000
	function addon:RefreshOnEvent(frameTimeInMilliseconds, ...)
		if frameTimeInMilliseconds > lastTime then
			local args = {...}
			lastTime = frameTimeInMilliseconds + REFRESH_ON_EVENT_TIME_DELAY

			local function onUpdate()
				EVENT_MANAGER:UnregisterForUpdate(self.name)
				CALLBACK_MANAGER:FireCallbacks('BMU_GAMEPAD_CATEGORY_CHANGED')
			end

			EVENT_MANAGER:UnregisterForUpdate(self.name)
			EVENT_MANAGER:RegisterForUpdate(self.name, REFRESH_ON_EVENT_TIME_DELAY, onUpdate)
		end
	end
end

function addon:RegisterEvents()
	local function onCategoryChanged(categoryData)
		if not categoryData then return end

		-- Here temporarily, may not be needed on next BMU update.
		if categoryData.filter.index == 8 then
			categoryData.filter.fZoneId = GetZoneId(GetCurrentMapZoneIndex())
		end
		
	--	BMU.changeState(categoryData.filter.index)
		if categoryData.callback then
			categoryData.callback(categoryData.filter)
			if categoryData.categoryType ~= 9 then
				self:UpdatePortalPlayers()
				self.isDirty = true
			end
		end
	end
	CALLBACK_MANAGER:RegisterCallback('BMU_GAMEPAD_CATEGORY_CHANGED', onCategoryChanged)

	local function onBmuListUpdated()
		local categoryListShowing = not self.categoryList.fragment:IsHidden()
		local teleportListShowing = not self.teleportList.fragment:IsHidden()

		if categoryListShowing or teleportListShowing then
			self:UpdatePortalPlayers()
			self:RefreshHeader()

			if categoryListShowing then
				self.categoryList:RefreshKeybind()
			elseif teleportListShowing then
				self.teleportList:Refresh()
			end
		end
	end
	CALLBACK_MANAGER:RegisterCallback('BMU_List_Updated', onBmuListUpdated)

	local function refreshOnEvent(_, ...)
		self:RefreshOnEvent(GetFrameTimeMilliseconds(), ...)
	end

	EVENT_MANAGER:RegisterForEvent(self.name, EVENT_FRIEND_ADDED, refreshOnEvent)
	EVENT_MANAGER:RegisterForEvent(self.name, EVENT_FRIEND_REMOVED, refreshOnEvent)

	EVENT_MANAGER:RegisterForEvent(self.name, EVENT_GROUP_MEMBER_LEFT, refreshOnEvent)
	EVENT_MANAGER:RegisterForEvent(self.name, EVENT_GROUP_MEMBER_JOINED, refreshOnEvent)

	EVENT_MANAGER:RegisterForEvent(self.name, EVENT_GUILD_MEMBER_ADDED, refreshOnEvent)
	EVENT_MANAGER:RegisterForEvent(self.name, EVENT_GUILD_MEMBER_REMOVED, refreshOnEvent)

	EVENT_MANAGER:RegisterForEvent(self.name, EVENT_FRIEND_PLAYER_STATUS_CHANGED, refreshOnEvent)
    EVENT_MANAGER:RegisterForEvent(self.name, EVENT_GROUP_MEMBER_CONNECTED_STATUS, refreshOnEvent)
    EVENT_MANAGER:RegisterForEvent(self.name, EVENT_GUILD_MEMBER_PLAYER_STATUS_CHANGED, refreshOnEvent)

	EVENT_MANAGER:RegisterForEvent(self.name, EVENT_FRIEND_CHARACTER_ZONE_CHANGED, refreshOnEvent)
	EVENT_MANAGER:RegisterForEvent(self.name, EVENT_GUILD_MEMBER_CHARACTER_ZONE_CHANGED, refreshOnEvent)

    local function OnZoneUpdate(evt, unitTag, newZone)
--	d( '-- EVENT_ZONE_UPDATE', unitTag)
        if ZO_Group_IsGroupUnitTag(unitTag) or unitTag == "player" then
            refreshOnEvent()
        end
    end
    EVENT_MANAGER:RegisterForEvent(self.name, EVENT_ZONE_UPDATE, OnZoneUpdate)

	self.eventsRegistered = true

	local function getLocationList()
		return self:RefreshLocationList()
	end
	GAMEPAD_WORLD_MAP_LOCATIONS.data.GetLocationList = getLocationList
end

function addon:RefreshLocationList()
    local mapData = {}
    for i = 1, GetNumMaps() do
        local mapName, mapType, mapContentType, zoneIndex, description = GetMapInfoByIndex(i)

		if description ~= '' then
			local numResults, locationName = playersPerZone[zoneIndex]
			if numResults then
				locationName = ZO_CachedStrFormat('<<t:1>><<2>>', mapName, numResults)
			else
				locationName = ZO_CachedStrFormat(SI_ZONE_NAME, mapName)
			end

			mapData[#mapData + 1] = { locationName = locationName, description = description, index = i }
		end
	end

    table.sort(mapData, function(a,b)
        return a.locationName < b.locationName
    end)

    return mapData
end

---------------------------------------------------------------------------------------------------------------
--
---------------------------------------------------------------------------------------------------------------
function IJA_BMU_Initialize( ... )
	IJA_BMU_GAMEPAD_PLUGIN = addon:New( ... )
end
	








