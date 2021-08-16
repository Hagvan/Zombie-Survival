// Database
Database databaseSQL = null;

/* SQL_ConnectDatabase()
** -------------------------------------------------------------------------- */
public void SQL_ConnectDatabase()
{
	if (databaseSQL != null)
	{
		delete databaseSQL;
	}

	if(!SQL_CheckConfig("zombie_survival"))
	{
		SetFailState("SQL_ConnectDatabase failed to find zs_feedback config in database.cfg");
	}

	Database.Connect(SQL_ConnectDatabase_Callback, "zombie_survival");
}

/* SQL_ConnectDatabase_Callback()
** -------------------------------------------------------------------------- */
public void SQL_ConnectDatabase_Callback(Database database, const char[] error, any data)
{
	if(database == null)
	{
		SetFailState("SQL_ConnectDatabase failed to connect to database");
	}

	databaseSQL = database;
	inserting = false;

	databaseSQL.SetCharset("utf8mb4");

	//SQL_CreateTables();
}

/* SQL_InsertRound()
** -------------------------------------------------------------------------- */
public void SQL_InsertRound(int attempt)
{
	inserting = true;
	
	Transaction transaction = SQL_CreateTransaction(); // create a new transaction
	
	char map[45];
	GetCurrentMap(map, 45);

	char perk_string[200]; // bulid a perk count string for table_round insert
	char buffer[200];
	for (int i = 0; i < PERKS; i++) {
		if (i + 1 == PERKS) {
			Format(buffer, 200, "%i", perk_count[i]);
		} else {
			Format(buffer, 200, "%i, ", perk_count[i]);
		}
		StrCat(perk_string, 200, buffer);
	}

	char query[3000];
	Format(query, 3000, "insert into table_round (map, time_left) values ('%s', %i);", map, ROUND_DURATION - round_time);
	transaction.AddQuery(query); // insert the round first

	Format(query, 3000, "SET @last_round = (select round_id from last_round);");
	transaction.AddQuery(query); // tell the database to update the @last_round session variable
	
	Format(query, 3000, "insert into table_player_round (steam_id, perk, score, kills, juggernaut_kills, warden_kills, survival_time, round_id) values ");
	
	char player_result[200];
	bool first = true;
	for (int i = 1; i < MAX_TF_CLIENTS; i++) {
		if (!started_as_engie[i]) { // if not valid client or didn't start as engie or not same player as from the start
			continue;
		}
		if (first) {
			Format(player_result, 200, "(%i, %i, %i, %i, %i, %i, %i, @last_round)", round_steam_id[i], round_perk[i], score[i], kills[i], jug_kills[i], warden_kills[i], survived_time[i]);
			first = false;
		} else {
			Format(player_result, 200, ", (%i, %i, %i, %i, %i, %i, %i, @last_round)", round_steam_id[i], round_perk[i], score[i], kills[i], jug_kills[i], warden_kills[i], survived_time[i]);
		}
		StrCat(query, 3000, player_result);
	}
	StrCat(query, 3000, ";");
	transaction.AddQuery(query);
	
	SQL_ExecuteTransaction(databaseSQL, transaction, SQL_TransactionSuccess, SQL_TransactionFailure, attempt);
}

public void SQL_TransactionSuccess(Database db, any data, int numQueries, DBResultSet[] results, any[] queryData)
{
	inserting = false;
}

public void SQL_TransactionFailure(Database db, any data, int numQueries, const char[] error, int failIndex, any[] queryData)
{
	if (data > 4) {
		PrintToChatAll("SQL transaction failed.");
		inserting = false;
	} else {
		SQL_InsertRound(data + 1); // retry to insert the round
	}
}

public void SQL_GetPlayerRankOnJoin(int client) {
	Transaction transaction = SQL_CreateTransaction();
	char query[3000];
	Format(query, 3000, "SET @row_number = 0;");
	transaction.AddQuery(query);
	Format(query, 3000, "select rank, recent_score from (SELECT (@row_number:=@row_number + 1) AS rank, scores.steam_id, scores.recent_score FROM (SELECT steam_id, sum(score) AS recent_score FROM (SELECT steam_id, score, round_id, @rank_num:=IF(@current_steam = steam_id, @rank_num + 1, 1) AS ranker, @current_steam:=steam_id FROM last_thousand ORDER BY steam_id , round_id DESC) ranked WHERE ranker <= 50 GROUP BY steam_id ORDER BY recent_score DESC) AS scores ORDER BY rank ASC) as leaderboard where steam_id = %i;", GetSteamAccountID(client, true));
	transaction.AddQuery(query);
	SQL_ExecuteTransaction(databaseSQL, transaction, SQL_GetPlayerRankOnJoinSuccess, SQL_GetPlayerRankOnJoinFailure, client);
}

public void SQL_GetPlayerRankOnJoinSuccess(Database db, any data, int numQueries, DBResultSet[] results, any[] queryData) {
	DBResultSet rank_result = results[numQueries - 1];
	char playername[50];
	GetClientName(data, playername, 50);
	if (rank_result.FetchRow()) {
		PrintToChatAll("[EXPERIMENTAL] %s (rank: #%i, recent total score: %i) joined the game!", playername, rank_result.FetchInt(0), rank_result.FetchInt(1));
	} else {
		PrintToChatAll("[EXPERIMENTAL] %s (unranked) joined the game!", playername);
	}
}

public void SQL_GetPlayerRankOnJoinFailure(Database db, any data, int numQueries, const char[] error, int failIndex, any[] queryData)
{
	PrintToChatAll("SQL transaction failed.");
}

public void SQL_GetPlayerRankCommand(int client) {
	Transaction transaction = SQL_CreateTransaction();
	char query[3000];
	Format(query, 3000, "SET @row_number = 0;");
	transaction.AddQuery(query);
	Format(query, 3000, "select rank, recent_score from (SELECT (@row_number:=@row_number + 1) AS rank, scores.steam_id, scores.recent_score FROM (SELECT steam_id, sum(score) AS recent_score FROM (SELECT steam_id, score, round_id, @rank_num:=IF(@current_steam = steam_id, @rank_num + 1, 1) AS ranker, @current_steam:=steam_id FROM last_thousand ORDER BY steam_id , round_id DESC) ranked WHERE ranker <= 50 GROUP BY steam_id ORDER BY recent_score DESC) AS scores ORDER BY rank ASC) as leaderboard where steam_id = %i;", GetSteamAccountID(client, true));
	transaction.AddQuery(query);
	SQL_ExecuteTransaction(databaseSQL, transaction, SQL_GetPlayerRankCommandSuccess, SQL_GetPlayerRankCommandFailure, client);
}

public void SQL_GetPlayerRankCommandSuccess(Database db, any data, int numQueries, DBResultSet[] results, any[] queryData) {
	DBResultSet rank_result = results[numQueries - 1];
	char playername[50];
	GetClientName(data, playername, 50);
	if (rank_result.FetchRow()) {
		PrintToChatAll("[EXPERIMENTAL] %s is ranked #%i with recent total score of: %i!", playername, rank_result.FetchInt(0), rank_result.FetchInt(1));
	} else {
		PrintToChatAll("[EXPERIMENTAL] %s is unranked!", playername);
	}
}

public void SQL_GetPlayerRankCommandFailure(Database db, any data, int numQueries, const char[] error, int failIndex, any[] queryData)
{
	PrintToChatAll("SQL transaction failed.");
}