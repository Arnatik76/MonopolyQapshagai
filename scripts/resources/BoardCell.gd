class_name BoardCell
extends Resource

enum CellType {
	START,        # «Вперёд!» — 200М при прохождении
	PROPERTY,     # Стол в казино-зале (Silver/Gold/Platinum)
	HOTEL,        # Номер отеля (клетки 4, 13, 23, 32)
	CHANCE,       # Карта Шанс
	EVENT,        # Карта Событие
	BETS,         # Ставки — мини-игра Чёрное/Красное (клетка 18)
	JAIL,         # Тюрьма / просто визит (клетка 9)
	GO_TO_JAIL,   # Отправляйтесь в тюрьму! (клетка 27)
}

enum ColorGroup { NONE, YELLOW, GREEN, WHITE, BLUE, PINK, ORANGE, GRAY, RED }
enum Tier { NONE, SILVER, GOLD, PLATINUM }

@export var cell_index: int
@export var name: String
@export var type: CellType
@export var color_group: ColorGroup
@export var casino: String           # название зала ("ЛОТО", "ДОМИНО" и т.д.)
@export var hall: int                # номер зала (1–8), 0 если не зал
@export var tier: Tier               # уровень стола
@export var price: int               # цена покупки
# rent[0]=без дилеров, rent[1..4]=1–4 младших, rent[5]=старший дилер
@export var rent: Array[int]
# Для HOTEL: рента по кол-ву номеров у владельца [0,25,50,100,200]
@export var rent_by_count: Array[int]
@export var dealer_price: int        # цена одного младшего дилера
@export var mortgage_value: int      # залоговая стоимость
@export var bet_min: int             # для BETS клетки
@export var bet_max: int             # для BETS клетки
@export var description: String
@export var world_angle_deg: float   # угол на окружности поля
