import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/lobby_provider.dart';

class JoinPrivateLobbyDialog extends StatefulWidget {
  final Function(String lobbyId) onJoined;

  const JoinPrivateLobbyDialog({
    Key? key,
    required this.onJoined,
  }) : super(key: key);

  @override
  State<JoinPrivateLobbyDialog> createState() => _JoinPrivateLobbyDialogState();
}

class _JoinPrivateLobbyDialogState extends State<JoinPrivateLobbyDialog> {
  final _formKey = GlobalKey<FormState>();
  final _accessCodeController = TextEditingController();
  bool _isJoining = false;

  @override
  void dispose() {
    _accessCodeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Join Private Lobby'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Enter the 6-character access code to join a private lobby.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            SizedBox(height: 16),
            TextFormField(
              controller: _accessCodeController,
              decoration: InputDecoration(
                labelText: 'Access Code',
                hintText: 'ABC123',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.lock),
              ),
              textCapitalization: TextCapitalization.characters,
              maxLength: 6,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[A-Z0-9]')),
                UpperCaseTextFormatter(),
              ],
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter an access code';
                }
                if (value.length != 6) {
                  return 'Access code must be 6 characters';
                }
                return null;
              },
              onFieldSubmitted: (value) {
                if (_formKey.currentState!.validate()) {
                  _joinLobby();
                }
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isJoining ? null : () => Navigator.pop(context),
          child: Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isJoining ? null : _joinLobby,
          child: _isJoining
              ? SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
              : Text('Join'),
        ),
      ],
    );
  }

  Future<void> _joinLobby() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isJoining = true;
    });

    final lobbyProvider = context.read<LobbyProvider>();
    final success = await lobbyProvider.joinPrivateLobby(
      _accessCodeController.text.toUpperCase(),
    );

    setState(() {
      _isJoining = false;
    });

    if (success && mounted) {
      // Get the lobby ID from the current lobby
      final currentLobby = lobbyProvider.currentLobby;
      if (currentLobby != null) {
        print('✅ Successfully joined lobby: ${currentLobby.id}');
        widget.onJoined(currentLobby.id);
      } else {
        print('❌ Current lobby is null after joining');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to get lobby details'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } else if (mounted) {
      print('❌ Failed to join lobby: ${lobbyProvider.error}');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(lobbyProvider.error ?? 'Failed to join lobby'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}

class UpperCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue,
      TextEditingValue newValue,
      ) {
    return TextEditingValue(
      text: newValue.text.toUpperCase(),
      selection: newValue.selection,
    );
  }
}