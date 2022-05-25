-- This function is for basic patrol thinker
function barebones:PatrolThinker(unit, entvals)
  print("Patrol thinker started on unit", unit:GetUnitName())

  local ms = entvals[PAT_MVSPD]
  local turnDelay = entvals[PAT_TURND] or 0.5
  local delay = entvals[PAT_DELAY] or 0.03

  -- Setting basic properties
  unit:SetBaseMoveSpeed(ms)
  unit:FindAbilityByName("kill_radius_lua"):SetLevel(1)

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
  
  local waypoints = _G.MultVector[patrolIndex]
  unit.waypoints = waypoints

  Patrols:StartPatrol(unit, delay, turnDelay)
end

-- This function is a thinker for a gate to move upon full mana
function barebones:GateThinker(unit, entvals)
  print("Gate Thinker has started on unit", unit:GetUnitName(), "(", unit:GetEntityIndex(), ")")
  local pos = Entities:FindByName(nil, entvals[ENT_SPAWN]):GetAbsOrigin()
  local mana = entvals[GAT_NUMBR]
  local hullRadius = 80

  unit.moved = false
  unit:SetMaxMana(mana)
  unit:SetHullRadius(hullRadius)
  unit:SetForwardVector(entvals[GAT_ORIEN])
  local abil = unit:FindAbilityByName("gate_unit_passive")
  Timers:CreateTimer(function()
    if IsValidEntity(unit) then
      -- print("Has mana?", abil:IsOwnersManaEnough(), unit:GetUnitName(), "(", unit:GetEntityIndex(), ")")
      if unit:GetMana() == mana then
        unit:SetBaseMoveSpeed(100)
        unit:CastAbilityImmediately(abil, -1)
        unit:SetHullRadius(25)
        unit.moved = true
      end
      if not unit.moved then
        if CalcDist2D(unit:GetAbsOrigin(), pos) > 100 and RandomFloat(0, 1) > 0.75 then
          unit:MoveToPosition(pos)
        end

        -- Check for phase boots through
        local foundUnits = FindUnitsInRadius(DOTA_TEAM_GOODGUYS,
                                             unit:GetAbsOrigin(),
                                             nil,
                                             hullRadius,
                                             DOTA_UNIT_TARGET_TEAM_FRIENDLY,
                                             DOTA_UNIT_TARGET_HERO,
                                             DOTA_UNIT_TARGET_FLAG_NONE,
                                             FIND_ANY_ORDER,
                                             false)
        for _,foundUnit in pairs(foundUnits) do
          --print("Found", foundUnit:GetName())
          local posU = unit:GetAbsOrigin()
          local posF = foundUnit:GetAbsOrigin()

          if posF.z < 130 then
            local shift = -(hullRadius - CalcDist2D(posU, posF) + 25)
            local forwardVec = foundUnit:GetForwardVector():Normalized()
            local newOrigin = posF + forwardVec*shift
            foundUnit:SetAbsOrigin(newOrigin)
          end
        end
      end
      return 0.03
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
                                    DOTA_UNIT_TARGET_ALL, 
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
function barebones:MagnusThinker(unit, entvals)
  print("Magnus thinker started")
  local spawn = Entities:FindByName(nil, entvals[ENT_SPAWN]):GetAbsOrigin()
  local goal = Entities:FindByName(nil, entvals[MAG_GOALS]):GetAbsOrigin()
  local rate = entvals[MAG_RATES]
  local delay = entvals[MAG_DELAY]
  
  unit.pos = goal
  local abil = unit:AddAbility("magnus_skewer_lua")
  abil:SetLevel(1)

  --unit:SetControllableByPlayer(0, false)

  --print("Magnus values: ", spawn, goal, rate, delay)
  print("Magnus thinker set, starting...")

  Timers:CreateTimer(delay, function()
    if IsValidEntity(unit) then
      --print("Magnus skewer vals: ", unit.pos, abil:GetAbilityName())
      unit:CastAbilityOnPosition(unit.pos, abil, -1)
      unit.pos = unit.pos == spawn and goal or spawn
      return rate
    else
      return
    end
  end)
end

-- This function is for creating a multi wall patrol
function barebones:WallPatrolThinker(dummyUnit, entvals)
  print("Multi wall patrol started")
  dummyUnit:FindAbilityByName("dummy_unit"):SetLevel(1)

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
  dummyUnit:FindAbilityByName("dummy_unit"):SetLevel(1)

  local unitTable = {}
  local isCarts = string.find(entvals[ENT_SPAWN], 'cart')

  local spacingCarts = 110
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
        local mappedDist = (i/numUnits) * (2 * len) - len

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
          phased = true
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

  local ms = entvals[PAT_MVSPD] or 300
  local delay = entvals[PAT_DELAY] or 0.03
  local amp = entvals[PAT_AMPLT] or 200
  local period = entvals[PAT_PEROD] or 2

  local patrolIndex = entvals[PAT_VECNM]
  local waypoints = _G.MultVector[patrolIndex]
  local goalpoints = CopyTable(waypoints)
  local first = table.remove(goalpoints, 1)
  table.insert(goalpoints, first)

  -- Setting basic properties
  unit:SetBaseMoveSpeed(ms)
  unit:FindAbilityByName("kill_radius_lua"):SetLevel(1)

  if ms > 550 then
    unit:AddNewModifier(unit, nil, "modifier_dark_seer_surge", {})
  end

  -- Patrolling
  local rate = 0.15
  local moveAmount = ms * rate
  unit.goal = goalpoints[1]
  unit.i = 1

  Timers:CreateTimer(delay, function()
    if IsValidEntity(unit) then
      local posUnit = unit:GetAbsOrigin()

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

      return rate
    else
      return
    end
  end)
end