import 'dart:io';

import 'package:dsr_lma/core/network/dual_stack_connect.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('NAT64 prefix embeds the IPv4 address', () {
    final mapped = nat64WellKnownPrefix(InternetAddress('150.136.215.212'));
    expect(mapped, isNotNull);
    expect(mapped!.rawAddress, [
      0x00, 0x64, 0xff, 0x9b, // 64:ff9b
      0, 0, 0, 0, 0, 0, 0, 0,
      150, 136, 215, 212, // 9688:d7d4
    ]);
  });

  test('IPv6 is tried before IPv4 when DNS returns both', () {
    final ipv4 = InternetAddress('150.136.215.212');
    final ipv6 = InternetAddress('64:ff9b::9688:d7d4');
    final ordered = connectionCandidates([ipv4, ipv6]);

    expect(ordered.first.type, InternetAddressType.IPv6);
    expect(ordered.last.address, ipv4.address);
    expect(ordered, hasLength(2));
  });

  test('synthesizes NAT64 when lookup returns only IPv4', () {
    final ordered = connectionCandidates([
      InternetAddress('150.136.215.212'),
    ]);

    expect(ordered.first.rawAddress.sublist(0, 4), [0x00, 0x64, 0xff, 0x9b]);
    expect(ordered.last.type, InternetAddressType.IPv4);
  });

  test('connects over IPv4 when that is the only route', () async {
    final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(server.close);
    server.listen((socket) => socket.destroy());

    final task = await dualStackConnectionFactory(
      Uri.parse('http://127.0.0.1:${server.port}/'),
      null,
      null,
    );
    final socket = await task.socket.timeout(const Duration(seconds: 5));
    socket.destroy();
  });
}
