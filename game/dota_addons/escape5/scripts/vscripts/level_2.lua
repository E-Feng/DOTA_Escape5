-- This function spawns the poles for hookshot
function barebones:SpawnGales()
  print("Spawning gales")
  local spawnPos = Entities:FindByName(nil, "carty2_1a"):GetAbsOrigin()

  local unit = CreateUnitByName("npc_void_spirit", spawnPos, false, nil, nil, DOTA_TEAM_GOODGUYS)

  table.insert(_G.Extras, unit:GetEntityIndex())

  local params = {
    duration = 5,
    radius = 1000,
    strength = 250,
    direction = 45
  }

  Timers:CreateTimer(3, function()
    if IsValidEntity(unit) then    
      barebones:CastGale(unit, spawnPos, params)

      return 8
    else
      return
    end
  end)
end

function barebones:RandomLSAThinker()
  print("Starting random LSAs thinker")
  local center = Entities:FindByName(nil, 'gale2_11'):GetAbsOrigin()

  local spawnRate = 3.25

  local rMin = 300
  local rMax = 950
  local spacingLSA = 400
  local delayLSA = 1.7

  local minRandom = 8
  local maxRandom = 12

  local maxLineLSA = math.floor(rMax/spacingLSA)

  local warningParticle = "particles/misc/light_strike_ring.vpcf"

  local dummy = CreateUnitByName("npc_dummy_unit", center, true, nil, nil, DOTA_TEAM_GOODGUYS)
  dummy:FindAbilityByName("dummy_unit"):SetLevel(1)

  Timers:CreateTimer(1, function()
    if _G.currentLevel == 2 then
      local typeLSA = RandomInt(1, 3)
      local tableLSA = {}

      -- Circular
      if typeLSA == 1 then
        local rRand = RandomInt(rMin, rMax)
        local angleShift = RandomInt(0, 90)

        local circum = 2*math.pi*rRand
        local numLSA = math.ceil(circum/spacingLSA)
        local angleLSA = 360/numLSA

        for i = 1,numLSA do
          local angle = angleLSA*(i-1) + angleShift

          local pos = CalculatePositionPolar(center, rRand, math.rad(angle))

          table.insert(tableLSA, pos)
        end

      -- Line
      elseif typeLSA == 2 then
        local angleRand1 = math.rad(RandomInt(0, 360))
        local angleRand2 = math.rad(RandomInt(0, 360))

        for i = -maxLineLSA,maxLineLSA do
          local r = i*spacingLSA

          local pos1 = CalculatePositionPolar(center, r, angleRand1)
          local pos2 = CalculatePositionPolar(center, r, angleRand2)

          table.insert(tableLSA, pos1)
          table.insert(tableLSA, pos2)
        end

      -- Random
      elseif typeLSA == 3 then
        local numRandom = RandomInt(minRandom, maxRandom)

        for i = 1,numRandom do
          local rRand = RandomInt(0, rMax)
          local angleRand = math.rad(RandomInt(0, 360))

          local pos = CalculatePositionPolar(center, rRand, angleRand)

          table.insert(tableLSA, pos)   
        end
      end

      -- Casting LSAs defined from above
      for i,pos in pairs(tableLSA) do
        local part = ParticleManager:CreateParticle(warningParticle, PATTACH_ABSORIGIN, dummy)
        ParticleManager:SetParticleControl(part, 0, pos)
        Timers:CreateTimer(delayLSA, function()
          barebones:CastLSA(dummy, pos, i == 1)
        end)
      end

      return spawnRate
    else
      return
    end
  end)
end

function barebones:RandomMangoThinker()
  print("Starting random mango thinker")
  local center = Entities:FindByName(nil, 'gale2_11'):GetAbsOrigin()

  local rMax = 950

  local maxMangoes = 8

  local mango
  local countMango = 0

  Timers:CreateTimer(5, function()
    if _G.currentLevel == 2 and countMango < maxMangoes then
      
      -- Spawn mango
      if not IsValidEntity(mango) then
        print("Spawning new mango #", countMango)

        local angle = math.rad(RandomInt(0, 360))
        local r = RandomInt(0, rMax)
        local pos = CalculatePositionPolar(center, r, angle)

        mango = CreateItem("item_mango_custom", nil, nil)
        CreateItemOnPositionSync(pos, mango)

        countMango = countMango + 1
      end

      return 1
    else
      return
    end
  end)
end