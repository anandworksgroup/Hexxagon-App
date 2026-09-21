enum AiLevel {
  easy('Easy'),
  normal('Normal'),
  hard('Hard'),
  expert('Expert');

  const AiLevel(this.label);
  final String label;
}

enum PlayerKind { human, ai }

/// Who sits in a seat: a person or a computer opponent, plus the colour and
/// token symbol used to draw them. Colour and token are palette indices so
/// the engine stays free of Flutter types.
class PlayerSlot {
  const PlayerSlot({
    required this.name,
    required this.kind,
    required this.colorIndex,
    required this.tokenIndex,
    this.ai,
  });

  final String name;
  final PlayerKind kind;
  final int colorIndex;
  final int tokenIndex;
  final AiLevel? ai;

  bool get isHuman => kind == PlayerKind.human;

  Map<String, Object?> toJson() => {
    'name': name,
    'kind': kind.name,
    'color': colorIndex,
    'token': tokenIndex,
    'ai': ai?.name,
  };

  static PlayerSlot fromJson(Map<String, dynamic> json) {
    final ai = json['ai'] as String?;
    return PlayerSlot(
      name: json['name'] as String,
      kind: PlayerKind.values.byName(json['kind'] as String),
      colorIndex: (json['color'] as num).toInt(),
      tokenIndex: (json['token'] as num).toInt(),
      ai: ai == null ? null : AiLevel.values.byName(ai),
    );
  }
}
