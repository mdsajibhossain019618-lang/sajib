import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  runApp(const AmarKajApp());
}

const String _kTasksKey = 'tasks_v1';

/// ইংরেজি সংখ্যাকে বাংলা সংখ্যায় বদলায়।
String bnDigits(String input) {
  const en = ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9'];
  const bn = ['০', '১', '২', '৩', '৪', '৫', '৬', '৭', '৮', '৯'];
  var out = input;
  for (var i = 0; i < 10; i++) {
    out = out.replaceAll(en[i], bn[i]);
  }
  return out;
}

const List<String> _bnWeekdays = [
  'সোমবার',
  'মঙ্গলবার',
  'বুধবার',
  'বৃহস্পতিবার',
  'শুক্রবার',
  'শনিবার',
  'রবিবার',
];

const List<String> _bnMonths = [
  'জানুয়ারি',
  'ফেব্রুয়ারি',
  'মার্চ',
  'এপ্রিল',
  'মে',
  'জুন',
  'জুলাই',
  'আগস্ট',
  'সেপ্টেম্বর',
  'অক্টোবর',
  'নভেম্বর',
  'ডিসেম্বর',
];

String bnDate(DateTime d) =>
    '${bnDigits(d.day.toString())} ${_bnMonths[d.month - 1]} ${bnDigits(d.year.toString())}';

String bnWeekday(DateTime d) => _bnWeekdays[d.weekday - 1];

bool _isSameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

enum Priority { joruri, shadharon, pore }

extension PriorityX on Priority {
  String get label {
    switch (this) {
      case Priority.joruri:
        return 'জরুরি';
      case Priority.shadharon:
        return 'সাধারণ';
      case Priority.pore:
        return 'পরে হলেও চলবে';
    }
  }

  Color get color {
    switch (this) {
      case Priority.joruri:
        return Colors.red;
      case Priority.shadharon:
        return Colors.orange.shade800;
      case Priority.pore:
        return Colors.green;
    }
  }
}

class Task {
  Task({
    required this.id,
    required this.title,
    this.note = '',
    this.priority = Priority.shadharon,
    this.dueDate,
    this.done = false,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  final String id;
  String title;
  String note;
  Priority priority;
  DateTime? dueDate;
  bool done;
  final DateTime createdAt;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'title': title,
        'note': note,
        'priority': priority.name,
        'dueDate': dueDate?.toIso8601String(),
        'done': done,
        'createdAt': createdAt.toIso8601String(),
      };

  factory Task.fromJson(Map<String, dynamic> json) {
    return Task(
      id: json['id'] as String? ?? DateTime.now().millisecondsSinceEpoch.toString(),
      title: json['title'] as String? ?? '',
      note: json['note'] as String? ?? '',
      priority: Priority.values.firstWhere(
        (p) => p.name == (json['priority'] as String? ?? ''),
        orElse: () => Priority.shadharon,
      ),
      dueDate: json['dueDate'] == null
          ? null
          : DateTime.tryParse(json['dueDate'] as String),
      done: json['done'] as bool? ?? false,
      createdAt: json['createdAt'] == null
          ? null
          : DateTime.tryParse(json['createdAt'] as String),
    );
  }
}

class AmarKajApp extends StatelessWidget {
  const AmarKajApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'আমার কাজ',
      debugShowCheckedModeBanner: false,
      locale: const Locale('bn'),
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('bn'),
        Locale('en'),
      ],
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.green),
      ),
      home: const HomePage(),
    );
  }
}

enum TaskFilter { all, remaining, done }

extension TaskFilterX on TaskFilter {
  String get label {
    switch (this) {
      case TaskFilter.all:
        return 'সব';
      case TaskFilter.remaining:
        return 'বাকি';
      case TaskFilter.done:
        return 'হয়ে গেছে';
    }
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  List<Task> _tasks = [];
  bool _loading = true;
  TaskFilter _filter = TaskFilter.all;

  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _noteController = TextEditingController();
  Priority _newPriority = Priority.shadharon;
  DateTime? _newDueDate;

  @override
  void initState() {
    super.initState();
    _loadTasks();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _loadTasks() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kTasksKey);
    if (raw != null && raw.isNotEmpty) {
      try {
        final list = jsonDecode(raw) as List<dynamic>;
        _tasks = list
            .map((e) => Task.fromJson(e as Map<String, dynamic>))
            .toList();
      } catch (_) {
        _tasks = [];
      }
    }
    if (mounted) {
      setState(() => _loading = false);
    }
  }

  Future<void> _saveTasks() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _kTasksKey,
      jsonEncode(_tasks.map((t) => t.toJson()).toList()),
    );
  }

  void _addTask() {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      return;
    }
    setState(() {
      _tasks.insert(
        0,
        Task(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          title: title,
          note: _noteController.text.trim(),
          priority: _newPriority,
          dueDate: _newDueDate,
        ),
      );
      _titleController.clear();
      _noteController.clear();
      _newPriority = Priority.shadharon;
      _newDueDate = null;
    });
    _saveTasks();
  }

  void _toggleDone(Task task) {
    setState(() => task.done = !task.done);
    _saveTasks();
  }

  void _deleteTask(Task task) {
    setState(() => _tasks.removeWhere((t) => t.id == task.id));
    _saveTasks();
  }

  void _clearCompleted() {
    setState(() => _tasks.removeWhere((t) => t.done));
    _saveTasks();
  }

  Future<bool?> _confirmDelete(Task task) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('মুছে ফেলবেন?'),
        content: Text('‘${task.title}’ কাজটি মুছে ফেলা হবে।'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('বাতিল'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('হ্যাঁ, মুছুন'),
          ),
        ],
      ),
    );
  }

  Future<bool?> _confirmClearCompleted(int count) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('শেষ হওয়া কাজ মুছে ফেলবেন?'),
        content: Text('$countটি শেষ হওয়া কাজ মুছে ফেলা হবে।'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('বাতিল'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('হ্যাঁ, মুছুন'),
          ),
        ],
      ),
    );
  }

  Future<void> _pickDueDate({DateTime? initial, required ValueChanged<DateTime?> onPicked}) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final picked = await showDatePicker(
      context: context,
      initialDate: initial ?? today,
      firstDate: DateTime(2020),
      lastDate: DateTime(now.year + 2, 12, 31),
      helpText: 'শেষ তারিখ বেছে নিন',
      cancelText: 'বাতিল',
      confirmText: 'ঠিক আছে',
    );
    if (picked != null) {
      onPicked(DateTime(picked.year, picked.month, picked.day));
    }
  }

  Future<void> _editTask(Task task) async {
    final titleController = TextEditingController(text: task.title);
    final noteController = TextEditingController(text: task.note);
    var priority = task.priority;
    var dueDate = task.dueDate;

    final saved = await showDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('কাজ এডিট করুন'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: titleController,
                      decoration: const InputDecoration(
                        labelText: 'কাজের নাম',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: noteController,
                      decoration: const InputDecoration(
                        labelText: 'নোট (ঐচ্ছিক)',
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 2,
                    ),
                    const SizedBox(height: 12),
                    const Text('গুরুত্ব'),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      children: Priority.values.map((p) {
                        return ChoiceChip(
                          label: Text(p.label),
                          selected: priority == p,
                          onSelected: (_) =>
                              setDialogState(() => priority = p),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        OutlinedButton.icon(
                          onPressed: () async {
                            await _pickDueDate(
                              initial: dueDate,
                              onPicked: (d) =>
                                  setDialogState(() => dueDate = d),
                            );
                          },
                          icon: const Icon(Icons.calendar_today, size: 18),
                          label: Text(
                            dueDate == null
                                ? 'শেষ তারিখ'
                                : bnDate(dueDate!),
                          ),
                        ),
                        if (dueDate != null)
                          IconButton(
                            tooltip: 'তারিখ সরান',
                            onPressed: () =>
                                setDialogState(() => dueDate = null),
                            icon: const Icon(Icons.clear),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('বাতিল'),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: const Text('সংরক্ষণ করুন'),
                ),
              ],
            );
          },
        );
      },
    );

    if (saved == true) {
      final newTitle = titleController.text.trim();
      if (newTitle.isEmpty) {
        return;
      }
      setState(() {
        task.title = newTitle;
        task.note = noteController.text.trim();
        task.priority = priority;
        task.dueDate = dueDate;
      });
      _saveTasks();
    }
    titleController.dispose();
    noteController.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final todayTasks = _tasks.where((t) {
      return t.dueDate != null && !t.dueDate!.isAfter(today);
    }).toList();
    final todayDone = todayTasks.where((t) => t.done).length;

    final todayPending = _tasks
        .where((t) => !t.done && t.dueDate != null && !t.dueDate!.isAfter(today))
        .toList();
    final otherPending = _tasks
        .where((t) => !t.done && (t.dueDate == null || t.dueDate!.isAfter(today)))
        .toList();
    final doneTasks = _tasks.where((t) => t.done).toList();

    final doneCount = _tasks.where((t) => t.done).length;

    List<Task> visibleToday = todayPending;
    List<Task> visibleOther = otherPending;
    List<Task> visibleDone = doneTasks;
    if (_filter == TaskFilter.remaining) {
      visibleDone = [];
    } else if (_filter == TaskFilter.done) {
      visibleToday = [];
      visibleOther = [];
    }

    final progress = todayTasks.isEmpty ? 0.0 : todayDone / todayTasks.length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('আমার কাজ'),
        centerTitle: true,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(
                  '${bnWeekday(now)}, ${bnDate(now)}',
                  style: Theme.of(context).textTheme.titleMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          todayTasks.isEmpty
                              ? 'আজকের কোনো কাজ নেই'
                              : 'আজ ${bnDigits(todayTasks.length.toString())}টির মধ্যে ${bnDigits(todayDone.toString())}টি কাজ শেষ',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        LinearProgressIndicator(value: progress),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        TextField(
                          controller: _titleController,
                          decoration: const InputDecoration(
                            labelText: 'নতুন কাজ লিখুন',
                            border: OutlineInputBorder(),
                          ),
                          onChanged: (_) => setState(() {}),
                          onSubmitted: (_) => _addTask(),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _noteController,
                          decoration: const InputDecoration(
                            labelText: 'নোট (ঐচ্ছিক)',
                            border: OutlineInputBorder(),
                          ),
                          maxLines: 2,
                        ),
                        const SizedBox(height: 12),
                        const Text('গুরুত্ব'),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 8,
                          children: Priority.values.map((p) {
                            return ChoiceChip(
                              label: Text(p.label),
                              selected: _newPriority == p,
                              onSelected: (_) =>
                                  setState(() => _newPriority = p),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            OutlinedButton.icon(
                              onPressed: () async {
                                await _pickDueDate(
                                  initial: _newDueDate,
                                  onPicked: (d) =>
                                      setState(() => _newDueDate = d),
                                );
                              },
                              icon: const Icon(Icons.calendar_today, size: 18),
                              label: Text(
                                _newDueDate == null
                                    ? 'শেষ তারিখ'
                                    : bnDate(_newDueDate!),
                              ),
                            ),
                            if (_newDueDate != null)
                              IconButton(
                                tooltip: 'তারিখ সরান',
                                onPressed: () =>
                                    setState(() => _newDueDate = null),
                                icon: const Icon(Icons.clear),
                              ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        FilledButton.icon(
                          onPressed: _titleController.text.trim().isEmpty
                              ? null
                              : _addTask,
                          icon: const Icon(Icons.add),
                          label: const Text('যোগ করুন'),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  children: TaskFilter.values.map((f) {
                    return ChoiceChip(
                      label: Text(f.label),
                      selected: _filter == f,
                      onSelected: (_) => setState(() => _filter = f),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 8),
                if (_tasks.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 32),
                    child: Text(
                      'এখনো কোনো কাজ নেই।\nউপরে নতুন কাজ যোগ করুন।',
                      textAlign: TextAlign.center,
                    ),
                  ),
                if (visibleToday.isNotEmpty) ...[
                  _SectionHeader(title: 'আজকের কাজ', count: visibleToday.length),
                  ...visibleToday.map((t) => _TaskTile(
                        task: t,
                        today: today,
                        onToggle: () => _toggleDone(t),
                        onEdit: () => _editTask(t),
                        onDelete: () async {
                          final ok = await _confirmDelete(t);
                          if (ok == true) {
                            _deleteTask(t);
                          }
                        },
                      )),
                ],
                if (visibleOther.isNotEmpty) ...[
                  _SectionHeader(title: 'অন্যান্য কাজ', count: visibleOther.length),
                  ...visibleOther.map((t) => _TaskTile(
                        task: t,
                        today: today,
                        onToggle: () => _toggleDone(t),
                        onEdit: () => _editTask(t),
                        onDelete: () async {
                          final ok = await _confirmDelete(t);
                          if (ok == true) {
                            _deleteTask(t);
                          }
                        },
                      )),
                ],
                if (visibleDone.isNotEmpty) ...[
                  _SectionHeader(title: 'হয়ে গেছে', count: visibleDone.length),
                  ...visibleDone.map((t) => _TaskTile(
                        task: t,
                        today: today,
                        onToggle: () => _toggleDone(t),
                        onEdit: () => _editTask(t),
                        onDelete: () async {
                          final ok = await _confirmDelete(t);
                          if (ok == true) {
                            _deleteTask(t);
                          }
                        },
                      )),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: () async {
                      final ok = await _confirmClearCompleted(doneCount);
                      if (ok == true) {
                        _clearCompleted();
                      }
                    },
                    icon: const Icon(Icons.delete_sweep),
                    label: const Text('শেষ হওয়া সব মুছে ফেলুন'),
                  ),
                ],
                const SizedBox(height: 24),
              ],
            ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.count});

  final String title;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 4),
      child: Text(
        '$title (${bnDigits(count.toString())})',
        style: Theme.of(context)
            .textTheme
            .titleMedium
            ?.copyWith(fontWeight: FontWeight.bold),
      ),
    );
  }
}

class _TaskTile extends StatelessWidget {
  const _TaskTile({
    required this.task,
    required this.today,
    required this.onToggle,
    required this.onEdit,
    required this.onDelete,
  });

  final Task task;
  final DateTime today;
  final VoidCallback onToggle;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final overdue =
        !task.done && task.dueDate != null && task.dueDate!.isBefore(today);
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        leading: Checkbox(
          value: task.done,
          onChanged: (_) => onToggle(),
        ),
        title: Text(
          task.title,
          style: task.done
              ? const TextStyle(decoration: TextDecoration.lineThrough)
              : null,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (task.note.isNotEmpty) Text(task.note),
            const SizedBox(height: 4),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                Chip(
                  label: Text(task.priority.label),
                  backgroundColor: task.priority.color.withOpacity(0.15),
                  labelStyle: TextStyle(color: task.priority.color),
                  visualDensity: VisualDensity.compact,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                if (task.dueDate != null)
                  Chip(
                    label: Text(
                      _isSameDay(task.dueDate!, today)
                          ? 'আজ'
                          : bnDate(task.dueDate!),
                    ),
                    visualDensity: VisualDensity.compact,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                if (overdue)
                  const Chip(
                    label: Text('মেয়াদ পার হয়েছে'),
                    backgroundColor: Colors.red,
                    labelStyle: TextStyle(color: Colors.white),
                    visualDensity: VisualDensity.compact,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
              ],
            ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              tooltip: 'এডিট',
              onPressed: onEdit,
              icon: const Icon(Icons.edit),
            ),
            IconButton(
              tooltip: 'মুছুন',
              onPressed: onDelete,
              icon: const Icon(Icons.delete),
            ),
          ],
        ),
      ),
    );
  }
}
