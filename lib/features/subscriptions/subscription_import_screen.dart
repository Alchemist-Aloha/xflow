import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/client/twitter_client.dart';
import '../../core/database/repository.dart';

class SubscriptionImportScreen extends StatefulWidget {
  const SubscriptionImportScreen({super.key});

  @override
  State<SubscriptionImportScreen> createState() =>
      _SubscriptionImportScreenState();
}

class _SubscriptionImportScreenState extends State<SubscriptionImportScreen> {
  String? _fromScreenName;
  StreamController<int>? _streamController;
  bool _isImporting = false;

  Future<void> _importSubscriptions() async {
    if (_fromScreenName == null || _fromScreenName!.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a username')),
      );
      return;
    }

    setState(() {
      _isImporting = true;
      _streamController = StreamController<int>();
    });

    try {
      _streamController?.add(0);
      final client = TwitterClient();

      final user = await client.fetchProfile(_fromScreenName!);
      if (user == null) {
        throw Exception('User not found');
      }

      final following = await client.fetchFollowing(user.id);
      if (following.isNotEmpty) {
        await Repository.insertSubscriptions(following);
        _streamController?.add(following.length);
      } else {
        _streamController?.add(0);
      }

      _streamController?.close();
    } catch (e, stackTrace) {
      debugPrint('Import error: $e\n$stackTrace');
      _streamController?.addError(e, stackTrace);
    } finally {
      if (mounted) {
        setState(() {
          _isImporting = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _streamController?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Import Subscriptions'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Card(
                elevation: 0,
                color: Theme.of(context).colorScheme.surfaceContainerLow,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24)),
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    children: [
                      const Icon(Icons.import_export,
                          size: 48, color: Colors.blue),
                      const SizedBox(height: 16),
                      Text(
                        'Enter a username to sync their following list into your XFlow subscriptions.',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant),
                      ),
                      const SizedBox(height: 24),
                      TextFormField(
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: Theme.of(context)
                              .colorScheme
                              .surfaceContainerHigh,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide.none,
                          ),
                          hintText: 'Enter X username',
                          prefixIcon: const Icon(Icons.alternate_email),
                          labelText: 'Username',
                        ),
                        maxLength: 15,
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(
                              RegExp(r'^[a-zA-Z0-9_]+'))
                        ],
                        onChanged: (value) {
                          setState(() {
                            _fromScreenName = value;
                          });
                        },
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: _isImporting ? null : _importSubscriptions,
                          icon: _isImporting
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2, color: Colors.white))
                              : const Icon(Icons.cloud_download),
                          label: Text(
                              _isImporting ? 'Importing...' : 'Start Import'),
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 32),
              Center(
                child: StreamBuilder<int>(
                  stream: _streamController?.stream,
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return _StatusCard(
                        icon: Icons.error_outline,
                        color: Colors.redAccent,
                        message: 'Error: ${snapshot.error}',
                      );
                    }

                    if (snapshot.connectionState == ConnectionState.active) {
                      return _StatusCard(
                        icon: Icons.sync,
                        color: Colors.blue,
                        message: 'Found ${snapshot.data} users so far...',
                        isSpinning: true,
                      );
                    }

                    if (snapshot.connectionState == ConnectionState.done) {
                      return _StatusCard(
                        icon: Icons.check_circle_outline,
                        color: Colors.green,
                        message: 'Success! Imported ${snapshot.data} users.',
                      );
                    }

                    return const SizedBox.shrink();
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String message;
  final bool isSpinning;

  const _StatusCard({
    required this.icon,
    required this.color,
    required this.message,
    this.isSpinning = false,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: color.withOpacity(0.1),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: color.withOpacity(0.2)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isSpinning)
              const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2))
            else
              Icon(icon, color: color, size: 24),
            const SizedBox(width: 16),
            Flexible(
                child: Text(message,
                    style:
                        TextStyle(color: color, fontWeight: FontWeight.w500))),
          ],
        ),
      ),
    );
  }
}
