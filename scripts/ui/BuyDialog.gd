extends Control

# Диалог покупки / аукциона собственности

@onready var title_label: Label = $Panel/VBox/TitleLabel
@onready var property_name_label: Label = $Panel/VBox/PropertyNameLabel
@onready var price_label: Label = $Panel/VBox/PriceLabel
@onready var rent_info_label: Label = $Panel/VBox/RentInfoLabel
@onready var buy_button: Button = $Panel/VBox/Buttons/BuyButton
@onready var decline_button: Button = $Panel/VBox/Buttons/DeclineButton

var _cell_index: int = -1
var _player_index: int = -1

func _ready() -> void:
	hide()
	buy_button.pressed.connect(_on_buy_pressed)
	decline_button.pressed.connect(_on_decline_pressed)
	SignalBus.cell_action_required.connect(_on_cell_action)

func _on_cell_action(cell: BoardCell, player_index: int) -> void:
	if cell.type != BoardCell.CellType.PROPERTY:
		return
	# Проверяем, что клетка свободна
	for i in PlayerManager.player_count:
		if cell.cell_index in PlayerManager.get_player(i).owned_properties:
			return

	_cell_index = cell.cell_index
	_player_index = player_index
	_show_buy_dialog(cell, player_index)

func _show_buy_dialog(cell: BoardCell, player_index: int) -> void:
	var player := PlayerManager.get_player(player_index)
	title_label.text = "Свободная собственность"
	property_name_label.text = cell.name
	price_label.text = "Цена: %dМ (у вас: %dМ)" % [cell.price, player.balance]
	rent_info_label.text = "Рента: %s" % ", ".join(cell.rent.map(func(r): return str(r) + "М"))
	buy_button.disabled = player.balance < cell.price
	show()

func _on_buy_pressed() -> void:
	hide()
	get_tree().get_first_node_in_group("turn_sm").buy_property(_player_index, _cell_index)

func _on_decline_pressed() -> void:
	hide()
	get_tree().get_first_node_in_group("turn_sm").decline_buy(_player_index, _cell_index)
