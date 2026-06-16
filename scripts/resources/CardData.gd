class_name CardData
extends Resource

enum CardType { CHANCE, EVENT }

enum EffectType {
	MOVE_TO,           # переместиться на клетку N (cell_index)
	MOVE_BY,           # переместиться на N клеток (±)
	GET_MONEY,         # получить N от банка
	PAY_MONEY,         # заплатить N банку
	PAY_EACH_PLAYER,   # заплатить N каждому игроку
	GET_FROM_EACH,     # получить N от каждого игрока
	GO_TO_JAIL,        # в тюрьму
	GET_OUT_OF_JAIL,   # карта выхода из тюрьмы (хранится у игрока)
	SKIP_TURN,         # пропустить следующий ход
	PAY_PER_DEALER,    # заплатить N × количество своих дилеров
	CASINO_MINIGAME,   # мини-игра казино (только в колоде Событие)
}

@export var card_type: CardType
@export var title: String
@export var description: String
@export var effect_type: EffectType
@export var effect_value: int       # число (сумма, клетка, кол-во шагов)
@export var front_texture: Texture2D
