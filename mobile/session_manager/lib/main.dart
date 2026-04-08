import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/crypto/encryption_service.dart';
import 'core/network/device_address.dart';
import 'core/theme/app_theme.dart';
import 'features/credentials/data/credentials_repository_impl.dart';
import 'features/credentials/domain/credentials_repository.dart';
import 'features/credentials/presentation/credentials_list_screen.dart';
import 'features/credentials/presentation/credentials_notifier.dart';
import 'features/server/local_http_server.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final encryption = EncryptionService();
  await encryption.init();

  final CredentialsRepository repository = CredentialsRepositoryImpl(
    encryption: encryption,
  );

  final server = LocalHttpServer(repository);
  await server.start();

  final deviceAddress = DeviceAddressService();
  runApp(
    MultiProvider(
      providers: [
        Provider<EncryptionService>.value(value: encryption),
        Provider<CredentialsRepository>.value(value: repository),
        Provider<LocalHttpServer>.value(value: server),
        Provider<DeviceAddressService>.value(value: deviceAddress),
        ChangeNotifierProvider(
          create: (_) => CredentialsNotifier(repository)..load(),
        ),
        ChangeNotifierProvider(create: (_) => SessionFlowNotifier()),
      ],
      child: const SessionManagerApp(),
    ),
  );
}

class SessionManagerApp extends StatelessWidget {
  const SessionManagerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Session Manager',
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: ThemeMode.system,
      home: const CredentialsListScreen(),
    );
  }
}
