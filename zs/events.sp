/* Event_OnSetupFinished()
** -------------------------------------------------------------------------- */
public Action Event_OnSetupFinished(Event event, const char[] name, bool dontBroadcast) {
	int ent = -1;
	while ((ent = FindEntityByClassname(ent, "team_round_timer")) != INVALID_ENT_REFERENCE) {
		//PrintToChatAll("Hidden one timer");
		SetVariantBool(false);
		AcceptEntityInput(ent, "Pause");
		AcceptEntityInput(ent, "Disable");
	}
	return Plugin_Handled;
}

/* Event_OnPlayerDeath()
** -------------------------------------------------------------------------- */
public Action Event_OnPlayerDeath(Event event, const char[] name, bool dontBroadcast) {
	if (!ignore_deaths) {
		int victim = GetClientOfUserId(event.GetInt("userid"));

		if(!IsValidClient(victim)) {
			return Plugin_Continue;
		}
		if (TF2_GetClientTeam(victim) == TFTeam_Spectator || TF2_GetClientTeam(victim) == TFTeam_Unassigned) {
			return Plugin_Continue;
		} else if (TF2_GetClientTeam(victim) == TFTeam_Red) {
			CreateTimer(0.3, ToMedic, victim);
		} else {
			bool jug_kill = GetJuggernaut(victim) > -1;
			bool warden_kill = GetWarden(victim) > -1;
			
			int killer = GetClientOfUserId(event.GetInt("attacker"));
			
			if(IsValidClient(killer)) {
				if (perk[killer] == 3 && leaping[killer]) {
					leap_cd[killer] = 0.0;
				}
				if (perk[killer] == 7) {
					perk_cd[killer] -= 10.0;
				}
				if (perk[killer] == 9 && leaping[killer]) {
					jet_charges[killer]++;
					leap_cd[killer] = 0.0;
				}
				HUD_ShowCooldowns(killer);
				
				score[killer] += (jug_kill || warden_kill) ? 30 : (recent_damage[victim] > 0.0 ? 10 : 5);
				if (jug_kill) {
					jug_kills[killer]++;
				}
				if (warden_kill) {
					warden_kills[killer]++;
				}
				kills[killer]++;
				HUD_ShowStatus(killer);
			}

			int assistor = GetClientOfUserId(event.GetInt("assistor"));
			if (IsValidClient(assistor)) {
				if (perk[assistor] == 7) {
					perk_cd[assistor] -= 5.0;
					HUD_ShowCooldowns(assistor);
				}
				
				score[assistor] += (jug_kill || warden_kill) ? 30 : (recent_damage[victim] > 0.0 ? 10 : 5);
				if (jug_kill) {
					jug_kills[assistor]++;
				}
				if (warden_kill) {
					warden_kills[assistor]++;
				}
				kills[assistor]++;
				HUD_ShowStatus(assistor);
			}

			if (killer < 1 || killer >= MAX_TF_CLIENTS) { // check if player died to environment
				if (report_timeout[victim] > 0.0) {
					reports[last_teleporter[victim]]++;
					report_timeout[victim] = 0.0;
					last_teleporter[victim] = 0;
				}
			}
		}

		CreateTimer(g_convar_respawntime.FloatValue, Timer_Respawn, GetClientSerial(victim));
	}
	return Plugin_Handled;
}

/* Event_PlayerSpawn()
** -------------------------------------------------------------------------- */
public Action Event_PlayerSpawn(Event event, const char[] name, bool dontBroadcast) {
	int client = GetClientOfUserId(event.GetInt("userid"));

	if(!IsValidClient(client))
	{
		return Plugin_Continue;
	}

	//CreateTimer(0.5, Timer_SetModel, GetClientSerial(client));
	return Plugin_Continue;
}

/* Event_OnPlayerTeam()
** -------------------------------------------------------------------------- */
public Action Event_OnPlayerTeam(Event event, const char[] name, bool dontBroadcast) {
	event.BroadcastDisabled = true;
	if (ignore_deaths || round_time < 0) {
		return Plugin_Continue;
	}

	int client = GetClientOfUserId(event.GetInt("userid"));
	char player_name[30];
	GetClientName(client, player_name, sizeof(player_name));
	//PrintToChatAll("%s was converted to zombie.", player_name);
	return Plugin_Continue;
}

/* Event_OnInventory()
** -------------------------------------------------------------------------- */
public Action Event_OnInventory(Event event, const char[] name, bool dontBroadcast) {
	int client = GetClientOfUserId(event.GetInt("userid"));
	speed_modifier[client] = 100.0;
	summon_priority[client] = ++last_spawn;
	if (!waiting && TF2_GetClientTeam(client) == TFTeam_Blue) {
		if (round_time < 0) {
			protection_end[client] = 5;
			SetEntityMoveType(client, MOVETYPE_NONE);
		} else {
			protection_end[client] = round_time + 5;
		}
		TF2_RemoveWeaponSlot(client, 0);
		TF2_RemoveWeaponSlot(client, 1);
		int weapon = GetPlayerWeaponSlot(client, 2);
		SetEntPropEnt(client, Prop_Send, "m_hActiveWeapon", weapon);
		for (int i = 0; i < JUGGERNAUTS; i++) {
			if (client == juggernaut[i]) {
				breaker_stacks[i] = 0;
			}
			if (need_jug[i] && IsValidClient(client) && GetJuggernaut(client) == -1 && GetWarden(client) == -1 && AfkCounter[client] < 35/* && activity[client] < 100*/) {
				juggernaut[i] = client;
				PrintToChat(client, "You are now a juggernaut!");
				SetEntityRenderColor(client, 12, 178, 67, 255);
				need_jug[i] = false;
				breaker_stacks[i] = 0;
				CreateTimer(0.1, Timer_Juggernaut, i, TIMER_REPEAT);
				break;
			}
		}
		for (int i = 0; i < WARDENS; i++) {
			if (need_warden[i] && IsValidClient(client) && GetJuggernaut(client) == -1 && GetWarden(client) == -1 && AfkCounter[client] < 35/* && activity[client] < 100*/) {
				warden[i] = client;
				PrintToChat(client, "You are now a warden!");
				SetEntityRenderColor(client, 255, 153, 0, 255);
				need_warden[i] = false;
				CreateTimer(0.1, Timer_Warden, i, TIMER_REPEAT);
				break;
			}
		}
	}
	return Plugin_Handled;
}

/* Event_OnRoundStart()
** -------------------------------------------------------------------------- */
public Action Event_OnRoundStart(Event event, const char[] name, bool dontBroadcast) {
	if (waiting) {
		return Plugin_Handled;
	}

	int ent;
	while ((ent = FindEntityByClassname(ent, "func_door")) != INVALID_ENT_REFERENCE) AcceptEntityInput(ent, "Open"); ent = -1;

	ignore_deaths = true;
	main_timer = false;

	round_time = -30; // preparation time

	int players = 0;
	m_max = 0;
	last_spawn = 0;
	start_medics = 0;
	for (int i = 1; i < MAX_TF_CLIENTS; i++) {
		
		started_as_engie[i] = false;
		score[i] = 0;
		kills[i] = 0;
		jug_kills[i] = 0;
		warden_kills[i] = 0;
		survived_time[i] = 0;
		
		slowed[i] = false;
		protection_end[i] = -30;
		activity[i] = 0;
		reports[i] = 0;
		summon_priority[i] = 0;
		
		if (IsValidClient(i) && TF2_GetClientTeam(i) != TFTeam_Spectator && TF2_GetClientTeam(i) != TFTeam_Unassigned) {
			players++;
			toMedic[i] = false;
			perk[i] = 0;
			if (wasMedic[i] > m_max) {
				m_max = wasMedic[i];
			}
			SetEntityRenderColor(i, 255, 255, 255, 255);
		}
	}

	for (int i = 0; i < JUGGERNAUTS + WARDENS; i++) {
		summon_cd[i] = 0.0;
	}

	int medics = 0;
	if (players == 1) {
		medics = 0;
	} else if (players < 12) {
		medics = RoundToCeil(players / 3.0);
		juggernauts = 1;
		wardens = 1;
	} else if (players >= 12 && players < 24) {
		medics = RoundToCeil(players / 4.0);
		juggernauts = 2;
		wardens = 1;
	} else {
		medics = RoundToCeil(players / 5.0);
		juggernauts = 3;
		wardens = 2;
	}
	

	if (medics > 5) { // experimental cap to make rounds a bit longer
		medics = 5;
	}
	
	start_medics = medics;

	LogAction(-1, -1, "To medic = %d", medics);
	LogAction(-1, -1, "Players = %d", players);
	int cur = m_max - 1;
	int player_medics = 0;
	while (medics > 0) {
		for (int i = 1; i <= MaxClients; i++) {
			if (IsValidClient(i) && TF2_GetClientTeam(i) != TFTeam_Spectator && TF2_GetClientTeam(i) != TFTeam_Unassigned) {
				if (wasMedic[i] <= cur) {
					wasMedic[i]++;
					toMedic[i] = true;
					if (--medics <= 0)
					{
						break;
					}
				}
			}
		}
		cur++;
	}

	for (int i = 1; i <= MaxClients; i++) {
		if (IsValidClient(i) && TF2_GetClientTeam(i) != TFTeam_Spectator && TF2_GetClientTeam(i) != TFTeam_Unassigned) {
			if (toMedic[i]) {
				//LogAction(-1, -1, "Player moved to blu. %i", wasMedic[i]);
				ChangeClientTeam_Safe(i, TFTeam_Blue);
				TF2_SetPlayerClass(i, TFClass_Medic);
				if (IsValidClient(i))player_medics++;
			} else {
				//LogAction(-1, -1, "Player moved to red. %i", wasMedic[i]);
				ChangeClientTeam_Safe(i, TFTeam_Red);
				TF2_SetPlayerClass(i, TFClass_Engineer);
			}
			TF2_RespawnPlayer(i);
		}
	}
	for (int i = 0; i < JUGGERNAUTS; i++) {
		juggernaut[i] = 0;
	}
	for (int i = 0; i < WARDENS; i++) {
		warden[i] = 0;
	}
	return Plugin_Handled;
}

/* Event_OnRoundActive()
** -------------------------------------------------------------------------- */
public Action Event_OnRoundActive(Event event, const char[] name, bool dontBroadcast) {
	if (waiting) {
		return Plugin_Handled;
	}

	main_timer = true;
	CreateTimer(1.0, Timer_Main, _, TIMER_REPEAT);
	CreateTimer(0.1, Timer_HUD, _, TIMER_REPEAT);
	for (int i = 0; i < juggernauts; i++) {
		CreateTimer(0.1, Timer_Juggernaut, i, TIMER_REPEAT);
	}
	for (int i = 0; i < wardens; i++) {
		CreateTimer(0.1, Timer_Warden, i, TIMER_REPEAT);
	}
	for (int i = 1; i <= MaxClients; i++) {
		if (IsValidClient(i)) {
			switch (TF2_GetClientTeam(i)) {
				case TFTeam_Blue: protection_end[i] = round_time + 35;
				case TFTeam_Red: Menu_ShowPerk(i);
			}

		}
	}
	ignore_deaths = false;
	return Plugin_Handled;
}

/* Event_BuiltObject()
** -------------------------------------------------------------------------- */
public Action Event_BuiltObject(Event event, const char[] name, bool dontBroadcast) {
	int entity = GetEventInt(event, "index");
	SDKHook(entity, SDKHook_OnTakeDamage, OnTakeDamageBuilding);

	int builder = GetEntPropEnt(entity, Prop_Send, "m_hBuilder");
	if (!IsValidClient(builder)) {
		return Plugin_Continue;
	}

	if (TF2_GetObjectType(entity) == TFObject_Teleporter && TF2_GetObjectMode(entity) == TFObjectMode_Exit) {
		DataPack dataPack = new DataPack();
		dataPack.WriteCell(EntIndexToEntRef(entity));
		dataPack.WriteCell(GetClientSerial(builder));
		CreateTimer(0.1, Timer_CheckDispenser, dataPack); // after 0.1 seconds check if there is a dispenser present near the teleporter exit
	}
	
	if (TF2_GetObjectType(entity) == TFObject_Sentry) {
		SetVariantInt(9999);
		AcceptEntityInput(entity, "RemoveHealth");
	}
	
	//if (perk[builder] ==
	return Plugin_Handled;
}