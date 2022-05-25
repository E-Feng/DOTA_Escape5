-- This function creates the zombie patrol with holes
function barebones:MultiPatrolWithGap()
  local initSpawn = Entities:FindByName(nil, "lsa2_2_1"):GetAbsOrigin()
  local initGoal = Entities:FindByName(nil, "lsa2_2_5"):GetAbsOrigin()
  local radii = 500
  local spacing = 75
  local unitName = "npc_creep_patrol_torso"
  local ms = 300

  local spawns, goals = Patrols:GenerateMovingWallPositions(initSpawn, initGoal, radii, spacing)

  local unitsTable = {}
  
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
    table.insert(unitsTable, unit)
  end

  -- Moving units simultaneously, logic here for gaps
  Timers:CreateTimer(0.1, function()
    if _G.currentLevel == 1 then
      local count = 0

      for _,unit in pairs(unitsTable) do
        Patrols:MoveToGoal(unit)
      end

    else
      for _,ent in pairs(unitsTable) do
        ent:ForceKill(true)
        ent:RemoveSelf()
      end
    end
  end)
end