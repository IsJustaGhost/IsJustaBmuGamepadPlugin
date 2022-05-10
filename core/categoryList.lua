local addon = IJA_BMU_GAMEPAD_PLUGIN
local TeleportClass_Shared = addon.subclassTable.list_Shared

local CATEGORY_TYPE_GROUP		= 0
local CATEGORY_TYPE_ALL			= 1
local CATEGORY_TYPE_OTHER		= 2
local CATEGORY_TYPE_QUESTS		= 3
local CATEGORY_TYPE_ITEMS		= 4
local CATEGORY_TYPE_DUNGEON		= 5
local CATEGORY_TYPE_DISPLAYED	= 6
local CATEGORY_TYPE_BMU			= 7
local CATEGORY_TYPE_DELVE		= 8
local CATEGORY_TYPE_TEST		= 9

local FILTER_DEFAULTS =  {
	{ -- Show Group
		name = GetString(SI_MAIN_MENU_GROUP),
		index = 0,
	},
	{ -- Show all
		name = GetString(SI_GUILD_HISTORY_SUBCATEGORY_ALL),
		index = 0,
	},
	{ -- current map zone only
		name = GetString(SI_TELE_UI_BTN_CURRENT_ZONE),
		index = 8,
	},
	{ -- personal homes
		name = GetString(SI_TELE_UI_BTN_PORT_TO_OWN_HOUSE),
		index = 0,
	},
	{ -- show quests
		name = GetString(SI_TELE_UI_BTN_RELATED_QUESTS),
		index = 9,
	},
	{ -- "Treasure & survey maps & leads"
		name = GetString(SI_TELE_KEYBINDING_TOGGLE_MAIN_RELATED_ITEMS),
		index = 4,
	},
	{ -- dungeon finder
		name = GetString(SI_TELE_UI_BTN_DUNGEON_FINDER),
		index = 0,
	},
	{ -- Delves and open Dungeons
		name = GetString(SI_BMU_GAMEPAD_CATEGORY_DELVES), -- only Delves and open Dungeons (in your own Zone or globally)
		index = 5,
	},
	{ -- show BMU guilds
		name = GetString(SI_TELE_UI_BTN_GUILD_BMU),
		index = 0,
	},
}

local function resetMapPosition()
	SetMapToPlayerLocation()

	local navigateIn = true
	CALLBACK_MANAGER:FireCallbacks("OnWorldMapChanged", navigateIn)
end

local function categoryFilter_Group(data)
	return data.sourceIndexLeading == TELEPORTER_SOURCE_INDEX_GROUP
end

local function getTeleporterSetting(index)
	local setting = BMU.savedVarsChar[index]
	return setting
end

local function isVisible(visible)
	if type(visible) == 'function' then
		visible = visible()
	end
	return visible
end

local HEADER_STRINGS = {
	CATEGORY0 = '',
	CATEGORY1 = GetString(SI_CUSTOMERSERVICEASKFORHELPCHARACTERISSUECATEGORY2), -- Group Activities
	CATEGORY2 = GetString(SI_GUILD_RECRUITMENT_ADDITIONAL_ACTIVITIES_HEADER):gsub(':$',''), -- Additional Activities
	CATEGORY3 = GetString(SI_CHATCHANNELCATEGORIES60), -- Other
}

local function getHeaderString(headerType, headerIndex)
	headerIndex = headerIndex or 0
	return HEADER_STRINGS[headerType .. headerIndex]
end

---------------------------------------------------------------------------------------------------------------
-- Category list
---------------------------------------------------------------------------------------------------------------
local categoryList = TeleportClass_Shared:Subclass()

function categoryList:Initialize(owner, control)
--	local control = CreateControlFromVirtual(owner.name .. name, parentControl:GetNamedChild('Main'), "IsJustaSANDBOX_List_Template")
	TeleportClass_Shared.Initialize(self, control)

	self.container = control
	self.owner = owner

	self:BuildCategories()
	self:Refresh()

	self.fragment:RegisterCallback("StateChange",  function(oldState, newState)
		if newState == SCENE_SHOWING then
			self:Activate()
			KEYBIND_STRIP:AddKeybindButtonGroup(self.keybindStripDescriptor)

			self:Refresh()
		elseif newState == SCENE_SHOWN then
		--	self:UpdateTooltip()
			self:UpdateTooltip(self:GetTargetData())
		elseif newState == SCENE_HIDDEN then
			KEYBIND_STRIP:RemoveKeybindButtonGroup(self.keybindStripDescriptor)
			self:Deactivate()
			self.owner:RefreshHeader()
		end
	end)
end

function categoryList:BuildCategories()
	local categories = {
		{ -- Show Group
			filterType = 0,
			categoryType = CATEGORY_TYPE_GROUP,
			name = GetString(SI_MAIN_MENU_GROUP),
			icon = "/esoui/art/mainmenu/menubar_group_up.dds",

			enabled = isEnabled_Default,
			visible = function() return IsUnitGrouped('player') end,

			categoryFilter = categoryFilter_Group,

			filter = {
				index = 0,
			},
			callback = function(currentFilter)
				local orig_zoneOnceOnly = BMU.savedVarsAcc.zoneOnceOnly
				-- not tested
				-- We must set this to false so it will list all players in a zone in order to show all group members.
				BMU.savedVarsAcc.zoneOnceOnly = false
				BMU.createTable(currentFilter)

				-- Now set it back to what it was originally set to.
				BMU.savedVarsAcc.zoneOnceOnly = orig_zoneOnceOnly
			end,
		},
		{ -- Show all
			filterType = 0,
			categoryType = CATEGORY_TYPE_ALL,
			name = GetString(SI_GUILD_HISTORY_SUBCATEGORY_ALL),

			icon = BMU.textures.refreshBtn,
			enabled = isEnabled_Default,
			visible = true,

			filter = {
				index = 0,
			},
			callback = function(currentFilter)
				BMU.createTable(currentFilter)
			end,
		},
		{ -- current map zone only
			filterType = 0,
			categoryType = CATEGORY_TYPE_DISPLAYED,
			name = GetString(SI_TELE_UI_BTN_CURRENT_ZONE),
			icon = BMU.textures.currentZoneBtn,

			enabled = true,
			visible = true,

			filter = {
				index = 8,
			},
			callback = function(currentFilter)
				BMU.createTable(currentFilter)
			end,
		},
		{ -- personal homes
			filterType = 0,
			categoryType = CATEGORY_TYPE_OTHER,
			name = GetString(SI_TELE_UI_BTN_PORT_TO_OWN_HOUSE),
			icon = BMU.textures.houseBtn,

			enabled = true,
			visible = true,

			filter = {
				index = 0,
			},
			callback = function(currentFilter)
				BMU.createTableHouses(currentFilter)
			end,
		},
		{ -- show quests
			filterType = 0,
			categoryType = CATEGORY_TYPE_QUESTS,
			name = GetString(SI_TELE_UI_BTN_RELATED_QUESTS),
			icon = BMU.textures.questBtn,

			enabled = true,
			visible = true,

			filter = {
				index = 9,
			},
			callback = function(currentFilter)
				BMU.createTable(currentFilter)
			end,
		},
		{ -- "Treasure & survey maps & leads"
			filterType = 0,
			categoryType = CATEGORY_TYPE_ITEMS,
			name = GetString(SI_TELE_KEYBINDING_TOGGLE_MAIN_RELATED_ITEMS),
			icon = BMU.textures.relatedItemsBtn,

			enabled = isEnabled_Default,
			visible = true,

			filter = {
				index = 4,
			},
			callback = function(currentFilter)
				BMU.createTable(currentFilter)
			end,
		},
		{ -- dungeon finder
			filterType = 1,
			categoryType = CATEGORY_TYPE_DUNGEON,
			name = GetString(SI_TELE_UI_BTN_DUNGEON_FINDER),
			icon = BMU.textures.groupDungeonBtn,

			enabled = true,
			visible = true,

			filter = {
				index = 0,
			},
			callback = function()
				BMU.createTableDungeons()
			end,
		},
		{ -- Delves and open Dungeons
			filterType = 2,
			categoryType = CATEGORY_TYPE_DELVE,
			name = GetString(SI_BMU_GAMEPAD_CATEGORY_DELVES), -- only Delves and open Dungeons (in your own Zone or globally)
			icon = BMU.textures.groupDungeonBtn,

			enabled = isEnabled_Default,
			visible = true,

			filter = {
				index = 5,
			},
			callback = function(currentFilter)
				BMU.createTable(currentFilter)
			end,
		},
		{ -- show BMU guilds
			filterType = 3,
			categoryType = CATEGORY_TYPE_BMU,
			name = GetString(SI_TELE_UI_BTN_GUILD_BMU),
			icon = BMU.textures.guildBtn,

			enabled = true,
			visible = function() return BMU.var.BMUGuilds[GetWorldName()] ~= nil end,
		--	visible = false,

			filter = {
				index = 0,
			},
			callback = function()
				if not BMU.isCurrentlyRequestingGuildData then
					BMU.requestGuildData()
				end
				BMU.clearInputFields()
				zo_callLater(function() BMU.createTableGuilds() end, 350)
			end,
		},
	}

	if PortToFriend then
		local cataegory = { -- show port to friends
			filterType = 3,
			categoryType = CATEGORY_TYPE_OTHER,
			name = GetString(SI_TELE_UI_BTN_PTF_INTEGRATION),
			icon = BMU.textures.ptfHouseBtn,

			enabled = isEnabled_PTF,
			visible = true,

			filter = {
				index = 0,
			},
			callback = function()
				BMU.createTablePTF()
			end,
		}

		table.insert(categories, cataegory)
	end

	if true then
		local cataegory = { -- test
			filterType = 3,
			categoryType = CATEGORY_TYPE_TEST,
			name = 'Test Houses',
			icon = BMU.textures.ptfHouseBtn,

			enabled = true,
			visible = true,

			filter = {
				index = 0,
			},
			callback = function(currentFilter)
				zo_callLater(function()
					self.owner:CreateTestList(currentFilter)
				end, 100)
			end,
		}

		table.insert(categories, cataegory)
		local cataegory = { -- test
			filterType = 3,
			categoryType = CATEGORY_TYPE_TEST,
			name = 'Test ZONES',
			icon = BMU.textures.ptfHouseBtn,

			enabled = true,
			visible = true,

			filter = {
				index = 1,
			},
			callback = function(currentFilter)
				zo_callLater(function()
					self.owner:CreateTestList(currentFilter)
				end, 100)
			end,
		}

		table.insert(categories, cataegory)
	end

	self.categories = categories
end

function categoryList:InitializeKeybindDescriptor()
	local function onCategorySelected(categoryData)

					onCategorySelected(targetData)
	end

	self.keybindStripDescriptor =
	{
		alignment = KEYBIND_STRIP_ALIGN_LEFT,
		{ -- select item
			name = GetString(SI_GAMEPAD_SELECT_OPTION),
			keybind = "UI_SHORTCUT_PRIMARY",
			callback = function()
				local targetData = self:GetTargetData()

				if targetData then
					self.owner.OnShowTeleportList()
					PlaySound(SOUNDS.MAP_LOCATION_CLICKED)
				end
			end,
		--	enabled =  function() return true end,
			enabled =  function() return #self.owner.portalPlayers > 0 end,
			visible = function() return true end,
		},
		{ -- select refresh
			name = GetString(SI_OPTIONS_RESET),
			keybind = "UI_SHORTCUT_SECONDARY",
			callback = function()
				resetMapPosition()
				
				g_selectedIndex = 1
				self:ResetFilters()
				PlaySound(SOUNDS.MAP_LOCATION_CLICKED)
			end,
			enabled = function() return true end,
			visible = function() return true end,
		},
		{
			name = GetString(SI_GAMEPAD_OPTIONS_MENU),
			keybind = "UI_SHORTCUT_TERTIARY",
			enabled = function()
				return self:HasAnyShownOptions()
			end,
			callback = function()
				return self:ShowOptionsDialog()
			end,
		},
	}

	ZO_Gamepad_AddBackNavigationKeybindDescriptors(self.keybindStripDescriptor, GAME_NAVIGATION_TYPE_BUTTON, ZO_WorldMapInfo_OnBackPressed)
	ZO_Gamepad_AddListTriggerKeybindDescriptors(self.keybindStripDescriptor, self)
end

---------------------------------------------------------------------------------------------------------------
-- 
---------------------------------------------------------------------------------------------------------------
function categoryList:BuildOptionsList()
	self.optionTemplateGroups = {}
	self.conditionResults = {}

	local filtersGroupId = self:AddOptionTemplateGroup(function() return GetString(SI_GAMEPAD_CRAFTING_OPTIONS_FILTERS) end)
	self:BuildMainCategroyOptions(filtersGroupId)
	self:BuildItemsCategoryOptions(filtersGroupId)
	self:BuildDungeonsCategoryOptions(filtersGroupId)
	self:BuildDelvesCategoryOptions(filtersGroupId)
end

function categoryList:BuildMainCategroyOptions(groupId)
	local function callback(data)
		self:SetCategoryFilter(2, data.filterName, data.filterIndex, data.filterSourceIndex, data.controlIndex)
		self:Refresh()
	end

	local function conditionFunction()
		local categoryData = self:GetTargetData()
		if not categoryData then return false end
		return categoryData.categoryType == CATEGORY_TYPE_ALL
	end

	if self.dropdownDataMain == nil then
		local dropdownData = {callback = callback}
		table.insert(dropdownData, { -- All
			filterName = GetString(SI_GUILD_HISTORY_SUBCATEGORY_ALL),
			filterIndex = 0,
		})

		table.insert(dropdownData, { -- Group
			filterName = BMU.var.color.colOrange .. GetString(SI_TELE_UI_FILTER_GROUP),
			filterIndex = 7,
			filterSourceIndex = TELEPORTER_SOURCE_INDEX_GROUP,
		})

		table.insert(dropdownData, { -- Friends
			filterName = BMU.var.color.colGreen .. GetString(SI_TELE_UI_FILTER_FRIENDS),
			filterIndex = 7,
			filterSourceIndex = TELEPORTER_SOURCE_INDEX_FRIEND,
		})

		for guildIndex = 1, GetNumGuilds() do -- Guilds
			local guildId = GetGuildId(guildIndex)

			table.insert(dropdownData, {
				filterName = BMU.var.color.colWhite .. GetGuildName(guildId),
				filterIndex = 7,
				filterSourceIndex = TELEPORTER_SOURCE_INDEX_FRIEND + guildIndex,
			})
		end

		self.dropdownDataMain = dropdownData
	end

	self:AddOptionTemplate(groupId, function() return self:BuildDropdown(SI_GAMEPAD_CRAFTING_OPTIONS_FILTERS, label, self.dropdownDataMain, icon) end, conditionFunction)
end

function categoryList:BuildItemsCategoryOptions(groupId)
	local function conditionFunction()
		local categoryData = self:GetTargetData()
		if not categoryData then return false end
		return categoryData.categoryType == CATEGORY_TYPE_ITEMS
	end

	local surveyReports = {
		'displaySurveyMapsAlchemist', 'displaySurveyMapsEnchanter', 'displaySurveyMapsWoodworker',
		'displaySurveyMapsBlacksmith', 'displaySurveyMapsClothier', 'displaySurveyMapsJewelry'
	}


	local function areSurveysActive()
		for k, index in pairs(surveyReports) do
			if not getTeleporterSetting(index) then
				return false
			end
		end
		return true
	end

	local filterData = {
		{
			filterName = GetString(SI_TELE_UI_TOGGLE_SURVEY_MAP),
			callback = function(data)
				for k, index in pairs(surveyReports) do
					self:ToggleBUISetting(index, data.checked)
				end
			end,
			checked = function() return areSurveysActive() end,
		},
		{
			filterName = GetString(SI_TELE_UI_TOGGLE_TREASURE_MAP),
			callback = function(data)
				self:ToggleBUISetting('displayTreasureMaps', data.checked)
			end,
			checked = function() return getTeleporterSetting('displayTreasureMaps') end,
		},
		{
			filterName = GetString(SI_TELE_UI_TOGGLE_LEADS_MAP),
			callback = function(data)
				self:ToggleBUISetting('displayLeads', data.checked)
			end,
			checked = function() return getTeleporterSetting('displayLeads') end,
		},
		{
			filterName = GetString(SI_TELE_UI_TOGGLE_INCLUDE_BANK_MAP),
			callback = function(data)
				self:ToggleBUISetting('scanBankForMaps', data.checked)
			end,
			checked = function() return getTeleporterSetting('scanBankForMaps') end,
		},
	}

	for filterIndex, currentFilter in ipairs(filterData) do
		self:AddOptionTemplate(groupId, function() return self:BuildCheckbox(SI_GAMEPAD_CRAFTING_OPTIONS_FILTERS, label, currentFilter, icon) end, conditionFunction)
	end

	local filterData = {
		{
			filterName = GetString(SI_ITEMTYPEDISPLAYCATEGORY14),
			callback = function(data)
				self:ToggleBUISetting('displaySurveyMapsAlchemist', data.checked)
			end,
			checked = function() return getTeleporterSetting('displaySurveyMapsAlchemist') end,
		},
		{
			filterName = GetString(SI_ITEMTYPEDISPLAYCATEGORY15),
			callback = function(data)
				self:ToggleBUISetting('displaySurveyMapsEnchanter', data.checked)
			end,
			checked = function() return getTeleporterSetting('displaySurveyMapsEnchanter') end,
		},
		{
			filterName = GetString(SI_ITEMTYPEDISPLAYCATEGORY12),
			callback = function(data)
				self:ToggleBUISetting('displaySurveyMapsWoodworker', data.checked)
			end,
			checked = function() return getTeleporterSetting('displaySurveyMapsWoodworker') end,
		},
		{
			filterName = GetString(SI_ITEMTYPEDISPLAYCATEGORY10),
			callback = function(data)
				self:ToggleBUISetting('displaySurveyMapsBlacksmith', data.checked)
			end,
			checked = function() return getTeleporterSetting('displaySurveyMapsBlacksmith') end,
		},
		{
			filterName = GetString(SI_ITEMTYPEDISPLAYCATEGORY11),
			callback = function(data)
				self:ToggleBUISetting('displaySurveyMapsClothier', data.checked)
			end,
			checked = function() return getTeleporterSetting('displaySurveyMapsClothier') end,
		},
		{
			filterName = GetString(SI_ITEMTYPEDISPLAYCATEGORY13),
			callback = function(data)
				self:ToggleBUISetting('displaySurveyMapsJewelry', data.checked)
			end,
			checked = function() return getTeleporterSetting('displaySurveyMapsJewelry') end,
		},
	}

	local filtersGroupId = self:AddOptionTemplateGroup(function() return GetString(SI_TELE_UI_TOGGLE_SURVEY_MAP) end)
	for filterIndex, currentFilter in ipairs(filterData) do
		self:AddOptionTemplate(filtersGroupId, function() return self:BuildCheckbox(SI_GAMEPAD_CRAFTING_OPTIONS_FILTERS, label, currentFilter, icon) end, conditionFunction)
	end
	


	--[[
	local filterData = {
		{
			filterName = GetString(SI_ITEMTYPEDISPLAYCATEGORY14),
			callback = function(data)
				self:ToggleBUISetting('displaySurveyMapsAlchemist', data.checked)
			end,
			checked = getTeleporterSetting('displaySurveyMapsAlchemist'),
		},
		{
			filterName = GetString(SI_ITEMTYPEDISPLAYCATEGORY15),
			callback = function(data)
				self:ToggleBUISetting('displaySurveyMapsEnchanter', data.checked)
			end,
			checked = getTeleporterSetting('displaySurveyMapsEnchanter'),
		},
		{
			filterName = GetString(SI_ITEMTYPEDISPLAYCATEGORY12),
			callback = function(data)
				self:ToggleBUISetting('displaySurveyMapsWoodworker', data.checked)
			end,
			checked = getTeleporterSetting('displaySurveyMapsWoodworker'),
		},
		{
			filterName = GetString(SI_ITEMTYPEDISPLAYCATEGORY10),
			callback = function(data)
				self:ToggleBUISetting(displaySurveyMapsBlacksmith)
			end,
			checked = getTeleporterSetting('displaySurveyMapsBlacksmith'),
		},
		{
			filterName = GetString(SI_ITEMTYPEDISPLAYCATEGORY11),
			callback = function(data)
				self:ToggleBUISetting('displaySurveyMapsClothier', data.checked)
			end,
			checked = getTeleporterSetting('displaySurveyMapsClothier'),
		},
		{
			filterName = GetString(SI_ITEMTYPEDISPLAYCATEGORY13),
			callback = function(data)
				self:ToggleBUISetting('displaySurveyMapsJewelry', data.checked)
			end,
			checked = getTeleporterSetting('displaySurveyMapsJewelry'),
		},
	}
	]]
end

function categoryList:BuildDungeonsCategoryOptions(groupId)
	local function conditionFunction()
		local categoryData = self:GetTargetData()
		if not categoryData then return false end
		return categoryData.categoryType == CATEGORY_TYPE_DUNGEON
	end
	local filterData = {
		{
			filterName = GetString(SI_TELE_UI_TOGGLE_ARENAS),
			callback = function(data)
				self:ToggleBUISetting('df_showArenas', data.checked)
			end,
			checked = getTeleporterSetting('df_showArenas'),
		},
		{
			filterName = GetString(SI_TELE_UI_TOGGLE_GROUP_ARENAS),
			callback = function(data)
				self:ToggleBUISetting('df_showGroupArenas', data.checked)
			end,
			checked = getTeleporterSetting('df_showGroupArenas'),
		},
		{
			filterName = GetString(SI_TELE_UI_TOGGLE_TRIALS),
			callback = function(data)
				self:ToggleBUISetting('df_showTrials', data.checked)
			end,
			checked = getTeleporterSetting('df_showTrials'),
		},
		{
			filterName = GetString(SI_TELE_UI_TOGGLE_GROUP_DUNGEONS),
			callback = function(data)
				self:ToggleBUISetting('df_showDungeons', data.checked)
			end,
			checked = getTeleporterSetting('df_showDungeons'),
		},
	}
	for filterIndex, currentFilter in ipairs(filterData) do
		self:AddOptionTemplate(groupId, function() return self:BuildCheckbox(SI_GAMEPAD_CRAFTING_OPTIONS_FILTERS, label, currentFilter, icon) end, conditionFunction)
	end

end

function categoryList:BuildDelvesCategoryOptions(groupId)
	local function conditionFunction()
		local categoryData = self:GetTargetData()
		if not categoryData then return false end
		return categoryData.categoryType == CATEGORY_TYPE_DELVE
	end
	
	local filterData = {
		{
			filterName = GetString(SI_TELE_UI_TOGGLE_ALL_DELVES),
			callback = function(data)
				self:ToggleBUISetting('showAllDelves', data.checked)
			end,
			checked = getTeleporterSetting('showAllDelves'),
		},
	}
	for filterIndex, currentFilter in ipairs(filterData) do
		self:AddOptionTemplate(groupId, function() return self:BuildCheckbox(SI_GAMEPAD_CRAFTING_OPTIONS_FILTERS, label, currentFilter, icon) end, conditionFunction)
	end
end

---------------------------------------------------------------------------------------------------------------
-- 
---------------------------------------------------------------------------------------------------------------
function categoryList:ToggleBUISetting(index, checked)
	BMU.savedVarsChar[index] = checked
	self.owner:UpdatePortalPlayers()
	self:Refresh()
end

function categoryList:ResetFilters()
	for categoryIndex, filter in ipairs(FILTER_DEFAULTS) do
		self:SetCategoryFilter(categoryIndex, filter.name, filter.index)
	end

	self.dropdownDataMain.selectedIndex = 1
--	self:RefreshVisible()
	self:Refresh()
end

function categoryList:SetCategoryFilter(categoryIndex, name, index, filterSourceIndex)
	self.categories[categoryIndex].name = name
	local currentFilter = {
		index = index,
		filterSourceIndex = filterSourceIndex,
	}
	self.categories[categoryIndex].filter = currentFilter

	local currentControl = self.dataIndexToControl[self.selectedData.controlIndex]
	if currentControl then
		currentControl.label:SetText(name)
	end
end

function categoryList:Refresh()
	self:Clear()
	local categories = self.categories or {}
	local lastFilterType
	local controlIndex = 1
	for i, data in ipairs(categories) do
		if isVisible(data.visible) then
			local entryData = ZO_GamepadEntryData:New(data.name, data.icon)

			entryData:SetDataSource(data)
			zo_mixin(entryData, data)

			entryData.controlIndex = controlIndex
			entryData:AddSubLabel(data.foundInZoneName)

			if lastFilterType ~= data.filterType then
				lastFilterType = data.filterType
				entryData:SetHeader(getHeaderString('CATEGORY', data.filterType))
				self:AddEntry("ZO_GamepadMenuEntryTemplateLowercase42WithHeader", entryData)
			else
				self:AddEntry("ZO_GamepadMenuEntryTemplateLowercase42", entryData)
			end
			controlIndex = controlIndex + 1
		end
	end

	self:Commit()
	self:RefreshNoEntriesLabel()

	self:SetupOptions(self:GetTargetData())
	self:RefreshKeybind()
end

---------------------------------------------------------------------------------------------------------------
-- 
---------------------------------------------------------------------------------------------------------------
function categoryList:OnSelectedDataChangedCallback(categoryData)
	CALLBACK_MANAGER:FireCallbacks('BMU_GAMEPAD_CATEGORY_CHANGED', categoryData)
	self:UpdateTooltip(categoryData)
end

---------------------------------------------------------------------------------------------------------------
-- 
---------------------------------------------------------------------------------------------------------------
addon.subclassTable.categoryList = categoryList