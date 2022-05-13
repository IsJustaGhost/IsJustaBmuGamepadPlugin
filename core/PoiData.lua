---------------------------------------------------------------------------------------------------------------
-- POI
---------------------------------------------------------------------------------------------------------------
local POI_DATA = {}
local MAP_DATA_BY_ZONE_ID = {}
local MAX_NUM_ZONE_INDEXS = GetNumZones()
local CLEAN_TEST = 2 -- Some dummy zone called "Clean Test"
local wayShrineString = GetString(SI_DEATH_PROMPT_WAYSHRINE)

local missingPinInfo = {
	[469] = { -- Tomb of Apostates
		['pinInfo'] = {
			["poiIndex"] = 35,
			["poiZoneIndex"] = 11,
		},
		["parentZoneId"] = 58,
	},
	[913] = { -- The Mage's Staff/Spellscar
		['pinInfo'] = {
			["poiIndex"] = 9,
			["poiZoneIndex"] = 500,
		},
		["parentZoneId"] = 888,
	},
	[915] = { -- Skyreach Temple. Located inside Loth'Na Caverns
		['pinInfo'] = {
			["poiIndex"] = 18,
			["poiZoneIndex"] = 500,
		},
		["parentZoneId"] = 888,
	},
	[1080] = { -- Dungeon: Frostvault can get mistaken as Frostvault Chasm
		['pinInfo'] = {
			["poiIndex"] = 60,
			["poiZoneIndex"] = 15,
		},
		["parentZoneId"] = 101,
	},
	[1125] = { -- Frostvault Chasm to be safe.
		["pinInfo"] = {
			["poiIndex"] = 61,
			["poiZoneIndex"] = 15,
		},
		["parentZoneId"] = 101,
	},
}

local excludedZoneIndex = {
	[346] = true, -- Imperial City -- needed to prevent Imperial City Prison form using Imperial City as poi reference
	[373] = true, -- Imperial Sewers -- needed to prevent White-Gold Tower form using Imperial Sewers as poi reference
}

local invalidMapContent = {
	[MAP_CONTENT_BATTLEGROUND] = true,
	[MAP_CONTENT_AVA] = true,
}

local parentZoneIdModifier = {
	[1027] = 1027, -- Artaeum
	[1283] = 1283, -- The Shambles
}

local function createSinglePOIPin(zoneIndex, poiIndex)
	local objectiveName, objectiveLevel, startDescription, finishedDescription = GetPOIInfo(zoneIndex, poiIndex)

	if objectiveName ~= '' and not objectiveName:match(wayShrineString) then
		local zoneId = GetZoneId(zoneIndex)
		local zoneName = GetZoneNameById(zoneId)
		zoneName = zoneName:lower()

		local zoneData = POI_DATA[zoneIndex] or {}
		local xLoc, zLoc, poiPinType, icon, isShownInCurrentMap, linkedCollectibleIsLocked, isDiscovered, isNearby = GetPOIMapInfo(zoneIndex, poiIndex)

		local pinDesc
		if HasCompletedFastTravelNodePOI(zoneIndex) then
			pinDesc = finishedDescription
		else
			pinDesc = startDescription
		end

		local entry = {
			pinInfo = {
				poiIndex = poiIndex,
				poiZoneIndex = zoneIndex, -- the parent zoneIndex
				name = objectiveName,
				startDescription = startDescription,
				finishedDescription = finishedDescription,
			},
			icon = icon,
			parentZoneId = zoneId,
			mapId = GetMapIdByZoneId(zoneId),
			parentZoneName = BMU.formatName(GetZoneNameById(zoneId)),
		}

		objectiveName = ZO_CachedStrFormat(SI_ZONE_NAME, objectiveName):lower()

		if zoneData[objectiveName] and objectiveName:find(' i$') ~= nil then
			-- we need to add an 'i' to darkshade caverns ii
			objectiveName = objectiveName .. 'i'
		end

		local entryData = zoneData[objectiveName] or {}
		table.insert(entryData, entry)
		zoneData[objectiveName] = entryData

		POI_DATA[zoneIndex] = zoneData
	end
end

-----------------
local function getParentZoneId(zoneId)
	local parentZoneId = parentZoneIdModifier[zoneId]

	if not parentZoneId then
		parentZoneId = GetParentZoneId(zoneId)
	end

	return parentZoneId
end

local function compareNames(objectiveName, zoneName)
	local reverseSt = objectiveName:gsub('^(%S+) (.*)$', '%2 %1')
	local reverseZone = zoneName:gsub('^(%S+) (.*)$', '%2 %1')
	if objectiveName:find(zoneName, 1, true) ~= nil
		or reverseSt:find(zoneName, 1, true) ~= nil
		or reverseZone:find(objectiveName, 1, true) ~= nil
		or zoneName:match('^' .. objectiveName .. '$') ~= nil then

		return math.abs(#objectiveName - #zoneName)
	end
end

local function getPinInfoByName(zoneName)
	local result, match

	for zoneIndex, zoneData in pairs(POI_DATA) do
		for objectiveName, pinInfo in pairs(zoneData) do
			local score = compareNames(objectiveName, zoneName)

			if score then
				if not match or score < match then
					match = score
					result = pinInfo
				end
			end
		end
	end

	if match then
		return select(2, next(result))
	end
end

-- We use this to create the data for select zones that do not match up dynamically.
local function getPinInfoByZoneId(zoneId)
	local entry = missingPinInfo[zoneId]

	if entry then
		local zoneIndex, poiIndex = entry.pinInfo.poiZoneIndex, entry.pinInfo.poiIndex
		local startDescription, finishedDescription = select(3, GetPOIInfo(zoneIndex, poiIndex))
		local icon = select(4, GetPOIMapInfo(zoneIndex, poiIndex))

		entry.pinInfo.startDescription = startDescription
		entry.pinInfo.finishedDescription = finishedDescription
		
		entry.icon = icon
		entry.mapId = GetMapIdByZoneId(entry.parentZoneId)
		entry.pinDesc = pinDesc
		entry.parentZoneName = GetZoneNameById(entry.parentZoneId)

		return entry
	end
end

local function isValid(zoneName, parentZoneId, mapContentType)
	if zoneName ~= nil then
		return zoneName ~= '' and parentZoneId ~= CLEAN_TEST and not invalidMapContent[mapContentType]
	end

	return false
end

local function validateMapInfo(entry)
	return entry.mapId ~= nil
		and entry.parentZoneId ~= nil
		and entry.parentZoneName ~= nil
	--	and entry.zoneIndex ~= nil
	--	and entry.zoneName ~= nil
	--	and entry.pinInfo ~= nil
	--	and entry.parentMapId ~= 0
end

local function createSingleZoneInfo(zoneIndex)
	-- build zoneInfo and attach poiInfo.
	local zoneId = GetZoneId(zoneIndex)
	local zoneName = GetZoneNameById(zoneId)
	local parentZoneId = getParentZoneId(zoneId)
	local mapContentType = select(3, GetMapInfoById(GetMapIdByZoneId(zoneId)))

	if isValid(zoneName, parentZoneId, mapContentType) then
		local zoneInfo
		if GetMapIndexByZoneId(zoneId) == nil then
			zoneInfo = getPinInfoByZoneId(zoneId) or getPinInfoByName(zoneName:lower())
		end

		local pinDesc
		if zoneInfo then
			-- Use the parentZone associated with the pin.
			parentZoneId = zoneInfo.parentZoneId
			
			if HasCompletedFastTravelNodePOI(zoneIndex) then
				pinDesc = zoneInfo.pinInfo.finishedDescription
			else
				pinDesc = zoneInfo.pinInfo.startDescription
			end
		end

		local entry = zoneInfo or {
			-- If no pinInfo, create default info.
			icon = "/esoui/art/icons/poi/poi_wayshrine_complete.dds",
			mapId = GetMapIdByZoneId(zoneId),
			parentZoneId = parentZoneId,
			parentZoneName = BMU.formatName(GetZoneNameById(parentZoneId)),
		}
		
		entry.pinDesc = pinDesc
		
	--	entry.zoneName = zoneName
	--	entry.zoneIndex = zoneIndex

		if validateMapInfo(entry) then
			MAP_DATA_BY_ZONE_ID[zoneId] = entry
		end
	end
end

-----------------
local function poiBuildFunction(zoneIndex)
	local poiCount = GetNumPOIs(zoneIndex)
	for i = 1, poiCount do
		createSinglePOIPin(zoneIndex, i)
	end
end

local function zoneBuildFunction(zoneIndex)
	createSingleZoneInfo(zoneIndex)
end

-- Iterate zone indexes
local function buildList(buildFunction)
	for zoneIndex = 0, MAX_NUM_ZONE_INDEXS do
		if not excludedZoneIndex[zoneIndex] then
			buildFunction(zoneIndex)
		end
	end
end

-- Build poi list in order to add parent poi info to child zone info.
buildList(poiBuildFunction)
-- Build zone info list.
buildList(zoneBuildFunction)

-- We no longer need
POI_DATA = nil

---@param entry table # Table with non-numeric or non-contiguous keys
---@return number parentZoneId 
---@return string parentZoneName
---@return number mapId
---@return string icon
---@return string pinDesc
---@return table pinInfo
function IJA_BMU_GAMEPAD_PLUGIN:GetMapInfo()	
	if not self.zoneId then return end
	local mapData = MAP_DATA_BY_ZONE_ID[self.zoneId]
	
--	d( '--------- GetMapInfo', mapData)
	if mapData then
		return mapData.parentZoneId, mapData.parentZoneName, mapData.mapId, mapData.icon, mapData.pinDesc, mapData.pinInfo
	end
	
	-- If no mapData then return current info.
	return self.parentZoneId, self.parentZoneName, self.mapId, self.icon
end

