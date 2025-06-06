import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/ranking_service.dart';

class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({Key? key}) : super(key: key);

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  PlayerRank? _currentPlayerRank;
  bool _loadingCurrentRank = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadCurrentPlayerRank();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadCurrentPlayerRank() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        final rank = await RankingService.getPlayerRank(user.uid);
        setState(() {
          _currentPlayerRank = rank;
          _loadingCurrentRank = false;
        });
      } catch (e) {
        setState(() {
          _loadingCurrentRank = false;
        });
      }
    } else {
      setState(() {
        _loadingCurrentRank = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Leaderboard'),
        backgroundColor: Colors.purple,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(
              icon: Icon(Icons.leaderboard),
              text: 'Global',
            ),
            Tab(
              icon: Icon(Icons.person),
              text: 'My Rank',
            ),
          ],
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildGlobalLeaderboard(),
          _buildMyRankTab(),
        ],
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
                Text(
                  'Error loading leaderboard',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                SizedBox(height: 8),
                Text(
                  'Please check your connection and try again',
                  style: TextStyle(color: Colors.grey[600]),
                ),
                SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () {
                    setState(() {}); // Trigger rebuild to retry
                  },
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
                Icon(
                  Icons.emoji_events,
                  size: 64,
                  color: Colors.grey,
                ),
                SizedBox(height: 16),
                Text(
                  'No ranked players yet',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                SizedBox(height: 8),
                Text(
                  'Be the first to play ranked matches!',
                  style: TextStyle(color: Colors.grey[600]),
                ),
                SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context); // Go back to queue
                  },
                  child: Text('Play Ranked'),
                ),
              ],
            ),
          );
        }

        final players = snapshot.data!;
        return Column(
          children: [
            // Top 3 podium
            if (players.length >= 3) _buildPodium(players.take(3).toList()),

            // Rest of the list
            Expanded(
              child: ListView.builder(
                padding: EdgeInsets.all(16),
                itemCount: players.length,
                itemBuilder: (context, index) {
                  final player = players[index];
                  final isCurrentUser = FirebaseAuth.instance.currentUser?.uid == player.playerId;

                  return Card(
                    margin: EdgeInsets.only(bottom: 8),
                    color: isCurrentUser
                        ? Colors.purple.withOpacity(0.1)
                        : null,
                    child: ListTile(
                      leading: _buildRankIcon(player.rank),
                      title: Row(
                        children: [
                          CircleAvatar(
                            radius: 20,
                            backgroundImage: player.avatarUrl != null
                                ? NetworkImage(player.avatarUrl!)
                                : null,
                            child: player.avatarUrl == null
                                ? Icon(Icons.person)
                                : null,
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
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: isCurrentUser ? Colors.purple : null,
                                        ),
                                      ),
                                    ),
                                    if (isCurrentUser)
                                      Container(
                                        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: Colors.purple,
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                        child: Text(
                                          'YOU',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                                Text(
                                  '${player.gamesPlayed} games • ${player.winRate.toStringAsFixed(1)}% win rate',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      trailing: Container(
                        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.purple.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(
                          '${player.rating}',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.purple,
                            fontSize: 16,
                          ),
                        ),
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
          // 2nd place
          if (topThree.length > 1)
            Expanded(child: _buildPodiumPlace(topThree[1], 140, Colors.grey)),

          // 1st place
          Expanded(child: _buildPodiumPlace(topThree[0], 180, Colors.amber)),

          // 3rd place
          if (topThree.length > 2)
            Expanded(child: _buildPodiumPlace(topThree[2], 100, Colors.orange)),
        ],
      ),
    );
  }

  Widget _buildPodiumPlace(PlayerRank player, double height, Color color) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        CircleAvatar(
          radius: 25,
          backgroundImage: player.avatarUrl != null
              ? NetworkImage(player.avatarUrl!)
              : null,
          child: player.avatarUrl == null
              ? Icon(Icons.person, size: 30)
              : null,
        ),
        SizedBox(height: 8),
        Text(
          player.playerName,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        Text(
          '${player.rating}',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        SizedBox(height: 4),
        Container(
          height: height,
          decoration: BoxDecoration(
            color: color.withOpacity(0.2),
            borderRadius: BorderRadius.vertical(top: Radius.circular(8)),
            border: Border.all(color: color, width: 2),
          ),
          child: Center(
            child: Text(
              player.rankDisplay,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMyRankTab() {
    if (_loadingCurrentRank) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Colors.purple),
            SizedBox(height: 16),
            Text('Loading your rank...'),
          ],
        ),
      );
    }

    if (_currentPlayerRank == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.info,
              size: 64,
              color: Colors.grey,
            ),
            SizedBox(height: 16),
            Text(
              'No Ranking Yet',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            SizedBox(height: 8),
            Text(
              'Play ranked matches to get your ranking!',
              style: TextStyle(color: Colors.grey[600]),
            ),
            SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context); // Go back to queue
              },
              child: Text('Play Ranked'),
            ),
          ],
        ),
      );
    }

    final rank = _currentPlayerRank!;
    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        children: [
          // Profile card
          Card(
            elevation: 4,
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 50,
                    backgroundImage: rank.avatarUrl != null
                        ? NetworkImage(rank.avatarUrl!)
                        : null,
                    child: rank.avatarUrl == null
                        ? Icon(Icons.person, size: 50)
                        : null,
                  ),
                  SizedBox(height: 16),
                  Text(
                    rank.playerName,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 8),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.purple.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      'Rank ${rank.rankDisplay}',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.purple,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          SizedBox(height: 16),

          // Stats cards
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  'Rating',
                  '${rank.rating}',
                  Icons.star,
                  Colors.purple,
                ),
              ),
              SizedBox(width: 8),
              Expanded(
                child: _buildStatCard(
                  'Games',
                  '${rank.gamesPlayed}',
                  Icons.games,
                  Colors.blue,
                ),
              ),
            ],
          ),

          SizedBox(height: 8),

          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  'Wins',
                  '${rank.gamesWon}',
                  Icons.emoji_events,
                  Colors.green,
                ),
              ),
              SizedBox(width: 8),
              Expanded(
                child: _buildStatCard(
                  'Win Rate',
                  '${rank.winRate.toStringAsFixed(1)}%',
                  Icons.trending_up,
                  Colors.orange,
                ),
              ),
            ],
          ),

          SizedBox(height: 24),

          // Progress to next rank (if applicable)
          if (rank.rank > 1) _buildRankProgress(rank),
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(icon, color: color, size: 32),
            SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(
              title,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRankProgress(PlayerRank rank) {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Rank Progress',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 12),
            Text(
              'You are currently rank #${rank.rank}',
              style: TextStyle(color: Colors.grey[600]),
            ),
            SizedBox(height: 8),
            Text(
              'Keep playing ranked matches to climb higher!',
              style: TextStyle(color: Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRankIcon(int rank) {
    if (rank <= 3) {
      final icons = [Icons.looks_one, Icons.looks_two, Icons.looks_3];
      final colors = [Colors.amber, Colors.grey, Colors.orange];

      return CircleAvatar(
        radius: 20,
        backgroundColor: colors[rank - 1].withOpacity(0.2),
        child: Icon(
          icons[rank - 1],
          color: colors[rank - 1],
          size: 24,
        ),
      );
    }

    return CircleAvatar(
      radius: 20,
      backgroundColor: Colors.purple.withOpacity(0.1),
      child: Text(
        '#$rank',
        style: TextStyle(
          fontWeight: FontWeight.bold,
          color: Colors.purple,
          fontSize: 12,
        ),
      ),
    );
  }
}