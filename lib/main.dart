import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:background_downloader/background_downloader.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:workmanager/workmanager.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await FileDownloader().trackTasks();
  Workmanager().initialize(
      callbackDispatcher, // The top level function, aka callbackDispatcher
      isInDebugMode:
          true // If enabled it will post a notification whenever the task is running. Handy for debugging tasks
      );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        // This is the theme of your application.
        //
        // TRY THIS: Try running your application with "flutter run". You'll see
        // the application has a purple toolbar. Then, without quitting the app,
        // try changing the seedColor in the colorScheme below to Colors.green
        // and then invoke "hot reload" (save your changes or press the "hot
        // reload" button in a Flutter-supported IDE, or press "r" if you used
        // the command line to start the app).
        //
        // Notice that the counter didn't reset back to zero; the application
        // state is not lost during the reload. To reset the state, use hot
        // restart instead.
        //
        // This works for code too, not just values: Most code changes can be
        // tested with just a hot reload.
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const MyHomePage(title: 'Flutter Demo Home Page'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  // This widget is the home page of your application. It is stateful, meaning
  // that it has a State object (defined below) that contains fields that affect
  // how it looks.

  // This class is the configuration for the state. It holds the values (in this
  // case the title) provided by the parent (in this case the App widget) and
  // used by the build method of the State. Fields in a Widget subclass are
  // always marked "final".

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final ValueNotifier<List<String>> _files = ValueNotifier([]);
  final ValueNotifier<List<TaskRecord>> _tasks = ValueNotifier([]);
  StreamSubscription? _sub;
  Timer? _timer;
  StreamSubscription? _downloaderStatus;

  @override
  void initState() {
    unawaited(_readTasks());
    _downloaderStatus = FileDownloader().updates.listen((status) async {
      await _readTasks();
    });

    // Poll the tasks
    /*
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _readTasks();
    });
    */
    super.initState();
  }

  Future<void> _readFiles() async {
    final directory = await getApplicationDocumentsDirectory();
    _files.value = directory.listSync().map((f) => _filename(f)).toList();

    _sub = directory.watch().listen((events) {
      _files.value = directory.listSync().map((f) => _filename(f)).toList();
    });
  }

  Future<void> _readTasks() async {
    final tasks = await FileDownloader().database.allRecords();
    _tasks.value = tasks;
  }

  @override
  void dispose() {
    _timer?.cancel();
    _sub?.cancel();
    _downloaderStatus?.cancel();
    super.dispose();
  }

  String _filename(FileSystemEntity f) {
    return f.path.split('/').last;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Files in Application Directory'),
      ),
      body: ValueListenableBuilder(
        valueListenable: _tasks,
        builder: (context, tasks, child) => ListView.builder(
          itemCount: tasks.length,
          itemBuilder: (context, index) => ListTile(
            title: Text(tasks[index].taskId),
            subtitle: Text(tasks[index].status.toString()),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await _readTasks();
          Workmanager().registerOneOffTask(
            "task-identifier",
            "simpleTask",
            initialDelay: const Duration(seconds: 5),
          );
          await _readTasks();
        },
        tooltip: 'Increment',
        child: const Icon(Icons.add),
      ), // This trailing comma makes auto-formatting nicer for build methods.
    );
  }
}

DownloadTask _createDownloadTask({String type = 'background'}) {
  return DownloadTask(
    url: 'https://google.com/search',
    urlQueryParameters: {'q': 'pizza'},
    filename: '$type-file-${Random().nextInt(100000)}.html',
    metaData: type,
  );
}

@pragma(
    'vm:entry-point') // Mandatory if the App is obfuscated or using Flutter 3.1+
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    //  start tracking tasks in the database
    await FileDownloader().trackTasks();
    final download = _createDownloadTask();
    print('background download for $download');
    final success = await FileDownloader().enqueue(download);
    return Future.value(success);
  });
}
