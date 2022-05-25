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
		barebones:InitializeGameConstants()
	end)	

  -- Loads the level
	Timers:CreateTimer(5, function()
		barebones:SetupMap()
	end)
end

function barebones:InitializeGameConstants()
	-- Setting up the game, variables and tables
  Players = {}
  _G.Extras = {}
  MultVector = {}
	Linked = {}
	_G.Cheeses = {}

	Vote = {}
	votesNeeded = 6
	GameRules.Ongoing = true
	GameRules.VoteOngoing = false

	_G.patreonUsed = false

  GameRules.Lives = 6
  _G.currentLevel = 0
	GameRules.Checkpoint = Vector(0, 0, 0)

	-- All abilities to give to everyone
	_G.abilList = {
		"tinker_keen_teleport_custom"
	}

	-- Modifiers to check for leaving safety trigger
	_G.outOfBoundsModifiers = {
		"modifier_mirana_leap",
		"modifier_enchantress_bunny_hop",
	}

	-- Spell names to change to pure damage
	_G.SpellList = {}

	_G.BossHp = 0

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
  _G.MultPatrol = {
                 {"p1_1_1a",  "p1_1_1b"}, -- 1
                 {"p1_1_2a",  "p1_1_2b"},
                 {"p1_1_3a",  "p1_1_3b"},
                 {"p1_1_4a",  "p1_1_4b"},
                 {"p1_1_5a",  "p1_1_5b"}, -- 5
                 {"p1_1_6a",  "p1_1_6b"}, 
                 {"p1_1_7a",  "p1_1_7b"},
                 {"p1_1_8a",  "p1_1_8b"},
                 {"p1_1_9a",  "p1_1_9b"},
                 {"p1_1_10a",  "p1_1_10b"}, -- 10
                 {"p1_2_1a",  "p1_2_1b"},
                 {"p1_2_2a",  "p1_2_2b"},
                 {"p1_2_3a",  "p1_2_3b"},
                 {"p1_2_4a",  "p1_2_4b"},
                 {"p1_2_5a",  "p1_2_5b"}, -- 15
                 {"p1_2_6a",  "p1_2_6b"},
                 {"p1_2_7a",  "p1_2_7b"},
                 {"p1_2_8a",  "p1_2_8b"},
								 {"p1_2_9a",  "p1_2_9b"},
								 {"p1_2_10a",  "p1_2_10b"}, -- 20
                 {"p1_2_11a",  "p1_2_11b"},
                 {"p1_2_12a",  "p1_2_12b"}, 
                 {"p1_3_1a",  "p1_3_1b", "p1_3_1c", "p1_3_1d"},
                 {"p1_3_2a",  "p1_3_2b", "p1_3_2c", "p1_3_2d"},
                 {"p1_3_3a",  "p1_3_3b", "p1_3_3c", "p1_3_3d"}, -- 25
                 {"p1_3_4a",  "p1_3_4b", "p1_3_4c", "p1_3_4d"},
								 {"p2_1a", "p2_1b"},
								 {"p2_2a", "p2_2b"},
								 {"p2_3a", "p2_3b"},
								 {"p2_4a", "p2_4b"}, -- 30
                 {"p3_1a", "p3_1b"},
								 {"p3_2a", "p3_2b"},
								 {"p3_3a", "p3_3b"},
								 {"p3_1_1a", "p3_1_1b"}, 
								 {"p3_1_2a", "p3_1_2b"}, -- 35
								 {"p3_1_3a", "p3_1_3b"},
								 {"p4_1a", "p4_1b"},
								 {"p4_2a", "p4_2b"},
								 {"p4_3a", "p4_3b"},
								 {"p4_4a", "p4_4b"}, -- 40
								 {"p5_1a", "p5_1b", "p5_1c", "p5_1d",  "p5_1e", "p5_1f", "p5_1g", "p5_1h"},
								 {"p5_2a", "p5_2b"}, 
								 {"p5_3a", "p5_3b"}, 
								 {"p5_4a", "p5_4b"},
								 {"p5_5a", "p5_5b", "p5_5c", "p5_5d"}, -- 45
								 {"p5_6a", "p5_6b", "p5_6c", "p5_6d"}
               }

  -- Table for ent names
  Ents = {
           "item_mango_custom",
           "item_cheese_custom",
           "npc_creep_patrol",
					 "npc_gate",
					 "npc_dummy_unit",
					 "npc_zombie_static",
					 "npc_dummy_unit",
					 "npc_magnus",
					 "npc_dummy_unit",
         }

	ENT_MANGO = 1; ENT_CHEES = 2; ENT_PATRL = 3;  ENT_GATES = 4; ENT_AOELS = 5; ENT_ZSTAT = 6;
	ENT_MULTI = 7; ENT_MAGNS = 8; ENT_CARTY = 9;

  -- Table for all ents (exc pat creeps) {item/unit/part, ent#, entindex, spawn, function, etc}
  EntList = {
							{ -- Level 1
								{2, ENT_MULTI, 0, "m1_1a", "WallPatrolThinker", "m1_1b", 425, 0, 360},
								{2, ENT_MULTI, 0, "m1_2a", "WallPatrolThinker", "m1_2b", 350, 0, 265},
								{1, ENT_CHEES, 0, "cheese1_1", nil},
                {1, ENT_MANGO, 0, "mango1_1", nil, false},
								{2, ENT_GATES, 0, "gate1_1a", "GateThinker", "gate1_1b", Vector(0, 1, 0), 1},
								{2, ENT_GATES, 0, "gate1_2a", "GateThinker", "gate1_2b", Vector(-1, 0, 0), 4},
                {2, ENT_PATRL, 0, "p1_1_1a",  "WavePatrolThinker", 1,  1, 300, 200, 2},
								{2, ENT_PATRL, 0, "p1_1_1a",  "WavePatrolThinker", 1,  0.03, 300, -200, 2},
                {2, ENT_PATRL, 0, "p1_1_2a",  "PatrolThinker", 2,  0.03, 300, 0.5},
                {2, ENT_PATRL, 0, "p1_1_3a",  "PatrolThinker", 3,  0.03, 260, 0.5},
                {2, ENT_PATRL, 0, "p1_1_4a",  "PatrolThinker", 4,  0.03, 475, 0.5},
                {2, ENT_PATRL, 0, "p1_1_5a",  "PatrolThinker", 5,  0.03, 380, 0.5},
                {2, ENT_PATRL, 0, "p1_1_6a",  "PatrolThinker", 6,  0.03, 340, 0.5},
                {2, ENT_PATRL, 0, "p1_1_7a",  "PatrolThinker", 7,  0.03, 280, 0.5},
                {2, ENT_PATRL, 0, "p1_1_8a",  "PatrolThinker", 8,  0.03, 360, 0.5},
                {2, ENT_PATRL, 0, "p1_1_9a",  "PatrolThinker", 9,  0.03, 400, 0.5},
                {2, ENT_PATRL, 0, "p1_1_10a",  "PatrolThinker", 10, 0.03, 450, 0.5},
								{1, ENT_MANGO, 0, "mango1_2", nil, false},
								{1, ENT_MANGO, 0, "mango1_3", nil, false},
                {1, ENT_MANGO, 0, "mango1_4", nil, false},
                {1, ENT_MANGO, 0, "mango1_5", nil, false},
                {2, ENT_PATRL, 0, "p1_2_1a",  "PatrolThinker", 11,  0.03, 450, 0.5},
                {2, ENT_PATRL, 0, "p1_2_2a",  "PatrolThinker", 12,  0.03, 280, 0.5},
                {2, ENT_PATRL, 0, "p1_2_3a",  "PatrolThinker", 13,  0.03, 340, 0.5},
                {2, ENT_PATRL, 0, "p1_2_4a",  "PatrolThinker", 14,  0.03, 300, 0.5},
                {2, ENT_PATRL, 0, "p1_2_5a",  "PatrolThinker", 15,  0.03, 380, 0.5},
                {2, ENT_PATRL, 0, "p1_2_6a",  "PatrolThinker", 16,  0.03, 400, 0.5},
                {2, ENT_PATRL, 0, "p1_2_7a",  "PatrolThinker", 17,  0.03, 475, 0.5},
                {2, ENT_PATRL, 0, "p1_2_8a",  "PatrolThinker", 18,  0.03, 360, 0.5},
                {2, ENT_PATRL, 0, "p1_2_9a",  "PatrolThinker", 19,  0.03, 440, 0.5},
                {2, ENT_PATRL, 0, "p1_2_10a",  "PatrolThinker", 20, 0.03, 260, 0.5},
								{2, ENT_PATRL, 0, "p1_2_11a",  "PatrolThinker", 21, 0.03, 300, 0.5},
                {2, ENT_PATRL, 0, "p1_2_12a",  "PatrolThinker", 22, 0.03, 450, 0.5},
								-- Split of multi patrol vs single
								{2, ENT_PATRL, 0, "p1_3_1a",  "PatrolThinker", 23, 0.03, 400, 0.5},
								{2, ENT_PATRL, 0, "p1_3_2a",  "PatrolThinker", 24, 0.03, 400, 0.5},
								{2, ENT_PATRL, 0, "p1_3_3a",  "PatrolThinker", 25, 0.03, 425, 0.5},
								{2, ENT_PATRL, 0, "p1_3_4a",  "PatrolThinker", 26, 0.03, 425, 0.5},
              },
							{ -- Level 2
								{1, ENT_CHEES, 0, "cheese2_1", nil},
								{2, ENT_CARTY, 0, "carty2_1a", "MovingWallThinker", "carty2_1b", 225, 0, 240, 4},
								{2, ENT_CARTY, 0, "carty2_2a", "MovingWallThinker", "carty2_2b", 225, 0, 415, 3.5},  
								{1, ENT_MANGO, 0, "mango2_1", nil, false},
								{1, ENT_MANGO, 0, "mango2_2", nil, false},
								{2, ENT_GATES, 0, "gate2_1a", "GateThinker", "gate2_1b", Vector(0, 1, 0), 2},
								{2, ENT_PATRL, 0, "p2_1a", "PatrolThinker", 27, 0.03, 325},
								{2, ENT_PATRL, 0, "p2_2a", "PatrolThinker", 28, 0.03, 425},
								{2, ENT_AOELS, 0, "lsa2_2_1", "AOEThinker", 5, 2.5, true},  
								{2, ENT_AOELS, 0, "lsa2_2_2", "AOEThinker", 5, 0, false},  
								{2, ENT_AOELS, 0, "lsa2_2_3", "AOEThinker", 5, 2.5, false},  
								{2, ENT_AOELS, 0, "lsa2_2_4", "AOEThinker", 5, 0, false},  
								{2, ENT_AOELS, 0, "lsa2_2_5", "AOEThinker", 5, 2.5, false},  
								{2, ENT_AOELS, 0, "lsa2_2_6", "AOEThinker", 5, 0, false},  
								{2, ENT_AOELS, 0, "lsa2_2_7", "AOEThinker", 5, 2.5, false},  
								{2, ENT_AOELS, 0, "lsa2_2_8", "AOEThinker", 5, 0, false},  
								{2, ENT_AOELS, 0, "lsa2_2_9", "AOEThinker", 5, 2.5, false},  
								{2, ENT_AOELS, 0, "lsa2_2_10", "AOEThinker", 5, 0, true},  
								{2, ENT_AOELS, 0, "cheese2_1", "AOEThinker", 1, 0, true},  
								{2, ENT_PATRL, 0, "p2_3a", "PatrolThinker", 29, 0.03, 350},
								{2, ENT_PATRL, 0, "p2_4a", "PatrolThinker", 30, 1.03, 350},
              },
							{ -- Level 3
								{1, ENT_CHEES, 0, "cheese3_1", nil}, 
								{2, ENT_AOELS, 0, "lsa3_1", "AOEThinker", 4, 0, true},  
								{2, ENT_PATRL, 0, "p3_1a", "PatrolThinker", 31, 0.03, 400},
								{2, ENT_PATRL, 0, "p3_2a", "PatrolThinker", 32, 0.03, 400},
								{2, ENT_PATRL, 0, "p3_3a", "PatrolThinker", 33, 0.03, 400},
								{1, ENT_MANGO, 0, "mango3_1", nil, true},
								{1, ENT_MANGO, 0, "mango3_2", nil, true},
								{1, ENT_MANGO, 0, "mango3_3", nil, true},
                {1, ENT_MANGO, 0, "mango3_4", nil, true},
                {1, ENT_MANGO, 0, "mango3_5", nil, true},
                {1, ENT_MANGO, 0, "mango3_6", nil, true},
                {1, ENT_MANGO, 0, "mango3_7", nil, true},
                {1, ENT_MANGO, 0, "mango3_8", nil, true},
                {1, ENT_MANGO, 0, "mango3_9", nil, true},
                {1, ENT_MANGO, 0, "mango3_10", nil, true},
								{2, ENT_AOELS, 0, "lsa3_2", "AOEThinker", 6, 3, false},  
								{2, ENT_AOELS, 0, "lsa3_3", "AOEThinker", 6, 0, false},  
								{2, ENT_AOELS, 0, "lsa3_4", "AOEThinker", 6, 3, true},  
								{2, ENT_AOELS, 0, "lsa3_5", "AOEThinker", 6, 0, true},  
								{2, ENT_AOELS, 0, "lsa3_6", "AOEThinker", 6, 3, true},  
								{2, ENT_AOELS, 0, "lsa3_7", "AOEThinker", 6, 0, true},  
								{2, ENT_AOELS, 0, "lsa3_8", "AOEThinker", 6, 3, true},  
								{2, ENT_AOELS, 0, "lsa3_9", "AOEThinker", 6, 0, false},  
								{2, ENT_AOELS, 0, "lsa3_10", "AOEThinker", 6, 3, false},  
								{2, ENT_GATES, 0, "gate3_1a", "GateThinker", "gate3_1b", Vector(0, -1, 0), 10},
                {1, ENT_MANGO, 0, "mango3_11", nil, true},
								{2, ENT_PATRL, 0, "p3_1_1a", "PatrolThinker", 34, 0.03, 275, 0.5}, 
								{2, ENT_AOELS, 0, "lsa3_11", "AOEThinker", 1.5, 0, false},  
								{2, ENT_AOELS, 0, "lsa3_12", "AOEThinker", 1.5, 0, true},  
                {1, ENT_MANGO, 0, "mango3_12", nil, true},
								{1, ENT_MANGO, 0, "mango3_13", nil, true},
								{2, ENT_PATRL, 0, "p3_1_2a", "PatrolThinker", 35, 0.03, 300},
								{2, ENT_PATRL, 0, "p3_1_3a", "PatrolThinker", 36, 0.03, 300},
								{2, ENT_GATES, 0, "gate3_2a", "GateThinker", "gate3_2b", Vector(1, 0, 0), 3},       
              },
							{ -- Level 4 
								{1, ENT_CHEES, 0, "cheese4_1", nil},
								{2, ENT_MULTI, 0, "m4_1a", "WallPatrolThinker", "m4_1b", 975, 0, 450},
								{2, ENT_CARTY, 0, "wall4_1a", "MovingWallThinker", "wall4_1b", 525, 0, 500, 10},
								{2, ENT_CARTY, 0, "wall4_2a", "MovingWallThinker", "wall4_2b", 625, 0, 150, 4},
								{2, ENT_AOELS, 0, "lsa4_1", "AOEThinker", 3, 0, true}, 
								{2, ENT_PATRL, 0, "p4_1a", "PatrolThinker", 37, 0.03, 400, 0.25},
								{2, ENT_PATRL, 0, "p4_2a", "PatrolThinker", 38, 0.03, 400, 0.25},
								{2, ENT_PATRL, 0, "p4_3a", "PatrolThinker", 39, 0.03, 400},
								{2, ENT_AOELS, 0, "lsa4_2", "AOEThinker", 2, 0, true}, 
								{2, ENT_AOELS, 0, "lsa4_3", "AOEThinker", 2, 0.8, true}, 
								{2, ENT_AOELS, 0, "lsa4_4", "AOEThinker", 2, 0, true}, 
								{2, ENT_AOELS, 0, "lsa4_5", "AOEThinker", 1.25, 0, true}, 
								{2, ENT_PATRL, 0, "p4_4a", "PatrolThinker", 40, 0.03, 450},
								{2, ENT_PATRL, 0, "p4_z1", "PatrolThinker", 0, 0.03, 450},
								{2, ENT_PATRL, 0, "p4_z2", "PatrolThinker", 0, 0.03, 450},
								{2, ENT_PATRL, 0, "p4_z3", "PatrolThinker", 0, 0.03, 450},
								{2, ENT_PATRL, 0, "p4_z4", "PatrolThinker", 0, 0.03, 450},
								{2, ENT_PATRL, 0, "p4_z5", "PatrolThinker", 0, 0.03, 450},
								{2, ENT_PATRL, 0, "p4_z6", "PatrolThinker", 0, 0.03, 450},
								{2, ENT_PATRL, 0, "p4_z7", "PatrolThinker", 0, 0.03, 450},
              },
							{ -- Level 5
								{2, ENT_PATRL, 0, "p5_1a", "PatrolThinker", 41, 0.03, 230},
								{1, ENT_MANGO, 0, "mango5_1", nil, true},
								{2, ENT_GATES, 0, "gate5_1a", "GateThinker", "gate5_1b", Vector(0, -1, 0), 1},
								{2, ENT_AOELS, 0, "lsa5_1", "AOEThinker", 2.5, 0, true}, 
								{2, ENT_AOELS, 0, "lsa5_2", "AOEThinker", 2, 0, true},   
								{2, ENT_PATRL, 0, "p5_2a", "PatrolThinker", 42, 0.03, 400},
								{2, ENT_PATRL, 0, "p5_3a", "PatrolThinker", 43, 0.03, 575, 0.25},
								{2, ENT_PATRL, 0, "p5_4a", "PatrolThinker", 44, 0.03, 575, 0.25},
								{2, ENT_AOELS, 0, "lsa5_3", "AOEThinker", 3.5, 0, true}, 
								{2, ENT_PATRL, 0, "p5_5a", "PatrolThinker", 45, 0.03, 550},  
								{2, ENT_AOELS, 0, "lsa5_4", "AOEThinker", 4, 0, true},  
								{2, ENT_AOELS, 0, "lsa5_5", "AOEThinker", 2.5, 0, true},  
								{2, ENT_AOELS, 0, "lsa5_6", "AOEThinker", 5, 0, true}, 
								{2, ENT_PATRL, 0, "p5_6a", "PatrolThinker", 46, 0.03, 340},
              },
              { -- Level 6
              }
            }

	
  -- Constants for EntList table and PartList
  ENT_UNTIM = 1; ENT_TYPEN = 2; ENT_INDEX = 3; ENT_SPAWN = 4; ENT_RFUNC = 5;
  PAR_INDEX = 1; PAR_FNAME = 2; PAR_SPAWN = 3; PAR_CTRLP = 4;

	PAT_VECNM = 6; PAT_DELAY = 7; PAT_MVSPD = 8; PAT_TURND = 9;
																							 PAT_AMPLT = 9; PAT_PEROD = 10;
	MNG_RSPWN = 6;
	GAT_MOVES = 6; GAT_ORIEN = 7; GAT_NUMBR = 8;
	AOE_RATES = 6; AOE_DELAY = 7; AOE_SOUND = 8;
	MAG_GOALS = 6; MAG_RATES = 7; MAG_DELAY = 8;
	MLT_GOALS = 6; MLT_RADII = 7; MLT_SPACE = 8; MLT_MVSPD = 9;
	CAR_GOALS = 6; CAR_RADII = 7; CAR_SPACE = 8; CAR_MVSPD = 9; CAR_RATES = 10;

  -- Table for particles to spawn for each level {partname, ent location, part cp, savekey}
  PartList = {
               { -- Level 1
                 {},
               },
               { -- Level 2
								 {},
								 {},
               },
               { -- Level 3
								 {0, "particles/misc/ring1.vpcf", "33mirana_leap_custom", 0},
								 --{0, "particles/misc/ring1.vpcf", "34enchantress_bunny_hop_custom", 0},
							 },
							 { -- Level 4
							 	 {0, "particles/misc/ring1.vpcf", "43shredder_timber_chain_custom", 0},
								 --{0, "particles/misc/ring1.vpcf", "46rattletrap_hookshot_custom", 0},
               },
               { -- Level 5
								 {0, "particles/misc/sunray_cw.vpcf", "cw1", 0},
								 {0, "particles/misc/sunray_ccw.vpcf", "ccw1", 0},
								 {0, "particles/misc/sunray_cw.vpcf", "cw2", 0},
								 {0, "particles/misc/sunray_ccw.vpcf", "ccw2", 0},
               },
               { -- Level 6
							 {0, "particles/misc/ring1.vpcf", "64invoker_sun_strike_custom", 0},
               },
             }

  -- Table for functions to run for each level
  FuncList = {
            {"ExtraLifeSpawn", "MultiPatrolWithGap"},                 -- Level 1
            {},       -- Level 2
            {"SpawnFriendlyPatrols"},      -- Level 3
            {"SpawnPoles"},     -- Level 4
            {"PheonixInitial"},                 -- Level 5
            {"FinalBossThinker", "MangoThinker"},        -- Level 6
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
	if USE_LEVEL_DEBUG then
		level = LEVEL_DEBUG
		_G.currentLevel = LEVEL_DEBUG
	end

  barebones:InitializeVectors()

	Timers:CreateTimer(2, function()
		barebones:SetUpLevel(level)
	end)
	
	DebugPrint("[BAREBONES] Done setting up map")
end

-- This function turns the "name" table into vector table
function barebones:InitializeVectors()
	DebugPrint("[BAREBONES] Initializing Vectors")
  for i,list in pairs(_G.MultPatrol) do
    MultVector[i] = {}
		for j,entloc in pairs(list) do
			--print("Initializing vector ", j, entloc)
			local ent = Entities:FindByName(nil, entloc)
			if ent ~= nil then
      	local pos = ent:GetAbsOrigin()
      	MultVector[i][j] = pos
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
