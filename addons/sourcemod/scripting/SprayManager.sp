#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <clientprefs>
#include <cstrike>
#include <multicolors>
#include <LagReducer>

#undef REQUIRE_PLUGIN
#include <adminmenu>
#define REQUIRE_PLUGIN

#pragma newdecls required

enum
{
	AABBMinX = 0,
	AABBMaxX = 1,
	AABBMinY = 2,
	AABBMaxY = 3,
	AABBMinZ = 4,
	AABBMaxZ = 5,
	AABBTotalPoints = 6
}

Handle g_hDatabase = null;
Handle g_hRoundEndTimer = null;
Handle g_hTopMenu = null;
Handle g_hWantsToSeeNSFWCookie = null;

ConVar g_cvarHookedDecalFrequency = null;
ConVar g_cvarDecalFrequency = null;
ConVar g_cvarUseProximityCheck = null;
ConVar g_cvarSendSpraysToConnectingClients = null;
ConVar g_cvarUsePersistentSprays = null;
ConVar g_cvarMaxSprayLifetime = null;
ConVar g_cvarEnableSprays = null;
ConVar g_cvarAuthorizedFlags = null;

int g_iNSFWDecalIndex;
int g_iHiddenDecalIndex;
int g_iTransparentDecalIndex;
int g_iOldDecalFreqVal;
int g_iAllowSpray;

bool g_bLoadedLate;
bool g_bSQLite;
bool g_bGotBans;
bool g_bGotBlacklist;
bool g_bGotNSFWList;
bool g_bFullyConnected;
bool g_bSkipDecalHook;

char g_sBanIssuer[MAXPLAYERS + 1][64];
char g_sBanIssuerSID[MAXPLAYERS + 1][32];
char g_sBanReason[MAXPLAYERS + 1][32];
char g_sSprayHash[MAXPLAYERS + 1][16];

int g_iClientToClientSprayLifetime[MAXPLAYERS + 1][MAXPLAYERS + 1];
int g_iClientSprayLifetime[MAXPLAYERS + 1] = { 2, ... };
int g_iSprayLifetime[MAXPLAYERS + 1];
int g_iSprayBanTimestamp[MAXPLAYERS + 1];
int g_iSprayUnbanTimestamp[MAXPLAYERS + 1] = { -1, ... };
int g_iSprayBanTarget[MAXPLAYERS + 1];
int g_iSprayUnbanTarget[MAXPLAYERS + 1];
int g_iSprayTraceTarget[MAXPLAYERS + 1];
int g_iBanTarget[MAXPLAYERS + 1];
int g_iDecalEntity[MAXPLAYERS + 1];
int g_iAuthorizedFlags[32] = { -1, ...};

bool g_bEnableSprays = true;
bool g_bWantsToSeeNSFWSprays[MAXPLAYERS + 1];
bool g_bHasNSFWSpray[MAXPLAYERS + 1];
bool g_bMarkedNSFWByAdmin[MAXPLAYERS + 1];
bool g_bSprayBanned[MAXPLAYERS + 1];
bool g_bSprayHashBanned[MAXPLAYERS + 1];
bool g_bInvokedThroughTopMenu[MAXPLAYERS + 1];
bool g_bInvokedThroughListMenu[MAXPLAYERS + 1];
bool g_bHasSprayHidden[MAXPLAYERS + 1][MAXPLAYERS + 1];
bool g_bSprayNotified[MAXPLAYERS + 1] = { false, ... };

float ACTUAL_NULL_VECTOR[3] = { 16384.0, ... }; //durr
float g_fNextSprayTime[MAXPLAYERS + 1];
float g_vecSprayOrigin[MAXPLAYERS + 1][3];
float g_SprayAABB[MAXPLAYERS + 1][AABBTotalPoints];

int g_iAdminFlags[6][2] = {
	{'b', ADMFLAG_GENERIC},
	{'o', ADMFLAG_CUSTOM1},
	{'p', ADMFLAG_CUSTOM2},
	{'h', ADMFLAG_CONVARS},
	{'m', ADMFLAG_RCON},
	{'z', ADMFLAG_ROOT}
};

public Plugin myinfo =
{
	name		= "Spray Manager",
	description	= "Help manage player sprays.",
	author		= "Obus, maxime1907",
	version		= "2.2.1",
	url			= ""
}

public APLRes AskPluginLoad2(Handle hThis, bool bLate, char[] err, int iErrLen)
{
	g_bLoadedLate = bLate;

	return APLRes_Success;
}

public void OnPluginStart()
{
	LoadTranslations("common.phrases");

	AddFileToDownloadsTable("materials/spraymanager/1.vtf");
	AddFileToDownloadsTable("materials/spraymanager/1.vmt");

	AddFileToDownloadsTable("materials/spraymanager/2.vtf");
	AddFileToDownloadsTable("materials/spraymanager/2.vmt");

	AddFileToDownloadsTable("materials/spraymanager/3.vtf");
	AddFileToDownloadsTable("materials/spraymanager/3.vmt");

	RegConsoleCmd("sm_marknsfw", Command_MarkNSFW, "Marks your spray as NSFW");
	RegConsoleCmd("sm_marksfw", Command_MarkSFW, "Marks your spray as SFW");
	RegConsoleCmd("sm_nsfw", Command_NSFW, "Opt-in or out of seeing NSFW sprays");
	RegConsoleCmd("sm_hs", Command_HideSpray, "Hides a players spray");
	RegConsoleCmd("sm_us", Command_UnhideSpray, "Unhides a players spray");

	RegAdminCmd("sm_spray", Command_AdminSpray, ADMFLAG_GENERIC, "Spray a clients spray");
	RegAdminCmd("sm_sprayban", Command_SprayBan, ADMFLAG_GENERIC, "Ban a client from spraying");
	RegAdminCmd("sm_sprayunban", Command_SprayUnban, ADMFLAG_GENERIC, "Unban a client and allow them to spray");
	RegAdminCmd("sm_banspray", Command_BanSpray, ADMFLAG_GENERIC, "Ban a clients spray from being sprayed (Note: This will not spray-ban the client, it will only ban the spray which they are currently using)");
	RegAdminCmd("sm_unbanspray", Command_UnbanSpray, ADMFLAG_GENERIC, "Unban a clients spray (Note: This will not spray-unban the client, it will only unban the spray which they are currently using)");
	RegAdminCmd("sm_tracespray", Command_TraceSpray, ADMFLAG_GENERIC, "Finds a spray under your crosshair");
	RegAdminCmd("sm_spraytrace", Command_TraceSpray, ADMFLAG_GENERIC, "Finds a spray under your crosshair");
	RegAdminCmd("sm_removespray", Command_RemoveSpray, ADMFLAG_GENERIC, "Finds and removes a spray under your crosshair");
	RegAdminCmd("sm_forcensfw", Command_ForceNSFW, ADMFLAG_GENERIC, "Forces a spray to be marked NSFW");
	RegAdminCmd("sm_forcesfw", Command_ForceSFW, ADMFLAG_GENERIC, "Forces a spray to be marked SFW");
	RegAdminCmd("sm_spraymanagerupdatedb", Command_SprayManager_UpdateInfo, ADMFLAG_CHEATS, "Updates all clients info");
	RegAdminCmd("sm_spraymanagerrefreshdb", Command_SprayManager_UpdateInfo, ADMFLAG_CHEATS, "Updates all clients info");
	RegAdminCmd("sm_spraymanagerreloaddb", Command_SprayManager_UpdateInfo, ADMFLAG_CHEATS, "Updates all clients info");

	g_hWantsToSeeNSFWCookie = RegClientCookie("spraymanager_wanttoseensfw", "Does this client want to see NSFW sprays?", CookieAccess_Private);

	AddTempEntHook("Player Decal", HookDecal);
	AddNormalSoundHook(HookSprayer);

	TopMenu hTopMenu;

	if (LibraryExists("adminmenu") && ((hTopMenu = GetAdminTopMenu()) != null))
		OnAdminMenuReady(hTopMenu);

	g_cvarHookedDecalFrequency = FindConVar("decalfrequency");
	g_iOldDecalFreqVal = g_cvarHookedDecalFrequency.IntValue;
	g_cvarHookedDecalFrequency.IntValue = 0;

	g_cvarDecalFrequency = CreateConVar("sm_decalfrequency", "10.0", "Controls how often clients can spray", FCVAR_NOTIFY);

	g_cvarEnableSprays = CreateConVar("sm_spraymanager_enablesprays", "1", "Enable or disable all sprays usage");
	g_cvarAuthorizedFlags = CreateConVar("sm_spraymanager_authorizedflags", "b,z", "Authorizes specific flags to spray when usage is disabled server side");

	g_cvarEnableSprays.AddChangeHook(ConVarChanged_EnableSpray);
	g_cvarAuthorizedFlags.AddChangeHook(ConVarChanged_AuthorizedFlags);

	HookConVarChange(g_cvarHookedDecalFrequency, ConVarChanged_DecalFrequency);

	g_cvarUseProximityCheck = CreateConVar("sm_spraymanager_blockoverspraying", "1", "Blocks people from overspraying each other", FCVAR_NOTIFY);

	g_cvarSendSpraysToConnectingClients = CreateConVar("sm_spraymanager_sendspraystoconnectingclients", "1", "Try to send active sprays to connecting clients");

	g_cvarUsePersistentSprays = CreateConVar("sm_spraymanager_persistentsprays", "1", "Re-spray sprays when their client-sided lifetime (in rounds) expires");

	g_cvarMaxSprayLifetime = CreateConVar("sm_spraymanager_maxspraylifetime", "2", "If not using persistent sprays, remove sprays after their global lifetime (in rounds) exceeds this number");

	AutoExecConfig(true);
	GetConVars();

	if (g_bLoadedLate)
	{
		for (int i = 1; i <= MaxClients; i++)
		{
			if (!IsClientInGame(i) || IsFakeClient(i))
				continue;

			OnClientPutInServer(i);
			OnClientCookiesCached(i);
		}
	}

	InitializeSQL();
}

public void OnPluginEnd()
{
	RemoveAllSprays();

	RemoveTempEntHook("Player Decal", HookDecal);
	RemoveNormalSoundHook(HookSprayer);
	UnhookConVarChange(g_cvarHookedDecalFrequency, ConVarChanged_DecalFrequency);

	if (g_hDatabase != null)
		delete g_hDatabase;

	if (g_hRoundEndTimer != null)
		delete g_hRoundEndTimer;

	g_cvarHookedDecalFrequency.IntValue = g_iOldDecalFreqVal;
}

public void OnMapStart()
{
	g_iNSFWDecalIndex = PrecacheDecal("spraymanager/1.vtf", true);
	g_iHiddenDecalIndex = PrecacheDecal("spraymanager/2.vtf", true);
	g_iTransparentDecalIndex = PrecacheDecal("spraymanager/3.vtf", true);
}

public void OnMapEnd()
{
	if (g_hRoundEndTimer != null)
		delete g_hRoundEndTimer;
}

public void OnClientPutInServer(int client)
{
	if (QueryClientConVar(client, "r_spray_lifetime", CvarQueryFinished_SprayLifeTime) == QUERYCOOKIE_FAILED)
		g_iClientSprayLifetime[client] = 2;
}

public void OnClientCookiesCached(int client)
{
	char sWantsToSeeNSFW[8];
	GetClientCookie(client, g_hWantsToSeeNSFWCookie, sWantsToSeeNSFW, sizeof(sWantsToSeeNSFW));

	g_bWantsToSeeNSFWSprays[client] = view_as<bool>(StringToInt(sWantsToSeeNSFW));
}

public void CvarQueryFinished_SprayLifeTime(QueryCookie cookie, int client, ConVarQueryResult res, const char[] sCvarName, const char[] sCvarVal)
{
	if (res != ConVarQuery_Okay)
	{
		g_iClientSprayLifetime[client] = 2;
		return;
	}

	int iVal = StringToInt(sCvarVal);

	g_iClientSprayLifetime[client] = iVal <= 0 ? 1 : iVal > 1000 ? 1000 : iVal;
}

public void OnClientPostAdminCheck(int client)
{
	if (g_hDatabase != null)
	{
		ClearPlayerInfo(client);
		GetPlayerDecalFile(client, g_sSprayHash[client], sizeof(g_sSprayHash[]));
		UpdatePlayerInfo(client);
		UpdateSprayHashInfo(client);
		UpdateNSFWInfo(client);
	}

	if (g_cvarSendSpraysToConnectingClients.BoolValue)
	{
		for (int i = 1; i <= MaxClients; i++)
		{
			if (!IsValidClient(i) || IsFakeClient(i))
				continue;

			if (IsVectorZero(g_vecSprayOrigin[i]))
				continue;

			if (g_bHasNSFWSpray[i] && !g_bWantsToSeeNSFWSprays[client])
			{
				PaintWorldDecalToOne(g_iNSFWDecalIndex, g_vecSprayOrigin[i], client);
				continue;
			}

			g_bSkipDecalHook = true;
			SprayClientDecalToOne(i, client, g_iDecalEntity[i], g_vecSprayOrigin[i]);
			g_iClientToClientSprayLifetime[client][i] = 0;
			g_bSkipDecalHook = false;
		}
	}
}

public void OnClientDisconnect(int client)
{
	if (IsValidClient(client))
	{
		for (int i = 1; i <= MaxClients; i++)
		{
			if (!IsValidClient(i))
				continue;

			if (!g_bHasSprayHidden[i][client] && g_bWantsToSeeNSFWSprays[i])
				continue;

			PaintWorldDecalToOne(g_iTransparentDecalIndex, g_vecSprayOrigin[client], i);
		}

		g_bSkipDecalHook = true;
		SprayClientDecalToAll(client, 0, ACTUAL_NULL_VECTOR);
		g_bSkipDecalHook = false;
	}

	ClearPlayerInfo(client);
}

public Action CS_OnTerminateRound(float &fDelay, CSRoundEndReason &reason)
{
	if (g_cvarUsePersistentSprays.BoolValue)
	{
		g_hRoundEndTimer = CreateTimer(fDelay + 0.5, Timer_ProcessPersistentSprays);

		return Plugin_Continue;
	}

	g_hRoundEndTimer = CreateTimer(fDelay, Timer_ResetOldSprays);

	return Plugin_Continue;
}

public Action OnPlayerRunCmd(int client, int &buttons, int &impulse)
{
	if (!impulse || impulse != 201)
		return Plugin_Continue;

	if (CheckCommandAccess(client, "sm_sprayban", ADMFLAG_GENERIC))
	{
		if (!g_bSprayBanned[client] && !g_bSprayHashBanned[client])
		{
			//if (IsPlayerAlive(client))
				//if (TracePlayerAnglesRanged(client, 128.0))
					//return Plugin_Continue;

			ForceSpray(client, client, false);
			g_fNextSprayTime[client] = 0.0;

			impulse = 0; //wow

			return Plugin_Changed;
		}
	}

	if (!g_bEnableSprays)
	{
		CPrintToChat(client, "{green}[SprayManager] {white}Sorry, all sprays are currently disabled on the server.");
		return Plugin_Handled;
	}

	return Plugin_Continue;
}

public void OnAdminMenuReady(Handle hAdminMenu)
{
	if (hAdminMenu == g_hTopMenu)
		return;

	g_hTopMenu = CloneHandle(hAdminMenu);

	TopMenuObject hMenuObj = AddToTopMenu(g_hTopMenu, "SprayManagerCommands", TopMenuObject_Category, TopMenu_Main_Handler, INVALID_TOPMENUOBJECT);

	if (hMenuObj == INVALID_TOPMENUOBJECT)
		return;

	AddToTopMenu(g_hTopMenu, "SprayManager_Spraybanlist", TopMenuObject_Item, Handler_SprayBanList, hMenuObj, "", ADMFLAG_GENERIC);
	AddToTopMenu(g_hTopMenu, "SprayManager_Tracespray", TopMenuObject_Item, Handler_TraceSpray, hMenuObj, "sm_tracespray", ADMFLAG_GENERIC);
	AddToTopMenu(g_hTopMenu, "SprayManager_Spray", TopMenuObject_Item, Handler_Spray, hMenuObj, "sm_spray", ADMFLAG_GENERIC);
	AddToTopMenu(g_hTopMenu, "SprayManager_Sprayban", TopMenuObject_Item, Handler_SprayBan, hMenuObj, "sm_sprayban", ADMFLAG_GENERIC);
	AddToTopMenu(g_hTopMenu, "SprayManager_Banspray", TopMenuObject_Item, Handler_BanSpray, hMenuObj, "sm_banspray", ADMFLAG_GENERIC);
	AddToTopMenu(g_hTopMenu, "SprayManager_Unban", TopMenuObject_Item, Handler_UnbanSpray, hMenuObj, "sm_unbanspray", ADMFLAG_GENERIC);
}

public void OnLibraryRemoved(const char[] sLibraryName)
{
	if (strcmp(sLibraryName, "adminmenu") == 0)
		delete g_hTopMenu;
}

public void TopMenu_Main_Handler(Handle hMenu, TopMenuAction hAction, TopMenuObject hObjID, int iParam1, char[] sBuffer, int iBufflen)
{
	if (hAction == TopMenuAction_DisplayOption)
		Format(sBuffer, iBufflen, "%s", "SprayManager Commands", iParam1);
	else if (hAction == TopMenuAction_DisplayTitle)
		Format(sBuffer, iBufflen, "%s", "SprayManager Commands:", iParam1);
}

public void Handler_SprayBanList(Handle hMenu, TopMenuAction hAction, TopMenuObject hObjID, int iParam1, char[] sBuffer, int iBufflen)
{
	if (hAction == TopMenuAction_DisplayOption)
		Format(sBuffer, iBufflen, "%s", "List Spray Banned Clients", iParam1);
	else if (hAction == TopMenuAction_SelectOption)
		Menu_ListBans(iParam1);
}

public void Handler_TraceSpray(Handle hMenu, TopMenuAction hAction, TopMenuObject hObjID, int iParam1, char[] sBuffer, int iBufflen)
{
	if (hAction == TopMenuAction_DisplayOption)
	{
		Format(sBuffer, iBufflen, "%s", "Trace a Spray", iParam1);
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

		CPrintToChat(iParam1, "{green}[SprayManager]{default} Trace did not hit any sprays.");

		if (g_hTopMenu != null)
			DisplayTopMenu(g_hTopMenu, iParam1, TopMenuPosition_LastCategory);
	}
}

public void Handler_Spray(Handle hMenu, TopMenuAction hAction, TopMenuObject hObjID, int iParam1, char[] sBuffer, int iBufflen)
{
	if (hAction == TopMenuAction_DisplayOption)
		Format(sBuffer, iBufflen, "%s", "Spray a Client's Spray", iParam1);
	else if (hAction == TopMenuAction_SelectOption)
		Menu_Spray(iParam1);
}

public void Handler_SprayBan(Handle hMenu, TopMenuAction hAction, TopMenuObject hObjID, int iParam1, char[] sBuffer, int iBufflen)
{
	if (hAction == TopMenuAction_DisplayOption)
		Format(sBuffer, iBufflen, "%s", "Spray Ban a Client", iParam1);
	else if (hAction == TopMenuAction_SelectOption)
		Menu_SprayBan(iParam1);
}

public void Handler_BanSpray(Handle hMenu, TopMenuAction hAction, TopMenuObject hObjID, int iParam1, char[] sBuffer, int iBufflen)
{
	if (hAction == TopMenuAction_DisplayOption)
		Format(sBuffer, iBufflen, "%s", "Ban a Client's Spray", iParam1);
	else if (hAction == TopMenuAction_SelectOption)
		Menu_BanSpray(iParam1);
}

public void Handler_UnbanSpray(Handle hMenu, TopMenuAction hAction, TopMenuObject hObjID, int iParam1, char[] sBuffer, int iBufflen)
{
	if (hAction == TopMenuAction_DisplayOption)
		Format(sBuffer, iBufflen, "%s", "Unban a Client", iParam1);
	else if (hAction == TopMenuAction_SelectOption)
		Menu_Unban(iParam1);
}

void Menu_ListBans(int client)
{
	if (!IsValidClient(client))
		return;

	int iBannedClients;

	Menu ListMenu = new Menu(MenuHandler_Menu_ListBans);
	ListMenu.SetTitle("[SprayManager] Banned Clients:");
	ListMenu.ExitBackButton =  true;

	for (int i = 1; i <= MaxClients; i++)
	{
		if (!IsValidClient(i) || IsFakeClient(i))
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
		ListMenu.AddItem("", "No Banned Clients.", ITEMDRAW_DISABLED);

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
				DisplayTopMenu(g_hTopMenu, iParam1, TopMenuPosition_LastCategory);
		}

		case MenuAction_Select:
		{
			char sOption[32];
			hMenu.GetItem(iParam2, sOption, sizeof(sOption));

			int target = GetClientOfUserId(StringToInt(sOption));

			if (!IsValidClient(target))
			{
				CPrintToChat(iParam1, "{green}[SprayManager]{default} Target no longer available.");

				if (g_hTopMenu != null)
					DisplayTopMenu(g_hTopMenu, iParam1, TopMenuPosition_LastCategory);
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
	char sSteamID[32];
	GetClientAuthId(target, AuthId_Steam2, sSteamID, sizeof(sSteamID));

	Menu TraceMenu = new Menu(MenuHandler_Menu_Trace);
	TraceMenu.SetTitle("Sprayed by: %N (%s)", target, sSteamID);

	if (g_bInvokedThroughTopMenu[client])
		TraceMenu.ExitBackButton = true;

	TraceMenu.AddItem("1", "Warn Client");
	TraceMenu.AddItem("2", "Slap and Warn Client", (CheckCommandAccess(client, "", ADMFLAG_CHEATS, true))?ITEMDRAW_DEFAULT:ITEMDRAW_DISABLED);
	TraceMenu.AddItem("3", "Kick Client");
	TraceMenu.AddItem("4", "Spray Ban Client");
	TraceMenu.AddItem("5", "Ban Clients Spray");
	TraceMenu.AddItem("", "", ITEMDRAW_SPACER);
	TraceMenu.AddItem("6", "Ban Client");

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
				DisplayTopMenu(g_hTopMenu, iParam1, TopMenuPosition_LastCategory);
		}

		case MenuAction_Select:
		{
			char sOption[2];
			hMenu.GetItem(iParam2, sOption, sizeof(sOption));

			int target = g_iSprayTraceTarget[iParam1];

			if (!IsValidClient(target))
			{
				CPrintToChat(iParam1, "{green}[SprayManager]{default} Target no longer available.");

				g_bInvokedThroughTopMenu[iParam1] = false;

				if (g_hTopMenu != null)
					DisplayTopMenu(g_hTopMenu, iParam1, TopMenuPosition_LastCategory);
				else
					delete hMenu;
			}
			else
			{
				switch (StringToInt(sOption))
				{
					case 1:
					{
						CPrintToChat(target, "{green}[SprayManager]{default} Your spray is not allowed, change it.");
						LogAction(target, iParam1, "[SprayManager] \"%L\" has been warned for his spray by \"%L\"", target, iParam1);
						NotifyAdmins(iParam1, target, "{default}has been {green}warned {default}for his spray");
						Menu_Trace(iParam1, target);
					}

					case 2:
					{
						SlapPlayer(target, 0);
						CPrintToChat(target, "{green}[SprayManager]{default} Your spray is not allowed, change it.");
						LogAction(target, iParam1, "[SprayManager] \"%L\" has been warned and slapped for his spray by \"%L\"", target, iParam1);
						NotifyAdmins(iParam1, target, "{default}has been {green}warned and slapped {default}for his spray");
						Menu_Trace(iParam1, target);
					}

					case 3:
					{
						g_bInvokedThroughTopMenu[iParam1] = false;
						KickClient(target, "Your spray is not allowed, change it"); 
						CShowActivity2(iParam1, "{green}[SprayManager]{olive} ", "{default}Kicked {olive}%N{default}'s for his spray", target);
						LogAction(target, iParam1, "[SprayManager] \"%L\" has been kicked for his spray by \"%L\"", target, iParam1);
					}

					case 4:
					{
						Menu TraceSpraySprayBan = new Menu(MenuHandler_Menu_Trace_SprayBan);
						TraceSpraySprayBan.SetTitle("[SprayManager] Select a Spray Ban Length for %N (#%d)", target, GetClientUserId(target));
						TraceSpraySprayBan.ExitBackButton = true;

						TraceSpraySprayBan.AddItem("10", "10 Minutes");
						TraceSpraySprayBan.AddItem("30", "30 Minutes");
						TraceSpraySprayBan.AddItem("60", "1 Hour");
						TraceSpraySprayBan.AddItem("1440", "1 Day");
						TraceSpraySprayBan.AddItem("10080", "1 Week");
						TraceSpraySprayBan.AddItem("40320", "1 Month");
						TraceSpraySprayBan.AddItem("0", "Permanent");

						g_iSprayBanTarget[iParam1] = target;

						TraceSpraySprayBan.Display(iParam1, MENU_TIME_FOREVER);
					}

					case 5:
					{
						if (BanClientSpray(iParam1, target))
						{
							CShowActivity2(iParam1, "{green}[SprayManager]{olive} ", "{default}Banned {green}%N{default}'s spray.", target);
							LogAction(iParam1, target, "\"%L\" banned \"%L\"'s spray.", iParam1, target);
						}
					}

					case 6:
					{
						Menu TraceSprayBan = new Menu(MenuHandler_Menu_Trace_Ban);
						TraceSprayBan.SetTitle("[SprayManager] Select a Ban Length for %N (#%d)", target, GetClientUserId(target));
						TraceSprayBan.ExitBackButton = true;

						TraceSprayBan.AddItem("10", "10 Minutes");
						TraceSprayBan.AddItem("30", "30 Minutes");
						TraceSprayBan.AddItem("60", "1 Hour");
						TraceSprayBan.AddItem("1440", "1 Day");
						TraceSprayBan.AddItem("10080", "1 Week");
						TraceSprayBan.AddItem("40320", "1 Month");
						TraceSprayBan.AddItem("0", "Permanent");

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
					DisplayTopMenu(g_hTopMenu, iParam1, TopMenuPosition_LastCategory);
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
				CPrintToChat(iParam1, "{green}[SprayManager]{default} Target no longer available.");

				g_iSprayBanTarget[iParam1] = 0;
				g_bInvokedThroughTopMenu[iParam1] = false;

				if (g_hTopMenu != null)
					DisplayTopMenu(g_hTopMenu, iParam1, TopMenuPosition_LastCategory);
				else
					delete hMenu;
			}
			else
			{
				if (SprayBanClient(iParam1, target, StringToInt(sOption), "Inappropriate Spray"))
				{
					CShowActivity2(iParam1, "{green}[SprayManager]{olive} ", "{default}Spray banned {olive}%N{default}.", target);
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
					DisplayTopMenu(g_hTopMenu, iParam1, TopMenuPosition_LastCategory);
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
				CPrintToChat(iParam1, "{green}[SprayManager]{default} Target no longer available.");

				g_iBanTarget[iParam1] = 0;
				g_bInvokedThroughTopMenu[iParam1] = false;

				if (g_hTopMenu != null)
					DisplayTopMenu(g_hTopMenu, iParam1, TopMenuPosition_LastCategory);
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
	SprayMenu.SetTitle("[SprayManager] Select a Client to Force Spray:");
	SprayMenu.ExitBackButton =  true;

	for (int i = 1; i <= MaxClients; i++)
	{
		if (!IsValidClient(i) || IsFakeClient(i))
			continue;

		char sUserID[16];
		char sBuff[64];
		int iUserID = GetClientUserId(i);

		Format(sUserID, sizeof(sUserID), "%d", iUserID);

		if (g_bSprayBanned[i] && g_bSprayHashBanned[i])
		{
			Format(sBuff, sizeof(sBuff), "%N (#%d) [Spray & Hash Banned]", i, iUserID);

			SprayMenu.AddItem(sUserID, sBuff);
		}
		else if (g_bSprayBanned[i])
		{
			Format(sBuff, sizeof(sBuff), "%N (#%d) [Spray Banned]", i, iUserID);

			SprayMenu.AddItem(sUserID, sBuff);
		}
		else if (g_bSprayHashBanned[i])
		{
			Format(sBuff, sizeof(sBuff), "%N (#%d) [Hash Banned]", i, iUserID);

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
				DisplayTopMenu(g_hTopMenu, iParam1, TopMenuPosition_LastCategory);
		}

		case MenuAction_Select:
		{
			char sOption[8];
			hMenu.GetItem(iParam2, sOption, sizeof(sOption));

			int target = GetClientOfUserId(StringToInt(sOption));

			if (!IsValidClient(target))
			{
				CPrintToChat(iParam1, "{green}[SprayManager]{default} Target no longer available.");

				if (g_hTopMenu != null)
					DisplayTopMenu(g_hTopMenu, iParam1, TopMenuPosition_LastCategory);
				else
					delete hMenu;
			}
			else
			{
				g_iAllowSpray = target;
				ForceSpray(iParam1, target);

				CPrintToChat(iParam1, "{green}[SprayManager]{default} Sprayed {green}%N{default}'s spray(s).", target);

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
	SprayBanMenu.SetTitle("[SprayManager] Select a Client to Spray Ban:");
	SprayBanMenu.ExitBackButton = true;

	for (int i = 1; i <= MaxClients; i++)
	{
		if (!IsValidClient(i) || IsFakeClient(i))
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
		SprayBanMenu.AddItem("", "No eligible Clients found.", ITEMDRAW_DISABLED);

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
				DisplayTopMenu(g_hTopMenu, iParam1, TopMenuPosition_LastCategory);
		}

		case MenuAction_Select:
		{
			char sOption[32];
			hMenu.GetItem(iParam2, sOption, sizeof(sOption));

			int target = GetClientOfUserId(StringToInt(sOption));

			if (!IsValidClient(target))
			{
				CPrintToChat(iParam1, "{green}[SprayManager]{default} Target no longer available.");

				if (g_hTopMenu != null)
					DisplayTopMenu(g_hTopMenu, iParam1, TopMenuPosition_LastCategory);
				else
					delete hMenu;
			}
			else
			{
				Menu SprayBanLengthMenu = new Menu(MenuHandler_Menu_SprayBan_Length);
				SprayBanLengthMenu.SetTitle("[SprayManager] Choose a Spray Ban Length for %N (#%d)", target, GetClientUserId(target));
				SprayBanLengthMenu.ExitBackButton = true;

				SprayBanLengthMenu.AddItem("10", "10 Minutes");
				SprayBanLengthMenu.AddItem("30", "30 Minutes");
				SprayBanLengthMenu.AddItem("60", "1 Hour");
				SprayBanLengthMenu.AddItem("1440", "1 Day");
				SprayBanLengthMenu.AddItem("10080", "1 Week");
				SprayBanLengthMenu.AddItem("40320", "1 Month");
				SprayBanLengthMenu.AddItem("0", "Permanent");

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
				CPrintToChat(iParam1, "{green}[SprayManager]{default} Target no longer available.");

				g_iSprayBanTarget[iParam1] = 0;

				Menu_SprayBan(iParam1);
			}
			else
			{
				if (SprayBanClient(iParam1, target, StringToInt(sOption), "Inappropriate Spray"))
				{
					CShowActivity2(iParam1, "{green}[SprayManager]{olive} ", "{default}Spray banned {olive}%N", target);
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
	BanSprayMenu.SetTitle("[SprayManager] Select a Client to Ban their Spray:");
	BanSprayMenu.ExitBackButton =  true;

	for (int i = 1; i <= MaxClients; i++)
	{
		if (!IsValidClient(i) || IsFakeClient(i))
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
		BanSprayMenu.AddItem("", "No eligible Clients found.", ITEMDRAW_DISABLED);

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
				DisplayTopMenu(g_hTopMenu, iParam1, TopMenuPosition_LastCategory);
		}

		case MenuAction_Select:
		{
			char sOption[32];
			hMenu.GetItem(iParam2, sOption, sizeof(sOption));

			int target = GetClientOfUserId(StringToInt(sOption));

			if (!IsValidClient(target))
			{
				CPrintToChat(iParam1, "{green}[SprayManager]{default} Target no longer available.");

				Menu_BanSpray(iParam1);
			}
			else
			{
				if (BanClientSpray(iParam1, target))
				{
					CShowActivity2(iParam1, "{green}[SprayManager]{olive} ", "{default}Banned {olive}%N{default}'s spray", target);
					LogAction(iParam1, target, "\"%L\" banned \"%L\"'s spray", iParam1, target);
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
	UnbanSprayMenu.SetTitle("[SprayManager] Select a Client for more information:");
	UnbanSprayMenu.ExitBackButton =  true;

	for (int i = 1; i <= MaxClients; i++)
	{
		if (!IsValidClient(i) || IsFakeClient(i))
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
		UnbanSprayMenu.AddItem("", "No Banned Clients.", ITEMDRAW_DISABLED);

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
				DisplayTopMenu(g_hTopMenu, iParam1, TopMenuPosition_LastCategory);
		}

		case MenuAction_Select:
		{
			char sOption[32];
			hMenu.GetItem(iParam2, sOption, sizeof(sOption));

			int target = GetClientOfUserId(StringToInt(sOption));

			if (!IsValidClient(target))
			{
				CPrintToChat(iParam1, "{green}[SprayManager]{default} Target no longer available.");

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
	ListTargetMenu.SetTitle("[SprayManager] Banned Client: %N (#%d)", target, GetClientUserId(target));
	ListTargetMenu.ExitBackButton = true;

	char sBanType[32];
	char sUserID[32];
	int iUserID = GetClientUserId(target);

	Format(sUserID, sizeof(sUserID), "%d", iUserID);

	if (g_bSprayHashBanned[target] && !g_bSprayBanned[target])
	{
		strcopy(sBanType, sizeof(sBanType), "Type: Hash");

		ListTargetMenu.AddItem("", sBanType, ITEMDRAW_DISABLED);
		ListTargetMenu.AddItem("", "", ITEMDRAW_SPACER);

		ListTargetMenu.AddItem(sUserID, "Unban Client?");

		ListTargetMenu.Display(client, MENU_TIME_FOREVER);
		return;
	}

	char sBanExpiryDate[64];
	char sBanIssuedDate[64];
	char sBanDuration[64];
	char sBannedBy[128];
	char sBanReason[64];
	int iBanExpiryDate = g_iSprayUnbanTimestamp[target];
	int iBanIssuedDate = g_iSprayBanTimestamp[target];
	int iBanDuration = iBanExpiryDate ? ((iBanExpiryDate - iBanIssuedDate) / 60) : 0;

	if (iBanExpiryDate)
	{
		FormatTime(sBanExpiryDate, sizeof(sBanExpiryDate), NULL_STRING, iBanExpiryDate);
		Format(sBanDuration, sizeof(sBanDuration), "%d %s", iBanDuration, SingularOrMultiple(iBanDuration) ? "Minutes" : "Minute");
	}
	else
	{
		strcopy(sBanExpiryDate, sizeof(sBanExpiryDate), "Never");
		strcopy(sBanDuration, sizeof(sBanDuration), "Permanent");
	}

	FormatTime(sBanIssuedDate, sizeof(sBanIssuedDate), NULL_STRING, iBanIssuedDate);
	Format(sBannedBy, sizeof(sBannedBy), "Banned by: %s (%s)", g_sBanIssuer[target], g_sBanIssuerSID[target]);
	Format(sBanDuration, sizeof(sBanDuration), "Duration: %s", sBanDuration);
	Format(sBanExpiryDate, sizeof(sBanExpiryDate), "Expires: %s", sBanExpiryDate);
	Format(sBanIssuedDate, sizeof(sBanIssuedDate), "Issued on: %s", sBanIssuedDate);
	Format(sBanReason, sizeof(sBanReason), "Reason: %s", g_sBanReason[target]);

	if (g_bSprayBanned[target] && g_bSprayHashBanned[target])
		strcopy(sBanType, sizeof(sBanType), "Type: Spray & Hash");
	else if (g_bSprayBanned[target])
		strcopy(sBanType, sizeof(sBanType), "Type: Spray");

	ListTargetMenu.AddItem("", sBanType, ITEMDRAW_DISABLED);
	ListTargetMenu.AddItem("", sBannedBy, ITEMDRAW_DISABLED);
	ListTargetMenu.AddItem("", sBanIssuedDate, ITEMDRAW_DISABLED);
	ListTargetMenu.AddItem("", sBanExpiryDate, ITEMDRAW_DISABLED);
	ListTargetMenu.AddItem("", sBanDuration, ITEMDRAW_DISABLED);
	ListTargetMenu.AddItem("", sBanReason, ITEMDRAW_DISABLED);

	ListTargetMenu.AddItem(sUserID, "Unban Client?");

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
				CPrintToChat(iParam1, "{green}[SprayManager]{default} Target no longer available.");
				Menu_ListBans(iParam1);
			}
			else
			{
				if (g_bSprayBanned[target] && g_bSprayHashBanned[target])
				{
					Menu MenuUnbanMode = new Menu(MenuHandler_Menu_UnbanMode);
					MenuUnbanMode.SetTitle("[SprayManager] Unban %N?", target);
					MenuUnbanMode.ExitBackButton = true;

					MenuUnbanMode.AddItem("H", "Remove Hash Ban.");
					MenuUnbanMode.AddItem("S", "Remove Spray Ban.");
					MenuUnbanMode.AddItem("B", "Remove Both.");

					g_iSprayUnbanTarget[iParam1] = target;

					MenuUnbanMode.Display(iParam1, MENU_TIME_FOREVER);

					return 0;
				}

				Menu MenuConfirmUnban = new Menu(MenuHandler_Menu_ConfirmUnban);
				MenuConfirmUnban.SetTitle("[SprayManager] Unban %N?", target);
				MenuConfirmUnban.ExitBackButton = true;

				MenuConfirmUnban.AddItem("Y", "Yes.");
				MenuConfirmUnban.AddItem("N", "No.");

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
					DisplayTopMenu(g_hTopMenu, iParam1, TopMenuPosition_LastCategory);
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
				CPrintToChat(iParam1, "{green}[SprayManager]{default} Target no longer available.");

				g_iSprayUnbanTarget[iParam1] = 0;

				if (g_hTopMenu != null)
					DisplayTopMenu(g_hTopMenu, iParam1, TopMenuPosition_LastCategory);
				else
					delete hMenu;
			}
			else
			{
				if (sOption[0] == 'H')
				{
					if (UnbanClientSpray(iParam1, target))
					{
						CShowActivity2(iParam1, "{green}[SprayManager]{olive} ", "{default}Unbanned {olive}%N{default}'s spray", target);
						LogAction(iParam1, target, "\"%L\" unbanned \"%L\"'s spray", iParam1, target);
					}
				}
				else if (sOption[0] == 'S')
				{
					if (SprayUnbanClient(target, iParam1))
					{
						CShowActivity2(iParam1, "{green}[SprayManager]{olive} ", "{default}Spray unbanned {olive}%N", target);
						LogAction(iParam1, target, "\"%L\" spray unbanned \"%L\"", iParam1, target);
					}
				}
				else if (sOption[0] == 'B')
				{
					if (SprayUnbanClient(target, iParam1) && UnbanClientSpray(iParam1, target))
					{
						CShowActivity2(iParam1, "{green}[SprayManager]{olive} ", "{default}Spray unbanned {olive}%N", target);
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
					DisplayTopMenu(g_hTopMenu, iParam1, TopMenuPosition_LastCategory);
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
				CPrintToChat(iParam1, "{green}[SprayManager]{default} Target no longer available.");

				g_iSprayUnbanTarget[iParam1] = 0;

				if (g_hTopMenu != null)
					DisplayTopMenu(g_hTopMenu, iParam1, TopMenuPosition_LastCategory);
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
							CShowActivity2(iParam1, "{green}[SprayManager]{olive} ", "{default}Spray unbanned {olive}%N", target);
							LogAction(iParam1, target, "\"%L\" spray unbanned \"%L\"", iParam1, target);
						}
					}
					else if (g_bSprayBanned[target])
					{
						if (SprayUnbanClient(target, iParam1))
						{
							CShowActivity2(iParam1, "{green}[SprayManager]{olive} ", "{default}Spray unbanned {olive}%N", target);
							LogAction(iParam1, target, "\"%L\" spray unbanned \"%L\"", iParam1, target);
						}
					}
					else if (g_bSprayHashBanned[target])
					{
						if (UnbanClientSpray(iParam1, target))
						{
							CShowActivity2(iParam1, "{green}[SprayManager]{olive} ", "{default}Unbanned {olive}%N{default}'s spray", target);
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

public Action Command_MarkNSFW(int client, int argc)
{
	if (!client)
	{
		PrintToServer("[SprayManager] Cannot use command from server console.");
		return Plugin_Handled;
	}

	if (!IsValidClient(client))
	{
		ReplyToCommand(client, "[SprayManager] Unable to update status, please wait a few seconds and try again.");
		return Plugin_Handled;
	}

	if (g_hDatabase == null || !g_bFullyConnected)
	{
		ReplyToCommand(client, "{green}[SprayManager]{default} Unable to update status, please wait a few seconds and try again.");
		return Plugin_Handled;
	}

	if (g_bMarkedNSFWByAdmin[client] || g_bHasNSFWSpray[client])
	{
		CPrintToChat(client, "{green}[SprayManager]{default} Your spray is already marked as NSFW.");
		return Plugin_Handled;
	}

	g_bHasNSFWSpray[client] = true;

	char sQuery[256];
	char sClientSteamID[32];

	GetClientAuthId(client, AuthId_Steam2, sClientSteamID, sizeof(sClientSteamID));
	Format(sQuery, sizeof(sQuery), "INSERT INTO `spraynsfwlist` (`sprayhash`, `sprayersteamid`, `setbyadmin`) VALUES ('%s', '%s', '%d');", g_sSprayHash[client], sClientSteamID, 0);
	SQL_TQuery(g_hDatabase, DummyCallback, sQuery);

	for (int i = 1; i <= MaxClients; i++)
	{
		if (!IsValidClient(i))
			continue;

		for (int x = 1; x <= MaxClients; x++)
		{
			if (!IsValidClient(x))
				continue;

			if (g_bHasSprayHidden[i][x])
				continue;

			if (g_bWantsToSeeNSFWSprays[i])
				continue;

			PaintWorldDecalToOne(g_bHasNSFWSpray[x] ? g_iNSFWDecalIndex : g_iTransparentDecalIndex, g_vecSprayOrigin[x], i);
			g_bSkipDecalHook = true;
			SprayClientDecalToOne(x, i, g_bHasNSFWSpray[x] ? 0 : g_iDecalEntity[x], g_bHasNSFWSpray[x] ? ACTUAL_NULL_VECTOR : g_vecSprayOrigin[x]);
			g_iClientToClientSprayLifetime[i][x] = g_bHasNSFWSpray[x] ? g_iClientToClientSprayLifetime[i][x] : 0;
			g_bSkipDecalHook = false;
		}
	}

	CPrintToChat(client, "{green}[SprayManager]{default} Your spray is now marked as NSFW.");

	return Plugin_Continue;
}

public Action Command_MarkSFW(int client, int argc)
{
	if (!client)
	{
		PrintToServer("[SprayManager] Cannot use command from server console.");
		return Plugin_Handled;
	}

	if (!IsValidClient(client))
	{
		ReplyToCommand(client, "[SprayManager] Unable to update status, please wait a few seconds and try again.");
		return Plugin_Handled;
	}

	if (g_hDatabase == null || !g_bFullyConnected)
	{
		ReplyToCommand(client, "{green}[SprayManager]{default} Unable to update status, please wait a few seconds and try again.");
		return Plugin_Handled;
	}

	if (g_bMarkedNSFWByAdmin[client])
	{
		CPrintToChat(client, "{green}[SprayManager]{default} Your spray has been marked as NSFW by an admin, you cannot change this.");
		return Plugin_Handled;
	}

	if (!g_bHasNSFWSpray[client])
	{
		CPrintToChat(client, "{green}[SprayManager]{default} Your spray is already marked as SFW.");
		return Plugin_Handled;
	}

	g_bHasNSFWSpray[client] = false;

	char sQuery[256];

	Format(sQuery, sizeof(sQuery), "DELETE FROM `spraynsfwlist` WHERE `sprayhash` = '%s';", g_sSprayHash[client]);
	SQL_TQuery(g_hDatabase, DummyCallback, sQuery);

	for (int i = 1; i <= MaxClients; i++)
	{
		if (!IsValidClient(i))
			continue;

		if (g_bHasSprayHidden[i][client])
			continue;

		if (g_bWantsToSeeNSFWSprays[i])
			continue;

		PaintWorldDecalToOne(g_iTransparentDecalIndex, g_vecSprayOrigin[client], i);
		g_bSkipDecalHook = true;
		SprayClientDecalToOne(client, i, g_iDecalEntity[client], g_vecSprayOrigin[client]);
		g_iClientToClientSprayLifetime[i][client] = 0;
		g_bSkipDecalHook = false;
	}

	CPrintToChat(client, "{green}[SprayManager]{default} Your spray is now marked as SFW.");

	return Plugin_Continue;
}

public Action Command_NSFW(int client, int argc)
{
	if (!client)
	{
		ReplyToCommand(client, "[SprayManager] Cannot use command from server console.");
		return Plugin_Handled;
	}

	if (!AreClientCookiesCached(client))
	{
		CPrintToChat(client, "{green}[SprayManager]{default} Could not update status, please wait a few seconds and try again.");
		return Plugin_Handled;
	}

	g_bWantsToSeeNSFWSprays[client] = !g_bWantsToSeeNSFWSprays[client];

	SetClientCookie(client, g_hWantsToSeeNSFWCookie, g_bWantsToSeeNSFWSprays[client] ? "1" : "0");

	CPrintToChat(client, "{green}[SprayManager]{default} You can %s", g_bWantsToSeeNSFWSprays[client] ? "now see {purple}NSFW{default} sprays." : "no longer see {purple}NSFW{default} sprays.");

	for (int i = 1; i <= MaxClients; i++)
	{
		if (!IsValidClient(i))
			continue;

		if (!g_bHasNSFWSpray[i])
			continue;

		if (g_bHasSprayHidden[client][i])
			continue;

		PaintWorldDecalToOne(g_bWantsToSeeNSFWSprays[client] ? g_iTransparentDecalIndex : g_iNSFWDecalIndex, g_vecSprayOrigin[i], client);
		g_bSkipDecalHook = true;
		SprayClientDecalToOne(i, client, g_bWantsToSeeNSFWSprays[client] ? g_iDecalEntity[i] : 0, g_bWantsToSeeNSFWSprays[client] ? g_vecSprayOrigin[i] : ACTUAL_NULL_VECTOR);
		g_iClientToClientSprayLifetime[client][i] = g_bWantsToSeeNSFWSprays[client] ? 0 : g_iClientToClientSprayLifetime[client][i];
		g_bSkipDecalHook = false;
	}

	return Plugin_Handled;
}

public Action Command_HideSpray(int client, int argc)
{
	if (!client)
	{
		ReplyToCommand(client, "[SprayManager] Cannot use command from server console.");
		return Plugin_Handled;
	}

	if (argc > 0)
	{
		int iTarget;
		char sArg[64];

		GetCmdArg(1, sArg, sizeof(sArg));

		if ((iTarget = FindTarget(client, sArg, false, false)) <= 0)
			return Plugin_Handled;

		g_bHasSprayHidden[client][iTarget] = true;
		CPrintToChat(client, "{green}[SprayManager]{default} You have hidden {green}%N{default}'s spray.", iTarget);

		PaintWorldDecalToOne(g_iHiddenDecalIndex, g_vecSprayOrigin[iTarget], client);
		g_bSkipDecalHook = true;
		SprayClientDecalToOne(iTarget, client, 0, ACTUAL_NULL_VECTOR);
		g_bSkipDecalHook = false;

		return Plugin_Handled;
	}

	float vecEndPos[3];

	if (TracePlayerAngles(client, vecEndPos))
	{
	 	for (int i = 1; i <= MaxClients; i++)
		{
			if (!IsPointInsideAABB(vecEndPos, g_SprayAABB[i]))
				continue;

			g_bHasSprayHidden[client][i] = true;
			CPrintToChat(client, "{green}[SprayManager]{default} You have hidden {green}%N{default}'s spray.", i);

			PaintWorldDecalToOne(g_iHiddenDecalIndex, g_vecSprayOrigin[i], client);
			g_bSkipDecalHook = true;
			SprayClientDecalToOne(i, client, 0, ACTUAL_NULL_VECTOR);
			g_bSkipDecalHook = false;

			return Plugin_Handled;
		}
	}

	CPrintToChat(client, "{green}[SprayManager]{default} No spray could be found.");

	return Plugin_Handled;
}

public Action Command_UnhideSpray(int client, int argc)
{
	if (!client)
	{
		ReplyToCommand(client, "[SprayManager] Cannot use command from server console.");
		return Plugin_Handled;
	}

	if (argc > 0)
	{
		int iTarget;
		char sArg[64];

		GetCmdArg(1, sArg, sizeof(sArg));

		if ((iTarget = FindTarget(client, sArg, false, false)) <= 0)
			return Plugin_Handled;

		g_bHasSprayHidden[client][iTarget] = false;
		CPrintToChat(client, "{green}[SprayManager]{default} You have unhidden {green}%N{default}'s spray.", iTarget);

		PaintWorldDecalToOne(g_iTransparentDecalIndex, g_vecSprayOrigin[iTarget], client);

		if (!g_bWantsToSeeNSFWSprays[client] && g_bHasNSFWSpray[iTarget])
		{
			PaintWorldDecalToOne(g_iNSFWDecalIndex, g_vecSprayOrigin[iTarget], client);
			return Plugin_Handled;
		}

		g_bSkipDecalHook = true;
		SprayClientDecalToOne(iTarget, client, g_iDecalEntity[iTarget], g_vecSprayOrigin[iTarget]);
		g_iClientToClientSprayLifetime[client][iTarget] = 0;
		g_bSkipDecalHook = false;

		return Plugin_Handled;
	}

	float vecEndPos[3];

	if (TracePlayerAngles(client, vecEndPos))
	{
	 	for (int i = 1; i <= MaxClients; i++)
		{
			if (!IsPointInsideAABB(vecEndPos, g_SprayAABB[i]))
				continue;

			g_bHasSprayHidden[client][i] = false;
			CPrintToChat(client, "{green}[SprayManager]{default} You have unhidden {green}%N{default}'s spray.", i);

			PaintWorldDecalToOne(g_iTransparentDecalIndex, g_vecSprayOrigin[i], client);

			if (!g_bWantsToSeeNSFWSprays[client] && g_bHasNSFWSpray[i])
			{
				PaintWorldDecalToOne(g_iNSFWDecalIndex, g_vecSprayOrigin[i], client);
				return Plugin_Handled;
			}

			g_bSkipDecalHook = true;
			SprayClientDecalToOne(i, client, g_iDecalEntity[i], g_vecSprayOrigin[i]);
			g_iClientToClientSprayLifetime[client][i] = 0;
			g_bSkipDecalHook = false;

			return Plugin_Handled;
		}
	}

	CPrintToChat(client, "{green}[SprayManager]{default} No spray could be found.");

	return Plugin_Handled;
}

public Action Command_AdminSpray(int client, int argc)
{
	if (!client)
	{
		PrintToServer("[SprayManager] Cannot use command from server console.");
		return Plugin_Handled;
	}

	if (argc > 0)
	{
		char sArgs[64];
		char sTargetName[MAX_TARGET_LENGTH];
		int iTargets[MAXPLAYERS];
		int iTargetCount;
		bool bIsML;

		GetCmdArg(1, sArgs, sizeof(sArgs));

		if ((iTargetCount = ProcessTargetString(sArgs, client, iTargets, MAXPLAYERS, COMMAND_FILTER_NO_BOTS, sTargetName, sizeof(sTargetName), bIsML)) <= 0)
		{
			ReplyToTargetError(client, iTargetCount);
			return Plugin_Handled;
		}

		for (int i = 0; i < iTargetCount; i++)
		{
			g_iAllowSpray = iTargets[i];
			ForceSpray(client, iTargets[i], false);
		}

		CPrintToChat(client, "{green}[SprayManager]{default} Sprayed {green}%s{default}'s spray(s).", sTargetName);

		return Plugin_Handled;
	}

	g_iAllowSpray = client;
	ForceSpray(client, client, false);

	CPrintToChat(client, "{green}[SprayManager]{default} Sprayed your own spray.");

	return Plugin_Handled;
}

public Action Command_SprayBan(int client, int argc)
{
	if (argc < 2)
	{
		ReplyToCommand(client, "[SprayManager] Usage: sm_sprayban <target> <time> <reason:optional>");
		return Plugin_Handled;
	}

	int iTarget;
	char sTarget[32];
	char sLength[32];
	char sReason[32];

	GetCmdArg(1, sTarget, sizeof(sTarget));
	GetCmdArg(2, sLength, sizeof(sLength));

	if (argc > 2)
		GetCmdArg(3, sReason, sizeof(sReason));

	if ((iTarget = FindTarget(client, sTarget)) <= 0)
		return Plugin_Handled;

	if (!SprayBanClient(client, iTarget, StringToInt(sLength), sReason))
		return Plugin_Handled;

	CShowActivity2(client, "{green}[SprayManager]{olive} ", "{default}Spray banned {olive}%N", iTarget);
	LogAction(client, iTarget, "\"%L\" spray banned \"%L\" (Hash: \"%s\")", client, iTarget, g_sSprayHash[iTarget]);

	return Plugin_Handled;
}

public Action Command_SprayUnban(int client, int argc)
{
	if (argc < 1)
	{
		ReplyToCommand(client, "[SprayManager] Usage: sm_sprayunban <target>");
		return Plugin_Handled;
	}

	int iTarget;
	char sTarget[32];

	GetCmdArg(1, sTarget, sizeof(sTarget));

	if ((iTarget = FindTarget(client, sTarget)) <= 0)
		return Plugin_Handled;

	if (!SprayUnbanClient(iTarget, client))
		return Plugin_Handled;

	CShowActivity2(client, "{green}[SprayManager]{olive} ", "{default}Spray unbanned {olive}%N", iTarget);
	LogAction(client, iTarget, "\"%L\" spray unbanned \"%L\"", client, iTarget);

	return Plugin_Handled;
}

public Action Command_BanSpray(int client, int argc)
{
	if (argc > 0)
	{
		int iTarget;
		char sTarget[32];

		GetCmdArg(1, sTarget, sizeof(sTarget));

		if ((iTarget = FindTarget(client, sTarget)) <= 0)
			return Plugin_Handled;

		if (!BanClientSpray(client, iTarget))
			return Plugin_Handled;

		CShowActivity2(client, "{green}[SprayManager] ", "{default}Banned {green}%N{default}'s spray", iTarget);
		LogAction(client, iTarget, "\"%L\" banned \"%L\"'s spray", client, iTarget);

		return Plugin_Handled;
	}

	float vecEndPos[3];

	if (TracePlayerAngles(client, vecEndPos))
	{
	 	for (int i = 1; i <= MaxClients; i++)
		{
			if (!IsPointInsideAABB(vecEndPos, g_SprayAABB[i]))
				continue;

			if (!BanClientSpray(client, i))
				return Plugin_Handled;

			CShowActivity2(client, "{green}[SprayManager]{olive} ", "{default}Banned {olive}%N{default}'s spray", i);
			LogAction(client, i, "\"%L\" banned \"%L\"'s spray", client, i);

			return Plugin_Handled;
		}
	}

	CPrintToChat(client, "{green}[SprayManager]{default} No spray could be found.");

	return Plugin_Handled;
}

public Action Command_UnbanSpray(int client, int argc)
{
	if (argc < 1)
	{
		ReplyToCommand(client, "[SprayManager] Usage: sm_unbanspray <target>");
		return Plugin_Handled;
	}

	int iTarget;
	char sTarget[32];

	GetCmdArg(1, sTarget, sizeof(sTarget));

	if ((iTarget = FindTarget(client, sTarget)) <= 0)
		return Plugin_Handled;

	if (!UnbanClientSpray(client, iTarget))
		return Plugin_Handled;

	CShowActivity2(client, "{green}[SprayManager]{olive} ", "{default}Unbanned {olive}%N{default}'s spray", iTarget);
	LogAction(client, iTarget, "\"%L\" unbanned \"%L\"'s spray", client, iTarget);

	return Plugin_Handled;
}

public Action Command_TraceSpray(int client, int argc)
{
	if (!client)
	{
		PrintToServer("[SprayManager] Cannot use command from server console.");
		return Plugin_Handled;
	}

	float vecEndPos[3];
	if (TracePlayerAngles(client, vecEndPos))
	{
		for (int i = 1; i <= MaxClients; i++)
		{
			if (!IsPointInsideAABB(vecEndPos, g_SprayAABB[i]))
				continue;

			g_bInvokedThroughTopMenu[client] = false;
			Menu_Trace(client, i);

			return Plugin_Handled;
		}
	}

	CPrintToChat(client, "{green}[SprayManager]{default} Trace did not hit any sprays.");

	return Plugin_Handled;
}

public Action Command_RemoveSpray(int client, int argc)
{
	if (!client)
	{
		PrintToServer("[SprayManager] Cannot use command from server console.");
		return Plugin_Handled;
	}

	if (argc > 0)
	{
		char sArgs[64];
		char sTargetName[MAX_TARGET_LENGTH];
		int iTargets[MAXPLAYERS];
		int iTargetCount;
		bool bIsML;

		GetCmdArg(1, sArgs, sizeof(sArgs));

		if ((iTargetCount = ProcessTargetString(sArgs, client, iTargets, MAXPLAYERS, COMMAND_FILTER_NO_BOTS, sTargetName, sizeof(sTargetName), bIsML)) <= 0)
		{
			ReplyToTargetError(client, iTargetCount);
			return Plugin_Handled;
		}

		for (int i = 0; i < iTargetCount; i++)
		{
			g_iAllowSpray = iTargets[i];
			SprayClientDecalToAll(iTargets[i], 0, ACTUAL_NULL_VECTOR);
		}

		CPrintToChat(client, "{green}[SprayManager]{default} Removed {green}%s{default}'s spray(s).", sTargetName);

		return Plugin_Handled;
	}

	float vecEndPos[3];

	if (TracePlayerAngles(client, vecEndPos))
	{
	 	for (int i = 1; i <= MaxClients; i++)
		{
			if (!IsPointInsideAABB(vecEndPos, g_SprayAABB[i]))
				continue;

			g_iAllowSpray = i;
			SprayClientDecalToAll(i, 0, ACTUAL_NULL_VECTOR);

			CPrintToChat(client, "{green}[SprayManager]{default} Removed {green}%N{default}'s spray.", i);

			return Plugin_Handled;
		}
	}

	CPrintToChat(client, "{green}[SprayManager]{default} No spray could be found.");

	return Plugin_Handled;
}

public Action Command_ForceNSFW(int client, int argc)
{
	if (!client)
	{
		ReplyToCommand(client, "[SprayManager] Cannot use command from server console.");
		return Plugin_Handled;
	}

	if (argc > 0)
	{
		int iTarget;
		char sTarget[32];

		GetCmdArg(1, sTarget, sizeof(sTarget));

		if ((iTarget = FindTarget(client, sTarget)) <= 0)
			return Plugin_Handled;

		AdminForceSprayNSFW(iTarget);
		CPrintToChat(client, "{green}[SprayManager]{default} Marked {green}%N{default}'s spray as NSFW.", iTarget);
		LogAction(client, iTarget, "[SprayManager] %L Marked %L spray as NSFW.", client, iTarget);
		NotifyAdmins(client, iTarget, "{default}spray was marked as {green}NSFW");

		return Plugin_Handled;
	}

	float vecEndPos[3];

	if (TracePlayerAngles(client, vecEndPos))
	{
	 	for (int i = 1; i <= MaxClients; i++)
		{
			if (!IsPointInsideAABB(vecEndPos, g_SprayAABB[i]))
				continue;

			AdminForceSprayNSFW(i);
			CPrintToChat(client, "{green}[SprayManager]{default} Marked {green}%N{default}'s spray as NSFW.", i);
			LogAction(client, i, "[SprayManager] %L Marked %L spray as NSFW.", client, i);
			NotifyAdmins(client, i, "{default}spray was marked as {green}NSFW");

			return Plugin_Handled;
		}
	}

	CPrintToChat(client, "{green}[SprayManager]{default} No spray could be found.");

	return Plugin_Handled;
}

public Action Command_ForceSFW(int client, int argc)
{
	if (!client)
	{
		ReplyToCommand(client, "[SprayManager] Cannot use command from server console.");
		return Plugin_Handled;
	}

	if (argc > 0)
	{
		int iTarget;
		char sTarget[32];

		GetCmdArg(1, sTarget, sizeof(sTarget));

		if ((iTarget = FindTarget(client, sTarget)) <= 0)
			return Plugin_Handled;

		AdminForceSpraySFW(iTarget);
		CPrintToChat(client, "{green}[SprayManager]{default} Marked {green}%N{default}'s spray as SFW.", iTarget);
		LogAction(client, iTarget, "[SprayManager] %L Marked %L spray as SFW.", client, iTarget);
		NotifyAdmins(client, iTarget, "{default}spray was marked as {green}SFW");

		return Plugin_Handled;
	}

	float vecEndPos[3];

	if (TracePlayerAngles(client, vecEndPos))
	{
	 	for (int i = 1; i <= MaxClients; i++)
		{
			if (!IsPointInsideAABB(vecEndPos, g_SprayAABB[i]))
				continue;

			AdminForceSpraySFW(i);
			CPrintToChat(client, "{green}[SprayManager]{default} Marked {green}%N{default}'s spray as SFW.", i);
			LogAction(client, i, "[SprayManager] %L Marked %L spray as SFW.", client, i);
			NotifyAdmins(client, i, "{default}spray was marked as {green}SFW");

			return Plugin_Handled;
		}
	}

	CPrintToChat(client, "{green}[SprayManager]{default} No spray could be found.");

	return Plugin_Handled;
}

public Action Command_SprayManager_UpdateInfo(int client, int argc)
{
	for (int i = 1; i <= MaxClients; i++)
	{
		if (!IsValidClient(i) || IsFakeClient(i))
			continue;

		ClearPlayerInfo(i);
		UpdatePlayerInfo(i);
		UpdateSprayHashInfo(i);
		UpdateNSFWInfo(i);
	}

	ReplyToCommand(client, "[SprayManager] Refreshed database.");
	return Plugin_Handled;
}

public Action HookDecal(const char[] sTEName, const int[] iClients, int iNumClients, float fSendDelay)
{
	if (g_bSkipDecalHook)
		return Plugin_Continue;

	int client = TE_ReadNum("m_nPlayer");

	if (!IsValidClient(client))
	{
		if (g_iAllowSpray == client)
			g_iAllowSpray = 0;

		return Plugin_Handled;
	}

	float vecOrigin[3];
	TE_ReadVector("m_vecOrigin", vecOrigin);

	float AABBTemp[AABBTotalPoints];

	AABBTemp[AABBMinX] = vecOrigin[0] - 32.0;
	AABBTemp[AABBMaxX] = vecOrigin[0] + 32.0;
	AABBTemp[AABBMinY] = vecOrigin[1] - 32.0;
	AABBTemp[AABBMaxY] = vecOrigin[1] + 32.0;
	AABBTemp[AABBMinZ] = vecOrigin[2] - 32.0;
	AABBTemp[AABBMaxZ] = vecOrigin[2] + 32.0;

	if (g_iAllowSpray != client)
	{
		if (g_bSprayHashBanned[client])
		{
			CPrintToChat(client, "{green}[SprayManager]{default} Your spray is blacklisted, change it.");
			return Plugin_Handled;
		}

		if (g_iSprayUnbanTimestamp[client] != 0 && g_iSprayUnbanTimestamp[client] != -1)
		{
			if (g_iSprayUnbanTimestamp[client] < GetTime())
				SprayUnbanClient(client);
		}

		if (g_bSprayBanned[client])
		{
			char sRemainingTime[512];

			FormatRemainingTime(g_iSprayUnbanTimestamp[client], sRemainingTime, sizeof(sRemainingTime));

			CPrintToChat(client, "{green}[SprayManager]{default} You are currently spray banned. ({green}%s{default})", sRemainingTime);

			return Plugin_Handled;
		}

		if (g_fNextSprayTime[client] > GetGameTime())
			return Plugin_Handled;

		if (!CheckCommandAccess(client, "sm_sprayban", ADMFLAG_GENERIC))
		{
			if (g_cvarUseProximityCheck.BoolValue)
			{
				for (int i = 1; i <= MaxClients; i++)
				{
					if (!IsValidClient(i) || i == client)
						continue;

					if (IsVectorZero(g_vecSprayOrigin[i]))
						continue;

					if (!IsPointInsideAABB(vecOrigin, g_SprayAABB[i]) && !CheckForAABBCollision(AABBTemp, g_SprayAABB[i]))
						continue;

					if (CheckCommandAccess(i, "", ADMFLAG_CUSTOM1, true) || CheckCommandAccess(i, "sm_sprayban", ADMFLAG_GENERIC))
					{
						CPrintToChat(client, "{green}[SprayManager]{default} Your spray is too close to {green}%N{default}'s spray.", i);

						return Plugin_Handled;
					}
				}
			}

			if (CheckCommandAccess(client, "", ADMFLAG_CUSTOM1))
				g_fNextSprayTime[client] = GetGameTime() + (g_cvarDecalFrequency.FloatValue / 2);
			else
				g_fNextSprayTime[client] = GetGameTime() + g_cvarDecalFrequency.FloatValue;
		}
	}

	int iClientCount = GetClientCount(true);

	int[] iarrValidClients = new int[iClientCount];
	int[] iarrHiddenClients = new int[iClientCount];
	int[] iarrNoNSFWClients = new int[iClientCount];
	int iCurValidIdx;
	int iCurHiddenIdx;
	int iCurNoNSFWIdx;

	for (int i = 1; i <= MaxClients; i++)
	{
		if (!IsClientInGame(i))
			continue;

		if (g_bHasSprayHidden[i][client])
		{
			iarrHiddenClients[iCurHiddenIdx] = i;
			iCurHiddenIdx++;
			continue;
		}

		if (g_bHasNSFWSpray[client] && !g_bWantsToSeeNSFWSprays[i])
		{
			iarrNoNSFWClients[iCurNoNSFWIdx] = i;
			iCurNoNSFWIdx++;
			continue;
		}

		iarrValidClients[iCurValidIdx] = i;
		iCurValidIdx++;
	}

	if (!IsVectorZero(g_vecSprayOrigin[client]))
	{
		PaintWorldDecalToSelected(g_iTransparentDecalIndex, g_vecSprayOrigin[client], iarrNoNSFWClients, iCurNoNSFWIdx);
		PaintWorldDecalToSelected(g_iTransparentDecalIndex, g_vecSprayOrigin[client], iarrHiddenClients, iCurHiddenIdx);
	}

	PaintWorldDecalToSelected(g_iHiddenDecalIndex, vecOrigin, iarrHiddenClients, iCurHiddenIdx);
	PaintWorldDecalToSelected(g_iNSFWDecalIndex, vecOrigin, iarrNoNSFWClients, iCurNoNSFWIdx);

	g_bSkipDecalHook = true;
	SprayClientDecalToSelected(client, g_iDecalEntity[client], vecOrigin, iarrValidClients, iCurValidIdx);
	g_bSkipDecalHook = false;

	g_vecSprayOrigin[client] = vecOrigin;
	g_iAllowSpray = 0;
	g_iSprayLifetime[client] = 0;
	UpdateClientToClientSprayLifeTime(client, 0);
	g_SprayAABB[client] = AABBTemp;

	ArrayList PosArray = new ArrayList(3, 0);
	PosArray.PushArray(vecOrigin, 3);
	RequestFrame(FrameAfterSpray, PosArray);

	return Plugin_Handled;
}

public void FrameAfterSpray(ArrayList Data)
{
	float vecPos[3];
	Data.GetArray(0, vecPos, 3);

	EmitSoundToAll("player/sprayer.wav", SOUND_FROM_WORLD, SNDCHAN_AUTO, SNDLEVEL_NORMAL, SND_NOFLAGS, _, _, _, vecPos);

	delete Data;
}

public Action HookSprayer(int iClients[MAXPLAYERS], int &iNumClients, char sSoundName[PLATFORM_MAX_PATH], int &iEntity, int &iChannel, float &flVolume, int &iLevel, int &iPitch, int &iFlags, char sSoundEntry[PLATFORM_MAX_PATH], int &seed)
{
	if (strcmp(sSoundName, "player/sprayer.wav") == 0 && iEntity > 0)
		return Plugin_Handled;

	return Plugin_Continue;
}

public void LagReducer_OnClientGameFrame(int iClient)
{
	PerformPlayerTraces(iClient);
}

public void PerformPlayerTraces(int client)
{
	bool bLookingatSpray = false;

	float vecPos[3];

	if (!IsValidClient(client) || IsFakeClient(client))
		return;

	if (!TracePlayerAngles(client, vecPos))
		return;

	for (int i = 1; i <= MaxClients; i++)
	{
		if (!IsValidClient(i))
			continue;

		if (IsPointInsideAABB(vecPos, g_SprayAABB[i]))
		{
			char sSteamID[32];
			GetClientAuthId(i, AuthId_Steam2, sSteamID, sizeof(sSteamID));

			PrintHintText(client, "Sprayed by: %N (%s) [%s]", i, sSteamID, g_bHasNSFWSpray[i] ? "NSFW" : "SFW");
			StopSound(client, SNDCHAN_STATIC, "UI/hint.wav");

			g_bSprayNotified[client] = true;
			bLookingatSpray = true;

			break;
		}
	}

	if (!bLookingatSpray && g_bSprayNotified[client])
	{
		PrintHintText(client, "");
		StopSound(client, SNDCHAN_STATIC, "UI/hint.wav");
		g_bSprayNotified[client] = false;
	}
}

public Action Timer_ProcessPersistentSprays(Handle hThis)
{
	for (int i = 1; i <= MaxClients; i++)
	{
		if (!IsValidClient(i) || IsFakeClient(i))
			continue;

		for (int x = 1; x <= MaxClients; x++)
		{
			if (!IsValidClient(x) || IsFakeClient(x))
				continue;

			if (!IsVectorZero(g_vecSprayOrigin[x]))
				g_iClientToClientSprayLifetime[i][x]++;

			bool bDoNotSpray;

			if (g_bHasSprayHidden[i][x])
			{
				PaintWorldDecalToOne(g_iHiddenDecalIndex, g_vecSprayOrigin[x], i);
				bDoNotSpray = true;
			}

			if (!g_bWantsToSeeNSFWSprays[i] && g_bHasNSFWSpray[x] && !bDoNotSpray)
			{
				PaintWorldDecalToOne(g_iNSFWDecalIndex, g_vecSprayOrigin[x], i);
				bDoNotSpray = true;
			}

			if (g_iClientToClientSprayLifetime[i][x] >= g_iClientSprayLifetime[i] && !bDoNotSpray)
			{
				g_bSkipDecalHook = true;
				SprayClientDecalToOne(x, i, g_iDecalEntity[x], g_vecSprayOrigin[x]);
				g_iClientToClientSprayLifetime[i][x] = 0;
				g_bSkipDecalHook = false;
			}
		}
	}

	g_hRoundEndTimer = null;
	return Plugin_Continue;
}

public Action Timer_ResetOldSprays(Handle hThis)
{
	for (int i = 1; i <= MaxClients; i++)
	{
		if (!IsValidClient(i) || IsFakeClient(i))
			continue;

		if (!IsVectorZero(g_vecSprayOrigin[i]))
			g_iSprayLifetime[i]++;

		if (g_iSprayLifetime[i] >= g_cvarMaxSprayLifetime.IntValue)
		{
			g_iAllowSpray = i;
			SprayClientDecalToAll(i, 0, ACTUAL_NULL_VECTOR);
			g_iSprayLifetime[i] = 0;
		}
		else
		{
			for (int x = 1; x <= MaxClients; x++)
			{
				if (!IsValidClient(x) || IsFakeClient(x))
					continue;

				if (g_bHasSprayHidden[x][i])
				{
					PaintWorldDecalToOne(g_iHiddenDecalIndex, g_vecSprayOrigin[i], x);
					continue;
				}

				if (!g_bWantsToSeeNSFWSprays[x] && g_bHasNSFWSpray[i])
					PaintWorldDecalToOne(g_iNSFWDecalIndex, g_vecSprayOrigin[i], x);
			}
		}
	}

	g_hRoundEndTimer = null;
	return Plugin_Continue;
}

void InitializeSQL()
{
	if (g_hDatabase != null)
		delete g_hDatabase;

	if (SQL_CheckConfig("spraymanager"))
		SQL_TConnect(OnSQLConnected, "spraymanager");
	else
		SetFailState("Could not find \"spraymanager\" entry in databases.cfg.");
}

public void OnSQLConnected(Handle hParent, Handle hChild, const char[] err, any data)
{
	if (hChild == null)
	{
		LogError("Failed to connect to database, retrying in 10 seconds. (%s)", err);
		CreateTimer(10.0, ReconnectSQL);

		return;
	}

	char sDriver[16];
	g_hDatabase = CloneHandle(hChild);
	SQL_GetDriverIdent(hParent, sDriver, sizeof(sDriver));

	SQL_LockDatabase(g_hDatabase);
	if (!strncmp(sDriver, "my", 2, false))
	{
		SQL_TQuery(g_hDatabase, DummyCallback, "SET NAMES \"UTF8\"");

		SQL_TQuery(g_hDatabase, OnSQLTableCreated, "CREATE TABLE IF NOT EXISTS `spraymanager` (`steamid` VARCHAR(32) NOT NULL, `name` VARCHAR(32) NOT NULL, `unbantime` INT, `issuersteamid` VARCHAR(32), `issuername` VARCHAR(32) NOT NULL, `issuedtime` INT, `issuedreason` VARCHAR(64) NOT NULL, PRIMARY KEY(steamid)) CHARACTER SET utf8 COLLATE utf8_general_ci;");
		SQL_TQuery(g_hDatabase, OnSQLSprayBlacklistCreated, "CREATE TABLE IF NOT EXISTS `sprayblacklist` (`sprayhash` VARCHAR(16) NOT NULL, `sprayer` VARCHAR(32) NOT NULL, `sprayersteamid` VARCHAR(32), PRIMARY KEY(sprayhash)) CHARACTER SET utf8 COLLATE utf8_general_ci;");
		SQL_TQuery(g_hDatabase, OnSQLNSFWListCreated, "CREATE TABLE IF NOT EXISTS `spraynsfwlist` (`sprayhash` VARCHAR(16) NOT NULL, `sprayersteamid` VARCHAR(32), `setbyadmin` TINYINT, PRIMARY KEY(sprayhash)) CHARACTER SET utf8 COLLATE utf8_general_ci");

		g_bSQLite = false;
	}
	else
	{
		SQL_TQuery(g_hDatabase, OnSQLTableCreated, "CREATE TABLE IF NOT EXISTS `spraymanager` (`steamid` TEXT NOT NULL, `name` TEXT DEFAULT 'unknown', `unbantime` INTEGER, `issuersteamid` TEXT, `issuername` TEXT DEFAULT 'unknown', `issuedtime` INTEGER NOT NULL, `issuedreason` TEXT DEFAULT 'none', PRIMARY KEY(steamid));");
		SQL_TQuery(g_hDatabase, OnSQLSprayBlacklistCreated, "CREATE TABLE IF NOT EXISTS `sprayblacklist` (`sprayhash` TEXT NOT NULL, `sprayer` TEXT DEFAULT 'unknown', `sprayersteamid` TEXT, PRIMARY KEY(sprayhash));");
		SQL_TQuery(g_hDatabase, OnSQLNSFWListCreated, "CREATE TABLE IF NOT EXISTS `spraynsfwlist` (`sprayhash` TEXT NOT NULL, `sprayersteamid` TEXT, `setbyadmin` INTEGER, PRIMARY KEY(sprayhash));");

		g_bSQLite = true;
	}
	SQL_UnlockDatabase(g_hDatabase);
}

public Action ReconnectSQL(Handle hTimer)
{
	InitializeSQL();

	return Plugin_Handled;
}

public void OnSQLTableCreated(Handle hParent, Handle hChild, const char[] err, any data)
{
	if (hChild == null)
	{
		LogError("Database error while creating/checking for \"spraymanager\" table, retrying in 10 seconds. (%s)", err);
		CreateTimer(10.0, RetryMainTableCreation);

		return;
	}

	g_bGotBans = true;

	if (g_bGotBlacklist && g_bGotNSFWList)
	{
		if (g_bLoadedLate)
			CreateTimer(2.5, RetryUpdatingPlayerInfo);

		LogMessage("Successfully connected to %s database!", g_bSQLite ? "SQLite" : "mySQL");

		g_bFullyConnected = true;
	}
}

public Action RetryMainTableCreation(Handle hTimer)
{
	SQL_LockDatabase(g_hDatabase);
	if (g_bSQLite)
		SQL_TQuery(g_hDatabase, OnSQLTableCreated, "CREATE TABLE IF NOT EXISTS `spraymanager` (`steamid` TEXT NOT NULL, `name` TEXT DEFAULT 'unknown', `unbantime` INTEGER, `issuersteamid` TEXT, `issuername` TEXT DEFAULT 'unknown', `issuedtime` INTEGER NOT NULL, `issuedreason` TEXT DEFAULT 'none', PRIMARY KEY(steamid));");
	else
		SQL_TQuery(g_hDatabase, OnSQLTableCreated, "CREATE TABLE IF NOT EXISTS `spraymanager` (`steamid` VARCHAR(32) NOT NULL, `name` VARCHAR(32) NOT NULL, `unbantime` INT, `issuersteamid` VARCHAR(32), `issuername` VARCHAR(32) NOT NULL, `issuedtime` INT, `issuedreason` VARCHAR(64) NOT NULL, PRIMARY KEY(steamid)) CHARACTER SET utf8 COLLATE utf8_general_ci;");
	SQL_UnlockDatabase(g_hDatabase);
	return Plugin_Continue;
}

public void OnSQLSprayBlacklistCreated(Handle hParent, Handle hChild, const char[] err, any data)
{
	if (hChild == null)
	{
		LogError("Database error while creating/checking for \"sprayblacklist\" table, retrying in 10 seconds. (%s)", err);
		CreateTimer(10.0, RetryBlacklistTableCreation);

		return;
	}

	g_bGotBlacklist = true;

	if (g_bGotBans && g_bGotNSFWList)
	{
		if (g_bLoadedLate)
			CreateTimer(2.5, RetryUpdatingPlayerInfo);

		LogMessage("Successfully connected to %s database!", g_bSQLite ? "SQLite" : "mySQL");

		g_bFullyConnected = true;
	}
}

public Action RetryBlacklistTableCreation(Handle hTimer)
{
	SQL_LockDatabase(g_hDatabase);
	if (g_bSQLite)
		SQL_TQuery(g_hDatabase, OnSQLSprayBlacklistCreated, "CREATE TABLE IF NOT EXISTS `sprayblacklist` (`sprayhash` TEXT NOT NULL, `sprayer` TEXT DEFAULT 'unknown', `sprayersteamid` TEXT NOT NULL, PRIMARY KEY(sprayhash));");
	else
		SQL_TQuery(g_hDatabase, OnSQLSprayBlacklistCreated, "CREATE TABLE IF NOT EXISTS `sprayblacklist` (`sprayhash` VARCHAR(16) NOT NULL, `sprayer` VARCHAR(32) NOT NULL, `sprayersteamid` VARCHAR(32) NOT NULL, PRIMARY KEY(sprayhash)) CHARACTER SET utf8 COLLATE utf8_general_ci;");
	SQL_UnlockDatabase(g_hDatabase);
	return Plugin_Continue;
}

public void OnSQLNSFWListCreated(Handle hParent, Handle hChild, const char[] err, any data)
{
	if (hChild == null)
	{
		LogError("Database error while creating/checking for \"spraynsfwlist\" table, retrying in 10 seconds. (%s)", err);
		CreateTimer(10.0, RetryNSFWlistTableCreation);

		return;
	}

	g_bGotNSFWList = true;

	if (g_bGotBans && g_bGotBlacklist)
	{
		if (g_bLoadedLate)
			CreateTimer(2.5, RetryUpdatingPlayerInfo);

		LogMessage("Successfully connected to %s database!", g_bSQLite ? "SQLite" : "mySQL");

		g_bFullyConnected = true;
	}
}

public Action RetryNSFWlistTableCreation(Handle hTimer)
{
	SQL_LockDatabase(g_hDatabase);
	if (g_bSQLite)
		SQL_TQuery(g_hDatabase, OnSQLNSFWListCreated, "CREATE TABLE IF NOT EXISTS `spraynsfwlist` (`sprayhash` TEXT NOT NULL, `sprayersteamid` TEXT, `setbyadmin` INTEGER, PRIMARY KEY(sprayhash));");
	else
		SQL_TQuery(g_hDatabase,	OnSQLNSFWListCreated, "CREATE TABLE IF NOT EXISTS `spraynsfwlist` (`sprayhash` VARCHAR(16) NOT NULL, `sprayersteamid` VARCHAR(32), `setbyadmin` TINYINT PRIMARY KEY(sprayhash)) CHARACTER SET utf8 COLLATE utf8_general_ci");
	SQL_UnlockDatabase(g_hDatabase);
	return Plugin_Continue;
}

public Action RetryUpdatingPlayerInfo(Handle hTimer)
{
	for (int i = 1; i <= MaxClients; i++)
	{
		if (!IsValidClient(i))
			continue;

		OnClientPostAdminCheck(i);
	}
	return Plugin_Continue;
}

public void RemoveAllSprays()
{
	for (int i = 1; i <= MaxClients; i++)
	{
		if (!IsValidClient(i) || IsFakeClient(i))
			continue;

		if (IsVectorZero(g_vecSprayOrigin[i]))
			continue;

		g_iAllowSpray = i;
		SprayClientDecalToAll(i, 0, ACTUAL_NULL_VECTOR);
	}
}

void GetConVars(bool bDeleteSprays = true)
{
	g_bEnableSprays = g_cvarEnableSprays.BoolValue;

	if (bDeleteSprays && !g_bEnableSprays)
		RemoveAllSprays();

	char sAuthorizedFlags[64];
	g_cvarAuthorizedFlags.GetString(sAuthorizedFlags, sizeof(sAuthorizedFlags));

	char sSplitedFlags[32][3];
	int iSentences = ExplodeString(sAuthorizedFlags, ",", sSplitedFlags, sizeof(sSplitedFlags), 3);
	for (int j = 0; j < sizeof(g_iAuthorizedFlags); j++)
		g_iAuthorizedFlags[j] = -1;

	int i = 0;
	while (i < iSentences)
	{
		if (strlen(sSplitedFlags[i]) == 1)
			g_iAuthorizedFlags[i] = sSplitedFlags[i][0];
		else
			g_iAuthorizedFlags[i] = 0;
		i++;
	}
	if (i < sizeof(g_iAuthorizedFlags))
		g_iAuthorizedFlags[i] =  -1;
}

public void ConVarChanged_EnableSpray(ConVar cvar, const char[] sOldValue, const char[] sNewValue)
{
	GetConVars();
}

public void ConVarChanged_AuthorizedFlags(ConVar cvar, const char[] sOldValue, const char[] sNewValue)
{
	GetConVars(false);
}

public void ConVarChanged_DecalFrequency(ConVar cvar, const char[] sOldValue, const char[] sNewValue)
{
	if (cvar == g_cvarHookedDecalFrequency)
	{
		if (StringToInt(sNewValue) != 0)
		{
			LogMessage("ConVar \"decalfrequency\" needs to be 0 at all times, please use sm_decalfrequency instead.");
			cvar.IntValue = 0;
		}
	}
}

bool SprayBanClient(int client, int target, int iBanLength, const char[] sReason)
{
	if (!IsValidClient(target))
	{
		ReplyToCommand(client, "[SprayManager] Target is no longer valid.");
		return false;
	}

	if (g_hDatabase == null || !g_bFullyConnected)
	{
		ReplyToCommand(client, "[SprayManager] Database is not connected.");
		return false;
	}

	if (g_bSprayBanned[target])
	{
		ReplyToCommand(client, "[SprayManager] %N is already spray banned.", target);
		return false;
	}

	char sQuery[512];
	char sAdminName[64];
	char sTargetName[64];
	char sTargetSteamID[32];
	char sAdminSteamID[32];

	Format(sAdminName, sizeof(sAdminName), "%N", client);
	GetClientName(target, sTargetName, sizeof(sTargetName));

	if (client)
		GetClientAuthId(client, AuthId_Steam2, sAdminSteamID, sizeof(sAdminSteamID));
	else
		strcopy(sAdminSteamID, sizeof(sAdminSteamID), "STEAM_ID_SERVER");

	GetClientAuthId(target, AuthId_Steam2, sTargetSteamID, sizeof(sTargetSteamID));

	char[] sSafeAdminName = new char[2 * strlen(sAdminName) + 1];
	char[] sSafeTargetName = new char[2 * strlen(sTargetName) + 1];
	char[] sSafeReason = new char[2 * strlen(sReason) + 1];
	SQL_EscapeString(g_hDatabase, sAdminName, sSafeAdminName, 2 * strlen(sAdminName) + 1);
	SQL_EscapeString(g_hDatabase, sTargetName, sSafeTargetName, 2 * strlen(sTargetName) + 1);
	SQL_EscapeString(g_hDatabase, sReason, sSafeReason, 2 * strlen(sReason) + 1);

	Format(sQuery, sizeof(sQuery), "INSERT INTO `spraymanager` (`steamid`, `name`, `unbantime`, `issuersteamid`, `issuername`, `issuedtime`, `issuedreason`) VALUES ('%s', '%s', '%d', '%s', '%s', '%d', '%s');",
		sTargetSteamID, sSafeTargetName, iBanLength ? (GetTime() + (iBanLength * 60)) : 0, sAdminSteamID, sSafeAdminName, GetTime(), strlen(sSafeReason) > 1 ? sSafeReason : "none");

	SQL_TQuery(g_hDatabase, DummyCallback, sQuery);

	strcopy(g_sBanIssuer[target], sizeof(g_sBanIssuer[]), sAdminName);
	strcopy(g_sBanIssuerSID[target], sizeof(g_sBanIssuerSID[]), sAdminSteamID);
	strcopy(g_sBanReason[target], sizeof(g_sBanReason[]), strlen(sReason) ? sReason : "none");
	g_bSprayBanned[target] = true;
	g_iSprayBanTimestamp[target] = GetTime();
	g_iSprayUnbanTimestamp[target] = iBanLength ? (GetTime() + (iBanLength * 60)) : 0;
	g_fNextSprayTime[target] = 0.0;

	g_iAllowSpray = target;
	SprayClientDecalToAll(target, 0, ACTUAL_NULL_VECTOR);

	return true;
}

bool SprayUnbanClient(int target, int client=-1)
{
	if (!IsValidClient(target))
	{
		if (client != -1)
			ReplyToCommand(client, "[SprayManager] Target is no longer valid.");

		return false;
	}

	if (g_hDatabase == null || !g_bFullyConnected)
	{
		if (client != -1)
			ReplyToCommand(client, "[SprayManager] Database is not connected.");

		return false;
	}

	if (!g_bSprayBanned[target])
	{
		if (client != -1)
			ReplyToCommand(client, "[SprayManager] %N is not spray banned.", target);

		return false;
	}

	char sQuery[128];
	char sClientSteamID[32];

	GetClientAuthId(target, AuthId_Steam2, sClientSteamID, sizeof(sClientSteamID));
	Format(sQuery, sizeof(sQuery), "DELETE FROM `spraymanager` WHERE steamid = '%s';", sClientSteamID);

	SQL_TQuery(g_hDatabase, DummyCallback, sQuery);

	strcopy(g_sBanIssuer[target], sizeof(g_sBanIssuer[]), "");
	strcopy(g_sBanIssuerSID[target], sizeof(g_sBanIssuerSID[]), "");
	strcopy(g_sBanReason[target], sizeof(g_sBanReason[]), "");
	g_bSprayBanned[target] = false;
	g_iSprayLifetime[target] = 0;
	UpdateClientToClientSprayLifeTime(target, 0);
	g_iSprayBanTimestamp[target] = 0;
	g_iSprayUnbanTimestamp[target] = -1;
	g_fNextSprayTime[target] = 0.0;

	return true;
}

bool BanClientSpray(int client, int target)
{
	if (!IsValidClient(target))
	{
		ReplyToCommand(client, "[SprayManager] Target is no longer valid.");
		return false;
	}

	if (g_hDatabase == null || !g_bFullyConnected)
	{
		ReplyToCommand(client, "[SprayManager] Database is not connected.");
		return false;
	}

	if (g_bSprayHashBanned[target])
	{
		ReplyToCommand(client, "[SprayManager] %N is already hash banned.", target);
		return false;
	}

	char sQuery[256];
	char sTargetName[64];
	char sTargetSteamID[32];

	GetClientName(target, sTargetName, sizeof(sTargetName));
	GetClientAuthId(target, AuthId_Steam2, sTargetSteamID, sizeof(sTargetSteamID));

	char[] sSafeTargetName = new char[2 * strlen(sTargetName) + 1];
	SQL_EscapeString(g_hDatabase, sTargetName, sSafeTargetName, 2 * strlen(sTargetName) + 1);

	Format(sQuery, sizeof(sQuery), "INSERT INTO `sprayblacklist` (`sprayhash`, `sprayer`, `sprayersteamid`) VALUES ('%s', '%s', '%s');",
		g_sSprayHash[target], sSafeTargetName, sTargetSteamID);

	SQL_TQuery(g_hDatabase, DummyCallback, sQuery);

	g_bSprayHashBanned[target] = true;

	g_iAllowSpray = target;
	SprayClientDecalToAll(target, 0, ACTUAL_NULL_VECTOR);

	return true;
}

bool UnbanClientSpray(int client, int target)
{
	if (!IsValidClient(target))
	{
		ReplyToCommand(client, "[SprayManager] Target is no longer valid.");
		return false;
	}

	if (g_hDatabase == null || !g_bFullyConnected)
	{
		ReplyToCommand(client, "[SprayManager] Database is not connected.");
		return false;
	}

	if (!g_bSprayHashBanned[target])
	{
		ReplyToCommand(client, "[SprayManager] %N is not hash banned.", target);
		return false;
	}

	char sQuery[128];
	Format(sQuery, sizeof(sQuery), "DELETE FROM `sprayblacklist` WHERE `sprayhash` = '%s';", g_sSprayHash[target]);

	SQL_TQuery(g_hDatabase, DummyCallback, sQuery);

	g_bSprayHashBanned[target] = false;

	return true;
}

void AdminForceSprayNSFW(int client)
{
	char sQuery[256];
	char sClientSteamID[32];

	GetClientAuthId(client, AuthId_Steam2, sClientSteamID, sizeof(sClientSteamID));
	Format(sQuery, sizeof(sQuery), "INSERT INTO `spraynsfwlist` (`sprayhash`, `sprayersteamid`, `setbyadmin`) VALUES ('%s', '%s', '%d');", g_sSprayHash[client], sClientSteamID, 1);

	SQL_TQuery(g_hDatabase, DummyCallback, sQuery);

	g_bHasNSFWSpray[client] = true;
	g_bMarkedNSFWByAdmin[client] = true;

	for (int i = 1; i <= MaxClients; i++)
	{
		if (!IsValidClient(i))
			continue;

		for (int x = 1; x <= MaxClients; x++)
		{
			if (!IsValidClient(x))
				continue;

			if (g_bHasSprayHidden[i][x])
				continue;

			if (g_bWantsToSeeNSFWSprays[i])
				continue;

			PaintWorldDecalToOne(g_iNSFWDecalIndex, g_vecSprayOrigin[x], i);
			g_bSkipDecalHook = true;
			SprayClientDecalToOne(x, i, 0, ACTUAL_NULL_VECTOR);
			g_bSkipDecalHook = false;
		}
	}
}

void AdminForceSpraySFW(int client)
{
	char sQuery[256];
	char sClientSteamID[32];

	GetClientAuthId(client, AuthId_Steam2, sClientSteamID, sizeof(sClientSteamID));
	Format(sQuery, sizeof(sQuery), "DELETE FROM `spraynsfwlist` WHERE `sprayhash` = '%s';", g_sSprayHash[client]);

	SQL_TQuery(g_hDatabase, DummyCallback, sQuery);

	g_bHasNSFWSpray[client] = false;
	g_bMarkedNSFWByAdmin[client] = false;

	for (int i = 1; i <= MaxClients; i++)
	{
		if (!IsValidClient(i))
			continue;

		for (int x = 1; x <= MaxClients; x++)
		{
			if (!IsValidClient(x))
				continue;

			if (g_bHasSprayHidden[i][x])
				continue;

			PaintWorldDecalToOne(g_iTransparentDecalIndex, g_vecSprayOrigin[x], i);
			g_bSkipDecalHook = true;
			SprayClientDecalToOne(x, i, g_iDecalEntity[x], g_vecSprayOrigin[x]);
			g_iClientToClientSprayLifetime[i][x] = 0;
			g_bSkipDecalHook = false;
		}
	}
}

void UpdatePlayerInfo(int client)
{
	if (!IsValidClient(client))
		return;

	if (g_hDatabase == null || !g_bFullyConnected)
		return;

	char sSteamID[32];
	char sQuery[128];

	GetClientAuthId(client, AuthId_Steam2, sSteamID, sizeof(sSteamID));
	Format(sQuery, sizeof(sQuery), "SELECT * FROM `spraymanager` WHERE `steamid` = '%s';", sSteamID);

	SQL_TQuery(g_hDatabase, OnSQLCheckBanQuery, sQuery, client, DBPrio_High);
}

void UpdateSprayHashInfo(int client)
{
	if (!IsValidClient(client))
		return;

	if (g_hDatabase == null || !g_bFullyConnected)
		return;

	char sSprayQuery[128];

	Format(sSprayQuery, sizeof(sSprayQuery), "SELECT * FROM `sprayblacklist` WHERE `sprayhash` = '%s';", g_sSprayHash[client]);
	SQL_TQuery(g_hDatabase, OnSQLCheckSprayHashBanQuery, sSprayQuery, client, DBPrio_High);
}

void UpdateNSFWInfo(int client)
{
	if (!IsValidClient(client))
		return;

	if (g_hDatabase == null || !g_bFullyConnected)
		return;

	char sSprayQuery[128];

	Format(sSprayQuery, sizeof(sSprayQuery), "SELECT * FROM `spraynsfwlist` WHERE `sprayhash` = '%s';", g_sSprayHash[client]);
	SQL_TQuery(g_hDatabase, OnSQLCheckNSFWSprayHashQuery, sSprayQuery, client);
}

void NotifyAdmins(int iParam1, int target, const char[] sReason)
{
	for(int i = 1; i <= MaxClients; i++)
	{
		if(IsClientInGame(i) && !IsFakeClient(i) && CheckCommandAccess(i, "sm_spray", ADMFLAG_GENERIC))
			CPrintToChat(i, "{green}[SM]{olive} %N %s {default}by {olive}%N{default}.", target, sReason, iParam1);
	}
}

public void DummyCallback(Handle hOwner, Handle hChild, const char[] err, any data)
{
	if (hOwner == null || hChild == null)
		LogError("Query error. (%s)", err);
}

public void OnSQLCheckBanQuery(Handle hParent, Handle hChild, const char[] err, any client)
{
	if (!IsValidClient(client))
		return;

	if (hChild == null)
	{
		LogError("An error occurred while querying the database for a user ban, retrying in 10 seconds. (%s)", err);
		CreateTimer(10.0, RetryPlayerInfoUpdate, client);

		return;
	}

	if (SQL_FetchRow(hChild))
	{
		g_bSprayBanned[client] = true;
		g_iSprayUnbanTimestamp[client] = SQL_FetchInt(hChild, 2);
		g_iSprayBanTimestamp[client] = SQL_FetchInt(hChild, 5);

		SQL_FetchString(hChild, 3, g_sBanIssuerSID[client], sizeof(g_sBanIssuerSID[]));
		SQL_FetchString(hChild, 4, g_sBanIssuer[client], sizeof(g_sBanIssuer[]));
		SQL_FetchString(hChild, 6, g_sBanReason[client], sizeof(g_sBanReason[]));
	}
}

public void OnSQLCheckSprayHashBanQuery(Handle hParent, Handle hChild, const char[] err, any client)
{
	if (!IsValidClient(client))
		return;

	if (hChild == null)
	{
		LogError("An error occurred while querying the database for a spray ban, retrying in 10 seconds. (%s)", err);
		CreateTimer(10.0, RetrySprayHashUpdate, client);

		return;
	}

	if (SQL_FetchRow(hChild))
		g_bSprayHashBanned[client] = true;
}

public void OnSQLCheckNSFWSprayHashQuery(Handle hParent, Handle hChild, const char[] err, any client)
{
	if (!IsValidClient(client))
		return;

	if (hChild == null)
	{
		LogError("An error occurred while querying the NSFW database for a spray, retrying in 10 seconds. (%s)", err);
		CreateTimer(10.0, RetryNSFWSprayLookup, client);

		return;
	}

	if (SQL_FetchRow(hChild))
	{
		g_bHasNSFWSpray[client] = true;

		char sSetByAdmin[8];
		SQL_FetchString(hChild, 2, sSetByAdmin, sizeof(sSetByAdmin));

		g_bMarkedNSFWByAdmin[client] = view_as<bool>(StringToInt(sSetByAdmin));
	}
}

public Action RetryPlayerInfoUpdate(Handle hTimer, any client)
{
	UpdatePlayerInfo(client);
	return Plugin_Continue;
}

public Action RetrySprayHashUpdate(Handle hTimer, any client)
{
	UpdateSprayHashInfo(client);
	return Plugin_Continue;
}

public Action RetryNSFWSprayLookup(Handle hTimer, any client)
{
	UpdateNSFWInfo(client);
	return Plugin_Continue;
}

stock bool ForceSpray(int client, int target, bool bPlaySound=true)
{
	if (!IsValidClient(target))
		return false;

	if (!g_bEnableSprays)
	{
		bool bAuthorized = false;
		for (int i = 0; i < sizeof(g_iAuthorizedFlags); i++)
		{
			for (int j = 0; j < sizeof(g_iAdminFlags); j++)
			{
				if (g_iAuthorizedFlags[i] == g_iAdminFlags[j][0] && (GetUserFlagBits(client) & (g_iAdminFlags[j][1]) == (g_iAdminFlags[j][1])))
				{
					bAuthorized = true;
					break;
				}
			}
			if (bAuthorized || g_iAuthorizedFlags[i] == -1)
				break;
		}
		if (!bAuthorized)
		{
			CPrintToChat(client, "{green}[SprayManager] {white}Sorry, all sprays are currently disabled on the server.");
			return false;
		}
	}

	float vecEndPos[3];

	if (TracePlayerAngles(client, vecEndPos))
	{
		SprayClientDecalToAll(target, g_iDecalEntity[client], vecEndPos);

		if (bPlaySound)
			EmitSoundToAll("player/sprayer.wav", SOUND_FROM_WORLD, SNDCHAN_AUTO, SNDLEVEL_NORMAL, SND_NOFLAGS, _, _, _, vecEndPos);

		return true;
	}

	CPrintToChat(client, "{green}[SprayManager]{default} Could not spray here, try somewhere else.");

	return false;
}

stock bool SprayClientDecalToAll(int client, int iEntity, const float vecOrigin[3])
{
	if (!IsValidClient(client))
		return false;

	TE_Start("Player Decal");
	TE_WriteVector("m_vecOrigin", vecOrigin);
	TE_WriteNum("m_nEntity", iEntity);
	TE_WriteNum("m_nPlayer", client);
	TE_SendToAll();

	return true;
}

stock bool SprayClientDecalToSelected(int client, int iEntity, const float vecOrigin[3], int[] iClients, int iNumClients)
{
	if (!IsValidClient(client))
		return false;

	TE_Start("Player Decal");
	TE_WriteVector("m_vecOrigin", vecOrigin);
	TE_WriteNum("m_nEntity", iEntity);
	TE_WriteNum("m_nPlayer", client);
	TE_Send(iClients, iNumClients);

	return true;
}

stock bool SprayClientDecalToOne(int client, int target, int iEntity, const float vecOrigin[3])
{
	if (!IsValidClient(client))
		return false;

	TE_Start("Player Decal");
	TE_WriteVector("m_vecOrigin", vecOrigin);
	TE_WriteNum("m_nEntity", iEntity);
	TE_WriteNum("m_nPlayer", client);
	TE_SendToClient(target);

	return true;
}

stock void PaintWorldDecalToSelected(int iDecalIndex, const float vecOrigin[3], int[] iClients, int iNumClients)
{
	TE_Start("World Decal");
	TE_WriteVector("m_vecOrigin", vecOrigin);
	TE_WriteNum("m_nIndex", iDecalIndex);
	TE_Send(iClients, iNumClients);
}

stock void PaintWorldDecalToOne(int iDecalIndex, const float vecOrigin[3], int target)
{
	TE_Start("World Decal");
	TE_WriteVector("m_vecOrigin", vecOrigin);
	TE_WriteNum("m_nIndex", iDecalIndex);
	TE_SendToClient(target);
}

stock bool TracePlayerAngles(int client, float vecResult[3])
{
	if (!IsValidClient(client))
		return false;

	float vecEyeAngles[3];
	float vecEyeOrigin[3];

	GetClientEyeAngles(client, vecEyeAngles);
	GetClientEyePosition(client, vecEyeOrigin);

	g_iDecalEntity[client] = 0;

	Handle hTraceRay = TR_TraceRayFilterEx(vecEyeOrigin, vecEyeAngles, MASK_SOLID_BRUSHONLY, RayType_Infinite, TraceEntityFilter_FilterPlayers);

	if (TR_DidHit(hTraceRay))
	{
		TR_GetEndPosition(vecResult, hTraceRay);

		int iEntity;

		if ((iEntity = TR_GetEntityIndex(hTraceRay)) >= 0)
			g_iDecalEntity[client] = iEntity;

		delete hTraceRay;

		return true;
	}

	delete hTraceRay;

	return false;
}

stock bool TracePlayerAnglesRanged(int client, float fMaxDistance)
{
	if (!IsValidClient(client))
		return false;

	float vecEyeAngles[3];
	float vecEyeOrigin[3];
	float vecDirection[3];
	float vecEndPos[3];

	GetClientEyeAngles(client, vecEyeAngles);
	GetClientEyePosition(client, vecEyeOrigin);
	GetAngleVectors(vecEyeAngles, vecDirection, NULL_VECTOR, NULL_VECTOR);

	vecEndPos[0] = vecEyeOrigin[0] + (vecDirection[0] * fMaxDistance);
	vecEndPos[1] = vecEyeOrigin[1] + (vecDirection[1] * fMaxDistance);
	vecEndPos[2] = vecEyeOrigin[2] + (vecDirection[2] * fMaxDistance);

	g_iDecalEntity[client] = 0;

	Handle hTraceRay = TR_TraceRayFilterEx(vecEyeOrigin, vecEndPos, MASK_SOLID_BRUSHONLY, RayType_EndPoint, TraceEntityFilter_FilterPlayers);

	if (TR_DidHit(hTraceRay))
	{
		delete hTraceRay;

		return true;
	}

	delete hTraceRay;

	return false;
}

stock void ClearPlayerInfo(int client)
{
	strcopy(g_sBanIssuer[client], sizeof(g_sBanIssuer[]), "");
	strcopy(g_sBanIssuerSID[client], sizeof(g_sBanIssuerSID[]), "");
	strcopy(g_sBanReason[client], sizeof(g_sBanReason[]), "");
	strcopy(g_sSprayHash[client], sizeof(g_sSprayHash[]), "");
	g_bSprayBanned[client] = false;
	g_bSprayHashBanned[client] = false;
	g_iClientSprayLifetime[client] = 2;
	g_iSprayLifetime[client] = 0;
	ResetClientToClientSprayLifeTime(client);
	ResetHiddenSprayArray(client);
	g_iSprayBanTimestamp[client] = 0;
	g_iSprayUnbanTimestamp[client] = -1;
	g_fNextSprayTime[client] = 0.0;
	g_vecSprayOrigin[client] = ACTUAL_NULL_VECTOR;
	g_SprayAABB[client] = view_as<float>({ 0.0, 0.0, 0.0, 0.0, 0.0, 0.0 }); //???
	g_bHasNSFWSpray[client] = false;
	g_bMarkedNSFWByAdmin[client] = false;
}

stock void UpdateClientToClientSprayLifeTime(int client, int iLifeTime)
{
	for (int i = 1; i <= MaxClients; i++)
	{
		g_iClientToClientSprayLifetime[i][client] = iLifeTime;
	}
}

stock void ResetClientToClientSprayLifeTime(int client)
{
	for (int i = 1; i <= MaxClients; i++)
	{
		g_iClientToClientSprayLifetime[i][client] = 0;
		g_iClientToClientSprayLifetime[client][i] = 0;
	}
}

stock void ResetHiddenSprayArray(int client)
{
	for (int i = 1; i <= MaxClients; i++)
	{
		g_bHasSprayHidden[i][client] = false;
		g_bHasSprayHidden[client][i] = false;
	}
}

stock void FormatRemainingTime(int iTimestamp, char[] sBuffer, int iBuffSize)
{
	if (!iTimestamp)
	{
		Format(sBuffer, iBuffSize, "Permanent");
		return;
	}

	int tstamp = (iTimestamp - GetTime());

	int days = (tstamp / 86400);
	int hours = ((tstamp / 3600) % 24);
	int minutes = ((tstamp / 60) % 60);
	int seconds = (tstamp % 60);

	if (tstamp > 86400)
	{
		Format(sBuffer, iBuffSize, "%d %s, %d %s, %d %s, %d %s", days, SingularOrMultiple(days) ? "Days" : "Day",
			hours, SingularOrMultiple(hours) ? "Hours" : "Hour", minutes, SingularOrMultiple(minutes) ? "Minutes" : "Minute",
			seconds, SingularOrMultiple(seconds)?"Seconds":"Second");
	}
	else if (tstamp > 3600)
	{
		Format(sBuffer, iBuffSize, "%d %s, %d %s, %d %s", hours, SingularOrMultiple(hours) ? "Hours" : "Hour",
			minutes, SingularOrMultiple(minutes) ? "Minutes" : "Minute", seconds, SingularOrMultiple(seconds) ? "Seconds" : "Second");
	}
	else if (tstamp > 60)
	{
		Format(sBuffer, iBuffSize, "%d %s, %d %s", minutes, SingularOrMultiple(minutes) ? "Minutes" : "Minute",
			seconds, SingularOrMultiple(seconds) ? "Seconds" : "Second");
	}
	else
		Format(sBuffer, iBuffSize, "%d %s", seconds, SingularOrMultiple(seconds) ? "Seconds":"Second");
}

stock bool IsPointInsideAABB(float vecPoint[3], float AABB[6])
{
	if (vecPoint[0] >= AABB[AABBMinX] && vecPoint[0] <= AABB[AABBMaxX] &&
		vecPoint[1] >= AABB[AABBMinY] && vecPoint[1] <= AABB[AABBMaxY] &&
		vecPoint[2] >= AABB[AABBMinZ] && vecPoint[2] <= AABB[AABBMaxZ])
	{
		return true;
	}

	return false;
}

stock bool CheckForAABBCollision(float AABB1[6], float AABB2[6])
{
	if (AABB1[AABBMinX] > AABB2[AABBMaxX]) return false;
	if (AABB1[AABBMinY] > AABB2[AABBMaxY]) return false;
	if (AABB1[AABBMinZ] > AABB2[AABBMaxZ]) return false;
	if (AABB1[AABBMaxX] < AABB2[AABBMinX]) return false;
	if (AABB1[AABBMaxY] < AABB2[AABBMinY]) return false;
	if (AABB1[AABBMaxZ] < AABB2[AABBMinZ]) return false;

	return true;
}

stock bool IsVectorZero(float vecPos[3])
{
	return ((vecPos[0] == 0.0) && (vecPos[1] == 0.0) && (vecPos[2] == 0.0));
}

stock bool SingularOrMultiple(int num)
{
	if (!num || num > 1)
		return true;

	return false;
}

stock bool TraceEntityFilter_FilterPlayers(int entity, int contentsMask)
{
	return entity > MaxClients;
}

stock bool IsValidClient(int client)
{
	if (client <= 0 || client > MaxClients || !IsClientInGame(client))
		return false;

	return IsClientAuthorized(client);
}
