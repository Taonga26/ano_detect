import 'package:ano_detect/pages/home.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../pages/login.dart';

class Auth extends StatelessWidget {
  Auth({super.key});

  final supabase = Supabase.instance.client;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: supabase.auth.onAuthStateChange,
      builder: (context, snapshot) {
        final session = supabase.auth.currentSession;
        if (session != null) {
          // User logged in
          return HomePage();
        } else {
          return const LoginPage();
        }
      },
    );
  }
}
