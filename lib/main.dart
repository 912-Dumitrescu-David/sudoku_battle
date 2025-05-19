import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sudoku_battle/providers/sudoku_provider.dart';
import 'package:sudoku_battle/screens/home_screen.dart';

void main() {
  runApp(const SudokuBattleApp());
}

class SudokuBattleApp extends StatelessWidget {
  const SudokuBattleApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => SudokuProvider(),
      child: MaterialApp(
        title: 'Sudoku Battle',
        theme: ThemeData(
          primarySwatch: Colors.blue,
        ),
        home: const HomeScreen(),
      ),
    );
  }
}
