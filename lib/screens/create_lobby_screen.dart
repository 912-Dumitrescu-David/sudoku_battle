import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../providers/lobby_controller.dart';
import '../models/lobby_model.dart';
import '../providers/sudoku_provider.dart'; // Adjust path if needed
import 'lobby_waiting_screen.dart'; // For navigation

class CreateLobbyScreen extends StatefulWidget {
  final bool isPublic;
  const CreateLobbyScreen({Key? key, required this.isPublic}) : super(key: key);

  @override
  State<CreateLobbyScreen> createState() => _CreateLobbyScreenState();
}

class _CreateLobbyScreenState extends State<CreateLobbyScreen> {
  bool _isLoading = false;
  String? _lobbyCode;
  String? _errorText;

  Future<void> _createLobby() async {
    setState(() {
      _isLoading = true;
      _errorText = null;
    });

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() {
        _errorText = "Not logged in.";
        _isLoading = false;
      });
      return;
    }

    final lobbyController = LobbyController();
    final code = await lobbyController.generateLobbyCode();

    // Generate the sudoku puzzle with your provider
    final sudokuProvider = Provider.of<SudokuProvider>(context, listen: false);
    sudokuProvider.generatePuzzle(emptyCells: 40); // Optionally pass difficulty or config
    final board = sudokuProvider.board;
    final puzzleString = board.map((row) => row.join(',')).join(';'); // Simple CSV

    final lobby = Lobby(
      id: code,
      type: widget.isPublic ? 'public' : 'private',
      hostUid: user.uid,
      hostUsername: user.displayName ?? user.email ?? 'Player',
      status: 'waiting',
      puzzle: puzzleString,
    );

    try {
      await lobbyController.createLobby(lobby);
      setState(() {
        _lobbyCode = code;
        _isLoading = false;
      });
      // Navigate to waiting screen
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => LobbyWaitingScreen(lobbyId: code),
        ),
      );
    } on FirebaseException catch (e) {
      setState(() {
        _errorText = "Failed to create lobby: ${e.message ?? e.code}";
        _isLoading = false;
      });
      print("Firebase Firestore Error: Code: ${e.code}, Message: ${e.message}");
    } catch (e) {
      setState(() {
        _errorText = "Failed to create lobby: $e";
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isPublic ? "Create Public Lobby" : "Create Private Lobby"),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: _isLoading
              ? const CircularProgressIndicator()
              : Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                widget.isPublic
                    ? "Anyone can join this lobby."
                    : "You will get a code to share with your friend.",
                style: const TextStyle(fontSize: 16),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: _createLobby,
                child: const Text("Create Lobby"),
              ),
              if (_errorText != null) ...[
                const SizedBox(height: 16),
                Text(_errorText!, style: const TextStyle(color: Colors.red)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
