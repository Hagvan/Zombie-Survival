/**
** Created by horr0rjkee
** Thanks for Alex(tracker) for ColorHexToRGB function! Wiki link: https://wiki.alliedmods.net/User_messages
** Date: 18 July 2014
*/
#if defined easy_hud_message
	#endinput
#endif
#define easy_hud_message
/**
 * Return colors from HEX to RGB format.
 *
 * @param color		HEX color with transparent (Example: 0xFF00FFFF - Fully red color). Get any color from colorpicker.com.
 * @param outr		Red color.
 * @param outg		Green color.
 * @param outb		Blue color.
 * @param outalpha	Transparent.
 * @return			1 or 0.			
 */
stock bool:ColorHexToRGB(color, &outr, &outg, &outb, &outalpha) { //by Alex (Tracker)
	outr=(color & 0xFF000000)>>>24;
	outg=(color & 0x00FF0000)>>16;
	outb=(color & 0x0000FF00)>>8;
	outalpha=color & 0x000000FF;
	return true;
}
/**
 * Prints hud message to player
 *
 * @param client		Client index.
 * @param channel		Channel index (Only 1 channel can write message).
 * @param posx			Position x on monitor (-1.0 = center).
 * @param posy			Position y on monitor (-1.0 = center).
 * @param color1		First color in HEX.
 * @param color2		Second color in HEX.
 * @param effect		Effect index (0 is fade in/fade out; 1 is flickery credits; 2 is write out).
 * @param fadetime		FadeIn time.
 * @param fadeouttime	FadeOut time.
 * @param holdtime		Hold time.
 * @param fxtime		Effect time (Effect type 2 used)
 * @param message		Message
 * @param ...			Variable number of format parameters.
 * @return				1 or 0.	
 */
stock bool:SendHudMessage(client,channel=3,Float:posx=-1.0, Float:posy=-1.0,color1,color2,effect=0,Float:fadetime=1.0,Float:fadeouttime=1.0,Float:holdtime=1.5,Float:fxtime=5.0,const String:message[],any:...)
{
	if(client == 0 || !IsClientConnected(client) || effect < 0 || fadetime < 0.0 || fadeouttime < 0.0 || holdtime < 0.0 || fxtime < 0.0) return false;
	new String:buffer[256];
	SetGlobalTransTarget(client);
	VFormat(buffer, sizeof(buffer), message, 13);
	new Handle:hBf = StartMessageOne("HudMsg", client), rgb[4];
	BfWriteByte(hBf, channel); //channel
	BfWriteFloat(hBf, posx); // x ( -1 = center )
	BfWriteFloat(hBf, posy); // y ( -1 = center )
	// second color
	ColorHexToRGB(color1, rgb[0], rgb[1], rgb[2], rgb[3]);
	BfWriteByte(hBf, rgb[0]); //r1
	BfWriteByte(hBf, rgb[1]); //g1
	BfWriteByte(hBf, rgb[2]); //b1
	BfWriteByte(hBf, rgb[3]); //a1 // transparent?
	// init color
	ColorHexToRGB(color2, rgb[0], rgb[1], rgb[2], rgb[3]);
	BfWriteByte(hBf, rgb[0]); //r2
	BfWriteByte(hBf, rgb[1]); //g2
	BfWriteByte(hBf, rgb[2]); //b2
	BfWriteByte(hBf, rgb[3]); //a2
	BfWriteByte(hBf, effect); //effect (0 is fade in/fade out; 1 is flickery credits; 2 is write out)
	BfWriteFloat(hBf, fadetime); //fadeinTime (message fade in time - per character in effect 2)
	BfWriteFloat(hBf, fadeouttime); //fadeoutTime
	BfWriteFloat(hBf, holdtime); //holdtime
	BfWriteFloat(hBf, fxtime); //fxtime (effect type(2) used)
	BfWriteString(hBf, buffer); //Message
	EndMessage();
	return true;
}