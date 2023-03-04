-- This is the primary barebones gamemode script and should be used to assist in initializing your game mode
BAREBONES_VERSION = "2.0.9"

-- Selection library (by Noya) provides player selection inspection and management from server lua
require('libraries/selection')

-- settings.lua is where you can specify many different properties for your game mode and is one of the core barebones files.
require('settings')
-- events.lua is where you can specify the actions to be taken when any event occurs and is one of the core barebones files.
require('events')
-- filters.lua
require('filters')

require('core_mechanics')
require('unit_mechanics')
require('items')
require('abilities')
require('triggers')
require('patrols')

require('level_1')
require('level_2')
require('level_3')
require('level_4')
require('level_5')
require('level_6')

--[[
  This function should be used to set up Async precache calls at the beginning of the gameplay.

  In this function, place all of your PrecacheItemByNameAsync and PrecacheUnitByNameAsync.  These calls will be made
  after all players have loaded in, but before they have selected their heroes. PrecacheItemByNameAsync can also
  be used to precache dynamically-added datadriven abilities instead of items.  PrecacheUnitByNameAsync will 
  precache the precache{} block statement of the unit and all precache{} block statements for every Ability# 
  defined on the unit.

  This function should only be called once.  If you want to/need to precache more items/abilities/units at a later
  time, you can call the functions individually (for example if you want to precache units in a new wave of
  holdout).

  This function should generally only be used if the Precache() function in addon_game_mode.lua is not working.
]]
function barebones:PostLoadPrecache()
	DebugPrint("[BAREBONES] Performing Post-Load precache.")
	--PrecacheItemByNameAsync("item_example_item", function(...) end)
	--PrecacheItemByNameAsync("example_ability", function(...) end)

	--PrecacheUnitByNameAsync("npc_dota_hero_viper", function(...) end)
	--PrecacheUnitByNameAsync("npc_dota_hero_enigma", function(...) end)
end

--[[
  This function is called once and only once after all players have loaded into the game, right as the hero selection time begins.
  It can be used to initialize non-hero player state or adjust the hero selection (i.e. force random etc)
]]
function barebones:OnAllPlayersLoaded()
  DebugPrint("[BAREBONES] All Players have loaded into the game.")
  
  -- Force Random a hero for every play that didnt pick a hero when time runs out
  local delay = HERO_SELECTION_TIME + HERO_SELECTION_PENALTY_TIME + STRATEGY_TIME - 0.1
  if ENABLE_BANNING_PHASE then
    delay = delay + BANNING_PHASE_TIME
  end
  Timers:CreateTimer(delay, function()
    for playerID = 0, DOTA_MAX_TEAM_PLAYERS-1 do
      if PlayerResource:IsValidPlayerID(playerID) then
        -- If this player still hasn't picked a hero, random one
        -- PlayerResource:IsConnected(index) is custom-made; can be found in 'player_resource.lua' library
        if not PlayerResource:HasSelectedHero(playerID) and PlayerResource:IsConnected(playerID) and (not PlayerResource:IsBroadcaster(playerID)) then
          PlayerResource:GetPlayer(playerID):MakeRandomHeroSelection() -- this will cause an error if player is disconnected
          PlayerResource:SetHasRandomed(playerID)
          PlayerResource:SetCanRepick(playerID, false)
          DebugPrint("[BAREBONES] Randomed a hero for a player number "..playerID)
        end
      end
    end
  end)
end

--[[
  This function is called once and only once when the game completely begins (about 0:00 on the clock).  At this point,
  gold will begin to go up in ticks if configured, creeps will spawn, towers will become damageable etc.  This function
  is useful for starting any game logic timers/thinkers, beginning the first round, etc.
]]
function barebones:OnGameInProgress()
	DebugPrint("[BAREBONES] The game has officially begun.")

	-- Sets it to be nighttime, cycle disabled so 24/7 night
	GameRules:SetTimeOfDay(4)

	-- Constant running thinker to revive players
	Timers:CreateTimer(function()
		barebones:ReviveThinker()
		return 0.1
	end)

		-- Starts the thinker to check if everyones dead and to revive
	Timers:CreateTimer(4, function()
		if GameRules.Ongoing then
			barebones:CheckpointThinker()
			return 2
		end
	end)   

	-- Setting up gamescore data collection
	WebApi:InitGameScore()

	-- Setting up bot spawn for solo players
	local nPlayers = PlayerResource:GetPlayerCount()
	if nPlayers == 1 then
		local playerId = _G.PlayersTable[1]:GetPlayerID()

		local randomHero = GetRandomHeroName()
		local spawn = Entities:FindByName(nil, "checkpoint1"):GetAbsOrigin()

		local bot = GameRules:AddBotPlayerWithEntityScript(randomHero, "Buddy", DOTA_TEAM_GOODGUYS, nil, false)
		bot:SetControllableByPlayer(playerId, true)
		bot:SetAbsOrigin(spawn)
		bot.safe = true
	end
end

-- This function initializes the game mode and is called before anyone loads into the game
-- It can be used to pre-initialize any values/tables that will be needed later
function barebones:InitGameMode()
	DebugPrint("[BAREBONES] Starting to load Game Rules.")
	-- Grabbing data from DB first thing
	Timers:CreateTimer(0.1, function()
		print("LEADERBOARD: Running function initially")
		WebApi:GetLeaderboard()
		--GameRules:BotPopulate()
	end)

	local attempts = 0
	local MAX_ATTEMPTS = 5

	Timers:CreateTimer(0.2, function()
		print("PATREONS: Running function initially")
		if not WebApi.patreonsLoaded and attempts < MAX_ATTEMPTS then
			WebApi:GetPatreons()
		else
			return
		end
		attempts = attempts + 1
		return 10
	end)

	-- Setup rules
	GameRules:SetSameHeroSelectionEnabled(ALLOW_SAME_HERO_SELECTION)
	GameRules:SetUseUniversalShopMode(UNIVERSAL_SHOP_MODE)
	GameRules:SetHeroRespawnEnabled(ENABLE_HERO_RESPAWN)

	GameRules:SetHeroSelectionTime(HERO_SELECTION_TIME) --THIS IS IGNORED when "EnablePickRules" is "1" in 'addoninfo.txt' !
	GameRules:SetHeroSelectPenaltyTime(HERO_SELECTION_PENALTY_TIME)
	
	GameRules:SetPreGameTime(PRE_GAME_TIME)
	GameRules:SetPostGameTime(POST_GAME_TIME)
	GameRules:SetShowcaseTime(SHOWCASE_TIME)
	GameRules:SetStrategyTime(STRATEGY_TIME)

	GameRules:SetTreeRegrowTime(TREE_REGROW_TIME)

	GameRules:SetCustomGameEndDelay(10)

	if USE_CUSTOM_HERO_LEVELS then
		GameRules:SetUseCustomHeroXPValues(true)
	end

	--GameRules:SetGoldPerTick(GOLD_PER_TICK) -- Doesn't work 24.2.2020
	--GameRules:SetGoldTickTime(GOLD_TICK_TIME) -- Doesn't work 24.2.2020
	GameRules:SetStartingGold(NORMAL_START_GOLD)

	if USE_CUSTOM_HERO_GOLD_BOUNTY then
		GameRules:SetUseBaseGoldBountyOnHeroes(false) -- if true Heroes will use their default base gold bounty which is similar to creep gold bounty, rather than DOTA specific formulas
	end

	GameRules:SetHeroMinimapIconScale(MINIMAP_ICON_SIZE)
	GameRules:SetCreepMinimapIconScale(MINIMAP_CREEP_ICON_SIZE)
	GameRules:SetRuneMinimapIconScale(MINIMAP_RUNE_ICON_SIZE)
	GameRules:SetFirstBloodActive(ENABLE_FIRST_BLOOD)
	GameRules:SetHideKillMessageHeaders(HIDE_KILL_BANNERS)
	GameRules:LockCustomGameSetupTeamAssignment(LOCK_TEAMS)

	-- This is multi-team configuration stuff
	if USE_AUTOMATIC_PLAYERS_PER_TEAM then
		local num = math.floor(10/MAX_NUMBER_OF_TEAMS)
		local count = 0
		for team,number in pairs(TEAM_COLORS) do
			if count >= MAX_NUMBER_OF_TEAMS then
				GameRules:SetCustomGameTeamMaxPlayers(team, 0)
			else
				GameRules:SetCustomGameTeamMaxPlayers(team, num)
			end
			count = count + 1
		end
	else
		local count = 0
		for team,number in pairs(CUSTOM_TEAM_PLAYER_COUNT) do
			if count >= MAX_NUMBER_OF_TEAMS then
				GameRules:SetCustomGameTeamMaxPlayers(team, 0)
			else
				GameRules:SetCustomGameTeamMaxPlayers(team, number)
			end
			count = count + 1
		end
	end

	if USE_CUSTOM_TEAM_COLORS then
		for team,color in pairs(TEAM_COLORS) do
			SetTeamCustomHealthbarColor(team, color[1], color[2], color[3])
		end
	end

	DebugPrint("[BAREBONES] Done with setting Game Rules.")

	-- Event Hooks / Listeners
	ListenToGameEvent('dota_player_gained_level', Dynamic_Wrap(barebones, 'OnPlayerLevelUp'), self)
	ListenToGameEvent('dota_player_learned_ability', Dynamic_Wrap(barebones, 'OnPlayerLearnedAbility'), self)
	ListenToGameEvent('entity_killed', Dynamic_Wrap(barebones, 'OnEntityKilled'), self)
	ListenToGameEvent('player_connect_full', Dynamic_Wrap(barebones, 'OnConnectFull'), self)
	ListenToGameEvent('player_disconnect', Dynamic_Wrap(barebones, 'OnDisconnect'), self)
	ListenToGameEvent('dota_item_picked_up', Dynamic_Wrap(barebones, 'OnItemPickedUp'), self)
	ListenToGameEvent('last_hit', Dynamic_Wrap(barebones, 'OnLastHit'), self)
	ListenToGameEvent('dota_rune_activated_server', Dynamic_Wrap(barebones, 'OnRuneActivated'), self)
	ListenToGameEvent('tree_cut', Dynamic_Wrap(barebones, 'OnTreeCut'), self)

	ListenToGameEvent('dota_player_used_ability', Dynamic_Wrap(barebones, 'OnAbilityUsed'), self)
	ListenToGameEvent('dota_non_player_used_ability', Dynamic_Wrap(barebones, 'OnAbilityUsed'), self)
	ListenToGameEvent('game_rules_state_change', Dynamic_Wrap(barebones, 'OnGameRulesStateChange'), self)
	ListenToGameEvent('npc_spawned', Dynamic_Wrap(barebones, 'OnNPCSpawned'), self)
	ListenToGameEvent('dota_player_pick_hero', Dynamic_Wrap(barebones, 'OnPlayerPickHero'), self)
	ListenToGameEvent("player_reconnected", Dynamic_Wrap(barebones, 'OnPlayerReconnect'), self)
	ListenToGameEvent("player_chat", Dynamic_Wrap(barebones, 'OnPlayerChat'), self)

	ListenToGameEvent("dota_tower_kill", Dynamic_Wrap(barebones, 'OnTowerKill'), self)
	ListenToGameEvent("dota_player_selected_custom_team", Dynamic_Wrap(barebones, 'OnPlayerSelectedCustomTeam'), self)
	ListenToGameEvent("dota_npc_goal_reached", Dynamic_Wrap(barebones, 'OnNPCGoalReached'), self)


	-- Change random seed for math.random function
	local timeTxt = string.gsub(string.gsub(GetSystemTime(), ':', ''), '0','')
	math.randomseed(tonumber(timeTxt))

	DebugPrint("[BAREBONES] Setting filters.")

	local gamemode = GameRules:GetGameModeEntity()

	-- Setting the Order filter 
	gamemode:SetExecuteOrderFilter(Dynamic_Wrap(barebones, "OrderFilter"), self)

	-- Setting the Damage filter
	gamemode:SetDamageFilter(Dynamic_Wrap(barebones, "DamageFilter"), self)

	-- Setting the Modifier filter
	gamemode:SetModifierGainedFilter(Dynamic_Wrap(barebones, "ModifierFilter"), self)

	-- Setting the Experience filter
	gamemode:SetModifyExperienceFilter(Dynamic_Wrap(barebones, "ExperienceFilter"), self)

	-- Setting the Tracking Projectile filter
	gamemode:SetTrackingProjectileFilter(Dynamic_Wrap(barebones, "ProjectileFilter"), self)

	-- Setting the rune spawn filter
	gamemode:SetRuneSpawnFilter(Dynamic_Wrap(barebones, "RuneSpawnFilter"), self)

	-- Setting the bounty rune pickup filter
	gamemode:SetBountyRunePickupFilter(Dynamic_Wrap(barebones, "BountyRuneFilter"), self)

	-- Setting the Healing filter
	gamemode:SetHealingFilter(Dynamic_Wrap(barebones, "HealingFilter"), self)

	-- Setting the Gold Filter
	gamemode:SetModifyGoldFilter(Dynamic_Wrap(barebones, "GoldFilter"), self)

	-- Setting the Inventory filter
	gamemode:SetItemAddedToInventoryFilter(Dynamic_Wrap(barebones, "InventoryFilter"), self)

	DebugPrint("[BAREBONES] Done with setting Filters.")

	-- Global Lua Modifiers
	LinkLuaModifier("modifier_custom_invulnerable", "modifiers/modifier_custom_invulnerable", LUA_MODIFIER_MOTION_NONE)

	print("[BAREBONES] initialized.")
	DebugPrint("[BAREBONES] Done loading the game mode!\n\n")
	
	-- Increase/decrease maximum item limit per hero
	Convars:SetInt('dota_max_physical_items_purchase_limit', 64)

	-- Set up initial constants
	Timers:CreateTimer(1, function()
		_G.PlayersTable = {}

		barebones:InitializeGameConstants()
	end)	

  -- Loads the level
	Timers:CreateTimer(5, function()
		barebones:SetupMap()
	end)
end

function barebones:InitializeGameConstants()
	-- Setting up the game, variables and tables
  _G.Extras = {}
	_G.ExtraParticles = {}
	_G.Cheeses = {}

	Vote = {}
	votesNeeded = 6
	GameRules.Ongoing = true
	GameRules.VoteOngoing = false

	_G.patreonUsed = false

  GameRules.Lives = 8
  _G.currentLevel = 0
	GameRules.Checkpoint = Vector(0, 0, 0)

	-- All abilities and modifiers to give to everyone
	_G.abilList = {
		"tusk_ice_shards",
		--"tusk_snowball",
		--"tusk_launch_snowball",
		"tusk_snowball_lua",
		"tusk_snowball_release_lua",
		"tusk_walrus_kick_custom",
		"puck_phase_shift",
		"boots_travel_lua",
		"weaver_shukuchi_custom",
		"ursa_enrage_custom",
		"weaver_time_lapse"
	}

	_G.modifierList = {
		"modifier_item_ultimate_scepter_consumed",
		"modifier_tusk_snowball_host",
		"modifier_tusk_snowball_guest",
		"modifier_tusk_snowball_dummy"
	}

	-- Modifiers to check for leaving safety trigger
	_G.outOfBoundsModifiers = {
		"modifier_boots_travel_lua",
		"modifier_magnus_skewer_lua_debuff",
		"modifier_tusk_snowball_host",
		"modifier_tusk_snowball_guest"
	}

	-- Spell names to change to pure damage
	_G.SpellList = {}

  DOTA_TEAM_ZOMBIES = DOTA_TEAM_BADGUYS

  TeamColors = {}
  TeamColors[0] = {61, 210, 150} -- Teal
  TeamColors[1] = {243, 201, 9}  -- Yellow
  TeamColors[2] = {197, 77, 168} -- Pink
  TeamColors[3] = {255, 108, 0}  -- Orange
  TeamColors[4] = {52, 85, 255}  -- Blue
  TeamColors[5] = {101, 212, 19} -- Green
  TeamColors[6] = {129, 83, 54}  -- Brown
  TeamColors[7] = {77, 0, 1}     -- Dred (Dark Red)
  TeamColors[8] = {199, 228, 13} -- Olive
  TeamColors[9] = {140, 42, 244} -- Purple

  BeaconPart = {}
  BeaconPart[0] = "particles/beacons/kunkka_x_marks_teal.vpcf"
  BeaconPart[1] = "particles/beacons/kunkka_x_marks_yellow.vpcf" 
  BeaconPart[2] = "particles/beacons/kunkka_x_marks_pink.vpcf" 
  BeaconPart[3] = "particles/beacons/kunkka_x_marks_orange.vpcf" 
  BeaconPart[4] = "particles/beacons/kunkka_x_marks_blue.vpcf" 
  BeaconPart[5] = "particles/beacons/kunkka_x_marks_green.vpcf" 
  BeaconPart[6] = "particles/beacons/kunkka_x_marks_brown.vpcf" 
  BeaconPart[7] = "particles/beacons/kunkka_x_marks_dred.vpcf" 
  BeaconPart[8] = "particles/beacons/kunkka_x_marks_olive.vpcf" 
  BeaconPart[9] = "particles/beacons/kunkka_x_marks_purple.vpcf" 

  -- Table for multiple patrol creeps {"waypoint1", "waypoint2", "etc"}
	_G.MultVector = {{}, {}, {}, {}, {}, {}}

  _G.MultPatrol = {
		{ -- Level 1
			{"p1_1_1a",  "p1_1_1b"}, -- 1
			{"p1_1_2a",  "p1_1_2b"},
			{"p1_2a",  "p1_2b"},
			{"p1_3a",  "p1_3b"},
			{"p1_4a",  "p1_4b"}, -- 5
			{"p1_5a",  "p1_5b"}, 
			{"p1_6a",  "p1_6b"},
			{"p1_7a",  "p1_7b"},
		},
		{ -- Level 2
			{"p2_1a", "p2_1b"},
			{"p2_2a", "p2_2b"},
			{"p2_3a", "p2_3b"},
			{"p2_4a", "p2_4b"}, 
			{"p2_5a", "p2_5b"}, 
			{"p2_6a", "p2_6b"}, 
			{"p2_7a", "p2_7b"}, 
			{"p2_8a", "p2_8b"}, 
			{"p2_9a", "p2_9b"}, 
		},
		{ -- Level 3
			{"p3_1a", "p3_1b"},
			{"p3_2a", "p3_2b", "p3_2c"},
			{"p3_3a", "p3_3b"},
			{"p3_4a", "p3_4b"},
			{"p3_5a", "p3_5b"}, -- 5
			{"p3_6a", "p3_6b"},
			{"p3_7a", "p3_7b"},
			{"p3_8a", "p3_8b"},
			{"p3_9a", "p3_9b"},
			{"p3_10a", "p3_10b", "p3_10c", "p3_10d"}, -- 10
		},
		{ -- Level 4
			{"p4_1a", "p4_1b"},
			{"p4_2a", "p4_2b"},
			{"f4_2a", "f4_2b"},
			{"p4_3a", "p4_3b"},
			{"p4_4a", "p4_4b"}, -- 5
			{"p4_5a", "p4_5b"},
			{"f4_3a", "f4_3b"},
			{"f4_4a", "f4_4b"},
			{"p4_6a", "p4_6b"},
			{"p4_7a", "p4_7b"}, -- 10
			{"p4_8a", "p4_8b"},
			{"p4_9a", "p4_9b"},
			{"f4_6a", "f4_6b"},
			{"p4_10a", "p4_10b"},
			{"p4_11a", "p4_11b"}, -- 15
			{"p4_12a", "p4_12b"}, 
			{"p4_13a", "p4_13b", "p4_13c", "p4_13d"},
			{"f4_7a", "f4_7b", "f4_7c"},
		},
		{ -- Level 5
			{"sel5_1", "sel5_1"},
			{"sel5_2a", "sel5_2b"}, 
			{"sel5_3", "sel5_3"}, 
			{"sel5_4", "sel5_4"},
			{"sel5_5", "sel5_5"}, -- 5
			{"sel5_6", "sel5_6"}, 
			{"sel5_7", "sel5_7"}, 
		},
		{ -- Level 6
			{"p6_4_1a", "p6_4_1a"},
			{"p6_4_2a", "p6_4_2a"},
			{"p6_4_3a", "p6_4_3a"},
			{"p6_4_4a", "p6_4_4b"},
			{"p6_4_5a", "p6_4_5a"}, -- 5
		}
  }

  -- Table for ent names
  Ents = {
		"item_mango_custom", -- 1
		"item_cheese_custom",
		"npc_creep_patrol",
		"npc_gate",
		"npc_dummy_unit", -- 5
		"npc_zombie_static",
		"npc_dummy_unit",
		"npc_dummy_unit",
		"npc_dummy_unit",
		"npc_dummy_unit", -- 10
		"npc_dummy_unit",
		"npc_dummy_unit",
		"npc_friendly",
		"npc_creep_patrol_selectable",
  }

	ENT_MANGO_ = 1; 
	ENT_CHEESE = 2; 
	ENT_PATROL = 3;  -- Standard Patrol
	ENT_GATE__ = 4;  -- Gate
	ENT_AOELSA = 5;  -- LSA AOE 
	ENT_STATIC = 6;  -- Big Static Zombie
	ENT_MULTI_ = 7;  -- Multi patrol
	ENT_MAGNUS = 8;  -- Patrol magnus skewer
	ENT_CARTY_ = 9;  -- Carty wall, non-patrol
	ENT_GALE__ = 10; -- Gale force
	ENT_CIRCLE = 11; -- Circular patrol, spacing/gap
	ENT_MULTI2 = 12; -- Double multi patrol
	ENT_GGSEL_ = 13; -- Friendly patrol
	ENT_BGSEL_ = 14; -- Enemy castable patrol

	-- Types
	-- 1-Item, 2-Enemy, 3-Friendly, 4-Selectable Enemy

  -- Table for all ents (exc pat creeps) {item/unit/part, ent#, entindex, spawn, function, etc}
	EntList = {
	{ -- Level 1
		{1, ENT_CHEESE, 0, "cheese1_1", nil},
		{1, ENT_MANGO_, 0, "mango1_1", nil, false},
		{2, ENT_GATE__, 0, "gate1_1a", "GateThinker", "gate1_1b", Vector(0, 1, 0), 1},
		{2, ENT_PATROL, 0, "p1_1_1a",  "WavePatrolThinker", 1,  0.0, 325, 250, 2},
		{2, ENT_PATROL, 0, "p1_1_1a",  "WavePatrolThinker", 1,  1.5, 325, -250, 2},
		{2, ENT_PATROL, 0, "p1_1_1a",  "WavePatrolThinker", 1,  3.0, 325, 250, 2},
		{2, ENT_PATROL, 0, "p1_1_1a",  "WavePatrolThinker", 1,  4.5, 325, -250, 2},
		{2, ENT_PATROL, 0, "p1_1_1a",  "WavePatrolThinker", 1,  6.0, 325, 250, 2},
		{2, ENT_PATROL, 0, "p1_1_1a",  "WavePatrolThinker", 1,  7.5, 325, -250, 2},
		{2, ENT_PATROL, 0, "p1_1_1a",  "WavePatrolThinker", 1,  8.0, 325, 250, 2},
		{2, ENT_CIRCLE, 0, "mango1_1",  "CircularWithGapThinker", 325, 300, 300, 20, 12},
		{2, ENT_CIRCLE, 0, "cheese1_1",  "CircularWithGapThinker", 330, 300, 320, 20, -8},

		{2, ENT_GATE__, 0, "gate1_2a", "GateThinker", "gate1_2b", Vector(0, 1, 0), 6},
		{2, ENT_CIRCLE, 0, "circular1",  "CircularWithGapThinker", 325, 300, 300, 25, 12},
		{1, ENT_MANGO_, 0, "mango1_2", nil, false},
		{1, ENT_MANGO_, 0, "mango1_3", nil, false},
		{1, ENT_MANGO_, 0, "mango1_4", nil, false},
		{1, ENT_MANGO_, 0, "mango1_5", nil, false},
		{1, ENT_MANGO_, 0, "mango1_6", nil, false},
		{1, ENT_MANGO_, 0, "mango1_7", nil, false},

		{2, ENT_PATROL, 0, "p1_1_2a",  "WavePatrolThinker", 2,  0, 280, 200, 1},
		{2, ENT_PATROL, 0, "p1_1_2a",  "WavePatrolThinker", 2,  0, 280, 200, 2},
		{2, ENT_PATROL, 0, "p1_1_2a",  "WavePatrolThinker", 2,  0, 280, 200, 3},
		{2, ENT_PATROL, 0, "p1_1_2a",  "WavePatrolThinker", 2,  0, 280, 200, 5},
		{2, ENT_PATROL, 0, "p1_1_2a",  "WavePatrolThinker", 2,  0, 280, 200, 7},
		{2, ENT_PATROL, 0, "p1_1_2a",  "WavePatrolThinker", 2,  0, 280, 200, 11},
		{2, ENT_PATROL, 0, "p1_1_2a",  "WavePatrolThinker", 2,  0, 280, 200, 13},
		{2, ENT_PATROL, 0, "p1_1_2a",  "WavePatrolThinker", 2,  0, 280, 200, 17},

		{2, ENT_PATROL, 0, "p1_2a",  "WavePatrolThinker", 3,  0, 260, 450, 2},
		{2, ENT_PATROL, 0, "p1_3a",  "WavePatrolThinker", 4,  0, 280, 400, 4},
		{2, ENT_PATROL, 0, "p1_4a",  "WavePatrolThinker", 5,  0, 400, 450, 3},
		{2, ENT_PATROL, 0, "p1_5a",  "WavePatrolThinker", 6,  0, 425, 425, 4},
		{2, ENT_PATROL, 0, "p1_6a",  "WavePatrolThinker", 7,  0, 425, 400, 3},
		{2, ENT_PATROL, 0, "p1_7a",  "WavePatrolThinker", 8,  0, 450, 375, 4},
	},


	{ -- Level 2
		-- Intro
		{2, ENT_GALE__, 0, "gale2_1", "GaleThinker", 0, 0, 300, 180},
		{2, ENT_GALE__, 0, "gale2_2", "GaleThinker", 0, 0, 450, 90},
		{2, ENT_GALE__, 0, "gale2_3", "GaleThinker", 5, 4.8, 500, -1},
		{2, ENT_AOELSA, 0, "lsa2_1", "AOEThinker", 2.5, 0, true}, 
		{2, ENT_PATROL, 0, "p2_1a", "PatrolThinker", 1, 0, 325},
		{2, ENT_PATROL, 0, "p2_2a", "PatrolThinker", 2, 0, 350},
		{2, ENT_PATROL, 0, "p2_3a", "PatrolThinker", 3, 0, 375},
		{2, ENT_PATROL, 0, "p2_4a", "PatrolThinker", 4, 0, 400},

		-- 3 patrol only
		{2, ENT_GATE__, 0, "gate2_1a", "GateThinker", "gate2_1b", Vector(1, 0, 0), 6},
		{2, ENT_GALE__, 0, "gale2_4", "GaleThinker", 0, 0, 500, 90},
		{2, ENT_PATROL, 0, "p2_5a", "PatrolThinker", 5, 0, 300},
		{2, ENT_PATROL, 0, "p2_6a", "PatrolThinker", 6, 0, 350},
		{2, ENT_PATROL, 0, "p2_7a", "PatrolThinker", 7, 0, 450},
		{1, ENT_MANGO_, 0, "mango2_1", nil, false},
		
		-- LSA mix
		{2, ENT_GALE__, 0, "gale2_5", "GaleThinker", 8, 7.8, 500, -1},
		{2, ENT_AOELSA, 0, "lsa2_2", "AOEThinker", 5.2, 2.6, false}, 
		{2, ENT_AOELSA, 0, "lsa2_3", "AOEThinker", 5.2, 0, false}, 

		{2, ENT_AOELSA, 0, "lsa2_4", "AOEThinker", 4.8, 0, false}, 
		{2, ENT_AOELSA, 0, "gale2_5", "AOEThinker", 4.8, 2.4, true}, 
		{2, ENT_AOELSA, 0, "lsa2_5", "AOEThinker", 4.8, 0, false}, 

		{2, ENT_AOELSA, 0, "lsa2_6", "AOEThinker", 5.8, 2.9, false}, 
		{2, ENT_AOELSA, 0, "lsa2_7", "AOEThinker", 5.8, 0, false}, 
		{1, ENT_MANGO_, 0, "mango2_2", nil, false},

		-- Right entry
		{2, ENT_GALE__, 0, "gale2_6", "GaleThinker", 0, 0, 480, 270},
		{2, ENT_AOELSA, 0, "gale2_6", "AOEThinker", 3, 0, true}, 
		{2, ENT_MULTI_, 0, "m2_1a", "WallPatrolThinker", "m2_1b", 200, 0, 550},
		{2, ENT_PATROL, 0, "p2_8a", "PatrolThinker", 8, 0, 400},
		{1, ENT_MANGO_, 0, "mango2_3", nil, false},
		{1, ENT_MANGO_, 0, "mango2_4", nil, false},

		{2, ENT_GALE__, 0, "gale2_7", "GaleThinker", 0, 0, 425, 180},
		{2, ENT_AOELSA, 0, "gale2_7", "AOEThinker", 2.1, 0, true}, 

		-- Left exit
		{2, ENT_GALE__, 0, "gale2_8", "GaleThinker", 0, 0, 480, 90},
		{2, ENT_AOELSA, 0, "gale2_8", "AOEThinker", 2.7, 0, true}, 
		{2, ENT_CIRCLE, 0, "gale2_8",  "CircularWithGapThinker", 325, 425, 288, 72, -6},
		{1, ENT_MANGO_, 0, "mango2_5", nil, false},
		{1, ENT_MANGO_, 0, "mango2_6", nil, false},

		-- Cheese
		{1, ENT_CHEESE, 0, "cheese2_1", nil},
		{2, ENT_GALE__, 0, "gale2_9", "GaleThinker", 5, 4.8, 500, -1},
		{2, ENT_AOELSA, 0, "cheese2_1", "AOEThinker", 1.75, 0, true}, 
		{2, ENT_PATROL, 0, "p2_9a", "PatrolThinker", 9, 0, 500},

		-- Last LSA/Mango
		{2, ENT_GATE__, 0, "gate2_2a", "GateThinker", "gate2_2b", Vector(-1, 0, 0), 8},
		{2, ENT_GALE__, 0, "gale2_10", "GaleThinker", 0, 0, 900, 0},
		{2, ENT_MULTI_, 0, "m2_2a", "WallPatrolThinker", "m2_2b", 650, 0, 400},
		{2, ENT_GALE__, 0, "gale2_11", "GaleThinker", 8, 7.8, 1000, -1},
	},


	{ -- Level 3
		{1, ENT_CHEESE, 0, "cheese3_1", nil}, 
		{2, ENT_AOELSA, 0, "lsa3_1", "AOEThinker", 2, 0, true}, 
		{2, ENT_AOELSA, 0, "lsa3_2", "AOEThinker", 2, 0, false},   
		{2, ENT_MAGNUS, 0, "mag3_1a", "MagnusThinker", "mag3_1b", 0.5, 0.5},
		{2, ENT_MAGNUS, 0, "mag3_2a", "MagnusThinker", "mag3_2b", 0.4, 0.6},
		{2, ENT_PATROL, 0, "p3_1a", "PatrolThinker", 1, 0.03, 400},
		{2, ENT_PATROL, 0, "p3_2a", "PatrolThinker", 2, 0.03, 300},
		{2, ENT_GATE__, 0, "gate3_1a", "GateThinker", "gate3_1b", Vector(1, 0, 0), 5},
		{1, ENT_MANGO_, 0, "mango3_1", nil, false},
		{1, ENT_MANGO_, 0, "mango3_2", nil, false},
		{1, ENT_MANGO_, 0, "mango3_3", nil, false},
		{1, ENT_MANGO_, 0, "mango3_4", nil, false},
		{1, ENT_MANGO_, 0, "mango3_5", nil, false},

		{2, ENT_MAGNUS, 0, "mag3_6a", "MagnusThinker", "mag3_6b", 0.25, 0},
		{2, ENT_AOELSA, 0, "lsa3_3", "AOEThinker", 1.9, 0, true},  
		{2, ENT_AOELSA, 0, "lsa3_4", "AOEThinker", 1.9, 0, false},  

		{2, ENT_MAGNUS, 0, "mag3_3a", "MagnusThinker", "mag3_3b", 0.9, 0},
		{2, ENT_MAGNUS, 0, "mag3_4a", "MagnusThinker", "mag3_4b", 0.57, 0},
		{2, ENT_MAGNUS, 0, "mag3_5a", "MagnusThinker", "mag3_5b", 0.9, 4.5},
		{2, ENT_AOELSA, 0, "lsa3_5", "AOEThinker", 2.5, 0, true},  
		{2, ENT_AOELSA, 0, "lsa3_6", "AOEThinker", 2.5, 0, false}, 

		-- {2, ENT_PATROL, 0, "p3_3a", "PatrolThinker", 3, 0, 300, 1},
		-- {2, ENT_PATROL, 0, "p3_4a", "PatrolThinker", 4, 0, 365, 1},
		{2, ENT_PATROL, 0, "p3_5a", "PatrolThinker", 5, 0, 285},
		{2, ENT_PATROL, 0, "p3_6a", "PatrolThinker", 6, 0, 275},
		{2, ENT_PATROL, 0, "p3_7a", "PatrolThinker", 7, 0, 295},
		{2, ENT_AOELSA, 0, "lsa3_7", "AOEThinker", 3, 0, true},  
		{2, ENT_AOELSA, 0, "lsa3_8", "AOEThinker", 3, 1.5, false}, 
		{2, ENT_MAGNUS, 0, "mag3_7a", "MagnusThinker", "mag3_7b", 3, 0},
		{2, ENT_MAGNUS, 0, "mag3_8a", "MagnusThinker", "mag3_8b", 4, 0}, 
		{2, ENT_AOELSA, 0, "lsa3_9", "AOEThinker", 6, 0, true},  

		{1, ENT_MANGO_, 0, "lsa3_9", nil, true},
		{2, ENT_GATE__, 0, "gate3_2a", "GateThinker", "gate3_2b", Vector(0, -1, 0), 1},
		{2, ENT_MAGNUS, 0, "mag3_9a", "MagnusThinker", "mag3_9b", 0.45, 0},
		{2, ENT_AOELSA, 0, "lsa3_10", "AOEThinker", 1.85, 0, true},  
		{2, ENT_PATROL, 0, "p3_8a", "PatrolThinker", 8, 0, 325},
		{2, ENT_PATROL, 0, "p3_9a", "PatrolThinker", 9, 0, 375},
		{2, ENT_PATROL, 0, "p3_10a", "PatrolThinker", 10, 0, 320, 0.25},
	},


	{ -- Level 4 
		{1, ENT_CHEESE, 0, "cheese4_1", nil},
		{3, ENT_GGSEL_, 0, "f4_1", "PatrolThinker", 0, 0, 300},
		{2, ENT_MULTI_, 0, "m4_1a", "WallPatrolThinker", "m4_1b", 200, 0, 300},
		{2, ENT_PATROL, 0, "p4_1a", "PatrolThinker", 1, 0, 465, 0},
		{2, ENT_PATROL, 0, "p4_2a", "PatrolThinker", 2, 0, 400, 0},
		{3, ENT_GGSEL_, 0, "f4_2a", "PatrolThinker", 3, 0, 300},
		{2, ENT_MULTI_, 0, "m4_2a", "WallPatrolThinker", "m4_2b", 200, 0, 300},
		{2, ENT_STATIC, 0, "z4_1", "StaticThinker"},
		{2, ENT_STATIC, 0, "z4_2", "StaticThinker"},
		{2, ENT_AOELSA, 0, "lsa4_1", "AOEThinker", 1.9, 0, true}, 
		{2, ENT_PATROL, 0, "p4_3a", "PatrolThinker", 4, 0, 400},
		{2, ENT_PATROL, 0, "p4_4a", "PatrolThinker", 5, 0, 350},
		{2, ENT_PATROL, 0, "p4_5a", "PatrolThinker", 6, 0, 350},
		{2, ENT_STATIC, 0, "z4_3", "StaticThinker"},

		{3, ENT_GGSEL_, 0, "f4_3a", "PatrolThinker", 7, 0, 300},
		{2, ENT_GATE__, 0, "gate4_1a", "GateThinker", "gate4_1b", Vector(1, 0, 0), 4},       
		{1, ENT_MANGO_, 0, "mango4_1", nil, true},
		{1, ENT_MANGO_, 0, "mango4_2", nil, true},
		{1, ENT_MANGO_, 0, "mango4_3", nil, true},
		{1, ENT_MANGO_, 0, "mango4_4", nil, true},
		{2, ENT_AOELSA, 0, "lsa4_2", "AOEThinker", 3, 0, true}, 

		{2, ENT_CARTY_, 0, "carty4_1a", "MovingWallThinker", "carty4_1b", 450, 0, 185, 6},
		{3, ENT_GGSEL_, 0, "f4_4a", "PatrolThinker", 8, 0, 300},
		{2, ENT_PATROL, 0, "p4_6a", "PatrolThinker", 9, 0, 275},
		{2, ENT_PATROL, 0, "p4_7a", "PatrolThinker", 10, 0, 325},
		{2, ENT_PATROL, 0, "p4_8a", "PatrolThinker", 11, 0, 375},
		{2, ENT_AOELSA, 0, "lsa4_3", "AOEThinker", 5, 0, true}, 
		{3, ENT_GGSEL_, 0, "f4_5a", "PatrolThinker", 0, 0, 300},
		{2, ENT_PATROL, 0, "p4_9a", "PatrolThinker", 12, 0, 365, 0.5},
		{2, ENT_AOELSA, 0, "lsa4_4", "AOEThinker", 3, 0, true}, 
		{2, ENT_AOELSA, 0, "lsa4_5", "AOEThinker", 3, 1.5, false}, 
		{2, ENT_STATIC, 0, "z4_4", "StaticThinker"},
		{2, ENT_STATIC, 0, "z4_5", "StaticThinker"},
		{2, ENT_STATIC, 0, "z4_6", "StaticThinker"},
		{2, ENT_STATIC, 0, "z4_7", "StaticThinker"},
		{3, ENT_GGSEL_, 0, "f4_6a", "PatrolThinker", 13, 0, 300},

		{2, ENT_CARTY_, 0, "carty4_2a", "MovingWallThinker", "carty4_2b", 450, 0, 200, 9.5},
		{1, ENT_MANGO_, 0, "mango4_5", nil, false},
		{1, ENT_MANGO_, 0, "mango4_6", nil, false},
		{1, ENT_MANGO_, 0, "mango4_7", nil, false},
		{1, ENT_MANGO_, 0, "mango4_8", nil, false},
		{1, ENT_MANGO_, 0, "mango4_9", nil, false},
		{2, ENT_GATE__, 0, "gate4_2a", "GateThinker", "gate4_2b", Vector(-1, 0, 0), 5},       
		{2, ENT_PATROL, 0, "p4_10a", "PatrolThinker", 14, 0, 225},
		{2, ENT_PATROL, 0, "p4_11a", "PatrolThinker", 15, 0, 275},
		{2, ENT_PATROL, 0, "p4_12a", "PatrolThinker", 16, 0, 300, 0.5},
		{2, ENT_PATROL, 0, "p4_13a", "PatrolThinker", 17, 0, 275},
		{2, ENT_PATROL, 0, "p4_13c", "PatrolThinker", 17, 0, 275},
		{2, ENT_MAGNUS, 0, "mag4_1a", "MagnusThinker", "mag4_1b", 0.5, 0},
		{3, ENT_GGSEL_, 0, "f4_7a", "PatrolThinker", 18, 0, 285},
	},


	{ -- Level 5
		{4, ENT_BGSEL_, 0, "sel5_1", {"PatrolThinker", "TetherThinker", "WalrusKickMinistunThinker"}, 1, 0.03, 250},
		{2, ENT_MULTI_, 0, "m5_1a", "WallPatrolThinker", "m5_1b", 250, 0, 250},
		{4, ENT_BGSEL_, 0, "sel5_2a", {"PatrolThinker", "TetherThinker", "WalrusKickMinistunThinker"}, 2, 0.03, 250},
		{4, ENT_BGSEL_, 0, "sel5_3", {"PatrolThinker", "TetherThinker", "WalrusKickMinistunThinker"}, 3, 0.03, 250},
		{2, ENT_AOELSA, 0, "lsa5_1", "AOEThinker", 7.5, 0, true}, 
		{4, ENT_BGSEL_, 0, "sel5_4", {"PatrolThinker", "TetherThinker", "WalrusKickMinistunThinker"}, 4, 0.03, 250},

		--{2, ENT_MULTI_, 0, "m5_2a", "WallPatrolThinker", "m5_2b", 775, 0, 260},
		--{2, ENT_MULTI_, 0, "m5_2b", "WallPatrolThinker", "m5_2a", 775, 0, 260},
		{2, ENT_CARTY_, 0, "m5_2a", "MovingWallThinker", "m5_2b", 850, 0, 350, 3.5},
		{4, ENT_BGSEL_, 0, "sel5_5", {"PatrolThinker", "TetherThinker", "WalrusKickMinistunThinker"}, 5, 0.03, 250},

		{4, ENT_BGSEL_, 0, "sel5_6", {"PatrolThinker", "TetherThinker", "WalrusKickMinistunThinker"}, 6, 0.03, 250},
		{2, ENT_CARTY_, 0, "wall5_1a", "MovingWallThinker", "wall5_1b", 225, 0, 240, 7},
		--{2, ENT_CARTY_, 0, "wall5_1b", "MovingWallThinker", "wall5_1a", 225, 0, 240, 7},
		{4, ENT_BGSEL_, 0, "sel5_7", {"PatrolThinker", "TetherThinker", "WalrusKickMinistunThinker"}, 7, 0.03, 250},
		{2, ENT_AOELSA, 0, "lsa5_2", "AOEThinker", 7.3, 0, true}, 
		{2, ENT_AOELSA, 0, "lsa5_2_1", "AOEThinker", 4.8, 0, true}, 
		--{2, ENT_CARTY_, 0, "wall5_2a", "MovingWallThinker", "wall5_2b", 225, 0, 240, 3.5},
		--{2, ENT_CARTY_, 0, "wall5_2b", "MovingWallThinker", "wall5_2a", 225, 0, 240, 3.5},

		{2, ENT_GATE__, 0, "gate5_1a", "GateThinker", "gate5_1b", Vector(-1, 0, 0), 4},       
		{1, ENT_MANGO_, 0, "mango5_1", nil, true},
		{1, ENT_MANGO_, 0, "mango5_2", nil, true},
		{1, ENT_MANGO_, 0, "mango5_3", nil, true},
		{1, ENT_MANGO_, 0, "mango5_4", nil, true},
		{2, ENT_MULTI_, 0, "m5_3a", "WallPatrolThinker", "m5_3b", 175, 0, 245},
		{2, ENT_MULTI_, 0, "m5_4a", "WallPatrolThinker", "m5_4b", 175, 0, 225},
		{2, ENT_MULTI_, 0, "m5_5a", "WallPatrolThinker", "m5_5b", 175, 0, 225},
		{2, ENT_AOELSA, 0, "lsa5_3", "AOEThinker", 12, 0, true}, 
		{2, ENT_AOELSA, 0, "lsa5_4", "AOEThinker", 12, 4, true}, 
		{2, ENT_AOELSA, 0, "lsa5_5", "AOEThinker", 12, 8, true}, 
		{2, ENT_CARTY_, 0, "wall5_3a", "MovingWallThinker", "wall5_3b", 95, 100, 240, 6.8},
		{2, ENT_CARTY_, 0, "wall5_3b", "MovingWallThinker", "wall5_3a", 95, 100, 240, 6.8},
	},


	{ -- Level 6																		 			 Rad, Spc, MVSP, Gap, Rate
		-- Layer 1
		{2, ENT_MULTI2, 0, "g6_1_1a", "GapThinker", "g6_1_1b", 150, 100, 245, 240, 0.5, 0},
		{2, ENT_MULTI2, 0, "g6_1_2a", "GapThinker", "g6_1_2b", 225, 100, 220, 275, 0, 0},
		{2, ENT_MULTI2, 0, "g6_1_3a", "GapThinker", "g6_1_3b", 325, 100, 220, 300, 0.5, 0},
		{2, ENT_MULTI2, 0, "g6_1_4a", "GapThinker", "g6_1_4b", 800, 100, 220, 300, 0.12, 0},
		{2, ENT_AOELSA, 0, "lsa6_1", "AOEThinker", 4, 0, true}, 
		{2, ENT_AOELSA, 0, "lsa6_2", "AOEThinker", 4, 0, true}, 

		-- Layer 2
		{2, ENT_GATE__, 0, "gate6_1a", "GateThinker", "gate6_1b", Vector(0, -1, 0), 8},       
		{1, ENT_MANGO_, 0, "mango6_1", nil, false},
		{1, ENT_MANGO_, 0, "mango6_2", nil, false},
		{1, ENT_MANGO_, 0, "mango6_3", nil, false},
		{1, ENT_MANGO_, 0, "mango6_4", nil, false},
		{1, ENT_MANGO_, 0, "mango6_5", nil, false},
		{1, ENT_MANGO_, 0, "mango6_6", nil, false},
		{1, ENT_MANGO_, 0, "mango6_7", nil, false},
		{1, ENT_MANGO_, 0, "mango6_8", nil, false},

		{2, ENT_CARTY_, 0, "carty6_1a", "MovingWallThinker", "carty6_1b", 60, 0, 240, 5.5},
		{2, ENT_CARTY_, 0, "carty6_2a", "MovingWallThinker", "carty6_2b", 60, 0, 240, 5.5},
		{2, ENT_MULTI_, 0, "g6_2_1a", "WallPatrolThinker", "g6_2_1b", 250, 0, 250},
		{2, ENT_MULTI2, 0, "g6_2_2a", "GapThinker", "g6_2_2b", 300, 100, 170, 240, 2, 0},
		{2, ENT_MULTI2, 0, "g6_2_4a", "GapThinker", "g6_2_4b", 1000, 100, 100, 300, 0, 0},

		-- Layer 3
		-- {2, ENT_CARTY_, 0, "carty6_3a", "MovingWallThinker", "carty6_3b", 225, 0, 240, 4},
		{2, ENT_MULTI2, 0, "g6_3_1a", "GapThinker", "g6_3_1b", 300, 100, 170, 250, 1, 0},
		{2, ENT_AOELSA, 0, "lsa6_3_1", "AOEThinker", 6, 0, false}, 
		{2, ENT_AOELSA, 0, "lsa6_3_2", "AOEThinker", 6, 3, true}, 
		{2, ENT_MULTI2, 0, "g6_3_2a", "GapThinker", "g6_3_2b", 625, 100, 170, 275, 0.75, 0},
		{2, ENT_AOELSA, 0, "lsa6_3_3", "AOEThinker", 6, 0, true}, 
		{2, ENT_AOELSA, 0, "lsa6_3_4", "AOEThinker", 6, 0, false}, 
		{2, ENT_AOELSA, 0, "lsa6_3_5", "AOEThinker", 6, 3, false}, 
		{2, ENT_AOELSA, 0, "lsa6_3_6", "AOEThinker", 6, 3, false}, 
		{2, ENT_MULTI2, 0, "g6_3_3a", "GapThinker", "g6_3_3b", 1100, 100, 170, 275, 0.5, 0},

		-- Layer 4
		{2, ENT_CARTY_, 0, "carty6_4a", "MovingWallThinker", "carty6_4b", 175, 0, 250, 25},
		{2, ENT_MULTI2, 0, "g6_4_1a", "GapThinker", "g6_4_1b", 75, 100, 165, 270, 0.3, 0},
		{2, ENT_MULTI2, 0, "g6_4_2a", "GapThinker", "g6_4_2b", 75, 100, 225, 245, 0.3, 0},
		{2, ENT_MULTI2, 0, "g6_4_3a", "GapThinker", "g6_4_3b", 101, 100, 110, 225, 0.3, 0},
		
		{2, ENT_MULTI2, 0, "g6_4_4a", "GapThinker", "g6_4_4b", 250, 100, 180, 300, 0, 0},
		{2, ENT_PATROL, 0, "p6_4_1a", "PatrolThinker", 0, 0, 300},

		{2, ENT_MULTI2, 0, "g6_4_5a", "GapThinker", "g6_4_5b", 300, 100, 165, 265, 0, 0},
		{2, ENT_PATROL, 0, "p6_4_2a", "PatrolThinker", 0, 0, 300},
		{2, ENT_PATROL, 0, "p6_4_3a", "PatrolThinker", 0, 0, 300},

		{2, ENT_MULTI2, 0, "g6_4_7a", "GapThinker", "g6_4_7b", 600, 100, 175, 265, 0, 0},
		{2, ENT_PATROL, 0, "p6_4_4a", "PatrolThinker", 4, 0, 225},
		{2, ENT_PATROL, 0, "p6_4_5a", "PatrolThinker", 0, 0, 225},
		{2, ENT_AOELSA, 0, "lsa6_4_1", "AOEThinker", 4, 0, true}, 
	}
}

	
  -- Constants for EntList table and PartList
  ENT_UNTIM = 1; ENT_TYPEN = 2; ENT_INDEX = 3; ENT_SPAWN = 4; ENT_RFUNC = 5;
  PAR_FNAME = 1; PAR_SPAWN = 2; PAR_CTRLP = 3;

	PAT_VECNM = 6; PAT_DELAY = 7; PAT_MVSPD = 8; PAT_TURND = 9;
																							 PAT_AMPLT = 9; PAT_PEROD = 10;
	MNG_RSPWN = 6;
	GAT_MOVES = 6; GAT_ORIEN = 7; GAT_NUMBR = 8;
	AOE_RATES = 6; AOE_DELAY = 7; AOE_SOUND = 8;
	MAG_GOALS = 6; MAG_RATES = 7; MAG_DELAY = 8;
	MLT_GOALS = 6; MLT_RADII = 7; MLT_SPACE = 8; MLT_MVSPD = 9;
	CAR_GOALS = 6; CAR_RADII = 7; CAR_SPACE = 8; CAR_MVSPD = 9; CAR_RATES = 10;
	GAL_RATES = 6; GAL_DURAT = 7; GAL_RADII = 8; GAL_DIREC = 9;
	CIR_MVSPD = 6; CIR_RADII = 7; CIR_ANGLE = 8; CIR_INCRE = 9; CIR_RATES = 10;
	GAP_GOALS = 6; GAP_RADII = 7; GAP_SPACE = 8; GAP_MVSPD = 9; GAP_DTGAP = 10; GAP_RATES = 11; GAP_DELAY = 12;

  -- Table for particles to spawn for each level {partname, ent location, part cp, savekey}
  PartList = {
		{ -- Level 1
			{},
		},
		{ -- Level 2
			{"particles/misc/ring1.vpcf", "23puck_phase_shift", 0},
		},
		{ -- Level 3
			{"particles/misc/ring1.vpcf", "36ursa_enrage_custom", 0},
			--{0, "particles/misc/ring1.vpcf", "34enchantress_bunny_hop_custom", 0},
		},
		{ -- Level 4
			{"particles/misc/ring1.vpcf", "46weaver_time_lapse", 0},
			{"particles/misc/ring1.vpcf", "45tinker_keen_teleport_custom", 0},
			{"particles/misc/mana.vpcf", "mana4", 0},
		},
		{ -- Level 5
			{"particles/misc/ring1.vpcf", "52tusk_snowball_lua.tusk_walrus_kick_custom", 0},
			{"particles/misc/ring1.vpcf", "54tusk_walrus_kick_custom.tusk_snowball_lua", 0},
			{"particles/misc/ring1.vpcf", "51tusk_ice_shards", 0},
		},
		{ -- Level 6
			{},
		},
  }

  -- Table for functions to run for each level
  FuncList = {
		{"ExtraLifeSpawn"},      -- Level 1
		{"RandomLSAThinker", "RandomMangoThinker"},       -- Level 2
		{},      -- Level 3
		{},     -- Level 4
		{"SelectableSpawner", "SnowballCleanup"},     -- Level 5
		{"PatternLSA"},        -- Level 6
	}

	-- Messages for each level
	_G.MsgList = {
		{},     -- Level 1
		{},     -- Level 2
		{},     -- Level 3
		{},     -- Level 4
		{},     -- Level 5
		{},     -- Level 6
	}
end

function barebones:SetupMap()
	DebugPrint("[BAREBONES] Setting up initial map")
  -- Setting up the beginning level (1)
	local level = 1
	_G.currentLevel = level

	if USE_LEVEL_DEBUG then
		level = LEVEL_DEBUG
		_G.currentLevel = LEVEL_DEBUG
	end

  barebones:InitializeVectors()

	Timers:CreateTimer(2, function()
		barebones:SetUpLevel(level)
		barebones:CheckPlayersInbounds(level)
	end)
	
	DebugPrint("[BAREBONES] Done setting up map")
end

-- This function turns the "name" table into vector table
function barebones:InitializeVectors()
	DebugPrint("[BAREBONES] Initializing Vectors")
  for level,level_list in pairs(_G.MultPatrol) do
		for i,list in pairs(level_list) do
			_G.MultVector[level][i] = {}

			for j,entloc in pairs(list) do
				--print("Initializing vector ", j, entloc)
				local ent = Entities:FindByName(nil, entloc)
				if ent ~= nil then
					local pos = ent:GetAbsOrigin()
					_G.MultVector[level][i][j] = pos
				end
			end
    end
  end
	DebugPrint("[BAREBONES] Finished Initializing Vectors")
end

-- This function is called as the first player loads and sets up the game mode parameters
function barebones:CaptureGameMode()
	print("CaptureGameMode starting")
	local gamemode = GameRules:GetGameModeEntity()

	-- Set GameMode parameters
	gamemode:SetRecommendedItemsDisabled(RECOMMENDED_BUILDS_DISABLED)
	gamemode:SetCameraDistanceOverride(CAMERA_DISTANCE_OVERRIDE)
	gamemode:SetBuybackEnabled(BUYBACK_ENABLED)
	gamemode:SetCustomBuybackCostEnabled(CUSTOM_BUYBACK_COST_ENABLED)
	gamemode:SetCustomBuybackCooldownEnabled(CUSTOM_BUYBACK_COOLDOWN_ENABLED)
	gamemode:SetTopBarTeamValuesOverride(USE_CUSTOM_TOP_BAR_VALUES)
	gamemode:SetTopBarTeamValuesVisible(TOP_BAR_VISIBLE)

	if USE_CUSTOM_XP_VALUES then
		gamemode:SetUseCustomHeroLevels(true)
		gamemode:SetCustomXPRequiredToReachNextLevel(XP_PER_LEVEL_TABLE)
	end

	gamemode:SetBotThinkingEnabled(USE_STANDARD_DOTA_BOT_THINKING)
	gamemode:SetTowerBackdoorProtectionEnabled(ENABLE_TOWER_BACKDOOR_PROTECTION)

	gamemode:SetFogOfWarDisabled(DISABLE_FOG_OF_WAR_ENTIRELY)
	gamemode:SetGoldSoundDisabled(DISABLE_GOLD_SOUNDS)
	--gamemode:SetRemoveIllusionsOnDeath(REMOVE_ILLUSIONS_ON_DEATH)

	gamemode:SetAlwaysShowPlayerInventory(SHOW_ONLY_PLAYER_INVENTORY)
	gamemode:SetAnnouncerDisabled(DISABLE_ANNOUNCER)
	if FORCE_PICKED_HERO ~= nil then
		gamemode:SetCustomGameForceHero(FORCE_PICKED_HERO) -- THIS WILL NOT WORK when "EnablePickRules" is "1" in 'addoninfo.txt' !
	else
		gamemode:SetDraftingHeroPickSelectTimeOverride(HERO_SELECTION_TIME)
		gamemode:SetDraftingBanningTimeOverride(0)
		if ENABLE_BANNING_PHASE then
			gamemode:SetDraftingBanningTimeOverride(BANNING_PHASE_TIME)
		end
	end
	gamemode:SetFixedRespawnTime(FIXED_RESPAWN_TIME)
	gamemode:SetFountainConstantManaRegen(FOUNTAIN_CONSTANT_MANA_REGEN)
	gamemode:SetFountainPercentageHealthRegen(FOUNTAIN_PERCENTAGE_HEALTH_REGEN)
	gamemode:SetFountainPercentageManaRegen(FOUNTAIN_PERCENTAGE_MANA_REGEN)
	gamemode:SetLoseGoldOnDeath(LOSE_GOLD_ON_DEATH)
	gamemode:SetMaximumAttackSpeed(MAXIMUM_ATTACK_SPEED)
	gamemode:SetMinimumAttackSpeed(MINIMUM_ATTACK_SPEED)
	gamemode:SetStashPurchasingDisabled(DISABLE_STASH_PURCHASING)

	if USE_DEFAULT_RUNE_SYSTEM then
		gamemode:SetUseDefaultDOTARuneSpawnLogic(true)
	else
		-- Most runes are broken by Valve, RuneSpawnFilter also doesn't work
		for rune, spawn in pairs(ENABLED_RUNES) do
			gamemode:SetRuneEnabled(rune, spawn)
		end
		gamemode:SetBountyRuneSpawnInterval(BOUNTY_RUNE_SPAWN_INTERVAL)
		gamemode:SetPowerRuneSpawnInterval(POWER_RUNE_SPAWN_INTERVAL)
	end

	gamemode:SetUnseenFogOfWarEnabled(USE_UNSEEN_FOG_OF_WAR)
	gamemode:SetDaynightCycleDisabled(DISABLE_DAY_NIGHT_CYCLE)
	gamemode:SetKillingSpreeAnnouncerDisabled(DISABLE_KILLING_SPREE_ANNOUNCER)
	gamemode:SetStickyItemDisabled(DISABLE_STICKY_ITEM)
	gamemode:SetPauseEnabled(ENABLE_PAUSING)
	gamemode:SetCustomScanCooldown(CUSTOM_SCAN_COOLDOWN)
	gamemode:SetCustomGlyphCooldown(CUSTOM_GLYPH_COOLDOWN)
	gamemode:DisableHudFlip(FORCE_MINIMAP_ON_THE_LEFT)

	if DEFAULT_DOTA_COURIER then
		gamemode:SetFreeCourierModeEnabled(true)
	end
end
