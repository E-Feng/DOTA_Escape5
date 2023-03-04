function barebones:PatternLSA()
  print("Starting pattern LSA...")
  local center = Entities:FindByName(nil, "mango6_5"):GetAbsOrigin()

  local numTotal = 7
  local spacing = 300
  local rate = 4

  local lsaPos = {}

  local dummy = CreateUnitByName("npc_dummy_unit", center, true, nil, nil, DOTA_TEAM_GOODGUYS)
  dummy:FindAbilityByName("dummy_unit"):SetLevel(1)

  for i=1,numTotal do
    local x = center.x + spacing * (i - math.ceil(numTotal/2))
    local pos = Vector(x, center.y, 128)

    table.insert(lsaPos, pos)
  end

  local offset = true

  Timers:CreateTimer(1, function()
    if _G.currentLevel == 6 then
      --print("Running...........")
      
      -- LSA casting
      for i=1,numTotal do
        local castLSA = true

        local j = i + (offset and 1 or 0)

        if (j % 2) == 1 then
          castLSA = false
        end

        if castLSA then
          local emitSound = (i == 3) or (i == 4)
          barebones:CastLSA(dummy, lsaPos[i], emitSound)
        end

      end

      offset = not offset

      return rate
    else
      return
    end
  end)
end