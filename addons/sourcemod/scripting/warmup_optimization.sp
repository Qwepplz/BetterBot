#include <sourcemod>
#include <sdktools>
#include <entitylump>

#pragma semicolon 1
#pragma newdecls required

public Plugin myinfo =
{
    name = "Warmup Optimization",
    author = "Qwepplz",
    description = "Optimizes CS:GO warmup by keeping players on the match map and restoring warmup money.",
    version = "1.0.0"
};

static const int WARMUP_MONEY = 16000;
static const int WARMUP_RESERVE_AMMO = 999;
static const int WEAPON_SLOT_PRIMARY = 0;
static const int WEAPON_SLOT_SECONDARY = 1;
static const float WARMUP_AMMO_REFRESH_INTERVAL = 0.5;
static const char WARMUP_TELEPORT_SCRIPT[] = "warmup/warmup_teleport.nut";

public void OnPluginStart()
{
    HookEvent("player_death", Event_PlayerDeath);
    CreateTimer(WARMUP_AMMO_REFRESH_INTERVAL, Timer_RefreshWarmupAmmo, 0, TIMER_REPEAT);
}

public void OnMapInit(const char[] mapName)
{
    for (int i = EntityLump.Length() - 1; i >= 0; i--)
    {
        EntityLumpEntry entry = EntityLump.Get(i);
        bool removeEntry = IsWarmupTeleportTrigger(entry);
        delete entry;

        if (removeEntry)
        {
            EntityLump.Erase(i);
        }
    }
}

public void Event_PlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
    if (!IsWarmupPeriod())
    {
        return;
    }

    int client = GetClientOfUserId(event.GetInt("userid"));
    if (client < 1 || client > MaxClients || !IsClientInGame(client))
    {
        return;
    }

    SetEntProp(client, Prop_Send, "m_iAccount", WARMUP_MONEY);
    ResetClientWarmupAmmoCounts(client);
}

public Action Timer_RefreshWarmupAmmo(Handle timer)
{
    if (!IsWarmupPeriod())
    {
        return Plugin_Continue;
    }

    for (int client = 1; client <= MaxClients; client++)
    {
        if (!IsClientInGame(client) || !IsPlayerAlive(client))
        {
            continue;
        }

        RefreshClientWeaponReserveAmmo(client);
    }

    return Plugin_Continue;
}

static bool IsWarmupPeriod()
{
    return GameRules_GetProp("m_bWarmupPeriod") != 0;
}

static void ResetClientWarmupAmmoCounts(int client)
{
    if (HasEntProp(client, Prop_Send, "m_iAmmo"))
    {
        ResetClientWarmupAmmoCountsByProp(client, Prop_Send);
        return;
    }

    if (HasEntProp(client, Prop_Data, "m_iAmmo"))
    {
        ResetClientWarmupAmmoCountsByProp(client, Prop_Data);
    }
}

static void ResetClientWarmupAmmoCountsByProp(int client, PropType propType)
{
    int ammoSlots = GetEntPropArraySize(client, propType, "m_iAmmo");

    for (int ammoType = 0; ammoType < ammoSlots; ammoType++)
    {
        SetEntProp(client, propType, "m_iAmmo", 0, 4, ammoType);
    }
}

static void RefreshClientWeaponReserveAmmo(int client)
{
    RefreshWeaponReserveAmmo(client, GetPlayerWeaponSlot(client, WEAPON_SLOT_PRIMARY));
    RefreshWeaponReserveAmmo(client, GetPlayerWeaponSlot(client, WEAPON_SLOT_SECONDARY));
}

static void RefreshWeaponReserveAmmo(int client, int weapon)
{
    if (weapon == -1 || !IsValidEntity(weapon))
    {
        return;
    }

    int ammoType = GetWeaponPrimaryAmmoType(weapon);
    if (ammoType < 0)
    {
        return;
    }

    if (HasEntProp(weapon, Prop_Send, "m_iPrimaryReserveAmmoCount"))
    {
        SetEntProp(weapon, Prop_Send, "m_iPrimaryReserveAmmoCount", WARMUP_RESERVE_AMMO);
    }

    static int ammoOffset = -2;
    if (ammoOffset == -2)
    {
        ammoOffset = FindDataMapInfo(client, "m_iAmmo");
    }

    if (ammoOffset == -1)
    {
        return;
    }

    SetEntData(client, ammoOffset + (ammoType * 4), WARMUP_RESERVE_AMMO, 4, true);
}

static int GetWeaponPrimaryAmmoType(int weapon)
{
    if (HasEntProp(weapon, Prop_Send, "m_iPrimaryAmmoType"))
    {
        return GetEntProp(weapon, Prop_Send, "m_iPrimaryAmmoType");
    }

    if (HasEntProp(weapon, Prop_Data, "m_iPrimaryAmmoType"))
    {
        return GetEntProp(weapon, Prop_Data, "m_iPrimaryAmmoType");
    }

    return -1;
}

static bool IsWarmupTeleportTrigger(EntityLumpEntry entry)
{
    char className[64];
    entry.GetNextKey("classname", className, sizeof(className));

    if (!StrEqual(className, "trigger_multiple", false))
    {
        return false;
    }

    char scripts[256];
    entry.GetNextKey("vscripts", scripts, sizeof(scripts));

    return StrContains(scripts, WARMUP_TELEPORT_SCRIPT, false) != -1;
}
