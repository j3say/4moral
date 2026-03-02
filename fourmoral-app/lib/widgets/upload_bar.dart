import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart' as firebase_storage;

// Enum for upload status
enum UploadStatus { uploading, failed, completed }

// Upload task model with needed fields
class UploadTaskModel {
  final String id;
  final String fileName;
  final String storagePath;
  UploadStatus status;
  double progress;
  DateTime startTime;
  bool isCanceled;
  firebase_storage.UploadTask? firebaseUploadTask;

  UploadTaskModel({
    required this.id,
    required this.fileName,
    required this.storagePath,
    this.status = UploadStatus.uploading,
    this.progress = 0.0,
    DateTime? startTime,
    this.isCanceled = false,
    this.firebaseUploadTask,
  }) : startTime = startTime ?? DateTime.now();
}

// Upload Manager Provider skeleton
class UploadManager extends ChangeNotifier {
  final List<UploadTaskModel> _tasks = [];
  bool _cancelAllTriggered = false;

  List<UploadTaskModel> get tasks => List.unmodifiable(_tasks);

  bool get wasCancelAllTriggered => _cancelAllTriggered;

  void resetCancelAllFlag() {
    _cancelAllTriggered = false;
  }

  void _addTask(UploadTaskModel task) {
    _tasks.add(task);
    notifyListeners();
  }

  /// Adds a new upload task for the given file, uploading to the specified storagePath.
  /// The [storagePath] is the full path in the Firebase Storage bucket where the file will be stored.
  void addTask(File file, String storagePath) {
    final id = '${DateTime.now().millisecondsSinceEpoch}_${file.path.hashCode}';
    final fileName =
        file.uri.pathSegments.isNotEmpty
            ? file.uri.pathSegments.last
            : file.path;
    final taskModel = UploadTaskModel(
      id: id,
      fileName: fileName,
      storagePath: storagePath,
      status: UploadStatus.uploading,
      progress: 0.0,
      startTime: DateTime.now(),
      isCanceled: false,
    );
    _addTask(taskModel);

    final ref = firebase_storage.FirebaseStorage.instance.ref().child(
      storagePath,
    );
    final uploadTask = ref.putFile(file);
    taskModel.firebaseUploadTask = uploadTask;

    uploadTask.snapshotEvents.listen(
      (firebase_storage.TaskSnapshot snapshot) {
        if (taskModel.isCanceled) {
          uploadTask.cancel();
          return;
        }
        final double prog =
            snapshot.totalBytes > 0
                ? snapshot.bytesTransferred / snapshot.totalBytes
                : 0.0;
        taskModel.progress = prog;
        notifyListeners();

        if (snapshot.state == firebase_storage.TaskState.success) {
          taskModel.status = UploadStatus.completed;
          taskModel.progress = 1.0;
          notifyListeners();
        } else if (snapshot.state == firebase_storage.TaskState.error ||
            snapshot.state == firebase_storage.TaskState.canceled) {
          taskModel.status = UploadStatus.failed;
          notifyListeners();
        }
      },
      onError: (e) {
        taskModel.status = UploadStatus.failed;
        notifyListeners();
      },
    );
  }

  Future<void> cancelUpload(String id) async {
    final task = _tasks.firstWhere(
      (t) => t.id == id,
      orElse: () => throw Exception('Task not found'),
    );
    if (task.status == UploadStatus.uploading) {
      task.isCanceled = true;
      try {
        if (task.firebaseUploadTask != null) {
          await task.firebaseUploadTask!.cancel();
        }
      } catch (e) {
        // Handle cancellation error if needed
      }
      task.status = UploadStatus.failed; // Mark as canceled/failed
      notifyListeners();
    }
  }

  void retryUpload(UploadTaskModel task) {
    if (task.status == UploadStatus.failed) {
      task.status = UploadStatus.uploading;
      task.progress = 0.0;
      task.isCanceled = false;
      task.startTime = DateTime.now();
      notifyListeners();

      // Trigger your actual retry upload logic here...
    }
  }

  void removeCompletedTasks() {
    _tasks.removeWhere((t) => t.status == UploadStatus.completed);
    notifyListeners();
  }
}

// Upload Bar Widget
class PositionedUploadBar extends StatefulWidget {
  const PositionedUploadBar({super.key});

  @override
  State<PositionedUploadBar> createState() => _PositionedUploadBarState();
}

class _PositionedUploadBarState extends State<PositionedUploadBar> {
  bool _showCompleted = false;
  Timer? _completionDebounceTimer;
  Timer? _completionHideTimer;
  List<String> _lastTaskIds = [];

  @override
  void dispose() {
    _completionDebounceTimer?.cancel();
    _completionHideTimer?.cancel();
    super.dispose();
  }

  String _formatDuration(Duration d) {
    if (d.inSeconds < 1) return '';
    final minutes = d.inMinutes;
    final seconds = d.inSeconds % 60;
    if (minutes > 0) {
      return '${minutes}m ${seconds.toString().padLeft(2, '0')}s';
    }
    return '${seconds}s';
  }

  Duration? _estimateTimeRemaining(List<UploadTaskModel> tasks) {
    final uploadingTasks =
        tasks.where((t) => t.status == UploadStatus.uploading).toList();
    if (uploadingTasks.isEmpty) return null;
    final earliestStart = uploadingTasks
        .map((t) => t.startTime)
        .reduce((a, b) => a.isBefore(b) ? a : b);
    final now = DateTime.now();
    final elapsed = now.difference(earliestStart).inSeconds;
    final sumProgress = uploadingTasks.fold(
      0.0,
      (a, t) => a + t.progress.clamp(0.0, 1.0),
    );
    final avgProgress = sumProgress / uploadingTasks.length;
    if (avgProgress == 0) return null;
    final estimatedTotal = elapsed / avgProgress;
    final remainingSeconds = estimatedTotal - elapsed;
    if (remainingSeconds <= 0) return null;
    return Duration(seconds: remainingSeconds.round());
  }

  void _scheduleShowCompleted(
    UploadManager manager,
    int completedCount,
    int totalCount,
    int uploadingCount,
    List<String> currentTaskIds,
  ) {
    // If all uploads completed, debounce showing the completed bar until no new uploads start for 2 seconds
    if (totalCount > 0 && completedCount == totalCount && uploadingCount == 0) {
      // If the task IDs have changed, reset the debounce timer
      if (_completionDebounceTimer != null) {
        // If task IDs changed during debounce, cancel and reschedule
        if (_lastTaskIds.toString() != currentTaskIds.toString()) {
          _completionDebounceTimer?.cancel();
          _completionDebounceTimer = null;
        }
      }
      if (_completionDebounceTimer == null) {
        _lastTaskIds = List<String>.from(currentTaskIds);
        _completionDebounceTimer = Timer(const Duration(seconds: 2), () {
          if (!mounted) return;
          // Only show completed if task IDs haven't changed
          final managerTasks = manager.tasks.map((t) => t.id).toList();
          if (_lastTaskIds.toString() == managerTasks.toString()) {
            setState(() {
              _showCompleted = true;
              // Keep _lastTaskIds for hide timer
            });
            _completionHideTimer?.cancel();
            _completionHideTimer = Timer(const Duration(seconds: 2), () {
              if (!mounted) return;
              // Only hide if nothing new started
              final managerTasks2 = manager.tasks.map((t) => t.id).toList();
              if (_showCompleted &&
                  _lastTaskIds.toString() == managerTasks2.toString()) {
                manager.removeCompletedTasks();
                setState(() {
                  _showCompleted = false;
                  _lastTaskIds = [];
                });
              }
            });
          } else {
            // If new uploads started, don't show completed
            _completionDebounceTimer?.cancel();
            _completionDebounceTimer = null;
          }
        });
      }
    } else {
      // If uploads started again or incomplete, hide the completed bar and cancel debounce
      _cancelShowCompleted();
    }
  }

  void _cancelShowCompleted() {
    if (_showCompleted) {
      _completionHideTimer?.cancel();
      setState(() {
        _showCompleted = false;
        _lastTaskIds = [];
      });
    }
    _completionDebounceTimer?.cancel();
    _completionDebounceTimer = null;
  }

  @override
  Widget build(BuildContext context) {
    final manager = Provider.of<UploadManager>(context);
    final tasks = manager.tasks;

    final totalCount = tasks.length;
    final completedCount =
        tasks.where((t) => t.status == UploadStatus.completed).length;
    final uploadingCount =
        tasks.where((t) => t.status == UploadStatus.uploading).length;

    double sumProgress = 0.0;
    for (var t in tasks) {
      if (t.status == UploadStatus.completed) {
        sumProgress += 1.0;
      } else if (t.status == UploadStatus.uploading) {
        sumProgress += t.progress.clamp(0.0, 1.0);
      }
    }
    final combinedProgress = totalCount > 0 ? sumProgress / totalCount : 0.0;
    final percentText = (combinedProgress * 100).toStringAsFixed(0);
    final eta = _estimateTimeRemaining(tasks);
    final etaText =
        (eta != null && uploadingCount > 0) ? _formatDuration(eta) : '';

    final currentTaskIds = tasks.map((t) => t.id).toList();
    _scheduleShowCompleted(
      manager,
      completedCount,
      totalCount,
      uploadingCount,
      currentTaskIds,
    );

    if (tasks.isEmpty && !_showCompleted) {
      return const SizedBox.shrink();
    }

    return KeyedSubtree(
      key: const ValueKey('upload-bar'),
      child: Material(
        color: Colors.transparent,
        elevation: 0,
        child: AnimatedSlide(
          offset: Offset.zero,
          duration: const Duration(milliseconds: 300),
          child: AnimatedOpacity(
            opacity: 1,
            duration: const Duration(milliseconds: 300),
            child: Container(
              color: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child:
                            // _showCompleted
                            //     ? Row(
                            //       mainAxisAlignment: MainAxisAlignment.center,
                            //       children: const [
                            //         Icon(
                            //           Icons.check_circle,
                            //           color: Colors.green,
                            //         ),
                            //         SizedBox(width: 8),
                            //         Text(
                            //           'All uploads completed',
                            //           style: TextStyle(
                            //             color: Colors.green,
                            //             fontWeight: FontWeight.bold,
                            //             fontSize: 14,
                            //           ),
                            //         ),
                            //       ],
                            //     )
                            //     :
                            Text(
                                  'Uploading: $completedCount/$totalCount files • $percentText%${etaText.isNotEmpty ? ' • $etaText remaining' : ''}',
                                  style: const TextStyle(fontSize: 14),
                                ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  if (!_showCompleted)
                    LinearProgressIndicator(
                      value: combinedProgress,
                      minHeight: 6,
                      backgroundColor: Colors.grey[300],
                      color: Colors.redAccent,
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
