import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app_themes.dart';
import 'database/database_helper.dart';
import 'db_ffi.dart';
import 'platform_info.dart';
import 'models/task.dart';
import 'notification_service.dart';
import 'theme_controller.dart';
import 'widgets/alarm_dialog.dart';
import 'widgets/home_header.dart';
import 'widgets/settings_page.dart';
import 'widgets/task_form_dialog.dart';
import 'widgets/task_tile.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (!isAndroid && !isIOS) {
    // En web es no-op (ver db_ffi_stub.dart).
    initDatabaseFactory();
  }
  try {
    await NotificationService.instance.init();
  } catch (e) {
    debugPrint('[main] Error inicializando notificaciones: $e');
  }
  final themeController = await ThemeController.load();
  runApp(TaskFlowApp(themeController: themeController));
}

class TaskFlowApp extends StatefulWidget {
  final ThemeController themeController;

  TaskFlowApp({super.key, ThemeController? themeController})
      : themeController = themeController ?? ThemeController();

  @override
  State<TaskFlowApp> createState() => _TaskFlowAppState();
}

class _TaskFlowAppState extends State<TaskFlowApp> {
  @override
  void initState() {
    super.initState();
    widget.themeController.startAutoRefresh();
  }

  @override
  void dispose() {
    widget.themeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.themeController,
      builder: (context, _) {
        return MaterialApp(
          navigatorKey: navigatorKey,
          debugShowCheckedModeBanner: false,
          title: 'TaskFlow',
          theme: appThemeOf(widget.themeController.current).data,
          home: HomePage(themeController: widget.themeController),
        );
      },
    );
  }
}

class HomePage extends StatefulWidget {
  final ThemeController themeController;

  const HomePage({super.key, required this.themeController});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with WidgetsBindingObserver {
  final DatabaseHelper _db = DatabaseHelper.instance;

  List<Task> _tasks = [];
  bool _isLoading = true;
  bool _alarmDialogOpen = false;
  bool _overlayDialogOpen = false;
  bool _overlayGranted = true;
  int? _filterWeekday;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadTasks();
    _checkPermissionsAndAlarm();
    _setupAlarmListener();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _onAppResumed();
    }
  }

  Future<void> _onAppResumed() async {
    try {
      widget.themeController.refresh();
      _overlayGranted = await NotificationService.instance.canDrawOverlays();
      await _checkLaunchPayload();
      await _applyPendingAlarmActions();
    } catch (e) {
      debugPrint('[HomePage] Error al reanudar la app: $e');
    }
  }

  Future<void> _rescheduleAllTasks() async {
    try {
      final tasks = await _db.getTasks();
      for (final task in tasks) {
        if (task.id == null) continue;
        // Solo las detenidas (no se repiten o con stopOnComplete) pierden sus
        // alarmas. Una repetitiva sin stop completada solo marcó la ocurrencia
        // (completedAt) y sus futuras alarmas siguen activas.
        if (task.isStopped) {
          await NotificationService.instance.cancelTask(task.id!);
        } else {
          // Con posposición activa no se toca nada: ni re-agendar ni cancelar.
          final snooze = await NotificationService.instance.snoozeDeadline(task.id!);
          if (snooze != null) {
            debugPrint('[HomePage] Tarea ${task.id} con snooze activo, omitiendo re-agendado');
            continue;
          }
          await NotificationService.instance.scheduleTask(task);
        }
      }
      debugPrint('[HomePage] Re-agendadas ${tasks.length} tareas');
    } catch (e) {
      debugPrint('[HomePage] Error re-agendando tareas: $e');
    }
  }

  Future<void> _checkPermissionsAndAlarm() async {
    try {
      final hasPermission = await NotificationService.instance.checkPermissions();
      debugPrint('[HomePage] Permisos concedidos: $hasPermission');

      if (!hasPermission && isAndroid) {
        if (!mounted) return;
        _showPermissionDialog();
      }

      await _ensureOverlayPermission();
      await _ensureBatteryOptimization();
      _overlayGranted = await NotificationService.instance.canDrawOverlays();
      await AlarmDialog.clearStaleSnoozeCounts();
      await _checkLaunchPayload();
      await _applyPendingAlarmActions();
      await _checkInitialAlarm();
      await _rescheduleAllTasks();
    } catch (e) {
      debugPrint('[HomePage] Error verificando permisos: $e');
    }
  }

  Future<void> _ensureOverlayPermission() async {
    if (!isAndroid) return;

    try {
      final can = await NotificationService.instance.canDrawOverlays();
      debugPrint('[HomePage] Permiso de overlay: $can');
      if (can) return;

      final prefs = await SharedPreferences.getInstance();
      final alreadyAsked = prefs.getBool('overlay_permission_asked') ?? false;
      if (alreadyAsked) return;

      await prefs.setBool('overlay_permission_asked', true);

      if (_overlayDialogOpen || !mounted) return;

      _overlayDialogOpen = true;
      final go = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => AlertDialog(
          icon: const Icon(Icons.open_in_full, size: 48, color: Colors.indigo),
          title: const Text('Modo alarma intrusivo'),
          content: const Text(
            'Para que la tarea aparezca en pantalla completa interrumpiendo la app que estés usando '
            '(Instagram, redes, juegos...), TaskFlow necesita el permiso "Mostrar sobre otras apps".\n\n'
            'Serás llevado a los ajustes. Busca TaskFlow y activa el interruptor.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Ahora no'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Configurar ahora'),
            ),
          ],
        ),
      );

      if (go == true && mounted) {
        await NotificationService.instance.openOverlaySettings();
      }
      _overlayDialogOpen = false;
    } catch (e) {
      _overlayDialogOpen = false;
      debugPrint('[HomePage] Error pidiendo permiso de overlay: $e');
    }
  }

  Future<void> _ensureBatteryOptimization() async {
    if (!isAndroid) return;
    try {
      final ignoring = await NotificationService.instance.isIgnoringBatteryOptimizations();
      debugPrint('[HomePage] Optimización de batería ignorada: $ignoring');
      if (ignoring) return;

      final prefs = await SharedPreferences.getInstance();
      final alreadyAsked = prefs.getBool('battery_optimization_asked') ?? false;
      if (alreadyAsked) return;

      await prefs.setBool('battery_optimization_asked', true);

      if (_overlayDialogOpen || !mounted) return;
      showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          icon: const Icon(Icons.battery_alert, size: 48, color: Colors.orange),
          title: const Text('Modo alarmas en segundo plano'),
          content: const Text(
            'Para que TaskFlow te despierte aunque la app esté cerrada o el teléfono optimice la batería, '
            'desactiva la optimización de energía para TaskFlow.\n\n'
            'Serás llevado a ajustes de batería: selecciona TaskFlow y marca "Sin restricciones".',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Ahora no'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(dialogContext);
                NotificationService.instance.openBatteryOptimizationSettings();
              },
              child: const Text('Configurar ahora'),
            ),
          ],
        ),
      );
    } catch (e) {
      debugPrint('[HomePage] Error pidiendo exención de batería: $e');
    }
  }

  Future<void> _checkLaunchPayload() async {
    try {
      final payload = await NotificationService.instance.consumeLaunchPayload();
      if (payload == null) return;
      debugPrint('[HomePage] Payload de lanzamiento nativo: $payload');
      final data = jsonDecode(payload);
      if (data['type'] == 'alarm') {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _showAlarmDialog(data);
        });
      } else if (data['type'] == 'alarm_action') {
        final taskId = data['taskId'] as int? ?? -1;
        final weekday = data['weekday'] as int? ?? DateTime.now().weekday;
        final action = data['action'] as String? ?? '';
        if (action == 'completed') {
          await _completeTaskFromAlarm(taskId, weekday);
        } else if (action == 'snoozed') {
          await _snoozeTaskFromAlarm(taskId, weekday);
        }
      }
    } catch (e) {
      debugPrint('[HomePage] Error leyendo payload de lanzamiento: $e');
    }
  }

  void _showPermissionDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        icon: const Icon(Icons.notifications_off, size: 48, color: Colors.orange),
        title: const Text('Permisos de notificación'),
        content: const Text(
          'TaskFlow necesita permisos de notificación para enviarte alarmas de tus tareas. '
          'Sin estos permisos, las notificaciones no funcionarán.\n\n'
          'Por favor, otorga el permiso cuando Android te lo solicite.',
        ),
        actions: [
          FilledButton(
            onPressed: () async {
              Navigator.pop(context);
              await NotificationService.instance.checkPermissions();
            },
            child: const Text('Otorgar permiso'),
          ),
        ],
      ),
    );
  }

  Future<void> _checkInitialAlarm() async {
    final details = await NotificationService.instance.getLaunchDetails();
    if (details == null || details.notificationResponse == null) return;
    final payload = details.notificationResponse!.payload;
    if (payload == null) return;

    debugPrint('[HomePage] App abierta desde notificación: $payload');

    try {
      final data = jsonDecode(payload);
      if (data['type'] == 'alarm') {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _showAlarmDialog(data);
        });
      }
    } catch (_) {}
  }

  void _setupAlarmListener() {
    NotificationService.instance.onAlarmTriggered = (payload) {
      debugPrint('[HomePage] Alarma recibida: $payload');
      try {
        final data = jsonDecode(payload);
        if (data['type'] == 'alarm') {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _showAlarmDialog(data);
          });
        }
      } catch (_) {}
    };

    NotificationService.instance.onAlarmAction = (payload) {
      debugPrint('[HomePage] Acción de alarma: $payload');
      try {
        final data = jsonDecode(payload);
        if (data['type'] == 'alarm_action') {
          final taskId = data['taskId'] as int? ?? -1;
          final weekday = data['weekday'] as int? ?? DateTime.now().weekday;
          final action = data['action'] as String? ?? '';
          if (action == 'completed') {
            _completeTaskFromAlarm(taskId, weekday);
          } else if (action == 'snoozed') {
            _snoozeTaskFromAlarm(taskId, weekday);
          }
        }
      } catch (_) {}
    };
  }

  void _showAlarmDialog(Map<String, dynamic> data) {
    // En Android con overlay la única pantalla de alarma es la nativa
    // (AlarmActivity). Sin overlay, el diálogo es el respaldo (la notificación
    // usa fullScreenIntent y al tocarla solo se abre la app).
    if (isAndroid && _overlayGranted) return;
    final taskId = data['taskId'] as int? ?? -1;
    final taskTitle = data['title'] as String? ?? 'Tarea';
    final weekday = data['weekday'] as int? ?? DateTime.now().weekday;

    debugPrint('[HomePage] Mostrando dialogo de alarma: $taskTitle');

    if (_alarmDialogOpen) {
      debugPrint('[HomePage] Diálogo de alarma ya abierto, ignorando duplicado');
      return;
    }

    final ctx = navigatorKey.currentContext;
    if (ctx == null) {
      debugPrint('[HomePage] Contexto nulo, reintentando...');
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _showAlarmDialog(data);
      });
      return;
    }

    _alarmDialogOpen = true;
    showDialog(
      context: ctx,
      barrierDismissible: false,
      builder: (_) => AlarmDialog(
        taskId: taskId,
        taskTitle: taskTitle,
        weekday: weekday,
        onCompleted: () => _completeTaskFromAlarm(taskId, weekday),
        onSnoozed: () => _snoozeTaskFromAlarm(taskId, weekday),
      ),
    ).whenComplete(() async {
      _alarmDialogOpen = false;
      await NotificationService.instance.returnToPreviousApp();
    });
  }

  Future<void> _completeTaskFromAlarm(int taskId, int weekday) async {
    if (taskId <= 0) return;
    try {
      await NotificationService.instance.dismissBackupNotification(taskId, weekday);
      final tasks = await _db.getTasks();
      final task = tasks.firstWhere(
        (t) => t.id == taskId,
        orElse: () => throw Exception('Tarea no encontrada'),
      );
      await _applyCompletion(task, true);
    } catch (e) {
      debugPrint('[HomePage] Error completando tarea desde alarma: $e');
    }
  }

  Future<void> _applyCompletion(Task task, bool completed) async {
    // Repetitiva sin stopOnComplete: completar solo marca la ocurrencia actual
    // (fecha) y las alarmas futuras siguen activas.
    if (completed && !task.stopsOnComplete) {
      final updated = task.copyWith(
        completed: false,
        completedAt: DateTime.now().millisecondsSinceEpoch,
      );
      await _db.updateTask(updated);
      await NotificationService.instance.clearSnoozeDeadline(task.id!);
      await NotificationService.instance.scheduleTask(updated);
      await _loadTasks();
      return;
    }

    final updated = completed
        ? task.copyWith(completed: true, clearCompletedAt: true)
        : task.copyWith(completed: false, clearCompletedAt: true);
    await _db.updateTask(updated);

    if (completed) {
      await NotificationService.instance.clearSnoozeDeadline(task.id!);
      await NotificationService.instance.cancelTask(task.id!);
    } else {
      await NotificationService.instance.scheduleTask(updated);
    }
    await _loadTasks();
  }

  Future<void> _snoozeTaskFromAlarm(int taskId, int weekday, {int? triggerAtMillis}) async {
    if (taskId <= 0) return;
    try {
      await NotificationService.instance.dismissBackupNotification(taskId, weekday);
      final tasks = await _db.getTasks();
      final task = tasks.firstWhere(
        (t) => t.id == taskId,
        orElse: () => throw Exception('Tarea no encontrada'),
      );
      await NotificationService.instance.scheduleSnooze(task, weekday, triggerAtMillis: triggerAtMillis);
    } catch (e) {
      debugPrint('[HomePage] Error posponiendo tarea desde alarma: $e');
    }
  }

  /// Aplica en Dart las acciones que AlarmActivity ya aplicó en nativo.
  /// Un snooze vencido se ignora (ya sonó; la marca se autolimpia al leerla).
  Future<void> _applyPendingAlarmActions() async {
    try {
      final pending = await NotificationService.instance.consumePendingAlarmActions();
      if (pending.isEmpty) return;
      debugPrint('[HomePage] Acciones pendientes nativas: ${pending.length}');
      for (final item in pending) {
        final action = item['action'] as String? ?? '';
        final taskId = (item['taskId'] as num?)?.toInt() ?? -1;
        final weekday = (item['weekday'] as num?)?.toInt() ?? DateTime.now().weekday;
        final triggerAt = (item['triggerAt'] as num?)?.toInt() ?? 0;
        if (taskId <= 0) continue;
        if (action == 'completed') {
          await _completeTaskFromAlarm(taskId, weekday);
        } else if (action == 'snoozed') {
          if (NotificationService.isSnoozeTriggerFresh(
              triggerAt, DateTime.now().millisecondsSinceEpoch)) {
            await _snoozeTaskFromAlarm(taskId, weekday, triggerAtMillis: triggerAt);
          }
        }
      }
    } catch (e) {
      debugPrint('[HomePage] Error aplicando acciones pendientes: $e');
    }
  }

  Future<void> _loadTasks() async {
    setState(() => _isLoading = true);
    try {
      final tasks = await _db.getTasks();
      if (!mounted) return;
      setState(() {
        _tasks = tasks;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al cargar tareas: $e')),
      );
    }
  }

  Future<void> _openTaskDialog({Task? task}) async {
    final result = await showDialog<Task>(
      context: context,
      builder: (_) => TaskFormDialog(task: task),
    );
    if (result != null) {
      await _loadTasks();
    }
  }

  Future<void> _toggleTask(Task task) async {
    final newCompleted = !task.isEffectivelyCompleted(DateTime.now());

    try {
      await _applyCompletion(task, newCompleted);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al actualizar tarea: $e')),
      );
    }
  }

  Future<void> _deleteTask(Task task) async {
    if (task.id == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar tarea'),
        content: Text('¿Quieres eliminar "${task.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await _db.deleteTask(task.id!);
      await NotificationService.instance.cancelTask(task.id!);
      await _loadTasks();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tarea eliminada')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al eliminar tarea: $e')),
      );
    }
  }

  Future<void> _testNotification() async {
    debugPrint('[HomePage] Enviando notificación de prueba...');
    await NotificationService.instance.scheduleImmediate('Prueba de alarma TaskFlow');
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Notificación de prueba programada para 10 segundos'),
        duration: Duration(seconds: 3),
      ),
    );
  }

  /// Aviso en plataformas sin alarmas del sistema (web y escritorio).
  /// En móvil no hay nada que avisar: lista vacía.
  List<Widget> _buildPlatformNotice() {
    if (isAndroid || isIOS) return const [];
    final text = isWeb
        ? 'Versión web: las alarmas no están disponibles y las tareas no se guardan.'
        : 'Versión de escritorio: no hay alarmas del sistema; la app funciona como lista de tareas.';
    final colors = Theme.of(context).colorScheme;
    return [
      Container(
        width: double.infinity,
        color: colors.secondaryContainer,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            Icon(Icons.info_outline, color: colors.onSecondaryContainer),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                text,
                style: TextStyle(color: colors.onSecondaryContainer),
              ),
            ),
          ],
        ),
      ),
    ];
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_tasks.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Aún no tienes tareas.\nToca + para agregar una.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    final daysWithTasks = <int>{
      for (final task in _tasks) ...task.weekdays,
    };
    final visible = _filterWeekday == null
        ? _tasks
        : _tasks.where((t) => t.weekdays.contains(_filterWeekday)).toList();
    final next = findNextAlarm(_tasks, DateTime.now());
    return Column(
      children: [
        WeekStrip(
          selected: _filterWeekday,
          daysWithTasks: daysWithTasks,
          onSelect: (day) => setState(() => _filterWeekday = day),
        ),
        if (next != null) NextAlarmCard(task: next.task, when: next.when),
        Expanded(
          child: visible.isEmpty
              ? const Center(
                  child: Text('Sin tareas este día.'),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(12),
                  itemCount: visible.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final task = visible[index];
                    return TaskTile(
                      task: task,
                      onTap: () => _openTaskDialog(task: task),
                      onCheckboxChanged: (_) => _toggleTask(task),
                      onDelete: () => _deleteTask(task),
                    );
                  },
                ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mis Tareas'),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_active),
            tooltip: 'Probar notificación',
            onPressed: _testNotification,
          ),
          IconButton(
            icon: const Icon(Icons.open_in_full),
            tooltip: 'Permiso mostrar sobre apps',
            onPressed: () async {
              final can = await NotificationService.instance.canDrawOverlays();
              debugPrint('[HomePage] Permiso overlay al tocar botón: $can');
              await NotificationService.instance.openOverlaySettings();
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadTasks,
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: 'Ajustes de tema',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => SettingsPage(themeController: widget.themeController),
                ),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          ..._buildPlatformNotice(),
          Expanded(child: _buildBody()),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openTaskDialog(),
        icon: const Icon(Icons.add),
        label: const Text('Nueva tarea'),
      ),
    );
  }
}
