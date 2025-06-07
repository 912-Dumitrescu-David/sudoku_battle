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
  Timer? _maxTimeTimer; // 🔥 NEW: Timer for max queue time
  late AnimationController _pulseController;
  late AnimationController _progressController;

  bool _isInQueue = false;
  QueueStatus? _queueStatus;
  int _secondsInQueue = 0;
  int? _currentRating;

  // 🔥 NEW: Cache leaderboard data to prevent constant refreshing
  List<PlayerRank>? _cachedLeaderboard;
  bool _leaderboardLoaded = false;

  // 🔥 NEW: Queue limits
  static const int MAX_QUEUE_TIME_SECONDS = 180; // 3 minutes
  static const int MAX_SEARCH_RADIUS = 600; // Max rating difference
  static const int INITIAL_SEARCH_RADIUS = 100; // Starting search radius
  static const int RADIUS_EXPANSION_INTERVAL = 20; // Expand every 20 seconds
  static const int RADIUS_EXPANSION_AMOUNT = 50; // Expand by 50 points each time

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // 🔥 FORCE CLEANUP any stale lobby state when entering ranked queue
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final lobbyProvider = context.read<LobbyProvider>();
      lobbyProvider.forceCleanupLobbyState();
    });

    _pulseController = AnimationController(
      duration: Duration(seconds: 2),
      vsync: this,
    );

    _progressController = AnimationController(
      duration: Duration(seconds: MAX_QUEUE_TIME_SECONDS), // 🔥 Use max time for progress
      vsync: this,
    );

    _loadCurrentRating();
    _loadLeaderboard(); // 🔥 Load leaderboard once at start
    _listenToQueue();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _queueSubscription?.cancel();
    _matchmakingTimer?.cancel();
    _searchRadiusTimer?.cancel();
    _maxTimeTimer?.cancel(); // 🔥 NEW: Cancel max time timer
    _pulseController.dispose();
    _progressController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      print('🔄 App resumed in ranked queue - refreshing rating');
      _loadCurrentRating();
    }
  }

  Future<void> _loadCurrentRating() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        print('🔄 Loading current rating for ranked queue');

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
      print('🔍 Queue status update: ${status?.searchRadius ?? "null"}');

      setState(() {
        _queueStatus = status;
        _isInQueue = status != null;
      });

      if (status != null) {
        if (status.isMatched && status.lobbyId != null) {
          _handleMatchFound(status.lobbyId!);
        } else if (!status.isMatched) {
          _startSearchTimers();
        }
      } else {
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

    // 🔥 NEW: Max time timer - auto-leave queue after 3 minutes
    _maxTimeTimer?.cancel();
    _maxTimeTimer = Timer(Duration(seconds: MAX_QUEUE_TIME_SECONDS), () {
      if (_isInQueue) {
        print('⏰ Max queue time reached (${MAX_QUEUE_TIME_SECONDS}s) - leaving queue');
        _handleQueueTimeout();
      }
    });

    // 🔥 FIXED: Timer for search radius expansion every 20 seconds (not every search attempt)
    _searchRadiusTimer?.cancel();
    _searchRadiusTimer = Timer.periodic(Duration(seconds: RADIUS_EXPANSION_INTERVAL), (timer) {
      print('⏰ 20 seconds passed, triggering radius expansion timer...');
      // The expansion will happen in the next findRankedMatch call
      // We don't need to do anything here - just let the next search attempt handle it
    });

    // Start animations
    _pulseController.repeat();
    _progressController.forward();
  }

  void _stopSearchTimers() {
    _matchmakingTimer?.cancel();
    _searchRadiusTimer?.cancel();
    _maxTimeTimer?.cancel(); // 🔥 NEW: Cancel max time timer
    _pulseController.stop();
    _progressController.stop();
    _progressController.reset(); // Reset progress bar
    setState(() {
      _secondsInQueue = 0;
    });
  }

  // 🔥 NEW: Handle queue timeout
  void _handleQueueTimeout() async {
    _stopSearchTimers();

    // Leave queue
    await RankingService.leaveRankedQueue();

    if (mounted) {
      // Show timeout dialog
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Row(
            children: [
              Icon(Icons.access_time, color: Colors.orange),
              SizedBox(width: 8),
              Text('Queue Timeout'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('No match found after 3 minutes.'),
              SizedBox(height: 8),
              Text('This could mean:'),
              Text('• Few players at your rating level'),
              Text('• Try playing during peak hours'),
              Text('• Consider casual multiplayer'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('OK'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _rejoinQueue();
              },
              child: Text('Try Again'),
            ),
          ],
        ),
      );
    }
  }

  // 🔥 NEW: Rejoin queue after timeout
  void _rejoinQueue() {
    _joinQueue();
  }

  void _handleMatchFound(String lobbyId) {
    _stopSearchTimers();

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

    Timer(Duration(seconds: 2), () {
      Navigator.of(context).pop();
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => LobbyDetailScreen(lobbyId: lobbyId),
        ),
      ).then((_) {
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
      print('✅ Successfully joined ranked queue with limits:');
      print('   Max time: ${MAX_QUEUE_TIME_SECONDS}s');
      print('   Max radius: $MAX_SEARCH_RADIUS');

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
          if (_currentRating != null)
            Padding(
              padding: EdgeInsets.only(right: 16),
              child: Center(
                child: GestureDetector(
                  onTap: _loadCurrentRating,
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
            _buildQueueStatusCard(),
            SizedBox(height: 24),
            _buildActionButton(),
            SizedBox(height: 24),
            _buildInfoCards(),
            Spacer(),
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
              // 🔥 NEW: Show time remaining instead of just elapsed
              Text(_formatSearchTime(_secondsInQueue)),
              // 🔥 NEW: Show warning when approaching timeout
              if (_secondsInQueue > MAX_QUEUE_TIME_SECONDS - 30) ...[
                SizedBox(height: 4),
                Text(
                  'Timeout in ${MAX_QUEUE_TIME_SECONDS - _secondsInQueue}s',
                  style: TextStyle(
                    color: Colors.orange,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
              SizedBox(height: 16),
              if (_queueStatus != null) ...[
                _buildSearchInfo(),
                SizedBox(height: 16),
                // 🔥 NEW: Progress bar showing time until timeout
                _buildTimeoutProgressBar(),
              ],
            ] else ...[
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

  // 🔥 NEW: Timeout progress bar
  Widget _buildTimeoutProgressBar() {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Time remaining:',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
            Text(
              '${MAX_QUEUE_TIME_SECONDS - _secondsInQueue}s',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: _secondsInQueue > MAX_QUEUE_TIME_SECONDS - 30
                    ? Colors.orange
                    : Colors.purple,
              ),
            ),
          ],
        ),
        SizedBox(height: 4),
        LinearProgressIndicator(
          value: _secondsInQueue / MAX_QUEUE_TIME_SECONDS,
          backgroundColor: Colors.grey[300],
          valueColor: AlwaysStoppedAnimation<Color>(
            _secondsInQueue > MAX_QUEUE_TIME_SECONDS - 30
                ? Colors.orange
                : Colors.purple,
          ),
        ),
      ],
    );
  }

  Widget _buildSearchInfo() {
    final rating = _currentRating ?? _queueStatus?.rating ?? 1000;

    // 🔥 FIXED: Calculate actual current search radius based on time in queue
    int actualSearchRadius = INITIAL_SEARCH_RADIUS;

    if (_queueStatus != null) {
      // Use the radius from queue status if available
      actualSearchRadius = _queueStatus!.searchRadius;
    } else {
      // Fallback: calculate based on time in queue
      final expansions = (_secondsInQueue / RADIUS_EXPANSION_INTERVAL).floor();
      actualSearchRadius = (INITIAL_SEARCH_RADIUS + (expansions * RADIUS_EXPANSION_AMOUNT))
          .clamp(INITIAL_SEARCH_RADIUS, MAX_SEARCH_RADIUS);
    }

    print('🔍 Debug search info:');
    print('   Seconds in queue: $_secondsInQueue');
    print('   Queue status radius: ${_queueStatus?.searchRadius}');
    print('   Calculated radius: $actualSearchRadius');

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
                '${rating - actualSearchRadius} - ${rating + actualSearchRadius}',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          SizedBox(height: 4),
          // 🔥 Show current radius and expansion info
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Current Radius:',
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
              Text(
                '±$actualSearchRadius',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: actualSearchRadius >= MAX_SEARCH_RADIUS ? Colors.orange : Colors.purple,
                ),
              ),
            ],
          ),
          // 🔥 Show radius expansion status
          if (actualSearchRadius >= MAX_SEARCH_RADIUS) ...[
            SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.info, size: 16, color: Colors.orange),
                SizedBox(width: 4),
                Text(
                  'Maximum search range reached',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.orange,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ] else ...[
            SizedBox(height: 4),
            Text(
              'Expanding every ${RADIUS_EXPANSION_INTERVAL}s (+$RADIUS_EXPANSION_AMOUNT)',
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey[600],
                fontStyle: FontStyle.italic,
              ),
              textAlign: TextAlign.center,
            ),
          ],
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
                  Icon(Icons.error_outline, color: Colors.amber, size: 32),
                  SizedBox(height: 8),
                  Text(
                    '3 Max',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  Text(
                    'Mistakes',
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
                  Icon(Icons.tune, color: Colors.blue, size: 32),
                  SizedBox(height: 8),
                  Text(
                    'Medium',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  Text(
                    'Difficulty',
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
                Row(
                  children: [
                    // 🔥 NEW: Refresh button for manual refresh
                    IconButton(
                      icon: Icon(Icons.refresh, size: 18),
                      onPressed: () {
                        setState(() {
                          _leaderboardLoaded = false;
                          _cachedLeaderboard = null;
                        });
                        _loadLeaderboard();
                      },
                      tooltip: 'Refresh leaderboard',
                    ),
                    TextButton(
                      onPressed: () {
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
              ],
            ),
            SizedBox(height: 8),
            // 🔥 FIXED: Use cached data instead of FutureBuilder
            _buildLeaderboardContent(),
          ],
        ),
      ),
    );
  }

  // 🔥 NEW: Build leaderboard content from cached data
  Widget _buildLeaderboardContent() {
    if (!_leaderboardLoaded) {
      // Still loading
      return Center(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_cachedLeaderboard == null || _cachedLeaderboard!.isEmpty) {
      // No data or empty
      return Padding(
        padding: EdgeInsets.all(16),
        child: Text(
          'No ranked players yet',
          style: TextStyle(color: Colors.grey[600]),
          textAlign: TextAlign.center,
        ),
      );
    }

    // Show cached leaderboard
    return Column(
      children: _cachedLeaderboard!.map((player) =>
          _buildLeaderboardItem(player)).toList(),
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

  // 🔥 NEW: Load leaderboard once and cache it
  Future<void> _loadLeaderboard() async {
    if (_leaderboardLoaded) return; // Don't reload if already loaded

    try {
      print('📊 Loading leaderboard (one time)...');
      final leaderboard = await RankingService.getLeaderboard(limit: 3);

      if (mounted) {
        setState(() {
          _cachedLeaderboard = leaderboard;
          _leaderboardLoaded = true;
        });
        print('✅ Leaderboard cached with ${leaderboard.length} players');
      }
    } catch (e) {
      print('❌ Error loading leaderboard: $e');
      // Set empty list so we don't keep trying
      if (mounted) {
        setState(() {
          _cachedLeaderboard = [];
          _leaderboardLoaded = true;
        });
      }
    }
  }

}