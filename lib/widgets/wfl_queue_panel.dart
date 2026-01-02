import 'package:flutter/material.dart';

import '../wfl_models.dart';

class WFLQueuePanel extends StatelessWidget {
  final List<QueueItem> queue;
  final bool isPlayingQueue;
  final int currentQueueIndex;
  final Function(int, int) onReorder;
  final Function(int) onRemove;
  final VoidCallback onPlayQueue;
  final VoidCallback onClearQueue;

  const WFLQueuePanel({
    super.key,
    required this.queue,
    required this.isPlayingQueue,
    required this.currentQueueIndex,
    required this.onReorder,
    required this.onRemove,
    required this.onPlayQueue,
    required this.onClearQueue,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 200,
      color: const Color(0xFF1a1a2e),
      child: Column(
        children: [
          // Queue header
          Container(
            padding: const EdgeInsets.all(12),
            color: const Color(0xFF2a2a3e),
            child: Row(
              children: [
                const Text('Queue',
                    style: TextStyle(
                        color: Colors.white, fontWeight: FontWeight.bold)),
                const Spacer(),
                Text('${queue.length}',
                    style: const TextStyle(color: Colors.grey)),
              ],
            ),
          ),

          // Queue list (drag to reorder)
          Expanded(
            child: queue.isEmpty
                ? const Center(
                    child: Text(
                      'Drop videos\nto queue',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey),
                    ),
                  )
                : ReorderableListView.builder(
                    itemCount: queue.length,
                    onReorder: onReorder,
                    itemBuilder: (context, index) {
                      final item = queue[index];
                      final isPlaying =
                          isPlayingQueue && index == currentQueueIndex;
                      return _buildQueueItem(item, index, isPlaying);
                    },
                  ),
          ),

          // Play Queue button
          Container(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: queue.isEmpty ? null : onPlayQueue,
                    icon: Icon(isPlayingQueue ? Icons.stop : Icons.play_arrow),
                    label: Text(isPlayingQueue ? 'Stop' : 'Play Queue'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          isPlayingQueue ? Colors.red : Colors.green,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: queue.isEmpty ? null : onClearQueue,
                  icon: const Icon(Icons.clear_all),
                  color: Colors.grey,
                  tooltip: 'Clear queue',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQueueItem(QueueItem item, int index, bool isPlaying) {
    return Container(
      key: ValueKey(item.id),
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color:
            isPlaying ? Colors.green.withOpacity(0.3) : const Color(0xFF2a2a3e),
        borderRadius: BorderRadius.circular(8),
        border: isPlaying ? Border.all(color: Colors.green, width: 2) : null,
      ),
      child: ListTile(
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: item.thumbnail != null
              ? Image.memory(item.thumbnail!,
                  width: 50, height: 50, fit: BoxFit.cover)
              : Container(width: 50, height: 50, color: Colors.grey.shade800),
        ),
        title: Text(
          item.filename,
          style: const TextStyle(color: Colors.white, fontSize: 12),
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          'Window ${item.window}',
          style: const TextStyle(color: Colors.grey, fontSize: 10),
        ),
        trailing: IconButton(
          icon: const Icon(Icons.close, size: 16),
          color: Colors.grey,
          onPressed: () => onRemove(index),
        ),
      ),
    );
  }
}
