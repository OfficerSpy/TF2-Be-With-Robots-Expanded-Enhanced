/* Used for offset calculations
https://github.com/Mikusch/MannVsMann/blob/571737b5ae0aadc1e743360e94311ca64e693bd9/addons/sourcemod/gamedata/mannvsmann.txt */
static StringMap m_adtOffsets;

void InitOffsets(GameData hGamedata)
{
	m_adtOffsets = new StringMap();
	
	SetOffset(hGamedata, "CTFPlayer", "m_nDeployingBombState");
	SetOffset(hGamedata, "CTFPlayer", "m_bIsMissionEnemy");
	SetOffset(hGamedata, "CTFPlayer", "m_bIsSupportEnemy");
	SetOffset(hGamedata, "CTFPlayer", "m_accumulatedSentryGunDamageDealt");
	SetOffset(hGamedata, "CTFPlayer", "m_accumulatedSentryGunKillCount");
	SetOffset(hGamedata, "CPopulationManager", "m_nMvMEventPopfileType");
	SetOffset(hGamedata, "CPopulationManager", "m_canBotsAttackWhileInSpawnRoom");
	SetOffset(hGamedata, "CPopulationManager", "m_bSpawningPaused");
	SetOffset(hGamedata, "CBaseObject", "m_vecBuildOrigin");
	SetOffset(hGamedata, "CWave", "m_nSentryBustersSpawned");
	SetOffset(hGamedata, "CWave", "m_nNumEngineersTeleportSpawned");
	SetOffset(hGamedata, "CWave", "m_nNumSentryBustersKilled");
	SetOffset(hGamedata, "CTFNavArea", "m_distanceToBombTarget");
	
#if defined TESTING_ONLY
	//Dump offsets
	LogMessage("InitOffsets: CTFPlayer->m_nDeployingBombState = %d", GetOffset("CTFPlayer", "m_nDeployingBombState"));
	LogMessage("InitOffsets: CTFPlayer->m_bIsMissionEnemy = %d", GetOffset("CTFPlayer", "m_bIsMissionEnemy"));
	LogMessage("InitOffsets: CTFPlayer->m_bIsSupportEnemy = %d", GetOffset("CTFPlayer", "m_bIsSupportEnemy"));
	LogMessage("InitOffsets: CTFPlayer->m_accumulatedSentryGunDamageDealt = %d", GetOffset("CTFPlayer", "m_accumulatedSentryGunDamageDealt"));
	LogMessage("InitOffsets: CTFPlayer->m_accumulatedSentryGunKillCount = %d", GetOffset("CTFPlayer", "m_accumulatedSentryGunKillCount"));
	LogMessage("InitOffsets: CPopulationManager->m_nMvMEventPopfileType = %d", GetOffset("CPopulationManager", "m_nMvMEventPopfileType"));
	LogMessage("InitOffsets: CPopulationManager->m_canBotsAttackWhileInSpawnRoom = %d", GetOffset("CPopulationManager", "m_canBotsAttackWhileInSpawnRoom"));
	LogMessage("InitOffsets: CPopulationManager->m_bSpawningPaused = %d", GetOffset("CPopulationManager", "m_bSpawningPaused"));
	LogMessage("InitOffsets: CBaseObject->m_vecBuildOrigin = %d", GetOffset("CBaseObject", "m_vecBuildOrigin"));
	LogMessage("InitOffsets: CWave->m_nSentryBustersSpawned = %d", GetOffset("CWave", "m_nSentryBustersSpawned"));
	LogMessage("InitOffsets: CWave->m_nNumEngineersTeleportSpawned = %d", GetOffset("CWave", "m_nNumEngineersTeleportSpawned"));
	LogMessage("InitOffsets: CWave->m_nNumSentryBustersKilled = %d", GetOffset("CWave", "m_nNumSentryBustersKilled"));
	LogMessage("InitOffsets: CTFNavArea->m_distanceToBombTarget = %d", GetOffset("CTFNavArea", "m_distanceToBombTarget"));
#endif
}

static any GetOffset(const char[] cls, const char[] prop)
{
	char key[64];
	Format(key, sizeof(key), "%s::%s", cls, prop);
	
	int offset;
	if (!m_adtOffsets.GetValue(key, offset))
	{
		ThrowError("Offset '%s' not present in map", key);
	}
	
	return offset;
}

static void SetOffset(GameData hGamedata, const char[] cls, const char[] prop)
{
	char key[64], base_key[64], base_prop[64];
	Format(key, sizeof(key), "%s::%s", cls, prop);
	Format(base_key, sizeof(base_key), "%s_BaseOffset", cls);
	
	// Get the actual offset, calculated using a base offset if present
	if (hGamedata.GetKeyValue(base_key, base_prop, sizeof(base_prop)))
	{
		int base_offset = FindSendPropInfo(cls, base_prop);
		if (base_offset == -1)
		{
			// If we found nothing, search on CBaseEntity instead
			base_offset = FindSendPropInfo("CBaseEntity", base_prop);
			if (base_offset == -1)
			{
				ThrowError("Base offset '%s::%s' could not be found", cls, base_prop);
			}
		}
		
		int offset = base_offset + hGamedata.GetOffset(key);
		m_adtOffsets.SetValue(key, offset);
	}
	else
	{
		int offset = hGamedata.GetOffset(key);
		if (offset == -1)
		{
			ThrowError("Offset '%s' could not be found", key);
		}
		
		m_adtOffsets.SetValue(key, offset);
	}
}

/* This only exists to set the variable that is factored in damage knockback
when the game checks for it in CTFPlayer::ApplyPushFromDamage */
void SetDeployingBombState(int client, int nDeployingBombState)
{
	SetEntData(client, GetOffset("CTFPlayer", "m_nDeployingBombState"), nDeployingBombState);
}

void SetAsMissionEnemy(int client, bool bVal)
{
	SetEntData(client, GetOffset("CTFPlayer", "m_bIsMissionEnemy"), bVal, 1);
}

void SetAsSupportEnemy(int client, bool bVal)
{
	SetEntData(client, GetOffset("CTFPlayer", "m_bIsSupportEnemy"), bVal, 1);
}

float GetAccumulatedSentryGunDamageDealt(int client)
{
	return GetEntDataFloat(client, GetOffset("CTFPlayer", "m_accumulatedSentryGunDamageDealt"));
}

int GetAccumulatedSentryGunKillCount(int client)
{
	return GetEntData(client, GetOffset("CTFPlayer", "m_accumulatedSentryGunKillCount"));
}

int GetPopFileEventType(int populator)
{
	return GetEntData(populator, GetOffset("CPopulationManager", "m_nMvMEventPopfileType"));
}

//This checks if the populator allows bots to attack while in their spawn room
bool CanBotsAttackWhileInSpawnRoom(int populator)
{
	return view_as<bool>(GetEntData(populator, GetOffset("CPopulationManager", "m_canBotsAttackWhileInSpawnRoom"), 1));
}

bool IsBotSpawningPaused(int populator)
{
	return view_as<bool>(GetEntData(populator, GetOffset("CPopulationManager", "m_bSpawningPaused"), 1));
}

void GetCurrentBuildOrigin(int iObject, float buffer[3])
{
	GetEntDataVector(iObject, GetOffset("CBaseObject", "m_vecBuildOrigin"), buffer);
}

int GetNumSentryBustersSpawned(Address wave)
{
	return LoadFromAddress(wave + GetOffset("CWave", "m_nSentryBustersSpawned"), NumberType_Int32);
}

void SetNumSentryBustersSpawned(Address wave, int iValue)
{
	StoreToAddress(wave + GetOffset("CWave", "m_nSentryBustersSpawned"), iValue, NumberType_Int32);
}

int GetNumEngineersTeleportSpawned(Address wave)
{
	return LoadFromAddress(wave + GetOffset("CWave", "m_nNumEngineersTeleportSpawned"), NumberType_Int32);
}

void SetNumEngineersTeleportSpawned(Address wave, int iValue)
{
	StoreToAddress(wave + GetOffset("CWave", "m_nNumEngineersTeleportSpawned"), iValue, NumberType_Int32);
}

int GetNumSentryBustersKilled(Address wave)
{
	return LoadFromAddress(wave + GetOffset("CWave", "m_nNumSentryBustersKilled"), NumberType_Int32);
}

void SetNumSentryBustersKilled(Address wave, int iValue)
{
	StoreToAddress(wave + GetOffset("CWave", "m_nNumSentryBustersKilled"), iValue, NumberType_Int32);
}

float GetTravelDistanceToBombTarget(CTFNavArea area)
{
	return LoadFromAddress(view_as<Address>(area) + GetOffset("CTFNavArea", "m_distanceToBombTarget"), NumberType_Int32);
}