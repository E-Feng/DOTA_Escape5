-- This function spawns the friendly units for tp
function barebones:SpawnFriendlyPatrols()
  print("Spawning friendly patrols for tp")
  local entList = {
    {"f1a", "f1b"},
    {"f2a", "f2b"}
  }

  for i,waypoints in pairs(entList) do
    local spawn = Entities:FindByName(nil, waypoints[1]):GetAbsOrigin()
    local unit = CreateUnitByName("npc_friendly", pos, false, nil, nil, DOTA_TEAM_GOODGUYS)

    unit:SetBaseMoveSpeed(300)
    unit.waypoints = waypoints

    Patrols:StartPatrol(unit)

    print("Friendly patrol created, id: ", unit:GetEntityIndex())
    table.insert(Extras, unit:GetEntityIndex())
  end
end