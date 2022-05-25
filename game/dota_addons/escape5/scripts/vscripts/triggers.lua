function OnStartSafety(trigger)
	local ent = trigger.activator
	if not ent then return end
	if ent:IsRealHero() and ent:IsAlive() then
		ent.isSafe = true
		ent:SetBaseMagicalResistanceValue(100)
		print(ent:GetName(), " has stepped on safety trigger")
		return
	end
end

function OnEndSafety(trigger)
	local ent = trigger.activator
	print(ent:GetName(), " has initially stepped off trigger")
	if not ent then return end

	if ent:IsRealHero() and ent:IsAlive() then
		ent.isSafe = false

		-- Dealing with out of bounds spells
		local hasModifier = false
		for _,modifierName in pairs(_G.outOfBoundsModifiers) do
			if ent:HasModifier(modifierName) then
				hasModifier = true
			end
		end

		if hasModifier then
			local tickRate = 0.1
			local tickDelay = 0.05

			Timers:CreateTimer(0, function()
				-- Recheck modifier
				hasModifier = false
				for _,modifierName in pairs(_G.outOfBoundsModifiers) do
					if ent:HasModifier(modifierName) then
						hasModifier = true
					end
				end

				if hasModifier then
					return tickRate
				else
					Timers:CreateTimer(tickDelay, function()
						if ent:GetAbsOrigin().z > 500 then
							print("Landed on map border, killing now")
							ent.outOfBoundsDeath = true
							ent:SetBaseMagicalResistanceValue(25)
						else
							if ent.isSafe then
								print("Landed on safe after out of bounds spell")
								ent.outOfBoundsDeath = false
							else
								print("Landed on lava after spell, killing now")
								ent.outOfBoundsDeath = true
								ent:SetBaseMagicalResistanceValue(25)
							end
						end	
						return
					end)
					return
				end
			end)
		-- For hookshot issues leaving trigger from highground
		elseif ent.hookZ >= 129 then
			Timers:CreateTimer(0.03, function()
				if ent:HasModifier("modifier_rattletrap_hookshot") then
					return 0.03
				else
					Timers:CreateTimer(0.2, function()
						if not ent.isSafe then
							print(ent:GetName(), " will be killed, hooking from highground")
							ent:SetBaseMagicalResistanceValue(25)
						end
					end)
				end
				return
			end)
		else
			print(ent:GetName(), " will be killed")
			ent:SetBaseMagicalResistanceValue(25)
		end

		return
	end
end

function OnStartKill(trigger)
	local ent = trigger.activator
	if not ent then return end
	--print(ent:GetName(), " has stepped on trigger")
	if ent:IsRealHero() and ent:IsAlive() then
		ent.isSafe = false
		ent.outOfBoundsDeath = true
		ent:SetBaseMagicalResistanceValue(25)
		return
	end
end

function UpdateCheckpoint(trigger)
	print("---------UpdateCheckpoint trigger activated--------")
	local trigblock = trigger.caller
	local position = trigblock:GetAbsOrigin()
	--print("Checkpoint was:", GameRules.Checkpoint)
	GameRules.Checkpoint = position
	local name = trigblock:GetName()
	local level = tonumber(string.sub(name, -1))
	if _G.currentLevel < level then
		_G.currentLevel = level
		print("Checkpoint updated to:", position)
		print("Level updated to:", level)
		local msg = {
			text = "Level " .. tostring(level) .. "!",
			duration = 8.0,
			style={color="white", ["font-size"]="96px"}
		}       
		if level < 7 then
			Notifications:TopToAll(msg)
			GameRules:SendCustomMessage("Level " .. tostring(level) .. "!", 0, 1)
		end
		if level > 1 and level < 7 then
			barebones:ReviveAll()
			barebones:RemoveAllSkills()
			barebones:CleanLevel(level-1)
			barebones:SetUpLevel(level)
			Timers:CreateTimer(1, function()
				barebones:MoveCreeps(level, {})
			end)
			WebApi:UpdateTimeSplit(level)
		elseif level == 7 then
			GameRules.Ongoing = false
			WebApi:UpdateTimeSplit(level)
			Timers:CreateTimer(0.1, function()
				WebApi:FinalizeGameScoreAndSend()
				WebApi:SendDeleteRequest()
				Timers:CreateTimer(2, function()
					GameRules:SetGameWinner(DOTA_TEAM_GOODGUYS)
					GameRules:SetSafeToLeave(true)
				end)
			end)
		end
		print("---------UpdateCheckpoint trigger finished--------")
	end
end

function GiveSkill(trigger)
	print("Skill trigger triggered")
	local hero = trigger.activator
	local trig = trigger.caller

	local name = trig:GetName()
	local level = tonumber(string.sub(name, 1, 1))
	local slot = tonumber(string.sub(name, 2, 2))
	local abilName = string.sub(name, 3)

	if trig and level == _G.currentLevel then
		-- Adding skill if somehow doesnt have
		if not hero:FindAbilityByName(abilName) then
			print("Giving skill to player")
			local tempAbil = hero:AddAbility(abilName)
			tempAbil:SetHidden(true)
			tempAbil:SetLevel(1)
		end

		local abil = hero:FindAbilityByName(abilName)
		local abilSlot = abil:GetAbilityIndex()

		print("Current slot for ", abil:GetAbilityName(), slot, abilSlot + 1)
		-- Checking proper slot
		if slot ~= (abilSlot + 1) then
			hero:SwapAbilities(abilName, "barebones_empty" .. slot, true, false)

			-- Particles for spell
			local partname = "particles/generic_hero_status/hero_levelup.vpcf"
			local part = ParticleManager:CreateParticle(partname, PATTACH_ABSORIGIN_FOLLOW, hero)
		end
	end
end

function RemoveSkill(trigger)
	print("Remove skill trigger triggered")
	local hero = trigger.activator
	local trig = trigger.caller
	if trig then
		local trigName = trig:GetName()
		local removeName = string.sub(trigName, 3)
		
    for i = 0,5 do
      local abil = hero:GetAbilityByIndex(i)
      local abilName = abil:GetAbilityName()
			
			print(i, removeName, abilName)
      if removeName == abilName then
        hero:SwapAbilities(abilName, "barebones_empty" .. (i+1), false, true)
      end
    end
	end
end

-- Trigger rotations
function RotateOn(trigger)
	local r1 = 50
	local r2 = 800
	local baseTurnRate = 1.5  -- Degrees
	local adjRate = 0.67

	-- Getting all the triggers
	local cw1 = Entities:FindByName(nil, "cw1")
	local ccw1 = Entities:FindByName(nil, "ccw1")
	local cw2 = Entities:FindByName(nil, "cw2")
	local ccw2 = Entities:FindByName(nil, "ccw2")

	cw1.count = cw1.count or 0
	ccw1.count = ccw1.count or 0
	cw2.count = cw2.count or 0
	ccw2.count = ccw2.count or 0

	-- Increasing count on current trigger
	local trig = trigger.caller
	trig.count = (trig.count or 0) + 1
	print("Currently", trig.count, "on triggerblock")

	-- Sorting out which trigger and count
	local name = trig:GetName()
	local isCcw = string.find(name, "ccw")
	local turnRate = isCcw and baseTurnRate or -baseTurnRate
	local num = string.sub(name, -1)

	local trigRev
	local trigOtherA
	local trigOtherB

	if num == "1" then
		trigOtherA = cw2
		trigOtherB = ccw2
		trigRev = isCcw and cw1 or ccw1
	elseif num == "2" then
		trigOtherA = cw1
		trigOtherB = ccw1
		trigRev = isCcw and cw2 or ccw2
	end

	print(trig.count, trigRev.count, trigOtherA.count, trigOtherB.count)

	if trig.count == 1 then
		Timers:CreateTimer(function()
			local otherTurning = (trigOtherA.count == 0 and trigOtherB.count > 0) or (trigOtherB.count == 0 and trigOtherA.count > 0)
			local adjTurnRate = otherTurning and (turnRate * adjRate) or turnRate

			local colorTurn = otherTurning and Vector(0, 255, 255) or Vector(0, 255, 0)

			if trig.count > 0 and trigRev.count == 0 then
				ParticleManager:SetParticleControl(trig.part, 1, colorTurn)

				for i,unit in pairs(trig.pheonixes) do
					local origin = unit:GetAbsOrigin()
					local forw = unit:GetForwardVector()
					local newforw = RotateVector2D(forw, adjTurnRate)
					local newpos = trig.spawn + r1*newforw
					local move = origin + r2*newforw
					unit:SetAbsOrigin(newpos)
					unit:MoveToPosition(move)
				end
			elseif trig.count > 0 and trigRev.count > 0 then
				ParticleManager:SetParticleControl(trig.part, 1, Vector(255, 255, 0))
				ParticleManager:SetParticleControl(trigRev.part, 1, Vector(255, 255, 0))
			elseif trig.count == 0 then
				ParticleManager:SetParticleControl(trig.part, 1, Vector(255, 0, 0))
				return
			end
			return 0.05
		end)
	end
end

function RotateOff(trigger)
	local trig = trigger.caller
	trig.count = trig.count - 1
	print("Currently", trig.count, "on triggerblock")
end