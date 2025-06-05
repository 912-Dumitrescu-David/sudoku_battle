class Lobby {
  final String id; // 6-digit code or Firestore doc id
  final String type; // 'public' or 'private'
  final String hostUid;
  final String hostUsername;
  final String? guestUid;
  final String? guestUsername;
  final String status; // 'waiting', 'full', 'started'
  final String? puzzle; // JSON or String

  Lobby({
    required this.id,
    required this.type,
    required this.hostUid,
    required this.hostUsername,
    this.guestUid,
    this.guestUsername,
    required this.status,
    this.puzzle,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'type': type,
      'hostUid': hostUid,
      'hostUsername': hostUsername,
      'guestUid': guestUid,
      'guestUsername': guestUsername,
      'status': status,
      'puzzle': puzzle,
      'createdAt': DateTime.now(),
    };
  }

  factory Lobby.fromMap(Map<String, dynamic> map) {
    return Lobby(
      id: map['id'] ?? '',
      type: map['type'] ?? 'public',
      hostUid: map['hostUid'] ?? '',
      hostUsername: map['hostUsername'] ?? '',
      guestUid: map['guestUid'],
      guestUsername: map['guestUsername'],
      status: map['status'] ?? 'waiting',
      puzzle: map['puzzle'],
    );
  }

  //tojson


}
