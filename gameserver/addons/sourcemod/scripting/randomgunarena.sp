#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <cstrike>

#pragma semicolon 1
#pragma newdecls required

public Plugin myinfo = 
{
	name = "randomgunarena", 
	author = "Justin", 
	description = "Everyone has same random gun on spawn", 
	version = "1.0.0",
	url = "https://www.steamcommunity.com/id/namenotjustin"
};

enum struct Weapon
{
	char id[64];
	char name[64];
	char group[64];
	char soundPath[PLATFORM_MAX_PATH];
	float weight;
	float accumulatedWeight;
	int armor;
}

ArrayList
	g_Weapons,
	g_Available,
	g_Used
;

int
	g_WeaponCount = 0,
	g_GroupCount = 0,
	g_RemovedGroupCount = 0
;

Weapon g_Weapon;
bool firstRound = true;
char g_RandomWeaponName[64];

float
	g_AccumulatedWeight = 0.0,
	g_iClientDamageDealt[MAXPLAYERS + 1],
	g_iClientDamageTaken[MAXPLAYERS + 1],
	g_iClientDamageHealed[MAXPLAYERS + 1],
	g_iClientNumPrinted[MAXPLAYERS + 1]
;

bool allowDrop = true;

ConVar 
	cvar_RoundRestartDelay,
	cvar_RemoveType,
	cvar_RemovePreviousWeapons,
	cvar_RemovePreviousGroups,
	cvar_PrintDamageMessages
;

public void OnPluginStart()
{
	g_Weapons = new ArrayList(sizeof(Weapon));
	g_Available = new ArrayList();
	g_Used = new ArrayList();

	HookEvent("player_spawn", Event_PlayerSpawn, EventHookMode_Post);
	HookEvent("round_end", Event_RoundEnd);
	HookEvent("round_start", Event_RoundStart);
	HookEvent("player_death", Event_PlayerDeath, EventHookMode_Post);
	HookEvent("player_hurt", Event_PlayerHurt, EventHookMode_Post);

	cvar_RoundRestartDelay = FindConVar("mp_round_restart_delay");
	cvar_RemoveType = CreateConVar("rga_removetype", "2", "0 = Do not remove any weapons from pool. 1 = sab_removepreviousweapons. 2 = sab_removepreviousgroups. You cannot do both", _, true, 0.0, true, 2.0);
	cvar_RemovePreviousWeapons = CreateConVar("rga_removepreviousweapons", "0", "Max is 36. Number of weapons that must pass before most recent weapon can be repeated. You can write 'all' instead of 36");
	cvar_RemovePreviousGroups = CreateConVar("rga_removepreviousgroups", "1", "Max is 7. Number of groups that must pass before most recent group can be repeated. You can write 'all' instead of 7.");
	cvar_PrintDamageMessages = CreateConVar("rga_printdamagemessages", "1", "When a client dies, or, when survives to end of round, print the damage they dealt, received, and healed to chat");

	AddCommandListener(CommandList_Drop, "drop");

	AutoExecConfig(true, "RandomGunArena");
}

void Event_PlayerHurt(Event event, const char[] name, bool dontBroadcast)
{
	int attacker = GetClientOfUserId(GetEventInt(event, "attacker"));
	int victim = GetClientOfUserId(GetEventInt(event, "userid"));
	int damage = GetEventInt(event, "dmg_health");
	if (attacker && attacker < MaxClients && IsClientInGame(attacker) && !IsFakeClient(attacker))
	{
		g_iClientDamageDealt[attacker] += damage;
	}
	g_iClientDamageTaken[victim] += damage;
}

public void OnMapStart()
{
	firstRound = true;
	KeyValues weapons = new KeyValues("Weapons");
	char sPath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, sPath, sizeof(sPath), "configs/rga/weapons.txt");
	weapons.ImportFromFile(sPath);
	weapons.GotoFirstSubKey();
	BrowseWeapons(weapons);
	PickRandomWeapon();
	delete weapons;
}

public void OnMapEnd()
{
	for (int i = 0; i < g_Used.Length; ++i)
	{
		g_Available.Push(g_Used.Get(i));
	}
	g_Used.Clear();
}

Action Event_RoundStart(Event event, const char[] name, bool dontBroadcast)
{
	ResetDamageOnAllPlayers();
	allowDrop = false;
	CreateTimer(2.0, SetAllowDropToTrue);
}

Action SetAllowDropToTrue(Handle timer)
{
	allowDrop = true;
	return Plugin_Handled;
}

Action CommandList_Drop(int client, const char[] command, int argc)
{
	if (!allowDrop)
	{
		return Plugin_Handled;
	}
	return Plugin_Continue;
}

Action Event_PlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
	int attacker = GetClientOfUserId(GetEventInt(event, "attacker"));
	int client = GetClientOfUserId(GetEventInt(event, "userid"));
	if (cvar_PrintDamageMessages.BoolValue && client && !IsFakeClient(client))
	{
		RequestFrame(Frame_PrintDamageToClient, GetClientUserId(client));
	}
	if (attacker && !IsFakeClient(attacker))
	{
		SetArmor(attacker);
		g_iClientDamageHealed[attacker] += (100.0 - GetEntProp(attacker, Prop_Send, "m_iHealth"));
		SetEntityHealth(attacker, 100);
	}
}

void SetArmor(int client)
{
	if (g_Weapon.armor == 0)
	{
		SetEntProp(client, Prop_Data, "m_ArmorValue", 0, 1);
		SetEntProp(client, Prop_Send, "m_bHasHelmet", 0);
	}
	else if (g_Weapon.armor == 1)
	{
		SetEntProp(client, Prop_Data, "m_ArmorValue", 100, 1);
		SetEntProp(client, Prop_Send, "m_bHasHelmet", 0);
	}
	else if (g_Weapon.armor == 2)
	{
		SetEntProp(client, Prop_Data, "m_ArmorValue", 100, 1);
		SetEntProp(client, Prop_Send, "m_bHasHelmet", 1);
	}
}

void BrowseWeapon(KeyValues weapons, char group[64], float weightOverride, int armorOverride)
{
	char id[64];
	weapons.GetString("id", id, sizeof(id));

	char name[64];
	weapons.GetSectionName(name, sizeof(name));

	char soundPath[PLATFORM_MAX_PATH];
	char bufferString[PLATFORM_MAX_PATH];
	weapons.GetString("sound", soundPath, sizeof(soundPath), "rga/ak47.mp3");

	if (!strcmp(soundPath, "", false))
	{
		Format(bufferString, sizeof(bufferString), "sound/%s", soundPath);
		AddFileToDownloadsTable(bufferString);
		Format(soundPath, sizeof(soundPath), "%s", soundPath);
		AddToStringTable(FindStringTable("soundprecache"), soundPath);
	}

	float weight = weapons.GetFloat("weight");
	if (weightOverride != -1.0)
	{
		weight = weightOverride;
	}

	int armor = weapons.GetNum("armor");
	if (armorOverride != -1)
	{
		armor = armorOverride;
	}

	Weapon weapon;
	weapon.id = id;
	weapon.name = name;
	weapon.group = group;
	weapon.soundPath = soundPath;
	weapon.weight = weight;
	weapon.armor = armor;
	g_Weapons.PushArray(weapon);
	g_Available.Push(g_WeaponCount++);
}

void BrowseGroup(KeyValues weapons, char group[64], float weightOverride, int armorOverride)
{
	weapons.GotoFirstSubKey();
	do
	{
		BrowseWeapon(weapons, group, weightOverride, armorOverride);
	}
	while(weapons.GotoNextKey());
	weapons.GoBack();
}

void BrowseWeapons(KeyValues weapons)
{
	do
	{
		char group[64];
		++g_GroupCount;
		weapons.GetSectionName(group, sizeof(group));
		float weightOverride = weapons.GetFloat("weight_override");
		int armorOverride = weapons.GetNum("armor_override");
		BrowseGroup(weapons, group, weightOverride, armorOverride);
	}
	while(weapons.GotoNextKey());
}

Action Event_RoundEnd(Event event, const char[] name, bool dontBroadcast)
{
	if (!firstRound)
	{
		PickRandomWeapon();
		for (int client = 1; client < MaxClients; client++)
		{
			if (cvar_PrintDamageMessages.BoolValue && IsClientInGame(client) && !IsFakeClient(client) && IsPlayerAlive(client))
			{
				RequestFrame(Frame_PrintDamageToClient, GetClientUserId(client));
			}
		}
	}
	else
	{
		firstRound = false;
	}
}

void Frame_PrintDamageToClient(int userId)
{
	int client = GetClientOfUserId(userId);
	if (!client)
	{
		return;
	}
	PrintToChat(client, "Damage dealt: %f", g_iClientDamageDealt[client]);
	PrintToChat(client, "Damage taken: %f", g_iClientDamageTaken[client]);
	PrintToChat(client, "Damage healed: %f", g_iClientDamageHealed[client]);
}

void ResetDamageOnAllPlayers()
{
	for (int client = 1; client < MaxClients; client++)
	{
		g_iClientDamageHealed[client] = 0.0;
		g_iClientDamageTaken[client] = 0.0;
		g_iClientDamageDealt[client] = 0.0;
	}
}

Action Event_PlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
	if (IsWarmupActive())
	{
		return;
	}
	int userId = GetEventInt(event, "userid");
	RequestFrame(RemoveAllWeapons, userId);
	CreateTimer(0.1, GiveWeaponToClient, userId);
}

Action GiveWeaponToClient(Handle timer, int userId)
{
	int client = GetClientOfUserId(userId);
	int team;
	if (!client || !IsClientInGame(client) || (team = GetClientTeam(client)) == 0 || team == 1)
	{
		return;
	}
	SetArmor(client);
	if (!strcmp(g_Weapon.id, "weapon_fists", false))
	{
		int item = GivePlayerItem(client, g_Weapon.id);
		if (!strcmp(g_Weapon.id, "weapon_fists", false))
		{
			EquipPlayerWeapon(client, item);
		}
	}
	else if (!strcmp(g_Weapon.id, "weapon_hkp2000", false))
	{
		GivePlayerItem2(client, g_Weapon.id);
		GivePlayerItem(client, "weapon_knife");
	}
	else if (!strcmp(g_Weapon.id, "weapon_taser", false))
	{
		GivePlayerItem(client, "weapon_knife");
		GivePlayerItem(client, g_Weapon.id);
	}
	else if (!strcmp(g_Weapon.id, "weapon_knife", false))
	{
		GivePlayerItem(client, "g_Weapon.id");
	}
	else
	{
		GivePlayerItem(client, g_Weapon.id);
		GivePlayerItem(client, "weapon_knife");
	}
}

void RemoveAllWeapons(int userId)
{
	int client = GetClientOfUserId(userId);
	if (client && IsClientInGame(client))
	{
		int array_size = GetEntPropArraySize(client, Prop_Send, "m_hMyWeapons");
		int entity;
		char weaponName[32];
		for(int i = 0; i < array_size; ++i)
		{
			entity = GetEntPropEnt(client, Prop_Send, "m_hMyWeapons", i);
			if(entity != -1 && GetEntSendPropOffs(entity, "m_bStartedArming") == -1)
			{
				GetEdictClassname(entity, weaponName, sizeof(weaponName));
				CS_DropWeapon(client, entity, false, true);
				RemoveEntity(entity);
			}
		}
	}
}

void PickRandomWeapon()
{
	int removeType = cvar_RemoveType.IntValue;
	int removeAmount = 0;
	char stringValue[3];
	bool removeAll = false;
	if (removeType == 1)
	{
		removeAmount = cvar_RemovePreviousWeapons.IntValue;
		cvar_RemovePreviousWeapons.GetString(stringValue, sizeof(stringValue));
		if (!strcmp(stringValue, "all", false))
		{
			removeAll = true;
		}
	}
	else if (removeType == 2)
	{
		removeAmount = cvar_RemovePreviousGroups.IntValue;
		cvar_RemovePreviousGroups.GetString(stringValue, sizeof(stringValue));
		if (!strcmp(stringValue, "all", false))
		{
			removeAll = true;
		}
	}
	if (removeAll || removeAmount >= g_Weapons.Length)
	{
		if (g_Available.Length == 0)
		{
			delete g_Available;
			g_Available = g_Used.Clone();
			g_Used.Clear();
		}
	}
	g_AccumulatedWeight = 0.0;
	for (int i = 0; i < g_Available.Length; ++i)
	{
		int index = g_Available.Get(i);
		Weapon weapon;
		g_Weapons.GetArray(index, weapon, sizeof(weapon));
		g_AccumulatedWeight = g_AccumulatedWeight + weapon.weight;
		weapon.accumulatedWeight = g_AccumulatedWeight;
		g_Weapons.SetArray(index, weapon);
	}
	float weight = GetRandomFloat(0.0, g_AccumulatedWeight);
	for (int i = 0; i < g_Available.Length; ++i)
	{
		int index = g_Available.Get(i);
		Weapon weapon;
		g_Weapons.GetArray(index, weapon, sizeof(weapon));
		if (weapon.accumulatedWeight >= weight)
		{
			g_Weapon = weapon;
			g_Used.Push(index);
			g_Available.Erase(i);
			if (removeType == 1)
			{
				if (!removeAll && removeAmount < g_Weapons.Length && g_Used.Length > removeAmount)
				{
					g_Available.Push(g_Used.Get(0));
					g_Used.Erase(0);
				}
			}
			else if (removeType == 2)
			{
				++g_RemovedGroupCount;
				for (int j = 0; j < g_Available.Length; ++j)
				{
					index = g_Available.Get(j);
					Weapon weaponTwo;
					g_Weapons.GetArray(index, weaponTwo, sizeof(weaponTwo));
					if (!strcmp(weaponTwo.group, weapon.group, false))
					{
						g_Used.Push(index);
						g_Available.Erase(j--);
					}
				}
				if (!removeAll && removeAmount < g_GroupCount && g_RemovedGroupCount > removeAmount)
				{
					char group[64];
					g_Weapons.GetArray(g_Used.Get(0), weapon, sizeof(weapon));
					strcopy(group, sizeof(group), weapon.group);
					g_Available.Push(g_Used.Get(0));
					g_Used.Erase(0);
					for (int j = 0; j < g_Used.Length; ++j)
					{
						index = g_Used.Get(j);
						g_Weapons.GetArray(index, weapon, sizeof(weapon));
						if (!strcmp(weapon.group, group, false))
						{
							g_Available.Push(index);
							g_Used.Erase(j--);
						}
					}
				}
			}
			break;
		}
	}
	EmitSoundToAll(g_Weapon.soundPath);
	ShowNextWeaponToAll();
}

void ShowNextWeaponToAll()
{
	//SetHudTextParams(-1.0, 0.30, cvar_RoundRestartDelay.FloatValue, 255, 255, 0, 255, 1, 0.0, 0.0, 0.0);
	for (int i = 1; i < MaxClients; ++i)
	{
		if (IsClientInGame(i) && !IsFakeClient(i))
		{
			//ShowHudText(i, -1, "Next Weapon: %s", g_Weapon.name);
			CreateTimer(0.1, Timer_ShowWeaponHintToClient, GetClientUserId(i), TIMER_REPEAT);
		}
	}
}

Action Timer_ShowWeaponHintToClient(Handle timer, int userId)
{
	int client = GetClientOfUserId(userId);
	if (client)
	{
		char str[128];
		if (g_iClientNumPrinted[client] >= cvar_RoundRestartDelay.FloatValue * 5)
		{
			g_iClientNumPrinted[client] = 0.0;
			Format(str, sizeof(str), "The next weapon is:\n%s", g_Weapon.name);
			PrintHintText(client, str);
			return Plugin_Stop;
		}
		++g_iClientNumPrinted[client];
		UpdateRandomWeaponName();
		Format(str, sizeof(str), "The next weapon could be...\n%s", g_RandomWeaponName);
		PrintHintText(client, str);
	}
	else
	{
		g_iClientNumPrinted[client] = 0.0;
	}
	return Plugin_Continue;
}

void UpdateRandomWeaponName()
{
	Weapon weapon;
	int index = g_Available.Get(GetRandomInt(0, g_Available.Length - 1));
	g_Weapons.GetArray(index, weapon, sizeof(weapon));
	g_RandomWeaponName = weapon.name;
}

void GivePlayerItem2(int iClient, const char[] chItem)
{
    int iTeam = GetClientTeam(iClient);
    if (iTeam == 3)
    {
    	SetEntProp(iClient, Prop_Send, "m_iTeamNum", 2);
    }
    GivePlayerItem(iClient, chItem);
    SetEntProp(iClient, Prop_Send, "m_iTeamNum", iTeam);
} 

bool IsWarmupActive()
{
	return view_as<bool>(GameRules_GetProp("m_bWarmupPeriod"));
}