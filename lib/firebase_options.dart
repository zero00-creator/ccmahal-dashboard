import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

/// The database the plugin writes to and this app reads from.
const databaseUrl =
    'https://my-mod-7160b-default-rtdb.asia-southeast1.firebasedatabase.app';

/// Public client configuration of the Firebase project (not secrets: the
/// database rules and the login protect the data).
FirebaseOptions get firebaseOptions => kIsWeb ? _web : _android;

const _web = FirebaseOptions(
  apiKey: 'AIzaSyA8IZce4NS2ecgOFhaWM3FPDPmjc1gLMI8',
  appId: '1:645730616753:web:24162f83cc09ed7ae62990',
  messagingSenderId: '645730616753',
  projectId: 'my-mod-7160b',
  authDomain: 'my-mod-7160b.firebaseapp.com',
  storageBucket: 'my-mod-7160b.firebasestorage.app',
  databaseURL: databaseUrl,
);

const _android = FirebaseOptions(
  apiKey: 'AIzaSyCKIIJehQtxPs_fcAHBky8QPinDBXRx6QI',
  appId: '1:645730616753:android:e5cb0ac9059dc63be62990',
  messagingSenderId: '645730616753',
  projectId: 'my-mod-7160b',
  storageBucket: 'my-mod-7160b.firebasestorage.app',
  databaseURL: databaseUrl,
);

/// The Web client ID of the Google sign-in (public). Android needs it; the
/// web does not. Empty until Yohan pastes it from the Firebase console.
const googleWebClientId = '';
