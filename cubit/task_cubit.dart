import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:sqflite/sqflite.dart';

part 'task_state.dart';

class TaskCubit extends Cubit<TaskState> {
  TaskCubit() : super(TaskInitial());

  Database? database;

  Future<void> initDatabase() async {
    database = await openDatabase(
      'todo2.db',
      version: 1,
      onCreate: (Database db, int version) {
        db.execute(
          "CREATE TABLE tasks (id INTEGER PRIMARY KEY, title TEXT, date TEXT, time TEXT, status TEXT, image_path TEXT)",
        ).then((_) {
          print('created table');
        });
      },
      onOpen: (Database db) {
        print('database opened');
      },
    );
    await getTasks();
  }

  Future<void> getTasks() async {
    emit(TaskLoading());
    try {
      final tasks = await database!.rawQuery("SELECT * FROM tasks");
      emit(TaskLoaded(tasks));
    } catch (e) {
      emit(TaskError('Error loading tasks'));
    }
  }

  Future<void> insertTask({
    required String title,
    required String date,
    required String time,
    String status = 'new',
    String? imagePath,
  }) async {
    await database!.rawInsert(
      "INSERT INTO tasks(title, date, time, status, image_path) VALUES(?, ?, ?, ?, ?)",
      [title, date, time, status, imagePath],
    ).then((value) {
      print("$value raw inserted");
      getTasks(); 
    });
  }

  Future<void> updateTask({
    required int id,
    required String title,
    required String date,
    required String time,
    required String status,
    String? imagePath,
  }) async {
    await database!.rawUpdate(
      "UPDATE tasks SET title = ?, date = ?, time = ?, status = ?, image_path = ? WHERE id = ?",
      [title, date, time, status, imagePath, id],
    ).then((value) {
      print("$value raw updated");
      getTasks(); 
    });
  }

  Future<void> deleteTask(int id) async {
    await database!.rawDelete("DELETE FROM tasks WHERE id = ?", [id]).then((value) {
      print("$value raw deleted");
      getTasks(); 
    });
  }

  Future<void> updateTaskStatus(int id, String status) async {
    await database!.rawUpdate(
      "UPDATE tasks SET status = ? WHERE id = ?",
      [status, id],
    ).then((value) {
      print("$value status updated");
      getTasks(); 
    });
  }
}