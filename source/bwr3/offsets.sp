//Used for offset calculations
//https://github.com/Mikusch/MannVsMann/blob/571737b5ae0aadc1e743360e94311ca64e693bd9/addons/sourcemod/gamedata/mannvsmann.txt
static StringMap m_adtOffsets;

void InitOffsets(GameData hGamedata)
{
	m_adtOffsets = new StringMap();
	
	SetOffset(hGamedata, "CTFPlayer", "m_nDeployingBombState");
	SetOffset(hGamedata, "CPopulationManager", "m_canBotsAttackWhileInSpawnRoom");
	SetOffset(hGamedata, "CTFPlayer", "m_accumulatedSentryGunDamageDealt");
	SetOffset(hGamedata, "CTFPlayer", "m_accumulatedSentryGunKillCount");
	SetOffset(hGamedata, "CPopulationManager", "m_bSpawningPaused");
	
#if defined TESTING_ONLY
	//Dump offsets
	LogMessage("InitOffsets: CTFPlayer->m_nDeployingBombState = %d", GetOffset("CTFPlayer", "m_nDeployingBombState"));
	LogMessage("InitOffsets: CPopulationManager->m_canBotsAttackWhileInSpawnRoom = %d", GetOffset("CPopulationManager", "m_canBotsAttackWhileInSpawnRoom"));
	LogMessage("InitOffsets: CTFPlayer->m_accumulatedSentryGunDamageDealt = %d", GetOffset("CTFPlayer", "m_accumulatedSentryGunDamageDealt"));
	LogMessage("InitOffsets: CTFPlayer->m_accumulatedSentryGunKillCount = %d", GetOffset("CTFPlayer", "m_accumulatedSentryGunKillCount"));
	LogMessage("InitOffsets: CPopulationManager->m_bSpawningPaused = %d", GetOffset("CPopulationManager", "m_bSpawningPaused"));
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

//This checks if the populator allows bots to attack while in their spawn room
bool CanBotsAttackWhileInSpawnRoom(int populator)
{
	return view_as<bool>(GetEntData(populator, GetOffset("CPopulationManager", "m_canBotsAttackWhileInSpawnRoom"), 1));
}

int GetAccumulatedSentryGunDamageDealt(int client)
{
	return GetEntData(client, GetOffset("CTFPlayer", "m_accumulatedSentryGunDamageDealt"));
}

int GetAccumulatedSentryGunKillCount(int client)
{
	return GetEntData(client, GetOffset("CTFPlayer", "m_accumulatedSentryGunKillCount"));
}

bool IsBotSpawningPaused(int populator)
{
	return view_as<bool>(GetEntData(populator, GetOffset("CPopulationManager", "m_bSpawningPaused"), 1));
}