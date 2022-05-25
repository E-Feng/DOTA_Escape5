local phxTable1 = {}
local phxTable2 = {}

-- This function is the setup for the pheonix
function barebones:PheonixInitial()
  print("Setup for pheonix started")
  local spawn1 = Entities:FindByName(nil, "pheonix1"):GetAbsOrigin()
  local spawn2 = Entities:FindByName(nil, "pheonix2"):GetAbsOrigin()
  local spawns = {spawn1, spawn2}
  local beams = {4, 4}
  local r = 50
  local level = 5

	local angleOffset = 45
	local zSpawn = 100  -- Lowering to the ground a bit, maybe doesnt work

  local triggerList = {"cw1", "ccw1", "cw2", "ccw2"}

  -- Creating the pheonixes
  for i = 1,2 do
    local beam = beams[i]
    local spawn = spawns[i]
    for j = 1,beam do
      local angle = math.rad((360/beam)*(j-1)) + angleOffset
      local pos = Vector(spawn.x + r*math.cos(angle), spawn.y + r*math.sin(angle), zSpawn)
      local unit = CreateUnitByName("npc_pheonix", pos, true, nil, nil, DOTA_TEAM_ZOMBIES)
      unit:SetForwardVector(Vector(math.cos(angle), math.sin(angle), 0))
      local abil = unit:FindAbilityByName("sun_ray_datadriven")
      Timers:CreateTimer(2, function()
        unit:CastAbilityNoTarget(abil, -1)
      end)

      if i == 1 then
        table.insert(phxTable1, unit)
      elseif i == 2 then
        table.insert(phxTable2, unit)
      end

      table.insert(Extras, unit:GetEntityIndex())
    end
  end

  -- Creating the triggers
  Timers:CreateTimer(3, function()
    for i,trigName in pairs(triggerList) do
      local block = Entities:FindByName(nil, trigName)
      block.part = PartList[level][i][PAR_INDEX]
      ParticleManager:SetParticleControl(block.part, 1, Vector(255, 0, 0))

      if string.sub(trigName, -1) == "1" then
        block.pheonixes = phxTable1
        block.spawn = spawn1
      elseif string.sub(trigName, -1) == "2" then
        block.pheonixes = phxTable2
        block.spawn = spawn2
      end
    end
  end)
end

-- Sun ray datadriven scripts
function SunRay(event)
	print("SunRay casted")
	local caster = event.caster
	local abil = event.ability
	local turnrate = event.turn_rate
	local beamrange = event.beam_range
	local partname = "particles/units/heroes/hero_phoenix/phoenix_sunray.vpcf"
	Timers:CreateTimer(0.5, function()
		local endcap = CreateUnitByName("npc_dummy_unit", caster:GetAbsOrigin(), false, caster, caster, caster:GetTeam())
		endcap:FindAbilityByName("dummy_unit"):SetLevel(1)
		local part = ParticleManager:CreateParticle(partname, PATTACH_ABSORIGIN, caster)
		ParticleManager:SetParticleControlEnt(part, 0, caster, PATTACH_POINT_FOLLOW, "attach_hitloc", caster:GetAbsOrigin(), true)
		ParticleManager:SetParticleControl(part, 1, endcap:GetAbsOrigin())
		local endcapSoundName = "Hero_Phoenix.SunRay.Beam"
		StartSoundEvent(endcapSoundName, endcap)
		Timers:CreateTimer(function()
			if IsValidEntity(caster) then
				if caster:HasModifier("modifier_sun_ray") then
					local forw = caster:GetForwardVector()
					local origin = caster:GetAbsOrigin()
					local endcapPos = origin + beamrange * forw
					endcapPos = GetGroundPosition(endcapPos, nil)
					endcapPos.z = endcapPos.z + 92
					endcap:SetAbsOrigin(endcapPos)
					ParticleManager:SetParticleControl(part, 1, endcapPos)
					--print(endcapPos, endcap:GetAbsOrigin())
					return 0.03
				else
					ParticleManager:DestroyParticle(part, false)
					StopSoundEvent(endcapSoundName, endcap)
					endcap:RemoveSelf()
					return
				end
			else
				return
			end
		end)
	end)
end

function SunRayCheck(event)
	local caster = event.caster
	local abil = event.ability
	local radius = event.path_radius - 25
	local beamrange = event.beam_range
	local dmg = event.base_dmg
	local origin = caster:GetAbsOrigin()
	local forw = caster:GetForwardVector()
	local endcap = origin + beamrange * forw
	local table = FindUnitsInLine(DOTA_TEAM_GOODGUYS, 
								  origin, endcap, nil, radius, 
								  DOTA_UNIT_TARGET_TEAM_BOTH, 
								  DOTA_UNIT_TARGET_HERO, 
								  FIND_ANY_ORDER)
	--print(table, #table)
	for i,unit in pairs(table) do
		local damagetable = {victim = unit, 
							 attacker = caster, 
							 damage = dmg, 
							 damage_type = DAMAGE_TYPE_PURE,
							 ability = abil}
		ApplyDamage(damagetable)
	end
end