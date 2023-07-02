#pragma semicolon 1

#include <sourcemod>
#include <morecolors>
#include <sdktools>
#include <sdkhooks>
#include <cstrike>

//
#include <cee/cee>

public Plugin:myinfo =
{
	name = "Surf Battle",
	author = "Cee",
	description = "以1.6的安乐岁月滑坡对战服务器玩法为基础, 移植到起源服务器.",
	version = "2.3",
	url = "http://www.srgaming.net"
};

ArrayList hWeaponList;

new iPlayerMoney[MAXPLAYERS+1] = {0, ...};
new bool:bRemoveWeapon[MAXPLAYERS+1] = {false, ...};

public OnPluginStart()
{
	HookEvent("round_end", Event_OnRoundEnd);
	HookEvent("round_start", Event_OnRoundStart);
	HookEvent("player_spawn", Event_OnPlayerSpawn);
	HookEvent("round_freeze_end", Event_OnRoundFreezeEnd);
	
	//移除进服的选队菜单
	HookUserMessage(GetUserMessageId("VGUIMenu"), UserMessageHook_VGUIMenu, true);

	//队伍切换
	RegConsoleCmd("jointeam", Command_ChooseTeam);
	
	//服务器参数
	SetConVarInt(FindConVar("mp_ignore_round_win_conditions"), 1);
	ServerCommand("mp_restartgame 1");
	
	//
	for(new i = 1; i < MaxClients; i ++)
	{
		if(IsClientInGame(i))
			OnClientPutInServer(i);
	}
}

public OnPluginEnd()
{
	SetConVarInt(FindConVar("mp_ignore_round_win_conditions"), 0);
	ServerCommand("mp_restartgame 1");
}

public OnMapStart()
{
	ArrayList hCreateList = CreateArray();
	for(int i = 1; i < GetEntityCount(); i ++)
	{
		if(!IsValidEntity(i))
			continue;
			
		new entity = i;
		
		decl String:sClassname[128];
		GetEntityClassname(entity, sClassname, sizeof(sClassname));
		
		if(hWeaponList.FindValue(entity))
			continue;
		
		PrintToServer("i: %d || %s", i, sClassname);
		
		PrintToServer("this is weapon\n");
		
		decl Float:vec[3];
		GetEntPropVector(entity, Prop_Send, "m_vecOrigin", vec);
		
		decl Float:ang[3];
		GetEntPropVector(entity, Prop_Data, "m_angAbsRotation", ang);
		
		//
//		KillEntity(entity);
		//Weapon name
		decl String:weapons[][] = {
				"weapon_mp5navy",
				"weapon_ump45",
				"weapon_m3",
				"weapon_xm1014",
				"weapon_mac10",
				"weapon_tmp"
			};
		
		decl String:sWeapon[128];
		Format(sWeapon, sizeof(sWeapon), "weapon_%s", weapons[GetRandomInt(0, sizeof(weapons)-1)]);
		
		new weapon = CreateEntityByName(sWeapon);
		SetEntityMoveType(weapon, MOVETYPE_NONE);
		DispatchSpawn(weapon);
		
		hCreateList.Push(weapon);
	}
}

public OnClientPutInServer(client)
{
	SDKHook(client, SDKHook_WeaponDrop, SDKHooks_OnWeaponDrop);
	SDKHook(client, SDKHook_WeaponCanUse, SDKHooks_OnWeaponEquip);
}

//进入服务器时触发
public OnClientPostAdminCheck(client)
{
	CreateTimer(0.1, Timer_AutoJointeam, client);
}

//自动选择队伍
public Action:Command_ChooseTeam(client, args)
{
//	CreateTimer(0.1, TimerMoveTeam, client);
	return Plugin_Handled;
}

public Action:SDKHooks_OnWeaponDrop(client, weapon)
{
	KillEntity(weapon);
	return Plugin_Continue;
}

public Action:SDKHooks_OnWeaponEquip(client, weapon)
{
//	decl Float:vec[3];
//	GetEntPropVector(entity, Prop_Send, "m_vecOrigin", vec);
	
	if(bRemoveWeapon[client])
		KillEntity(weapon);
		
	decl String:sWeaponName[256];
	GetEntityClassname(weapon, sWeaponName, sizeof(sWeaponName));
	
	GivePlayerItem(client, sWeaponName);
	
	bRemoveWeapon[client] = false;
	return Plugin_Continue;
}

//回合开始
public Action:Event_OnRoundStart(Handle:event, const String:name[], bool:dontBroadcast)
{
	//SetBack Cash
	for(new i = 1; i <= MaxClients; i++)
	{
		if(IsClientInGame(i))
			SetClientMoney(i, iPlayerMoney[i] == 0 ? GetConVarInt(FindConVar("mp_startmoney")) : iPlayerMoney[i]);
	}
}

public Action:Event_OnRoundFreezeEnd(Event event, const String:name[], bool:dontBroadcast)
{
	
}

public Action:Event_OnRoundEnd(Handle:event, const String:name[], bool:dontBroadcast)
{	
	for(new i = 1; i <= MaxClients; i++)
	{
		if(IsClientInGame(i))
			iPlayerMoney[i] = GetClientMoney(i);
	}
}

//回合开始重置玩家武器
public Action:Event_OnPlayerSpawn(Handle:event, const String:name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
 	
 	if(IsPlayerAlive(client) && GetClientTeam(client) >= 2)
 		bRemoveWeapon[client] = true;
 		
	return Plugin_Handled;
}

//玩家进入游戏时自动加入队伍
public Action:Timer_AutoJointeam(Handle:timer, any:client)
{
	if(client > 0 && IsClientInGame(client) && !IsFakeClient(client))
	{
		ChangeClientTeam(client, GetTeamClientCount(CS_TEAM_CT) <= GetTeamClientCount(CS_TEAM_T) ? CS_TEAM_CT : CS_TEAM_T);
		CS_RespawnPlayer(client);
	}
}

public Action:UserMessageHook_VGUIMenu(UserMsg:msg_id, Handle:bf, const players[], playersNum, bool:reliable, bool:init)
{
	decl String:type[32];
	BfReadString(bf, type, sizeof(type));
	
	if(strncmp(type, "team", 8) == 0 || strncmp(type, "class_ct", 8) == 0 || strncmp(type, "class_ter", 8) == 0)
		return Plugin_Handled;
	return Plugin_Continue;
}

public OnConVarChanged(Handle:convar, const String:oldValue[], const String:newValue[])
{
}