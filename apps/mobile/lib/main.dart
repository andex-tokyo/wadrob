import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'core/api.dart';
import 'core/cache.dart';
import 'core/session.dart';
import 'features/wardrobe/wardrobe_screen.dart';

const appBackground = Color(0xfffafaf8);

final sessionProvider = Provider<Session>(
  (ref) => throw UnimplementedError('Session is injected at startup'),
);
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final session = Session(
    Api(),
    await WardrobeCache.open(),
    await SharedPreferences.getInstance(),
  );
  runApp(
    ProviderScope(
      overrides: [sessionProvider.overrideWithValue(session)],
      child: const WadrobApp(),
    ),
  );
  await session.restore();
}

class WadrobApp extends ConsumerWidget {
  const WadrobApp({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionProvider);
    return MaterialApp(
      title: 'WDRB',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: appBackground,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xff252522),
          primary: const Color(0xff252522),
          surface: appBackground,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: appBackground,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
        ),
        dividerColor: const Color(0xffeeece8),
        inputDecorationTheme: const InputDecorationTheme(
          border: UnderlineInputBorder(),
          enabledBorder: UnderlineInputBorder(
            borderSide: BorderSide(color: Color(0xffdedbd5)),
          ),
          floatingLabelStyle: TextStyle(color: Color(0xff5d5c57)),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            minimumSize: const Size(48, 50),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(3),
            ),
          ),
        ),
      ),
      home: AnimatedBuilder(
        animation: session,
        builder: (context, _) => session.initializing
            ? const Scaffold(body: Center(child: Text('W A D R O B')))
            : session.user != null
            ? WardrobeScreen(
                key: ValueKey(session.user!['id']),
                session: session,
              )
            : LoginScreen(session: session),
      ),
    );
  }
}

class LoginScreen extends StatelessWidget {
  final Session session;
  const LoginScreen({super.key, required this.session});
  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Spacer(flex: 2),
            const Text(
              'WDRB',
              style: TextStyle(
                fontSize: 42,
                fontWeight: FontWeight.w500,
                letterSpacing: 10,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'ワドロブ',
              style: TextStyle(
                fontSize: 13,
                letterSpacing: 4,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 48),
            const Text(
              '好きな服を、\nいつも手元に。',
              style: TextStyle(
                fontSize: 30,
                height: 1.6,
                fontWeight: FontWeight.w300,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              '自分だけの、デジタルクローゼット。',
              style: TextStyle(color: Colors.grey),
            ),
            const Spacer(flex: 3),
            if (session.error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Text(
                  session.error!,
                  style: const TextStyle(color: Colors.brown),
                ),
              ),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: session.busy ? null : () => session.login(),
                child: Text(session.busy ? 'ログイン中…' : 'Google でログイン'),
              ),
            ),
            const SizedBox(height: 20),
            const Center(
              child: Text(
                'あなたの服は、あなただけに。',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    ),
  );
}
