//#include "../../ChatCommandManager"

//ChatCommandSystem::ChatCommandManager@ g_ChatCommands = null;

void PluginInit()
{
	g_Module.ScriptInfo.SetAuthor( "Drake \"w00tguy\" Hunter" );
	g_Module.ScriptInfo.SetContactInfo( "w00tguy123@gmail.com" );
	g_Module.ScriptInfo.SetContactInfo( "w00tguy123@gmail.com" );
	
	g_Hooks.RegisterHook( Hooks::Player::ClientSay, @ClientSay );
	//g_ChatCommands.AddCommand( ChatCommandSystem::ChatCommand( "!hurtclass", @ClientSay, true, 1 ) );
	//g_Hooks.RegisterHook( Hooks::Player::ClientDisconnect, @ClientDisconnect );
}

List<EHandle> g_bots;

void kickAllBots( CBasePlayer@ plr )
{	
	if ( g_bots.Length() == 0 ) {
		g_PlayerFuncs.SayTextAll(plr, "g_Bots is empty");
	} else {
		CBaseEntity@ test = g_bots.At(0);
		g_PlayerFuncs.SayTextAll(plr, "Kicking all bots... " + test.pev.netname);
	}
}

void addBot( CBasePlayer@ plr )
{
	/*
	const string szName = "Big_Faggot";
	edict_t@ pEdict = g_EngineFuncs.CreateFakeClient( szName );
	
	if ( pEdict !is null )
	{
		//CBaseEntity@ pEntity = g_EntityFuncs.Instance( pEdict );
		g_Game.AlertMessage( at_console, "Attempt to create player ent\n");
		Vector origin = Vector(800, 0, 100);
		Vector angles = Vector(0, 0, 0);
		CBaseEntity@ pEntity = g_EntityFuncs.Create( "player", origin, angles, true, pEdict );
		g_Game.AlertMessage( at_console, "Wow we made one\n");
		if ( pEntity !is null )
		{
			g_Game.AlertMessage( at_console, "Attempt to spawn player\n");
			//pEntity.Spawn();
			EHandle e = @pEntity;
			g_bots.PushTail(e);
			g_PlayerFuncs.SayTextAll(plr, "Adding bot " + szName);
		} else {
			g_PlayerFuncs.SayTextAll(plr, "CreateFakeClient failed to spawn");
		}
		g_Game.AlertMessage( at_console, "welp guess we're done here\n");
	}
	else
		g_PlayerFuncs.SayTextAll(plr, "CreateFakeClient failed");
	*/
}

HookReturnCode ClientSay( SayParameters@ pParams )
{
	CBasePlayer@ plr = pParams.GetPlayer();
	const CCommand@ pArguments = pParams.GetArguments();

	bool debug = true;
	
	if ( pArguments.ArgC() >= 2 )
	{
		if ( pArguments[0] == "/wbot" )
		{
			if ( pArguments[1] == "add" )
			{
				g_PlayerFuncs.SayTextAll(plr, "One w00tbot coming right up!");
				addBot(plr);
				
				return HOOK_HANDLED;
			}
			if ( pArguments[1] == "kall" )
			{
				kickAllBots(plr);
				
				return HOOK_HANDLED;
			}
		}
	}
	
	return HOOK_CONTINUE;
}