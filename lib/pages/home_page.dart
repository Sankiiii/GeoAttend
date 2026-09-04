import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:socekt_demo/service/socket_constant.dart';
import 'package:socekt_demo/service/socket_service.dart';
import 'dashboard_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key, required this.loginData});

  final Map<String, dynamic> loginData;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  bool showAttendance = true;
  StreamSubscription? subscription;
  late List<Map<String, dynamic>> accessiblePages;
  String? lastSocketMessage;

  @override
  void initState() {
    super.initState();

    final data = widget.loginData['data'] as Map<String, dynamic>? ?? {};
    accessiblePages = List<Map<String, dynamic>>.from(
      (data['accessible_pages'] as List? ?? []).map((page) {
        if (page is Map) {
          return Map<String, dynamic>.from(page as Map);
        }
        return <String, dynamic>{};
      }),
    );

    subscription = SocketService.instance.stream.listen((message) {
      if (!mounted) return;

      try {
        final data = jsonDecode(message.toString());

        if (data is Map<String, dynamic>) {
          final eventName = data['type']?.toString() ?? data['event']?.toString();

          if (eventName == SocketConstants.pageMappingUpdated) {
            final updatedPages = data['updated_pages'] as List? ?? [];
            final payload = data['data'] as Map<String, dynamic>? ?? {};

            setState(() {
              showAttendance = payload['showAttendance'] ?? true;
              accessiblePages = List<Map<String, dynamic>>.from(
                updatedPages.map((page) {
                  if (page is Map) {
                    return Map<String, dynamic>.from(page as Map);
                  }
                  return <String, dynamic>{};
                }),
              );
              lastSocketMessage = updatedPages.isEmpty
                  ? 'No pages available from backend'
                  : 'Page mapping updated from backend';
            });

            if (payload['redirect'] == 'dashboard') {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => const DashboardPage()),
              );
            }
          }
        }
      } catch (_) {
        debugPrint('Unable to parse socket message: $message');
      }
    });
  }

  @override
  void dispose() {
    subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {

    final userData = widget.loginData['data'] as Map<String, dynamic>? ?? {};
    final firstName = userData['firstName']?.toString() ?? '';
    final lastName = userData['lastName']?.toString() ?? '';
    final username = userData['username']?.toString() ?? 'User';
    final userLabel = [firstName, lastName].where((value) => value.isNotEmpty).join(' ').trim();

    return Scaffold(
      appBar: AppBar(title: const Text('Dashboard')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      userLabel.isNotEmpty ? userLabel : username,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    Text('Username: $username'),
                    if (userData['email'] != null) Text('Email: ${userData['email']}'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Accessible Pages',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            if (lastSocketMessage != null) ...[
              const SizedBox(height: 8),
              Text(
                lastSocketMessage!,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.blueGrey,
                ),
              ),
            ],
            const SizedBox(height: 8),
            ...accessiblePages.map((page) {
              final pageName = page['page_name']?.toString() ?? 'Page';
              final pageUrl = page['url']?.toString() ?? '';
              final children = page['children'] as List? ?? [];

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: children.isEmpty
                    ? ListTile(
                        title: Text(pageName),
                        subtitle: Text(pageUrl.isNotEmpty ? pageUrl : 'No URL'),
                        trailing: const Icon(Icons.chevron_right),
                      )
                    : ExpansionTile(
                        title: Text(pageName),
                        subtitle: Text(pageUrl.isNotEmpty ? pageUrl : 'Nested page'),
                        children: children.map<Widget>((child) {
                          final childName = child['page_name']?.toString() ?? 'Child page';
                          return ListTile(
                            title: Text(childName),
                            subtitle: Text(child['url']?.toString() ?? ''),
                          );
                        }).toList(),
                      ),
              );
            }),
            if (showAttendance)
              const Card(
                child: ListTile(title: Text('Attendance Widget')),
              ),
          ],
        ),
      ),
    );
  }
}
