#define ROBOT_TEMPLATE_CONFIG_DIRECTORY	"configs/bwree"
#define ROBOT_NAME_UNDEFINED	"TFBot"
#define MAX_ROBOT_TEMPLATES	113
#define MAX_ENGINEER_NEST_HINT_LOCATIONS	10

enum eRobotTemplateType
{
	ROBOT_STANDARD,
	ROBOT_GIANT,
	ROBOT_GATEBOT,
	ROBOT_GATEBOT_GIANT,
	ROBOT_SENTRYBUSTER,
	ROBOT_BOSS,
	ROBOT_TEMPLATE_TYPE_COUNT
};

enum eEngineerTeleportType
{
	ENGINEER_TELEPORT_NEAR_BOMB,
	ENGINEER_TELEPORT_RANDOM,
	ENGINEER_TELEPORT_NEAR_TEAMMATE
};

// Robot template property arrays
int g_iTotalRobotTemplates[ROBOT_TEMPLATE_TYPE_COUNT];
char g_sRobotTemplateName[ROBOT_TEMPLATE_TYPE_COUNT][MAX_ROBOT_TEMPLATES][MAX_NAME_LENGTH];

float g_vecEngineerHintOrigin[MAX_ENGINEER_NEST_HINT_LOCATIONS][3];

static Handle m_hDetonateTimer[MAXPLAYERS + 1];
static bool m_bHasDetonated[MAXPLAYERS + 1];
static bool m_bWasSuccessful[MAXPLAYERS + 1];
static bool m_bWasKilled[MAXPLAYERS + 1];

methodmap MvMSuicideBomber < MvMRobotPlayer
{
	public MvMSuicideBomber(int index)
	{
		return view_as<MvMSuicideBomber>(index);
	}
	
	public void InitializeSuicideBomber(int victim)
	{
		this.SetMissionTarget(victim);
		
		m_bHasDetonated[this.index] = false;
		m_bWasSuccessful[this.index] = false;
		m_bWasKilled[this.index] = false;
	}
	
	public void DestroySuicideBomber()
	{
		this.DetonateTimer_Invalidate();
	}
	
	public void DetonateTimer_Invalidate()
	{
		if (m_hDetonateTimer[this.index])
		{
			KillTimer(m_hDetonateTimer[this.index]);
			m_hDetonateTimer[this.index] = null;
		}
	}
	
	public bool DetonateTimer_HasStarted()
	{
		return m_hDetonateTimer[this.index] != null;
	}
	
	public void DetonateTimer_Start(float duration)
	{
		m_hDetonateTimer[this.index] = CreateTimer(duration, Timer_SuicideBomberDetonate, this.index);
	}
	
	public void StartDetonate(bool bWasSuccessful = false, bool bWasKilled = false)
	{
		if (this.DetonateTimer_HasStarted())
			return;
		
		OSTFPlayer player = OSTFPlayer(this.index);
		
		/* if (!IsPlayerAlive(this.index) || player.GetHealth() < 1)
		{
			if (TF2_GetClientTeam(this.index) != TFTeam_Spectator)
			{
				player.m_lifeState = LIFE_ALIVE;
				player.SetHealth(1);
			}
		} */
		
		m_bWasSuccessful[this.index] = bWasSuccessful;
		m_bWasKilled[this.index] = bWasKilled;
		
		player.m_takedamage = DAMAGE_NO;
		
		VS_Taunt(this.index, TAUNT_BASE_WEAPON);
		this.DetonateTimer_Start(2.0);
		EmitGameSoundToAll("MvM.SentryBusterSpin", this.index);
	}
	
	public void Detonate()
	{
		m_bHasDetonated[this.index] = true;
		
		//Use vscript to emit the particles
		SetVariantString("DispatchParticleEffect(\"explosionTrail_seeds_mvm\", self.GetOrigin(), self.GetAngles()); DispatchParticleEffect(\"fluidSmokeExpl_ring_mvm\", self.GetOrigin(), self.GetAngles());");
		AcceptEntityInput(this.index, "RunScriptCode");
		
		EmitGameSoundToAll("MVM.SentryBusterExplode", this.index);
		
		float origin[3]; GetClientAbsOrigin(this.index, origin);
		UTIL_ScreenShake(origin, 25.0, 5.0, 5.0, 1000.0, SHAKE_START);
		
		if (!m_bWasSuccessful[this.index])
		{
			MultiplayRules_HaveAllPlayersSpeakConceptIfAllowed(MP_CONCEPT_MVM_SENTRY_BUSTER_DOWN, view_as<int>(TFTeam_Red));
			
			//TODO: decide to award achievement here
		}
		
		//The actual game function uses two CUtlVector objects for players
		//but it's not needed here since the second is just a copy of the first
		
		ArrayList adtVictims = new ArrayList();
		CollectPlayers(adtVictims, view_as<int>(TFTeam_Red), true);
		CollectPlayers(adtVictims, view_as<int>(TFTeam_Blue), true, true);
		
		//Add objects as potential victims
		int iEnt = -1;
		while ((iEnt = FindEntityByClassname(iEnt, "obj_*")) != -1)
			if (BaseEntity_GetTeamNumber(iEnt) == view_as<int>(TFTeam_Blue) || BaseEntity_GetTeamNumber(iEnt) == view_as<int>(TFTeam_Red))
				adtVictims.Push(iEnt);
		
		//TODO: non-player nextbots?
		
		if (m_bWasKilled[this.index])
		{
			Event hEvent = CreateEvent("mvm_sentrybuster_killed");
			
			if (hEvent)
			{
				hEvent.SetInt("sentry_buster", this.index);
				hEvent.Fire();
			}
		}
		
		this.SetMission(CTFBot_NO_MISSION);
		OSTFPlayer(this.index).m_takedamage = DAMAGE_YES;
		
		for (int i = 0; i < adtVictims.Length; i++)
		{
			int victim = adtVictims.Get(i);
			
			float toVictim[3]; SubtractVectors(WorldSpaceCenter(victim), WorldSpaceCenter(this.index), toVictim);
			
			if (Vector_IsLengthGreaterThan(toVictim, tf_bot_suicide_bomb_range.FloatValue))
				continue;
			
			if (BaseEntity_IsPlayer(i))
			{
				int colorHIt[4] = {255, 255, 255, 255};
				UTIL_ScreenFade(i, colorHIt, 1.0, 0.1, FFADE_IN);
			}
			
			if (TF2_IsLineOfFireClear4(this.index, victim))
			{
				NormalizeVector(toVictim, toVictim);
				
				int damage = MaxInt(BaseEntity_GetMaxHealth(victim), BaseEntity_GetHealth(victim));
				float finalDamage = SentryBuster_GetDamageForVictim(victim, float(damage));
				
#if defined MOD_EXT_CBASENPC
				CTakeDamageInfo info = GetGlobalDamageInfo();
				info.Init(this.index, this.index, _, _, _, finalDamage, DMG_BLAST, TF_DMG_CUSTOM_NONE);
				
				if (tf_bot_suicide_bomb_friendly_fire.BoolValue)
					info.SetForceFriendlyFire(true);
				
				CalculateMeleeDamageForce(info, toVictim, WorldSpaceCenter(this.index), 1.0);
				CBaseEntity(victim).TakeDamage(info);
#else
				float vecDamageForce[3]; CalculateMeleeDamageForce(finalDamage, toVictim, 1.0, vecDamageForce);
				SDKHooks_TakeDamage(victim, this.index, this.index, finalDamage, DMG_BLAST, _, vecDamageForce, WorldSpaceCenter(this.index));
#endif
			}
		}
		
		delete adtVictims;
		
		//SM NOTE: bForce is always set to true in SM 1.12
		ForcePlayerSuicide(this.index);
		
		/* if (IsPlayerAlive(this.index))
			VS_ForceChangeTeam(this.index, TFTeam_Spectator); */
		
		if (m_bWasKilled[this.index])
		{
			if (IsValidEntity(g_iPopulationManager))
			{
				Address pWave = GetCurrentWave(g_iPopulationManager);
				
				if (pWave)
				{
					//Our death counts towards the wave's sentry busters killed count
					SetNumSentryBustersKilled(pWave, GetNumSentryBustersKilled(pWave) + 1);
				}
			}
		}
	}
}

int g_iRefLastTeleporter = INVALID_ENT_REFERENCE;
float g_flLastTeleportTime = -1.0;

bool g_bRobotBossesAvailable;
float g_flBossDelayDuration;
float g_flBossRespawnDelayDuration;
bool g_bBossProportionalHealth;
float g_flNextBossSpawnTime;

static float m_flDestroySentryCooldownDuration; //Cooldown amount specified by the population file
static float m_flSentryBusterCooldown; //How long our active cooldown is right now

int g_iOverrideTeleportVictim[MAXPLAYERS + 1] = {-1, ...};

static char m_sIdleSound[MAXPLAYERS + 1][PLATFORM_MAX_PATH];
static int m_nIdleSoundChannel[MAXPLAYERS + 1];
static int m_iSpyTeleportAttempt[MAXPLAYERS + 1];

static Action Timer_SuicideBomberDetonate(Handle timer, any data)
{
	if (IsClientInGame(data) && IsPlayingAsRobot(data) && IsPlayerAlive(data) && !ShouldCurrentActionBeSuspended(data))
	{
		MvMSuicideBomber(data).Detonate();
		
		//TODO: victim stuff for detonation event
		if (m_bWasSuccessful[data])
		{
			
		}
	}
	
	m_hDetonateTimer[data] = null;
	
	return Plugin_Stop;
}

static Action Timer_SpyLeaveSpawnRoom(Handle timer, any data)
{
	if (!IsClientInGame(data) || !IsPlayerAlive(data) || !TF2_IsClass(data, TFClass_Spy))
		return Plugin_Stop;
	
	int victim = -1;
	
	if (g_iOverrideTeleportVictim[data] != -1)
	{
		//Player overrided their own victim to teleport to
		if (IsValidSpyTeleportVictim(g_iOverrideTeleportVictim[data]))
		{
			if (TeleportNearVictim(data, g_iOverrideTeleportVictim[data], m_iSpyTeleportAttempt[data]))
				victim = g_iOverrideTeleportVictim[data];
		}
		else
		{
			//Our desired victim is not valid anymore, resort to backup plan
			g_iOverrideTeleportVictim[data] = -1;
			PrintToChat(data, "%s %t", PLUGIN_PREFIX, "Spy_Teleport_Custom_Failed");
		}
	}
	else
	{
		ArrayList adtEnemy = new ArrayList();
		CollectPlayers(adtEnemy, view_as<int>(TFTeam_Red), true);
		
		ArrayList adtShuffle = adtEnemy.Clone();
		
		delete adtEnemy;
		
		int n = adtShuffle.Length;
		
		while (n > 1)
		{
			int k = GetRandomInt(0, n - 1);
			n--;
			
			int tmp = adtShuffle.Get(n);
			adtShuffle.Set(n, adtShuffle.Get(k));
			adtShuffle.Set(k, tmp);
		}
		
		for (int i = 0; i < adtShuffle.Length; i++)
		{
			if (TeleportNearVictim(data, adtShuffle.Get(i), m_iSpyTeleportAttempt[data]))
			{
				victim = adtShuffle.Get(i);
				break;
			}
		}
		
		delete adtShuffle;
	}
	
	if (victim == -1)
	{
		CreateTimer(1.0, Timer_SpyLeaveSpawnRoom, data, TIMER_FLAG_NO_MAPCHANGE);
		
		m_iSpyTeleportAttempt[data]++;
		
		return Plugin_Stop;
	}
	
	SetPlayerToMove(data, true);
	
	return Plugin_Stop;
}

static Action Timer_MvMEngineerTeleportSpawn(Handle timer, DataPack pack)
{
	pack.Reset();
	
	int client = pack.ReadCell();
	
	if (!IsClientInGame(client) || !IsPlayerAlive(client) || !TF2_IsClass(client, TFClass_Engineer))
		return Plugin_Stop;
	
	float nestOrigin[3]; pack.ReadFloatArray(nestOrigin, sizeof(nestOrigin));
	
	//This should never happen
	if (IsZeroVector(nestOrigin))
		return Plugin_Stop;
	
	float angles[3]; //angles = GetAbsAngles(hintEntity);
	float origin[3]; origin = nestOrigin;
	origin[2] += 10.0;
	
	TeleportEntity(client, origin, angles, NULL_VECTOR);
	
	TE_TFParticleEffectComplex(0.0, "teleported_blue", origin, NULL_VECTOR);
	TE_TFParticleEffectComplex(0.0, "player_sparkles_blue", origin, NULL_VECTOR);
	
	//TODO: what exactly determines m_bFirstTeleportSpawn?
	TE_TFParticleEffectComplex(0.0, "teleported_mvm_bot", origin, NULL_VECTOR);
	EmitGameSoundToAll("Engineer.MVM_BattleCry07", client);
	EmitGameSoundToAll("MVM.Robot_Engineer_Spawn", _, _, _, nestOrigin);
	
	if (IsValidEntity(g_iPopulationManager))
	{
		Address pWave = GetCurrentWave(g_iPopulationManager);
		
		if (pWave)
		{
			int numSpawned = GetNumEngineersTeleportSpawned(pWave);
			
			if (numSpawned == 0)
				TeamplayRoundBasedRules_BroadcastSound(255, "Announcer.MVM_First_Engineer_Teleport_Spawned");
			else
				TeamplayRoundBasedRules_BroadcastSound(255, "Announcer.MVM_Another_Engineer_Teleport_Spawned");
			
			SetNumEngineersTeleportSpawned(pWave, numSpawned + 1);
		}
	}
	
	return Plugin_Stop;
}

static float SentryBuster_GetDamageForVictim(int victim, float baseDamage)
{
	if (BaseEntity_IsPlayer(victim))
	{
		//Sentry busters are an exception to the damage override on minibosses rule
		//This is due to an order of precdence in CTFPlayer::OnTakeDamage
		if (IsSentryBusterRobot(victim))
			return baseDamage * 4;
		
		if (TF2_IsMiniBoss(victim))
			return SENTRYBUSTER_DMG_TO_MINIBOSS;
	}
	
	return baseDamage * 4;
}

void TurnPlayerIntoRobot(int client, const eRobotTemplateType type, const int templateID)
{
	char fileName[PLATFORM_MAX_PATH];
	char filePath[PLATFORM_MAX_PATH];
	
	switch (type)
	{
		case ROBOT_STANDARD:
		{
			bwr3_robot_template_file.GetString(fileName, sizeof(fileName));
			BuildPath(Path_SM, filePath, sizeof(filePath), "%s/%s", ROBOT_TEMPLATE_CONFIG_DIRECTORY, fileName);
			
			if (!FileExists(filePath))
				ThrowError("Could not find standard robot config file: %s", filePath);
			
			KeyValues kv = new KeyValues("RobotStandardTemplates");
			kv.ImportFromFile(filePath);
			
			ParseTemplateOntoPlayerFromKeyValues(kv, client, templateID);
			delete kv;
		}
		case ROBOT_GIANT:
		{
			bwr3_robot_giant_template_file.GetString(fileName, sizeof(fileName));
			BuildPath(Path_SM, filePath, sizeof(filePath), "%s/%s", ROBOT_TEMPLATE_CONFIG_DIRECTORY, fileName);
			
			if (!FileExists(filePath))
				ThrowError("Could not find giant robot config file: %s", filePath);
			
			KeyValues kv = new KeyValues("RobotGiantTemplates");
			kv.ImportFromFile(filePath);
			
			ParseTemplateOntoPlayerFromKeyValues(kv, client, templateID);
			delete kv;
		}
		case ROBOT_GATEBOT:
		{
			bwr3_robot_gatebot_template_file.GetString(fileName, sizeof(fileName));
			BuildPath(Path_SM, filePath, sizeof(filePath), "%s/%s", ROBOT_TEMPLATE_CONFIG_DIRECTORY, fileName);
			
			if (!FileExists(filePath))
				ThrowError("Could not find gatebot robot config file: %s", filePath);
			
			KeyValues kv = new KeyValues("RobotGatebotTemplates");
			kv.ImportFromFile(filePath);
			
			ParseTemplateOntoPlayerFromKeyValues(kv, client, templateID);
			delete kv;
		}
		case ROBOT_GATEBOT_GIANT:
		{
			bwr3_robot_gatebot_giant_template_file.GetString(fileName, sizeof(fileName));
			BuildPath(Path_SM, filePath, sizeof(filePath), "%s/%s", ROBOT_TEMPLATE_CONFIG_DIRECTORY, fileName);
			
			if (!FileExists(filePath))
				ThrowError("Could not find giant gatebot robot config file: %s", filePath);
			
			KeyValues kv = new KeyValues("RobotGatebotGiantTemplates");
			kv.ImportFromFile(filePath);
			
			ParseTemplateOntoPlayerFromKeyValues(kv, client, templateID);
			delete kv;
		}
		case ROBOT_SENTRYBUSTER:
		{
			bwr3_robot_sentrybuster_template_file.GetString(fileName, sizeof(fileName));
			BuildPath(Path_SM, filePath, sizeof(filePath), "%s/%s", ROBOT_TEMPLATE_CONFIG_DIRECTORY, fileName);
			
			if (!FileExists(filePath))
				ThrowError("Could not find sentry buster robot config file: %s", filePath);
			
			KeyValues kv = new KeyValues("RobotSentryBusterTemplates");
			kv.ImportFromFile(filePath);
			
			ParseTemplateOntoPlayerFromKeyValues(kv, client, templateID);
			delete kv;
		}
		case ROBOT_BOSS:
		{
			bwr3_robot_boss_template_file.GetString(fileName, sizeof(fileName));
			BuildPath(Path_SM, filePath, sizeof(filePath), "%s/%s", ROBOT_TEMPLATE_CONFIG_DIRECTORY, fileName);
			
			if (!FileExists(filePath))
				ThrowError("Could not find boss robot config file: %s", filePath);
			
			KeyValues kv = new KeyValues("RobotBossTemplates");
			kv.ImportFromFile(filePath);
			
			ParseTemplateOntoPlayerFromKeyValues(kv, client, templateID);
			delete kv;
		}
		default:	LogError("TurnPlayerIntoRobot: Unknown robot template type %d", type);
	}
}

static void ParseTemplateOntoPlayerFromKeyValues(KeyValues kv, int client, const int templateID)
{
	if (kv.JumpToKey("Templates"))
	{
		kv.GotoFirstSubKey(false);
		
		//Template IDs start from 0
		//This corresponds with the property arrays
		int keyIndex = 0;
		
		do
		{
			if (keyIndex == templateID)
			{
				TF2Attrib_RemoveAll(client);
				
				//First we need to join as the class desired by the template
				char className[PLATFORM_MAX_PATH]; kv.GetString("Class", className, sizeof(className));
				TFClassType playerClass = TF2_GetClassIndexFromString(className);
				Player_JoinClass(client, playerClass);
				
				//After joining a class, remove their weapons and cosmetics
				StripWeapons(client, true, TFWeaponSlot_Building);
				RemovePowerupBottle(client);
				RemoveSpellbook(client);
				
				if (bwr3_cosmetic_mode.IntValue == COSMETIC_MODE_NONE)
					RemoveCosmetics(client);
				
				MvMRobotPlayer roboPlayer = MvMRobotPlayer(client);
				
				//Now we set the robot's basic details here
				roboPlayer.SetAutoJump(kv.GetFloat("AutoJumpMin"), kv.GetFloat("AutoJumpMax"));
				
				char kvStringBuffer[16];
				
				//Not usually part of a robot template, but I don't see any other way to do it here
				kv.GetString("Objective", kvStringBuffer, sizeof(kvStringBuffer));
				roboPlayer.SetMission(GetBotMissionFromString(kvStringBuffer));
				
				//These will be used later
				char name[MAX_NAME_LENGTH]; kv.GetString("Name", name, sizeof(name), ROBOT_NAME_UNDEFINED);
				int health = kv.GetNum("Health");
				float scale = kv.GetFloat("Scale");
				char classIcon[PLATFORM_MAX_PATH]; kv.GetString("ClassIcon", classIcon, sizeof(classIcon));
				int credits = kv.GetNum("TotalCurrency");
				
				roboPlayer.ClearEventChangeAttributes();
				
				if (kv.JumpToKey("EventChangeAttributes"))
				{
					//If we enter this block, this means we want to parse multiple blocks of robot stats
					//These should be stored on the player as well so they can be referenced later
					roboPlayer.InitializeEventChangeAttributes();
					ParseEventChangeAttributesForPlayer(client, kv, true);
					kv.GoBack();
				}
				else
				{
					//Don't store anything as this robot will only use default stats
					ParseEventChangeAttributesForPlayer(client, kv);
				}
				
				//Now we do all the stuff needed for when the bot spawns
				DataPack pack;
				CreateDataTimer(0.1, Timer_FinishRobotPlayer, pack);
				pack.WriteCell(client);
				pack.WriteString(name);
				pack.WriteCell(health);
				pack.WriteFloat(scale);
				pack.WriteCell(playerClass);
				pack.WriteString(classIcon);
				pack.WriteCell(credits);
				
				break;
			}
			
			keyIndex++;
		} while (kv.GotoNextKey(false))
	}
}

static Action Timer_FinishRobotPlayer(Handle timer, DataPack pack)
{
	pack.Reset();
	int client = pack.ReadCell();
	
	if (!IsClientInGame(client) || !IsPlayerAlive(client))
		return Plugin_Stop;
	
	char strName[MAX_NAME_LENGTH]; pack.ReadString(strName, sizeof(strName));
	int iHealth = pack.ReadCell();
	float flScale = pack.ReadFloat();
	TFClassType iClass = pack.ReadCell();
	char strClassIcon[PLATFORM_MAX_PATH]; pack.ReadString(strClassIcon, sizeof(strClassIcon));
	int iCreditAmount = pack.ReadCell();
	
	MvMRobotPlayer roboPlayer = MvMRobotPlayer(client);
	OSTFPlayer player = OSTFPlayer(client);
	
	//If an icon wasn't specified, then we just use the class's default icon
	//Even though we don't modify it, we still copy it over cause we're going to use it for the wavebar
	if (strlen(strClassIcon) > 0)
		player.SetClassIconName(strClassIcon);
	else
		player.GetClassIconName(strClassIcon, sizeof(strClassIcon));
	
	roboPlayer.ClearTeleportWhere();
	
	//TODO: SetTeleportWhjere
	
	if (roboPlayer.HasAttribute(CTFBot_MINIBOSS))
		player.SetIsMiniBoss(true);
	
	if (roboPlayer.HasAttribute(CTFBot_USE_BOSS_HEALTH_BAR))
		player.SetUseBossHealthBar(true);
	
	//Handled elsewhere
	/* if (roboPlayer.HasAttribute(CTFBot_AUTO_JUMP))
		roboPlayer.SetAutoJump(flAutoJumpMin, flAutoJumpMax); */
	
	if (roboPlayer.HasAttribute(CTFBot_BULLET_IMMUNE))
		player.AddCond(TFCond_BulletImmune);
	
	if (roboPlayer.HasAttribute(CTFBot_BLAST_IMMUNE))
		player.AddCond(TFCond_BlastImmune);
	
	if (roboPlayer.HasAttribute(CTFBot_FIRE_IMMUNE))
		player.AddCond(TFCond_FireImmune);
	
	//Currency is used as an amount to drop
	player.SetCurrency(iCreditAmount);
	
	int nMission = roboPlayer.GetMission();
	int spyCount = 0;
	int nSniperCount = 0;
	
	if (iClass == TFClass_Spy || nMission == CTFBot_MISSION_SNIPER)
	{
		for (int i = 1; i <= MaxClients; i++)
		{
			if (IsClientInGame(i) && TF2_GetClientTeam(i) == TFTeam_Blue && IsPlayerAlive(i))
			{
				if (TF2_IsClass(i, TFClass_Spy))
					spyCount++;
				
				if (TF2_IsClass(i, TFClass_Sniper))
					nSniperCount++;
			}
		}
	}
	
	/* This is the part that tells the client game to announce incoming spies
	It will update the count for every spy on blue that is currently active */
	if (iClass == TFClass_Spy)
	{
		Event hEvent = CreateEvent("mvm_mission_update");

		if (hEvent)
		{
			hEvent.SetInt("class", view_as<int>(TFClass_Spy));
			hEvent.SetInt("count", spyCount);
			hEvent.Fire();
		}
	}
	
	if (flScale > 0.0)
		player.SetModelScale(flScale);
	
	int nHealth = iHealth;
	
	if (nHealth <= 0.0)
		nHealth = player.GetMaxHealth();
	
	//TODO: factor in GetHealthMultiplier for endless waves
	
	ModifyMaxHealth(client, nHealth, _, _, flScale);
	
	StartIdleSound(client, iClass);
	
	//NOTE: romevision is added later
	
	if (roboPlayer.HasAttribute(CTFBot_SPAWN_WITH_FULL_CHARGE))
	{
		int medigun = GetPlayerWeaponSlot(client, TFWeaponSlot_Secondary);
		
		if (medigun != -1 && TF2Util_GetWeaponID(medigun) == TF_WEAPON_MEDIGUN)
			SetEntPropFloat(medigun, Prop_Send, "m_flChargeLevel", 1.0);
		
		SetEntPropFloat(client, Prop_Send, "m_flRageMeter", 100.0);
	}
	
	int nClassIndex = view_as<int>(iClass);
	
	//TODO: this should be using the value of m_nMvMEventPopfileType from CPopulationManager
	if (GetEntProp(g_iObjectiveResource, Prop_Send, "m_nMvMEventPopfileType") == MVM_EVENT_POPFILE_HALLOWEEN)
	{
		//NOTE: this part wouldn't actually change anything visibly due to how the client's game is coded
		player.m_nSkin = 4;
		
		char itemName[64]; Format(itemName, sizeof(itemName), "Zombie %s", g_sClassNamesShort[nClassIndex]);
		
		AddItemToPlayer(client, itemName);
	}
	else
	{
		if (iClass >= TFClass_Scout && iClass <= TFClass_Engineer && nMission != CTFBot_MISSION_DESTROY_SENTRIES)
		{
			if ((flScale >= tf_mvm_miniboss_scale.FloatValue || roboPlayer.HasAttribute(CTFBot_MINIBOSS)) /* && FileExists(g_sBotBossModels[nClassIndex]) */)
			{
				player.SetCustomModel(g_sBotBossModels[nClassIndex], true);
				player.SetBloodColor(DONT_BLEED);
			}
			else //if (FileExists(g_sBotModels[nClassIndex]))
			{
				player.SetCustomModel(g_sBotModels[nClassIndex], true);
				player.SetBloodColor(DONT_BLEED);
			}
		}
	}
	
	if (nMission == CTFBot_MISSION_DESTROY_SENTRIES)
	{
		player.SetCustomModel(g_sBotSentryBusterModel, true);
		player.SetBloodColor(DONT_BLEED);
	}
	
	//Do this after the items, since this one only adds new ones if there are no equip region conflicts
	AddRomevisionCosmetics(client);
	
	//Standard shit i guess
	PostInventoryApplication(client);
	
	if (nMission == CTFBot_MISSION_DESTROY_SENTRIES)
	{
		if (GameRules_GetRoundState() == RoundState_RoundRunning)
			StartSentryBusterCooldown();
		
		MvMSuicideBomber(client).InitializeSuicideBomber(GetMostThreateningSentry());
		
		// SetAsMissionEnemy(client, true);
		
		if (IsValidEntity(g_iObjectiveResource))
		{
			int iFlags = MVM_CLASS_FLAG_MISSION;
			
			if (roboPlayer.HasAttribute(CTFBot_MINIBOSS))
				iFlags |= MVM_CLASS_FLAG_MINIBOSS;
			
			if (roboPlayer.HasAttribute(CTFBot_ALWAYS_CRIT))
				iFlags |= MVM_CLASS_FLAG_ALWAYSCRIT;
			
			TF2_IncrementMannVsMachineWaveClassCount(g_iObjectiveResource, strClassIcon, iFlags);
		}
		
		MultiplayRules_HaveAllPlayersSpeakConceptIfAllowed(MP_CONCEPT_MVM_SENTRY_BUSTER, view_as<int>(TFTeam_Red));
		
		/* TODO: replace this as this is a jank way of letting the player phase through other players
		They will only phase through if the colliding entity is actually moving, otherwise the player will still be blocked */
		SetEntityCollisionGroup(client, COLLISION_GROUP_PROJECTILE);
		
		Address pWave = GetCurrentWave(g_iPopulationManager);
		
		if (pWave)
		{
			SetNumSentryBustersSpawned(pWave, GetNumSentryBustersSpawned(pWave) + 1);
			
			if (GetNumSentryBustersSpawned(pWave) > 1)
				TeamplayRoundBasedRules_BroadcastSound(255, "Announcer.MVM_Sentry_Buster_Alert_Another");
			else
				TeamplayRoundBasedRules_BroadcastSound(255, "Announcer.MVM_Sentry_Buster_Alert");
			
			/* NOTE: doing this will likely make actual mission sentry busters spawn faster
			This actual value gets checked in CMissionPopulator::UpdateMissionDestroySentries */
			// SetNumSentryBustersKilled(pWave, 0);
		}
	}
	else if (nMission == CTFBot_MISSION_SNIPER)
	{
		//Don't update this as the loop done earlier already counts ourselves as we;ve already changed classes by now
		// nSniperCount++;
		
		//Only the first sniper is announced by the defenders
		if (nSniperCount == 1)
			MultiplayRules_HaveAllPlayersSpeakConceptIfAllowed(MP_CONCEPT_MVM_SNIPER_CALLOUT, view_as<int>(TFTeam_Red));
	}
	else if (roboPlayer.HasAttribute(CTFBot_MINIBOSS))
	{
		MultiplayRules_HaveAllPlayersSpeakConceptIfAllowed(MP_CONCEPT_MVM_GIANT_CALLOUT, view_as<int>(TFTeam_Red));
	}
	
	if (nMission == CTFBot_MISSION_SNIPER || nMission == CTFBot_MISSION_ENGINEER)
	{
		//Since we increment the icon in the wavebar, set them as the mission enemy so it decrements the icon with MVM_CLASS_FLAG_MISSION when they die
		SetAsMissionEnemy(client, true);
		
		if (IsValidEntity(g_iObjectiveResource))
		{
			int iFlags = MVM_CLASS_FLAG_MISSION;
			
			if (roboPlayer.HasAttribute(CTFBot_MINIBOSS))
				iFlags |= MVM_CLASS_FLAG_MINIBOSS;
			
			if (roboPlayer.HasAttribute(CTFBot_ALWAYS_CRIT))
				iFlags |= MVM_CLASS_FLAG_ALWAYSCRIT;
			
			TF2_IncrementMannVsMachineWaveClassCount(g_iObjectiveResource, strClassIcon, iFlags);
		}
	}
	
	float rawHere[3];
	
	SpawnLocationResult result = FindSpawnLocation(rawHere);
	
	if (result == SPAWN_LOCATION_TELEPORTER)
		OnBotTeleported(client);
	
	float here[3]; here = rawHere;
	
	float z;
	
	//Try a few heights to see if we can actually spawn here
	for (z = 0.0; z < TFBOT_STEP_HEIGHT; z += 4.0)
	{
		here[2] = rawHere[2] + TFBOT_STEP_HEIGHT;
		
		if (IsSpaceToSpawnHere(here))
			break;
	}
	
	if (z >= TFBOT_STEP_HEIGHT)
	{
		LogError("Timer_FinishRobotPlayer: %3.2f: *** No space to spawn at (%f, %f, %f)", GetGameTime(), here[0], here[1], here[2]);
		// return Plugin_Stop;
	}
	
	if (result != SPAWN_LOCATION_NOT_FOUND)
		TeleportEntity(client, here);
	else
		LogError("Timer_FinishRobotPlayer: No suitable spawn could be found for %N!", client);
	
#if defined TESTING_ONLY
	PrintToChatAll("[Timer_FinishRobotPlayer] Spawn Location for %N at %6.1f %6.1f %6.1f", client, here[0], here[1], here[2]);
#endif
	
	if (iClass == TFClass_Spy)
	{
		if (bwr3_spy_teleport_method.IntValue == SPY_TELEPORT_METHOD_MENU)
		{
			//Let him choose how he teleports
			ShowSpyTeleportMenu(client);
			SetPlayerToMove(client, false);
		}
		else
		{
			//Default teleporting
			SpyLeaveSpawnRoom_OnStart(client);
		}
	}
	else if (iClass == TFClass_Engineer && roboPlayer.HasAttribute(CTFBot_TELEPORT_TO_HINT))
	{
		if (bwr3_engineer_teleport_method.IntValue == ENGINEER_TELEPORT_METHOD_MENU)
		{
			//Let him choose how he teleports
			ShowEngineerTeleportMenu(client);
			SetPlayerToMove(client, false);
		}
		else
		{
			//Default teleporting
			MvMEngineerTeleportSpawn(client);
		}
	}
	
	//For TFBots this is actually checked in CTFBot::PhysicsSimulate
	if (roboPlayer.HasAttribute(CTFBot_ALWAYS_CRIT))
		player.AddCond(TFCond_CritCanteen);
	
	PrintToChat(client, "%s %t", PLUGIN_PREFIX, "Player_Spawn_As_Robot", strName);
	
#if defined TESTING_ONLY
	LogAction(client, -1, "%3.2f: %L spawned as robot %s", GetGameTime(), client, strName);
#endif
	
	return Plugin_Stop;
}

static void ParseEventChangeAttributesForPlayer(int client, KeyValues kv, bool bStoreToPlayer = false)
{
	MvMRobotPlayer roboPlayer = MvMRobotPlayer(client);
	
	//Before we do anything with this, store this to the player if necessary
	if (bStoreToPlayer)
		roboPlayer.SetEventChangeAttributes(kv);
	
#if defined TESTING_ONLY
	//Dump the current block of EventChangeAttributes here
	char filePath[PLATFORM_MAX_PATH]; BuildPath(Path_SM, filePath, sizeof(filePath), "data/bwr3_eventchangeattributes.txt");
	kv.ExportToFile(filePath);
#endif
	
	//Default describes what the robot's stats are for when it first spawns in
	bool isReadingDefaultAttributes = kv.JumpToKey("Default");
	
	char kvStringBuffer[16]; kv.GetString("Skill", kvStringBuffer, sizeof(kvStringBuffer));
	
	roboPlayer.SetDifficulty(GetSkillFromString(kvStringBuffer));
	roboPlayer.ClearWeaponRestrictions();
	
	kv.GetString("WeaponRestrictions", kvStringBuffer, sizeof(kvStringBuffer));
	
	roboPlayer.SetWeaponRestriction(GetWeaponRestrictionFlagsFromString(kvStringBuffer));
	
	roboPlayer.SetMaxVisionRange(kv.GetFloat("MaxVisionRange", -1.0));
	roboPlayer.ClearTags();
	
	char botTags[BOT_TAGS_BUFFER_MAX_LENGTH]; kv.GetString("Tags", botTags, sizeof(botTags));
	
	if (strlen(botTags) > 0)
	{
		char splitTags[MAX_BOT_TAG_CHECKS][BOT_TAG_EACH_MAX_LENGTH];
		int splitTagsCount = ExplodeString(botTags, ",", splitTags, sizeof(splitTags), sizeof(splitTags[]));
		
		for (int i = 0; i < splitTagsCount; i++)
			roboPlayer.AddTag(splitTags[i]);
	}
	
	roboPlayer.ClearAllAttributes();
	
	if (kv.JumpToKey("BotAttributes"))
	{
		roboPlayer.SetAttribute(GetBotAttributesFromKeyValues(kv));
		kv.GoBack();
	}
	
	if (kv.JumpToKey("CharacterAttributes"))
	{
		if (kv.GotoFirstSubKey(false))
		{
			char attributeName[PLATFORM_MAX_PATH];
			char attributeValue[PLATFORM_MAX_PATH];
			
			do
			{
				kv.GetSectionName(attributeName, sizeof(attributeName));
				kv.GetString(NULL_STRING, attributeValue, sizeof(attributeValue));
				
				TF2Attrib_SetFromStringValue(client, attributeName, attributeValue);
			} while (kv.GotoNextKey(false))
			
			kv.GoBack();
		}
		
		kv.GoBack();
	}
	
	if (kv.JumpToKey("Items"))
	{
		if (kv.GotoFirstSubKey(false))
		{
			char itemName[128];
			int item = -1;
			
			do
			{
				kv.GetSectionName(itemName, sizeof(itemName));
				
				item = AddItemToPlayer(client, itemName);
				
				if (item != -1)
				{
					if (kv.GotoFirstSubKey(false))
					{
						char attributeName[PLATFORM_MAX_PATH];
						char attributeValue[PLATFORM_MAX_PATH];
						
						do
						{
							kv.GetSectionName(attributeName, sizeof(attributeName));
							kv.GetString(NULL_STRING, attributeValue, sizeof(attributeValue));
							
							if (TF2Attrib_IsValidAttributeName(attributeName))
							{
								if (!DoSpecialSetFromStringValue(item, attributeName, attributeValue))
									TF2Attrib_SetFromStringValue(item, attributeName, attributeValue);
							}
							else
							{
								LogError("ParseEventChangeAttributesForPlayer: %s is not a real item attribute", attributeName);
							}
						} while (kv.GotoNextKey(false))
						
						kv.GoBack();
						
						//The style may have changed, tell the game to update its model
						VS_ReapplyProvision(item);
					}
				}
			} while (kv.GotoNextKey(false))
			
			kv.GoBack();
		}
		
		kv.GoBack();
	}
	
	if (isReadingDefaultAttributes)
		kv.GoBack();
}

DifficultyType GetSkillFromString(const char[] value)
{
	if (strlen(value) > 0)
	{
		if (!strcmp(value, "Easy"))
		{
			return CTFBot_EASY;
		}
		else if (!strcmp(value, "Normal"))
		{
			return CTFBot_NORMAL;
		}
		else if (!strcmp(value, "Hard"))
		{
			return CTFBot_HARD;
		}
		else if (!strcmp(value, "Expert"))
		{
			return CTFBot_EXPERT;
		}
		else
		{
			LogError("ParseDynamioAttributes: Invalid skill '%s'", value);
			return CTFBot_EASY;
		}
	}
	
	return CTFBot_EASY;
}

WeaponRestrictionType GetWeaponRestrictionFlagsFromString(const char[] value)
{
	if (strlen(value) > 0)
	{
		if (!strcmp(value, "MeleeOnly"))
		{
			return CTFBot_MELEE_ONLY;
		}
		else if (!strcmp(value, "PrimaryOnly"))
		{
			return CTFBot_PRIMARY_ONLY;
		}
		else if (!strcmp(value, "SecondaryOnly"))
		{
			return CTFBot_SECONDARY_ONLY;
		}
		else
		{
			LogError("ParseDynamioAttributes: Invalid weapon restriction '%s'", value);
			return CTFBot_ANY_WEAPON;
		}
	}
	
	return CTFBot_ANY_WEAPON;
}

static int GetBotMissionFromString(const char[] value)
{
	if (strlen(value) > 0)
	{
		if (!strcmp(value, "DestroySentries"))
		{
			return CTFBot_MISSION_DESTROY_SENTRIES;
		}
		else if (!strcmp(value, "Sniper"))
		{
			return CTFBot_MISSION_SNIPER;
		}
		else if (!strcmp(value, "Spy"))
		{
			return CTFBot_MISSION_SPY;
		}
		else if (!strcmp(value, "Engineer"))
		{
			return CTFBot_MISSION_ENGINEER;
		}
		else if (!strcmp(value, "SeekAndDestroy"))
		{
			return CTFBot_MISSION_DESTROY_SENTRIES;
		}
		else
		{
			LogError("GetBotMissionFromString: Invalid mission '%s'", value);
			return CTFBot_NO_MISSION;
		}
	}
	
	return CTFBot_NO_MISSION;
}

AttributeType GetBotAttributesFromKeyValues(KeyValues kv)
{
	AttributeType flags = CTFBot_NONE;
	
	if (kv.GetNum("RemoveOnDeath") > 0)
	{
		flags |= CTFBot_REMOVE_ON_DEATH;
	}
	
	if (kv.GetNum("Aggressive") > 0)
	{
		flags |= CTFBot_AGGRESSIVE;
	}
	if (kv.GetNum("SuppressFire") > 0)
	{
		flags |= CTFBot_SUPPRESS_FIRE;
	}
	if (kv.GetNum("DisableDodge") > 0)
	{
		flags |= CTFBot_DISABLE_DODGE;
	}
	if (kv.GetNum("BecomeSpectatorOnDeath") > 0)
	{
		flags |= CTFBot_BECOME_SPECTATOR_ON_DEATH;
	}
	if (kv.GetNum("RetainBuildings") > 0)
	{
		flags |= CTFBot_RETAIN_BUILDINGS;
	}
	if (kv.GetNum("SpawnWithFullCharge") > 0)
	{
		flags |= CTFBot_SPAWN_WITH_FULL_CHARGE;
	}
	if (kv.GetNum("AlwaysCrit") > 0)
	{
		flags |= CTFBot_ALWAYS_CRIT;
	}
	if (kv.GetNum("IgnoreEnemies") > 0)
	{
		flags |= CTFBot_IGNORE_ENEMIES;
	}
	if (kv.GetNum("HoldFireUntilFullReload") > 0)
	{
		flags |= CTFBot_HOLD_FIRE_UNTIL_FULL_RELOAD;
	}
	if (kv.GetNum("AlwaysFireWeapon") > 0)
	{
		flags |= CTFBot_ALWAYS_FIRE_WEAPON;
	}
	if (kv.GetNum("TeleportToHint") > 0)
	{
		flags |= CTFBot_TELEPORT_TO_HINT;
	}
	if (kv.GetNum("MiniBoss") > 0)
	{
		flags |= CTFBot_MINIBOSS;
	}
	if (kv.GetNum("UseBossHealthBar") > 0)
	{
		flags |= CTFBot_USE_BOSS_HEALTH_BAR;
	}
	if (kv.GetNum("IgnoreFlag") > 0)
	{
		flags |= CTFBot_IGNORE_FLAG;
	}
	if (kv.GetNum("AutoJump") > 0)
	{
		flags |= CTFBot_AUTO_JUMP;
	}
	if (kv.GetNum("AirChargeOnly") > 0)
	{
		flags |= CTFBot_AIR_CHARGE_ONLY;
	}
	if (kv.GetNum("VaccinatorBullets") > 0)
	{
		flags |= CTFBot_PREFER_VACCINATOR_BULLETS;
	}
	if (kv.GetNum("VaccinatorBlast") > 0)
	{
		flags |= CTFBot_PREFER_VACCINATOR_BLAST;
	}
	if (kv.GetNum("VaccinatorFire") > 0)
	{
		flags |= CTFBot_PREFER_VACCINATOR_FIRE;
	}
	if (kv.GetNum("BulletImmune") > 0)
	{
		flags |= CTFBot_BULLET_IMMUNE;
	}
	if (kv.GetNum("BlastImmune") > 0)
	{
		flags |= CTFBot_BLAST_IMMUNE;
	}
	if (kv.GetNum("FireImmune") > 0)
	{
		flags |= CTFBot_FIRE_IMMUNE;
	}
	if (kv.GetNum("Parachute") > 0)
	{
		flags |= CTFBot_PARACHUTE;
	}
	if (kv.GetNum("ProjectileShield") > 0)
	{
		flags |= CTFBot_PROJECTILE_SHIELD;
	}
	
	return flags;
}

//Different from CTFBot::ModifyMaxHealth, as I don't feel model scale override necessary as its own variable right now
void ModifyMaxHealth(int client, int nNewMaxHealth, bool bSetCurrentHealth = true, bAllowModelScaling = true, float flModelScaleOverride = 0.0)
{
	OSTFPlayer player = OSTFPlayer(client);
	
	int maxHealth = TF2Util_GetEntityMaxHealth(client);
	
	if (maxHealth != nNewMaxHealth)
		TF2Attrib_SetByName(client, "hidden maxhealth non buffed", float(nNewMaxHealth - maxHealth));
	
	if (bSetCurrentHealth)
		player.SetHealth(nNewMaxHealth);
	
	if (bAllowModelScaling && player.IsMiniBoss())
		player.SetModelScale(flModelScaleOverride > 0.0 ? flModelScaleOverride : tf_mvm_miniboss_scale.FloatValue);
}

static void StartIdleSound(int client, TFClassType class)
{
	StopIdleSound(client);
	
	if (TF2_IsMiniBoss(client))
	{
		int level;
		float volume;
		int pitch;
		bool bFound = false;
		
		switch (class)
		{
			case TFClass_Heavy:	bFound = GetGameSoundParams("MVM.GiantHeavyLoop", m_nIdleSoundChannel[client], level, volume, pitch, m_sIdleSound[client], sizeof(m_sIdleSound[]), client);
			case TFClass_Soldier:	bFound = GetGameSoundParams("MVM.GiantSoldierLoop", m_nIdleSoundChannel[client], level, volume, pitch, m_sIdleSound[client], sizeof(m_sIdleSound[]), client);
			case TFClass_DemoMan:
			{
				bFound = GetGameSoundParams(MvMRobotPlayer(client).HasMission(CTFBot_MISSION_DESTROY_SENTRIES) ? "MVM.SentryBusterLoop" : "MVM.GiantDemomanLoop", m_nIdleSoundChannel[client], level, volume, pitch, m_sIdleSound[client], sizeof(m_sIdleSound[]), client);
			}
			case TFClass_Scout:	bFound = GetGameSoundParams("MVM.GiantScoutLoop", m_nIdleSoundChannel[client], level, volume, pitch, m_sIdleSound[client], sizeof(m_sIdleSound[]), client);
			case TFClass_Pyro:	bFound = GetGameSoundParams("MVM.GiantPyroLoop", m_nIdleSoundChannel[client], level, volume, pitch, m_sIdleSound[client], sizeof(m_sIdleSound[]), client);
		}
		
		if (bFound)
		{
			//Emit to everyone
			int[] iArrClients = new int[MaxClients];
			int total = 0;

			for (int i = 1; i <= MaxClients; i++)
				if (IsClientInGame(i))
					iArrClients[total++] = i;
			
			if (total)
				EmitSound(iArrClients, total, m_sIdleSound[client], client, m_nIdleSoundChannel[client], level, _, volume, pitch);
		}
	}
}

//NEW METHOD: heavily based on a function from [TF2] Chaos Mod
//NOTE: it doesn't seem to always remove conflicting cosmetics...
int AddItemToPlayer(int client, const char[] szItemName)
{
	int iItemDefIndex = GetItemDefinitionIndexByName(szItemName);
	
	if (iItemDefIndex != TF_ITEMDEF_DEFAULT)
	{
		// If we already have an item in that slot, remove it
		TFClassType nClass = TF2_GetPlayerClass(client);
		int iSlot = TF2Econ_GetItemLoadoutSlot(iItemDefIndex, nClass);
		int nNewItemRegionMask = TF2Econ_GetItemEquipRegionMask(iItemDefIndex);
		
		if (IsWearableSlot(iSlot))
		{
			// Remove any wearable that has a conflicting equip_region
			for (int wbl = 0; wbl < TF2Util_GetPlayerWearableCount(client); wbl++)
			{
				int wearable = TF2Util_GetPlayerWearable(client, wbl);
				
				if (wearable == -1)
					continue;
				
				int iWearableDefIndex = GetEntProp(wearable, Prop_Send, "m_iItemDefinitionIndex");
				
				if (iWearableDefIndex == 0xFFFF)
					continue;
				
				int nWearableRegionMask = TF2Econ_GetItemEquipRegionMask(iWearableDefIndex);
				
				if (nWearableRegionMask & nNewItemRegionMask)
				{
					TF2_RemoveWearable(client, wearable);
				}
			}
		}
		else
		{
			int entity = TF2Util_GetPlayerLoadoutEntity(client, iSlot);
			
			if (entity != -1)
			{
				RemovePlayerItem(client, entity);
				RemoveEntity(entity);
			}
		}
		
		char szClassname[64];
		TF2Econ_GetItemClassName(iItemDefIndex, szClassname, sizeof(szClassname));
		TF2Econ_TranslateWeaponEntForClass(szClassname, sizeof(szClassname), nClass);
		
		int newItem = EconItemCreateNoSpawn(szClassname, iItemDefIndex, 1, AE_UNIQUE);
		
		if (newItem != -1)
		{
			SetRandomEconItemID(newItem);
			EconItemSpawnGiveTo(newItem, client);
		}
		
		// PostInventoryApplication(client);
		
		return newItem;
	}
	else
	{
		if (szItemName[0])
		{
			LogError("AddItemToPlayer: Invalid item %s.", szItemName);
		}
	}
	
	return -1;
}

static void AddRomevisionCosmetics(int client)
{
	//We're not gonna nitpicks about adding then removing items, as it's counter-intuitive
	//Instead, we will only add the items if they have no conflict with what we're currently wearing
	if (MvMRobotPlayer(client).HasMission(CTFBot_MISSION_DESTROY_SENTRIES))
	{
		const int sentrybusterRomeDefIndex = 30161; //tw_sentrybuster
		
		if (!DoPlayerWearablesConflictWith(client, sentrybusterRomeDefIndex))
		{
			int item = EconItemCreateNoSpawn("tf_wearable", sentrybusterRomeDefIndex, 1, AE_UNIQUE);
			
			if (item != -1)
			{
				SetRandomEconItemID(item);
				EconItemSpawnGiveTo(item, client);
			}
		}
	}
	else
	{
		int classIndex = view_as<int>(TF2_GetPlayerClass(client));
		int hatIndex = g_iRomePromoItems_Hat[classIndex];
		int miscIndex = g_iRomePromoItems_Misc[classIndex];
		
		if (!DoPlayerWearablesConflictWith(client, hatIndex))
		{
			int item = EconItemCreateNoSpawn("tf_wearable", hatIndex, 1, AE_UNIQUE);
			
			if (item != -1)
			{
				SetRandomEconItemID(item);
				EconItemSpawnGiveTo(item, client);
			}
		}
		
		if (!DoPlayerWearablesConflictWith(client, miscIndex))
		{
			int item = EconItemCreateNoSpawn("tf_wearable", miscIndex, 1, AE_UNIQUE);
			
			if (item != -1)
			{
				SetRandomEconItemID(item);
				EconItemSpawnGiveTo(item, client);
			}
		}
	}
	
	// PostInventoryApplication(client);
}

static bool ShouldDispatchSentryBuster()
{
	//Still on cooldown
	if (m_flSentryBusterCooldown > GetGameTime())
		return false;
	
	//TODO: we should actually check if other sentries can be targeted, not just single out one
	//Also factor in players whose next robot are sentry busters and what sentry they're gonna target
	int sentry = GetMostThreateningSentry();
	
	if (sentry == -1)
		return false;
	
	if (IsSentryAlreadyTargeted(sentry))
		return false;
	
	return true;
}

static int GetMostThreateningSentry()
{
	int nDmgLimit = 0;
	int nKillLimit = 0;
	GetSentryBusterDamageAndKillThreshold(g_iPopulationManager, nDmgLimit, nKillLimit);
	
	int ent = -1;
	
	while ((ent = FindEntityByClassname(ent, "obj_sentrygun")) != -1)
	{
		OSBaseObject cboSentry = OSBaseObject(ent);
		
		if (cboSentry.IsDisposableBuilding())
			continue;
		
		if (cboSentry.GetTeamNumber() == view_as<int>(TFTeam_Red))
		{
			int sentryOwner = cboSentry.GetOwner();
			
			if (sentryOwner != -1)
			{
				int nDmgDone = RoundFloat(GetAccumulatedSentryGunDamageDealt(sentryOwner));
				int nKillsMade = GetAccumulatedSentryGunKillCount(sentryOwner);
				
				if (nDmgDone >= nDmgLimit || nKillsMade >= nKillLimit)
					return ent;
			}
		}
	}
	
	return -1;
}

SpawnLocationResult FindSpawnLocation(float vSpawnPosition[3], float playerScale = 1.0)
{
	int activeTeleporter = EntRefToEntIndex(g_iRefLastTeleporter);
	
	if (activeTeleporter != INVALID_ENT_REFERENCE && IsTeleporterUsableByRobots(activeTeleporter))
	{
		//Just use the teleporter we're already aware of
		vSpawnPosition = WorldSpaceCenter(activeTeleporter);
		return SPAWN_LOCATION_TELEPORTER;
	}
	
	ArrayList adtTeleporter = new ArrayList();
	int ent = -1;
	
	while ((ent = FindEntityByClassname(ent, "obj_teleporter")) != -1)
	{
		if (!IsTeleporterUsableByRobots(ent))
			continue;
		
		adtTeleporter.Push(ent);
	}
	
	if (adtTeleporter.Length > 0)
	{
		int which = GetRandomInt(0, adtTeleporter.Length - 1);
		int chosenTeleporter = adtTeleporter.Get(which);
		delete adtTeleporter;
		
		vSpawnPosition = WorldSpaceCenter(chosenTeleporter);
		g_iRefLastTeleporter = EntIndexToEntRef(chosenTeleporter);
		
		return SPAWN_LOCATION_TELEPORTER;
	}
	
	delete adtTeleporter;
	
	ent = -1;
	ArrayList adtSpawnPoints = new ArrayList();
	
	while ((ent = FindEntityByClassname(ent, "info_player_teamspawn")) != -1)
	{
		if (GetEntProp(ent, Prop_Data, "m_bDisabled") == 1)
			continue;
		
		if (BaseEntity_GetTeamNumber(ent) == view_as<int>(TFTeam_Red))
			continue;
		
		adtSpawnPoints.Push(ent);
	}
	
	if (adtSpawnPoints.Length == 0)
	{
		//Could not find any spawn points to begin with
		delete adtSpawnPoints;
		return SPAWN_LOCATION_NOT_FOUND;
	}
	
	float origin[3];
	int maxTries = adtSpawnPoints.Length;
	
	for (int i = 0; i < maxTries; i++)
	{
		int index = GetRandomInt(0, adtSpawnPoints.Length - 1);
		int spawn = adtSpawnPoints.Get(index);
		adtSpawnPoints.Erase(index);
		origin = WorldSpaceCenter(spawn);
		
		if (IsSpaceToSpawnHere(origin, playerScale))
		{
			vSpawnPosition = origin;
			break;
		}
	}
	
	delete adtSpawnPoints;
	
	if (IsZeroVector(vSpawnPosition))
		return SPAWN_LOCATION_NOT_FOUND;
	
	CNavArea spawnArea = TheNavMesh.GetNearestNavArea(vSpawnPosition);
	
	if (spawnArea == NULL_AREA)
		return SPAWN_LOCATION_NOT_FOUND;
	
	spawnArea.GetCenter(vSpawnPosition);
	
	return SPAWN_LOCATION_NAV;
}

void OnBotTeleported(int client)
{
	int teleporter = EntRefToEntIndex(g_iRefLastTeleporter);
	
	// float origin[3]; origin = GetAbsOrigin(teleporter);
	
	if (GetGameTime() - g_flLastTeleportTime > 0.1)
	{
		EmitGameSoundToAll("MVM.Robot_Teleporter_Deliver", teleporter);
		g_flLastTeleportTime = GetGameTime();
	}
	
	//Have us face the direction specified by the teleporter
	float vForward[3];
	float teleporterAngles[3]; teleporterAngles = GetAbsAngles(teleporter);
	GetAngleVectors(teleporterAngles, vForward, NULL_VECTOR, NULL_VECTOR);
	
	float vecFaceTowards[3]; GetClientAbsOrigin(client, vecFaceTowards);
	vecFaceTowards[0] = vecFaceTowards[0] + 50 * vForward[0];
	vecFaceTowards[1] = vecFaceTowards[1] + 50 * vForward[1];
	vecFaceTowards[2] = vecFaceTowards[2] + 50 * vForward[2];
	
	SnapViewToPosition(client, vecFaceTowards);
	
	if (!TF2_IsClass(client, TFClass_Spy))
	{
		TeleportEffect(client);
		
		float flUberTime = tf_mvm_engineer_teleporter_uber_duration.FloatValue;
		TF2_AddCondition(client, TFCond_Ubercharged, flUberTime);
		TF2_AddCondition(client, TFCond_UberchargeFading, flUberTime);
	}
}

static int GetActiveSentryBusterCount()
{
	int count = 0;
	
	for (int i = 1; i <= MaxClients; i++)
		if (IsClientInGame(i) && TF2_GetClientTeam(i) == TFTeam_Blue && IsPlayerAlive(i) && IsSentryBusterRobot(i))
			count++;
	
	return count;
}

//See if another player is already after this sentry
static bool IsSentryAlreadyTargeted(int sentry)
{
	for (int i = 1; i <= MaxClients; i++)
		if (IsClientInGame(i) && IsPlayingAsRobot(i) && MvMSuicideBomber(i).GetMissionTarget() == sentry)
			return true;
	
	return false;
}

bool AreGatebotsAvailable()
{
	//If there's a point RED can defend, then it's a point BLUE can capture
	return GetDefendablePointTrigger(TFTeam_Red) != -1;
}

void ResetRobotSpawnerData()
{
	g_iRefLastTeleporter = INVALID_ENT_REFERENCE;
	g_flLastTeleportTime = 0.0;
	
	m_flDestroySentryCooldownDuration = 0.0;
	m_flSentryBusterCooldown = 0.0;
}

void StartSentryBusterCooldown()
{
	//TODO: factor in NumSentryBustersKilled?
	m_flSentryBusterCooldown = GetGameTime() + m_flDestroySentryCooldownDuration;
}

// Determine the next robot template the player should use on their next spawn
void SelectPlayerNextRobot(int client)
{
	MvMRobotPlayer roboPlayer = MvMRobotPlayer(client);
	
	if (g_bRobotBossesAvailable && g_flNextBossSpawnTime <= GetGameTime())
	{
		roboPlayer.SetMyNextRobot(ROBOT_BOSS, GetRandomInt(0, g_iTotalRobotTemplates[ROBOT_BOSS] - 1));
		g_bSpawningAsBossRobot[client] = true;
		g_bRobotBossesAvailable = false;
		return;
	}
	
	if (ShouldDispatchSentryBuster())
	{
		roboPlayer.SetMyNextRobot(ROBOT_SENTRYBUSTER, GetRandomInt(0, g_iTotalRobotTemplates[ROBOT_SENTRYBUSTER] - 1));
		return;
	}
	
	bool bShouldBeGatebot = AreGatebotsAvailable() && RollRandomChanceFloat(bwr3_robot_gatebot_chance.FloatValue);
	
	if (GetTeamClientCount(view_as<int>(TFTeam_Red)) >= bwr3_minmimum_players_for_giants.IntValue)
	{
		if (RollRandomChanceFloat(bwr3_robot_giant_chance.FloatValue))
		{
			if (bShouldBeGatebot)
			{
				roboPlayer.SetMyNextRobot(ROBOT_GATEBOT_GIANT, GetRandomInt(0, g_iTotalRobotTemplates[ROBOT_GATEBOT_GIANT] - 1));
			}
			else
			{
				roboPlayer.SetMyNextRobot(ROBOT_GIANT, GetRandomInt(0, g_iTotalRobotTemplates[ROBOT_GIANT] - 1));
			}
			
			return;
		}
	}
	
	if (bShouldBeGatebot)
	{
		roboPlayer.SetMyNextRobot(ROBOT_GATEBOT, GetRandomInt(0, g_iTotalRobotTemplates[ROBOT_GATEBOT] - 1));
	}
	else
	{
		roboPlayer.SetMyNextRobot(ROBOT_STANDARD, GetRandomInt(0, g_iTotalRobotTemplates[ROBOT_STANDARD] - 1));
	}
}

bool ForceRandomPlayerToReselectRobot()
{
	int newPlayer = GetRandomRobotPlayer();
	
	if (newPlayer != -1)
	{
		SelectPlayerNextRobot(newPlayer);
		return true;
	}
	
	return false;
}

void ForceAllPlayersToReselectRobot(int excludePlayer = -1)
{
	for (int i = 1; i <= MaxClients; i++)
	{
		if (i != excludePlayer && IsClientInGame(i) && IsPlayingAsRobot(i))
		{
			SelectPlayerNextRobot(i);
		}
	}
}

void TurnPlayerIntoHisNextRobot(int client)
{
	MvMRobotPlayer roboPlayer = MvMRobotPlayer(client);
	
	g_bCanRespawn[client] = true;
	TurnPlayerIntoRobot(client, roboPlayer.MyNextRobotTemplateType, roboPlayer.MyNextRobotTemplateID);
	
	if (roboPlayer.MyNextRobotTemplateType == ROBOT_BOSS)
		g_bSpawningAsBossRobot[client] = false;
}

void UpdateRobotTemplateDataForType(eRobotTemplateType type = ROBOT_STANDARD)
{
	char fileName[PLATFORM_MAX_PATH];
	char filePath[PLATFORM_MAX_PATH];
	KeyValues kv = null;
	
	switch (type)
	{
		case ROBOT_STANDARD:
		{
			bwr3_robot_template_file.GetString(fileName, sizeof(fileName));
			BuildPath(Path_SM, filePath, sizeof(filePath), "%s/%s", ROBOT_TEMPLATE_CONFIG_DIRECTORY, fileName);
			
			if (!FileExists(filePath))
				ThrowError("Could not find standard robot config file: %s", filePath);
			
			kv = new KeyValues("RobotStandardTemplates");
		}
		case ROBOT_GIANT:
		{
			bwr3_robot_giant_template_file.GetString(fileName, sizeof(fileName));
			BuildPath(Path_SM, filePath, sizeof(filePath), "%s/%s", ROBOT_TEMPLATE_CONFIG_DIRECTORY, fileName);
			
			if (!FileExists(filePath))
				ThrowError("Could not find giant robot config file: %s", filePath);
			
			kv = new KeyValues("RobotGiantTemplates");
		}
		case ROBOT_GATEBOT:
		{
			bwr3_robot_gatebot_template_file.GetString(fileName, sizeof(fileName));
			BuildPath(Path_SM, filePath, sizeof(filePath), "%s/%s", ROBOT_TEMPLATE_CONFIG_DIRECTORY, fileName);
			
			if (!FileExists(filePath))
				ThrowError("Could not find gatebot robot config file: %s", filePath);
			
			kv = new KeyValues("RobotGatebotTemplates");
		}
		case ROBOT_GATEBOT_GIANT:
		{
			bwr3_robot_gatebot_giant_template_file.GetString(fileName, sizeof(fileName));
			BuildPath(Path_SM, filePath, sizeof(filePath), "%s/%s", ROBOT_TEMPLATE_CONFIG_DIRECTORY, fileName);
			
			if (!FileExists(filePath))
				ThrowError("Could not find giant gatebot robot config file: %s", filePath);
			
			kv = new KeyValues("RobotGatebotGiantTemplates");
		}
		case ROBOT_SENTRYBUSTER:
		{
			bwr3_robot_sentrybuster_template_file.GetString(fileName, sizeof(fileName));
			BuildPath(Path_SM, filePath, sizeof(filePath), "%s/%s", ROBOT_TEMPLATE_CONFIG_DIRECTORY, fileName);
			
			if (!FileExists(filePath))
				ThrowError("Could not find sentry buster robot config file: %s", filePath);
			
			kv = new KeyValues("RobotSentryBusterTemplates");
		}
		case ROBOT_BOSS:
		{
			bwr3_robot_boss_template_file.GetString(fileName, sizeof(fileName));
			BuildPath(Path_SM, filePath, sizeof(filePath), "%s/%s", ROBOT_TEMPLATE_CONFIG_DIRECTORY, fileName);
			
			if (!FileExists(filePath))
				ThrowError("Could not find boss robot config file: %s", filePath);
			
			kv = new KeyValues("RobotBossTemplates");
		}
		default:	LogError("UpdateRobotTemplateDataForType: Unknown robot template type %d", type);
	}
	
	if (kv && kv.ImportFromFile(filePath))
	{
		if (kv.JumpToKey("Templates"))
		{
			kv.GotoFirstSubKey(false);
			
			g_iTotalRobotTemplates[type] = 0;
			
			do
			{
				if (g_iTotalRobotTemplates[type] >= MAX_ROBOT_TEMPLATES)
				{
					LogError("UpdateRobotTemplateDataForType: Type %d reached the max robot template limit!", type);
					break;
				}
				
				//Store these details for later
				kv.GetString("Name", g_sRobotTemplateName[type][g_iTotalRobotTemplates[type]], sizeof(g_sRobotTemplateName[][]), ROBOT_NAME_UNDEFINED);
				
				g_iTotalRobotTemplates[type]++;
			} while (kv.GotoNextKey(false))
			
			LogMessage("UpdateRobotTemplateDataForType: Found %d robot templates for robot template type %d", g_iTotalRobotTemplates[type], type);
		}
	}
	else
	{
		ThrowError("Could not import KeyValues from file %s", filePath);
	}
	
	delete kv;
}

char[] GetRobotTemplateName(eRobotTemplateType type, int templateID)
{
	return g_sRobotTemplateName[type][templateID];
}

void UpdateEngineerHintLocations()
{
	//Reset currently stored data
	for (int i = 0; i < sizeof(g_vecEngineerHintOrigin); i++)
		g_vecEngineerHintOrigin[i] = NULL_VECTOR;
	
	int ent = -1;
	int index = 0;
	
	while ((ent = FindEntityByClassname(ent, "bot_hint_engineer_nest")) != -1)
	{
		if (index >= sizeof(g_vecEngineerHintOrigin))
		{
			LogError("UpdateEngineerHintLocations: reached the limit for engineer hint locations");
			break;
		}
		
		/* if (GetEntProp(ent, Prop_Data, "m_isDisabled") == 1)
			continue; */
		
		g_vecEngineerHintOrigin[index++] = GetAbsOrigin(ent);
	}
}

// Finds an origin nearest to the specified position vector
static void GetNearestEngineerHintPosition(float vec[3], float outputOrigin[3])
{
	float bestDistance = 999999.0;
	
	//Cycle through all the stored hint positions
	for (int i = 0; i < sizeof(g_vecEngineerHintOrigin); i++)
	{
		//Stop right here, cause the rest are probably empty as well
		if (IsZeroVector(g_vecEngineerHintOrigin[i]))
			break;
		
		float distance = GetVectorDistance(vec, g_vecEngineerHintOrigin[i]);
		
		if (distance <= bestDistance)
		{
			bestDistance = distance;
			outputOrigin = g_vecEngineerHintOrigin[i];
		}
	}
	
	//TODO: angles
}

void StopIdleSound(int client)
{
	if (strlen(m_sIdleSound[client]) > 0)
	{
		StopSound(client, m_nIdleSoundChannel[client], m_sIdleSound[client]);
		m_sIdleSound[client] = NULL_STRING;
		m_nIdleSoundChannel[client] = SNDCHAN_AUTO;
	}
}

bool IsSentryBusterRobot(int client)
{
	if (IsPlayingAsRobot(client) && MvMRobotPlayer(client).HasMission(CTFBot_MISSION_DESTROY_SENTRIES))
		return true;
	
	//TODO: find a better way to determine if a tfbot is a sentry buster
	
	char modelName[PLATFORM_MAX_PATH]; GetClientModel(client, modelName, sizeof(modelName));
	
	return StrEqual(modelName, "models/bots/demo/bot_sentry_buster.mdl");
}

void SpyLeaveSpawnRoom_OnStart(int client)
{
	TF2_DisguiseAsMemberOfEnemyTeam(client);
	
	PressAltFireButton(client);
	
	CreateTimer(2.0 + GetRandomFloat(0.0, 1.0), Timer_SpyLeaveSpawnRoom, client, TIMER_FLAG_NO_MAPCHANGE);
	
	m_iSpyTeleportAttempt[client] = 0;
	
	SetPlayerToMove(client, false);
	
	PrintToChat(client, "%s %t", PLUGIN_PREFIX, "Spy_Teleporting");
}

bool IsValidSpyTeleportVictim(int victim)
{
	return IsClientInGame(victim) && IsPlayerAlive(victim);
}

void MvMEngineerTeleportSpawn(int client, eEngineerTeleportType type = ENGINEER_TELEPORT_NEAR_BOMB)
{
	float hintTeleportPos[3];
	
	switch (type)
	{
		case ENGINEER_TELEPORT_NEAR_BOMB:
		{
			int flag = FindBombNearestToHatch();
			
			if (flag != -1)
			{
				GetNearestEngineerHintPosition(WorldSpaceCenter(flag), hintTeleportPos);
			}
			else
			{
				//TODO: find the engineer hint closest to the robot spawn then
			}
		}
		case ENGINEER_TELEPORT_RANDOM:
		{
			int validCount = 0;
			
			for (int i = 0; i < sizeof(g_vecEngineerHintOrigin); i++)
			{
				//Not valid, the rest won't be either
				if (IsZeroVector(g_vecEngineerHintOrigin[i]))
					break;
				
				validCount++;
			}
			
			if (validCount > 0)
				hintTeleportPos = g_vecEngineerHintOrigin[GetRandomInt(0, validCount - 1)];
		}
		case ENGINEER_TELEPORT_NEAR_TEAMMATE:
		{
			int ally = GetRandomLivingPlayerFromTeam(TFTeam_Blue, client);
			
			if (ally != -1)
			{
				float allyPos[3]; GetClientAbsOrigin(ally, allyPos);
				GetNearestEngineerHintPosition(allyPos, hintTeleportPos);
			}
		}
	}
	
	//When using the menu we disable movement, re-enable it before we teleport
	SetPlayerToMove(client, true);
	
	if (IsZeroVector(hintTeleportPos))
	{
		LogError("MvMEngineerTeleportSpawn: no hint origins could be found for this specific map!");
		return;
	}
	
	DataPack pack;
	CreateDataTimer(0.1, Timer_MvMEngineerTeleportSpawn, pack, TIMER_FLAG_NO_MAPCHANGE);
	pack.WriteCell(client);
	pack.WriteFloatArray(hintTeleportPos, sizeof(hintTeleportPos));
	
	TF2_PushAllPlayersAway(hintTeleportPos, 400.0, 500.0, TFTeam_Red);
}

bool UpdateSentryBusterSpawningCriteria()
{
	char missionFilePath[PLATFORM_MAX_PATH]; TF2_GetMvMPopfileName(g_iObjectiveResource, missionFilePath, sizeof(missionFilePath));
	
	if (!FileExists(missionFilePath))
	{
		//Search the valve directory then...
		if (!FileExists(missionFilePath, true))
		{
			LogError("UpdateSentryBusterSpawningCriteria: Could not find the current mission file %s!", missionFilePath);
			return false;
		}
	}
	
	int currentWaveNumber = TF2_GetMannVsMachineWaveCount(g_iObjectiveResource);
	bool bUpdated = false;
	KeyValues kv = new KeyValues("Population");
	kv.ImportFromFile(missionFilePath);
	
	//Search the pop file for a sentry buster specification that can be used for this current wave
	if (kv.GotoFirstSubKey())
	{
		char name[8];
		char botMissionName[16];
		
		do
		{
			kv.GetSectionName(name, sizeof(name));
			
			if (!strcmp(name, "Mission", false))
			{
				kv.GetString("Objective", botMissionName, sizeof(botMissionName));
				
				if (GetBotMissionFromString(botMissionName) == CTFBot_MISSION_DESTROY_SENTRIES)
				{
					int beginAtWaveNumber = kv.GetNum("BeginAtWave", 1);
					
					if (currentWaveNumber >= beginAtWaveNumber)
					{
						int waveDuration = kv.GetNum("RunForThisManyWaves", -1);
						
						if (waveDuration == -1)
							waveDuration = 99999;
						
						//NOTE: since we use the actual wave number instead of the internal index, we subtract 1 from beginAtWaveNumber
						int stopAtWaveNumber = (beginAtWaveNumber - 1) + waveDuration;
						
						if (currentWaveNumber <= stopAtWaveNumber)
						{
							m_flDestroySentryCooldownDuration = kv.GetFloat("CooldownTime");
							bUpdated = true;
							break;
						}
					}
				}
			}
		} while (kv.GotoNextKey())
	}
	
	delete kv;
	
#if defined TESTING_ONLY
	PrintToChatAll("[UpdateSentryBusterSpawningCriteria] Sentry buster cooldown for wave %d: %f", currentWaveNumber, m_flDestroySentryCooldownDuration);
#endif
	
	return bUpdated;
}

bool BossRobotSystem_UpdateData()
{
	g_bRobotBossesAvailable = false;
	g_flBossDelayDuration = 60.0;
	g_flBossRespawnDelayDuration = 0.0;
	g_bBossProportionalHealth = true;
	
	char mapName[PLATFORM_MAX_PATH]; GetCurrentMap(mapName, sizeof(mapName));
	
	char filePath[PLATFORM_MAX_PATH]; BuildPath(Path_SM, filePath, sizeof(filePath), "configs/bwree/bosswave/%s.cfg", mapName);
	
	if (!FileExists(filePath))
	{
		LogError("LoadBossWaveConfig: File %s not found.", filePath);
		return false;
	}
	
	KeyValues kv = new KeyValues("BossWaveConfig");
	
	kv.ImportFromFile(filePath);
	
	int waveNumber = TF2_GetMannVsMachineWaveCount(g_iObjectiveResource);
	int maxWaveNumber = TF2_GetMannVsMachineMaxWaveCount(g_iObjectiveResource);
	
	char missionName[PLATFORM_MAX_PATH]; TF2_GetMvMPopfileName(g_iObjectiveResource, missionName, sizeof(missionName));
	char sectionWaveNum[16];
	
	//Remove these things
	ReplaceString(missionName, sizeof(missionName), "scripts/population/", "");
	ReplaceString(missionName, sizeof(missionName), ".pop", "");
	
	if (kv.JumpToKey(missionName))
	{
		FormatEx(sectionWaveNum, sizeof(sectionWaveNum), "wave%d", waveNumber);
		
		if (kv.JumpToKey(sectionWaveNum))
		{
			g_bRobotBossesAvailable = true;
			g_flBossDelayDuration = kv.GetFloat("delay", 60.0);
			g_flBossRespawnDelayDuration = kv.GetFloat("respawn_delay", 0.0);
			g_bBossProportionalHealth = view_as<bool>(kv.GetNum("proportional_health", 1));
		}
		else
		{
			delete kv;
			LogError("LoadBossWaveConfig: Could not find config for wave %d of mission %s", waveNumber, missionName);
			return false;
		}
	}
	else if (kv.JumpToKey("default"))
	{
		//Allow the boss robot on the final wave
		if (waveNumber == maxWaveNumber)
		{
			g_bRobotBossesAvailable = true;
			g_flBossDelayDuration = kv.GetFloat("delay", 60.0);
			g_flBossRespawnDelayDuration = kv.GetFloat("respawn_delay", 0.0);
		}
		else
		{
			delete kv;
			return false;
		}
	}
	else
	{
		delete kv;
		LogError("LoadBossWaveConfig: Could not find default section");
		return false;
	}
	
	delete kv;
	
#if defined TESTING_ONLY
	LogMessage("BOSS SYSTEM: available = %d, delay = %f, respawn delay = %f", g_bRobotBossesAvailable ? 1 : 0, g_flBossDelayDuration, g_flBossRespawnDelayDuration);
#endif
	
	return true;
}

void BossRobotSystem_StartSpawnCooldown()
{
	g_flNextBossSpawnTime = GetGameTime() + g_flBossDelayDuration;
}