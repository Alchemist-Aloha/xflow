import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/utils/app_logger.dart';

class LogViewerScreen extends StatefulWidget {
  const LogViewerScreen({super.key});

  @override
  State<LogViewerScreen> createState() => _LogViewerScreenState();
}

class _LogViewerScreenState extends State<LogViewerScreen> {
  @override
  Widget build(BuildContext context) {
    final logs = AppLogger.logs;

    return Scaffold(
      appBar: AppBar(
        title: const Text('App Logs'),
        actions: [
          IconButton(
            icon: const Icon(Icons.copy),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: logs.join('\n')));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Logs copied to clipboard')),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: () {
              setState(() {
                AppLogger.clear();
              });
            },
          ),
        ],
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(8),
        itemCount: logs.length,
        itemBuilder: (context, index) {
          final log = logs[logs.length - 1 - index]; // Show latest logs first
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 2.0),
            child: Text(
              log,
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 12,
              ),
            ),
          );
        },
      ),
    );
  }
}
