import 'hex.dart';

/// The static shape of a board: which hexes are playable and, for each,
/// which cells are one step (multiply) and two steps (jump) away.
///
/// Cells are addressed by index everywhere in the engine so the hot paths
/// (move generation, capture, AI search) are plain integer array lookups.
class BoardLayout {
  BoardLayout._(this.cells, this._index, this.adjacent, this.jumps);

  factory BoardLayout(Iterable<Hex> hexes) {
    final seen = <Hex>{};
    final cells = <Hex>[];
    for (final h in hexes) {
      if (seen.add(h)) cells.add(h);
    }
    if (cells.isEmpty) {
      throw ArgumentError('A board needs at least one cell');
    }
    final index = <Hex, int>{for (var i = 0; i < cells.length; i++) cells[i]: i};
    final adjacent = <List<int>>[];
    final jumps = <List<int>>[];
    for (final c in cells) {
      final a = <int>[];
      for (final d in Hex.directions) {
        final i = index[c + d];
        if (i != null) a.add(i);
      }
      adjacent.add(List.unmodifiable(a));
      final j = <int>[];
      for (final h in Hex.ring(c, 2)) {
        final i = index[h];
        if (i != null) j.add(i);
      }
      jumps.add(List.unmodifiable(j));
    }
    return BoardLayout._(
      List.unmodifiable(cells),
      index,
      List.unmodifiable(adjacent),
      List.unmodifiable(jumps),
    );
  }

  final List<Hex> cells;
  final Map<Hex, int> _index;

  /// Indices of the (up to 6) cells at distance 1.
  final List<List<int>> adjacent;

  /// Indices of the (up to 12) cells at distance exactly 2.
  final List<List<int>> jumps;

  int get size => cells.length;

  int? indexOf(Hex h) => _index[h];

  bool contains(Hex h) => _index.containsKey(h);

  int distance(int a, int b) => cells[a].distanceTo(cells[b]);

  List<List<int>> toJson() => [for (final c in cells) c.toJson()];

  static BoardLayout fromJson(Object? json) =>
      BoardLayout([for (final c in json as List) Hex.fromJson(c)]);
}
