/* Timer_Slow()
** -------------------------------------------------------------------------- */
public Action Timer_Slow(Handle timer, int client) {
	//PrintToChatAll("Speed modifier = %f, duration = %i", speed_modifier[client], slow_duration[client]);
	//PrintToChat(client, "");
	if (!IsClientInGame(client)) {
		speed_modifier[client] = 100.0;
		slowed[client] = false;
		return Plugin_Stop;
	}
	if (slow_duration[client] <= 0.0) {
		speed_modifier[client] = 100.0;
		slowed[client] = false;
		HUD_ShowStatus(client);
		//PrintToChatAll("Speed modifier = %f, duration = %i", speed_modifier[client], slow_duration[client]);
		return Plugin_Stop;
	}
	slow_duration[client] -= 0.1;
	return Plugin_Continue;
}

/* Timer_Frostbite()
** -------------------------------------------------------------------------- */
public Action Timer_Frostbite(Handle timer, int client) {
	//PrintToChatAll("Speed modifier = %f, duration = %i", speed_modifier[client], slow_duration[client]);
	//PrintToChat(client, "");
	if (!IsClientInGame(client)) {
		frostbitten[client] = false;
		return Plugin_Stop;
	}
	if (frostbite[client] <= 0.0) {
		frostbitten[client] = false;
		HUD_ShowStatus(client);
		return Plugin_Stop;
	}
	frostbite[client] -= 0.1;
	return Plugin_Continue;
}

/* Timer_LoneWolf()
** -------------------------------------------------------------------------- */
public Action Timer_LoneWolf(Handle timer, int client) {
	if (!IsValidClient(client) || TF2_GetClientTeam(client) != TFTeam_Red) {
		return Plugin_Stop;
	}
	lone_wolf_nearby[client] = 0;
	int counter = 0;
	float lone_wolf_pos[3];
	GetEntPropVector(client, Prop_Send, "m_vecOrigin", lone_wolf_pos);
	float pos[3];
	for (int i = 1; i <= MaxClients; i++) {
		if (IsValidClient(i) && TF2_GetClientTeam(i) == TFTeam_Red && IsPlayerAlive(i) && i != client) {
			GetEntPropVector(i, Prop_Send, "m_vecOrigin", pos);
			int distance = RoundToNearest(GetVectorDistance(lone_wolf_pos, pos, false));
			//PrintToChat(client, "%i", distance);
			if (distance <= 400) {
				//lone_wolf_nearby[client]++;
				counter++;
			}
		}
	}
	lone_wolf_nearby[client] = counter;
	//PrintToChat(client, "%i", lone_wolf_nearby[client]);
	return Plugin_Continue;
}

/* Timer_Invis()
** -------------------------------------------------------------------------- */
public Action Timer_Invis(Handle timer, int client) {
	if (!IsValidClient(client)) {
		return Plugin_Stop;
	}
	//PrintToChat(client, "Duration: %i", invis_duration[client]);
	if (invis_duration[client] <= 0) {
		Colorize(client, NORMAL);
		return Plugin_Stop;
	}
	invis_duration[client] -= 0.1;
	return Plugin_Continue;
}

/* Timer_Respawn()
** -------------------------------------------------------------------------- */
public Action Timer_Respawn(Handle timer, int clientSerial)
{
	int client = GetClientFromSerial(clientSerial);

	if(!IsValidClient(client)) {
		return Plugin_Handled;
	}

	if(!IsPlayerAlive(client) && TF2_GetClientTeam(client) != TFTeam_Spectator && TF2_GetClientTeam(client) != TFTeam_Unassigned) {
		TF2_RespawnPlayer(client);
	}

	return Plugin_Handled;
}

/* Timer_Leaping()
** -------------------------------------------------------------------------- */
public Action Timer_Leaping(Handle timer, int client) {
	if (!IsValidClient(client) || GetEntityFlags(client) & FL_ONGROUND || GetEntityFlags(client) & FL_INWATER) {
		leaping[client] = false;
		if (second_leap_cd[client] <= 0) {
			second_leap_cd[client] = 34.0;
			HUD_ShowCooldowns(client);
		}
		//PrintToChatAll("The client landed.");
		return Plugin_Stop;
	}
	leap_ticks[client]++;
	return Plugin_Continue;
}

/* Timer_Juggernaut()
** -------------------------------------------------------------------------- */
public Action Timer_Juggernaut(Handle timer, int index) {
	if (!main_timer) {
		return Plugin_Stop;
	}
	if (juggernauts < index) {
		// remove juggernaut effect
		return Plugin_Stop;
	}
	if (juggernaut[index] == 0 || !IsClientInGame(juggernaut[index]) || AfkCounter[juggernaut[index]] >= 35/* || activity[juggernaut[index]] >= 100*/ || reports[juggernaut[index]] >= 2) {
		if (juggernaut[index] != 0 && IsClientInGame(juggernaut[index])) { // needed if juggernaut is being taken away from a player
			SetEntityRenderColor(juggernaut[index], 255, 255, 255, 255); // regular color back
		}
		juggernaut[index] = 0;
		//PrintToChatAll("Looking for a new juggernaut.");
		int players = 0;
		int candidates[MAX_TF_CLIENTS];
		for (int i = 1; i <= MaxClients; i++) {
			if (IsValidClient(i) && !IsFakeClient(i) && TF2_GetClientTeam(i) == TFTeam_Blue && GetJuggernaut(i) == -1 && GetWarden(i) == -1 && AfkCounter[i] < 35/* && activity[i] < 100*/ && reports[juggernaut[index]] < 2) {
				candidates[players++] = i;
			}
		}
		if (players > 0) {
			juggernaut[index] = candidates[GetURandomInt() % players];
			PrintToChat(juggernaut[index], "You are now a juggernaut!");
			SetEntityRenderColor(juggernaut[index], 12, 178, 67, 255); // green color for juggernaut
			need_jug[index] = false;
			return Plugin_Continue;
		}
		need_jug[index] = true;
		return Plugin_Stop;
	}
	if (IsPlayerAlive(juggernaut[index])) {
		ApplyJuggernautBuffs(index);
		ApplySeeker(index, false);
	}
	return Plugin_Continue;
}

/* Timer_Juggernaut()
** -------------------------------------------------------------------------- */
public Action Timer_Warden(Handle timer, int index) {
	if (!main_timer) {
		return Plugin_Stop;
	}
	if (wardens < index) {
		// remove juggernaut effect
		return Plugin_Stop;
	}
	if (warden[index] == 0 || !IsClientInGame(warden[index]) || AfkCounter[warden[index]] >= 35/* || activity[warden[index]] >= 100*/ || reports[warden[index]] >= 2) { // TODO add more conditions for role
		if (warden[index] != 0 && IsClientInGame(warden[index])) { // needed if warden is being taken away from a player
			SetEntityRenderColor(warden[index], 255, 255, 255, 255); // normal color
		}
		warden[index] = 0;
		//PrintToChatAll("Looking for a new warden.");
		int players = 0;
		int candidates[MAX_TF_CLIENTS];
		for (int i = 1; i <= MaxClients; i++) {
			if (IsValidClient(i) && !IsFakeClient(i) && TF2_GetClientTeam(i) == TFTeam_Blue && GetJuggernaut(i) == -1 && GetWarden(i) == -1 && AfkCounter[i] < 35/* && activity[i] < 100*/ && reports[warden[index]] < 2) {
				candidates[players++] = i;
			}
		}
		if (players > 0) {
			warden[index] = candidates[GetURandomInt() % players];
			PrintToChat(warden[index], "You are now a warden!");
			SetEntityRenderColor(warden[index], 255, 153, 0, 255); // yellow color for warden
			need_warden[index] = false;
			return Plugin_Continue;
		}
		need_warden[index] = true;
		return Plugin_Stop;
	}
	if (IsPlayerAlive(warden[index])) {
		ApplySeeker(index, true);
	}
	return Plugin_Continue;
}

/* Timer_Main()
** -------------------------------------------------------------------------- */
public Action Timer_Main(Handle timer) {
	if (!main_timer) {
		return Plugin_Stop;
	}
	if (round_time == 0) {
		PlaySound("RoundStart");
		for (int i = 0; i < PERKS; i++) {
			perk_count[i] = 0;
		}
		for (int i = 1; i <= MaxClients; i++) {
			if (IsValidClient(i)) {
				if (TF2_GetClientTeam(i) == TFTeam_Red) {
					perk[i] = confirmed_perk[i];

					round_perk[i] = confirmed_perk[i]; // database
					perk_count[confirmed_perk[i]]++;
					round_steam_id[i] = GetSteamAccountID(i, true);
					started_as_engie[i] = true;

					PrintToChat(i, "Your perk was assigned. Your perk is: %s.", perks_names[perk[i]]);
					HUD_ShowInfo(i);
					HUD_ShowStatus(i);
					HUD_ShowCooldowns(i);
					if (perk[i] == 6) {
						CreateTimer(0.1, Timer_LoneWolf, i, TIMER_REPEAT);
					}
					if (perk[i] == 8) {
						TF2_RemoveWeaponSlot(i, 0);
						//TF2_RemoveWeaponSlot(i, 1); // now keeps secondary weapon, just no damage boost if he does
					}
					if (perk[i] == 9) {
						jet_charges[i] = 3;
					}
				} else {
					SetEntityMoveType(i, MOVETYPE_WALK);
				}
			}
		}
	}
	for (int i = 1; i <= MAX_TF_CLIENTS; i++) {
		if (IsValidClient(i) && TF2_GetClientTeam(i) == TFTeam_Red) {
			survived_time[i]++;
		}
	}
	if (round_time >= ROUND_DURATION) {
		RequestFrame(ForceWin, TFTeam_Red);
		return Plugin_Stop;
	}
	round_time++;
	return Plugin_Continue;
}

/* Timer_HUD()
** -------------------------------------------------------------------------- */
public Action Timer_HUD(Handle timer) {
	if (!main_timer) {
		return Plugin_Stop;
	}
	bool have_engie = false;
	for (int i = 1; i <= MaxClients; i++) {
		if (IsValidClient(i)) {
			HUD_ShowInfo(i);
			HUD_ShowStatus(i);
			HUD_ShowCooldowns(i);
			if (TF2_GetClientTeam(i) == TFTeam_Red) {
				have_engie = true;
			}
		}
	}
	if (!have_engie) {
		RequestFrame(ForceWin, TFTeam_Blue);
	}
	UpdateCooldowns();
	return Plugin_Continue;
}

/* Timer_Invis_Delay()
** -------------------------------------------------------------------------- */
public Action Timer_Invis_Delay(Handle timer, int client) {
	if (invis_interrupted[client]) {
		invis_interrupted[client] = false;
		return Plugin_Stop;
	}
	HUD_ShowStatus(client);
	invis_delay[client] -= 0.1;
	if (invis_delay[client] > 0.0) {
		return Plugin_Continue;
	}
	invis_duration[client] = 7.0;
	perk_cd[client] = 35.0;
	HUD_ShowCooldowns(client);
	HUD_ShowStatus(client);
	Colorize(client, INVIS);
	CreateTimer(0.1, Timer_Invis, client, TIMER_REPEAT);
	return Plugin_Stop;
}

/* Timer_Activity_Counter()
** -------------------------------------------------------------------------- */
public Action Timer_Activity_Counter(Handle timer) { // timer to monitor if medics are active
	for (int i = 1; i <= MaxClients; i++) {
		if (IsValidClient(i) && TF2_GetClientTeam(i) == TFTeam_Blue) {
			activity[i]++;
		}
	}
	return Plugin_Continue;
}

/* Timer_Afk_Counter()
** -------------------------------------------------------------------------- */
public Action Timer_Afk_Counter(Handle timer) {
	for (int i = 1; i <= MaxClients; i++) {
		if (IsValidClient(i) && TF2_GetClientTeam(i) != TFTeam_Spectator) {
			if (LastButtons[i] == TimerLastButtons[i]) {
				AfkCounter[i]++;
			} else {
				AfkCounter[i] = 0;
				TimerLastButtons[i] = LastButtons[i];
			}
		}
	}
	return Plugin_Continue;
}

/* Timer_Report()
** -------------------------------------------------------------------------- */
public Action Timer_Report(Handle timer, int client) {
	if (report_timeout[client] <= 0.0) {
		last_teleporter[client] = 0;
		return Plugin_Stop;
	}
	report_timeout[client] -= 0.1;
	return Plugin_Continue;
}

/* Timer_CheckDispenser()
** -------------------------------------------------------------------------- */
public Action Timer_CheckDispenser(Handle timer, DataPack dataPack) {

	dataPack.Reset();
	int teleporter = EntRefToEntIndex(dataPack.ReadCell());
	int client = GetClientFromSerial(dataPack.ReadCell());
	delete dataPack;

	if(!IsValidClient(client) || !IsValidEntity(teleporter)) {
		return Plugin_Handled;
	}
	
	float builder_position[3];
	GetClientAbsOrigin(client, builder_position);
	float tele_position[3];
	GetEntPropVector(teleporter, Prop_Send, "m_vecOrigin", tele_position);
	float disp_position[3];
	
	//float vec_client_tele[3];
	//float vec_client_disp[3];
	float distance_td;
	//float distance_tb;
	float distance_db;

	bool legal = false;

	int entity = -1;
	while ((entity = FindEntityByClassname(entity, "obj_dispenser")) > -1) {
		GetEntPropVector(entity, Prop_Send, "m_vecOrigin", disp_position);
		distance_td = GetVectorDistance(tele_position, disp_position, false);
		//distance_tb = GetVectorDistance(tele_position, builder_position, false);
		distance_db = GetVectorDistance(disp_position, builder_position, false);
		//PrintToChatAll("%f %f %f", distance_td, distance_tb, distance_db);
		if (distance_td < 75.0 && distance_db > 120.0) {
			legal = true;
			break;
		}
	}
	
	if (!legal) {
		PlaySound("Forbid", client);
		SetVariantInt(9999);
		AcceptEntityInput(teleporter, "RemoveHealth");
		//AcceptEntityInput(teleporter, "Kill"); - this is also a nice option but remove health at least returns some metal
		PrintToChat(client, "Teleporter exit must be near a dispencer and between you and dispencer!");
	}

	return Plugin_Handled;
}

public Action Timer_Recent_Damage(Handle timer, int client) {
	if (recent_damage[client] <= 0.0) {
		recent_damage[client] = 0.0;
		return Plugin_Stop;
	}
	recent_damage[client] -= 0.1;
	return Plugin_Continue;
}

public Action Timer_Recently_Damaged(Handle timer, int client) {
	if (recently_damaged[client] <= 0.0) {
		recently_damaged[client] = 0.0;
		return Plugin_Stop;
	}
	recently_damaged[client] -= 0.1;
	return Plugin_Continue;
}

public Action Timer_RankCooldown(Handle timer, int client) {
	get_rank_cooldown[client] = false;
	return Plugin_Continue;
}