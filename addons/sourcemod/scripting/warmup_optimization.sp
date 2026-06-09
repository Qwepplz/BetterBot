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
static const char WARMUP_TELEPORT_SCRIPT[] = "warmup/warmup_teleport.nut";

public void OnPluginStart()
{
    HookEvent("player_death", Event_PlayerDeath);
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
}

static bool IsWarmupPeriod()
{
    return GameRules_GetProp("m_bWarmupPeriod") != 0;
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
