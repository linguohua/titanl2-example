import 'dart:convert';

import 'package:flutter/material.dart';
import 'dart:async';
import 'titanedge_jcall.dart' as nativel2;
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'dart:io';
import 'package:toml/toml.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  // late Future<nativel2.JSONRsp> signAsyncResult;

  @override
  void initState() {
    super.initState();
    // signAsyncResult = nativel2.L2APIs().sign("abc");
  }

  @override
  Widget build(BuildContext context) {
    const textStyle = TextStyle(fontSize: 25);
    const spacerSmall = SizedBox(height: 10);
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Native Packages'),
        ),
        body: SingleChildScrollView(
          child: Container(
            padding: const EdgeInsets.all(10),
            child: const Column(
              children: [
                Text(
                  'This calls a native function through FFI that is shipped as source in the package. '
                  'The native code is built as part of the Flutter Runner build.',
                  style: textStyle,
                  textAlign: TextAlign.center,
                ),
                spacerSmall,
                DaemonCtrl(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class DaemonCtrl extends StatefulWidget {
  const DaemonCtrl({super.key});

  @override
  State<DaemonCtrl> createState() => _DaemonCtrlState();
}

class _DaemonCtrlState extends State<DaemonCtrl> {
  bool isDaemonRunning = false;
  int daemonCounter = 0;
  bool isClickHandling = false;
  String _title = "Start";
  late Timer timer;
  bool isQuerying = false;

  Future<String> stopDaemon() async {
    Map<String, dynamic> stopDaemonArgs = {
      'method': 'stopDaemon',
      'JSONParams': "",
    };

    var args = json.encode(stopDaemonArgs);

    var result = await nativel2.L2APIs().jsonCall(args);
    return result;
  }

  Future<String> startDaemon() async {
    var directory = await getApplicationDocumentsDirectory();
    var repoPath = path.join(directory.path, "titanl2");
    var repoDirectory = Directory(repoPath);
    if (!await repoDirectory.exists()) {
      await repoDirectory.create();
    }

    debugPrint('path: $repoDirectory');

    Map<String, dynamic> startDaemonArgs = {
      'repoPath': repoPath,
      'logPath': path.join(directory.path, "edge.log"),
      'locatorURL': "https://test-locator.titannet.io:5000/rpc/v0"
    };

    String startDaemonArgsJSON = json.encode(startDaemonArgs);

    Map<String, dynamic> jsonCallArgs = {
      'method': 'startDaemon',
      'JSONParams': startDaemonArgsJSON,
    };

    var args = json.encode(jsonCallArgs);

    var result = await nativel2.L2APIs().jsonCall(args);
    return result;
  }

  Future<String> daemonState() async {
    Map<String, dynamic> jsonCallArgs = {
      'method': 'state',
      'JSONParams': "",
    };

    var args = json.encode(jsonCallArgs);

    var result = await nativel2.L2APIs().jsonCall(args);
    return result;
  }

  Future<String> daemonSign() async {
    var directory = await getApplicationDocumentsDirectory();
    var repoPath = path.join(directory.path, "titanl2");

    Map<String, dynamic> signReqArgs = {'repoPath': repoPath, 'hash': "abc"};

    var signReqArgsJSON = json.encode(signReqArgs);

    Map<String, dynamic> jsonCallArgs = {
      'method': 'sign',
      'JSONParams': signReqArgsJSON,
    };

    var args = json.encode(jsonCallArgs);

    var result = await nativel2.L2APIs().jsonCall(args);
    return result;
  }

  Future<String> mergeConfig() async {
    Map<String, dynamic> configs = {
      'Storage': {"StorageGB": 32, "Path": "D:/filecoin-titan/test2"},
    };

    var configFile = TomlDocument.fromMap(configs).toString();

    // debugPrint('configsJSON: $configFile');
    var directory = await getApplicationDocumentsDirectory();
    var repoPath = path.join(directory.path, "titanl2");

    Map<String, dynamic> mergeConfigReqArgs = {
      'repoPath': repoPath,
      "config": configFile
    };

    var mergeConfigReqArgsJSON = json.encode(mergeConfigReqArgs);

    Map<String, dynamic> jsonCallArgs = {
      'method': 'mergeConfig',
      'JSONParams': mergeConfigReqArgsJSON,
    };

    var args = json.encode(jsonCallArgs);

    var result = await nativel2.L2APIs().jsonCall(args);
    return result;
  }

  Future<String> readConfig() async {
    var directory = await getApplicationDocumentsDirectory();
    var repoPath = path.join(directory.path, "titanl2");

    Map<String, dynamic> readConfigReqArgs = {
      'repoPath': repoPath,
    };

    var readConfigReqArgsJSON = json.encode(readConfigReqArgs);

    Map<String, dynamic> jsonCallArgs = {
      'method': 'readConfig',
      'JSONParams': readConfigReqArgsJSON,
    };

    var args = json.encode(jsonCallArgs);

    var result = await nativel2.L2APIs().jsonCall(args);
    return result;
  }

  Future<void> readLog() async {
    var directory = await getApplicationDocumentsDirectory();
    var logPath = path.join(directory.path, "edge.log");
    File file = File(logPath);

    // Read the contents of the file
    String contents = await file.readAsString();
    debugPrint(contents);
  }

  void handleStartStopClick() async {
    if (isClickHandling) {
      return;
    }

    isClickHandling = true;
    String result;

    if (isDaemonRunning) {
      result = await stopDaemon();
    } else {
      result = await startDaemon();
    }

    debugPrint('start/stop call: $result');
    isClickHandling = false;
    final Map<String, dynamic> jsonResult = jsonDecode(result);

    if (jsonResult["code"] == 0) {
      isDaemonRunning = !isDaemonRunning;
      setState(() {
        _title = isDaemonRunning ? "Stop" : "Start";
      });
    }
  }

  void handleSignClick() async {
    var ret = await daemonSign();
    debugPrint('handleSignClick: $ret');
  }

  void handleSetConfigClick() async {
    var ret = await mergeConfig();
    debugPrint('handleSetConfigClick: $ret');
  }

  void handleReadConfigClick() async {
    var ret = await readConfig();
    debugPrint('handleReadConfigClick: $ret');
  }

  void handleReadLogClick() async {
    await readLog();
  }

  void queryDaemonState() async {
    if (isQuerying) {
      return;
    }

    if (!isDaemonRunning) {
      return;
    }

    isQuerying = true;
    String result;

    result = await daemonState();

    debugPrint('state call: $result');

    isQuerying = false;
    final Map<String, dynamic> jsonResult = jsonDecode(result);

    if (jsonResult["Code"] == 0) {
      if (jsonResult["Counter"] != daemonCounter) {
        daemonCounter = jsonResult["Counter"];

        setState(() {
          final String prefix = isDaemonRunning ? "Stop" : "Start";
          _title = "$prefix(counter:$daemonCounter)";
        });
      }
    }
  }

  @override
  void initState() {
    super.initState();

    timer = Timer.periodic(const Duration(seconds: 3), (Timer timer) {
      queryDaemonState();
    });
  }

  @override
  void dispose() {
    super.dispose();
    timer.cancel();
  }

  @override
  Widget build(BuildContext context) {
    debugPrint('build call with button title: $_title');
    return Row(
      children: [
        ElevatedButton(
          onPressed: () {
            if (isClickHandling) {
              return;
            }
            handleStartStopClick();
          },
          child: Text(
            _title,
          ),
        ),
        ElevatedButton(
          onPressed: () {
            if (isClickHandling) {
              return;
            }
            handleSignClick();
          },
          child: const Text(
            "Sign",
          ),
        ),
        ElevatedButton(
          onPressed: () {
            if (isClickHandling) {
              return;
            }
            handleSetConfigClick();
          },
          child: const Text(
            "Set config",
          ),
        ),
        ElevatedButton(
          onPressed: () {
            if (isClickHandling) {
              return;
            }
            handleReadConfigClick();
          },
          child: const Text(
            "read config",
          ),
        ),
        ElevatedButton(
          onPressed: () {
            if (isClickHandling) {
              return;
            }
            handleReadLogClick();
          },
          child: const Text(
            "read log",
          ),
        )
      ],
    );
  }
}
