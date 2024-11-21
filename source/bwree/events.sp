void InitGameEventHooks()
{
	HookEvent("player_team", Event_PlayerTeam);
	HookEvent("player_death", Event_PlayerDeath);
	HookEvent("mvm_begin_wave", Event_MvmBeginWave);
	HookEvent("player_builtobject", Event_PlayerBuiltObject);
	HookEvent("mvm_wave_failed", Event_MvmWaveFailed);
	HookEvent("mvm_wave_complete", Event_MvmWaveComplete);
	HookEvent("player_spawn", Event_PlayerSpawn);
	HookEvent("teamplay_flag_event", Event_TeamplayFlagEvent);
	HookEvent("teamplay_round_start", Event_TeamplayRoundStart);
	HookEvent("teamplay_round_win", Event_TeamplayRoundWin);
	HookEvent("player_buyback", Event_PlayerBuyback);
	HookEvent("post_inventory_application", Event_PostInventoryApplication);
	
#if defined FIX_VOTE_CONTROLLER
	HookEvent("vote_options", Event_VoteOptions);
#endif
}

static void Event_PlayerTeam(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	
	if (IsPlayingAsRobot(client))
	{
		StopIdleSound(client);
		
		TFTeam team = view_as<TFTeam>(event.GetInt("team"));
		
		if (team != TFTeam_Blue)
		{
			if (GetBWRCooldownTimeLeft(client) <= 0.0)
				SetBWRCooldownTimeLeft(client, GetPlayerCalculatedCooldown(client));
			
			//Any robot player changing to a team that's not blue is not a robot
			SetRobotPlayer(client, false);
			
			if (IsPlayerAlive(client))
			{
				//CTFPlayer::ChangeTeam calls CBasePlayer::ChangeTeam before CTFPlayer::CommitSuicide
				
				if (bwr3_edit_wavebar.BoolValue)
				{
					//We won't first die as a robot player so decrement the icon here
					DecrementRobotPlayerClassIcon(client);
				}
			}
		}
	}
}

static void Event_PlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
	//None of this matters if the round hasn't started
	if (GameRules_GetRoundState() == RoundState_BetweenRounds)
		return;
	
	int iDeathFlags = event.GetInt("death_flags");
	
	if (iDeathFlags & TF_DEATHFLAG_DEADRINGER)
		return;
	
	int client = GetClientOfUserId(event.GetInt("userid"));
	
#if defined SPY_DISGUISE_VISION_OVERRIDE
	SpyDisguiseClear(client);
#else
	//All robot players forget about this spy that died
	for (int i = 1; i <= MaxClients; i++)
		if (IsClientInGame(i) && IsPlayingAsRobot(i) && IsPlayerAlive(i))
			MvMRobotPlayer(i).ForgetSpy(client);
#endif
	
	int attacker = GetClientOfUserId(event.GetInt("attacker"));
	
	if (attacker > 0)
	{
		if (IsPlayingAsRobot(attacker))
		{
			if (attacker != client)
				g_arrRobotPlayerStats[client].iKills++;
		}
	}
	
	if (!IsPlayingAsRobot(client))
		return;
	
	if (attacker != client)
		g_arrRobotPlayerStats[client].iDeaths++;
	
	MvMSuicideBomber roboPlayer = MvMSuicideBomber(client);
	
	//CTFBot::Event_Killed
	if (TF2_IsClass(client, TFClass_Spy))
	{
		int spyCount = 0;
		
		for (int i = 1; i <= MaxClients; i++)
			if (i != client && IsClientInGame(i) && TF2_GetClientTeam(i) == TFTeam_Blue && IsPlayerAlive(i))
				if (TF2_IsClass(i, TFClass_Spy))
					spyCount++;
		
		Event hEvent = CreateEvent("mvm_mission_update");
		
		if (hEvent)
		{
			hEvent.SetInt("class", view_as<int>(TFClass_Spy));
			hEvent.SetInt("count", spyCount);
			hEvent.Fire();
		}
	}
	else if (TF2_IsClass(client, TFClass_Engineer))
	{
		while (TF2Util_GetPlayerObjectCount(client) > 0)
		{
			int iObject = TF2Util_GetPlayerObject(client, 0);
			
			if (iObject != -1)
			{
				SetEntityOwner(iObject, -1);
				TF2_SetBuilder(iObject, -1);
			}
			
			RemoveObject(client, iObject);
		}
		
		bool bShouldAnnounceLastEngineerDeath = roboPlayer.HasAttribute(CTFBot_TELEPORT_TO_HINT);
		
		if (bShouldAnnounceLastEngineerDeath)
		{
			//Don't announce last engineer death if there are other engineers alive
			for (int i = 1; i <= MaxClients; i++)
			{
				if (IsClientInGame(i) && TF2_GetClientTeam(i) == TFTeam_Blue && IsPlayerAlive(i))
				{
					if (i != client && TF2_IsClass(i, TFClass_Engineer))
					{
						bShouldAnnounceLastEngineerDeath = false;
						break;
					}
				}
			}
		}
		
		if (bShouldAnnounceLastEngineerDeath)
		{
			bool bEngineerTeleporterInTheWorld = false;
			
			int obj = -1;
			
			while ((obj = FindEntityByClassname(obj, "obj_teleporter")) != -1)
			{
				if (BaseEntity_GetTeamNumber(obj) == view_as<int>(TFTeam_Blue))
				{
					if (TF2_IsPlacing(obj))
						continue;
					
					bEngineerTeleporterInTheWorld = true;
					break;
				}
			}
			
			if (bEngineerTeleporterInTheWorld)
				TeamplayRoundBasedRules_BroadcastSound(255, "Announcer.MVM_An_Engineer_Bot_Is_Dead_But_Not_Teleporter");
			else
				TeamplayRoundBasedRules_BroadcastSound(255, "Announcer.MVM_An_Engineer_Bot_Is_Dead");
		}
	}
	
	if (TF2_IsMiniBoss(client))
	{
		//NOTE: this is already handled in CTFPlayer::DeathSound
		/* switch (TF2_GetPlayerClass(client))
		{
			case TFClass_Heavy:	EmitGameSoundToAll("MVM.GiantHeavyExplodes", client);
			default:	EmitGameSoundToAll("MVM.GiantCommonExplodes", client);
		} */
		
		StopIdleSound(client);
	}
	
	//Killed by a RED player and we're a gatebot, give them the achievement
	//Would never fire normally for human players regardless because they can't be casted as CTFBot
	if (attacker > 0 && TF2_GetClientTeam(attacker) == TFTeam_Red)
	{
		char mapName[15]; GetCurrentMap(mapName, sizeof(mapName));
		
		if (StrEqual(mapName, "mvm_mannhattan"))
			if (roboPlayer.HasTag("bot_gatebot"))
				BaseMultiplayerPlayer_AwardAchievement(attacker, ACHIEVEMENT_TF_MVM_MAPS_MANNHATTAN_BOMB_BOT_GRIND);
	}
	
	//NOTE: probably handled by function DHookCallback_EventKilled_Pre
	/* if (roboPlayer.DeployBombState > TF_BOMB_DEPLOYING_NONE)
	{
		Event hEvent = CreateEvent("mvm_kill_robot_delivering_bomb");
		
		if (hEvent)
		{
			hEvent.SetInt("player", attacker);
			hEvent.Fire();
		}
	} */
	
	if (roboPlayer.HasMission(CTFBot_MISSION_DESTROY_SENTRIES))
	{
		if (!roboPlayer.DetonateTimer_HasStarted())
		{
			//Would normally call StartDetonate here but it's pointless
			EmitGameSoundToAll("MvM.SentryBusterSpin", client);
		}
		
		roboPlayer.DestroySuicideBomber();
	}
	
	roboPlayer.NextSpawnTime = GetGameTime() + GetRandomFloat(bwr3_robot_spawn_time_min.FloatValue, bwr3_robot_spawn_time_max.FloatValue);
	
	if (roboPlayer.NextSpawnTime == GetGameTime())
	{
		/* FIXME: CWave::ActiveWaveUpdate will cause all blue players to suicide when the wave is about to be completed before
		gamerules can transition to state GR_STATE_BETWEEN_RNDS which means respawn time can never truly be zero or else
		our system will turn the player into a robot immediately after death keeping them as a robot during intermission!
		Kind of a stupid fix so find a way to know when the wave is about to end to only affect this death specifically */
		roboPlayer.NextSpawnTime += 0.016; //One frame is about 15.152 milliseconds?
	}
	
#if defined OVERRIDE_PLAYER_RESPAWN_TIME
#if defined CORRECT_VISIBLE_RESPAWN_TIME
	TF2Util_SetPlayerRespawnTimeOverride(client, roboPlayer.NextSpawnTime - GetGameTime() + 0.1);
#else
	TF2Util_SetPlayerRespawnTimeOverride(client, bwr3_robot_spawn_time_max.FloatValue + BWR_FAKE_SPAWN_DURATION_EXTRA);
#endif //CORRECT_VISIBLE_RESPAWN_TIME
#endif //OVERRIDE_PLAYER_RESPAWN_TIME
}

static void Event_MvmBeginWave(Event event, const char[] name, bool dontBroadcast)
{
	g_flTimeRoundStarted = GetGameTime();
	g_bCanBotsAttackInSpawn = CanBotsAttackWhileInSpawnRoom(g_iPopulationManager);
	
	if (bwr3_edit_wavebar.BoolValue)
		UpdateCurrentWaveUsedIcons();
	
	BWRCooldown_PurgeExpired();
	StartSentryBusterCooldown();
	BossRobotSystem_UpdateSettings();
	BossRobotSystem_StartSpawnCooldown();
	
#if !defined OVERRIDE_PLAYER_RESPAWN_TIME
	/* Since we control the spawning of robot players, they should never be allowed to respawn themselves
	This should be set to a very high number so that the player can't spawn in whenever bot spawning gets disabled
	Generally I'd like to think of this value as time it takes to cap (mannhattan 12) + current respawn wave time (usually 22) */
	SetTeamRespawnWaveTime(TFTeam_Blue, bwr3_robot_spawn_time_max.FloatValue + BWR_FAKE_SPAWN_DURATION_EXTRA);
#endif
	
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i))
		{
			if (IsPlayingAsRobot(i))
			{
				//The round started, now we turn into one of our robots
				TurnPlayerIntoHisNextRobot(i);
				SelectPlayerNextRobot(i);
			}
			else if (TF2_GetClientTeam(i) == TFTeam_Red)
			{
				if (IsPlayerAlive(i))
				{
					//Remove any debuff conditions that may have been applied by the robot players
					for (int j = 0; j < sizeof(g_nTrackedConditions); j++)
					{
						if (TF2_IsPlayerInCondition(i, g_nTrackedConditions[j]))
						{
#if defined REMOVE_DEBUFF_COND_BY_ROBOTS
							int provider = TF2Util_GetPlayerConditionProvider(i, g_nTrackedConditions[j]);
							
							if (provider > 0 && BaseEntity_IsPlayer(provider) && IsPlayingAsRobot(provider))
								TF2_RemoveCondition(i, g_nTrackedConditions[j]);
#else
							TF2_RemoveCondition(i, g_nTrackedConditions[j]);
#endif
						}
					}
				}
			}
		}
	}
	
	//Remove lingering projectiles that may exploit to hurt when the wave starts
	RemoveAllRobotPlayerOwnedEntities();
	
	if (bwr3_edit_wavebar.BoolValue)
	{
		if (IsValidEntity(g_iObjectiveResource))
		{
			if (!IsClassIconUsedInCurrentWave(TFOR_TELEPORTER_STRING))
			{
				//TODO: how about you put this in the wavebar without actually setting a count > 0?
				TF2_SetWaveIconSpawnCount(g_iObjectiveResource, TFOR_TELEPORTER_STRING, MVM_CLASS_FLAG_MISSION, 1, false);
				TF2_DecrementMannVsMachineWaveClassCount(g_iObjectiveResource, TFOR_TELEPORTER_STRING, MVM_CLASS_FLAG_MISSION);
			}
		}
	}
}

static void Event_PlayerBuiltObject(Event event, const char[] name, bool dontBroadcast)
{
	if (GameRules_GetRoundState() == RoundState_BetweenRounds)
		return;
	
	int client = GetClientOfUserId(event.GetInt("userid"));
	int entity = event.GetInt("index");
	TFObjectType objectType = view_as<TFObjectType>(event.GetInt("object"));
	
	if (BaseEntity_GetTeamNumber(entity) == view_as<int>(TFTeam_Blue))
	{
		if (objectType == TFObject_Teleporter)
			DHooks_RobotTeleporter(entity);
	}
	
	if (!IsPlayingAsRobot(client))
		return;
	
	/* In MvM, engineer buildings are actually just spawned in manually by the behavior
	and there's actually a 0.1 second delay before spawning it in with players being pushed away first
	Now that's not really gonna be possible here unless we make things a bit more complicated
	so instead we'll just check for when it gets built by robot players */
	
	if (objectType == TFObject_Dispenser)
		return;
	
	//We don't care about re-deployed buildings
	if (GetEntProp(entity, Prop_Send, "m_bCarryDeploy") == 1)
		return;
	
	if (objectType == TFObject_Sentry)
	{
		//Destroy the previous building we have built
		DetonateAllObjectsOfType(client, TFObject_Sentry, _, entity);
		
		//Start the sentry at level 3
		SetEntProp(entity, Prop_Data, "m_nDefaultUpgradeLevel", 2);
	}
	else if (objectType == TFObject_Teleporter)
	{
		DetonateAllObjectsOfType(client, TFObject_Teleporter, TFObjectMode_Exit, entity);
		
		int iHealth = BaseEntity_GetMaxHealth(entity) * tf_bot_engineer_building_health_multiplier.IntValue;
		BaseEntity_SetMaxHealth(entity, iHealth);
		BaseEntity_SetHealth(entity, iHealth);
		
		EmitGameSoundToAll("Engineer.MVM_AutoBuildingTeleporter02", client);
		
		//Objects use context think, but this is apparently called while it's building so we'll just use it as a think
		SDKHook(entity, SDKHook_GetMaxHealth, TeleporterConstructionGetMaxHealth);
	}
	
	TF2_PushAllPlayersAway(GetAbsOrigin(entity), 400.0, 500.0, TFTeam_Red);
}

static void Event_MvmWaveFailed(Event event, const char[] name, bool dontBroadcast)
{
	if (!UpdateSentryBusterSpawningCriteria())
		LogError("Failed to update sentry buster spawning criteria for the current mission!");
}

static void Event_MvmWaveComplete(Event event, const char[] name, bool dontBroadcast)
{
	if (!UpdateSentryBusterSpawningCriteria())
		LogError("Failed to update sentry buster spawning criteria for the current mission!");
	
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i) && IsPlayingAsRobot(i))
		{
			ResetRobotPlayerGameStats(i);
			
#if defined OVERRIDE_PLAYER_RESPAWN_TIME
			/* All BLUE players are killed when the wave is complete
			so we need to reset the respawn time on robot players because we override it when they die
			Though they could actually get around this by changing classes as this will instantly respawn them between waves */
			TF2Util_SetPlayerRespawnTimeOverride(i, -1.0);
#endif
		}
	}
}

static void Event_PlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	
	if (GameRules_GetRoundState() == RoundState_BetweenRounds)
	{
		if (IsPlayingAsRobot(client))
		{
			if (!bwr3_allow_movement.BoolValue)
				SetPlayerToMove(client, false);
			
			//Robot players are ignored by sentries between rounds
			SetEntityFlags(client, GetEntityFlags(client) | FL_NOTARGET);
		}
		
		return;
	}
	
	if (IsPlayingAsRobot(client))
	{
		/* switch (bwr3_robot_custom_viewmodels.IntValue)
		{
			case 1:	SetPlayerViewModel(client, g_sRobotArmModels[TF2_GetPlayerClass(client)]);
		} */
		
#if !defined SPY_DISGUISE_VISION_OVERRIDE
		MvMRobotPlayer(client).ClearTrackedSpyData();
#endif
	}
	
#if defined TELEPORTER_METHOD_MANUAL
	if (TF2_GetClientTeam(client) == TFTeam_Blue && IsTFBotPlayer(client))
	{
		//Catch this before uber gets applied in CTFBotMainAction::Update
		float delay = nb_update_frequency.FloatValue - 0.004;
		
		if (delay < 0.0)
			delay = 0.0;
		
		CreateTimer(delay, Timer_TFBotSpawn, client, TIMER_FLAG_NO_MAPCHANGE);
	}
#endif
}

static void Event_TeamplayFlagEvent(Event event, const char[] name, bool dontBroadcast)
{
	int type = event.GetInt("eventtype");
	
	switch (type)
	{
		case TF_FLAGEVENT_CAPTURED:
		{
			int client = event.GetInt("player");
			
			if (IsPlayingAsRobot(client))
			{
				g_arrRobotPlayerStats[client].iFlagCaptures++;
				
				char playerName[MAX_NAME_LENGTH]; GetClientName(client, playerName, sizeof(playerName));
				int health = GetClientHealth(client);
				int maxHealth = TF2Util_GetEntityMaxHealth(client);
				
				PrintToChatAll("%s %t", PLUGIN_PREFIX, "Player_Deployed_Bomb", playerName, health, maxHealth);
				LogAction(client, -1, "%L deployed the bomb (%d/%d HP).", client, health, maxHealth);
			}
		}
	}
}

static void Event_TeamplayRoundStart(Event event, const char[] name, bool dontBroadcast)
{
	/* From CTFGameRules::FireGameEvent, when this event is fired all BLUE players are switched to spectator
	So here we are just going to switch them to RED, but only the actual human players! */
	for (int i = 1; i <= MaxClients; i++)
	{
		if (!IsClientInGame(i))
			continue;
		
		if (TF2_GetClientTeam(i) != TFTeam_Spectator)
			continue;
		
		if (IsTFBotPlayer(i))
			continue;
		
		if (IsClientSourceTV(i))
			continue;
		
		if (IsClientReplay(i))
			continue;
		
		//Silent team change
		SetVariantString("self.ForceChangeTeam(Constants.ETFTeam.TF_TEAM_PVE_DEFENDERS, false)");
		AcceptEntityInput(i, "RunScriptCode");
	}
}

static void Event_TeamplayRoundWin(Event event, const char[] name, bool dontBroadcast)
{
	TFTeam team = view_as<TFTeam>(event.GetInt("team"));
	
	if (team == TFTeam_Blue)
	{
		for (int i = 1; i <= MaxClients; i++)
		{
			if (IsClientInGame(i) && IsPlayingAsRobot(i))
			{
				//Compensate cooldown for map reset time
				SetBWRCooldownTimeLeft(i, GetPlayerCalculatedCooldown(i) + BONUS_ROUND_TIME_MVM + 1.0);
			}
		}
	}
}

static void Event_PlayerBuyback(Event event, const char[] name, bool dontBroadcast)
{
	int client = event.GetInt("player");
	
	if (!IsPlayingAsRobot(client))
		return;
	
	TurnPlayerIntoHisNextRobot(client);
	SelectPlayerNextRobot(client);
}

static void Event_PostInventoryApplication(Event event, const char[] name, bool dontBroadcast)
{
#if defined NO_AIRBLAST_BETWEEN_ROUNDS
	int client = GetClientOfUserId(event.GetInt("userid"));
	
	if (GameRules_GetRoundState() == RoundState_BetweenRounds)
	{
		if (IsPlayingAsRobot(client))
		{
			int primary = GetPlayerWeaponSlot(client, TFWeaponSlot_Primary);
			
			if (primary != -1)
			{
				switch (TF2Util_GetWeaponID(primary))
				{
					case TF_WEAPON_FLAMETHROWER, TF_WEAPON_FLAME_BALL:
					{
						//Don't allow robot players to airblast anyone
						TF2Attrib_SetByName(primary, "airblast_pushback_disabled", 1.0);
					}
				}
			}
		}
	}
#endif
}

#if defined FIX_VOTE_CONTROLLER
static void Event_VoteOptions(Event event, const char[] name, bool dontBroadcast)
{
	/* For some reason, the developers coded in MvM specifically to only allow RED team to count as valid voters
	To circumvent this, we will attempt to change all robot players to team RED before they get counted
	
	BACKTRACE REFERENCE:
	CVoteController::CreateVote
		CBaseIssue::CountPotentialVoters
			CVoteController::IsValidVoter */
	for (int i = 1; i <= MaxClients; i++)
		if (IsPlayingAsRobot(i))
			SetTeamNumber(i, TFTeam_Red);
	
	//Undo what we did a frame later
	RequestFrame(FrameResetRobotPlayersTeam);
}
#endif

static Action TeleporterConstructionGetMaxHealth(int entity, int &maxhealth)
{
	if (GetEntPropFloat(entity, Prop_Send, "m_flPercentageConstructed") == 1.0)
	{
		/* In MvM, the particle is actually controlled on the client's side and is emitted from the bot_hint_engineer_nest entity
		So it isn't always visibly on top of a teleporter, but we're going to make it seem as if it's from a hint by offsetting it a bit
		However, it shouldn't be too far from the teleporter itself */
		float vec[3]; BaseEntity_GetLocalOrigin(entity, vec);
		float rand = GetRandomFloat(-150.0, 150.0);
		
		vec[0] += rand;
		vec[1] += rand;
		
		/* While we can use a temporary entity, it is a bit risky for persistent particles
		Not only that, but unless the building always transmits, the particle won't be visible to everyone */
		IPS_CreateParticle(entity, "teleporter_mvm_bot_persist", vec, true);
		SDKUnhook(entity, SDKHook_GetMaxHealth, TeleporterConstructionGetMaxHealth);
	}
	
	return Plugin_Continue;
}

#if defined TELEPORTER_METHOD_MANUAL
static Action Timer_TFBotSpawn(Handle timer, int data)
{
	if (!IsClientInGame(data) || !IsPlayerAlive(data) || TF2_GetClientTeam(data) != TFTeam_Blue || !IsTFBotPlayer(data))
		return Plugin_Stop;
	
	//Only teleport the bot if they're in a spawn room, otherwise they were probably already teleported
	if (!TF2Util_IsPointInRespawnRoom(WorldSpaceCenter(data), data))
		return Plugin_Stop;
	
	float spawnPos[3];
	
	if (FindSpawnLocation(spawnPos) == SPAWN_LOCATION_TELEPORTER)
	{
		spawnPos[2] += TFBOT_STEP_HEIGHT;
		TeleportEntity(data, spawnPos);
		OnBotTeleported(data);
		
#if defined MOD_EXT_CBASENPC
		//Updated for the same reason as in Timer_FinishRobotPlayer
		CBaseCombatCharacter(data).UpdateLastKnownArea();
		
		//Reset behavior for bot to recalculate his path
		// CBaseNPC_GetNextBotOfEntity(data).GetIntentionInterface().Reset();
#endif
	}
	
	return Plugin_Stop;
}
#endif

#if defined FIX_VOTE_CONTROLLER
static void FrameResetRobotPlayersTeam()
{
	for (int i = 1; i <= MaxClients; i++)
		if (IsPlayingAsRobot(i))
			SetTeamNumber(i, TFTeam_Blue);
}
#endif