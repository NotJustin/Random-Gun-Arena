# Random Gun Arena
 A variant of Gun Game. Inspired by this thread: https://forums.alliedmods.net/showthread.php?t=313378 and thanks to CliptonHeist (The Doggy) for the original plugin and inspiration<br>
 At the end of a round, a random gun is chosen, to be given to all players at the start of the following round.<br>
 When a player kills another player, they receive full health and armor(depending on if there is armor for the current weapon).<br>

https://www.youtube.com/watch?v=1aTuJrlZKjA

### Changelog

```
1.0.1 - 
Fixed sounds not working.
Added hint text and ConVar to play sound when hint text stops changing. (See video above)
```

### ConVars

```
rga_removetype (int | min 0 max 2 default 2)
"0 = Do not remove any weapons from pool. 1 = rga_removepreviousweapons. 2 = rga_removepreviousgroups. You cannot do both"

rga_removepreviousweapons (int | default 0)
"Max is 36. Number of weapons that must pass before most recent weapon can be repeated. You can write 'all' instead of 36"

rga_removepreviousgroups (int | default 1)
"Max is 7. Number of groups that must pass before most recent group can be repeated. You can write 'all' instead of 7."

rga_printdamagemessages (bool | default 1)
"When a client dies or survives to end of round, print the damage they dealt, received, and healed to chat"

rga_playnextweaponsound (bool | default 1)
"When the next weapon is chosen, a voice will read the name of the weapon" 
```

### Installation

gameserver goes on your csgo server. move the addons and sound folders into your csgo folder.<br>
fastdl goes on your web server.

### Configuration

In addons/sourcemod/configs/rga/weapons.txt you can edit a lot of things.

1. Edit the "weight" of the gun, which is how likely it is to be selected randomly.
2. Edit the sound that will play when the gun is chosen. By default, the sounds are done by someone we paid on fiver to read the names of the guns. If you want to remove the voices, set the sound to be ""
3. Edit the armor that players will have when given this gun. 0 = no armor, 1 = body armor, 2 = body + head armor.
4. Override the weights of all of the weapons in the weapon group and set them to the override value. "-1.0" means do not override.
5. Override the armor that will be given to players in the weapon group and set them to the override value. "-1" means do not override.
6. Remove guns from being used, by just removing their entry from weapons.txt

### Bugs
none atm
