import 'dart:convert';
import 'dart:io';

import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;

import '../credentials/domain/credentials_repository.dart';

const Map<String, String> _corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
  'Access-Control-Allow-Headers': 'Content-Type',
};

/// Local HTTP server for LAN credential handoff (port 8080).
class LocalHttpServer {
  LocalHttpServer(this._repository);

  final CredentialsRepository _repository;
  HttpServer? _server;

  int get port => _server?.port ?? 8080;

  bool get isRunning => _server != null;

  /// URL для запросов с этого же устройства (симулятор/телефон) к встроенному серверу.
  Uri credentialsUri() =>
      Uri(scheme: 'http', host: '127.0.0.1', port: port, path: '/credentials');

  Future<void> start() async {
    if (_server != null) return;
    final handler = Pipeline()
        .addMiddleware(_corsMiddleware())
        .addHandler(_handle);
    try {
      _server = await shelf_io.serve(handler, InternetAddress.anyIPv4, 8080);
    } on SocketException catch (e) {
      if (e.message.contains('Address already in use') ||
          e.osError?.errorCode == 48) {
        throw SocketException(
          'Порт 8080 занят (часто это node server.js на том же Mac в симуляторе). '
          'Остановите другой процесс на 8080 или смените его порт.',
          address: e.address,
          port: e.port,
        );
      }
      rethrow;
    }
  }

  Future<void> stop() async {
    await _server?.close(force: true);
    _server = null;
  }

  Middleware _corsMiddleware() {
    return (Handler inner) {
      return (Request request) async {
        if (request.method == 'OPTIONS') {
          return Response.ok('', headers: _corsHeaders);
        }
        final response = await inner(request);
        return response.change(headers: {...response.headers, ..._corsHeaders});
      };
    };
  }

  Future<Response> _handle(Request request) async {
    final path = request.requestedUri.path;
    if (request.method == 'GET' &&
        (path == '/request' || path == '/request/')) {
      return Response.ok(
        jsonEncode({'status': 'ok'}),
        headers: {'Content-Type': 'application/json'},
      );
    }
    if (request.method == 'POST' &&
        (path == '/credentials' || path == '/credentials/')) {
      try {
        final body = await request.readAsString();
        final map = jsonDecode(body) as Map<String, dynamic>;
        final accountId = map['account_id'] as String?;
        if (accountId == null || accountId.isEmpty) {
          return Response.badRequest(
            body: jsonEncode({'error': 'account_id is required'}),
            headers: {'Content-Type': 'application/json'},
          );
        }
        final cred = await _repository.getDecryptedById(accountId);
        if (cred == null || cred.password == null) {
          return Response.notFound(
            jsonEncode({'error': 'credential not found'}),
            headers: {'Content-Type': 'application/json'},
          );
        }
        return Response.ok(
          jsonEncode({'login': cred.login, 'password': cred.password}),
          headers: {'Content-Type': 'application/json'},
        );
      } catch (e) {
        return Response.internalServerError(
          body: jsonEncode({'error': e.toString()}),
          headers: {'Content-Type': 'application/json'},
        );
      }
    }
    return Response.notFound(
      jsonEncode({'error': 'not found'}),
      headers: {'Content-Type': 'application/json'},
    );
  }
}
