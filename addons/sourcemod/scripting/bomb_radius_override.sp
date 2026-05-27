#include <sourcemod>
#include <entitylump>

#pragma semicolon 1
#pragma newdecls required

public Plugin myinfo =
{
    name = "Bomb Radius Override",
    author = "Qwepplz",
    description = "Overrides selected map C4 bomb radius before map entities spawn.",
    version = "1.0.0"
};

static const char BOMB_RADIUS_VALUE[] = "500";

public void OnMapInit(const char[] mapName)
{
    if (!ShouldOverrideBombRadius(mapName))
    {
        return;
    }

    OverrideBombRadius(BOMB_RADIUS_VALUE);
}

static bool ShouldOverrideBombRadius(const char[] mapName)
{
    return StrEqual(mapName, "de_inferno", false) || StrEqual(mapName, "de_ancient", false);
}
static void OverrideBombRadius(const char[] value)
{
    for (int i = 0; i < EntityLump.Length(); i++)
    {
        EntityLumpEntry entry = EntityLump.Get(i);

        char className[64];
        entry.GetNextKey("classname", className, sizeof(className));

        if (StrEqual(className, "info_map_parameters", false))
        {
            SetEntryBombRadius(entry, value);
            delete entry;
            return;
        }

        delete entry;
    }

    int entityIndex = EntityLump.Append();
    EntityLumpEntry entry = EntityLump.Get(entityIndex);
    entry.Append("classname", "info_map_parameters");
    entry.Append("bombradius", value);
    delete entry;
}

static void SetEntryBombRadius(EntityLumpEntry entry, const char[] value)
{
    int radiusIndex = entry.FindKey("bombradius");

    if (radiusIndex == -1)
    {
        entry.Append("bombradius", value);
        return;
    }

    entry.Update(radiusIndex, NULL_STRING, value);
}
