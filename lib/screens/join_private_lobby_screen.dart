import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../providers/lobby_controller.dart';
import '../models/lobby_model.dart';
import 'lobby_waiting_screen.dart';

class JoinPrivateLobbyScreen extends StatefulWidget {
  const JoinPrivateLobbyScreen({Key? key}) : super(key: key);

  @override
  State<JoinPrivateLobbyScreen> createState() => _JoinPrivateLobbyScreenState();
}

class _JoinPrivateLobbyScreenState extends State<JoinPrivateLobbyScreen> {
  final TextEditingController _codeController = TextEditingController();
  bool _isLoading = false;
  String? _errorText;

  Future<void> _joinLobby() async {
    setState(() {
      _isLoading = true;
      _errorText = null;
    });
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() {
        _errorText = "Not logged in!";
        _isLoading = false;
      });
      return;
    }
    final code = _codeController.text.trim().toUpperCase();
    if (code.isEmpty) {
      setState(() {
        _errorText = "Enter a lobby code.";
        _isLoading = false;
      });
      return;
    }
    final lobbyController = LobbyController();
    final lobby = await lobbyController.joinLobby(
      code,
      user.uid,
      user.displayName ?? user.email ?? "Player",
    );
    if (lobby == null) {
      setState(() {
        _errorText = "Lobby not found, is full, or already started!";
        _isLoading = false;
      });
      return;
    }

    // Success: Navigate to lobby waiting/game screen
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => LobbyWaitingScreen(lobbyId: code),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Join Private Lobby")),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _codeController,
                textCapitalization: TextCapitalization.characters,
                textAlign: TextAlign.center,
                decoration: InputDecoration(
                  labelText: "Lobby Code",
                  border: OutlineInputBorder(),
                  errorText: _errorText,
                ),
                maxLength: 6,
              ),
              const SizedBox(height: 24),
              _isLoading
                  ? const CircularProgressIndicator()
                  : ElevatedButton(
                onPressed: _joinLobby,
                child: const Text("Join Lobby"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
