import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';
import 'package:provider/provider.dart';

import '../../../core/network/device_address.dart';
import '../../server/local_http_server.dart';
import '../domain/credential.dart';
import '../domain/credentials_repository.dart';
import 'add_credential_screen.dart';
import 'credentials_notifier.dart';
import '../../qr/presentation/qr_scan_screen.dart';

class CredentialsListScreen extends StatelessWidget {
  const CredentialsListScreen({super.key});

  /// HTTP к Mac по Wi‑Fi: явные таймауты (иначе iOS часто даёт Operation timed out).
  static Future<http.Response> _postToLan(
    Uri uri, {
    required Map<String, String> headers,
    required String body,
  }) async {
    final socket = HttpClient()
      ..connectionTimeout = const Duration(seconds: 12);
    final client = IOClient(socket);
    try {
      return await client
          .post(uri, headers: headers, body: body)
          .timeout(const Duration(seconds: 25));
    } finally {
      client.close();
    }
  }

  static String _networkErrorHint(Object e, String host) {
    final t = e.toString().toLowerCase();
    if (e is TimeoutException ||
        t.contains('timeout') ||
        t.contains('timed out')) {
      return 'Таймаут до $host. Проверьте: 1) Mac и iPhone в одной Wi‑Fi без «гостевой изоляции» '
          '2) на Mac: Системные настройки → Сеть → Файрвол — разрешите node/терминалу входящие на порт 8080 '
          '3) iPhone: Настройки → Конфиденциальность → Локальная сеть — включите Session Manager '
          '4) IP в QR = IP Mac в Wi‑Fi (ifconfig / «Подробнее» у Wi‑Fi).';
    }
    if (t.contains('failed host lookup') || t.contains('no address')) {
      return 'Не удалось разрешить имя хоста для $host.';
    }
    if (t.contains('network is unreachable')) {
      return 'Сеть недоступна. Wi‑Fi включён?';
    }
    return e.toString();
  }

  /// Встроенный Shelf на этом устройстве: в QR указан IP телефона в Wi‑Fi, либо loopback
  /// только на симуляторе (нет реального Wi‑Fi IP). Нельзя считать 127.0.0.1 «телефоном»,
  /// если телефон в сети — иначе POST уйдёт на Shelf, а Node на ПК не получит данные.
  static bool _isPhoneAsServerHost(String host, String? phoneWifiIpv4) {
    final h = host.toLowerCase();
    if (phoneWifiIpv4 != null &&
        phoneWifiIpv4.isNotEmpty &&
        h == phoneWifiIpv4.toLowerCase()) {
      return true;
    }
    if (h == '127.0.0.1' || h == 'localhost' || h == '::1') {
      return phoneWifiIpv4 == null || phoneWifiIpv4.isEmpty;
    }
    return false;
  }

  Future<void> _sendViaLocalHttp(BuildContext context, String accountId) async {
    final server = context.read<LocalHttpServer>();
    final sessionFlow = context.read<SessionFlowNotifier>();
    final repository = context.read<CredentialsRepository>();
    final device = context.read<DeviceAddressService>();

    final cred = await repository.getDecryptedById(accountId);
    if (cred == null || cred.password == null) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Не удалось прочитать учётную запись.')),
      );
      return;
    }

    final phoneIp = await device.getWifiIpv4();
    final origin = sessionFlow.relayOrigin;
    final sessionId = sessionFlow.pendingSessionId;

    final useRelayToPc = sessionId != null &&
        origin != null &&
        !_isPhoneAsServerHost(origin.host, phoneIp);

    if (useRelayToPc) {
      final hostLower = origin.host.toLowerCase();
      if ((hostLower == '127.0.0.1' || hostLower == 'localhost') &&
          phoneIp != null &&
          phoneIp.isNotEmpty) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'В QR указан 127.0.0.1 — с телефона сервер на компьютере так не найти. '
              'На ПК в client/index.html выставьте baseUrl: http://<IP_этого_Mac_в_Wi‑Fi>:8080, '
              'перезагрузите страницу и отсканируйте новый QR.',
            ),
            duration: Duration(seconds: 12),
          ),
        );
        return;
      }
      final uri = origin.replace(
        path: '/request',
        queryParameters: {'session': sessionId},
      );
      try {
        final response = await _postToLan(
          uri,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'login': cred.login, 'password': cred.password}),
        );
        if (!context.mounted) return;
        if (response.statusCode == 200) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Данные отправлены на ПК. Страница в браузере подхватит их по сессии.',
              ),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('HTTP ${response.statusCode}: ${response.body}'),
            ),
          );
        }
      } on SocketException catch (e) {
        if (!context.mounted) return;
        final os = e.osError;
        final refused = os?.errorCode == 61 || os?.errorCode == 111;
        final msg = refused
            ? 'Порт закрыт: ${uri.host}:${uri.port}. Запущен node server.js на Mac? Файрвол не блокирует 8080?'
            : _networkErrorHint(e, uri.host);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg), duration: const Duration(seconds: 12)),
        );
      } catch (e) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_networkErrorHint(e, uri.host)),
            duration: const Duration(seconds: 14),
          ),
        );
      }
      return;
    }

    if (!server.isRunning) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Локальный HTTP-сервер не запущен. Полный перезапуск приложения.',
          ),
        ),
      );
      return;
    }
    final uri = server.credentialsUri();
    try {
      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'account_id': accountId}),
      );
      if (!context.mounted) return;
      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Отправлено только на HTTP-сервер в этом приложении (не Node на ПК). '
              'Для релея на компьютер отсканируйте QR с IP ПК в Wi‑Fi.',
            ),
            duration: Duration(seconds: 8),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('HTTP ${response.statusCode}: ${response.body}')),
        );
      }
    } on SocketException catch (e) {
      if (!context.mounted) return;
      final os = e.osError;
      final refused = os?.errorCode == 61 || os?.errorCode == 111;
      final msg = refused
          ? 'Никто не слушает ${uri.host}:${uri.port}. '
                'Часто порт 8080 занят (остановите node server.js на Mac при работе в iOS Simulator) '
                'или сделайте полный stop приложения и запуск снова.'
          : 'Сеть: $e';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), duration: const Duration(seconds: 8)),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Request failed: $e')),
      );
    }
  }

  void _showCredentialActions(
    BuildContext context,
    Credential c,
    SessionFlowNotifier session,
  ) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ListTile(
                title: Text(c.url, maxLines: 1, overflow: TextOverflow.ellipsis),
                subtitle: Text(c.login),
              ),
              ListTile(
                leading: const Icon(Icons.send),
                title: Text(
                  session.pendingSessionId != null
                      ? 'Отправить на сервер (Mac)'
                      : 'Локальный тест (только это устройство)',
                ),
                onTap: () async {
                  Navigator.pop(ctx);
                  await _sendViaLocalHttp(context, c.id);
                },
              ),
              ListTile(
                leading: Icon(Icons.delete_outline, color: Theme.of(context).colorScheme.error),
                title: Text('Delete', style: TextStyle(color: Theme.of(context).colorScheme.error)),
                onTap: () async {
                  Navigator.pop(ctx);
                  final ok = await showDialog<bool>(
                    context: context,
                    builder: (dCtx) => AlertDialog(
                      title: const Text('Delete credential?'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(dCtx, false),
                          child: const Text('Cancel'),
                        ),
                        FilledButton(
                          onPressed: () => Navigator.pop(dCtx, true),
                          child: const Text('Delete'),
                        ),
                      ],
                    ),
                  );
                  if (ok == true && context.mounted) {
                    await context.read<CredentialsNotifier>().delete(c.id);
                  }
                },
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Session Manager'),
        actions: [
          IconButton(
            tooltip: 'Scan QR',
            onPressed: () async {
              final device = context.read<DeviceAddressService>();
              final scanned = await Navigator.of(context).push<bool>(
                MaterialPageRoute(
                  builder: (_) => QrScanScreen(deviceAddress: device),
                ),
              );
              if (!context.mounted) return;
              if (scanned == true) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Сессия сохранена. Нажмите на учётную запись → «Отправить на сервер». '
                      'Если списка нет — сначала «+» и добавьте логин/пароль.',
                    ),
                    duration: Duration(seconds: 9),
                  ),
                );
              }
            },
            icon: const Icon(Icons.qr_code_scanner),
          ),
        ],
      ),
      body: Consumer<CredentialsNotifier>(
        builder: (context, notifier, _) {
          if (notifier.loading && notifier.items.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }
          if (notifier.error != null) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  notifier.error!,
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          final session = context.watch<SessionFlowNotifier>();
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (session.pendingSessionId != null)
                MaterialBanner(
                  content: Text(
                    'Сессия: ${session.pendingSessionId}\n'
                    'Нажмите на строку с логином → «Отправить на сервер». '
                    'Один скан QR данные на Mac не передаёт.',
                  ),
                  leading: const Icon(Icons.link),
                  actions: [
                    TextButton(
                      onPressed: () => session.clearSession(),
                      child: const Text('Сбросить'),
                    ),
                  ],
                ),
              Expanded(
                child: notifier.items.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(
                            session.pendingSessionId != null
                                ? 'Нет учётных записей. Нажмите «+», добавьте логин/пароль, '
                                    'затем откройте запись и «Отправить на сервер».'
                                : 'Нет записей.\nНажмите «+», чтобы добавить.',
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodyLarge,
                          ),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        itemCount: notifier.items.length,
                        itemBuilder: (context, index) {
                          final c = notifier.items[index];
                          return Dismissible(
                            key: ValueKey(c.id),
                            direction: DismissDirection.endToStart,
                            background: Container(
                              alignment: Alignment.centerRight,
                              padding: const EdgeInsets.only(right: 20),
                              color: Theme.of(context).colorScheme.errorContainer,
                              child: Icon(
                                Icons.delete,
                                color: Theme.of(context).colorScheme.onErrorContainer,
                              ),
                            ),
                            onDismissed: (_) =>
                                context.read<CredentialsNotifier>().delete(c.id),
                            child: ListTile(
                              title: Text(
                                c.url,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              subtitle: Text(c.login),
                              onTap: () => _showCredentialActions(
                                context,
                                c,
                                session,
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await Navigator.of(context).push<void>(
            MaterialPageRoute(
              builder: (_) => const AddCredentialScreen(),
            ),
          );
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}
