class_name PlayerData
extends Resource

@export var player_index: int
@export var name: String
@export var token_color: Color
@export var balance: int = 1500
@export var cell_position: int = 0
@export var owned_properties: Array[int] = []   # индексы клеток-собственностей
@export var owned_hotels: Array[int] = []        # индексы клеток-номеров отеля
# Дилеры: cell_index → {"junior": 0..4, "senior": 0..1}
@export var dealers: Dictionary = {}
@export var mortgaged_cells: Array[int] = []
@export var is_in_jail: bool = false
@export var jail_turns_remaining: int = 0
@export var doubles_streak: int = 0
@export var is_bankrupt: bool = false
@export var get_out_of_jail_cards: int = 0
