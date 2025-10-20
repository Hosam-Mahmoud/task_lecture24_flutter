import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  int _currentIndex = 0;

  @override
  void initState() {
    createDatabase();
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        appBar: AppBar(
          title: const Text('To-Do List'),
        ),
        body: [
          TaskListScreen(status: 'new', onTaskUpdated: () => setState(() {})),
          TaskListScreen(status: 'done', onTaskUpdated: () => setState(() {})),
          TaskListScreen(status: 'archived', onTaskUpdated: () => setState(() {})),
        ][_currentIndex],
        bottomNavigationBar: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) {
            setState(() {
              _currentIndex = index;
            });
          },
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.task), label: 'New Task'),
            BottomNavigationBarItem(icon: Icon(Icons.circle), label: 'Done Tasks'),
            BottomNavigationBarItem(icon: Icon(Icons.archive_sharp), label: 'Archived Tasks'),
          ],
        ),
      ),
    );
  }
}

class TaskListScreen extends StatefulWidget {
  final String status;
  final VoidCallback onTaskUpdated;

  const TaskListScreen({super.key, required this.status, required this.onTaskUpdated});

  @override
  State<TaskListScreen> createState() => _TaskListScreenState();
}

class _TaskListScreenState extends State<TaskListScreen> {
  Future<List<Map<String, dynamic>>> getData() async {
    if (database == null) {
      await createDatabase();
    }
    return await database!.rawQuery("SELECT * FROM tasks WHERE status = ?", [widget.status]);
  }

  Future<void> deleteTask(int id) async {
    await database!.rawDelete("DELETE FROM tasks WHERE id = ?", [id]).then((value) {
      print("$value raw deleted");
      widget.onTaskUpdated(); // تحديث الشاشة بعد الحذف
    });
  }

  Future<void> updateTaskStatus(int id, String status) async {
    await database!.rawUpdate(
      "UPDATE tasks SET status = ? WHERE id = ?",
      [status, id],
    ).then((value) {
      print("$value status updated");
      widget.onTaskUpdated(); // تحديث الشاشة بعد تغيير الحالة
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        FutureBuilder<List<Map<String, dynamic>>>(
          future: getData(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return const Center(child: Text('Error loading tasks'));
            }
            if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return const Center(child: Text('No tasks available'));
            }

            final tasks = snapshot.data!;
            return ListView.builder(
              itemCount: tasks.length,
              itemBuilder: (context, index) {
                final task = tasks[index];
                return ListTile(
                  leading: task['image_path'] != null
                      ? Image.file(
                          File(task['image_path']),
                          width: 50,
                          height: 50,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => const Icon(Icons.image_not_supported),
                        )
                      : const Icon(Icons.image_not_supported),
                  title: Text(task['title']),
                  subtitle: Text('${task['date']} ${task['time']}'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Checkbox(
                        value: task['status'] == 'done',
                        onChanged: (value) {
                          updateTaskStatus(task['id'], value == true ? 'done' : 'new');
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.edit, color: Colors.blue),
                        onPressed: () {
                          showModalBottomSheet(
                            context: context,
                            isScrollControlled: true,
                            builder: (context) {
                              return AddTaskBottomSheet(
                                onTaskAdded: widget.onTaskUpdated,
                                task: task,
                              );
                            },
                          );
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () {
                          deleteTask(task['id']);
                        },
                      ),
                    ],
                  ),
                );
              },
            );
          },
        ),
        if (widget.status == 'new')
          Align(
            alignment: Alignment.bottomRight,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: FloatingActionButton(
                child: const Icon(Icons.add),
                onPressed: () {
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    builder: (context) {
                      return AddTaskBottomSheet(
                        onTaskAdded: widget.onTaskUpdated,
                      );
                    },
                  );
                },
              ),
            ),
          ),
      ],
    );
  }
}

class AddTaskBottomSheet extends StatefulWidget {
  final VoidCallback? onTaskAdded;
  final Map<String, dynamic>? task;

  const AddTaskBottomSheet({super.key, this.onTaskAdded, this.task});

  @override
  State<AddTaskBottomSheet> createState() => _AddTaskBottomSheetState();
}

class _AddTaskBottomSheetState extends State<AddTaskBottomSheet> {
  final TextEditingController _titleController = TextEditingController();
  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;
  File? _selectedImage;
  final ImagePicker _picker = ImagePicker();
  int? _taskId;

  @override
  void initState() {
    super.initState();
    if (widget.task != null) {
      _taskId = widget.task!['id'];
      _titleController.text = widget.task!['title'];
      final dateParts = widget.task!['date'].split('-');
      _selectedDate = DateTime(
        int.parse(dateParts[2]),
        int.parse(dateParts[1]),
        int.parse(dateParts[0]),
      );
      _selectedTime = _parseTimeOfDay(widget.task!['time']);
      if (widget.task!['image_path'] != null) {
        _selectedImage = File(widget.task!['image_path']);
      }
    }
  }

  TimeOfDay? _parseTimeOfDay(String time) {
    final parts = time.split(':');
    final hour = int.parse(parts[0]);
    final minute = int.parse(parts[1].split(' ')[0]);
    final period = parts[1].split(' ')[1];
    return TimeOfDay(hour: period == 'PM' && hour != 12 ? hour + 12 : hour, minute: minute);
  }

  Future<void> _pickDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(2100),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _pickTime(BuildContext context) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime ?? TimeOfDay.now(),
    );
    if (picked != null && picked != _selectedTime) {
      setState(() {
        _selectedTime = picked;
      });
    }
  }

  Future<void> _pickImage() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() {
        _selectedImage = File(image.path);
      });
    }
  }

  void _saveTask() {
    if (_titleController.text.isNotEmpty && _selectedDate != null && _selectedTime != null) {
      if (_taskId == null) {
        insertIntoMyDatabase(
          title: _titleController.text,
          date: "${_selectedDate!.day}-${_selectedDate!.month}-${_selectedDate!.year}",
          time: _selectedTime!.format(context),
          imagePath: _selectedImage?.path,
        );
      } else {
        updateTask(
          id: _taskId!,
          title: _titleController.text,
          date: "${_selectedDate!.day}-${_selectedDate!.month}-${_selectedDate!.year}",
          time: _selectedTime!.format(context),
          imagePath: _selectedImage?.path,
          status: widget.task!['status'],
        );
      }
      widget.onTaskAdded?.call();
      Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill all fields')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 16,
        right: 16,
        top: 16,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Task Title',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.calendar_today),
              title: Text(
                _selectedDate == null
                    ? 'Select Date'
                    : "${_selectedDate!.day}-${_selectedDate!.month}-${_selectedDate!.year}",
              ),
              onTap: () => _pickDate(context),
            ),
            ListTile(
              leading: const Icon(Icons.access_time),
              title: Text(
                _selectedTime == null
                    ? 'Select Time'
                    : _selectedTime!.format(context),
              ),
              onTap: () => _pickTime(context),
            ),
            ListTile(
              leading: const Icon(Icons.image),
              title: Text(_selectedImage == null ? 'Select Image' : 'Image Selected'),
              onTap: _pickImage,
            ),
            if (_selectedImage != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Image.file(
                  _selectedImage!,
                  height: 100,
                  width: 100,
                  fit: BoxFit.cover,
                ),
              ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _saveTask,
              child: Text(_taskId == null ? 'Add Task' : 'Update Task'),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

Database? database;

Future<void> createDatabase() async {
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
}

Future<void> insertIntoMyDatabase({
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
  });
}
