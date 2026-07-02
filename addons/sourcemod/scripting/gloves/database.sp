void GetPlayerData(int client)
{
	if (db == null)
	{
		return;
	}

	char steamid[32];
	if (!GetClientAuthId(client, AuthId_Steam2, steamid, sizeof(steamid), true))
	{
		return;
	}

	char query[255];
	FormatEx(query, sizeof(query), "SELECT * FROM %sgloves WHERE steamid = '%s'", g_TablePrefix, steamid);
	db.Query(T_GetPlayerDataCallback, query, GetClientUserId(client));
}

public void T_GetPlayerDataCallback(Database database, DBResultSet results, const char[] error, int userid)
{
	int client = GetClientOfUserId(userid);
	if (!IsValidClient(client))
	{
		return;
	}

	if (results == null)
	{
		LogError("Query failed! %s", error);
		return;
	}

	g_iGroup[client][CS_TEAM_T] = 0;
	g_iGloves[client][CS_TEAM_T] = 0;
	g_fFloatValue[client][CS_TEAM_T] = 0.0;
	g_iGroup[client][CS_TEAM_CT] = 0;
	g_iGloves[client][CS_TEAM_CT] = 0;
	g_fFloatValue[client][CS_TEAM_CT] = 0.0;

	if (results.RowCount == 0)
	{
		char steamid[32];
		if (GetClientAuthId(client, AuthId_Steam2, steamid, sizeof(steamid), true))
		{
			char query[255];
			FormatEx(query, sizeof(query), "INSERT INTO %sgloves (steamid) VALUES ('%s')", g_TablePrefix, steamid);
			db.Query(T_InsertCallback, query);
		}
		return;
	}

	if (results.FetchRow())
	{
		int field;
		static const int teams[] = { CS_TEAM_T, CS_TEAM_CT };
		static const char prefixes[][] = { "t", "ct" };
		for (int i = 0; i < sizeof(teams); i++)
		{
			char fieldName[16];
			FormatEx(fieldName, sizeof(fieldName), "%s_group", prefixes[i]);
			if (results.FieldNameToNum(fieldName, field))
				g_iGroup[client][teams[i]] = results.FetchInt(field);
			FormatEx(fieldName, sizeof(fieldName), "%s_glove", prefixes[i]);
			if (results.FieldNameToNum(fieldName, field))
				g_iGloves[client][teams[i]] = results.FetchInt(field);
			FormatEx(fieldName, sizeof(fieldName), "%s_float", prefixes[i]);
			if (results.FieldNameToNum(fieldName, field))
				g_fFloatValue[client][teams[i]] = results.FetchFloat(field);
		}
	}
}

void UpdatePlayerData(int client, char[] updateFields)
{
	if (db == null)
	{
		return;
	}

	char steamid[32];
	GetClientAuthId(client, AuthId_Steam2, steamid, sizeof(steamid), true);
	char query[255];
	FormatEx(query, sizeof(query), "UPDATE %sgloves SET %s WHERE steamid = '%s'", g_TablePrefix, updateFields, steamid);
	db.Query(T_UpdatePlayerDataCallback, query, client);
}

public void T_UpdatePlayerDataCallback(Database database, DBResultSet results, const char[] error, int client)
{
	if (results == null)
	{
		LogError("Update Player failed! %s", error);
	}
}

public void T_InsertCallback(Database database, DBResultSet results, const char[] error, any data)
{
	if (results == null)
	{
		LogError("Query failed! %s", error);
	}
}

public void SQLConnectCallback(Database database, const char[] error, any data)
{
	if (database == null)
	{
		LogError("Database failure: %s", error);
	}
	else
	{
		db = database;
		char createQuery[1024];
		char dbIdentifier[10];

		Format(createQuery, sizeof(createQuery), "CREATE TABLE IF NOT EXISTS %sgloves (steamid varchar(32) NOT NULL PRIMARY KEY, t_group int(5) NOT NULL DEFAULT '-1', t_glove int(5) NOT NULL DEFAULT '-1', t_float decimal(3,2) NOT NULL DEFAULT '0.0', ct_group int(5) NOT NULL DEFAULT '-1', ct_glove int(5) NOT NULL DEFAULT '-1', ct_float decimal(3,2) NOT NULL DEFAULT '0.0')", g_TablePrefix);

		db.Driver.GetIdentifier(dbIdentifier, sizeof(dbIdentifier));
		bool mysql = StrEqual(dbIdentifier, "mysql");
		if (mysql)
		{
			Format(createQuery, sizeof(createQuery), "%s ENGINE=InnoDB CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;", createQuery);
		}

		db.Query(T_CreateTableCallback, createQuery, mysql, DBPrio_High);
	}
}

public void T_CreateTableCallback(Database database, DBResultSet results, const char[] error, bool mysql)
{
	if (results == null)
	{
		LogError("Create table failed! %s", error);
		return;
	}

	MigrateMainTableColumns();
	MigrateMainTableDefaults(mysql);
}

void AddGloveDefaultMigrationQuery(Transaction txn, const char[] column, int defaultValue)
{
	char query[256];
	FormatEx(query, sizeof(query), "ALTER TABLE %sgloves ALTER COLUMN %s SET DEFAULT '%d'", g_TablePrefix, column, defaultValue);
	txn.AddQuery(query);
}

void MigrateMainTableDefaults(bool mysql)
{
	if (!mysql)
	{
		LoadConnectedClients();
		return;
	}

	char query[512];
	FormatEx(query, sizeof(query),
		"SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = '%sgloves' AND COLUMN_NAME IN ('t_group', 't_glove', 'ct_group', 'ct_glove') AND COLUMN_DEFAULT <> '-1'",
		g_TablePrefix);
	db.Query(T_DefaultMigrationCheckCallback, query, mysql, DBPrio_High);
}

public void T_DefaultMigrationCheckCallback(Database database, DBResultSet results, const char[] error, bool mysql)
{
	if (results == null)
	{
		LogError("Checking glove default values failed! %s", error);
		LoadConnectedClients();
		return;
	}

	if (results.FetchRow() && results.FetchInt(0) == 0)
	{
		LoadConnectedClients();
		return;
	}

	Transaction txn = new Transaction();
	AddGloveDefaultMigrationQuery(txn, "t_group", -1);
	AddGloveDefaultMigrationQuery(txn, "t_glove", -1);
	AddGloveDefaultMigrationQuery(txn, "ct_group", -1);
	AddGloveDefaultMigrationQuery(txn, "ct_glove", -1);
	db.Execute(txn, Txn_DefaultMigrationSuccess, Txn_DefaultMigrationFail);
}

public void Txn_DefaultMigrationSuccess(Database database, any data, int numQueries, DBResultSet[] results, any[] queryData)
{
	LoadConnectedClients();
}

public void Txn_DefaultMigrationFail(Database database, any data, int numQueries, const char[] error, int failIndex, any[] queryData)
{
	LogError("Updating glove default values failed! %s", error);
	LoadConnectedClients();
}

void MigrateMainTableColumns()
{
	char query[255];
	static const char columnDefs[][] = {
		"t_group int(5) NOT NULL DEFAULT '-1'",
		"t_glove int(5) NOT NULL DEFAULT '-1'",
		"t_float decimal(3,2) NOT NULL DEFAULT '0.0'",
		"ct_group int(5) NOT NULL DEFAULT '-1'",
		"ct_glove int(5) NOT NULL DEFAULT '-1'",
		"ct_float decimal(3,2) NOT NULL DEFAULT '0.0'"
	};
	for (int i = 0; i < sizeof(columnDefs); i++)
	{
		FormatEx(query, sizeof(query), "ALTER TABLE %sgloves ADD COLUMN %s", g_TablePrefix, columnDefs[i]);
		db.Query(T_MigrateTableCallback, query, _, DBPrio_Low);
	}
}

public void T_MigrateTableCallback(Database database, DBResultSet results, const char[] error, any data)
{
}

void LoadConnectedClients()
{
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientConnected(i))
		{
			OnClientPostAdminCheck(i);
		}
	}
}
