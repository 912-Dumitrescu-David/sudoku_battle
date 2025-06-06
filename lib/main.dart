import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sudoku_battle/providers/lobby_provider.dart';
import 'package:sudoku_battle/providers/sudoku_provider.dart';
import 'package:sudoku_battle/screens/auth_screen.dart';
import 'package:sudoku_battle/screens/home_screen.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:sudoku_battle/services/user_initializayion_service.dart';
import 'firebase_options.dart';
import 'package:sudoku_battle/providers/theme_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  // In your main.dart, after Firebase.initializeApp()
  FirebaseAuth.instance.authStateChanges().listen((User? user) {
    if (user != null) {
      UserInitializationService.initializeUserIfNeeded();
    }
  });

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => SudokuProvider()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => LobbyProvider()),
      ],
      child: SudokuBattleApp(),
    ),
  );
}


class SudokuBattleApp extends StatelessWidget {
  const SudokuBattleApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    return MaterialApp(
      title: 'Sudoku Battle',
      theme: themeProvider.themeData,
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasData) {
            // User is signed in
            return HomeScreen(); // Replace with your actual main screen
          }
          // Not signed in
          return AuthScreen();
        },
      ),
    );
  }
}
