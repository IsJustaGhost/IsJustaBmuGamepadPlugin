local addon = IJA_BMU_GAMEPAD_PLUGIN

---------------------------------------------------------------------------------------------------------------
-- Right Side Tooltip
---------------------------------------------------------------------------------------------------------------
local GENERAL_COLOR_WHITE = GAMEPAD_TOOLTIP_COLOR_GENERAL_COLOR_1
ZO_TOOLTIP_STYLES.bmuHeader = {
		fontFace = "$(GAMEPAD_MEDIUM_FONT)",
		fontSize = "$(GP_27)",
		uppercase = true,
		fontColorField = GENERAL_COLOR_WHITE,
		horizontalAlignment = TEXT_ALIGN_CENTER,
		widthPercent = 100,
}
ZO_TOOLTIP_STYLES.bmuTitle = {
		fontSize = "$(GP_42)",
		horizontalAlignment = TEXT_ALIGN_CENTER,

}
ZO_TOOLTIP_STYLES.bmuBodyDescription = {
		fontSize = "$(GP_34)",
		horizontalAlignment = TEXT_ALIGN_CENTER,

}
ZO_TOOLTIP_STYLES.bmuBodySection = {
		childSpacing = 2,
		widthPercent = 100,

}

local tooltip_mixin = {}
function tooltip_mixin:LayoutTitleAndMultiSectionDescriptionTooltip(title, ...)
	--Title
	if title then
		local headerSection = self.tooltip:AcquireSection(self.tooltip:GetStyle("bmuHeader"))
		headerSection:AddLine(title, self.tooltip:GetStyle("bmuTitle"))
		self.tooltip:AddSection(headerSection)
	end

	--Body
	for i = 1, select("#", ...) do
		local bodySection = self.tooltip:AcquireSection(self.tooltip:GetStyle("bmuBodySection"))
		bodySection:AddLine(select(i, ...), self.tooltip:GetStyle("bmuBodyDescription"))
		self.tooltip:AddSection(bodySection)
	end
end

---------------------------------------------------------------------------------------------------------------
--
---------------------------------------------------------------------------------------------------------------
local function GetStringFromData(data)
	local dataType = type(data)
	if dataType == "function" then
		return data()
	elseif dataType == "number" then
		return GetString(data)
	else
		return data
	end
end

local function highlightText(label)
	return '|cFFFFFF' .. label-- .. 'r|'
end

local function addTooltipData(tooltipData, data)
	if data then
		if #tooltipData > 0 then
			-- add separator
			table.insert(tooltipData, BMU.textures.tooltipSeperator)
		end
		if type(data) == 'table' then
			for k, entry in pairs(data) do
				table.insert(tooltipData, entry)
			end
		else
			table.insert(tooltipData, data)
		end
	else
		table.insert(tooltipData, BMU.textures.tooltipSeperator)
	end
end

local function getTargetTooltipData(targetData)
	local tooltipData = {}
	local tooltipTextLevel = ""

	-- Second language for zone names
	-- if second language is selected & entry is a real zone & zoneNameSecondLanguage exists
	if BMU.savedVarsAcc.secondLanguage ~= 1 and targetData.zoneNameClickable == true and targetData.zoneNameSecondLanguage ~= nil then
		-- add zone name
		addTooltipData(tooltipData, targetData.zoneNameSecondLanguage)
	end
	------------------


	-- wayhsrine and skyshard discovery info
	if targetData.zoneNameClickable == true and (targetData.zoneWayhsrineDiscoveryInfo ~= nil or targetData.zoneSkyshardDiscoveryInfo ~= nil) then
		if #tooltipData > 0 then
			-- add separator
	--		table.insert(tooltipData, 1, BMU.textures.tooltipSeperator)
		end
		
		local discoveryInfo = {}
		-- add discovery info
		if targetData.zoneWayhsrineDiscoveryInfo ~= nil then
			table.insert(discoveryInfo, targetData.zoneWayhsrineDiscoveryInfo)
		end
		if targetData.zoneSkyshardDiscoveryInfo ~= nil then
			table.insert(discoveryInfo, targetData.zoneSkyshardDiscoveryInfo)
		end
		
		addTooltipData(tooltipData, discoveryInfo)
	end
	------------------
	
	
	--------- zone tooltip (and zone name)  and handler for map opening ---------
	-- if search for related items and info not already added
	if targetData.relatedItems ~= nil and #targetData.relatedItems > 0 then
		if string.sub(targetData.zoneName, -1) ~= ")" then
			-- add info about total number of related items
			local totalItemsCountInv = 0
			local totalItemsCountBank = 0
			for index, item in pairs(targetData.relatedItems) do
				if item.isInInventory then
					totalItemsCountInv = totalItemsCountInv + item.itemCount
				else
					totalItemsCountBank = totalItemsCountBank + item.itemCount
				end
			end
			if totalItemsCountInv > 0 then
				targetData.zoneName = targetData.zoneName .. " (" .. totalItemsCountInv .. ")"
			end
			if totalItemsCountBank > 0 then
				targetData.zoneName = targetData.zoneName .. BMU.var.color.colTrash .. " (" .. totalItemsCountBank .. ")"
			end
		end

		-- copy item names to tooltipData
		local relatedItems = {}
		for index, item in ipairs(targetData.relatedItems) do
			table.insert(relatedItems, item.itemTooltip)
		end

		addTooltipData(tooltipData, relatedItems)

	-- if search for related quests
	elseif targetData.relatedQuests ~= nil and #targetData.relatedQuests > 0 then
		if string.sub(targetData.zoneName, -1) ~= ")" then
			-- add info about number of related quests
			targetData.zoneName = targetData.zoneName .. " (" .. targetData.countRelatedQuests .. ")"
		end
		-- copy "targetData.relatedQuests" to "tooltipData" (Attention: "=" will set pointer!)
	--	ZO_DeepTableCopy(targetData.relatedQuests, tooltipData)
		local relatedQuests = {}
		for index, quest in ipairs(targetData.relatedQuests) do
			table.insert(relatedQuests, quest)
		end
		
		addTooltipData(tooltipData, relatedQuests)
	end


	--------- player tooltip ---------
	if targetData.displayName ~= "" and targetData.championRank then
		-- set level text for player tooltip
		if targetData.championRank >= 1 then
			tooltipTextLevel = "CP " .. targetData.championRank
		else
			tooltipTextLevel = targetData.level
		end
		local playerInfo = {highlightText(targetData.displayName), targetData.characterName, tooltipTextLevel, targetData.allianceName}

		addTooltipData(tooltipData, playerInfo)
		addTooltipData(tooltipData, targetData.sourcesText)
	end
	------------------


	-- GetString(SI_TELE_UI_GOLD) .. " " .. BMU.formatGold(BMU.savedVarsAcc.savedGold)
	-- Info if player is in same instance
	if targetData.groupMemberSameInstance ~= nil then
		-- add instance info
		if targetData.groupMemberSameInstance == true then
			addTooltipData(tooltipData, BMU.var.color.colGreen .. GetString(SI_TELE_UI_SAME_INSTANCE))
		else
			addTooltipData(tooltipData, BMU.var.color.colRed .. GetString(SI_TELE_UI_DIFFERENT_INSTANCE))
		end
	end
	------------------

	-- house tooltip
	if targetData.houseTooltip then
		-- add house infos
		--ZO_DeepTableCopy(targetData.houseTooltip, tooltipData)
		local hasZoneName = false
		local houseData = {}
		for _, v in pairs(targetData.houseTooltip) do
			if v == targetData.parentZoneName then
				v = highlightText(targetData.parentZoneName)
				hasZoneName = true
			end
			v = v:gsub('%|t75%:75', '|t128:128')
			table.insert(houseData, v)
		end
		if not hasZoneName then
			table.insert(houseData, highlightText(targetData.parentZoneName))
		end
		
		addTooltipData(tooltipData, houseData)
	end

	-- guild tooltip
	if targetData.guildTooltip then
		ZO_DeepTableCopy(tooltipData, targetData.guildTooltip)
	end

	return tooltipData
end

local function releaseDialogueCallback()
	ZO_Dialogs_ReleaseAllDialogsOfName("BMU_GAMEPAD_SOCIAL_OPTIONS_DIALOG")
end

---------------------------------------------------------------------------------------------------------------
--
---------------------------------------------------------------------------------------------------------------
local TeleportClass_Shared = ZO_Object.MultiSubclass(ZO_GamepadVerticalParametricScrollList, ZO_SocialOptionsDialogGamepad)

function TeleportClass_Shared:New(...)
	return ZO_GamepadVerticalParametricScrollList.New(self, ...)
end

function TeleportClass_Shared:Initialize(control)
	local listControl = control:GetNamedChild('Main'):GetNamedChild('List')

	self.socialData = {}
	ZO_GamepadVerticalParametricScrollList.Initialize(self, listControl)
	ZO_SocialOptionsDialogGamepad.Initialize(self)


	self.scrollTooltip = control:GetNamedChild("SideContent"):GetNamedChild("Tooltip")
	ZO_ScrollTooltip_Gamepad:Initialize(self.scrollTooltip, ZO_TOOLTIP_STYLES, "worldMapTooltip")
	zo_mixin(self.scrollTooltip, ZO_MapInformationTooltip_Gamepad_Mixin, tooltip_mixin)

	ZO_Scroll_Gamepad_SetScrollIndicatorSide(self.scrollTooltip.scrollIndicator, ZO_SharedGamepadNavQuadrant_4_Background, LEFT)

	self:InitializeKeybindDescriptor()

	self.noItemsLabel:SetText(GetString(SI_TELE_UI_NO_MATCHES))

	self:SetOnSelectedDataChangedCallback(function(_, selectedData, oldData, reselectingDuringRebuild, listIndex)
		self:OnSelectedDataChangedCallback(selectedData, oldData, reselectingDuringRebuild, listIndex)
	end)

	self.fragment = ZO_SimpleSceneFragment:New(control)

	self:SetOnTargetDataChangedCallback(function(_, newTargetData, oldTargetData)
		if newTargetData then
			self:SetupOptions(newTargetData)
		else
			self:SetupOptions(nil)
		end
	end)

	self:AddDataTemplate("ZO_GamepadMenuEntryTemplateLowercase42", ZO_SharedGamepadEntry_OnSetup, ZO_GamepadMenuEntryTemplateParametricListFunction)
	self:AddDataTemplateWithHeader("ZO_GamepadMenuEntryTemplateLowercase42", ZO_SharedGamepadEntry_OnSetup, ZO_GamepadMenuEntryTemplateParametricListFunction, nil, "ZO_GamepadMenuEntryHeaderTemplate")

--	self:BuildOptionsList()
end

function TeleportClass_Shared:PerformFullRefresh()
	if self.fragment:IsHidden() then return end

	self:Clear()
	self:Refresh()
	self:Commit()
	self:RefreshNoEntriesLabel()

	self:RefreshKeybind()
end

function TeleportClass_Shared:PerformUpdate()
	self.dirty = false
end

function TeleportClass_Shared:RefreshKeybind()
	if self.fragment:IsHidden() then return end
	KEYBIND_STRIP:UpdateKeybindButtonGroup(self.keybindStripDescriptor)
end

function TeleportClass_Shared:UpdateTooltip(targetData)
	if not targetData then
		self:RefreshKeybind()
		return
	end
	if self.control:IsHidden() then return end

	local tooltipControl = self.scrollTooltip
	tooltipControl:ClearLines()

	local tooltipData = {}
	if targetData.zoneName then
		tooltipData = getTargetTooltipData(targetData)
	elseif targetData.tooltipData then
		tooltipData = ZO_ShallowTableCopy(targetData.tooltipData)
	end

	if #tooltipData > 0 then -- add separator
		table.insert(tooltipData, 1, BMU.textures.tooltipSeperator)
	end
	if targetData.setCollectionProgress then
		table.insert(tooltipData, 1, targetData.setCollectionProgress)
		table.insert(tooltipData, 1, BMU.textures.tooltipSeperator)
	end
	
	
	if targetData.collectibleId then
		if #tooltipData > 0 then -- add separator
			table.insert(tooltipData, BMU.textures.tooltipSeperator)
		end
		local collectibleDescription = select(2, GetCollectibleInfo(targetData.collectibleId))
		table.insert(tooltipData, collectibleDescription)
	end
	
	if targetData.pinDesc and targetData.pinDesc ~= '' then
		if #tooltipData > 0 then -- add separator
			table.insert(tooltipData, BMU.textures.tooltipSeperator)
		end
		table.insert(tooltipData, targetData.pinDesc)
	end
	
	if targetData.mapId then
		local description = select(5, GetMapInfoById(targetData.mapId))
		
	--	local parentZoneId = GetZoneId(GetCurrentMapZoneIndex())
		local parentZoneId = targetData.parentZoneId
		local zoneName = GetZoneNameById(parentZoneId)
		
		if description == '' then
			-- If the parent zone is a subzone then let's get the subzone's parent
			parentZoneId = GetParentZoneId(parentZoneId)
			zoneName = GetZoneNameById(parentZoneId)
			description = select(5, GetMapInfoById(GetMapIdByZoneId(parentZoneId)))
		end
		
		if description ~= '' then
			if #tooltipData > 0 then -- add separator
				table.insert(tooltipData, BMU.textures.tooltipSeperator)
			end
			
			if targetData.zoneId ~= targetData.parentZoneId then
				table.insert(tooltipData, highlightText(zoneName))
			end
			
			table.insert(tooltipData, description)
		end
	end
	
	tooltipControl:LayoutTitleAndMultiSectionDescriptionTooltip(targetData.text, unpack(tooltipData))
	self:RefreshKeybind()
end

function TeleportClass_Shared:SetZoneId(zoneId)
	self.owner:SetZoneId(zoneId)
end

---------
function TeleportClass_Shared:RefreshNoEntriesLabel()
	self.noItemsLabel:SetHidden(not self:IsEmpty())
end

function TeleportClass_Shared:BuildCheckboxEntry(header, label, setupFunction, callback, setChecked, finishedCallback, icon)
	local entry =
	{
		template = "ZO_CheckBoxTemplate_WithPadding_Gamepad",
		header = header or self.currentGroupingHeader,
		templateData =
		{
			text = GetStringFromData(label),
			setup = setupFunction,
			callback = callback,
			setChecked = setChecked,
			finishedCallback = finishedCallback,
		},
		icon = icon,
	}
	return entry
end

function TeleportClass_Shared:BuildCheckbox(header, label, currentFilter, finishedCallback, icon)
	if type(currentFilter) == 'function' then
		currentFilter = currentFilter()
	end

	local header = self.currentGroupHeader
	local label = currentFilter.filterName

	local function onFilterToggled()
		if currentFilter.control ~= nil then
			local targetControl = currentFilter.control
			ZO_GamepadCheckBoxTemplate_OnClicked(targetControl)
			currentFilter.checked = ZO_CheckButton_IsChecked(targetControl.checkBox)

			if currentFilter.callback then
				currentFilter:callback()
			end
		--	ZO_GamepadDialogPara:setupFunc()
			
		--	TBUG.slashCommand(self)
		
		--[[
		
		]]
		end
	end

	local function onFilterSelected()
		if not self.dialogData.ignoreTooltips then
			GAMEPAD_TOOLTIPS:LayoutTitleAndDescriptionTooltip(GAMEPAD_LEFT_TOOLTIP, GetStringFromData(currentFilter.filterName), GetStringFromData(currentFilter.filterTooltip))
		end
	end

	local function filterCheckboxEntrySetup(control, data, selected, reselectingDuringRebuild, enabled, active)
		data.callback = onFilterToggled
		data.onSelected = onFilterSelected
		ZO_GamepadCheckBoxTemplate_Setup(control, data, selected, reselectingDuringRebuild, enabled, active)

		local checked = currentFilter.checked
		if type(checked) == 'function' then
			checked = checked()
		end
		
		if checked then
			ZO_CheckButton_SetChecked(control.checkBox)
		else
			ZO_CheckButton_SetUnchecked(control.checkBox)
		end
		currentFilter.control = control

	end

	return self:BuildCheckboxEntry(header, label, filterCheckboxEntrySetup, Callback, setChecked)
end

function TeleportClass_Shared:BuildDropdownEntry(header, label, setupFunction, callback, finishedCallback, icon)
	local entry = {
		header = header or self.currentGroupingHeader,
		template = "ZO_GamepadDropdownItem",

		templateData =
		{
			text = GetStringFromData(label),
			setup = setupFunction,
			callback = callback,
			finishedCallback = finishedCallback,
		},
		icon = icon,
	}

	return entry
end

function TeleportClass_Shared:BuildDropdown(header, label, dropdownData, icon)

	local function onSelectedCallback(dropdown, entryText, entry)
		dropdownData.selectedIndex = entry.index

		if dropdownData.callback then
			dropdownData.callback(entry)
		end
	end

	local function callback(dialog)
		local targetData = dialog.entryList:GetTargetData()
		local targetControl = dialog.entryList:GetTargetControl()
		targetControl.dropdown:Activate()
	end

	local function dropdownEntrySetup(control, data, selected, reselectingDuringRebuild, enabled, active)
		local dialogData = data and data.dialog and data.dialog.data

		local dropdowns = data.dialog.dropdowns
		if not dropdowns then
			dropdowns = {}
			data.dialog.dropdowns = dropdowns
		end
		local dropdown = control.dropdown
		table.insert(dropdowns, dropdown)

		dropdown:SetNormalColor(ZO_GAMEPAD_COMPONENT_COLORS.UNSELECTED_INACTIVE:UnpackRGB())
		dropdown:SetHighlightedColor(ZO_GAMEPAD_COMPONENT_COLORS.SELECTED_ACTIVE:UnpackRGB())
		dropdown:SetSelectedItemTextColor(selected)

		dropdown:SetSortsItems(false)
		dropdown:ClearItems()

		for i = 1, #dropdownData do
			local entryText = dropdownData[i].filterName
			local newEntry = dropdown:CreateItemEntry(entryText, onSelectedCallback)
			newEntry.index = i
			zo_mixin(newEntry, dropdownData[i])
			dropdown:AddItem(newEntry)
		end

		dropdown:UpdateItems()

		local initialIndex = dropdownData.selectedIndex or 1
		dropdown:SelectItemByIndex(initialIndex)
	end

	return self:BuildDropdownEntry(header, label, dropdownEntrySetup, callback, icon)
end

function TeleportClass_Shared:ShowOptionsDialog()
	self.filterControls = {}
	local parametricList = {}
	self:PopulateOptionsList(parametricList)
	local data = self:GetDialogData()
	--Saving the displayName and online state of the person the dialog is being opened for.
	self.dialogData.displayName = self.socialData.displayName
	self.dialogData.online = self.socialData.online
	ZO_Dialogs_ShowGamepadDialog("BMU_GAMEPAD_SOCIAL_OPTIONS_DIALOG", data)
end

function TeleportClass_Shared:BuildGuildInviteOption(header, guildId)
    local inviteFunction = function()
            ZO_TryGuildInvite(guildId, self.socialData.displayName)
        end

    return self:BuildOptionEntry(header, GetGuildName(guildId), inviteFunction, nil, GetLargeAllianceSymbolIcon(GetGuildAlliance(guildId)))
end

function TeleportClass_Shared:AddInviteToGuildOptionTemplates()
    local guildCount = GetNumGuilds()

    if guildCount > 0 then
        local guildInviteGroupingId = self:AddOptionTemplateGroup(function() return GetString(SI_GAMEPAD_CONTACTS_INVITE_TO_GUILD_HEADER) end)

        for i = 1, guildCount do
            local guildId = GetGuildId(i)

            local buildFunction = function() return self:BuildGuildInviteOption(nil, guildId) end
            local visibleFunction = function() return not self.socialData.isPlayer and DoesPlayerHaveGuildPermission(guildId, GUILD_PERMISSION_INVITE) end

            self:AddOptionTemplate(guildInviteGroupingId, buildFunction, visibleFunction)
        end
    end
end

function TeleportClass_Shared:BuildSendMailOption()
    local function finishCallback(dialog)
        if IsUnitDead("player") then
            ZO_AlertEvent(EVENT_UI_ERROR, SI_CANNOT_DO_THAT_WHILE_DEAD)
        elseif IsUnitInCombat("player") then
            ZO_AlertEvent(EVENT_UI_ERROR, SI_CANNOT_DO_THAT_WHILE_IN_COMBAT)
        else
            MAIL_MANAGER_GAMEPAD:GetSend():ComposeMailTo(ZO_FormatUserFacingCharacterOrDisplayName(self.socialData.displayName))
        end
    end
    return self:BuildOptionEntry(nil, SI_SOCIAL_MENU_SEND_MAIL, releaseDialogueCallback, finishCallback)
end

function TeleportClass_Shared:BuildWhisperOption()
    local finishCallback = function()
		StartChatInput("", CHAT_CHANNEL_WHISPER, self.socialData.displayName)
	end
    return self:BuildOptionEntry(nil, SI_SOCIAL_LIST_PANEL_WHISPER, releaseDialogueCallback, finishCallback)
end

addon.subclassTable.list_Shared = TeleportClass_Shared