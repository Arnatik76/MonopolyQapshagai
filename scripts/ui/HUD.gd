extends CanvasLayer

# HUD — панели игроков, лог событий, кнопки хода

@onready var roll_button: Button = $GamePanel/VBox/Buttons/RollButton
@onready var end_turn_button: Button = $GamePanel/VBox/Buttons/EndTurnButton
@onready var log_label: RichTextLabel = $LogPanel/LogLabel
@onready var players_container: VBoxContainer = $PlayersPanel/PlayersContainer
@onready var dice_label: Label = $GamePanel/VBox/DiceLabel
@onready var phase_label: Label = $GamePanel/VBox/PhaseLabel

# Карточки игроков (создаются динамически)
var _player_cards: Array[Control] = []

func _ready() -> void:
	SignalBus.turn_started.connect(_on_turn_started)
	SignalBus.dice_rolled.connect(_on_dice_rolled)
	SignalBus.balance_changed.connect(_on_balance_changed)
	SignalBus.turn_ended.connect(_on_turn_ended)
	SignalBus.player_bankrupt.connect(_on_player_bankrupt)
	SignalBus.game_over.connect(_on_game_over)
	SignalBus.rent_paid.connect(_on_rent_paid)
	SignalBus.property_bought.connect(_on_property_bought)
	SignalBus.cell_action_required.connect(_on_cell_action_required)
	SignalBus.game_message.connect(_on_game_message)

	roll_button.pressed.connect(_on_roll_pressed)
	end_turn_button.pressed.connect(_on_end_turn_pressed)

func setup_players() -> void:
	# Создаём карточку для каждого игрока
	for child in players_container.get_children():
		child.queue_free()
	_player_cards.clear()

	for i in PlayerManager.player_count:
		var card := _create_player_card(i)
		players_container.add_child(card)
		_player_cards.append(card)

func _create_player_card(player_index: int) -> Control:
	var player := PlayerManager.get_player(player_index)
	var panel := PanelContainer.new()
	panel.name = "Player%d" % player_index

	var vbox := VBoxContainer.new()
	vbox.name = "VBox"
	panel.add_child(vbox)

	var name_lbl := Label.new()
	name_lbl.name = "NameLabel"
	name_lbl.text = player.name
	name_lbl.add_theme_color_override("font_color", player.token_color)
	vbox.add_child(name_lbl)

	var balance_lbl := Label.new()
	balance_lbl.name = "BalanceLabel"
	balance_lbl.text = "%dМ" % player.balance
	vbox.add_child(balance_lbl)

	return panel

func _get_balance_label(player_index: int) -> Label:
	if player_index >= _player_cards.size():
		return null
	return _player_cards[player_index].get_node_or_null("VBox/BalanceLabel")

func _on_turn_started(player_index: int) -> void:
	var player := PlayerManager.get_player(player_index)
	_add_log("[color=yellow]Ход игрока: %s[/color]" % player.name)

	_reset_buttons()
	roll_button.disabled = false

	# Принудительно обновляем все балансы
	for i in PlayerManager.player_count:
		var lbl := _get_balance_label(i)
		if lbl:
			lbl.text = "%dМ" % PlayerManager.get_balance(i)

	# Обновляем фазу
	phase_label.text = "Бросайте кубики"

	# Выделяем карточку активного игрока
	for i in _player_cards.size():
		var card := _player_cards[i]
		if i == player_index:
			card.add_theme_stylebox_override("panel", _make_active_style(player.token_color))
		else:
			card.remove_theme_stylebox_override("panel")

func _on_dice_rolled(a: int, b: int, is_double: bool) -> void:
	dice_label.text = "🎲 %d + %d = %d%s" % [a, b, a + b, " (ДУБЛЬ!)" if is_double else ""]
	_add_log("Выпало: %d и %d%s" % [a, b, " — дубль!" if is_double else ""])
	roll_button.disabled = true

func _on_balance_changed(player_index: int, new_balance: int) -> void:
	var lbl := _get_balance_label(player_index)
	if lbl:
		lbl.text = "%dМ" % new_balance

func _on_turn_ended(_player_index: int) -> void:
	roll_button.disabled = true
	end_turn_button.disabled = true

func _on_rent_paid(from_player: int, to_player: int, amount: int) -> void:
	var from_name := PlayerManager.get_player(from_player).name
	var to_name := PlayerManager.get_player(to_player).name
	_add_log("[color=red]%s заплатил ренту %dМ → %s[/color]" % [from_name, amount, to_name])

func _on_property_bought(cell_index: int, player_index: int) -> void:
	var cell := BoardData.get_cell(cell_index)
	var player := PlayerManager.get_player(player_index)
	_add_log("[color=cyan]%s купил «%s»[/color]" % [player.name, cell.name])

func _on_player_bankrupt(player_index: int) -> void:
	var player := PlayerManager.get_player(player_index)
	_add_log("[color=red]%s — БАНКРОТ![/color]" % player.name)

func _on_game_over(winner_index: int) -> void:
	var winner := PlayerManager.get_player(winner_index)
	_add_log("[color=gold]🏆 ПОБЕДИТЕЛЬ: %s![/color]" % winner.name)

func _on_roll_pressed() -> void:
	if roll_button.has_meta("buy_mode"):
		var tsm: Node = get_tree().get_first_node_in_group("turn_sm")
		if not tsm:
			return
		var cell_idx: int = roll_button.get_meta("buy_cell")
		var p_idx: int = roll_button.get_meta("buy_player")
		roll_button.remove_meta("buy_mode")
		roll_button.remove_meta("buy_cell")
		roll_button.remove_meta("buy_player")
		_reset_buttons()
		tsm.buy_property(p_idx, cell_idx)
		return

	if GameState.current_phase == GameState.TurnPhase.WAIT_FOR_ROLL:
		get_tree().get_first_node_in_group("board").on_roll_button_pressed()

func _on_cell_action_required(cell: BoardCell, player_index: int) -> void:
	var tsm: Node = get_tree().get_first_node_in_group("turn_sm")
	if not tsm:
		return

	match GameState.current_phase:
		GameState.TurnPhase.BUY_DECISION:
			var player := PlayerManager.get_player(player_index)
			_add_log("[color=yellow]Купить «%s» за %dМ? (баланс: %dМ)[/color]" % [cell.name, cell.price, player.balance])
			# Показываем кнопки прямо в лог-панели через inline-кнопки
			roll_button.text = "Купить %dМ" % cell.price
			roll_button.disabled = false
			roll_button.set_meta("buy_mode", true)
			roll_button.set_meta("buy_cell", cell.cell_index)
			roll_button.set_meta("buy_player", player_index)
			end_turn_button.text = "Отказ (аукцион)"
			end_turn_button.disabled = false
			end_turn_button.set_meta("decline_mode", true)
			end_turn_button.set_meta("decline_cell", cell.cell_index)
			end_turn_button.set_meta("decline_player", player_index)

		GameState.TurnPhase.BET_MINIGAME:
			_add_log("[color=orange]Клетка СТАВКИ — мини-игра (пока пропускаем)[/color]")
			end_turn_button.text = "Пропустить ставки"
			end_turn_button.disabled = false
			end_turn_button.set_meta("skip_bets", true)
			end_turn_button.set_meta("skip_player", player_index)

func _on_end_turn_pressed() -> void:
	var tsm: Node = get_tree().get_first_node_in_group("turn_sm")
	if not tsm:
		return

	if end_turn_button.has_meta("decline_mode"):
		var cell_idx: int = end_turn_button.get_meta("decline_cell")
		var p_idx: int = end_turn_button.get_meta("decline_player")
		end_turn_button.remove_meta("decline_mode")
		end_turn_button.remove_meta("decline_cell")
		end_turn_button.remove_meta("decline_player")
		_reset_buttons()
		tsm.decline_buy(p_idx, cell_idx)

	elif end_turn_button.has_meta("skip_bets"):
		var p_idx: int = end_turn_button.get_meta("skip_player")
		end_turn_button.remove_meta("skip_bets")
		end_turn_button.remove_meta("skip_player")
		_reset_buttons()
		# Временная заглушка — просто завершаем ход
		GameState.set_phase(GameState.TurnPhase.TURN_END)
		SignalBus.turn_ended.emit(p_idx)
		PlayerManager.next_turn()

func _reset_buttons() -> void:
	roll_button.text = "Бросить кубики"
	roll_button.disabled = true
	if roll_button.has_meta("buy_mode"):
		roll_button.remove_meta("buy_mode")
		roll_button.remove_meta("buy_cell")
		roll_button.remove_meta("buy_player")
	end_turn_button.text = "Завершить ход"
	end_turn_button.disabled = true

func _on_game_message(text: String) -> void:
	_add_log("[color=gray]%s[/color]" % text)

func _add_log(text: String) -> void:
	log_label.append_text(text + "\n")
	# Прокрутка вниз
	await get_tree().process_frame
	log_label.scroll_to_line(log_label.get_line_count())

func _make_active_style(color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(color.r, color.g, color.b, 0.25)
	style.border_color = color
	style.set_border_width_all(2)
	style.set_corner_radius_all(4)
	return style

func show_phase(phase_text: String) -> void:
	phase_label.text = phase_text
