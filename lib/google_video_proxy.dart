import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

class GoogleVideoProxy {
  GoogleVideoProxy({
    required Uri targetUri,
    required Map<String, String> forwardHeaders,
  })  : _targetUri = targetUri,
        _forwardHeaders = Map.unmodifiable(forwardHeaders);

  final Uri _targetUri;
  final Map<String, String> _forwardHeaders;

  HttpServer? _server;
  HttpClient? _client;
  StreamSubscription<HttpRequest>? _subscription;
  Uri? _localUri;

  bool get isRunning => _server != null;

  Future<Uri> start() async {
    if (_localUri != null && _server != null) {
      return _localUri!;
    }

    _client = _createHttpClient();

    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    _server = server;
    _localUri = Uri(
      scheme: 'http',
      host: server.address.address,
      port: server.port,
      path: '/stream',
    );

    _subscription = server.listen(
      _handleRequest,
      onError: (error, stackTrace) {
        debugPrint('GoogleVideoProxy server error: $error');
        debugPrint('$stackTrace');
      },
    );

    debugPrint('GoogleVideoProxy started at $_localUri');
    return _localUri!;
  }

  Future<void> stop() async {
    await _subscription?.cancel();
    _subscription = null;

    await _server?.close(force: true);
    _server = null;

    _client?.close(force: true);
    _client = null;

    _localUri = null;
  }

  HttpClient _createHttpClient() {
    final client = HttpClient();
    final userAgent = _forwardHeaders[HttpHeaders.userAgentHeader];
    if (userAgent != null && userAgent.isNotEmpty) {
      client.userAgent = userAgent;
    }
    client.autoUncompress = false;
    client.connectionTimeout = const Duration(seconds: 12);
    return client;
  }

  Future<void> _handleRequest(HttpRequest request) async {
    final client = _client ?? _createHttpClient();
    _client = client;

    HttpClientRequest upstreamRequest;
    try {
      upstreamRequest = await client.openUrl(request.method, _targetUri);
    } catch (error, stackTrace) {
      debugPrint('GoogleVideoProxy upstream open error: $error');
      debugPrint('$stackTrace');
      return _failRequest(request, HttpStatus.badGateway, 'Proxy open error');
    }

    // Apply persisted headers first.
    _forwardHeaders.forEach((key, value) {
      if (_shouldSkipRequestHeader(key)) return;
  upstreamRequest.headers.set(key, value);
    });

    // Forward range and other relevant headers from the local request.
    final forwardedHeaders = <String>[
      HttpHeaders.rangeHeader,
      HttpHeaders.acceptHeader,
      HttpHeaders.acceptLanguageHeader,
      HttpHeaders.acceptEncodingHeader,
    ];

    for (final headerName in forwardedHeaders) {
      final value = request.headers.value(headerName);
      if (value != null && value.isNotEmpty) {
  upstreamRequest.headers.set(headerName, value);
      }
    }

    // Ensure Accept-Encoding is identity if not overridden.
  if (upstreamRequest.headers.value(HttpHeaders.acceptEncodingHeader) ==
        null) {
      final encoding =
          _forwardHeaders[HttpHeaders.acceptEncodingHeader] ?? 'identity';
  upstreamRequest.headers.set(HttpHeaders.acceptEncodingHeader, encoding);
    }

    HttpClientResponse upstreamResponse;
    try {
      upstreamResponse = await upstreamRequest.close();
    } catch (error, stackTrace) {
      debugPrint('GoogleVideoProxy upstream request error: $error');
      debugPrint('$stackTrace');
      return _failRequest(request, HttpStatus.badGateway, 'Proxy fetch error');
    }

    request.response.statusCode = upstreamResponse.statusCode;

    upstreamResponse.headers.forEach((name, values) {
      if (_shouldSkipResponseHeader(name)) {
        return;
      }
      for (final value in values) {
        request.response.headers.add(name, value);
      }
    });

    try {
      if (request.method == 'HEAD') {
        await upstreamResponse.drain();
        await request.response.close();
      } else {
        await upstreamResponse.pipe(request.response);
      }
    } catch (error, stackTrace) {
      debugPrint('GoogleVideoProxy piping error: $error');
      debugPrint('$stackTrace');
      try {
        await request.response.close();
      } catch (_) {}
    }
  }

  bool _shouldSkipRequestHeader(String name) {
    final lower = name.toLowerCase();
    return lower == 'connection' ||
        lower == 'host' ||
        lower == 'content-length' ||
        lower == 'accept-encoding';
  }

  bool _shouldSkipResponseHeader(String name) {
    final lower = name.toLowerCase();
    return lower == 'connection' || lower == 'transfer-encoding';
  }

  Future<void> _failRequest(
    HttpRequest request,
    int statusCode,
    String message,
  ) async {
    request.response.statusCode = statusCode;
    request.response.write(message);
    await request.response.close();
  }
}
