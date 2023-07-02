/*
cheer.sp

Description:
	The Cheer! plugin allows players to cheer random cheers per round.

Versions:
	1.0
		* Initial Release
		
	1.1
		* Added cvar to control colors
		* Added cvar to control chat
		* Added team color to name
		
	1.2
		* Added jeers
		* Added admin only support for jeers
		* Made config file autoload
		
	1.3
		* Added *DEAD* in front of dead people's jeers
		* Added volume control cvar sm_cheer_jeer_volume
		* Added jeer limit cvat sm_cheer_jeer_limit
		* Added count infomation to limit displays
*/


#include <sourcemod>
#include <sdktools>

#pragma semicolon 1

#define PLUGIN_VERSION "1.3.1"

//Plugin definitions
public Plugin:myinfo = 
{
	name = "Cheer!",
	author = "dalto & Cee",
	description = "The Cheer! plugin allows players to cheer random cheers per round",
	version = PLUGIN_VERSION,
	url = "http://www.srgaming.net"
};

#define Cheer 0
#define Jeer	1
#define MAX_SOUND_NUM 32

//Fixed
new SoundCount[2];
new Handle:hDeveloper = INVALID_HANDLE;
new String:g_soundsList[2][MAX_SOUND_NUM][PLATFORM_MAX_PATH];

//Normal
new g_cheerCount[MAXPLAYERS + 1];
new g_jeerCount[MAXPLAYERS + 1];
new Handle:g_CvarEnabled = INVALID_HANDLE;
new Handle:g_CvarMaxCheers = INVALID_HANDLE;
new Handle:g_CvarChat = INVALID_HANDLE;
new Handle:g_CvarColors = INVALID_HANDLE;
new Handle:g_CvarJeer = INVALID_HANDLE;
new Handle:g_CvarMaxJeers = INVALID_HANDLE;
new Handle:g_CvarJeerVolume = INVALID_HANDLE;
new Handle:g_CvarCheerVolume = INVALID_HANDLE;

public OnPluginStart()
{
	//Version
	CreateConVar("sm_cheer_version", PLUGIN_VERSION, "Cheer Version", FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_REPLICATED|FCVAR_NOTIFY);
	
	//Developer
	hDeveloper = CreateConVar("sm_cheer_developer", "0", "Enable developer mode.");
	
	//ConVars
	g_CvarEnabled = CreateConVar("sm_cheer_enable", "1", "Enables the Cheer! plugin");
	g_CvarMaxCheers = CreateConVar("sm_cheer_limit", "3", "The maximum number of cheers per round");
	g_CvarColors = CreateConVar("sm_cheer_colors", "1", "1 to turn chat colors on, 0 for off");
	g_CvarChat = CreateConVar("sm_cheer_chat", "1", "1 to turn enable chat messages, 0 for off");
	g_CvarJeer = CreateConVar("sm_cheer_jeer", "1", "0 to disable jeers when dead, 1 to enable for all, 2 for admin only");
	g_CvarMaxJeers = CreateConVar("sm_cheer_jeer_limit", "1", "The maximum number of jeers per round");
	g_CvarJeerVolume = CreateConVar("sm_cheer_jeer_volume", "1.0", "Jeer volume: should be a number between 0.0. and 1.0");
	g_CvarCheerVolume = CreateConVar("sm_cheer_volume", "1.0", "Cheer volume: should be a number between 0.0. and 1.0");
	
	//Execute the config file
	AutoExecConfig(true, "cheer");
	
	//Translation
	LoadTranslations("plugin.cheer");
	
	//GetSound
	LoadSounds();
	
	//Events
	HookEvent("round_start", EventRoundStart, EventHookMode_PostNoCopy);
	
	//Commands
	RegConsoleCmd("cheer", Command_Cheer);
	RegServerCmd("sm_cheer_reload", Command_Reload);
}

public OnMapStart()
{
	AddFileToDownloadTable();
}

// When a new client is put in the server we reset their cheer count
public OnClientPutInServer(client)
{
	//Reset client count.
	if(client && !IsFakeClient(client))
	{
		g_cheerCount[client] = 0;
		g_jeerCount[client] = 0;
	}
}

public Action:Command_Reload(arg)
{
	//Reload Files
	LoadSounds();
	AddFileToDownloadTable();
}

public Action:Command_Cheer(client, args)
{
	if(!GetConVarBool(g_CvarEnabled))
	{
		return Plugin_Handled;
	}
	
	if(!client || !IsClientInGame(client))
	{
		return Plugin_Handled;
	}
	
	
	if(IsPlayerAlive(client))
	{
		if(g_cheerCount[client] >= GetConVarInt(g_CvarMaxCheers))
		{
			PrintToChat(client, "%t", "over cheer limit", GetConVarInt(g_CvarMaxCheers));
			return Plugin_Handled;
		}
		new Float:vec[3];
		GetClientEyePosition(client, vec);
		EmitAmbientSound(g_soundsList[Cheer][GetRandomInt(0, SoundCount[Cheer]-1)], vec, SOUND_FROM_WORLD, SNDLEVEL_SCREAMING, _, GetConVarFloat(g_CvarCheerVolume));
		if(GetConVarBool(g_CvarChat))
		{
			decl String:name[50];
			GetClientName(client, name, sizeof(name));
			if(GetConVarBool(g_CvarColors))
			{
				new Handle:hMessage = StartMessageAll("SayText2");
				BfWriteByte(hMessage, client);
				BfWriteByte(hMessage, true);
				BfWriteString(hMessage, "\x03%s1 \x04cheered!!!");
				BfWriteString(hMessage, name);
				EndMessage();
			} else {
				PrintToChatAll("%s cheered!!", name);
			}
		}
		g_cheerCount[client]++;
	}
	else //Player dead.
	{
		
		if(g_jeerCount[client] >= GetConVarInt(g_CvarMaxJeers))
		{
			PrintToChat(client, "%t", "over jeer limit", GetConVarInt(g_CvarMaxJeers));
			return Plugin_Handled;
		}
		if(GetConVarInt(g_CvarJeer) == 1 || (GetConVarInt(g_CvarJeer) == 2 && GetUserAdmin(client) != INVALID_ADMIN_ID))
		{
			for(new i = 1; i <= GetMaxClients(); i++)
			{
				if(IsClientInGame(i) && !IsFakeClient(i))
				{
					EmitSoundToClient(i, g_soundsList[Jeer][GetRandomInt(0, SoundCount[Jeer]-1)], _, _, _, _, GetConVarFloat(g_CvarJeerVolume));
				}
			}
			if(GetConVarBool(g_CvarChat))
			{
				decl String:team[10];
				team = GetClientTeam(client) > 1 ? "DEAD" : "SPEC";
				decl String:name[50];
				GetClientName(client, name, sizeof(name));
				if(GetConVarBool(g_CvarColors))
				{
					new Handle:hMessage = StartMessageAll("SayText2");
					BfWriteByte(hMessage, client);
					BfWriteByte(hMessage, true);
					BfWriteString(hMessage, "\x01*%s1* \x03%s2 \x04jeered!!!");
					BfWriteString(hMessage, team);
					BfWriteString(hMessage, name);
					EndMessage();
				}
				else
				{
					PrintToChatAll("*%s* %s jeered!!", team, name);
				}
			}
			g_jeerCount[client]++;
		}
		else
		{
			PrintToChat(client, "%t", "dead cant cheer");
		}
	}
	
	return Plugin_Handled;
}

//Load sound file name
LoadSounds()
{
	decl String:Path[256];
	BuildPath(Path_SM, Path, sizeof(Path), "configs/cheersoundlist.cfg");
	
	new Handle:kv = CreateKeyValues("CheerSoundsList");
	FileToKeyValues(kv, Path);
	
	decl String:Namelist[][] = {"cheer sounds", "jeer sounds"};
	
	for(new i = 0; i < 2; i ++)
	{
		//Back to top
		KvRewind(kv);
		
		//Jump to sub key.
		if(KvJumpToKey(kv, Namelist[i]))
		{
			decl String:SectionName[256];
			if(KvGetSectionName(kv, SectionName, sizeof(SectionName)))
			{
				new j = 0;
				
				while(StrEqual(SectionName, Namelist[i]))
				{
					decl String:buffer[64];
					decl String:sValue[128];
					
					Format(buffer, sizeof(buffer), "%s sound %i", i == 0 ? "cheer" : "jeer", j + 1);
					KvGetString(kv, buffer, sValue, PLATFORM_MAX_PATH);
					
					if(StrEqual(sValue, ""))	//Cant read value.
						break;
					
					//
					SoundCount[i]++;
					
					//Copy file name
					strcopy(g_soundsList[i][j], PLATFORM_MAX_PATH, sValue);
					
					j ++;
					
					if(GetConVarBool(hDeveloper))
						PrintToServer("%s || \"%s\" || %s", SectionName, sValue, buffer);
				}
			}
			else
				PrintToServer("Connot get keyvalue section name.");
		}
		else
			PrintToServer("Connot read keyvalue file for \"%s\" Section.", Namelist[i]);
	}
	CloseHandle(kv);
}

AddFileToDownloadTable()
{
	//Add file to DownloadTable.
	for(new i = 0; i < 2; i ++)
	{
		decl String:LoadList[MAX_SOUND_NUM][PLATFORM_MAX_PATH];
			
		for(new j = 0; j < SoundCount[i]; j ++)
		{
			decl String:downloadFile[PLATFORM_MAX_PATH];
			
			if(!StrEqual(g_soundsList[i][j], ""))
			{
				PrecacheSound(g_soundsList[i][j], true);
				Format(downloadFile, PLATFORM_MAX_PATH, "sound/%s", g_soundsList[i][j]);
				AddFileToDownloadsTable(downloadFile);
				
				strcopy(LoadList[j], PLATFORM_MAX_PATH, g_soundsList[i][j]);
				
				if(GetConVarBool(hDeveloper))
					PrintToServer(downloadFile);
			}
		}
	}
}

// Initializations to be done at the beginning of the round
public EventRoundStart(Handle:event, const String:name[], bool:dontBroadcast)
{
	for(new i = 0; i <= MAXPLAYERS; i++)
	{
		g_cheerCount[i] = 0;
		g_jeerCount[i] = 0;
	}
}