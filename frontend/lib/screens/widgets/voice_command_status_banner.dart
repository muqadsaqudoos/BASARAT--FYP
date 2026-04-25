import 'package:flutter/material.dart';

/// Same visual as the home screen: live recognition / status above the bottom bar.
class VoiceCommandStatusBanner extends StatelessWidget {
  const VoiceCommandStatusBanner({
    super.key,
    this.statusMessage,
    this.recognizedCommand,
  });

  final String? statusMessage;
  final String? recognizedCommand;

  @override
  Widget build(BuildContext context) {
    if (statusMessage == null && recognizedCommand == null) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: statusMessage != null
            ? Colors.orange.shade50
            : Colors.blue.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: statusMessage != null
              ? Colors.orange.shade200
              : Colors.blue.shade200,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(
            statusMessage != null ? Icons.hourglass_empty : Icons.mic,
            color: statusMessage != null
                ? Colors.orange.shade700
                : Colors.blue.shade700,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              statusMessage != null
                  ? statusMessage!
                  : 'Detected: "$recognizedCommand"',
              style: TextStyle(
                color: statusMessage != null
                    ? Colors.orange.shade900
                    : Colors.blue.shade900,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
