import 'package:flutter/material.dart';
import '../../../models/call_model.dart';

/// Widget pour afficher un événement d'appel dans le chat
class CallEventBubble extends StatelessWidget {
  final CallModel call;
  final bool isMine;

  const CallEventBubble({
    super.key,
    required this.call,
    required this.isMine,
  });

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 8,
      ),
      child: Row(
        mainAxisAlignment:
            isMine ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: _getBackgroundColor(isDarkMode),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _getIconForStatus(),
                      size: 16,
                      color: _getStatusColor(),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _getStatusLabel(),
                      style: TextStyle(
                        fontWeight: FontWeight.w500,
                        fontSize: 13,
                        color: _getStatusColor(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(
                      call.mediaType == CallMediaType.audio
                          ? Icons.phone
                          : Icons.videocam,
                      size: 16,
                      color: _getStatusColor(),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  _formatTime(call.createdAt),
                  style: TextStyle(
                    fontSize: 11,
                    color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                  ),
                ),
                if (call.status == CallStatus.failed && call.failureReason != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Raison: ${call.failureReason}',
                    style: const TextStyle(
                      fontSize: 11,
                      color: Colors.red,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _getBackgroundColor(bool isDarkMode) {
    switch (call.status) {
      case CallStatus.ended:
        return isDarkMode
            ? (Colors.green[900]?.withOpacity(0.3) ?? Colors.green)
            : (Colors.green[50] ?? Colors.green);
      case CallStatus.declined:
      case CallStatus.missed:
        return isDarkMode
            ? (Colors.orange[900]?.withOpacity(0.3) ?? Colors.orange)
            : (Colors.orange[50] ?? Colors.orange);
      case CallStatus.failed:
        return isDarkMode
            ? (Colors.red[900]?.withOpacity(0.3) ?? Colors.red)
            : (Colors.red[50] ?? Colors.red);
      default:
        return isDarkMode
            ? (Colors.blue[900]?.withOpacity(0.3) ?? Colors.blue)
            : (Colors.blue[50] ?? Colors.blue);
    }
  }

  IconData _getIconForStatus() {
    switch (call.status) {
      case CallStatus.ended:
        return Icons.call_received;
      case CallStatus.declined:
        return Icons.call_missed;
      case CallStatus.missed:
        return Icons.call_missed;
      case CallStatus.failed:
        return Icons.error_outline;
      default:
        return Icons.phone;
    }
  }

  Color _getStatusColor() {
    switch (call.status) {
      case CallStatus.ended:
        return Colors.green;
      case CallStatus.declined:
      case CallStatus.missed:
        return Colors.orange;
      case CallStatus.failed:
        return Colors.red;
      default:
        return Colors.blue;
    }
  }

  String _getStatusLabel() {
    switch (call.status) {
      case CallStatus.ended:
        if (isMine) {
          return 'Appel émis';
        } else {
          return 'Appel reçu';
        }
      case CallStatus.declined:
        return 'Appel décliné';
      case CallStatus.missed:
        return 'Appel manqué';
      case CallStatus.failed:
        return 'Appel échoué';
      default:
        return 'Appel';
    }
  }

  String _formatTime(DateTime dateTime) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final date = DateTime(dateTime.year, dateTime.month, dateTime.day);

    String formattedTime = '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';

    if (date == today) {
      return 'Aujourd\'hui à $formattedTime';
    } else if (date == yesterday) {
      return 'Hier à $formattedTime';
    } else {
      return '${dateTime.day}/${dateTime.month}/${dateTime.year} à $formattedTime';
    }
  }
}
