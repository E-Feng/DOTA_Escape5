function OnStartSafety(trigger)
	local ent = trigger.activator
	print(ent:GetName(), " has initially stepped on safety trigger")

	if not ent then return end
	if not ent:IsHero() then return end

	ent.isSafe = true

	if ent:IsRealHero() and ent:IsAlive() then
		ent:SetBaseMagicalResistanceValue(100)
		print(ent:GetName(), " is safe, setting magic resist")
		return
	end
end

function OnEndSafety(trigger)
	local ent = trigger.activator
	print(ent:GetName(), " has initially stepped off trigger")

	if not ent then return end
	if not ent:IsHero() then return end

	if ent:IsRealHero() and ent:IsAlive() then
		ent.isSafe = false

		-- Dealing with magic immunity modifiers
		if ent:HasModifier("modifier_neutral_spell_immunity") then
			ent:RemoveModifierByName("modifier_neutral_spell_immunity")
		end

		-- Dealing with out of bounds spells
		local hasModifier = false
		for _,modifierName in pairs(_G.outOfBoundsModifiers) do
			if ent:HasModifier(modifierName) then
				print("Found modifier for death trigger", modifierName)
				hasModifier = true
			end
		end

		-- Specific for boots travel, no killing 
		-- if ent:HasModifier("modifier_boots_travel_lua") then
		-- 	return
		-- end

		if hasModifier then
			local tickRate = 0.06
			local tickDelay = 0.06

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
								print(ent:GetName(), "Landed on lava after spell, killing now")
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

		-- No modifiers, killing
		else
			print(ent:GetName(), " will be killed", ent:GetAbsOrigin())
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
		print(ent:GetName(), "touched kill box, killing")

		ent.isSafe = false
		ent.outOfBoundsDeath = true
		ent:SetBaseMagicalResistanceValue(25)
		return
	end
end

-- Stupid hack to bypass trigger killing with setorigin???
function OnStartKillTemp2(trigger)
	local ent = trigger.activator
	if not ent then return end
	--print(ent:GetName(), " has stepped on trigger")
	if ent:IsRealHero() and ent:IsAlive() then
		local tl = Vector(-4056, -2008, 128)
		local br = Vector(-3910, -2256, 128)

		if not OutsideRectangle(ent, tl, br) then
			print(ent:GetName(), "touched kill box, killing")

			ent.isSafe = false
			ent.outOfBoundsDeath = true
			ent:SetBaseMagicalResistanceValue(25)
			return
		end
	end
end

-- Stupid hack to bypass trigger killing with setorigin???
function OnStartKillTemp3(trigger)
	local ent = trigger.activator
	if not ent then return end
	--print(ent:GetName(), " has stepped on trigger")
	if ent:IsRealHero() and ent:IsAlive() then
		local tl = Vector(-2336, 752, 128)
		local br = Vector(-2192, 400, 128)

		if not OutsideRectangle(ent, tl, br) then
			print(ent:GetName(), "touched kill box, killing")

			ent.isSafe = false
			ent.outOfBoundsDeath = true
			ent:SetBaseMagicalResistanceValue(25)
			return
		end
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
			barebones:RemoveAllSkills()
			barebones:RemoveAllModifiers()
			barebones:CleanLevel(level-1)
			barebones:SetUpLevel(level)
			barebones:CheckPlayersInbounds(level)
			Timers:CreateTimer(0, function()
				barebones:ReviveAll()
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

		abil:EndCooldown()

		--print("Current slot for ", abil:GetAbilityName(), slot, abilSlot + 1)
		-- Checking proper slot
		if slot ~= (abilSlot + 1) then
			hero:SwapAbilities(abilName, "barebones_empty" .. slot, true, false)

			-- Particles for spell
			local partname = "particles/generic_hero_status/hero_levelup.vpcf"
			local part = ParticleManager:CreateParticle(partname, PATTACH_ABSORIGIN_FOLLOW, hero)
		
			local pos = hero:GetAbsOrigin()
			EmitSoundOnLocationForAllies(pos, "General.LevelUp", hero)
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

			if abil then
				local abilName = abil:GetAbilityName()
				
				print(i, removeName, abilName)
				if removeName == abilName then
					hero:SwapAbilities(abilName, "barebones_empty" .. (i+1), false, true)
				end
			end
    end
	end
end

function GiveAndRemoveSkill(trigger)
	print("Give and remove skill triggered")
	local hero = trigger.activator
	local trig = trigger.caller

	if trig then
		local trigName = trig:GetName()

		local level = tonumber(string.sub(trigName, 1, 1))
		local slot = tonumber(string.sub(trigName, 2, 2))
		local rest = string.sub(trigName, 3)

		local sep = string.find(rest, '%.')
		local giveAbil = string.sub(rest, 1, sep - 1)
		local removeAbil = string.sub(rest, sep + 1)

		if level == _G.currentLevel then
			-- Adding skill if somehow doesnt have
			if not hero:FindAbilityByName(giveAbil) then
				print("Giving skill to player")
				local tempAbil = hero:AddAbility(giveAbil)
				tempAbil:SetHidden(true)
				tempAbil:SetLevel(1)
			end				

			local abil = hero:FindAbilityByName(giveAbil)
			local abilSlot = abil:GetAbilityIndex()
			abil:EndCooldown()

			-- Checking proper slot
			if slot ~= (abilSlot + 1) then
				hero:SwapAbilities(giveAbil, "barebones_empty" .. slot, true, false)
	
				-- Particles for spell
				local partname = "particles/generic_hero_status/hero_levelup.vpcf"
				local part = ParticleManager:CreateParticle(partname, PATTACH_ABSORIGIN_FOLLOW, hero)
			
				local pos = hero:GetAbsOrigin()
				EmitSoundOnLocationForAllies(pos, "General.LevelUp", hero)
			end

			-- Removing ability
			for i = 0,5 do
				local abilGet = hero:GetAbilityByIndex(i)
	
				if abilGet then
					local abilName = abilGet:GetAbilityName()
					
					--print(i, removeName, abilName)
					if removeAbil == abilName then
						hero:SwapAbilities(abilName, "barebones_empty" .. (i+1), false, true)
					end
				end
			end

		end
	end
end

function GiveMana(trigger)
	local hero = trigger.activator
	local trig = trigger.caller
	if trig then
		if hero:GetMana() < 1 then
			local pos = hero:GetAbsOrigin()

			local partName = "particles/units/heroes/hero_keeper_of_the_light/keeper_chakra_magic.vpcf"
			local part = ParticleManager:CreateParticle(partName, PATTACH_ABSORIGIN, hero)
			
			local c = 0
			Timers:CreateTimer(function()
				if c < 1 then
					ParticleManager:SetParticleControl(part, 0, hero:GetAbsOrigin())
					ParticleManager:SetParticleControl(part, 1, hero:GetAbsOrigin())
					c = c + 0.03
					return 0.03
				else
					return
				end
			end)

			EmitSoundOnLocationForAllies(pos, "Hero_KeeperOfTheLight.ChakraMagic.Target", hero)

			hero:SetMana(1)
			hero.mana = 1
		end
	end
end

function GiveModifier(trigger)
	local hero = trigger.activator
	local trig = trigger.caller

	local name = trig:GetName()
	local level = tonumber(string.sub(name, 1, 1))
	local modName = string.sub(name, 2)

	if trig and level == _G.currentLevel then
		if not hero:HasModifier(modName) then
			hero:AddNewModifier(hero, nil, modName, {})
		end
	end
end

function FixAbuse(trigger)
	local hero = trigger.activator
	local trig = trigger.caller

	if trig then
		local abil1 = hero:FindAbilityByName("tusk_snowball_lua")
		local abil2 = hero:FindAbilityByName("tusk_snowball_release_lua")
		local abil3 = hero:FindAbilityByName("tusk_walrus_kick_custom")

		local index1 = abil1:GetAbilityIndex()
		local index2 = abil2:GetAbilityIndex()
		local index3 = abil3:GetAbilityIndex()

		if (index1 <= 5 or index2 <= 5) and index3 <= 5 then
			print("Found both spells, removing 1")

			hero:SwapAbilities("tusk_walrus_kick_custom", "barebones_empty" .. (index3+1), false, true)
		end
	end
end