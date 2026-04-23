## Relays count-increase signals so [card_table.gd] can keep a running total as pieces are spawned.
extends Node3D

@warning_ignore_start("unused_signal")
## Emitted when a new elephant is spawned. 
## Listened to by [card_table.gd] to update the total elephant count.
signal increase_total_Elephant
## Emitted when a new villager is spawned. 
## Listened to by [card_table.gd] to update the total villager count.
signal increase_total_Meeple
@warning_ignore_restore("unused_signal")
