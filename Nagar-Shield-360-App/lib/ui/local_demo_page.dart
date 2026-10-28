import 'dart:convert';

import 'package:flutter/material.dart';

import '../nagar_repository.dart';
import 'notice.dart';
import 'operations_lab.dart';

class LocalDemoPage extends StatefulWidget {
  const LocalDemoPage({
    super.key,
    required this.repository,
    required this.bangla,
    required this.onBack,
  });

  final NagarRepository repository;
  final bool bangla;
  final VoidCallback onBack;

  @override
  State<LocalDemoPage> createState() => _LocalDemoPageState();
}

class _LocalDemoPageState extends State<LocalDemoPage> {
  RowData? state;
  String? error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final value = await widget.repository.demoState();
    if (mounted) setState(() => state = value);
  }

  Future<void> _act(String action) async {
    try {
      if (action == 'reset') {
        await widget.repository.resetDemo();
      } else {
        await widget.repository.advanceDemo(action);
      }
      await _load();
      if (mounted) setState(() => error = null);
    } catch (value) {
      if (mounted) setState(() => error = value.toString());
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(widget.bangla ? 'ইন্টারনেট ছাড়া ডেমো' : 'Local presentation'),
      leading: BackButton(onPressed: widget.onBack),
    ),
    body: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Notice('LOCAL PRESENTATION DATA · SIMULATED'),
        Card(
          child: ListTile(
            leading: const Icon(Icons.hub_outlined),
            title: Text(widget.bangla
                ? 'সমন্বিত সিটি অপারেশন দেখুন'
                : 'Explore connected city operations'),
            subtitle: Text(widget.bangla
                ? 'চারটি নমুনা সমস্যা: খবর, অগ্রাধিকার, কাজ, যাচাই'
                : 'Four seeded cases: signals, priority, tasks and verification'),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
              builder: (_) => Scaffold(
                appBar: AppBar(title: Text(widget.bangla
                    ? 'সমন্বিত অপারেশন'
                    : 'City operations')),
                body: OperationsLab(bangla: widget.bangla),
              ),
            )),
          ),
        ),
        if (error != null) Notice(error!),
        if (state == null)
          const Center(child: CircularProgressIndicator())
        else ...[
          Text(
            widget.bangla
                ? 'শুরু থেকে শেষ পর্যন্ত কাজের ধাপ'
                : 'Complete role chain',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          ListTile(
            title: Text(widget.bangla ? 'ঘটনার অবস্থা' : 'Incident status'),
            subtitle: Text(state!['incident_status'].toString()),
          ),
          ListTile(
            title: Text(widget.bangla ? 'কাজের অবস্থা' : 'Task status'),
            subtitle: Text(state!['task_status'].toString()),
          ),
          for (final entry in const [
            ('Public → Executive / Head', 'verify'),
            ('Executive / Head → Employee', 'assign'),
            ('Employee accepts', 'accept'),
            ('Employee starts', 'start'),
            ('Employee submits after evidence', 'submit'),
            ('Supervisor approves', 'approve'),
          ])
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: OutlinedButton(
                onPressed: () => _act(entry.$2),
                child: Text(entry.$1),
              ),
            ),
          TextButton(
            onPressed: () => _act('reset'),
            child: Text(widget.bangla ? 'ডেমো রিসেট' : 'Reset Demo'),
          ),
          const SizedBox(height: 12),
          Text(
            widget.bangla ? 'কখন কী হলো' : 'Audit timeline',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          for (final event
              in (jsonDecode(state!['event_log'] as String) as List))
            ListTile(
              leading: const Icon(Icons.history),
              title: Text(event.toString()),
            ),
        ],
      ],
    ),
  );
}
