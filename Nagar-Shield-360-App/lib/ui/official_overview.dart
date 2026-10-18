import 'package:flutter/material.dart';

import '../nagar_repository.dart';
import 'workflow_labels.dart';

class OfficialOverview extends StatefulWidget {
  const OfficialOverview({
    super.key,
    required this.repository,
    required this.profile,
    required this.bangla,
    required this.onNavigate,
    required this.onOpenIncident,
  });
  final NagarRepository repository;
  final RowData profile;
  final bool bangla;
  final ValueChanged<String> onNavigate;
  final ValueChanged<String> onOpenIncident;

  @override
  State<OfficialOverview> createState() => _OfficialOverviewState();
}

class _OfficialOverviewState extends State<OfficialOverview> {
  late final Future<List<List<RowData>>> data;
  String t(String en, String bn) => widget.bangla ? bn : en;

  @override
  void initState() {
    super.initState();
    final role = widget.profile['role'].toString();
    data = Future.wait([
      widget.repository.incidents(),
      widget.repository.tasks(),
      if (const ['executive', 'department_head'].contains(role))
        widget.repository.reviewQueue(),
    ]);
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<List<List<RowData>>>(
    future: data,
    builder: (context, snapshot) {
      if (snapshot.hasError) return Center(child: Text('${snapshot.error}'));
      if (!snapshot.hasData) {
        return const Center(child: CircularProgressIndicator());
      }
      final incidents = snapshot.data![0];
      final tasks = snapshot.data![1];
      final review = snapshot.data!.length > 2
          ? snapshot.data![2]
          : <RowData>[];
      final waitingApproval = tasks
          .where((row) => row['status'] == 'action_submitted')
          .length;
      final active = incidents
          .where((row) => row['status'] != 'resolved')
          .length;
      final resolved = incidents.length - active;
      final role = widget.profile['role'].toString();
      String n(int value) => WorkflowLabels.number(value, widget.bangla);
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF173F35),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  WorkflowLabels.role(role, widget.bangla),
                  style: const TextStyle(
                    color: Color(0xFFC9E9A5),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  t(
                    'Welcome, ${widget.profile['display_name']}',
                    'স্বাগতম, ${widget.profile['display_name']}',
                  ),
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  t(
                    'Follow each report from review to completed work.',
                    'নতুন অভিযোগ দেখা থেকে কাজ শেষ হওয়া পর্যন্ত সব ধাপ এখানেই।',
                  ),
                  style: const TextStyle(color: Color(0xFFD2E6D9), height: 1.5),
                ),
              ],
            ),
          ),
          const SizedBox(height: 15),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _Metric(
                t('Visible incidents', 'মোট ঘটনা'),
                incidents.length,
                Icons.location_city_outlined,
                widget.bangla,
              ),
              _Metric(
                t('Work in progress', 'চলমান কাজ'),
                active,
                Icons.construction_outlined,
                widget.bangla,
              ),
              _Metric(
                t('Awaiting approval', 'অনুমোদনের অপেক্ষায়'),
                waitingApproval,
                Icons.fact_check_outlined,
                widget.bangla,
              ),
              _Metric(
                t('Completed', 'কাজ শেষ'),
                resolved,
                Icons.task_alt_outlined,
                widget.bangla,
              ),
            ],
          ),
          const SizedBox(height: 19),
          Text(
            t('Next actions', 'এখন যা দেখবেন'),
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          if (review.isNotEmpty)
            _ActionCard(
              icon: Icons.rate_review_outlined,
              title: t(
                '${review.length} new reports need review',
                '${n(review.length)}টি নতুন প্রতিবেদন যাচাই বাকি',
              ),
              detail: t(
                'Check evidence before creating an incident.',
                'ঘটনা খোলার আগে বিবরণ ও ছবি মিলিয়ে দেখুন।',
              ),
              onTap: () => widget.onNavigate('incidents'),
            ),
          if (waitingApproval > 0)
            _ActionCard(
              icon: Icons.fact_check_outlined,
              title: t(
                '$waitingApproval completed tasks need approval',
                '${n(waitingApproval)}টি কাজের ফল যাচাই বাকি',
              ),
              detail: t(
                'Compare before and after evidence.',
                'আগের ও পরের প্রমাণ মিলিয়ে অনুমোদন করুন।',
              ),
              onTap: () => widget.onNavigate('tasks'),
            ),
          _ActionCard(
            icon: Icons.assignment_outlined,
            title: t('Open tasks', 'দেওয়া কাজ দেখুন'),
            detail: t(
              'See the assigned worker and current step.',
              'কাকে কাজ দেওয়া হয়েছে ও এখন কোন ধাপে আছে, দেখুন।',
            ),
            onTap: () => widget.onNavigate('tasks'),
          ),
          _ActionCard(
            icon: Icons.hub_outlined,
            title: t('Connected city operations', 'সমন্বিত সিটি অপারেশন'),
            detail: t(
              'Explore three seeded cases from signals to verified results.',
              'তিনটি নমুনা ঘটনায় খবর থেকে ফল যাচাই পর্যন্ত দেখুন।',
            ),
            onTap: () => widget.onNavigate('operations'),
          ),
          _ActionCard(
            icon: Icons.bar_chart_outlined,
            title: t('City work report', 'কাজের সারসংক্ষেপ'),
            detail: t(
              'Review completion and department totals.',
              'কত কাজ শেষ, কোন বিভাগে কত—সব হিসাব দেখুন।',
            ),
            onTap: () => widget.onNavigate('reports'),
          ),
          const SizedBox(height: 20),
          Text(
            t('Recent incidents', 'সাম্প্রতিক ঘটনা'),
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
          ),
          if (incidents.isEmpty)
            Padding(
              padding: const EdgeInsets.all(18),
              child: Text(
                t(
                  'No incidents are visible to this account yet.',
                  'এই অ্যাকাউন্টে এখনো কোনো ঘটনা দেখার নেই।',
                ),
              ),
            ),
          for (final incident in incidents.take(5))
            Card(
              child: ListTile(
                title: Text('${incident['code']} · ${incident['title_bn']}'),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(incident['area_bn']?.toString() ?? ''),
                    const SizedBox(height: 5),
                    StatusPill(
                      status: incident['status'].toString(),
                      bangla: widget.bangla,
                    ),
                  ],
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => widget.onOpenIncident(incident['id'].toString()),
              ),
            ),
          const SizedBox(height: 12),
          Text(
            t(
              'Priority values and detection overlays are illustrative.',
              'অগ্রাধিকারের স্কোর ও ছবির চিহ্নগুলো নমুনা হিসেবে দেখানো হয়েছে।',
            ),
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      );
    },
  );
}

class _Metric extends StatelessWidget {
  const _Metric(this.label, this.value, this.icon, this.bangla);
  final String label;
  final int value;
  final IconData icon;
  final bool bangla;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 160,
    child: Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 21, color: const Color(0xFF287456)),
            const SizedBox(height: 6),
            Text(
              WorkflowLabels.number(value, bangla),
              style: Theme.of(
                context,
              ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            Text(label, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    ),
  );
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({
    required this.icon,
    required this.title,
    required this.detail,
    required this.onTap,
  });
  final IconData icon;
  final String title;
  final String detail;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Card(
    child: ListTile(
      leading: Icon(icon, color: const Color(0xFF287456)),
      title: Text(title),
      subtitle: Text(detail),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    ),
  );
}
