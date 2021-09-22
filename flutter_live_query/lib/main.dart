import 'dart:async';

import 'package:flutter/material.dart';
import 'package:parse_server_sdk_flutter/parse_server_sdk.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  const keyApplicationId = 'Your_AppId_Here';
  const keyClientKey = 'Your_ClientKey_Here';
  const keyParseServerUrl = 'https://parseapi.back4app.com';

  await Parse().initialize(keyApplicationId, keyParseServerUrl,
      clientKey: keyClientKey,
      liveQueryUrl: 'Your_LiveQuery_URL_Here',
      debug: true);

  runApp(const MaterialApp(
    home: Home(),
  ));
}

class Home extends StatefulWidget {
  const Home({Key? key}) : super(key: key);

  @override
  _HomeState createState() => _HomeState();
}

class _HomeState extends State<Home> {
  final todoController = TextEditingController();
  List<ParseObject> taskList = [];
  final QueryBuilder<ParseObject> queryTodo =
      QueryBuilder<ParseObject>(ParseObject('Todo'))
        ..orderByAscending('createdAt');

  StreamController<List<ParseObject>> streamController = StreamController();

  final LiveQuery liveQuery = LiveQuery(debug: true);
  late Subscription<ParseObject> subscription;

  void addToDo() async {
    if (todoController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text("Empty title"),
        duration: Duration(seconds: 2),
      ));
      return;
    }
    await saveTodo(todoController.text);
    todoController.clear();
  }

  @override
  void initState() {
    super.initState();
    getTodoList();
    startLiveQuery();
  }

  void startLiveQuery() async {
    subscription = await liveQuery.client.subscribe(queryTodo);

    subscription.on(LiveQueryEvent.create, (value) {
      debugPrint('*** CREATE ***: $value ');
      taskList.add(value);
      streamController.add(taskList);
    });

    subscription.on(LiveQueryEvent.update, (value) {
      debugPrint('*** UPDATE ***: $value ');
      taskList[taskList
          .indexWhere((element) => element.objectId == value.objectId)] = value;
      streamController.add(taskList);
    });

    subscription.on(LiveQueryEvent.delete, (value) {
      debugPrint('*** DELETE ***: $value ');
      taskList.removeWhere((element) => element.objectId == value.objectId);
      streamController.add(taskList);
    });
  }

  void cancelLiveQuery() async {
    liveQuery.client.unSubscribe(subscription);
  }

  Future<void> saveTodo(String title) async {
    final todo = ParseObject('Todo')
      ..set('title', title)
      ..set('done', false);
    await todo.save();
  }

  void getTodoList() async {
    final ParseResponse apiResponse = await queryTodo.query();

    if (apiResponse.success && apiResponse.results != null) {
      taskList.addAll(apiResponse.results as List<ParseObject>);
      streamController.add(apiResponse.results as List<ParseObject>);
    } else {
      taskList.clear();
      streamController.add([]);
    }
  }

  Future<void> updateTodo(String id, bool done) async {
    var todo = ParseObject('Todo')
      ..objectId = id
      ..set('done', done);
    await todo.save();
  }

  Future<void> deleteTodo(String id) async {
    var todo = ParseObject('Todo')..objectId = id;
    await todo.delete();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Todo List Live"),
        backgroundColor: Colors.blueAccent,
        centerTitle: true,
      ),
      body: Column(
        children: <Widget>[
          Container(
              padding: const EdgeInsets.fromLTRB(17.0, 1.0, 7.0, 1.0),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: TextField(
                      autocorrect: true,
                      textCapitalization: TextCapitalization.sentences,
                      controller: todoController,
                      decoration: const InputDecoration(
                          labelText: "New todo",
                          labelStyle: TextStyle(color: Colors.blueAccent)),
                    ),
                  ),
                  ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        onPrimary: Colors.white,
                        primary: Colors.blueAccent,
                      ),
                      onPressed: addToDo,
                      child: const Text("ADD")),
                ],
              )),
          Expanded(
              child: StreamBuilder<List<ParseObject>>(
            stream: streamController.stream,
            builder: (context, snapshot) {
              switch (snapshot.connectionState) {
                case ConnectionState.none:
                case ConnectionState.waiting:
                  return const Center(
                    child: SizedBox(
                        width: 100,
                        height: 100,
                        child: CircularProgressIndicator()),
                  );
                default:
                  if (snapshot.hasError) {
                    return const Center(
                      child: Text("Error..."),
                    );
                  }
                  if (!snapshot.hasData) {
                    return const Center(
                      child: Text("No Data..."),
                    );
                  } else {
                    return ListView.builder(
                        padding: const EdgeInsets.only(top: 10.0),
                        itemCount: snapshot.data!.length,
                        itemBuilder: (context, index) {
                          //*************************************
                          //Get Parse Object Values
                          final varTodo = snapshot.data![index];
                          final varTitle = varTodo.get<String>('title')!;
                          final varDone = varTodo.get<bool>('done')!;
                          //*************************************

                          return ListTile(
                            title: Text(varTitle),
                            leading: CircleAvatar(
                              child: Icon(varDone ? Icons.check : Icons.error),
                              backgroundColor:
                                  varDone ? Colors.green : Colors.blue,
                              foregroundColor: Colors.white,
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Checkbox(
                                    value: varDone,
                                    onChanged: (value) async {
                                      await updateTodo(
                                          varTodo.objectId!, value!);
                                      //setState(() {
                                      //  //Refresh UI
                                      //});
                                    }),
                                IconButton(
                                  icon: const Icon(
                                    Icons.delete,
                                    color: Colors.blue,
                                  ),
                                  onPressed: () async {
                                    await deleteTodo(varTodo.objectId!);
                                    //setState(() {
                                    const snackBar = SnackBar(
                                      content: Text("Todo deleted!"),
                                      duration: Duration(seconds: 2),
                                    );
                                    ScaffoldMessenger.of(context)
                                      ..removeCurrentSnackBar()
                                      ..showSnackBar(snackBar);
                                    //});
                                  },
                                )
                              ],
                            ),
                          );
                        });
                  }
              }
            },
          ))
        ],
      ),
    );
  }

  @override
  void dispose() {
    cancelLiveQuery();
    streamController.close();
    super.dispose();
  }
}
