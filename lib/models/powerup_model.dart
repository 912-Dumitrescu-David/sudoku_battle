// models/powerup_model.dart
import 'package:cloud_firestore/cloud_firestore.dart';

enum PowerupType {
  revealTwoCells, // Reveals two random empty cells
  freezeOpponent, // Freezes opponent for 10 seconds
  extraHints,    // Gives +2 extra hints
  clearMistakes, // Removes all current mistakes/errors
  timeBonus,     // Adds 60 seconds to timer (if time limit exists)
  showSolution,  // Shows solution for 3 seconds
  shield,        // Protects from next opponent powerup
  bomb,          // Clears a 3x3 area of opponent's completed cells
}

extension PowerupTypeExtension on PowerupType {
  String get displayName {
    switch (this) {
      case PowerupType.revealTwoCells:
        return 'Reveal 2 Cells';
      case PowerupType.freezeOpponent:
        return 'Freeze Opponent';
      case PowerupType.extraHints:
        return 'Extra Hints';
      case PowerupType.clearMistakes:
        return 'Clear Mistakes';
      case PowerupType.timeBonus:
        return 'Time Bonus';
      case PowerupType.showSolution:
        return 'Show Solution';
      case PowerupType.shield:
        return 'Shield';
      case PowerupType.bomb:
        return 'Bomb';
    }
  }

  String get description {
    switch (this) {
      case PowerupType.revealTwoCells:
        return 'Reveals the solution for two random empty cells';
      case PowerupType.freezeOpponent:
        return 'Freezes opponent for 10 seconds';
      case PowerupType.extraHints:
        return 'Gives you 2 additional hints';
      case PowerupType.clearMistakes:
        return 'Removes all your current mistakes and errors';
      case PowerupType.timeBonus:
        return 'Adds 60 seconds to the timer';
      case PowerupType.showSolution:
        return 'Shows the complete solution for 3 seconds';
      case PowerupType.shield:
        return 'Protects from the next opponent powerup';
      case PowerupType.bomb:
        return 'Clears a 3x3 area of opponent\'s completed cells';
    }
  }

  String get iconPath {
    switch (this) {
      case PowerupType.revealTwoCells:
        return '🔍';
      case PowerupType.freezeOpponent:
        return '❄️';
      case PowerupType.extraHints:
        return '💡';
      case PowerupType.clearMistakes:
        return '🧹';
      case PowerupType.timeBonus:
        return '⏰';
      case PowerupType.showSolution:
        return '👁️';
      case PowerupType.shield:
        return '🛡️';
      case PowerupType.bomb:
        return '💣';
    }
  }

  String get colorHex {
    switch (this) {
      case PowerupType.revealTwoCells:
        return '#4CAF50'; // Green
      case PowerupType.freezeOpponent:
        return '#2196F3'; // Blue
      case PowerupType.extraHints:
        return '#FF9800'; // Orange
      case PowerupType.clearMistakes:
        return '#9C27B0'; // Purple
      case PowerupType.timeBonus:
        return '#F44336'; // Red
      case PowerupType.showSolution:
        return '#607D8B'; // Blue Grey
      case PowerupType.shield:
        return '#795548'; // Brown
      case PowerupType.bomb:
        return '#FF5722'; // Deep Orange
    }
  }
}

// In powerup_model.dart - UPDATE the PowerupSpawn class

class PowerupSpawn {
  final String id;
  final PowerupType type;
  final int row; // 🔥 UPDATED: May be -1 if not positioned yet
  final int col; // 🔥 UPDATED: May be -1 if not positioned yet
  final DateTime spawnTime;
  final String? claimedBy;
  final DateTime? claimedAt;
  final bool isActive;

  PowerupSpawn({
    required this.id,
    required this.type,
    required this.row,
    required this.col,
    required this.spawnTime,
    this.claimedBy,
    this.claimedAt,
    this.isActive = true,
  });

  factory PowerupSpawn.fromMap(Map<String, dynamic> map) {
    return PowerupSpawn(
      id: map['id'] ?? '',
      type: PowerupType.values.firstWhere(
            (e) => e.toString() == map['type'],
        orElse: () => PowerupType.revealTwoCells,
      ),
      row: map['row'] ?? -1, // 🔥 UPDATED: Default to -1 for unpositioned
      col: map['col'] ?? -1, // 🔥 UPDATED: Default to -1 for unpositioned
      spawnTime: DateTime.fromMillisecondsSinceEpoch(map['spawnTime'] ?? 0),
      claimedBy: map['claimedBy'],
      claimedAt: map['claimedAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['claimedAt'])
          : null,
      isActive: map['isActive'] ?? true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'type': type.toString(),
      'row': row,
      'col': col,
      'spawnTime': spawnTime.millisecondsSinceEpoch,
      'claimedBy': claimedBy,
      'claimedAt': claimedAt?.millisecondsSinceEpoch,
      'isActive': isActive,
    };
  }

  factory PowerupSpawn.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return PowerupSpawn.fromMap({...data, 'id': doc.id});
  }

  PowerupSpawn copyWith({
    String? id,
    PowerupType? type,
    int? row,
    int? col,
    DateTime? spawnTime,
    String? claimedBy,
    DateTime? claimedAt,
    bool? isActive,
  }) {
    return PowerupSpawn(
      id: id ?? this.id,
      type: type ?? this.type,
      row: row ?? this.row,
      col: col ?? this.col,
      spawnTime: spawnTime ?? this.spawnTime,
      claimedBy: claimedBy ?? this.claimedBy,
      claimedAt: claimedAt ?? this.claimedAt,
      isActive: isActive ?? this.isActive,
    );
  }

  // 🔥 NEW: Check if this powerup has a valid position
  bool get hasValidPosition => row >= 0 && col >= 0;
}
class PlayerPowerup {
  final String id;
  final PowerupType type;
  final String playerId;
  final DateTime obtainedAt;
  final bool isUsed;
  final DateTime? usedAt;

  PlayerPowerup({
    required this.id,
    required this.type,
    required this.playerId,
    required this.obtainedAt,
    this.isUsed = false,
    this.usedAt,
  });

  factory PlayerPowerup.fromMap(Map<String, dynamic> map) {
    return PlayerPowerup(
      id: map['id'] ?? '',
      type: PowerupType.values.firstWhere(
            (e) => e.toString() == map['type'],
        orElse: () => PowerupType.revealTwoCells,
      ),
      playerId: map['playerId'] ?? '',
      obtainedAt: DateTime.fromMillisecondsSinceEpoch(map['obtainedAt'] ?? 0),
      isUsed: map['isUsed'] ?? false,
      usedAt: map['usedAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['usedAt'])
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'type': type.toString(),
      'playerId': playerId,
      'obtainedAt': obtainedAt.millisecondsSinceEpoch,
      'isUsed': isUsed,
      'usedAt': usedAt?.millisecondsSinceEpoch,
    };
  }

  factory PlayerPowerup.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return PlayerPowerup.fromMap({...data, 'id': doc.id});
  }

  PlayerPowerup copyWith({
    String? id,
    PowerupType? type,
    String? playerId,
    DateTime? obtainedAt,
    bool? isUsed,
    DateTime? usedAt,
  }) {
    return PlayerPowerup(
      id: id ?? this.id,
      type: type ?? this.type,
      playerId: playerId ?? this.playerId,
      obtainedAt: obtainedAt ?? this.obtainedAt,
      isUsed: isUsed ?? this.isUsed,
      usedAt: usedAt ?? this.usedAt,
    );
  }
}

class PowerupEffect {
  final String id;
  final PowerupType type;
  final String targetPlayerId;
  final String sourcePlayerId;
  final DateTime appliedAt;
  final DateTime? expiresAt;
  final bool isActive;
  final Map<String, dynamic> data;

  PowerupEffect({
    required this.id,
    required this.type,
    required this.targetPlayerId,
    required this.sourcePlayerId,
    required this.appliedAt,
    this.expiresAt,
    this.isActive = true,
    this.data = const {},
  });

  factory PowerupEffect.fromMap(Map<String, dynamic> map) {
    return PowerupEffect(
      id: map['id'] ?? '',
      type: PowerupType.values.firstWhere(
            (e) => e.toString() == map['type'],
        orElse: () => PowerupType.revealTwoCells,
      ),
      targetPlayerId: map['targetPlayerId'] ?? '',
      sourcePlayerId: map['sourcePlayerId'] ?? '',
      appliedAt: DateTime.fromMillisecondsSinceEpoch(map['appliedAt'] ?? 0),
      expiresAt: map['expiresAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['expiresAt'])
          : null,
      isActive: map['isActive'] ?? true,
      data: Map<String, dynamic>.from(map['data'] ?? {}),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'type': type.toString(),
      'targetPlayerId': targetPlayerId,
      'sourcePlayerId': sourcePlayerId,
      'appliedAt': appliedAt.millisecondsSinceEpoch,
      'expiresAt': expiresAt?.millisecondsSinceEpoch,
      'isActive': isActive,
      'data': data,
    };
  }

  factory PowerupEffect.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return PowerupEffect.fromMap({...data, 'id': doc.id});
  }

  bool get isExpired {
    if (expiresAt == null) return false;
    return DateTime.now().isAfter(expiresAt!);
  }

  PowerupEffect copyWith({
    String? id,
    PowerupType? type,
    String? targetPlayerId,
    String? sourcePlayerId,
    DateTime? appliedAt,
    DateTime? expiresAt,
    bool? isActive,
    Map<String, dynamic>? data,
  }) {
    return PowerupEffect(
      id: id ?? this.id,
      type: type ?? this.type,
      targetPlayerId: targetPlayerId ?? this.targetPlayerId,
      sourcePlayerId: sourcePlayerId ?? this.sourcePlayerId,
      appliedAt: appliedAt ?? this.appliedAt,
      expiresAt: expiresAt ?? this.expiresAt,
      isActive: isActive ?? this.isActive,
      data: data ?? this.data,
    );
  }
}