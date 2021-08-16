/* Command_Perks()
** -------------------------------------------------------------------------- */
public Action Command_Perks(int client, int args) {
	Menu_ShowPerk(client);
	return Plugin_Handled;
}


/* Command_GetRank()
** -------------------------------------------------------------------------- */
public Action Command_GetRank(int client, int args) {
	if (get_rank_cooldown[client]) {
		PrintToChat(client, "Command is on cooldown.");
		return Plugin_Handled;
	}
	get_rank_cooldown[client] = true;
	CreateTimer(10.0, Timer_RankCooldown, client);
	SQL_GetPlayerRankCommand(client);
	return Plugin_Handled;
}

public Action Command_Dump(int client, int args) { // dump all variables in console for finding bugs
	/*PrintToConsole(client, "main_timer: %s\n", main_timer ? "true" : "false");
	PrintToConsole(client, "waiting: %s\n", waiting ? "true" : "false");
	
	PrintToConsole(client, "round_time: %i\n", round_time);
	
	for (int i = 1; i <= MAX_TF_CLIENTS; i++) {
		
	}*/
}