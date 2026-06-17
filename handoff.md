# Handoff — MONEY POLYS CASINO

Читай этот файл в начале каждой сессии вместо расспросов.
После прочтения скажи: «Контекст загружен, готов к работе».

---

## Что это за проект

Цифровая версия казино-монополии **MONEY POLYS CASINO**.
- Круглое поле, **36 клеток**, 8 залов-казино
- **Godot 4.x**, Forward+, GDScript, только 3D
- Локальный мультиплеер 2–6 игроков (один экран)
- Платформа: ПК (Windows/Linux/macOS)

---

## Структура — ключевые файлы

```
scripts/
  autoload/
    GameState.gd       — enum TurnPhase, текущая фаза хода
    PlayerManager.gd   — массив PlayerData, current_player_index, next_turn()
    BoardData.gd       — загружает board_cells.json, get_cell_world_pos()
    SignalBus.gd       — ВСЕ сигналы игры через одну точку
  game/
    TurnStateMachine.gd — полная логика хода (главный файл логики)
    Board3D.gd          — 3D сцена: фишки, дилеры, подсветка, текстура поля
    BoardRenderer.gd    — Node2D, рисует поле процедурно в SubViewport 2048×2048
    PlayerToken3D.gd    — фишка одного игрока, move_to_cell() с анимацией
    DiceRoller3D.gd     — физические кубики, emit dice_animation_finished
    CameraController.gd — орбитальная камера, два режима (обзор / слежение)
  ui/
    HUD.gd              — баланс, лог, кнопки хода + кнопка камеры
    CardPopup.gd        — попап карты Шанс/Событие (ждёт OK → apply_card_effect)
scripts/resources/
    BoardCell.gd        — Resource: тип клетки, рента, цена
    PlayerData.gd       — Resource: баланс, позиция, is_in_jail, dealers...
    CardData.gd         — Resource: эффект карты
data/
    board_cells.json    — 36 клеток (ГОТОВО, не трогать без причины)
scenes/
    Main.tscn + scripts/Main.gd  — точка входа, вызывает setup
    game/Board3D.tscn            — вся 3D сцена поля
    game/PlayerToken3D.tscn      — фишка игрока
    ui/HUD.tscn                  — интерфейс (с CamButton)
    ui/CardPopup.tscn            — попап карты (подключён к Main.tscn)
```

---

## Карта поля (36 клеток)

```
0  ВПЕРЁД!          START
1  Лото — Silver    PROPERTY  YELLOW  60М
2  Событие          EVENT
3  Лото — Gold      PROPERTY  YELLOW  60М
4  Номер отеля №1   HOTEL
5  Домино — Silver  PROPERTY  GREEN   100М
6  Шанс             CHANCE
7  Домино — Gold    PROPERTY  GREEN   100М
8  Домино — Plat.   PROPERTY  GREEN   120М
9  ТЮРЬМА           JAIL
10 Кости — Silver   PROPERTY  WHITE   140М
11 Кости — Gold     PROPERTY  WHITE   160М
12 Кости — Plat.    PROPERTY  WHITE   160М
13 Номер отеля №2   HOTEL
14 Авт. — Silver    PROPERTY  BLUE    180М
15 Событие          EVENT
16 Авт. — Gold      PROPERTY  BLUE    180М
17 Авт. — Plat.     PROPERTY  BLUE    200М
18 СТАВКИ           BETS
19 Колесо — Silver  PROPERTY  PINK    220М
20 Шанс             CHANCE
21 Колесо — Gold    PROPERTY  PINK    220М
22 Колесо — Plat.   PROPERTY  PINK    240М
23 Номер отеля №3   HOTEL
24 Рулетка — Silver PROPERTY  ORANGE  260М
25 Рулетка — Gold   PROPERTY  ORANGE  260М
26 Рулетка — Plat.  PROPERTY  ORANGE  280М
27 В ТЮРЬМУ!        GO_TO_JAIL
28 Блэкджек — Sil.  PROPERTY  GRAY    300М
29 Блэкджек — Gold  PROPERTY  GRAY    300М
30 Событие          EVENT
31 Блэкджек — Plat. PROPERTY  GRAY    320М
32 Номер отеля №4   HOTEL
33 Покер — Gold     PROPERTY  RED     350М
34 Шанс             CHANCE
35 Покер — Plat.    PROPERTY  RED     400М
```

---

## Архитектура хода (TurnStateMachine.gd)

```
WAIT_FOR_ROLL → (кнопка) → ROLLING → (dice_animation_finished)
→ MOVING → (player_moved) → CELL_ACTION → ...
  PROPERTY свободна → BUY_DECISION → (купить/отказ) → TURN_END
  PROPERTY чужая   → платим ренту → TURN_END
  HOTEL            → аналогично PROPERTY
  CHANCE / EVENT   → CARD_EFFECT → card_drawn → [CardPopup OK] → apply_card_effect() → TURN_END
  BETS (кл.18)     → BET_MINIGAME → (кнопка пропуска) → TURN_END
  GO_TO_JAIL       → _send_to_jail() → TURN_END
  JAIL (кл.9)      → сообщение «просто визит» → TURN_END
  START (кл.0)     → +200М → TURN_END
TURN_END → если дубль и не тюрьма → снова WAIT_FOR_ROLL (тот же игрок)
         → иначе → PlayerManager.next_turn() → turn_started (следующий)
```

**Тюрьма (is_in_jail = true):**
- При старте хода → JAIL_DECISION (HUD показывает кнопки)
- «Бросить (дубль?)» → jail_roll_dice() → если дубль: освободить + двигать
- «Заплатить 50М» → pay_jail_fine() → WAIT_FOR_ROLL
- 3 неудачных попытки → принудительно платим 50М и двигаем

**CardPopup (важно):**
- `_draw_card()` эмитирует `card_drawn` и ОСТАНАВЛИВАЕТСЯ — НЕ вызывает apply_card_effect
- CardPopup ловит сигнал, показывает карту, ждёт нажатия OK
- По OK → `tsm.apply_card_effect(card, player_index)` → `_end_turn()`

---

## Процедурная текстура поля (BoardRenderer.gd)

- **Node2D** добавляется в SubViewport (2048×2048) в Board3D._ready()
- SubViewport → get_texture() → стандартный материал на BoardDisc/BoardTop
- SHADING_MODE_UNSHADED (иначе освещение затемняет текстуру)
- После рендера: SubViewport.UPDATE_ONCE (поле статично)

**Радиусы:**
```
R_OUTER = 950  — внешний край
R_STRIPE = 892 — начало цветной полосы у края (для PROPERTY)
R_CELL   = 645 — граница: снаружи клетка, внутри зал
R_INNER  = 330 — внутренняя граница / хаб
```

---

## HUD (HUD.gd)

**Кнопки меняют режим через meta:**
- Обычный ход: roll_button → `board.on_roll_button_pressed()`
- Тюрьма: roll_button → `tsm.jail_roll_dice()`, end_turn_button (jail_pay) → `tsm.pay_jail_fine()`
- Покупка: roll_button (buy_mode) → `tsm.buy_property()`, end_turn_button (decline_mode) → `tsm.decline_buy()`
- Ставки: end_turn_button (skip_bets) → завершить ход

**Кнопка камеры (cam_button):**
- Находится в `$GamePanel/VBox/CamButton` — ниже основных кнопок
- Переключает `CameraController.follow_mode` через `cam.call("set_follow_mode", bool)`
- Текст меняется: «Вид: Обзор поля» ↔ «Вид: На игрока»

**Сигналы в HUD:**
`turn_started, dice_rolled, balance_changed, turn_ended, player_bankrupt,
game_over, rent_paid, property_bought, cell_action_required, game_message`

---

## Камера (CameraController.gd)

- Добавлена в группу `"camera_controller"` — находится через `get_first_node_in_group`
- **Два режима:** `follow_mode = false` (обзор, фокус на центре) / `true` (слежение за токеном)
- `_update_transform()` вызывается в `_process()` каждый кадр — анимации работают покадрово
- При смене режима: плавный tween на `focus_target`, `distance`, `pitch` одновременно
- Обзор: distance=12, pitch=55° | Слежение: distance=7.5, pitch=42°
- `camera_focus_requested` реагирует только в `follow_mode = true`
- Управление: Q/E — вращение, ПКМ+мышь — орбита, колёсико — зум

---

## AutoLoad синглтоны

| Имя           | Назначение                                          |
|---------------|-----------------------------------------------------|
| GameState     | current_phase, last_dice_a/b, last_is_double        |
| PlayerManager | players[], current_player_index, add/subtract_balance |
| BoardData     | cells[], get_cell(idx), get_cell_world_pos(idx)     |
| SignalBus     | все сигналы                                         |

**Позиция клетки (актуальная формула):**
```gdscript
# BoardData.BOARD_RADIUS = 3.9 (не 5.0!), CELL_COUNT = 36
# +0.5 — центр клетки, а не левая граница
var angle = (TAU / 36) * (cell_index + 0.5) - PI / 2
Vector3(cos(angle) * 3.9, 0.06, sin(angle) * 3.9)
```
Почему 3.9: PlaneMesh 10×10 → R_OUTER(950px)/1024*5 = 4.64 ед., R_CELL(645px)/1024*5 = 3.15 ед.
Центр зоны клеток = (4.64+3.15)/2 ≈ 3.9. При BOARD_RADIUS=5.0 токены были за пределами текстуры.

---

## Что реализовано (работает)

- [x] Полный цикл хода: бросок → движение → действие → следующий игрок
- [x] Покупка/отказ от собственности (PROPERTY и HOTEL)
- [x] Рента с учётом дилеров (rent[] по слотам)
- [x] Карты ШАНС/СОБЫТИЕ: CardPopup показывает карту, эффект применяется после OK
- [x] Тюрьма: посадка, попытки дубля, оплата штрафа
- [x] Дубль → повторный ход; три дубля подряд → тюрьма
- [x] Прохождение START → +200М
- [x] Банкротство игрока
- [x] Процедурная текстура поля
- [x] Фишки с анимацией прыжков, стоят в центре клеток
- [x] HUD: баланс, лог, кнопки смены режима
- [x] Камера: обзор поля / слежение за игроком, плавные переходы

## Что НЕ реализовано (заглушки) — приоритет

- [ ] **BetDialog** — СТАВКИ (кл.18): сейчас кнопка «Пропустить», вся мини-игра отсутствует
- [ ] **AuctionDialog** — decline_buy просто завершает ход, аукциона нет
- [ ] **Дилеры UI** — нет интерфейса покупки/продажи/расстановки дилеров
- [ ] **GO_TO_JAIL** — по правилам нужен бросок 1 кубика (1-2→тюрьма, 3-4→50М, 5-6→ничего); сейчас просто сажает
- [ ] **Залог собственности** — не реализован
- [ ] **Торговля между игроками** — не реализована
- [ ] **MainMenu + PlayerSetup** — сейчас 2 игрока захардкожено в Main.gd:11
- [ ] **Звуки, частицы** — нет

---

## Частые ошибки / известные паттерны

**Вывод типа Variant (ошибка как warning treated as error):**
```gdscript
# НЕПРАВИЛЬНО:
var x := some_dict.get("key", 0)
# ПРАВИЛЬНО:
var x: int = some_dict.get("key", 0)
```

**load() не выводит тип — использовать preload:**
```gdscript
const FOO := preload("res://scripts/Foo.gd")
var r := FOO.new()
```

**lerp() возвращает Variant:**
```gdscript
var a: float = lerp(x, y, t)  # обязательная аннотация типа
```

**Порядок сигналов:** `cell_action_required` должен эмититься ПОСЛЕ `GameState.set_phase()`.

**% 36, не % 24** — на поле 36 клеток.

**GO_TO_JAIL:** 200М НЕ начислять (игрок не проходит START).

**Тюрьма = клетка 9** (не 8).

**Выход из тюрьмы дублем:** после освобождения `player.doubles_streak = 3`,
иначе `_end_turn()` даёт незаслуженный повторный ход.

---

## Текущая ветка

`fix/jail` — активная ветка разработки.
Main branch: `main`.

---

## Как запустить отладку

В `Main.gd` строка 11: `PlayerManager.setup_players(2)` — быстрый старт 2 игроков.
Все `print("[TSM]...")` и `print("[PM]...")` — отладочные логи в Output.
