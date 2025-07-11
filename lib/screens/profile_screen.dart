import 'dart:io';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image/image.dart' as img;
import 'package:provider/provider.dart';
import 'package:profanity_filter/profanity_filter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/foundation.dart' show kIsWeb; // Import kIsWeb
import '../providers/theme_provider.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _usernameController = TextEditingController();
  bool _isLoading = false;
  bool _profileChanged = false;

  @override
  void initState() {
    super.initState();
    final user = FirebaseAuth.instance.currentUser;
    _usernameController.text = user?.displayName ?? '';
  }

  Future<void> _launchAPKUrl() async {
    // Paste the Download URL from Firebase Storage here
    final Uri apkUrl = Uri.parse('https://firebasestorage.googleapis.com/v0/b/sudoku-battle-cluj.firebasestorage.app/o/app-release.apk?alt=media&token=e0328e69-4623-4b98-a64a-9de93701eb8b');
    if (!await launchUrl(apkUrl, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not launch download link.')),
        );
      }
    }
  }

  Future<bool> isUsernameAvailable(String username) async {
    final result = await FirebaseFirestore.instance
        .collection('users')
        .where('username', isEqualTo: username)
        .get();

    return result.docs.isEmpty;
  }

  Future<void> _updateUsername() async {
    setState(() => _isLoading = true);
    try {
      final username = _usernameController.text.trim();
      if (username.isEmpty) throw Exception("Username cannot be empty");
      if (username.length < 3 || username.length > 15) {
        throw Exception("Username must be between 3 and 15 characters.");
      }

      final filter = ProfanityFilter();
      if (filter.hasProfanity(username)) {
        throw Exception("This username is not allowed.");
      }

      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      if (username == user.displayName) {
        setState(() => _isLoading = false);
        return;
      }

      final available = await isUsernameAvailable(username);
      if (!available) {
        throw Exception('Username already taken!');
      }

      await user.updateDisplayName(username);

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .update({'username': username});

      await user.reload();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Username updated successfully!')),
      );

      setState(() {
        _profileChanged = true;
      });

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst("Exception: ", ""))),
      );
    }

    setState(() => _isLoading = false);
  }

  Future<void> _pickAndUploadPhoto() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);

    if (picked != null) {
      setState(() => _isLoading = true);
      final user = FirebaseAuth.instance.currentUser;

      final fileBytes = await picked.readAsBytes();

      img.Image? originalImage = img.decodeImage(fileBytes);
      if (originalImage == null) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not process image.')),
        );
        return;
      }

      final img.Image resized = img.copyResize(
        originalImage,
        width: 256,
        height: 256,
        interpolation: img.Interpolation.cubic,
      );

      final Uint8List jpg = Uint8List.fromList(img.encodeJpg(resized, quality: 85));

      final storageRef = FirebaseStorage.instance
          .ref()
          .child('user_photos')
          .child('${user?.uid}.jpg');
      await storageRef.putData(jpg, SettableMetadata(contentType: 'image/jpeg'));
      final photoURL = await storageRef.getDownloadURL();

      await user?.updatePhotoURL(photoURL);
      await user?.reload();

      setState(() {
        _profileChanged = true;
      });
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.pop(context, _profileChanged);
          },
        ),
        title: const Text('Profile'),
        actions: [
          IconButton(
            icon: const Icon(Icons.brightness_6),
            tooltip: 'Toggle theme',
            onPressed: () {
              Provider.of<ThemeProvider>(context, listen: false).toggleTheme();
            },
          ),
        ],
      ),
      body: Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              GestureDetector(
                onTap: _pickAndUploadPhoto,
                child: CircleAvatar(
                  radius: 50,
                  backgroundImage: user?.photoURL != null
                      ? NetworkImage(user!.photoURL!)
                      : null,
                  child: user?.photoURL == null
                      ? const Icon(Icons.account_circle, size: 80)
                      : null,
                ),
              ),
              const SizedBox(height: 16),
              Text(user?.email ?? 'No email', style: const TextStyle(fontSize: 16)),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: TextField(
                  controller: _usernameController,
                  textAlign: TextAlign.center,
                  decoration: const InputDecoration(labelText: 'Username'),
                ),
              ),
              const SizedBox(height: 8),
              _isLoading
                  ? const CircularProgressIndicator()
                  : ElevatedButton(
                onPressed: _updateUsername,
                child: const Text('Update Username'),
              ),
              const SizedBox(height: 24),
              const Divider(indent: 32, endIndent: 32),
              const SizedBox(height: 16),
              // --- UPDATED: Conditional Download Button ---
              if (kIsWeb)
                OutlinedButton.icon(
                  icon: const Icon(Icons.android),
                  label: const Text('Download for Android'),
                  onPressed: _launchAPKUrl,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.green,
                    side: const BorderSide(color: Colors.green),
                  ),
                ),
              // --- END UPDATE ---
              const SizedBox(height: 16),
              ElevatedButton.icon(
                icon: const Icon(Icons.logout),
                label: const Text('Sign Out'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                ),
                onPressed: () async {
                  await FirebaseAuth.instance.signOut();
                  if (mounted) {
                    Navigator.of(context).popUntil((route) => route.isFirst);
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
