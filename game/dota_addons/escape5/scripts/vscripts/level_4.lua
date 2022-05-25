-- This function spawns the poles for hookshot
function barebones:SpawnPoles()
  print("Spawning poles for hookshot")
  local units = Entities:FindAllByName("hookshot_pole")

  for i,unit in pairs(units) do
    local pos = unit:GetAbsOrigin()
    pos.z = 60
    local pole = CreateUnitByName("npc_hook_pole", pos, false, nil, nil, DOTA_TEAM_GOODGUYS)
    local abil = pole:AddAbility("patrol_unit_no_bar_unselectable_passive")
    abil:SetLevel(1)

    print("Hookshot pole created, id: ", pole:GetEntityIndex())
    table.insert(Extras, pole:GetEntityIndex())
  end
end