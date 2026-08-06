import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';

import 'core/theme/app_theme.dart';
import 'features/home/screens/home_screen.dart';
import 'features/pdf_viewer/screens/pdf_viewer_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  pdfrxFlutterInitialize();
  runApp(const ProviderScope(child: PdfTabsApp()));
}

class PdfTabsApp extends ConsumerStatefulWidget {
  const PdfTabsApp({super.key});

  @override
  ConsumerState<PdfTabsApp> createState() => _PdfTabsAppState();
}

class _PdfTabsAppState extends ConsumerState<PdfTabsApp> {
  final _navigatorKey = GlobalKey<NavigatorState>();
  StreamSubscription<List<SharedMediaFile>>? _mediaSubscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _handleInitialMedia());
    _mediaSubscription =
        ReceiveSharingIntent.instance.getMediaStream().listen(_openSharedFiles);
  }

  @override
  void dispose() {
    _mediaSubscription?.cancel();
    super.dispose();
  }

  Future<void> _handleInitialMedia() async {
    final files = await ReceiveSharingIntent.instance.getInitialMedia();
    if (files.isNotEmpty) _openSharedFiles(files);
  }

  void _openSharedFiles(List<SharedMediaFile> files) {
    final navigator = _navigatorKey.currentState;
    if (navigator == null) return;

    for (final file in files) {
      final path = file.path;
      if (path.isEmpty || !path.toLowerCase().endsWith('.pdf')) continue;

      final name = path.split('/').last;
      navigator.push(
        MaterialPageRoute(
          builder: (_) => PdfViewerScreen(filePath: path, fileName: name),
        ),
      );
      return;
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp(
      title: 'PdfTabs',
      debugShowCheckedModeBanner: false,
      navigatorKey: _navigatorKey,
      theme: AppTheme.lightTheme(),
      darkTheme: AppTheme.darkTheme(),
      themeMode: themeMode,
      home: const HomeScreen(),
    );
  }
}
