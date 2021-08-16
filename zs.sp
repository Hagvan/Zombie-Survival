#pragma semicolon 1

#define DEBUG

#define PLUGIN_AUTHOR "Hagvan"
#define PLUGIN_VERSION "1.11"

#define JUGGERNAUTS 3
#define WARDENS 2
#define MAX_TF_CLIENTS 33
#define RES_MUL 0.13
#define PERKS 10
#define ROUND_DURATION 230

#include <sourcemod>
#include <sdktools>
#include <tf2>
#include <tf2_stocks>
#include <entity.inc>
#include <sdkhooks>
#include <easy_hudmessage>
#include <dbi>

#pragma newdecls required

#pragma semicolon 1

public Plugin myinfo =  {
	name = "Medic vs Engineer",
	author = PLUGIN_AUTHOR,
	description = "Hagvan's version of Medic vs Engineer gamemode.",
	version = PLUGIN_VERSION,
	url = ""
};

bool main_timer;
int round_time = -30;
bool waiting = true;

bool toMedic[MAX_TF_CLIENTS];
int wasMedic[MAX_TF_CLIENTS];
int m_max = 0;
int start_medics = 0;

//Juggernaut

int juggernauts = 0;
int wardens = 0;

int juggernaut[JUGGERNAUTS];
int resistance[JUGGERNAUTS];
bool need_jug[JUGGERNAUTS];
int breaker_target[JUGGERNAUTS];
int breaker_stacks[JUGGERNAUTS];

int warden[WARDENS]; // list of current wardens
bool need_warden[WARDENS];
int summon_priority[MAX_TF_CLIENTS]; // determine which medics should be summonable first
int last_spawn = 0;

int seeker_temp[JUGGERNAUTS + WARDENS]; // 0-2 - juggernauts, 3-4 - wardens
char seeker_temps[][] = {"Cold", "Cool", "Warm", "Hot"};
float summon_cd[JUGGERNAUTS + WARDENS];

// Convars
ConVar g_convar_respawntime;

int protection_end[MAX_TF_CLIENTS]; // Medic spawn protection

char perks_names[][] = {"Default", "Berserk", "Empowered", "Jetpack" , "Freezer", "Pusher", "Lone Wolf",
						"Sneaky Pardner", "Texas Style", "Battery Jetpack"};
int perk[MAX_TF_CLIENTS];
int selected_perk[MAX_TF_CLIENTS];
int confirmed_perk[MAX_TF_CLIENTS];
float perk_duration[MAX_TF_CLIENTS];
float perk_cd[MAX_TF_CLIENTS];
int lone_wolf_nearby[MAX_TF_CLIENTS];
float invis_duration[MAX_TF_CLIENTS];
float invis_delay[MAX_TF_CLIENTS];
bool invis_interrupted[MAX_TF_CLIENTS];
#define INVIS	{255,255,255,0}
#define NORMAL	{255,255,255,255}
int g_wearableOffset, g_shieldOffset;

bool ignore_deaths = false;

int LastButtons[MAX_TF_CLIENTS];
int TimerLastButtons[MAX_TF_CLIENTS];
int AfkCounter[MAX_TF_CLIENTS]; // detecting afk players
int activity[MAX_TF_CLIENTS]; // detecting "friendly" medics
int reports[MAX_TF_CLIENTS]; // medics can report the lats juggernaut/warden who teleported them
int last_teleporter[MAX_TF_CLIENTS]; // index of the client who last teleported the reporter
float report_timeout[MAX_TF_CLIENTS]; // time before the option to report expires or timespan that auto-report can trigger

// Leap
float leap_cd[MAX_TF_CLIENTS]; // leap cooldown, used for jetpack too
float second_leap_cd[MAX_TF_CLIENTS]; // secondary leap
bool leaping[MAX_TF_CLIENTS]; // if player currently in a middle of a leap
int leap_ticks[MAX_TF_CLIENTS]; // counting the time the player is in the leap
int jet_charges[MAX_TF_CLIENTS]; // used by battery jetpack exclusively

float speed_modifier[MAX_TF_CLIENTS]; // setting the speed of a player
bool slowed[MAX_TF_CLIENTS]; // used by freezer to slow medics and leap slow debuff
float slow_duration[MAX_TF_CLIENTS]; // duration of the slow
bool frostbitten[MAX_TF_CLIENTS]; // is the player frostbitten (prevents leaping and freezes cooldowns)
float frostbite[MAX_TF_CLIENTS]; // duration of the frostbite

float damageForceZero[3]; // used for cleave

// Database

int perk_count[PERKS]; // used for round statistics
bool started_as_engie[MAX_TF_CLIENTS]; // should the player performance be tracked and saved?
int round_steam_id[MAX_TF_CLIENTS]; // storing the steam id of the player
int round_perk[MAX_TF_CLIENTS]; // saves the perk client started the round with

// all entries are as engineer only
int score[MAX_TF_CLIENTS]; // score accumulated during the round (total rate of round performace)
int kills[MAX_TF_CLIENTS]; // total medic kills during the round (5 score bounty)
int jug_kills[MAX_TF_CLIENTS]; // total juggernaut kills (20 score bounty)
int warden_kills[MAX_TF_CLIENTS]; // total warden kills (20 score bounty)
int survived_time[MAX_TF_CLIENTS]; // total time survived (first 2 min - +1 score, rest - +2 score per second)
float recent_damage[MAX_TF_CLIENTS]; // did medic deal damage recently
float recently_damaged[MAX_TF_CLIENTS]; // did medic get shot (and hit) recently

bool inserting; // used to prevent duplicates
bool get_rank_cooldown[MAX_TF_CLIENTS]; // used to prevent database abuse

#include "zs/stocks.sp"
#include "zs/sounds.sp"
#include "zs/hud.sp"
#include "zs/menus.sp"
#include "zs/timers.sp"
#include "zs/commandlisteners.sp"
#include "zs/commands.sp"
#include "zs/events.sp"
#include "zs/database.sp"

/* OnPluginStart()
** -------------------------------------------------------------------------- */
public void OnPluginStart() {
	// Database connection
	SQL_ConnectDatabase();
	// Hooks
	HookEvent("player_death", Event_OnPlayerDeath);
	HookEvent("post_inventory_application", Event_OnInventory);
	HookEvent("player_spawn", Event_PlayerSpawn);
	HookEvent("teamplay_round_start", Event_OnRoundStart);
	HookEvent("teamplay_round_active", Event_OnRoundActive);
	HookEvent("player_team", Event_OnPlayerTeam, EventHookMode_Pre);
	HookEvent("teamplay_setup_finished", Event_OnSetupFinished);
	HookEvent("player_builtobject", Event_BuiltObject);
	
	// Command Listeners
	RegConsoleCmd("jointeam", CommandListener_JoinTeam);
	RegConsoleCmd("joinclass", CommandListener_JoinClass);
	RegConsoleCmd("autoteam", CommandListener_AutoTeam);
	RegConsoleCmd("build", CommandListener_Build);
	RegServerCmd("changelevel", CommandListener_ChangeLevel);

	// Commands
	RegConsoleCmd("zs_perks", Command_Perks);
	RegConsoleCmd("zs_rank", Command_GetRank);

	AddCommandListener(Listener_Voice, "voicemenu");

	for (int i = 1; i <= 33; i++) {
		if (IsClientValid(i)) {
			SDKHook(i, SDKHook_OnTakeDamage, OnTakeDamage);
			SDKHook(i, SDKHook_PreThinkPost, Hook_PreThinkPost);
		}
	}

	CreateTimer(1.0, Timer_Afk_Counter, _, TIMER_REPEAT);
	CreateTimer(1.0, Timer_Activity_Counter, _, TIMER_REPEAT);

	g_wearableOffset = FindSendPropInfo("CTFWearableItem", "m_hOwnerEntity");
	g_shieldOffset = FindSendPropInfo("CTFWearableItemDemoShield", "m_hOwnerEntity");

	//Convars
	g_convar_respawntime = CreateConVar("sm_zs_respawntime", "3.0", "Respawn time for dead medics");
}

/* OnMapStart()
** -------------------------------------------------------------------------- */
public void OnMapStart() {
	main_timer = false;
	
	PrecacheSounds();
}

/* OnClientPutInServer()
** -------------------------------------------------------------------------- */
public void OnClientPutInServer(int client) {
	SDKHook(client, SDKHook_OnTakeDamage, OnTakeDamage);
	SDKHook(client, SDKHook_PreThinkPost, Hook_PreThinkPost);

	if(IsAdmin(client))
	{
		return;
	}

	//wasMedic[client] = round_time > 120 ? m_max : m_max - 1;
	
	wasMedic[client] = m_max; // experimental
	
	LogAction(-1, -1, "A client joined, m_max = %i", wasMedic[client]);
	
	confirmed_perk[client] = 0; // fix for invulnerable engie glitch
	
	protection_end[client] = -30;
	
	if (round_time < 0) { // if round did not start yet
		int medics = 0;
		for (int i = 1; i <= MaxClients; i++) {
			if (IsValidClient(i) && TF2_GetClientTeam(i) == TFTeam_Blue) {
				medics++;
			}
		}
		if (medics >= start_medics) { // if there are less than 5 medics, put player as engineer before round starts
			TF2_SetPlayerClass(client, TFClass_Engineer);
			TF2_ChangeClientTeam(client, TFTeam_Red);
			Menu_ShowPerk(client);
			return;
		}
	}
	TF2_SetPlayerClass(client, TFClass_Medic);
	TF2_ChangeClientTeam(client, TFTeam_Blue);
	
	SQL_GetPlayerRankOnJoin(client);
}

/* Hook_PreThinkPost()
** -------------------------------------------------------------------------- */
public void Hook_PreThinkPost(int client) {
	float newspeed;
	if (!IsClientConnected(client)) {
		return;
	}
	switch (TF2_GetPlayerClass(client)) {
		case TFClass_Engineer: {
			newspeed = 300 * (speed_modifier[client] / 100);
		}
		case TFClass_Medic: {
			newspeed = 320 * (speed_modifier[client] / 100);
		}
	}
	if (perk[client] == 7 && invis_duration[client] > 0) {
		newspeed *= 1.2;
	}
	/*if (perk[client] == 8) { // texas style used to have a speed boost built into the perk, now it can be brough back by using the wrangler
		newspeed *= 1.2;
	}*/
	if (newspeed > 520.0) {
		newspeed = 520.0;
	}
	if (newspeed < 100.0) {
		newspeed = 100.0;
	}
	SetEntPropFloat(client, Prop_Data, "m_flMaxspeed", newspeed);
}

/* OnTakeDamage()
** -------------------------------------------------------------------------- */
public Action OnTakeDamage(int victim, int & attacker, int & inflictor, float & damage, int & damagetype, int & weapon, float damageForce[3], float damagePosition[3], int damagecustom) {
	if (attacker < 1 || attacker > MaxClients)
		return Plugin_Continue;

	if (protection_end[victim] > round_time) {
		//PrintToChat(victim, "Protecc: %i, time: %i", protection_end[victim], round_time);
		damage = 0.0;
		return Plugin_Changed;
	}

	activity[attacker] = 0; // reset activity counter to 0 for damage dealer

	if (leaping[attacker]) {
		PlaySound("LeapHit", attacker);
		if (TF2_GetClientTeam(attacker) == TFTeam_Blue) {
			
			speed_modifier[victim] -= leap_ticks[attacker] * 2.75;
			damage *= 1 + leap_ticks[attacker] * 0.05;
			KnockBack(attacker, victim, damage / 2);
			if (!(damageForce[0] == 0.0 || damageForce[1] == 0.0 || damageForce[2] == 0.0)) { // if not splash damage, do the splash
				float victim_pos[3];
				GetClientAbsOrigin(victim, victim_pos);
				TFTeam enemy_team = TF2_GetClientTeam(victim);
				float pos[3];
				for (int i = 1; i <= MaxClients; i++) {
					if (i != victim && IsClientInGame(i) && TF2_GetClientTeam(i) == enemy_team && IsPlayerAlive(i)) {
						GetClientAbsOrigin(i, pos);
						int distance = RoundToNearest(GetVectorDistance(victim_pos, pos, false));
						if (distance < 120 && distance > 0) {
							//PrintToChatAll("distance = %i, splash: %f", distance, damage - damage * (distance / 120.0));
							//SDKHooks_TakeDamage(i, attacker, inflictor, damage - damage * (distance / 120.0), damagetype, weapon, damageForceZero, damagePosition);
							SDKHooks_TakeDamage(i, attacker, inflictor, damage, damagetype, weapon, damageForceZero, damagePosition);
						}
					}
				}
			}
			if (!slowed[victim]) {
				slowed[victim] = true;
				slow_duration[victim] = leap_ticks[attacker] * 0.45;
				CreateTimer(0.1, Timer_Slow, victim, TIMER_REPEAT);
			} else {
				slow_duration[victim] += leap_ticks[attacker] * 0.45;
			}
			HUD_ShowStatus(victim);
		} else if (GetEntPropEnt(attacker, Prop_Send, "m_hActiveWeapon") == GetPlayerWeaponSlot(attacker, 2)) {
			damage *= 1 + leap_ticks[attacker] * 0.30;
			if (!(damageForce[0] == 0.0 || damageForce[1] == 0.0 || damageForce[2] == 0.0)) { // if not splash damage, do the splash
				float victim_pos[3];
				GetClientAbsOrigin(victim, victim_pos);
				TFTeam enemy_team = TF2_GetClientTeam(victim);
				float pos[3];
				for (int i = 1; i <= MaxClients; i++) {
					if (i != victim && IsClientInGame(i) && TF2_GetClientTeam(i) == enemy_team && IsPlayerAlive(i)) {
						GetClientAbsOrigin(i, pos);
						int distance = RoundToNearest(GetVectorDistance(victim_pos, pos, false));
						if (distance < 120 && distance > 0) {
							//PrintToChatAll("distance = %i, splash: %f", distance, damage - damage * (distance / 120.0));
							//SDKHooks_TakeDamage(i, attacker, inflictor, damage - damage * (distance / 120.0), damagetype, weapon, damageForceZero, damagePosition);
							SDKHooks_TakeDamage(i, attacker, inflictor, damage, damagetype, weapon, damageForceZero, damagePosition);
						}
					}
				}
			}
		}
	}
	int w_index = GetWarden(victim);
	if (w_index > -1 && summon_cd[JUGGERNAUTS + w_index] < 10.0) {
		summon_cd[JUGGERNAUTS + w_index] = 10.0; // warden cd resets completely after taking damage
	}
	int j_index = GetJuggernaut(victim);
	if (j_index > -1) { // is victim is juggernaut, also make sure the attack is not from behind. Attacks from behind ignore resistance.
		if (summon_cd[j_index] < 5.0) {
			summon_cd[j_index] = 5.0; // juggernaut has shorter penalty for taking damage
		}
		switch (perk[attacker]) {
			case 1: {
				float f_damage = damage;
				float penetrated = f_damage * 0.3;
				f_damage -= penetrated;
				damage = f_damage * (1 - resistance[j_index] * RES_MUL) + penetrated;
			}
			case 2: {
				damage = (damage * 0.5) * (1 - resistance[j_index] * RES_MUL);
			}
			case 4: {
				if (perk_duration[attacker] > 0) {
					speed_modifier[victim] -= damage * 0.5;
					if (!slowed[victim]) {
						slowed[victim] = true;
						slow_duration[victim] = 3.0;
						CreateTimer(0.1, Timer_Slow, victim, TIMER_REPEAT);
					} else {
						slow_duration[victim] = 3.0;
					}
					if (!frostbitten[victim]) {
						if (speed_modifier[victim] < 75.0) {
							frostbitten[victim] = true;
							frostbite[victim] = 12.0;
							CreateTimer(0.1, Timer_Frostbite, victim, TIMER_REPEAT);
						}
					} else {
						frostbite[victim] = 12.0;
					}
					HUD_ShowStatus(victim);
				}
				damage = (damage * 0.6) * (1 - resistance[j_index] * RES_MUL);
			}
			case 5: {
				if (perk_duration[attacker] > 0) { // experimental - no more need for activation, might make it toggle later
				KnockBack(attacker, victim, damage);
				}
				damage = (damage * 0.6) * (1 - resistance[j_index] * RES_MUL);
			}
			case 6: {
				damage *= 1.35;
				if (lone_wolf_nearby[attacker]) {
					damage /= 2 * lone_wolf_nearby[attacker];
				}
				damage = damage * (1 - resistance[j_index] * RES_MUL);
			}
			case 7: {
				if (IsFromBehind(attacker, victim)) {
					damage *= 2; // sneaky pardner deals double damage from behind, also ignores resistance
				} else {
					damage = damage * (1 - resistance[j_index] * RES_MUL);
				}
			}
			case 8: {
				if (IsWeaponSlotActive(attacker, 2)) {
					damage *= 1.5; // +50% melee and bleed damage for melee
				}
				/*if (damage > 30.0 && !(damageForce[0] == 0.0 || damageForce[1] == 0.0 || damageForce[2] == 0.0)) { // if not bleed or splash damage, do the splash
					float victim_pos[3];
					GetClientAbsOrigin(victim, victim_pos);
					TFTeam enemy_team = TF2_GetClientTeam(victim); // will always be medic
					float pos[3];
					for (int i = 1; i <= MaxClients; i++) {
						if (i != victim && IsClientInGame(i) && TF2_GetClientTeam(i) == enemy_team && IsPlayerAlive(i)) {
							GetClientAbsOrigin(i, pos);
							int distance = RoundToNearest(GetVectorDistance(victim_pos, pos, false));
							if (distance < 120 && distance > 0) {
								//PrintToChatAll("distance = %i, splash: %f", distance, damage - damage * (distance / 120.0));
								//SDKHooks_TakeDamage(i, attacker, inflictor, damage - damage * (distance / 120.0), damagetype, weapon, damageForceZero, damagePosition);
								SDKHooks_TakeDamage(i, attacker, inflictor, damage, damagetype, weapon, damageForceZero, damagePosition);
							}
						}
					}
				}*/
				damage = damage * (1 - resistance[j_index] * RES_MUL); // reduce the damage to juggernaut according to resist
			}
			default: {
				damage = damage * (1 - resistance[j_index] * RES_MUL);
			}
		}
	} else if (TF2_GetClientTeam(victim) == TFTeam_Blue) { // is regular zombie
		switch (perk[attacker]) {
			case 1: {
				damage = damage * 0.6;
			}
			case 2: {
				damage = damage * 1.3;
			}
			case 4: {
				if (perk_duration[attacker] > 0) {
					speed_modifier[victim] -= damage * 0.6;
					if (!slowed[victim]) {
						slowed[victim] = true;
						slow_duration[victim] = 3.0;
						CreateTimer(0.1, Timer_Slow, victim, TIMER_REPEAT);
					} else {
						slow_duration[victim] = 3.0;
					}
					if (!frostbitten[victim]) {
						if (speed_modifier[victim] < 50) {
							frostbitten[victim] = true;
							if (recent_damage[victim] > 0.0) {
								score[attacker] += 5; // reward for slowing and frostbitting a medic who is dealing damage
								HUD_ShowStatus(attacker);
							}
							frostbite[victim] = 15.0;
							CreateTimer(0.1, Timer_Frostbite, victim, TIMER_REPEAT);
						}
					} else {
						frostbite[victim] = 15.0;
					}
					HUD_ShowStatus(victim);
				}
				damage = damage * 0.7;
			}
			case 5: {
				if (perk_duration[attacker] > 0) { // - experimental
				KnockBack(attacker, victim, damage);
				}
				damage = damage * 0.7;
			}
			case 6: {
				damage *= 1.35;
				if (lone_wolf_nearby[attacker]) {
					damage /= 2 * lone_wolf_nearby[attacker];
				}
			}
			case 7: {
				if (IsFromBehind(attacker, victim)) {
					damage *= 2; // sneaky pardner deals double damage from behind
				}
			}
			case 8: {
				if (IsWeaponSlotActive(attacker, 2)) {
					damage *= 1.5; // +50% melee and bleed damage for melee
				}
				/*if (damage > 30.0 && !(damageForce[0] == 0.0 || damageForce[1] == 0.0 || damageForce[2] == 0.0)) { // if not bleed or splash damage, do the splash
					float victim_pos[3];
					GetClientAbsOrigin(victim, victim_pos);
					TFTeam enemy_team = TF2_GetClientTeam(victim); // will always be medic
					float pos[3];
					for (int i = 1; i <= MaxClients; i++) {
						if (i != victim && IsClientInGame(i) && TF2_GetClientTeam(i) == enemy_team && IsPlayerAlive(i)) {
							GetClientAbsOrigin(i, pos);
							int distance = RoundToNearest(GetVectorDistance(victim_pos, pos, false));
							if (distance < 120 && distance > 0) {
								//PrintToChatAll("distance = %i, splash: %f", distance, damage - damage * (distance / 120.0));
								//SDKHooks_TakeDamage(i, attacker, inflictor, damage - damage * (distance / 120.0), damagetype, weapon, damageForceZero, damagePosition);
								SDKHooks_TakeDamage(i, attacker, inflictor, damage, damagetype, weapon, damageForceZero, damagePosition);
							}
						}
					}
				}*/
			}
		}
	} else { // victim is engineer
		if (perk[victim] == 7) {
			if (invis_duration[victim] > 0.0) {
				invis_duration[victim] -= 3.0; // invis perk nerf #1 (lose duration if take damage from medic)
				HUD_ShowStatus(victim);
			} else if (perk_cd[victim] < 3.0) {
				perk_cd[victim] = 3.0; // invis perk nerf #2 (on hit can't activate for 3 seconds)
				HUD_ShowCooldowns(victim);
			}
			if (invis_delay[victim] > 0.0) {
				invis_interrupted[victim] = true;
				invis_delay[victim] = 0.0;
				HUD_ShowStatus(victim);
				PrintToChat(victim, "Invisibility activation was interrupted!");
			}
		}
	}
	if (recent_damage[attacker] <= 0.0) {
		CreateTimer(0.1, Timer_Recent_Damage, attacker, TIMER_REPEAT);
	}
	recent_damage[attacker] = 3.0;
	if (recently_damaged[victim] <= 0.0) {
		CreateTimer(0.1, Timer_Recently_Damaged, victim, TIMER_REPEAT);
	}
	recently_damaged[victim] = 3.0;
	//place for perks
	return Plugin_Changed;
}

/* OnTakeDamageBuilding()
** -------------------------------------------------------------------------- */
public Action OnTakeDamageBuilding(int victim, int & attacker, int & inflictor, float & damage, int & damagetype, int & weapon, float damageForce[3], float damagePosition[3], int damagecustom) {
	if(IsValidClient(attacker)) {
		activity[attacker] = 0; // reset activity counter for damage dealer
		if (recent_damage[attacker] <= 0.0) {
			CreateTimer(0.1, Timer_Recent_Damage, attacker, TIMER_REPEAT);
		}
		recent_damage[attacker] = 3.0;
	}

	int j_index = GetJuggernaut(attacker);
	if (j_index > -1) {
		if (victim == breaker_target[j_index]) {
			damage += breaker_stacks[j_index] * 20;
			breaker_stacks[j_index]++;
		} else {
			breaker_target[j_index] = victim;
			breaker_stacks[j_index] /= 2;
			damage += breaker_stacks[j_index] * 20;
			breaker_stacks[j_index]++;
		}
	}
	
	return Plugin_Changed;
}

/* ForceWin()
** -------------------------------------------------------------------------- */
public void ForceWin(int team) {
	//LogAction(-1, -1, "Forcing a win");
	main_timer = false;
	WinRound(team);
	int players = 0;
	for (int i = 1; i <= MaxClients; i++) {
		if (IsValidClient(i) && TF2_GetClientTeam(i) != TFTeam_Unassigned && TF2_GetClientTeam(i) != TFTeam_Spectator) {
			players++;
		}
	}
	if (players >= 16 && ROUND_DURATION - round_time >= 0 && !inserting) {
		SQL_InsertRound(1);
	}
}

/* ToMedic()
** -------------------------------------------------------------------------- */
public Action ToMedic(Handle timer, int client) {
	ChangeClientTeam_Safe(client, TFTeam_Blue);
	TF2_SetPlayerClass(client, TFClass_Medic);
	perk[client] = 0;

	// Try to find any remaining Engineers
	for (int i = 1; i <= MaxClients; i++) {
		if (IsValidClient(i) && TF2_GetClientTeam(i) == TFTeam_Red && client != i) {
			CreateTimer(0.3, Timer_Respawn, client);
			return;
		}
	}
	//LogAction(-1, -1, "All the engies died.");
	RequestFrame(ForceWin, TFTeam_Blue);
}

/* TF2_OnWaitingForPlayersStart()
** -------------------------------------------------------------------------- */
public void TF2_OnWaitingForPlayersStart() {
	//LogAction(-1, -1, "Waiting for players begins.");
	waiting = true;
}

/* TF2_OnWaitingForPlayersEnd()
** -------------------------------------------------------------------------- */
public void TF2_OnWaitingForPlayersEnd() {
	//LogAction(-1, -1, "Waiting for players end.");
	waiting = false;
}

/* ApplyJuggernautBuffs()
** -------------------------------------------------------------------------- */
public void ApplyJuggernautBuffs(int index) {
	resistance[index] = 0;
	seeker_temp[index] = 0;
	float jug_pos[3];
	GetEntPropVector(juggernaut[index], Prop_Send, "m_vecOrigin", jug_pos);
	float pos[3];
	for (int i = 1; i <= MaxClients; i++) {
		if (!IsValidClient(i)) continue;
		if (TF2_GetClientTeam(i) == TFTeam_Blue && IsPlayerAlive(i) && i != juggernaut[index]) {
			GetEntPropVector(i, Prop_Send, "m_vecOrigin", pos);
			int distance = RoundToNearest(GetVectorDistance(jug_pos, pos, false));
			if (distance <= 1000) {
				if (++resistance[index] == 5) return;
			}
		}
	}
}

public void ApplySeeker(int index, bool is_warden) {
	float pos[3];
	float temp_pos[3];
	GetClientAbsOrigin(is_warden ? warden[index] : juggernaut[index], pos);
	if (is_warden) {
		index += JUGGERNAUTS;
	}
	seeker_temp[index] = 0;
	for (int i = 1; i <= MaxClients; i++) {
		if (!IsValidClient(i)) {
			continue;
		}
		if (TF2_GetClientTeam(i) == TFTeam_Red && IsPlayerAlive(i)) {
			if (seeker_temp[index] == 3) { // if already max
				break;
			}
			GetClientAbsOrigin(i, temp_pos);
			int distance = RoundToNearest(GetVectorDistance(pos, temp_pos, false));
			if (distance < 300) {
				seeker_temp[index] = 3; // 3 = hot
			} else if (distance >= 300 && distance < 600 && seeker_temp[index] < 3) {
				seeker_temp[index] = 2; // 2 = warm
			} else if (distance >= 600 && distance < 900 && seeker_temp[index] < 2) {
				seeker_temp[index] = 1; // 1 = cool
			} else if (distance >= 900 && seeker_temp[index] < 1) {
				seeker_temp[index] = 0; // 0 = cold
			}
		}
	}
}

/* OnPlayerRunCmd()
** -------------------------------------------------------------------------- */
public Action OnPlayerRunCmd(int client, int &buttons, int &impulse, float vel[3], float angles[3], int &weapon, int &subtype, int &cmdnum, int &tickcount, int &seed, int ATTACK[2]) {
	int flags = GetEntityFlags(client);
	if (!(flags & FL_ONGROUND) && !(LastButtons[client] & IN_ATTACK2) && buttons & IN_ATTACK2) {
		if (TF2_GetClientTeam(client) == TFTeam_Blue) { // is medic
			if (leaping[client]) {
				if (!frostbitten[client] && second_leap_cd[client] <= 0.0) {
					second_leap_cd[client] = 34.0;
					Leap(client, angles);
					HUD_ShowCooldowns(client);
				}
			} else {
				if (!frostbitten[client] && leap_cd[client] <= 0.0) {
					leaping[client] = true; // set the client leapting status to true
					leap_ticks[client] = 0; // reset the leap timer
					leap_cd[client] = 15.0;
					if (second_leap_cd[client] > 0.0) {
						second_leap_cd[client] = 45.0;
					}
					Leap(client, angles);
					HUD_ShowCooldowns(client); // update client's hud cooldown immediately
					CreateTimer(0.1, Timer_Leaping, client, TIMER_REPEAT); // start counting leap ticks
				}
			}
		} else if (perk[client] == 3 && leap_cd[client] <= 0.0) { // if engineer with regular jetpack
			leap_cd[client] = 15.0;
			leap_ticks[client] = 0;
			leaping[client] = true;
			Leap(client, angles);
			CreateTimer(0.1, Timer_Leaping, client, TIMER_REPEAT); // start counting leap ticks
		} else if (perk[client] == 9 && leap_cd[client] <= 0.0 && jet_charges[client] > 0) { // if engineer with regular jetpack
			leap_cd[client] = 3.0;
			if (jet_charges[client]-- >= 3) {
				perk_cd[client] = 30.0;
			}
			leap_ticks[client] = 0;
			leaping[client] = true;
			Leap(client, angles);
			CreateTimer(0.1, Timer_Leaping, client, TIMER_REPEAT); // start counting leap ticks
		}
	}

	/*if (leap_cd[client] <= 0.0 && TF2_GetClientTeam(client) == TFTeam_Blue && !(flags & FL_ONGROUND) && !(LastButtons[client] & IN_ATTACK2) && buttons & IN_ATTACK2) {  //Leap
		leap_cd[client] = 7.0;
		Leap(client, angles);
	} else if (perk[client] == 3 && leap_cd[client] <= 0 && !(flags & FL_ONGROUND) && !(LastButtons[client] & IN_ATTACK2) && buttons & IN_ATTACK2) {  //IN_ATTACK2
		leap_cd[client] = 14.0;
		Leap(client, angles);
	}*/

	if (!(LastButtons[client] & IN_ATTACK3) && buttons & IN_ATTACK3) {
		switch (TF2_GetClientTeam(client)) {
			case TFTeam_Red: {
				switch (perk[client]) {
					case 4: { // experimental
						if (perk_cd[client] <= 0.0) {
							perk_cd[client] = 30.0;
							perk_duration[client] = 10.0;
							HUD_ShowCooldowns(client);
							HUD_ShowStatus(client);
						}
					}
					case 5: {
						if (perk_cd[client] <= 0.0) {
							perk_cd[client] = 30.0;
							perk_duration[client] = 10.0;
							HUD_ShowCooldowns(client);
							HUD_ShowStatus(client);
						}
					}
					case 7: {
						if (perk_cd[client] <= 0.0 && invis_delay[client] <= 0.0) {
							invis_delay[client] = 1.5;
							HUD_ShowCooldowns(client);
							HUD_ShowStatus(client);
							CreateTimer(0.1, Timer_Invis_Delay, client, TIMER_REPEAT);
						}
					}
				}
			}
		}
	}

	if (invis_duration[client] > 0 && !(LastButtons[client] & IN_ATTACK3) && buttons & IN_ATTACK) {
		invis_duration[client] = 0.0;
		HUD_ShowCooldowns(client);
		HUD_ShowStatus(client);
	}

	LastButtons[client] = buttons;
}

/* KnockBack()
** -------------------------------------------------------------------------- */
public void KnockBack(int attacker, int victim, float damage) {
	if (damage < 35) {
		return;
	}
	float current[3];
	GetEntPropVector(victim, Prop_Data, "m_vecVelocity", current); // get victim's current velocity
	float angles[3];
	GetClientAbsAngles(attacker, angles); // get attackers angles
	float direction[3]; // getting knockback direction
	if (angles[0] > -15.0) {
		angles[0] = -15.0;
	}
	GetAngleVectors(angles, direction, NULL_VECTOR, NULL_VECTOR);
	angles[0] = -angles[0];
	ScaleVector(direction, damage * 30.0);
	//PrintToChatAll("%.1f, %.1f, %.1f", angles[0], angles[1], angles[2]);
	current[0] = direction[0];
	current[1] = direction[1];
	current[2] = direction[2];
	//PrintToChatAll("%.1f, %.1f, %.1f", direction[0], direction[1], direction[2]);
	float vpos[3];
	GetClientAbsOrigin(victim, vpos);
	vpos[2] += 0.1; // lifting the medic up a bit in order for knockback to work
	TeleportEntity(victim, vpos, NULL_VECTOR, current);
	
	if (recent_damage[victim] > 0.0) {
		score[attacker] += 5; // reward for pushing away a medic who is dealing damage
		HUD_ShowStatus(attacker);
	}
}

/* Leap()
** -------------------------------------------------------------------------- */
public void Leap(int client, float angles[3]) {
	if (TF2_GetClientTeam(client) == TFTeam_Blue) {
		/*float pos[3];
		float user_pos[3];
		GetEntPropVector(client, Prop_Send, "m_vecOrigin", user_pos);
		for (int i = 1; i <= MaxClients; i++) { // add leap cooldown to all medics nearby if their leap is ready
			if (IsClientInGame(i) && TF2_GetClientTeam(i) == TFTeam_Blue && IsPlayerAlive(i)) {
				GetEntPropVector(i, Prop_Send, "m_vecOrigin", pos);
				int distance = RoundToNearest(GetVectorDistance(user_pos, pos, false));
				if (distance <= 500 && leap_cd[i] < 1.0) {
					leap_cd[i] = 1.0;
					HUD_ShowCooldowns(i);
				}
			}
		}*/
		int j_index = GetJuggernaut(client);
		if (j_index > -1 && summon_cd[j_index] < 5.0) {
			summon_cd[j_index] = 5.0;
		}
		int w_index = GetWarden(client);
		if (w_index > -1 && summon_cd[JUGGERNAUTS + w_index] < 10.0) {
			summon_cd[JUGGERNAUTS + w_index] = 10.0; // it could be without if, keeping it like that in case I'll want to change cooldown again
		}
	}

	float current[3];  // leap itself
	GetEntPropVector(client, Prop_Data, "m_vecVelocity", current);
	float direction[3];
	GetAngleVectors(angles, direction, NULL_VECTOR, NULL_VECTOR);
	angles[0] = -angles[0];
	if (angles[0] >= -20 && angles[0] <= 20.0) { // horizontal leap
		direction[2] = (200.0 / 750) + ((angles[0] + 20) / 200);
		ScaleVector(direction, 750.0);
	} else if (angles[0] > 20.0 && angles[0] <= 50.0) { // balanced leap
		direction[2] = 500.0 / 750;
		ScaleVector(direction, 750.0);
	} else if (angles[0] > 50) { // vertial leap
		direction[2] = 615.0 / 450;
		ScaleVector(direction, 450.0);
	} else { // dive leap
		ScaleVector(direction, 1000.0);
		direction[2] /= 1.65;
	}
	current[0] = direction[0];  // apply the leap velocity
	current[1] = direction[1];
	current[2] = direction[2];
	TeleportEntity(client, NULL_VECTOR, NULL_VECTOR, current);
	AttachParticle(client, (TF2_GetClientTeam(client) == TFTeam_Red ? "burningplayer_red" : "burningplayer_blueglow"), 1.5);
}

public void Summon(int client, bool is_warden) {
	float origin[3];
	float angles[3];
	GetClientAbsOrigin(client, origin);
	GetClientAbsAngles(client, angles);
	//PrintToChatAll("%s %s", is_warden ? "Warden" : "Juggernaut", "used summon");
	int to_summon = is_warden ? 3 : 1;
	int summoned = 0;
	//int to_summon = 2; // now juggernaut and warden summon only 2 medics
	int offset = 0;
	int flags = 0;
	while (to_summon > 0 && offset < MAX_TF_CLIENTS) {
		for (int i = 1; i < MAX_TF_CLIENTS; i++) {
			if (IsValidClient(i) && IsPlayerAlive(i) && i != client && TF2_GetClientTeam(i) == TFTeam_Blue && summon_priority[i] == last_spawn - offset) {
				flags = GetEntityFlags(i);
				//PrintToChatAll("%b %b %b %b", flags & FL_ONGROUND, flags & FL_INWATER, recent_damage[i] > 0.0, recently_damaged[i] > 0.0);
				if (!(flags & FL_ONGROUND || flags & FL_INWATER) || recent_damage[i] > 0.0 || recently_damaged[i] > 0.0) {
					break;
				}
				TeleportEntity(i, origin, angles, NULL_VECTOR);
				to_summon--;
				summoned++;
				last_teleporter[i] = client;
				report_timeout[i] = 10.0;
				CreateTimer(0.1, Timer_Report, i, TIMER_REPEAT);
			}
		}
		offset++;
	}
	/*char deb[300];
	char temp[10];
	for (int i = 1; i < MAX_TF_CLIENTS; i++) {
		Format(temp, 300, "%i ", summon_priority[i]);
		StrCat(deb, 300, temp);
	}
	PrintToChatAll(deb);*/
	if (summoned == 0) {
		return;
	}
	summon_cd[is_warden ? JUGGERNAUTS + GetWarden(client) : GetJuggernaut(client)] = is_warden ? 20.0 : 40.0;  // warden now has 2 times less cooldown
	//summon_cd[is_warden ? JUGGERNAUTS + GetWarden(client) : GetJuggernaut(client)] = 2.0;
	for (int i = 0; i < JUGGERNAUTS; i++) {
		if (juggernaut[i] > 0 && IsPlayerAlive(juggernaut[i])) {
			ApplyJuggernautBuffs(i);
			HUD_ShowInfo(juggernaut[i]);
			HUD_ShowCooldowns(juggernaut[i]);
		}
	}
}

/* UpdateCooldowns()
** -------------------------------------------------------------------------- */
public void UpdateCooldowns() {
	for (int i = 1; i <= MaxClients; i++) {
		if (leap_cd[i] > 0) leap_cd[i] -= 0.1;
		if (second_leap_cd[i] > 0) second_leap_cd[i] -= 0.1;
		if (perk_cd[i] > 0) {
			perk_cd[i] -= 0.1;
		} else if (perk[i] == 9 && jet_charges[i] < 3) {
			jet_charges[i]++;
			perk_cd[i] = 20.0;
		}
		if (perk_duration[i] > 0) perk_duration[i] -= 0.1;
	}
	for (int i = 0; i < JUGGERNAUTS + WARDENS; i++) {
		if (summon_cd[i] > 0) summon_cd[i] -= 0.1;
	}
}

public int GetJuggernaut(int client) { // returns index of juggernaut if true, -1 if not juggernaut
	if (!IsValidClient(client) || !IsClientInGame(client)) {
		return -1;
	}
	for (int i = 0; i < JUGGERNAUTS; i++) {
		if (juggernaut[i] == client) {
			return i;
		}
	}
	return -1;
}

public int GetWarden(int client) { // returns index of warden if true, -1 if not warden
	if (!IsValidClient(client) || !IsClientInGame(client)) {
		return -1;
	}
	for (int i = 0; i < WARDENS; i++) {
		if (warden[i] == client) {
			return i;
		}
	}
	return -1;
}

public bool IsFromBehind(int attacker, int victim) {
	float attacker_angles[3];
	GetClientAbsAngles(attacker, attacker_angles);
	float victim_angles[3];
	GetClientAbsAngles(victim, victim_angles);
	
	float result = FloatAbs(attacker_angles[1] - victim_angles[1]);
	
	return result < 75;
}