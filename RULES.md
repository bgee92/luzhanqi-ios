# Luzhanqi (陆战棋) — Rules

Luzhanqi ("Land Battle Chess", also called Army Chess / 军棋) is a two-player Chinese strategy game. Each army hides its pieces' identities from the enemy; a neutral referee (in this app, the app itself) decides every battle. Your goal is to **capture the enemy Flag**.

## The board

The board has two halves of 5 columns × 6 rows. Squares are named like chess squares: files **a–e** left to right and ranks **1–12** counted up from Red's back row. Red sits at the bottom and moves first.

```
         a   b   c   d   e
   12    o───H───o───H───o    Blue back row
         │   │   │   │   │
   11    o═══o═══o═══o═══o
         ║ \ │ / │ \ │ / ║
   10    o───C───o───C───o
         ║ / │ \ │ / │ \ ║
    9    o───o───C───o───o
         ║ \ │ / │ \ │ / ║
    8    o───C───o───C───o
         ║ / │ \ │ / │ \ ║
    7    o═══o═══o═══o═══o    Blue front row
         ║   ^   ║   ^   ║    frontier  (^ = mountain, impassable)
    6    o═══o═══o═══o═══o    Red front row
         ║ \ │ / │ \ │ / ║
    5    o───C───o───C───o
         ║ / │ \ │ / │ \ ║
    4    o───o───C───o───o
         ║ \ │ / │ \ │ / ║
    3    o───C───o───C───o
         ║ / │ \ │ / │ \ ║
    2    o═══o═══o═══o═══o
         │   │   │   │   │
    1    o───H───o───H───o    Red back row

   o post    C camp (行营)    H headquarters (大本营)
   ─ │ \ /  road (one step)    ═ ║  railroad (any distance)
```

Each half has 30 stations:

| Station | Per side | Special rule |
|---|---|---|
| **Post** (兵站) | 23 | Normal square. |
| **Camp** (行营) | 5 | A piece in a camp **cannot be attacked**. Camps connect diagonally to the four squares around them. |
| **Headquarters** (大本营) | 2 | The Flag must start in one. A piece in a headquarters **can never move again**. |

You can only cross the frontier at files **a**, **c** and **e**. Mountains block files b and d.

## Pieces

Each side has 25 pieces. Officers are listed strongest first.

| Piece | 中文 | Count | Notes |
|---|---|---|---|
| Field Marshal | 司令 | 1 | Strongest officer. When it dies, its owner's Flag is revealed. |
| General | 军长 | 1 | |
| Major General | 师长 | 2 | |
| Brigadier | 旅长 | 2 | |
| Colonel | 团长 | 2 | |
| Major | 营长 | 2 | |
| Captain | 连长 | 3 | |
| Lieutenant | 排长 | 3 | |
| Engineer | 工兵 | 3 | Weakest officer, but can turn corners on railroads and clears landmines safely. |
| Bomb | 炸弹 | 2 | Destroys itself and whatever it attacks or is attacked by. |
| Landmine | 地雷 | 3 | Never moves. Kills any attacker except an Engineer; a Bomb destroys it along with itself. |
| Flag | 军旗 | 1 | Never moves. Lose it and you lose the game. |

## Setup

Each player secretly arranges all 25 pieces on their own half:

1. **Camps start empty.** Every other station (23 posts + 2 headquarters) gets exactly one piece.
2. The **Flag** must be in one of your two **headquarters**.
3. **Landmines** must be in your **back two rows**.
4. **Bombs** may not start in your **front row**.

## Moving

Players alternate turns and move one piece per turn. Passing is not allowed.

- **Road:** move one step along any connecting line, including the diagonals into and out of camps.
- **Railroad:** move any number of squares in a **straight line** along a railroad, as long as no piece is in the way. You may finish by attacking the first enemy piece in your path.
- **Engineers on railroads** may turn corners and follow any connected railroad path through empty squares.
- **Landmines and the Flag never move.** Any piece in a **headquarters** is stuck there for the rest of the game.
- You can't move onto your own pieces, and you can't attack a piece in a **camp**.

## Battles

Moving onto an enemy piece is an attack. The referee compares the two pieces and announces only the **result**, not the ranks:

| Situation | Result |
|---|---|
| Two officers of different ranks | The lower-ranked one is removed. If the attacker wins, it moves onto the square. |
| Equal officers | Both are removed. |
| Anything vs **Bomb**, or a **Bomb** attacking anything | Both are removed. |
| Engineer attacks **Landmine** | Landmine is removed; the Engineer occupies the square. |
| Any other piece attacks **Landmine** | The attacker is removed; the landmine stays. |
| Any piece reaches the enemy **Flag** | **The Flag is captured and the attacker's side wins.** |

**Reveals:**

- When a **Field Marshal** is removed, its owner's **Flag position is revealed** to the opponent.
- If a piece captures an enemy **headquarters that does not hold the Flag**, the Flag's location (the other headquarters) is revealed.

## Winning and drawing

- **Win** by capturing the enemy Flag.
- **Win** if your opponent has no legal move on their turn. If **neither** side can move, the game is a **draw**.
- A player may **resign**.
- **Draw** after 60 consecutive turns (30 by each side) with no battle. This is an app house rule that keeps games from stalling, and you can change the limit in Settings.

## Variants (Settings)

| Option | Default | Effect |
|---|---|---|
| **Open pieces (明棋)** | Off | Every piece is face-up for both players, so the game has perfect information. |
| **Explosive landmines** | Off | When a non-Engineer attacks a Landmine, the attacker *and* the mine are both removed. |
| **Taking the empty HQ reveals the Flag** | On | Capturing the headquarters that doesn't hold the Flag reveals where the Flag is. |
| **Draw after no battles for** | 60 turns | Choose 40, 60 or 100 turns, or Never to turn the rule off. |

Other well-known variants exist but aren't implemented: *Flying Bombs* (bombs move like Engineers), *Flag Carrier* (the Flag must be carried home), and four-player *Si Guo Da Zhan* (四国大战).

## Tips

- Put Landmines around your Flag's headquarters, and consider bluffing by guarding the empty headquarters too.
- Keep Engineers alive for the endgame. They're the only pieces that can clear the minefield around the Flag.
- Park Bombs in camps early so they don't get traded for something cheap, then save them for the enemy Field Marshal or General.
- Probe with low officers to learn what the enemy's strong pieces are before committing your Field Marshal.
- A piece that has moved can't be a Landmine or the Flag. A piece that turned a railroad corner is an Engineer.

## Sources

- [Wikipedia: Luzhanqi](https://en.wikipedia.org/wiki/Luzhanqi)
- [Ancient Chess: How to play Luzhanqi](https://www.ancientchess.com/page/play-luzhanqi.htm)
- [YM Imports: How to Play Army Chess](https://www.ymimports.com/pages/how-to-play-luzhanqi)
