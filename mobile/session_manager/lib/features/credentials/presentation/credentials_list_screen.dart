import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';

import '../../../core/network/device_address.dart';
import '../domain/credential.dart';
import '../domain/credentials_repository.dart';
import 'add_credential_screen.dart';
import 'credentials_notifier.dart';
import '../../qr/presentation/qr_scan_screen.dart';

class CredentialsListScreen extends StatelessWidget {
  const CredentialsListScreen({super.key});

  Future<void> _sendViaLocalHttp(BuildContext context, String accountId) async {
    final uri = Uri.parse('http://127.0.0.1:8080/credentials');
    try {
      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'account_id': accountId}),
      );
      if (!context.mounted) return;
      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Credentials sent over local HTTP (OK)')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('HTTP ${response.statusCode}: ${response.body}')),
        );
      }
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
                      ? 'Send via local HTTP (session active)'
                      : 'POST to local server',
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
              await Navigator.of(context).push<void>(
                MaterialPageRoute(
                  builder: (_) => QrScanScreen(deviceAddress: device),
                ),
              );
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
                    'Session: ${session.pendingSessionId} — pick a credential, then use “Send” or POST test.',
                  ),
                  leading: const Icon(Icons.link),
                  actions: [
                    TextButton(
                      onPressed: () => session.clearSession(),
                      child: const Text('Dismiss'),
                    ),
                  ],
                ),
              Expanded(
                child: notifier.items.isEmpty
                    ? Center(
                        child: Text(
                          'No credentials yet.\nTap + to add one.',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodyLarge,
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
