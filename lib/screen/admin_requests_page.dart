import 'package:flutter/material.dart';

import '../services/admin_service.dart';

class AdminRequestsPage extends StatelessWidget {
  const AdminRequestsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: AdminService.instance.canApproveRequests(),
      builder: (context, accessSnapshot) {
        if (accessSnapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (accessSnapshot.data != true) {
          return Scaffold(
            appBar: AppBar(title: const Text('Admin request approve')),
            body: Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Only an approved admin of this masjid can approve requests.',
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          );
        }
        return Scaffold(
          appBar: AppBar(title: const Text('Admin request approve')),
          body: StreamBuilder(
            stream: AdminService.instance.pendingRequests(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Center(
                  child: Text('Could not load requests: ${snapshot.error}'),
                );
              }
              final requests = snapshot.data?.docs ?? [];
              if (requests.isEmpty) {
                return const Center(child: Text('No pending admin requests.'));
              }
              return ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: requests.length,
                itemBuilder: (context, index) {
                  final request = requests[index];
                  final data = request.data();
                  return Card(
                    child: ListTile(
                      title: Text((data['name'] ?? 'Unnamed admin').toString()),
                      subtitle: Text(
                        'Phone: ${(data['phone'] ?? '').toString()}\n'
                        'Email: ${(data['email'] ?? '').toString()}',
                      ),
                      isThreeLine: true,
                      trailing: Wrap(
                        spacing: 4,
                        children: [
                          IconButton(
                            tooltip: 'Approve',
                            icon: const Icon(Icons.check, color: Colors.green),
                            onPressed: () => _decide(context, request.id, true),
                          ),
                          IconButton(
                            tooltip: 'Reject',
                            icon: const Icon(Icons.close, color: Colors.red),
                            onPressed: () =>
                                _decide(context, request.id, false),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        );
      },
    );
  }

  Future<void> _decide(
    BuildContext context,
    String requestId,
    bool approve,
  ) async {
    try {
      await AdminService.instance.decideRequest(
        requestId: requestId,
        approve: approve,
      );
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(approve ? 'Request approved.' : 'Request rejected.'),
        ),
      );
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Action failed: $error')));
    }
  }
}
