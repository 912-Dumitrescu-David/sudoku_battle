import 'package:cloud_firestore/cloud_firestore.dart';

enum LobbyStatus { waiting, starting, inProgress, completed }
enum GameMode { classic, powerup, coop }

class Player {
  final String id;
  final String name;
  final String? avatarUrl;
  final int rating;
  final DateTime joinedAt;

  Player({
    required this.id,
    required this.name,
    this.avatarUrl,
    required this.rating,
    required this.joinedAt,
  });

  factory Player.fromMap(Map<String, dynamic> map) {
    return Player(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      avatarUrl: map['avatarUrl'],
      rating: map['rating'] ?? 1000,
      joinedAt: DateTime.fromMillisecondsSinceEpoch(map['joinedAt'] ?? 0),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'avatarUrl': avatarUrl,
      'rating': rating,
      'joinedAt': joinedAt.millisecondsSinceEpoch,
    };
  }
}

class GameSettings {
  final int? timeLimit; // in seconds, null for no limit
  final bool allowHints;
  final bool allowMistakes;
  final int maxMistakes;
  final String difficulty;

  GameSettings({
    this.timeLimit,
    this.allowHints = true,
    this.allowMistakes = true,
    this.maxMistakes = 3,
    this.difficulty = 'medium',
  });

  factory GameSettings.fromMap(Map<String, dynamic> map) {
    return GameSettings(
      timeLimit: map['timeLimit'],
      allowHints: map['allowHints'] ?? true,
      allowMistakes: map['allowMistakes'] ?? true,
      maxMistakes: map['maxMistakes'] ?? 3,
      difficulty: map['difficulty'] ?? 'medium',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'timeLimit': timeLimit,
      'allowHints': allowHints,
      'allowMistakes': allowMistakes,
      'maxMistakes': maxMistakes,
      'difficulty': difficulty,
    };
  }
}

class Lobby {
  final String id;
  final String hostPlayerId;
  final String hostPlayerName;
  final GameMode gameMode;
  final bool isPrivate;
  final String? accessCode;
  final int maxPlayers;
  final int currentPlayers;
  final List<Player> playersList;
  final GameSettings gameSettings;
  final LobbyStatus status;
  final DateTime createdAt;
  final DateTime? startedAt;
  final String? gameSessionId;
  final String? gameServerEndpoint;
  final Map<String, dynamic>? sharedPuzzle; // Add shared puzzle
  final bool isRanked; // Add ranked flag
  final int? sharedHintCount;
  final int? sharedMistakeCount;

  Lobby({
    required this.id,
    required this.hostPlayerId,
    required this.hostPlayerName,
    required this.gameMode,
    required this.isPrivate,
    this.accessCode,
    required this.maxPlayers,
    required this.currentPlayers,
    required this.playersList,
    required this.gameSettings,
    required this.status,
    required this.createdAt,
    this.startedAt,
    this.gameSessionId,
    this.gameServerEndpoint,
    this.sharedPuzzle, // Add to constructor
    this.isRanked = false,
    this.sharedHintCount,
    this.sharedMistakeCount,
  });

  factory Lobby.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;

    return Lobby(
      id: doc.id,
      hostPlayerId: data['hostPlayerId'] ?? '',
      hostPlayerName: data['hostPlayerName'] ?? '',
      gameMode: _getGameModeFromString(data['gameMode'] ?? 'classic'),
      isPrivate: data['isPrivate'] ?? false,
      accessCode: data['accessCode'],
      maxPlayers: data['maxPlayers'] ?? 2,
      currentPlayers: data['currentPlayers'] ?? 0,
      playersList: (data['playersList'] as List<dynamic>?)
          ?.map((player) => Player.fromMap(player as Map<String, dynamic>))
          .toList() ?? [],
      gameSettings: GameSettings.fromMap(data['gameSettings'] ?? {}),
      status: _getLobbyStatusFromString(data['status'] ?? 'waiting'),
      createdAt: DateTime.fromMillisecondsSinceEpoch(data['createdAt'] ?? 0),
      startedAt: data['startedAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(data['startedAt'])
          : null,
      gameSessionId: data['gameSessionId'],
      gameServerEndpoint: data['gameServerEndpoint'],
      sharedPuzzle: data['sharedPuzzle'] as Map<String, dynamic>?,
      isRanked: data['isRanked'] ?? false,
      sharedHintCount: data['sharedHintCount'],
      sharedMistakeCount: data['sharedMistakeCount'],
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'hostPlayerId': hostPlayerId,
      'hostPlayerName': hostPlayerName,
      'gameMode': gameMode.toString().split('.').last,
      'isPrivate': isPrivate,
      'accessCode': accessCode,
      'maxPlayers': maxPlayers,
      'currentPlayers': currentPlayers,
      'playersList': playersList.map((player) => player.toMap()).toList(),
      'gameSettings': gameSettings.toMap(),
      'status': status.toString().split('.').last,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'startedAt': startedAt?.millisecondsSinceEpoch,
      'gameSessionId': gameSessionId,
      'gameServerEndpoint': gameServerEndpoint,
      'sharedPuzzle': sharedPuzzle,
      'isRanked': isRanked,
      'sharedHintCount': sharedHintCount,
      'sharedMistakeCount': sharedMistakeCount,
    };
  }

  static GameMode _getGameModeFromString(String mode) {
    switch (mode.toLowerCase()) {
      case 'classic':
        return GameMode.classic;
      case 'powerup':
        return GameMode.powerup;
      case 'coop':
        return GameMode.coop;
      default:
        return GameMode.classic;
    }
  }

  static LobbyStatus _getLobbyStatusFromString(String status) {
    switch (status.toLowerCase()) {
      case 'waiting':
        return LobbyStatus.waiting;
      case 'starting':
        return LobbyStatus.starting;
      case 'inprogress':
        return LobbyStatus.inProgress;
      case 'completed':
        return LobbyStatus.completed;
      default:
        return LobbyStatus.waiting;
    }
  }

  Lobby copyWith({
    String? id,
    String? hostPlayerId,
    String? hostPlayerName,
    GameMode? gameMode,
    bool? isPrivate,
    String? accessCode,
    int? maxPlayers,
    int? currentPlayers,
    List<Player>? playersList,
    GameSettings? gameSettings,
    LobbyStatus? status,
    DateTime? createdAt,
    DateTime? startedAt,
    String? gameSessionId,
    String? gameServerEndpoint,
    Map<String, dynamic>? sharedPuzzle,
    bool? isRanked,
  }) {
    return Lobby(
      id: id ?? this.id,
      hostPlayerId: hostPlayerId ?? this.hostPlayerId,
      hostPlayerName: hostPlayerName ?? this.hostPlayerName,
      gameMode: gameMode ?? this.gameMode,
      isPrivate: isPrivate ?? this.isPrivate,
      accessCode: accessCode ?? this.accessCode,
      maxPlayers: maxPlayers ?? this.maxPlayers,
      currentPlayers: currentPlayers ?? this.currentPlayers,
      playersList: playersList ?? this.playersList,
      gameSettings: gameSettings ?? this.gameSettings,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      startedAt: startedAt ?? this.startedAt,
      gameSessionId: gameSessionId ?? this.gameSessionId,
      gameServerEndpoint: gameServerEndpoint ?? this.gameServerEndpoint,
      sharedPuzzle: sharedPuzzle ?? this.sharedPuzzle,
      isRanked: isRanked ?? this.isRanked,
    );
  }
}

class LobbyCreationRequest {
  final GameMode gameMode;
  final bool isPrivate;
  final int maxPlayers;
  final GameSettings gameSettings;

  LobbyCreationRequest({
    required this.gameMode,
    required this.isPrivate,
    required this.maxPlayers,
    required this.gameSettings,
  });
}