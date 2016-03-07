class Talker
{
	string name; // What you see in the voice selection menu
	dictionary phrases; // each value is a @Phrase
	
	Talker(string displayName) {
		name = displayName;
	}
}

class Phrase
{
	string soundFile;  // path to the sound clip
	string talkerId;   // voice this phrase belongs to
	string categoryId; // e.g. "follow" for the Follow me command
	float gain; 	   // 0 to 6, anything above 1.0 needs to be a whole number, anything between 0 and 1 is a percentage
	int id;			   // unique
	
	Phrase(string talker, string category, float gainVal, string filePath)
	{
		talkerId = talker;
		categoryId = category;
		gain = gainVal;
		soundFile = filePath;
	}
}

class CommandGroup
{
	string name;   // display/data name
	string sprite; // path to the displayed sprite
	int menu; 	   // which menu this command should appear on
	
	CommandGroup(string cmdName, string spritePath, int menuId)
	{
		name = cmdName;
		sprite = spritePath;
		menu = menuId;
	}
}

class PlayerState
{
	CTextMenu@ menu;
	string talker_id;  // voice this player is using
	int pitch; 		   // voice pitch adjustment (100 = normal, range = 1-1000)
	int lastChatMenu;  // if non-zero, player currently has a chat menu open
	int globalInvert;  // set to 1 when a chat menu was opened 3 times (inverse global state)
	string lastSample; // store the last soundFile played so we can stop it later
	uint lastChatTime; // time this player last used a voice command
	int lastPhraseId;
	
	void initMenu(CBasePlayer@ plr, TextMenuPlayerSlotCallback@ callback, bool destroyOldMenu)
	{
		destroyOldMenu = false; // Unregistering throws an error for whatever reason. TODO: Ask the big man why
		if (destroyOldMenu and @menu !is null and menu.IsRegistered()) {
			menu.Unregister();
			@menu = null;
		}
		CTextMenu temp(@callback);
		@menu = @temp;
	}
	
	void openMenu(CBasePlayer@ plr) 
	{
		if ( menu.Register() == false ) {
			g_Game.AlertMessage( at_console, "Oh dear menu registration failed\n");
		}
		menu.Open(10, 0, plr);
	}
}

dictionary g_talkers; // all the voice data
array<Phrase@> g_all_phrases; // for straight-forward precaching, duplicates the data in g_talkers
array<string> g_talkers_ordered; // used to display talkers/voices in the correct order
array<CommandGroup@> g_commands; // all of em
string command_menu_1_title = "Actions:";
string command_menu_2_title = "Responses:";

dictionary player_states; // persistent-ish player data, organized by steam-id or username if on a LAN server, values are @PlayerState
int g_sound_gain = 0; // apply gain to all sound clips if > 1
bool g_enable_gain = true;
bool g_monster_reactions = true;
bool g_enable_sprites = true;
uint g_command_delay = 2500;
bool debug_mode = false;
bool debug_log = false;
string default_voice = 'Scientist';
string plugin_path = 'scripts/plugins/voice_commands/';
// All possible sound channels we can use
array<SOUND_CHANNEL> channels = {CHAN_STATIC, CHAN_VOICE, CHAN_STREAM, CHAN_BODY, CHAN_ITEM, CHAN_NETWORKVOICE_BASE, CHAN_AUTO, CHAN_WEAPON};

void print(string text) { g_Game.AlertMessage( at_console, "VoiceCommands: " + text); }
void println(string text) { print(text + "\n"); }
void printSuccess() { g_Game.AlertMessage( at_console, "SUCCESS\n"); }

void PluginInit()
{
	g_Module.ScriptInfo.SetAuthor( "w00tguy" );
	g_Module.ScriptInfo.SetContactInfo( "w00tguy123 - forums.svencoop.com" );
	g_Hooks.RegisterHook( Hooks::Player::ClientSay, @ClientSay );	
	g_Hooks.RegisterHook( Hooks::Game::MapChange, @MapChange );
	
	loadConfig();		
	loadVoiceData();
}

void MapInit()
{
	g_Game.AlertMessage( at_console, "Precaching " + g_all_phrases.length() + " sounds and " + g_commands.length() + " sprites\n");
	
	for (uint i = 0; i < g_all_phrases.length(); i++)
		g_SoundSystem.PrecacheSound(g_all_phrases[i].soundFile);
		
	if (g_enable_sprites)
		for (uint i = 0; i < g_commands.length(); i++)
			g_Game.PrecacheModel(g_commands[i].sprite);
	
	// Reset temporary vars on map change
	array<string>@ states = player_states.getKeys();
	for (uint i = 0; i < states.length(); i++)
	{
		PlayerState@ state = cast< PlayerState@ >(player_states[states[i]]);
		state.lastChatTime = 0;
		state.lastChatMenu = 0;
		state.globalInvert = 0;
		state.lastSample = "";
		state.lastPhraseId = -1;
	}
}

HookReturnCode MapChange()
{
	// set all menus to null. Apparently this fixes crashes for some people:
	// http://forums.svencoop.com/showthread.php/43310-Need-help-with-text-menu#post515087
	array<string>@ stateKeys = player_states.getKeys();
	for (uint i = 0; i < stateKeys.length(); i++)
	{
		PlayerState@ state = cast<PlayerState@>( player_states[stateKeys[i]] );
		if (state.menu !is null)
			@state.menu = null;
	}
	return HOOK_CONTINUE;
}

enum parse_mode {
	PARSE_SETTINGS,
	PARSE_VOICES,
	PARSE_CMDS_1,
	PARSE_CMDS_2,
	PARSE_SPECIAL_CMDS,
}

void loadConfig()
{
	string dataPath = plugin_path + "VoiceCommands.cfg";
	File@ f = g_FileSystem.OpenFile( dataPath, OpenFile::READ );
	int parseMode = PARSE_SETTINGS;	
	
	if( f !is null && f.IsOpen() )
	{
		string line;
		while( !f.EOFReached() )
		{
			f.ReadLine( line );
			line.Trim();
			if (line.Length() == 0 or line[0] == '/')
				continue;
			if (line[0] == '/' and line[1] == '/') 
				continue; // ignore comments
				
			if (line == "[settings]") {
				parseMode = PARSE_SETTINGS;
				continue;
			}
			if (line == "[voices]") {
				parseMode = PARSE_VOICES;
				continue;
			}
			if (line == "[command_menu_1]") {
				parseMode = PARSE_CMDS_1;
				continue;
			}
			if (line == "[command_menu_2]") {
				parseMode = PARSE_CMDS_2;
				continue;
			}
			if (line == "[special_commands]") {
				parseMode = PARSE_SPECIAL_CMDS;
				continue;
			}
			
			if (parseMode == PARSE_SETTINGS)
			{
				array<string>@ settingValue = line.Split("=");
				if (settingValue.length() != 2) 
					continue;
				settingValue[0].Trim();
				settingValue[1].Trim();
				if (settingValue[0].Length() == 0 or settingValue[1].Length() == 0)
					continue;
				
				if (settingValue[0] == "default_voice")
					default_voice = settingValue[1];
				if (settingValue[0] == "command_menu_1_title")
					command_menu_1_title = settingValue[1];
				if (settingValue[0] == "command_menu_2_title")
					command_menu_2_title = settingValue[1];
				if (settingValue[0] == "enable_gain")
					g_enable_gain = atoi( settingValue[1] ) != 0;
				if (settingValue[0] == "monster_reactions")
					g_monster_reactions = atoi( settingValue[1] ) != 0;	
				if (settingValue[0] == "enable_sprites")
					g_enable_sprites = atoi( settingValue[1] ) != 0;
				if (settingValue[0] == "command_delay")
					g_command_delay = atoi( settingValue[1] );	
				if (settingValue[0] == "global_gain")
					g_sound_gain = atoi( settingValue[1] );	
				if (settingValue[0] == "debug_mode")
					debug_mode = atoi( settingValue[1] ) != 0;	
			}
			else if (parseMode == PARSE_VOICES)
			{
				g_talkers[line] = @Talker(line);
				g_talkers_ordered.insertLast(line);
				//g_Game.AlertMessage( at_console, "Got voice: '" + line + "'\n");
			}
			else if (parseMode == PARSE_CMDS_1 or parseMode == PARSE_CMDS_2 or parseMode == PARSE_SPECIAL_CMDS)
			{
				array<string>@ cmd_values = line.Split(":");
				if (cmd_values.length() != 2) 
					continue;
				cmd_values[0].Trim();
				cmd_values[1].Trim();
				if (cmd_values[0].Length() == 0 or cmd_values[1].Length() == 0)
					continue;
					
				CommandGroup c(cmd_values[0], cmd_values[1], 1);
				if (parseMode == PARSE_CMDS_2)
					c.menu = 2;
				else if (parseMode == PARSE_SPECIAL_CMDS)
					c.menu = 0;
					
				g_commands.insertLast(c);
				//g_Game.AlertMessage( at_console, "Got command: '" + c.name + " " + c.sprite + "'\n");
			}
			else
				g_Game.AlertMessage( at_console, "Uhhh, something's wrong with your .cfg, check the lines with [] in them" + "\n");
			
		}
	}
	else
		g_Game.AlertMessage( at_console, "Unable to open voice data file:\n" + dataPath + "\n");
}

void loadVoiceData()
{	
	array<string>@ voiceNames = g_talkers.getKeys();
	int phraseIdNum = 0;
	
	for (uint i = 0; i < voiceNames.length(); i++)
	{
		
		Talker@ talker = cast< Talker@ >( g_talkers[voiceNames[i]] );
		array<Phrase@>@ phrases;
		string groupName;
		
		string voicePath = plugin_path + "voices/" + talker.name + ".txt";
		File@ f = g_FileSystem.OpenFile( voicePath, OpenFile::READ );
		
		if( f !is null && f.IsOpen() )
		{
			string line;
			while( !f.EOFReached() )
			{
				f.ReadLine( line );			
				line.Trim();
				if (line.Length() == 0 or line[0] == '/')
					continue;

				if (line[0] == '[') // Command group name
				{
					int end = line.FindLastOf(']');
					groupName = line.SubString(1, end-1);
					if (talker !is null and talker.phrases.exists(groupName) == false) 
					{
						array<Phrase@> p;
						talker.phrases[groupName] = @p;
					}
					@phrases = cast< array<Phrase@>@ >( talker.phrases[groupName] );
				}
				else // Phrase
				{
					//if (line.Find)
					array<string>@ params = line.Split(":");
					params[0].Trim();
					params[1].Trim();
					if (talker !is null and phrases !is null and params.length() == 2)
					{						
						Phrase p(talker.name, groupName, atoi( params[0] ), params[1]);
						p.id = phraseIdNum++;
						phrases.insertLast( p );
						g_all_phrases.insertLast(@p);
					}
				}
				//g_Game.AlertMessage( at_console, line + "\n");
			}
		}
		else
			g_Game.AlertMessage( at_console, "Unable to open voice data file:\n" + voicePath + "\n");
		
		//g_Game.AlertMessage( at_console, "LOAD voice: '" + talker.name + "'\n");
	}
	
	
}

// Returns the monster that the player is looking directly at, if any.
CBaseMonster@ getMonsterLookingAt(CBasePlayer@ plr, float maxDistance)
{
	// Calculate position that the player is looking at
	Vector vec, vecDummy;
	g_EngineFuncs.AngleVectors( plr.pev.v_angle, vec, vecDummy, vecDummy );
	
	TraceResult tr;
	const Vector vecEyes = plr.pev.origin + plr.pev.view_ofs;
	g_Utility.TraceLine( vecEyes, vecEyes + ( vec * maxDistance ), dont_ignore_monsters, plr.edict(), tr );
	
	if ( tr.flFraction < 1.0 and tr.pHit !is null )
	{
		CBaseEntity@ hitEnt = g_EntityFuncs.Instance( tr.pHit );
		if ( hitEnt !is null and hitEnt.IsMonster() != 0 )
		{
			return cast<CBaseMonster@>(hitEnt);
		}
	}
	
	return null;
}

void triggerMonsterAction(CBaseMonster@ monster, CBasePlayer@ plr, string action)
{
	//CTalkMonster@ talkmon = cast<CTalkMonster@>(monster);
	if (action == 'Follow me' or action == 'Help') {
		monster.StartPlayerFollowing(plr);
	} else if (action == 'stop') {
		monster.StopPlayerFollowing(0);
	} else {
		//talkmon.IdleRespond();
		//talkmon.Talk(2.0f);
		
		//g_PlayerFuncs.SayTextAll(plr, "talk test");
	}
}

int g_idx = 0; // debug

// handles player voice chats
void voiceMenuCallback(CTextMenu@ menu, CBasePlayer@ plr, int page, const CTextMenuItem@ item)
{
	if (item is null or plr is null) {
		return;
	}

	PlayerState@ state = getPlayerState(plr);

	state.lastChatMenu = 0;	// return chat menu to normal order
	state.globalInvert = 0; // no inversion either
	
	// Check if player has waited long enough to use another command
	uint t = uint(g_EngineFuncs.Time()*1000); // Get server time in milliseconds
	uint delta = t - state.lastChatTime;
	if (delta < g_command_delay)
	{
		float waitTime = float(g_command_delay - delta) / 1000.0f;
		g_PlayerFuncs.SayText(plr, "Wait " + waitTime + " seconds before using another command.\n");
		return;
	}
	state.lastChatTime = t;
	
	// verify talker exists
	if (g_talkers.exists(state.talker_id) == false) {
		g_Game.AlertMessage( at_console, "Bad talker ID: " + state.talker_id + "\n");
		return;
	}
	
	string phraseId = item.szUserData;
	bool global = phraseId.Length() > 1 and phraseId[0] == 'G' and phraseId[1] == ':';
	if (global)
		phraseId = phraseId.SubString(2, phraseId.Length()-2);
	
	// get the selected voice and phrase group
	Talker@ talker = cast< Talker@ >(g_talkers[state.talker_id]);
	if (plr.pev.deadflag != DEAD_NO)
		phraseId = "Dead"; // players can't talk when they're dead, but they can gurgle a bit
		
	// verify phrase id exists for current voice
	if (talker.phrases.exists(phraseId) == false) {
		g_Game.AlertMessage( at_console, "Bad Phrase ID for " + state.talker_id + ": " + phraseId + "\n");
		return;
	}
	// Get the phrase group list
	array<Phrase@>@ phrases = cast< array<Phrase@>@ >(talker.phrases[phraseId]);
	
	// get a random sound clip from the selected phrase group
	int idx = Math.RandomLong(0, phrases.length()-1);
	
	// try not to repeat the last thing this player said
	if (phrases.length() > 1)
	{
		for (int i = 0; i < 10 and phrases[idx].id == state.lastPhraseId; i++) {
			idx = Math.RandomLong(0, phrases.length()-1);
		}
	}
	state.lastPhraseId = phrases[idx].id;
	
	// play in a linear order for debugging
	if (debug_mode)
	{
		idx = g_idx % phrases.length();
		g_idx += 1;
	}
	
	Phrase@ phrase = phrases[idx];
	
	// figure out the volume and gain for this sample
	uint gain = g_sound_gain;
	float vol = 1.0f;
	if (phrase.gain >= 1)
		gain += int(phrase.gain);
	if (phrase.gain < 1)
		vol = phrase.gain;
	if (gain > channels.length())
		gain = channels.length();
	
	if (!g_enable_gain)
		gain = 1;
	
	// Stop the last sound file in case its still playing
	if (state.lastSample.Length() > 0)
		for (uint i = 0; i < channels.length(); i++)
			g_SoundSystem.StopSound(plr.edict(), channels[i], state.lastSample, false);
	
	if (global) 
	{
		// play sound through a global entity so everyone can hear it
		string ambientName = "vc__" + phrase.soundFile;
		dictionary keyvalues;
		keyvalues["targetname"] = ambientName;
		keyvalues["message"] = phrase.soundFile;
		keyvalues["pitch"] = string(state.pitch);
		keyvalues["spawnflags"] = "49";
		keyvalues["playmode"] = "1";
		keyvalues["health"] = string(vol * 10);
		
		array<CBaseEntity@> ambients;
		for (uint g = 0; g < gain; g++)
			ambients.insertLast( g_EntityFuncs.CreateEntity( "ambient_generic", keyvalues, true ) );
		
		g_EntityFuncs.FireTargets(ambientName, null, null, USE_ON);
		
		// delete the entities we just created
		for (uint g = 0; g < ambients.length(); g++) 
			if (ambients[g] !is null)
				g_EntityFuncs.Remove(ambients[g]);
	}
	else
	{
		// play the sound locally, possibly on multiple channels to increase volume
		for (uint i = 0; i < gain; i++) {
			g_SoundSystem.PlaySound(plr.edict(), channels[i], phrase.soundFile, vol, 1.0f, 0, state.pitch, 0, true, plr.pev.origin);
		}
	}
	
	state.lastSample = phrase.soundFile;
	
	if (global)
		g_PlayerFuncs.SayTextAll(plr, "(voice) " + plr.pev.netname + ": " + phraseId + "\n");
	
	// Get the command sprite
	if (g_enable_sprites) {
		for (uint i = 0; i < g_commands.length(); i++)
			if (g_commands[i].name == phraseId)
				plr.ShowOverheadSprite(g_commands[i].sprite, 51.0f, (g_command_delay / 1000.0f));
	}
	
	
	
	// Monster reactions to sounds
	if (g_monster_reactions)
	{
		GetSoundEntInstance().InsertSound(4, plr.pev.origin, NORMAL_GUN_VOLUME, 0, plr); // let monsters respond to this sound
		
		CBaseMonster@ target = getMonsterLookingAt(plr, 512.0f);
		
		if ( target !is null ) // Looking at a monster that is within earshot
		{
			g_Scheduler.SetTimeout( "triggerMonsterAction", 1, @target, @plr, phraseId );
		}
	}
	
	if (debug_mode)
		g_PlayerFuncs.SayTextAll(plr, "Gain: " + gain + ", Volume: " + vol + ", Pitch: " + state.pitch + ", Sound File: " + phrase.soundFile + "\n");
}

// handles player voice selection
void voiceSelectCallback(CTextMenu@ menu, CBasePlayer@ plr, int page, const CTextMenuItem@ item)
{
	if (item is null or plr is null) {
		return;
	}
	PlayerState@ state = getPlayerState(plr);
	state.talker_id = item.szUserData;
	g_PlayerFuncs.SayText(plr, "Your voice has been set to " + item.szName + "\n");
}

// Will create a new state if the requested one does not exit
PlayerState@ getPlayerState(CBasePlayer@ plr)
{	
	string steamId = g_EngineFuncs.GetPlayerAuthId( plr.edict() );
	if (steamId == 'STEAM_ID_LAN') {
		steamId = plr.pev.netname;
	}
	
	if ( !player_states.exists(steamId) )
	{
		PlayerState state;
		state.talker_id = default_voice;
		state.lastChatMenu = 0;
		state.globalInvert = 0;
		state.pitch = 100;
		state.lastChatTime = 0;
		player_states[steamId] = state;
	}
	return cast<PlayerState@>( player_states[steamId] );
}

void openChatMenu(PlayerState@ state, CBasePlayer@ plr, int menuId, bool global)
{
	state.initMenu(plr, voiceMenuCallback, state.lastChatMenu != 0);
	
	string menuTitle = (menuId == 1) ? command_menu_1_title : command_menu_2_title;
	if (state.lastChatMenu < 0)
		global = !global;
	if (global)
		menuTitle = "(Global) " + menuTitle;
	state.menu.SetTitle(menuTitle + "\n");
	string menuDataPrefix = global ? "G:" : ""; // G: prefix means we want this sound to be global
	if (state.lastChatMenu == menuId)
	{
		// show chat commands in reverse order (so you don't have to stretch your index finger for 5, 6, and 7)
		for (int i = int(g_commands.length() - 1); i >= 0; i--)
			if (g_commands[i].menu == menuId)
				state.menu.AddItem(g_commands[i].name, menuDataPrefix + g_commands[i].name);
		state.lastChatMenu = -menuId;
	}
	else if (state.lastChatMenu == -menuId) // inverse global mode
	{
		// show chat commands in normal order, but with global mode inverted
		if (state.globalInvert == 1) {
			for (int i = int(g_commands.length() - 1); i >= 0; i--)
				if (g_commands[i].menu == menuId)
					state.menu.AddItem(g_commands[i].name, menuDataPrefix + g_commands[i].name);
			state.globalInvert = 0;
			state.lastChatMenu = 0;
		} else {
			for (int i = 0; i < int(g_commands.length()); i++)
				if (g_commands[i].menu == menuId)
					state.menu.AddItem(g_commands[i].name, menuDataPrefix + g_commands[i].name);
			state.globalInvert = 1;
		}
	}
	else
	{
		// show chat commands in normal order
		for (int i = 0; i < int(g_commands.length()); i++)
			if (g_commands[i].menu == menuId)
				state.menu.AddItem(g_commands[i].name, menuDataPrefix + g_commands[i].name);
		state.lastChatMenu = menuId;
		state.globalInvert = 0;
	}

	state.openMenu(plr);
}

HookReturnCode ClientSay( SayParameters@ pParams )
{	
	CBasePlayer@ plr = pParams.GetPlayer();
	const CCommand@ args = pParams.GetArguments();
	
	PlayerState@ state = getPlayerState(plr);
	
	if ( args.ArgC() > 0 )
	{
		if ( args[0] == "/vc" )
		{
			if ( args[1] == "1" || args[1] == "2" )
			{
				openChatMenu(state, plr, args[1] == "1" ? 1 : 2, false);
				
				pParams.ShouldHide = true;
				return HOOK_HANDLED;
			}
			if ( args[1] == 'global' and args.ArgC() > 2 and (args[2] == "1" || args[2] == "2") )
			{
				openChatMenu(state, plr, args[2] == "1" ? 1 : 2, true);
				
				pParams.ShouldHide = true;
				return HOOK_HANDLED;
			}
			if ( args[1] == "voice" )
			{
				state.initMenu(plr, voiceSelectCallback, state.lastChatMenu != 0);
				
				state.menu.SetTitle("Voice selection:\n");
				
				// show a list of all voices
				for (uint i = 0; i < g_talkers_ordered.length(); i++)
					state.menu.AddItem(g_talkers_ordered[i], g_talkers_ordered[i]);
				
				state.openMenu(plr);
				state.lastChatMenu = 0;	
				state.globalInvert = 0;
				
				pParams.ShouldHide = true;
				return HOOK_HANDLED;
			}
			if ( args[1] == "pitch" and args.ArgC() > 2 )
			{		
				int newPitch = atoi( args[2] );
				if (newPitch < 1)
					newPitch = 1;
				if (newPitch > 1000)
					newPitch = 1000;
					
				g_PlayerFuncs.SayText(plr, "Your voice pitch has been set to " + newPitch + "\n");
				
				state.pitch = newPitch;
				
				pParams.ShouldHide = true;
				return HOOK_HANDLED;
			}
			pParams.ShouldHide = true;
			g_PlayerFuncs.SayText(plr, "Voice command usage:\n");
			g_PlayerFuncs.SayText(plr, 'Say "/vc X" top open a command menu (where X = 1 or 2).\n');
			g_PlayerFuncs.SayText(plr, 'Say "/vc global X" to open a command menu in global mode (everyone can hear you across the map).\n');
			g_PlayerFuncs.SayText(plr, 'Say "/vc voice" to select a different voice.\n');
			g_PlayerFuncs.SayText(plr, 'Say "/vc pitch X" to change your voice pitch (where X = 1-1000).\n');
			return HOOK_HANDLED;
		}
		
	}
	return HOOK_CONTINUE;
}