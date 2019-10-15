# Voice Commands

This plugin adds voice commands that function like the "Take Cover!" and "Medic!" alerts. The default setup has 6 different voices each with 14 voice commands.

| Default voices | Default commands for menu 1 | Default commands for menu 2
| --- | --- | ---|
| Scientist | Follow me | Yes |
| Barney | I'm with you | No |
| Otis | Help | Cheer |
| Soldier | Run away | Hello |
| Bodyguard | Stop | Thanks |
| Gman | Taunt | You're welcome |
| | Chit-chat | Sorry |

Each command has its own sprite and a collection of sound clips that are chosen randomly. Monsters will react to the sound of your commands, and will follow/unfollow you if you use the "Follow me", "help" and "Stop" commands while looking at them. If you die, the only thing you can do is make death gurgles (there's a sprite for that, too).

All voices and commands are fully customizable. You can add, remove, or rearrange commands and voices as you see fit. Just don't remove or rename the "Follow me", "Help", or "Stop" commands if you want monster following to work.

Currently up to 4 different menus are supported, 2 are there by default.

# Usage

Say ".vc X" to open a command menu (where X = 1 or 2).  
Say ".vc global X" to open a command menu in global mode (everyone can hear you).  
Say ".vc voice" to select a different voice.  
Say ".vc pitch X" to change your voice pitch (where X = 1-255).  
Say ".vc vol X" to adjust all voice volumes (where X = 0-100).  

I recommend binding the ".vc 1" and ".vc 2" commands to keys (I use Z and X).

If you repeat ".vc X" before choosing a command, the menu will flip orders. This is so you don't have to stretch your index finger to reach the 5, 6, and 7 number keys.
If you repeat ".vc X" one more time, you will enter global mode. This is so you don't have to bind more than 2 keys for this plugin.

# CVars

```
as_command vc.delay 2.5
as_command vc.enable_global 1
as_command vc.enable_gain 1
as_command vc.global_gain 0
as_command vc.falloff 1.0
as_command vc.monster_reactions 1
as_command vc.use_sentences 1
as_command vc.debug 0
```

```vc.delay``` sets how long players have to wait (seconds) before using another command. Use this to prevent spam.  
```vc.enable_global``` enables/disables global commands which can be heard anywhere in the map.  
```vc.enable_gain``` amplifies voices by playing multiple overlapping sounds. Keep this on or else the default voices won't have equal volumes.  
```vc.global_gain``` adds extra gain to all sound files (0-6). Has no effect if gain is disabled.  
```vc.falloff``` adjusts how far non-global commands can be heard (2 = near, 1 = normal, 0.5 = far, 0 = global)  
```vc.monster_reactions``` enables monster responses to voice commands (e.g. follow player, detect noise).  
```vc.use_sentences``` controls the use of sentence lines. Set to 0 for maps that override the default sentences (as_command in map cfg)  
```vc.debug``` shows sound details in chat and plays files in order instead of randomly. Use this to test your own sounds.  

# Server impact

The default setup includes 59 custom sounds and 15 custom sprites. The total size of these files is 662 KB, which will take a little over a minute to download if you don't have fastdl set up. By disabling the Gman voice, the download is reduced to 206 KB.

In total, there are 456 sounds and 15 sprites that are precached when the plugin loads. In previous versions of Sven Co-op this would be unacceptable because the precache limit was around 512. As of SC 5.0, the precache limit has been increased to 8192, so this isn't an issue anymore. If needed, you can greatly reduce the amount of content that is precached by disabling some of the default voices.

# Known issues

- Sometimes a command will play multiple instances of a sound that are slightly off-sync. Set "enable_gain" to "0" in VoiceCommands.cfg to fix this. Note that sounds may be too quiet to hear if you do this.

- Sometimes sounds get mixed up on a dedicated server (you hear an alien sound when you try to say "yes"). Delete your server's soundcache (svencoop/maps/soundcache) and change the level to fix that.

- The sprites are kind of shitty and don't all make sense.

# Adding your own voice or command

1) Add a new entry to the [voices] list in VoiceCommands.cfg, let's call it "Billy" for example.
2) Create a new text file with the same name (case sensitive) in the "voices" directory ("Billy.txt")
3) Copy the contents of "Bodyguard.txt" into your new file.
4) At this point you can either erase all of sound file paths or edit them in place.

The format of each line is "Volume : File path". Volume can be a number between 0 and 6. 1 = default volume, 2 = double volume, 0.5 = half volume

To test your sound files, set "debug_mode" to "1" in VoiceCommands.cfg. This will play command sounds in order, and give you info for each sound you play.


### If you want to add a new command, follow these steps

1) Add a new entry to either [command_menu_1] or [command_menu_2] in VoiceCommands.cfg, let's call it "Stand on me"
   The format for commands is "Command name : Sprite file". The sprite file is what will display above player heads when you use the command.
2) Add your new command type (case sensitive) to every voice.txt in the "voices" folder.
3) For each voice, add new sound entries under your new command name. Example:
```
[Stand on me]
2 : voice_commands/barney/standonme1.ogg
4 : voice_commands/barney/standonme2.ogg
```
