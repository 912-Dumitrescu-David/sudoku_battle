import 'package:flutter/material.dart';

final ThemeData lightTheme = ThemeData(
  brightness: Brightness.light,
  primaryColor: Colors.blue,
  scaffoldBackgroundColor: Colors.white,
  colorScheme: ColorScheme.light(
    primary: Colors.blue,
    secondary: Colors.orange,
  ),
  appBarTheme: AppBarTheme(
    backgroundColor: Colors.blue,
    foregroundColor: Colors.white,
  ),
  // Add more custom colors as needed
);

final ThemeData darkTheme = ThemeData(
  brightness: Brightness.dark,
  primaryColor: Colors.blueGrey,
  scaffoldBackgroundColor: Colors.black,
  colorScheme: ColorScheme.dark(
    primary: Colors.blueGrey,
    secondary: Colors.deepOrange,

  ),
  appBarTheme: AppBarTheme(
    backgroundColor: Colors.black,
    foregroundColor: Colors.white,
  ),
  //win-color fail-color
);
