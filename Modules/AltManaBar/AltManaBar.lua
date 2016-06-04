if select(5, GetAddOnInfo("PitBull4_" .. (debugstack():match("[o%.][d%.][u%.]les\\(.-)\\") or ""))) ~= "MISSING" then return end

local player_class = select(2, UnitClass("player"))
if not ALT_MANA_BAR_PAIR_DISPLAY_INFO[player_class] then return end

local PitBull4 = _G.PitBull4
if not PitBull4 then
	error("PitBull4_AltManaBar requires PitBull4")
end

local L = PitBull4.L

local PitBull4_AltManaBar = PitBull4:NewModule("DruidManaBar", "AceEvent-3.0")

PitBull4_AltManaBar:SetModuleType("bar")
PitBull4_AltManaBar:SetName(L["Alternate mana bar"])
PitBull4_AltManaBar:SetDescription(L["Show a mana bar for classes that have a different main resource but still use mana for some spells."])
PitBull4_AltManaBar:SetDefaults({
	size = 1,
	position = 6,
	hide_if_full = false,
})

-- constants
local MANA_TYPE = 0

-- cached power type for optimization
local power_type = nil

function PitBull4_AltManaBar:OnEnable()
	PitBull4_AltManaBar:RegisterEvent("UNIT_POWER_FREQUENT")
	PitBull4_AltManaBar:RegisterEvent("UNIT_MAXPOWER","UNIT_POWER_FREQUENT")
	PitBull4_AltManaBar:RegisterEvent("UNIT_DISPLAYPOWER","UNIT_POWER_FREQUENT")
	PitBull4_AltManaBar:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
end

function PitBull4_AltManaBar:GetValue(frame)
	if frame.unit ~= "player" then
		return nil
	end
 
	power_type = UnitPowerType("player")
	if power_type == MANA_TYPE then
		return nil
	end

	if (player_class == "PRIEST" and GetSpecialization() ~= SPEC_PRIEST_SHADOW) or
		(player_class == "DRUID" and GetSpecialization() ~= SPEC_DRUID_BALANCE) or
		(player_class == "SHAMAN" and GetSpecialization() == SPEC_SHAMAN_RESTORATION) then
		return nil
	end	

	local max = UnitPowerMax("player", MANA_TYPE)
	local percent = 0
	if max ~= 0 then
	  percent = UnitPower("player", MANA_TYPE) / max
	end

	if percent == 1 and self:GetLayoutDB(frame).hide_if_full then
		return nil
	end

	return percent
end
function PitBull4_AltManaBar:GetExampleValue(frame)
	-- just go with what :GetValue gave
	return nil
end

function PitBull4_AltManaBar:GetColor(frame, value)
	local color = PitBull4.PowerColors["MANA"]
	return color[1], color[2], color[3]
end
PitBull4_AltManaBar.GetExampleColor = PitBull4_AltManaBar.GetColor

function PitBull4_AltManaBar:UNIT_POWER_FREQUENT(event, unit, power_type)
	if unit ~= "player" or ((event == "UNIT_POWER_FREQUENT" or event == "UNIT_MAXPOWER") and power_type ~= "MANA") then
		return
	end

	local prev_power_type = power_type
	power_type = UnitPowerType("player") 
	if power_type == MANA_TYPE and power_type == prev_power_type then
		-- We really don't want to iterate all the frames on every mana
		-- update when the druid is already in a mana form and the bar
		-- is already hidden.
		return
	end

	for frame in PitBull4:IterateFramesForUnitID("player") do
		self:Update(frame)
	end
end

function PitBull4_AltManaBar:PLAYER_SPECIALIZATION_CHANGED(event)
	for frame in PitBull4:IterateFramesForUnitID("player") do
		self:Update(frame)
	end
end

PitBull4_AltManaBar:SetLayoutOptionsFunction(function(self)
	return 'hide_if_full', {
		name = L["Hide if full"],
		desc = L["Hide when at 100% mana."],
		type = 'toggle',
		get = function(info)
			return PitBull4.Options.GetLayoutDB(self).hide_if_full
		end,
		set = function(info, value)
			PitBull4.Options.GetLayoutDB(self).hide_if_full = value
			
			PitBull4.Options.UpdateFrames()
		end,
	}
end)
