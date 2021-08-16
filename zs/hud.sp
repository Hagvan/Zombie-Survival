/* HUD_ShowInfo()
** -------------------------------------------------------------------------- */
public void HUD_ShowInfo(int client) {

	if((GetClientButtons(client) & IN_SCORE)) {
		return;
	}

	char temp[256];
	char info[256];
	if (TF2_GetClientTeam(client) == TFTeam_Red) {
		if (round_time < 0) {
			Format(info, 256, "%i seconds before the round starts\n", -round_time);
			Format(temp, 256, "Your current perk is: %s\n", perks_names[confirmed_perk[client]]);
			StrCat(info, 256, temp);
			Format(temp, 256, "Type !zs_perks to open the perk menu");
			StrCat(info, 256, temp);
		} else {
			Format(info, 256, "Surive %i seconds to win\n", ROUND_DURATION - round_time);
			Format(temp, 256, "Your perk is: %s\n", perks_names[perk[client]]);
			StrCat(info, 256, temp);
			Format(temp, 256, "Your round score: %i\n", score[client]);
			StrCat(info, 256, temp);
		}
	} else {
		int j_index = GetJuggernaut(client);
		int w_index = GetWarden(client);
		if (round_time < 0) {
			Format(info, 256, "%i seconds before the round starts\n", -round_time);
			if (j_index > -1) {
				Format(temp, 256, "You are a juggernaut, lead the BLU team!\n");
				StrCat(info, 256, temp);
			}
			if (w_index > -1) {
				Format(temp, 256, "You are a warden, help the BLU team!\n");
				StrCat(info, 256, temp);
			}
		} else {
			Format(info, 256, "You have %i seconds to kill all the engineers\n", ROUND_DURATION - round_time);
			if (j_index > -1) {
				Format(temp, 256, "You are a juggernaut, lead the BLU team!\n");
				StrCat(info, 256, temp);
				Format(temp, 256, "Your current resistance is %i%s\n", RoundToNearest(resistance[j_index] * 100 * RES_MUL), "%%");
				StrCat(info, 256, temp);
			}
			if (w_index > -1) {
				Format(temp, 256, "You are a warden, help the BLU team!\n");
				StrCat(info, 256, temp);
				//Format(temp, 256, "*Placeholder for summonable medics/coodlown*\n");
				//StrCat(info, 256, temp);
			}
		}
	}
	SendHudMessage(client, 1, -1.0, 0.05, 0xFFFF00FF, 0xFFFFFFFF, 0, 0.0, 0.0, 5.0, 5.0, info);
}

/* HUD_ShowCooldowns()
** -------------------------------------------------------------------------- */
public void HUD_ShowCooldowns(int client) {

	if((GetClientButtons(client) & IN_SCORE)) {
		return;
	}

	char info[256];
	char temp[256];
	if (TF2_GetClientTeam(client) == TFTeam_Red) {
		switch (perk[client]) {
			case 3: {
				if (leap_cd[client] > 0.0) {
					Format(info, 256, "[JUMP+ATTACK2] Burst: on cooldown (%.1f)\n", leap_cd[client]);
				} else {
					StrCat(info, 256, "[JUMP+ATTACK2] Burst: ready\n");
				}
			}
			case 4: {
				if (perk_cd[client] > 0.0) { // experimental - no need to show hud status for perk
					Format(info, 256, "[ATTACK3] Freezing hits: on cooldown (%.1f)\n", perk_cd[client]);
				} else {
					StrCat(info, 256, "[ATTACK3] Freezing hits: ready\n");
				}
			}
			case 5: {
				if (perk_cd[client] > 0.0) { // experimental - no need to show hud status for perk
					Format(info, 256, "[ATTACK3] Forceful hits: on cooldown (%.1f)\n", perk_cd[client]); //Blast shells
				} else {
					StrCat(info, 256, "[ATTACK3] Forceful hits: ready\n");
				}
			}
			case 7: {
				if (perk_cd[client] > 0.0) {
					Format(info, 256, "[ATTACK3] Sneak: on cooldown (%.1f)\n", perk_cd[client]);
				} else {
					StrCat(info, 256, "[ATTACK3] Sneak: ready\n");
				}
			}
			case 9: {
				if (jet_charges[client] > 0) {
					if (leap_cd[client] > 0.0) {
						Format(info, 256, "[JUMP+ATTACK2] Burst (%i): on cooldown (%.1f)\n", jet_charges[client], leap_cd[client]); // in between charges leap cooldown
					} else if (jet_charges[client] < 3) {
						Format(info, 256, "[JUMP+ATTACK2] Burst (%i): ready (%.1f)\n", jet_charges[client], perk_cd[client]); // burst ready, shows progress to next charge
					} else {
						Format(info, 256, "[JUMP+ATTACK2] Burst (%i): ready\n", jet_charges[client]); // burst ready, shows progress to next charge
					}
				} else {
					Format(info, 256, "[JUMP+ATTACK2] Burst: no charges (%.1f)\n", perk_cd[client]); // if has no charges
				}
			}
		}
	} else {
		if (frostbitten[client]) {
			Format(temp, 256, "[JUMP+ATTACK2] Leap: frostbitten\n", leap_cd[client]);
		} else if (leap_cd[client] > 0.0) {
			Format(temp, 256, "[JUMP+ATTACK2] Leap: on cooldown (%.1f)\n", leap_cd[client]);
		} else {
			Format(temp, 256, "[JUMP+ATTACK2] Leap: ready\n", leap_cd[client]);
		}
		StrCat(info, 256, temp);
		if (frostbitten[client]) {
			Format(temp, 256, "Second Leap: frostbitten\n", leap_cd[client]);
		}
		else if (second_leap_cd[client] > 0.0) {
			Format(temp, 256, "Second Leap: on cooldown (%.1f)\n", second_leap_cd[client]);
		} else {
			Format(temp, 256, "Second Leap: ready\n");
		}
		StrCat(info, 256, temp);
		int j_index = GetJuggernaut(client);
		int w_index = GetWarden(client);
		if (j_index > -1) {
			if (summon_cd[j_index] > 0.0) {
				Format(temp, 256, "[MEDIC] Summon: on cooldown (%.1f)\n", summon_cd[j_index]);
			} else if (seeker_temp[j_index] > 0) {
				Format(temp, 256, "[MEDIC] Summon: ready\n");
			} else {
				Format(temp, 256, "[MEDIC] Summon: no survivors nearby\n");
			}
			StrCat(info, 256, temp);
		} else if (w_index > -1) {
			if (summon_cd[JUGGERNAUTS + w_index] > 0.0) {
				Format(temp, 256, "[MEDIC] Summon: on cooldown (%.1f)\n", summon_cd[JUGGERNAUTS + w_index]);
			} else if (seeker_temp[JUGGERNAUTS + w_index] > 0) {
				Format(temp, 256, "[MEDIC] Summon: ready\n");
			} else {
				Format(temp, 256, "[MEDIC] Summon: no survivors nearby\n");
			}
			StrCat(info, 256, temp);
		}
	}
	SendHudMessage(client, 2, 0.005, 0.36, 0xFFFF00FF, 0xFFFFFFFF, 0, 0.0, 0.0, 5.0, 5.0, info);
}

/* HUD_ShowStatus()
** -------------------------------------------------------------------------- */
public void HUD_ShowStatus(int client) {

	if((GetClientButtons(client) & IN_SCORE)) {
		return;
	}
	
	char temp[256];
	char info[256];
	if (TF2_GetClientTeam(client) == TFTeam_Red) {
		if (perk_duration[client] > 0 || invis_duration[client] > 0 || invis_delay[client] > 0) {
			switch (perk[client]) {
				case 4: {
					Format(info, 256, "Freezing hits: %.1f\n", perk_duration[client]);
				}
				case 5: {
					Format(info, 256, "Forceful hits: %.1f\n", perk_duration[client]);
				}
				case 7: {
					if (invis_delay[client] > 0) {
						Format(info, 256, "Activation delay: %.1f\n", invis_delay[client]);
					} else {
						Format(info, 256, "Sneak: %.1f\nSpeed boost: %.1f\n", invis_duration[client], invis_duration[client]);
					}
				}
			}
		} else {
			if (perk[client] == 6) {
				Format(info, 256, "Damage boost: %i%s\n", (133 / (lone_wolf_nearby[client] + 1) - 100), "%%");
			}
		}
	} else {
		int j_index = GetJuggernaut(client);
		int w_index = GetWarden(client);
		if (j_index > -1) {
			Format(info, 256, "Breaker bonus damage: +%i\nSeeker temperature: %s\n", breaker_stacks[j_index] * 20, seeker_temps[seeker_temp[j_index]]);
		} else if (w_index > -1) {
			Format(info, 256, "Seeker temperature: %s\n", seeker_temps[seeker_temp[JUGGERNAUTS + w_index]]);
		}
	}
	if (slowed[client]) {
		Format(temp, 256, "Slow: %.1f\n", slow_duration[client]);
		StrCat(info, 256, temp);
	}
	if (frostbitten[client]) {
		Format(temp, 256, "Frostbite: %.1f\n", frostbite[client]);
		StrCat(info, 256, temp);
	}
	if (protection_end[client] > round_time) {
		Format(temp, 256, "Spawn protection: %i\n", protection_end[client] - round_time);
		StrCat(info, 256, temp);
	}
	SendHudMessage(client, 3, 0.005, 0.5, 0xFFFF00FF, 0xFFFFFFFF, 0, 0.0, 0.0, 5.0, 5.0, info);
}