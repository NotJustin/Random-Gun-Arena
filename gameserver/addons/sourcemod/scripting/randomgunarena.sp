#include <sourcemod>
#include <sdktools>
#include <sdktools_sound>
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

ArrayList g_iWeapon;
ArrayList g_iWeaponSoundPath;
ArrayList g_iWeaponWeight;
ArrayList g_iWeaponGroupIndex;
ArrayList g_iGroup;

float g_AccumulatedWeight = 0.0;

char g_nextWeapon[32];
int g_nextWeaponIndex;

bool allowDrop = true;

public void OnPluginStart()
{
	g_iWeapon = new ArrayList(32);
	g_iWeaponWeight = new ArrayList();
	g_iWeaponSoundPath = new ArrayList(PLATFORM_MAX_PATH);
	g_iWeaponGroupIndex = new ArrayList();
	g_iGroup = new ArrayList(32);

	HookEvent("player_spawn", Event_PlayerSpawn, EventHookMode_Post);
	HookEvent("round_end", Event_RoundEnd);
	HookEvent("round_start", Event_RoundStart);
	HookEvent("player_death", Event_PlayerDeath, EventHookMode_Post);
	AddCommandListener(CommandList_Drop, "drop");
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

public Action Event_RoundStart(Event event, const char[] name, bool dontBroadcast) 
{
	char nextSound[PLATFORM_MAX_PATH];
	g_iWeaponSoundPath.GetString(g_nextWeaponIndex, nextSound, sizeof(nextSound));
	EmitSoundToAll(nextSound);
	allowDrop = false;
	CreateTimer(2.0, SetAllowDropToTrue);
}

public Action SetAllowDropToTrue(Handle timer)
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

public Action Event_PlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
	int client =  GetClientOfUserId(GetEventInt(event, "attacker"));
	if (IsClientValid(client))
	{
		if(strcmp(g_nextWeapon, "weapon_usp_silencer", 	false) 	== 0 
		|| strcmp(g_nextWeapon, "weapon_hkp2000", 		false) 	== 0 
		|| strcmp(g_nextWeapon, "weapon_glock", 		false) 	== 0)
		{
			SetEntProp(client, Prop_Send, "m_bHasHelmet", 0);
		}
		else
		{
			SetEntProp(client, Prop_Send, "m_bHasHelmet", 1);
		}
		SetEntProp(client, Prop_Data, "m_ArmorValue", 100, 1);
		SetEntityHealth(client, 100);
	}
}

public void BrowseWeapon(KeyValues weapons, char [] sectionName, float groupWeight, int groupIndex)
{
	g_iWeaponGroupIndex.Push(groupIndex);

	char weaponId[32];
	weapons.GetString("id", weaponId, sizeof(weaponId));
	g_iWeapon.PushString(weaponId);

	char soundPath[PLATFORM_MAX_PATH];
	char bufferString[PLATFORM_MAX_PATH];
	weapons.GetString("sound", soundPath, sizeof(soundPath), "rga/ak47.mp3");
	if (strcmp(soundPath, "") != 0)
	{
		Format(bufferString, sizeof(bufferString), "sound/%s", soundPath);
		AddFileToDownloadsTable(bufferString);
		Format(soundPath, sizeof(soundPath), "%s", soundPath);
		AddToStringTable(FindStringTable("soundprecache"), soundPath);
		g_iWeaponSoundPath.PushString(soundPath);
	}

	g_AccumulatedWeight += groupWeight * weapons.GetFloat("weight");
	g_iWeaponWeight.Push(g_AccumulatedWeight);
}

public void BrowseGroup(KeyValues weapons, char [] sectionName, float groupWeight, int groupIndex)
{
	weapons.GotoFirstSubKey();
	do
	{
		BrowseWeapon(weapons, sectionName, groupWeight, groupIndex);
	}
	while(weapons.GotoNextKey());
	weapons.GoBack();
}

public void BrowseWeapons(KeyValues weapons)
{
	do
	{
		char sectionName[32];
		weapons.GetSectionName(sectionName, sizeof(sectionName));
		int groupIndex = g_iGroup.PushString(sectionName);
		float groupWeight = weapons.GetFloat("weight");
		BrowseGroup(weapons, sectionName, groupWeight, groupIndex);
	}
	while(weapons.GotoNextKey());
}



public Action Event_RoundEnd(Event event, const char[] name, bool dontBroadcast)
{
	PickRandomWeapon();
}

public Action Event_PlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
	int userId = GetEventInt(event, "userid");
	RequestFrame(RemoveAllWeapons, userId);
	CreateTimer(0.1, GiveWeaponToClient, userId);
}

public Action GiveWeaponToClient(Handle timer, int userId)
{
	int client = GetClientOfUserId(userId);
	if (IsClientValid(client))
	{
		SetEntProp(client, Prop_Data, "m_ArmorValue", 100, 1);

		char group[32];
		g_iGroup.GetString(g_iWeaponGroupIndex.Get(g_nextWeaponIndex), group, sizeof(group));

		if(	strcmp(g_nextWeapon, "weapon_hkp2000", 		false) == 0
		||	strcmp(g_nextWeapon, "weapon_usp_silencer", false) == 0 
		|| 	strcmp(g_nextWeapon, "weapon_glock", 		false) == 0)
		{
			SetEntProp(client, Prop_Send, "m_bHasHelmet", 0);
		}
		else
		{
			SetEntProp(client, Prop_Send, "m_bHasHelmet", 1);
		}

		if(strcmp(group, "Melee", false) != 0)
		{
			GivePlayerItem(client, "weapon_knife");
			if(strcmp(g_nextWeapon, "weapon_hkp2000", false) == 0)
			{
				GivePlayerItem2(client, g_nextWeapon);
			}
			else
			{
				GivePlayerItem(client, g_nextWeapon);
			}
		}
		else
		{
			int item = GivePlayerItem(client, g_nextWeapon);
			if (strcmp(g_nextWeapon, "weapon_fists", false) == 0)
			{
				EquipPlayerWeapon(client, item);
			}
		}
	}
}

public void RemoveAllWeapons(int userId)
{
	int client = GetClientOfUserId(userId);
	if (IsClientValid(client))
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

public void PickRandomWeapon()
{
	int i = 0;
	float weight = GetRandomFloat(0.0, g_AccumulatedWeight);
	char group[32];
	while (i < g_iWeaponWeight.Length)
	{
		if (g_iWeaponWeight.Get(i) >= weight)
		{
			g_nextWeapon[0] = '\0';
			group[0] = '\0';
			g_iWeapon.GetString(i, g_nextWeapon, sizeof(g_nextWeapon));
			PrintToChatAll("Next weapon: %s", g_nextWeapon);
			g_nextWeaponIndex = i;
			break;
		}
		++i;
	}
}

stock bool IsClientValid(int client)
{
    return (client >= 1 && client <= MaxClients && IsClientInGame(client) && !IsFakeClient(client));
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