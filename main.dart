import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'cubit/task_cubit.dart';

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
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: BlocProvider(
        create: (context) => TaskCubit()..initDatabase(),
        child: Scaffold(
          appBar: AppBar(
            title: const Text('To-Do List'),
          ),
          body: Builder(
            builder: (context) {
              return [
                TaskListScreen(status: 'new'),
                TaskListScreen(status: 'done'),
                TaskListScreen(status: 'archived'),
              ][_currentIndex];
            },
          ),
          bottomNavigationBar: BottomNavigationBar(
            currentIndex: _currentIndex,
            onTap: (index) {
              setState(() {
                _currentIndex = index;
              });
            },
            items: const [
              BottomNavigationBarItem(
                icon: Icon(Icons.task),
                label: 'New Task',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.circle),
                label: 'Done Tasks',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.archive_sharp),
                label: 'Archived Tasks',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class TaskListScreen extends StatelessWidget {
  final String status;

  const TaskListScreen({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        BlocBuilder<TaskCubit, TaskState>(
          builder: (context, state) {
            if (state is TaskLoading) {
              return const Center(child: CircularProgressIndicator());
            }
            if (state is TaskError) {
              return const Center(child: Text('Error loading tasks'));
            }
            if (state is TaskLoaded && state.tasks.isEmpty) {
              return const Center(child: Text('No tasks available'));
            }
            if (state is TaskLoaded) {
              final tasks = state.tasks.where((task) => task['status'] == status).toList();
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
                            context.read<TaskCubit>().updateTaskStatus(
                                  task['id'],
                                  value == true ? 'done' : 'new',
                                );
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.edit, color: Colors.blue),
                          onPressed: () {
                            showModalBottomSheet(
                              context: context,
                              isScrollControlled: true,
                              builder: (bottomSheetContext) {
                                return AddTaskBottomSheet(
                                  task: task,
                                  parentContext: context,
                                );
                              },
                            );
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () {
                            context.read<TaskCubit>().deleteTask(task['id']);
                          },
                        ),
                      ],
                    ),
                  );
                },
              );
            }
            return const Center(child: Text('No tasks available'));
          },
        ),
        if (status == 'new')
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
                    builder: (bottomSheetContext) {
                      return AddTaskBottomSheet(
                        parentContext: context,
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
  final Map<String, dynamic>? task;
  final BuildContext parentContext;

  const AddTaskBottomSheet({
    super.key,
    this.task,
    required this.parentContext,
  });

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
        widget.parentContext.read<TaskCubit>().insertTask(
              title: _titleController.text,
              date: "${_selectedDate!.day}-${_selectedDate!.month}-${_selectedDate!.year}",
              time: _selectedTime!.format(context),
              imagePath: _selectedImage?.path,
            );
      } else {
        widget.parentContext.read<TaskCubit>().updateTask(
              id: _taskId!,
              title: _titleController.text,
              date: "${_selectedDate!.day}-${_selectedDate!.month}-${_selectedDate!.year}",
              time: _selectedTime!.format(context),
              imagePath: _selectedImage?.path,
              status: widget.task!['status'],
            );
      }
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