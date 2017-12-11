#include <sourcemod>
#include <sdktools>
#include <cstrike>
#include <retakes>

#pragma newdecls required
#pragma semicolon 1

Bombsite g_iBombsite;

bool gb_bombDel;

ConVar gc_freezeTime;

float gf_bombPosition[3];

Handle gh_bombPlantTimer;

int m_bBombTicking;

public Plugin myinfo =
{
    name = "[Retakes] Bomb Autoplant",
    author = "Techno",
    description = "Autoplant the bomb on round start.",
    version = "1.4.0",
    url = "https://tech-no.me"
};

public void OnPluginStart()
{
    gc_freezeTime = FindConVar("mp_freezetime");

    m_bBombTicking = FindSendPropInfo("CPlantedC4", "m_bBombTicking");

    HookEvent("round_start", OnRoundStart, EventHookMode_PostNoCopy);
    HookEvent("round_end", OnRoundEnd, EventHookMode_PostNoCopy);
}

public void OnRoundStart(Event event, const char[] name, bool dontBroadcast)
{
    gb_bombDel = false;

    for (int client = 1; client <= MaxClients; client++)
    {
        if (IsClientInGame(client) && IsPlayerAlive(client) && GetPlayerWeaponSlot(client, 4) > 0)
        {
            int iBomb = GetPlayerWeaponSlot(client, 4);

            gb_bombDel = SafeRemoveWeapon(client, iBomb);

            GetClientAbsOrigin(client, gf_bombPosition);

            delete gh_bombPlantTimer;

            gh_bombPlantTimer = CreateTimer(gc_freezeTime.FloatValue, PlantBomb, client);
        }
    }
}

public void OnRoundEnd(Event event, const char[] name, bool dontBroadcast)
{
    delete gh_bombPlantTimer;

    GameRules_SetProp("m_bBombPlanted", 0);
}

public Action PlantBomb(Handle timer, int client)
{
    gh_bombPlantTimer = INVALID_HANDLE;

    if (IsClientInGame(client))
    {
        if (gb_bombDel)
        {
            int Bomb_Ent = CreateEntityByName("planted_c4");

            GameRules_SetProp("m_bBombPlanted", 1);
            SetEntData(Bomb_Ent, m_bBombTicking, 1, 1, true);

            SendBombPlanted(client);

            if (DispatchSpawn(Bomb_Ent))
            {
                ActivateEntity(Bomb_Ent);
                TeleportEntity(Bomb_Ent, gf_bombPosition, NULL_VECTOR, NULL_VECTOR);
            }
        }
    }
    else
    {
        CS_TerminateRound(1.0, CSRoundEnd_Draw);
    }
}

public void SendBombPlanted(int client)
{
    Event event = CreateEvent("bomb_planted");

    if (event == null)
    {
        return;
    }

    event.SetInt("userid", GetClientUserId(client));
    event.SetInt("site", view_as<int>(g_iBombsite));
    event.Fire();
}

public void Retakes_OnSitePicked(Bombsite& site)
{
    g_iBombsite = site;
}

stock bool SafeRemoveWeapon(int client, int weapon)
{
    if (!IsValidEntity(weapon) || !IsValidEdict(weapon))
    {
        return false;
    }

    if (!HasEntProp(weapon, Prop_Send, "m_hOwnerEntity"))
    {
        return false;
    }

    int iOwnerEntity = GetEntPropEnt(weapon, Prop_Send, "m_hOwnerEntity");

    if (iOwnerEntity != client)
    {
        SetEntPropEnt(weapon, Prop_Send, "m_hOwnerEntity", client);
    }

    CS_DropWeapon(client, weapon, false);

    if (HasEntProp(weapon, Prop_Send, "m_hWeaponWorldModel"))
    {
        int iWorldModel = GetEntPropEnt(weapon, Prop_Send, "m_hWeaponWorldModel");

        if (IsValidEdict(iWorldModel) && IsValidEntity(iWorldModel))
        {
            if (!AcceptEntityInput(iWorldModel, "Kill"))
            {
                return false;
            }
        }
    }

    if (!AcceptEntityInput(weapon, "Kill"))
    {
        return false;
    }

    return true;
}
