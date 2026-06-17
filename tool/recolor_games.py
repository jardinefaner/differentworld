"""One-shot: reassign every game's GameVibe accent to the harmonized
GameAccents palette (Calm, on-brand). Keyed by file so the two
ActivityPalette.blue games (and the duplicate teals) map to DIFFERENT accents.
Surface drops to the shared kGameSurface default."""
import os

G = "lib/features/games/games"
A = "lib/features/action_words"
LB = "lib/features/live_board"

repl = {
    f"{G}/this_or_that_game.dart": (
        "const GameVibe(accent: ActivityPalette.blue)",
        "const GameVibe(accent: GameAccents.teal)"),
    f"{G}/charades_game.dart": (
        "const GameVibe(accent: Color(0xFFB388FF), surface: Color(0xFF15101F))",
        "const GameVibe(accent: GameAccents.plum)"),
    f"{G}/riddles_game.dart": (
        "const GameVibe(accent: Color(0xFF7E57C2))",
        "const GameVibe(accent: GameAccents.slate)"),
    f"{G}/fact_or_fib_game.dart": (
        "const GameVibe(accent: Color(0xFF66BB6A))",
        "const GameVibe(accent: GameAccents.sage)"),
    f"{G}/as_if_game.dart": (
        "const GameVibe(accent: Color(0xFFFFD54F), surface: Color(0xFF0E0E0E))",
        "const GameVibe(accent: GameAccents.coral)"),
    f"{G}/story_starters_game.dart": (
        "const GameVibe(accent: Color(0xFFFFCA62), surface: Color(0xFF1B1430))",
        "const GameVibe(accent: GameAccents.amber)"),
    f"{G}/rhyme_time_game.dart": (
        "const GameVibe(accent: Color(0xFF26A69A), surface: Color(0xFF06100F))",
        "const GameVibe(accent: GameAccents.teal)"),
    f"{G}/letter_words_game.dart": (
        "const GameVibe(accent: Color(0xFFFFC857), surface: Color(0xFF121006))",
        "const GameVibe(accent: GameAccents.amber)"),
    f"{G}/math_quiz_game.dart": (
        "const GameVibe(accent: Color(0xFF4DD0E1), surface: Color(0xFF06121A))",
        "const GameVibe(accent: GameAccents.slate)"),
    f"{G}/poll_game.dart": (
        "const GameVibe(accent: Color(0xFF26A69A))",
        "const GameVibe(accent: GameAccents.deepTeal)"),
    f"{G}/cues_game.dart": (
        "const GameVibe(accent: ActivityPalette.blue)",
        "const GameVibe(accent: GameAccents.coral)"),
    f"{G}/nownext_game.dart": (
        "const GameVibe(accent: Color(0xFF26A69A))",
        "const GameVibe(accent: GameAccents.sage)"),
    f"{G}/picker_game.dart": (
        "const GameVibe(accent: Color(0xFFFFCA28))",
        "const GameVibe(accent: GameAccents.amber)"),
    f"{G}/name_it_game.dart": (
        "const GameVibe(accent: Color(0xFF7C4DFF))",
        "const GameVibe(accent: GameAccents.rose)"),
    f"{G}/odd_one_out_game.dart": (
        "const GameVibe(accent: Color(0xFFFF7043), surface: Color(0xFF1A0F0B))",
        "const GameVibe(accent: GameAccents.coral)"),
    f"{G}/whats_missing_game.dart": (
        "const GameVibe(accent: Color(0xFFEC407A), surface: Color(0xFF1A0A12))",
        "const GameVibe(accent: GameAccents.rose)"),
    f"{G}/memory_match_game.dart": (
        "const GameVibe(accent: Color(0xFF5C6BC0), surface: Color(0xFF0F1020))",
        "const GameVibe(accent: GameAccents.plum)"),
    f"{A}/world_cast_game.dart": (
        "const GameVibe(accent: Color(0xFF6B5B95), surface: Color(0xFF09090F))",
        "const GameVibe(accent: GameAccents.plum)"),
    f"{A}/conductor.dart": (
        "const GameVibe(accent: Color(0xFF4ABED9), surface: Color(0xFF07090C))",
        "const GameVibe(accent: GameAccents.slate)"),
    f"{LB}/board_game.dart": (
        "const GameVibe(accent: Color(0xFF2A9D8F), surface: Color(0xFF0B0F0E))",
        "const GameVibe(accent: GameAccents.deepTeal)"),
}

for path, (old, new) in repl.items():
    with open(path) as f:
        s = f.read()
    if old in s:
        with open(path, "w") as f:
            f.write(s.replace(old, new, 1))
        print("OK  ", os.path.basename(path))
    else:
        print("MISS", os.path.basename(path), "(check old string)")
