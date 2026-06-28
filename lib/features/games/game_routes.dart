import 'package:flutter/material.dart';

import '../../shared/models/game_catalog.dart';
import 'card_duel/card_duel_screen.dart';
import 'lobby_player.dart';
import 'math_masters/math_masters_screen.dart';
import 'quiz_blitz/quiz_blitz_screen.dart';
import 'reaction_royale/reaction_royale_screen.dart';
import 'sketch_wars/sketch_wars_screen.dart';
import 'type_racer/type_racer_screen.dart';

/// Maps a game id to its in-match screen.
Widget buildGameScreen({
  required GameInfo game,
  required String matchId,
  required List<LobbyPlayer> players,
  required String myUid,
}) {
  switch (game.id) {
    case 'quiz_blitz':
      return QuizBlitzScreen(matchId: matchId, players: players, myUid: myUid);
    case 'sketch_wars':
      return SketchWarsScreen(matchId: matchId, players: players, myUid: myUid);
    case 'card_duel':
      return CardDuelScreen(matchId: matchId, players: players, myUid: myUid);
    case 'type_racer':
      return TypeRacerScreen(matchId: matchId, players: players, myUid: myUid);
    case 'math_masters':
      return MathMastersScreen(
          matchId: matchId, players: players, myUid: myUid);
    case 'reaction_royale':
      return ReactionRoyaleScreen(
          matchId: matchId, players: players, myUid: myUid);
    default:
      return QuizBlitzScreen(matchId: matchId, players: players, myUid: myUid);
  }
}
