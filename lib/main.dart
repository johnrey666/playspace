import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'app/router.dart';
import 'app/theme.dart';
import 'app/theme_controller.dart';
import 'firebase_options.dart';
import 'shared/providers/auth_provider.dart';
import 'shared/providers/chat_provider.dart';
import 'shared/providers/friends_provider.dart';
import 'shared/providers/story_provider.dart';
import 'shared/providers/user_provider.dart';
import 'shared/services/auth_service.dart';
import 'shared/services/fcm_service.dart';
import 'shared/services/firestore_service.dart';
import 'shared/services/local_notification_service.dart';
import 'shared/services/matchmaking_service.dart';
import 'shared/services/presence_service.dart';
import 'shared/services/random_chat_service.dart';
import 'shared/services/realtime_db_service.dart';
import 'shared/services/storage_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const PlaySpaceApp());
}

class PlaySpaceApp extends StatelessWidget {
  const PlaySpaceApp({super.key});

  @override
  Widget build(BuildContext context) {
    final authService = AuthService();
    final firestoreService = FirestoreService();
    final storageService = StorageService();
    final realtimeDbService = RealtimeDbService();
    final matchmakingService = MatchmakingService();
    final fcmService = FcmService();
    final presenceService = PresenceService();
    final randomChatService = RandomChatService();
    final localNotificationService = LocalNotificationService();

    return MultiProvider(
      providers: [
        Provider.value(value: authService),
        Provider.value(value: firestoreService),
        Provider.value(value: storageService),
        Provider.value(value: realtimeDbService),
        Provider.value(value: matchmakingService),
        Provider.value(value: fcmService),
        Provider.value(value: presenceService),
        Provider.value(value: randomChatService),
        Provider.value(value: localNotificationService),
        ChangeNotifierProvider(create: (_) => ThemeController()),
        ChangeNotifierProvider(
          create: (_) =>
              AuthProvider(authService, fcmService, presenceService),
        ),
        ChangeNotifierProxyProvider<AuthProvider, UserProvider>(
          create: (_) => UserProvider(firestoreService),
          update: (_, auth, prev) => (prev ?? UserProvider(firestoreService))
            ..bind(auth.uid),
        ),
        ChangeNotifierProxyProvider<AuthProvider, FriendsProvider>(
          create: (_) => FriendsProvider(firestoreService),
          update: (_, auth, prev) =>
              (prev ?? FriendsProvider(firestoreService))..bind(auth.uid),
        ),
        ChangeNotifierProxyProvider<AuthProvider, ChatProvider>(
          create: (_) => ChatProvider(firestoreService),
          update: (_, auth, prev) =>
              (prev ?? ChatProvider(firestoreService))..bind(auth.uid),
        ),
        ChangeNotifierProxyProvider<UserProvider, StoryProvider>(
          create: (_) => StoryProvider(firestoreService),
          update: (_, user, prev) => (prev ?? StoryProvider(firestoreService))
            ..bind(user.user?.uid, user.friendIds),
        ),
      ],
      child: Consumer<ThemeController>(
        builder: (context, theme, _) => MaterialApp(
          title: 'PlaySpace',
          debugShowCheckedModeBanner: false,
          scaffoldMessengerKey: fcmService.messengerKey,
          theme: AppTheme.light(seed: theme.seed),
          darkTheme: AppTheme.dark(seed: theme.seed),
          themeMode: theme.mode,
          home: const RootGate(),
        ),
      ),
    );
  }
}
