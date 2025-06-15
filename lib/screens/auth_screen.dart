import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';

import '../providers/theme_provider.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool isLogin = true;
  String error = '';

  Future<void> signInOrUp() async {
    try {
      if (isLogin) {
        await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );
      } else {
        await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );
      }
    } on FirebaseAuthException catch (e) {
      setState(() {
        error = e.message ?? "Unknown error";
      });
    }
  }

  Widget _buildWelcomeTitle() {
    final theme = Theme.of(context);
    final isLightTheme = theme.brightness == Brightness.light;

    return Column(
      children: [
        Text(
          'Welcome to',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w300,
            color: theme.textTheme.bodySmall?.color,
          ),
        ),
        SizedBox(height: 8),
        ShaderMask(
          blendMode: BlendMode.srcIn,
          shaderCallback: (bounds) => LinearGradient(
            colors: [
              Colors.blue,
              Colors.purple,
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ).createShader(
            Rect.fromLTWH(0, 0, bounds.width, bounds.height),
          ),
          child: Text(
            'Sudoku Gladiators',
            style: TextStyle(
              fontSize: 36,
              fontWeight: FontWeight.bold,
              shadows: [
                Shadow(
                  blurRadius: isLightTheme ? 2.0 : 4.0,
                  color: isLightTheme
                      ? Colors.black.withOpacity(0.2)
                      : Colors.black.withOpacity(0.5),
                  offset: Offset(2.0, 2.0),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(isLogin ? 'Login' : 'Sign Up'),
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
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildWelcomeTitle(),
              const SizedBox(height: 48),

              TextField(
                controller: _emailController,
                decoration: InputDecoration(labelText: 'Email'),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _passwordController,
                obscureText: true,
                decoration: InputDecoration(labelText: 'Password'),
              ),
              const SizedBox(height: 16),
              if (error.isNotEmpty) ...[
                Text(error, style: TextStyle(color: Colors.red)),
                const SizedBox(height: 16),
              ],
              ElevatedButton(
                onPressed: signInOrUp,
                child: Text(isLogin ? 'Login' : 'Sign Up'),
              ),
              TextButton(
                onPressed: () => setState(() => isLogin = !isLogin),
                child: Text(isLogin
                    ? "Don't have an account? Sign Up"
                    : "Already have an account? Login"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}