local _G = _G
local PitBull4 = _G.PitBull4

local values = {
	disabled = "Disable",
	solo = "Solo",
}
--- Return the select values dictionary used by PitBull4 to choose config mode.
-- @usage local values = PitBull4:GetConfigModeValues()
-- @return an AceConfig-3.0-compliant select values dictionary.
function PitBull4:GetConfigModeValues()
	return values
end

--- Return whether PitBull4 is in config mode, and if so, what type.
-- @usage local config_mode = PitBull4:IsInConfigMode()
-- @return nil meaning disabled or one of the keys from PitBull4:GetConfigModeValues() (except "disabled")
function PitBull4:IsInConfigMode()
	return self.config_mode
end

--- Set the config mode type.
-- This will error if you pass in a wrong param. See PitBull4:GetConfigModeValues().
-- @param kind nil or "disabled" to disable, or one of the other keys from PitBull4:GetConfigModeValues().
-- @usage PitBull4:SetConfigMode(nil)
-- @usage PitBull4:SetConfigMode("disabled")
-- @usage PitBull4:SetConfigMode("solo")
function PitBull4:SetConfigMode(kind)
	if kind ~= nil and not values[kind] then
		error(("%q is not a valid option to pass to PitBull4:SetConfigMode"):format(kind), 2)
	elseif InCombatLockdown() then
		error("Cannot call PitBull4:SetConfigMode while in combat lockdown.")
	end
	if kind == "disabled" then
		kind = nil
	end
	if PitBull4.config_mode == kind then
		return
	end
	PitBull4.config_mode = kind
	
	for frame in self:IterateFrames(true) do
		if frame.is_singleton then
			if kind then
				frame:ForceShow()
			else
				frame:UnforceShow()
			end
		end
		frame:Update(true, true)
	end
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("PLAYER_REGEN_DISABLED")
frame:SetScript("OnEvent", function()
	if not PitBull4.config_mode then
		return
	end
	
	UIErrorsFrame:AddMessage("Disabling PitBull4 config mode, entering combat.", 0.5, 1, 0.5, nil, 1)
	PitBull4:SetConfigMode(nil)
end)

function PitBull4.Options.get_config_mode_options()
	return {
		name = "Config mode",
		desc = "Show all frames that can be shown, for easy configuration.",
		type = 'select',
		values = PitBull4:GetConfigModeValues(),
		get = function(info)
			return PitBull4:IsInConfigMode() or "disabled"
		end,
		set = function(info, value)
			PitBull4:SetConfigMode(value)
		end,
		disabled = function(info)
			return InCombatLockdown()
		end,
	}
end
