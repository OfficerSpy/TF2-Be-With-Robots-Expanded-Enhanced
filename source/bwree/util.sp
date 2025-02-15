#include <stocklib_officerspy/shared/tf_shareddefs>
#include <stocklib_officerspy/tf/tf_player>
#include <stocklib_officerspy/tf/tf_obj>
#include <stocklib_officerspy/tf/tf_objective_resource>
#include <stocklib_officerspy/mathlib/vector>
#include <stocklib_officerspy/stocklib_extra_vscript.inc>
#include <stocklib_officerspy/teamplayroundbased_gamerules>
#include <stocklib_officerspy/tf/tf_fx>
#include <stocklib_officerspy/multiplay_gamerules>
#include <stocklib_officerspy/tf/tf_gamerules>
#include <stocklib_officerspy/econ_item_view>
#include <stocklib_officerspy/shared/tf_item_constants>
#include <stocklib_officerspy/shared/econ_item_constants>
#include <stocklib_officerspy/util>
#include <stocklib_officerspy/baseserver>
#include <stocklib_officerspy/tf/tf_weaponbase>
#include <stocklib_officerspy/tf/entity_capture_flag>

#define IsEmptyString(%1) (%1[0] == 0)

//CTFBotDeliverFlag
#define DONT_UPGRADE	-1

//PlayerLocomotion::GetStepHeight
#define TFBOT_STEP_HEIGHT	18.0

//Minibosses take reduced damage from sentry busters in CTFPlayer::OnTakeDamage
#define SENTRYBUSTER_DMG_TO_MINIBOSS	600.0

//Raw value found in CTFBotVision::GetMaxVisionRange
#define TFBOT_MAX_VISION_RANGE	6000.0

//Cvar tf_mvm_defenders_team_size
#define MVM_DEFAULT_DEFENDER_TEAM_SIZE	6

//Raw value found in CTFGameRules::GetBonusRoundTime
#define BONUS_ROUND_TIME_MVM	5

#define BWR_FAKE_SPAWN_DURATION_EXTRA	34.0

#define SOUND_GIANT_SCOUT_LOOP	"mvm/giant_scout/giant_scout_loop.wav"
#define SOUND_GIANT_SOLDIER_LOOP	"mvm/giant_soldier/giant_soldier_loop.wav"
#define SOUND_GIANT_PYRO_LOOP	"mvm/giant_pyro/giant_pyro_loop.wav"
#define SOUND_GIANT_DEMOMAN_LOOP	"mvm/giant_demoman/giant_demoman_loop.wav"
#define SOUND_GIANT_HEAVY_LOOP	")mvm/giant_heavy/giant_heavy_loop.wav"
#define SOUND_SENTRYBUSTER_LOOP	"mvm/sentrybuster/mvm_sentrybuster_loop.wav"

#if !defined __tf_econ_data_included
#define TF_ITEMDEF_DEFAULT	-1
#endif

#define TF_ITEMDEF_TF_WEAPON_PDA_SPY	27
#define TF_ITEMDEF_TF_WEAPON_INVIS	30
#define TF_ITEMDEF_THE_DEAD_RINGER	59
#define TF_ITEMDEF_THE_CLOAK_AND_DAGGER	60
#define TF_ITEMDEF_UPGRADEABLE_TF_WEAPON_INVIS	212
#define TF_ITEMDEF_TTG_WATCH	297
#define TF_ITEMDEF_THE_QUACKENBIRDT	947

enum SpawnLocationResult
{
	SPAWN_LOCATION_NOT_FOUND = 0,
	SPAWN_LOCATION_NAV,
	SPAWN_LOCATION_TELEPORTER
}

public char g_sClassNamesShort[][] =
{
	"undefined",
	"scout",
	"sniper",
	"soldier",
	"demo",
	"medic",
	"heavy",
	"pyro",
	"spy",
	"engineer",
	"civilian",
	"",
	"random"
};

public char g_sBotModels[][] =
{
	"",
	"models/bots/scout/bot_scout.mdl",
	"models/bots/sniper/bot_sniper.mdl",
	"models/bots/soldier/bot_soldier.mdl",
	"models/bots/demo/bot_demo.mdl",
	"models/bots/medic/bot_medic.mdl",
	"models/bots/heavy/bot_heavy.mdl",
	"models/bots/pyro/bot_pyro.mdl",
	"models/bots/spy/bot_spy.mdl",
	"models/bots/engineer/bot_engineer.mdl"
};

public char g_sBotBossModels[][] =
{
	"",
	"models/bots/scout_boss/bot_scout_boss.mdl",
	"models/bots/sniper/bot_sniper.mdl",
	"models/bots/soldier_boss/bot_soldier_boss.mdl",
	"models/bots/demo_boss/bot_demo_boss.mdl",
	"models/bots/medic/bot_medic.mdl",
	"models/bots/heavy_boss/bot_heavy_boss.mdl",
	"models/bots/pyro_boss/bot_pyro_boss.mdl",
	"models/bots/spy/bot_spy.mdl",
	"models/bots/engineer/bot_engineer.mdl"
};

public char g_sBotSentryBusterModel[] = "models/bots/demo/bot_sentry_buster.mdl";

public const float TF_VEC_HULL_MIN[3] =	{-24.0, -24.0, 0.0};
public const float TF_VEC_HULL_MAX[3] =	{24.0, 24.0, 82.0};

//Array size if bsaed on class count, 0 is class undefined
public int g_iRomePromoItems_Hat[] = {TF_ITEMDEF_DEFAULT, 30154, 30156, 30158, 30144, 30150, 30148, 30152, 30160, 30146};
public int g_iRomePromoItems_Misc[] = {TF_ITEMDEF_DEFAULT, 30153, 30155, 30157, 30143, 30149, 30147, 30151, 30159, 30145};

public TFCond g_nTrackedConditions[] =
{
	TFCond_Dazed,
	TFCond_Jarated,
	TFCond_Milked,
	TFCond_Gas
};

#if defined SPY_DISGUISE_VISION_OVERRIDE
public char g_strModelHumans[][] = 
{
	"",
	"models/player/scout.mdl",
	"models/player/sniper.mdl",
	"models/player/soldier.mdl",
	"models/player/demo.mdl",
	"models/player/medic.mdl",
	"models/player/heavy.mdl",
	"models/player/pyro.mdl",
	"models/player/spy.mdl",
	"models/player/engineer.mdl"
};
#endif

public char g_sRobotArmModels[][] =
{
	"",
	"models/mvm/weapons/c_models/c_scout_bot_arms.mdl",
	"models/mvm/weapons/c_models/c_sniper_bot_arms.mdl",
	"models/mvm/weapons/c_models/c_soldier_bot_arms.mdl",
	"models/mvm/weapons/c_models/c_demo_bot_arms.mdl",
	"models/mvm/weapons/c_models/c_medic_bot_arms.mdl",
	"models/mvm/weapons/c_models/c_heavy_bot_arms.mdl",
	"models/mvm/weapons/c_models/c_pyro_bot_arms.mdl",
	"models/mvm/weapons/c_models/c_spy_bot_arms.mdl",
	"models/mvm/weapons/c_models/c_engineer_bot_arms.mdl"
};

public bool TraceFilter_RobotSpawn(int entity, int contentsMask)
{
	const int collisionGroup = COLLISION_GROUP_PLAYER_MOVEMENT;
	
	//TODO: replace with a call to CBaseEntity::ShouldCollide like in CTraceFilterSimple::ShouldHitEntity
	if (BaseEntity_IsPlayer(entity))
	{
		return false;
	}
	
	return TFGameRules_ShouldCollide(collisionGroup, BaseEntity_GetCollisionGroup(entity));
}

bool Player_IsRangeGreaterThanVec(int client, float pos[3], float range)
{
	float clientPosition[3]; GetClientAbsOrigin(client, clientPosition);
	
	float to[3]; SubtractVectors(pos, clientPosition, to);
	
	return Vector_IsLengthGreaterThan(to, range);
}

int GetClosestCaptureZone(int client)
{
	int pCaptureZone = -1;
	float flClosestDistance = FLT_MAX;
	float origin[3]; GetClientAbsOrigin(client, origin);
	
	int pTempCaptureZone = -1;
	while ((pTempCaptureZone = FindEntityByClassname(pTempCaptureZone, "func_capturezone")) != -1)
	{
		if (GetEntProp(pTempCaptureZone, Prop_Send, "m_bDisabled") == 0 && BaseEntity_GetTeamNumber(pTempCaptureZone) == GetClientTeam(client))
		{
			float fCurrentDistance = GetVectorDistance(origin, WorldSpaceCenter(pTempCaptureZone));
			
			if (flClosestDistance > fCurrentDistance)
			{
				pCaptureZone = pTempCaptureZone;
				flClosestDistance = fCurrentDistance;
			}
		}
	}
	
	return pCaptureZone;
}

void AddEffects(int entity, int nEffects)
{
	int flags = GetEntProp(entity, Prop_Send, "m_fEffects");
	flags |= nEffects;
	SetEntProp(entity, Prop_Send, "m_fEffects", flags);
	
#if defined MOD_EXT_CBASENPC
	if (nEffects & EF_NODRAW)
		CBaseEntity(entity).DispatchUpdateTransmitState();
#endif
}

float[] WorldSpaceCenter(int entity)
{
	float vec[3];

#if defined MOD_EXT_CBASENPC
	CBaseEntity(entity).WorldSpaceCenter(vec);
#else	
	BaseEntity_WorldSpaceCenter(entity, vec);
#endif
	
	return vec;
}

void SetAbsOrigin(int entity, float origin[3])
{
#if defined MOD_EXT_CBASENPC
	CBaseEntity(entity).SetAbsOrigin(origin);
#else	
	VS_SetAbsOrigin(entity, origin);
#endif
}

void SetAbsVelocity(int entity, const float velocity[3])
{
#if defined MOD_EXT_CBASENPC
	CBaseEntity(entity).SetAbsVelocity(velocity);
#else	
	VS_SetAbsVelocity(entity, velocity);
#endif
}

int FindBombNearestToHatch()
{
	float origin[3]; origin = GetBombHatchPosition();
	
	float bestDistance = 999999.0;
	int bestEnt = -1;
	int ent = -1;
	
	while ((ent = FindEntityByClassname(ent, "item_teamflag")) != -1)
	{
		if (CaptureFlag_IsHome(ent))
			continue;
		
		float distance = GetVectorDistance(origin, WorldSpaceCenter(ent));
		
		if (distance <= bestDistance)
		{
			bestDistance = distance;
			bestEnt = ent;
		}
	}
	
	return bestEnt;
}

float[] GetBombHatchPosition()
{
	float origin[3];

	int hole = FindEntityByClassname(-1, "func_capturezone");
	
	if (hole != -1)
		origin = WorldSpaceCenter(hole);
	
	return origin;
}

//This is somewhat similar to INextBot::IsRangeLessThan, but it doesn't really matter too much
bool Player_IsRangeLessThan(int client, int subject, float range)
{
	return GetVectorDistance(WorldSpaceCenter(subject), WorldSpaceCenter(client)) < range;
}

void EmitParticleEffect(const char[] particleName, const char[] attachmentName, int entity, ParticleAttachment_t attachType)
{
	TE_TFParticleEffect(0.0, particleName, attachType, entity, LookupEntityAttachment(entity, attachmentName));
}

bool Player_IsVisibleInFOVNow(int client, int entity)
{
	//TODO: do a trace, this only checks if they're within our FOV
	//but not if they're currently visible to us
	float eyePosition[3]; GetClientEyePosition(client, eyePosition);
	float eyeAngles[3]; GetClientEyeAngles(client, eyeAngles);
	float center[3]; center = GetAbsOrigin(entity);
	
	return ArePointsWithinFieldOfView(eyePosition, eyeAngles, center);
}

//This is based on the game's function, but it's been modified to also factor in the player's scale
bool IsSpaceToSpawnHere(const float where[3], float playerScale = 1.0)
{
	float scaledVecHullMin[3]; scaledVecHullMin = TF_VEC_HULL_MIN;
	ScaleVector(scaledVecHullMin, playerScale);
	
	float scaledVecHullMax[3]; scaledVecHullMax = TF_VEC_HULL_MAX;
	ScaleVector(scaledVecHullMax, playerScale);
	
	const float bloat = 5.0;
	
	float mins[3];
	float bloatMin[3] = {bloat, bloat, 0.0};
	SubtractVectors(scaledVecHullMin, bloatMin, mins);
	
	float maxs[3];
	float bloatMax[3] = {bloat, bloat, bloat};
	AddVectors(scaledVecHullMax, bloatMax, maxs);
	
	Handle trace = TR_TraceHullFilterEx(where, where, mins, maxs, MASK_SOLID | CONTENTS_PLAYERCLIP, TraceFilter_RobotSpawn);
	
	if (TR_GetFraction(trace) >= 1.0)
	{
		delete trace;
		return true;
	}
	
	delete trace;
	
	return false;
}

bool IsTFBotPlayer(int client)
{
	//TODO: not correct, should be checking IsBotOfType or entity net class CTFBot
	return IsFakeClient(client);
}

//Set up an entity for item creation
int EconItemCreateNoSpawn(char[] classname, int itemDefIndex, int level, int quality)
{
	int item = CreateEntityByName(classname);
	
	if (item != -1)
	{
		SetEntProp(item, Prop_Send, "m_iItemDefinitionIndex", itemDefIndex);
		SetEntProp(item, Prop_Send, "m_bInitialized", 1);
		
		//SetEntProp doesn't work here...
		char serverClassname[64]; GetEntityNetClass(item, serverClassname, sizeof(serverClassname));
		SetEntData(item, FindSendPropInfo(serverClassname, "m_iEntityQuality"), quality);
		SetEntData(item, FindSendPropInfo(serverClassname, "m_iEntityLevel"), level);
		
		if (StrEqual(classname, "tf_weapon_builder", false))
		{
			/* NOTE: After the 2023-10-09 update, not setting netprop m_iObjectType
			will crash all client games (but the server will remain fine)
			I suspect the client's game code change and not setting it cause it to read garbage */
			SetEntProp(item, Prop_Send, "m_iObjectType", 3); //Set to OBJ_ATTACHMENT_SAPPER?
			
			bool isSapper = IsItemDefIndexSapper(itemDefIndex);
			
			if (isSapper)
				SetEntProp(item, Prop_Data, "m_iSubType", 3);
			
			SetEntProp(item, Prop_Send, "m_aBuildableObjectTypes", isSapper ? 0 : 1, _, 0); //OBJ_DISPENSER
			SetEntProp(item, Prop_Send, "m_aBuildableObjectTypes", isSapper ? 0 : 1, _, 1); //OBJ_TELEPORTER
			SetEntProp(item, Prop_Send, "m_aBuildableObjectTypes", isSapper ? 0 : 1, _, 2); //OBJ_SENTRYGUN
			SetEntProp(item, Prop_Send, "m_aBuildableObjectTypes", isSapper ? 1 : 0, _, 3); //OBJ_ATTACHMENT_SAPPER
		}
		else if (StrEqual(classname, "tf_weapon_sapper", false))
		{
			SetEntProp(item, Prop_Send, "m_iObjectType", 3);
			SetEntProp(item, Prop_Data, "m_iSubType", 3);
			SetEntProp(item, Prop_Send, "m_aBuildableObjectTypes", 0, _, 0);
			SetEntProp(item, Prop_Send, "m_aBuildableObjectTypes", 0, _, 1);
			SetEntProp(item, Prop_Send, "m_aBuildableObjectTypes", 0, _, 2);
			SetEntProp(item, Prop_Send, "m_aBuildableObjectTypes", 1, _, 3);
		}
	}
	else
	{
		LogError("EconItemCreateNoSpawn: Failed to create entity.");
	}
	
	return item;
}

//Call this when you're ready to spawn it
void EconItemSpawnGiveTo(int item, int client)
{
	DispatchSpawn(item);
	
	if (TF2Util_IsEntityWearable(item))
	{
		TF2Util_EquipPlayerWearable(client, item);
	}
	else
	{
		EquipPlayerWeapon(client, item);
		// TF2Util_SetPlayerActiveWeapon(client, item);
	}
	
	//NOTE: Bot players always have their items visible in PvE modes
	// SetEntProp(item, Prop_Send, "m_bValidatedAttachedEntity", 1);
}

bool DoPlayerWearablesConflictWith(int client, const int itemDefIndex)
{
	int newItemReigonMask = TF2Econ_GetItemEquipRegionMask(itemDefIndex);
	
	for (int i = 0; i < TF2Util_GetPlayerWearableCount(client); i++)
	{
		int wearable = TF2Util_GetPlayerWearable(client, i);
		
		if (wearable == -1)
			continue;
		
		int wearableDefIndex = GetEntProp(wearable, Prop_Send, "m_iItemDefinitionIndex");
		
		if (!TF2Econ_IsValidItemDefinition(wearableDefIndex))
			continue;
		
		int wearableRegionMask = TF2Econ_GetItemEquipRegionMask(wearableDefIndex);
		
		if (wearableRegionMask & newItemReigonMask)
			return true;
	}
	
	return false;
}

void StripWeapons(int client, bool bWearables = true, int upperLimit = TFWeaponSlot_PDA, bool bActionSlot = false)
{
	if (bWearables)
	{
		static int iMaxEntCount = -1;
		
		if (iMaxEntCount == -1)
			iMaxEntCount = GetMaxEntities();
		
		char classname[PLATFORM_MAX_PATH];
		
		for (int i = MaxClients + 1; i <= iMaxEntCount; i++)
		{
			if (IsValidEntity(i))
			{
				if (GetEntityClassname(i, classname, sizeof(classname)))
				{
					if (StrContains(classname, "tf_wearable", false) != -1)
					{
						if (StrEqual(classname, "tf_wearable_demoshield", false)
						|| StrEqual(classname, "tf_wearable_razorback", false)
						|| IsDefIndexForWearableWeapon(GetEntProp(i, Prop_Send, "m_iItemDefinitionIndex")))
						{
							if (BaseEntity_GetOwnerEntity(i) == client)
							{
								TF2_RemoveWearable(client, i);
								// RemoveEntity(i);
							}
						}
					}
				}
			}
		}
	}
	
	for (int i = TFWeaponSlot_Primary; i <= upperLimit; i++)
		TF2_RemoveWeaponSlot(client, i);
	
	//If desired, remove action slot weapons (like spellbooks)
	if (bActionSlot)
	{
		/* Fuck, this is not ideal! While this does remove weapons like spellbooks, it also removes builder weapons making engineer unable to build
		Alternatively we can go through each one with GetPlayerWeaponSlot and filter out by certain weapon classnames
		Another option is to loop through every entity and see which of the classname filtered entities are owned by this player */
		// TF2_RemoveWeaponSlot(client, TFWeaponSlot_PDA);
		
		int item = TF2Util_GetPlayerLoadoutEntity(client, LOADOUT_POSITION_ACTION, false);
		
		if (item != -1 && !TF2Util_IsEntityWearable(item))
		{
			RemovePlayerItem(client, item);
			RemoveEntity(item);
		}
	}
}

// Taken from [TF2] Chaos Mod
int GetItemDefinitionIndexByName(const char[] szItemName)
{
	if (!szItemName[0])
	{
		return TF_ITEMDEF_DEFAULT;
	}
	
	static StringMap s_hItemDefsByName;
	
	if (!s_hItemDefsByName)
	{
		s_hItemDefsByName = new StringMap();
	}
	
	if (s_hItemDefsByName.ContainsKey(szItemName))
	{
		// get cached item def from map
		int iItemDefIndex = TF_ITEMDEF_DEFAULT;
		return s_hItemDefsByName.GetValue(szItemName, iItemDefIndex) ? iItemDefIndex : TF_ITEMDEF_DEFAULT;
	}
	else
	{
		DataPack hDataPack = new DataPack();
		hDataPack.WriteString(szItemName);
		
		// search the item list and cache the result
		ArrayList hItemList = TF2Econ_GetItemList(ItemFilterCriteria_FilterByName, hDataPack);
		int iItemDefIndex = (hItemList.Length > 0) ? hItemList.Get(0) : TF_ITEMDEF_DEFAULT;
		s_hItemDefsByName.SetValue(szItemName, iItemDefIndex);
		
		delete hDataPack;
		delete hItemList;
		
		return iItemDefIndex;
	}
}

void PressAltFireButton(int client)
{
	if (TF2_IsControlStunned(client) || TF2_IsLoserStateStunned(client) || MvMRobotPlayer(client).HasAttribute(CTFBot_SUPPRESS_FIRE))
	{
		//TODO: ReleaseAltFireButton?
		return;
	}
	
	g_iForcedButtonInput[client] = IN_ATTACK2;
}

//Based on DoTeleporterOverride
bool IsTeleporterUsableByRobots(int teleporter)
{
	OSBaseObject cboTeleporter = OSBaseObject(teleporter);
	
	if (cboTeleporter.GetTeamNumber() != view_as<int>(TFTeam_Blue))
		return false;
	
	if (cboTeleporter.IsBuilding())
		return false;
	
	if (cboTeleporter.HasSapper())
		return false;
	
	if (cboTeleporter.IsPlasmaDisabled())
		return false;
	
	if (cboTeleporter.IsPlacing())
		return false;
	
	if (cboTeleporter.IsCarried())
		return false;
	
	return true;
}

float[] GetAbsOrigin(int entity)
{
	float vec[3];

#if defined MOD_EXT_CBASENPC
	CBaseEntity(entity).GetAbsOrigin(vec);
#else	
	BaseEntity_GetAbsOrigin(entity, vec);
#endif
	
	return vec;
}

float[] GetAbsAngles(int entity)
{
	float vec[3];

#if defined MOD_EXT_CBASENPC
	CBaseEntity(entity).GetAbsAngles(vec);
#else	
	BaseEntity_GetAbsAngles(entity, vec);
#endif
	
	return vec;
}

//CTFPlayer::TeleportEffect
void TeleportEffect(int client)
{
	//NOTE: In mvm, this duration is 30.0
	TF2_AddCondition(client, TFCond_TeleportedGlow, 30.0);
}

#define FLAG_REW_COSMETIC	(1 << 0)
#define FLAG_REW_CANTEEN	(1 << 1)
#define FLAG_REW_CONTRACKER	(1 << 2)

void RemoveEquippedWearables(int client, int iFilterFlags)
{
	static int iMaxEntCount = -1;
	
	if (iMaxEntCount == -1)
		iMaxEntCount = GetMaxEntities();
	
	for (int i = MaxClients + 1; i <= iMaxEntCount; i++)
	{
		if (IsValidEntity(i))
		{
			char classname[PLATFORM_MAX_PATH];
			
			if (GetEntityClassname(i, classname, sizeof(classname)))
			{
				if (iFilterFlags & FLAG_REW_COSMETIC && StrEqual(classname, "tf_wearable", false))
				{
					if (!IsDefIndexForWearableWeapon(GetEntProp(i, Prop_Send, "m_iItemDefinitionIndex")))
					{
						if (BaseEntity_GetOwnerEntity(i) == client)
						{
							TF2_RemoveWearable(client, i);
							// RemoveEntity(i);
						}
					}
				}
				else if (iFilterFlags & FLAG_REW_CANTEEN && StrEqual(classname, "tf_powerup_bottle", false))
				{
					if (BaseEntity_GetOwnerEntity(i) == client)
					{
						TF2_RemoveWearable(client, i);
						// RemoveEntity(i);
					}
				}
				else if (iFilterFlags & FLAG_REW_CONTRACKER && StrEqual(classname, "tf_wearable_campaign_item", false))
				{
					if (BaseEntity_GetOwnerEntity(i) == client)
					{
						TF2_RemoveWearable(client, i);
						// RemoveEntity(i);
					}
				}
			}
		}
	}
}

/* Is the definition index for a wearable that is also usually seen as loadut weapon?
We manually list these by definition index cause i don't know how to tell otherwise */
bool IsDefIndexForWearableWeapon(int defIndex)
{
	switch (defIndex)
	{
		case 133, 444, 405, 608, 231, 642:
		{
			return true;
		}
		default:	return false;
	}
}

void AddCond_MVMBotStunRadiowave(int client, float duration)
{
	if (BasePlayer_IsBot(client))
	{
		TF2_AddCondition(client, TFCond_MVMBotRadiowave, duration);
	}
	else
	{
		SetClientAsBot(client, true);
		TF2_AddCondition(client, TFCond_MVMBotRadiowave, duration);
		SetClientAsBot(client, false);
	}
}

void DetonateAllObjectsOfType(int client, TFObjectType type, TFObjectMode mode = TFObjectMode_None, int ignoredObject = -1)
{
	int ent = -1;
	
	while ((ent = FindEntityByClassname(ent, "obj_*")) != -1)
	{
		if (ignoredObject > 0 && ent == ignoredObject)
			continue;
		
		if (TF2_GetBuilder(ent) != client)
			continue;
		
		if (TF2_GetObjectType(ent) != type)
			continue;
		
		if (mode > TFObjectMode_None && TF2_GetObjectMode(ent) != mode)
			continue;
		
		TF2_DetonateObject(ent);
		
		Event hEvent = CreateEvent("object_removed");
		
		if (hEvent)
		{
			hEvent.SetInt("userid", GetClientUserId(client));
			hEvent.SetInt("objecttype", view_as<int>(type));
			hEvent.SetInt("index", ent);
			hEvent.Fire();
		}
	}
}

bool IsRealPlayer(int client)
{
	if (IsFakeClient(client))
		return false;
	
	if (IsClientSourceTV(client))
		return false;
	
	return true;
}

//TODO: Sentries spawned by the engineer bot ai are owned by bot_hint_sentrygun entities
//Maybe loop around and check if the owner entity is one of these sentries?
void DisableAllTeamObjectsByClassname(TFTeam team, const char[] objectType = "obj_*")
{
	int ent = -1;
	
	while ((ent = FindEntityByClassname(ent, objectType)) != -1)
	{
		if (GetEntProp(ent, Prop_Send, "m_bDisabled") == 1)
			continue;
		
		if (BaseEntity_GetTeamNumber(ent) != view_as<int>(team))
			continue;
		
		int builder = TF2_GetBuilder(ent);
		
		//Ignore buildings owned by actual TFBots
		if (builder != -1 && IsTFBotPlayer(builder))
			continue;
		
		AcceptEntityInput(ent, "Disable");
	}
}

void IPS_CreateParticle(int entity, char[] particleName, float position[3], bool bAttach = false)
{
	int particleSystem = CreateEntityByName("info_particle_system");
	
	if (particleSystem != -1)
	{
		DispatchKeyValueVector(particleSystem, "origin", position);
		DispatchKeyValue(particleSystem, "effect_name", particleName);
		
		if (bAttach)
		{
			SetVariantString("!activator");
			AcceptEntityInput(particleSystem, "SetParent", entity, particleSystem, 0);
		}

		DispatchSpawn(particleSystem);
		ActivateEntity(particleSystem);
		AcceptEntityInput(particleSystem, "Start");
	}
	else
	{
		LogError("IPS_CreateParticle: failed to create entity info_particle_system");
	}
}

float[] GetAbsVelocity(int entity)
{
	float vec[3];

#if defined MOD_EXT_CBASENPC
	CBaseEntity(entity).GetAbsVelocity(vec);
#else	
	BaseEntity_GetAbsVelocity(entity, vec);
#endif
	
	return vec;
}

int GetDefendablePointTrigger(TFTeam team)
{
	int trigger = -1;
	
	//Look for a trigger_timer_door associated with a control point
	while ((trigger = FindEntityByClassname(trigger, "trigger_timer_door")) != -1)
	{		
		//Ignore disabled triggers
		if (GetEntProp(trigger, Prop_Data, "m_bDisabled") == 1)
			continue;
		
		//Apparently some community maps don't disable the trigger when capped
		char cpname[32]; GetEntPropString(trigger, Prop_Data, "m_iszCapPointName", cpname, sizeof(cpname));
		
		//Trigger has no point associated with it
		if (strlen(cpname) < 3)
			continue;
		
		//Now find the matching control point
		int point = -1;
		char targetname[32];
		
		while ((point = FindEntityByClassname(point, "team_control_point")) != -1)
		{
			GetEntPropString(point, Prop_Data, "m_iName", targetname, sizeof(targetname));
			
			//Found the match
			if (strcmp(targetname, cpname, false) == 0)
				if (BaseEntity_GetTeamNumber(point) == view_as<int>(team))
					return trigger;
		}
	}
	
	return -1;
}

//Certain attribues have to be applied in special ways, not sure why though
bool DoSpecialSetFromStringValue(int entity, const char[] attributeName, const char[] value)
{
	if (StrEqual(attributeName, "paintkit_proto_def_index", false))
	{
		//Strictly stored as an integer
		TF2Attrib_SetByName(entity, attributeName, view_as<float>(StringToInt(value)));
		return true;
	}
	
	return false;
}

void SetRandomEconItemID(int item)
{
	EconItemView_SetItemID(item, GetRandomInt(1, 2048));
}

//Somewhat similar to INextBot::IsRangeGreaterThan
bool Player_IsRangeGreaterThanEntity(int client, int subject, float range)
{
	return GetVectorDistance(WorldSpaceCenter(subject), WorldSpaceCenter(client)) > range;
}

/* float Player_GetRangeTo(int client, int subject)
{
	return GetVectorDistance(WorldSpaceCenter(subject), WorldSpaceCenter(client));
} */

void ForcePlayerToDropFlag(int client)
{
	int item = TF2_GetItem(client);
	
	if (item != -1)
		AcceptEntityInput(item, "ForceDrop");
}

void SetWeaponCustomViewModel(int weapon, const char[] modelName)
{
	SetEntityModel(weapon, modelName);
	SetEntProp(weapon, Prop_Send, "m_iViewModelIndex", GetEntProp(weapon, Prop_Data, "m_nModelIndex"));
	SetEntProp(weapon, Prop_Send, "m_nCustomViewmodelModelIndex", GetEntProp(weapon, Prop_Data, "m_nModelIndex"));
}

void SetForcedTauntCam(int client, int value)
{
	SetVariantInt(value);
	AcceptEntityInput(client, "SetForcedTauntCam");
}

/* void SetPlayerViewModel(int client, const char[] modelName)
{
	int vm = GetEntPropEnt(client, Prop_Send, "m_hViewModel");
	
	if (vm != -1)
		SetEntityModel(vm, modelName);
} */

bool IsSpaceToSpawnOnTeleporter(const float where[3], float playerScale = 1.0, int iDebugClient = -1)
{
	float scaledVecHullMin[3]; scaledVecHullMin = TF_VEC_HULL_MIN;
	ScaleVector(scaledVecHullMin, playerScale);
	
	float scaledVecHullMax[3]; scaledVecHullMax = TF_VEC_HULL_MAX;
	ScaleVector(scaledVecHullMax, playerScale);
	
	const float bloat = 5.0;
	
	float mins[3];
	float bloatMin[3] = {bloat, bloat, 0.0};
	SubtractVectors(scaledVecHullMin, bloatMin, mins);
	
	float maxs[3];
	float bloatMax[3] = {bloat, bloat, bloat};
	AddVectors(scaledVecHullMax, bloatMax, maxs);
	
	Handle trace = TR_TraceHullFilterEx(where, where, mins, maxs, MASK_SOLID | CONTENTS_PLAYERCLIP, TraceFilter_RobotSpawn);
	
	if (TR_GetFraction(trace) >= 1.0)
	{
		CloseHandle(trace);
		return true;
	}
	
	CloseHandle(trace);
	
	if (iDebugClient > 0)
	{
		//Draw bounding box on failure
		DrawBoundingBox(mins, maxs, where, 0.2, {255, 0, 0, 255}, iDebugClient);
	}
	
	return false;
}

#if defined MOD_EXT_CBASENPC
void CalculateMeleeDamageForce(CTakeDamageInfo &info, const float vecMeleeDir[3], const float vecForceOrigin[3], float flScale)
{
	info.SetDamagePosition(vecForceOrigin);
	
	float flForceScale = info.GetBaseDamage() * ImpulseScale(75.0, 4.0);
	float vecForce[3]; vecForce = vecMeleeDir;
	NormalizeVector(vecForce, vecForce);
	ScaleVector(vecForce, flForceScale);
	ScaleVector(vecForce, phys_pushscale.FloatValue);
	ScaleVector(vecForce, flScale);
	info.SetDamageForce(vecForce);
}
#else
/* INPUTS:
- base damage
- melee direction
- force scale multiplier
- destination buffer to store the calculated damage force
vecForceOrigin is exempted as it only sets damage position, which can be passed outside this function */
void CalculateMeleeDamageForce(float baseDamage, const float vecMeleeDir[3], float flScale, float vecForceBuffer[3])
{
	float flForceScale = baseDamage * ImpulseScale(75, 4);
	vecForceBuffer = vecMeleeDir;
	NormalizeVector(vecForceBuffer, vecForceBuffer);
	ScaleVector(vecForceBuffer, flForceScale);
	ScaleVector(vecForceBuffer, phys_pushscale.FloatValue);
	ScaleVector(vecForceBuffer, flScale);
}
#endif

#if defined MOD_EXT_CBASENPC
bool TeleportNearVictim(int client, int victim, int attempt)
{
	if (!IsValidEntity(victim))
		return false;
	
	CNavArea lastKnownArea = CBaseCombatCharacter(victim).GetLastKnownArea();
	
	if (lastKnownArea == NULL_AREA)
		return false;
	
	ArrayList ambushVector = new ArrayList();
	
	const float maxSurroundTravelRange = 6000.0;
	
	float surroundTravelRange = 1500.0 + 500.0 * attempt;
	
	if (surroundTravelRange > maxSurroundTravelRange)
		surroundTravelRange = maxSurroundTravelRange;
	
	AreasCollector areaVector = TheNavMesh.CollectSurroundingAreas(lastKnownArea, surroundTravelRange, TFBOT_STEP_HEIGHT, TFBOT_STEP_HEIGHT);
	
	for (int j = 0; j < areaVector.Count(); j++)
	{
		CTFNavArea area = view_as<CTFNavArea>(areaVector.Get(j));
		
		if (!CTFNavArea_IsValidForWanderingPopulation(area))
			continue;
		
		if (CNavArea_IsPotentiallyVisibleToTeam(area, TF2_GetClientTeam(victim)))
			continue;
		
		ambushVector.Push(area);
	}
	
	delete areaVector;
	
	if (ambushVector.Length == 0)
	{
		delete ambushVector;
		return false;
	}
	
	int maxTries = MinInt(10, ambushVector.Length);
	
	for (int retry = 0; retry < maxTries; retry++)
	{
		int which = GetRandomInt(0, ambushVector.Length - 1);
		
		float where[3];
		CNavArea pArea = ambushVector.Get(which);
		pArea.GetCenter(where);
		where[2] += TFBOT_STEP_HEIGHT;
		
		if (IsSpaceToSpawnHere(where))
		{
			delete ambushVector;
			TeleportEntity(client, where, NULL_VECTOR, NULL_VECTOR);
			return true;
		}
	}
	
	delete ambushVector;
	
	return false;
}

/* bool FindEngineerBotHint(bool bShouldCheckForBlockingObjects, bool bAllowOutOfRangeNest, int &iFoundNest)
{
	ArrayList adtActiveEngineerNest = new ArrayList();
	
	int iEnt = -1;
	while ((iEnt = FindEntityByClassname(iEnt, "bot_hint_engineer_nest")) != -1)
	{
		if (GetEntProp(iEnt, Prop_Data, "m_isDisabled") != 1 && BaseEntity_GetOwnerEntity(iEnt) == -1)
			adtActiveEngineerNest.Push(iEnt);
	}
	
	if (adtActiveEngineerNest.Length == 0)
	{
		if (iFoundNest != -1)
			iFoundNest = -1
		
		return false;
	}
	
	//TODO: replace me with GetBombInfo stuff and JSONObject
	iFoundNest = adtActiveEngineerNest.Get(GetRandomInt(0, adtActiveEngineerNest.Length - 1));
	
	return true;
} */
#else
//TODO: alternative method
#endif

#if defined MOD_EXT_CBASENPC
bool CNavArea_IsPotentiallyVisibleToTeam(CNavArea area, TFTeam team)
{
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i) && TF2_GetClientTeam(i) == team && IsPlayerAlive(i))
		{
			CNavArea from = CBaseCombatCharacter(i).GetLastKnownArea();
			
			if (from != NULL_AREA && from.IsPotentiallyVisible(area))
				return true;
		}
	}
	
	return false;
}

bool CTFNavArea_IsValidForWanderingPopulation(CTFNavArea area)
{
	return !area.HasAttributeTF(BLOCKED | RED_SPAWN_ROOM | BLUE_SPAWN_ROOM | NO_SPAWNING | RESCUE_CLOSET);
}
#endif

// Taken from [TF2] Chaos Mod
static bool ItemFilterCriteria_FilterByName(int iItemDefIndex, DataPack hDataPack)
{
	hDataPack.Reset();
	
	char szName1[64];
	hDataPack.ReadString(szName1, sizeof(szName1));
	
	char szName2[64];
	if (TF2Econ_GetItemName(iItemDefIndex, szName2, sizeof(szName2)) && StrEqual(szName1, szName2, false))
	{
		return true;
	}
	
	return false;
}

stock void TF2_RefundPlayer(int client)
{
	SetEntProp(client, Prop_Send, "m_bInUpgradeZone", 1);
	
	KeyValues kv = new KeyValues("MVM_Respec");
	
	FakeClientCommandKeyValues(client, kv);
	delete kv;
	
	SetEntProp(client, Prop_Send, "m_bInUpgradeZone", 0);
}

stock void LogMVMRobotUnderground(int client)
{
	char playerName[MAX_NAME_LENGTH]; GetClientName(client, playerName, sizeof(playerName));
	char networkIDString[PLATFORM_MAX_PATH]; GetNetworkIDString(client, networkIDString, sizeof(networkIDString));
	char teamName[11]; GetTeamName(GetClientTeam(client), teamName, sizeof(teamName));
	float origin[3]; GetClientAbsOrigin(client, origin);
	
	LogMessage("\"%s<%i><%s><%s>\" underground (position \"%3.2f %3.2f %3.2f\")", playerName, GetClientUserId(client), networkIDString, teamName, origin[0], origin[1], origin[2]);
}

stock void GetNetworkIDString(int client, char[] buffer, int maxlen)
{
	if (IsFakeClient(client))
	{
		strcopy(buffer, maxlen, "BOT");
		return;
	}
	
	if (IsClientSourceTV(client))
		strcopy(buffer, maxlen, "HLTV");
	else if (IsClientReplay(client))
		strcopy(buffer, maxlen, "REPLAY");
	else if (!GetClientAuthId(client, AuthId_Steam3, buffer, maxlen))
		strcopy(buffer, maxlen, "UNKNOWN");
}

stock float ImpulseScale(float flTargetMass, float flDesiredSpeed)
{
	return flTargetMass * flDesiredSpeed;
}

stock void SendTauntCommand(int client)
{
	FakeClientCommand(client, "taunt");
}

stock bool IsMeleeWeapon(int entity)
{
	return HasEntProp(entity, Prop_Data, "CTFWeaponBaseMeleeSmack");
}

stock int GetEnemyPlayerNearestToMe(int client, float max_distance = 999999.0)
{
	float vecOrigin[3]; GetClientAbsOrigin(client, vecOrigin);
	
	float flBestDistance = 999999.0;
	int iBestEntity = -1;
	float vecEnemyOrigin[3];
	
	for (int i = 1; i <= MaxClients; i++)
	{
		if (i == client)
			continue;
		
		if (!IsClientInGame(i))
			continue;
		
		if (!IsPlayerAlive(i))
			continue;
		
		if (GetClientTeam(i) == GetClientTeam(client))
			continue;
		
		GetClientAbsOrigin(i, vecEnemyOrigin);
		
		float flDistance = GetVectorDistance(vecEnemyOrigin, vecOrigin);
		
		if (flDistance <= flBestDistance && flDistance <= max_distance)
		{
			flBestDistance = flDistance;
			iBestEntity = i;
		}
	}
	
	return iBestEntity;
}

/* Unlike TF2_SetPlayerClass, this forces the class to be initialized
CTFPlayer::ForceRespawn > GetPlayerClass()->Init( iDesiredClass ); */
stock void Player_JoinClass(int client, TFClassType classType, bool allowSpawn = true)
{
	SetEntProp(client, Prop_Send, "m_iDesiredPlayerClass", view_as<int>(classType));
	
	Event hEvent = CreateEvent("player_changeclass");
	if (hEvent)
	{
		hEvent.SetInt("userid", GetClientUserId(client));
		hEvent.SetInt("class", view_as<int>(classType));
		hEvent.Fire();
	}
	
	if (allowSpawn)
		TF2_RespawnPlayer(client);
}

stock int RetardedGetItemDefinitionByName(const char[] pszDefName)
{
	if (StrEqual(pszDefName, "TF_WEAPON_BAT", false))
		return 0;
	
	if (StrEqual(pszDefName, "TF_WEAPON_BOTTLE", false))
		return 1;
	
	if (StrEqual(pszDefName, "TF_WEAPON_FIREAXE", false))
		return 2;
	
	if (StrEqual(pszDefName, "TF_WEAPON_FIREAXE", false))
		return 2;
	
	//TODO: fuck no
	
	return -1;
}

stock void SnapViewToPosition(int iClient, const float fPos[3])
{
	float clientEyePos[3]; GetClientEyePosition(iClient, clientEyePos);
	
	float fDesiredDir[3]; MakeVectorFromPoints(clientEyePos, fPos, fDesiredDir);
	GetVectorAngles(fDesiredDir, fDesiredDir);

	float clientEyeAng[3]; GetClientEyeAngles(iClient, clientEyeAng);
	
	float fEyeAngles[3];
	fEyeAngles[0] = (clientEyeAng[0] + NormalizeAngle(fDesiredDir[0] - clientEyeAng[0]));
	fEyeAngles[1] = (clientEyeAng[1] + NormalizeAngle(fDesiredDir[1] - clientEyeAng[1]));
	fEyeAngles[2] = 0.0;

	TeleportEntity(iClient, NULL_VECTOR, fEyeAngles, NULL_VECTOR);
}

stock float NormalizeAngle(float fAngle)
{
	fAngle = (fAngle - RoundToFloor(fAngle / 360.0) * 360.0);
	if (fAngle > 180.0)fAngle -= 360.0;
	else if (fAngle < -180.0)fAngle += 360.0;
	return fAngle;
}

stock void SetClientAsBot(int client, bool bValue)
{
	int flags = GetEntityFlags(client);
	SetEntityFlags(client, bValue ? flags | FL_FAKECLIENT : flags & ~FL_FAKECLIENT);
}

stock void StopParticleEffects(int entity)
{
	SetVariantString("ParticleEffectStop");
	AcceptEntityInput(entity, "DispatchEffect");
}

stock bool IsItemDefIndexSapper(int itemDefIndex)
{
	switch (itemDefIndex)
	{
		case 735, 736, 810, 831, 933, 1080, 1102:
		{
			return true;
		}
	}
	
	return false;
}

stock void SetTeamNumber(int entity, TFTeam team)
{
	SetEntProp(entity, Prop_Send, "m_iTeamNum", team);
}

stock int GetGroundEntity(int entity)
{
	return GetEntPropEnt(entity, Prop_Data, "m_hGroundEntity");
}

stock bool IsZeroVector(float origin[3])
{
	return origin[0] == NULL_VECTOR[0] && origin[1] == NULL_VECTOR[1] && origin[2] == NULL_VECTOR[2];
}

stock bool RollRandomChanceFloat(float percent)
{
	return GetRandomFloat(1.0, 100.0) <= percent;
}

stock bool IsProjectileArrow(int entity)
{
	return HasEntProp(entity, Prop_Send, "m_bArrowAlight");
}

stock void SetTeamRespawnWaveTime(TFTeam team, float value)
{
	if (team < TFTeam_Red)
		ThrowError("Team %d is not a valid playing team!", team);
	
	int gamerules = FindEntityByClassname(-1, "tf_gamerules");
	
	if (gamerules == -1)
	{
		LogError("SetTeamRespawnWaveTime: Could not find entity tf_gamerules!");
		return;
	}
	
	switch (team)
	{
		case TFTeam_Red:
		{
			SetVariantFloat(value);
			AcceptEntityInput(gamerules, "SetRedTeamRespawnWaveTime");
		}
		case TFTeam_Blue:
		{
			SetVariantFloat(value);
			AcceptEntityInput(gamerules, "SetBlueTeamRespawnWaveTime");
		}
	}
}

stock void BlockAttackForDuration(int client, float duration)
{
	SetEntPropFloat(client, Prop_Send, "m_flStealthNoAttackExpire", GetGameTime() + duration);
}

//Taken from SourceMod Anti-Cheat
stock bool ArePointsWithinFieldOfView(const float start[3], const float angles[3], const float end[3])
{
    float normal[3], plane[3];

    GetAngleVectors(angles, normal, NULL_VECTOR, NULL_VECTOR);
    SubtractVectors(end, start, plane);
    NormalizeVector(plane, plane);
    
    return GetVectorDotProduct(plane, normal) > 0.0; // Cosine(Deg2Rad(179.9 / 2.0))
}

stock int GetRandomLivingPlayerFromTeam(TFTeam team, int excludePlayer = -1)
{
	int total = 0;
	int[] arrPlayers = new int[MaxClients];
	
	for (int i = 1; i <= MaxClients; i++)
	{
		if (i == excludePlayer)
			continue;
		
		if (!IsClientInGame(i))
			continue;
		
		if (TF2_GetClientTeam(i) != team)
			continue;
		
		if (!IsPlayerAlive(i))
			continue;
		
		arrPlayers[total++] = i;
	}
	
	if (total > 0)
		return arrPlayers[GetRandomInt(0, total - 1)];
	
	return -1;
}

stock int GetLivingClientCountOnTeam(TFTeam team)
{
	int count = 0;
	
	for (int i = 1; i <= MaxClients; i++)
	{
		if (!IsClientInGame(i))
			continue;
		
		if (TF2_GetClientTeam(i) != team)
			continue;
		
		if (!IsPlayerAlive(i))
			continue;
		
		count++;
	}
	
	return count;
}

stock bool IsEntityATrigger(int entity)
{
	//TODO: this isn't a reliable way to check for CBaseTrigger
	char classname[PLATFORM_MAX_PATH];
	
	if (!GetEdictClassname(entity, classname, sizeof(classname)))
		return false;
	
	return StrContains(classname, "trigger_", false) != -1;
}

//Modified function from Parkour Fortress: Redux
stock void DrawBoundingBox(const float vecMins[3], const float vecMaxs[3], const float vecOrigin[3], float flDuration = 10.0, int rgbColor[4] = {255, 0, 0, 255}, int iShowToWho = -1)
{
	float vecRelMinsSub1[3], vecRelMinsSub2[3], vecRelMinsSub3[3], vecRelMinsSub4[3];
	float vecRelMaxsSub1[3], vecRelMaxsSub2[3], vecRelMaxsSub3[3], vecRelMaxsSub4[3];
	
	AddVectors(vecOrigin, vecMins, vecRelMinsSub1);
	
	vecRelMinsSub2[0] = vecMins[0];
	vecRelMinsSub2[1] = -vecMins[1];
	vecRelMinsSub2[2] = vecMins[2];
	AddVectors(vecOrigin, vecRelMinsSub2, vecRelMinsSub2);
	
	vecRelMinsSub3[0] = -vecMins[0];
	vecRelMinsSub3[1] = -vecMins[1];
	vecRelMinsSub3[2] = vecMins[2];
	AddVectors(vecOrigin, vecRelMinsSub3, vecRelMinsSub3);
	
	vecRelMinsSub4[0] = -vecMins[0];
	vecRelMinsSub4[1] = vecMins[1];
	vecRelMinsSub4[2] = vecMins[2];
	AddVectors(vecOrigin, vecRelMinsSub4, vecRelMinsSub4);
	
	AddVectors(vecOrigin, vecMaxs, vecRelMaxsSub1);
	
	vecRelMaxsSub2[0] = vecMaxs[0];
	vecRelMaxsSub2[1] = -vecMaxs[1];
	vecRelMaxsSub2[2] = vecMaxs[2];
	AddVectors(vecOrigin, vecRelMaxsSub2, vecRelMaxsSub2);
	
	vecRelMaxsSub3[0] = -vecMaxs[0];
	vecRelMaxsSub3[1] = -vecMaxs[1];
	vecRelMaxsSub3[2] = vecMaxs[2];
	AddVectors(vecOrigin, vecRelMaxsSub3, vecRelMaxsSub3);
	
	vecRelMaxsSub4[0] = -vecMaxs[0];
	vecRelMaxsSub4[1] = vecMaxs[1];
	vecRelMaxsSub4[2] = vecMaxs[2];
	AddVectors(vecOrigin, vecRelMaxsSub4, vecRelMaxsSub4);
	
	DrawVectorPoints(vecRelMinsSub1, vecRelMaxsSub3, flDuration, rgbColor, _, iShowToWho);
	DrawVectorPoints(vecRelMinsSub1, vecRelMaxsSub4, flDuration, rgbColor, _, iShowToWho);
	DrawVectorPoints(vecRelMinsSub1, vecRelMaxsSub2, flDuration, rgbColor, _, iShowToWho);
	
	DrawVectorPoints(vecRelMinsSub1, vecRelMinsSub2, flDuration, rgbColor, _, iShowToWho);
	DrawVectorPoints(vecRelMinsSub1, vecRelMinsSub3, flDuration, rgbColor, _, iShowToWho);
	DrawVectorPoints(vecRelMinsSub1, vecRelMinsSub4, flDuration, rgbColor, _, iShowToWho);
	
	DrawVectorPoints(vecRelMinsSub2, vecRelMaxsSub1, flDuration, rgbColor, _, iShowToWho);
	DrawVectorPoints(vecRelMinsSub2, vecRelMaxsSub4, flDuration, rgbColor, _, iShowToWho);
	
	DrawVectorPoints(vecRelMinsSub2, vecRelMinsSub3, flDuration, rgbColor, _, iShowToWho);
	
	DrawVectorPoints(vecRelMinsSub3, vecRelMaxsSub1, flDuration, rgbColor, _, iShowToWho);
	DrawVectorPoints(vecRelMinsSub3, vecRelMaxsSub2, flDuration, rgbColor, _, iShowToWho);
	
	DrawVectorPoints(vecRelMinsSub3, vecRelMinsSub4, flDuration, rgbColor, _, iShowToWho);
	
	DrawVectorPoints(vecRelMinsSub4, vecRelMaxsSub2, flDuration, rgbColor, _, iShowToWho);
	
	DrawVectorPoints(vecRelMaxsSub1, vecRelMaxsSub2, flDuration, rgbColor, _, iShowToWho);
	DrawVectorPoints(vecRelMaxsSub1, vecRelMaxsSub3, flDuration, rgbColor, _, iShowToWho);
	DrawVectorPoints(vecRelMaxsSub1, vecRelMaxsSub4, flDuration, rgbColor, _, iShowToWho);
	
	DrawVectorPoints(vecRelMaxsSub2, vecRelMaxsSub3, flDuration, rgbColor, _, iShowToWho);
	
	DrawVectorPoints(vecRelMaxsSub3, vecRelMaxsSub4, flDuration, rgbColor, _, iShowToWho);
}

//Modified function from Parkour Fortress: Redux
stock void DrawVectorPoints(float vecOrigin[3], float vecEndpoint[3], float flLifespan, int iColor[4], float flWidth = 3.0, int iSendToWho = -1)
{
	TE_SetupBeamPoints(vecOrigin, vecEndpoint, PrecacheModel("materials/sprites/laser.vmt"), 0, 0, 0, flLifespan, flWidth, 3.0, 1, 0.0, iColor, 0);
	
	if (iSendToWho > 0)
		TE_SendToClient(iSendToWho);
	else
		TE_SendToAll();
}

stock int GetTeamHumanClientCount(TFTeam team)
{
	int count = 0;
	
	for (int i = 1; i <= MaxClients; i++)
		if (IsClientInGame(i) && !IsFakeClient(i) && TF2_GetClientTeam(i) == team)
			count++;
	
	return count;
}

stock bool IsLeftForInvasionMode()
{
	ConVar cvar = FindConVar("sm_bar3_gamemode");
	bool isEnabled = cvar ? cvar.IntValue == 1 : false;
	
	delete cvar;
	
	return isEnabled;
}

stock void SendBuildCommand(int client, TFObjectType type, TFObjectMode mode = TFObjectMode_None)
{
	FakeClientCommand(client, "build %d %d", type, mode);
}

stock void ShowAnnotationToClient(int client, char[] message, int target, float duration, char[] sound = "")
{
	Event event = CreateEvent("show_annotation");
	event.SetInt("id", target);
	event.SetInt("follow_entindex", target);
	event.SetFloat("lifetime", duration);
	event.SetString("text", message);
	event.SetString("play_sound", sound);
	event.FireToClient(client);
	event.Cancel();
}

stock int GetPlayerBuilding(int client, TFObjectType type, TFObjectMode mode = TFObjectMode_None)
{
	for (int i = 0; i < TF2Util_GetPlayerObjectCount(client); i++)
	{
		int building = TF2Util_GetPlayerObject(client, i);
		
		if (TF2_GetObjectType(building) != type)
			continue;
		
		if (mode > TFObjectMode_None && TF2_GetObjectMode(building) != mode)
			continue;
		
		return building;
	}
	
	return -1;
}