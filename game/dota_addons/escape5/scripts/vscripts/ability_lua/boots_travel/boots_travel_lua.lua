-- Created by Elfansoer
--[[
Ability checklist (erase if done/checked):
- Scepter Upgrade
- Break behavior
- Linken/Reflect behavior
- Spell Immune/Invulnerable/Invisible behavior
- Illusion behavior
- Stolen behavior
]]
--------------------------------------------------------------------------------
boots_travel_lua = class({})
LinkLuaModifier("modifier_boots_travel_lua", "ability_lua/boots_travel/boots_travel_lua", LUA_MODIFIER_MOTION_NONE)
--------------------------------------------------------------------------------
-- Init Abilities
function boots_travel_lua:Precache( context )
	PrecacheResource( "soundfile", "soundevents/game_sounds_heroes/game_sounds_tinker.vsndevts", context )
	PrecacheResource( "particle", "particles/units/heroes/hero_magnataur/magnataur_skewer.vpcf", context )
	PrecacheResource( "particle", "particles/units/heroes/hero_magnataur/magnataur_skewer_debuff.vpcf", context )
end

-- Modifier for travel boots
modifier_boots_travel_lua = modifier_boots_travel_lua or class({})

function modifier_boots_travel_lua:IsHidden()		  return false end
function modifier_boots_travel_lua:IsPurgable()		return false end
function modifier_boots_travel_lua:RemoveOnDeath()	return false end

function modifier_boots_travel_lua:OnCreated()
  if IsServer() then
    if not self:GetAbility() then self:Destroy() end
  end
end

function modifier_boots_travel_lua:OnDestroy()
  if IsServer() then
    if not self:GetAbility() then self:Destroy() end
  end
end

-- Ability Start
function boots_travel_lua:OnSpellStart()
	-- unit identifier
	local caster = self:GetCaster()
	local target = self:GetCursorTarget()
  local ability = self

	-- Particles
	local particle_caster = "particles/econ/items/tinker/boots_of_travel/teleport_start_bots.vpcf"
	local particle_target = "particles/econ/items/tinker/boots_of_travel/teleport_end_bots.vpcf"

	self.effect_caster = ParticleManager:CreateParticle( particle_caster, PATTACH_ABSORIGIN_FOLLOW, caster)
	self.effect_target = ParticleManager:CreateParticle( particle_target, PATTACH_ABSORIGIN_FOLLOW, target)

	-- Play effects
	local sound_cast = "Hero_Tinker.MechaBoots.Loop"
	EmitSoundOnLocationForAllies( caster:GetOrigin(), sound_cast, caster )

	caster:AddNewModifier(caster, ability, "modifier_boots_travel_lua", {})
end

function boots_travel_lua:OnChannelFinish( bInterrupted )
	local caster = self:GetCaster()
	local target = self:GetCursorTarget()

	ParticleManager:DestroyParticle(self.effect_caster, false)
	ParticleManager:DestroyParticle(self.effect_target, false)

	local sound_cast = "Hero_Tinker.MechaBoots.Loop"
	StopSoundOn( sound_cast, self:GetCaster() )

	Timers:CreateTimer(0.3, function()
		print("Removing travel modifier")
		caster:RemoveModifierByName("modifier_boots_travel_lua")
	end)

	if bInterrupted then
		caster:RemoveModifierByName("modifier_boots_travel_lua")

		return
	end

	local targetPos = target:GetAbsOrigin()
	--caster:SetAbsOrigin(targetPos)
	FindClearSpaceForUnit(caster, targetPos, false)

	Timers:CreateTimer(0.03, function()
		ResolveNPCPositions(targetPos, 50)
	end)
end