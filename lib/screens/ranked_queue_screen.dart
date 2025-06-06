import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import '../services/ranking_service.dart';
import '../providers/lobby_provider.dart';
import 'lobby_detail_screen.dart';
import 'leaderboard_screen.dart';
import '../widgets/debug_ranking_widget.dart';

class RankedQueueScreen extends StatefulWidget {
  const RankedQueueScreen({Key? key}) : super(key: key);

  @override
  State<RankedQueueScreen> createState() => _RankedQueueScreenState();
}

class _RankedQueueScreenState extends State<RankedQueueScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  StreamSubscription? _queueSubscription;
  Timer? _matchmakingTimer;
  Timer? _searchRadiusTimer;
  late AnimationController _pulseController;
  late AnimationController _progressController;

  bool _isInQueue = false;
  QueueStatus? _queueStatus;
  int _secondsInQueue = 0;
  int? _currentRating; // 🔥 Add current rating display

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this); // 🔥 Add observer

    _pulseController = AnimationController(
      duration: Duration(seconds: 2),
      vsync: this,
    );

    _progressController = AnimationController(
      duration: Duration(seconds: 20), // 20 seconds for search radius expansion
      vsync: this,
    );

    _loadCurrentRating(); // 🔥 Load rating on init
    _listenToQueue();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this); // 🔥 Remove observer
    _queueSubscription?.cancel();
    _matchmakingTimer?.cancel();
    _searchRadiusTimer?.cancel();
    _pulseController.dispose();
    _progressController.dispose();
    super.dispose();
  }

  // 🔥 Detect when app resumes (when user returns from ranked match)
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      print('🔄 App resumed in ranked queue - refreshing rating');
      _loadCurrentRating();
    }
  }

  // 🔥 Load current player rating
  Future<void> _loadCurrentRating() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        print('🔄 Loading current rating for ranked queue');

        // Force refresh from server to get latest rating
        final userDoc = await FirebaseFirestore.instanceFor(
          app: Firebase.app(),
          databaseId: 'lobbies',
        ).collection('users').doc(user.uid).get(const GetOptions(source: Source.server));

        if (userDoc.exists && mounted) {
          final newRating = userDoc.data()?['rating'] ?? 1000;
          print('✅ Loaded rating for queue: $newRating');

          setState(() {
            _currentRating = newRating;
          });
        }
      }
    } catch (e) {
      print('Error loading rating in queue: $e');
      // Fallback to cache
      try {
        final user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          final userDoc = await FirebaseFirestore.instanceFor(
            app: Firebase.app(),
            databaseId: 'lobbies',
          ).collection('users').doc(user.uid).get(const GetOptions(source: Source.cache));

          if (userDoc.exists && mounted) {
            setState(() {
              _currentRating = userDoc.data()?['rating'] ?? 1000;
            });
          }
        }
      } catch (cacheError) {
        print('Cache error in queue: $cacheError');
      }
    }
  }

  void _listenToQueue() {
    _queueSubscription = RankingService.getQueueStatus().listen((status) {
      setState(() {
        _queueStatus = status;
        _isInQueue = status != null;
      });

      if (status != null) {
        if (status.isMatched && status.lobbyId != null) {
          // Match found! Navigate to lobby
          _handleMatchFound(status.lobbyId!);
        } else if (!status.isMatched) {
          // Still searching
          _startSearchTimers();
        }
      } else {
        // Not in queue
        _stopSearchTimers();
      }
    });
  }

  void _startSearchTimers() {
    // Timer for updating search duration
    _matchmakingTimer?.cancel();
    _matchmakingTimer = Timer.periodic(Duration(seconds: 1), (timer) {
      setState(() {
        _secondsInQueue++;
      });
    });

    // Timer for search radius expansion every 20 seconds
    _searchRadiusTimer?.cancel();
    _searchRadiusTimer = Timer.periodic(Duration(seconds: 20), (timer) {
      print('⏰ 20 seconds passed, expanding search radius...');
      // The backend will handle radius expansion
    });

    // Start animations
    _pulseController.repeat();
    _progressController.repeat();
  }

  void _stopSearchTimers() {
    _matchmakingTimer?.cancel();
    _searchRadiusTimer?.cancel();
    _pulseController.stop();
    _progressController.stop();
    setState(() {
      _secondsInQueue = 0;
    });
  }

  void _handleMatchFound(String lobbyId) {
    _stopSearchTimers();

    // Show match found dialog briefly
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green),
            SizedBox(width: 8),
            Text('Match Found!'),
          ],
        ),
        content: Text('Connecting to your opponent...'),
      ),
    );

    // Navigate to lobby after a short delay
    Timer(Duration(seconds: 2), () {
      Navigator.of(context).pop(); // Close dialog
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => LobbyDetailScreen(lobbyId: lobbyId),
        ),
      ).then((_) {
        // 🔥 Refresh rating when returning from match
        _loadCurrentRating();
      });
    });
  }

  Future<void> _joinQueue() async {
    try {
      setState(() {
        _isInQueue = true;
        _secondsInQueue = 0;
      });

      await RankingService.joinRankedQueue();
      print('✅ Successfully joined ranked queue');

      // Start looking for matches immediately and periodically
      _startMatchmaking();

    } catch (e) {
      print('❌ Error joining queue: $e');
      setState(() {
        _isInQueue = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to join queue: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _startMatchmaking() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    print('🔍 Starting matchmaking for user: ${user.uid}');

    // Try to find a match every 3 seconds
    Timer.periodic(Duration(seconds: 3), (timer) async {
      if (!_isInQueue || _queueStatus?.isMatched == true) {
        print('⏹️ Stopping matchmaking - not in queue or already matched');
        timer.cancel();
        return;
      }

      try {
        print('🔍 Attempting to find match...');
        final lobbyId = await RankingService.findRankedMatch(user.uid);

        if (lobbyId != null) {
          print('✅ Match found! Lobby ID: $lobbyId');
          timer.cancel();
          // The stream listener will handle navigation when isMatched becomes true
        } else {
          print('⏰ No match found yet, continuing search...');
        }
      } catch (e) {
        print('❌ Error during matchmaking: $e');
      }
    });
  }

  Future<void> _leaveQueue() async {
    try {
      await RankingService.leaveRankedQueue();
      _stopSearchTimers();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to leave queue: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Ranked Queue'),
        backgroundColor: Colors.purple,
        foregroundColor: Colors.white,
        actions: [
          // 🔥 Add rating display in app bar
          if (_currentRating != null)
            Padding(
              padding: EdgeInsets.only(right: 16),
              child: Center(
                child: GestureDetector(
                  onTap: _loadCurrentRating, // 🔥 Tap to refresh
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.star, color: Colors.white, size: 16),
                        SizedBox(width: 4),
                        Text(
                          '$_currentRating',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
      body: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            // Queue status card
            _buildQueueStatusCard(),

            SizedBox(height: 24),

            // Action button
            _buildActionButton(),

            SizedBox(height: 24),

            // Info cards
            _buildInfoCards(),

            Spacer(),

            // Leaderboard preview
            _buildLeaderboardPreview(),
          ],
        ),
      ),
    );
  }

  Widget _buildQueueStatusCard() {
    return Card(
      elevation: 4,
      child: Padding(
        padding: EdgeInsets.all(20),
        child: Column(
          children: [
            if (_isInQueue) ...[
              // In queue - show search status
              AnimatedBuilder(
                animation: _pulseController,
                builder: (context, child) {
                  return Transform.scale(
                    scale: 1.0 + (_pulseController.value * 0.1),
                    child: Icon(
                      Icons.search,
                      size: 64,
                      color: Colors.purple,
                    ),
                  );
                },
              ),
              SizedBox(height: 16),
              Text(
                'Searching for Opponent',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: Colors.purple,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 8),
              Text(_formatSearchTime(_secondsInQueue)),
              SizedBox(height: 16),
              if (_queueStatus != null) ...[
                _buildSearchInfo(),
                SizedBox(height: 16),
                // Search progress indicator
                LinearProgressIndicator(
                  backgroundColor: Colors.grey[300],
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.purple),
                ),
              ],
            ] else ...[
              // Not in queue - show join prompt
              Icon(
                Icons.emoji_events,
                size: 64,
                color: Colors.purple,
              ),
              SizedBox(height: 16),
              Text(
                'Ready for Ranked?',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 8),
              Text(
                'Compete against players of similar skill level',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey[600],
                ),
              ),
              // 🔥 Show current rating in queue status
              if (_currentRating != null) ...[
                SizedBox(height: 12),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.purple.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.purple.withOpacity(0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.star, color: Colors.purple, size: 20),
                      SizedBox(width: 4),
                      Text(
                        'Your Rating: $_currentRating',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.purple,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSearchInfo() {
    // 🔥 Use current rating from state instead of queue status for more up-to-date info
    final rating = _currentRating ?? _queueStatus?.rating ?? 1000;
    final searchRadius = _queueStatus?.searchRadius ?? 100;

    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.purple.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Your Rating:'),
              Text(
                '$rating',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Search Range:'),
              Text(
                '${rating - searchRadius} - ${rating + searchRadius}',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton() {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: ElevatedButton(
        onPressed: _isInQueue ? _leaveQueue : _joinQueue,
        style: ElevatedButton.styleFrom(
          backgroundColor: _isInQueue ? Colors.red : Colors.purple,
          foregroundColor: Colors.white,
        ),
        child: Text(
          _isInQueue ? 'Leave Queue' : 'Join Ranked Queue',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Widget _buildInfoCards() {
    return Row(
      children: [
        Expanded(
          child: Card(
            child: Padding(
              padding: EdgeInsets.all(12),
              child: Column(
                children: [
                  Icon(Icons.timer, color: Colors.orange, size: 32),
                  SizedBox(height: 8),
                  Text(
                    '10 Min',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  Text(
                    'Time Limit',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        SizedBox(width: 8),
        Expanded(
          child: Card(
            child: Padding(
              padding: EdgeInsets.all(12),
              child: Column(
                children: [
                  Icon(Icons.block, color: Colors.red, size: 32),
                  SizedBox(height: 8),
                  Text(
                    'No Hints',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  Text(
                    'Pure Skill',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        SizedBox(width: 8),
        Expanded(
          child: Card(
            child: Padding(
              padding: EdgeInsets.all(12),
              child: Column(
                children: [
                  Icon(Icons.trending_up, color: Colors.green, size: 32),
                  SizedBox(height: 8),
                  Text(
                    'ELO',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  Text(
                    'Rating',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLeaderboardPreview() {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Leaderboard',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                TextButton(
                  onPressed: () {
                    // Navigate to full leaderboard
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => LeaderboardScreen(),
                      ),
                    );
                  },
                  child: Text('View All'),
                ),
              ],
            ),
            SizedBox(height: 8),
            FutureBuilder<List<PlayerRank>>(
              future: RankingService.getLeaderboard(limit: 3),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(child: CircularProgressIndicator());
                }

                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return Text('No ranked players yet');
                }

                final topPlayers = snapshot.data!;
                return Column(
                  children: topPlayers.map((player) =>
                      _buildLeaderboardItem(player)).toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLeaderboardItem(PlayerRank player) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(
            width: 30,
            child: Text(
              player.rankDisplay,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
          SizedBox(width: 8),
          CircleAvatar(
            radius: 16,
            backgroundImage: player.avatarUrl != null
                ? NetworkImage(player.avatarUrl!)
                : null,
            child: player.avatarUrl == null
                ? Icon(Icons.person, size: 16)
                : null,
          ),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              player.playerName,
              style: TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          Text(
            '${player.rating}',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.purple,
            ),
          ),
        ],
      ),
    );
  }

  String _formatSearchTime(int seconds) {
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;

    if (minutes > 0) {
      return 'Searching for ${minutes}m ${remainingSeconds}s';
    } else {
      return 'Searching for ${remainingSeconds}s';
    }
  }
}