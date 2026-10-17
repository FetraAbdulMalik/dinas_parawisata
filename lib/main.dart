import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:provider/provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';

import 'providers/app_state.dart';
import 'services/supabase_service.dart';
import 'screens/main_shell.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (kIsWeb) {
    databaseFactory = databaseFactoryFfiWeb;
  } else {
    await JustAudioBackground.init(
      androidNotificationChannelId: 'com.example.guriang_garut.audio',
      androidNotificationChannelName: 'Audio destinasi',
      androidNotificationOngoing: true,
    );
  }
  await SupabaseService.instance.initialize();
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => AppState()..init(),
        ),
        Provider<AudioPlayer>(
          create: (_) => AudioPlayer(),
          dispose: (_, player) => player.dispose(),
        ),
      ],
      child: const GuriangApp(),
    ),
  );
}

class GuriangApp extends StatelessWidget {
  const GuriangApp({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    return MaterialApp(
      title: 'Guriang Garut',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      home: !state.ready
          ? const Scaffold(
              body: Center(
                  child: CircularProgressIndicator(color: AppColors.green)))
          : const MainShell(),
    );
  }
}
