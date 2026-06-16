extends Node

# Шина сигналов — все игровые события проходят через этот синглтон

signal turn_started(player_index: int)
signal dice_rolled(a: int, b: int, is_double: bool)
signal dice_animation_finished()           # кубики остановились — начать движение
signal player_moved(player_index: int, cell_index: int)
signal cell_action_required(cell: BoardCell, player_index: int)
signal property_bought(cell_index: int, player_index: int)
signal dealer_placed(cell_index: int, player_index: int, is_senior: bool)
signal dealer_sold(cell_index: int, player_index: int, is_senior: bool)
signal rent_paid(from_player: int, to_player: int, amount: int)
signal card_drawn(card: CardData, player_index: int)
signal card_effect_applied(card: CardData, player_index: int)
signal bet_resolved(winners: Array[int], losers: Array[int])
signal player_jailed(player_index: int)
signal player_freed(player_index: int)
signal property_mortgaged(cell_index: int, player_index: int)
signal property_redeemed(cell_index: int, player_index: int)
signal player_bankrupt(player_index: int)
signal game_over(winner_index: int)
signal balance_changed(player_index: int, new_balance: int)
signal turn_ended(player_index: int)
signal camera_focus_requested(target: Vector3)
signal move_player_requested(player_index: int, target_cell: int)
signal game_message(text: String)  # информационные сообщения для лога HUD
