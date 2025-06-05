import 'dart:io';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image/image.dart' as img;
import 'package:provider/provider.dart';

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

      final user = FirebaseAuth.instance.currentUser;

      // Check if username is unique
      final available = await isUsernameAvailable(username);
      if (!available) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Username already taken!')),
        );
        setState(() => _isLoading = false);
        return;
      }

      // Update Auth displayName
      await user?.updateDisplayName(username);
      await user?.reload();

      // Save in Firestore
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user?.uid)
          .set({
        'username': username,
        'email': user?.email,
        'photoURL': user?.photoURL,
      }, SetOptions(merge: true));

      setState(() {});
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update username')),
      );
    }
    setState(() {
      _profileChanged = true; // <--- Profile changed!
    });
    setState(() => _isLoading = false);
  }

  Future<void> _pickAndUploadPhoto() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);

    if (picked != null) {
      setState(() => _isLoading = true);
      final user = FirebaseAuth.instance.currentUser;

      // Read file as bytes
      final fileBytes = await picked.readAsBytes();

      // Decode image
      img.Image? originalImage = img.decodeImage(fileBytes);
      if (originalImage == null) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not process image.')),
        );
        return;
      }

      // Resize if too large (e.g., max 256x256)
      final img.Image resized = img.copyResize(
        originalImage,
        width: 256,
        height: 256,
        interpolation: img.Interpolation.cubic,
      );

      // Compress as JPEG
      final Uint8List jpg = Uint8List.fromList(img.encodeJpg(resized, quality: 85));

      // Upload resized/compressed image to Storage
      final storageRef = FirebaseStorage.instance
          .ref()
          .child('user_photos')
          .child('${user?.uid}.jpg');
      await storageRef.putData(jpg, SettableMetadata(contentType: 'image/jpeg'));
      final photoURL = await storageRef.getDownloadURL();

      // Update Auth user profile with new photoURL
      await user?.updatePhotoURL(photoURL);
      await user?.reload();

      setState(() {
        _profileChanged = true; // <--- Profile changed!
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
          icon: Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.pop(context, _profileChanged);
          },
        ),
        title: const Text('Profile'),
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
      body: Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Profile Photo
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
              // Email
              Text(user?.email ?? 'No email', style: const TextStyle(fontSize: 16)),
              const SizedBox(height: 8),
              // Username Edit
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: TextField(
                  controller: _usernameController,
                  textAlign: TextAlign.center,
                  decoration: const InputDecoration(labelText: 'Username'),
                ),
              ),
              const SizedBox(height: 8),
              // Update Username Button
              _isLoading
                  ? const CircularProgressIndicator()
                  : ElevatedButton(
                onPressed: _updateUsername,
                child: const Text('Update Username'),
              ),
              const SizedBox(height: 16),
              // Sign Out Button
              ElevatedButton.icon(
                icon: const Icon(Icons.logout),
                label: const Text('Sign Out'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                ),
                onPressed: () async {
                  await FirebaseAuth.instance.signOut();
                  Navigator.of(context).popUntil((route) => route.isFirst);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
