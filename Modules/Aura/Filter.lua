-- Filter.lua : Code to handle Filtering the Auras.

if select(6, GetAddOnInfo("PitBull4_" .. (debugstack():match("[o%.][d%.][u%.]les\\(.-)\\") or ""))) ~= "MISSING" then return end

local _G = getfenv(0)
local PitBull4 = _G.PitBull4
local L = PitBull4.L
local PitBull4_Aura = PitBull4:GetModule("Aura")
local cata_400
local cata_406
local mop_500
do
	local _,wow_build,_,wow_interface = GetBuildInfo()
	wow_build = tonumber(wow_build)
	cata_400 = wow_interface >= 40000
	cata_406 = wow_build >= 13596
	mop_500 = wow_interface >= 50000
end

local GetNumSpecializations = GetNumSpecializations
if not mop_500 then
	GetNumSpecializations = GetNumTalentTabs
end

local _,player_class = UnitClass('player')
local _,player_race = UnitRace('player')
local player_faction = UnitFactionGroup('player')

--- Return the DB dictionary for the specified filter.
-- Filter Types should use this to get their db.
-- @param filter the name of the filter
-- @usage local db = PitBull4_Aura:GetFilterDB("myfilter")
-- @return the DB dictionrary for the specified filter or nil
function PitBull4_Aura:GetFilterDB(filter)
	return self.db.profile.global.filters[filter]
end

-- Return true if the talent matching the name of the spell given by
-- spellid has at least one point spent in it or false otherwise
local function scan_for_known_talent(spellid)
	if mop_500 then
		return IsPlayerSpell(spellid)
	end
	local wanted_name = GetSpellInfo(spellid)
	if not wanted_name then return nil end
	local num_tabs = GetNumSpecializations()
	for t=1, num_tabs do
		local num_talents = GetNumTalents(t)
		for i=1, num_talents do
			local name_talent, _, _, _, current_rank = GetTalentInfo(t,i)
			if name_talent and (name_talent == wanted_name) then
				if current_rank and (current_rank > 0) then
					return true
				else
					return false
				end
			end
		end
	end
	return false
end

-- Setup the data for who can dispel what types of auras.
-- dispel in this context means remove from friendly players
local can_dispel = {
	DEATHKNIGHT = {},
	DRUID = {
		Curse = not mop_500 or scan_for_known_talent(88423),
		Poison = not mop_500 or scan_for_known_talent(88423),
		Magic = scan_for_known_talent(88423),
	},
	HUNTER = {},
	MAGE = {
		Curse = true,
	},
	PALADIN = {
		Magic = scan_for_known_talent(53551),
		Poison = true,
		Disease = true,
	},
	PRIEST = {
		Magic = true,
		Disease = scan_for_known_talent(527),
	},
	ROGUE = {},
	SHAMAN = {
		Curse = true,
		Magic = scan_for_known_talent(77130),
	},
	WARLOCK = {},
	WARRIOR = {},
	MONK = {
		Poison = true,
		Disease = true,
		Magic = scan_for_known_talent(115451)
	},
}
can_dispel.player = can_dispel[player_class]
PitBull4_Aura.can_dispel = can_dispel

-- Setup the data for who can purge what types of auras.
-- purge in this context means remove from enemies.
local can_purge = {
	DEATHKNIGHT = {},
	DRUID = {
		Enrage = true,
	},
	HUNTER = {
		Magic = true,
		Enrage = true,
	},
	MAGE = {
		Magic = true,
	},
	PALADIN = {},
	PRIEST = {
		Magic = true,
	},
	ROGUE = {
		Enrage = true,
	},
	SHAMAN = {
		Magic = true,
	},
	WARLOCK = {
		Magic = true,
	},
	WARRIOR = {
		Magic = true,
	},
	MONK = {},
}
can_purge.player = can_purge[player_class]
PitBull4_Aura.can_purge = can_purge

-- Handle PLAYER_TALENT_UPDATE event .
-- Rescan the talents for the relevent talents that change
-- what we can dispel.
function PitBull4_Aura:PLAYER_TALENT_UPDATE(event)
	local monk_magic = scan_for_known_talent(115451)
	can_dispel.MONK.Magic = monk_magic
	self:GetFilterDB('//3').aura_type_list.Magic = monk_magic

	local shaman_magic = scan_for_known_talent(77130)
	can_dispel.SHAMAN.Magic = shaman_magic 
	self:GetFilterDB('23').aura_type_list.Magic = shaman_magic

	local druid_magic = scan_for_known_talent(88423)
	can_dispel.DRUID.Magic = druid_magic
	self:GetFilterDB(',3').aura_type_list.Magic = druid_magic
	if mop_500 then
		can_dispel.DRUID.Curse = druid_magic
		can_dispel.DRUID.Poison = druid_magic
		self:GetFilterDB(',3').aura_type_list.Curse = druid_magic
		self:GetFilterDB(',3').aura_type_list.Poison = druid_magic
	end

	local paladin_magic = scan_for_known_talent(53551)
	can_dispel.PALADIN.Magic = paladin_magic
	self:GetFilterDB('/3').aura_type_list.Magic = paladin_magic
end

-- Setup the data for which auras belong to whom
local friend_buffs,friend_debuffs,self_buffs,self_debuffs,pet_buffs,enemy_debuffs = {},{},{},{},{},{}

-- DEATHKNIGHT
friend_buffs.DEATHKNIGHT = {
	[53137] = not mop_500 or nil, -- Abomination's Might
	[57330] = true, -- Horn of Winter
	[49016] = true, -- Hysteria
	[3714]  = true, -- Path of Frost
	[55610] = mop_500 or nil, -- Unholy Aura
	[49016] = true, -- Unholy Frenzy
}
friend_debuffs.DEATHKNIGHT = {}
self_buffs.DEATHKNIGHT = {
	[48707] = true, -- Anti-Magic Shell
	[42650] = true, -- Army of the Dead
	[49222] = true, -- Bone Shield
	[81141] = true, -- Crimson Scourge
	[49028] = true, -- Dancing Rune Weapon
	[59052] = true, -- Freezing Fog (Rime)
	[48266] = true, -- Frost Presence
	[48792] = true, -- Icebound Fortitude
	[51124] = true, -- Killing Machine
	[49039] = true, -- Lichborne
	[51271] = true, -- Pillar of Frost
	[50421] = true, -- Scent of Blood
	[81340] = true, -- Sudden Doom
	[49206] = true, -- Summon Gargoyle (TODO: Is this an enemy debuff or self buff?)
	[55233] = true, -- Vampiric Blood
	[93099] = true, -- Vengeance
	[51271] = true, -- Unbreakable Armor
	[48265] = true, -- Unholy Presence
}
self_debuffs.DEATHKNIGHT = {}
pet_buffs.DEATHKNIGHT = {
	[63560] = true, -- Dark Transformation
	[91342] = true, -- Shadow Infusion
	[19705] = true, -- Well Fed
}
enemy_debuffs.DEATHKNIGHT = {
	[55078] = true, -- Blood Plague
	[48263] = true, -- Blood Presence
	[45524] = true, -- Chains of Ice
	[111673] = mop_500 or nil, -- Control Undead (TODO: Check where this really applies, could show on friendly pet as well)
	[56222] = true, -- Dark Command
	[77606] = true, -- Dark Simulacrum
	[43265] = true, -- Death and Decay
	[55095] = true, -- Frost Fever
	[49203] = not mop_500 or nil, -- Hungering Cold
	[73975] = true, -- Necrotic Strike
	[81326] = mop_500 or nil, -- Physical Vulnerability (from Brittle Bones and Ebon Plaguebringer)
	[47476] = true, -- Strangulate
	[130735] = mop_500 or nil, -- Soul Reaper (TODO: Find the 50% haste buff associated with this)
	[49206] = true, -- Summon Gargoyle
	[50536] = not mop_500 or nil, -- Unholy Blight
	[115798] = mop_500 or nil, -- Weakened Blows (from Scarlet Fever)
}

-- DRUID
friend_buffs.DRUID = {
	[2893]  = not cata_400 or nil, -- Abolish Poison
	[21849] = not cata_400 or nil, -- Gift of the Wild
	[29166] = true, -- Innervate
	[17007] = true, -- Leader of the Pack
	[33763] = true, -- Lifebloom
	[48496] = not mop_500 or nil, -- Living Seed
	[1126]  = true, -- Mark of the Wild
	[24907] = true, -- Moonkin Aura
	[8936]  = true, -- Regrowth
	[774]   = true, -- Rejuvenation
	[57669] = cata_400 or nil, -- Replenishment
	[77764] = cata_400 or nil, -- Stampeding Roar
	[467]   = not mop_500 or nil, -- Thorns
	[740]   = true, -- Tranquility
	[5420]  = true, -- Tree of Life
	[48438] = true, -- Wild Growth
}
friend_debuffs.DRUID = {}
self_buffs.DRUID = {
	[1066]  = true, -- Aquatic Form
	[20655] = true, -- Barkskin
	[50334] = true, -- Berserk
	[5487]  = true, -- Bear Form
	[768]   = true, -- Cat Form
	[12536] = not mop_500 or nil, -- Clearcasting
	[1850]  = true, -- Dash
	[9634]  = not cata_400 or nil, -- Dire Bear Form
	[48517] = true, -- Eclipse (Solar)
	[48518] = true, -- Eclipse (Lunar)
	[3019]  = true, -- Enrage
	[33943] = true, -- Flight Form
	[22842] = true, -- Frenzied Regeneration
	[81093] = not mop_500 and cata_400 or nil, -- Fury of Stormrage
	[81006] = not mop_500 and cata_400 or nil, -- Lunar Shower
	[24858] = true, -- Moonkin Form
	[33883] = not cata_400 or nil, -- Natural Perfection
	[16880] = not mop_500 or nil, -- Nature's Grace
	[16689] = true, -- Nature's Grasp
	[16188] = true, -- Nature's Swiftness
	[16864] = true, -- Omen of Clarity
	[48389] = not mop_500 or nil, -- Owlkin Frenzy
	[5215]  = true, -- Prowl
	[80951] = not mop_500 and cata_400 or nil, -- Pulverize
	[62606] = true, -- Savage Defense
	[52610]	= true, -- Savage Roar
	[81021] = not mop_500 and cata_400 or nil, -- Stampede
	[48505] = true, -- Starfall
	[93400] = cata_400 or nil, -- Shooting Stars
	[61336] = true, -- Survival Instincts
	[40120] = true, -- Swift Flight Form
	[5217]  = true, -- Tiger's Fury
	[5225]  = true, -- Track Humanoids
	[783]   = true, -- Travel Form
}
self_debuffs.DRUID = {}
pet_buffs.DRUID = {}
enemy_debuffs.DRUID = {
	[5211]  = true, -- Bash
	[5209]  = not mop_500 or nil, -- Challenging Roar
	[29538] = true, -- Cyclone
	[99]    = true, -- Demoralizing Roar
	[339]   = true, -- Entangling Roots
	[48506] = not mop_500 or nil, -- Earth and Moon
	[770]   = true, -- Faerie Fire
	[16857] = not mop_500 or nil, -- Faerie Fire (Feral)
	[16979] = true, -- Feral Charge
	[2637]  = true, -- Hibernate
	[16914] = true, -- Hurricane
	[48483] = not mop_500 or nil, -- Infected Wounds
	[5570]  = true, -- Insect Swarm
	[5422]  = true, -- Lacerate
	[22570] = true, -- Maim
	[33878] = true, -- Mangle (Bear)
	[33876] = true, -- Mangle (Cat)
	[563]   = not mop_500 or nil, -- Moonfire
	[9005]  = true, -- Pounce
	[1822]  = true, -- Rake
	[1079]  = true, -- Rip
	[80964] = cata_400 or nil, -- Skull Bash
	[2908]  = true, -- Soothe Animal
	[81261] = cata_400 or nil, -- Solar Beam
	[93402] = cata_400 or nil, -- Sunfire
	[77758] = cata_400 or nil, -- Thrash
}

-- HUNTER
friend_buffs.HUNTER = {
	[13159] = true, -- Aspect of the Pack
	[20043] = not mop_500 or nil, -- Aspect of the Wild
	[34455] = not cata_400 or nil, -- Ferocious Inspiration
	[34477] = true, -- Misdirection
	[19578] = not mop_500 or nil, -- Spirit Bond
	[19506] = true, -- Trueshot Aura
	[57669] = true, -- Replenishment
	[54216] = true, -- Master's Call
}
friend_debuffs.HUNTER = {}
self_buffs.HUNTER = {
	[13161] = not cata_400 or nil, -- Aspect of the Beast
	[5118]  = true, -- Aspect of the Cheetah
	[61846] = not cata_400 or nil, -- Aspect of the Dragonhawk
	[13165] = true, -- Aspect of the Hawk
	[13163] = not cata_400 or nil, -- Aspect of the Monkey
	[34074] = not cata_400 or nil, -- Aspect of the Viper
	[19263] = true, -- Deterrence
	[6197]  = true, -- Eagle Eye
	[1002]  = not cata_400 or nil, -- Eyes of the Beast
	[5384]  = true, -- Feign Death
	[34506] = true, -- Master Tactician
	[6150]  = true, -- Quick Shots
	[3045]  = true, -- Rapid Fire
	[34948] = not mop_500 or nil, -- Rapid Killing
	[34471] = true, -- The Beast Within
}
self_debuffs.HUNTER = {}
pet_buffs.HUNTER = {
	[19574] = true, -- Bestial Wrath
	[3385]  = true, -- Boar Charge
	[1850]  = true, -- Dash
	[23145] = true, -- Dive
	[1539]  = true, -- Feed Pet Effect
	[19451] = true, -- Frenzy
	[3149]  = true, -- Furious Howl
	[136]   = true, -- Mend Pet
	[5215]  = true, -- Prowl
	[26064] = true, -- Shell Shield
	[32920] = true, -- Warp
	[19705] = true, -- Well Fed
}
enemy_debuffs.HUNTER = {
	[19434] = true, -- Aimed Shot
	[1462]  = true, -- Beast Lore
	[3385]  = true, -- Boar Charge
	[53359]	= not cata_400 or nil, -- Chimera Shot - Scorpid
	[35100] = not mop_500 or nil, -- Concussive Barrage
	[5116]  = true, -- Concussive Shot
	[19306] = not mop_500 or nil, -- Counterattack
	[3408]  = true, -- Crippling Poison
	[2818]  = true, -- Deadly Poison
	[19184] = true, -- Entrapment
	[13812] = true, -- Explosive Trap Effect
	[7140]  = true, -- Expose Weakness
	[34889] = true, -- Fire Breath
	[1543]  = true, -- Flare
	[3355]  = true, -- Freezing Trap Effect
	[13810] = true, -- Frost Trap Aura
	[1853]  = not mop_500 or nil, -- Growl
	[1130]  = true, -- Hunter's Mark
	[19407] = not cata_400 or nil, -- Improved Concussive Shot
	[7093]  = true, -- Intimidation
	[5760]  = true, -- Mind-numbing Poison
	[32093] = true, -- Poison Spit
	[1513]  = true, -- Scare Beast
	[19503] = true, -- Scatter Shot
	[6411]  = true, -- Scorpid Poison
	[3043]  = not cata_400 or nil, -- Scorpid Sting
	[24423] = true, -- Screech
	[1978]  = true, -- Serpent Sting
	[34490] = true, -- Silencing Shot
	[1515]  = true, -- Tame Beast
	[3034]  = not cata_400 or nil, -- Viper Sting
	[2974]  = not mop_500 or nil, -- Wing Clip
	[19386] = true, -- Wyvern Sting
}

-- MAGE
friend_buffs.MAGE = {
	[1008]  = not cata_400 or nil, -- Amplify Magic
	[23028] = not cata_400 or nil, -- Arcane Brilliance
	[1459]  = true, -- Arcane Intellect
	[61316] = true, -- Dalaran Brilliance
	[61024] = not cata_400 or nil, -- Dalaran Intellect
	[54648] = not mop_500 or nil, -- Focus Magic
	[604]   = not cata_400 or nil, -- Dampen Magic
	[130]   = true, -- Slow Fall
	[57669] = true, -- Replenishment
}
friend_debuffs.MAGE = {}
self_buffs.MAGE = {
	[31571] = not mop_500 or nil, -- Arcane Potency
	[12042] = true, -- Arcane Power
	[31641] = not mop_500 or nil, -- Blazing Speed
	[1953]  = true, -- Blink
	[12536] = not mop_500 or nil, -- Clearcasting
	[11129] = true, -- Combustion
	[12051] = true, -- Evocation
	[543]   = not mop_500 or nil, -- Fire Ward
	[57761] = true, -- Fireball! (instant cast fireball proc from Brain Freeze)
	[54741] = not mop_500 or nil, -- Firestarter
	[44440] = not mop_500 or nil, -- Firey Payback
	[168]   = not cata_400 or nil, -- Frost Armor
	[6143]  = not cata_400 or nil, -- Frost Ward
	[44445] = not mop_500 or nil, -- Hot Streak
	[7302]  = true, -- Ice Armor
	[11426] = true, -- Ice Barrier
	[27619] = true, -- Ice Block
	[44394] = not mop_500 or nil, -- Incanter's Absorption
	[66]    = true, -- Invisibility
	[6117]  = true, -- Mage Armor
	[1463]  = true, -- Mana Shield
	[44401] = not cata_400 or nil, -- Missile Barrage
	[30482] = true, -- Molten Armor
	[12043] = true, -- Presence of Mind
}
self_debuffs.MAGE = {
	[10833] = true, -- Arcane Blast
	[41425] = true, -- Hypothermia
}
pet_buffs.MAGE = {}
enemy_debuffs.MAGE = {
	[11113]	= true, -- Blast Wave
	[10]    = true, -- Blizzard
	[6136]  = true, -- Chilled
	[120]   = true, -- Cone of Cold
	[44572] = true, -- Deep Freeze
	[29964] = true, -- Dragon's Breath
	[22959] = not mop_500 or nil, -- Fire Vulnerability
	[133]   = true, -- Fireball
	[2120]  = true, -- Flamestrike
	[168]   = not cata_400 or nil, -- Frost Armor
	[122]   = true, -- Frost Nova
	[11071] = not cata_400 or nil, -- Frostbite
	[116]   = true, -- Frostbolt
	[7302]  = true, -- Ice Armor
	[3261]  = true, -- Ignite
	[11103] = not mop_500 or nil, -- Impact
	[18469] = not mop_500 or nil, -- Silenced - Improved Counterspell
	[44457] = true, -- Living Bomb
	[118]   = true, -- Polymorph
	[11366] = true, -- Pyroblast
	[246]   = true, -- Slow
	[11180] = not mop_500 or nil, -- Winter's Chill
}

-- PALADIN
friend_buffs.PALADIN = {
	[64364]	= true, -- Aura Mastery
	[53563] = true, -- Beacon of Light
	[20217] = true, -- Blessing of Kings
	[19740] = true, -- Blessing of Might
	[20911] = not mop_500 or nil, -- Blessing of Sanctuary
	[19742] = not cata_400 or nil, -- Blessing of Wisdom
	[19746] = not mop_500 or nil, -- Concentration Aura
	[32223] = true, -- Crusader Aura
	[465]   = not mop_500 or nil, -- Devotion Aura
	[19752] = not cata_400 or nil, -- Divine Intervention
	[19891] = not mop_500 or nil, -- Fire Resistance Aura
	[19888] = not cata_400 or nil, -- Frost Resistance Aura
	[25898] = not cata_400 or nil, -- Greater Blessing of Kings
	[25782] = not cata_400 or nil, -- Greater Blessing of Might
	[25899] = not cata_400 or nil, -- Greater Blessing of Sanctuary
	[25894] = not cata_400 or nil, -- Greater Blessing of Wisdom
	[1044]  = true, -- Hand of Freedom
	[1022]  = true, -- Hand of Protection
	[6940]  = not cata_400 or nil, -- Hand of Sacrifice
	[20233]	= not cata_400 or nil, -- Improved Lay on Hands
	[7294]  = not mop_500 or nil, -- Retribution Aura
	[53659]	= not cata_400 or nil, -- Sacred Cleansing
	[53601] = not cata_400 or nil, -- Sacred Shield
	[58597]	= not cata_400 or nil, -- Sacred Shield Proc
	[19876] = not cata_400 or nil, -- Shadow Resistance Aura
	[54203]	= not cata_400 or nil, -- Sheath of Light
	[57669] = true, -- Replenishment
}
friend_debuffs.PALADIN = {
	[25771] = true, -- Forbearance
}
self_buffs.PALADIN = {
	[31884] = true, -- Avenging Wrath
	[20216] = not cata_400 or nil, -- Divine Favor
	[31842] = true, -- Divine Illumination
	[54428]	= true, -- Divine Plea
	[498]   = true, -- Divine Protection
	[64205]	= not mop_500 or nil, -- Divine Sacrifice
	[642]   = true, -- Divine Shield
	[9800]  = true, -- Holy Shield
	[54149]	= true, -- Infusion of Light
	[54153]	= not cata_400 or nil, -- Judgements of the Pure
	[31834]	= not cata_400 or nil, -- Light's Grace
	[20178]	= not mop_500 or nil, -- Reckoning
	[25780] = true, -- Righteous Fury
	[31892] = not cata_400 and player_race == "BloodElf" or nil, -- Seal of Blood
	[20375] = not cata_400 or nil, -- Seal of Command
	[53736] = not cata_400 and player_race == "BloodElf" or nil, -- Seal of Corruption
	[20164] = true, -- Seal of Justice
	[20165] = true, -- Seal of Light
	[53720] = not cata_400 and (player_race == "Human" or player_race == "Dwarf" or player_race == "Draenei") or nil, -- Seal of the Martyr
	[20154] = true, -- Seal of Righteousness
	[31801] = true, -- Seal of Truth 
	[20166] = not cata_400 or nil, -- Seal of Wisdom
	[5502]  = not mop_500 or nil, -- Sense Undead
	[23214] = true, -- Summon Charger
	[13819] = true, -- Summon Warhorse
	[53489]	= not cata_400 or nil, -- The Art of War
}
self_debuffs.PALADIN = {}
pet_buffs.PALADIN = {}
enemy_debuffs.PALADIN = {
	[31935] = true, -- Avenger's Shield
	[53742] = not cata_400 and player_race == "BloodElf" or nil, -- Dot, from Seal of Corruption (Blood Corruption)
	[31803] = true, -- Dot, from Seal of Truth (Censure)
	[20116] = not mop_500 or nil, -- Consecration
	[853]   = true, -- Hammer of Justice
	[21183]	= not cata_400 or nil, -- Heart of the Crusader
	[31803] = player_race == "Human" or player_race == "Dwarf" or player_race == "Draenei", -- Dot from, Seal of Vengeance (Holy Vengeance)
	[20184] = not cata_400 or nil, -- Judgement of Justice
	[20185] = not cata_400 or nil, -- Judgement of Light
	[20186] = not cata_400 or nil, -- Judgement of Wisdom
	[20066] = true, -- Repentance
	[61840] = not cata_400 or nil, -- Righteous Vengeance
	[25]    = true, -- Stun, from Seal of Justice
	[10326] = true, -- Turn Evil
	[67]	= not cata_400 or nil, -- Vindication (pre-Cata)
	[26017] = cata_400 or nil, -- Vindication (Cataclysm)
}


-- PRIEST
friend_buffs.PRIEST = {
	[552]   = not cata_400 or nil, -- Abolish Disease
	[47753]	= true, -- Divine Aegis
	[64843] = true, -- Divine Hymn
	[14752] = not cata_400 or nil, -- Divine Spirit
	[6346]  = true, -- Fear Ward
	[56161] = not mop_500 or nil, -- Glyph of Prayer of Healing
	[47930]	= not mop_500 or nil, -- Grace
	[47788]	= true, -- Guardian Spirit
	[64901] = true, -- Hymn of Hope
	[14892] = not mop_500 or nil, -- Inspiration
	[1706]  = true, -- Levitate
	[7001]	= true, -- Lightwell Renew
	[10060] = true, -- Power Infusion
	[1243]  = not cata_400 or nil, -- Power Word: Fortitude
	[17]    = true, -- Power Word: Shield
	[21562] = true, -- Prayer of Fortitude
	[33206] = true, -- Pain Suppression
	[33076] = true, -- Prayer of Mending
	[27683] = not mop_500 or nil, -- Prayer of Shadow Protection
	[27681] = not cata_400 or nil, -- Prayer of Spirit
	[139]   = true, -- Renew
	[63944] = not cata_400 or nil, -- Renewed Hope
	[976]   = not cata_400 or nil, -- Shadow Protection
	[57669] = true, -- Replenishment
}
friend_debuffs.PRIEST = {
	[2096]  = true, -- Mind Vision
	[6788]  = true, -- Weakened Soul
}
self_buffs.PRIEST = {
	[27811] = not mop_500 or nil, -- Blessed Recovery
	[33143]	= not mop_500 or nil, -- Blessed Resilience
	[59887]	= not mop_500 or nil, -- Borrowed Time
	[47585] = true, -- Dispersion
	[586]   = true, -- Fade
	[14743] = not cata_400 or nil, -- Focused Casting
	[45237]	= not cata_400 or nil, -- Focused Will
	[34754]	= not cata_400 or nil, -- Holy Concentration 
	[588]   = true, -- Inner Fire
	[14751] = not mop_500 or nil, -- Inner Focus
	[2096]  = true, -- Mind Vision
	[63731]	= not mop_500 or nil, -- Serendipity
	[15258] = not cata_400 or nil, -- Shadow Weaving
	[15473] = true, -- Shadowform
	[27827] = true, -- Spirit of Redemption
	[88690]	= not mop_500 or nil, -- Surge of Light
}
self_debuffs.PRIEST = {}
pet_buffs.PRIEST = {}
enemy_debuffs.PRIEST = {
	[2944]  = true, -- Devouring Plague
	[14914] = true, -- Holy Fire
	[605]   = true, -- Mind Control
	[15407] = true, -- Mind Flay
	[49821]	= true, -- Mind Sear
	[453]   = not mop_500 or nil, -- Mind Soothe
	[48301] = not mop_500 or nil, -- Mind Trauma (debuff from Improved Mind Blast talent)
	[2096]  = true, -- Mind Vision
	[33196]	= not mop_500 or nil, -- Misery
	[64058] = true, -- Psychic Horror
	[8122]  = true, -- Psychic Scream
	[9484]  = true, -- Shackle Undead
	[15258] = not cata_400 or nil, -- Shadow Vulnerability
	[589]   = true, -- Shadow Word: Pain
	[6726]  = true, -- Silence
	[15286] = true, -- Vampiric Embrace
	[34914] = true, -- Vampiric Touch
}

-- ROGUE
friend_buffs.ROGUE = {
	[57934] = true, -- Tricks of the Trade
}
friend_debuffs.ROGUE = {}
self_buffs.ROGUE = {
	[13750] = true, -- Adrenaline Rush
	[13877] = true, -- Blade Flurry
	[31224] = true, -- Cloak of Shadows
	[14177] = not mop_500 or nil, -- Cold Blood
	[4086]  = true, -- Evasion
	[14278] = not cata_400 or nil, -- Ghostly Strike
	[51662] = not cata_400 or nil, -- Hunger For Blood
	[14143] = not mop_500 or nil, -- Remorseless
	[36554] = true, -- Shadowstep
	[5171]  = true, -- Slice and Dice
	[2983]  = true, -- Sprint
	[1784]  = true, -- Stealth
	[1856]  = true, -- Vanish
}
self_debuffs.ROGUE = {}
pet_buffs.ROGUE = {}
enemy_debuffs.ROGUE = {
	[51585] = not mop_500 or nil, -- Blade Twisting
	[2094]  = true, -- Blind
	[1833]  = true, -- Cheap Shot
	[3408]  = true, -- Crippling Poison
	[2818]  = true, -- Deadly Poison
	[26679] = true, -- Deadly Throw
	[8647]  = true, -- Expose Armor
	[91023] = true, -- Find Weakness
	[703]   = true, -- Garrote
	[1330]  = true, -- Garrote - Silence
	[1776]  = true, -- Gouge
	[16511] = true, -- Hemorrhage
	[18425] = not mop_500 or nil, -- Kick - Silenced
	[408]   = true, -- Kidney Shot
	[5530]  = not cata_400 or nil, -- Mace Stun Effect
	[5760]  = true, -- Mind-numbing Poison
	[84617] = true, -- Revealing Strike
	[14251] = not mop_500 or nil, -- Riposte
	[1943]  = true, -- Rupture
	[6770]  = true, -- Sap
	[51693] = not mop_500 or nil, -- Waylay
	[13218] = not mop_500 or nil, -- Wound Poison
}

-- SHAMAN
friend_buffs.SHAMAN = {
	[16177] = not mop_500 or nil, -- Ancestral Fortitude
	[2825]  = player_race == "Troll" or player_race == "Tauren" or player_race == "Orc" or player_race == "Goblin" or (player_faction == "Horde" and player_race == "Pandaren"), -- Bloodlust
	[77747] = true, -- Burning Wrath
	[379]   = true, -- Earth Shield
	[51945] = true, -- Earthliving
	[51466] = not mop_500 or nil, -- Elemental Oath
	[4057]  = true, -- Fire Resistance
	[8227]  = not mop_500 or nil, -- Flametongue Totem
	[4077]  = true, -- Frost Resistance
	[8178]  = true, -- Grounding Totem Effect
	[5672]  = true, -- Healing Stream
	[29202] = not mop_500 or nil, -- Healing Way
	[23682] = player_race == "Draenei" or player_race == "Dwarf" or (player_faction == "Alliance" and player_race == "Pandaren"), -- Heroism
	[5677]  = not mop_500 or nil, -- Mana Spring
	[16191] = true, -- Mana Tide
	[4081]  = true, -- Nature Resistance
	[61295] = true, -- Riptide
	[8072]  = not mop_500 or nil, -- Stoneskin
	[8076]  = not mop_500 or nil, -- Strength of Earth
	[30706] = not cata_400 or nil, -- Totem of Wrath
	[131]   = not mop_500 or nil, -- Water Breathing
	[546]   = true, -- Water Walking
	[27621] = true, -- Windfury Totem
	[2895]  = not mop_500 or nil, -- Wrath of Air Totem
}
friend_debuffs.SHAMAN = {
	[57723] = player_race == "Draenei" or player_race == "Dawrf" or (player_faction == "Alliance" and player_race == "Pandaren"), -- Exhaustion
	[57724] = player_race == "Troll" or player_race == "Tauren" or player_race == "Orc" or player_race == "Goblin" or (player_faction == "Horde" and player_race == "Pandaren"), -- Sated
}
self_buffs.SHAMAN = {
	[52179] = not mop_500 or nil, -- Astral Shift
	[12536] = not mop_500 or nil, -- Clearcasting
	[29177] = not cata_400 or nil, -- Elemental Devastation
	[16166] = true, -- Elemental Mastery
	[6196]  = true, -- Far Sight
	[14743] = not cata_400 or nil, -- Focused Casting
	[2645]  = true, -- Ghost Wolf
	[324]   = true, -- Lightning Shield
	[53817] = true, -- Maelstrom Weapon
	[16188] = true, -- Nature's Swiftness
	[6495]  = not cata_400 or nil, -- Sentry Totem
	[43339] = not mop_500 or nil, -- Shamanistic Focus (Focused)
	[30823] = true, -- Shamanistic Rage
	[55166] = not mop_500 or nil, -- Tidal Force
	[53390] = true, -- Tidal Waves
	[52127] = true, -- Water Shield
	[16257]	= not mop_500 or nil, -- Flurry
	[58875]	= true, -- Spirit Walk
}
self_debuffs.SHAMAN = {}
pet_buffs.SHAMAN = {
	[58875]	= true, -- Spirit Walk
}
enemy_debuffs.SHAMAN = {
	[76780] = true, -- Bind Elemental
	[3600]  = true, -- Earthbind
	[8050]  = true, -- Flame Shock
	[8056]  = true, -- Frost Shock
	[8034]  = true, -- Frostbrand Attack
	[39796] = not mop_500 or nil, -- Stoneclaw Stun
	[17364] = true, -- Stormstrike
	[30708]	= not cata_400 or nil, -- Totem of Wrath
	[51514]	= true, -- Hex
	[58861]	= not mop_500 or nil, -- Bash
}

-- WARLOCK
friend_buffs.WARLOCK = {
	[6307]  = true, -- Blood Pact
	[132]   = not cata_400 or nil, -- Detect Invisibility
	[134]   = true, -- Fire Shield
	[54424] = not mop_500 or nil, -- Fel Intelligence
	[20707] = true, -- Soulstone Resurrection
	[5697]  = true, -- Unending Breath
	[57669] = true, -- Replenishment
}
friend_debuffs.WARLOCK = {}
self_buffs.WARLOCK = {
	[47258] = not mop_500 or nil, -- Backdraft
	[34935] = not mop_500 or nil, -- Backlash
	[63156] = not mop_500 or nil, -- Decimation
	[706]   = not cata_400 or nil, -- Demon Armor
	[687]   = not mop_500 or nil, -- Demon Skin
	[35691] = not mop_500 or nil, -- Demonic Knowledge
	[18788] = not mop_500 or nil, -- Demonic Sacrifice
	[47195] = not mop_500 or nil, -- Eradication
	[28176] = not mop_500 or nil, -- Fel Armor
	[18708] = not mop_500 or nil, -- Fel Domination
	[63321] = not cata_400 or nil, -- Life Tap (Glyph of)
	[23759] = not mop_500 or nil, -- Master Demonologist
	[47245] = not mop_500 or nil, -- Molten Core
	[30299] = not mop_500 or nil, -- Nether Protection
	[1050]  = true, -- Sacrifice
	[5500]  = not cata_400 or nil, -- Sense Demons
	[17941] = true, -- Shadow Trance
	[6229]  = true, -- Shadow Ward
	[19028] = not mop_500 or nil, -- Soul Link
	[23161] = true, -- Summon Dreadsteed
	[1710]  = not mop_500 or nil, -- Summon Felsteed
	[47241]	= not mop_500 or nil, -- Metamorphosis
}
self_debuffs.WARLOCK = {}
pet_buffs.WARLOCK = {
	[23257] = true, -- Demonic Frenzy
	[19705] = true, -- Well Fed
}
enemy_debuffs.WARLOCK = {
	[18118] = not mop_500 or nil, -- Aftermath
	[80240] = cata_400 or nil, -- Bane of Havoc
	[710]   = true, -- Banish
	[91986] = not mop_500 and cata_400 or nil, -- Burning Embers
	[172]   = true, -- Corruption
	[89]    = true, -- Cripple
	[980]   = true, -- Curse of Agony
	[603]   = true, -- Curse of Doom
	[18223] = true, -- Curse of Exhaustion
	[1714]  = not mop_500 or nil, -- Curse of Tongues
	[702]   = not mop_500 or nil, -- Curse of Weakness
	[1490]  = true, -- Curse of the Elements
	[6789]  = true, -- Death Coil
	[689]   = true, -- Drain Life
	[5138]  = not cata_406 or nil, -- Drain Mana
	[1120]  = true, -- Drain Soul
	[5782]  = true, -- Fear
	[48181] = true, -- Haunt
	[1949]  = true, -- Hellfire
	[5484]  = true, -- Howl of Terror
	[348]   = true, -- Immolate
	[1122]  = true, -- Inferno
	[22703] = true, -- Internal Awakening
	[85547] = not mop_500 and cata_400 or nil, -- Jinx
	[18073] = not cata_400 or nil, -- Pyroclasm
	[4629]  = true, -- Rain of Fire
	[6358]  = true, -- Seduction
	[27243] = true, -- Seed of Corruption
	[32385] = not mop_500 or nil, -- Shadow Embrace
	[17800] = not mop_500 or nil, -- Shadow Mastery
	[17877] = true, -- Shadowburn
	[30283] = true, -- Shadowfury
	[63311] = true, -- Shadowsnare
	[6726]  = true, -- Silence
	[6360]  = true, -- Soothing Kiss
	[19244] = not cata_400 or nil, -- Spell Lock
	[17735] = true, -- Suffering
	[54049] = true, -- Shadow Bite
	[61291] = not cata_400 or nil, -- Shadowflame
	[30108] = true, -- Unstable Affliction
}

-- WARRIOR
friend_buffs.WARRIOR = {
	[2048]  = not cata_400 or nil, -- Battle Shout (3.x)
	[6673]  = cata_400 or nil, -- Battle Shout (4.x)
	[469]   = true, -- Commanding Shout
	[3411]  = true, -- Intervene
	[50720] = not mop_500 or nil, -- Vigilance
}
friend_debuffs.WARRIOR = {}
self_buffs.WARRIOR = {
	[18499] = true, -- Berserker Rage
	[16487] = not mop_500 or nil, -- Blood Craze
	[2687]  = not cata_400 or nil, -- Bloodrage
	[23880] = not mop_500 or nil, -- Bloodthirst
	[3019]  = true, -- Enrage
	[55694]	= true, -- Enraged Regeneration
	[12319] = not mop_500 or nil, -- Flurry
	[12975] = true, -- Last Stand
	[8285]  = true, -- Rampage
	[1719]  = true, -- Recklessness
	[20230] = not mop_500 or nil, -- Retaliation
	[15604] = true, -- Second Wind
	[2565]  = true, -- Shield Block
	[871]   = true, -- Shield Wall
	[9941]  = true, -- Spell Reflection
	[12328] = true, -- Sweeping Strikes
	-- T4, Tank, 2/4 piece bonus
	[37514] = true, -- Blade Turning
	[6572]  = true, -- Revenge
	-- T5, Tank, 2/4 piece bonus
	[37525] = true, -- Battle Rush
	[37523] = true, -- Reinforced Shield
	-- T5, DPS, 2 piece bonus
	[7384]  = true, -- Overpower
	[40729] = true, -- Heightened Reflexes
	[61571] = true, -- Spirits of the Lost
	[46916] = true, -- Slam!
}
self_debuffs.WARRIOR = {
	[12292] = true, -- Death Wish
}
pet_buffs.WARRIOR = {}
enemy_debuffs.WARRIOR = {
	[16952] = not mop_500 or nil, -- Blood Frenzy
	[1161]  = not mop_500 or nil, -- Challenging Shout
	[7922]  = true, -- Charge Stun
	[12809] = not mop_500 or nil, -- Concussion Blow
	[1604]  = true, -- Dazed
	[12721] = not mop_500 or nil, -- Deep Wound
	[1160]  = true, -- Demoralizing Shout
	[676]   = true, -- Disarm
	[1715]  = true, -- Hamstring
	[12289] = not mop_500 or nil, -- Improved Hamstring
	[20253] = not mop_500 or nil, -- Intercept Stun
	[5246]  = true, -- Intimidating Shout
	[5530]  = not cata_400 or nil, -- Mace Stun Effect
	[694]   = not cata_400 or nil, -- Mocking Blow
	[9347]  = true, -- Mortal Strike
	[10576] = true, -- Piercing Howl
	[772]   = not mop_500 or nil, -- Rend
	[12798] = not cata_400 or nil, -- Revenge Stun
	[18498] = true, -- Shield Bash - Silenced
	[7386]  = true, -- Sunder Armor
	[355]   = true, -- Taunt
	[6343]  = true, -- Thunder Clap
}

-- MONK
friend_buffs.MONK = {}
friend_debuffs.MONK= {}
self_buffs.MONK = {}
self_debuffs.MONK = {}
pet_buffs.MONK = {}
enemy_debuffs.MONK = {}

-- Human
friend_buffs.Human = {
	[23333] = true, -- Warsong Flag
}
friend_debuffs.Human = {}
self_buffs.Human = {}
self_debuffs.Human = {}
pet_buffs.Human = {}
enemy_debuffs.Human = {}

-- Dwarf
friend_buffs.Dwarf = {
	[23333] = true, -- Warsong Flag
}
friend_debuffs.Dwarf = {}
self_buffs.Dwarf = {
	[7020] = true, -- Stoneform
}
self_debuffs.Dwarf = {}
pet_buffs.Dwarf = {}
enemy_debuffs.Dwarf = {}

-- NightElf
friend_buffs.NightElf = {
	[23333] = true, -- Warsong Flag
}
friend_debuffs.NightElf = {}
self_buffs.NightElf = {
	[58984] = true, -- Shadowmeld
}
self_debuffs.NightElf = {}
pet_buffs.NightElf = {}
enemy_debuffs.NightElf = {}

-- Gnome
friend_buffs.Gnome = {
	[23333] = true, -- Warsong Flag
}
friend_debuffs.Gnome = {}
self_buffs.Gnome = {}
self_debuffs.Gnome = {}
pet_buffs.Gnome = {}
enemy_debuffs.Gnome = {}

-- Draenei
friend_buffs.Draenei = {
	[28880] = true, -- Gift of the Naaru
	[23333] = true, -- Warsong Flag
}
friend_debuffs.Draenei = {}
self_buffs.Draenei = {}
self_debuffs.Draenei = {}
pet_buffs.Draenei = {}
enemy_debuffs.Draenei = {}

-- Orc
friend_buffs.Orc = {
	[23335] = true, -- Silverwing Flag
}
friend_debuffs.Orc = {}
self_buffs.Orc = {
	[20572] = true, -- Blood Fury
}
self_debuffs.Orc = {
	[20572] = true, -- Blood Fury
}
pet_buffs.Orc = {}
enemy_debuffs.Orc = {}

-- Scourge
friend_buffs.Scourge = {
	[23335] = true, -- Silverwing Flag
}
friend_debuffs.Scourge = {}
self_buffs.Scourge = {
	[20577] = true, -- Cannibalize
	[7744] = true, -- Will of the Forsaken
}
self_debuffs.Scourge = {}
pet_buffs.Scourge = {}
enemy_debuffs.Scourge = {}

-- Tauren
friend_buffs.Tauren = {
	[23335] = true, -- Silverwing Flag
}
friend_debuffs.Tauren = {}
self_buffs.Tauren = {}
self_debuffs.Tauren = {}
pet_buffs.Tauren = {}
enemy_debuffs.Tauren = {
	[45] = true, -- War Stomp
}

-- Troll
friend_buffs.Troll = {
	[23335] = true, -- Silverwing Flag
}
friend_debuffs.Troll = {}
self_buffs.Troll = {
	[26297] = true, -- Berserking
}
self_debuffs.Troll = {}
pet_buffs.Troll = {}
enemy_debuffs.Troll = {}

-- BloodElf
friend_buffs.BloodElf = {
	[23335] = true, -- Silverwing Flag
}
friend_debuffs.BloodElf = {}
self_buffs.BloodElf = {}
self_debuffs.BloodElf = {}
pet_buffs.BloodElf = {}
enemy_debuffs.BloodElf = {
	[25046] = true, -- Arcane Torrent
}

-- Goblin
friend_buffs.Goblin = {
	[23335] = true, -- Silverwing Flag
}
friend_debuffs.Goblin = {}
self_buffs.Goblin = {}
self_debuffs.Goblin = {}
pet_buffs.Goblin = {}
enemy_debuffs.Goblin = {}

-- Worgen
friend_buffs.Worgen = {
	[23333] = true, -- Warsong Flag
}
friend_debuffs.Worgen = {}
self_buffs.Worgen = {
	[68992] = true, -- Darkflight
	[87840] = true, -- Running Wild
}
self_debuffs.Worgen = {}
pet_buffs.Worgen = {}
enemy_debuffs.Worgen = {}

-- Pandaren
friend_buffs.Pandaren = {
	[23335] = player_faction == "Horde", -- Silverwing Flag
	[23333] = player_faction == "Alliance", -- Warsong Flag
}
friend_debuffs.Pandaren = {}
self_buffs.Pandaren = {}
self_debuffs.Pandaren = {}
pet_buffs.Pandaren = {}
enemy_debuffs.Pandaren = {
	[107079] = mop_500 or nil, -- Quaking Palm
}

-- Everyone
local extra_buffs = {
	[34976] = true, -- Netherstorm Flag
}

local function turn(t, shallow)
	local tmp = {}
	local function turn(entry)
		for id,v in pairs(entry) do
			local spell = GetSpellInfo(id)
			if not spell then
				DEFAULT_CHAT_FRAME:AddMessage(string.format("PitBull4_Aura: Unknown spell ID: %d",id))
			else
				tmp[spell] = v
			end
		end
		wipe(entry)
		for spell,v in pairs(tmp) do
			entry[spell] = v
		end
	end
	if shallow then
		turn(t)
		return
	end
	for k in pairs(t) do
		local entry = t[k]
		wipe(tmp)
		turn(entry)
	end
end
turn(friend_buffs)
turn(friend_debuffs)
turn(self_buffs)
turn(self_debuffs)
turn(pet_buffs)
turn(enemy_debuffs)
turn(extra_buffs, true)

PitBull4_Aura.friend_buffs = friend_buffs
PitBull4_Aura.friend_debuffs = friend_debuffs
PitBull4_Aura.self_buffs = self_buffs
PitBull4_Aura.self_debuffs = self_debuffs
PitBull4_Aura.pet_buffs = pet_buffs
PitBull4_Aura.enemy_debuffs = enemy_debuffs
PitBull4_Aura.extra_buffs = extra_buffs

function PitBull4_Aura:FilterEntry(name, entry, frame)
	if not name or name == "" then return true end
	local filter = self:GetFilterDB(name)
	if not filter then return true end
	local filter_func = self.filter_types[filter.filter_type].filter_func
	return filter_func(name, entry, frame)
end
