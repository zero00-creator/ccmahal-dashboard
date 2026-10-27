import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'auth/auth_service.dart';
import 'auth/firebase_auth_service.dart';
import 'firebase_options.dart';
import 'live_page.dart';
import 'auth/login_screen.dart';
import 'sprites.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: firebaseOptions);
  // Firebase keeps a phone sign-in until sign-out. "Remember me" off means one
  // session only: sign out at the next start. (On the web the login page picks
  // the session-only persistence instead.)
  if (!kIsWeb) {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(rememberKey) == false) {
      await FirebaseAuth.instance.signOut();
    }
  }
  runApp(
    DashboardApp(auth: FirebaseAuthService(), sprites: await SpriteSet.load()),
  );
}

class DashboardApp extends StatelessWidget {
  const DashboardApp({super.key, required this.auth, required this.sprites});

  final AuthService auth;
  final SpriteSet sprites;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CCmahal dashboard',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        colorSchemeSeed: const Color(0xFFD97757),
        useMaterial3: true,
      ),
      home: StreamBuilder<AuthUser?>(
        stream: auth.user,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }
          final user = snap.data;
          return user == null
              ? LoginScreen(auth: auth, sprites: sprites)
              : LivePage(key: ValueKey(user.uid), auth: auth, user: user);
        },
      ),
    );
  }
}
