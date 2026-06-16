extends Node

# Машина состояний хода — управляет переходами между фазами

var _dice_roller: Node = null   # ссылка на DiceRoller3D

func _ready() -> void:
	add_to_group("turn_sm")
	SignalBus.dice_animation_finished.connect(_on_dice_finished)
	SignalBus.player_moved.connect(_on_player_moved)
	SignalBus.turn_started.connect(_on_turn_started)

func set_dice_roller(roller: Node) -> void:
	_dice_roller = roller

# ─── Вход в фазы ──────────────────────────────────────────────────

func begin_turn(player_index: int) -> void:
	var player := PlayerManager.get_player(player_index)
	if player.is_in_jail:
		_enter_jail_decision(player_index)
	else:
		_enter_wait_for_roll()

func _enter_wait_for_roll() -> void:
	GameState.set_phase(GameState.TurnPhase.WAIT_FOR_ROLL)

func roll_dice() -> void:
	# Вызывается кнопкой «Бросить кубики»
	if GameState.current_phase != GameState.TurnPhase.WAIT_FOR_ROLL:
		return
	if not _dice_roller:
		push_error("TurnStateMachine: dice_roller не задан")
		return
	GameState.set_phase(GameState.TurnPhase.ROLLING)
	_dice_roller.roll()

func _on_dice_finished() -> void:
	print("[TSM] _on_dice_finished, phase=%d" % GameState.current_phase)
	if GameState.current_phase != GameState.TurnPhase.ROLLING:
		print("[TSM] wrong phase, skipping")
		return

	var player_index := PlayerManager.current_player_index
	var player := PlayerManager.get_player(player_index)

	var a := GameState.last_dice_a
	var b := GameState.last_dice_b
	var is_double := GameState.last_is_double

	# Игрок в тюрьме — попытка выбросить дубль
	if player.is_in_jail:
		if is_double:
			player.is_in_jail = false
			player.jail_turns_remaining = 0
			SignalBus.player_freed.emit(player_index)
			# Идём на сумму дубля, но без повторного хода за дубль
			GameState.set_phase(GameState.TurnPhase.MOVING)
			var target_jail: int = (player.cell_position + a + b) % BoardData.CELL_COUNT
			_move_player(player_index, target_jail)
		else:
			player.jail_turns_remaining -= 1
			if player.jail_turns_remaining <= 0:
				# 3 попытки исчерпаны — принудительно платим 50М
				PlayerManager.subtract_balance(player_index, 50)
				player.is_in_jail = false
				SignalBus.player_freed.emit(player_index)
				GameState.set_phase(GameState.TurnPhase.MOVING)
				var target_forced: int = (player.cell_position + a + b) % BoardData.CELL_COUNT
				_move_player(player_index, target_forced)
			else:
				_end_turn()
		return

	# Три дубля подряд → тюрьма
	if is_double:
		player.doubles_streak += 1
		if player.doubles_streak >= 3:
			_send_to_jail(player_index)
			return
	else:
		player.doubles_streak = 0

	# Двигаем фишку
	GameState.set_phase(GameState.TurnPhase.MOVING)
	var steps := a + b
	var old_pos := player.cell_position
	var target_cell := (old_pos + steps) % BoardData.CELL_COUNT
	# +200М при прохождении клетки 0 (START)
	if old_pos + steps >= BoardData.CELL_COUNT:
		print("[TSM] прошли START — +200М игроку %d" % player_index)
		PlayerManager.add_balance(player_index, 200)
	SignalBus.camera_focus_requested.emit(BoardData.get_cell_world_pos(target_cell))
	_move_player(player_index, target_cell)

func _move_player(player_index: int, target_cell: int) -> void:
	SignalBus.move_player_requested.emit(player_index, target_cell)

func _on_player_moved(player_index: int, cell_index: int) -> void:
	print("[TSM] _on_player_moved: player=%d cell=%d phase=%d" % [player_index, cell_index, GameState.current_phase])
	if GameState.current_phase != GameState.TurnPhase.MOVING:
		print("[TSM] wrong phase for player_moved, skipping")
		return
	# Обновляем позицию в данных
	PlayerManager.get_player(player_index).cell_position = cell_index
	GameState.set_phase(GameState.TurnPhase.CELL_ACTION)
	_handle_cell_action(player_index, cell_index)

func _handle_cell_action(player_index: int, cell_index: int) -> void:
	var cell := BoardData.get_cell(cell_index)
	print("[TSM] cell action: index=%d type=%s" % [cell_index, cell.type if cell else "null"])
	if not cell:
		_end_turn()
		return

	match cell.type:
		BoardCell.CellType.START:
			var pname := PlayerManager.get_player(player_index).name
			PlayerManager.add_balance(player_index, 200)
			SignalBus.game_message.emit("%s точно попал на «Вперёд!» — +200М" % pname)
			_end_turn()

		BoardCell.CellType.PROPERTY:
			_handle_property(player_index, cell)

		BoardCell.CellType.HOTEL:
			_handle_hotel(player_index, cell)

		BoardCell.CellType.CHANCE:
			_draw_card(player_index, CardData.CardType.CHANCE)

		BoardCell.CellType.EVENT:
			_draw_card(player_index, CardData.CardType.EVENT)

		BoardCell.CellType.BETS:
			GameState.set_phase(GameState.TurnPhase.BET_MINIGAME)
			SignalBus.cell_action_required.emit(cell, player_index)

		BoardCell.CellType.GO_TO_JAIL:
			_send_to_jail(player_index)

		BoardCell.CellType.JAIL:
			var pname := PlayerManager.get_player(player_index).name
			SignalBus.game_message.emit("%s посещает тюрьму — просто визит" % pname)
			_end_turn()

		_:
			_end_turn()

func _handle_property(player_index: int, cell: BoardCell) -> void:
	var owner_index := _find_owner(cell.cell_index)
	print("[TSM] _handle_property: cell=%d owner=%d current_player=%d" % [cell.cell_index, owner_index, player_index])

	if owner_index == -1:
		GameState.set_phase(GameState.TurnPhase.BUY_DECISION)
		SignalBus.cell_action_required.emit(cell, player_index)
	elif owner_index == player_index:
		_end_turn()
	else:
		var owner := PlayerManager.get_player(owner_index)
		if owner.is_bankrupt or cell.cell_index in owner.mortgaged_cells:
			_end_turn()
			return
		# Рента по числу дилеров на клетке
		var dealers_data: Dictionary = owner.dealers.get(cell.cell_index, {"junior": 0, "senior": 0}) as Dictionary
		var junior: int = dealers_data.get("junior", 0) as int
		var senior: int = dealers_data.get("senior", 0) as int
		var slot: int = 5 if senior > 0 else junior
		var rent_amount: int = cell.rent[min(slot, cell.rent.size() - 1)] if cell.rent.size() > 0 else 0
		if not PlayerManager.subtract_balance(player_index, rent_amount):
			_check_bankrupt(player_index)
		else:
			PlayerManager.add_balance(owner_index, rent_amount)
			SignalBus.rent_paid.emit(player_index, owner_index, rent_amount)
			_end_turn()

func _handle_hotel(player_index: int, cell: BoardCell) -> void:
	var owner_index := _find_hotel_owner(cell.cell_index)

	if owner_index == -1:
		GameState.set_phase(GameState.TurnPhase.BUY_DECISION)
		SignalBus.cell_action_required.emit(cell, player_index)
	elif owner_index == player_index:
		_end_turn()
	else:
		var owner := PlayerManager.get_player(owner_index)
		if owner.is_bankrupt or cell.cell_index in owner.mortgaged_cells:
			_end_turn()
			return
		var hotel_count: int = owner.owned_hotels.size()
		var rent_amount: int = cell.rent_by_count[min(hotel_count, cell.rent_by_count.size() - 1)] if cell.rent_by_count.size() > 0 else 0
		if not PlayerManager.subtract_balance(player_index, rent_amount):
			_check_bankrupt(player_index)
		else:
			PlayerManager.add_balance(owner_index, rent_amount)
			SignalBus.rent_paid.emit(player_index, owner_index, rent_amount)
			_end_turn()

func buy_property(player_index: int, cell_index: int) -> void:
	var cell := BoardData.get_cell(cell_index)
	if not cell:
		return
	if PlayerManager.subtract_balance(player_index, cell.price):
		var player := PlayerManager.get_player(player_index)
		if cell.type == BoardCell.CellType.HOTEL:
			player.owned_hotels.append(cell_index)
		else:
			player.owned_properties.append(cell_index)
		SignalBus.property_bought.emit(cell_index, player_index)
	_end_turn()

func decline_buy(player_index: int, cell_index: int) -> void:
	GameState.set_phase(GameState.TurnPhase.AUCTION)
	_end_turn()

func _draw_card(player_index: int, card_type: CardData.CardType) -> void:
	GameState.set_phase(GameState.TurnPhase.CARD_EFFECT)
	var cards := BoardData.get_cards(card_type)
	if cards.is_empty():
		print("[TSM] колода пуста, пропускаем карту")
		_end_turn()
		return
	var card: CardData = cards[randi() % cards.size()]
	print("[TSM] карта: %s, эффект=%s, значение=%d" % [card.title, card.effect_type, card.effect_value])
	SignalBus.card_drawn.emit(card, player_index)
	# CardPopup ещё не реализован — применяем эффект сразу
	apply_card_effect(card, player_index)

func apply_card_effect(card: CardData, player_index: int) -> void:
	SignalBus.card_effect_applied.emit(card, player_index)
	var player := PlayerManager.get_player(player_index)

	match card.effect_type:
		CardData.EffectType.GET_MONEY:
			PlayerManager.add_balance(player_index, card.effect_value)
			_end_turn()

		CardData.EffectType.PAY_MONEY:
			if not PlayerManager.subtract_balance(player_index, card.effect_value):
				_check_bankrupt(player_index)
			else:
				_end_turn()

		CardData.EffectType.GET_FROM_EACH:
			for i in PlayerManager.player_count:
				if i != player_index and not PlayerManager.get_player(i).is_bankrupt:
					PlayerManager.subtract_balance(i, card.effect_value)
					PlayerManager.add_balance(player_index, card.effect_value)
			_end_turn()

		CardData.EffectType.PAY_EACH_PLAYER:
			for i in PlayerManager.player_count:
				if i != player_index and not PlayerManager.get_player(i).is_bankrupt:
					PlayerManager.subtract_balance(player_index, card.effect_value)
					PlayerManager.add_balance(i, card.effect_value)
			_check_bankrupt(player_index)

		CardData.EffectType.GO_TO_JAIL:
			_send_to_jail(player_index)

		CardData.EffectType.GET_OUT_OF_JAIL:
			player.get_out_of_jail_cards += 1
			_end_turn()

		CardData.EffectType.SKIP_TURN:
			player.jail_turns_remaining = 1  # используем поле для пропуска
			_end_turn()

		CardData.EffectType.PAY_PER_DEALER:
			var total_dealers := 0
			for cell_idx in player.dealers:
				var d: Dictionary = player.dealers[cell_idx]
				total_dealers += (d.get("junior", 0) as int) + (d.get("senior", 0) as int) * 4
			var amount: int = total_dealers * card.effect_value
			if not PlayerManager.subtract_balance(player_index, amount):
				_check_bankrupt(player_index)
			else:
				_end_turn()

		CardData.EffectType.CASINO_MINIGAME:
			# Запускает мини-игру из колоды Событие — обрабатывается как BET_MINIGAME
			GameState.set_phase(GameState.TurnPhase.BET_MINIGAME)
			SignalBus.cell_action_required.emit(BoardData.get_cell(player.cell_position), player_index)

		CardData.EffectType.MOVE_TO:
			GameState.set_phase(GameState.TurnPhase.MOVING)
			_move_player(player_index, card.effect_value)

		CardData.EffectType.MOVE_BY:
			GameState.set_phase(GameState.TurnPhase.MOVING)
			var target := (player.cell_position + card.effect_value) % BoardData.CELL_COUNT
			if target < 0:
				target += BoardData.CELL_COUNT
			_move_player(player_index, target)

func _enter_jail_decision(_player_index: int) -> void:
	GameState.set_phase(GameState.TurnPhase.JAIL_DECISION)
	# HUD покажет кнопки: Заплатить 50М / Попробовать дубль / Карта

func pay_jail_fine(player_index: int) -> void:
	var player := PlayerManager.get_player(player_index)
	if PlayerManager.subtract_balance(player_index, 50):
		player.is_in_jail = false
		player.jail_turns_remaining = 0
		_enter_wait_for_roll()
	else:
		_check_bankrupt(player_index)

func use_jail_card(player_index: int) -> void:
	var player := PlayerManager.get_player(player_index)
	if player.get_out_of_jail_cards > 0:
		player.get_out_of_jail_cards -= 1
		player.is_in_jail = false
		player.jail_turns_remaining = 0
		_enter_wait_for_roll()

func jail_roll_dice() -> void:
	# Попытка выбросить дубль из тюрьмы
	if not _dice_roller:
		return
	GameState.set_phase(GameState.TurnPhase.ROLLING)
	_dice_roller.roll()
	# Результат придёт через _on_dice_finished
	# Если дубль — выходим и идём, иначе остаёмся

func _send_to_jail(player_index: int) -> void:
	var player := PlayerManager.get_player(player_index)
	player.is_in_jail = true
	player.jail_turns_remaining = 3
	player.cell_position = 9  # клетка тюрьмы
	player.doubles_streak = 0
	# 200М не начисляются при отправке в тюрьму
	SignalBus.player_jailed.emit(player_index)
	SignalBus.move_player_requested.emit(player_index, 9)
	GameState.set_phase(GameState.TurnPhase.TURN_END)
	_end_turn()

func _end_turn() -> void:
	GameState.set_phase(GameState.TurnPhase.TURN_END)
	var player_index := PlayerManager.current_player_index
	var player := PlayerManager.get_player(player_index)

	# Если был дубль и не тюрьма — ещё один ход
	if GameState.last_is_double and not player.is_in_jail and player.doubles_streak < 3:
		SignalBus.turn_ended.emit(player_index)
		_enter_wait_for_roll()
		SignalBus.turn_started.emit(player_index)
		return

	SignalBus.turn_ended.emit(player_index)
	PlayerManager.next_turn()

func _check_bankrupt(player_index: int) -> void:
	var player := PlayerManager.get_player(player_index)
	if player.balance < 0:
		PlayerManager.declare_bankrupt(player_index)
		_end_turn()
	else:
		_end_turn()

func _find_owner(cell_index: int) -> int:
	for i in PlayerManager.player_count:
		var p := PlayerManager.get_player(i)
		if not p.is_bankrupt and cell_index in p.owned_properties:
			return i
	return -1

func _find_hotel_owner(cell_index: int) -> int:
	for i in PlayerManager.player_count:
		var p := PlayerManager.get_player(i)
		if not p.is_bankrupt and cell_index in p.owned_hotels:
			return i
	return -1

func _on_turn_started(player_index: int) -> void:
	begin_turn(player_index)
