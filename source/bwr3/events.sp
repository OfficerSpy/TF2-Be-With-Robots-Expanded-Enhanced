void InitGameEventHooks()
{
	HookEvent("player_team", Event_PlayerTeam);
	HookEvent("player_death", Event_PlayerDeath);
	HookEvent("mvm_begin_wave", Event_MvmBeginWave);
	HookEvent("player_builtobject", Event_PlayerBuiltObject);
	
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
			//Any robot player changing to a team that's not blue is not a robot
			SetRobotPlayer(client, false);
		}
	}
}

static void Event_PlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
	int iDeathFlags = event.GetInt("death_flags");
	
	if (iDeathFlags & TF_DEATHFLAG_DEADRINGER)
		return;
	
	int client = GetClientOfUserId(event.GetInt("userid"));
	
	if (!IsPlayingAsRobot(client))
		return;
	
	MvMSuicideBomber roboPlayer = MvMSuicideBomber(client);
	
	//CTFBot::Event_Killed
	if (TF2_IsClass(client, TFClass_Spy))
	{
		int spyCount = 0;
		
		for (int i = 1; i <= MaxClients; i++)
			if (IsClientInGame(i) && TF2_GetClientTeam(i) == TFTeam_Blue && IsPlayerAlive(i))
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
	
	int attacker = GetClientOfUserId(event.GetInt("attacker"));
	
	//Killed by a RED player and we're a gatebot, give them the achievement
	//Would never fire normally for human players regardless because they can't be casted as CTFBot
	if (attacker > 0 && BaseEntity_IsPlayer(attacker) && TF2_GetClientTeam(attacker) == TFTeam_Red)
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
		roboPlayer.DestroySuicideBomber();
	
	roboPlayer.NextSpawnTime = GetGameTime() + GetRandomFloat(3.0, 5.0);
}

static void Event_MvmBeginWave(Event event, const char[] name, bool dontBroadcast)
{
	g_bCanBotsAttackInSpawn = CanBotsAttackWhileInSpawnRoom(g_iPopulationManager);
	
	//The round started, now we turn into one of our robots
	for (int i = 1; i <= MaxClients; i++)
		if (IsClientInGame(i) && IsPlayingAsRobot(i))
			SelectSpawnRobotTypeForPlayer(i);
}

static void Event_PlayerBuiltObject(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	
	if (!IsPlayingAsRobot(client))
		return;
	
	/* In MvM, engineer buildings are actually just spawned in manually by the behavior
	and there's actually a 0.1 second delay before spawning it in with players being pushed away first
	Now that's not really gonna be possible here unless we make things a bit more complicated
	so instead we'll just check for when it gets built by robot players */
	
	TFObjectType objectType = view_as<TFObjectType>(event.GetInt("object"));
	
	if (objectType != TFObject_Sentry && objectType != TFObject_Teleporter)
		return;
	
	int entity = event.GetInt("index");
	
	if (objectType == TFObject_Sentry)
	{
		//Destroy the previous building we have built
		DetonateObjectsOfType(client, TFObject_Sentry, entity);
		
		//Start the sentry at level 3
		SetEntProp(entity, Prop_Data, "m_nDefaultUpgradeLevel", 2);
	}
	else if (objectType == TFObject_Teleporter)
	{
		DetonateObjectsOfType(client, TFObject_Teleporter, entity);
		
		int iHealth = BaseEntity_GetMaxHealth(entity) * tf_bot_engineer_building_health_multiplier.IntValue;
		BaseEntity_SetMaxHealth(entity, iHealth);
		BaseEntity_SetHealth(entity, iHealth);
		
		EmitGameSoundToAll("Engineer.MVM_AutoBuildingTeleporter02", client);
		
		//Objects use context think, but this is apparently called while it's building so we'll just use it as a think
		SDKHook(entity, SDKHook_GetMaxHealth, ObjectTeleporter_GetMaxHealth);
	}
	
	TF2_PushAllPlayersAway(GetAbsOrigin(entity), 400.0, 500.0, TFTeam_Red);
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

static void FrameResetRobotPlayersTeam()
{
	for (int i = 1; i <= MaxClients; i++)
		if (IsPlayingAsRobot(i))
			SetTeamNumber(i, TFTeam_Blue);
}
#endif