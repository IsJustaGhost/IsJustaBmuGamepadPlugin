
local function ReleaseDialog(dialogName)
	ZO_Dialogs_ReleaseDialogOnButtonPress(dialogName)
end

local finishedCallback = nil

ZO_Dialogs_RegisterCustomDialog("BMU_GAMEPAD_SOCIAL_OPTIONS_DIALOG",
{
	gamepadInfo = {
		dialogType = GAMEPAD_DIALOGS.PARAMETRIC,
	},
	setup = function(dialog)
		local data = dialog.data
		if data.setupFunction then
			data.setupFunction(dialog)
		end

		dialog.info.parametricList = data.parametricList
		finishedCallback = nil
		dialog:setupFunc()
	end,
	finishedCallback = function(dialog)
		if finishedCallback then
			finishedCallback(dialog)
		end
	end,
	title = {
		text = SI_GAMEPAD_CONTACTS_OPTIONS_TITLE,
	},
	blockDialogReleaseOnPress = true,
	canQueue = true,
	buttons = {
		{
			keybind = "DIALOG_PRIMARY",
			text = SI_GAMEPAD_SELECT_OPTION,
			callback =  function(dialog)
				local data = dialog.entryList:GetTargetData()
				if data.callback then
					data.callback(dialog)
				end
				finishedCallback = data.finishedCallback
			--	ReleaseDialog(dialogName)
			end,
		},

		{
			keybind = "DIALOG_NEGATIVE",
			text = SI_DIALOG_CLOSE,
			callback = function()
				ReleaseDialog("BMU_GAMEPAD_SOCIAL_OPTIONS_DIALOG")
			end,
		},
	}
})

local function buildCheckbox(header, label, entryData, finishedCallback, icon)
	local function onFilterToggled(data)
		if entryData.control ~= nil then
			local targetControl = entryData.control
			ZO_GamepadCheckBoxTemplate_OnClicked(targetControl)
			entryData.checked = ZO_CheckButton_IsChecked(targetControl.checkBox)

			BMU.savedVarsServ[entryData.savedVar][entryData.savedVarIndex] = entryData.checked or nil
		end
	end
	
	local function setupFunction(control, data, selected, reselectingDuringRebuild, enabled, active)
		data.callback = onFilterToggled
		ZO_GamepadCheckBoxTemplate_Setup(control, data, selected, reselectingDuringRebuild, enabled, active)
		
		local checked = entryData.checked
		
		if type(checked) == 'function' then
			checked = checked()
		end
		
		if checked then
			ZO_CheckButton_SetChecked(control.checkBox)
		else
			ZO_CheckButton_SetUnchecked(control.checkBox)
		end
		entryData.control = control
	end

	entryData.setup = setupFunction
	local listItem =
	{
		template = "ZO_CheckBoxTemplate_WithPadding_Gamepad",
		entryData = entryData,
		header = header,
	}

	return listItem
end

ZO_Dialogs_RegisterCustomDialog("BMU_GAMEPAD_MANAGE_FAVORITES_DIALOG",
{
	gamepadInfo = {
		dialogType = GAMEPAD_DIALOGS.PARAMETRIC,
		allowShowOnNextScene = true,
	},
	finishedCallback = function(dialog)
		if finishedCallback then
			finishedCallback(dialog)
		end
	end,
	title = {
		text = SI_GAMEPAD_CONTACTS_OPTIONS_TITLE,
	},
	canQueue = true,
	blockDialogReleaseOnPress = true, -- We'll handle Dialog Releases ourselves since we don't want DIALOG_PRIMARY to release the dialog on press.

	parametricList = {}, -- Generated Dynamically
	setup = function(dialog)
		local parametricList = dialog.info.parametricList
		ZO_ClearNumericallyIndexedTable(parametricList)

		local categoryName = GetString(SI_TELE_UI_FAVORITE_PLAYER)
		for displayName, v in pairs(BMU.savedVarsServ.favoriteListPlayers) do
			local name = type(displayName) ~= 'number' and displayName or v

			local entryData = ZO_GamepadEntryData:New(name)
			entryData.savedVar = 'favoriteListPlayers'
			entryData.savedVarIndex = displayName
			entryData.checked = true

			local listItem = buildCheckbox(categoryName, name, entryData)

			table.insert(parametricList, listItem)
			categoryName = nil
		end

		local categoryName = GetString(SI_TELE_UI_FAVORITE_ZONE)
		for zoneId, v in pairs(BMU.savedVarsServ.favoriteListZones) do
			local zoneId = type(v) == 'number' and v or zoneId
			local name = GetZoneNameById(zoneId)

			local entryData = ZO_GamepadEntryData:New(name)
			entryData.savedVar = 'favoriteListZones'
			entryData.savedVarIndex = zoneId
			entryData.checked = true

			local listItem = buildCheckbox(categoryName, name, entryData)

			table.insert(parametricList, listItem)
			categoryName = nil
		end

		if #parametricList == 0 then

			local name = GetString(SI_TELE_UI_NO_MATCHES)

			local entryData = ZO_GamepadEntryData:New(name)
			entryData.setup = ZO_SharedGamepadEntry_OnSetup

			local listItem =
			{
				template = "ZO_GamepadItemEntryTemplate",
				entryData = entryData,
			}
			table.insert(parametricList, listItem)
		end

		dialog:setupFunc()
	end,

	buttons = {
		{
			keybind = "DIALOG_PRIMARY",
			text = SI_GAMEPAD_SELECT_OPTION,
			callback =  function(dialog)
				local data = dialog.entryList:GetTargetData()
				if data.callback then
					data.callback(dialog)
				end
				finishedCallback = data.finishedCallback
			end,
		},

		{
			keybind = "DIALOG_NEGATIVE",
			text = SI_DIALOG_CLOSE,
			callback = function()
				ReleaseDialog("BMU_GAMEPAD_MANAGE_FAVORITES_DIALOG")
			end,
		},
	}
})
