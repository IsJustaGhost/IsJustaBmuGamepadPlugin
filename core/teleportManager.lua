local addon = IJA_BMU_GAMEPAD_PLUGIN

local Entry_Manager = addon.entryManager
local TeleportClass_Shared = addon.telportListSubclass

---------------------------------------------------------------------------------------------------------------
-- 
---------------------------------------------------------------------------------------------------------------
local function getNumberOfPlayers(numberPlayer)
    if type(numberPlayer) ~= 'string' then return end
    local numPlayers = numberPlayer:gsub('%((%d+)%)', '%1')
    
    return tonumber(numPlayers)
end

---------------------------------------------------------------------------------------------------------------
-- Category list
---------------------------------------------------------------------------------------------------------------
local categoryList = TeleportClass_Shared:Subclass()

function categoryList:Initialize(control)
	TeleportClass_Shared.Initialize(self, control)

	self.portalPlayers = {}
	
	self:InitializeCustomTabs()
	self:BuildCategories()

	self.list:SetOnSelectedDataChangedCallback(function()
		local targetData = self.list:GetTargetData()
		if targetData then
			
			self:SetupSelectionDetails(targetData)
			callBMU_Update(targetData)
			self:RefreshKeybind()
		end
	end)

	BMU_GAMEPAD_WORLD_MAP_TELEPORT_CATEGORY_FRAGMENT = ZO_SimpleSceneFragment:New(control)
	BMU_GAMEPAD_WORLD_MAP_TELEPORT_CATEGORY_FRAGMENT:RegisterCallback("StateChange",  function(oldState, newState)
		if newState == SCENE_SHOWING then
			self.list:Activate()
			KEYBIND_STRIP:AddKeybindButtonGroup(self.keybindStripDescriptor)
			self:PerformFullRefresh()
		elseif newState == SCENE_SHOWN then
			self:SetupSelectionDetails()
		elseif newState == SCENE_HIDDEN then
			KEYBIND_STRIP:RemoveKeybindButtonGroup(self.keybindStripDescriptor)
			self.list:Deactivate()
		end
	end)

	self.locations = locations:New(IJA_BMU_TeleportList_Gamepad)
end

function categoryList:InitializeCustomTabs()
	local mapInfo = GAMEPAD_WORLD_MAP_INFO
	local tabBarEntries = mapInfo.tabBarEntries

	local newtab = {
		text = "Teleporter",
		callback = function() mapInfo:SwitchToFragment(BMU_GAMEPAD_WORLD_MAP_TELEPORT_CATEGORY_FRAGMENT, USES_RIGHT_SIDE_CONTENT) end,
	}
	table.insert(tabBarEntries, 1, newtab)

	mapInfo.tabBarEntries = tabBarEntries

	mapInfo.baseHeaderData = {
		tabBarEntries = mapInfo.tabBarEntries
	}

	ZO_GamepadGenericHeader_Refresh(mapInfo.header, mapInfo.baseHeaderData)
	ZO_GamepadGenericHeader_SetActiveTabIndex(mapInfo.header, 1)
end

function categoryList:InitializeKeybindDescriptor()
	function onCategorySelected(categoryData)
		self.locations.categoryData = categoryData
		GAMEPAD_WORLD_MAP_INFO:SwitchToFragment(BMU_GAMEPAD_WORLD_MAP_TELEPORT_LOCATIONS_FRAGMENT, USES_RIGHT_SIDE_CONTENT)
		PlaySound(SOUNDS.MAP_LOCATION_CLICKED)
	end

	self.keybindStripDescriptor =
	{
		alignment = KEYBIND_STRIP_ALIGN_LEFT,
		{ -- select item
			name = GetString(SI_GAMEPAD_SELECT_OPTION),
			keybind = "UI_SHORTCUT_PRIMARY",
			callback = function()
				local targetData = self.list:GetTargetData()

				if targetData then
					onCategorySelected(targetData)
				end
			end,
			enabled = function()
			--	return self.list:GetTargetData() ~= nil
				return #self.portalPlayers > 0
			end,
			visible = function() return true end,
		},
		{ -- select refresh
			name = GetString(SI_OPTIONS_RESET),
			keybind = "UI_SHORTCUT_SECONDARY",
			callback = function()
				local playersZoneIndex = GetUnitZoneIndex("player")
				local playersZoneId = GetZoneId(playersZoneIndex)
				ZO_WorldMap_SetMapByIndex(GetMapIndexByZoneId(playersZoneId))
				
				self:ResetFilters()
				self:PerformFullRefresh()
				PlaySound(SOUNDS.MAP_LOCATION_CLICKED)
			end,
			enabled = function() return true end,
			visible = function() return true end,
		},
        {
            name = GetString(SI_GAMEPAD_OPTIONS_MENU),
            keybind = "UI_SHORTCUT_TERTIARY",
            visible = function()
                return self:HasAnyShownOptions()
            end,
            enabled = function()
                return true
            end,
            callback = function()
                return self:ShowOptionsDialog()
            end,
        },
	}

	ZO_Gamepad_AddBackNavigationKeybindDescriptors(self.keybindStripDescriptor, GAME_NAVIGATION_TYPE_BUTTON, ZO_WorldMapInfo_OnBackPressed)
	ZO_Gamepad_AddListTriggerKeybindDescriptors(self.keybindStripDescriptor, self.list)
end

function categoryList:Refresh()
	local categories = self.categories or {}
	local lastFilterType
	for i, data in ipairs(categories) do
		local visible = data.visible
		if type(visible) == 'function' then
			visible = visible()
		end

		if visible then
			local entryData = ZO_GamepadEntryData:New(data.name, data.icon)

			entryData:SetDataSource(data)
			zo_mixin(entryData, data)
			
			entryData:AddSubLabel(data.foundInZoneName)
			
			if lastFilterType ~= data.filterType then
				lastFilterType = data.filterType
				entryData:SetHeader(getHeaderString('CATEGORY', data.filterType))
				self.list:AddEntry("ZO_GamepadMenuEntryTemplateLowercase42WithHeader", entryData)
			else
				self.list:AddEntry("ZO_GamepadMenuEntryTemplateLowercase42", entryData)
			end
		end
	end
end

local numResults = {}
function categoryList:UpdatePortalPlayers()
	local categoryData = self.list:GetTargetData()
	local portalPlayers = {}
	
	GAMEPAD_WORLD_MAP_LOCATIONS.data.mapData = nil

	numResults = {}

	local teleporterList = TeleporterList.lines or {}
	for k, data in pairs(teleporterList) do
		if data.category and data.category > 0 then
			if not categoryData.categoryFilter or categoryData.categoryFilter(data) then
				
				if categoryData.index > 9 then
					self:CreateMultiEntry(data, dataTable)
				else
					local entry = self:CreateNewEntry(data, categoryData.categoryType)
					table.insert(portalPlayers, entry)
				end
				
				
				local numPlayers = getNumberOfPlayers(data.numberPlayers)
				local zoneIndex = data.zoneIndex or GetZoneIndex(data.zoneId)
				
				if not numResults[zoneIndex] then
					numResults[zoneIndex] = numPlayers
				end
			
			end
		end
	end

	self.portalPlayers = portalPlayers
	
    GAMEPAD_WORLD_MAP_LOCATIONS:BuildLocationList()
end

-- Dialogue options
function categoryList:BuildOptionsList()
	local groupId = self:AddOptionTemplateGroup(GetString(SI_GAMEPAD_CRAFTING_OPTIONS_FILTERS))

	local categoryData = self.list:GetTargetData()
	
	if categoryData == nil then return end
	local dropdownData = {}
	
	local function callback(data)
		self:SetCategoryFilter(2, data.filterName, data.filterIndex, data.filterSourceIndex)
	end
			
	table.insert(dropdownData, { -- All
		filterName = GetString(SI_GUILD_HISTORY_SUBCATEGORY_ALL),
		filterIndex = 0,
		callback = callback,
	})

	table.insert(dropdownData, { -- Group
		filterName = BMU.var.color.colOrange .. GetString(SI_TELE_UI_FILTER_GROUP),
		filterIndex = 7,
		filterSourceIndex = TELEPORTER_SOURCE_INDEX_GROUP,
		callback = callback,
	})

	table.insert(dropdownData, { -- Friends
		filterName = BMU.var.color.colGreen .. GetString(SI_TELE_UI_FILTER_FRIENDS),
		filterIndex = 7,
		filterSourceIndex = TELEPORTER_SOURCE_INDEX_FRIEND,
		callback = callback,
	})

	for guildIndex = 1, GetNumGuilds() do -- Guilds
		local guildId = GetGuildId(guildIndex)
		
		table.insert(dropdownData, { 
			filterName = BMU.var.color.colWhite .. GetGuildName(guildId),
			filterIndex = 7,
			filterSourceIndex = TELEPORTER_SOURCE_INDEX_FRIEND + guildIndex,
			callback = callback,
		})
	end
	
	self:AddOptionTemplate(groupId, function() return self:BuildDropdown(SI_GAMEPAD_CRAFTING_OPTIONS_FILTERS, label, dropdownData, icon) end, conditionFunction)
	
	if categoryData.categoryType == CATEGORY_TYPE_ITEMS then
		self:BuildItemsOptionsList(groupId)
	end
	if categoryData.categoryType == CATEGORY_TYPE_DUNGEON then
		self:BuildDungeonsOptionsList(groupId)
	end
end

function categoryList:BuildItemsOptionsList(groupId)
	dropdownData = {
		{
			filterName = GetString(SI_TELE_UI_TOGGLE_SURVEY_MAP),
			callback = function(checked)
				setTeleporterSetting('displaySurveyMaps', checked)
				self:PerformFullRefresh()
			end,
			checked = BMU.savedVarsChar.displaySurveyMaps,
		},
		{
			filterName = GetString(SI_TELE_UI_TOGGLE_TREASURE_MAP),
			callback = function(checked)
				setTeleporterSetting('displayTreasureMaps', checked)
				self:PerformFullRefresh()
			end,
			checked = BMU.savedVarsChar.displayTreasureMaps,
		},
		{
			filterName = GetString(SI_TELE_UI_TOGGLE_LEADS_MAP),
			callback = function(checked)
				setTeleporterSetting('displayLeads', checked)
				self:PerformFullRefresh()
			end,
			checked = BMU.savedVarsChar.displayLeads,
		},
		{
			filterName = GetString(SI_TELE_UI_TOGGLE_INCLUDE_BANK_MAP),
			callback = function(checked)
				setTeleporterSetting('scanBankForMaps', checked)
				self:PerformFullRefresh()
			end,
			checked = BMU.savedVarsChar.scanBankForMaps,
		},
	}
	
	self:AddOptionTemplate(groupId, function() return self:BuildDropdown(SI_GAMEPAD_CRAFTING_OPTIONS_FILTERS, label, dropdownData, icon) end, conditionFunction)
end

function categoryList:BuildDungeonsOptionsList(groupId)
	dropdownData = {
		{
			filterName = GetString(SI_TELE_UI_TOGGLE_ARENAS),
			callback = function(checked)
				setTeleporterSetting('df_showArenas', checked)
				self:PerformFullRefresh()
			end,
			checked = BMU.savedVarsChar.df_showArenas,
		},
		{
			filterName = GetString(SI_TELE_UI_TOGGLE_GROUP_ARENAS),
			callback = function(checked)
				setTeleporterSetting('df_showGroupArenas', checked)
				self:PerformFullRefresh()
			end,
			checked = BMU.savedVarsChar.df_showGroupArenas,
		},
		{
			filterName = GetString(SI_TELE_UI_TOGGLE_TRIALS),
			callback = function(checked)
				setTeleporterSetting('df_showTrials', checked)
				self:PerformFullRefresh()
			end,
			checked = BMU.savedVarsChar.df_showTrials,
		},
		{
			filterName = GetString(SI_TELE_UI_TOGGLE_GROUP_DUNGEONS),
			callback = function(checked)
				setTeleporterSetting('df_showDungeons', checked)
				self:PerformFullRefresh()
			end,
			checked = BMU.savedVarsChar.df_showDungeons,
		},
	}
	
	self:AddOptionTemplate(groupId, function() return self:BuildDropdown(SI_GAMEPAD_CRAFTING_OPTIONS_FILTERS, label, dropdownData, icon) end, conditionFunction)
end

---------------------------------------------------------------------------------------------------------------
-- Handle category list
---------------------------------------------------------------------------------------------------------------
function categoryList:BuildCategories()
	local categories = {
		{ -- Show Group
			filterType = 0,
			categoryType = CATEGORY_TYPE_GROUP,
			name = GetString(SI_MAIN_MENU_GROUP),
			icon = "/esoui/art/mainmenu/menubar_group_up.dds",
			index = 0,
			enabled = isEnabled_Default,
			visible = function() return IsUnitGrouped('player') end,
			createList = 'createTable', -- refresh BMU data
			categoryFilter = categoryFilter_Group,
			tooltipData = {},
		},
		{ -- Show all
			filterType = 0,
			categoryType = CATEGORY_TYPE_ALL,
			name = GetString(SI_GUILD_HISTORY_SUBCATEGORY_ALL),
			index = 0,
			icon = BMU.textures.refreshBtn,
			enabled = isEnabled_Default,
			visible = true,
			createList = 'createTable', -- refresh BMU data
			tooltipData = {},
			filters = CATEGORY_FILTERS_ALL
		},
		{ -- current map zone only
			filterType = 0,
			categoryType = CATEGORY_TYPE_DISPLAYED,
			name = GetString(SI_TELE_UI_BTN_CURRENT_ZONE),
			icon = BMU.textures.currentZoneBtn,
		--	index = 1,
			index = 8,
			enabled = true,
			visible = true,
			createList = 'createTable',
		},
		{ -- personal homes
			filterType = 0,
			categoryType = CATEGORY_TYPE_ALL,
			name = GetString(SI_TELE_UI_BTN_PORT_TO_OWN_HOUSE),
			icon = BMU.textures.houseBtn,
			index = 0,
			enabled = true,
			visible = true,
			createList = 'createTableHouses',
		},
		{ -- show quests
			filterType = 0,
			categoryType = CATEGORY_TYPE_QUESTS,
			name = GetString(SI_TELE_UI_BTN_RELATED_QUESTS),
			icon = BMU.textures.questBtn,
			index = 9,
			enabled = true,
			visible = true,
			createList = 'createTable',
		},
		{ -- "Treasure & survey maps & leads"
			filterType = 0,
			categoryType = CATEGORY_TYPE_ITEMS,
			name = GetString(SI_TELE_KEYBINDING_TOGGLE_MAIN_RELATED_ITEMS),
			icon = BMU.textures.relatedItemsBtn,
			index = 4,
			enabled = isEnabled_Default,
			visible = true,
			createList = 'createTable', -- refresh BMU data
			filters = CATEGORY_FILTERS_MAPS
		},
		{ -- dungeon finder
			filterType = 1,
			categoryType = CATEGORY_TYPE_DUNGEON,
			name = GetString(SI_TELE_UI_BTN_DUNGEON_FINDER),
			icon = BMU.textures.groupDungeonBtn,
			index = 0,
			enabled = true,
			visible = true,
			createList = 'createTableDungeons',
			filters = CATEGORY_FILTERS_DUNGEONS
		},
		{ -- Delves and open Dungeons
			filterType = 2,
			categoryType = CATEGORY_TYPE_DUNGEON,
			name = 'Delves and open Dungeons', -- only Delves and open Dungeons (in your own Zone or globally)
			icon = BMU.textures.groupDungeonBtn,
			index = 5,
			enabled = isEnabled_Default,
			visible = true,
			createList = 'createTable', -- refresh BMU data
		},
		{ -- show BMU guilds
			filterType = 3,
			categoryType = CATEGORY_TYPE_ALL,
			name = GetString(SI_TELE_UI_BTN_GUILD_BMU),
			icon = BMU.textures.guildBtn,
			index = 0,
			enabled = true,
			visible = true,
			createList = 'createTableGuilds',
		},
	}

	local ptfCategory = { -- show port to friends
		filterType = 3,
		categoryType = CATEGORY_TYPE_ALL,
		name = GetString(SI_TELE_UI_BTN_PTF_INTEGRATION),
		icon = BMU.textures.ptfHouseBtn,
		index = 0,
		enabled = isEnabled_PTF,
		visible = true,
		createList = 'createTablePTF',
	}

	if PortToFriend then
		table.insert(categories, ptfCategory)
	end

	self.categories = categories
end


addon.categoryList_subclass = categoryList
