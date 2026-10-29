import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../nagar_repository.dart';
import 'private_evidence_preview.dart';
import 'workflow_labels.dart';

class IncidentDetail extends StatefulWidget {
  const IncidentDetail({
    super.key,
    required this.repository,
    required this.id,
    required this.profile,
    required this.bangla,
  });
  final NagarRepository repository;
  final String id;
  final RowData profile;
  final bool bangla;

  @override
  State<IncidentDetail> createState() => _IncidentDetailState();
}

class _IncidentDetailState extends State<IncidentDetail> {
  late Future<(RowData, List<RowData>, List<RowData>, List<RowData>, List<RowData>)> data;
  String t(String en, String bn) => widget.bangla ? bn : en;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    data = _load();
    setState(() {});
  }

  Future<(RowData, List<RowData>, List<RowData>, List<RowData>, List<RowData>)> _load() async {
    final incident = await widget.repository.client!
        .from('incidents')
        .select()
        .eq('id', widget.id)
        .single();
    final tasks = await widget.repository.client!
        .from('tasks')
        .select()
        .eq('incident_id', widget.id);
    final events = await widget.repository.events(widget.id);
    final staff = await widget.repository.staffDirectory();
    final evidence = await widget.repository.client!
        .from('media_assets')
        .select('task_id,storage_key')
        .eq('incident_id', widget.id)
        .eq('stage', 'before');
    return (incident, tasks.cast<RowData>(), events, staff, evidence.cast<RowData>());
  }

  Future<void> _action(
    String name,
    String target, [
    RowData payload = const {},
  ]) async {
    try {
      final sent = await widget.repository.workflow(
        name,
        target: target,
        payload: payload,
      );
      if (sent) {
        _reload();
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.bangla
                  ? 'সংযোগ ফিরলে কাজটি পাঠানো হবে।'
                  : 'Saved for sync when connected.',
            ),
          ),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.toString())));
      }
    }
  }

  Future<void> _assign(RowData incident, List<RowData> staff) async {
    final employees =
        staff.where((item) => item['role'] == 'field_employee').toList()
          ..sort((a, b) {
            final aMatch = a['department_id'] == incident['department_id']
                ? 0
                : 1;
            final bMatch = b['department_id'] == incident['department_id']
                ? 0
                : 1;
            return aMatch.compareTo(bMatch);
          });
    if (!mounted) return;
    String? selectedId = employees.isEmpty
        ? null
        : employees.first['id'].toString();
    final note = TextEditingController(
      text: t(
        'Inspect the site, complete the work and attach an after photo.',
        'স্থানটি দেখে কাজ শেষ করুন এবং পরের ছবি জমা দিন।',
      ),
    );
    final choice = await showDialog<(RowData, String)>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, update) => AlertDialog(
          title: Text(t('Assign a named worker', 'নির্দিষ্ট কর্মীকে কাজ দিন')),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('${incident['title_bn']} · ${incident['area_bn']}'),
                const SizedBox(height: 14),
                if (employees.isEmpty)
                  Text(
                    t(
                      'No field employee is visible in your team.',
                      'আপনার দলের কোনো মাঠকর্মী পাওয়া যায়নি।',
                    ),
                  )
                else
                  DropdownButtonFormField<String>(
                    initialValue: selectedId,
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: t('Field employee', 'মাঠকর্মী'),
                    ),
                    items: [
                      for (final employee in employees)
                        DropdownMenuItem(
                          value: employee['id'].toString(),
                          child: Text(
                            '${employee['display_name']} · '
                            '${WorkflowLabels.department(employee['department_id'].toString(), widget.bangla)}',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                    onChanged: (value) => update(() => selectedId = value),
                  ),
                const SizedBox(height: 12),
                TextField(
                  controller: note,
                  maxLines: 2,
                  maxLength: 1000,
                  decoration: InputDecoration(
                    labelText: t('Work instructions', 'কাজের নির্দেশনা'),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(t('Cancel', 'ফিরে যান')),
            ),
            FilledButton(
              onPressed: selectedId == null
                  ? null
                  : () {
                      final selected = employees.firstWhere(
                        (item) => item['id'].toString() == selectedId,
                      );
                      Navigator.pop(dialogContext, (
                        selected,
                        note.text.trim(),
                      ));
                    },
              child: Text(t('Assign task', 'কাজ দিন')),
            ),
          ],
        ),
      ),
    );
    note.dispose();
    if (choice == null) return;
    await _action('assign_task', widget.id, {
      'department_id': choice.$1['department_id'],
      'team_id': choice.$1['team_id'],
      'assignee_id': choice.$1['id'],
      'note': choice.$2,
    });
  }

  Future<void> _submitPhoto(String taskId) async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: Text(t('Take a photo', 'এখন ছবি তুলুন')),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: Text(t('Choose from gallery', 'গ্যালারি থেকে ছবি নিন')),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null) return;
    XFile? photo;
    try {
      photo = await ImagePicker().pickImage(
        source: source,
        maxWidth: 1600,
        imageQuality: 75,
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              t(
                'Camera or photo access was denied. You can try the other source.',
                'ছবি তোলার বা গ্যালারি খোলার অনুমতি নেই। অন্য পথটি চেষ্টা করুন।',
              ),
            ),
          ),
        );
      }
      return;
    }
    if (photo == null || !mounted) return;
    final note = TextEditingController();
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(t('Submit after evidence', 'কাজ শেষে প্রমাণ জমা দিন')),
        content: TextField(
          controller: note,
          maxLength: 1000,
          decoration: InputDecoration(
            labelText: t('Work completed', 'সম্পন্ন কাজ'),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(t('Cancel', 'বাতিল')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(t('Submit', 'জমা দিন')),
          ),
        ],
      ),
    );
    if (accepted == true) {
      if (note.text.trim().length < 8) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                t(
                  'Describe the completed work in at least eight characters.',
                  'কী কাজ করেছেন, অন্তত আট অক্ষরে লিখুন।',
                ),
              ),
            ),
          );
        }
        note.dispose();
        return;
      }
      try {
        final sent = await widget.repository.submitTaskEvidence(
          taskId: taskId,
          note: note.text,
          imagePath: photo.path,
        );
        if (sent) {
          _reload();
        } else if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                widget.bangla
                    ? 'ছবিটি সংরক্ষিত। সংযোগ ফিরলে পাঠানো হবে।'
                    : 'Photo saved for sync when connected.',
              ),
            ),
          );
        }
      } catch (error) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(error.toString())));
        }
      }
    }
    note.dispose();
  }

  Future<void> _actionWithNote(String action, String taskId) async {
    final controller = TextEditingController();
    final note = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          action == 'approve_task'
              ? t('Approve completed work?', 'কাজটি অনুমোদন করবেন?')
              : t('Send work back?', 'আরও কাজের জন্য ফেরত দেবেন?'),
        ),
        content: TextField(
          controller: controller,
          maxLines: 2,
          decoration: InputDecoration(
            labelText: t('Review note', 'যাচাইয়ের মন্তব্য'),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(t('Cancel', 'ফিরে যান')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: Text(
              action == 'approve_task'
                  ? t('Approve', 'অনুমোদন করুন')
                  : t('Send back', 'ফেরত দিন'),
            ),
          ),
        ],
      ),
    );
    controller.dispose();
    if (note == null) return;
    if (action == 'rework_task' && note.length < 8) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              t('Explain what needs more work.', 'আর কী কাজ দরকার, তা লিখুন।'),
            ),
          ),
        );
      }
      return;
    }
    await _action(action, taskId, {'note': note});
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(t('Incident', 'ঘটনা'))),
    body: FutureBuilder(
      future: data,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return Center(
            child: snapshot.error == null
                ? const CircularProgressIndicator()
                : Text(snapshot.error.toString()),
          );
        }
        final (incident, tasks, events, staff, markedEvidence) = snapshot.data!;
        final names = {
          for (final person in staff)
            person['id'].toString(): person['display_name'].toString(),
        };
        final role = widget.profile['role'].toString();
        final manager = const [
          'executive',
          'department_head',
          'supervisor',
        ].contains(role);
        final hasActiveTask = tasks.any((item) => item['status'] != 'resolved');
        final status = incident['status'].toString();
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              incident['code'].toString(),
              style: Theme.of(
                context,
              ).textTheme.labelLarge?.copyWith(color: const Color(0xFF287456)),
            ),
            const SizedBox(height: 5),
            Text(
              incident['title_bn'].toString(),
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: StatusPill(status: status, bangla: widget.bangla),
            ),
            const SizedBox(height: 8),
            Text(
              '${incident['area_bn']} · ${WorkflowLabels.department(incident['department_id'].toString(), widget.bangla)}',
            ),
            Text(
              WorkflowLabels.priority(
                incident['priority'].toString(),
                widget.bangla,
              ),
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            LinearProgressIndicator(
              value: (WorkflowLabels.stage(status) + 1) / 6,
              minHeight: 6,
              borderRadius: BorderRadius.circular(8),
            ),
            const SizedBox(height: 10),
            Text(incident['description_bn']?.toString() ?? ''),
            const SizedBox(height: 16),
            if (incident['before_key'] != null)
              PrivateEvidencePreview(
                repository: widget.repository,
                storageKey: incident['before_key'].toString(),
                label: t('Before evidence', 'কাজের আগের প্রমাণ'),
                bangla: widget.bangla,
              ),
            if (incident['after_key'] != null)
              PrivateEvidencePreview(
                repository: widget.repository,
                storageKey: incident['after_key'].toString(),
                label: t('After evidence', 'কাজের পরের প্রমাণ'),
                bangla: widget.bangla,
              ),
            if (manager && status != 'resolved' && !hasActiveTask)
              FilledButton.icon(
                onPressed: () => _assign(incident, staff),
                icon: const Icon(Icons.person_add_alt),
                label: Text(t('Assign a field employee', 'মাঠকর্মীকে কাজ দিন')),
              ),
            if (manager && hasActiveTask)
              Text(
                t(
                  'A worker is already assigned. Follow the task below.',
                  'একজন কর্মীকে কাজ দেওয়া আছে। নিচে কাজের অগ্রগতি দেখুন।',
                ),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            if (manager)
              TextButton(
                onPressed: () => _action('toggle_escalation', widget.id),
                child: Text(
                  incident['escalated'] == true
                      ? t('Remove escalation', 'জরুরি চিহ্ন সরান')
                      : t('Escalate', 'জরুরি চিহ্ন দিন'),
                ),
              ),
            const Divider(),
            Text(
              t('Tasks', 'কাজ'),
              style: Theme.of(context).textTheme.titleLarge,
            ),
            if (tasks.isEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    t(
                      'No worker has been assigned yet.',
                      'এখনো কাউকে কাজ দেওয়া হয়নি।',
                    ),
                  ),
                ),
              ),
            for (final task in tasks)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        names[task['assignee_id'].toString()] ??
                            t('Assigned worker', 'নিযুক্ত কর্মী'),
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      Text(
                        '${WorkflowLabels.department(task['department_id'].toString(), widget.bangla)} · '
                        '${task['team_id'] ?? ''}',
                      ),
                      const SizedBox(height: 6),
                      StatusPill(
                        status: task['status'].toString(),
                        bangla: widget.bangla,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        task['completion_note']?.toString() ??
                            task['note']?.toString() ??
                            '',
                      ),
                      for (final frame in markedEvidence.where(
                        (item) => item['task_id'] == task['id'],
                      ))
                        Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: PrivateEvidencePreview(
                            repository: widget.repository,
                            storageKey: frame['storage_key'].toString(),
                            label: t(
                              'Marked screenshot for this task',
                              'এই কাজের চিহ্নিত স্ক্রিনশট',
                            ),
                            bangla: widget.bangla,
                          ),
                        ),
                      if (role == 'field_employee' &&
                          task['assignee_id'] == widget.profile['id'])
                        Wrap(
                          spacing: 8,
                          children: [
                            if (task['status'] == 'assigned')
                              FilledButton(
                                onPressed: () => _action(
                                  'acknowledge_task',
                                  task['id'].toString(),
                                ),
                                child: Text(t('Accept', 'গ্রহণ করুন')),
                              ),
                            if (task['status'] == 'acknowledged')
                              FilledButton(
                                onPressed: () => _action(
                                  'start_task',
                                  task['id'].toString(),
                                ),
                                child: Text(t('Start', 'শুরু করুন')),
                              ),
                            if (task['status'] == 'in_progress')
                              FilledButton(
                                onPressed: () =>
                                    _submitPhoto(task['id'].toString()),
                                child: Text(
                                  t(
                                    'Submit after photo',
                                    'কাজ শেষে ছবি জমা দিন',
                                  ),
                                ),
                              ),
                          ],
                        ),
                      if (manager && task['status'] == 'action_submitted')
                        Wrap(
                          spacing: 8,
                          children: [
                            FilledButton(
                              onPressed: () => _actionWithNote(
                                'approve_task',
                                task['id'].toString(),
                              ),
                              child: Text(t('Approve', 'অনুমোদন করুন')),
                            ),
                            OutlinedButton(
                              onPressed: () => _actionWithNote(
                                'rework_task',
                                task['id'].toString(),
                              ),
                              child: Text(t('Rework', 'পুনরায় কাজ')),
                            ),
                          ],
                        ),
                      if (manager &&
                          task['status'] == 'resolved' &&
                          incident['status'] == 'resolved')
                        TextButton(
                          onPressed: () =>
                              _action('reopen_task', task['id'].toString()),
                          child: Text(t('Reopen', 'পুনরায় খুলুন')),
                        ),
                    ],
                  ),
                ),
              ),
            const Divider(),
            Text(
              t('Audit timeline', 'কাজের ইতিহাস'),
              style: Theme.of(context).textTheme.titleLarge,
            ),
            for (final event in events)
              ListTile(
                leading: const Icon(Icons.history),
                title: Text(
                  WorkflowLabels.event(event['kind'].toString(), widget.bangla),
                ),
                subtitle: Text(
                  [
                    if (names[event['actor_id'].toString()] != null)
                      names[event['actor_id'].toString()]!,
                    if (event['note']?.toString().isNotEmpty == true)
                      event['note'].toString(),
                  ].join(' · '),
                ),
                trailing: Text(event['created_at'].toString().split('T').first),
              ),
          ],
        );
      },
    ),
  );
}
