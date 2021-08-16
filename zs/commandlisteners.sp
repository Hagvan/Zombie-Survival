/* CommandListener_ChangeLevel()
** -------------------------------------------------------------------------- */
public Action CommandListener_ChangeLevel(int args) {
	if (args == 0) {
		return;
	}
}

/* CommandListener_Build()
** -------------------------------------------------------------------------- */
public Action CommandListener_Build(int client, int args) {
	if (perk[client] == 3 || perk[client] == 6 || perk[client] == 7 || perk[client] == 9) { // jetpack, lone wolf, sneaky and battery jetpack can't build
		PlaySound("Forbid", client);
		return Plugin_Handled;
	}
	char arg[10];
	GetCmdArg(1, arg, 10);
	if (strcmp(arg, "2") == 0 || strcmp(arg, "2") == 7) {
		PlaySound("Forbid", client);
		return Plugin_Handled;
	}
	return Plugin_Continue;
}

/* CommandListener_JoinTeam()
** -------------------------------------------------------------------------- */
public Action CommandListener_JoinTeam(int client, int args) {
	char arg[10];
	GetCmdArg(1, arg, 10);
	if (IsAdmin(client) && StrEqual(arg, "spectate")) {
		return Plugin_Continue;
	}
	return Plugin_Handled;
}

/* CommandListener_AutoTeam()
** -------------------------------------------------------------------------- */
public Action CommandListener_AutoTeam(int client, int args) {
	return Plugin_Handled;
}

/* CommandListener_JoinClass()
** -------------------------------------------------------------------------- */
public Action CommandListener_JoinClass(int client, int args) {
	return Plugin_Handled;
}

/* Listener_Voice()
** -------------------------------------------------------------------------- */
public Action Listener_Voice(int client, const char[] sCommand, int args) {
	char arguments[30];
	GetCmdArgString(arguments, sizeof(arguments));
	int j_index = GetJuggernaut(client);
	int w_index = GetWarden(client);
	int flags = GetEntityFlags(client);
	if (StrEqual(arguments, "0 0")) {
		if (j_index > -1 && summon_cd[j_index] <= 0.0 && (flags & FL_ONGROUND || flags & FL_INWATER) && !(flags & FL_DUCKING) && seeker_temp[j_index] > 0) {
			Summon(client, false);
		} else if (w_index > -1 && summon_cd[JUGGERNAUTS + w_index] <= 0.0 && (flags & FL_ONGROUND || flags & FL_INWATER) && !(flags & FL_DUCKING) && seeker_temp[JUGGERNAUTS+ w_index] > 0) {
			Summon(client, true);
		}
	} else {
		return Plugin_Continue;
	}
	return Plugin_Continue;
}