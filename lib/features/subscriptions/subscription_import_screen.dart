import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/client/twitter_client.dart';
import '../../core/database/repository.dart';

class SubscriptionImportScreen extends StatefulWidget {
  const SubscriptionImportScreen({super.key});

  @override
  State<SubscriptionImportScreen> createState() => _SubscriptionImportScreenState();
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
      ),
      body: SingleChildScrollView(
        child: Container(
          margin: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.only(bottom: 16),
                child: Text(
                  'To import subscriptions from an existing X account, enter the username below. This will fetch their "Following" list.',
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: TextFormField(
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    hintText: 'Enter X username',
                    prefixText: '@',
                    labelText: 'Username',
                  ),
                  maxLength: 15,
                  inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^[a-zA-Z0-9_]+'))],
                  onChanged: (value) {
                    setState(() {
                      _fromScreenName = value;
                    });
                  },
                ),
              ),
              Center(
                child: StreamBuilder<int>(
                  stream: _streamController?.stream,
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return Column(
                        children: [
                          const Icon(Icons.error_outline, color: Colors.red, size: 48),
                          const SizedBox(height: 16),
                          Text('Error: ${snapshot.error}', textAlign: TextAlign.center),
                        ],
                      );
                    }

                    if (snapshot.connectionState == ConnectionState.active) {
                      return Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const CircularProgressIndicator(),
                          const SizedBox(height: 16),
                          Text('Importing... Found ${snapshot.data} users so far'),
                        ],
                      );
                    }

                    if (snapshot.connectionState == ConnectionState.done) {
                      return Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.check_circle_outline, color: Colors.green, size: 48),
                          const SizedBox(height: 16),
                          Text('Import finished! Imported ${snapshot.data} users.'),
                        ],
                      );
                    }

                    return Container();
                  },
                ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _isImporting ? null : _importSubscriptions,
        child: const Icon(Icons.cloud_download),
      ),
    );
  }
}
