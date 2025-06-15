import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/theme_provider.dart';
import 'sudoku_screen.dart';

class DifficultyScreen extends StatefulWidget {
  const DifficultyScreen({Key? key}) : super(key: key);

  @override
  State<DifficultyScreen> createState() => _DifficultyScreenState();
}

class _DifficultyScreenState extends State<DifficultyScreen> {
  bool _allowHints = true;
  bool _allowMistakes = true;
  int _maxMistakes = 3;

  int _emptyCellsCount(String difficulty) {
    switch (difficulty) {
      case 'Easy':
        return 40;
      case 'Medium':
        return 50;
      case 'Hard':
        return 54;
      case 'Expert':
        return 60;
      default:
        return 50;
    }
  }

  void _startGame(BuildContext context, String difficulty) {
    int emptyCells = _emptyCellsCount(difficulty);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SudokuScreen(
          difficulty: difficulty,
          emptyCells: emptyCells,
          allowHints: _allowHints,
          allowMistakes: _allowMistakes,
          maxMistakes: _maxMistakes,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Difficulty'),
        actions: [
          IconButton(
            icon: Icon(Icons.brightness_6),
            tooltip: 'Toggle theme',
            onPressed: () {
              Provider.of<ThemeProvider>(context, listen: false).toggleTheme();
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Game Options Card
            Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Game Options',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    SizedBox(height: 16),

                    // Hints option
                    SwitchListTile(
                      title: Text('Enable Hints'),
                      subtitle: Text(_allowHints
                          ? 'Get help when you\'re stuck (3 hints available)'
                          : 'Challenge yourself without hints'),
                      value: _allowHints,
                      onChanged: (value) {
                        setState(() {
                          _allowHints = value;
                        });
                      },
                      contentPadding: EdgeInsets.zero,
                    ),

                    // Mistakes option
                    SwitchListTile(
                      title: Text('Allow Mistakes'),
                      subtitle: Text(_allowMistakes
                          ? 'Game ends after $_maxMistakes mistakes'
                          : 'Game ends on first mistake'),
                      value: _allowMistakes,
                      onChanged: (value) {
                        setState(() {
                          _allowMistakes = value;
                          if (!value) {
                            _maxMistakes = 1;
                          } else {
                            _maxMistakes = 3;
                          }
                        });
                      },
                      contentPadding: EdgeInsets.zero,
                    ),

                    if (_allowMistakes) ...[
                      SizedBox(height: 8),
                      Text('Maximum Mistakes: $_maxMistakes'),
                      Slider(
                        value: _maxMistakes.toDouble(),
                        min: 1,
                        max: 10,
                        divisions: 9,
                        label: _maxMistakes.toString(),
                        onChanged: (value) {
                          setState(() {
                            _maxMistakes = value.round();
                          });
                        },
                      ),
                    ],
                  ],
                ),
              ),
            ),

            SizedBox(height: 24),

            // Difficulty Selection
            Text(
              'Select Difficulty',
              style: Theme.of(context).textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),

            SizedBox(height: 16),

            // Difficulty buttons
            _buildDifficultyButton(context, 'Easy', Colors.green,
                '40 empty cells - Perfect for beginners'),
            SizedBox(height: 12),
            _buildDifficultyButton(context, 'Medium', Colors.orange,
                '50 empty cells - Good balance of challenge'),
            SizedBox(height: 12),
            _buildDifficultyButton(context, 'Hard', Colors.red,
                '54 empty cells - For experienced players'),
            SizedBox(height: 12),
            _buildDifficultyButton(context, 'Expert', Colors.purple,
                '60 empty cells - Ultimate challenge'),
          ],
        ),
      ),
    );
  }

  Widget _buildDifficultyButton(BuildContext context, String difficulty, Color color, String description) {
    return Card(
      elevation: 2,
      child: InkWell(
        onTap: () => _startGame(context, difficulty),
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  _getDifficultyIcon(difficulty),
                  color: color,
                  size: 24,
                ),
              ),
              SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      difficulty,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: color,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      description,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios, color: Colors.grey[400], size: 16),
            ],
          ),
        ),
      ),
    );
  }

  IconData _getDifficultyIcon(String difficulty) {
    switch (difficulty) {
      case 'Easy':
        return Icons.sentiment_very_satisfied;
      case 'Medium':
        return Icons.sentiment_satisfied;
      case 'Hard':
        return Icons.sentiment_neutral;
      case 'Expert':
        return Icons.sentiment_very_dissatisfied;
      default:
        return Icons.extension;
    }
  }
}