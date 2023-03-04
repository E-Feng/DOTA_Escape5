-- This function is for basic patrol thinker
function barebones:PatrolThinker(unit, entvals)
  print("Patrol thinker started on ", unit:GetUnitName(), unit:GetEntityIndex())

  local ms = entvals[PAT_MVSPD]
  local turnDelay = entvals[PAT_TURND] or 0.5
  local delay = math.max(entvals[PAT_DELAY], 0.03)

  local level = unit.level

  -- Setting basic properties
  unit:SetBaseMoveSpeed(ms)

  if unit:FindAbilityByName("kill_radius_lua") then
    unit:FindAbilityByName("kill_radius_lua"):SetLevel(1)
  end

  if ms > 550 then
    unit:AddNewModifier(unit, nil, "modifier_dark_seer_surge", {})
  end

  -- Setting up patrol waypoints
  local patrolIndex = entvals[PAT_VECNM]
  -- For nonpatrolling units
  if patrolIndex == 0 then
    unit:SetForwardVector(RandomVector(1):Normalized())
    return
  end
  
  local waypoints = _G.MultVector[level][patrolIndex]
  unit.waypoints = waypoints

  Patrols:StartPatrol(unit, delay, turnDelay)
end

-- This function is a thinker for a gate to move upon full mana
function barebones:GateThinker(unit, entvals)
  print("Gate Thinker has started on unit", unit:GetUnitName(), "(", unit:GetEntityIndex(), ")")
  local spawn = Entities:FindByName(nil, entvals[ENT_SPAWN]):GetAbsOrigin()
  local forwardVec = entvals[GAT_ORIEN]
  local mana = entvals[GAT_NUMBR]
  local hullRadius = 85

  print("Gate Mana ", mana)

  unit.moved = false

  unit:SetHullRadius(hullRadius)
  unit:SetForwardVector(forwardVec)
  local abil = unit:FindAbilityByName("gate_unit_passive")

  unit:AddNewModifier(unit, nil, "modifier_spectre_spectral_dagger_path_phased", {})
  unit:SetBaseMoveSpeed(100)

  unit:SetMaxMana(mana)

  Timers:CreateTimer(1, function()
    if IsValidEntity(unit) then
      -- print("Has mana?", abil:IsOwnersManaEnough(), unit:GetUnitName(), "(", unit:GetEntityIndex(), ")")
      if unit:GetMana() == mana then
        unit:SetBaseMoveSpeed(100)
        unit:CastAbilityImmediately(abil, -1)
        unit:SetHullRadius(25)
        unit.moved = true
      end

      if not unit.moved then
        if CalcDist2D(unit:GetAbsOrigin(), spawn) > 25 and RandomFloat(0, 1) > 0.75 then
          unit:MoveToPosition(spawn)
        end

        -- Check for phase boots through
        local foundHeroesGate = GetHeroesInsideCircle(unit:GetAbsOrigin(), hullRadius, true)     
        local foundHeroesSpawn = GetHeroesInsideCircle(spawn, hullRadius, true)  

        local foundHeroes = ConcatTables(foundHeroesGate, foundHeroesSpawn)

        for _,hero in pairs(foundHeroes) do
          if hero:GetAbsOrigin().z < 130 then
            local newOrigin = spawn + forwardVec * hullRadius * 1.15
            FindClearSpaceForUnit(hero, newOrigin, true)
          end
        end
      end
      return 0.06
    else
      return
    end
  end)
end

-- This function casts Linas LSA ability
function barebones:CastLSA(unit, castPos, emitSound)
  local partRad = 225
  local killRad = 200

  local part = ParticleManager:CreateParticle("particles/misc/light_strike.vpcf", PATTACH_ABSORIGIN, unit)
  ParticleManager:SetParticleControl(part, 0, castPos)
  ParticleManager:SetParticleControl(part, 1, Vector(partRad, 0, 0))

  if emitSound then
    EmitSoundOnLocationWithCaster(castPos, "Ability.LightStrikeArray", unit)
  end

  local targets = FindUnitsInRadius(DOTA_TEAM_GOODGUYS,
                                    castPos, 
                                    nil, 
                                    killRad, 
                                    DOTA_UNIT_TARGET_TEAM_FRIENDLY, 
                                    DOTA_UNIT_TARGET_HERO, 
                                    DOTA_UNIT_TARGET_FLAG_NONE, 
                                    FIND_ANY_ORDER, 
                                    false)
  for _,target in pairs(targets) do
    --target:SetBaseMagicalResistanceValue(25)
    target:ForceKill(true)
  end
end

-- This function is for the AOE spell caster
function barebones:AOEThinker(unit, entvals)
  print("AOE Thinker has started on unit", unit:GetUnitName(), "(", unit:GetEntityIndex(), ")")
  local pos = Entities:FindByName(nil, entvals[ENT_SPAWN]):GetAbsOrigin()
  local rate = entvals[AOE_RATES]
  local delay = entvals[AOE_DELAY]
  local emitSound = entvals[AOE_SOUND]

  unit:FindAbilityByName("dummy_unit"):SetLevel(1)

  Timers:CreateTimer(delay, function()
    if IsValidEntity(unit) then
      barebones:CastLSA(unit, pos, emitSound)
      return rate
    else
      return
    end
  end)
end

-- This function is for the static zombie thinker
function barebones:StaticThinker(unit, entvals)
  print("Thinker has started on static zombie (", unit:GetEntityIndex(), ")")
  local pos = unit:GetAbsOrigin()
  local minwait = 2
  local maxwait = 5

  unit:FindAbilityByName("kill_radius_lua"):SetLevel(2)
  Timers:CreateTimer(1, function()
    if IsValidEntity(unit) then
      local xrand = RandomFloat(-1, 1)
      local yrand = RandomFloat(-1, 1)
      unit:SetForwardVector(Vector(xrand, yrand, 0))

      if CalcDist2D(unit:GetAbsOrigin(), pos) > 10 then
        Timers:CreateTimer(1, function()
          unit:MoveToPosition(pos)
        end)
      end

      return RandomFloat(minwait, maxwait)
    else
      return
    end
  end)
end

-- This function is for the magnus thinker
function barebones:MagnusThinker(dummyUnit, entvals)
  print("Magnus thinker started")

  local spawn = Entities:FindByName(nil, entvals[ENT_SPAWN]):GetAbsOrigin()
  local goal = Entities:FindByName(nil, entvals[MAG_GOALS]):GetAbsOrigin()
  local rate = entvals[MAG_RATES]
  local delay = entvals[MAG_DELAY]
  local level = dummyUnit.level

  -- Rate<1, spawn, cast, remove magnus, otherwise patrol
  -- Cheap hack for 2 different rates, <1 multiply by 0 and its continously spawn
  if rate < 1 then
    Timers:CreateTimer(1, function()
      if _G.currentLevel == level then
        local unit = CreateUnitByName("npc_magnus", spawn, true, nil, nil, DOTA_TEAM_ZOMBIES)
        unit:SetForwardVector(goal)
        unit.pos = goal

        local abil = unit:FindAbilityByName("magnus_skewer_lua")
        abil:SetLevel(1)

        Timers:CreateTimer(delay + 1, function()
          unit:CastAbilityOnPosition(unit.pos, abil, -1)

          if IsValidEntity(unit) then
            if CalcDist2D(unit:GetAbsOrigin(), unit.pos) < 25 then
              unit:ForceKill(true)
              Timers:CreateTimer(1.8, function()
                unit:RemoveSelf()
                return
              end)
              return
            else
              return 0.5
            end
          else
            return
          end
        end)

        return rate*10
      else
        return
      end
    end)
  else
    local unit = CreateUnitByName("npc_magnus", spawn, true, nil, nil, DOTA_TEAM_ZOMBIES)
    local abil = unit:FindAbilityByName("magnus_skewer_lua")
    abil:SetLevel(1)
    unit.pos = goal

    table.insert(Extras, unit:GetEntityIndex())

    Timers:CreateTimer(delay + 0.06, function()
      if IsValidEntity(unit) then
        unit:CastAbilityOnPosition(unit.pos, abil, -1)
  
        unit.pos = unit.pos == spawn and goal or spawn
        return rate
      else
        return
      end
    end)
  end
end

-- This function is for creating a multi wall patrol
function barebones:WallPatrolThinker(dummyUnit, entvals)
  print("Multi wall patrol started")

  local units = {}

  local defaultSpacing = 75
  local radii = entvals[MLT_RADII] 
  local spacing = (entvals[MLT_SPACE] == 0) and defaultSpacing or entvals[MLT_SPACE]
  local ms = entvals[MLT_MVSPD]
  local level = dummyUnit.level
  local spawn = Entities:FindByName(nil, entvals[ENT_SPAWN]):GetAbsOrigin()
  local goal = Entities:FindByName(nil, entvals[MLT_GOALS]):GetAbsOrigin()

  -- Generating spawn/goal table for units
  local spawnTb, goalTb = Patrols:GenerateMovingWallPositions(spawn, goal, radii, spacing)

  -- Creating units along the line, lots of geometry
  Timers:CreateTimer(0.5, function()
    for i,_ in pairs(spawnTb) do
      local pos1 = spawnTb[i]
      local pos2 = goalTb[i]

      local unit = CreateUnitByName("npc_creep_patrol_torso", pos1, true, nil, nil, DOTA_TEAM_ZOMBIES)
      unit:SetBaseMoveSpeed(ms)
      unit.waypoints = {pos1, pos2}
      unit.goal = pos2
      table.insert(units, unit)

      if ms > 550 then
        unit:AddNewModifier(unit, nil, "modifier_dark_seer_surge", {})
      end
    end
  end)

  Timers:CreateTimer(1, function()
    if (_G.currentLevel == level) or (_G.currentLevel == 0) then
      local count = 0

      for _,ent in pairs(units) do
        ent:MoveToPosition(ent.goal)
        if CalcDist2D(ent:GetAbsOrigin(), ent.goal) < 5 then
          count = count + 1
        end
      end
      if count == #units then
        for _,ent in pairs(units) do
          ent.goal = ent.waypoints[1]

          local newtable = CopyTable(ent.waypoints)
          local first = table.remove(newtable, 1)
          table.insert(newtable, first)
          ent.waypoints = newtable
        end
      end
      return 0.25
    else
      for _,ent in pairs(units) do
        ent:ForceKill(true)
      end
      return
    end
  end)  
end

-- This function is for creating a carty wall to move and die
function barebones:MovingWallThinker(dummyUnit, entvals)
  print("Carty wall patrol started")

  local unitTable = {}
  local isCarts = string.find(entvals[ENT_SPAWN], 'cart')

  local spacingCarts = 125
  local spacingZombies = 75
  local killRadiusLevelCarts = 2
  local killRadiusLevelZombies = 1

  local unitName = isCarts and "npc_carty" or "npc_creep_patrol_torso"
  local setSpacing = isCarts and spacingCarts or spacingZombies
  local spacing = (entvals[CAR_SPACE] == 0) and setSpacing or entvals[CAR_SPACE]
  local killRadiusLevel = isCarts and killRadiusLevelCarts or killRadiusLevelZombies


  local spawn = Entities:FindByName(nil, entvals[ENT_SPAWN]):GetAbsOrigin()
  local goal = Entities:FindByName(nil, entvals[CAR_GOALS]):GetAbsOrigin()
  local len = entvals[CAR_RADII] 
  local moveSpeed = entvals[CAR_MVSPD]
  local rate = entvals[CAR_RATES]
  local level = dummyUnit.level


  local numUnits = math.ceil((len * 2)/spacing) + 1

  local thetaSpawn = math.atan((goal.y - spawn.y)/(goal.x - spawn.x))
  local thetaGoal = math.atan((spawn.y - goal.y)/(spawn.x - goal.x))

  --print(thetaSpawn, thetaGoal)
  print("Radii ", len, "movespeed ", moveSpeed)

  Timers:CreateTimer(0.1, function()
    if _G.currentLevel == level then
      for i = 1,numUnits do
        --print("Spawning carty")
        local mappedDist = ((i - 1)/(numUnits - 1)) * (2 * len) - len

        local spawnX = spawn.x + mappedDist * math.cos(thetaSpawn + math.pi/2)
        local spawnY = spawn.y + mappedDist * math.sin(thetaSpawn + math.pi/2)
        local goalX = goal.x - mappedDist * math.cos(thetaGoal + math.pi/2)
        local goalY = goal.y + mappedDist * math.sin(thetaGoal + math.pi/2)
  
        local pos1 = Vector(spawnX, spawnY, 129)
        local pos2 = Vector(goalX, goalY, 129)

        local unit = Patrols:Initialize({
          name = unitName, 
          spawn = pos1,
          goal = pos2,
          ms = moveSpeed,
          phased = false
        })
        unit:FindAbilityByName("kill_radius_lua"):SetLevel(killRadiusLevel)

        table.insert(unitTable, unit)
      end

      -- Moving units simultaneously
      Timers:CreateTimer(0.1, function()
        for _,unit in pairs(unitTable) do
          Patrols:MoveToGoalAndDie(unit)
        end
      end)

      return rate
    else
      return
    end
  end)
end

-- This function is for wave patrol, left-right for now
function barebones:WavePatrolThinker(unit, entvals)
  print("Wave patrol thinker started on unit", unit:GetUnitName())
  local level = unit.level

  local ms = entvals[PAT_MVSPD] or 300
  local delay = math.max(entvals[PAT_DELAY], 0.03)
  local amp = entvals[PAT_AMPLT] or 200
  local period = entvals[PAT_PEROD] or 2

  local patrolIndex = entvals[PAT_VECNM]
  local waypoints = _G.MultVector[level][patrolIndex]
  local goalpoints = CopyTable(waypoints)
  local first = table.remove(goalpoints, 1)
  table.insert(goalpoints, first)

  -- Setting basic properties
  unit:SetBaseMoveSpeed(ms)
  unit:FindAbilityByName("kill_radius_lua"):SetLevel(1)

  if ms > 550 then
    unit:AddNewModifier(unit, nil, "modifier_dark_seer_surge", {})
  end

  -- Dealing with horizontal/vertical
  local horizontal = true

  if math.abs(waypoints[1].y - goalpoints[1].y) > math.abs(waypoints[1].x - goalpoints[1].x) then
    horizontal = false
  end

  -- Patrolling
  local rate = 0.15
  local moveAmount = ms * rate
  unit.goal = goalpoints[1]
  unit.i = 1

  Timers:CreateTimer(delay, function()
    if IsValidEntity(unit) then
      local posUnit = unit:GetAbsOrigin()

      if horizontal then
        local moveAdd = math.min(math.abs(posUnit.x - unit.goal.x), moveAmount)
        moveAdd = (posUnit.x < unit.goal.x) and moveAdd or -moveAdd

        local posX = posUnit.x + moveAdd
        local normalizedX = math.abs((posX - unit.goal.x)/(waypoints[unit.i].x - unit.goal.x))
        local posY = unit.goal.y + amp*math.sin(period*normalizedX*(2*math.pi))

        unit:MoveToPosition(Vector(posX, posY, 128))

        if math.abs(posUnit.x - unit.goal.x) < 5 then
          unit.i = unit.i + 1
          if unit.i > #waypoints then
            unit.i = 1
          end
  
          unit.goal = goalpoints[unit.i]
        end
      else
        local moveAdd = math.min(math.abs(posUnit.y - unit.goal.y), moveAmount)
        moveAdd = (posUnit.y < unit.goal.y) and moveAdd or -moveAdd

        local posY = posUnit.y + moveAdd
        local normalizedY = math.abs((posY - unit.goal.y)/(waypoints[unit.i].y - unit.goal.y))
        local posX = unit.goal.x + amp*math.sin(period*normalizedY*(2*math.pi))

        unit:MoveToPosition(Vector(posX, posY, 128))

        if math.abs(posUnit.y - unit.goal.y) < 5 then
          unit.i = unit.i + 1
          if unit.i > #waypoints then
            unit.i = 1
          end
  
          unit.goal = goalpoints[unit.i]
        end
      end

      return rate
    else
      return
    end
  end)
end

-- This function is the thinker for the gale force
function barebones:GaleThinker(unit, entvals)
  print("Wave patrol thinker started on unit", unit:GetUnitName())
  local level = unit.level

  local rate = entvals[GAL_RATES]
  local duration = rate == 0 and 99999 or entvals[GAL_DURAT]
  local radius = entvals[GAL_RADII]
  local direction = entvals[GAL_DIREC]

  local params = {}
  params.duration = duration
  params.radius = radius
  params.direction = direction

  local castPos = unit:GetAbsOrigin()

  Timers:CreateTimer(1, function()
    if level == _G.currentLevel then
      if direction == -1 then
        params.direction = RandomFloat(0, 360)
      end

      barebones:CastGale(unit, castPos, params)

      -- Rate=0, cast once with infinite duration
      if rate == 0 then
        return
      else
        return rate
      end
    else
      return
    end
  end)
end

-- This function casts Windrunners Gale Force ability
function barebones:CastGale(unit, castPos, params)
  local level = unit.level

  local graceTime = 0.25

  local duration = (params.duration or 5) - graceTime
  local strength = params.strength or 250
  local radius = params.radius or 1000
  local direction = params.direction or RandomFloat(0, 360)

  local angle = math.rad(direction)
  local angleAdjusted = math.rad(direction - 180)

  local vecFor = Vector(0, 1, 0)
  local vecLeft = Vector(math.cos(angleAdjusted), math.sin(angleAdjusted), 0)
  local vecUp = Vector(0, 0, 1)

  local rate = 0.06

  local partGaleName = "particles/misc/gale.vpcf"

  local soundName = "Hero_Windrunner.GaleForce"

  local partWind = ParticleManager:CreateParticle(partGaleName, PATTACH_ABSORIGIN, unit)
  ParticleManager:SetParticleControl(partWind, 0, castPos)
  ParticleManager:SetParticleControl(partWind, 1, Vector(0, radius, 0))
  ParticleManager:SetParticleControl(partWind, 3, Vector(0, direction, 0))
  ParticleManager:SetParticleControlOrientation(partWind, 3, vecFor, vecLeft, vecUp)

  EmitSoundOnLocationWithCaster(castPos, soundName, unit)

  local c = 0
  Timers:CreateTimer(graceTime, function()
    if rate * c < duration and level == _G.currentLevel then
      local targets = FindUnitsInRadius(
        DOTA_TEAM_GOODGUYS,
        castPos,
        nil,
        radius,
        DOTA_UNIT_TARGET_TEAM_FRIENDLY,
        DOTA_UNIT_TARGET_HERO,
        DOTA_UNIT_TARGET_FLAG_NONE,
        FIND_ANY_ORDER,
        false
      )

      for _,target in pairs(targets) do
        local targetPos = target:GetAbsOrigin()
        local vectorDir = Vector(math.cos(angle), math.sin(angle), 0):Normalized()
        local targetNewPos = targetPos + vectorDir * strength * rate

        target:SetAbsOrigin(targetNewPos)
      end

      c = c + 1
      return rate
    else
      ParticleManager:DestroyParticle(partWind, true)
      return
    end
  end)
end

-- This function blinks a unit back if it leaves a range
function barebones:TetherThinker(unit, entvals)
  --print("Starting tether on unit")
  local center = Entities:FindByName(nil, entvals[ENT_SPAWN]):GetAbsOrigin()

  local r = 1375

  Timers:CreateTimer(1, function()
    if IsValidEntity(unit) then
      local unitPos = unit:GetAbsOrigin()

      if CalcDist2D(unitPos, center) > r then
        local blinkPartStart = "particles/econ/events/ti7/blink_dagger_start_ti7.vpcf"
        local blinkPartEnd = "particles/econ/events/ti7/blink_dagger_end_ti7.vpcf"

        unit:RemoveModifierByName("modifier_tusk_walrus_kick_air_time")

        local part1 = ParticleManager:CreateParticle(blinkPartStart, PATTACH_CUSTOMORIGIN, unit)
        ParticleManager:SetParticleControl(part1, 0, unitPos)

        unit:SetAbsOrigin(center)
        local part2 = ParticleManager:CreateParticle(blinkPartEnd, PATTACH_CUSTOMORIGIN, unit)
        ParticleManager:SetParticleControl(part2, 0, center)
      end

      return 0.1
    else
      return
    end
  end)
end

-- This function creates the zombie patrol with holes
function barebones:GapThinker(unit, entvals)
  local initSpawn = Entities:FindByName(nil, entvals[ENT_SPAWN]):GetAbsOrigin()
  local initGoal = Entities:FindByName(nil, entvals[GAP_GOALS]):GetAbsOrigin()
  local radii = entvals[GAP_RADII]
  local spacing = entvals[GAP_SPACE]
  local unitName = "npc_creep_patrol_torso"
  local ms = entvals[GAP_MVSPD]
  local gap = entvals[GAP_DTGAP]

  local rate = entvals[GAP_RATES]
  local delay = entvals[GAP_DELAY] or 0

  local spawns, goals = Patrols:GenerateMovingWallPositions(initSpawn, initGoal, radii, spacing)

  local otherSpawns = {}
  local otherGoals = {}
  for i,spawn in pairs(spawns) do
    local vec = (goals[i] - spawns[i]):Normalized()

    local newSpawn = spawns[i] + gap*vec
    local newGoal = goals[i] + gap*vec
    table.insert(otherSpawns, newSpawn)
    table.insert(otherGoals, newGoal)
  end

  spawns = ConcatTables(spawns, otherSpawns)
  goals = ConcatTables(goals, otherGoals)

  local unitTable = {}
  
  -- Generating units
  for i,_ in pairs(spawns) do
    local spawn = spawns[i]
    local goal = goals[i]

    local unit = Patrols:Initialize({
      name = unitName,
      spawn = spawn,
      goal = goal,
      ms = ms,
      phased = true
    })

    unit:FindAbilityByName("kill_radius_lua"):SetLevel(3)

    unit.level = _G.currentLevel
    unit.waypoints = {spawn, goal}

    table.insert(unitTable, unit)
    table.insert(_G.Extras, unit:GetEntityIndex())
  end

  Patrols:StartPatrolGroupSync(unitTable, delay, rate)
end

-- This function creates a circular ring of zombies
function barebones:CircularWithGapThinker(unit, entvals)
  --print("Starting circular with gap thinker")
  local level = unit.level
  local center = Entities:FindByName(nil, entvals[ENT_SPAWN]):GetAbsOrigin()

  local r = entvals[CIR_RADII]
  local startAngle = 0
  local endAngle = entvals[CIR_ANGLE]
  local increment = entvals[CIR_INCRE]

  local ms = entvals[CIR_MVSPD]
  local angleRate = entvals[CIR_RATES]
  local rate = 0.15

  local unitsTable = {}

  -- Generating units
  for i = startAngle, endAngle, increment do
    --print("................", i)
    local angleRad = math.rad(i)
    local spawnPos = center + Vector(r*math.cos(angleRad), r*math.sin(angleRad), 0)

    local unit = CreateUnitByName("npc_creep_patrol_torso", spawnPos, false, nil, nil, DOTA_TEAM_ZOMBIES)
    unit:SetBaseMoveSpeed(ms)
    unit.start = i

    table.insert(unitsTable, unit)
    table.insert(_G.Extras, unit:GetEntityIndex())
  end

  -- Movement thinker
  local c = 0
  Timers:CreateTimer(1, function()
    if _G.currentLevel == level then
      for _,unit in pairs(unitsTable) do
        local newAngle = unit.start + c * angleRate
        local newAngleRad = math.rad(newAngle)

        local newPos = center + Vector(r*math.cos(newAngleRad), r*math.sin(newAngleRad), 0)
        unit:MoveToPosition(newPos)
      end

      c = c + 1
      return rate
    else
      return
    end
  end)
end

function barebones:WalrusKickMinistunThinker(unit, entvals)
  local rate = 0.03

  local foundModifier = false
  
  Timers:CreateTimer(0.03, function()
    if IsValidEntity(unit) then
      if not foundModifier then
        if unit:HasModifier("modifier_tusk_walrus_kick_air_time") then
          foundModifier = true

          -- Running new timer to check when it is gone
          Timers:CreateTimer(0.03, function()
            if unit:HasModifier("modifier_tusk_walrus_kick_air_time") then
              return rate
            else
		          unit:AddNewModifier(unit, nil, "modifier_stunned", {duration=0.5})
              foundModifier = false

              return
            end
          end)
        end
      end

      return rate
    else
      return
    end
  end)
end

function barebones:LowerTetherThinker(unit, spawn)
  local y = 1800

  Timers:CreateTimer(0.03, function()
    if IsValidEntity(unit) then
      local pos = unit:GetAbsOrigin()
      
      if pos.y < y then
        unit:RemoveModifierByName("modifier_tusk_walrus_kick_air_time")

        unit:SetAbsOrigin(spawn)
        ResolveNPCPositions(spawn, 25)
      end
      return 0.1
    else
      return
    end
  end)
end