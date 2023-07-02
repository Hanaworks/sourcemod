#pragma semicolon 1

#include <sourcemod>
#include <cstrike>
#include <smlib>
#include <morecolors>

#define PLUGIN_VERSION "1.0"

public Plugin:myinfo = 
{
	name = "Afk Tool",
	author = "Cee",
	description = "some for afk server function tool",
	version = PLUGIN_VERSION,
	url = "http://www.srgaming.net"
};

new Handle:hRemoveTeam = INVALID_HANDLE;
new Handle:hFreezeTeam = INVALID_HANDLE;
new Handle:hAutoRespawn = INVALID_HANDLE;
new Handle:hBuyTeam = INVALID_HANDLE;

public OnPluginStart()
{
	//
	hRemoveTeam = CreateConVar("sm_afktool_removeteam", "0", "0 = Disable, 1 = All Team, 2 = T, 3 = CT", _, true, 0.0, true, 3.0);
	hFreezeTeam = CreateConVar("sm_afktool_freezeteam", "0", "0 = Disable, 1 = All Team, 2 = T, 3 = CT", _, true, 0.0, true, 3.0);
	hAutoRespawn = CreateConVar("sm_afktool_autorespawn", "1", "0 = Disable, 1 = Enable", _, true, 0.0, true, 3.0);
	hBuyTeam = CreateConVar("sm_afktool_buyteam", "2", "0 = Disable, 1 = All Team, 2 = T, 3 = CT",  _, true, 0.0, true, 3.0);
	
	RegConsoleCmd("sm_ct", JoinCt);
	RegConsoleCmd("sm_t", JoinT);
	RegConsoleCmd("sm_fz", Command_Freeze);
//	RegConsoleCmd("buy", Command_Buy);
	
//	HookEvent("round_start", On_Player_Spawn);
	HookEvent("player_spawn", On_Player_Spawn);			//CSS
//	HookEvent("player_spawned", On_Player_Spawn);			//CSGO
	HookEvent("player_death", On_Player_Death);
}

public Action:Command_Freeze(client, args)
{
	FreezeClient(client);
}

public Action:On_Player_Spawn(Handle:event, const String:name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	
	if(IsPlayerAlive(client))
	{
		//ReMove Weapon
		new Int = GetConVarInt(hRemoveTeam);
		
		if(Int == 1 && GetClientTeam(client) >= 2)
		{
			Client_RemoveAllWeapons(client);
		}
		else if(Int > 1 && GetClientTeam(client) == Int)
		{
			Client_RemoveAllWeapons(client);
		}
	
		//Freeze Player
		Int = GetConVarInt(hFreezeTeam);
		
		if(Int == 1 && GetClientTeam(client) >= 2)
		{
			CreateTimer(0.1, FreezeTimer, client);
		}
		else if(Int > 1 && GetClientTeam(client) == Int)
			CreateTimer(0.1, FreezeTimer, client);
	}
	
	return Plugin_Continue;
}

public Action:On_Player_Death(Handle:event, const String:name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
		
	if(!IsPlayerAlive(client) && GetConVarInt(hAutoRespawn) == 1)
		CreateTimer(0.1, Respawn, client);
	
	return Plugin_Continue;
}

public Action:Respawn(Handle:timer, any:client)
{
	if(IsClientInGame(client) && GetConVarInt(hAutoRespawn) == 1)
		CS_RespawnPlayer(client);	
}

public Action:CS_OnBuyCommand(client, const String:weapon[])
{
	new Int = GetConVarInt(hBuyTeam);
	
	if(Int == 1)
		return Plugin_Handled;
	else if(GetClientTeam(client) > 1 && GetClientTeam(client) != Int)
		return Plugin_Handled;
		
	return Plugin_Continue;
}

public Action:JoinCt(client, args)
{
	if(client > 0 && IsClientInGame(client))
	{
		ChangeClientTeam(client, CS_TEAM_CT);
		CS_RespawnPlayer(client);	
	}
}

public Action:JoinT(client, args)
{
	if(client > 0 && IsClientInGame(client))
	{
		ChangeClientTeam(client, CS_TEAM_T);
		CS_RespawnPlayer(client);	
	}
}

public Action:FreezeTimer(Handle:timer, any:client)
{
	if(client > 0 && IsClientInGame(client) && IsPlayerAlive(client))
		FreezeClient(client);
}


public Action:FreezeClient(client)
{
	SetEntityMoveType(client, MOVETYPE_NONE);
	SetEntityRenderColor(client, 0, 128, 255, 192);
}

public OnClientPostAdminCheck(client)
{
	CreateTimer(0.1, TimerMoveTeam, client);
}

public Action:TimerMoveTeam(Handle:timer, any:client)
{
	if(client > 0 && IsClientInGame(client))
	{
		ChangeClientTeam(client, GetTeamClientCount(CS_TEAM_CT) <= GetTeamClientCount(CS_TEAM_T) ? CS_TEAM_CT : CS_TEAM_T);
		CS_RespawnPlayer(client);
	}
}