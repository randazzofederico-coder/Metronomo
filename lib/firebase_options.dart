import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    // Mismas claves para todas las plataformas (proyecto compartido con federicorandazzo.com.ar)
    return const FirebaseOptions(
      apiKey: 'AIzaSyA4DWLh-GFbicov8QvOvAM4bbcbHDO67nI',
      authDomain: 'federicorandazzo-a5c9b.firebaseapp.com',
      projectId: 'federicorandazzo-a5c9b',
      storageBucket: 'federicorandazzo-a5c9b.firebasestorage.app',
      messagingSenderId: '858245145787',
      appId: '1:858245145787:web:9f041f6423348bca05b59e',
    );
  }
}
