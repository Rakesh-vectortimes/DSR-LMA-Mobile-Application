import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../network/api_response.dart';
import 'export_filename.dart';
import 'typography_controller.dart';

Future<void> exportAndShare({
  required WidgetRef ref,
  required BuildContext context,
  required Future<ExportFile> Function() download,
  String preparingMessage = 'Preparing report...',
}) async {
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(preparingMessage)),
  );

  try {
    await ref.read(typographyControllerProvider.notifier).ensureLoaded();
    final file = await download();
    await shareExportFile(file);
  } catch (e) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(e.toString())),
    );
  }
}

Future<void> shareExportFile(ExportFile file) async {
  final dir = await getTemporaryDirectory();
  final path = '${dir.path}/${file.filename}';
  final diskFile = File(path);
  await diskFile.writeAsBytes(file.bytes, flush: true);
  await Share.shareXFiles(
    [XFile(path, mimeType: file.kind.mimeType, name: file.filename)],
    subject: file.filename,
  );
}

ApiException mapExportError(DioException e, {required String fallback}) {
  final data = e.response?.data;
  if (data is List<int>) {
    return ApiException(
      _messageFromBytes(Uint8List.fromList(data), fallback),
      statusCode: e.response?.statusCode,
    );
  }
  if (data is Uint8List) {
    return ApiException(
      _messageFromBytes(data, fallback),
      statusCode: e.response?.statusCode,
    );
  }
  return ApiException(
    ApiException.messageFromBody(data, fallback: fallback),
    statusCode: e.response?.statusCode,
  );
}

String _messageFromBytes(Uint8List bytes, String fallback) {
  try {
    final decoded = jsonDecode(utf8.decode(bytes));
    return ApiException.messageFromBody(decoded, fallback: fallback);
  } catch (_) {
    return fallback;
  }
}
