import 'package:flutter/material.dart';
import '../home/home_screen.dart';

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    // Always show HomeScreen - users can browse without login
    // Login will be prompted only when accessing premium features
    return const HomeScreen();
  }
}

