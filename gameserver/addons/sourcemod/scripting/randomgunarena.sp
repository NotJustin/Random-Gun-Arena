#include <sourcemod>
#include <sdktools>
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

Weapon g_Weapon;
ArrayList g_Weapons;
int g_WeaponCount = 0;
ArrayList g_Available;
ArrayList g_Used;

float g_AccumulatedWeight = 0.0;

float g_iClientDamageDealt[MAXPLAYERS + 1];
float g_iClientDamageTaken[MAXPLAYERS + 1];
float g_iClientDamageHealed[MAXPLAYERS + 1];

bool allowDrop = true;

ConVar cvar_RoundRestartDelay;

public void OnPluginStart()
{
	g_Weapons = new ArrayList(sizeof(Weapon));
	g_Available = new ArrayList();
	g_Used = new ArrayList();

	HookEvent("player_spawn", Event_PlayerSpawn, EventHookMode_Post);
	HookEvent("round_end", Event_RoundEnd);
	HookEvent("round_start", Event_RoundStart);
	HookEvent("player_death", Event_PlayerDeath, EventHookMode_Post);

	cvar_RoundRestartDelay = FindConVar("mp_round_restart_delay");

	AddCommandListener(CommandList_Drop, "drop");
}

public void OnClientPostAdminCheck(int client)
{
	SDKHook(client, SDKHook_OnTakeDamage, Event_TakeDamage);
}

Action Event_TakeDamage(int victim, int &attacker, int &inflictor, float &damage, int &damagetype)
{
	if (attacker > 0 && attacker < MaxClients && IsClientInGame(attacker) && !IsFakeClient(attacker))
	{
		g_iClientDamageDealt[attacker] += damage;
	}
	g_iClientDamageTaken[victim] += damage;
	return Plugin_Continue;
}

public void OnMapStart()
{
	KeyValues weapons = new KeyValues("Weapons");
	char sPath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, sPath, sizeof(sPath), "configs/rga/weapons.txt");
	weapons.ImportFromFile(sPath);
	weapons.GotoFirstSubKey();
	BrowseWeapons(weapons);
	PickRandomWeapon();
	delete weapons;
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
	if (client != 0 && IsClientInGame(client) && !IsFakeClient(client))
	{
		PrintToChat(client, "Damage dealt: %f", g_iClientDamageDealt[client]);
		PrintToChat(client, "Damage taken: %f", g_iClientDamageTaken[client]);
		PrintToChat(client, "Damage healed: %f", g_iClientDamageHealed[client]);
	}
	if (attacker && IsClientInGame(attacker))
	{
		if (g_Weapon.armor == 0)
		{
			SetEntProp(attacker, Prop_Data, "m_ArmorValue", 0, 1);
			SetEntProp(attacker, Prop_Data, "m_ArmorValue", 0, 0);
			SetEntProp(attacker, Prop_Send, "m_bHasHelmet", 0);
		}
		else if (g_Weapon.armor == 1)
		{
			SetEntProp(attacker, Prop_Data, "m_ArmorValue", 100, 1);
			SetEntProp(attacker, Prop_Send, "m_bHasHelmet", 0);
		}
		else if (g_Weapon.armor == 2)
		{
			SetEntProp(attacker, Prop_Data, "m_ArmorValue", 100, 1);
			SetEntProp(attacker, Prop_Send, "m_bHasHelmet", 1);
		}
		int health = GetEntProp(attacker, Prop_Send, "m_iHealth");
		g_iClientDamageHealed[attacker] += (100.0 - health);
		SetEntityHealth(attacker, 100);
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

	if (strcmp(soundPath, "") != 0)
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
		weapons.GetSectionName(group, sizeof(group));
		float weightOverride = weapons.GetFloat("weight_override");
		int armorOverride = weapons.GetNum("armor_override");
		BrowseGroup(weapons, group, weightOverride, armorOverride);
	}
	while(weapons.GotoNextKey());
}

Action Event_RoundEnd(Event event, const char[] name, bool dontBroadcast)
{
	PickRandomWeapon();
	for (int client = 1; client < MaxClients; client++)
	{
		if (IsClientInGame(client) && !IsFakeClient(client) && IsPlayerAlive(client))
		{
			PrintToChat(client, "Damage dealt: %f", g_iClientDamageDealt[client]);
			PrintToChat(client, "Damage taken: %f", g_iClientDamageTaken[client]);
			PrintToChat(client, "Damage healed: %f", g_iClientDamageHealed[client]);
		}
	}
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
	int userId = GetEventInt(event, "userid");
	RequestFrame(RemoveAllWeapons, userId);
	CreateTimer(0.1, GiveWeaponToClient, userId);
}

Action GiveWeaponToClient(Handle timer, int userId)
{
	int client = GetClientOfUserId(userId);
	if (client && IsClientInGame(client))
	{
		if (strcmp(g_Weapon.id, "weapon_fists", false) == 0)
		{
			int item = GivePlayerItem(client, g_Weapon.id);
			if (strcmp(g_Weapon.id, "weapon_fists", false) == 0)
			{
				EquipPlayerWeapon(client, item);
				return;
			}
		}
		else if (strcmp(g_Weapon.id, "weapon_hkp2000", false) == 0)
		{
			GivePlayerItem2(client, g_Weapon.id);
			GivePlayerItem(client, "weapon_knife");
		}
		else
		{
			GivePlayerItem(client, g_Weapon.id);
			GivePlayerItem(client, "weapon_knife");
		}
	}
	if (g_Weapon.armor == 0)
	{
		SetEntProp(client, Prop_Data, "m_ArmorValue", 0, 1);
		SetEntProp(client, Prop_Data, "m_ArmorValue", 0, 0);
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

void RemoveAllWeapons(int userId)
{
	int client = GetClientOfUserId(userId);
	if (client && IsClientInGame(client))
	{
		int array_size = GetEntPropArraySize(client, Prop_Send, "m_hMyWeapons");
		int entity;
		char weaponName[32];
		for(int i = 0; i < array_size; i++)
		{
			entity = GetEntPropEnt(client, Prop_Send, "m_hMyWeapons", i);
			if(entity != -1 && GetEntSendPropOffs(entity, "m_bStartedArming") == -1)
			{
				GetEdictClassname(entity, weaponName, sizeof(weaponName));
				CS_DropWeapon(client, entity, false, true);
				AcceptEntityInput(entity, "Kill");
			}
		}
	}
}

void PickRandomWeapon()
{
	if (g_Available.Length == 0)
	{
		delete g_Available;
		g_Available = g_Used.Clone();
		g_Used.Clear();
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
			EmitSoundToAll(weapon.soundPath);
			break;
		}
	}
	ShowNextWeaponToAll();
}

void ShowNextWeaponToAll()
{
	SetHudTextParams(-1.0, 0.30, cvar_RoundRestartDelay.FloatValue, 255, 255, 0, 255, 1, 0.0, 0.0, 0.0);
	for (int i = 1; i < MaxClients; i++)
	{
		if (IsClientInGame(i) && !IsFakeClient(i))
		{
			ShowHudText(i, -1, "Next Weapon: %s", g_Weapon.name);
		}
	}
}

stock void GivePlayerItem2(int iClient, const char[] chItem)
{
    int iTeam = GetClientTeam(iClient);
    if (iTeam == 3)
    {
    	SetEntProp(iClient, Prop_Send, "m_iTeamNum", 2);
    }
    GivePlayerItem(iClient, chItem);
    SetEntProp(iClient, Prop_Send, "m_iTeamNum", iTeam);
} 