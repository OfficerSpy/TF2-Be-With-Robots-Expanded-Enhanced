void ShowPlayerNextRobotMenu(int client)
{
	MvMRobotPlayer roboPlayer = MvMRobotPlayer(client);
	
	if (roboPlayer.MyNextRobotTemplateID = ROBOT_TEMPLATE_ID_INVALID)
		ThrowError("Client %N (%d) does not have a valid robot template selected!", client, client);
	
	Menu hMenu = new Menu(MenuHandler_ViewNextRobot);
	hMenu.SetTitle("%t", "Menu_RobotPlayer_ViewNextRobot");
	
	char textFormatBuffer[32];
	Format(textFormatBuffer, sizeof(textFormatBuffer), "%t", "Menu_RobotPlayer_SpawnAsNextRobotNow");
	
	hMenu.AddItem(textFormatBuffer);
}