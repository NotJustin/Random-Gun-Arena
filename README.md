# Random Gun Arena
 A variant of Gun Game. Inspired by this thread: https://forums.alliedmods.net/showthread.php?t=313378 and thanks to CliptonHeist<br>
 At the end of a round, a random gun is chosen, to be given to all players at the start of the following round.<br>
 When a player kills another player, they receive full health and armor(depending on if there is armor for the current weapon).<br>

In addons/sourcemod/configs/rga/weapons.txt you can edit a lot of things.

1. Edit the "weight" of the gun, which is how likely it is to be selected randomly.
2. Edit the sound that will play when the gun is chosen. By default, the sounds are done by someone we paid on fiver to read the names of the guns. If you want to remove the voices, set the sound to be ""
3. Edit the armor that players will have when given this gun. 0 = no armor, 1 = body armor, 2 = body + head armor.
4. Override the weights of all of the weapons in the weapon group and set them to the override value. "-1.0" means do not override.
5. Override the armor that will be given to players in the weapon group and set them to the override value. "-1" means do not override.
6. Remove guns from being used, by just removing their entry from weapons.txt

Currently, the plugin forces all weapons to be used at least once before you can see another weapon used again. This makes weights kind of pointless. See plans ->

Plans:
1. Add option to remove "N" previous weapons (includes ALL).
2. Add option to remove "N" previous weapon-groups (includes ALL).
