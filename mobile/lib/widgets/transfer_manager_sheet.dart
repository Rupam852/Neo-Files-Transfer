import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';
import '../services/transfer_service.dart';

class TransferManagerSheet extends StatelessWidget {
  const TransferManagerSheet({super.key});

  static void show(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const TransferManagerSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    final transferService = Provider.of<TransferService>(context);
    final tasks = transferService.tasks;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.75,
      ),
      decoration: BoxDecoration(
        color: isLight ? Colors.white : const Color(0xFF0F172A),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border.all(
          color: isLight ? const Color(0xFFE2E8F0) : Colors.white.withValues(alpha: 0.1),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 30,
            spreadRadius: 5,
          )
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          // Drag Handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: isLight ? const Color(0xFFCBD5E1) : Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF4F46E5).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(LucideIcons.arrowUpDown, color: Color(0xFF818CF8), size: 18),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Background Transfers',
                          style: TextStyle(
                            color: isLight ? const Color(0xFF0F172A) : Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'Space_Grotesk',
                          ),
                        ),
                        Text(
                          '${transferService.activeTasks.length} active • 2GB+ Large File Support',
                          style: TextStyle(
                            color: isLight ? const Color(0xFF64748B) : Colors.white60,
                            fontSize: 11.5,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                if (tasks.any((t) => t.status == TransferStatus.completed || t.status == TransferStatus.cancelled))
                  TextButton.icon(
                    onPressed: () => transferService.clearCompleted(),
                    icon: const Icon(LucideIcons.trash2, size: 14),
                    label: const Text('Clear', style: TextStyle(fontSize: 12)),
                    style: TextButton.styleFrom(
                      foregroundColor: isLight ? const Color(0xFF64748B) : Colors.white60,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          const Divider(height: 1),

          // Transfer list
          if (tasks.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 20),
              child: Column(
                children: [
                  Icon(
                    LucideIcons.checkCircle,
                    size: 40,
                    color: isLight ? const Color(0xFF94A3B8) : Colors.white24,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'No active transfers',
                    style: TextStyle(
                      color: isLight ? const Color(0xFF64748B) : Colors.white60,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            )
          else
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                padding: const EdgeInsets.all(16),
                itemCount: tasks.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (ctx, i) {
                  final task = tasks[i];
                  return _buildTransferCard(ctx, task, isLight, transferService);
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTransferCard(
    BuildContext context,
    TransferTask task,
    bool isLight,
    TransferService service,
  ) {
    final isDl = task.type == TransferType.download;
    final isRunning = task.status == TransferStatus.running;
    final isPaused = task.status == TransferStatus.paused;
    final isCompleted = task.status == TransferStatus.completed;
    final isFailed = task.status == TransferStatus.failed;

    Color statusColor;
    String statusLabel;
    if (isRunning) {
      statusColor = const Color(0xFF10B981);
      statusLabel = 'Running';
    } else if (isPaused) {
      statusColor = const Color(0xFFF59E0B);
      statusLabel = 'Paused';
    } else if (isCompleted) {
      statusColor = const Color(0xFF10B981);
      statusLabel = 'Done';
    } else if (isFailed) {
      statusColor = const Color(0xFFEF4444);
      statusLabel = 'Failed';
    } else {
      statusColor = Colors.grey;
      statusLabel = 'Queued';
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isLight ? const Color(0xFFF8FAFC) : const Color(0xFF030712),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isLight ? const Color(0xFFE2E8F0) : Colors.white.withValues(alpha: 0.08),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: (isDl ? const Color(0xFF06B6D4) : const Color(0xFF4F46E5))
                      .withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: Icon(
                    isDl ? LucideIcons.download : LucideIcons.uploadCloud,
                    color: isDl ? const Color(0xFF06B6D4) : const Color(0xFF818CF8),
                    size: 18,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      task.fileName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: isLight ? const Color(0xFF0F172A) : Colors.white,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                          decoration: BoxDecoration(
                            color: statusColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            statusLabel,
                            style: TextStyle(
                              color: statusColor,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${task.formattedTransferredSize} / ${task.formattedTotalSize}',
                          style: TextStyle(
                            color: isLight ? const Color(0xFF64748B) : Colors.white60,
                            fontSize: 11,
                          ),
                        ),
                        if (task.speed.isNotEmpty && isRunning) ...[
                          const SizedBox(width: 6),
                          Text(
                            '• ${task.speed}',
                            style: const TextStyle(
                              color: Color(0xFF818CF8),
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),

              // Action buttons (Pause / Resume / Cancel)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (isRunning)
                    IconButton(
                      onPressed: () => service.pauseTask(task.id),
                      icon: const Icon(LucideIcons.pause, size: 16),
                      color: const Color(0xFFF59E0B),
                      tooltip: 'Pause Transfer',
                      splashRadius: 18,
                    )
                  else if (isPaused || isFailed)
                    IconButton(
                      onPressed: () => service.resumeTask(task.id),
                      icon: const Icon(LucideIcons.play, size: 16),
                      color: const Color(0xFF10B981),
                      tooltip: 'Resume Transfer',
                      splashRadius: 18,
                    ),
                  IconButton(
                    onPressed: () => service.cancelTask(task.id),
                    icon: const Icon(LucideIcons.x, size: 16),
                    color: isLight ? const Color(0xFF94A3B8) : Colors.white54,
                    tooltip: 'Cancel',
                    splashRadius: 18,
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Progress Bar
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: task.progress,
              backgroundColor: isLight ? const Color(0xFFE2E8F0) : Colors.white12,
              valueColor: AlwaysStoppedAnimation<Color>(
                isCompleted
                    ? const Color(0xFF10B981)
                    : (isPaused ? const Color(0xFFF59E0B) : const Color(0xFF4F46E5)),
              ),
              minHeight: 6,
            ),
          ),
          if (task.eta.isNotEmpty && isRunning) ...[
            const SizedBox(height: 4),
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                task.eta,
                style: TextStyle(
                  color: isLight ? const Color(0xFF94A3B8) : Colors.white38,
                  fontSize: 10,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
