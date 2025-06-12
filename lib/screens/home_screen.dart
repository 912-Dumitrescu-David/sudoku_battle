import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sudoku_battle/screens/lobby_screen.dart';
import 'package:sudoku_battle/screens/profile_screen.dart';
import 'package:sudoku_battle/screens/ranked_queue_screen.dart';
import '../providers/theme_provider.dart';
import 'difficulty_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  int? _currentRating;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this); // 🔥 Add observer to detect app resume
    _loadPlayerRating();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this); // 🔥 Remove observer
    super.dispose();
  }

  // 🔥 Detect when app resumes (when user returns from result screen)
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      print('🔄 App resumed - refreshing rating');
      _loadPlayerRating();
    }
  }

  Future<void> _loadPlayerRating() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        print('🔄 Loading player rating for: ${user.uid}');

        // Force refresh from server to get latest rating
        final userDoc = await FirebaseFirestore.instanceFor(
          app: Firebase.app(),
          databaseId: 'lobbies',
        ).collection('users').doc(user.uid).get(const GetOptions(source: Source.server));

        if (userDoc.exists && mounted) {
          final newRating = userDoc.data()?['rating'] ?? 1000;
          print('✅ Loaded rating: $newRating (previous: $_currentRating)');

          setState(() {
            _currentRating = newRating;
          });
        }
      }
    } catch (e) {
      print('Error loading rating: $e');
      // Fallback to cache if server fails
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
        print('Cache error: $cacheError');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final displayName = user?.displayName?.isNotEmpty == true
        ? user!.displayName
        : user?.email ?? "player";
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sudoku Gladiators'),
        actions: [
          IconButton(
            icon: CircleAvatar(
              radius: 16,
              backgroundImage:
              (user?.photoURL != null && user!.photoURL!.isNotEmpty)
                  ? NetworkImage(user!.photoURL!)
                  : null,
              child: (user?.photoURL == null || user!.photoURL!.isEmpty)
                  ? const Icon(Icons.person)
                  : null,
            ),
            onPressed: () async {
              final shouldRefresh = await Navigator.of(context).push(
                MaterialPageRoute(builder: (context) => const ProfileScreen()),
              );
              if (shouldRefresh == true) {
                setState(() {}); // Refresh HomeScreen to show updated info
                _loadPlayerRating(); // Reload rating
              }
            },
          ),
          IconButton(
            icon: Icon(Icons.brightness_6),
            tooltip: 'Toggle theme',
            onPressed: () {
              Provider.of<ThemeProvider>(context, listen: false).toggleTheme();
            },
          ),
        ],
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Welcome message
              Text(
                'Hello, $displayName!',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),

              // Rating display with refresh button
              if (_currentRating != null) ...[
                SizedBox(height: 8),
                GestureDetector(
                  onTap: () {
                    // 🔥 Allow manual refresh by tapping rating
                    print('🔄 Manual rating refresh triggered');
                    _loadPlayerRating();
                  },
                  child: Container(
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
                          'Rating: $_currentRating',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.purple,
                          ),
                        ),
                        SizedBox(width: 4),
                        Icon(Icons.refresh, color: Colors.purple, size: 16), // 🔥 Hint that it's tappable
                      ],
                    ),
                  ),
                ),
                Text(
                  'Tap to refresh',
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.grey[600],
                  ),
                ),
              ],

              const SizedBox(height: 32),

              // Game mode cards
              _buildGameModeCard(
                context,
                title: 'Classic Mode',
                description: 'Practice with customizable settings',
                icon: Icons.grid_3x3,
                color: Colors.blue,
                onTap: () => _goToClassicMode(context),
              ),

              const SizedBox(height: 16),

              _buildGameModeCard(
                context,
                title: 'Ranked Queue',
                description: 'Compete for rating against similar players',
                icon: Icons.emoji_events,
                color: Colors.purple,
                onTap: () => _goToRankedQueue(context),
              ),

              const SizedBox(height: 16),

              _buildGameModeCard(
                context,
                title: 'Casual Multiplayer',
                description: 'Create or join lobbies with friends',
                icon: Icons.people,
                color: Colors.green,
                onTap: () => _goToMultiplayer(context),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGameModeCard(
      BuildContext context, {
        required String title,
        required String description,
        required IconData icon,
        required Color color,
        required VoidCallback onTap,
      }) {
    return Card(
      elevation: 4,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Row(
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  color: color,
                  size: 32,
                ),
              ),
              SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      description,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios,
                color: Colors.grey[400],
                size: 16,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _goToClassicMode(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const DifficultyScreen()),
    );
  }

  void _goToRankedQueue(BuildContext context) async {
    // 🔥 Refresh rating when going to ranked queue
    await _loadPlayerRating();
    if (mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const RankedQueueScreen()),
      ).then((_) {
        // 🔥 Refresh rating when returning from ranked queue
        _loadPlayerRating();
      });
    }
  }

  void _goToMultiplayer(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => LobbyScreen()),
    );
  }
}