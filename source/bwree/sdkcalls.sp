enum PlayerAnimEvent_t
{
	PLAYERANIMEVENT_ATTACK_PRIMARY,
	PLAYERANIMEVENT_ATTACK_SECONDARY,
	PLAYERANIMEVENT_ATTACK_GRENADE,
	PLAYERANIMEVENT_RELOAD,
	PLAYERANIMEVENT_RELOAD_LOOP,
	PLAYERANIMEVENT_RELOAD_END,
	PLAYERANIMEVENT_JUMP,
	PLAYERANIMEVENT_SWIM,
	PLAYERANIMEVENT_DIE,
	PLAYERANIMEVENT_FLINCH_CHEST,
	PLAYERANIMEVENT_FLINCH_HEAD,
	PLAYERANIMEVENT_FLINCH_LEFTARM,
	PLAYERANIMEVENT_FLINCH_RIGHTARM,
	PLAYERANIMEVENT_FLINCH_LEFTLEG,
	PLAYERANIMEVENT_FLINCH_RIGHTLEG,
	PLAYERANIMEVENT_DOUBLEJUMP,
	PLAYERANIMEVENT_CANCEL,
	PLAYERANIMEVENT_SPAWN,
	PLAYERANIMEVENT_SNAP_YAW,
	PLAYERANIMEVENT_CUSTOM,
	PLAYERANIMEVENT_CUSTOM_GESTURE,
	PLAYERANIMEVENT_CUSTOM_SEQUENCE,
	PLAYERANIMEVENT_CUSTOM_GESTURE_SEQUENCE,
	PLAYERANIMEVENT_ATTACK_PRE,
	PLAYERANIMEVENT_ATTACK_POST,
	PLAYERANIMEVENT_GRENADE1_DRAW,
	PLAYERANIMEVENT_GRENADE2_DRAW,
	PLAYERANIMEVENT_GRENADE1_THROW,
	PLAYERANIMEVENT_GRENADE2_THROW,
	PLAYERANIMEVENT_VOICE_COMMAND_GESTURE,
	PLAYERANIMEVENT_DOUBLEJUMP_CROUCH,
	PLAYERANIMEVENT_STUN_BEGIN,
	PLAYERANIMEVENT_STUN_MIDDLE,
	PLAYERANIMEVENT_STUN_END,
	PLAYERANIMEVENT_PASSTIME_THROW_BEGIN,
	PLAYERANIMEVENT_PASSTIME_THROW_MIDDLE,
	PLAYERANIMEVENT_PASSTIME_THROW_END,
	PLAYERANIMEVENT_PASSTIME_THROW_CANCEL,
	PLAYERANIMEVENT_ATTACK_PRIMARY_SUPER,
	PLAYERANIMEVENT_COUNT
};

static Handle m_hPlaySpecificSequence;
static Handle m_hDoAnimationEvent;
static Handle m_hCapture;
static Handle m_hPlayThrottledAlert;
static Handle m_hPostInventoryApplication;
static Handle m_hGetSentryBusterDamageAndKillThreshold;
static Handle m_hRemoveObject;
static Handle m_hGetCurrentWave;
static Handle m_hDropCurrencyPack;
static Handle m_hDistributeCurrencyAmount;
static Handle m_hClip1;
static Handle m_hPickup;
static Handle m_hShouldCollide;

bool InitSDKCalls(GameData hGamedata)
{
	int iFailCount = 0;
	
	StartPrepSDKCall(SDKCall_Player);
	PrepSDKCall_SetFromConf(hGamedata, SDKConf_Signature, "CTFPlayer::PlaySpecificSequence");
	PrepSDKCall_AddParameter(SDKType_String, SDKPass_Pointer);
	if ((m_hPlaySpecificSequence = EndPrepSDKCall()) == null)
	{
		LogError("Failed to create SDKCall for CTFPlayer::PlaySpecificSequence!");
		iFailCount++;
	}
	
	StartPrepSDKCall(SDKCall_Player);
	PrepSDKCall_SetFromConf(hGamedata, SDKConf_Signature, "CTFPlayer::DoAnimationEvent");
	PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);
	PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);
	if ((m_hDoAnimationEvent = EndPrepSDKCall()) == null)
	{
		LogError("Failed to create SDKCall for CTFPlayer::DoAnimationEvent!");
		iFailCount++;
	}
	
	StartPrepSDKCall(SDKCall_Entity);
	PrepSDKCall_SetFromConf(hGamedata, SDKConf_Signature, "CCaptureZone::Capture");
	PrepSDKCall_AddParameter(SDKType_CBaseEntity, SDKPass_Pointer);
	if ((m_hCapture = EndPrepSDKCall()) == null)
	{
		LogError("Failed to create SDKCall for CCaptureZone::Capture!");
		iFailCount++;
	}
	
	StartPrepSDKCall(SDKCall_GameRules);
	PrepSDKCall_SetFromConf(hGamedata, SDKConf_Signature, "CTeamplayRoundBasedRules::PlayThrottledAlert");
	PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);
	PrepSDKCall_AddParameter(SDKType_String, SDKPass_Pointer);
	PrepSDKCall_AddParameter(SDKType_Float, SDKPass_Plain);
	PrepSDKCall_SetReturnInfo(SDKType_Bool, SDKPass_Plain);
	if ((m_hPlayThrottledAlert = EndPrepSDKCall()) == null)
	{
		LogError("Failed to create SDKCall for CTeamplayRoundBasedRules::PlayThrottledAlert!");
		iFailCount++;
	}
	
	StartPrepSDKCall(SDKCall_Player);
	PrepSDKCall_SetFromConf(hGamedata, SDKConf_Signature, "CTFPlayer::PostInventoryApplication");
	if ((m_hPostInventoryApplication = EndPrepSDKCall()) == null)
	{
		LogError("Failed to create SDKCall for CTFPlayer::PostInventoryApplication!");
		iFailCount++;
	}
	
	StartPrepSDKCall(SDKCall_Entity);
	PrepSDKCall_SetFromConf(hGamedata, SDKConf_Signature, "CPopulationManager::GetSentryBusterDamageAndKillThreshold");
	PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_ByRef, _, VENCODE_FLAG_COPYBACK);
	PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_ByRef, _, VENCODE_FLAG_COPYBACK);
	if ((m_hGetSentryBusterDamageAndKillThreshold = EndPrepSDKCall()) == null)
	{
		LogError("Failed To create SDKCall for CPopulationManager::GetSentryBusterDamageAndKillThreshold!");
		iFailCount++;
	}
	
	StartPrepSDKCall(SDKCall_Player);
	PrepSDKCall_SetFromConf(hGamedata, SDKConf_Signature, "CTFPlayer::RemoveObject");
	PrepSDKCall_AddParameter(SDKType_CBaseEntity, SDKPass_Pointer);
	if ((m_hRemoveObject = EndPrepSDKCall()) == null)
	{
		LogError("Failed To create SDKCall for CTFPlayer::RemoveObject!");
		iFailCount++;
	}
	
	StartPrepSDKCall(SDKCall_Entity);
	PrepSDKCall_SetFromConf(hGamedata, SDKConf_Signature, "CPopulationManager::GetCurrentWave");
	PrepSDKCall_SetReturnInfo(SDKType_PlainOldData, SDKPass_Plain);
	if ((m_hGetCurrentWave = EndPrepSDKCall()) == null)
	{
		LogError("Failed To create SDKCall for CPopulationManager::GetCurrentWave!");
		iFailCount++;
	}
	
	StartPrepSDKCall(SDKCall_Player);
	PrepSDKCall_SetFromConf(hGamedata, SDKConf_Signature, "CTFPlayer::DropCurrencyPack");
	PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_ByValue);
	PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);
	PrepSDKCall_AddParameter(SDKType_Bool, SDKPass_Plain);
	PrepSDKCall_AddParameter(SDKType_CBasePlayer, SDKPass_Pointer, VDECODE_FLAG_ALLOWNULL);
	if ((m_hDropCurrencyPack = EndPrepSDKCall()) == null)
	{
		LogError("Failed to create SDKCall for CTFPlayer::DropCurrencyPack!");
		iFailCount++;
	}
	
	StartPrepSDKCall(SDKCall_GameRules);
	PrepSDKCall_SetFromConf(hGamedata, SDKConf_Signature, "CTFGameRules::DistributeCurrencyAmount");
	PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);
	PrepSDKCall_AddParameter(SDKType_CBasePlayer, SDKPass_Pointer, VDECODE_FLAG_ALLOWNULL);
	PrepSDKCall_AddParameter(SDKType_Bool, SDKPass_ByValue);
	PrepSDKCall_AddParameter(SDKType_Bool, SDKPass_ByValue);
	PrepSDKCall_AddParameter(SDKType_Bool, SDKPass_ByValue);
	PrepSDKCall_SetReturnInfo(SDKType_PlainOldData, SDKPass_Plain);
	if ((m_hDistributeCurrencyAmount = EndPrepSDKCall()) == null)
	{
		LogError("Failed to create SDKCall for CTFGameRules::DistributeCurrencyAmount!");
		iFailCount++;
	}
	
	StartPrepSDKCall(SDKCall_Entity);
	PrepSDKCall_SetFromConf(hGamedata, SDKConf_Virtual, "CTFWeaponBase::Clip1");
	PrepSDKCall_SetReturnInfo(SDKType_PlainOldData, SDKPass_Plain);
	if ((m_hClip1 = EndPrepSDKCall()) == null)
	{
		LogError("Failed to create SDKCall for CTFWeaponBase::Clip1!");
		iFailCount++;
	}
	
	StartPrepSDKCall(SDKCall_Entity);
	PrepSDKCall_SetFromConf(hGamedata, SDKConf_Virtual, "CTFItem::PickUp");
	PrepSDKCall_AddParameter(SDKType_CBasePlayer, SDKPass_Pointer);
	PrepSDKCall_AddParameter(SDKType_Bool, SDKPass_Plain);
	if ((m_hPickup = EndPrepSDKCall()) == null)
	{
		LogError("Failed to create SDKCall for CTFItem::PickUp!");
		iFailCount++;
	}
	
	const char sTempConfFileName[] = "sdkhooks.games/engine.ep2v";
	GameData hTempConf = new GameData(sTempConfFileName);
	
	StartPrepSDKCall(SDKCall_Entity);
	PrepSDKCall_SetFromConf(hTempConf, SDKConf_Virtual, "ShouldCollide");
	PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);
	PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);
	PrepSDKCall_SetReturnInfo(SDKType_Bool, SDKPass_ByValue);
	if ((m_hShouldCollide = EndPrepSDKCall()) == null)
	{
		LogError("Failed to create SDKCall for CBaseEntity::ShouldCollide from file %s.txt", sTempConfFileName);
		iFailCount++;
	}
	
	hTempConf.Close();
	
	if (iFailCount > 0)
	{
		LogError("InitSDKCalls: GameData file has %d problems!", iFailCount);
		return false;
	}
	
	return true;
}

void PlaySpecificSequence(int client, const char[] pAnimationName)
{
	SDKCall(m_hPlaySpecificSequence, client, pAnimationName);
}

void DoAnimationEvent(int client, PlayerAnimEvent_t event, int nData = 0)
{
	SDKCall(m_hDoAnimationEvent, client, event, nData);
}

void CaptureZoneCapture(int zone, int pOther)
{
	SDKCall(m_hCapture, zone, pOther);
}

/* We actually don't need this as we can just fire the event from CTeamplayRoundBasedRules::BroadcastSound
However this is done so variable m_flNewThrottledAlertTime is updated within the game appropriately

Alternatively we can just hook event teamplay_broadcast_audio and do our own time shit and block
it whenever but at that point we're just making things more complicated than they have to be */
bool PlayThrottledAlert(int iTeam, const char[] sound, float fDelayBeforeNext)
{
	return SDKCall(m_hPlayThrottledAlert, iTeam, sound, fDelayBeforeNext);
}

void PostInventoryApplication(int client)
{
	SDKCall(m_hPostInventoryApplication, client);
}

void GetSentryBusterDamageAndKillThreshold(int populator, int &nDamage, int &nKills)
{
	SDKCall(m_hGetSentryBusterDamageAndKillThreshold, populator, nDamage, nKills);
}

void RemoveObject(int client, int pObject)
{
	SDKCall(m_hRemoveObject, client, pObject);
}

Address GetCurrentWave(int populator)
{
	return SDKCall(m_hGetCurrentWave, populator);
}

void DropCurrencyPack(int client, CurrencyRewards_t nSize = TF_CURRENCY_PACK_SMALL, int nAmount = 0, bool bForceDistribute = false, int pMoneyMaker = -1)
{
	SDKCall(m_hDropCurrencyPack, client, nSize, nAmount, bForceDistribute, pMoneyMaker);
}

int DistributeCurrencyAmount(int nAmount, int pTFPlayer = -1, bool bShared = true, bool bCountAsDropped = false, bool bIsBonus = false)
{
	return SDKCall(m_hDistributeCurrencyAmount, nAmount, pTFPlayer, bShared, bCountAsDropped, bIsBonus);
}

int Clip1(int weapon)
{
	return SDKCall(m_hClip1, weapon);
}

void CTFItemPickup(int item, int pPlayer, bool bInvisible)
{
	SDKCall(m_hPickup, item, pPlayer, bInvisible);
}

bool ShouldCollide(int entity, int collisionGroup, int contentsMask)
{
	return SDKCall(m_hShouldCollide, entity, collisionGroup, contentsMask);
}