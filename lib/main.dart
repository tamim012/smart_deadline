import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const SmartDeadlineApp());
}

// ============================================================
// APP
// ============================================================

class SmartDeadlineApp extends StatefulWidget {
  const SmartDeadlineApp({super.key});

  @override
  State<SmartDeadlineApp> createState() => _SmartDeadlineAppState();
}

class _SmartDeadlineAppState extends State<SmartDeadlineApp> {
  bool darkMode = false;

  @override
  Widget build(BuildContext context) {
    const seed = Color(0xFF5B5BD6);

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'SmartDeadline',
      themeMode: darkMode ? ThemeMode.dark : ThemeMode.light,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: seed,
        ),
        scaffoldBackgroundColor: const Color(0xFFF7F7FB),
        cardTheme: CardThemeData(
          elevation: 0,
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(
              color: seed,
              width: 1.5,
            ),
          ),
        ),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: seed,
          brightness: Brightness.dark,
        ),
        scaffoldBackgroundColor: const Color(0xFF121218),
        cardTheme: CardThemeData(
          elevation: 0,
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFF1C1C24),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
        ),
      ),
      home: HomeShell(
        onDarkModeChanged: (value) {
          setState(() {
            darkMode = value;
          });
        },
      ),
    );
  }
}

// ============================================================
// TASK MODEL
// ============================================================

class Task {
  Task({
    required this.id,
    required this.title,
    required this.category,
    required this.deadline,
    required this.estimatedMinutes,
    required this.importance,
    this.description = '',
    this.progress = 0,
    this.completed = false,
  });

  final String id;

  String title;
  String category;
  DateTime deadline;
  int estimatedMinutes;
  int importance;
  String description;
  int progress;
  bool completed;

  int get remainingMinutes {
    final remaining = ((estimatedMinutes * (100 - progress)) / 100).ceil();

    return remaining < 0 ? 0 : remaining;
  }

  int priorityScore(DateTime now) {
    if (completed) {
      return 0;
    }

    final hours = deadline.difference(now).inHours;

    double deadlineScore;

    if (hours <= 24) {
      deadlineScore = 100;
    } else if (hours <= 48) {
      deadlineScore = 85;
    } else if (hours <= 96) {
      deadlineScore = 70;
    } else if (hours <= 168) {
      deadlineScore = 50;
    } else if (hours <= 336) {
      deadlineScore = 30;
    } else {
      deadlineScore = 10;
    }

    final remainingScore = (100 - progress).clamp(0, 100).toDouble();

    final workloadScore =
        ((estimatedMinutes / 240) * 100).clamp(0, 100).toDouble();

    final score = deadlineScore * 0.40 +
        remainingScore * 0.25 +
        importance * 0.20 +
        workloadScore * 0.15;

    return score.round().clamp(0, 100);
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'category': category,
      'deadline': deadline.toIso8601String(),
      'estimatedMinutes': estimatedMinutes,
      'importance': importance,
      'description': description,
      'progress': progress,
      'completed': completed,
    };
  }

  static Task fromJson(Map<String, dynamic> json) {
    return Task(
      id: json['id'] as String,
      title: json['title'] as String,
      category: json['category'] as String,
      deadline: DateTime.parse(json['deadline'] as String),
      estimatedMinutes: (json['estimatedMinutes'] as num).toInt(),
      importance: (json['importance'] as num).toInt(),
      description: json['description'] as String? ?? '',
      progress: (json['progress'] as num?)?.toInt() ?? 0,
      completed: json['completed'] as bool? ?? false,
    );
  }
}

// ============================================================
// TASK STORE
// ============================================================

class TaskStore extends ChangeNotifier {
  static const String _key = 'smart_deadline_tasks';

  List<Task> tasks = [];
  bool loading = true;

  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      final raw = prefs.getString(_key);

      if (raw == null || raw.isEmpty) {
        tasks = _demoTasks();
      } else {
        try {
          final decoded = jsonDecode(raw);

          if (decoded is List) {
            tasks = decoded
                .map(
                  (item) => Task.fromJson(
                    Map<String, dynamic>.from(item),
                  ),
                )
                .toList();
          } else {
            tasks = _demoTasks();
          }
        } catch (_) {
          tasks = _demoTasks();
        }
      }
    } catch (_) {
      tasks = _demoTasks();
    }

    loading = false;
    notifyListeners();
  }

  Future<void> save() async {
    final prefs = await SharedPreferences.getInstance();

    final data = tasks.map((task) => task.toJson()).toList();

    await prefs.setString(
      _key,
      jsonEncode(data),
    );
  }

  Future<void> add(Task task) async {
    tasks.add(task);
    await save();
    notifyListeners();
  }

  Future<void> update(Task task) async {
    final index = tasks.indexWhere((item) => item.id == task.id);

    if (index != -1) {
      tasks[index] = task;
      await save();
      notifyListeners();
    }
  }

  Future<void> remove(String id) async {
    tasks.removeWhere((task) => task.id == id);

    await save();
    notifyListeners();
  }

  List<Task> _demoTasks() {
    final now = DateTime.now();

    return [
      Task(
        id: 'demo-1',
        title: 'Digital Electronics Assignment',
        category: 'Academic',
        deadline: now.add(
          const Duration(days: 1, hours: 5),
        ),
        estimatedMinutes: 240,
        importance: 100,
        progress: 70,
        description:
            'Finish Boolean simplification, K-map and final formatting.',
      ),
      Task(
        id: 'demo-2',
        title: 'Communication Lab Report',
        category: 'Academic',
        deadline: now.add(
          const Duration(days: 3),
        ),
        estimatedMinutes: 180,
        importance: 80,
        progress: 35,
        description:
            'Complete theory, calculations, discussion and conclusion.',
      ),
      Task(
        id: 'demo-3',
        title: 'Mathematics Homework',
        category: 'Academic',
        deadline: now.add(
          const Duration(days: 6),
        ),
        estimatedMinutes: 120,
        importance: 60,
        progress: 90,
        description: 'Finish the remaining mathematical problems.',
      ),
    ];
  }
}

// ============================================================
// HOME SHELL
// ============================================================

class HomeShell extends StatefulWidget {
  const HomeShell({
    super.key,
    required this.onDarkModeChanged,
  });

  final ValueChanged<bool> onDarkModeChanged;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  final TaskStore store = TaskStore();

  int index = 0;

  @override
  void initState() {
    super.initState();
    store.load();
  }

  @override
  void dispose() {
    store.dispose();
    super.dispose();
  }

  Future<void> addTask() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddTaskPage(
          store: store,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: store,
      builder: (context, _) {
        final pages = [
          DashboardPage(
            store: store,
            onGoToTasks: () {
              setState(() {
                index = 1;
              });
            },
          ),
          TasksPage(store: store),
          PlanPage(store: store),
          StatsPage(store: store),
        ];

        return Scaffold(
          body: SafeArea(
            child: pages[index],
          ),
          floatingActionButton: index == 0 || index == 1
              ? FloatingActionButton.extended(
                  onPressed: addTask,
                  icon: const Icon(Icons.add),
                  label: const Text('Add Task'),
                )
              : null,
          bottomNavigationBar: NavigationBar(
            selectedIndex: index,
            onDestinationSelected: (value) {
              setState(() {
                index = value;
              });
            },
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.home_outlined),
                selectedIcon: Icon(Icons.home),
                label: 'Home',
              ),
              NavigationDestination(
                icon: Icon(Icons.checklist_outlined),
                selectedIcon: Icon(Icons.checklist),
                label: 'Tasks',
              ),
              NavigationDestination(
                icon: Icon(Icons.calendar_month_outlined),
                selectedIcon: Icon(Icons.calendar_month),
                label: 'Plan',
              ),
              NavigationDestination(
                icon: Icon(Icons.bar_chart_outlined),
                selectedIcon: Icon(Icons.bar_chart),
                label: 'Stats',
              ),
            ],
          ),
        );
      },
    );
  }
}

// ============================================================
// HELPERS
// ============================================================

String formatDate(DateTime date) {
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  final hour = date.hour % 12 == 0 ? 12 : date.hour % 12;

  final minute = date.minute.toString().padLeft(2, '0');

  final period = date.hour >= 12 ? 'PM' : 'AM';

  return '${months[date.month - 1]} '
      '${date.day}, ${date.year} · '
      '$hour:$minute $period';
}

String remainingLabel(Task task) {
  if (task.completed) {
    return 'Completed';
  }

  final diff = task.deadline.difference(DateTime.now());

  if (diff.isNegative || diff.inSeconds <= 0) {
    return 'Overdue';
  }

  final days = diff.inDays;
  final hours = diff.inHours % 24;
  final minutes = diff.inMinutes % 60;
  final seconds = diff.inSeconds % 60;

  return '${days}d ${hours}h ${minutes}m ${seconds}s';
}

Color priorityColor(
  BuildContext context,
  int score,
) {
  if (score >= 80) {
    return Theme.of(context).colorScheme.error;
  }

  if (score >= 60) {
    return Colors.orange;
  }

  return Colors.green;
}

// ============================================================
// DASHBOARD
// ============================================================

class DashboardPage extends StatelessWidget {
  const DashboardPage({
    super.key,
    required this.store,
    required this.onGoToTasks,
  });

  final TaskStore store;
  final VoidCallback onGoToTasks;

  @override
  Widget build(BuildContext context) {
    if (store.loading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    final now = DateTime.now();

    final active = store.tasks.where((task) => !task.completed).toList();

    active.sort(
      (a, b) => b.priorityScore(now).compareTo(a.priorityScore(now)),
    );

    final focus = active.isEmpty ? null : active.first;

    final completed = store.tasks.where((t) => t.completed).length;

    final total = store.tasks.length;

    final progress = total == 0 ? 0.0 : completed / total;

    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
          sliver: SliverToBoxAdapter(
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Good ${now.hour < 12 ? 'morning' : now.hour < 18 ? 'afternoon' : 'evening'} 👋',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Let’s get things done.',
                        style:
                            Theme.of(context).textTheme.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.w800,
                                ),
                      ),
                    ],
                  ),
                ),
                CircleAvatar(
                  radius: 24,
                  backgroundColor:
                      Theme.of(context).colorScheme.primaryContainer,
                  child: Icon(
                    Icons.person,
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                  ),
                ),
              ],
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
          sliver: SliverToBoxAdapter(
            child: Card(
              color: Theme.of(context).colorScheme.primary,
              child: Padding(
                padding: const EdgeInsets.all(22),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Today’s Progress',
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.onPrimary,
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            '$completed of $total tasks completed',
                            style: TextStyle(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onPrimary
                                  .withValues(alpha: .85),
                            ),
                          ),
                          const SizedBox(height: 14),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(20),
                            child: LinearProgressIndicator(
                              value: progress,
                              minHeight: 10,
                              backgroundColor: Theme.of(context)
                                  .colorScheme
                                  .onPrimary
                                  .withValues(
                                    alpha: .20,
                                  ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 20),
                    SizedBox(
                      width: 78,
                      height: 78,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          CircularProgressIndicator(
                            value: progress,
                            strokeWidth: 7,
                            backgroundColor: Theme.of(context)
                                .colorScheme
                                .onPrimary
                                .withValues(
                                  alpha: .20,
                                ),
                            valueColor: AlwaysStoppedAnimation(
                              Theme.of(context).colorScheme.onPrimary,
                            ),
                          ),
                          Text(
                            '${(progress * 100).round()}%',
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.onPrimary,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        if (focus != null)
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 22, 20, 0),
            sliver: SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Focus now',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  const SizedBox(height: 10),
                  TaskCard(
                    task: focus,
                    store: store,
                    highlighted: true,
                  ),
                ],
              ),
            ),
          ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 18),
          sliver: SliverToBoxAdapter(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Upcoming deadlines',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
                TextButton(
                  onPressed: onGoToTasks,
                  child: const Text('See all'),
                ),
              ],
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          sliver: SliverList.separated(
            itemCount: active.take(3).length,
            itemBuilder: (context, i) {
              return TaskCard(
                task: active[i],
                store: store,
              );
            },
            separatorBuilder: (_, __) => const SizedBox(height: 12),
          ),
        ),
        const SliverToBoxAdapter(
          child: SizedBox(height: 90),
        ),
      ],
    );
  }
}

// ============================================================
// TASK CARD
// ============================================================

class TaskCard extends StatefulWidget {
  const TaskCard({
    super.key,
    required this.task,
    required this.store,
    this.highlighted = false,
  });

  final Task task;
  final TaskStore store;
  final bool highlighted;

  @override
  State<TaskCard> createState() => _TaskCardState();
}

class _TaskCardState extends State<TaskCard> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final task = widget.task;
    final store = widget.store;
    final highlighted = widget.highlighted;
    final score = task.priorityScore(DateTime.now());

    final color = priorityColor(context, score);

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => TaskDetailsPage(
                task: task,
                store: store,
              ),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: .10),
                      borderRadius: BorderRadius.circular(50),
                    ),
                    child: Text(
                      score >= 80
                          ? 'HIGH PRIORITY'
                          : score >= 60
                              ? 'MEDIUM'
                              : 'NORMAL',
                      style: TextStyle(
                        color: color,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    remainingLabel(task),
                    style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                task.title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: 5),
              Text(
                task.category,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 14),
              ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: LinearProgressIndicator(
                  value: task.progress / 100,
                  minHeight: 8,
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Text(
                    '${task.progress}% complete',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const Spacer(),
                  Text(
                    '${task.remainingMinutes ~/ 60}h '
                    '${task.remainingMinutes % 60}m remaining',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
              if (highlighted) ...[
                const SizedBox(height: 14),
                FilledButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => FocusPage(
                          task: task,
                          store: store,
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('Start Focus'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================
// TASKS PAGE
// ============================================================

class TasksPage extends StatefulWidget {
  const TasksPage({
    super.key,
    required this.store,
  });

  final TaskStore store;

  @override
  State<TasksPage> createState() => _TasksPageState();
}

class _TasksPageState extends State<TasksPage> {
  String filter = 'All';
  String query = '';

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();

    final list = widget.store.tasks.where((task) {
      final matchesQuery = query.trim().isEmpty ||
          task.title.toLowerCase().contains(query.trim().toLowerCase());

      bool matchesFilter;

      switch (filter) {
        case 'Today':
          matchesFilter = !task.completed &&
              task.deadline.year == now.year &&
              task.deadline.month == now.month &&
              task.deadline.day == now.day;
          break;

        case 'Upcoming':
          matchesFilter = !task.completed && task.deadline.isAfter(now);
          break;

        case 'Done':
          matchesFilter = task.completed;
          break;

        default:
          matchesFilter = true;
      }

      return matchesQuery && matchesFilter;
    }).toList();

    list.sort(
      (a, b) => b.priorityScore(now).compareTo(a.priorityScore(now)),
    );

    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 10),
          sliver: SliverToBoxAdapter(
            child: Text(
              'Your tasks',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          sliver: SliverToBoxAdapter(
            child: TextField(
              onChanged: (value) {
                setState(() {
                  query = value;
                });
              },
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Search tasks...',
              ),
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
          sliver: SliverToBoxAdapter(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  'All',
                  'Today',
                  'Upcoming',
                  'Done',
                ].map((item) {
                  return Padding(
                    padding: const EdgeInsets.only(
                      right: 8,
                    ),
                    child: ChoiceChip(
                      label: Text(item),
                      selected: filter == item,
                      onSelected: (_) {
                        setState(() {
                          filter = item;
                        });
                      },
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
        ),
        if (list.isEmpty)
          const SliverFillRemaining(
            hasScrollBody: false,
            child: EmptyState(),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(
              20,
              0,
              20,
              90,
            ),
            sliver: SliverList.separated(
              itemCount: list.length,
              itemBuilder: (context, i) {
                final task = list[i];

                return Dismissible(
                  key: ValueKey(task.id),
                  direction: DismissDirection.horizontal,
                  background: Container(
                    alignment: Alignment.centerLeft,
                    padding: const EdgeInsets.only(
                      left: 24,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.green.withValues(alpha: .15),
                      borderRadius: BorderRadius.circular(22),
                    ),
                    child: Icon(
                      Icons.check_circle,
                      color: Colors.green.shade700,
                      size: 30,
                    ),
                  ),
                  secondaryBackground: Container(
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(
                      right: 24,
                    ),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.errorContainer,
                      borderRadius: BorderRadius.circular(22),
                    ),
                    child: Icon(
                      Icons.delete,
                      color: Theme.of(context).colorScheme.onErrorContainer,
                    ),
                  ),
                  confirmDismiss: (direction) async {
                    if (direction == DismissDirection.startToEnd) {
                      if (!task.completed) {
                        task.progress = 100;
                        task.completed = true;
                        await widget.store.update(task);
                      }
                      return true;
                    }

                    return await showDialog<bool>(
                          context: context,
                          builder: (ctx) {
                            return AlertDialog(
                              title: const Text(
                                'Delete task?',
                              ),
                              content: const Text(
                                'This action cannot be undone.',
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () {
                                    Navigator.pop(
                                      ctx,
                                      false,
                                    );
                                  },
                                  child: const Text(
                                    'Cancel',
                                  ),
                                ),
                                FilledButton(
                                  onPressed: () {
                                    Navigator.pop(
                                      ctx,
                                      true,
                                    );
                                  },
                                  child: const Text(
                                    'Delete',
                                  ),
                                ),
                              ],
                            );
                          },
                        ) ??
                        false;
                  },
                  onDismissed: (direction) {
                    if (direction == DismissDirection.startToEnd) {
                      return;
                    }
                    widget.store.remove(task.id);
                  },
                  child: TaskCard(
                    task: task,
                    store: widget.store,
                  ),
                );
              },
              separatorBuilder: (_, __) => const SizedBox(height: 12),
            ),
          ),
      ],
    );
  }
}

// ============================================================
// EMPTY STATE
// ============================================================

class EmptyState extends StatelessWidget {
  const EmptyState({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(30),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.check_circle_outline,
              size: 72,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 18),
            Text(
              'All clear!',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 8),
            const Text(
              'No tasks match this view right now.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// ADD TASK PAGE
// ============================================================

class AddTaskPage extends StatefulWidget {
  const AddTaskPage({
    super.key,
    required this.store,
  });

  final TaskStore store;

  @override
  State<AddTaskPage> createState() => _AddTaskPageState();
}

class _AddTaskPageState extends State<AddTaskPage> {
  final titleController = TextEditingController();

  final descriptionController = TextEditingController();

  final hoursController = TextEditingController(text: '2');

  String category = 'Academic';

  int importance = 80;

  int progress = 0;

  DateTime? deadline;

  Future<void> pickDeadline() async {
    final now = DateTime.now();

    final day = await showDatePicker(
      context: context,
      firstDate: DateTime(
        now.year,
        now.month,
        now.day,
      ),
      lastDate: DateTime(now.year + 3),
      initialDate: now.add(
        const Duration(days: 2),
      ),
    );

    if (day == null || !mounted) {
      return;
    }

    final time = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(
        hour: 23,
        minute: 59,
      ),
    );

    if (time == null || !mounted) {
      return;
    }

    final selected = DateTime(
      day.year,
      day.month,
      day.day,
      time.hour,
      time.minute,
    );

    if (selected.isBefore(now)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Please choose a future deadline.',
          ),
        ),
      );
      return;
    }

    setState(() {
      deadline = selected;
    });
  }

  Future<void> save() async {
    final title = titleController.text.trim();

    if (title.isEmpty || deadline == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Please enter a title and deadline.',
          ),
        ),
      );
      return;
    }

    final hours = double.tryParse(
          hoursController.text.trim(),
        ) ??
        2;

    if (hours <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Estimated time must be greater than 0.',
          ),
        ),
      );
      return;
    }

    final task = Task(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      title: title,
      description: descriptionController.text.trim(),
      category: category,
      deadline: deadline!,
      estimatedMinutes: (hours * 60).round(),
      importance: importance,
      progress: progress,
      completed: progress == 100,
    );

    await widget.store.add(task);

    if (mounted) {
      Navigator.pop(context);
    }
  }

  @override
  void dispose() {
    titleController.dispose();
    descriptionController.dispose();
    hoursController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('New Task'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          20,
          10,
          20,
          30,
        ),
        children: [
          Text(
            'Create something you need to finish.',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: 22),
          TextField(
            controller: titleController,
            decoration: const InputDecoration(
              labelText: 'Task name',
              hintText: 'e.g. Digital Electronics Assignment',
            ),
          ),
          const SizedBox(height: 14),
          DropdownButtonFormField<String>(
            initialValue: category,
            decoration: const InputDecoration(
              labelText: 'Category',
            ),
            items: const [
              DropdownMenuItem(
                value: 'Academic',
                child: Text('Academic'),
              ),
              DropdownMenuItem(
                value: 'Work',
                child: Text('Work'),
              ),
              DropdownMenuItem(
                value: 'Personal',
                child: Text('Personal'),
              ),
              DropdownMenuItem(
                value: 'Project',
                child: Text('Project'),
              ),
            ],
            onChanged: (value) {
              setState(() {
                category = value ?? 'Academic';
              });
            },
          ),
          const SizedBox(height: 14),
          InkWell(
            onTap: pickDeadline,
            borderRadius: BorderRadius.circular(16),
            child: InputDecorator(
              decoration: const InputDecoration(
                labelText: 'Deadline',
                prefixIcon: Icon(Icons.event),
              ),
              child: Text(
                deadline == null
                    ? 'Choose date and time'
                    : formatDate(
                        deadline!,
                      ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: hoursController,
            keyboardType: const TextInputType.numberWithOptions(
              decimal: true,
            ),
            decoration: const InputDecoration(
              labelText: 'Estimated time (hours)',
            ),
          ),
          const SizedBox(height: 18),
          Text(
            'Importance',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 8),
          SegmentedButton<int>(
            segments: const [
              ButtonSegment(
                value: 30,
                label: Text('Low'),
              ),
              ButtonSegment(
                value: 60,
                label: Text('Medium'),
              ),
              ButtonSegment(
                value: 100,
                label: Text('High'),
              ),
            ],
            selected: {
              importance,
            },
            onSelectionChanged: (selection) {
              setState(() {
                importance = selection.first;
              });
            },
          ),
          const SizedBox(height: 20),
          Text(
            'Current progress: $progress%',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          Slider(
            value: progress.toDouble(),
            min: 0,
            max: 100,
            divisions: 20,
            label: '$progress%',
            onChanged: (value) {
              setState(() {
                progress = value.round();
              });
            },
          ),
          const SizedBox(height: 10),
          TextField(
            controller: descriptionController,
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: 'Description',
              hintText: 'Optional notes...',
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 52,
            child: FilledButton.icon(
              onPressed: save,
              icon: const Icon(Icons.check),
              label: const Text(
                'Create Task',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// TASK DETAILS
// ============================================================

class TaskDetailsPage extends StatefulWidget {
  const TaskDetailsPage({
    super.key,
    required this.task,
    required this.store,
  });

  final Task task;
  final TaskStore store;

  @override
  State<TaskDetailsPage> createState() => _TaskDetailsPageState();
}

class _TaskDetailsPageState extends State<TaskDetailsPage> {
  Future<void> toggleComplete() async {
    widget.task.completed = !widget.task.completed;

    if (widget.task.completed) {
      widget.task.progress = 100;
    } else if (widget.task.progress == 100) {
      widget.task.progress = 0;
    }

    await widget.store.update(widget.task);

    if (mounted) {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final task = widget.task;

    final score = task.priorityScore(
      DateTime.now(),
    );

    final color = priorityColor(
      context,
      score,
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Task Details'),
        actions: [
          IconButton(
            tooltip: task.completed ? 'Mark incomplete' : 'Mark complete',
            onPressed: toggleComplete,
            icon: Icon(
              task.completed ? Icons.undo : Icons.check_circle_outline,
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          20,
          8,
          20,
          30,
        ),
        children: [
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 10,
              vertical: 7,
            ),
            decoration: BoxDecoration(
              color: color.withValues(
                alpha: .10,
              ),
              borderRadius: BorderRadius.circular(
                50,
              ),
            ),
            child: Text(
              score >= 80
                  ? 'HIGH PRIORITY'
                  : score >= 60
                      ? 'MEDIUM PRIORITY'
                      : 'NORMAL',
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w800,
                fontSize: 12,
              ),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            task.title,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 8),
          Text(task.category),
          const SizedBox(height: 22),
          InfoTile(
            icon: Icons.event,
            title: 'Deadline',
            value: formatDate(
              task.deadline,
            ),
          ),
          const SizedBox(height: 10),
          InfoTile(
            icon: Icons.timer_outlined,
            title: 'Estimated',
            value: '${task.estimatedMinutes ~/ 60}h '
                '${task.estimatedMinutes % 60}m',
          ),
          const SizedBox(height: 10),
          InfoTile(
            icon: Icons.speed,
            title: 'Priority score',
            value: '$score / 100',
          ),
          const SizedBox(height: 20),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Progress',
                    style: Theme.of(
                      context,
                    ).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  const SizedBox(height: 12),
                  LinearProgressIndicator(
                    value: task.progress / 100,
                    minHeight: 10,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    '${task.progress}% complete · '
                    '${task.remainingMinutes} minutes remaining',
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Why this is important',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    task.deadline
                                .difference(
                                  DateTime.now(),
                                )
                                .inHours <=
                            48
                        ? '• Deadline is close'
                        : '• There is still useful planning time remaining',
                  ),
                  Text(
                    task.progress < 50
                        ? '• A large amount of work remains'
                        : '• You have already made good progress',
                  ),
                  Text(
                    task.importance >= 80
                        ? '• Marked as highly important'
                        : '• Importance level is moderate',
                  ),
                ],
              ),
            ),
          ),
          if (task.description.isNotEmpty) ...[
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Notes',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      task.description,
                    ),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => FocusPage(
                    task: task,
                    store: widget.store,
                  ),
                ),
              );
            },
            icon: const Icon(Icons.play_arrow),
            label: const Text(
              'Start Focus Session',
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// INFO TILE
// ============================================================

class InfoTile extends StatelessWidget {
  const InfoTile({
    super.key,
    required this.icon,
    required this.title,
    required this.value,
  });

  final IconData icon;
  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Theme.of(context).colorScheme.primaryContainer,
          child: Icon(icon),
        ),
        title: Text(title),
        subtitle: Text(
          value,
          style: const TextStyle(
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

// ============================================================
// PLAN PAGE
// ============================================================

class PlanPage extends StatefulWidget {
  const PlanPage({
    super.key,
    required this.store,
  });

  final TaskStore store;

  @override
  State<PlanPage> createState() => _PlanPageState();
}

class _PlanPageState extends State<PlanPage> {
  int regeneration = 0;

  void regenerate() {
    setState(() {
      regeneration++;
    });
  }

  @override
  Widget build(BuildContext context) {
    final active = widget.store.tasks.where((task) => !task.completed).toList();

    active.sort(
      (a, b) => b.priorityScore(DateTime.now()).compareTo(
            a.priorityScore(
              DateTime.now(),
            ),
          ),
    );

    var cursor = 18 * 60;
    const end = 22 * 60;

    final blocks = <Widget>[];

    for (final task in active.take(4)) {
      if (cursor >= end) {
        break;
      }

      final available = end - cursor;

      final duration = task.remainingMinutes.clamp(25, 90);

      final used = duration > available ? available : duration;

      if (used <= 0) {
        break;
      }

      final start = cursor;
      final finish = cursor + used;

      blocks.add(
        PlanBlock(
          task: task,
          start: start,
          finish: finish,
        ),
      );

      cursor = finish + 15;

      if (cursor < end) {
        blocks.add(
          BreakBlock(
            key: ValueKey(
              '${task.id}-$regeneration',
            ),
          ),
        );
      }
    }

    return ListView(
      key: ValueKey(regeneration),
      padding: const EdgeInsets.fromLTRB(
        20,
        16,
        20,
        40,
      ),
      children: [
        Text(
          'Today’s smart plan',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
              ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Prioritized from deadline, remaining work and importance.',
        ),
        const SizedBox(height: 20),
        if (blocks.isEmpty) const EmptyState() else ...blocks,
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: regenerate,
          icon: const Icon(Icons.refresh),
          label: const Text(
            'Regenerate plan',
          ),
        ),
      ],
    );
  }
}

// ============================================================
// PLAN BLOCK
// ============================================================

class PlanBlock extends StatelessWidget {
  const PlanBlock({
    super.key,
    required this.task,
    required this.start,
    required this.finish,
  });

  final Task task;
  final int start;
  final int finish;

  String tm(int minutes) {
    final h24 = minutes ~/ 60;

    final m = minutes % 60;

    final h = h24 % 12 == 0 ? 12 : h24 % 12;

    final period = h24 >= 12 ? 'PM' : 'AM';

    return '$h:${m.toString().padLeft(2, '0')} $period';
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(
        bottom: 12,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 74,
            child: Text(
              tm(start),
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
          ),
          Expanded(
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${tm(start)} – ${tm(finish)}',
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                    const SizedBox(height: 5),
                    Text(
                      task.title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(task.category),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// BREAK BLOCK
// ============================================================

class BreakBlock extends StatelessWidget {
  const BreakBlock({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.only(
        left: 74,
        bottom: 12,
      ),
      child: Row(
        children: [
          Icon(
            Icons.coffee,
            size: 17,
          ),
          SizedBox(width: 7),
          Text('15 min break'),
        ],
      ),
    );
  }
}

// ============================================================
// STATS PAGE
// ============================================================

class StatsPage extends StatelessWidget {
  const StatsPage({
    super.key,
    required this.store,
  });

  final TaskStore store;

  @override
  Widget build(BuildContext context) {
    final total = store.tasks.length;

    final completed = store.tasks
        .where(
          (task) => task.completed,
        )
        .length;

    final overdue = store.tasks
        .where(
          (task) =>
              !task.completed &&
              task.deadline.isBefore(
                DateTime.now(),
              ),
        )
        .length;

    final rate = total == 0 ? 0 : ((completed / total) * 100).round();

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        20,
        16,
        20,
        40,
      ),
      children: [
        Text(
          'Your statistics',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
              ),
        ),
        const SizedBox(height: 18),
        Row(
          children: [
            Expanded(
              child: StatCard(
                value: '$completed',
                label: 'Completed',
                icon: Icons.check_circle,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: StatCard(
                value: '$overdue',
                label: 'Overdue',
                icon: Icons.warning_amber_rounded,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: StatCard(
                value: '$rate%',
                label: 'Completion rate',
                icon: Icons.trending_up,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: StatCard(
                value: '$total',
                label: 'Total tasks',
                icon: Icons.checklist,
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Productivity score',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 18),
                Text(
                  '$rate',
                  style: Theme.of(context).textTheme.displaySmall?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  rate >= 80
                      ? 'Excellent'
                      : rate >= 50
                          ? 'Good progress'
                          : 'Room to improve',
                ),
                const SizedBox(height: 16),
                LinearProgressIndicator(
                  value: rate / 100,
                  minHeight: 10,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ============================================================
// STAT CARD
// ============================================================

class StatCard extends StatelessWidget {
  const StatCard({
    super.key,
    required this.value,
    required this.label,
    required this.icon,
  });

  final String value;
  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              icon,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 14),
            Text(
              value,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
            ),
            const SizedBox(height: 4),
            Text(label),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// FOCUS PAGE
// ============================================================

class FocusPage extends StatefulWidget {
  const FocusPage({
    super.key,
    required this.task,
    required this.store,
  });

  final Task task;
  final TaskStore store;

  @override
  State<FocusPage> createState() => _FocusPageState();
}

class _FocusPageState extends State<FocusPage> {
  static const int sessionLength = 25 * 60;

  int seconds = sessionLength;

  bool running = true;

  Timer? timer;

  @override
  void initState() {
    super.initState();
    startTimer();
  }

  void startTimer() {
    timer?.cancel();

    timer = Timer.periodic(
      const Duration(seconds: 1),
      (_) {
        if (!mounted) {
          return;
        }

        if (!running) {
          return;
        }

        if (seconds > 0) {
          setState(() {
            seconds--;
          });
        }

        if (seconds == 0) {
          setState(() {
            running = false;
          });

          timer?.cancel();

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Focus session completed! 🎉',
              ),
            ),
          );
        }
      },
    );
  }

  void toggleTimer() {
    setState(() {
      running = !running;
    });

    if (running) {
      startTimer();
    }
  }

  Future<void> endSession() async {
    timer?.cancel();

    if (mounted) {
      Navigator.pop(context);
    }
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final minutes = seconds ~/ 60;

    final remainingSeconds = seconds % 60;

    final progress = seconds / sessionLength;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Focus Mode'),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                widget.task.title,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Stay focused. One task at a time.',
              ),
              const SizedBox(height: 44),
              SizedBox(
                width: 230,
                height: 230,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    CircularProgressIndicator(
                      value: progress,
                      strokeWidth: 13,
                    ),
                    Text(
                      '$minutes:'
                      '${remainingSeconds.toString().padLeft(2, '0')}',
                      style: Theme.of(context).textTheme.displaySmall?.copyWith(
                            fontWeight: FontWeight.w900,
                          ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 40),
              FilledButton.icon(
                onPressed: toggleTimer,
                icon: Icon(
                  running ? Icons.pause : Icons.play_arrow,
                ),
                label: Text(
                  running ? 'Pause' : 'Resume',
                ),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: endSession,
                child: const Text(
                  'End session',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
