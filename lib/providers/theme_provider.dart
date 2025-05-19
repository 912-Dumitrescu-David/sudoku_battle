import 'package:flutter/material.dart';
import '../color_profiles.dart';

class ThemeProvider with ChangeNotifier {
  ThemeData _themeData = lightTheme;

  ThemeData get themeData => _themeData;

  void toggleTheme() {
    _themeData = _themeData == lightTheme ? darkTheme : lightTheme;
    notifyListeners();
  }

  void setTheme(ThemeData theme) {
    _themeData = theme;
    notifyListeners();
  }
}
