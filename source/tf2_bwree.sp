/* --------------------------------------------------
Be with Robots 3
February 27 2024
Author: ★ Officer Spy ★
-------------------------------------------------- */
#include <sourcemod>
#include <tf2_stocks>
#include <sdkhooks>
#include <dhooks>
#include <tf2attributes>
#include <tf2utils>
#include <tf_econ_data>
#include <cbasenpc>

#if defined _CBASENPC_EXTENSION_INC_
#include <cbasenpc/tf/nav>
#define MOD_EXT_CBASENPC
#endif

#pragma semicolon 1
#pragma newdecls required

#define PLUGIN_NAME	"[TF2] Be with Robots: Expanded & Enhanced"
#define PLUGIN_PREFIX	"[BWR E&E]"

#define TESTING_ONLY

#define TELEPORTER_METHOD_MANUAL
#define FIX_VOTE_CONTROLLER

bool g_bLateLoad;
bool g_bCanBotsAttackInSpawn;

int g_iObjectiveResource = -1;
int g_iPopulationManager = -1;

int g_iForcedButtonInput[MAXPLAYERS + 1];

static bool m_bIsRobot[MAXPLAYERS + 1];
static bool m_bBypassBotCheck[MAXPLAYERS + 1];
static float m_flCaptureZoneLastTouch[MAXPLAYERS + 1];
static bool m_bIsWaitingForReload[MAXPLAYERS + 1];
static eRobotTemplateType m_nRobotVariantType[MAXPLAYERS + 1];
static float m_flNextRobotSpawnTime[MAXPLAYERS + 1];
static float m_flAutoJumpTime[MAXPLAYERS + 1];
static int m_nDeployingBombState[MAXPLAYERS + 1]; //The state our deploying is currently in
static float m_flDeployingBombTime[MAXPLAYERS + 1]; //Only used as a time variable for each state the deploying is in
static float m_vecDeployPos[MAXPLAYERS + 1][3]; //Where we started deploying at
static float m_flUpgradeTime[MAXPLAYERS + 1]; //Time variable for upgrading the bomb
static float m_flBuffPulseTime[MAXPLAYERS + 1]; //Time variable for applying the bomb buff
static float m_flChuckleTime[MAXPLAYERS + 1]; //Time variable for when we can next laugh
static float m_flTalkTime[MAXPLAYERS + 1];
static float m_flUndergroundTime[MAXPLAYERS + 1]; //Used to track how long we've been underground
static int m_iUpgradeLevel[MAXPLAYERS + 1]; //Bomb upgrade level

//Player robot properties
static WeaponRestrictionType m_nWeaponRestrictionFlags[MAXPLAYERS + 1];
static AttributeType m_nAttributeFlags[MAXPLAYERS + 1];
static DifficultyType m_nDifficulty[MAXPLAYERS + 1];
static ArrayList m_adtTags[MAXPLAYERS + 1];
static int m_nMission[MAXPLAYERS + 1];
static int m_iMissionTarget[MAXPLAYERS + 1];
static float m_flMaxVisionRange[MAXPLAYERS + 1];
static ArrayList m_adtTeleportWhereName[MAXPLAYERS + 1];
static float m_flAutoJumpMin[MAXPLAYERS + 1];
static float m_flAutoJumpMax[MAXPLAYERS + 1];

ConVar bwr3_robot_template_file;
ConVar bwr3_robot_giant_template_file;
ConVar bwr3_robot_gatebot_template_file;
ConVar bwr3_robot_gatebot_giant_template_file;
ConVar bwr3_robot_sentrybuster_template_file;
ConVar bwr3_robot_boss_template_file;
ConVar bwr3_bomb_upgrade_mode;
ConVar bwr3_cosmetic_mode;
ConVar bwr3_max_invaders;
ConVar bwr3_minmimum_players_for_giants;
ConVar bwr3_robot_giant_chance;
ConVar bwr3_robot_boss_chance;
ConVar bwr3_robot_gatebot_chance;

ConVar tf_deploying_bomb_delay_time;
ConVar tf_deploying_bomb_time;
ConVar tf_mvm_bot_allow_flag_carrier_to_fight;
ConVar tf_mvm_bot_flag_carrier_interval_to_1st_upgrade;
ConVar tf_mvm_bot_flag_carrier_interval_to_2nd_upgrade;
ConVar tf_mvm_bot_flag_carrier_interval_to_3rd_upgrade;
ConVar tf_mvm_bot_flag_carrier_health_regen;
ConVar tf_bot_always_full_reload;
ConVar tf_bot_fire_weapon_allowed;
ConVar tf_mvm_miniboss_scale;
ConVar tf_mvm_engineer_teleporter_uber_duration;
ConVar tf_bot_suicide_bomb_range;
ConVar tf_bot_engineer_building_health_multiplier;
ConVar phys_pushscale;

#if defined MOD_EXT_CBASENPC
ConVar tf_bot_suicide_bomb_friendly_fire;
#endif

methodmap MvMRobotPlayer
{
	public MvMRobotPlayer(int index)
	{
		return view_as<MvMRobotPlayer>(index);
	}
	
	property int index
	{
		public get()	{ return view_as<int>(this); }
	}
	
	property eRobotTemplateType RobotVariantType
	{
		public get()	{ return m_nRobotVariantType[this.index]; }
		public set(eRobotTemplateType value)	{ m_nRobotVariantType[this.index] = value; }
	}
	
	property float NextSpawnTime
	{
		public get()	{ return m_flNextRobotSpawnTime[this.index]; }
		public set(float value)	{ m_flNextRobotSpawnTime[this.index] = value; }
	}
	
	property int DeployBombState
	{
		public get()	{ return m_nDeployingBombState[this.index]; }
		public set(int value)
		{
			m_nDeployingBombState[this.index] = value;
			
			//Also update this on the game's side
			if (IsClientInGame(this.index))
				SetDeployingBombState(this.index, value);
		}
	}
	
	property float DeployBombTime
	{
		public get()	{ return m_flDeployingBombTime[this.index]; }
		public set(float value)	{ m_flDeployingBombTime[this.index] = value; }
	}
	
	property int BombUpgradeLevel
	{
		public get()	{ return m_iUpgradeLevel[this.index]; }
		public set(int value)	{ m_iUpgradeLevel[this.index] = value; }
	}
	
	public void Reset()
	{
		this.NextSpawnTime = 0.0;
		this.DeployBombState = TF_BOMB_DEPLOYING_NONE;
		this.DeployBombTime = -1.0;
		m_flAutoJumpTime[this.index] = -1.0;
		m_flUpgradeTime[this.index] = -1.0;
		m_flBuffPulseTime[this.index] = -1.0;
		m_flChuckleTime[this.index] = -1.0;
		m_flTalkTime[this.index] = -1.0;
		m_flUndergroundTime[this.index] = -1.0;
		
		this.ClearWeaponRestrictions();
		this.ClearAllAttributes();
		this.SetDifficulty(CTFBot_UNDEFINED);
		this.ClearTags();
		this.SetMission(CTFBot_NO_MISSION);
		this.SetMissionTarget(-1);
		this.SetMaxVisionRange(-1.0);
		this.ClearTeleportWhere();
		this.SetAutoJump(0.0, 0.0);
	}
	
	public bool IsDeployingTheBomb()
	{
		return this.DeployBombState != TF_BOMB_DEPLOYING_NONE;
	}
	
	public void ClearWeaponRestrictions()
	{
		m_nWeaponRestrictionFlags[this.index] = CTFBot_ANY_WEAPON;
	}
	
	public void SetWeaponRestriction(WeaponRestrictionType restrictionFlags)
	{
		m_nWeaponRestrictionFlags[this.index] |= restrictionFlags;
	}
	
	public bool HasWeaponRestriction(WeaponRestrictionType restrictionFlags)
	{
		return m_nWeaponRestrictionFlags[this.index] & restrictionFlags ? true : false;
	}
	
	public void SetAttribute(AttributeType attributeFlag)
	{
		m_nAttributeFlags[this.index] |= attributeFlag;
	}
	
	public void ClearAttribute(AttributeType attributeFlag)
	{
		m_nAttributeFlags[this.index] &= ~attributeFlag;
	}
	
	public void ClearAllAttributes()
	{
		m_nAttributeFlags[this.index] = CTFBot_NONE;
	}
	
	public bool HasAttribute(AttributeType attributeFlag)
	{
		return m_nAttributeFlags[this.index] & attributeFlag ? true : false;
	}
	
	public DifficultyType GetDifficulty()
	{
		return m_nDifficulty[this.index];
	}
	
	public void SetDifficulty(DifficultyType difficulty)
	{
		m_nDifficulty[this.index] = difficulty;
		
		SetEntProp(this.index, Prop_Send, "m_nBotSkill", difficulty);
	}
	
	public bool IsDifficulty(DifficultyType skill)
	{
		return skill == m_nDifficulty[this.index];
	}
	
	public void ClearTags()
	{
		if (m_adtTags[this.index])
			m_adtTags[this.index].Clear();
	}
	
	public void AddTag(const char[] tag)
	{
		//TODO: should we do an existing tag check here?
		m_adtTags[this.index].PushString(tag);
	}
	
	public void RemoveTag(const char[] tag)
	{
		int index = m_adtTags[this.index].FindString(tag);
		
		if (index != -1)
			m_adtTags[this.index].Erase(index);
	}
	
	public bool HasTag(const char[] tag)
	{
		return m_adtTags[this.index].FindString(tag) != -1;
	}
	
	public void SetMission(int mission)
	{
		m_nMission[this.index] = mission;
	}
	
	public int GetMission()
	{
		return m_nMission[this.index];
	}
	
	public bool HasMission(int mission)
	{
		return m_nMission[this.index] == mission ? true : false;
	}
	
	public bool IsOnAnyMission()
	{
		return m_nMission[this.index] == CTFBot_NO_MISSION ? false : true;
	}
	
	public void SetMissionTarget(int target)
	{
		m_iMissionTarget[this.index] = target;
	}
	
	public int GetMissionTarget()
	{
		return m_iMissionTarget[this.index];
	}
	
	public void SetMaxVisionRange(float range)
	{
		m_flMaxVisionRange[this.index] = range;
	}
	
	public float GetMaxVisionRange()
	{
		return m_flMaxVisionRange[this.index];
	}
	
	public void SetTeleportWhere(const ArrayList teleportWhereName)
	{
		m_adtTeleportWhereName[this.index] = teleportWhereName;
	}
	
	public ArrayList GetTeleportWhere()
	{
		return m_adtTeleportWhereName[this.index];
	}
	
	public void ClearTeleportWhere()
	{
		if (m_adtTeleportWhereName[this.index])
			m_adtTeleportWhereName[this.index].Clear();
	}
	
	public void SetAutoJump(float min, float max)
	{
		m_flAutoJumpMin[this.index] = min;
		m_flAutoJumpMax[this.index] = max;
	}
	
	//CountdownTimer
	public void AutoJumpTimer_Start(float duration)
	{
		m_flAutoJumpTime[this.index] = GetEngineTime() + duration;
	}
	
	public bool AutoJumpTimer_HasStarted()
	{
		return m_flAutoJumpTime[this.index] > 0.0;
	}
	
	public bool AutoJumpTimer_IsElapsed()
	{
		return GetEngineTime() > m_flAutoJumpTime[this.index];
	}
	
	public void DeployBombTimer_Start(float duration)
	{
		m_flDeployingBombTime[this.index] = GetEngineTime() + duration;
	}
	
	public bool DeployBombTimer_IsElapsed()
	{
		return GetEngineTime() > m_flDeployingBombTime[this.index];
	}
	
	public void BombUpgradeTimer_Start(float duration)
	{
		m_flUpgradeTime[this.index] = GetEngineTime() + duration;
	}
	
	public bool BombUpgradeTimer_IsElapsed()
	{
		return GetEngineTime() > m_flUpgradeTime[this.index];
	}
	
	public float BombUpgradeTimer_GetRemainingTime()
	{
		return m_flUpgradeTime[this.index] - GetEngineTime();
	}
	
	public void BuffPulseTimer_Start(float duration)
	{
		m_flBuffPulseTime[this.index] = GetEngineTime() + duration;
	}
	
	public bool BuffPulseTimer_IsElapsed()
	{
		return GetEngineTime() > m_flBuffPulseTime[this.index];
	}
	
	public void ChuckleTimer_Start(float duration)
	{
		m_flChuckleTime[this.index] = GetEngineTime() + duration;
	}
	
	public bool ChuckleTimer_IsElapsed()
	{
		return GetEngineTime() > m_flChuckleTime[this.index];
	}
	
	public void TalkTimer_Start(float duration)
	{
		m_flTalkTime[this.index] = GetEngineTime() + duration;
	}
	
	public bool TalkTimer_IsElapsed()
	{
		return GetEngineTime() > m_flTalkTime[this.index];
	}
	
	//IntervalTimer
	public void UndergroundTimer_Start()
	{
		m_flUndergroundTime[this.index] = GetEngineTime();
	}
	
	public void UndergroundTimer_Invalidate()
	{
		m_flUndergroundTime[this.index] = -1.0;
	}
	
	public bool UndergroundTimer_HasStarted()
	{
		return m_flUndergroundTime[this.index] > 0.0;
	}
	
	public bool UndergroundTimer_IsGreaterThen(float duration)
	{
		return GetEngineTime() - m_flUndergroundTime[this.index] > duration;
	}
}

#include "bwree/util.sp"
#include "bwree/offsets.sp"
#include "bwree/sdkcalls.sp"
#include "bwree/events.sp"
#include "bwree/dhooks.sp"
#include "bwree/robot_templates.sp"

public Plugin myinfo =
{
	name = PLUGIN_NAME,
	author = "Officer Spy",
	description = "Perhaps this is the true BWR experience?",
	version = "1.0.1",
	url = ""
};
	
public void OnPluginStart()
{
#if defined MOD_EXT_CBASENPC
	PrintToServer("%s compiled for use with extension CBaseNPC", PLUGIN_NAME);
#endif
	
	LoadTranslations("bwree.phrases");
	
	bwr3_robot_template_file = CreateConVar("sm_bwr3_robot_template_file", "robot_standard.cfg", _, FCVAR_NOTIFY);
	bwr3_robot_giant_template_file = CreateConVar("sm_bwr3_robot_giant_template_file", "robot_giant.cfg", _, FCVAR_NOTIFY);
	bwr3_robot_gatebot_template_file = CreateConVar("sm_bwr3_robot_gatebot_template_file", "robot_gatebot.cfg", _, FCVAR_NOTIFY);
	bwr3_robot_gatebot_giant_template_file = CreateConVar("sm_bwr3_robot_gatebot_giant_template_file", "robot_gatebot_giant.cfg", _, FCVAR_NOTIFY);
	bwr3_robot_sentrybuster_template_file = CreateConVar("sm_bwr3_robot_sentrybuster_template_file", "robot_sentrybuster.cfg", _, FCVAR_NOTIFY);
	bwr3_robot_boss_template_file = CreateConVar("sm_bwr3_robot_boss_template_file", "robot_boss.cfg", _, FCVAR_NOTIFY);
	bwr3_bomb_upgrade_mode = CreateConVar("sm_bwr3_bomb_upgrade_mode", "1", _, FCVAR_NOTIFY);
	bwr3_cosmetic_mode = CreateConVar("sm_bwr3_cosmetic_mode", "0", _, FCVAR_NOTIFY);
	bwr3_max_invaders = CreateConVar("sm_bwr3_max_invaders", "4", _, FCVAR_NOTIFY);
	bwr3_minmimum_players_for_giants = CreateConVar("sm_bwr3_minmimum_players_for_giants", "6", _, FCVAR_NOTIFY);
	bwr3_robot_giant_chance = CreateConVar("sm_bwr3_robot_giant_chance", "10", _, FCVAR_NOTIFY);
	bwr3_robot_boss_chance = CreateConVar("sm_bwr3_robot_boss_chance", "1", _, FCVAR_NOTIFY);
	bwr3_robot_gatebot_chance = CreateConVar("sm_bwr3_robot_gatebot_chance", "25", _, FCVAR_NOTIFY);
	
	HookConVarChange(bwr3_robot_template_file, ConVarChanged_RobotTemplateFile);
	HookConVarChange(bwr3_robot_giant_template_file, ConVarChanged_RobotTemplateFile);
	HookConVarChange(bwr3_robot_gatebot_template_file, ConVarChanged_RobotTemplateFile);
	HookConVarChange(bwr3_robot_gatebot_giant_template_file, ConVarChanged_RobotTemplateFile);
	HookConVarChange(bwr3_robot_sentrybuster_template_file, ConVarChanged_RobotTemplateFile);
	HookConVarChange(bwr3_robot_boss_template_file, ConVarChanged_RobotTemplateFile);
	
	RegConsoleCmd("sm_bwr", Command_JoinBlue, "Join the blue team and become a robot!");
	RegConsoleCmd("sm_joinblu", Command_JoinBlue, "Join the blue team and become a robot!");
	
	RegAdminCmd("sm_bwr3_berobot", Command_PlayAsRobotType, ADMFLAG_GENERIC);
	RegAdminCmd("sm_bwr3_debug_sentrybuster", Command_DebugSentryBuster, ADMFLAG_GENERIC);
	
#if defined TESTING_ONLY	
	RegConsoleCmd("sm_johnblue", Command_JoinBlue, "Join the blue team and become a robot!");
#endif
	
	AddCommandListener(CommandListener_Voicemenu, "voicemenu");
	AddCommandListener(CommandListener_TournamentPlayerReadystate, "tournament_player_readystate");
	
	AddNormalSoundHook(SoundHook_General);
	
	HookEntityOutput("item_teamflag", "OnPickUp", CaptureFlag_OnPickup);
	
	InitGameEventHooks();
	
	GameData hGamedata = new GameData("tf2.bwree");
	
	if (hGamedata)
	{
		InitOffsets(hGamedata);
		
		bool bFailed = false;
		
		if (!InitSDKCalls(hGamedata))
			bFailed = true;
		
		if (!InitDHooks(hGamedata))
			bFailed = true;
		
		delete hGamedata;
		
		if (bFailed)
			SetFailState("Gamedata failed!");
	}
	else
	{
		SetFailState("Failed to load gamedata file tf2.bwree.txt");
	}
	
	//Initialize the tags list
	for (int i = 1; i <= MaxClients; i++)
		m_adtTags[i] = new ArrayList(BOT_TAG_EACH_MAX_LENGTH);
	
	if (g_bLateLoad)
	{
		//Rehook all players
		for (int i = 1; i <= MaxClients; i++)
			if (IsClientInGame(i))
				OnClientPutInServer(i);
		
		//Find the remembered entities
		g_iObjectiveResource = FindEntityByClassname(MaxClients + 1, "tf_objective_resource");
		g_iPopulationManager = FindEntityByClassname(MaxClients + 1, "info_populator");
	}
}

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	g_bLateLoad = late;
	
	return APLRes_Success;
}

public void OnMapStart()
{
	g_bCanBotsAttackInSpawn = false;
	
	ResetRobotSpawnerData();
}

public void OnClientPutInServer(int client)
{
	g_iForcedButtonInput[client] = 0;
	
	m_bIsRobot[client] = false;
	m_bBypassBotCheck[client] = false;
	m_flCaptureZoneLastTouch[client] = 0.0;
	m_bIsWaitingForReload[client] = false;
	
	MvMRobotPlayer(client).Reset();
	
	SDKHook(client, SDKHook_OnTakeDamage, Actor_OnTakeDamage);
	
	DHooks_OnClientPutInServer(client);
}

public void OnClientDisconnect(int client)
{
	if (IsPlayingAsRobot(client))
	{
		//When we leave, the sound might still persist, so stop it
		StopIdleSound(client);
	}
}

public void OnConfigsExecuted()
{
	tf_deploying_bomb_delay_time = FindConVar("tf_deploying_bomb_delay_time");
	tf_deploying_bomb_time = FindConVar("tf_deploying_bomb_time");
	tf_mvm_bot_allow_flag_carrier_to_fight = FindConVar("tf_mvm_bot_allow_flag_carrier_to_fight");
	tf_mvm_bot_flag_carrier_interval_to_1st_upgrade = FindConVar("tf_mvm_bot_flag_carrier_interval_to_1st_upgrade");
	tf_mvm_bot_flag_carrier_interval_to_2nd_upgrade = FindConVar("tf_mvm_bot_flag_carrier_interval_to_2nd_upgrade");
	tf_mvm_bot_flag_carrier_interval_to_3rd_upgrade = FindConVar("tf_mvm_bot_flag_carrier_interval_to_3rd_upgrade");
	tf_mvm_bot_flag_carrier_health_regen = FindConVar("tf_mvm_bot_flag_carrier_health_regen");
	tf_bot_always_full_reload = FindConVar("tf_bot_always_full_reload");
	tf_bot_fire_weapon_allowed = FindConVar("tf_bot_fire_weapon_allowed");
	tf_mvm_miniboss_scale = FindConVar("tf_mvm_miniboss_scale");
	tf_mvm_engineer_teleporter_uber_duration = FindConVar("tf_mvm_engineer_teleporter_uber_duration");
	tf_bot_suicide_bomb_range = FindConVar("tf_bot_suicide_bomb_range");
	tf_bot_engineer_building_health_multiplier = FindConVar("tf_bot_engineer_building_health_multiplier");
	phys_pushscale = FindConVar("phys_pushscale");
	
#if defined MOD_EXT_CBASENPC
	tf_bot_suicide_bomb_friendly_fire = FindConVar("tf_bot_suicide_bomb_friendly_fire");
#endif
	
	// HookConVarChange(tf_mvm_miniboss_scale, ConVarChanged_MinibossScale);
	
	BaseServer_AddTag("bwree");
}

public void OnEntityCreated(int entity, const char[] classname)
{
	//TODO: verify this always works
	//TODO: maybe change this to entity reference instead?
	if (StrEqual(classname, "tf_objective_resource"))
		g_iObjectiveResource = entity;
	else if (StrEqual(classname, "info_populator"))
		g_iPopulationManager = entity;
	else if (StrEqual(classname, "item_teamflag"))
		SDKHook(entity, SDKHook_Touch, CaptureFlag_Touch);
	else if (StrEqual(classname, "headless_hatman"))
		SDKHook(entity, SDKHook_OnTakeDamage, Actor_OnTakeDamage);
	else if (StrEqual(classname, "merasmus"))
		SDKHook(entity, SDKHook_OnTakeDamage, Actor_OnTakeDamage);
	else if (StrEqual(classname, "eyeball_boss"))
		SDKHook(entity, SDKHook_OnTakeDamage, Actor_OnTakeDamage);
	else if (StrEqual(classname, "base_boss"))
		SDKHook(entity, SDKHook_OnTakeDamage, Actor_OnTakeDamage);
	else if (StrEqual(classname, "tank_boss"))
		SDKHook(entity, SDKHook_OnTakeDamage, Actor_OnTakeDamage);
	else if (StrEqual(classname, "obj_attachment_sapper"))
		SDKHook(entity, SDKHook_SpawnPost, ObjectSapper_SpawnPost);
	
	DHooks_OnEntityCreated(entity, classname);
}

public Action OnPlayerRunCmd(int client, int &buttons, int &impulse, float vel[3], float angles[3], int &weapon, int &subtype, int &cmdnum, int &tickcount, int &seed, int mouse[2])
{
	if (!IsPlayingAsRobot(client))
		return Plugin_Continue;
	
	OSTFPlayer player = OSTFPlayer(client);
	
	if (GameRules_GetRoundState() == RoundState_BetweenRounds)
	{
		//No attacking allowed during pre-round
		if (buttons & IN_ATTACK)
		{
			buttons &= ~IN_ATTACK;
		}
		
		if (buttons & IN_ATTACK2)
		{
			buttons &= ~IN_ATTACK2;
		}
		
		//Keep us protected though
		player.AddCond(TFCond_Ubercharged, 0.5);
		player.AddCond(TFCond_UberchargedHidden, 0.5);
		player.AddCond(TFCond_UberchargeFading, 0.5);
		// player.AddCond(TFCond_ImmuneToPushback, 1.0);
		
		return Plugin_Continue;
	}
	
	MvMRobotPlayer roboPlayer = MvMRobotPlayer(client);
	
	if (!IsPlayerAlive(client))
	{
		//Spawn the player in the next respawn wave
		if (roboPlayer.NextSpawnTime <= GetGameTime() && !IsBotSpawningPaused(g_iPopulationManager))
		{
			roboPlayer.NextSpawnTime = GetGameTime() + 1.0;
			SelectSpawnRobotTypeForPlayer(client);
		}
		
		return Plugin_Continue;
	}
	
	//Force any input if specified elsewhere
	if (g_iForcedButtonInput[client] != 0)
	{
		buttons |= g_iForcedButtonInput[client];
		g_iForcedButtonInput[client] = 0;
	}
	
	if (roboPlayer.HasMission(CTFBot_MISSION_DESTROY_SENTRIES))
	{
		if (buttons & IN_ATTACK)
		{
			//Sentry buster never attacks
			buttons &= ~IN_ATTACK;
		}
		
		if (roboPlayer.TalkTimer_IsElapsed())
		{
			roboPlayer.TalkTimer_Start(4.0);
			EmitGameSoundToAll("MVM.SentryBusterIntro", client);
		}
	}
	
	bool bHasTheFlag = player.HasTheFlag();
	
	if (roboPlayer.IsDeployingTheBomb())
	{
		//NOTE: not needed if using TF_COND_FREEZE_INPUT in SetPlayerToMove
		/* if (buttons & IN_ATTACK)
		{
			//Deny attacking while deploying
			buttons &= ~IN_ATTACK;
		} */
		
		//Deploy bomb logic
		if (!MvMDeployBomb_Update(client))
			MvMDeployBomb_OnEnd(client);
	}
	else if (bHasTheFlag)
	{
		if (buttons & IN_ATTACK && !tf_mvm_bot_allow_flag_carrier_to_fight.BoolValue)
		{
			//Not allowed to attack if carrying the bomb
			buttons &= ~IN_ATTACK;
		}
	}
	
	// player.GiveAmmo(100, TF_AMMO_METAL, true);
	player.SetSpyCloakMeter(100.0);
	
	if (ShouldAutoJump(client))
	{
		//We are forced to jump on intervals
		buttons |= IN_JUMP;
	}
	
	if (roboPlayer.HasAttribute(CTFBot_ALWAYS_FIRE_WEAPON))
	{
		//We are always attacking no matter what
		buttons |= IN_ATTACK;
	}
	
	int myWeapon = player.GetActiveTFWeapon();
	
	if (buttons & IN_ATTACK)
	{
		if (roboPlayer.HasAttribute(CTFBot_SUPPRESS_FIRE) || roboPlayer.HasAttribute(CTFBot_IGNORE_ENEMIES) || !tf_bot_fire_weapon_allowed.BoolValue)
		{
			//Never allowed to attack
			buttons &= ~IN_ATTACK;
		}
		else if (myWeapon != -1)
		{
			if (roboPlayer.HasAttribute(CTFBot_HOLD_FIRE_UNTIL_FULL_RELOAD) || tf_bot_always_full_reload.BoolValue)
			{
				if (Clip1(myWeapon) <= 0)
					m_bIsWaitingForReload[client] = true;
				
				if (m_bIsWaitingForReload[client])
				{
					if (Clip1(myWeapon) < GetMaxClip1(myWeapon))
					{
						//Our clip has not refiled yet, so don't attack right now
						buttons &= ~IN_ATTACK;
					}
					else
					{
						//We have fully reloaded
						m_bIsWaitingForReload[client] = false;
					}
				}
			}
		}
	}
	
	if (buttons & IN_ATTACK2)
	{
		if (player.IsClass(TFClass_DemoMan) && player.IsShieldEquipped())
		{
			float vecForward[3]; player.EyeVectors(vecForward);
			bool bShouldCharge = true;
			
			if (roboPlayer.HasAttribute(CTFBot_AIR_CHARGE_ONLY))
			{
				float myAbsVelocity[3]; myAbsVelocity = GetAbsVelocity(client);
				
				if (GetGroundEntity(client) != -1 || myAbsVelocity[2] > 0)
					bShouldCharge = false;
				
				if (!bShouldCharge)
				{
					//Only allowed to charge in the air
					buttons &= ~IN_ATTACK2;
				}
			}
		}
		
		if (myWeapon != -1 && TF2Util_GetWeaponID(myWeapon) == TF_WEAPON_MEDIGUN)
		{
			bool bUseUber = true; //TODO: change this
			
			//These human players don't have a variable their patient, but this will be treated as theirs
			//TODO: realistically, i think we should make our own variable and allow the player to switch their patient by healing someone else
			int myPatient = GetEntPropEnt(myWeapon, Prop_Send, "m_hHealingTarget");
			
			if (myPatient != -1 && BaseEntity_IsPlayer(myPatient))
			{
				//Use uber if the patient is getting low
				/* const float healthyRatio = 0.5;
				bUseUber = GetClientHealth(myPatient) / TF2Util_GetEntityMaxHealth(myPatient) < healthyRatio; */
				
				//The patient is already ubered
				if (TF2_IsPlayerInCondition(myPatient, TFCond_Ubercharged) || TF2_IsPlayerInCondition(myPatient, TFCond_MegaHeal))
					bUseUber = false;
				
				//TODO: uber health threshold?
				
				//We're about to die
				/* if (player.GetHealth() < 25)
					bUseUber = true; */
				
				//Special MvM case, we're both in spawn
				if (TF2_IsPlayerInCondition(myPatient, TFCond_UberchargedHidden) && player.InCond(TFCond_UberchargedHidden))
					bUseUber = false;
				
				if (!bUseUber)
				{
					//Not allowed to uber
					buttons &= ~IN_ATTACK2;
				}
			}
		}
	}
	
	float myAbsOrigin[3]; GetClientAbsOrigin(client, myAbsOrigin);
	
	//Heehee I'm a spy!
	if (player.IsClass(TFClass_Spy) && roboPlayer.ChuckleTimer_IsElapsed())
	{
		if (myWeapon != -1 && IsMeleeWeapon(myWeapon))
		{
			int threat = GetEnemyPlayerNearestToMe(client);
			
			if (threat != -1 && Player_IsVisibleInFOVNow(client, threat))
			{
				float threatAbsOrigin[3]; GetClientAbsOrigin(threat, threatAbsOrigin);
				float toPlayerThreat[3]; SubtractVectors(threatAbsOrigin, myAbsOrigin, toPlayerThreat);
				
				float threatRange = NormalizeVector(toPlayerThreat, toPlayerThreat);
				
				const float circleStrafeRange = 250.0;
				
				if (threatRange < circleStrafeRange)
				{
					float playerThreadForward[3]; BasePlayer_EyeVectors(threat, playerThreadForward);
					
					//In mvm, it's always this value regardless of difficulty
					const float behindTolerance = 0.7071;
					
					bool isBehindVictim = GetVectorDotProduct(playerThreadForward, toPlayerThreat) > behindTolerance;
					
					if (isBehindVictim)
					{
						if (roboPlayer.ChuckleTimer_IsElapsed())
						{
							roboPlayer.ChuckleTimer_Start(1.0);
							EmitGameSoundToAll("Spy.MVM_Chuckle", client);
						}
					}
				}
			}
		}
	}
	
#if defined MOD_EXT_CBASENPC
	CTFNavArea myArea = view_as<CTFNavArea>(CBaseCombatCharacter(client).GetLastKnownArea());
	
	if (myArea)
	{
		if (myArea.HasAttributeTF(BLUE_SPAWN_ROOM))
		{
			if (!g_bCanBotsAttackInSpawn)
			{
				if (buttons & IN_ATTACK) //TODO: allow attacking if the player robot has always fire
				{
					if (myWeapon != -1 && !CanWeaponFireInRobotSpawn(myWeapon, IN_ATTACK))
					{
						buttons &= ~IN_ATTACK;
					}
				}
				
				if (buttons & IN_ATTACK2)
				{
					if (myWeapon != -1 && !CanWeaponFireInRobotSpawn(myWeapon, IN_ATTACK2))
					{
						buttons &= ~IN_ATTACK2;
					}
				}
			}
			
			//Protected while in spawn
			player.AddCond(TFCond_Ubercharged, 0.5);
			player.AddCond(TFCond_UberchargedHidden, 0.5);
			player.AddCond(TFCond_UberchargeFading, 0.5);
			player.AddCond(TFCond_ImmuneToPushback, 1.0);
			
			if (bHasTheFlag && roboPlayer.BombUpgradeLevel != DONT_UPGRADE)
			{
				//Do not upgrade the bomb while in spawn
				roboPlayer.BombUpgradeTimer_Start(tf_mvm_bot_flag_carrier_interval_to_1st_upgrade.FloatValue);
				
				OSTFObjectiveResource rsrc = OSTFObjectiveResource(g_iObjectiveResource);
				rsrc.SetBaseMvMBombUpgradeTime(GetGameTime());
				rsrc.SetNextMvMBombUpgradeTime(GetGameTime() + roboPlayer.BombUpgradeTimer_GetRemainingTime());
			}
		}
		else
		{
			//When TFBots perform their taunts, they change to nextbot action CTFBotTaunt
			//Treat player taunting as if they decided to change their own "actions"
			if (bHasTheFlag && roboPlayer.BombUpgradeLevel != DONT_UPGRADE && !player.IsTaunting())
			{
				//Buff me and all of my teammates near me after first upgrading the bomb
				if (roboPlayer.BombUpgradeLevel > 0 && roboPlayer.BuffPulseTimer_IsElapsed())
				{
					roboPlayer.BuffPulseTimer_Start(1.0);
					
					const float buffRadius = 450.0;
					
					for (int i = 1; i <= MaxClients; i++)
						if (IsClientInGame(i) && GetClientTeam(i) == GetClientTeam(client) && IsPlayerAlive(i) && Player_IsRangeLessThan(client, i, buffRadius))
							TF2_AddCondition(i, TFCond_DefenseBuffNoCritBlock, 1.2);
				}
				
				if (roboPlayer.BombUpgradeTimer_IsElapsed())
				{
					switch (bwr3_bomb_upgrade_mode.IntValue)
					{
						case BOMB_UPGRADE_MANUAL:
						{
							//Advise the player the ycan upgrade the bomb now
							PrintCenterText(client, "%t", "RobotPlayer_Notify_Upgrade_Bomb");
						}
						case BOMB_UPGRADE_AUTO:
						{
							//Upgrade the bomb over time
							if (UpgradeBomb(client))
								SendTauntCommand(client);
						}
					}
				}
			}
		}
		
		//Check if we fell underground and teleport us to a reasonable area if we did
		if (myArea.GetZVector(myAbsOrigin) - myAbsOrigin[2] > 100.0)
		{
			if (!roboPlayer.UndergroundTimer_HasStarted())
			{
				roboPlayer.UndergroundTimer_Start();
			}
			else if (roboPlayer.UndergroundTimer_IsGreaterThen(3.0))
			{
				LogMVMRobotUnderground(client);
				
				float center[3]; myArea.GetCenter(center);
				SetAbsOrigin(client, center);
			}
		}
		else
		{
			roboPlayer.UndergroundTimer_Invalidate();
		}
	}
#else
	//TODO: alternative
#endif
	
	return Plugin_Continue;
}

public void TF2_OnConditionAdded(int client, TFCond condition)
{
	if (!IsPlayingAsRobot(client))
		return;
	
	if (condition == TFCond_Taunting && bwr3_bomb_upgrade_mode.IntValue == BOMB_UPGRADE_MANUAL && MvMRobotPlayer(client).BombUpgradeTimer_IsElapsed() && TF2_HasTheFlag(client))
	{
		//Here we taunt to upgrade the bomb in this mode
		UpgradeBomb(client);
	}
	else if (condition == TFCond_MVMBotRadiowave && m_bBypassBotCheck[client] == false)
	{
		//This condition does nothing on human players, so we apply the stun ourselves
		m_bBypassBotCheck[client] = true;
		AddCond_MVMBotStunRadiowave(client, TF2Util_GetPlayerConditionDuration(client, TFCond_MVMBotRadiowave));
		m_bBypassBotCheck[client] = false;
		
		//Particle is handled client-side and only shows up on bots, so just do this
		EmitParticleEffect("bot_radio_waves", "head", client, PATTACH_POINT_FOLLOW);
	}
}

public void TF2_OnConditionRemoved(int client, TFCond condition)
{
	if (!IsPlayingAsRobot(client))
		return;
	
	if (condition == TFCond_MVMBotRadiowave)
	{
		//Stop the particle we may have added earlier in TF2_OnConditionAdded
		StopParticleEffects(client);
	}
}

public void ConVarChanged_RobotTemplateFile(ConVar convar, const char[] oldValue, const char[] newValue)
{
	char filePath[PLATFORM_MAX_PATH]; BuildPath(Path_SM, filePath, sizeof(filePath), "%s/%s", ROBOT_TEMPLATE_CONFIG_DIRECTORY, newValue);
	
	if (!FileExists(filePath))
	{
		LogError("New template file (%s) does not exist!", filePath);
		
		BuildPath(Path_SM, filePath, sizeof(filePath), "%s/%s", ROBOT_TEMPLATE_CONFIG_DIRECTORY, oldValue);
		
		if (FileExists(filePath))
			convar.SetString(oldValue);
		else
			LogError("Old template file (%s) does not exist!", filePath);
	}
}

/* public void ConVarChanged_MinibossScale(ConVar convar, const char[] oldValue, const char[] newValue)
{
	for (int i = 1; i <= MAXPLAYERS; i++)
		if (IsClientInGame(i) && TF2_IsMiniBoss(i))
			BaseAnimating_SetModelScale(i, convar.FloatValue, 1.0);
} */

public Action Command_JoinBlue(int client, int args)
{
	if (IsPlayingAsRobot(client))
	{
		PrintToChat(client, "%s %t", PLUGIN_PREFIX, "Player_Already_Robot");
		return Plugin_Handled;
	}
	
	if (GetRobotPlayerCount() >= bwr3_max_invaders.IntValue)
	{
		PrintToChat(client, "%s %t", PLUGIN_PREFIX, "Robot_Player_Limit_Reached");
		return Plugin_Handled;
	}
	
	// TF2_RefundPlayer(client);
	MvMRobotPlayer(client).NextSpawnTime = GetGameTime() + 5.0;
	ChangePlayerToTeamInvaders(client);
	
	return Plugin_Handled;
}

public Action Command_PlayAsRobotType(int client, int args)
{
	if (!IsPlayingAsRobot(client))
		return Plugin_Handled;
	
	char arg1[2]; GetCmdArg(1, arg1, sizeof(arg1));
	
	TurnPlayerIntoRandomRobot(client, view_as<eRobotTemplateType>(StringToInt(arg1)));
	
	return Plugin_Handled;
}

public Action Command_DebugSentryBuster(int client, int args)
{
	int nDmgLimit = 0;
	int nKillLimit = 0;
	GetSentryBusterDamageAndKillThreshold(g_iPopulationManager, nDmgLimit, nKillLimit);
	
	PrintToChat(client, "SENTRY BUSTER\nDamage limit = %d\nKill limit = %d", nDmgLimit, nKillLimit);
	
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
				
				PrintToChat(client, "%N's sentry damage = %d, sentry kills = %d", sentryOwner, nDmgDone, nKillsMade);
			}
		}
	}
	
	return Plugin_Handled;
}

public Action CommandListener_Voicemenu(int client, const char[] command, int argc)
{
	if (argc >= 2 && IsPlayingAsRobot(client) && !ShouldTacticalMonitorSuspendAction())
	{
		MvMSuicideBomber roboPlayer = MvMSuicideBomber(client);
		
		//Use voice command to trigger detonation sequence
		if (roboPlayer.HasMission(CTFBot_MISSION_DESTROY_SENTRIES))
		{
			char arg1[2]; GetCmdArg(1, arg1, sizeof(arg1));
			char arg2[2]; GetCmdArg(2, arg2, sizeof(arg2));
			
			if (StringToInt(arg1) == 0 && StringToInt(arg2) == 0)
			{
				roboPlayer.StartDetonate(true);
				return Plugin_Handled;
			}
		}
	}
	
	return Plugin_Continue;
}

public Action CommandListener_TournamentPlayerReadystate(int client, const char[] command, int argc)
{
	//Robot players can't start the game
	if (IsPlayingAsRobot(client))
		return Plugin_Handled;
	
	return Plugin_Continue;
}

public Action SoundHook_General(int clients[MAXPLAYERS], int &numClients, char sample[PLATFORM_MAX_PATH], int &entity, int &channel, float &volume, int &level, int &pitch, int &flags, char soundEntry[PLATFORM_MAX_PATH], int &seed)
{
	if (entity > MaxClients)
	{
		if (StrEqual(sample, ")mvm/mvm_tele_deliver.wav"))
		{
			char classname[PLATFORM_MAX_PATH]; GetEntityClassname(entity, classname, sizeof(classname));
			
			if (StrEqual(classname, "obj_teleporter"))
			{
				//If an actual engineer bot's teleporter emits this sound, then this will be the teleporter we use
				g_iRefLastTeleporter = EntIndexToEntRef(entity);
				g_flLastTeleportTime = GetGameTime();
			}
		}
	}
	
	return Plugin_Continue;
}

public void CaptureFlag_OnPickup(const char[] output, int caller, int activator, float delay)
{
	int owner = BaseEntity_GetOwnerEntity(activator);
	
	if (!IsPlayingAsRobot(owner))
		return;
	
	//Set this here so we don't prematurely upgrade
	//It will be properly set on the next frame
	MvMRobotPlayer(owner).BombUpgradeLevel = DONT_UPGRADE;
	
	//CCaptureFlag::PickUp updates the bomb hud and fires this output on the same frame
	//Since the output is fired first, we need to delay by a frame here to update the bomb hud ourselves
	RequestFrame(Frame_CaptureFlagOnPickup, owner);
}

public void Frame_CaptureFlagOnPickup(any data)
{
	//Update the bomb HUD
	if (TF2_IsMiniBoss(data))
	{
		MvMRobotPlayer(data).BombUpgradeLevel = DONT_UPGRADE;
		
		if (IsValidEntity(g_iObjectiveResource))
		{
			OSTFObjectiveResource rsrc = OSTFObjectiveResource(g_iObjectiveResource);
			rsrc.SetFlagCarrierUpgradeLevel(4);
			rsrc.SetBaseMvMBombUpgradeTime(-1.0);
			rsrc.SetNextMvMBombUpgradeTime(-1.0);
		}
	}
	else
	{
		MvMRobotPlayer roboPlayer = MvMRobotPlayer(data);
		roboPlayer.BombUpgradeLevel = 0;
		roboPlayer.BombUpgradeTimer_Start(tf_mvm_bot_flag_carrier_interval_to_1st_upgrade.FloatValue);
		
		if (IsValidEntity(g_iObjectiveResource))
		{
			OSTFObjectiveResource rsrc = OSTFObjectiveResource(g_iObjectiveResource);
			rsrc.SetBaseMvMBombUpgradeTime(GetGameTime());
			rsrc.SetNextMvMBombUpgradeTime(GetGameTime() + roboPlayer.BombUpgradeTimer_GetRemainingTime());
		}
	}
}

public Action ObjectTeleporter_GetMaxHealth(int entity, int &maxhealth)
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
		SDKUnhook(entity, SDKHook_GetMaxHealth, ObjectTeleporter_GetMaxHealth);
	}
	
	return Plugin_Continue;
}

public Action Actor_OnTakeDamage(int victim, int &attacker, int &inflictor, float &damage, int &damagetype, int &weapon, float damageForce[3], float damagePosition[3], int damagecustom)
{
	if (BaseEntity_IsPlayer(attacker))
	{
		if (IsPlayingAsRobot(attacker) && MvMRobotPlayer(attacker).HasAttribute(CTFBot_ALWAYS_CRIT))
		{
			/* In MvM, CTFProjectile_Arrow::StrikeTarget removes DMG_CRITICAL from damagetype before it has the entity take damage from it
			if the attacker is not a TFBot or the TFBot doesn't have bot attribute ALWAYS_CRIT
			For our robot players, allow their arrows to deal critical damage if their robot allows it */
			if (inflictor > 0 && IsProjectileArrow(inflictor))
			{
				damagetype |= DMG_CRITICAL;
				
				return Plugin_Changed;
			}
		}
	}
	
	return Plugin_Continue;
}

public Action CaptureFlag_Touch(int entity, int other)
{
	if (!BaseEntity_IsPlayer(other))
		return Plugin_Continue;
	
	if (!IsPlayingAsRobot(other))
		return Plugin_Continue;
	
	if (!IsPlayerAlive(other))
		return Plugin_Continue;
	
	//Mission robots can't pick up the flag
	if (MvMRobotPlayer(other).IsOnAnyMission())
		return Plugin_Handled;
	
	//This robot is currently ignoring the flag
	if (MvMRobotPlayer(other).HasAttribute(CTFBot_IGNORE_FLAG))
		return Plugin_Handled;
	
	return Plugin_Continue;
}

public void ObjectSapper_SpawnPost(int entity)
{
	int builder = TF2_GetBuilder(entity);
	
	if (builder != -1 && IsPlayingAsRobot(builder))
	{
		//CObjectSapper::Spawn does not set the flag for human players to allow repeated sapper placement in MvM
		//We will add the flag here so in CTFWeaponBuilder::PrimaryAttack, the server will not switch us away from the sapper
		int nFlags = TF2_GetObjectFlags(entity);
		TF2_SetObjectFlags(entity, nFlags | OF_ALLOW_REPEAT_PLACEMENT);
	}
}

public void PlayerRobot_TouchPost(int entity, int other)
{
	if (other > MaxClients)
	{
		OSTFPlayer player = OSTFPlayer(entity);
		
		if (!ShouldTacticalMonitorSuspendAction())
		{
			char classname[PLATFORM_MAX_PATH]; GetEntityClassname(other, classname, sizeof(classname));
			
			if (StrEqual(classname, "func_capturezone"))
			{
				//Start deploying the bomb
				if (!MvMRobotPlayer(entity).IsDeployingTheBomb() && player.HasTheFlag())
					MvMDeployBomb_OnStart(entity);
				
				//Actively increment to indicate we are currently touching the capture zone
				m_flCaptureZoneLastTouch[entity] = GetGameTime() + 0.1;
			}
		}
		
		//Destroy objects we come in contact with
		if (player.IsMiniBoss())
		{
			OSBaseObject cboOther = OSBaseObject(other);
			
			if (cboOther.IsBaseObject())
			{
				if (cboOther.GetType() != TFObject_Sentry || cboOther.IsMiniBuilding())
				{
					int damage = MaxInt(cboOther.GetMaxHealth(), cboOther.GetHealth());
					
					float toVictim[3]; SubtractVectors(WorldSpaceCenter(other), WorldSpaceCenter(entity), toVictim);
					
#if defined MOD_EXT_CBASENPC
					CTakeDamageInfo info = GetGlobalDamageInfo();
					info.Init(entity, entity, _, _, _, float(damage), DMG_BLAST, TF_DMG_CUSTOM_NONE);
					CalculateMeleeDamageForce(info, toVictim, WorldSpaceCenter(entity), 1.0);
					CBaseEntity(other).TakeDamage(info);
#else
					float vecDamageForce[3]; CalculateMeleeDamageForce(float(damage), toVictim, 1.0, vecDamageForce);
					SDKHooks_TakeDamage(other, entity, entity, float(damage), DMG_BLAST, _, vecDamageForce, WorldSpaceCenter(entity));
#endif
				}
			}
		}
		/* char classname[PLATFORM_MAX_PATH]; GetEntityClassname(other, classname, sizeof(classname));
		PrintToChatAll("TOUCHING ENTITY %d %s", other, classname); */
	}
}

public Action PlayerRobot_OnTakeDamage(int victim, int &attacker, int &inflictor, float &damage, int &damagetype, int &weapon, float damageForce[3], float damagePosition[3], int damagecustom)
{
	MvMSuicideBomber roboVictim = MvMSuicideBomber(victim);
	OSTFPlayer cbpVictim = OSTFPlayer(victim);
	
	if (roboVictim.HasMission(CTFBot_MISSION_DESTROY_SENTRIES))
	{
		//We're about to die, detonate!
		if (cbpVictim.m_iHealth - damage <= 0)
		{
			cbpVictim.m_iHealth = 1;
			
			roboVictim.StartDetonate(false, true);
			
			return Plugin_Handled;
		}
	}
	
	if (BaseEntity_IsPlayer(attacker))
	{
		//As giants, we should take less damage from sentry buster bots
		if (damagecustom == TF_DMG_CUSTOM_NONE && damagetype & DMG_BLAST && damage > SENTRYBUSTER_DMG_TO_MINIBOSS && BasePlayer_IsBot(attacker) && IsSentryBusterRobot(attacker) && cbpVictim.IsMiniBoss())
		{
			damage = SENTRYBUSTER_DMG_TO_MINIBOSS;
			
			return Plugin_Changed;
		}
	}
	
	return Plugin_Continue;
}

bool IsPlayingAsRobot(int client)
{
	return m_bIsRobot[client];
}

int GetRobotPlayerCount()
{
	int count = 0;
	
	for (int i = 1; i <= MaxClients; i++)
		if (IsClientInGame(i) && IsPlayingAsRobot(i))
			count++;
	
	return count;
}

void ChangePlayerToTeamInvaders(int client)
{
	//CTFPlayer::ChangeTeam calls CTFGameRules::GetTeamAssignmentOverride which always returns TF_TEAM_PVE_DEFENDERS for human players
	//Bypass CBasePlayer::IsBot check
	SetPlayerAsBot(client, true);
	TF2_ChangeClientTeam(client, TFTeam_Blue);
	SetPlayerAsBot(client, false);
	
	//TODO: verify the player is actually on blue team after change
	SetRobotPlayer(client, true);
}

void SetRobotPlayer(int client, bool enabled)
{
	if (enabled)
	{
		m_bIsRobot[client] = true;
		
		SDKHook(client, SDKHook_TouchPost, PlayerRobot_TouchPost);
		SDKHook(client, SDKHook_OnTakeDamage, PlayerRobot_OnTakeDamage);
	}
	else
	{
		m_bIsRobot[client] = false;
		
		MvMRobotPlayer(client).Reset();
		
		SDKUnhook(client, SDKHook_TouchPost, PlayerRobot_TouchPost);
		SDKUnhook(client, SDKHook_OnTakeDamage, PlayerRobot_OnTakeDamage);
		
		ResetPlayerProperties(client);
	}
}

void ResetPlayerProperties(int client)
{
	TF2_SetCustomModel(client, "");
	TF2Attrib_RemoveAll(client);
}

bool MvMDeployBomb_OnStart(int client)
{
	MvMRobotPlayer roboPlayer = MvMRobotPlayer(client);
	roboPlayer.DeployBombState = TF_BOMB_DEPLOYING_DELAY;
	roboPlayer.DeployBombTimer_Start(tf_deploying_bomb_delay_time.FloatValue);
	
	GetClientAbsOrigin(client, m_vecDeployPos[client]);
	SetPlayerToMove(client, false);
	SetAbsVelocity(client, {0.0, 0.0, 0.0});
	
	if (TF2_IsMiniBoss(client))
	{
		//NOTE: normally a check is done to see if the attribute exists in the item schema
		//but this shouldn't be necessary unless the attribute gets removed or changed
		TF2Attrib_SetByName(client, "airblast vertical vulnerability multiplier", 0.0);
	}
	
	return true;
}

/* This part mainly controls the bomb deploying states
Return false if we should stop deploying the bomb
Return true to continue deploying the bomb */
bool MvMDeployBomb_Update(int client)
{
	if (ShouldTacticalMonitorSuspendAction())
		return false;
	
	MvMRobotPlayer roboPlayer = MvMRobotPlayer(client);
	
	int pAreaTrigger = -1;
	
	if (roboPlayer.DeployBombState != TF_BOMB_DEPLOYING_COMPLETE)
	{
		pAreaTrigger = GetClosestCaptureZone(client);
		
		if (pAreaTrigger == -1)
			return false;
		
		const float movedRange = 20.0;
		
		if (Player_IsRangeGreaterThanVec(client, m_vecDeployPos[client], movedRange) && !IsTouchingCaptureZone(client))
		{
			//TODO: whoever pushed us away, fire an event for them
			
			//We were pushed away from the hatch hole
			return false;
		}
		
		//Slam face towards hatch		
		float to[3]; SubtractVectors(WorldSpaceCenter(pAreaTrigger), WorldSpaceCenter(client), to);
		NormalizeVector(to, to);
		
		float desiredAngles[3];
		GetVectorAngles(to, desiredAngles);
		
		VS_SnapEyeAngles(client, desiredAngles);
	}
	
	switch (roboPlayer.DeployBombState)
	{
		case TF_BOMB_DEPLOYING_DELAY:
		{
			if (roboPlayer.DeployBombTimer_IsElapsed())
			{
				PlaySpecificSequence(client, "primary_deploybomb");
				roboPlayer.DeployBombTimer_Start(tf_deploying_bomb_time.FloatValue);
				roboPlayer.DeployBombState = TF_BOMB_DEPLOYING_ANIMATING;
				
				EmitGameSoundToAll(TF2_IsMiniBoss(client) ? "MVM.DeployBombGiant" : "MVM.DeployBombSmall", client);
				
				PlayThrottledAlert(255, "Announcer.MVM_Bomb_Alert_Deploying", 5.0);
			}
		}
		case TF_BOMB_DEPLOYING_ANIMATING:
		{
			if (roboPlayer.DeployBombTimer_IsElapsed())
			{
				if (pAreaTrigger != -1)
					CaptureZoneCapture(pAreaTrigger, client);
				
				roboPlayer.DeployBombTimer_Start(2.0);
				TeamplayRoundBasedRules_BroadcastSound(255, "Announcer.MVM_Robots_Planted");
				roboPlayer.DeployBombState = TF_BOMB_DEPLOYING_COMPLETE;
				OSTFPlayer(client).m_takedamage = DAMAGE_NO;
				AddEffects(client, EF_NODRAW);
				TF2_RemoveAllWeapons(client); //NOTE: the game uses CBaseCombatCharacter::RemoveAllWeapons
			}
		}
		case TF_BOMB_DEPLOYING_COMPLETE:
		{
			if (roboPlayer.DeployBombTimer_IsElapsed())
			{
				roboPlayer.DeployBombState = TF_BOMB_DEPLOYING_NONE;
				OSTFPlayer(client).m_takedamage = DAMAGE_YES;
				
#if defined MOD_EXT_CBASENPC
				CTakeDamageInfo info = GetGlobalDamageInfo();
				info.Init(client, client, _, _, _, 99999.9, DMG_CRUSH);
				CBaseEntity(client).TakeDamage(info);
#else
				SDKHooks_TakeDamage(client, client, client, 99999.9, DMG_CRUSH);
#endif
				
				return false;
			}
		}
	}
	
	return true;
}

void MvMDeployBomb_OnEnd(int client)
{
	MvMRobotPlayer roboPlayer = MvMRobotPlayer(client);
	
	if (roboPlayer.DeployBombState == TF_BOMB_DEPLOYING_ANIMATING)
	{
		//Reset deploy animation
		DoAnimationEvent(client, PLAYERANIMEVENT_SPAWN);
	}
	
	if (TF2_IsMiniBoss(client))
	{
		//Giants can be pushed again
		TF2Attrib_RemoveByName(client, "airblast vertical vulnerability multiplier");
	}
	
	roboPlayer.DeployBombState = TF_BOMB_DEPLOYING_NONE;
	
	SetPlayerToMove(client, true);
}

void SetPlayerToMove(int client, bool enabled)
{
	if (enabled)
	{
		//Enable movement
		TF2_RemoveCondition(client, TFCond_FreezeInput);
	}
	else
	{
		//Disable movement
		TF2_AddCondition(client, TFCond_FreezeInput);
	}
}

bool UpgradeBomb(int client)
{
	MvMRobotPlayer roboPlayer = MvMRobotPlayer(client);
	
	const int maxLevel = 3;
	
	if (roboPlayer.BombUpgradeLevel < maxLevel)
	{
		roboPlayer.BombUpgradeLevel++;
		
		TeamplayRoundBasedRules_BroadcastSound(255, "MVM.Warning");
		
		switch (roboPlayer.BombUpgradeLevel)
		{
			case 1:
			{
				roboPlayer.BombUpgradeTimer_Start(tf_mvm_bot_flag_carrier_interval_to_2nd_upgrade.FloatValue);
				
				if (IsValidEntity(g_iObjectiveResource))
				{
					OSTFObjectiveResource rsrc = OSTFObjectiveResource(g_iObjectiveResource);
					rsrc.SetFlagCarrierUpgradeLevel(1);
					rsrc.SetBaseMvMBombUpgradeTime(GetGameTime());
					rsrc.SetNextMvMBombUpgradeTime(GetGameTime() + roboPlayer.BombUpgradeTimer_GetRemainingTime());
					MultiplayRules_HaveAllPlayersSpeakConceptIfAllowed(MP_CONCEPT_MVM_BOMB_CARRIER_UPGRADE1, view_as<int>(TFTeam_Red));
					EmitParticleEffect("mvm_levelup1", "head", client, PATTACH_POINT_FOLLOW);
					return true;
				}
			}
			case 2:
			{
				roboPlayer.BombUpgradeTimer_Start(tf_mvm_bot_flag_carrier_interval_to_3rd_upgrade.FloatValue);
				
				TF2Attrib_SetByName(client, "health regen", tf_mvm_bot_flag_carrier_health_regen.FloatValue);
				
				if (IsValidEntity(g_iObjectiveResource))
				{
					OSTFObjectiveResource rsrc = OSTFObjectiveResource(g_iObjectiveResource);
					rsrc.SetFlagCarrierUpgradeLevel(2);
					rsrc.SetBaseMvMBombUpgradeTime(GetGameTime());
					rsrc.SetNextMvMBombUpgradeTime(GetGameTime() + roboPlayer.BombUpgradeTimer_GetRemainingTime());
					MultiplayRules_HaveAllPlayersSpeakConceptIfAllowed(MP_CONCEPT_MVM_BOMB_CARRIER_UPGRADE2, view_as<int>(TFTeam_Red));
					EmitParticleEffect("mvm_levelup2", "head", client, PATTACH_POINT_FOLLOW);
					return true;
				}
			}
			case 3:
			{
				TF2_AddCondition(client, TFCond_Kritzkrieged);
				
				if (IsValidEntity(g_iObjectiveResource))
				{
					OSTFObjectiveResource rsrc = OSTFObjectiveResource(g_iObjectiveResource);
					rsrc.SetFlagCarrierUpgradeLevel(3);
					rsrc.SetBaseMvMBombUpgradeTime(-1.0);
					rsrc.SetNextMvMBombUpgradeTime(-1.0);
					MultiplayRules_HaveAllPlayersSpeakConceptIfAllowed(MP_CONCEPT_MVM_BOMB_CARRIER_UPGRADE3, view_as<int>(TFTeam_Red));
					EmitParticleEffect("mvm_levelup3", "head", client, PATTACH_POINT_FOLLOW);
					return true;
				}
			}
		}
	}
	
	return false;
}

bool CanWeaponFireInRobotSpawn(int weapon, int inputType)
{
	if (inputType == IN_ATTACK)
	{
		switch (TF2Util_GetWeaponID(weapon))
		{
			case TF_WEAPON_MEDIGUN, TF_WEAPON_BUFF_ITEM, TF_WEAPON_LUNCHBOX:
			{
				//These are allowed to primary fire
				return true;
			}
			default:	return false;
		}
	}
	else if (inputType == IN_ATTACK2)
	{
		switch (TF2Util_GetWeaponID(weapon))
		{
			case TF_WEAPON_MINIGUN, TF_WEAPON_SNIPERRIFLE, TF_WEAPON_MECHANICAL_ARM:
			{
				//These are not allowed to secondary fire
				return false;
			}
			default:	return true;
		}
	}
	
	return true;
}

bool ShouldTacticalMonitorSuspendAction()
{
	//For TFBots, CTFBotTacticalMonitor::Update suspends CTFBotMvMDeployBomb for CTFBotSeekAndDestroy when the round has been won and they are on the winning team
	//So for the robot players here, just stop the deploy process once their team has already won the round
	return GameRules_GetRoundState() == RoundState_TeamWin;
}

bool ShouldAutoJump(int client)
{
	MvMRobotPlayer roboPlayer = MvMRobotPlayer(client);
	
	if (!roboPlayer.HasAttribute(CTFBot_AUTO_JUMP))
		return false;
	
	if (!roboPlayer.AutoJumpTimer_HasStarted())
	{
		roboPlayer.AutoJumpTimer_Start(GetRandomFloat(m_flAutoJumpMin[client], m_flAutoJumpMax[client]));
		return true;
	}
	else if (roboPlayer.AutoJumpTimer_IsElapsed())
	{
		roboPlayer.AutoJumpTimer_Start(GetRandomFloat(m_flAutoJumpMin[client], m_flAutoJumpMax[client]));
		return true;
	}
	
	return false;
}

bool IsTouchingCaptureZone(int client)
{
	return m_flCaptureZoneLastTouch[client] > GetGameTime();
}