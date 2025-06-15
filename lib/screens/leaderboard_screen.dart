import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/ranking_service.dart';

class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({Key? key}) : super(key: key);

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Global Leaderboard'),
        backgroundColor: Colors.purple,
        foregroundColor: Colors.white,
      ),
      body: _buildGlobalLeaderboard(),
    );
  }

  Widget _buildPlayerAvatar({
    String? avatarUrl,
    required String playerName,
    required double radius,
  }) {
    final fallbackChild = CircleAvatar(
      radius: radius,
      backgroundColor: Colors.grey.shade300,
      child: Text(
        playerName.isNotEmpty ? playerName[0].toUpperCase() : '?',
        style: TextStyle(
          fontSize: radius * 0.9,
          color: Colors.grey.shade700,
          fontWeight: FontWeight.bold,
        ),
      ),
    );

    if (avatarUrl == null || avatarUrl.isEmpty) {
      return fallbackChild;
    }

    return CircleAvatar(
      radius: radius,
      backgroundColor: Colors.grey.shade200,
      child: ClipOval(
        child: Image.network(
          avatarUrl,
          fit: BoxFit.cover,
          width: radius * 2,
          height: radius * 2,
          errorBuilder: (context, error, stackTrace) {
            return fallbackChild;
          },
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return Center(
              child: CircularProgressIndicator(
                strokeWidth: 2,
                value: loadingProgress.expectedTotalBytes != null
                    ? loadingProgress.cumulativeBytesLoaded /
                    loadingProgress.expectedTotalBytes!
                    : null,
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildGlobalLeaderboard() {
    return FutureBuilder<List<PlayerRank>>(
      future: RankingService.getLeaderboard(limit: 100),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(color: Colors.purple),
                SizedBox(height: 16),
                Text('Loading leaderboard...'),
              ],
            ),
          );
        }

        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error, size: 64, color: Colors.red),
                SizedBox(height: 16),
                Text('Error loading leaderboard', style: Theme.of(context).textTheme.titleMedium),
                SizedBox(height: 8),
                Text('Please check your connection and try again', style: TextStyle(color: Colors.grey[600])),
                SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => setState(() {}),
                  child: Text('Retry'),
                ),
              ],
            ),
          );
        }

        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.emoji_events, size: 64, color: Colors.grey),
                SizedBox(height: 16),
                Text('No ranked players yet', style: Theme.of(context).textTheme.titleMedium),
                SizedBox(height: 8),
                Text('Be the first to play ranked matches!', style: TextStyle(color: Colors.grey[600])),
                SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('Play Ranked'),
                ),
              ],
            ),
          );
        }

        final players = snapshot.data!;
        return Column(
          children: [
            if (players.length >= 3) _buildPodium(players.take(3).toList()),
            Expanded(
              child: ListView.builder(
                padding: EdgeInsets.all(16),
                itemCount: players.length,
                itemBuilder: (context, index) {
                  final player = players[index];
                  final isCurrentUser = FirebaseAuth.instance.currentUser?.uid == player.playerId;

                  return Card(
                    margin: EdgeInsets.only(bottom: 8),
                    color: isCurrentUser ? Colors.purple.withOpacity(0.1) : null,
                    child: ListTile(
                      leading: _buildRankIcon(player.rank),
                      title: Row(
                        children: [
                          _buildPlayerAvatar(
                              avatarUrl: player.avatarUrl,
                              playerName: player.playerName,
                              radius: 20
                          ),
                          SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        player.playerName,
                                        style: TextStyle(fontWeight: FontWeight.bold, color: isCurrentUser ? Colors.purple : null),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    if (isCurrentUser)
                                      Container(
                                        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                        decoration: BoxDecoration(color: Colors.purple, borderRadius: BorderRadius.circular(10)),
                                        child: Text('YOU', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                                      ),
                                  ],
                                ),
                                Text(
                                  '${player.gamesPlayed} games • ${player.winRate.toStringAsFixed(1)}% win rate',
                                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      trailing: Container(
                        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(color: Colors.purple.withOpacity(0.1), borderRadius: BorderRadius.circular(16)),
                        child: Text('${player.rating}', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.purple, fontSize: 16)),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildPodium(List<PlayerRank> topThree) {
    return Container(
      height: 200,
      padding: EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (topThree.length > 1) Expanded(child: _buildPodiumPlace(topThree[1], 140, Colors.grey)),
          if (topThree.isNotEmpty) Expanded(child: _buildPodiumPlace(topThree[0], 180, Colors.amber)),
          if (topThree.length > 2) Expanded(child: _buildPodiumPlace(topThree[2], 100, Colors.orange)),
        ],
      ),
    );
  }

  Widget _buildPodiumPlace(PlayerRank player, double height, Color color) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        _buildPlayerAvatar(
          avatarUrl: player.avatarUrl,
          playerName: player.playerName,
          radius: 25,
        ),
        SizedBox(height: 8),
        Text(player.playerName, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12), textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis),
        Text('${player.rating}', style: TextStyle(fontWeight: FontWeight.bold, color: color)),
        SizedBox(height: 4),
        Container(
          height: height,
          decoration: BoxDecoration(
            color: color.withOpacity(0.2),
            borderRadius: BorderRadius.vertical(top: Radius.circular(8)),
            border: Border.all(color: color, width: 2),
          ),
          child: Center(child: Text(player.rankDisplay, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: color))),
        ),
      ],
    );
  }

  Widget _buildRankIcon(int rank) {
    if (rank <= 3) {
      final icons = [Icons.looks_one, Icons.looks_two, Icons.looks_3];
      final colors = [Colors.amber, Colors.grey, Colors.orange];
      return CircleAvatar(
        radius: 20,
        backgroundColor: colors[rank - 1].withOpacity(0.2),
        child: Icon(icons[rank - 1], color: colors[rank - 1], size: 24),
      );
    }
    return CircleAvatar(
      radius: 20,
      backgroundColor: Colors.purple.withOpacity(0.1),
      child: Text('#$rank', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.purple, fontSize: 12)),
    );
  }
}
