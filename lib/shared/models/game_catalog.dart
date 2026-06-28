import 'package:flutter/material.dart';

class GameInfo {
  final String id;
  final String name;
  final String description;
  final IconData icon;
  final List<Color> colors;
  final int minPlayers;
  final int maxPlayers;

  const GameInfo({
    required this.id,
    required this.name,
    required this.description,
    required this.icon,
    required this.colors,
    required this.minPlayers,
    required this.maxPlayers,
  });

  bool get isOneVsOne => minPlayers == 2 && maxPlayers == 2;
}

class GameCatalog {
  GameCatalog._();

  static const quizBlitz = GameInfo(
    id: 'quiz_blitz',
    name: 'QuizBlitz',
    description: '1v1 trivia battle. Answer fast, score big.',
    icon: Icons.bolt_rounded,
    colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
    minPlayers: 2,
    maxPlayers: 2,
  );

  static const sketchWars = GameInfo(
    id: 'sketch_wars',
    name: 'SketchWars',
    description: 'Draw & guess with 2-8 friends.',
    icon: Icons.brush_rounded,
    colors: [Color(0xFF06B6D4), Color(0xFF3B82F6)],
    minPlayers: 2,
    maxPlayers: 8,
  );

  static const cardDuel = GameInfo(
    id: 'card_duel',
    name: 'CardDuel',
    description: '1v1 strategic card battle.',
    icon: Icons.style_rounded,
    colors: [Color(0xFFF59E0B), Color(0xFFEF4444)],
    minPlayers: 2,
    maxPlayers: 2,
  );

  static const typeRacer = GameInfo(
    id: 'type_racer',
    name: 'TypeRacer',
    description: 'Real-time typing race, 2-6 players.',
    icon: Icons.keyboard_rounded,
    colors: [Color(0xFF10B981), Color(0xFF14B8A6)],
    minPlayers: 2,
    maxPlayers: 6,
  );

  static const mathMasters = GameInfo(
    id: 'math_masters',
    name: 'MathMasters',
    description: 'Rapid-fire mental math. 2-8 players race the clock.',
    icon: Icons.calculate_rounded,
    colors: [Color(0xFF8B5CF6), Color(0xFFEC4899)],
    minPlayers: 2,
    maxPlayers: 8,
  );

  static const reactionRoyale = GameInfo(
    id: 'reaction_royale',
    name: 'ReactionRoyale',
    description: 'Tap the instant it turns green. 2-8 players, fastest wins.',
    icon: Icons.bolt_rounded,
    colors: [Color(0xFFF97316), Color(0xFFEAB308)],
    minPlayers: 2,
    maxPlayers: 8,
  );

  static const List<GameInfo> all = [
    quizBlitz,
    sketchWars,
    cardDuel,
    typeRacer,
    mathMasters,
    reactionRoyale,
  ];

  static GameInfo byId(String id) =>
      all.firstWhere((g) => g.id == id, orElse: () => quizBlitz);
}
