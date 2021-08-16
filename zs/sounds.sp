/* PrecacheSounds()
** -------------------------------------------------------------------------- */
stock void PrecacheSounds() {
	// Mysterious Start Sounds
	char mysterious[64];
	for (int i = 1; i <= 16; i++) {
		Format(mysterious, sizeof(mysterious), "ambient/halloween/mysterious_perc_0%i.wav", i);
		PrecacheSound(mysterious);
	}

	// Nope sounds
	PrecacheSound("vo/engineer_no01.mp3");
	PrecacheSound("vo/engineer_no02.mp3");
	PrecacheSound("vo/engineer_no03.mp3");

	// Leap Hit
	PrecacheSound("player/doubledonk.wav");
}

/* PrecacheSounds()
** -------------------------------------------------------------------------- */
stock void PlaySound(char[] soundName, int client = 0) {
	if(client == 0) {
		if (StrEqual(soundName, "RoundStart")) {
			char mysterious[64];
			Format(mysterious, sizeof(mysterious), "ambient/halloween/mysterious_perc_0%i.wav", GetRandomInt(1, 16));
			EmitSoundToAll(mysterious);
		}
	} else {
		if(StrEqual(soundName, "Forbid")) {
			switch(GetRandomInt(1, 3)) {
				case 1: {EmitSoundToClient(client, "vo/engineer_no01.mp3");}
				case 2: {EmitSoundToClient(client, "vo/engineer_no02.mp3");}
				case 3: {EmitSoundToClient(client, "vo/engineer_no03.mp3");}
			}
		}

		if(StrEqual(soundName, "LeapHit")) {
			EmitSoundToAll("player/doubledonk.wav", client);
		}
	}
}