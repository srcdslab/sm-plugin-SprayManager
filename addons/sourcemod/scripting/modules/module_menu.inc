public void OnAdminMenuReady(Handle hAdminMenu)
{
	if (hAdminMenu == g_hTopMenu)
		return;

	g_hTopMenu = view_as<TopMenu>(CloneHandle(hAdminMenu));

	TopMenuObject hMenuObj = g_hTopMenu.AddCategory("SprayManagerCommands", TopMenu_Main_Handler);

	if (hMenuObj == INVALID_TOPMENUOBJECT)
		return;

	g_hTopMenu.AddItem("SprayManager_Spraybanlist", Handler_SprayBanList, hMenuObj, "sm_banspray", ADMFLAG_GENERIC);
	g_hTopMenu.AddItem("SprayManager_Tracespray", Handler_TraceSpray, hMenuObj, "sm_tracespray", ADMFLAG_GENERIC);
	g_hTopMenu.AddItem("SprayManager_Spray", Handler_Spray, hMenuObj, "sm_spray", ADMFLAG_GENERIC);
	g_hTopMenu.AddItem("SprayManager_Sprayban", Handler_SprayBan, hMenuObj, "sm_sprayban", ADMFLAG_GENERIC);
	g_hTopMenu.AddItem("SprayManager_Banspray", Handler_BanSpray, hMenuObj, "sm_banspray", ADMFLAG_GENERIC);
	g_hTopMenu.AddItem("SprayManager_Unban", Handler_UnbanSpray, hMenuObj, "sm_unbanspray", ADMFLAG_GENERIC);
}

public void OnLibraryRemoved(const char[] sLibraryName)
{
	if (strcmp(sLibraryName, "adminmenu") == 0)
		delete g_hTopMenu;
}

public void TopMenu_Main_Handler(TopMenu hMenu, TopMenuAction hAction, TopMenuObject hObjID, int iParam1, char[] sBuffer, int iBufflen)
{
	if (hAction == TopMenuAction_DisplayOption)
		Format(sBuffer, iBufflen, "%T", "Menu Category", iParam1);
	else if (hAction == TopMenuAction_DisplayTitle)
		Format(sBuffer, iBufflen, "%T", "Menu Category Title", iParam1);
}

public void Handler_SprayBanList(TopMenu hMenu, TopMenuAction hAction, TopMenuObject hObjID, int iParam1, char[] sBuffer, int iBufflen)
{
	bool bHasAcces = CheckCommandAccess(iParam1, "sm_slap", ADMFLAG_GENERIC);

	if (hAction == TopMenuAction_DisplayOption)
		Format(sBuffer, iBufflen, "%T", "Menu List Bans", iParam1);
	else if (hAction == TopMenuAction_SelectOption)
		Menu_ListBans(iParam1);
	else if (hAction == TopMenuAction_DrawOption)
		sBuffer[0] = bHasAcces ? ITEMDRAW_DEFAULT : ITEMDRAW_IGNORE;
}

public void Handler_TraceSpray(TopMenu hMenu, TopMenuAction hAction, TopMenuObject hObjID, int iParam1, char[] sBuffer, int iBufflen)
{
	bool bHasAcces = CheckCommandAccess(iParam1, "sm_tracespray", ADMFLAG_GENERIC);

	if (hAction == TopMenuAction_DisplayOption)
	{
		Format(sBuffer, iBufflen, "%T", "Menu Trace Spray", iParam1);
	}
	else if (hAction == TopMenuAction_SelectOption)
	{
		float vecEndPos[3];

		if (TracePlayerAngles(iParam1, vecEndPos))
		{
			for (int i = 1; i <= MaxClients; i++)
			{
				if (IsPointInsideAABB(vecEndPos, g_SprayAABB[i]))
				{
					g_bInvokedThroughTopMenu[iParam1] = true;
					Menu_Trace(iParam1, i);

					return;
				}
			}
		}

		CPrintToChat(iParam1, "{green}[SprayManager]{default} %t", "Trace No Spray");

		if (g_hTopMenu != null)
			g_hTopMenu.Display(iParam1, TopMenuPosition_LastCategory);
	}
	else if (hAction == TopMenuAction_DrawOption)
		sBuffer[0] = bHasAcces ? ITEMDRAW_DEFAULT : ITEMDRAW_IGNORE;
}

public void Handler_Spray(TopMenu hMenu, TopMenuAction hAction, TopMenuObject hObjID, int iParam1, char[] sBuffer, int iBufflen)
{
	bool bHasAcces = CheckCommandAccess(iParam1, "sm_spray", ADMFLAG_GENERIC);

	if (hAction == TopMenuAction_DisplayOption)
		Format(sBuffer, iBufflen, "%T", "Menu Force Spray", iParam1);
	else if (hAction == TopMenuAction_SelectOption)
		Menu_Spray(iParam1);
	else if (hAction == TopMenuAction_DrawOption)
		sBuffer[0] = bHasAcces ? ITEMDRAW_DEFAULT : ITEMDRAW_IGNORE;
}

public void Handler_SprayBan(TopMenu hMenu, TopMenuAction hAction, TopMenuObject hObjID, int iParam1, char[] sBuffer, int iBufflen)
{
	bool bHasAcces = CheckCommandAccess(iParam1, "sm_sprayban", ADMFLAG_GENERIC);

	if (hAction == TopMenuAction_DisplayOption)
		Format(sBuffer, iBufflen, "%T", "Menu Spray Ban", iParam1);
	else if (hAction == TopMenuAction_SelectOption)
		Menu_SprayBan(iParam1);
	else if (hAction == TopMenuAction_DrawOption)
		sBuffer[0] = bHasAcces ? ITEMDRAW_DEFAULT : ITEMDRAW_IGNORE;
}

public void Handler_BanSpray(TopMenu hMenu, TopMenuAction hAction, TopMenuObject hObjID, int iParam1, char[] sBuffer, int iBufflen)
{
	bool bHasAcces = CheckCommandAccess(iParam1, "sm_banspray", ADMFLAG_GENERIC);

	if (hAction == TopMenuAction_DisplayOption)
		Format(sBuffer, iBufflen, "%T", "Menu Ban Spray", iParam1);
	else if (hAction == TopMenuAction_SelectOption)
		Menu_BanSpray(iParam1);
	else if (hAction == TopMenuAction_DrawOption)
		sBuffer[0] = bHasAcces ? ITEMDRAW_DEFAULT : ITEMDRAW_IGNORE;
}

public void Handler_UnbanSpray(TopMenu hMenu, TopMenuAction hAction, TopMenuObject hObjID, int iParam1, char[] sBuffer, int iBufflen)
{
	bool bHasAcces = CheckCommandAccess(iParam1, "sm_unbanspray", ADMFLAG_GENERIC);

	if (hAction == TopMenuAction_DisplayOption)
		Format(sBuffer, iBufflen, "%T", "Menu Unban", iParam1);
	else if (hAction == TopMenuAction_SelectOption)
		Menu_Unban(iParam1);
	else if (hAction == TopMenuAction_DrawOption)
		sBuffer[0] = bHasAcces ? ITEMDRAW_DEFAULT : ITEMDRAW_IGNORE;
}

void Menu_ListBans(int client)
{
	if (!IsValidClient(client))
		return;

	int iBannedClients;

	Menu ListMenu = new Menu(MenuHandler_Menu_ListBans);
	ListMenu.SetTitle("[SprayManager] %T", "Menu Banned Clients Title", client);
	ListMenu.ExitBackButton =  true;

	for (int i = 1; i <= MaxClients; i++)
	{
		if (!IsValidClient(i))
			continue;

		if (g_bSprayBanned[i] || g_bSprayHashBanned[i])
		{
			char sUserID[16];
			char sBuff[64];
			int iUserID = GetClientUserId(i);

			Format(sBuff, sizeof(sBuff), "%N (#%d)", i, iUserID);
			Format(sUserID, sizeof(sUserID), "%d", iUserID);

			ListMenu.AddItem(sUserID, sBuff);
			iBannedClients++;
		}
	}

	if (!iBannedClients)
		AddTranslatedMenuItem(ListMenu, "", "Menu No Banned Clients", client, ITEMDRAW_DISABLED);

	ListMenu.Display(client, MENU_TIME_FOREVER);
}

int MenuHandler_Menu_ListBans(Menu hMenu, MenuAction action, int iParam1, int iParam2)
{
	switch (action)
	{
		case MenuAction_End:
			delete hMenu;

		case MenuAction_Cancel:
		{
			if (iParam2 == MenuCancel_ExitBack && g_hTopMenu != null)
				g_hTopMenu.Display(iParam1, TopMenuPosition_LastCategory);
		}

		case MenuAction_Select:
		{
			char sOption[32];
			hMenu.GetItem(iParam2, sOption, sizeof(sOption));

			int target = GetClientOfUserId(StringToInt(sOption));

			if (!IsValidClient(target))
			{
				CPrintToChat(iParam1, "{green}[SprayManager]{default} %t", "Player no longer available");

				if (g_hTopMenu != null)
					g_hTopMenu.Display(iParam1, TopMenuPosition_LastCategory);
				else
					delete hMenu;
			}
			else
			{
				g_bInvokedThroughListMenu[iParam1] = true;
				Menu_ListBans_Target(iParam1, target);
			}
		}
	}
	return 0;
}

void Menu_Trace(int client, int target)
{
	Menu TraceMenu = new Menu(MenuHandler_Menu_Trace);
	TraceMenu.SetTitle("%T", "Menu Sprayed By Title", client, target, sAuthID3[target]);

	if (g_bInvokedThroughTopMenu[client])
		TraceMenu.ExitBackButton = true;

	AddTranslatedMenuItem(TraceMenu, "1", "Menu Warn Client", client);
	if (g_bHasNSFWSpray[target])
		AddTranslatedMenuItem(TraceMenu, "2", "Menu Mark SFW", client, (CheckCommandAccess(client, "sm_forcesfw", ADMFLAG_GENERIC))?ITEMDRAW_DEFAULT:ITEMDRAW_DISABLED);
	else
		AddTranslatedMenuItem(TraceMenu, "2", "Menu Mark NSFW", client, (CheckCommandAccess(client, "sm_forcensfw", ADMFLAG_GENERIC))?ITEMDRAW_DEFAULT:ITEMDRAW_DISABLED);
	AddTranslatedMenuItem(TraceMenu, "3", "Menu Kick Client", client, (CheckCommandAccess(client, "sm_kick", ADMFLAG_KICK))?ITEMDRAW_DEFAULT:ITEMDRAW_DISABLED);
	AddTranslatedMenuItem(TraceMenu, "4", "Menu Spray Ban Client", client, (CheckCommandAccess(client, "sm_sprayban", ADMFLAG_GENERIC))?ITEMDRAW_DEFAULT:ITEMDRAW_DISABLED);
	AddTranslatedMenuItem(TraceMenu, "5", "Menu Ban Spray Hash", client, (CheckCommandAccess(client, "sm_banspray", ADMFLAG_GENERIC))?ITEMDRAW_DEFAULT:ITEMDRAW_DISABLED);
	TraceMenu.AddItem("", "", ITEMDRAW_SPACER);
	AddTranslatedMenuItem(TraceMenu, "6", "Menu Ban Client", client, (CheckCommandAccess(client, "sm_ban", ADMFLAG_BAN))?ITEMDRAW_DEFAULT:ITEMDRAW_DISABLED);

	g_iSprayTraceTarget[client] = target;

	TraceMenu.Display(client, MENU_TIME_FOREVER);
}

int MenuHandler_Menu_Trace(Menu hMenu, MenuAction action, int iParam1, int iParam2)
{
	switch (action)
	{
		case MenuAction_End:
			delete hMenu;

		case MenuAction_Cancel:
		{
			if (iParam2 == MenuCancel_ExitBack && g_hTopMenu != null)
				g_hTopMenu.Display(iParam1, TopMenuPosition_LastCategory);
		}

		case MenuAction_Select:
		{
			char sOption[2];
			hMenu.GetItem(iParam2, sOption, sizeof(sOption));

			int target = g_iSprayTraceTarget[iParam1];

			if (!IsValidClient(target))
			{
				CPrintToChat(iParam1, "{green}[SprayManager]{default} %t", "Player no longer available");

				g_bInvokedThroughTopMenu[iParam1] = false;

				if (g_hTopMenu != null)
					g_hTopMenu.Display(iParam1, TopMenuPosition_LastCategory);
				else
					delete hMenu;
			}
			else
			{
				switch (StringToInt(sOption))
				{
					case 1:
					{
						CPrintToChat(target, "{green}[SprayManager]{default} %t", "Spray Not Allowed");
						LogAction(target, iParam1, "[SprayManager] \"%L\" has been warned for his spray by \"%L\"", target, iParam1);
						NotifyAdmins(iParam1, target, "Notify Warned");
						Menu_Trace(iParam1, target);
					}

					case 2:
					{
						if (!g_bHasNSFWSpray[target])
							AdminForceSprayNSFW(iParam1, target);
						else
							AdminForceSpraySFW(iParam1, target);

						Menu_Trace(iParam1, target);
					}

					case 3:
					{
						g_bInvokedThroughTopMenu[iParam1] = false;
						KickClient(target, "%t", "Spray Not Allowed");
						CShowActivity2(iParam1, "{green}[SprayManager]{olive} ", "%t", "Activity Kicked For Spray", target);
						LogAction(target, iParam1, "[SprayManager] \"%L\" has been kicked for his spray by \"%L\"", target, iParam1);
					}

					case 4:
					{
						Menu TraceSpraySprayBan = new Menu(MenuHandler_Menu_Trace_SprayBan);
						TraceSpraySprayBan.SetTitle("[SprayManager] %T", "Menu Spray Ban Length Title", iParam1, target, GetClientUserId(target));
						TraceSpraySprayBan.ExitBackButton = true;

						AddTranslatedMenuItem(TraceSpraySprayBan, "10", "Length 10 Minutes", iParam1);
						AddTranslatedMenuItem(TraceSpraySprayBan, "30", "Length 30 Minutes", iParam1);
						AddTranslatedMenuItem(TraceSpraySprayBan, "60", "Length 1 Hour", iParam1);
						AddTranslatedMenuItem(TraceSpraySprayBan, "240", "Length 4 Hours", iParam1);
						AddTranslatedMenuItem(TraceSpraySprayBan, "480", "Length 8 Hours", iParam1);
						AddTranslatedMenuItem(TraceSpraySprayBan, "720", "Length 12 Hours", iParam1);
						AddTranslatedMenuItem(TraceSpraySprayBan, "1440", "Length 1 Day", iParam1);
						AddTranslatedMenuItem(TraceSpraySprayBan, "2880", "Length 2 Days", iParam1);
						AddTranslatedMenuItem(TraceSpraySprayBan, "4320", "Length 3 Days", iParam1);
						AddTranslatedMenuItem(TraceSpraySprayBan, "10080", "Length 1 Week", iParam1);
						AddTranslatedMenuItem(TraceSpraySprayBan, "20160", "Length 2 Weeks", iParam1);
						AddTranslatedMenuItem(TraceSpraySprayBan, "40320", "Length 1 Month", iParam1);
						AddTranslatedMenuItem(TraceSpraySprayBan, "0", "Length Permanent", iParam1);

						g_iSprayBanTarget[iParam1] = target;

						TraceSpraySprayBan.Display(iParam1, MENU_TIME_FOREVER);
					}

					case 5:
					{
						if (BanClientSpray(iParam1, target))
						{
							CShowActivity2(iParam1, "{green}[SprayManager]{olive} ", "%t", "Activity Spray Hash Banned", target);
							LogAction(iParam1, target, "\"%L\" banned \"%L\"'s spray (Hash: \"%s\")", iParam1, target, g_sSprayHash[target]);
						}
					}

					case 6:
					{
						Menu TraceSprayBan = new Menu(MenuHandler_Menu_Trace_Ban);
						TraceSprayBan.SetTitle("[SprayManager] %T", "Menu Ban Length Title", iParam1, target, GetClientUserId(target));
						TraceSprayBan.ExitBackButton = true;

						AddTranslatedMenuItem(TraceSprayBan, "10", "Length 10 Minutes", iParam1);
						AddTranslatedMenuItem(TraceSprayBan, "30", "Length 30 Minutes", iParam1);
						AddTranslatedMenuItem(TraceSprayBan, "60", "Length 1 Hour", iParam1);
						AddTranslatedMenuItem(TraceSprayBan, "240", "Length 4 Hours", iParam1);
						AddTranslatedMenuItem(TraceSprayBan, "480", "Length 8 Hours", iParam1);
						AddTranslatedMenuItem(TraceSprayBan, "720", "Length 12 Hours", iParam1);
						AddTranslatedMenuItem(TraceSprayBan, "1440", "Length 1 Day", iParam1);
						AddTranslatedMenuItem(TraceSprayBan, "2880", "Length 2 Days", iParam1);
						AddTranslatedMenuItem(TraceSprayBan, "4320", "Length 3 Days", iParam1);
						AddTranslatedMenuItem(TraceSprayBan, "10080", "Length 1 Week", iParam1);
						AddTranslatedMenuItem(TraceSprayBan, "20160", "Length 2 Weeks", iParam1);
						AddTranslatedMenuItem(TraceSprayBan, "40320", "Length 1 Month", iParam1);
						AddTranslatedMenuItem(TraceSprayBan, "0", "Length Permanent", iParam1);

						g_iBanTarget[iParam1] = target;

						TraceSprayBan.Display(iParam1, MENU_TIME_FOREVER);
					}
				}
			}
		}
	}
	return 0;
}

int MenuHandler_Menu_Trace_SprayBan(Menu hMenu, MenuAction action, int iParam1, int iParam2)
{
	switch (action)
	{
		case MenuAction_End:
			delete hMenu;

		case MenuAction_Cancel:
		{
			if (iParam2 == MenuCancel_ExitBack)
			{
				if (IsValidClient(g_iSprayBanTarget[iParam1]))
				{
					Menu_Trace(iParam1, g_iSprayBanTarget[iParam1]);
				}
				else if (g_hTopMenu != null)
				{
					g_bInvokedThroughTopMenu[iParam1] = false;
					g_hTopMenu.Display(iParam1, TopMenuPosition_LastCategory);
				}
				else
				{
					g_bInvokedThroughTopMenu[iParam1] = false;
					delete hMenu;
				}
			}
		}

		case MenuAction_Select:
		{
			char sOption[8];
			hMenu.GetItem(iParam2, sOption, sizeof(sOption));

			int target = g_iSprayBanTarget[iParam1];

			if (!IsValidClient(target))
			{
				CPrintToChat(iParam1, "{green}[SprayManager]{default} %t", "Player no longer available");

				g_iSprayBanTarget[iParam1] = 0;
				g_bInvokedThroughTopMenu[iParam1] = false;

				if (g_hTopMenu != null)
					g_hTopMenu.Display(iParam1, TopMenuPosition_LastCategory);
				else
					delete hMenu;
			}
			else
			{
				if (SprayBanClient(iParam1, target, StringToInt(sOption), "Inappropriate Spray"))
				{
					CShowActivity2(iParam1, "{green}[SprayManager]{olive} ", "%t", "Activity Spray Banned", target);
					LogAction(iParam1, target, "\"%L\" spray banned \"%L\" (Hash: \"%s\")", iParam1, target, g_sSprayHash[target]);
				}

				g_iSprayBanTarget[iParam1] = 0;
				g_bInvokedThroughTopMenu[iParam1] = false;
			}
		}
	}
	return 0;
}

int MenuHandler_Menu_Trace_Ban(Menu hMenu, MenuAction action, int iParam1, int iParam2)
{
	switch (action)
	{
		case MenuAction_End:
			delete hMenu;

		case MenuAction_Cancel:
		{
			if (iParam2 == MenuCancel_ExitBack)
			{
				if (IsValidClient(g_iBanTarget[iParam1]))
				{
					Menu_Trace(iParam1, g_iBanTarget[iParam1]);
				}
				else if (g_hTopMenu != null)
				{
					g_bInvokedThroughTopMenu[iParam1] = false;
					g_hTopMenu.Display(iParam1, TopMenuPosition_LastCategory);
				}
				else
				{
					g_bInvokedThroughTopMenu[iParam1] = false;
					delete hMenu;
				}
			}
		}

		case MenuAction_Select:
		{
			char sOption[8];
			hMenu.GetItem(iParam2, sOption, sizeof(sOption));

			int target = g_iBanTarget[iParam1];

			if (!IsValidClient(target))
			{
				CPrintToChat(iParam1, "{green}[SprayManager]{default} %t", "Player no longer available");

				g_iBanTarget[iParam1] = 0;
				g_bInvokedThroughTopMenu[iParam1] = false;

				if (g_hTopMenu != null)
					g_hTopMenu.Display(iParam1, TopMenuPosition_LastCategory);
				else
					delete hMenu;
			}
			else
			{
				FakeClientCommandEx(iParam1, "sm_ban \"#%d\" \"%s\" \"Inappropriate spray\"", GetClientUserId(g_iBanTarget[iParam1]), sOption);
				g_iBanTarget[iParam1] = 0;
				g_bInvokedThroughTopMenu[iParam1] = false;
			}
		}
	}
	return 0;
}

void Menu_Spray(int client)
{
	if (!IsValidClient(client))
		return;

	Menu SprayMenu = new Menu(MenuHandler_Menu_Spray);
	SprayMenu.SetTitle("[SprayManager] %T", "Menu Force Spray Title", client);
	SprayMenu.ExitBackButton =  true;

	for (int i = 1; i <= MaxClients; i++)
	{
		if (!IsValidClient(i))
			continue;

		char sUserID[16];
		char sBuff[128];
		int iUserID = GetClientUserId(i);

		Format(sUserID, sizeof(sUserID), "%d", iUserID);

		if (g_bSprayBanned[i] && g_bSprayHashBanned[i])
		{
			Format(sBuff, sizeof(sBuff), "%N (#%d) [%T]", i, iUserID, "Menu Spray And Hash Banned", client);

			SprayMenu.AddItem(sUserID, sBuff);
		}
		else if (g_bSprayBanned[i])
		{
			Format(sBuff, sizeof(sBuff), "%N (#%d) [%T]", i, iUserID, "Menu Spray Banned", client);

			SprayMenu.AddItem(sUserID, sBuff);
		}
		else if (g_bSprayHashBanned[i])
		{
			Format(sBuff, sizeof(sBuff), "%N (#%d) [%T]", i, iUserID, "Menu Hash Banned", client);

			SprayMenu.AddItem(sUserID, sBuff);
		}
		else
		{
			Format(sBuff, sizeof(sBuff), "%N (#%d)", i, iUserID);

			SprayMenu.AddItem(sUserID, sBuff);
		}
	}

	SprayMenu.Display(client, MENU_TIME_FOREVER);
}

int MenuHandler_Menu_Spray(Menu hMenu, MenuAction action, int iParam1, int iParam2)
{
	switch (action)
	{
		case MenuAction_End:
			delete hMenu;

		case MenuAction_Cancel:
		{
			if (iParam2 == MenuCancel_ExitBack && g_hTopMenu != null)
				g_hTopMenu.Display(iParam1, TopMenuPosition_LastCategory);
		}

		case MenuAction_Select:
		{
			char sOption[8];
			hMenu.GetItem(iParam2, sOption, sizeof(sOption));

			int target = GetClientOfUserId(StringToInt(sOption));

			if (!IsValidClient(target))
			{
				CPrintToChat(iParam1, "{green}[SprayManager]{default} %t", "Player no longer available");

				if (g_hTopMenu != null)
					g_hTopMenu.Display(iParam1, TopMenuPosition_LastCategory);
				else
					delete hMenu;
			}
			else
			{
				g_iAllowSpray = target;
				ForceSpray(iParam1, target);

				CPrintToChat(iParam1, "{green}[SprayManager]{default} %t", "Sprayed Client Spray", target);

				Menu_Spray(iParam1);
			}
		}
	}
	return 0;
}

void Menu_SprayBan(int client)
{
	if (!IsValidClient(client))
		return;

	int iClientsToDisplay;

	Menu SprayBanMenu = new Menu(MenuHandler_Menu_SprayBan);
	SprayBanMenu.SetTitle("[SprayManager] %T", "Menu Spray Ban Title", client);
	SprayBanMenu.ExitBackButton = true;

	for (int i = 1; i <= MaxClients; i++)
	{
		if (!IsValidClient(i))
			continue;

		if (g_bSprayBanned[i])
			continue;

		char sUserID[16];
		char sBuff[64];
		int iUserID = GetClientUserId(i);

		Format(sBuff, sizeof(sBuff), "%N (#%d)", i, iUserID);
		Format(sUserID, sizeof(sUserID), "%d", iUserID);

		SprayBanMenu.AddItem(sUserID, sBuff);
		iClientsToDisplay++;
	}

	if (!iClientsToDisplay)
		AddTranslatedMenuItem(SprayBanMenu, "", "Menu No Eligible Clients", client, ITEMDRAW_DISABLED);

	SprayBanMenu.Display(client, MENU_TIME_FOREVER);
}

int MenuHandler_Menu_SprayBan(Menu hMenu, MenuAction action, int iParam1, int iParam2)
{
	switch (action)
	{
		case MenuAction_End:
			delete hMenu;

		case MenuAction_Cancel:
		{
			if (iParam2 == MenuCancel_ExitBack && g_hTopMenu != null)
				g_hTopMenu.Display(iParam1, TopMenuPosition_LastCategory);
		}

		case MenuAction_Select:
		{
			char sOption[32];
			hMenu.GetItem(iParam2, sOption, sizeof(sOption));

			int target = GetClientOfUserId(StringToInt(sOption));

			if (!IsValidClient(target))
			{
				CPrintToChat(iParam1, "{green}[SprayManager]{default} %t", "Player no longer available");

				if (g_hTopMenu != null)
					g_hTopMenu.Display(iParam1, TopMenuPosition_LastCategory);
				else
					delete hMenu;
			}
			else
			{
				Menu SprayBanLengthMenu = new Menu(MenuHandler_Menu_SprayBan_Length);
				SprayBanLengthMenu.SetTitle("[SprayManager] %T", "Menu Spray Ban Length Title", iParam1, target, GetClientUserId(target));
				SprayBanLengthMenu.ExitBackButton = true;

				AddTranslatedMenuItem(SprayBanLengthMenu, "10", "Length 10 Minutes", iParam1);
				AddTranslatedMenuItem(SprayBanLengthMenu, "30", "Length 30 Minutes", iParam1);
				AddTranslatedMenuItem(SprayBanLengthMenu, "60", "Length 1 Hour", iParam1);
				AddTranslatedMenuItem(SprayBanLengthMenu, "240", "Length 4 Hours", iParam1);
				AddTranslatedMenuItem(SprayBanLengthMenu, "480", "Length 8 Hours", iParam1);
				AddTranslatedMenuItem(SprayBanLengthMenu, "720", "Length 12 Hours", iParam1);
				AddTranslatedMenuItem(SprayBanLengthMenu, "1440", "Length 1 Day", iParam1);
				AddTranslatedMenuItem(SprayBanLengthMenu, "2880", "Length 2 Days", iParam1);
				AddTranslatedMenuItem(SprayBanLengthMenu, "4320", "Length 3 Days", iParam1);
				AddTranslatedMenuItem(SprayBanLengthMenu, "10080", "Length 1 Week", iParam1);
				AddTranslatedMenuItem(SprayBanLengthMenu, "20160", "Length 2 Weeks", iParam1);
				AddTranslatedMenuItem(SprayBanLengthMenu, "40320", "Length 1 Month", iParam1);
				AddTranslatedMenuItem(SprayBanLengthMenu, "0", "Length Permanent", iParam1);

				g_iSprayBanTarget[iParam1] = target;

				SprayBanLengthMenu.Display(iParam1, MENU_TIME_FOREVER);
			}
		}
	}
	return 0;
}

int MenuHandler_Menu_SprayBan_Length(Menu hMenu, MenuAction action, int iParam1, int iParam2)
{
	switch (action)
	{
		case MenuAction_End:
			delete hMenu;

		case MenuAction_Cancel:
		{
			if (iParam2 == MenuCancel_ExitBack)
				Menu_SprayBan(iParam1);
		}

		case MenuAction_Select:
		{
			char sOption[8];
			hMenu.GetItem(iParam2, sOption, sizeof(sOption));

			int target = g_iSprayBanTarget[iParam1];

			if (!IsValidClient(target))
			{
				CPrintToChat(iParam1, "{green}[SprayManager]{default} %t", "Player no longer available");

				g_iSprayBanTarget[iParam1] = 0;

				Menu_SprayBan(iParam1);
			}
			else
			{
				if (SprayBanClient(iParam1, target, StringToInt(sOption), "Inappropriate Spray"))
				{
					CShowActivity2(iParam1, "{green}[SprayManager]{olive} ", "%t", "Activity Spray Banned", target);
					LogAction(iParam1, target, "\"%L\" spray banned \"%L\" (Hash: \"%s\")", iParam1, target, g_sSprayHash[target]);
				}

				g_iSprayBanTarget[iParam1] = 0;
			}
		}
	}
	return 0;
}

void Menu_BanSpray(int client)
{
	if (!IsValidClient(client))
		return;

	int iClientsToDisplay;

	Menu BanSprayMenu = new Menu(MenuHandler_Menu_BanSpray);
	BanSprayMenu.SetTitle("[SprayManager] %T", "Menu Ban Spray Title", client);
	BanSprayMenu.ExitBackButton =  true;

	for (int i = 1; i <= MaxClients; i++)
	{
		if (!IsValidClient(i))
			continue;

		if (g_bSprayHashBanned[i])
			continue;

		char sUserID[16];
		char sBuff[64];
		int iUserID = GetClientUserId(i);

		Format(sBuff, sizeof(sBuff), "%N (#%d)", i, iUserID);
		Format(sUserID, sizeof(sUserID), "%d", iUserID);

		BanSprayMenu.AddItem(sUserID, sBuff);
		iClientsToDisplay++;
	}

	if (!iClientsToDisplay)
		AddTranslatedMenuItem(BanSprayMenu, "", "Menu No Eligible Clients", client, ITEMDRAW_DISABLED);

	BanSprayMenu.Display(client, MENU_TIME_FOREVER);
}

int MenuHandler_Menu_BanSpray(Menu hMenu, MenuAction action, int iParam1, int iParam2)
{
	switch (action)
	{
		case MenuAction_End:
			delete hMenu;

		case MenuAction_Cancel:
		{
			if (iParam2 == MenuCancel_ExitBack && g_hTopMenu != null)
				g_hTopMenu.Display(iParam1, TopMenuPosition_LastCategory);
		}

		case MenuAction_Select:
		{
			char sOption[32];
			hMenu.GetItem(iParam2, sOption, sizeof(sOption));

			int target = GetClientOfUserId(StringToInt(sOption));

			if (!IsValidClient(target))
			{
				CPrintToChat(iParam1, "{green}[SprayManager]{default} %t", "Player no longer available");

				Menu_BanSpray(iParam1);
			}
			else
			{
				if (BanClientSpray(iParam1, target))
				{
					CShowActivity2(iParam1, "{green}[SprayManager]{olive} ", "%t", "Activity Spray Hash Banned", target);
					LogAction(iParam1, target, "\"%L\" banned \"%L\"'s spray (Hash: \"%s\")", iParam1, target, g_sSprayHash[target]);
				}
			}
		}
	}
	return 0;
}

void Menu_Unban(int client)
{
	if (!IsValidClient(client))
		return;

	int iBannedClients;

	Menu UnbanSprayMenu = new Menu(MenuHandler_Menu_UnbanSpray);
	UnbanSprayMenu.SetTitle("[SprayManager] %T", "Menu Unban Select Title", client);
	UnbanSprayMenu.ExitBackButton =  true;

	for (int i = 1; i <= MaxClients; i++)
	{
		if (!IsValidClient(i))
			continue;

		if (!g_bSprayHashBanned[i] && !g_bSprayBanned[i])
			continue;

		char sUserID[16];
		char sBuff[64];
		int iUserID = GetClientUserId(i);

		Format(sBuff, sizeof(sBuff), "%N (#%d)", i, iUserID);
		Format(sUserID, sizeof(sUserID), "%d", iUserID);

		UnbanSprayMenu.AddItem(sUserID, sBuff);
		iBannedClients++;
	}

	if (!iBannedClients)
		AddTranslatedMenuItem(UnbanSprayMenu, "", "Menu No Banned Clients", client, ITEMDRAW_DISABLED);

	UnbanSprayMenu.Display(client, MENU_TIME_FOREVER);
}

int MenuHandler_Menu_UnbanSpray(Menu hMenu, MenuAction action, int iParam1, int iParam2)
{
	switch (action)
	{
		case MenuAction_End:
			delete hMenu;

		case MenuAction_Cancel:
		{
			if (iParam2 == MenuCancel_ExitBack && g_hTopMenu != null)
				g_hTopMenu.Display(iParam1, TopMenuPosition_LastCategory);
		}

		case MenuAction_Select:
		{
			char sOption[32];
			hMenu.GetItem(iParam2, sOption, sizeof(sOption));

			int target = GetClientOfUserId(StringToInt(sOption));

			if (!IsValidClient(target))
			{
				CPrintToChat(iParam1, "{green}[SprayManager]{default} %t", "Player no longer available");

				Menu_Unban(iParam1);
			}
			else
			{
				g_bInvokedThroughListMenu[iParam1] = false;
				Menu_ListBans_Target(iParam1, target);
			}
		}
	}
	return 0;
}

void Menu_ListBans_Target(int client, int target)
{
	Menu ListTargetMenu = new Menu(MenuHandler_Menu_ListBans_Target);
	ListTargetMenu.SetTitle("[SprayManager] %T", "Menu Banned Client Title", client, target, GetClientUserId(target));
	ListTargetMenu.ExitBackButton = true;

	char sBanType[64];
	char sUserID[32];
	int iUserID = GetClientUserId(target);

	Format(sUserID, sizeof(sUserID), "%d", iUserID);

	if (g_bSprayHashBanned[target] && !g_bSprayBanned[target])
	{
		FormatEx(sBanType, sizeof(sBanType), "%T", "Ban Type Hash", client);

		ListTargetMenu.AddItem("", sBanType, ITEMDRAW_DISABLED);
		ListTargetMenu.AddItem("", "", ITEMDRAW_SPACER);

		AddTranslatedMenuItem(ListTargetMenu, sUserID, "Menu Unban Client", client);

		ListTargetMenu.Display(client, MENU_TIME_FOREVER);
		return;
	}

	char sBanExpiryDate[128];
	char sBanIssuedDate[128];
	char sBanDuration[128];
	char sBannedBy[192];
	char sBanReason[128];
	int iBanExpiryDate = g_iSprayUnbanTimestamp[target];
	int iBanIssuedDate = g_iSprayBanTimestamp[target];
	int iBanDuration = iBanExpiryDate ? ((iBanExpiryDate - iBanIssuedDate) / 60) : 0;

	if (iBanExpiryDate)
	{
		FormatTime(sBanExpiryDate, sizeof(sBanExpiryDate), NULL_STRING, iBanExpiryDate);
		Format(sBanDuration, sizeof(sBanDuration), "%T", SingularOrMultiple(iBanDuration) ? "Time Minutes" : "Time Minute", client, iBanDuration);
	}
	else
	{
		FormatEx(sBanExpiryDate, sizeof(sBanExpiryDate), "%T", "Ban Never Expires", client);
		FormatEx(sBanDuration, sizeof(sBanDuration), "%T", "Length Permanent", client);
	}

	FormatTime(sBanIssuedDate, sizeof(sBanIssuedDate), NULL_STRING, iBanIssuedDate);
	Format(sBannedBy, sizeof(sBannedBy), "%T", "Ban Info Banned By", client, g_sBanIssuer[target], g_sBanIssuerSID[target]);
	Format(sBanDuration, sizeof(sBanDuration), "%T", "Ban Info Duration", client, sBanDuration);
	Format(sBanExpiryDate, sizeof(sBanExpiryDate), "%T", "Ban Info Expires", client, sBanExpiryDate);
	Format(sBanIssuedDate, sizeof(sBanIssuedDate), "%T", "Ban Info Issued", client, sBanIssuedDate);
	Format(sBanReason, sizeof(sBanReason), "%T", "Ban Info Reason", client, g_sBanReason[target]);

	if (g_bSprayBanned[target] && g_bSprayHashBanned[target])
		FormatEx(sBanType, sizeof(sBanType), "%T", "Ban Type Spray And Hash", client);
	else if (g_bSprayBanned[target])
		FormatEx(sBanType, sizeof(sBanType), "%T", "Ban Type Spray", client);

	ListTargetMenu.AddItem("", sBanType, ITEMDRAW_DISABLED);
	ListTargetMenu.AddItem("", sBannedBy, ITEMDRAW_DISABLED);
	ListTargetMenu.AddItem("", sBanIssuedDate, ITEMDRAW_DISABLED);
	ListTargetMenu.AddItem("", sBanExpiryDate, ITEMDRAW_DISABLED);
	ListTargetMenu.AddItem("", sBanDuration, ITEMDRAW_DISABLED);
	ListTargetMenu.AddItem("", sBanReason, ITEMDRAW_DISABLED);

	AddTranslatedMenuItem(ListTargetMenu, sUserID, "Menu Unban Client", client);

	ListTargetMenu.Display(client, MENU_TIME_FOREVER);
}

int MenuHandler_Menu_ListBans_Target(Menu hMenu, MenuAction action, int iParam1, int iParam2)
{
	switch (action)
	{
		case MenuAction_End:
			delete hMenu;

		case MenuAction_Cancel:
		{
			if (iParam2 == MenuCancel_ExitBack)
			{
				if (g_bInvokedThroughListMenu[iParam1])
					Menu_ListBans(iParam1);
				else
					Menu_Unban(iParam1);
			}
		}

		case MenuAction_Select:
		{
			char sOption[32];
			hMenu.GetItem(iParam2, sOption, sizeof(sOption));
			int target = GetClientOfUserId(StringToInt(sOption));

			if (!IsValidClient(target))
			{
				CPrintToChat(iParam1, "{green}[SprayManager]{default} %t", "Player no longer available");
				Menu_ListBans(iParam1);
			}
			else
			{
				if (g_bSprayBanned[target] && g_bSprayHashBanned[target])
				{
					Menu MenuUnbanMode = new Menu(MenuHandler_Menu_UnbanMode);
					MenuUnbanMode.SetTitle("[SprayManager] %T", "Menu Unban Confirm Title", iParam1, target);
					MenuUnbanMode.ExitBackButton = true;

					AddTranslatedMenuItem(MenuUnbanMode, "H", "Menu Remove Hash Ban", iParam1);
					AddTranslatedMenuItem(MenuUnbanMode, "S", "Menu Remove Spray Ban", iParam1);
					AddTranslatedMenuItem(MenuUnbanMode, "B", "Menu Remove Both", iParam1);

					g_iSprayUnbanTarget[iParam1] = target;

					MenuUnbanMode.Display(iParam1, MENU_TIME_FOREVER);

					return 0;
				}

				Menu MenuConfirmUnban = new Menu(MenuHandler_Menu_ConfirmUnban);
				MenuConfirmUnban.SetTitle("[SprayManager] %T", "Menu Unban Confirm Title", iParam1, target);
				MenuConfirmUnban.ExitBackButton = true;

				AddTranslatedMenuItem(MenuConfirmUnban, "Y", "Yes", iParam1);
				AddTranslatedMenuItem(MenuConfirmUnban, "N", "No", iParam1);

				g_iSprayUnbanTarget[iParam1] = target;

				MenuConfirmUnban.Display(iParam1, MENU_TIME_FOREVER);
			}
		}
	}
	return 0;
}

int MenuHandler_Menu_UnbanMode(Menu hMenu, MenuAction action, int iParam1, int iParam2)
{
	switch (action)
	{
		case MenuAction_End:
			delete hMenu;

		case MenuAction_Cancel:
		{
			if (iParam2 == MenuCancel_ExitBack)
			{
				if (IsValidClient(g_iSprayUnbanTarget[iParam1]))
					Menu_ListBans_Target(iParam1, g_iSprayUnbanTarget[iParam1]);
				else if (g_hTopMenu != null)
					g_hTopMenu.Display(iParam1, TopMenuPosition_LastCategory);
				else
					delete hMenu;
			}
		}

		case MenuAction_Select:
		{
			char sOption[2];
			hMenu.GetItem(iParam2, sOption, sizeof(sOption));

			int target = g_iSprayUnbanTarget[iParam1];

			if (!IsValidClient(target))
			{
				CPrintToChat(iParam1, "{green}[SprayManager]{default} %t", "Player no longer available");

				g_iSprayUnbanTarget[iParam1] = 0;

				if (g_hTopMenu != null)
					g_hTopMenu.Display(iParam1, TopMenuPosition_LastCategory);
				else
					delete hMenu;
			}
			else
			{
				if (sOption[0] == 'H')
				{
					if (UnbanClientSpray(iParam1, target))
					{
						CShowActivity2(iParam1, "{green}[SprayManager]{olive} ", "%t", "Activity Spray Hash Unbanned", target);
						LogAction(iParam1, target, "\"%L\" unbanned \"%L\"'s spray", iParam1, target);
					}
				}
				else if (sOption[0] == 'S')
				{
					if (SprayUnbanClient(target, iParam1))
					{
						CShowActivity2(iParam1, "{green}[SprayManager]{olive} ", "%t", "Activity Spray Unbanned", target);
						LogAction(iParam1, target, "\"%L\" spray unbanned \"%L\"", iParam1, target);
					}
				}
				else if (sOption[0] == 'B')
				{
					if (SprayUnbanClient(target, iParam1) && UnbanClientSpray(iParam1, target))
					{
						CShowActivity2(iParam1, "{green}[SprayManager]{olive} ", "%t", "Activity Spray Unbanned", target);
						LogAction(iParam1, target, "\"%L\" spray unbanned \"%L\"", iParam1, target);
					}
				}

				g_iSprayUnbanTarget[iParam1] = 0;
			}
		}
	}
	return 0;
}

int MenuHandler_Menu_ConfirmUnban(Menu hMenu, MenuAction action, int iParam1, int iParam2)
{
	switch (action)
	{
		case MenuAction_End:
			delete hMenu;

		case MenuAction_Cancel:
		{
			if (iParam2 == MenuCancel_ExitBack)
			{
				if (IsValidClient(g_iSprayUnbanTarget[iParam1]))
					Menu_ListBans_Target(iParam1, g_iSprayUnbanTarget[iParam1]);
				else if (g_hTopMenu != null)
					g_hTopMenu.Display(iParam1, TopMenuPosition_LastCategory);
				else
					delete hMenu;
			}
		}

		case MenuAction_Select:
		{
			char sOption[2];
			hMenu.GetItem(iParam2, sOption, sizeof(sOption));

			int target = g_iSprayUnbanTarget[iParam1];

			if (!IsValidClient(target))
			{
				CPrintToChat(iParam1, "{green}[SprayManager]{default} %t", "Player no longer available");

				g_iSprayUnbanTarget[iParam1] = 0;

				if (g_hTopMenu != null)
					g_hTopMenu.Display(iParam1, TopMenuPosition_LastCategory);
				else
					delete hMenu;
			}
			else
			{
				if (sOption[0] == 'Y')
				{
					if (g_bSprayHashBanned[target] && g_bSprayBanned[target])
					{
						if (SprayUnbanClient(target, iParam1) && UnbanClientSpray(iParam1, target))
						{
							CShowActivity2(iParam1, "{green}[SprayManager]{olive} ", "%t", "Activity Spray Unbanned", target);
							LogAction(iParam1, target, "\"%L\" spray unbanned \"%L\"", iParam1, target);
						}
					}
					else if (g_bSprayBanned[target])
					{
						if (SprayUnbanClient(target, iParam1))
						{
							CShowActivity2(iParam1, "{green}[SprayManager]{olive} ", "%t", "Activity Spray Unbanned", target);
							LogAction(iParam1, target, "\"%L\" spray unbanned \"%L\"", iParam1, target);
						}
					}
					else if (g_bSprayHashBanned[target])
					{
						if (UnbanClientSpray(iParam1, target))
						{
							CShowActivity2(iParam1, "{green}[SprayManager]{olive} ", "%t", "Activity Spray Hash Unbanned", target);
							LogAction(iParam1, target, "\"%L\" unbanned \"%L\"'s spray", iParam1, target);
						}
					}

					g_iSprayUnbanTarget[iParam1] = 0;
				}
				else if (sOption[0] == 'N')
				{
					Menu_ListBans_Target(iParam1, g_iSprayUnbanTarget[iParam1]);
					g_iSprayUnbanTarget[iParam1] = 0;
				}
			}
		}
	}
	return 0;
}