extends Control

# Всплывающий диалог карты Шанс / Событий

@onready var card_title: Label = $Panel/VBox/CardTitle
@onready var card_desc: Label = $Panel/VBox/CardDesc
@onready var card_image: TextureRect = $Panel/VBox/CardImage
@onready var ok_button: Button = $Panel/VBox/OKButton

var _pending_card: CardData = null
var _pending_player: int = -1

func _ready() -> void:
	hide()
	ok_button.pressed.connect(_on_ok_pressed)
	SignalBus.card_drawn.connect(_on_card_drawn)

func _on_card_drawn(card: CardData, player_index: int) -> void:
	_pending_card = card
	_pending_player = player_index

	card_title.text = card.title
	card_desc.text = card.description

	if card.front_texture:
		card_image.texture = card.front_texture
		card_image.visible = true
	else:
		card_image.visible = false

	show()

func _on_ok_pressed() -> void:
	hide()
	if _pending_card and _pending_player >= 0:
		get_tree().get_first_node_in_group("turn_sm").apply_card_effect(_pending_card, _pending_player)
	_pending_card = null
	_pending_player = -1
