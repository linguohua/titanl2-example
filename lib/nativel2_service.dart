import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_background_service_android/flutter_background_service_android.dart';
import 'nativel2.dart' as nativel2;

// this will be used as notification channel id
const notificationChannelId = 'my_foreground';

// this will be used for notification id, So you can update your custom notification with this id.
const notificationId = 888;

// to ensure this is executed
// run app from xcode, then from xcode menu, select Simulate Background Fetch

@pragma('vm:entry-point')
Future<bool> onIosBackground(ServiceInstance service) async {
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();
  return true;
}

@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
  // Only available for flutter 3.0.0 and later
  DartPluginRegistrant.ensureInitialized();

  /// OPTIONAL when use custom notification
  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  if (service is AndroidServiceInstance) {
    service.on('setAsForeground').listen((event) {
      service.setAsForegroundService();
    });

    service.on('setAsBackground').listen((event) {
      service.setAsBackgroundService();
    });
  }

  service.on('stopService').listen((event) {
    service.stopSelf();
  });

  service.on('jsoncall').listen((event) async {
    int id = event!["id"];
    String args = event["args"];

    var result = await nativel2.L2Golang().jsonCall(args);

    Map<String, dynamic> reply = {
      "id": id,
      "reply": result,
    };

    service.invoke("jsoncall-reply", reply);
  });

  // bring to foreground
  Timer.periodic(const Duration(seconds: 3), (timer) async {
    if (service is AndroidServiceInstance) {
      if (await service.isForegroundService()) {
        /// OPTIONAL for use custom notification
        /// the notification id must be equals with AndroidConfiguration when you call configure() method.
        flutterLocalNotificationsPlugin.show(
          888,
          'COOL SERVICE',
          'Awesome ${DateTime.now()}',
          const NotificationDetails(
            android: AndroidNotificationDetails(
              'my_foreground',
              'MY FOREGROUND SERVICE',
              icon: 'ic_bg_service_small',
              ongoing: true,
            ),
          ),
        );

        // if you don't using custom notification, uncomment this
        service.setForegroundNotificationInfo(
          title: "My App Service",
          content: "Updated at ${DateTime.now()}",
        );
      }
    }
  });
}

class L2Service {
  // singleton pattern
  static final L2Service _instance = L2Service._internal();

  int _nextJSONCallRequestId = 0;
  final Map<int, Completer<String>> _jsonCallRequests =
      <int, Completer<String>>{};

  L2Service._internal();

  factory L2Service() {
    return _instance;
  }

  Future<void> initializeService() async {
    final service = FlutterBackgroundService();

    /// OPTIONAL, using custom notification channel id
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'my_foreground', // id
      'MY FOREGROUND SERVICE', // title
      description:
          'This channel is used for important notifications.', // description
      importance: Importance.low, // importance must be at low or higher level
    );

    final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
        FlutterLocalNotificationsPlugin();

    if (Platform.isIOS || Platform.isAndroid) {
      await flutterLocalNotificationsPlugin.initialize(
        const InitializationSettings(
          iOS: DarwinInitializationSettings(),
          android: AndroidInitializationSettings('ic_bg_service_small'),
        ),
      );
    }

    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    await service.configure(
      androidConfiguration: AndroidConfiguration(
        // this will be executed when app is in foreground or background in separated isolate
        onStart: onStart,

        // auto start service
        autoStart: true,
        isForegroundMode: true,

        notificationChannelId: 'my_foreground',
        initialNotificationTitle: 'AWESOME SERVICE',
        initialNotificationContent: 'Initializing',
        foregroundServiceNotificationId: 888,
      ),
      iosConfiguration: IosConfiguration(
        // auto start service
        autoStart: true,

        // this will be executed when app is in foreground in separated isolate
        onForeground: onStart,

        // you have to enable background fetch capability on xcode project
        onBackground: onIosBackground,
      ),
    );

    service.on('jsoncall-reply').listen((event) {
      int id = event!["id"];

      // The helper isolate sent us a response to a request we sent.
      final Completer<String> completer2 = _jsonCallRequests[id]!;
      _jsonCallRequests.remove(id);

      completer2.complete(event["reply"]);
    });

    await service.startService();
  }

  Future<String> jsonCall(String args) async {
    if (Platform.isAndroid) {
      return _jsonCallAndroid(args);
    } else {
      return nativel2.L2Golang().jsonCall(args);
    }
  }

  Future<String> _jsonCallAndroid(String args) async {
    final service = FlutterBackgroundService();
    bool isServiceRunning = await service.isRunning();
    if (isServiceRunning) {
      return jsonEncode({"code": -1, "msg": "edge service not running"});
    }

    final int requestId = _nextJSONCallRequestId++;
    final Map<String, dynamic> request = {
      "id": requestId,
      "args": args,
    };

    final Completer<String> completer = Completer<String>();
    _jsonCallRequests[requestId] = completer;
    service.invoke("jsoncall", request);

    return completer.future;
  }
}
