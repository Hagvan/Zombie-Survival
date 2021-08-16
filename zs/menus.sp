/* Menu_ShowPerk()
** -------------------------------------------------------------------------- */
public void Menu_ShowPerk(int client) {
	Menu menu = CreateMenu(MenuHandler_ShowPerk, MENU_ACTIONS_DEFAULT);
	SetMenuTitle(menu, "Choose your perk");
	SetMenuPagination(menu, 5);
	AddMenuItem(menu, "0", "Default\n[+] No downsides\n[-] No upsides", ITEMDRAW_DEFAULT);
	AddMenuItem(menu, "1", "Berserk\n[+] 30% of your damage ignore juggernaut's resistance\n[-] -40% damage vs regular medics", ITEMDRAW_DEFAULT);
	AddMenuItem(menu, "2", "Empowered\n[+] +30% damage vs regular medics\n[-] -50% damage vs juggernaut", ITEMDRAW_DEFAULT);
	AddMenuItem(menu, "3", "Jetpack\n[ATTACK2] Leap like a medic\n[-] Can't build", ITEMDRAW_DEFAULT);
	AddMenuItem(menu, "4", "Freezer\n[+] Damage slows medics and can frostbite (prevent leaping)\n[-] -30% damage", ITEMDRAW_DEFAULT);
	AddMenuItem(menu, "5", "Pusher\n[+] Damage launches medics in the direction you are looking\n[-] -30% damage", ITEMDRAW_DEFAULT);
	AddMenuItem(menu, "6", "Lone Wolf\n[+] +35% damage\n[-] You lose 1/2 of your damage per engineer nearby", ITEMDRAW_DEFAULT);
	AddMenuItem(menu, "7", "Sneaky Pardner\n[ATTACK3] Can turn invisible and deals double damage from behind\n[-] Can't build", ITEMDRAW_DEFAULT);
	AddMenuItem(menu, "8", "Texas Style\n[+] +50% melee damage and bleed\n[-] No primary weapon", ITEMDRAW_DEFAULT);
	AddMenuItem(menu, "9", "Battery Jetpack\n[*] Like Jetpack\n[+] Stores up to 3 charges\n[-] Double cooldown.", ITEMDRAW_DEFAULT);
	DisplayMenu(menu, client, 30);
}

/* MenuHandler_ShowPerk()
** -------------------------------------------------------------------------- */
public int MenuHandler_ShowPerk(Menu menu, MenuAction action, int client, int choice) {
	switch (action) {
		case MenuAction_Select: {
			selected_perk[client] = choice;
			HUD_ShowInfo(client);
			Menu_ConfirmPerk(client);
		}
	}
}

/* Menu_ShowPerk()
** -------------------------------------------------------------------------- */
public void Menu_ConfirmPerk(int client) {
	Menu menu = CreateMenu(MenuHandler_ConfirmPerk, MENU_ACTIONS_DEFAULT);
	SetMenuTitle(menu, "Confirm choice?");
	SetMenuPagination(menu, 5);
	AddMenuItem(menu, "0", "Yes", ITEMDRAW_DEFAULT);
	AddMenuItem(menu, "1", "No", ITEMDRAW_DEFAULT);
	DisplayMenu(menu, client, 30);
}

/* MenuHandler_ShowPerk()
** -------------------------------------------------------------------------- */
public int MenuHandler_ConfirmPerk(Menu menu, MenuAction action, int client, int choice) {
	switch (action) {
		case MenuAction_Select: {
			switch (choice) {
				case 0: {
					confirmed_perk[client] = selected_perk[client];
				}
				case 1: {
					selected_perk[client] = 0;
					Menu_ShowPerk(client);
				}
			}
			HUD_ShowInfo(client);
		}
	}
}