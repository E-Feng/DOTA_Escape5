-- This function is to run a thinker to revive heroes upon "contact"
function barebones:ReviveThinker()
  --print("Number of dead heroes is ", barebones:TableLength(DeadHeroPos))
  for _, alivehero in pairs(_G.PlayersTable) do
    if alivehero:IsAlive() then
      --surr = Entities:FindAllInSphere(hero:GetAbsOrigin(), hero:GetModelRadius())
      --for i,ent in pairs(surr) do
      --  print(i, ent, ent:GetClassname(), ent:GetName())
      --end
      for _, deadhero in pairs(_G.PlayersTable) do
        if deadhero.deadHeroPos then
          local reviveRadius = alivehero.reviveRadius

          -- Patreon larger x
          if deadhero.largerXMod then
            reviveRadius = math.min(reviveRadius * 1.5, REVIVE_RAD_MAX)
          end

          if CalcDist2D(alivehero:GetAbsOrigin(), deadhero.deadHeroPos) < reviveRadius then
            --print("Radius ", alivehero:GetName(), reviveRadius)
            barebones:HeroRevived(deadhero, alivehero)

            -- Patreon phase boots
            Timers:CreateTimer(0, function()
              if alivehero.phaseMod then
                alivehero:AddNewModifier(alivehero, nil, "modifier_phased", {duration = 2})
              end
              if deadhero.phaseMod then
                deadhero:AddNewModifier(deadhero, nil, "modifier_phased", {duration = 2})
              end
            end)
          end
        end
      end
    end
  end
end

-- This function runs to save the location and particle spawn upon hero killed
function barebones:HeroKilled(hero, attacker, ability)
  -- Saves position of killed hero into table
  local playerIdx = hero:GetEntityIndex()
  -- If hero steps onto grass/lava origin is moved closer to path
  hero:SetBaseMagicalResistanceValue(25)
  hero.deadHeroPos = hero:GetAbsOrigin()
  hero.mana = hero:GetMana()

  if string.find(ability:GetClassname(), "ability") then
    if ability:GetAbilityName() == "self_immolation" then
      --print("Moving back location of hero and particle")
      local shift = -30
      local forVector = hero:GetForwardVector():Normalized()
      local newDeadPos = hero:GetAbsOrigin() + forVector*shift
      hero.deadHeroPos = newDeadPos
      --print("Normalized forward vector: ", forVector)
      --print("Altered position: ", newDeadPos)
    end
  end
  --print(hero:GetAbsOrigin())

  --print("Hero", playerIdx, " position saved as ", DeadHeroPos[playerIdx])
  --print("Hero killed by", attacker, attacker:GetName())
  --print("Hero killed by ability", ability, ability:GetAbilityName())

  -- Creates a particle at position and saves particleIdx into tables
  local part = BeaconPart[hero.id]
  local dummy = CreateUnitByName("npc_dummy_unit", hero.deadHeroPos, true, nil, nil, DOTA_TEAM_GOODGUYS)
  dummy:FindAbilityByName("dummy_unit"):SetLevel(1)
  dummy:AddNewModifier(dummy, nil, "modifier_phased", {})
  dummy:AddNewModifier(dummy, nil, "modifier_spectre_spectral_dagger_path_phased", {})
  
  local beacon = ParticleManager:CreateParticle(part, PATTACH_ABSORIGIN, dummy)
  ParticleManager:SetParticleControl(beacon, 0, hero.deadHeroPos)
  ParticleManager:SetParticleControl(beacon, 1, Vector(hero.beaconSize, 0, 0))
  hero.particleNumber = beacon
  hero.dummyPartEntIndex = dummy:GetEntityIndex()
  --print("Particle Created: ", beacon, "under player ", playerIdx, "dummy index: ", PartDummy[playerIdx])

  -- Removes the "killed by" ui when dead
  local player = PlayerResource:GetPlayer(hero:GetPlayerID())
  if player then
    Timers:CreateTimer(0.03, function()
        player:SetKillCamUnit(nil)
    end)
  end
end

-- This function revives the hero once the thinker has found "contact"
function barebones:HeroRevived(deadhero, alivehero)
  -- Sets up location of hero and respawns there
  local xLocation = deadhero.deadHeroPos

  -- Takes the average of alivehero and x location to respawn closer to path
  --local respawnLoc = AveragePos(alivehero:GetAbsOrigin(), xLocation)
  local respawnLoc = AveragePosBias(alivehero:GetAbsOrigin(), xLocation, 0.66)
  deadhero:SetRespawnPosition(respawnLoc)
  deadhero:RespawnHero(false, false)
  deadhero:SetBaseMoveSpeed(300)
  --print("Hero Idx(", playerIdx, ") respawned at ", respawnLoc)

  -- Finds the particle index and deletes it
  local partID = deadhero.particleNumber
  ParticleManager:DestroyParticle(partID, true)
  --print("Particle: ", partID, "destroyed after respawn")

  -- Resetting and updating
  deadhero.deadHeroPos = nil
  deadhero.particleNumber = nil
  deadhero.outOfBoundsDeath = false

  deadhero:SetMana(deadhero.mana)

  local dummy = EntIndexToHScript(deadhero.dummyPartEntIndex)
  if dummy and dummy:IsAlive() then
    dummy:RemoveSelf()
  end
  deadhero.dummyPartEntIndex = nil
end

-- This function is a thinker to check if everyone is dead and revives them
function barebones:CheckpointThinker()
  local numPlayers = #_G.PlayersTable
  local deadHeroes = 0
  for _,hero in pairs(_G.PlayersTable) do
    if not hero:IsAlive() then
      deadHeroes = deadHeroes + 1
    end
  end
  --print("Dead heroes:", deadHeroes, "Total:", numPlayers, "Lives:", GameRules.Lives)
  -- print("CheckpointThinker started, players:", numPlayers, "dead players:", numdead)
  if GameRules.Lives >= 0 and numPlayers == deadHeroes and numPlayers ~= 0 then
    deadHeroes = 0
    Timers:CreateTimer(0.5, function()
      barebones:ReviveAll()
      GameRules.Lives = GameRules.Lives - 1
      if GameRules.Lives >= 0 then
        local str = "You now have " .. tostring(GameRules.Lives) .. " lives remaining!"
        local msg = {
          text = str,
          duration = 5.0,
          style={color="red", ["font-size"]="80px"}
        }
        Notifications:TopToAll(msg)
        GameRules:SendCustomMessage(str, 0, 1)
      end
    end)
  elseif GameRules.Lives < 0 then
    WebApi:SendDeleteRequest()
    Timers:CreateTimer(1, function()
      GameRules.Ongoing = false
      GameRules:SetGameWinner(DOTA_TEAM_ZOMBIES)
      GameRules:SetSafeToLeave(true)
    end)
  end
end

-- This function revives everyone when they all die at last checkpoint
function barebones:ReviveAll()
  print("--------Everyone died, reviving all----------")
  local respawnLoc = GameRules.Checkpoint
  local caster
  for i,hero in pairs(_G.PlayersTable) do
    if hero:IsAlive() then
      hero:SetBaseMagicalResistanceValue(25)
    end
    hero:SetRespawnPosition(respawnLoc)
    --print("Respawn location set to", respawnLoc)
    hero:RespawnHero(false, false)
    hero:SetBaseMoveSpeed(300)
    hero:Stop()
    hero.deadHeroPos = nil
    hero:SetMana(hero.mana)

    print("Hero Idx(", i, ") respawned at ", hero:GetAbsOrigin())
    local particle = ParticleManager:CreateParticle("particles/units/heroes/hero_omniknight/omniknight_purification.vpcf", PATTACH_ABSORIGIN_FOLLOW, hero)
    if hero.particleNumber then
      ParticleManager:DestroyParticle(hero.particleNumber, true)
    end
    caster = hero
  end
  EmitSoundOnLocationForAllies(respawnLoc, "Hero_Omniknight.Purification", caster)
  print("-------All respawned, reset--------------")
end

-- This function is called to spawn the entities for the level
function barebones:SetUpLevel(level)
  print("------Spawning Entities (", level, ")-----")
  -- Running functions
  for _,funcName in pairs(FuncList[level]) do
    barebones[funcName]()
  end

  -- Spawning entities
  for i,entvals in pairs(EntList[level]) do
    --print(entvals[ENT_SPAWN])
    local entnum = entvals[ENT_TYPEN]
    local entspawn = Entities:FindByName(nil, entvals[ENT_SPAWN])
    local entname = Ents[entnum]
    local pos = entspawn:GetAbsOrigin()

    if entvals[ENT_UNTIM] == 1 then  -- item
      local item = CreateItem(entname, nil, nil)
      local item_pos = CreateItemOnPositionSync(pos, item)
      print(item:GetName(), "(", item:GetEntityIndex(), ") has spawned at", pos)
      EntList[level][i][ENT_INDEX] = item:GetEntityIndex()

      item.spawn = pos
      item.respawn = entvals[MNG_RSPWN]

    -- Spawning a unit
    elseif entvals[ENT_UNTIM] >= 2 then
      local team = DOTA_TEAM_ZOMBIES
      if entvals[ENT_UNTIM] == 3 then
        team = DOTA_TEAM_GOODGUYS
      end

      local unit = CreateUnitByName(entname, pos, true, nil, nil, team)
      print(unit:GetUnitName(), entvals[ENT_SPAWN], "(", unit:GetEntityIndex(), ") has spawned at", pos)
      EntList[level][i][ENT_INDEX] = unit:GetEntityIndex()

      if entname == "npc_dummy_unit" then
        unit:FindAbilityByName("dummy_unit"):SetLevel(1)
      end

      -- Running appriopriate function/thinker for entity
      unit.level = level

      local unitFunctions = {}
      if entvals[ENT_RFUNC] then
        if type(entvals[ENT_RFUNC]) == "string" then
          table.insert(unitFunctions, entvals[ENT_RFUNC])
        else
          unitFunctions = entvals[ENT_RFUNC]
        end

        for _,func in pairs(unitFunctions) do
          barebones[func](barebones, unit, entvals)
        end
      end
    end
  end

  -- Spawning particles
  print("--------Spawning particles--------")
  for _,partvals in pairs(PartList[level]) do
    if TableLength(partvals) > 0 then
      Timers:CreateTimer(1, function()
        barebones:SpawnParticle(partvals)
      end)
    end
  end

  -- Adding messages
  for _,msg in pairs(_G.MsgList[level]) do
    if msg then
      local msgData = {
        text = msg,
        duration = 8.0,
        style={color="white", ["font-size"]="72px"}
      }
      Notifications:TopToAll(msgData)
    end
  end
  print("----------All Entities Spawned----------")
end

-- This function spawns particles
function barebones:SpawnParticle(partvals)
  local entities = Entities:FindAllByName(partvals[PAR_SPAWN])

  for _,ent in pairs(entities) do
    local spawnPos = ent:GetAbsOrigin()
    spawnPos.z = 128

    print(spawnPos)

    local dummy = CreateUnitByName("npc_dummy_unit", spawnPos, true, nil, nil, DOTA_TEAM_GOODGUYS)
    dummy:FindAbilityByName("dummy_unit"):SetLevel(1)
  
    local part = ParticleManager:CreateParticle(partvals[PAR_FNAME], PATTACH_ABSORIGIN, dummy)
    ParticleManager:SetParticleControl(part, partvals[PAR_CTRLP], spawnPos)
  
    table.insert(_G.ExtraParticles, part)
    table.insert(_G.Extras, dummy:GetEntityIndex())

    print("Part", part, "spawned at", dummy:GetAbsOrigin())
  end
end

-- This function spawns the cheeses for extra life in the beginning
function barebones:ExtraLifeSpawn()
  print("Spawning extra life cheeses")
  local pos = Entities:FindByName(nil, "cheese_spawn"):GetAbsOrigin()
  local cheeseNum = 6
  local r = 175
  for i = 1,cheeseNum do
    local item = CreateItem("item_cheese_custom", nil, nil)
    local angle = math.rad((i-1)*(360/cheeseNum))
    local spawnPos = Vector(pos.x + r*math.cos(angle), pos.y + r*math.sin(angle), pos.z)
    CreateItemOnPositionSync(spawnPos, item)

    -- For patreon courier
    _G.Cheeses[item:GetEntityIndex()] = "spawned"
  end
end

-- This function cleans up the previous level
function barebones:CleanLevel(level)
  print("-------------Cleaning level---------------")
  for _,entvals in pairs(EntList[level]) do
    print("Removing ", entvals[ENT_SPAWN])
    if entvals[ENT_INDEX] ~= 0 then
      local ent = EntIndexToHScript(entvals[ENT_INDEX])

      if ent ~= nil and IsValidEntity(ent) then
        --print("DEBUG?? ", ent)

        -- Unit
        if entvals[ENT_UNTIM] >= 2 and ent:IsAlive() then
          print("Ent", ent:GetUnitName(), "ID", entvals[ENT_INDEX], "removed")
          ent:RemoveSelf()

        -- Mango
        elseif entvals[ENT_UNTIM] == 1 and ent:GetName() == "item_mango_custom" then
          --print(ent, ent:GetClassname(), ent:GetName())
          if ent:GetContainer() ~= nil then
            print("Ent container", ent:GetName(), "ID", entvals[ENT_INDEX], "removed")
            ent:GetContainer():RemoveSelf()
          end
          if ent ~= nil then
            print("Ent", ent:GetName(), "ID", entvals[ENT_INDEX], "removed")
            ent:RemoveSelf()
          end

        -- Cheese
        elseif entvals[ENT_UNTIM] == 1 and ent:GetName() == "item_cheese_custom" then
          --print(ent, ent:GetClassname(), ent:GetName())
          if ent:GetContainer() ~= nil then
            print("Ent container", ent:GetName(), "ID", entvals[ENT_INDEX], "removed")
            ent:GetContainer():RemoveSelf()
          end
          if ent ~= nil then
            print("Ent", ent:GetName(), "ID", entvals[ENT_INDEX], "removed")
            ent:RemoveSelf()
          end
        end
      end
    end
  end

  for _,extra in pairs(_G.Extras) do
    local ent = EntIndexToHScript(extra)

    if IsValidEntity(ent) and ent ~= nil and ent:IsAlive() then
      print("Ent ID", ent:GetUnitName(), extra, "removed")
      ent:RemoveSelf()
    end
  end
  _G.Extras = {}

  for _,extraPart in pairs(_G.ExtraParticles) do
    ParticleManager:DestroyParticle(extraPart, true)
    print("Particle", extraPart, "removed")
  end
  _G.ExtraParticles = {}

  print("----------Cleaning level done------------")
end

-- This function removes all skills from all players
function barebones:RemoveAllSkills()
  print("---------Removing All Skills------------")
  if not GIVE_ALL_SPELLS then
    for _,hero in pairs(_G.PlayersTable) do
      -- Removing abilities, legacy
      --[[for i = 0,5 do
        local abil = hero:GetAbilityByIndex(i)
        if abil then
          Timers:CreateTimer(1, function()
            abil:SetLevel(0)
          end)
        end
      end]]
      for i = 0,5 do
        local abil = hero:GetAbilityByIndex(i)
        local abilName = abil:GetAbilityName()
        local last = string.sub(abilName, -1)
        
        if tonumber(last) ~= (i+1) then
          hero:SwapAbilities(abilName, "barebones_empty" .. (i+1), false, true)
        end
      end
    end
  end
end

-- This function removes all modifiers from all players
function barebones:RemoveAllModifiers()
  print("---------Removing All Modifiers------------")
  for _,hero in pairs(_G.PlayersTable) do
    for _,modName in pairs(_G.modifierList) do
      if hero:HasModifier(modName) then
        hero:RemoveModifierByName(modName)
      end
    end
  end
end

-- This function checks to keeps players in bounds if present
function barebones:CheckPlayersInbounds(level)
  local tlName = "bounds_tl" .. level
  local brName = "bounds_br" .. level

  local tlEnt = Entities:FindByName(nil, tlName)
  local brEnt = Entities:FindByName(nil, brName)

  if tlEnt and brEnt then
    print("--------Starting players inbound check---------")
    local tlPos = tlEnt:GetAbsOrigin()
    local brPos = brEnt:GetAbsOrigin()

    Timers:CreateTimer(2, function()
      if _G.currentLevel == level then
        local heroesOutside = GetHeroesOutsideRectangle(tlPos, brPos, true)

        for _,hero in pairs(heroesOutside) do
          -- hero:ForceKill(true)
          hero:SetBaseMagicalResistanceValue(25)
        end

        return 0.25
      else
        return
      end
    end)
  end
end