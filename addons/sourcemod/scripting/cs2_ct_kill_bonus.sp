#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <cstrike>

#define PLUGIN_VERSION "1.0.0"
#define DEFAULT_MAX_MONEY 16000

enum Get5State
{
	Get5State_None,
	Get5State_PreVeto,
	Get5State_Veto,
	Get5State_Warmup,
	Get5State_KnifeRound,
	Get5State_WaitingForKnifeRoundDecision,
	Get5State_GoingLive,
	Get5State_Live,
	Get5State_PendingRestore,
	Get5State_PostGame,
};

native Get5State Get5_GetGameState();

ConVar g_cvEnabled;
ConVar g_cvBonusAmount;
ConVar g_cvMaxMoney;

bool g_bRoundActive;
bool g_bClientChinese[MAXPLAYERS + 1];

public Plugin myinfo =
{
	name = "CS2 CT Kill Bonus",
	author = "BetterBots",
	description = "Adds the CS2 CT team economy bonus when a CT kills a Terrorist",
	version = PLUGIN_VERSION,
	url = ""
};

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int errMax)
{
	MarkNativeAsOptional("Get5_GetGameState");
	return APLRes_Success;
}

public void OnPluginStart()
{
	CreateConVar("sm_cs2_ct_kill_bonus_version", PLUGIN_VERSION, "CS2 CT kill bonus version", FCVAR_NOTIFY | FCVAR_DONTRECORD);
	g_cvEnabled = CreateConVar("sm_cs2_ct_kill_bonus_enabled", "1", "Enable CS2 CT team kill bonus.", _, true, 0.0, true, 1.0);
	g_cvBonusAmount = CreateConVar("sm_cs2_ct_kill_bonus_amount", "50", "Money each CT receives when a CT kills a Terrorist.", _, true, 0.0);
	g_cvMaxMoney = FindConVar("mp_maxmoney");

	HookEvent("round_start", Event_RoundStart, EventHookMode_PostNoCopy);
	HookEvent("round_freeze_end", Event_RoundFreezeEnd, EventHookMode_PostNoCopy);
	HookEvent("round_end", Event_RoundEnd, EventHookMode_PostNoCopy);
	HookEvent("bomb_exploded", Event_BombExploded, EventHookMode_PostNoCopy);
	HookEvent("player_death", Event_PlayerDeath);

	for (int client = 1; client <= MaxClients; client++)
	{
		RefreshClientLanguage(client);
	}
}

public void OnClientPutInServer(int client)
{
	RefreshClientLanguage(client);
}

public void OnClientDisconnect(int client)
{
	g_bClientChinese[client] = false;
}

public void Event_RoundStart(Event event, const char[] name, bool dontBroadcast)
{
	g_bRoundActive = false;
}

public void Event_RoundFreezeEnd(Event event, const char[] name, bool dontBroadcast)
{
	g_bRoundActive = true;
}

public void Event_RoundEnd(Event event, const char[] name, bool dontBroadcast)
{
	g_bRoundActive = false;
}

public void Event_BombExploded(Event event, const char[] name, bool dontBroadcast)
{
	g_bRoundActive = false;
}

public void Event_PlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
	if (!g_cvEnabled.BoolValue || !g_bRoundActive || !IsEconomyLivePhase())
		return;

	int victim = GetClientOfUserId(event.GetInt("userid"));
	int attacker = GetClientOfUserId(event.GetInt("attacker"));

	if (!IsValidClient(victim) || !IsValidClient(attacker) || victim == attacker)
		return;

	if (GetClientTeam(victim) != CS_TEAM_T || GetClientTeam(attacker) != CS_TEAM_CT)
		return;

	RequestFrame(Frame_GiveCTKillBonus);
}

public void Frame_GiveCTKillBonus(any data)
{
	if (!g_cvEnabled.BoolValue || !g_bRoundActive || !IsEconomyLivePhase())
		return;

	int amount = g_cvBonusAmount.IntValue;
	if (amount <= 0)
		return;

	int maxMoney = GetMaxMoney();
	for (int client = 1; client <= MaxClients; client++)
	{
		if (!IsValidClient(client) || GetClientTeam(client) != CS_TEAM_CT)
			continue;

		int money = GetEntProp(client, Prop_Send, "m_iAccount");
		int newMoney = money + amount;
		if (newMoney > maxMoney)
			newMoney = maxMoney;

		SetEntProp(client, Prop_Send, "m_iAccount", newMoney);
		PrintTeamKillBonusMessage(client, amount);
	}
}

void RefreshClientLanguage(int client)
{
	if (!IsValidClient(client) || IsFakeClient(client))
		return;

	g_bClientChinese[client] = false;
	QueryClientConVar(client, "cl_language", OnClientLanguageQueried);
}

public void OnClientLanguageQueried(QueryCookie cookie, int client, ConVarQueryResult result, const char[] cvarName, const char[] cvarValue)
{
	if (!IsValidClient(client) || IsFakeClient(client))
		return;

	g_bClientChinese[client] = result == ConVarQuery_Okay && cvarValue[0] != '\0' && IsChineseLanguageValue(cvarValue);
}

bool IsChineseLanguageValue(const char[] value)
{
	return StrEqual(value, "schinese", false)
		|| StrEqual(value, "tchinese", false)
		|| StrEqual(value, "chi", false)
		|| StrEqual(value, "zho", false)
		|| StrEqual(value, "zh", false)
		|| StrEqual(value, "zh-hans", false)
		|| StrEqual(value, "zh_hans", false)
		|| StrEqual(value, "zh-cn", false)
		|| StrEqual(value, "zh_cn", false)
		|| StrEqual(value, "zh-sg", false)
		|| StrEqual(value, "zh_sg", false)
		|| StrEqual(value, "zh-hant", false)
		|| StrEqual(value, "zh_hant", false)
		|| StrEqual(value, "zh-tw", false)
		|| StrEqual(value, "zh_tw", false)
		|| StrEqual(value, "zh-hk", false)
		|| StrEqual(value, "zh_hk", false)
		|| StrContains(value, "simplified", false) != -1
		|| StrContains(value, "traditional", false) != -1
		|| StrContains(value, "chinese", false) != -1;
}

void PrintTeamKillBonusMessage(int client, int amount)
{
	if (IsFakeClient(client))
		return;

	if (g_bClientChinese[client])
	{
		PrintToChat(client, " \x06+$%d\x01: 消灭一名恐怖分子的团队奖励。", amount);
		return;
	}

	PrintToChat(client, " \x06+$%d\x01: Team award for eliminating a Terrorist.", amount);
}

bool IsEconomyLivePhase()
{
	if (GameRules_GetProp("m_bWarmupPeriod") != 0)
		return false;

	if (GetFeatureStatus(FeatureType_Native, "Get5_GetGameState") != FeatureStatus_Available)
		return true;

	Get5State state = Get5_GetGameState();
	return state == Get5State_None || state == Get5State_Live;
}

int GetMaxMoney()
{
	if (g_cvMaxMoney != null)
		return g_cvMaxMoney.IntValue;

	return DEFAULT_MAX_MONEY;
}

bool IsValidClient(int client)
{
	return client > 0 && client <= MaxClients && IsClientInGame(client);
}
