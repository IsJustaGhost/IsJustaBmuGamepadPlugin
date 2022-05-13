local addon = IJA_BMU_GAMEPAD_PLUGIN

--[[
	Updated how mapInfo is updated
	
	
	
	get strings for quest headers

]]


local SORT_ORDER_NONE			= 0
local SORT_ORDER_FRIEND			= 1
local SORT_ORDER_RECENT			= 2
local SORT_ORDER_FAVORITE		= 3
local SORT_ORDER_GROUP_LEADER	= 4
local SORT_ORDER_GROUP			= 5

local MIN_CATEGORY_SORT = SORT_ORDER_GROUP + 1

local CATEGORY_TYPE_GROUP		= 0
local CATEGORY_TYPE_ALL			= 1
local CATEGORY_TYPE_OTHER		= 2
local CATEGORY_TYPE_QUESTS		= 3
local CATEGORY_TYPE_ITEMS		= 4
local CATEGORY_TYPE_DUNGEON		= 5
local CATEGORY_TYPE_DISPLAYED	= 6
local CATEGORY_TYPE_BMU			= 7
local CATEGORY_TYPE_DELVE		= 8

local CURRENT_CATEGORY_TYPE = 0

local HEADER_STRINGS = {
	ENTRY0 ='',
	ENTRY1 = GetString(SI_INSTANCEDISPLAYTYPE7), -- Delve
	ENTRY2 = GetString(SI_INSTANCEDISPLAYTYPE6), -- Public Dungeon
	ENTRY3 = GetString(SI_INSTANCEDISPLAYTYPE8), -- Housing
	ENTRY4 = GetString(SI_INSTANCEDISPLAYTYPE2), -- Dungeon
	ENTRY5 = GetString(SI_INSTANCEDISPLAYTYPE3), -- Trial
	ENTRY7 = GetString(SI_TELE_UI_TOGGLE_GROUP_ARENAS), -- Group Arenas
	ENTRY8 = GetString(SI_TELE_UI_TOGGLE_ARENAS), -- Solo Arenas
	ENTRY9 = GetString(SI_CHAT_CHANNEL_NAME_ZONE), -- Zone

	ENTRY10 = GetString(SI_TELE_KEYBINDING_TOGGLE_MAIN_ACTIVE_QUESTS), -- Active quests
	ENTRY11 = GetString(SI_TELE_KEYBINDING_TOGGLE_MAIN_RELATED_ITEMS), -- "Treasure & survey maps & leads"

	ENTRY12 = GetString(SI_INSTANCEDISPLAYTYPE5), -- Group
	ENTRY13 = GetString(SI_TELE_UI_SUBMENU_FAVORITES), -- Favorites
	ENTRY14 = GetString(SI_ANTIQUITY_SCRYABLE_CURRENT_ZONE_SUBCATEGORY), -- Current Zone
	ENTRY15 = GetString(SI_GAMEPAD_CAMPAIGN_BROWSER_TOOLTIP_FRIENDS), -- Friends
	ENTRY16 = GetString(SI_GAMEPAD_WORLD_MAP_TOOLTIP_CATEGORY_PLAYERS), -- Players
}

local function getHeaderString(headerType, headerIndex)
	headerIndex = headerIndex or 0
	return HEADER_STRINGS[headerType .. headerIndex]
end

---------------------------------------------------------------------------------------------------------------
-- Entry Data
---------------------------------------------------------------------------------------------------------------
local function isFavoritePlayer(displayName)
	local savedVaars = BMU.savedVarsServ.favoriteListPlayers

	for k, v in pairs(savedVaars) do
		local fName = type(k) == 'number' and v or k

		if displayName == fName then
			return true
		end
	end

end
local function isFavoriteZone(zoneId)
	local savedVaars = BMU.savedVarsServ.favoriteListZones

	for k, v in pairs(savedVaars) do
		local fZoneId = type(v) == 'number' and v or k

		if fZoneId == zoneId then
			return true
		end
	end

end

local function getIsFavorite(data)
	if isFavoritePlayer(data.displayName) then
		return true
	elseif isFavoriteZone(data.zoneId) then
		return true
	end
	return false
end

local function getHasMissingSetItems(data)
	local numUnlocked, numTota = BMU.getNumSetCollectionProgressPieces(data.zoneId, data.category, data.parentZoneId)
	if (numUnlocked and numTota) then
		return ((numTota-numUnlocked) > 0)
	end
end

local function discovery(total, discovered)
	if not total then return nil end
	return total ~= discovered
end

local function discovery(total, discovered)
	if not total then return nil end
	return total ~= discovered
end

---------------------------------------------------------------------------------------------------------------
--
---------------------------------------------------------------------------------------------------------------
local Entry_Class = ZO_GamepadEntryData:Subclass()

function Entry_Class:Initialize(entryData)
	zo_mixin(self,  entryData)

	local text = self:GetFormattedName()
	
	icon = self:GetIcon()
	if icon ~= nil then
	--	self.icon = icon
	end
	
--	ZO_GamepadEntryData.Initialize(self, text, icon, selectedIcon, highlight, isNew)
	ZO_GamepadEntryData.Initialize(self, text)

	self:AddSubLabel(self:GetSubLabel())
	self:SetAlphaChangeOnSelection(true)
end

function Entry_Class:UpdatePayerCount()
	local numberPlayers = self.numberPlayers
	if numberPlayers then
		numberPlayers = numberPlayers:gsub('%((%d+)%)', '%1')
		self:SetStackCount(tonumber(numberPlayers))
	end
end

function Entry_Class:GetFormattedName()
	local name = self.textColorZoneName .. self.zoneName

	if (CURRENT_CATEGORY_TYPE == CATEGORY_TYPE_DISPLAYED and self.zoneIndex == GetCurrentMapZoneIndex()) and not self.isDungeon then
		-- Set entries in the current displayed map as displayName
		name = self.textColorDisplayName .. self.displayName
	end

	return name
end

function Entry_Class:GetIcon() -- This may no longer be needed.
--[[
	-- overland zones have category == 9
	local icon = BMU.textures.wayshrineBtn

	if self.category ~= nil and self.category ~= 0 then
		if		self.category == 1 then icon = BMU.textures.delvesBtn -- set Delve
		elseif	self.category == 2 then icon = BMU.textures.publicDungeonBtn -- set Public Dungeon
		elseif	self.category == 3 then icon = BMU.textures.houseBtn -- set House
		elseif	self.category == 4 then icon = BMU.textures.groupDungeonBtn -- 4 men Group Dungeons
		elseif	self.category == 5 then icon = BMU.textures.raidDungeonBtn -- 12 men Group Dungeons
		elseif	self.category == 6 then icon = BMU.textures.groupZonesBtn -- Other Group Zones (Dungeons in Craglorn)
		elseif	self.category == 7 then icon = BMU.textures.groupDungeonBtn -- Group Arenas
		elseif	self.category == 8 then icon = BMU.textures.soloArenaBtn -- Solo Arenas
		end
	end

	return icon
	]]
	return self.icon
end

function Entry_Class:GetSortOrder()
	return BMU.sortingByCategory[self.category] + MIN_CATEGORY_SORT
end

function Entry_Class:GetSubLabel()
	return self.parentZoneName or nil
end

function Entry_Class:UpdateIcon(icon)
	self:ClearIcons()
	self:AddIcon(icon)
	
	self.icon = icon
end

function Entry_Class:UpdateEntryData(mostUsed)
	local icon
	self.parentZoneId, self.parentZoneName, self.mapId, icon, self.pinDesc, self.pinInfo = IJA_BMU_GAMEPAD_PLUGIN.GetMapInfo(self)

--	self.parentZoneId, self.parentMapId, self.parentZoneName, self.icon, self.pinDesc, self.pinInfo = getMapInfo(self)

	self.unitTag = self:GetGroupUnitTag()
	self:UpdateIcon(icon)

	-- Lets add some additional data to use for subcategory sorting.
	if self.houseId then
		self.isPrimaryResidence = IsPrimaryHouse(self.houseId)
	end

	self.status					= self.status or 0
	self.isFavorite				= getIsFavorite(self)

	local timesUsed = BMU.savedVarsAcc.portCounterPerZone[self.zoneId] or 0
	self.mostUsed = timesUsed > mostUsed
	
	self:UpdatePayerCount()
end

function Entry_Class:UpdateSortOrder()
	local sortOrder = 9

	if self.unitTag then
		if self.isLeader then
			sortOrder = SORT_ORDER_GROUP_LEADER
		else
			sortOrder = SORT_ORDER_GROUP
		end
	elseif self.isFavorite then
		sortOrder = SORT_ORDER_FAVORITE
	elseif self.mostUsed then
		sortOrder = SORT_ORDER_FAVORITE
	elseif self.isPrimaryResidence then
		sortOrder = SORT_ORDER_FAVORITE
	else
		sortOrder = self:GetSortOrder()
	end

	self.sortOrder = sortOrder


	-- self.sourceIndexLeading
end

function Entry_Class:Update(mostUsedModifier)
	self:UpdateEntryData(mostUsedModifier)
	self:UpdateSortOrder()
end

function Entry_Class:GetGroupUnitTag()
	if IsUnitGrouped("player") then
		for i = 1, GROUP_SIZE_MAX do
			local unitTag = GetGroupUnitTagByIndex(i)
			local displayName = GetUnitDisplayName(unitTag)
			if displayName == self.displayName then
				return unitTag
			end
		end
	end
end

do
	local headers = {
		[1] = getHeaderString('ENTRY', 1),
		[2] = getHeaderString('ENTRY', 2),
		[3] = getHeaderString('ENTRY', 3),
		[4] = GetString(SI_TELE_UI_TOGGLE_GROUP_DUNGEONS),
		[5] = GetString(SI_TELE_UI_TOGGLE_TRIALS),
		[6] = getHeaderString('ENTRY', 2),
		[7] = GetString(SI_TELE_UI_TOGGLE_GROUP_ARENAS),
		[8] = GetString(SI_TELE_UI_TOGGLE_ARENAS),
		[9] = getHeaderString('ENTRY', 9)
	}

	function Entry_Class:GetHeader()
		local header = getHeaderString('ENTRY', 9)
		-- overland zones have category == 9

		if self.prio and self.prio == 0 then
			header = ''
		elseif self.unitTag then
			header = GetString(SI_MAPFILTER9) -- "Group Members"
		elseif self.isFavorite then
			header = getHeaderString('ENTRY', 13)
		else

			if self.category ~= nil and self.category ~= 0 then
				header = headers[self.category]
			end
		end

		return header
	end
end

-----
function Entry_Class:Ping()
	if self.unitTag then
		local delay, xLoc, yLoc, isInCurrentMap = self:GetUnitMapPosition()

		if not isInCurrentMap then
			ZO_WorldMap_SetMapByIndex(self.mapIndex)
		end

		zo_callLater(function()
			PingMap(MAP_PIN_TYPE_RALLY_POINT, MAP_TYPE_LOCATION_CENTERED, xLoc, yLoc)
		end, delay)

	elseif self.pinInfo then
		local xLoc, yLoc = self:GetPinMapPosition()
		PingMap(MAP_PIN_TYPE_RALLY_POINT, MAP_TYPE_LOCATION_CENTERED, xLoc, yLoc)
	end
end

function Entry_Class:GetUnitMapPosition()
	local xLoc, yLoc, _, isInCurrentMap = GetMapPlayerPosition(self.unitTag)
	local delay = isInCurrentMap and 0 or 100

	return delay, xLoc, yLoc
end

function Entry_Class:GetPinMapPosition()
	local xLoc, yLoc = GetPOIMapInfo(self.pinInfo.poiZoneIndex, self.pinInfo.poiIndex)

	return xLoc, yLoc
end

--[[
function Entry_Class:SetMapToEntry()
	local mapId = self.mapId or self.parentMapId
	if mapId then
		setMapById(mapId)
	end
end
]]
--	--
function Entry_Class:Get()
end

---------------------------------------------------------------------------------------------------------------
--
---------------------------------------------------------------------------------------------------------------
local Entry_Class_Zone = Entry_Class:Subclass()

---------------------------------------------------------------------------------------------------------------
--
---------------------------------------------------------------------------------------------------------------
local Entry_Class_Dungeon = Entry_Class:Subclass()

function Entry_Class_Dungeon:GetSortOrder()
	return BMU.sortingByCategory[self.category]
end

do
	local headers = {
		[1] = getHeaderString('ENTRY', 1),
		[2] = getHeaderString('ENTRY', 2),
		[4] = GetString(SI_TELE_UI_TOGGLE_GROUP_DUNGEONS),
		[5] = GetString(SI_TELE_UI_TOGGLE_TRIALS),
		[6] = getHeaderString('ENTRY', 2),
		[7] = GetString(SI_TELE_UI_TOGGLE_GROUP_ARENAS),
		[8] = GetString(SI_TELE_UI_TOGGLE_ARENAS),
		[9] = getHeaderString('ENTRY', 9)
	}

	function Entry_Class_Dungeon:GetHeader()
		if self.category ~= nil and self.category ~= 0 then
			local header = headers[self.category]

			return header
		end
	end
end

---------------------------------------------------------------------------------------------------------------
--
---------------------------------------------------------------------------------------------------------------
local Entry_Class_Player = Entry_Class:Subclass()

function Entry_Class_Player:GetFormattedName()
	return self.textColorDisplayName .. self.displayName
end

function Entry_Class_Player:GetIcon()
--	local icon = BMU.textures.wayshrineBtndd
	local icon
	if self.unitTag then
		if IsActiveWorldBattleground() then
			local battlegroundAlliance = GetUnitBattlegroundAlliance(self.unitTag)
			if battlegroundAlliance ~= BATTLEGROUND_ALLIANCE_NONE then
				icon = GetBattlegroundTeamIcon(battlegroundAlliance)
			end
		else
			local selectedRole = GetGroupMemberSelectedRole(self.unitTag)
			if selectedRole ~= LFG_ROLE_INVALID then
				icon = GetRoleIcon(selectedRole)
			end
		end
		
		self:ClearIcons()
		self:AddIcon(icon)
	else
	--	icon = Entry_Class.GetIcon(self)
	end

	return icon
end

function Entry_Class_Player:UpdateIcon(icon)
	if self.unitTag then
		if IsActiveWorldBattleground() then
			local battlegroundAlliance = GetUnitBattlegroundAlliance(self.unitTag)
			if battlegroundAlliance ~= BATTLEGROUND_ALLIANCE_NONE then
				icon = GetBattlegroundTeamIcon(battlegroundAlliance)
			end
		else
			local selectedRole = GetGroupMemberSelectedRole(self.unitTag)
			if selectedRole ~= LFG_ROLE_INVALID then
				icon = GetRoleIcon(selectedRole)
			end
		end
	end
	
	self:ClearIcons()
	self:AddIcon(icon)
end

function Entry_Class_Player:GetSubLabel()
	return self.zoneName
end

---------------------------------------------------------------------------------------------------------------
--
---------------------------------------------------------------------------------------------------------------
local Entry_Class_House = Entry_Class:Subclass()

function Entry_Class_House:GetFormattedName()
	name = self.houseNameFormatted or self.zoneName
	return self.textColorZoneName .. name
end

local Entry_Class_Items = Entry_Class:Subclass()

do
	local headers = {
		[1] = GetString(SI_ANTIQUITY_LEAD_TOOLTIP_TAG),
		[2] = GetString(SI_SPECIALIZEDITEMTYPE101),
		[3] = GetString(SI_SPECIALIZEDITEMTYPE100),
		[4] = GetString(SI_ITEM_SETS_BOOK_SEARCH_NO_MATCHES),
	}

	function Entry_Class_Items:GetHeader()
		local header = headers[self.sortOrder]

		return header
	end
end

---------------------------------------------------------------------------------------------------------------
--
---------------------------------------------------------------------------------------------------------------
function Entry_Class_Items:UpdateSortOrder()
	if self.countRelatedItems == 0 then return end
	local newSortOrder = 0
	local sortOrder = 4

	for k, itemData in pairs(self.relatedItems) do
		if itemData.antiquityId then
			sortOrder = 1
			break
		end
		local itemType, specializedItemType = GetItemType(itemData.bagId, itemData.slotIndex)
		if specializedItemType == SPECIALIZED_ITEMTYPE_TROPHY_SURVEY_REPORT then
			newSortOrder = 2
		end
		if specializedItemType == SPECIALIZED_ITEMTYPE_TROPHY_TREASURE_MAP then
			newSortOrder = 3
		end

		if sortOrder > newSortOrder then
			sortOrder = newSortOrder
		end
	end

	if self.status == 0 then
		sortOrder = 4
	end

	self.sortOrder = sortOrder
end

---------------------------------------------------------------------------------------------------------------
--
---------------------------------------------------------------------------------------------------------------
local Entry_Class_Quests = Entry_Class:Subclass()

function Entry_Class_Quests:GetSortOrder()
	-- prio (1: tracked quest, 2: related quests (with players), 3: unrelated quests (without players), 4: zoneless quests)
	return self.prio
end

function Entry_Class_Quests:UpdateSortOrder()
	self.sortOrder = self:GetSortOrder()
end

do
	local headers = {
		[1] = GetString(SI_RESTYLE_SHEET_HEADER), -- 'Active' Tracked
		[2] = 'Untracked', -- 'Untracked'
		[3] = GetString(SI_ITEM_SETS_BOOK_SEARCH_NO_MATCHES), -- unrelated untracked
		[4] = 'Zoneless', -- 'Zoneless'
	}

	function Entry_Class_Quests:GetHeader()
		local header = ''
		if self.prio then
			header = headers[self.prio]
		end

		return header
	end
end

---------------------------------------------------------------------------------------------------------------
--
---------------------------------------------------------------------------------------------------------------
local Entry_Class_BMU = Entry_Class:Subclass()

function Entry_Class_BMU:GetFormattedName()
	local name = self.displayName
	return name
end

function Entry_Class_BMU:GetSubLabel()
	return self.zoneName
end

function Entry_Class_BMU:IsBMUGuild()
	for _, guildId in pairs(BMU.var.BMUGuilds[GetWorldName()]) do
		if guildId == self.guildId then
			return true
		end
	end
end

function Entry_Class_BMU:GetSortOrder()
	local sortOrder = self:IsBMUGuild() and 0 or 1

	return sortOrder
end

function Entry_Class_BMU:UpdateEntryData(mostUsed)
end

do
	local headers = {
		[true] = "-- OFFICIAL GUILDS --",
		[false] = "-- PARTNER GUILDS --",
	}

	function Entry_Class_BMU:GetHeader()
		local header = headers[self.sortOrder == 0]

		return header
	end
end

---------------------------------------------------------------------------------------------------------------
--
---------------------------------------------------------------------------------------------------------------

BMU_Gamepad_EntryData = {}
function BMU_Gamepad_EntryData:CreateNewEntry(data, sameZone)
	CURRENT_CATEGORY_TYPE = data.categoryType

	if data.categoryType == CATEGORY_TYPE_ITEMS then
		return Entry_Class_Items:New(data)
	elseif data.categoryType == CATEGORY_TYPE_QUESTS then
		return Entry_Class_Quests:New(data)
	elseif data.categoryType == CATEGORY_TYPE_DISPLAYED and data.displayName ~= '' then
		return Entry_Class_Player:New(data)
	elseif data.categoryType == CATEGORY_TYPE_BMU then
		return Entry_Class_BMU:New(data)
	else
		if data.houseId and (data.zoneId ~= data.parentZoneId) then
			return Entry_Class_House:New(data)
		elseif data.isDungeon then
			return Entry_Class_Dungeon:New(data)
		elseif sameZone and data.displayName ~= '' then
			return Entry_Class_Player:New(data)
		end

		return Entry_Class_Zone:New(data)
	end
end

-- not in use at this time. Was a thought to make a list containing all zones and players separately.
function BMU_Gamepad_EntryData:CreateMultiEntry(data, dataTable)
	if data.houseId then
		table.insert(dataTable, Entry_Class_House:New(data))
	elseif data.isDungeon then
		table.insert(dataTable, Entry_Class_Dungeon:New(data))
	elseif data.displayName ~= '' then
		-- create player entry
		table.insert(dataTable, Entry_Class_Player:New(data))
	end

	if data.zoneId then
		-- create zone entry
		local entry = Entry_Class_Zone:New(data)
		table.insert(dataTable, entry)
	end
end




--[[
local missingPinInfo = { -- poiIndex
	[913] = 9, -- The Mage's Staff/Spellscar
	[469] = 35 -- Tomb of Apostates
}

function Entry_Class:JumpToPin()
	local poiIndex = missingPinInfo[self.zoneId]
	
	
	local function findPinFunction()
		local majorIndex = GetCurrentMapZoneIndex()
		if majorIndex and poiIndex then
			local pin = self:FindPin(majorIndex, poiIndex)
			
			if pin then
				return pin
			end
		end
	--	d( self:FindPinFromZoneName(majorIndex))
		return self:FindPinFromZoneName(majorIndex)
	end

	ZO_WorldMap_GetPanAndZoom():JumpToPinWhenAvailable(findPinFunction)
end

function Entry_Class:FindPinFromZoneName(majorIndex)
	local result, match

	local zoneName = self.zoneName:lower()
	for i = 1, GetNumPOIs(majorIndex) do 
        local poiName, _, poiStartDesc, poiFinishedDesc = GetPOIInfo(majorIndex, i)
		if poiName ~= '' and not poiName:match(wayShrineString) then
		
			local score = compareNames(poiName:lower(), zoneName)

		--	d( 'poiName', poiName)

			if score then
				if not match or score < match then
					match = score
					result = i
				end
			end
		end
    end
	
		d( result)
	if match then
	--	local poiPinType, icon = select(e, GetPOIMapInfo(majorIndex, result))
		return self:FindPin(majorIndex, result)
	end
	return false
end

function Entry_Class:FindPin(majorIndex, keyIndex)
    local lookupTable = ZO_WorldMap_GetPinManager().m_keyToPinMapping['poi']
    local keys
    if majorIndex then
        keys = lookupTable[majorIndex]
    end

    if keys then
        local pinKey
        if keyIndex then
            pinKey = keys[keyIndex]
        end

        if pinKey then
            return ZO_WorldMap_GetPinManager():GetActiveObject(pinKey)
        end
    end
end
]]
