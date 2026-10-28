import 'dart:async';

import 'package:flutter/material.dart';

import '../nagar_repository.dart';
import 'workflow_labels.dart';

class OfficialTaskList extends StatefulWidget {
  const OfficialTaskList({
    super.key,
    required this.repository,
    required this.profile,
    required this.bangla,
    required this.onOpenIncident,
  });
  final NagarRepository repository;
  final RowData profile;
  final bool bangla;
  final ValueChanged<String> onOpenIncident;

  @override
  State<OfficialTaskList> createState() => _OfficialTaskListState();
}

class _OfficialTaskListState extends State<OfficialTaskList> {
  late Future<List<List<RowData>>> data;
  Timer? notificationTimer;
  String filter = 'active';
  String t(String en, String bn) => widget.bangla ? bn : en;

  @override
  void initState() {
    super.initState();
    _load();
    if (widget.profile['role'] == 'field_employee') {
      notificationTimer = Timer.periodic(const Duration(seconds: 12), (_) {
        if (mounted) setState(_load);
      });
    }
  }

  void _load() {
    data = Future.wait([
      widget.repository.tasks(),
      widget.repository.staffDirectory(),
      widget.repository.notifications(),
    ]);
  }

  @override
  void dispose() {
    notificationTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<List<List<RowData>>>(
    future: data,
    builder: (context, snapshot) {
      if (snapshot.hasError) return Center(child: Text('${snapshot.error}'));
      if (!snapshot.hasData) {
        return const Center(child: CircularProgressIndicator());
      }
      final tasks = snapshot.data![0];
      final notifications = snapshot.data![2];
      final names = {
        for (final row in snapshot.data![1])
          row['id'].toString(): row['display_name'].toString(),
      };
      final active = tasks.where((row) => row['status'] != 'resolved').length;
      final activeBn = WorkflowLabels.number(active, widget.bangla);
      final totalBn = WorkflowLabels.number(tasks.length, widget.bangla);
      final shown = tasks
          .where(
            (row) => switch (filter) {
              'active' => row['status'] != 'resolved',
              'completed' => row['status'] == 'resolved',
              _ => true,
            },
          )
          .toList();
      shown.sort(
        (a, b) => _rank(
          a['status'].toString(),
        ).compareTo(_rank(b['status'].toString())),
      );
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            widget.profile['role'] == 'field_employee'
                ? t('My assigned work', 'আমার কাজ')
                : t('Assigned field work', 'মাঠপর্যায়ের কাজ'),
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 5),
          Text(
            t(
              '$active active of ${tasks.length} tasks',
              'মোট $totalBnটি কাজের মধ্যে $activeBnটি চলমান',
            ),
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 14),
          if (notifications.isNotEmpty) ...[
            Text(
              t('Assignment notifications', 'কাজের বিজ্ঞপ্তি'),
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            for (final notification in notifications.take(2))
              Card(
                color: const Color(0xFFE6F4E8),
                child: ListTile(
                  leading: const Icon(Icons.notifications_active_outlined),
                  title: Text(t('New field assignment', notification['text_bn']?.toString() ?? 'নতুন দায়িত্ব দেওয়া হয়েছে')),
                  subtitle: Text(t('Open the related incident', 'সংশ্লিষ্ট ঘটনা ও চিহ্নিত জায়গা দেখুন')),
                  onTap: () => widget.onOpenIncident(notification['incident_id'].toString()),
                ),
              ),
            const SizedBox(height: 10),
          ],
          SegmentedButton<String>(
            showSelectedIcon: false,
            segments: [
              ButtonSegment(value: 'active', label: Text(t('Active', 'চলমান'))),
              ButtonSegment(value: 'completed', label: Text(t('Done', 'শেষ'))),
              ButtonSegment(value: 'all', label: Text(t('All', 'সব'))),
            ],
            selected: {filter},
            onSelectionChanged: (value) => setState(() => filter = value.first),
          ),
          const SizedBox(height: 12),
          if (shown.isEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Text(
                  t('No tasks in this view.', 'এই তালিকায় কোনো কাজ নেই।'),
                ),
              ),
            ),
          for (final task in shown)
            Card(
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () =>
                    widget.onOpenIncident(task['incident_id'].toString()),
                child: Padding(
                  padding: const EdgeInsets.all(15),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        (task['incidents'] as Map?)?['title_bn']?.toString() ??
                            WorkflowLabels.department(
                              task['department_id'].toString(),
                              widget.bangla,
                            ),
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        '${WorkflowLabels.department(task['department_id'].toString(), widget.bangla)} · '
                        '${names[task['assignee_id'].toString()] ?? t('Assigned worker', 'নিযুক্ত কর্মী')}',
                      ),
                      if (task['note'] != null &&
                          task['note'].toString().isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 5),
                          child: Text(
                            task['note'].toString(),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      const SizedBox(height: 9),
                      Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 10,
                        runSpacing: 6,
                        children: [
                          StatusPill(
                            status: task['status'].toString(),
                            bangla: widget.bangla,
                          ),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                t('Open', 'বিস্তারিত'),
                                style: const TextStyle(
                                  color: Color(0xFF287456),
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const Icon(
                                Icons.chevron_right,
                                color: Color(0xFF287456),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      );
    },
  );

  int _rank(String status) => switch (status) {
    'action_submitted' => 0,
    'assigned' => 1,
    'acknowledged' => 2,
    'in_progress' => 3,
    _ => 4,
  };
}
