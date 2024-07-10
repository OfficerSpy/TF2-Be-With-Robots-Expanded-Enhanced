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
static Handle m_hRemoveObject;
static Handle m_hDropCurrencyPack;
static Handle m_hGetSentryBusterDamageAndKillThreshold;
static Handle m_hClip1;
static Handle m_hMaxClip1;

bool InitSDKCalls(GameData hGamedata)
{
	int failCount = 0;
	
	StartPrepSDKCall(SDKCall_Player);
	PrepSDKCall_SetFromConf(hGamedata, SDKConf_Signature, "CTFPlayer::PlaySpecificSequence");
	PrepSDKCall_AddParameter(SDKType_String, SDKPass_Pointer);
	if ((m_hPlaySpecificSequence = EndPrepSDKCall()) == null)
	{
		LogError("Failed to create SDKCall for CTFPlayer::PlaySpecificSequence!");
		failCount++;
	}
	
	StartPrepSDKCall(SDKCall_Player);
	PrepSDKCall_SetFromConf(hGamedata, SDKConf_Signature, "CTFPlayer::DoAnimationEvent");
	PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);
	PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);
	if ((m_hDoAnimationEvent = EndPrepSDKCall()) == null)
	{
		LogError("Failed to create SDKCall for CTFPlayer::DoAnimationEvent!");
		failCount++;
	}
	
	StartPrepSDKCall(SDKCall_Entity);
	PrepSDKCall_SetFromConf(hGamedata, SDKConf_Signature, "CCaptureZone::Capture");
	PrepSDKCall_AddParameter(SDKType_CBaseEntity, SDKPass_Pointer);
	if ((m_hCapture = EndPrepSDKCall()) == null)
	{
		LogError("Failed to create SDKCall for CCaptureZone::Capture!");
		failCount++;
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
		failCount++;
	}
	
	StartPrepSDKCall(SDKCall_Player);
	PrepSDKCall_SetFromConf(hGamedata, SDKConf_Signature, "CTFPlayer::PostInventoryApplication");
	if ((m_hPostInventoryApplication = EndPrepSDKCall()) == null)
	{
		LogError("Failed to create SDKCall for CTFPlayer::PostInventoryApplication!");
		failCount++;
	}
	
	StartPrepSDKCall(SDKCall_Entity);
	PrepSDKCall_SetFromConf(hGamedata, SDKConf_Signature, "CPopulationManager::GetSentryBusterDamageAndKillThreshold");
	PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_ByRef, _, VENCODE_FLAG_COPYBACK);
	PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_ByRef, _, VENCODE_FLAG_COPYBACK);
	if ((m_hGetSentryBusterDamageAndKillThreshold = EndPrepSDKCall()) == null)
	{
		LogError("Failed To create SDKCall for CPopulationManager::GetSentryBusterDamageAndKillThreshold!");
		failCount++;
	}
	
	StartPrepSDKCall(SDKCall_Player);
	PrepSDKCall_SetFromConf(hGamedata, SDKConf_Signature, "CTFPlayer::RemoveObject");
	PrepSDKCall_AddParameter(SDKType_CBaseEntity, SDKPass_Pointer);
	if ((m_hRemoveObject = EndPrepSDKCall()) == null)
	{
		LogError("Failed To create SDKCall for CTFPlayer::RemoveObject!");
		failCount++;
	}
	
	StartPrepSDKCall(SDKCall_Player);
	PrepSDKCall_SetFromConf(hGamedata, SDKConf_Signature, "CTFPlayer::DropCurrencyPack");
	PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_ByValue);
	PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);
	PrepSDKCall_AddParameter(SDKType_Bool, SDKPass_Plain);
	PrepSDKCall_AddParameter(SDKType_CBasePlayer, SDKPass_Pointer);
	if ((m_hDropCurrencyPack = EndPrepSDKCall()) == null)
	{
		LogError("Failed to create SDKCall for CTFPlayer::DropCurrencyPack!");
		failCount++;
	}
	
	StartPrepSDKCall(SDKCall_Entity);
	PrepSDKCall_SetFromConf(hGamedata, SDKConf_Virtual, "CTFWeaponBase::Clip1");
	PrepSDKCall_SetReturnInfo(SDKType_PlainOldData, SDKPass_Plain);
	if ((m_hClip1 = EndPrepSDKCall()) == null)
	{
		LogError("Failed to create SDKCall for CTFWeaponBase::Clip1!");
		failCount++;
	}
	
	StartPrepSDKCall(SDKCall_Entity);
	PrepSDKCall_SetFromConf(hGamedata, SDKConf_Virtual, "CTFWeaponBase::GetMaxClip1");
	PrepSDKCall_SetReturnInfo(SDKType_PlainOldData, SDKPass_Plain);
	if ((m_hMaxClip1 = EndPrepSDKCall()) == null)
	{
		LogError("Failed to create SDKCall for CTFWeaponBase::GetMaxClip1!");
		failCount++;
	}
	
	if (failCount > 0)
	{
		LogError("InitSDKCalls: GameData file has %d problems!", failCount);
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

void DropCurrencyPack(int client, CurrencyRewards_t nSize = TF_CURRENCY_PACK_SMALL, int nAmount = 0, bool bForceDistribute = false, int pMoneyMaker = -1)
{
	SDKCall(m_hDropCurrencyPack, client, nSize, nAmount, bForceDistribute, pMoneyMaker);
}

int Clip1(int weapon)
{
	return SDKCall(m_hClip1, weapon);
}

int GetMaxClip1(int weapon)
{
	return SDKCall(m_hMaxClip1, weapon);
}