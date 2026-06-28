import 'dart:math';

class DuelCard {
  final String id;
  final int attack;
  final int defense;
  final int cost;

  const DuelCard(
      {required this.id,
      required this.attack,
      required this.defense,
      required this.cost});

  factory DuelCard.fromMap(Map m) => DuelCard(
        id: m['id']?.toString() ?? '',
        attack: (m['attack'] as num?)?.toInt() ?? 1,
        defense: (m['defense'] as num?)?.toInt() ?? 1,
        cost: (m['cost'] as num?)?.toInt() ?? 1,
      );

  Map<String, dynamic> toMap() =>
      {'id': id, 'attack': attack, 'defense': defense, 'cost': cost};
}

class PlayerState {
  final String name;
  int energy;
  int deckCount;
  List<DuelCard> hand;
  List<DuelCard> board;

  PlayerState({
    required this.name,
    required this.energy,
    required this.deckCount,
    required this.hand,
    required this.board,
  });

  int get totalCards => deckCount + hand.length + board.length;

  factory PlayerState.fromMap(Map m) => PlayerState(
        name: m['name']?.toString() ?? 'Player',
        energy: (m['energy'] as num?)?.toInt() ?? 1,
        deckCount: (m['deckCount'] as num?)?.toInt() ?? 0,
        hand: ((m['hand'] as List?) ?? [])
            .map((e) => DuelCard.fromMap(e as Map))
            .toList(),
        board: ((m['board'] as List?) ?? [])
            .map((e) => DuelCard.fromMap(e as Map))
            .toList(),
      );

  Map<String, dynamic> toMap() => {
        'name': name,
        'energy': energy,
        'deckCount': deckCount,
        'hand': hand.map((c) => c.toMap()).toList(),
        'board': board.map((c) => c.toMap()).toList(),
      };
}

/// Generates a shuffled 30-card deck deterministically from [seed].
List<DuelCard> generateDeck(int seed, String prefix) {
  final rng = Random(seed);
  return List.generate(30, (i) {
    final cost = 1 + rng.nextInt(6); // 1..6
    final attack = cost + rng.nextInt(3); // scales with cost
    final defense = (cost + rng.nextInt(3)).clamp(1, 9);
    return DuelCard(
        id: '$prefix-$i', attack: attack, defense: defense, cost: cost);
  });
}
