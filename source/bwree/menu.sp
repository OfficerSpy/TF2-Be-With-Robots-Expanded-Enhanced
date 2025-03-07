#define DISPLAY_MENU_DURATION	30

static eRobotTemplateType m_nSelectedRobotType[MAXPLAYERS + 1];

// Show the next robot we are going to spawn as
void ShowPlayerNextRobotMenu(int client)
{
	MvMRobotPlayer roboPlayer = MvMRobotPlayer(client);
	
	if (roboPlayer.MyNextRobotTemplateID == ROBOT_TEMPLATE_ID_INVALID)
		ThrowError("Client %N (%d) does not have a valid robot template selected!", client, client);
	
	Menu hMenu = new Menu(MenuHandler_ViewNextRobot, MENU_ACTIONS_ALL);
	char robotName[MAX_NAME_LENGTH]; GetRobotTemplateName(roboPlayer.MyNextRobotTemplateType, roboPlayer.MyNextRobotTemplateID, robotName, sizeof(robotName));
	
	hMenu.SetTitle("%t", "Menu_ViewNextRobot", robotName);
	
	char textFormatBuffer[32];
	
	FormatEx(textFormatBuffer, sizeof(textFormatBuffer), "%t", "Menu_SpawnAsNextRobotNow");
	hMenu.AddItem("0", textFormatBuffer);
	
	FormatEx(textFormatBuffer, sizeof(textFormatBuffer), "%t", "Menu_ChangeRobot");
	hMenu.AddItem("1", textFormatBuffer);
	
	hMenu.Display(client, DISPLAY_MENU_DURATION);
}

// List the robot variant type categories that are available
void ShowRobotVariantTypeMenu(int client, bool bAdmin = false)
{
	Menu hMenu = new Menu(MenuHandler_RobotVariantType, MENU_ACTIONS_ALL);
	
	hMenu.AddItem("0", "Standard");
	
	if (bAdmin || AreGiantRobotsAvailable())
		hMenu.AddItem("1", "Giant");
	
	if (bAdmin || AreGatebotsAvailable())
	{
		hMenu.AddItem("2", "Gatebot");
		
		if (bAdmin || AreGiantRobotsAvailable())
			hMenu.AddItem("3", "Gatebot Giant");
	}
	
	if (bAdmin)
	{
		hMenu.AddItem("4", "Sentry Buster");
		hMenu.AddItem("5", "Boss");
	}
	
	hMenu.Display(client, bAdmin ? MENU_TIME_FOREVER : DISPLAY_MENU_DURATION);
}

// List the class names for the robot variant type
void ShowRobotTemplateClassMenu(int client, eRobotTemplateType type)
{
	//Sanity check
	if (type < ROBOT_STANDARD || type > ROBOT_TEMPLATE_TYPE_COUNT)
		ThrowError("Invalid robot template type given");
	
	if (g_iTotalRobotTemplates[type] == 0)
	{
		LogError("ShowRobotTemplateClassMenu: There are no robot templates for type %d", type);
		return;
	}
	
	Menu hMenu = new Menu(MenuHandler_RobotTemplateClasses, MENU_ACTIONS_ALL);
	
	hMenu.AddItem("0", "Scout");
	hMenu.AddItem("1", "Soldier");
	hMenu.AddItem("2", "Pyro");
	hMenu.AddItem("3", "Demoman");
	hMenu.AddItem("4", "Heavy");
	hMenu.AddItem("5", "Engineer");
	hMenu.AddItem("6", "Medic");
	hMenu.AddItem("7", "Sniper");
	hMenu.AddItem("8", "Spy");
	hMenu.ExitBackButton = true;
	hMenu.Display(client, MENU_TIME_FOREVER);
	
	m_nSelectedRobotType[client] = type;
}

// List the names of robots that are available for the specified class under the specified robot variant type
bool ShowRobotTemplatesForClassMenu(int client, eRobotTemplateType type, TFClassType class)
{
	bool bCurrentWaveRobots = bwr3_player_robot_template_mode.IntValue == ROBOT_TEMPLATE_MODE_WAVE_BOTS;
	Menu hMenu = new Menu(MenuHandler_RobotTemplatesForClass, MENU_ACTIONS_ALL);
	int count = 0;
	
	for (int i = 0; i < g_iTotalRobotTemplates[type]; i++)
	{
		if (GetRobotTemplateClass(type, i) == class)
		{
			if (bCurrentWaveRobots)
			{
				//We only want to show the robots that are allowed in the current wave
				if (!IsRobotTemplateUsableForCurrentWave(type, i))
					continue;
			}
			
			//Store as template ID
			char info[4]; IntToString(i, info, sizeof(info));
			
			char robotName[MAX_NAME_LENGTH]; GetRobotTemplateName(type, i, robotName, sizeof(robotName));
			
			hMenu.AddItem(info, robotName);
			count++;
		}
	}
	
	if (count == 0)
	{
		CloseHandle(hMenu);
		PrintToChat(client, "%s %t", PLUGIN_PREFIX, "Robot_Class_No_Templates");
		return false;
	}
	
	hMenu.ExitBackButton = true;
	
	return hMenu.Display(client, MENU_TIME_FOREVER);
}

void ShowEngineerTeleportMenu(int client)
{
	Menu hMenu = new Menu(MenuHandler_EngineerTeleport, MENU_ACTIONS_ALL);
	hMenu.SetTitle("%t", "Menu_EngineerTeleport");
	
	char textFormatBuffer[32];
	
	FormatEx(textFormatBuffer, sizeof(textFormatBuffer), "%t", "Menu_EngineerTeleport_NearBomb");
	hMenu.AddItem("0", textFormatBuffer);
	
	FormatEx(textFormatBuffer, sizeof(textFormatBuffer), "%t", "Menu_EngineerTeleport_Random");
	hMenu.AddItem("1", textFormatBuffer);
	
	FormatEx(textFormatBuffer, sizeof(textFormatBuffer), "%t", "Menu_EngineerTeleport_NearTeammate");
	hMenu.AddItem("2", textFormatBuffer);
	
	FormatEx(textFormatBuffer, sizeof(textFormatBuffer), "%t", "Menu_EngineerTeleport_NearBombSafe");
	hMenu.AddItem("3", textFormatBuffer);
	
	FormatEx(textFormatBuffer, sizeof(textFormatBuffer), "%t", "Menu_EngineerTeleport_UseBombInfo");
	hMenu.AddItem("4", textFormatBuffer);
	
	hMenu.Display(client, DISPLAY_MENU_DURATION);
}

void ShowSpyTeleportMenu(int client)
{
	Menu hMenu = new Menu(MenuHandler_SpyTeleporting, MENU_ACTIONS_ALL);
	hMenu.SetTitle("%t", "Menu_SpyTeleport");
	
	char textFormatBuffer[32];
	
	FormatEx(textFormatBuffer, sizeof(textFormatBuffer), "%t", "Menu_SpyTeleport_Default");
	hMenu.AddItem("0", textFormatBuffer);
	
	//Needs at least one player to pick from
	if (GetLivingClientCountOnTeam(TFTeam_Red) > 0)
	{
		FormatEx(textFormatBuffer, sizeof(textFormatBuffer), "%t", "Menu_SpyTeleport_Player");
		hMenu.AddItem("1", textFormatBuffer);
	}
	
	hMenu.Display(client, DISPLAY_MENU_DURATION);
}

void ShowSpyTeleportPlayerMenu(int client)
{
	Menu hMenu = new Menu(MenuHandler_SpyTeleportPlayer, MENU_ACTIONS_ALL);
	hMenu.SetTitle("%t", "Menu_SpyTeleportPlayer");
	
	char info[4], name[MAX_NAME_LENGTH];
	
	for (int i = 1; i <= MaxClients; i++)
	{
		if (!IsClientInGame(i))
			continue;
		
		if (TF2_GetClientTeam(i) != TFTeam_Red)
			continue;
		
		if (!IsPlayerAlive(i))
			continue;
		
		GetClientName(i, name, sizeof(name));
		
		//Store as userid, we will read from it later
		FormatEx(info, sizeof(info), "%i", GetClientUserId(i));
		
		hMenu.AddItem(info, name);
	}
	
	hMenu.Display(client, DISPLAY_MENU_DURATION);
}

static int MenuHandler_ViewNextRobot(Menu menu, MenuAction action, int param1, int param2)
{
	switch (action)
	{
		case MenuAction_Select:
		{
			switch (param2)
			{
				case 0:	RobotPlayer_SpawnNow(param1);
				case 1:	RobotPlayer_ChangeRobot(param1);
			}
		}
		case MenuAction_End:
		{
			delete menu;
		}
	}
	
	return 0;
}

static int MenuHandler_RobotVariantType(Menu menu, MenuAction action, int param1, int param2)
{
	switch (action)
	{
		case MenuAction_Select:
		{
			//Info just stores a number correlating to these types
			char info[2]; menu.GetItem(param2, info, sizeof(info));
			
			switch (StringToInt(info))
			{
				case 0:	ShowRobotTemplateClassMenu(param1, ROBOT_STANDARD);
				case 1:	ShowRobotTemplateClassMenu(param1, ROBOT_GIANT);
				case 2:	ShowRobotTemplateClassMenu(param1, ROBOT_GATEBOT);
				case 3:	ShowRobotTemplateClassMenu(param1, ROBOT_GATEBOT_GIANT);
				case 4:	ShowRobotTemplateClassMenu(param1, ROBOT_SENTRYBUSTER);
				case 5:	ShowRobotTemplateClassMenu(param1, ROBOT_BOSS);
			}
		}
		case MenuAction_End:
		{
			delete menu;
		}
	}
	
	return 0;
}

static int MenuHandler_RobotTemplateClasses(Menu menu, MenuAction action, int param1, int param2)
{
	switch (action)
	{
		case MenuAction_Select:
		{
			switch (param2)
			{
				case 0: ShowRobotTemplatesForClassMenu(param1, m_nSelectedRobotType[param1], TFClass_Scout);
				case 1: ShowRobotTemplatesForClassMenu(param1, m_nSelectedRobotType[param1], TFClass_Soldier);
				case 2: ShowRobotTemplatesForClassMenu(param1, m_nSelectedRobotType[param1], TFClass_Pyro);
				case 3: ShowRobotTemplatesForClassMenu(param1, m_nSelectedRobotType[param1], TFClass_DemoMan);
				case 4: ShowRobotTemplatesForClassMenu(param1, m_nSelectedRobotType[param1], TFClass_Heavy);
				case 5: ShowRobotTemplatesForClassMenu(param1, m_nSelectedRobotType[param1], TFClass_Engineer);
				case 6: ShowRobotTemplatesForClassMenu(param1, m_nSelectedRobotType[param1], TFClass_Medic);
				case 7: ShowRobotTemplatesForClassMenu(param1, m_nSelectedRobotType[param1], TFClass_Sniper);
				case 8: ShowRobotTemplatesForClassMenu(param1, m_nSelectedRobotType[param1], TFClass_Spy);
			}
		}
		case MenuAction_End:
		{
			CloseHandle(menu);
		}
		case MenuAction_Cancel:
		{
			if (param2 == MenuCancel_ExitBack)
				ShowRobotVariantTypeMenu(param1);
		}
	}
	
	return 0;
}

static int MenuHandler_RobotTemplatesForClass(Menu menu, MenuAction action, int param1, int param2)
{
	switch (action)
	{
		case MenuAction_Select:
		{
			//Info stores a robot template ID number
			char info[4]; menu.GetItem(param2, info, sizeof(info));
			int templateID = StringToInt(info);
			
			MvMRobotPlayer(param1).SetMyNextRobot(m_nSelectedRobotType[param1], templateID);
			
			if (GameRules_GetRoundState() == RoundState_RoundRunning)
				g_bChangeRobotPicked[param1] = true;
			
			if (MvMRobotPlayer(param1).MyNextRobotTemplateType != ROBOT_BOSS)
				g_bSpawningAsBossRobot[param1] = false;
			
			char robotName[MAX_NAME_LENGTH]; GetRobotTemplateName(m_nSelectedRobotType[param1], templateID, robotName, sizeof(robotName));
			
			LogAction(param1, -1, "%L selected robot %s (type %d, ID %d)", param1, robotName, m_nSelectedRobotType[param1], templateID);
		}
		case MenuAction_End:
		{
			CloseHandle(menu);
		}
		case MenuAction_Cancel:
		{
			if (param2 == MenuCancel_ExitBack)
				ShowRobotTemplateClassMenu(param1, m_nSelectedRobotType[param1]);
		}
	}
	
	return 0;
}

static int MenuHandler_EngineerTeleport(Menu menu, MenuAction action, int param1, int param2)
{
	switch (action)
	{
		case MenuAction_Select:
		{
			switch (param2)
			{
				case 0:	MvMEngineerTeleportSpawn(param1, ENGINEER_TELEPORT_NEAR_BOMB);
				case 1:	MvMEngineerTeleportSpawn(param1, ENGINEER_TELEPORT_RANDOM);
				case 2:	MvMEngineerTeleportSpawn(param1, ENGINEER_TELEPORT_NEAR_TEAMMATE);
				case 3:	MvMEngineerTeleportSpawn(param1, ENGINEER_TELEPORT_NEAR_BOMB_SAFE);
				case 4:	MvMEngineerTeleportSpawn(param1, ENGINEER_TELEPORT_FROM_BOMB_INFO);
			}
		}
		case MenuAction_Cancel:
		{
			//They didn't pick anything, resort to default
			MvMEngineerTeleportSpawn(param1);
		}
		case MenuAction_End:
		{
			delete menu;
		}
	}
	
	return 0;
}

static int MenuHandler_SpyTeleporting(Menu menu, MenuAction action, int param1, int param2)
{
	switch (action)
	{
		case MenuAction_Select:
		{
			switch (param2)
			{
				case 0:	SpyLeaveSpawnRoom_OnStart(param1);
				case 1:	ShowSpyTeleportPlayerMenu(param1);
			}
		}
		case MenuAction_Cancel:
		{
			//Default teleporting
			SpyLeaveSpawnRoom_OnStart(param1);
		}
		case MenuAction_End:
		{
			delete menu;
		}
	}
	
	return 0;
}

static int MenuHandler_SpyTeleportPlayer(Menu menu, MenuAction action, int param1, int param2)
{
	switch (action)
	{
		case MenuAction_Select:
		{
			//Item info should be storing a client's userid as a string
			char info[16]; menu.GetItem(param2, info, sizeof(info));
			int victim = GetClientOfUserId(StringToInt(info));
			
			if (victim != 0 && IsValidSpyTeleportVictim(victim))
			{
				g_iOverrideTeleportVictim[param1] = victim;
				SpyLeaveSpawnRoom_OnStart(param1);
			}
			else
			{
				PrintToChat(param1, "%s %t", PLUGIN_PREFIX, "Spy_Teleport_Victm_Not_Found_Retry");
				ShowSpyTeleportMenu(param1);
			}
		}
		case MenuAction_Cancel:
		{
			//Default teleporting
			g_iOverrideTeleportVictim[param1] = -1;
			SpyLeaveSpawnRoom_OnStart(param1);
		}
		case MenuAction_End:
		{
			delete menu;
		}
	}
	
	return 0;
}