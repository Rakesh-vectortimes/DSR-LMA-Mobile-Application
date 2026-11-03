import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

/// Builds connection targets for [HttpClient].
///
/// Dart prefers IPv4 when both families are returned and waits for that
/// attempt to time out before trying IPv6. On this network the API's IPv4
/// address does not connect, while DNS64 publishes a working NAT64 address
/// (`64:ff9b::/96`). IPv6 is listed first so the working path is used.
List<InternetAddress> connectionCandidates(Iterable<InternetAddress> lookedUp) {
  final ipv6 = <InternetAddress>[];
  final ipv4 = <InternetAddress>[];
  for (final address in lookedUp) {
    if (address.type == InternetAddressType.IPv6) {
      ipv6.add(address);
    } else if (address.type == InternetAddressType.IPv4) {
      ipv4.add(address);
    }
  }
  if (ipv6.isEmpty) {
    for (final address in ipv4) {
      final mapped = nat64WellKnownPrefix(address);
      if (mapped != null) ipv6.add(mapped);
    }
  }
  return [...ipv6, ...ipv4];
}

/// RFC 6052 well-known NAT64 prefix `64:ff9b::/96`.
InternetAddress? nat64WellKnownPrefix(InternetAddress ipv4) {
  if (ipv4.type != InternetAddressType.IPv4) return null;
  final raw = ipv4.rawAddress;
  if (raw.length != 4) return null;
  final bytes = Uint8List(16);
  bytes[1] = 0x64;
  bytes[2] = 0xff;
  bytes[3] = 0x9b;
  bytes[12] = raw[0];
  bytes[13] = raw[1];
  bytes[14] = raw[2];
  bytes[15] = raw[3];
  return InternetAddress.fromRawAddress(bytes);
}

/// Socket factory used by Dio. Direct HTTPS sockets are wrapped in TLS here
/// because [HttpClient] does not upgrade sockets that come from
/// [HttpClient.connectionFactory].
Future<ConnectionTask<Socket>> dualStackConnectionFactory(
  Uri uri,
  String? proxyHost,
  int? proxyPort,
) {
  if (proxyHost != null && proxyHost.isNotEmpty) {
    return Socket.startConnect(proxyHost, proxyPort ?? uri.port);
  }

  var cancelled = false;
  final attempts = <ConnectionTask<Socket>>[];
  final opened = <Socket>[];
  final socket = _open(uri, () => cancelled, attempts, opened);
  return Future.value(
    ConnectionTask.fromSocket(socket, () {
      cancelled = true;
      for (final attempt in List<ConnectionTask<Socket>>.of(attempts)) {
        attempt.cancel();
      }
      for (final open in List<Socket>.of(opened)) {
        open.destroy();
      }
    }),
  );
}

Future<Socket> _open(
  Uri uri,
  bool Function() cancelled,
  List<ConnectionTask<Socket>> attempts,
  List<Socket> opened,
) async {
  final lookedUp = await InternetAddress.lookup(uri.host);
  if (cancelled()) {
    throw const SocketException('Connection cancelled');
  }
  final candidates = connectionCandidates(lookedUp);
  if (candidates.isEmpty) {
    throw SocketException('Failed host lookup: ${uri.host}');
  }

  final raw = await _firstConnected(uri.port, candidates, cancelled, attempts);
  opened.add(raw);
  if (uri.scheme != 'https') return raw;

  try {
    final secure = await SecureSocket.secure(raw, host: uri.host);
    opened.add(secure);
    return secure;
  } catch (_) {
    raw.destroy();
    rethrow;
  }
}

Future<Socket> _firstConnected(
  int port,
  List<InternetAddress> candidates,
  bool Function() cancelled,
  List<ConnectionTask<Socket>> attempts,
) {
  final completer = Completer<Socket>();
  var remaining = candidates.length;
  Object? lastError;
  StackTrace? lastStack;

  for (final address in candidates) {
    final delay = address.type == InternetAddressType.IPv4 && candidates.length > 1
        ? const Duration(milliseconds: 250)
        : Duration.zero;
    unawaited(
      _attempt(address, port, delay, cancelled, attempts).then((socket) {
        if (completer.isCompleted || cancelled()) {
          socket.destroy();
          return;
        }
        completer.complete(socket);
        for (final attempt in List<ConnectionTask<Socket>>.of(attempts)) {
          attempt.cancel();
        }
      }, onError: (Object error, StackTrace stack) {
        lastError = error;
        lastStack = stack;
        remaining--;
        if (remaining == 0 && !completer.isCompleted) {
          completer.completeError(
            lastError ?? const SocketException('Connection failed'),
            lastStack,
          );
        }
      }),
    );
  }

  return completer.future;
}

Future<Socket> _attempt(
  InternetAddress address,
  int port,
  Duration delay,
  bool Function() cancelled,
  List<ConnectionTask<Socket>> attempts,
) async {
  if (delay > Duration.zero) {
    await Future<void>.delayed(delay);
  }
  if (cancelled()) {
    throw const SocketException('Connection cancelled');
  }
  final task = await Socket.startConnect(address, port);
  attempts.add(task);
  try {
    final socket = await task.socket.timeout(const Duration(seconds: 8));
    if (cancelled()) {
      socket.destroy();
      throw const SocketException('Connection cancelled');
    }
    return socket;
  } catch (_) {
    task.cancel();
    rethrow;
  } finally {
    attempts.remove(task);
  }
}
