/* Colorize()
** -------------------------------------------------------------------------- */
/* Credit to pheadxdll for invisibility code, taken from rtd plugin */
stock void Colorize(int client, int color[4]) {
	int maxents = GetMaxEntities();
	// Colorize player and weapons
	int m_hMyWeapons = FindSendPropInfo("CBasePlayer", "m_hMyWeapons");

	for(int i = 0, weapon; i < 47; i += 4) {
		weapon = GetEntDataEnt2(client, m_hMyWeapons + i);

		if (weapon > -1 ) {
			char strClassname[250];
			GetEdictClassname(weapon, strClassname, sizeof(strClassname));
			if(StrContains(strClassname, "tf_weapon") == -1) continue;

			SetEntityRenderMode(weapon, RENDER_TRANSCOLOR);
			SetEntityRenderColor(weapon, color[0], color[1], color[2], color[3]);
		}
	}

	SetEntityRenderMode(client, RENDER_TRANSCOLOR);
	SetEntityRenderColor(client, color[0], color[1], color[2], color[3]);

	// Colorize any wearable items
	for(int i = MaxClients + 1; i <= maxents; i++)
	{
		if(!IsValidEntity(i)) continue;

		char netclass[32];
		GetEntityNetClass(i, netclass, sizeof(netclass));

		if(strcmp(netclass, "CTFWearableItem") == 0 || strcmp(netclass, "CTFWearableItem")) {
			if(GetEntDataEnt2(i, g_wearableOffset) == client) {
				SetEntityRenderMode(i, RENDER_TRANSCOLOR);
				SetEntityRenderColor(i, color[0], color[1], color[2], color[3]);
			}
		} else if(strcmp(netclass, "CTFWearableItemDemoShield") == 0) {
			if(GetEntDataEnt2(i, g_shieldOffset) == client) {
				SetEntityRenderMode(i, RENDER_TRANSCOLOR);
				SetEntityRenderColor(i, color[0], color[1], color[2], color[3]);
			}
		}
	}

	if(TF2_GetPlayerClass(client) == TFClass_Spy)
	{
		int iWeapon = GetEntPropEnt(client, Prop_Send, "m_hDisguiseWeapon");
		if(iWeapon && IsValidEntity(iWeapon))
		{
			SetEntityRenderMode(iWeapon, RENDER_TRANSCOLOR);
			SetEntityRenderColor(iWeapon, color[0], color[1], color[2], color[3]);
		}
	}
}

/* ChangeClientTeam_Safe()
** -------------------------------------------------------------------------- */
stock void ChangeClientTeam_Safe(int client, TFTeam team) {
	int EntProp = GetEntProp(client, Prop_Send, "m_lifeState");
	SetEntProp(client, Prop_Send, "m_lifeState", 2);
	TF2_ChangeClientTeam(client, team);
	SetEntProp(client, Prop_Send, "m_lifeState", EntProp);
}

/* AttachParticle()
** -------------------------------------------------------------------------- */
stock void AttachParticle(int entity, char[] particle, float time)
{
	int particleEnt = CreateEntityByName("info_particle_system");

	if (!IsValidEntity(particleEnt))
	{
		return;
	}

	float position[3];
	GetEntPropVector(entity, Prop_Send, "m_vecOrigin", position);
	TeleportEntity(particleEnt, position, NULL_VECTOR, NULL_VECTOR);

	char name[32];
	GetEntPropString(entity, Prop_Data, "m_iName", name, sizeof(name));

	DispatchKeyValue(particleEnt, "targetname", "tf2particle");
	DispatchKeyValue(particleEnt, "parentname", name);
	DispatchKeyValue(particleEnt, "effect_name", particle);
	DispatchSpawn(particleEnt);

	SetVariantString("!activator");
	AcceptEntityInput(particleEnt, "SetParent", entity, particleEnt, 0);

	ActivateEntity(particleEnt);
	AcceptEntityInput(particleEnt, "start");

	CreateTimer(time, DeleteParticle, EntIndexToEntRef(particleEnt));
}


/* DeleteParticle()
** -------------------------------------------------------------------------- */
public Action DeleteParticle(Handle timer, int particleEnt)
{
	if (EntRefToEntIndex(particleEnt) != INVALID_ENT_REFERENCE)
	{
		AcceptEntityInput(particleEnt, "Kill");
	}
}

/* WinRound()
** -------------------------------------------------------------------------- */
public void WinRound(int team)
{
	int ent = FindEntityByClassname(-1, "game_round_win");
	if (ent == -1)
	{
		ent = FindEntityByClassname(-1, "team_control_point_master");
		if (ent == -1)
		{
			ent = CreateEntityByName("team_control_point_master");
			DispatchSpawn(ent);
			AcceptEntityInput(ent, "Enable");
		}
		SetVariantInt(team);
		AcceptEntityInput(ent, "SetWinner");
		return;
	}
	SetVariantInt(team);
	AcceptEntityInput(ent, "SetTeam");
	AcceptEntityInput(ent, "RoundWin");
}

/* IsAdmin()
** -------------------------------------------------------------------------- */
public bool IsAdmin(int iClient)
{
	if (GetAdminFlag(GetUserAdmin(iClient), Admin_Generic))
	{
		return true;
	}

	return false;
}

/* IsValidClient()
** -------------------------------------------------------------------------- */
stock bool IsValidClient(int iClient, bool bNoBots = true)
{
	if (iClient <= 0 || iClient > MaxClients || !IsClientConnected(iClient)/* || (bNoBots && IsFakeClient(iClient))*/)
	{
		return false;
	}
	return IsClientInGame(iClient);
}

stock bool IsWeaponSlotActive(int iClient, int iSlot)
{
    return GetPlayerWeaponSlot(iClient, iSlot) == GetEntPropEnt(iClient, Prop_Send, "m_hActiveWeapon");
}