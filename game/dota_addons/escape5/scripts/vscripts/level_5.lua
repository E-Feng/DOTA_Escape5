function barebones:SelectableSpawner()
	print("Starting selectable spawner")
	local spawn = Entities:FindByName(nil, "spawn5"):GetAbsOrigin()
	local goal = Entities:FindByName(nil, "goal5"):GetAbsOrigin()

	local unitName = "npc_creep_patrol_selectable"
	local rate = 5
	local ms = 175

	Timers:CreateTimer(1, function()
		if _G.currentLevel == 5 then
			local unit = Patrols:Initialize({
				name = unitName, 
				spawn = spawn,
				goal = goal,
				ms = ms,
				phased = false
			})
			barebones:WalrusKickMinistunThinker(unit, nil)
			barebones:LowerTetherThinker(unit, spawn)

			Patrols:MoveToGoalAndDie(unit)

			return rate
		else
			return
		end
	end)
end

function barebones:SnowballCleanup()
	print("Starting snowball particle cleanup")
	local partName = "particles/dev/empty_particle.vpcf"

	local rate = 10

  local dummy = CreateUnitByName("npc_dummy_unit", Vector(0, 0, 0), true, nil, nil, DOTA_TEAM_GOODGUYS)
  dummy:FindAbilityByName("dummy_unit"):SetLevel(1)

	local prevNum = nil

	Timers:CreateTimer(5, function()
		if _G.currentLevel == 5 then
			local num = ParticleManager:CreateParticle(partName, PATTACH_ABSORIGIN, dummy)
			
			local respawnParticles = {}
			for _,hero in pairs(_G.PlayersTable) do
				table.insert(respawnParticles, hero.particleNumber)
			end

			if prevNum then
				for i = prevNum,num do
					-- Dont cleanup respawn particles
					if not TableContains(respawnParticles, i) then
						Timers:CreateTimer(20, function()
							ParticleManager:ReleaseParticleIndex(i)
						end)
					end
				end
			end

			prevNum = num

			return rate
		else
			return
		end

	end)
end

-- function barebones:ZombieSpawner()
-- 	print("Starting zombie spawner")
-- 	local center = Entities:FindByName(nil, "center5"):GetAbsOrigin()

-- 	local topleft = Entities:FindByName(nil, "tl5"):GetAbsOrigin()
-- 	local botright = Entities:FindByName(nil, "br5"):GetAbsOrigin()

-- 	local x1 = topleft.x
-- 	local x2 = botright.x
-- 	local y1 = botright.y
-- 	local y2 = topleft.y

-- 	local width = math.abs(x1 - x2)
-- 	local height = math.abs(y1 - y2)

-- 	Timers:CreateTimer(1, function()
-- 		if _G.currentLevel == 5 then
-- 			local targets = GetHeroesInsideRectangle(topleft, botright, true)
-- 			print(#targets, targets)

-- 			for _,target in pairs(targets) do
-- 				local unit = CreateUnitByName("npc_creep_patrol", center, true, nil, nil, DOTA_TEAM_ZOMBIES)
-- 				table.insert(_G.Extras, unit:GetEntityIndex())

-- 				local targetPos = target:GetAbsOrigin()

-- 				Timers:CreateTimer(0, function()
-- 					if IsValidEntity(unit) then
-- 						unit:MoveToPositionAggressive(target:GetAbsOrigin())
-- 						return 0.25
-- 					else
-- 						return
-- 					end
-- 				end)
-- 			end

-- 			return 5
-- 		else
-- 			return
-- 		end
-- 	end)
-- end

-- -- This function triggers the start
-- function barebones:ArenaSetup()
-- 	print("Starting setup for arena")
-- 	local center = Entities:FindByName(nil, "arena5"):GetAbsOrigin()

-- 	local r = 500
-- 	local rTrigger = 100

-- 	local particleName = "particles/misc/cw.vpcf"
-- 	local particleCPColor = 1
-- 	local particleColorOff = Vector(255, 0, 0)
-- 	local particleColorOn = Vector(0, 255, 0)

-- 	local particleCPPosition = 0
-- 	local particlePositionHidden = Vector(0, 0, -128)

-- 	local numPlayers = #_G.PlayersTable
-- 	local angleIncrement = 360/numPlayers

-- 	local isTriggersActive = true
-- 	local triggersTable = {}

-- 	-- Spawning particles for triggers
-- 	for i = 1, numPlayers do
-- 		local angleRad = math.rad(angleIncrement * (i-1))
-- 		local spawn = CalculatePositionPolar(center, r, angleRad)

-- 		local dummy = CreateUnitByName("npc_dummy_unit", spawn, true, nil, nil, DOTA_TEAM_GOODGUYS)
-- 		dummy:FindAbilityByName("dummy_unit"):SetLevel(1)

-- 		local particleNumber = ParticleManager:CreateParticle(particleName, PATTACH_ABSORIGIN, dummy)
-- 		ParticleManager:SetParticleControl(particleNumber, particleCPColor, particleColorOff)

-- 		table.insert(triggersTable, {spawn, particleNumber})

-- 		table.insert(_G.Extras, dummy:GetEntityIndex())
-- 		table.insert(_G.ExtraParticles, particleNumber)
-- 	end

-- 	print("Triggers Particle Table: ")
-- 	PrintTable(triggersTable)

-- 	Timers:CreateTimer(1, function()
-- 		if _G.currentLevel == 5 then
-- 			if isTriggersActive then
-- 				local count = 0

-- 				for _,trigger in pairs(triggersTable) do
-- 					local spawn = trigger[1]
-- 					local particleNumber = trigger[2]
					
-- 					local targets = FindUnitsInRadius(
-- 						DOTA_TEAM_GOODGUYS,
-- 						spawn,
-- 						nil,
-- 						rTrigger,
-- 						DOTA_UNIT_TARGET_TEAM_FRIENDLY,
-- 						DOTA_UNIT_TARGET_HERO,
-- 						DOTA_UNIT_TARGET_FLAG_NONE,
-- 						FIND_ANY_ORDER,
-- 						false
-- 					)
-- 					if #targets > 0 then
-- 						count = count + 1
-- 						print("on", particleNumber, particleCPColor, particleColorOn)
-- 						ParticleManager:SetParticleControl(particleNumber, particleCPColor, particleColorOn)
-- 					else
-- 						ParticleManager:SetParticleControl(particleNumber, particleCPColor, particleColorOff)
-- 					end
-- 				end

-- 				if count == numPlayers then
-- 					for _,trigger in pairs(triggersTable) do
-- 						ParticleManager:SetParticleControl(trigger[2], particleCPPosition, particlePositionHidden)
-- 						isTriggersActive = false 
-- 					end

-- 					-- Start level function
-- 					print("Starting level 5..........")

-- 					return
-- 				end
-- 			else
-- 				-- Triggers not active, check if all dead to reactivate
-- 				local isAllDead = true
-- 				for _,hero in pairs(_G.PlayersTable) do
-- 					if hero:IsAlive() then
-- 						isAllDead = false
-- 					end
-- 				end

-- 				if isAllDead then
-- 					Timers:CreateTimer(2, function()
-- 						isTriggersActive = true
-- 					end)
-- 				end
-- 			end

-- 			return 1
-- 		else
-- 			-- Function end
-- 			return
-- 		end
-- 	end)
-- end