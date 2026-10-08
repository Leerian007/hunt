import 'package:web/web.dart' as web;

import 'dart:async';
import 'dart:js_interop';

Stream<Uri> browserAuthLinks() {
  late StreamController<Uri> controller;
  final listener = ((web.Event event) {
    controller.add(Uri.parse(web.window.location.href));
  }).toJS;
  controller = StreamController<Uri>(
    onListen: () => web.window.addEventListener('popstate', listener),
    onCancel: () => web.window.removeEventListener('popstate', listener),
  );
  return controller.stream;
}

void clearAuthQuery() {
  final query = Map<String, String>.from(Uri.base.queryParameters)
    ..remove('token')
    ..remove('steam_id');
  final clean = Uri.base.replace(queryParameters: query);
  web.window.history.replaceState(null, '', clean.toString());
}
