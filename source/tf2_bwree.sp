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

#define MOD_EXT_CBASENPC
// #define MOD_EXT_TF2_ECON_DYNAMIC

#if defined MOD_EXT_CBASENPC
#include <cbasenpc>
#include <cbasenpc/tf/nav>
#endif

#if defined MOD_EXT_TF2_ECON_DYNAMIC
#include <tf_econ_dynamic>
#endif

#pragma semicolon 1
#pragma newdecls required

// #define TESTING_ONLY
// #define DEBUG_DETOURS

#define PLUGIN_NAME	"Be With Robots: Expanded & Enhanced"
#define PLUGIN_PREFIX	"[BWR E&E]"

#define PLUGIN_CONFIG_DIRECTORY	"configs/bwree/"
#define MAP_CONFIG_DIRECTORY	"configs/bwree/map"
#define MAX_ROBOT_SPAWN_NAMES	3

#define BAD_TELE_PLACEMENT_SOUND	"buttons/button10.wav"
#define ALERT_FLAG_HELD_TOO_LONG_SOUND	"misc/doomsday_lift_warning.wav"

// #define MOD_BUY_A_ROBOT_3

#define TELEPORTER_METHOD_MANUAL
#define FIX_VOTE_CONTROLLER
#define PLAYER_UBER_LOGIC
#define OVERRIDE_PLAYER_RESPAWN_TIME
#define SPY_DISGUISE_VISION_OVERRIDE
// #define ALLOW_BUILDING_BETWEEN_ROUNDS
#define REMOVE_DEBUFF_COND_BY_ROBOTS
#define NO_AIRBLAST_BETWEEN_ROUNDS
// #define MANUAL_DEATH_WAVEBAR_EDIT
#define CORRECT_VISIBLE_RESPAWN_TIME
#define NO_UPGRADE_TELEPORTER

enum ePlayerPenalty
{
	PENALTY_NONE = 0,
	PENALTY_INVULNERABLE_DEPLOY = (1 << 0)
}

enum eRobotAction
{
	ROBOT_ACTION_UPGRADE_BOMB,
	ROBOT_ACTION_DEPLOY_BOMB,
	ROBOT_ACTION_SUICIDE_BOMBER
}

enum
{
	TAUNTING_MODE_NONE = 0,
	TAUNTING_MODE_BEHAVORIAL_ON_KILL,
	TAUNTING_MODE_BEHAVORIAL_BOMB,
	TAUNTING_MODE_BEHAVORIAL_ALL
}

enum
{
	BOMB_UPGRADE_DISABLED = 0,
	BOMB_UPGRADE_MANUAL,
	BOMB_UPGRADE_AUTO
}

enum
{
	COSMETIC_MODE_NONE = 0,
	COSMETIC_MODE_ALLOW_ALWAYS
}

enum
{
	DROPITEM_DISABLED = -1,
	DROPITEM_DISABLED_BOMB_LEVEL2,
	DROPITEM_ALLOWED
}

enum
{
	ROBOT_TEMPLATE_MODE_NONE = 0,
	ROBOT_TEMPLATE_MODE_WAVE_BOTS
}

enum
{
	CREDITS_DROP_NONE = 0,
	CREDITS_DROP_NORMAL,
	CREDITS_DROP_FORCE_DISTRIBUTE
}

enum
{
	COOLDOWN_MODE_DISABLED = 0,
	COOLDOWN_MODE_BASIC,
	COOLDOWN_MODE_DYNAMIC_PERFORMANCE
}

enum
{
	ENGINEER_TELEPORT_METHOD_NONE = 0,
	ENGINEER_TELEPORT_METHOD_MENU
}

enum
{
	SPY_TELEPORT_METHOD_NONE = 0,
	SPY_TELEPORT_METHOD_MENU
}

enum
{
	ROBOT_TELEPORTER_MODE_RECENTLY_USED,
	ROBOT_TELEPORTER_MODE_RANDOM,
	ROBOT_TELEPORTER_MODE_CLOSEST_BOMB,
	ROBOT_TELEPORTER_MODE_CLOSEST_BOMB_HATCH
}

enum struct esPlayerStats
{
	int iKills;
	int iDeaths;
	int iFlagCaptures;
	int iDamage;
	int iHealing;
	int iPointCaptures;
	int iPlayersUbered;
	int iSuccessiveRoundsPlayed;
	
	void Reset(bool bFullReset = false)
	{
		this.iKills = 0;
		this.iDeaths = 0;
		this.iFlagCaptures = 0;
		this.iDamage = 0;
		this.iHealing = 0;
		this.iPointCaptures = 0;
		this.iPlayersUbered = 0;
		
		if (bFullReset)
		{
			this.iSuccessiveRoundsPlayed = 0;
		}
	}
}

enum struct esButtonInput
{
	int iPress;
	float flPressTime;
	int iRelease;
	float flReleaseTime;
	
	void Reset()
	{
		this.iPress = 0;
		this.flPressTime = 0.0;
		this.iRelease = 0;
		this.flReleaseTime = 0.0;
	}
	
	void PressButtons(int buttons, float duration = -1.0)
	{
		this.iPress = buttons;
		this.flPressTime = duration > 0.0 ? GetGameTime() + duration : 0.0;
	}
	
	void ReleaseButtons(int buttons, float duration = -1.0)
	{
		this.iRelease = buttons;
		this.flReleaseTime = duration > 0.0 ? GetGameTime() + duration : 0.0;
	}
}

enum struct esCSProperties
{
	float flBaseDuration;
	float flFastCapWatchMaxSeconds;
	float flFastCapMaxMinutes;
	float flKDSecMultiplicand;
	float flSecPerKillNoDeath;
	float flSecPerCapFlag;
	int iDmgForSec;
	float flDmgForSecMult;
	int iHealingForSec;
	float flHealingForSecMult;
	float flCapturePointSec;
	float flInvulnDeploySec;
	float flSecPerSuccessiveRoundPlayed;
	
	void ResetToDefault()
	{
		this.flBaseDuration = 30.0;
		this.flFastCapWatchMaxSeconds = 120.0;
		this.flFastCapMaxMinutes = 10.0;
		this.flKDSecMultiplicand = 60.0;
		this.flSecPerKillNoDeath = 66.0;
		this.flSecPerCapFlag = 60.0;
		this.iDmgForSec = 750;
		this.flDmgForSecMult = 1.0;
		this.iHealingForSec = 600;
		this.flHealingForSecMult = 1.0;
		this.flCapturePointSec = 60.0;
		this.flInvulnDeploySec = 60.0;
		this.flSecPerSuccessiveRoundPlayed = 30.0;
	}
}

enum struct esPlayerPathing
{
	ArrayList adtPositions;
	int iTargetNodeIndex;
	float flNextRepathTime;
	
	void Reset()
	{
		delete this.adtPositions;
		this.iTargetNodeIndex = -1;
		this.flNextRepathTime = 0.0;
	}
	
	void Initialize()
	{
		this.adtPositions = new ArrayList(3);
	}
	
	bool IsDoingPathMovement()
	{
		//Only do this when our object is constructed, as it will only exist when we want to use it
		return this.adtPositions != null;
	}
	
	bool IsPathValid()
	{
		return this.iTargetNodeIndex >= 0 && this.iTargetNodeIndex < this.adtPositions.Length;
	}
	
	void GetCurrentGoalPosition(float buffer[3])
	{
		this.adtPositions.GetArray(this.iTargetNodeIndex, buffer);
	}
	
	void AppendPathPosition(const float vec[3])
	{
		this.adtPositions.PushArray(vec, sizeof(vec));
	}
	
	void OnPathRecalculated()
	{
		//Update the current node we are moving towards
		this.iTargetNodeIndex = this.adtPositions.Length - 2;
	}
	
	void TeleportToNearestNodeOutsideSpawn(int client)
	{
		for (int i = this.adtPositions.Length - 1; i > 0; i--)
		{
			float vToPos[3]; this.adtPositions.GetArray(i - 1, vToPos, sizeof(vToPos));
			
			CTFNavArea area = view_as<CTFNavArea>(TheNavMesh.GetNavArea(vToPos));
			
			if (area && !area.HasAttributeTF(BLUE_SPAWN_ROOM))
			{
				SetAbsOrigin(client, vToPos);
				break;
			}
		}
	}
	
	void DrawCurrentPath(int whom, float duration = 0.0)
	{
		static int iModelIndex = -1;
		
		if (iModelIndex == -1)
			iModelIndex = PrecacheModel("materials/sprites/laserbeam.vmt");
		
		if (duration <= 0.0)
			duration = MaxFloat(0.1, this.flNextRepathTime - GetGameTime());
		
		for (int i = this.adtPositions.Length - 1; i > 0; i--)
		{
			float vFromPos[3], vToPos[3];
			this.adtPositions.GetArray(i, vFromPos, sizeof(vFromPos));
			this.adtPositions.GetArray(i - 1, vToPos, sizeof(vToPos));
			TE_SetupBeamPoints(vFromPos, vToPos, iModelIndex, iModelIndex, 0, 30, duration, 5.0, 5.0, 5, 0.0, {0, 255, 0, 255}, 30);
			TE_SendToClient(whom);
		}
	}
}

#if defined SPY_DISGUISE_VISION_OVERRIDE
enum struct eDisguisedStruct
{
	int nDisguisedTeam; // The spy's disguised team
	int nDisguisedClass; // The spy's disguised class
}

eDisguisedStruct g_arrDisguised[MAXPLAYERS + 1];
#else
enum struct esSuspectedSpyInfo
{
	int iSuspectedSpy;
	float flSuspectedTime;
}
#endif

enum eRobotSpawnType
{
	ROBOT_SPAWN_NO_TYPE = -1,
	ROBOT_SPAWN_STANDARD,
	ROBOT_SPAWN_GIANT,
	ROBOT_SPAWN_SNIPER,
	ROBOT_SPAWN_SPY,
	ROBOT_SPAWN_TYPE_COUNT
}

bool g_bLateLoad;

int g_iMaxEdicts;
Handle g_hHudText;
float g_flTimeRoundStarted;
int g_iRoundCapturablePoints;
bool g_bCanBotsAttackInSpawn;

esCSProperties g_arrCooldownSystem;

// GLOBAL ENTITIES
int g_iObjectiveResource = -1;
int g_iPopulationManager = -1;

// MAP SETTINGS
float g_flMapGiantScale;
char g_sMapSpawnNames[ROBOT_SPAWN_TYPE_COUNT][MAX_ROBOT_SPAWN_NAMES][PLATFORM_MAX_PATH];

//KEY is player steamID, VALUE is the time when his ban expires
static StringMap m_adtBWRCooldown;

#if SOURCEMOD_V_MINOR >= 13
//KEY is player entity index, VALUE is ArrayList object
static IntMap m_adtPlayersUbered;
#endif

esPlayerStats g_arrRobotPlayerStats[MAXPLAYERS + 1];
esButtonInput g_arrExtraButtons[MAXPLAYERS + 1];
bool g_bRobotSpawning[MAXPLAYERS + 1];
bool g_bReleasingUber[MAXPLAYERS + 1];
float g_flTimeJoinedBlue[MAXPLAYERS + 1]; //Active round only, not used between waves
ePlayerPenalty g_iPenaltyFlags[MAXPLAYERS + 1];
int g_nForcedTauntCam[MAXPLAYERS + 1];
float g_flLastTimeFlagInSpawn[MAXPLAYERS + 1];
bool g_bChangeRobotPicked[MAXPLAYERS + 1];
float g_flChangeRobotCooldown[MAXPLAYERS + 1];
bool g_bSpawningAsBossRobot[MAXPLAYERS + 1];
esPlayerPathing g_arrPlayerPath[MAXPLAYERS + 1];
bool g_bAllowRespawn[MAXPLAYERS + 1];

static bool m_bIsRobot[MAXPLAYERS + 1];
static bool m_bBypassBotCheck[MAXPLAYERS + 1];
static char m_sPlayerName[MAXPLAYERS + 1][MAX_NAME_LENGTH];
static float m_flBlockMovementTime[MAXPLAYERS + 1];
static float m_flNextActionTime[MAXPLAYERS + 1];
static bool m_bIsWaitingForReload[MAXPLAYERS + 1];
// static eRobotTemplateType m_nRobotVariantType[MAXPLAYERS + 1];
static eRobotTemplateType m_nNextRobotTemplateType[MAXPLAYERS + 1];
static int m_nNextRobotTemplateID[MAXPLAYERS + 1];
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
static KeyValues m_kvEventChangeAttributes[MAXPLAYERS + 1];

#if !defined SPY_DISGUISE_VISION_OVERRIDE
static ArrayList m_adtKnownSpy[MAXPLAYERS + 1];
static ArrayList m_adtSuspectedSpyInfo[MAXPLAYERS + 1];
#endif

ConVar bwr3_robot_spawn_time_min;
ConVar bwr3_robot_spawn_time_max;
ConVar bwr3_robot_taunt_mode;
ConVar bwr3_bomb_upgrade_mode;
ConVar bwr3_cosmetic_mode;
ConVar bwr3_max_invaders;
ConVar bwr3_min_players_for_giants;
ConVar bwr3_allow_movement;
ConVar bwr3_allow_readystate;
ConVar bwr3_allow_drop_item;
ConVar bwr3_allow_buyback;
ConVar bwr3_player_robot_template_mode;
ConVar bwr3_player_change_name;
ConVar bwr3_edit_wavebar;
ConVar bwr3_drop_credits;
ConVar bwr3_invader_cooldown_mode;
ConVar bwr3_flag_max_hold_time;
ConVar bwr3_flag_idle_deal_method;
ConVar bwr3_robot_template_file;
ConVar bwr3_robot_giant_template_file;
ConVar bwr3_robot_gatebot_template_file;
ConVar bwr3_robot_gatebot_giant_template_file;
ConVar bwr3_robot_sentrybuster_template_file;
ConVar bwr3_robot_boss_template_file;
ConVar bwr3_robot_giant_chance;
ConVar bwr3_robot_boss_chance;
ConVar bwr3_robot_gatebot_chance;
ConVar bwr3_robot_menu_allowed;
ConVar bwr3_robot_menu_cooldown;
ConVar bwr3_robot_menu_giant_cooldown;
ConVar bwr3_engineer_teleport_method;
ConVar bwr3_spy_teleport_method;
ConVar bwr3_robot_teleporter_mode;
ConVar bwr3_robot_custom_viewmodels;

ConVar tf_mvm_defenders_team_size;
ConVar nb_update_frequency;
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
ConVar tf_bot_engineer_mvm_sentry_hint_bomb_backward_range;
ConVar tf_bot_engineer_mvm_sentry_hint_bomb_forward_range;
ConVar tf_bot_engineer_mvm_hint_min_distance_from_bomb;

#if !defined SPY_DISGUISE_VISION_OVERRIDE
ConVar tf_bot_suspect_spy_touch_interval;
#endif

#if defined MOD_EXT_CBASENPC
ConVar tf_bot_suicide_bomb_friendly_fire;
#endif

//I wish i could put these somewhere else
#define MAX_BOT_TAG_CHECKS	8 //Maximum amount of tags we will look for
#define BOT_TAGS_BUFFER_MAX_LENGTH	PLATFORM_MAX_PATH //How long the whole string list of tags can be
#define BOT_TAG_EACH_MAX_LENGTH	16 //How long each named tag can be

#define ROBOT_TEMPLATE_ID_INVALID	-1

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
	
	/* property eRobotTemplateType RobotVariantType
	{
		public get()	{ return m_nRobotVariantType[this.index]; }
		public set(eRobotTemplateType value)	{ m_nRobotVariantType[this.index] = value; }
	} */
	
	property eRobotTemplateType MyNextRobotTemplateType
	{
		public get()	{ return m_nNextRobotTemplateType[this.index]; }
		public set(eRobotTemplateType value)	{ m_nNextRobotTemplateType[this.index] = value; }
	}
	
	property int MyNextRobotTemplateID
	{
		public get()	{ return m_nNextRobotTemplateID[this.index]; }
		public set(int value)	{ m_nNextRobotTemplateID[this.index] = value; }
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
		this.MyNextRobotTemplateType = ROBOT_STANDARD;
		this.MyNextRobotTemplateID = ROBOT_TEMPLATE_ID_INVALID;
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
		delete m_adtTags[this.index];
		this.SetMission(CTFBot_NO_MISSION);
		this.SetMissionTarget(-1);
		this.SetMaxVisionRange(-1.0);
		delete m_adtTeleportWhereName[this.index];
		this.SetAutoJump(0.0, 0.0);
		this.ClearEventChangeAttributes();
		
#if !defined SPY_DISGUISE_VISION_OVERRIDE
		delete m_adtKnownSpy[this.index];
		delete m_adtSuspectedSpyInfo[this.index];
#endif
	}
	
	public void SetMyNextRobot(eRobotTemplateType type, int templateID)
	{
		this.MyNextRobotTemplateType = type;
		this.MyNextRobotTemplateID = templateID;
		
		char robotName[MAX_NAME_LENGTH]; GetRobotTemplateName(type, templateID, robotName, sizeof(robotName));
		
		PrintToChat(this.index, "%s %t", PLUGIN_PREFIX, "Next_Robot_Spawn", robotName);
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
		if (m_flMaxVisionRange[this.index] > 0.0)
			return m_flMaxVisionRange[this.index];
		
		//Custom value is -1, use default range
		return 6000.0;
	}
	
	public void SetTeleportWhere(const ArrayList teleportWhereName)
	{
		//Close the old version cause cloning will just make another one
		CloseHandle(m_adtTeleportWhereName[this.index]);
		m_adtTeleportWhereName[this.index] = teleportWhereName.Clone();
	}
	
	public ArrayList GetTeleportWhere()
	{
		return m_adtTeleportWhereName[this.index];
	}
	
	public void ClearTeleportWhere()
	{
		m_adtTeleportWhereName[this.index].Clear();
	}
	
	public void SetAutoJump(float min, float max)
	{
		m_flAutoJumpMin[this.index] = min;
		m_flAutoJumpMax[this.index] = max;
	}
	
	public void InitializeEventChangeAttributes()
	{
		if (m_kvEventChangeAttributes[this.index] == null)
			m_kvEventChangeAttributes[this.index] = new KeyValues("EventChangeAttributes");
	}
	
	public void SetEventChangeAttributes(KeyValues data)
	{
		/* NOTE: okay, so I tried CloneHandle and it did copy the correct tree
		but then manipulating the original handle also affects this one
		and put us in the wrong spot of the tree when we go to reference it
		So instead, we will export the current tree as a string then import it from that string
		Since these objects won't be tied to the same one in memory, we basically created our own tree here */
		char kvTree[2048]; data.ExportToString(kvTree, sizeof(kvTree));
		
		m_kvEventChangeAttributes[this.index].ImportFromString(kvTree);
	}
	
	public void ClearEventChangeAttributes()
	{
		if (m_kvEventChangeAttributes[this.index])
		{
			CloseHandle(m_kvEventChangeAttributes[this.index]);
			m_kvEventChangeAttributes[this.index] = null;
		}
	}
	
	public void OnEventChangeAttributes(const char[] eventName)
	{
		if (m_kvEventChangeAttributes[this.index] == null)
			return;
		
		//NOTE: we don't really need to clone here, but I don't want this looking worse than it already does
		KeyValues kv = view_as<KeyValues>(CloneHandle(m_kvEventChangeAttributes[this.index]));
		
		kv.GotoFirstSubKey(false);
		
		char sectionName[32];
		
		do
		{
			kv.GetSectionName(sectionName, sizeof(sectionName));
			
#if defined TESTING_ONLY
			PrintToChatAll("[OnEventChangeAttributes] Player %d: %s", this.index, sectionName);
#endif
			
			//Look for the specified event's name
			if (StrEqual(sectionName, eventName, false))
			{
				//Remember our current health before removing the attributes since ModifyMaxHealth uses an attribute to set the player's health
				// int nHealth = GetClientHealth(this.index);
				int nMaxHealth = TF2Util_GetEntityMaxHealth(this.index);
				
				//Remove these as we're about to override them
				TF2Attrib_RemoveAll(this.index);
				
				//Set the health back to what it was before
				ModifyMaxHealth(this.index, nMaxHealth, false, false);
				// SetEntityHealth(this.index, nHealth);
				
				ReadEventChangeAttributesForPlayer(this, kv);
				break;
			}
		} while (kv.GotoNextKey(false));
		
		delete kv;
	}
	
#if !defined SPY_DISGUISE_VISION_OVERRIDE
	public bool IsKnownSpy(int player)
	{
		return m_adtKnownSpy[this.index].FindValue(player) != -1;
	}
	
	public bool IsSuspectedSpy(int player, esSuspectedSpyInfo spyInfo, int &foundIndex = 0)
	{
		for (int i = 0; i < m_adtSuspectedSpyInfo[this.index].Length; i++)
		{
			m_adtSuspectedSpyInfo[this.index].GetArray(i, spyInfo);
			
			if (spyInfo.iSuspectedSpy == player)
			{
				foundIndex = i;
				return true;
			}
		}
		
		foundIndex = -1;
		return false;
	}
	
	public void SuspectSpy(int player)
	{
		esSuspectedSpyInfo spyInfo;
		int index;
		
		if (!this.IsSuspectedSpy(player, spyInfo, index))
		{
			//Well now we do start suspecting this spy
			spyInfo.iSuspectedSpy = player;
			spyInfo.flSuspectedTime = 0.0;
		}
		
		//TODO: this could be done better
		spyInfo.flSuspectedTime += 0.1;
		
		if (RoundFloat(spyInfo.flSuspectedTime) >= tf_bot_suspect_spy_touch_interval.IntValue)
			this.RealizeSpy(player);
		
		//Store into our suspicious memory
		if (index != -1)
			m_adtSuspectedSpyInfo[this.index].SetArray(index, spyInfo);
		else
			m_adtSuspectedSpyInfo[this.index].PushArray(spyInfo);
	}
	
	public void RealizeSpy(int player)
	{
		if (this.IsKnownSpy(player))
			return;
		
		m_adtKnownSpy[this.index].Push(player);
		
		BaseMultiplayerPlayer_SpeakConceptIfAllowed(this.index, MP_CONCEPT_PLAYER_CLOAKEDSPY);
		
		//TODO: should others realize there is a spy here?
	}
	
	public void ForgetSpy(int player)
	{
		this.StopSuspectingSpy(player);
		
		int index = m_adtKnownSpy[this.index].FindValue(player);
		
		if (index != -1)
			m_adtKnownSpy[this.index].Erase(index);
	}
	
	public void StopSuspectingSpy(int player)
	{
		for (int i = 0; i < m_adtSuspectedSpyInfo[this.index].Length; i++)
		{
			esSuspectedSpyInfo spyInfo;
			m_adtSuspectedSpyInfo[this.index].GetArray(i, spyInfo);
			
			if (spyInfo.iSuspectedSpy == player)
			{
				m_adtSuspectedSpyInfo[this.index].Erase(i);
				break;
			}
		}
	}
	
	public void ClearTrackedSpyData()
	{
		m_adtKnownSpy[this.index].Clear();
		m_adtSuspectedSpyInfo[this.index].Clear();
	}
#endif
	
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
#include "bwree/menu.sp"

#if defined SPY_DISGUISE_VISION_OVERRIDE
int g_iModelIndexRobots[sizeof(g_sBotModels)];
int g_iModelIndexHumans[sizeof(g_strModelHumans)];
#endif

static char m_sCurrentWaveIconNames[MVM_CLASS_TYPES_PER_WAVE_MAX * 2][PLATFORM_MAX_PATH];

public Plugin myinfo =
{
	name = PLUGIN_NAME,
	author = "Officer Spy",
	description = "Perhaps this is the true BWR experience?",
	version = "1.4.0",
	url = "https://github.com/OfficerSpy/TF2-Be-With-Robots-Expanded-Enhanced"
};

public void OnPluginStart()
{
#if defined MOD_EXT_CBASENPC
	PrintToServer("%s compiled for use with extension CBaseNPC", PLUGIN_NAME);
#endif
	
	LoadTranslations("bwree.phrases");
	
	bwr3_robot_spawn_time_min = CreateConVar("sm_bwr3_robot_spawn_time_min", "12", _, FCVAR_NOTIFY);
	bwr3_robot_spawn_time_max = CreateConVar("sm_bwr3_robot_spawn_time_max", "12", _, FCVAR_NOTIFY);
	bwr3_robot_taunt_mode = CreateConVar("sm_bwr3_robot_taunt_mode", "0", _, FCVAR_NOTIFY);
	bwr3_bomb_upgrade_mode = CreateConVar("sm_bwr3_bomb_upgrade_mode", "2", _, FCVAR_NOTIFY);
	bwr3_cosmetic_mode = CreateConVar("sm_bwr3_cosmetic_mode", "0", _, FCVAR_NOTIFY);
	bwr3_max_invaders = CreateConVar("sm_bwr3_max_invaders", "4", _, FCVAR_NOTIFY);
	bwr3_min_players_for_giants = CreateConVar("sm_bwr3_min_players_for_giants", "6", _, FCVAR_NOTIFY);
	bwr3_allow_movement = CreateConVar("sm_bwr3_allow_movement", "1", _, FCVAR_NOTIFY);
	bwr3_allow_readystate = CreateConVar("sm_bwr3_allow_readystate", "0", _, FCVAR_NOTIFY);
	bwr3_allow_drop_item = CreateConVar("sm_bwr3_allow_drop_item", "0", _, FCVAR_NOTIFY);
	bwr3_allow_buyback = CreateConVar("sm_bwr3_allow_buyback", "0", _, FCVAR_NOTIFY);
	bwr3_player_robot_template_mode = CreateConVar("sm_bwr3_player_robot_template_mode", "0", _, FCVAR_NOTIFY);
	bwr3_player_change_name = CreateConVar("sm_bwr3_player_change_name", "0", _, FCVAR_NOTIFY);
	bwr3_edit_wavebar = CreateConVar("sm_bwr3_edit_wavebar", "1", _, FCVAR_NOTIFY);
	bwr3_drop_credits = CreateConVar("sm_bwr3_drop_credits", "1", _, FCVAR_NOTIFY);
	bwr3_invader_cooldown_mode = CreateConVar("sm_bwr3_invader_cooldown_mode", "2", _, FCVAR_NOTIFY);
	bwr3_flag_max_hold_time = CreateConVar("sm_bwr3_flag_max_hold_time", "30.0", _, FCVAR_NOTIFY);
	bwr3_flag_idle_deal_method = CreateConVar("sm_bwr3_flag_idle_deal_method", "1", _, FCVAR_NOTIFY);
	bwr3_robot_template_file = CreateConVar("sm_bwr3_robot_template_file", "robot_standard.cfg", _, FCVAR_NOTIFY);
	bwr3_robot_giant_template_file = CreateConVar("sm_bwr3_robot_giant_template_file", "robot_giant.cfg", _, FCVAR_NOTIFY);
	bwr3_robot_gatebot_template_file = CreateConVar("sm_bwr3_robot_gatebot_template_file", "robot_gatebot.cfg", _, FCVAR_NOTIFY);
	bwr3_robot_gatebot_giant_template_file = CreateConVar("sm_bwr3_robot_gatebot_giant_template_file", "robot_gatebot_giant.cfg", _, FCVAR_NOTIFY);
	bwr3_robot_sentrybuster_template_file = CreateConVar("sm_bwr3_robot_sentrybuster_template_file", "robot_sentrybuster.cfg", _, FCVAR_NOTIFY);
	bwr3_robot_boss_template_file = CreateConVar("sm_bwr3_robot_boss_template_file", "robot_boss.cfg", _, FCVAR_NOTIFY);
	bwr3_robot_giant_chance = CreateConVar("sm_bwr3_robot_giant_chance", "10", _, FCVAR_NOTIFY);
	bwr3_robot_boss_chance = CreateConVar("sm_bwr3_robot_boss_chance", "1", _, FCVAR_NOTIFY);
	bwr3_robot_gatebot_chance = CreateConVar("sm_bwr3_robot_gatebot_chance", "25", _, FCVAR_NOTIFY);
	bwr3_robot_menu_allowed = CreateConVar("sm_bwr3_robot_menu_allowed", "0", _, FCVAR_NOTIFY);
	bwr3_robot_menu_cooldown = CreateConVar("sm_bwr3_robot_menu_cooldown", "30.0", _, FCVAR_NOTIFY);
	bwr3_robot_menu_giant_cooldown = CreateConVar("sm_bwr3_robot_menu_giant_cooldown", "60.0", _, FCVAR_NOTIFY);
	bwr3_engineer_teleport_method = CreateConVar("sm_bwr3_engineer_teleport_method", "0", _, FCVAR_NOTIFY);
	bwr3_spy_teleport_method = CreateConVar("sm_bwr3_spy_teleport_method", "0", _, FCVAR_NOTIFY);
	bwr3_robot_teleporter_mode = CreateConVar("sm_bwr3_robot_teleporter_mode", "1", _, FCVAR_NOTIFY);
	bwr3_robot_custom_viewmodels = CreateConVar("sm_bwr3_robot_custom_viewmodels", "0", _, FCVAR_NOTIFY);
	
	HookConVarChange(bwr3_allow_movement, ConVarChanged_AllowMovement);
	HookConVarChange(bwr3_player_change_name, ConVarChanged_PlayerChangeName);
	HookConVarChange(bwr3_robot_template_file, ConVarChanged_RobotTemplateFile);
	HookConVarChange(bwr3_robot_giant_template_file, ConVarChanged_RobotTemplateFile);
	HookConVarChange(bwr3_robot_gatebot_template_file, ConVarChanged_RobotTemplateFile);
	HookConVarChange(bwr3_robot_gatebot_giant_template_file, ConVarChanged_RobotTemplateFile);
	HookConVarChange(bwr3_robot_sentrybuster_template_file, ConVarChanged_RobotTemplateFile);
	HookConVarChange(bwr3_robot_boss_template_file, ConVarChanged_RobotTemplateFile);
	HookConVarChange(bwr3_robot_custom_viewmodels, ConVarChanged_RobotCustomViewmodels);
	
	RegConsoleCmd("sm_bwr", Command_JoinBlue, "Join the blue team and become a robot!");
	RegConsoleCmd("sm_joinblu", Command_JoinBlue, "Join the blue team and become a robot!");
	RegConsoleCmd("sm_joinblue", Command_JoinBlue, "Join the blue team and become a robot!");
	RegConsoleCmd("sm_joinred", Command_JoinRed);
	RegConsoleCmd("sm_viewnextrobot", Command_ViewNextRobotTemplate, "View the next robot you are going to spawn as.");
	RegConsoleCmd("sm_nextrobot", Command_ViewNextRobotTemplate, "View the next robot you are going to spawn as.");
	RegConsoleCmd("sm_robotmenu", Command_RobotTemplateMenu);
	RegConsoleCmd("sm_rm", Command_RobotTemplateMenu);
	RegConsoleCmd("sm_nextrobotmenu", Command_RobotTemplateMenu);
	RegConsoleCmd("sm_newrobot", Command_ReselectRobot);
	RegConsoleCmd("sm_nr", Command_ReselectRobot);
	RegConsoleCmd("sm_robotspawn", Command_SpawnNewRobotNow);
	RegConsoleCmd("sm_rs", Command_SpawnNewRobotNow);
	RegConsoleCmd("sm_newspawnpoint", Command_FindUseNewSpawnLocation);
	RegConsoleCmd("sm_newspawnarea", Command_FindUseNewSpawnLocation);
	RegConsoleCmd("sm_newspawn", Command_FindUseNewSpawnLocation);
	RegConsoleCmd("sm_ns", Command_FindUseNewSpawnLocation);
	
	RegAdminCmd("sm_bwr3_berobot", Command_PlayAsRobotType, ADMFLAG_GENERIC);
	RegAdminCmd("sm_bwr3_robots", Command_ListRobots, ADMFLAG_GENERIC);
	RegAdminCmd("sm_bwr3_setcooldown", Command_SetCooldownOnPlayer, ADMFLAG_GENERIC);
	RegAdminCmd("sm_bwr3_viewcooldowns", Command_ViewCooldownData, ADMFLAG_GENERIC);
	RegAdminCmd("sm_bwr3_debug_waveicons", Command_DebugWaveIcons, ADMFLAG_GENERIC);
	RegAdminCmd("sm_bwr3_debug_playerstats", Command_DebugPlayerStats, ADMFLAG_GENERIC);
	RegAdminCmd("sm_bwr3_debug_sentrybuster", Command_DebugSentryBuster, ADMFLAG_GENERIC);
	RegAdminCmd("sm_bwr3_debug_wavedata", Command_DebugWaveData, ADMFLAG_GENERIC);
	
#if defined TESTING_ONLY	
	RegConsoleCmd("sm_johnblue", Command_JoinBlue, "Join the blue team and become a robot!");
#endif
	
	AddCommandListener(CommandListener_Voicemenu, "voicemenu");
	AddCommandListener(CommandListener_TournamentPlayerReadystate, "tournament_player_readystate");
	AddCommandListener(CommandListener_Taunt, "taunt");
	AddCommandListener(CommandListener_Dropitem, "dropitem");
	AddCommandListener(CommandListener_Kill, "kill");
	AddCommandListener(CommandListener_Kill, "explode");
	AddCommandListener(CommandListener_Buyback, "td_buyback");
	AddCommandListener(CommandListener_Jointeam, "jointeam");
	AddCommandListener(CommandListener_Autoteam, "autoteam");
	
	AddNormalSoundHook(SoundHook_General);
	
	HookEntityOutput("item_teamflag", "OnPickUp", CaptureFlag_OnPickup);
	
	InitGameEventHooks();
	
	g_hHudText = CreateHudSynchronizer();
	m_adtBWRCooldown = new StringMap();
	
#if SOURCEMOD_V_MINOR >= 13
	m_adtPlayersUbered = new IntMap();
#endif
	
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
	
	if (g_bLateLoad)
	{
		int maxEntCount = GetMaxEntities();
		char classname[PLATFORM_MAX_PATH];
		
		for (int i = 1; i <= maxEntCount; i++)
		{
			if (i <= MaxClients)
			{
				//Rehook all players
				if (IsClientInGame(i))
					OnClientPutInServer(i);
				
				continue;
			}
			
			//Rehook all other entities
			if (IsValidEntity(i) && GetEntityClassname(i, classname, sizeof(classname)))
				OnEntityCreated(i, classname);
		}
	}
	
	FindGameConsoleVariables();
}

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	g_bLateLoad = late;
	
	return APLRes_Success;
}

public void OnMapStart()
{
	g_iMaxEdicts = GetMaxEntities();
	g_bCanBotsAttackInSpawn = false;
	m_adtBWRCooldown.Clear();
	// m_adtPlayersUbered.Clear();
	
	PrecacheSound(BAD_TELE_PLACEMENT_SOUND);
	PrecacheSound(ALERT_FLAG_HELD_TOO_LONG_SOUND);
	PrecacheSound(BOSS_ROBOT_SPAWN_SOUND);
	ResetRobotSpawnerData();
	
#if defined SPY_DISGUISE_VISION_OVERRIDE
	for (int x = 1; x < sizeof(g_iModelIndexHumans); x++) { g_iModelIndexHumans[x] = PrecacheModel(g_strModelHumans[x]); }
	for (int x = 1; x < sizeof(g_iModelIndexRobots); x++) { g_iModelIndexRobots[x] = PrecacheModel(g_sBotModels[x]); }
#endif
}

public void OnClientPutInServer(int client)
{
	g_arrRobotPlayerStats[client].Reset(true);
	g_arrExtraButtons[client].Reset();
	g_bRobotSpawning[client] = false;
	g_bReleasingUber[client] = false;
	// g_flTimeJoinedBlue[client] = 0.0;
	g_iPenaltyFlags[client] = PENALTY_NONE;
	// g_nForcedTauntCam[client] = 0;
	g_flLastTimeFlagInSpawn[client] = GetGameTime();
	g_bChangeRobotPicked[client] = false;
	g_flChangeRobotCooldown[client] = 0.0;
	g_bSpawningAsBossRobot[client] = false;
	g_arrPlayerPath[client].Reset();
	g_bAllowRespawn[client] = true;
	
	m_bIsRobot[client] = false;
	m_bBypassBotCheck[client] = false;
	m_flBlockMovementTime[client] = 0.0;
	m_flNextActionTime[client] = 0.0;
	m_bIsWaitingForReload[client] = false;
	
	MvMRobotPlayer(client).Reset();
	
	SDKHook(client, SDKHook_OnTakeDamage, Actor_OnTakeDamage);
	SDKHook(client, SDKHook_SetTransmit, Actor_SetTransmit);
	
	DHooks_OnClientPutInServer(client);
}

public void OnClientDisconnect(int client)
{
	if (IsPlayingAsRobot(client))
	{
		//The player that left was going to be a boss, so give it to someone else
		if (g_bSpawningAsBossRobot[client])
		{
			g_bRobotBossesAvailable = true;
			ForceRandomPlayerToReselectRobot();
		}
		
		//When we leave, the sound might still persist, so stop it
		StopIdleSound(client);
	}
}

public void OnConfigsExecuted()
{
	PrepareCustomViewModelAssets(bwr3_robot_custom_viewmodels.IntValue);
	
	// HookConVarChange(tf_mvm_miniboss_scale, ConVarChanged_MinibossScale);
	
	BaseServer_AddTag("bwree");
	
	for (eRobotTemplateType i = ROBOT_STANDARD; i < ROBOT_TEMPLATE_TYPE_COUNT; i++)
		UpdateRobotTemplateDataForType(i);
	
	MainConfig_UpdateSettings();
	MapConfig_UpdateSettings();
	UpdateEngineerHintLocations();
	PrepareRobotCustomFiles();
}

public void OnEntityCreated(int entity, const char[] classname)
{
	//TODO: verify this always works
	//TODO: maybe change this to entity reference instead?
	if (StrEqual(classname, "tf_objective_resource"))
	{
		g_iObjectiveResource = entity;
	}
	else if (StrEqual(classname, "info_populator"))
	{
		g_iPopulationManager = entity;
	}
	else if (StrEqual(classname, "item_teamflag"))
	{
		SDKHook(entity, SDKHook_Touch, CaptureFlag_Touch);
	}
	else if (StrEqual(classname, "obj_sentrygun"))
	{
		SDKHook(entity, SDKHook_OnTakeDamage, Actor_OnTakeDamage);
		SDKHook(entity, SDKHook_SetTransmit, Actor_SetTransmit);
	}
	else if (StrEqual(classname, "obj_dispenser"))
	{
		SDKHook(entity, SDKHook_OnTakeDamage, Actor_OnTakeDamage);
		SDKHook(entity, SDKHook_SetTransmit, Actor_SetTransmit);
	}
	else if (StrEqual(classname, "obj_teleporter"))
	{
		SDKHook(entity, SDKHook_OnTakeDamage, Actor_OnTakeDamage);
		SDKHook(entity, SDKHook_SetTransmit, Actor_SetTransmit);
	}
	else if (StrEqual(classname, "obj_attachment_sapper"))
	{
		// SDKHook(entity, SDKHook_OnTakeDamage, Actor_OnTakeDamage);
		// SDKHook(entity, SDKHook_SetTransmit, Actor_SetTransmit);
		SDKHook(entity, SDKHook_SpawnPost, ObjectSapper_SpawnPost);
	}
	else if (StrEqual(classname, "headless_hatman"))
	{
		SDKHook(entity, SDKHook_OnTakeDamage, Actor_OnTakeDamage);
		SDKHook(entity, SDKHook_SetTransmit, Actor_SetTransmit);
	}
	else if (StrEqual(classname, "merasmus"))
	{
		SDKHook(entity, SDKHook_OnTakeDamage, Actor_OnTakeDamage);
		SDKHook(entity, SDKHook_SetTransmit, Actor_SetTransmit);
	}
	else if (StrEqual(classname, "eyeball_boss"))
	{
		SDKHook(entity, SDKHook_OnTakeDamage, Actor_OnTakeDamage);
		SDKHook(entity, SDKHook_SetTransmit, Actor_SetTransmit);
	}
	else if (StrEqual(classname, "base_boss"))
	{
		SDKHook(entity, SDKHook_OnTakeDamage, Actor_OnTakeDamage);
		SDKHook(entity, SDKHook_SetTransmit, Actor_SetTransmit);
	}
	else if (StrEqual(classname, "tank_boss"))
	{
		SDKHook(entity, SDKHook_OnTakeDamage, Actor_OnTakeDamage);
		SDKHook(entity, SDKHook_SetTransmit, Actor_SetTransmit);
	}
	else if (StrEqual(classname, "func_regenerate"))
	{
		SDKHook(entity, SDKHook_Touch, RegenerateZone_Touch);
		SDKHook(entity, SDKHook_Touch, BaseTrigger_Touch);
	}
	
	if (StrEqual(classname, "trigger") || StrContains(classname, "trigger_") != -1)
	{
		SDKHook(entity, SDKHook_Touch, BaseTrigger_Touch);
	}
	
	//TODO: should we try to check if any other entity is a member of CBaseCombatCharacter?
	
	DHooks_OnEntityCreated(entity, classname);
}

//TODO: implement a MainAction onto the player
//Basically track every player's next action update instead of relying solely on this
public Action OnPlayerRunCmd(int client, int &buttons, int &impulse, float vel[3], float angles[3], int &weapon, int &subtype, int &cmdnum, int &tickcount, int &seed, int mouse[2])
{
	if (!IsPlayingAsRobot(client))
	{
#if defined SPY_DISGUISE_VISION_OVERRIDE
		if (IsPlayerAlive(client))
		{
			if (TF2_GetPlayerClass(client) == TFClass_Spy && GetPopFileEventType(g_iPopulationManager) != MVM_EVENT_POPFILE_HALLOWEEN)
			{
				int iDisguisedClass = view_as<int>(TF2_GetDisguiseClass(client));
				int iDisguisedTeam = GetEntProp(client, Prop_Send, "m_nDisguiseTeam");
				
				if (g_arrDisguised[client].nDisguisedClass != iDisguisedClass || g_arrDisguised[client].nDisguisedTeam != iDisguisedTeam)
				{
					if ((iDisguisedClass == 0 && iDisguisedTeam == 0) || iDisguisedTeam == TFTeam_Red)
					{
						SpyDisguiseClear(client);
					}
					else 
					{
						SpyDisguiseThink(client, iDisguisedClass, iDisguisedTeam);
						
						g_arrDisguised[client].nDisguisedClass = iDisguisedClass;
						g_arrDisguised[client].nDisguisedTeam = iDisguisedTeam;
					}
				}
			}
			else
			{
				SpyDisguiseClear(client);
			}
		}
#endif
		
		return Plugin_Continue;
	}
	
	RoundState iRoundState = GameRules_GetRoundState();
	OSTFPlayer player = OSTFPlayer(client);
	
	if (iRoundState == RoundState_BetweenRounds)
	{
		g_bAllowRespawn[client] = true;
		
		//No attacking allowed during pre-round
		/* if (buttons & IN_ATTACK)
		{
			buttons &= ~IN_ATTACK;
		}
		
		if (buttons & IN_ATTACK2)
		{
			buttons &= ~IN_ATTACK2;
		} */
		
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
		if (g_bReleasingUber[client])
		{
			//Not releasing uber anymore if we are dead
			g_bReleasingUber[client] = false;
			CollectPlayerCurrentUniqueUbers(client);
		}
		
		m_bIsWaitingForReload[client] = false;
		
		if (iRoundState == RoundState_TeamWin || iRoundState == RoundState_GameOver)
		{
			//No spawning at this time
			return Plugin_Continue;
		}
		
		//Spawn the player in the next respawn wave
		if (roboPlayer.NextSpawnTime <= GetGameTime() && !IsBotSpawningPaused(g_iPopulationManager))
		{
			roboPlayer.NextSpawnTime = GetGameTime() + 1.0;
			TurnPlayerIntoHisNextRobot(client);
			SelectPlayerNextRobot(client);
		}
		else
		{
			g_bAllowRespawn[client] = false;
		}
		
		return Plugin_Continue;
	}
	
	//We have spawned in as one of the robots, so we are currently not allowed to respawn ourselves
	g_bAllowRespawn[client] = false;
	
	//Don't do any of this while we're transforming
	if (g_bRobotSpawning[client])
		return Plugin_Continue;
	
	//Force any input if specified elsewhere
	if (g_arrExtraButtons[client].iPress != 0)
	{
		buttons |= g_arrExtraButtons[client].iPress;
		
		//Holding it down?
		if (g_arrExtraButtons[client].flPressTime <= GetGameTime())
			g_arrExtraButtons[client].iPress = 0;
	}
	
	if (g_arrExtraButtons[client].iRelease != 0)
	{
		buttons &= ~g_arrExtraButtons[client].iRelease;
		
		if (g_arrExtraButtons[client].flReleaseTime <= GetGameTime())
			g_arrExtraButtons[client].iRelease = 0;
	}
	
	if (g_bReleasingUber[client])
	{
		int medigun = GetPlayerWeaponSlot(client, TFWeaponSlot_Secondary);
		
		if (medigun != -1 && TF2Util_GetWeaponID(medigun) == TF_WEAPON_MEDIGUN)
		{
			if (GetEntProp(medigun, Prop_Send, "m_bChargeRelease") == 0)
			{
				//Our ubercharge expired
				g_bReleasingUber[client] = false;
				CollectPlayerCurrentUniqueUbers(client);
			}
		}
		else
		{
			//We should never be here...
			g_bReleasingUber[client] = false;
		}
	}
	
	if (m_flBlockMovementTime[client] > GetGameTime())
	{
		//Block all movement inputs
		vel = NULL_VECTOR;
	}
	
#if !defined SPY_DISGUISE_VISION_OVERRIDE
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i))
		{
			if (TF2_GetClientTeam(i) == TFTeam_Red && IsPlayerAlive(i))
			{
				//Scan for any revealed spies
				if (Player_IsRangeLessThan(client, i, 512.0) && TF2_IsLineOfFireClear2(client, WorldSpaceCenter(i)))
					IsPlayerNoticedByRobot(client, i);
			}
		}
	}
#endif
	
	if (roboPlayer.HasMission(CTFBot_MISSION_DESTROY_SENTRIES))
	{
		if (buttons & IN_ATTACK)
		{
			//Sentry buster never attacks
			BlockAttackForDuration(client, 0.5);
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
		//NOTE: not needed if using TF_COND_FREEZE_INPUT in FreezePlayerInput
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
			BlockAttackForDuration(client, 0.5);
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
	
	int myWeapon = player.GetActiveWeapon();
	
	if (myWeapon != -1)
	{
		if (roboPlayer.HasAttribute(CTFBot_HOLD_FIRE_UNTIL_FULL_RELOAD) || tf_bot_always_full_reload.BoolValue)
		{
			if (Clip1(myWeapon) <= 0)
				m_bIsWaitingForReload[client] = true;
			
			if (m_bIsWaitingForReload[client])
			{
				if (Clip1(myWeapon) < TF2Util_GetWeaponMaxClip(myWeapon))
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
	
	if (buttons & IN_ATTACK)
	{
		if (roboPlayer.HasAttribute(CTFBot_SUPPRESS_FIRE) || roboPlayer.HasAttribute(CTFBot_IGNORE_ENEMIES) || !tf_bot_fire_weapon_allowed.BoolValue)
		{
			//Never allowed to attack
			BlockAttackForDuration(client, 0.5);
			buttons &= ~IN_ATTACK;
		}
		else
		{
			if (myWeapon != -1)
			{
				if (TF2Util_GetWeaponID(myWeapon) == TF_WEAPON_BUILDER && TF2_GetObjectType(myWeapon) == TFObject_Teleporter && GetEntPropFloat(myWeapon, Prop_Data, "m_flNextPrimaryAttack") <= GetGameTime() + 0.1) //TODO: replace TF2_GetObjectType with builder stock
				{
					//Only do this when the weapon can attack again to not spam failed checks
					//We add 0.1s here to catch held input before CTFWeaponBuilder::ItemPostFrame decides to call CTFWeaponBuilder::PrimaryAttack
					int teleporter = GetEntPropEnt(myWeapon, Prop_Send, "m_hObjectBeingBuilt");
					
					if (teleporter != -1)
					{
						float telePos[3]; GetCurrentBuildOrigin(teleporter, telePos);
						telePos[2] += TFBOT_STEP_HEIGHT;
						
						if (!IsSpaceToSpawnOnTeleporter(telePos, tf_mvm_miniboss_scale.FloatValue, client))
						{
							buttons &= ~IN_ATTACK;
							
							//Delay next placement attempt
							SetEntPropFloat(myWeapon, Prop_Data, "m_flNextPrimaryAttack", GetGameTime() + 0.3);
							EmitSoundToClient(client, BAD_TELE_PLACEMENT_SOUND);
							
#if defined TESTING_ONLY
							PrintToChat(client, "No space for teleporter at %f %f %f!", telePos[0], telePos[1], telePos[2] - TFBOT_STEP_HEIGHT);
#endif
						}
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
		
		if (myWeapon != -1)
		{
			switch (TF2Util_GetWeaponID(myWeapon))
			{
				case TF_WEAPON_FLAMETHROWER:
				{
					if (roboPlayer.HasAttribute(CTFBot_ALWAYS_FIRE_WEAPON))
					{
						//Always fire can never airblast
						buttons &= ~IN_ATTACK2;
					}
				}
#if defined PLAYER_UBER_LOGIC
				case TF_WEAPON_MEDIGUN:
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
#endif
			}
		}
	}
	
	if (m_bIsWaitingForReload[client])
	{
		SetHudTextParams(-1.0, -0.55, 0.25, 0, 255, 0, 255, 0, 0.0, 0.0, 0.0);
		ShowSyncHudText(client, g_hHudText, "%t", "Hud_Reloading_Barrage");
	}
	else if (roboPlayer.HasMission(CTFBot_MISSION_DESTROY_SENTRIES))
	{
		if (!MvMSuicideBomber(client).DetonateTimer_HasStarted())
		{
			SetHudTextParams(-1.0, -1.0, 0.1, 255, 0, 0, 0, 0, 0.0, 0.0, 0.0);
			ShowSyncHudText(client, g_hHudText, "%t", "Hud_Instruct_SentryBuster_Detonate");
		}
	}
	
	float myAbsOrigin[3]; GetClientAbsOrigin(client, myAbsOrigin);
	
	//Heehee I'm a spy!
	if (player.IsClass(TFClass_Spy))
	{
		bool bSpyHiding = true;
		
		if (myWeapon != -1 && IsMeleeWeapon(myWeapon) && !player.IsStealthed())
		{
			int threat = GetEnemyPlayerNearestToMe(client, roboPlayer.GetMaxVisionRange(), true);
			
#if !defined SPY_DISGUISE_VISION_OVERRIDE
			//Spies aren't real threats unless we know they're a spy
			if (threat != -1 && Player_IsVisibleInFOVNow(client, threat) && (roboPlayer.IsKnownSpy(threat) || !TF2_IsPlayerInCondition(threat, TFCond_Disguised)))
#else
			if (threat != -1 && Player_IsVisibleInFOVNow(client, threat))
#endif
			{
				bSpyHiding = false;
				
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
		
		if (bSpyHiding)
		{
			if (roboPlayer.TalkTimer_IsElapsed())
			{
				roboPlayer.TalkTimer_Start(GetRandomFloat(5.0, 10.0));
				EmitGameSoundToAll("Spy.MVM_TeaseVictim", client);
			}
		}
	}
	
#if defined MOD_EXT_CBASENPC
	CTFNavArea myArea = view_as<CTFNavArea>(CBaseCombatCharacter(client).GetLastKnownArea());
	
	if (myArea)
	{
		if (g_arrPlayerPath[client].IsDoingPathMovement())
		{
			if (myArea.HasAttributeTF(BLUE_SPAWN_ROOM))
			{
				MakePlayerLeaveSpawn(client, vel);
			}
			else
			{
				g_arrPlayerPath[client].Reset();
			}
		}
		
		if (myArea.HasAttributeTF(BLUE_SPAWN_ROOM))
		{
			if (!g_bCanBotsAttackInSpawn)
			{
				if (buttons & IN_ATTACK) //TODO: allow attacking if the player robot has always fire
				{
					if (myWeapon != -1 && !CanWeaponFireInRobotSpawn(myWeapon, IN_ATTACK))
					{
						BlockAttackForDuration(client, 0.5);
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
			
			if (bHasTheFlag)
			{
				if (bwr3_flag_idle_deal_method.IntValue)
				{
					bool bMoving = buttons & (IN_FORWARD | IN_BACK | IN_MOVELEFT | IN_MOVERIGHT) != 0;
					
					if (bMoving || g_arrPlayerPath[client].IsDoingPathMovement())
					{
						//Reset if we are moving
						g_flLastTimeFlagInSpawn[client] = GetGameTime();
					}
					
					float timeHoldingFlag = GetGameTime() - g_flLastTimeFlagInSpawn[client];
					
					if (timeHoldingFlag >= bwr3_flag_max_hold_time.FloatValue)
					{
						g_flLastTimeFlagInSpawn[client] = GetGameTime();
						
						switch (bwr3_flag_idle_deal_method.IntValue)
						{
							case 1:
							{
								if (roboPlayer.BombUpgradeLevel > 1 && bwr3_allow_drop_item.IntValue <= DROPITEM_DISABLED_BOMB_LEVEL2)
								{
									//At this point we have permanent buffs, so just suicide
									ForcePlayerSuicide(client);
								}
								else
								{
									ForcePlayerToDropFlag(client);
								}
							}
							case 2:
							{
								g_arrPlayerPath[client].Initialize();
							}
							case 3:
							{
								//Construct a path and teleport us right outside the spawn room
								g_arrPlayerPath[client].Initialize();
								MakePlayerLeaveSpawn(client, NULL_VECTOR);
								g_arrPlayerPath[client].TeleportToNearestNodeOutsideSpawn(client);
								g_arrPlayerPath[client].Reset();
							}
						}
						
						char playerName[MAX_NAME_LENGTH]; GetClientName(client, playerName, sizeof(playerName));
						
						PrintToChatAll("%s %t", PLUGIN_PREFIX, "Player_Idle_Flag_SpawnRoom", playerName);
						EmitSoundToAll(ALERT_FLAG_HELD_TOO_LONG_SOUND);
						LogAction(client, -1, "%L held the flag for too long in spawn!", client);
					}
				}
				
				if (roboPlayer.BombUpgradeLevel != DONT_UPGRADE)
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
				//We're not idling with the flag
				g_flLastTimeFlagInSpawn[client] = GetGameTime();
			}
		}
		else
		{
			//Not idling in spawn
			g_flLastTimeFlagInSpawn[client] = GetGameTime();
			
			if (bHasTheFlag && roboPlayer.BombUpgradeLevel != DONT_UPGRADE && CanStartOrResumeAction(client, ROBOT_ACTION_UPGRADE_BOMB))
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
							PrintCenterText(client, "%t", "Notify_Upgrade_Bomb");
						}
						case BOMB_UPGRADE_AUTO:
						{
							//Upgrade the bomb over time
							if (UpgradeBomb(client))
							{
								DoBotTauntAction(client);
							}
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
	
	if (condition == TFCond_MVMBotRadiowave && m_bBypassBotCheck[client] == false)
	{
		//This condition does nothing on human players, so we apply the stun ourselves
		m_bBypassBotCheck[client] = true;
		AddCond_MVMBotStunRadiowave(client, TF2Util_GetPlayerConditionDuration(client, TFCond_MVMBotRadiowave));
		m_bBypassBotCheck[client] = false;
		
		//Particle is handled client-side and only shows up on bots, so just do this
		// EmitParticleEffect("bot_radio_waves", "head", client, PATTACH_POINT_FOLLOW);
	}
}

public void TF2_OnConditionRemoved(int client, TFCond condition)
{
	if (!IsPlayingAsRobot(client))
		return;
	
	if (condition == TFCond_Taunting)
	{
		//Taunting is considered an action
		SetNextBehaviorActionTime(client, nb_update_frequency.FloatValue);
	}
	else if (condition == TFCond_MVMBotRadiowave)
	{
		//Stop the particle we may have added earlier in TF2_OnConditionAdded
		// StopParticleEffects(client);
	}
}

public void ConVarChanged_AllowMovement(ConVar convar, const char[] oldValue, const char[] newValue)
{
	if (GameRules_GetRoundState() != RoundState_BetweenRounds)
		return;
	
	for (int i = 1; i <= MaxClients; i++)
		if (IsClientInGame(i) && IsPlayingAsRobot(i))
			SetPlayerToMove(i, StringToInt(newValue) ? true : false);
}

public void ConVarChanged_PlayerChangeName(ConVar convar, const char[] oldValue, const char[] newValue)
{
	//Only matters when turning it off
	if (StringToInt(newValue))
		return;
	
	if (GameRules_GetRoundState() == RoundState_BetweenRounds)
		return;
	
	for (int i = 1; i <= MaxClients; i++)
		if (IsClientInGame(i) && IsPlayingAsRobot(i))
			ResetRobotPlayerName(i);
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
		
		return;
	}
	
	//If changed for a specific template file, re-read it
	if (convar == bwr3_robot_template_file)
		UpdateRobotTemplateDataForType(ROBOT_STANDARD);
	else if (convar == bwr3_robot_giant_template_file)
		UpdateRobotTemplateDataForType(ROBOT_GIANT);
	else if (convar == bwr3_robot_gatebot_template_file)
		UpdateRobotTemplateDataForType(ROBOT_GATEBOT);
	else if (convar == bwr3_robot_gatebot_giant_template_file)
		UpdateRobotTemplateDataForType(ROBOT_GATEBOT_GIANT);
	else if (convar == bwr3_robot_sentrybuster_template_file)
		UpdateRobotTemplateDataForType(ROBOT_SENTRYBUSTER);
	else if (convar == bwr3_robot_boss_template_file)
		UpdateRobotTemplateDataForType(ROBOT_BOSS);
}

public void ConVarChanged_RobotCustomViewmodels(ConVar convar, const char[] oldValue, const char[] newValue)
{
	PrepareCustomViewModelAssets(StringToInt(newValue));
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
		ReplyToCommand(client, "%s %t", PLUGIN_PREFIX, "Player_Already_Robot");
		return Plugin_Handled;
	}
	
	if (GetRobotPlayerCount() >= bwr3_max_invaders.IntValue)
	{
		ReplyToCommand(client, "%s %t", PLUGIN_PREFIX, "Robot_Player_Limit_Reached");
		return Plugin_Handled;
	}
	
	float cooldown = GetBWRCooldownTimeLeft(client);
	
	if (cooldown > 0.0)
	{
		ReplyToCommand(client, "%s %t", PLUGIN_PREFIX, "Player_Robot_Denied_Cooldown", cooldown);
		return Plugin_Handled;
	}
	
	// TF2_RefundPlayer(client);
	
	if (GameRules_GetRoundState() == RoundState_RoundRunning)
	{
		//Since the player will die, set their next spawn time
		MvMRobotPlayer(client).NextSpawnTime = GetGameTime() + GetRandomFloat(bwr3_robot_spawn_time_min.FloatValue, bwr3_robot_spawn_time_max.FloatValue);
		
#if defined OVERRIDE_PLAYER_RESPAWN_TIME
#if defined CORRECT_VISIBLE_RESPAWN_TIME
		if (!IsPlayerAlive(client))
		{
			//We're already dead, act as if we died now as overridden respawn time is calculated as GetDeathTime() + GetRespawnTimeOverride()
			SetEntPropFloat(client, Prop_Send, "m_flDeathTime", GetGameTime());
		}
		
		TF2Util_SetPlayerRespawnTimeOverride(client, MvMRobotPlayer(client).NextSpawnTime - GetGameTime() + 0.1);
#else
		TF2Util_SetPlayerRespawnTimeOverride(client, bwr3_robot_spawn_time_max.FloatValue + BWR_FAKE_SPAWN_DURATION_EXTRA);
#endif //CORRECT_VISIBLE_RESPAWN_TIME
#endif //OVERRIDE_PLAYER_RESPAWN_TIME
	}
	
	ChangePlayerToTeamInvaders(client);
	
	return Plugin_Handled;
}

public Action Command_JoinRed(int client, int args)
{
	if (!IsPlayingAsRobot(client))
		return Plugin_Handled;
	
	//Get how many slots defender team has left
	//Not counting live match players as they should never matter for community servers
	int iDefenderTeamSize = tf_mvm_defenders_team_size.IntValue;
	int iSlotsLeft = iDefenderTeamSize - GetTeamClientCount(TFTeam_Red);
	bool bTeamFull = iSlotsLeft < 1;
	
	if (bTeamFull)
	{
		//Increase the defender limit until there is room to fit one more player
		int numNewSlots = 0;
		
		while (iSlotsLeft < 1)
		{
			iSlotsLeft++;
			numNewSlots++;
		}
		
		tf_mvm_defenders_team_size.IntValue = iDefenderTeamSize + numNewSlots;
	}
	
	//Go through CTFGameRules::GetTeamAssignmentOverride with modified limit
	TF2_ChangeClientTeam(client, TFTeam_Red);
	ShowVGUIPanel(client, PANEL_CLASS_RED);
	
	if (bTeamFull)
	{
		//Restore the old defender limit
		tf_mvm_defenders_team_size.IntValue = iDefenderTeamSize;
	}
	
	return Plugin_Handled;
}

public Action Command_ViewNextRobotTemplate(int client, int args)
{
	if (!IsPlayingAsRobot(client))
		return Plugin_Handled;
	
	ShowPlayerNextRobotMenu(client);
	
	return Plugin_Handled;
}

public Action Command_RobotTemplateMenu(int client, int args)
{
	if (!IsPlayingAsRobot(client))
		return Plugin_Handled;
	
	if (args >= 1)
	{
		char arg1[2]; GetCmdArg(1, arg1, sizeof(arg1));
		
		if (StringToInt(arg1) == 1 && CheckCommandAccess(client, "", ADMFLAG_GENERIC, true))
		{
			RobotPlayer_ChangeRobot(client, true);
			return Plugin_Handled;
		}
	}
	
	RobotPlayer_ChangeRobot(client);
	
	return Plugin_Handled;
}

public Action Command_ReselectRobot(int client, int args)
{
	if (!IsPlayingAsRobot(client))
		return Plugin_Handled;
	
	SelectPlayerNextRobot(client);
	
	if (MvMRobotPlayer(client).MyNextRobotTemplateType != ROBOT_BOSS)
		g_bSpawningAsBossRobot[client] = false;
	
	return Plugin_Handled;
}

public Action Command_SpawnNewRobotNow(int client, int args)
{
	if (!IsPlayingAsRobot(client))
		return Plugin_Handled;
	
	RobotPlayer_SpawnNow(client);
	
	return Plugin_Handled;
}

public Action Command_FindUseNewSpawnLocation(int client, int args)
{
	if (!IsPlayingAsRobot(client))
		return Plugin_Handled;
	
	if (GameRules_GetRoundState() == RoundState_BetweenRounds)
	{
		ReplyToCommand(client, "%s %t", PLUGIN_PREFIX, "FindNewSpawn_Denied_RoundState");
		return Plugin_Handled;
	}
	
	if (!TF2Util_IsPointInRespawnRoom(WorldSpaceCenter(client), client, true))
	{
		ReplyToCommand(client, "%s %t", PLUGIN_PREFIX, "FindNewSpawn_Denied_OutsideSpawn");
		return Plugin_Handled;
	}
	
	float newSpawnPos[3];
	
	if (FindSpawnLocation(newSpawnPos, BaseAnimating_GetModelScale(client), true, GetRobotPlayerSpawnType(MvMRobotPlayer(client))) == SPAWN_LOCATION_NOT_FOUND)
	{
		ReplyToCommand(client, "%s %t", PLUGIN_PREFIX, "FindNewSpawn_Failed_Search");
		return Plugin_Handled;
	}
	
	newSpawnPos[2] += TFBOT_STEP_HEIGHT;
	
	TeleportEntity(client, newSpawnPos);
	LogAction(client, -1, "%L selected a new spawn point.", client);
	
#if defined TESTING_ONLY
	PrintToChatAll("[Command_FindUseNewSpawnLocation] New spawn at %f %f %f", newSpawnPos[0], newSpawnPos[1], newSpawnPos[2]);
#endif
	
	return Plugin_Handled;
}

public Action Command_PlayAsRobotType(int client, int args)
{
	if (args < 3)
	{
		ReplyToCommand(client, "%s %t", PLUGIN_PREFIX, "Admin_PlayAsRobot_BadArg");
		return Plugin_Handled;
	}
	
	char arg1[MAX_NAME_LENGTH]; GetCmdArg(1, arg1, sizeof(arg1));
	
	char target_name[MAX_TARGET_LENGTH];
	int target_list[MAXPLAYERS], target_count;
	bool tn_is_ml;
	
	if ((target_count = ProcessTargetString(
			arg1,
			client,
			target_list,
			MAXPLAYERS,
			COMMAND_FILTER_CONNECTED,
			target_name,
			sizeof(target_name),
			tn_is_ml)) <= 0)
	{
		ReplyToTargetError(client, target_count);
		return Plugin_Handled;
	}
	
	char arg2[4]; GetCmdArg(2, arg2, sizeof(arg2));
	char arg3[4]; GetCmdArg(3, arg3, sizeof(arg3));
	
	eRobotTemplateType type = view_as<eRobotTemplateType>(StringToInt(arg2));
	int numID = StringToInt(arg3);
	
	for (int i = 0; i < target_count; i++)
	{
		if (IsPlayingAsRobot(target_list[i]))
		{
			g_bSpawningAsBossRobot[target_list[i]] = false;
			g_bAllowRespawn[target_list[i]] = true;
			TurnPlayerIntoRobot(target_list[i], type, numID);
		}
	}
	
	char robotName[MAX_NAME_LENGTH]; GetRobotTemplateName(type, numID, robotName, sizeof(robotName));
	
	ShowActivity2(client, "[SM] ", "%t", "Admin_Forced_BWR_Robot", robotName, target_name);
	LogAction(client, -1, "%L forced robot template %s (type %d, ID %d) on %s", client, robotName, type, numID, target_name);
	
	return Plugin_Handled;
}

public Action Command_ListRobots(int client, int args)
{
	eRobotTemplateType type = ROBOT_STANDARD;
	
	if (args > 0)
	{
		char arg1[2]; GetCmdArg(1, arg1, sizeof(arg1));
		type = view_as<eRobotTemplateType>(StringToInt(arg1));
	}
	
	PrintToConsole(client, "#ID - NAME");
	
	for (int i = 0; i < g_iTotalRobotTemplates[type]; i++)
	{
		char robotName[MAX_NAME_LENGTH]; GetRobotTemplateName(type, i, robotName, sizeof(robotName));
		PrintToConsole(client, "#%d - \"%s\"", i, robotName);
	}
	
	if (GetCmdReplySource() == SM_REPLY_TO_CHAT)
		PrintToChat(client, "Check console for details.");
	
	return Plugin_Handled;
}

public Action Command_SetCooldownOnPlayer(int client, int args)
{
	if (args < 2)
	{
		ReplyToCommand(client, "[SM] Usage: sm_bwr3_setcooldown <#userid|name> <seconds>");
		return Plugin_Handled;
	}
	
	char arg1[MAX_NAME_LENGTH]; GetCmdArg(1, arg1, sizeof(arg1));
	
	char target_name[MAX_TARGET_LENGTH];
	int target_list[MAXPLAYERS], target_count;
	bool tn_is_ml;
	
	if ((target_count = ProcessTargetString(
			arg1,
			client,
			target_list,
			MAXPLAYERS,
			COMMAND_FILTER_CONNECTED,
			target_name,
			sizeof(target_name),
			tn_is_ml)) <= 0)
	{
		ReplyToTargetError(client, target_count);
		return Plugin_Handled;
	}
	
	char arg2[4]; GetCmdArg(2, arg2, sizeof(arg2));
	float duration = StringToFloat(arg2);
	
	for (int i = 0; i < target_count; i++)
	{
		SetBWRCooldownTimeLeft(target_list[i], duration, client);
	}
	
	ShowActivity2(client, "[SM] ", "%t", "Admin_Forced_BWR_Cooldown", duration, target_name);
	
	return Plugin_Handled;
}

public Action Command_ViewCooldownData(int client, int args)
{
	if (m_adtBWRCooldown.Size == 0)
	{
		ReplyToCommand(client, "%s %t", PLUGIN_PREFIX, "Admin_ViewCooldownData_Empty");
		return Plugin_Handled;
	}
	
	ReplyToCommand(client, "CURRENT BWR COOLDOWNS");
	
	StringMapSnapshot shot = m_adtBWRCooldown.Snapshot();
	char keyName[MAX_AUTHID_LENGTH];
	float flExpireTime;
	
	for (int i = 0; i < shot.Length; i++)
	{
		shot.GetKey(i, keyName, sizeof(keyName));
		m_adtBWRCooldown.GetValue(keyName, flExpireTime);
		ReplyToCommand(client, "%s - %f", keyName, flExpireTime - GetGameTime());
	}
	
	CloseHandle(shot);
	
	return Plugin_Handled;
}

public Action Command_DebugWaveIcons(int client, int args)
{
	PrintToConsole(client, "ICONS USED IN CURRENT WAVE");
	
	for (int i = 0; i < sizeof(m_sCurrentWaveIconNames); i++)
	{
		PrintToConsole(client, m_sCurrentWaveIconNames[i]);
	}
	
	return Plugin_Handled;
}

public Action Command_DebugPlayerStats(int client, int args)
{
	if (args < 1)
	{
		ReplyToCommand(client, "[SM] Usage: sm_bwr3_debug_playerstats <#userid|name>");
		return Plugin_Handled;
	}
	
	char arg1[MAX_NAME_LENGTH]; GetCmdArg(1, arg1, sizeof(arg1));
	
	char target_name[MAX_TARGET_LENGTH];
	int target_list[MAXPLAYERS], target_count;
	bool tn_is_ml;
	
	if ((target_count = ProcessTargetString(
			arg1,
			client,
			target_list,
			MAXPLAYERS,
			COMMAND_FILTER_CONNECTED,
			target_name,
			sizeof(target_name),
			tn_is_ml)) <= 0)
	{
		ReplyToTargetError(client, target_count);
		return Plugin_Handled;
	}
	
	for (int i = 0; i < target_count; i++)
	{
		ReplyToCommand(client, "STATS OF PLAYER %N", target_list[i]);
		ReplyToCommand(client, "KILLS: %d", g_arrRobotPlayerStats[target_list[i]].iKills);
		ReplyToCommand(client, "DEATHS: %d", g_arrRobotPlayerStats[target_list[i]].iDeaths);
		ReplyToCommand(client, "FLAG CAPTURES: %d", g_arrRobotPlayerStats[target_list[i]].iFlagCaptures);
		ReplyToCommand(client, "DAMAGE: %d", g_arrRobotPlayerStats[target_list[i]].iDamage);
		ReplyToCommand(client, "HEALING: %d", g_arrRobotPlayerStats[target_list[i]].iHealing);
		ReplyToCommand(client, "POINT CAPTURES: %d", g_arrRobotPlayerStats[target_list[i]].iPointCaptures);
		ReplyToCommand(client, "TOTAL PLAYERS UBERED: %d", g_arrRobotPlayerStats[target_list[i]].iPlayersUbered);
		ReplyToCommand(client, "ROUNDS PLAYED IN A ROW: %d", g_arrRobotPlayerStats[target_list[i]].iSuccessiveRoundsPlayed);
	}
	
	return Plugin_Handled;
}

public Action Command_DebugSentryBuster(int client, int args)
{
	int nDmgLimit = 0;
	int nKillLimit = 0;
	GetSentryBusterDamageAndKillThreshold(g_iPopulationManager, nDmgLimit, nKillLimit);
	
	ReplyToCommand(client, "SENTRY BUSTER\nDamage limit = %d\nKill limit = %d", nDmgLimit, nKillLimit);
	
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
				
				ReplyToCommand(client, "%N's sentry damage = %d, sentry kills = %d", sentryOwner, nDmgDone, nKillsMade);
			}
		}
	}
	
	return Plugin_Handled;
}

public Action Command_DebugWaveData(int client, int args)
{
	Address pWave = GetCurrentWave(g_iPopulationManager);
	
	if (pWave == Address_Null)
	{
		ReplyToCommand(client, "CWave is NULL");
		return Plugin_Handled;
	}
	
	ReplyToCommand(client, "Sentry Busters spawned: %d", GetNumSentryBustersSpawned(pWave));
	ReplyToCommand(client, "Engineers teleport spawned: %d", GetNumEngineersTeleportSpawned(pWave));
	ReplyToCommand(client, "Sentry Busters killed: %d", GetNumSentryBustersKilled(pWave));
	
	return Plugin_Handled;
}

public Action CommandListener_Voicemenu(int client, const char[] command, int argc)
{
	if (argc >= 2 && IsPlayingAsRobot(client))
	{
		MvMSuicideBomber roboPlayer = MvMSuicideBomber(client);
		
		//Use voice command to trigger detonation sequence
		if (roboPlayer.HasMission(CTFBot_MISSION_DESTROY_SENTRIES) && CanStartOrResumeAction(client, ROBOT_ACTION_SUICIDE_BOMBER))
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
	if (IsPlayingAsRobot(client))
	{
		if (!bwr3_allow_readystate.BoolValue)
			return Plugin_Handled;
	}
	
	return Plugin_Continue;
}

public Action CommandListener_Taunt(int client, const char[] command, int argc)
{
	if (IsPlayingAsRobot(client))
	{
		if (TF2_IsTaunting(client))
			return Plugin_Continue;
		
		//Prevent bypassing delayed taunts
		if (m_flNextActionTime[client] > GetEngineTime())
			return Plugin_Handled;
		
		if (bwr3_bomb_upgrade_mode.IntValue == BOMB_UPGRADE_MANUAL)
		{
			if (CanStartOrResumeAction(client, ROBOT_ACTION_UPGRADE_BOMB) && MvMRobotPlayer(client).BombUpgradeTimer_IsElapsed() && TF2_HasTheFlag(client))
			{
				if (UpgradeBomb(client))
				{
					DoBotTauntAction(client);
					return Plugin_Handled;
				}
			}
		}
		
		if (bwr3_robot_taunt_mode.IntValue == TAUNTING_MODE_BEHAVORIAL_ALL)
		{
			//Every taunting we do is delayed
			DoBotTauntAction(client);
			return Plugin_Handled;
		}
	}
	
	return Plugin_Continue;
}

public Action CommandListener_Dropitem(int client, const char[] command, int argc)
{
	if (IsPlayingAsRobot(client))
	{
		switch (bwr3_allow_drop_item.IntValue)
		{
			case DROPITEM_DISABLED:
			{
				//No dropping here
				return Plugin_Handled;
			}
			case DROPITEM_DISABLED_BOMB_LEVEL2:
			{
				//The buffs after stage 1 are permanent so don't let them to drop it here
				if (MvMRobotPlayer(client).BombUpgradeLevel > 1)
					return Plugin_Handled;
			}
		}
	}
	
	return Plugin_Continue;
}

public Action CommandListener_Kill(int client, const char[] command, int argc)
{
	if (IsPlayingAsRobot(client))
	{
		//No suicide during transformation
		if (g_bRobotSpawning[client])
			return Plugin_Handled;
	}
	
	return Plugin_Continue;
}

public Action CommandListener_Buyback(int client, const char[] command, int argc)
{
	if (IsPlayingAsRobot(client))
	{
		if (!bwr3_allow_buyback.BoolValue)
			return Plugin_Handled;
	}
	
	return Plugin_Continue;
}

public Action CommandListener_Jointeam(int client, const char[] command, int argc)
{
	if (argc < 1)
		return Plugin_Continue;
	
	if (IsPlayingAsRobot(client))
		return Plugin_Continue;
	
	char arg1[8]; GetCmdArg(1, arg1, sizeof(arg1));
	
	if (strcmp(arg1, "auto", false) == 0)
	{
		if (HandleAutoTeam(client))
			return Plugin_Handled;
	}
	else
	{
		//Based on internal team name, should never change
		if (strcmp(arg1, "Blue", false) == 0)
		{
			return Command_JoinBlue(client, 0);
		}
	}
	
	return Plugin_Continue;
}

public Action CommandListener_Autoteam(int client, const char[] command, int argc)
{
	if (IsPlayingAsRobot(client))
		return Plugin_Continue;
	
	if (HandleAutoTeam(client))
		return Plugin_Handled;
	
	return Plugin_Continue;
}

public Action SoundHook_General(int clients[MAXPLAYERS], int &numClients, char sample[PLATFORM_MAX_PATH], int &entity, int &channel, float &volume, int &level, int &pitch, int &flags, char soundEntry[PLATFORM_MAX_PATH], int &seed)
{
	if (entity > MaxClients)
	{
		if (StrEqual(sample, ")mvm/mvm_tele_deliver.wav"))
		{
			char classname[PLATFORM_MAX_PATH]; GetEdictClassname(entity, classname, sizeof(classname));
			
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

static Action Timer_Taunt(Handle timer, int data)
{
	if (!IsClientInGame(data) || !IsPlayingAsRobot(data) || !IsPlayerAlive(data))
		return Plugin_Stop;
	
	//NOTE: we use Taunt instead of HandleTauntCommand to prevent us from accidentally doing partner taunts
	VS_Taunt(data, TAUNT_BASE_WEAPON);
	
	if (bwr3_robot_taunt_mode.IntValue >= TAUNTING_MODE_BEHAVORIAL_ON_KILL)
		FreezePlayerInput(data, false);
	
	return Plugin_Stop;
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
	
	//Copy the tags from the flag onto the player
	InheritFlagTags(owner, activator);
}

public void Frame_CaptureFlagOnPickup(int data)
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

public Action Actor_OnTakeDamage(int victim, int &attacker, int &inflictor, float &damage, int &damagetype, int &weapon, float damageForce[3], float damagePosition[3], int damagecustom)
{
	if (BaseEntity_IsPlayer(attacker))
	{
		if (IsPlayingAsRobot(attacker))
		{
			if (GameRules_GetRoundState() == RoundState_BetweenRounds && BaseEntity_GetTeamNumber(victim) != GetClientTeam(attacker))
			{
				//Can't damage anyone between rounds
				return Plugin_Handled;
			}
			
			if (MvMRobotPlayer(attacker).HasAttribute(CTFBot_ALWAYS_CRIT))
			{
				/* In MvM, CTFProjectile_Arrow::StrikeTarget removes DMG_CRITICAL from damagetype before it has the entity take damage from it
				if the attacker is not a TFBot or the TFBot doesn't have bot attribute ALWAYS_CRIT
				For our robot players, allow their arrows to deal critical damage if their robot allows it */
				if (inflictor > 0 && IsProjectileArrow(inflictor))
				{
					damagetype |= DMG_CRIT;
					
					return Plugin_Changed;
				}
			}
		}
	}
	
	return Plugin_Continue;
}

public Action Actor_SetTransmit(int entity, int client)
{
	if (IsPlayingAsRobot(client))
	{
#if defined MOD_BUY_A_ROBOT_3
		if (IsLeftForInvasionMode())
			return Plugin_Continue;
#endif
		
		//Always see entities on our team
		if (BaseEntity_GetTeamNumber(entity) == GetClientTeam(client))
			return Plugin_Continue;
		
		//In MvM, BLUE bots cannot see teleporters due to CTFBotVision::CollectPotentiallyVisibleEntities
		if (BaseEntity_IsBaseObject(entity) && TF2_GetObjectType(entity) == TFObject_Teleporter)
			return Plugin_Handled;
		
		//If it's farther than our current vision range, then we can't actually see it
		if (Player_IsRangeGreaterThanEntity(client, entity, MvMRobotPlayer(client).GetMaxVisionRange()))
			return Plugin_Handled;
		
		if (BaseEntity_IsPlayer(entity))
		{
#if !defined SPY_DISGUISE_VISION_OVERRIDE
			if (IsPlayerIgnoredByRobot(client, entity))
				return Plugin_Handled;
#endif
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
	
	//Currently in robot transformation
	if (g_bRobotSpawning[other])
		return Plugin_Handled;
	
	//Mission robots can't pick up the flag
	if (MvMRobotPlayer(other).IsOnAnyMission())
		return Plugin_Handled;
	
	//This robot is currently ignoring the flag
	if (MvMRobotPlayer(other).HasAttribute(CTFBot_IGNORE_FLAG))
		return Plugin_Handled;
	
	return Plugin_Continue;
}

public Action RegenerateZone_Touch(int entity, int other)
{
	if (!BaseEntity_IsPlayer(other))
		return Plugin_Continue;
	
	//Robots should never use resupply lockers
	if (IsPlayingAsRobot(other))
		return Plugin_Handled;
	
	return Plugin_Continue;
}

public Action BaseTrigger_Touch(int entity, int other)
{
	if (!BaseEntity_IsPlayer(other))
		return Plugin_Continue;
	
	if (!IsPlayingAsRobot(other))
		return Plugin_Continue;
	
	//Currently in robot transformation
	if (g_bRobotSpawning[other])
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
		char otherClassname[PLATFORM_MAX_PATH]; GetEntityClassname(other, otherClassname, sizeof(otherClassname));
		OSTFPlayer player = OSTFPlayer(entity);
		
		if (CanStartOrResumeAction(entity, ROBOT_ACTION_DEPLOY_BOMB))
		{
			if (StrEqual(otherClassname, "func_capturezone"))
			{
				//Start deploying the bomb
				if (!MvMRobotPlayer(entity).IsDeployingTheBomb() && player.HasTheFlag())
					MvMDeployBomb_OnStart(entity);
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
		
#if defined MOD_EXT_CBASENPC
		if (StrEqual(otherClassname, "trigger_capture_area") || StrEqual(otherClassname, "trigger_timer_door"))
		{
			if (TF2_IsPlayerInCondition(entity, TFCond_UberchargedHidden))
			{
				//Stop capture if we're somehow in our spawn area
				AcceptEntityInput(other, "EndTouch", _, entity);
			}
		}
#endif
	}
	else if (BaseEntity_IsPlayer(other))
	{
#if !defined SPY_DISGUISE_VISION_OVERRIDE
		if (GetClientTeam(other) != GetClientTeam(entity))
			MvMRobotPlayer(entity).SuspectSpy(other);
#endif
	}
}

public Action PlayerRobot_OnTakeDamage(int victim, int &attacker, int &inflictor, float &damage, int &damagetype, int &weapon, float damageForce[3], float damagePosition[3], int damagecustom)
{
	MvMSuicideBomber roboVictim = MvMSuicideBomber(victim);
	OSTFPlayer cbpVictim = OSTFPlayer(victim);
	
	if (damagecustom == TF_CUSTOM_BACKSTAB)
	{
		//Backstabs that don't kill me make me angry
		if (cbpVictim.GetHealth() - damage > 0)
			PrintCenterText(victim, "%t", "Player_Backstabbed");
	}
	/* else if (IsValidEntity(attacker) && damagetype & DMG_CRIT && damagetype & DMG_BURN)
	{
		//O\, neomg nirmed frp, nehomd
		if (Player_GetRangeTo(victim, attacker) < tf_bot_notice_backstab_max_range.FloatValue)
			PrintCenterText(victim, "%t", "Player_Backstabbed");
	} */
	
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

public Action PlayerRobot_WeaponCanSwitchTo(int client, int weapon)
{
	MvMRobotPlayer roboPlayer = MvMRobotPlayer(client);
	
	if (roboPlayer.HasWeaponRestriction(CTFBot_ANY_WEAPON) || !ShouldWeaponBeRestricted(weapon))
		return Plugin_Continue;
	
	int forcedWeapon = -1;
	
	if (roboPlayer.HasWeaponRestriction(CTFBot_MELEE_ONLY))
		forcedWeapon = GetPlayerWeaponSlot(client, TFWeaponSlot_Melee);
	else if (roboPlayer.HasWeaponRestriction(CTFBot_PRIMARY_ONLY))
		forcedWeapon = GetPlayerWeaponSlot(client, TFWeaponSlot_Primary);
	else if (roboPlayer.HasWeaponRestriction(CTFBot_SECONDARY_ONLY))
		forcedWeapon = GetPlayerWeaponSlot(client, TFWeaponSlot_Secondary);
	
	if (forcedWeapon != -1 && weapon != forcedWeapon)
		return Plugin_Handled;
	
	return Plugin_Continue;
}

public void PlayerRobot_WeaponEquipPost(int client, int weapon)
{
	if (GameRules_GetRoundState() == RoundState_BetweenRounds)
		return;
	
	switch (bwr3_robot_custom_viewmodels.IntValue)
	{
		case 1:
		{
			switch (EconItemView_GetItemDefIndex(weapon))
			{
				case TF_ITEMDEF_TF_WEAPON_PDA_SPY:
				{
					SetWeaponCustomViewModel(weapon, "models/mvm/weapons/v_models/v_pda_spy_bot.mdl");
				}
				case TF_ITEMDEF_TF_WEAPON_INVIS, TF_ITEMDEF_UPGRADEABLE_TF_WEAPON_INVIS:
				{
					SetWeaponCustomViewModel(weapon, "models/mvm/weapons/v_models/v_watch_spy_bot.mdl");
				}
				case TF_ITEMDEF_THE_DEAD_RINGER:
				{
					SetWeaponCustomViewModel(weapon, "models/mvm/weapons/v_models/v_watch_pocket_spy_bot.mdl");
				}
				case TF_ITEMDEF_THE_CLOAK_AND_DAGGER:
				{
					SetWeaponCustomViewModel(weapon, "models/mvm/weapons/v_models/v_watch_leather_spy_bot.mdl");
				}
				case TF_ITEMDEF_TTG_WATCH:
				{
					SetWeaponCustomViewModel(weapon, "models/mvm/weapons/v_models/v_ttg_watch_spy_bot.mdl");
				}
				case TF_ITEMDEF_THE_QUACKENBIRDT:
				{
					SetWeaponCustomViewModel(weapon, "models/mvm/workshop_partner/weapons/v_models/v_hm_watch/v_hm_watch_bot.mdl");
				}
				default:
				{
					SetWeaponCustomViewModel(weapon, g_sRobotArmModels[TF2_GetPlayerClass(client)]);
				}
			}
		}
	}
}

void FindGameConsoleVariables()
{
	tf_mvm_defenders_team_size = FindConVar("tf_mvm_defenders_team_size");
	nb_update_frequency = FindConVar("nb_update_frequency");
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
	tf_bot_engineer_mvm_sentry_hint_bomb_backward_range = FindConVar("tf_bot_engineer_mvm_sentry_hint_bomb_backward_range");
	tf_bot_engineer_mvm_sentry_hint_bomb_forward_range = FindConVar("tf_bot_engineer_mvm_sentry_hint_bomb_forward_range");
	tf_bot_engineer_mvm_hint_min_distance_from_bomb = FindConVar("tf_bot_engineer_mvm_hint_min_distance_from_bomb");
	
#if !defined SPY_DISGUISE_VISION_OVERRIDE
	tf_bot_suspect_spy_touch_interval = FindConVar("tf_bot_suspect_spy_touch_interval");
#endif
	
#if defined MOD_EXT_CBASENPC
	tf_bot_suicide_bomb_friendly_fire = FindConVar("tf_bot_suicide_bomb_friendly_fire");
#endif
}

bool HandleAutoTeam(int client)
{
	//Always favor the defenders first
	if (GetTeamClientCount(view_as<int>(TFTeam_Red)) < tf_mvm_defenders_team_size.IntValue)
		return false;
	
	if (GetRobotPlayerCount() >= bwr3_max_invaders.IntValue)
		return false;
	
	float cooldown = GetBWRCooldownTimeLeft(client);
	
	if (cooldown > 0.0)
		return false;
	
	if (GameRules_GetRoundState() == RoundState_RoundRunning)
	{
		MvMRobotPlayer(client).NextSpawnTime = GetGameTime() + GetRandomFloat(bwr3_robot_spawn_time_min.FloatValue, bwr3_robot_spawn_time_max.FloatValue);
		
#if defined OVERRIDE_PLAYER_RESPAWN_TIME
#if defined CORRECT_VISIBLE_RESPAWN_TIME
		if (!IsPlayerAlive(client))
		{
			SetEntPropFloat(client, Prop_Send, "m_flDeathTime", GetGameTime());
		}
		
		TF2Util_SetPlayerRespawnTimeOverride(client, MvMRobotPlayer(client).NextSpawnTime - GetGameTime() + 0.1);
#else
		TF2Util_SetPlayerRespawnTimeOverride(client, bwr3_robot_spawn_time_max.FloatValue + BWR_FAKE_SPAWN_DURATION_EXTRA);
#endif //CORRECT_VISIBLE_RESPAWN_TIME
#endif //OVERRIDE_PLAYER_RESPAWN_TIME
	}
	
	ChangePlayerToTeamInvaders(client);
	return true;
}

void PrepareRobotCustomFiles()
{
	for (eRobotTemplateType i = ROBOT_STANDARD; i < view_as<eRobotTemplateType>(sizeof(g_iTotalRobotTemplates)); i++)
	{
		char sFilePath[PLATFORM_MAX_PATH];
		
		for (int j = 0; j < g_iTotalRobotTemplates[i]; j++)
		{
			//Add custom robot icons to downloads from any template that specified it
			GetRobotTemplateClassIcon(i, j, sFilePath, sizeof(sFilePath));
			Format(sFilePath, sizeof(sFilePath), "materials/hud/leaderboard_class_%s.vmt", sFilePath);
			
			//We intentionally skip the valve file system here as we never want to download class icons already in the game files
			if (FileExists(sFilePath, false))
			{
				AddFileToDownloadsTable(sFilePath);
				
				if (StrContains(sFilePath, "_giant.vmt") != -1)
				{
					//Giant icons usually refer to a similarly named vtf file without the suffix
					ReplaceString(sFilePath, sizeof(sFilePath), "_giant.vmt", ".vtf");
				}
				else
				{
					ReplaceString(sFilePath, sizeof(sFilePath), ".vmt", ".vtf");
				}
				
				//Not every vtf will be consistently named as the vmt
				if (FileExists(sFilePath, false))
					AddFileToDownloadsTable(sFilePath);
			}
		}
	}
}

void PrepareCustomViewModelAssets(int type)
{
	//For custom viewmodels, precache the models, then add their assets to downloads
	
	switch (type)
	{
		case 1: //Bot arms
		{
			for (int i = 1; i < sizeof(g_sRobotArmModels); i++)
				PrecacheModel(g_sRobotArmModels[i]);
			
			PrecacheModel("models/mvm/weapons/c_models/c_engineer_bot_gunslinger.mdl");
			PrecacheModel("models/mvm/weapons/v_models/v_pda_spy_bot.mdl");
			PrecacheModel("models/mvm/weapons/v_models/v_ttg_watch_spy_bot.mdl");
			PrecacheModel("models/mvm/weapons/v_models/v_watch_leather_spy_bot.mdl");
			PrecacheModel("models/mvm/weapons/v_models/v_watch_pocket_spy_bot.mdl");
			PrecacheModel("models/mvm/weapons/v_models/v_watch_spy_bot.mdl");
			PrecacheModel("models/mvm/workshop_partner/weapons/v_models/v_hm_watch/v_hm_watch_bot.mdl");
			
			AddFileToDownloadsTable("models/mvm/weapons/c_models/c_demo_bot_animations.mdl");
			AddFileToDownloadsTable("models/mvm/weapons/c_models/c_demo_bot_arms.dx80.vtx");
			AddFileToDownloadsTable("models/mvm/weapons/c_models/c_demo_bot_arms.dx90.vtx");
			AddFileToDownloadsTable("models/mvm/weapons/c_models/c_demo_bot_arms.mdl");
			AddFileToDownloadsTable("models/mvm/weapons/c_models/c_demo_bot_arms.vvd");
			AddFileToDownloadsTable("materials/models/mvm/bots/demo/demo_bot_arms_blue.vmt");
			AddFileToDownloadsTable("materials/models/mvm/bots/demo/demo_bot_arms_blue.vtf");
			AddFileToDownloadsTable("materials/models/mvm/bots/demo/demo_bot_arms_exp.vtf");
			AddFileToDownloadsTable("materials/models/mvm/bots/demo/demo_bot_arms_normal.vtf");
			AddFileToDownloadsTable("materials/models/mvm/bots/demo/demo_bot_arms_red.vmt");
			AddFileToDownloadsTable("materials/models/mvm/bots/demo/demo_bot_arms_red.vtf");
			AddFileToDownloadsTable("models/mvm/weapons/c_models/c_engineer_bot_animations.mdl");
			AddFileToDownloadsTable("models/mvm/weapons/c_models/c_engineer_bot_arms.dx80.vtx");
			AddFileToDownloadsTable("models/mvm/weapons/c_models/c_engineer_bot_arms.dx90.vtx");
			AddFileToDownloadsTable("models/mvm/weapons/c_models/c_engineer_bot_arms.mdl");
			AddFileToDownloadsTable("models/mvm/weapons/c_models/c_engineer_bot_arms.vvd");
			AddFileToDownloadsTable("materials/models/mvm/bots/engineer/engineer_bot_arms_blue.vmt");
			AddFileToDownloadsTable("materials/models/mvm/bots/engineer/engineer_bot_arms_blue.vtf");
			AddFileToDownloadsTable("materials/models/mvm/bots/engineer/engineer_bot_arms_exp.vtf");
			AddFileToDownloadsTable("materials/models/mvm/bots/engineer/engineer_bot_arms_normal.vtf");
			AddFileToDownloadsTable("materials/models/mvm/bots/engineer/engineer_bot_arms_red.vmt");
			AddFileToDownloadsTable("materials/models/mvm/bots/engineer/engineer_bot_arms_red.vtf");
			/* AddFileToDownloadsTable("models/mvm/weapons/c_models/c_engineer_bot_gunslinger.dx80.vtx");
			AddFileToDownloadsTable("models/mvm/weapons/c_models/c_engineer_bot_gunslinger.dx90.vtx");
			AddFileToDownloadsTable("models/mvm/weapons/c_models/c_engineer_bot_gunslinger.mdl");
			AddFileToDownloadsTable("models/mvm/weapons/c_models/c_engineer_bot_gunslinger.vvd");
			AddFileToDownloadsTable("models/mvm/weapons/c_models/c_engineer_bot_gunslinger_animations.mdl"); */
			AddFileToDownloadsTable("models/mvm/weapons/c_models/c_heavy_bot_animations.mdl");
			AddFileToDownloadsTable("models/mvm/weapons/c_models/c_heavy_bot_arms.dx80.vtx");
			AddFileToDownloadsTable("models/mvm/weapons/c_models/c_heavy_bot_arms.dx90.vtx");
			AddFileToDownloadsTable("models/mvm/weapons/c_models/c_heavy_bot_arms.mdl");
			AddFileToDownloadsTable("models/mvm/weapons/c_models/c_heavy_bot_arms.vvd");
			AddFileToDownloadsTable("materials/models/mvm/bots/heavy/heavy_bot_arms_blue.vmt");
			AddFileToDownloadsTable("materials/models/mvm/bots/heavy/heavy_bot_arms_blue.vtf");
			AddFileToDownloadsTable("materials/models/mvm/bots/heavy/heavy_bot_arms_exp.vtf");
			AddFileToDownloadsTable("materials/models/mvm/bots/heavy/heavy_bot_arms_normal.vtf");
			AddFileToDownloadsTable("materials/models/mvm/bots/heavy/heavy_bot_arms_red.vmt");
			AddFileToDownloadsTable("materials/models/mvm/bots/heavy/heavy_bot_arms_red.vtf");
			AddFileToDownloadsTable("models/mvm/weapons/c_models/c_medic_bot_animations.mdl");
			AddFileToDownloadsTable("models/mvm/weapons/c_models/c_medic_bot_arms.dx80.vtx");
			AddFileToDownloadsTable("models/mvm/weapons/c_models/c_medic_bot_arms.dx90.vtx");
			AddFileToDownloadsTable("models/mvm/weapons/c_models/c_medic_bot_arms.mdl");
			AddFileToDownloadsTable("models/mvm/weapons/c_models/c_medic_bot_arms.vvd");
			AddFileToDownloadsTable("materials/models/mvm/bots/medic/medic_bot_arms_blue.vmt");
			AddFileToDownloadsTable("materials/models/mvm/bots/medic/medic_bot_arms_blue.vtf");
			AddFileToDownloadsTable("materials/models/mvm/bots/medic/medic_bot_arms_exp.vtf");
			AddFileToDownloadsTable("materials/models/mvm/bots/medic/medic_bot_arms_normal.vtf");
			AddFileToDownloadsTable("materials/models/mvm/bots/medic/medic_bot_arms_red.vmt");
			AddFileToDownloadsTable("materials/models/mvm/bots/medic/medic_bot_arms_red.vtf");
			AddFileToDownloadsTable("models/mvm/weapons/c_models/c_pyro_bot_animations.mdl");
			AddFileToDownloadsTable("models/mvm/weapons/c_models/c_pyro_bot_arms.dx80.vtx");
			AddFileToDownloadsTable("models/mvm/weapons/c_models/c_pyro_bot_arms.dx90.vtx");
			AddFileToDownloadsTable("models/mvm/weapons/c_models/c_pyro_bot_arms.mdl");
			AddFileToDownloadsTable("models/mvm/weapons/c_models/c_pyro_bot_arms.vvd");
			AddFileToDownloadsTable("materials/models/mvm/bots/pyro/pyro_bot_arms_blue.vmt");
			AddFileToDownloadsTable("materials/models/mvm/bots/pyro/pyro_bot_arms_blue.vtf");
			AddFileToDownloadsTable("materials/models/mvm/bots/pyro/pyro_bot_arms_exp.vtf");
			AddFileToDownloadsTable("materials/models/mvm/bots/pyro/pyro_bot_arms_normal.vtf");
			AddFileToDownloadsTable("materials/models/mvm/bots/pyro/pyro_bot_arms_red.vmt");
			AddFileToDownloadsTable("materials/models/mvm/bots/pyro/pyro_bot_arms_red.vtf");
			AddFileToDownloadsTable("models/mvm/weapons/c_models/c_scout_bot_animations.mdl");
			AddFileToDownloadsTable("models/mvm/weapons/c_models/c_scout_bot_arms.dx80.vtx");
			AddFileToDownloadsTable("models/mvm/weapons/c_models/c_scout_bot_arms.dx90.vtx");
			AddFileToDownloadsTable("models/mvm/weapons/c_models/c_scout_bot_arms.mdl");
			AddFileToDownloadsTable("models/mvm/weapons/c_models/c_scout_bot_arms.vvd");
			AddFileToDownloadsTable("materials/models/mvm/bots/scout/scout_bot_arms_blue.vmt");
			AddFileToDownloadsTable("materials/models/mvm/bots/scout/scout_bot_arms_blue.vtf");
			AddFileToDownloadsTable("materials/models/mvm/bots/scout/scout_bot_arms_exp.vtf");
			AddFileToDownloadsTable("materials/models/mvm/bots/scout/scout_bot_arms_normal.vtf");
			AddFileToDownloadsTable("materials/models/mvm/bots/scout/scout_bot_arms_red.vmt");
			AddFileToDownloadsTable("materials/models/mvm/bots/scout/scout_bot_arms_red.vtf");
			AddFileToDownloadsTable("models/mvm/weapons/c_models/c_sniper_bot_animations.mdl");
			AddFileToDownloadsTable("models/mvm/weapons/c_models/c_sniper_bot_arms.dx80.vtx");
			AddFileToDownloadsTable("models/mvm/weapons/c_models/c_sniper_bot_arms.dx90.vtx");
			AddFileToDownloadsTable("models/mvm/weapons/c_models/c_sniper_bot_arms.mdl");
			AddFileToDownloadsTable("models/mvm/weapons/c_models/c_sniper_bot_arms.vvd");
			AddFileToDownloadsTable("materials/models/mvm/bots/sniper/sniper_bot_arms_blue.vmt");
			AddFileToDownloadsTable("materials/models/mvm/bots/sniper/sniper_bot_arms_blue.vtf");
			AddFileToDownloadsTable("materials/models/mvm/bots/sniper/sniper_bot_arms_exp.vtf");
			AddFileToDownloadsTable("materials/models/mvm/bots/sniper/sniper_bot_arms_normal.vtf");
			AddFileToDownloadsTable("materials/models/mvm/bots/sniper/sniper_bot_arms_red.vmt");
			AddFileToDownloadsTable("materials/models/mvm/bots/sniper/sniper_bot_arms_red.vtf");
			AddFileToDownloadsTable("models/mvm/weapons/c_models/c_soldier_bot_animations.mdl");
			AddFileToDownloadsTable("models/mvm/weapons/c_models/c_soldier_bot_arms.dx80.vtx");
			AddFileToDownloadsTable("models/mvm/weapons/c_models/c_soldier_bot_arms.dx90.vtx");
			AddFileToDownloadsTable("models/mvm/weapons/c_models/c_soldier_bot_arms.mdl");
			AddFileToDownloadsTable("models/mvm/weapons/c_models/c_soldier_bot_arms.vvd");
			AddFileToDownloadsTable("materials/models/mvm/bots/soldier/soldier_bot_arms_blue.vmt");
			AddFileToDownloadsTable("materials/models/mvm/bots/soldier/soldier_bot_arms_blue.vtf");
			AddFileToDownloadsTable("materials/models/mvm/bots/soldier/soldier_bot_arms_exp.vtf");
			AddFileToDownloadsTable("materials/models/mvm/bots/soldier/soldier_bot_arms_normal.vtf");
			AddFileToDownloadsTable("materials/models/mvm/bots/soldier/soldier_bot_arms_red.vmt");
			AddFileToDownloadsTable("materials/models/mvm/bots/soldier/soldier_bot_arms_red.vtf");
			AddFileToDownloadsTable("models/mvm/weapons/c_models/c_spy_bot_animations.mdl");
			AddFileToDownloadsTable("models/mvm/weapons/c_models/c_spy_bot_arms.dx80.vtx");
			AddFileToDownloadsTable("models/mvm/weapons/c_models/c_spy_bot_arms.dx90.vtx");
			AddFileToDownloadsTable("models/mvm/weapons/c_models/c_spy_bot_arms.mdl");
			AddFileToDownloadsTable("models/mvm/weapons/c_models/c_spy_bot_arms.vvd");
			AddFileToDownloadsTable("materials/models/mvm/bots/spy/spy_bot_arms_blue.vmt");
			AddFileToDownloadsTable("materials/models/mvm/bots/spy/spy_bot_arms_blue.vtf");
			AddFileToDownloadsTable("materials/models/mvm/bots/spy/spy_bot_arms_exp.vtf");
			AddFileToDownloadsTable("materials/models/mvm/bots/spy/spy_bot_arms_normal.vtf");
			AddFileToDownloadsTable("materials/models/mvm/bots/spy/spy_bot_arms_red.vmt");
			AddFileToDownloadsTable("materials/models/mvm/bots/spy/spy_bot_arms_red.vtf");
			AddFileToDownloadsTable("models/mvm/weapons/v_models/v_pda_spy_bot.dx80");
			AddFileToDownloadsTable("models/mvm/weapons/v_models/v_pda_spy_bot.dx90.vtx");
			AddFileToDownloadsTable("models/mvm/weapons/v_models/v_pda_spy_bot.mdl");
			AddFileToDownloadsTable("models/mvm/weapons/v_models/v_pda_spy_bot.vvd");
			AddFileToDownloadsTable("models/mvm/weapons/v_models/v_pda_spy_bot_animations.mdl");
			AddFileToDownloadsTable("models/mvm/weapons/v_models/v_ttg_watch_spy_bot.dx80.vtx");
			AddFileToDownloadsTable("models/mvm/weapons/v_models/v_ttg_watch_spy_bot.dx90.vtx");
			AddFileToDownloadsTable("models/mvm/weapons/v_models/v_ttg_watch_spy_bot.mdl");
			AddFileToDownloadsTable("models/mvm/weapons/v_models/v_ttg_watch_spy_bot.vvd");
			AddFileToDownloadsTable("models/mvm/weapons/v_models/v_watch_leather_spy_bot.dx80.vtx");
			AddFileToDownloadsTable("models/mvm/weapons/v_models/v_watch_leather_spy_bot.dx90.vtx");
			AddFileToDownloadsTable("models/mvm/weapons/v_models/v_watch_leather_spy_bot.mdl");
			AddFileToDownloadsTable("models/mvm/weapons/v_models/v_watch_leather_spy_bot.vvd");
			AddFileToDownloadsTable("models/mvm/weapons/v_models/v_watch_pocket_spy_bot.dx80.vtx");
			AddFileToDownloadsTable("models/mvm/weapons/v_models/v_watch_pocket_spy_bot.dx90.vtx");
			AddFileToDownloadsTable("models/mvm/weapons/v_models/v_watch_pocket_spy_bot.mdl");
			AddFileToDownloadsTable("models/mvm/weapons/v_models/v_watch_pocket_spy_bot.vvd");
			AddFileToDownloadsTable("models/mvm/weapons/v_models/v_watch_pocket_spy_bot_animations.mdl");
			AddFileToDownloadsTable("models/mvm/weapons/v_models/v_watch_spy_bot.dx80.vtx");
			AddFileToDownloadsTable("models/mvm/weapons/v_models/v_watch_spy_bot.dx90.vtx");
			AddFileToDownloadsTable("models/mvm/weapons/v_models/v_watch_spy_bot.mdl");
			AddFileToDownloadsTable("models/mvm/weapons/v_models/v_watch_spy_bot.vvd");
			AddFileToDownloadsTable("models/mvm/weapons/v_models/v_watch_spy_bot_animations.mdl");
			AddFileToDownloadsTable("models/mvm/workshop_partner/weapons/v_models/v_hm_watch/v_hm_watch_bot.dx80.vtx");
			AddFileToDownloadsTable("models/mvm/workshop_partner/weapons/v_models/v_hm_watch/v_hm_watch_bot.dx90.vtx");
			AddFileToDownloadsTable("models/mvm/workshop_partner/weapons/v_models/v_hm_watch/v_hm_watch_bot.mdl");
			AddFileToDownloadsTable("models/mvm/workshop_partner/weapons/v_models/v_hm_watch/v_hm_watch_bot.vvd");
		}
	}
}

void UpdateCurrentWaveUsedIcons()
{
	for (int i = 0; i < MVM_CLASS_TYPES_PER_WAVE_MAX; i++)
	{
		//First set stored in indexes 0-11
		GetEntPropString(g_iObjectiveResource, Prop_Data, "m_iszMannVsMachineWaveClassNames", m_sCurrentWaveIconNames[i], sizeof(m_sCurrentWaveIconNames[]), i);
		
		//Second set stored in indexes 12-23
		GetEntPropString(g_iObjectiveResource, Prop_Data, "m_iszMannVsMachineWaveClassNames2", m_sCurrentWaveIconNames[i + MVM_CLASS_TYPES_PER_WAVE_MAX], sizeof(m_sCurrentWaveIconNames[]), i);
	}
}

bool IsClassIconUsedInCurrentWave(const char[] iconName)
{
	for (int i = 0; i < sizeof(m_sCurrentWaveIconNames); i++)
		if (StrEqual(iconName, m_sCurrentWaveIconNames[i], false))
			return true;
	
	return false;
}

float GetBWRCooldownTimeLeft(int client)
{
	//Nobody has a cooldown
	if (m_adtBWRCooldown.Size == 0)
		return 0.0;
	
	char steamID[MAX_AUTHID_LENGTH];
	
	//Not authorized or no steam connection
	if (!GetClientAuthId(client, AuthId_Steam3, steamID, sizeof(steamID)))
	{
		LogError("GetBWRCooldownTimeLeft: failed to get steamID for %L", client);
		return 0.0;
	}
	
	float flExpireTime;
	
	//They don't currently have a cooldown
	if (!m_adtBWRCooldown.GetValue(steamID, flExpireTime))
		return 0.0;
	
	float timeLeft = flExpireTime - GetGameTime();
	
	//If their cooldown time has expired, remove it
	if (timeLeft <= 0.0)
		m_adtBWRCooldown.Remove(steamID);
	
	return timeLeft;
}

bool SetBWRCooldownTimeLeft(int client, float duration, int user = -1)
{
	char steamID[MAX_AUTHID_LENGTH];
	
	if (!GetClientAuthId(client, AuthId_Steam3, steamID, sizeof(steamID)))
	{
		LogError("SetBWRCooldownTimeLeft: failed to get steamID for %L", client);
		return false;
	}
	
	if (user != -1)
		LogAction(user, client, "%L set a cooldown of %f seconds on %L.", user, duration, client);
	else
		LogAction(-1, client, "Applied a cooldown of %f seconds on %L.", duration, client);
	
	if (duration <= 0.0)
		return m_adtBWRCooldown.Remove(steamID);
	
	return m_adtBWRCooldown.SetValue(steamID, GetGameTime() + duration);
}

void BWRCooldown_PurgeExpired()
{
	if (m_adtBWRCooldown.Size == 0)
		return;
	
	StringMapSnapshot shot = m_adtBWRCooldown.Snapshot();
	char keyName[MAX_AUTHID_LENGTH];
	float flExpireTime;
	
	for (int i = 0; i < shot.Length; i++)
	{
		shot.GetKey(i, keyName, sizeof(keyName));
		m_adtBWRCooldown.GetValue(keyName, flExpireTime);
		
		if (flExpireTime <= GetGameTime())
			m_adtBWRCooldown.Remove(keyName);
	}
	
	CloseHandle(shot);
}

/* REMEMBER UNIQUE UBERS BY PLAYERS
We need these to be unique because event "player_invulned" repeatedly fires for every uber triggered even repeated by the same player
This is done through an IntMap because I do not want to allocate 102 ArrayList objects
This is only done temporarily for each new ubercharge the player pops and is then extorted to esPlayerStats.iPlayersUbered */
void RememberPlayerUberTarget(int client, int target)
{
#if SOURCEMOD_V_MINOR >= 13
	ArrayList adtUniqueUbers;
	
	if (!m_adtPlayersUbered.GetValue(client, adtUniqueUbers))
	{
		adtUniqueUbers = new ArrayList();
		m_adtPlayersUbered.SetValue(client, adtUniqueUbers);
	}
	
	int iTargetUID = GetClientUserId(target);
	
	//Already remembered?
	if (adtUniqueUbers.FindValue(iTargetUID) != -1)
		return;
	
	adtUniqueUbers.Push(iTargetUID);
#endif
}

int GetUniqueUbersByPlayer(int client)
{
#if SOURCEMOD_V_MINOR >= 13
	ArrayList adtUniqueUbers;
	
	if (!m_adtPlayersUbered.GetValue(client, adtUniqueUbers))
		return 0;
	
	return adtUniqueUbers.Length;
#endif
}

void ForgetUniqueUbersByPlayer(int client)
{
#if SOURCEMOD_V_MINOR >= 13
	ArrayList adtUniqueUbers;
	
	if (!m_adtPlayersUbered.GetValue(client, adtUniqueUbers))
		return;
	
	adtUniqueUbers.Close();
	m_adtPlayersUbered.Remove(client);
#endif
}

void CollectPlayerCurrentUniqueUbers(int client)
{
#if SOURCEMOD_V_MINOR >= 13
	//Count our totals and reset
	g_arrRobotPlayerStats[client].iPlayersUbered += GetUniqueUbersByPlayer(client);
	ForgetUniqueUbersByPlayer(client);
#endif
}

//Returns the cooldown duration the player should get based on certain statistics
float GetPlayerCalculatedCooldown(int client)
{
	if (bwr3_invader_cooldown_mode.IntValue == COOLDOWN_MODE_DISABLED)
	{
		return 0.0;
	}
	
	RoundState iRoundState = GameRules_GetRoundState();
	
	if (iRoundState == RoundState_BetweenRounds)
	{
		//Do nothing between rounds
		return 0.0;
	}
	
#if !defined TESTING_ONLY
	if (GetTeamHumanClientCount(TFTeam_Red) < 1)
	{
		//No human defenders, do not bother with a cooldown
		return 0.0;
	}
#endif
	
	float flBlueRoundTimePlayed = GetGameTime() - g_flTimeJoinedBlue[client];
	float flRoundLength = GetGameTime() - g_flTimeRoundStarted;
	float flBlueRoundTimeRatio = flBlueRoundTimePlayed / flRoundLength;
	
	if (bwr3_invader_cooldown_mode.IntValue == COOLDOWN_MODE_BASIC)
	{
		if (iRoundState == RoundState_RoundRunning)
			return 0.0;
		
		return flBlueRoundTimeRatio * g_arrCooldownSystem.flBaseDuration;
	}
	
	float flTotalDuration;
	
	if (iRoundState == RoundState_TeamWin)
	{
		//Base cooldown for winning to give others a chance to play
		flTotalDuration += flBlueRoundTimeRatio * g_arrCooldownSystem.flBaseDuration;
	}
	
	if (g_arrRobotPlayerStats[client].iFlagCaptures > 0)
	{
		if (flRoundLength < g_arrCooldownSystem.flFastCapWatchMaxSeconds)
		{
			float penalTimeLeft = g_arrCooldownSystem.flFastCapWatchMaxSeconds - flRoundLength;
			float secPerMin = g_arrCooldownSystem.flFastCapWatchMaxSeconds / g_arrCooldownSystem.flFastCapMaxMinutes;
			float extraSeconds = (penalTimeLeft / secPerMin) * 60;
			
			flTotalDuration += extraSeconds;
			LogAction(client, -1, "%L deployed the bomb in %f seconds (added ban time: %f)", client, flRoundLength, extraSeconds);
		}
		
		flTotalDuration += g_arrCooldownSystem.flSecPerCapFlag;
	}
	
	if (g_arrRobotPlayerStats[client].iKills > 0)
	{
		if (g_arrRobotPlayerStats[client].iDeaths > 0)
		{
			float ratioKD = float(g_arrRobotPlayerStats[client].iKills) / float(g_arrRobotPlayerStats[client].iDeaths);
			
			flTotalDuration += g_arrCooldownSystem.flKDSecMultiplicand * ratioKD;
		}
		else
		{
			//No deaths, add a minute for each kill obtained
			flTotalDuration += g_arrCooldownSystem.flSecPerKillNoDeath * g_arrRobotPlayerStats[client].iKills;
		}
	}
	
	if (g_arrRobotPlayerStats[client].iDamage > 0)
	{
		flTotalDuration += RoundToFloor(float(g_arrRobotPlayerStats[client].iDamage) / float(g_arrCooldownSystem.iDmgForSec)) * g_arrCooldownSystem.flDmgForSecMult;
	}
	
	if (g_arrRobotPlayerStats[client].iHealing > 0)
	{
		flTotalDuration += RoundToFloor(float(g_arrRobotPlayerStats[client].iHealing) / float(g_arrCooldownSystem.iHealingForSec)) * g_arrCooldownSystem.flHealingForSecMult;
	}
	
	if (g_arrRobotPlayerStats[client].iPointCaptures > 0)
	{
		//Add a percentage of this duration based on the amount of points we capped versus the total amount we could have capped this round
		flTotalDuration += (float(g_arrRobotPlayerStats[client].iPointCaptures) / float(g_iRoundCapturablePoints)) * g_arrCooldownSystem.flCapturePointSec;
	}
	
	if (g_iPenaltyFlags[client] & PENALTY_INVULNERABLE_DEPLOY)
	{
		//Additonal time for deploying the bomb while invulnerable
		flTotalDuration += g_arrCooldownSystem.flInvulnDeploySec;
	}
	
	flTotalDuration += g_arrRobotPlayerStats[client].iSuccessiveRoundsPlayed * g_arrCooldownSystem.flSecPerSuccessiveRoundPlayed;
	
	return flTotalDuration;
}

void RobotPlayer_SpawnNow(int client)
{
	if (g_bRobotSpawning[client])
	{
		PrintToChat(client, "%s %t", PLUGIN_PREFIX, "Player_Robot_Cannot_Spawn_Now");
		return;
	}
	
	if (GameRules_GetRoundState() == RoundState_BetweenRounds)
	{
		PrintToChat(client, "%s %t", PLUGIN_PREFIX, "Player_Robot_Cannot_Spawn_Now");
		return;
	}
	
	if (IsClientObserver(client))
	{
		//We allow spawning while dead but not if we are spectating
		if (BasePlayer_GetObserverMode(client) != OBS_MODE_DEATHCAM)
		{
			PrintToChat(client, "%s %t", PLUGIN_PREFIX, "Player_Robot_Cannot_Spawn_Now");
			return;
		}
	}
	
	if (IsBotSpawningPaused(g_iPopulationManager))
	{
		PrintToChat(client, "%s %t", PLUGIN_PREFIX, "Player_Robot_Cannot_Spawn_Now");
		return;
	}
	
	if (!TF2Util_IsPointInRespawnRoom(WorldSpaceCenter(client), client))
	{
		PrintToChat(client, "%s %t", PLUGIN_PREFIX, "Player_Robot_Cannot_Spawn_Now_RespawnRoom");
		return;
	}
	
	if (bwr3_edit_wavebar.BoolValue)
	{
		/* This is normally handled in CTFPlayer::Event_Killed when we die, but since we are changing robots now
		we are going to respawn, so decrement the icon here manually if we haven't already died */
		if (IsPlayerAlive(client))
			DecrementRobotPlayerClassIcon(client);
	}
	
	TurnPlayerIntoHisNextRobot(client);
	SelectPlayerNextRobot(client);
	
	LogAction(client, -1, "%L forcibly spawned as their next robot.", client);
}

void RobotPlayer_ChangeRobot(int client, bool bAdmin = false)
{
	if (!bwr3_robot_menu_allowed.BoolValue)
	{
		PrintToChat(client, "%s %t", PLUGIN_PREFIX, "Robot_Menu_Not_Allowed");
		return;
	}
	
	RoundState state = GameRules_GetRoundState();
	
	if (state == RoundState_TeamWin || state == RoundState_GameOver)
	{
		PrintToChat(client, "%s %t", PLUGIN_PREFIX, "Player_Change_Robot_Denied_GameOver");
		return;
	}
	
	if (state != RoundState_BetweenRounds)
	{
		if (g_bChangeRobotPicked[client])
		{
			PrintToChat(client, "%s %t", PLUGIN_PREFIX, "Player_Change_Robot_Denied_Chosen");
			return;
		}
		
		float timeLeft = g_flChangeRobotCooldown[client] - GetGameTime();
		
		if (timeLeft > 0.0)
		{
			PrintToChat(client, "%s %t", PLUGIN_PREFIX, "Player_Change_Robot_Denied_Cooldown", timeLeft);
			return;
		}
		
		/* if (!TF2Util_IsPointInRespawnRoom(WorldSpaceCenter(client), client))
		{
			PrintToChat(client, "%s %t", PLUGIN_PREFIX, "Player_Change_Robot_Denied_RespawnRoom");
			return;
		} */
	}
	
	ShowRobotVariantTypeMenu(client, bAdmin);
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
	/* We commit suicide when changing teams, so make the game think we're a support bot
	so it doesn't decrement the wavebar with our class icon in CTFPlayer::Event_Killed */
	SetAsSupportEnemy(client, true);
	
	/* CTFPlayer::ChangeTeam calls CTFGameRules::GetTeamAssignmentOverride which always returns TF_TEAM_PVE_DEFENDERS for human players
	Bypass CBasePlayer::IsBot check */
	SetClientAsBot(client, true);
	TF2_ChangeClientTeam(client, TFTeam_Blue);
	SetClientAsBot(client, false);
	
	//TODO: verify the player is actually on blue team after change
	SetRobotPlayer(client, true);
	SelectPlayerNextRobot(client);
	
	if (GameRules_GetRoundState() == RoundState_RoundRunning)
	{
		g_flTimeJoinedBlue[client] = GetGameTime();
	}
	
	//TODO: find a better place to put this
	BaseEntity_MarkNeedsNamePurge(client);
}

void SetRobotPlayer(int client, bool enabled)
{
	if (enabled)
	{
		m_bIsRobot[client] = true;
		m_adtTags[client] = new ArrayList(BOT_TAG_EACH_MAX_LENGTH);
		m_adtTeleportWhereName[client] = new ArrayList(1); //Does not matter how this is initialized as it will get replaced by a new one
		
#if !defined SPY_DISGUISE_VISION_OVERRIDE
		m_adtKnownSpy[client] = new ArrayList();
		m_adtSuspectedSpyInfo[client] = new ArrayList(2);
#endif
		
		SDKHook(client, SDKHook_TouchPost, PlayerRobot_TouchPost);
		SDKHook(client, SDKHook_OnTakeDamage, PlayerRobot_OnTakeDamage);
		SDKHook(client, SDKHook_WeaponCanSwitchTo, PlayerRobot_WeaponCanSwitchTo);
		SDKHook(client, SDKHook_WeaponEquipPost, PlayerRobot_WeaponEquipPost);
	}
	else
	{
		g_arrRobotPlayerStats[client].Reset();
		
		g_bRobotSpawning[client] = false;
		g_bReleasingUber[client] = false;
		g_iPenaltyFlags[client] = PENALTY_NONE;
		g_bSpawningAsBossRobot[client] = false;
		g_arrPlayerPath[client].Reset();
		g_bAllowRespawn[client] = true;
		m_bIsRobot[client] = false;
		
		MvMRobotPlayer(client).Reset();
		
		SDKUnhook(client, SDKHook_TouchPost, PlayerRobot_TouchPost);
		SDKUnhook(client, SDKHook_OnTakeDamage, PlayerRobot_OnTakeDamage);
		SDKUnhook(client, SDKHook_WeaponCanSwitchTo, PlayerRobot_WeaponCanSwitchTo);
		SDKUnhook(client, SDKHook_WeaponEquipPost, PlayerRobot_WeaponEquipPost);
		
		ForgetUniqueUbersByPlayer(client);
		ResetRobotPlayerName(client);
		ResetPlayerProperties(client);
		
#if defined OVERRIDE_PLAYER_RESPAWN_TIME
		//In case we switched off during a game, don't let us be stuck with a long respawn time
		if (GameRules_GetRoundState() == RoundState_RoundRunning)
			TF2Util_SetPlayerRespawnTimeOverride(client, -1.0);
#endif
	}
}

void ResetRobotPlayerName(int client)
{
	if (strlen(m_sPlayerName[client]) > 0)
	{
		SetClientName(client, m_sPlayerName[client]);
		m_sPlayerName[client] = NULL_STRING;
	}
}

void SaveRobotPlayerName(int client, bool bOverwiteSaved)
{
	//Don't overwrite existing name
	if (!bOverwiteSaved && strlen(m_sPlayerName[client]) > 0)
		return;
	
	GetClientName(client, m_sPlayerName[client], sizeof(m_sPlayerName[]));
}

void ResetPlayerProperties(int client)
{
	TF2_SetCustomModel(client, "");
	TF2Attrib_RemoveAll(client);
}

// Called when the player begins to deploy the bomb
bool MvMDeployBomb_OnStart(int client)
{
	MvMRobotPlayer roboPlayer = MvMRobotPlayer(client);
	roboPlayer.DeployBombState = TF_BOMB_DEPLOYING_DELAY;
	roboPlayer.DeployBombTimer_Start(tf_deploying_bomb_delay_time.FloatValue + nb_update_frequency.FloatValue);
	
	GetClientAbsOrigin(client, m_vecDeployPos[client]);
	FreezePlayerInput(client, true);
	SetBlockPlayerMovementTime(client, GetClientAvgLatency(client, NetFlow_Outgoing) * 1.3);
	SetAbsVelocity(client, {0.0, 0.0, 0.0});
	
	if (TF2_IsMiniBoss(client))
	{
		//NOTE: normally a check is done to see if the attribute exists in the item schema
		//but this shouldn't be necessary unless the attribute gets removed or changed
		TF2Attrib_SetByName(client, "airblast vertical vulnerability multiplier", 0.0);
	}
	
	g_nForcedTauntCam[client] = GetEntProp(client, Prop_Send, "m_nForceTauntCam");
	
	if (!g_nForcedTauntCam[client])
		SetForcedTauntCam(client, 1);
	
	return true;
}

/* Called while the player is deploying the bomb
This mainly controls the bomb deploying states
Return false if we should stop deploying the bomb
Return true to continue deploying the bomb */
bool MvMDeployBomb_Update(int client)
{
	if (!CanStartOrResumeAction(client, ROBOT_ACTION_DEPLOY_BOMB))
		return false;
	
	MvMRobotPlayer roboPlayer = MvMRobotPlayer(client);
	
	int pAreaTrigger = -1;
	
	if (roboPlayer.DeployBombState != TF_BOMB_DEPLOYING_COMPLETE)
	{
		pAreaTrigger = GetClosestCaptureZone(client);
		
		if (pAreaTrigger == -1)
			return false;
		
		const float movedRange = 20.0;
		
		if (Player_IsRangeGreaterThanVec(client, m_vecDeployPos[client], movedRange))
		{
			//TODO: whoever pushed us away, fire an event for them
			
			//Remove deploy penalty since we were pushed off of it
			g_iPenaltyFlags[client] &= ~PENALTY_INVULNERABLE_DEPLOY;
			
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
				roboPlayer.DeployBombTimer_Start(tf_deploying_bomb_time.FloatValue + nb_update_frequency.FloatValue);
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
				
				roboPlayer.DeployBombTimer_Start(2.0 + nb_update_frequency.FloatValue);
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
	
	if (g_iPenaltyFlags[client] & PENALTY_INVULNERABLE_DEPLOY == 0)
	{
		if (TF2_IsPlayerInCondition(client, TFCond_Ubercharged)
		|| TF2_IsPlayerInCondition(client, TFCond_MegaHeal)
		|| TF2_IsPlayerInCondition(client, TFCond_Bonked))
		{
			//Remember if we ever became invulnerable during the deploy
			g_iPenaltyFlags[client] |= PENALTY_INVULNERABLE_DEPLOY;
		}
	}
	
	return true;
}

// Called when the player stops deploying the bomb
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
	
	//Delay here so we don't just instantly start deploying again
	SetNextBehaviorActionTime(client, nb_update_frequency.FloatValue);
	
	roboPlayer.DeployBombState = TF_BOMB_DEPLOYING_NONE;
	
	FreezePlayerInput(client, false);
	SetBlockPlayerMovementTime(client, 0.0);
	
	if (!g_nForcedTauntCam[client])
		SetForcedTauntCam(client, 0);
}

void FreezePlayerInput(int client, bool bFreeze)
{
	if (bFreeze)
	{
		TF2_AddCondition(client, TFCond_FreezeInput);
	}
	else
	{
		TF2_RemoveCondition(client, TFCond_FreezeInput);
	}
}

void SetPlayerToMove(int client, bool bEnable)
{
	if (bEnable)
	{
		//Enable movement
		SetEntityMoveType(client, MOVETYPE_WALK);
	}
	else
	{
		//Disable movement
		SetEntityMoveType(client, MOVETYPE_NONE);
	}
}

void DoBotTauntAction(int client)
{
	//CTFBotTaunt taunts on random interval
	float interval = GetRandomFloat(0.0, 1.0);
	
	CreateTimer(interval, Timer_Taunt, client, TIMER_FLAG_NO_MAPCHANGE);
	SetNextBehaviorActionTime(client, interval + nb_update_frequency.FloatValue);
	
	if (bwr3_robot_taunt_mode.IntValue == TAUNTING_MODE_BEHAVORIAL_ALL || bwr3_robot_taunt_mode.IntValue == TAUNTING_MODE_BEHAVORIAL_BOMB)
		FreezePlayerInput(client, true);
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

bool ShouldWeaponBeRestricted(int weapon)
{
	switch (TF2Util_GetWeaponID(weapon))
	{
		case TF_WEAPON_BUFF_ITEM, TF_WEAPON_LUNCHBOX:
		{
			//These are free to use
			return false;
		}
	}
	
	return true;
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

bool CanStartOrResumeAction(int client, eRobotAction type)
{
	//Next action is delayed
	if (m_flNextActionTime[client] > GetEngineTime())
		return false;
	
	//Being dead cancels out everything!
	// if (!IsPlayerAlive(client))
		// return false;
	
	switch (type)
	{
		case ROBOT_ACTION_UPGRADE_BOMB:
		{
			//Deploying the bomb is its own action
			if (MvMRobotPlayer(client).IsDeployingTheBomb())
				return false;
			
			//Taunting means we suspended our current behavior to do it
			if (TF2_IsTaunting(client))
				return false;
			
			return GameRules_GetRoundState() != RoundState_TeamWin;
		}
		case ROBOT_ACTION_DEPLOY_BOMB:
		{
			if (TF2_IsTaunting(client))
				return false;
			
			/* For TFBots, CTFBotTacticalMonitor::Update suspends CTFBotMvMDeployBomb for CTFBotSeekAndDestroy
			when the round has been won and they are on the winning team, so for the robot players here 
			just stop the deploy process once the round has already been won */
			return GameRules_GetRoundState() != RoundState_TeamWin;
		}
		case ROBOT_ACTION_SUICIDE_BOMBER:
		{
			//Taunting is okay here only if we have started detonating
			if (TF2_IsTaunting(client) && !MvMSuicideBomber(client).DetonateTimer_HasStarted())
				return false;
			
			return GameRules_GetRoundState() != RoundState_TeamWin;
		}
	}
	
	LogError("CanStartOrResumeAction: unimplemented case %d", type);
	return false;
}

void SetBlockPlayerMovementTime(int client, float value)
{
	m_flBlockMovementTime[client] = GetGameTime() + value;
	
#if defined TESTING_ONLY
	PrintToChatAll("[SetBlockPlayerMovementTime] %N blocked for %f seconds!", client, value);
#endif
}

void SetNextBehaviorActionTime(int client, float value)
{
	m_flNextActionTime[client] = GetEngineTime() + value;
}

int GetFlagToFetch(int client)
{
	if (TF2_GetPlayerClass(client) == TFClass_Engineer)
		return -1;
	
	if (MvMRobotPlayer(client).HasAttribute(CTFBot_IGNORE_FLAG))
		return -1;
	
	int ent = -1;
	ArrayList adtFlags = new ArrayList();
	int nCarriedFlags = 0;
	int enemyTeam = view_as<int>(TF2_GetEnemyTeam(TF2_GetClientTeam(client)));
	
	while ((ent = FindEntityByClassname(ent, "item_teamflag")) != -1)
	{
		if (CaptureFlag_IsDisabled(ent))
			continue;
		
		//We do not look for these as we are not looking for the enemy's flag
		if (CaptureFlag_GetType(ent) == TF_FLAGTYPE_CTF)
			continue;
		
		if (BaseEntity_GetTeamNumber(ent) != enemyTeam)
			adtFlags.Push(ent);
		
		if (CaptureFlag_IsStolen(ent))
			nCarriedFlags++;
	}
	
	int iClosestFlag = -1;
	float flClosestFlagDist = FLT_MAX;
	int iClosestUncarriedFlag = -1;
	float flClosestUncarriedFlagDist = FLT_MAX;
	
	//Always in mvm, so we don't care about non-mvm specific rules here
	float myAbsOrigin[3]; GetClientAbsOrigin(client, myAbsOrigin);
	
	for (int i = 0; i < adtFlags.Length; i++)
	{
		int iFlag = adtFlags.Get(i);
		
		//TODO: m_followers?
		
		//Find closest flag
		float vecSubtracted[3]; SubtractVectors(GetAbsOrigin(iFlag), myAbsOrigin, vecSubtracted);
		float flDist = GetVectorLength(vecSubtracted, true);
		
		if (flDist < flClosestFlagDist)
		{
			iClosestFlag = iFlag;
			flClosestFlagDist = flDist;
		}
		
		//Find closest uncarried flag
		if (nCarriedFlags < adtFlags.Length && !CaptureFlag_IsStolen(iFlag))
		{
			if (flDist < flClosestUncarriedFlagDist)
			{
				iClosestUncarriedFlag = iFlag;
				flClosestUncarriedFlagDist = flDist;
			}
		}
	}
	
	CloseHandle(adtFlags);
	
	if (iClosestUncarriedFlag != -1)
		return iClosestUncarriedFlag;
	
	return iClosestFlag;
}

void InheritFlagTags(int client, int flag)
{
	char tags[BOT_TAGS_BUFFER_MAX_LENGTH]; GetEntPropString(flag, Prop_Data, "m_iszTags", tags, sizeof(tags));
	
	//This entity can parse multiple tags, separated by a blank space
	char splitTags[MAX_BOT_TAG_CHECKS][BOT_TAG_EACH_MAX_LENGTH];
	int splitTagsCount = ExplodeString(tags, " ", splitTags, sizeof(splitTags), sizeof(splitTags[]));
	
	for (int i = 0; i < splitTagsCount; i++)
		MvMRobotPlayer(client).AddTag(splitTags[i]);
}

void DecrementRobotPlayerClassIcon(int client)
{
	if (IsValidEntity(g_iObjectiveResource))
	{
		char iconName[PLATFORM_MAX_PATH]; TF2_GetClassIconName(client, iconName, sizeof(iconName));
		int iFlags = MvMRobotPlayer(client).GetMission() >= CTFBot_MISSION_DESTROY_SENTRIES ? MVM_CLASS_FLAG_MISSION : MVM_CLASS_FLAG_NORMAL;
		
		if (TF2_IsMiniBoss(client))
			iFlags |= MVM_CLASS_FLAG_MINIBOSS;
		
		if (IsClassIconUsedInCurrentWave(iconName))
		{
			//Take the icon out naturally
			TF2_DecrementMannVsMachineWaveClassCount(g_iObjectiveResource, iconName, iFlags);
		}
		else
		{
			if (MvMRobotPlayer(client).HasAttribute(CTFBot_ALWAYS_CRIT))
				iFlags |= MVM_CLASS_FLAG_ALWAYSCRIT;
			
			//Take the icon out completely
			OSLib_DecrementWaveIconSpawnCount(g_iObjectiveResource, iconName, iFlags, 1, false);
		}
	}
}

void RemoveAllRobotPlayerOwnedEntities()
{
	RemoveAllRobotPlayerOwnedProjectiles();
	
#if defined ALLOW_BUILDING_BETWEEN_ROUNDS
	RemoveAllRobotPlayerObjects();
#endif
}

void RemoveAllRobotPlayerOwnedProjectiles()
{
	int ent = -1;
	
	while ((ent = FindEntityByClassname(ent, "tf_projectile_*")) != -1)
	{
		int owner = BaseEntity_GetOwnerEntity(ent);
		
		if (owner == -1)
			continue;
		
		if (BaseEntity_IsPlayer(owner) && IsPlayingAsRobot(owner))
			RemoveEntity(ent);
	}
}

#if defined ALLOW_BUILDING_BETWEEN_ROUNDS
void RemoveAllRobotPlayerObjects(const char[] objectType = "obj_*")
{
	int ent = -1;
	
	while ((ent = FindEntityByClassname(ent, objectType)) != -1)
	{
		int builder = TF2_GetBuilder(ent);
		
		if (builder == -1)
			continue;
		
		if (IsPlayingAsRobot(builder))
			RemoveEntity(ent);
	}
}
#endif

int GetRandomRobotPlayer(int excludePlayer = -1)
{
	int total = 0;
	int[] arrPlayers = new int[MaxClients];
	
	for (int i = 1; i <= MaxClients; i++)
	{
		if (i == excludePlayer)
			continue;
		
		if (!IsClientInGame(i))
			continue;
		
		if (!IsPlayingAsRobot(i))
			continue;
		
		if (!IsPlayerAlive(i))
			continue;
		
		arrPlayers[total++] = i;
	}
	
	if (total > 0)
		return arrPlayers[GetRandomInt(0, total - 1)];
	
	return -1;
}

static bool MakePlayerLeaveSpawn(int client, float vel[3])
{
	if (g_arrPlayerPath[client].adtPositions)
	{
		if (g_arrPlayerPath[client].IsPathValid())
		{
			float vGoal[3]; g_arrPlayerPath[client].GetCurrentGoalPosition(vGoal);
			MovePlayerTowardsGoal(client, vGoal, vel);
			
			float vOrigin[3]; GetClientAbsOrigin(client, vOrigin);
			vGoal[2] = vOrigin[2];
			
			if (GetVectorDistance(vGoal, vOrigin) <= 25.0)
			{
				//Reached our goal, move on to the next
				g_arrPlayerPath[client].iTargetNodeIndex--;
			}
		}
	}
	
	if (g_arrPlayerPath[client].flNextRepathTime > GetGameTime())
		return true;
	
	g_arrPlayerPath[client].adtPositions.Clear();
	
	CNavArea startArea = CBaseCombatCharacter(client).GetLastKnownArea();
	
	if (startArea == NULL_AREA)
	{
		return false;
	}
	
	float vDesiredGoal[3]; vDesiredGoal = GetBombHatchPosition();
	
	const float maxDistanceToArea = 200.0;
	CNavArea goalArea = TheNavMesh.GetNearestNavArea(vDesiredGoal, true, maxDistanceToArea, true);
	
	if (startArea == goalArea)
	{
		//TODO: trivial path
	}
	
	CNavArea closestArea = NULL_AREA;
	TheNavMesh.BuildPath(startArea, goalArea, vDesiredGoal, _, closestArea, 0.0, GetClientTeam(client));
	
	if (closestArea == NULL_AREA)
		return false;
	
	CNavArea tempArea = closestArea;
	CNavArea parentArea = tempArea.GetParent();
	NavDirType iNavDirection;
	float flHalfWidth;
	float vCenterPortal[3], vClosestPoint[3];
	
	g_arrPlayerPath[client].AppendPathPosition(vDesiredGoal);
	
	while (parentArea != NULL_AREA)
	{
		float vTempAreaCenter[3], vParentAreaCenter[3];
		
		tempArea.GetCenter(vTempAreaCenter);
		parentArea.GetCenter(vParentAreaCenter);
		iNavDirection = CNavArea_ComputeDirection(tempArea, vParentAreaCenter);
		tempArea.ComputePortal(parentArea, iNavDirection, vCenterPortal, flHalfWidth);
		tempArea.ComputeClosestPointInPortal(parentArea, iNavDirection, vCenterPortal, vClosestPoint);
		vClosestPoint[2] = tempArea.GetZVector(vClosestPoint);
		g_arrPlayerPath[client].AppendPathPosition(vClosestPoint);
		tempArea = parentArea;
		parentArea = tempArea.GetParent();
	}
	
	float vStartPos[3]; startArea.GetCenter(vStartPos);
	g_arrPlayerPath[client].AppendPathPosition(vStartPos);
	g_arrPlayerPath[client].OnPathRecalculated();
	g_arrPlayerPath[client].flNextRepathTime = GetGameTime() + 5.0;
	
#if defined TESTING_ONLY
	g_arrPlayerPath[client].DrawCurrentPath(client);
#endif
	
	return true;
}

#if defined SPY_DISGUISE_VISION_OVERRIDE
void SpyDisguiseClear(int client)
{
	BaseEntity_ClearModelIndexOverrides(client);
	
	g_arrDisguised[client].nDisguisedClass = 0;
	g_arrDisguised[client].nDisguisedTeam = 0;
}

void SpyDisguiseThink(int client, int disguiseclass, int disguiseteam)
{
	switch (TF2_GetClientTeam(client))
	{
		case TFTeam_Red:
		{
			if (disguiseteam == view_as<int>(TFTeam_Blue))
			{
				//Appear as robot when disguised as BLUE player
				BaseEntity_SetModelIndexOverride(client, VISION_MODE_NONE, g_iModelIndexRobots[disguiseclass]);
			}
		}
		case TFTeam_Blue:
		{
			if (disguiseteam == view_as<int>(TFTeam_Blue))
			{
				//Appear as robot when disguised as BLUE player
				BaseEntity_SetModelIndexOverride(client, VISION_MODE_NONE, g_iModelIndexRobots[disguiseclass]);
			}
		}
	}
}
#else
bool IsPlayerIgnoredByRobot(int client, int subject)
{
	if (MvMRobotPlayer(client).IsKnownSpy(subject))
		return false;
	
	OSTFPlayer cbpSubject = OSTFPlayer(subject);
	
	if (cbpSubject.InCond(TFCond_OnFire) || cbpSubject.InCond(TFCond_Jarated) || cbpSubject.InCond(TFCond_CloakFlicker) || cbpSubject.InCond(TFCond_Bleeding))
		return false;
	
	if (cbpSubject.InCond(TFCond_StealthedUserBuffFade))
	{
		MvMRobotPlayer(client).ForgetSpy(subject);
		return true;
	}
	
	if (cbpSubject.IsStealthed())
	{
		if (cbpSubject.GetPercentInvisible() < 0.75)
			return false;
		
		MvMRobotPlayer(client).ForgetSpy(subject);
		return true;
	}
	
	if (cbpSubject.InCond(TFCond_Disguising))
		return false;
	
	if (cbpSubject.InCond(TFCond_Disguised) && cbpSubject.GetDisguiseTeam() == TF2_GetClientTeam(client))
		return true;
	
	return false;
}

bool IsPlayerNoticedByRobot(int client, int subject)
{
	OSTFPlayer cbpSubject = OSTFPlayer(subject);
	MvMRobotPlayer roboPlayer = MvMRobotPlayer(client);
	
	if (cbpSubject.InCond(TFCond_OnFire) || cbpSubject.InCond(TFCond_Jarated) || cbpSubject.InCond(TFCond_CloakFlicker) || cbpSubject.InCond(TFCond_Bleeding))
	{
		if (cbpSubject.InCond(TFCond_Cloaked))
			roboPlayer.RealizeSpy(subject);
		
		return true;
	}
	
	if (cbpSubject.InCond(TFCond_StealthedUserBuffFade))
	{
		roboPlayer.ForgetSpy(subject);
		return false;
	}
	
	if (cbpSubject.IsStealthed())
	{
		if (cbpSubject.GetPercentInvisible() < 0.75)
		{
			roboPlayer.RealizeSpy(subject);
			return true;
		}
		
		roboPlayer.ForgetSpy(subject);
		return false;
	}
	
	esSuspectedSpyInfo spyInfo;
	
	if (!roboPlayer.IsSuspectedSpy(subject, spyInfo))
	{
		if (cbpSubject.InCond(TFCond_Disguised) && cbpSubject.GetDisguiseTeam() == TF2_GetClientTeam(client))
		{
			roboPlayer.ForgetSpy(subject);
			return false;
		}
	}
	
	if (roboPlayer.IsKnownSpy(subject))
		return true;
	
	if (cbpSubject.InCond(TFCond_Disguising))
	{
		roboPlayer.RealizeSpy(subject);
		return true;
	}
	
	if (cbpSubject.InCond(TFCond_Disguised) && cbpSubject.GetDisguiseTeam() == TF2_GetClientTeam(client))
		return false;
	
	return true;
}
#endif

void MainConfig_UpdateSettings()
{
	//Reset data
	g_arrCooldownSystem.ResetToDefault();
	
	char sFilePath[PLATFORM_MAX_PATH]; BuildPath(Path_SM, sFilePath, sizeof(sFilePath), "%s/general.cfg", PLUGIN_CONFIG_DIRECTORY);
	KeyValues kv = new KeyValues("MainConfig");
	
	if (!kv.ImportFromFile(sFilePath))
	{
		//TODO: create a file here automatically with initialized default values
		CloseHandle(kv);
		
		LogError("MainConfig_UpdateSettings: File not found (%s)", sFilePath);
		return;
	}
	
	if (kv.JumpToKey("CooldownSystem"))
	{
		//If no keyvalue was found, assume default from the value it was originally set to
		g_arrCooldownSystem.flBaseDuration = kv.GetFloat("base_duration", g_arrCooldownSystem.flBaseDuration);
		
		if (kv.JumpToKey("DynamicPerformanceMode"))
		{
			if (kv.JumpToKey("BombCaptureRush"))
			{
				g_arrCooldownSystem.flFastCapWatchMaxSeconds = kv.GetFloat("watch_max_seconds", g_arrCooldownSystem.flFastCapWatchMaxSeconds);
				g_arrCooldownSystem.flFastCapMaxMinutes = kv.GetFloat("cooldown_max_minutes", g_arrCooldownSystem.flFastCapMaxMinutes);
				kv.GoBack();
			}
			
			g_arrCooldownSystem.flKDSecMultiplicand = kv.GetFloat("kd_seconds_multiplicand", g_arrCooldownSystem.flKDSecMultiplicand);
			g_arrCooldownSystem.flSecPerKillNoDeath = kv.GetFloat("seconds_per_kill_no_death", g_arrCooldownSystem.flSecPerKillNoDeath);
			g_arrCooldownSystem.flSecPerCapFlag = kv.GetFloat("seconds_per_capture_flag", g_arrCooldownSystem.flSecPerCapFlag);
			g_arrCooldownSystem.iDmgForSec = kv.GetNum("damage_for_one_second", g_arrCooldownSystem.iDmgForSec);
			g_arrCooldownSystem.flDmgForSecMult = kv.GetFloat("damage_for_one_second_multiplier", g_arrCooldownSystem.flDmgForSecMult);
			g_arrCooldownSystem.iHealingForSec = kv.GetNum("healing_for_one_second", g_arrCooldownSystem.iHealingForSec);
			g_arrCooldownSystem.flHealingForSecMult = kv.GetFloat("healing_for_one_second_multiplier", g_arrCooldownSystem.flHealingForSecMult);
			g_arrCooldownSystem.flCapturePointSec = kv.GetFloat("points_captured_sec", g_arrCooldownSystem.flCapturePointSec);
			g_arrCooldownSystem.flInvulnDeploySec = kv.GetFloat("invulnerable_deploy_sec", g_arrCooldownSystem.flInvulnDeploySec);
			g_arrCooldownSystem.flSecPerSuccessiveRoundPlayed = kv.GetFloat("seconds_per_successive_round_played", g_arrCooldownSystem.flSecPerSuccessiveRoundPlayed);
			kv.GoBack();
		}
		
		kv.GoBack();
	}
	
	CloseHandle(kv);
	
#if defined TESTING_ONLY
	LogMessage("MainConfig_UpdateSettings: CS DEFAULT DURATION = %f", g_arrCooldownSystem.flBaseDuration);
	LogMessage("MainConfig_UpdateSettings: FAST CAP MAX WATCH SECONDS = %f, MAX COOLDOWN MINUTES = %f", g_arrCooldownSystem.flFastCapWatchMaxSeconds, g_arrCooldownSystem.flFastCapMaxMinutes);
#endif
}

void MapConfig_UpdateSettings()
{
	//Reset all data
	g_flMapGiantScale = -1.0;
	
	for (int i = 0; i < sizeof(g_sMapSpawnNames); i++)
		for (int j = 0; j < sizeof(g_sMapSpawnNames[]); j++)
			g_sMapSpawnNames[i][j] = NULL_STRING;
	
	char mapName[PLATFORM_MAX_PATH]; GetCurrentMap(mapName, sizeof(mapName));
	char filePath[PLATFORM_MAX_PATH]; BuildPath(Path_SM, filePath, sizeof(filePath), "%s/%s.cfg", MAP_CONFIG_DIRECTORY, mapName);
	
	if (FileExists(filePath))
	{
		KeyValues kv = new KeyValues("MapConfig");
		
		kv.ImportFromFile(filePath);
		
		if (kv.JumpToKey("Settings"))
		{
			g_flMapGiantScale = kv.GetFloat("giant_scale", -1.0);
			kv.GoBack();
		}
		
		if (kv.JumpToKey("SpawnPoints"))
		{
			//Align this with eRobotSpawnType appropriately
			char keynameSpawnType[ROBOT_SPAWN_TYPE_COUNT][] = {"standard", "giant", "sniper", "spy"};
			
			char spawnNameList[PLATFORM_MAX_PATH];
			int count = 0;
			
			for (int i = 0; i < sizeof(keynameSpawnType); i++)
			{
				kv.GetString(keynameSpawnType[i], spawnNameList, sizeof(spawnNameList));
				
				if (strlen(spawnNameList) < 1)
					continue;
				
				count += ExplodeString(spawnNameList, ",", g_sMapSpawnNames[i], sizeof(g_sMapSpawnNames[]), sizeof(g_sMapSpawnNames[][]));
				
#if defined TESTING_ONLY
				for (int j = 0; j < sizeof(g_sMapSpawnNames[]); j++)
				{
					if (strlen(g_sMapSpawnNames[i][j]) < 1)
						break;
					
					LogMessage("MapConfig_UpdateSettings: Spawn \"%s\" for type %d", g_sMapSpawnNames[i][j], i);
				}
#endif
			}
			
			kv.GoBack();
			
			LogMessage("MapConfig_UpdateSettings: %d spawns specified", count);
		}
		
		CloseHandle(kv);
	}
	
#if defined TESTING_ONLY
	LogMessage("MapConfig_UpdateSettings: Giant scale: %f", g_flMapGiantScale);
#endif
}

eRobotSpawnType GetRobotPlayerSpawnType(MvMRobotPlayer roboPlayer)
{
	if (roboPlayer.HasAttribute(CTFBot_MINIBOSS))
		return ROBOT_SPAWN_GIANT;
	
	if (roboPlayer.HasMission(CTFBot_MISSION_SNIPER))
		return ROBOT_SPAWN_SNIPER;
	
	if (TF2_GetPlayerClass(roboPlayer.index) == TFClass_Spy)
		return ROBOT_SPAWN_SPY;
	
	return ROBOT_SPAWN_STANDARD;
}