import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../nagar_repository.dart';
import 'media_studio.dart';
import 'incident_detail.dart';
import 'survey_page.dart';
import 'staff_queue_page.dart';
import 'official_overview.dart';
import 'official_task_list.dart';
import 'official_report_view.dart';
import 'workflow_labels.dart';
import 'observation_review_card.dart';
import 'operations_lab.dart';

class OfficialPages extends StatefulWidget {
  const OfficialPages({
    super.key,
    required this.repository,
    required this.profile,
    required this.bangla,
    required this.onSignOut,
  });
  final NagarRepository repository;
  final RowData profile;
  final bool bangla;
  final VoidCallback onSignOut;

  @override
  State<OfficialPages> createState() => _OfficialPagesState();
}

class _OfficialPagesState extends State<OfficialPages> {
  String page = 'dashboard';
  int refresh = 0;
  bool refreshing = false;
  String incidentFilter = 'active';
  late Future<List<List<RowData>>> incidentData;
  late Future<List<RowData>> mapData;

  @override
  void initState() {
    super.initState();
    final role = widget.profile['role'].toString();
    if (role == 'field_employee') page = 'tasks';
    if (role == 'survey_operator') page = 'surveys';
    _loadLists();
  }

  void _loadLists() {
    incidentData = Future.wait([
      widget.repository.incidents(),
      if (reviewer) widget.repository.reviewQueue(),
    ]);
    mapData = widget.repository.incidents();
  }

  String get role => widget.profile['role'].toString();
  bool get manager =>
      const ['executive', 'department_head', 'supervisor'].contains(role);
  bool get reviewer => const ['executive', 'department_head'].contains(role);
  String t(String en, String bn) => widget.bangla ? bn : en;

  List<(String, IconData, String, String)> get pages => [
    if (role != 'field_employee' && role != 'survey_operator')
      ('dashboard', Icons.dashboard_outlined, 'Dashboard', 'সারসংক্ষেপ'),
    if (role != 'survey_operator')
      ('incidents', Icons.report_outlined, 'Incidents', 'ঘটনা'),
    if (role != 'survey_operator')
      ('tasks', Icons.assignment_outlined, 'Tasks', 'কাজ'),
    if (manager) ('map', Icons.map_outlined, 'Map', 'মানচিত্র'),
    if (role != 'survey_operator')
      ('operations', Icons.hub_outlined, 'City operations', 'সমন্বিত অপারেশন'),
    if (manager) ('reports', Icons.bar_chart_outlined, 'Reports', 'প্রতিবেদন'),
    if (reviewer || role == 'survey_operator')
      ('studio', Icons.image_search_outlined, 'Media Studio', 'মিডিয়া স্টুডিও'),
    if (role == 'survey_operator')
      ('surveys', Icons.flight_outlined, 'Surveys', 'জরিপ'),
    if (reviewer) ('governance', Icons.policy_outlined, 'Governance', 'অনুমতি'),
    ('queue', Icons.sync_outlined, 'Sync queue', 'পাঠানোর তালিকা'),
  ];

  Future<void> _reload() async {
    if (refreshing) return;
    setState(() => refreshing = true);
    try {
      await widget.repository.flushStaffActions();
      if (mounted) {
        setState(() {
          _loadLists();
          refresh++;
        });
      }
    } catch (error) {
      _error(error);
    } finally {
      if (mounted) setState(() => refreshing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget content;
    switch (page) {
      case 'incidents':
        content = _incidents();
      case 'tasks':
        content = OfficialTaskList(
          repository: widget.repository,
          profile: widget.profile,
          bangla: widget.bangla,
          onOpenIncident: _openIncident,
        );
      case 'map':
        content = _map();
      case 'operations':
        content = OperationsLab(bangla: widget.bangla);
      case 'reports':
        content = OfficialReportView(
          repository: widget.repository,
          bangla: widget.bangla,
          onOpenIncident: _openIncident,
        );
      case 'studio':
        content = MediaStudio(
          repository: widget.repository,
          bangla: widget.bangla,
        );
      case 'surveys':
        content = SurveyPage(
          repository: widget.repository,
          bangla: widget.bangla,
        );
      case 'governance':
        content = _governance();
      case 'queue':
        content = StaffQueuePage(
          repository: widget.repository,
          bangla: widget.bangla,
        );
      default:
        content = OfficialOverview(
          repository: widget.repository,
          profile: widget.profile,
          bangla: widget.bangla,
          onNavigate: (value) => setState(() => page = value),
          onOpenIncident: _openIncident,
        );
    }
    final primaryPages = pages
        .where(
          (item) =>
              const [
                'dashboard',
                'incidents',
                'tasks',
                'operations',
                'reports',
                'surveys',
              ].contains(item.$1) ||
              (role == 'survey_operator' && item.$1 == 'studio') ||
              (role == 'field_employee' && item.$1 == 'queue'),
        )
        .toList();
    final primaryIndex = primaryPages.indexWhere((item) => item.$1 == page);
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.bangla
              ? pages.firstWhere((item) => item.$1 == page).$4
              : pages.firstWhere((item) => item.$1 == page).$3,
        ),
        actions: [
          IconButton(
            onPressed: refreshing ? null : _reload,
            tooltip: t('Refresh', 'নতুন করে দেখুন'),
            icon: refreshing
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh),
          ),
        ],
      ),
      drawer: Drawer(
        child: SafeArea(
          child: ListView(
            children: [
              ListTile(
                leading: const Icon(Icons.shield_outlined),
                title: Text(widget.profile['display_name'].toString()),
                subtitle: Text(WorkflowLabels.role(role, widget.bangla)),
              ),
              const Divider(),
              for (final item in pages)
                ListTile(
                  selected: page == item.$1,
                  leading: Icon(item.$2),
                  title: Text(widget.bangla ? item.$4 : item.$3),
                  onTap: () {
                    Navigator.pop(context);
                    setState(() => page = item.$1);
                  },
                ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.logout),
                title: Text(t('Sign out', 'সাইন আউট')),
                onTap: widget.onSignOut,
              ),
            ],
          ),
        ),
      ),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 180),
        child: KeyedSubtree(key: ValueKey('$page-$refresh'), child: content),
      ),
      bottomNavigationBar: primaryIndex < 0 || primaryPages.length < 2
          ? null
          : NavigationBar(
              selectedIndex: primaryIndex,
              onDestinationSelected: (index) =>
                  setState(() => page = primaryPages[index].$1),
              destinations: [
                for (final item in primaryPages)
                  NavigationDestination(
                    icon: Icon(item.$2),
                    label: widget.bangla ? item.$4 : item.$3,
                  ),
              ],
            ),
    );
  }

  Widget _incidents() => FutureBuilder(
    future: incidentData,
    builder: (context, snapshot) {
      if (!snapshot.hasData) return _waiting(snapshot.error);
      final incidents = snapshot.data![0];
      final queue = reviewer ? snapshot.data![1] : <RowData>[];
      final filtered = incidents.where(
        (item) => switch (incidentFilter) {
          'active' => item['status'] != 'resolved',
          'resolved' => item['status'] == 'resolved',
          _ => true,
        },
      );
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (reviewer) ...[
            Text(
              t('Reports awaiting review', 'যাচাইয়ের অপেক্ষায় থাকা প্রতিবেদন'),
              style: Theme.of(context).textTheme.titleLarge,
            ),
            if (queue.isEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    t(
                      'No new reports right now. A public complaint will appear here after submission.',
                      'এখন নতুন প্রতিবেদন নেই। কেউ সমস্যা জানালে সেটি এখানে আসবে।',
                    ),
                  ),
                ),
              ),
            for (final item in queue)
              ObservationReviewCard(
                repository: widget.repository,
                observation: item,
                bangla: widget.bangla,
                onReview: (approve) => _review(item, approve),
              ),
            const Divider(),
          ],
          Text(
            t('Incidents', 'ঘটনা'),
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            children: [
              for (final option in ['active', 'resolved', 'all'])
                ChoiceChip(
                  label: Text(switch (option) {
                    'active' => t('Active', 'চলমান'),
                    'resolved' => t('Completed', 'শেষ'),
                    _ => t('All', 'সব'),
                  }),
                  selected: incidentFilter == option,
                  onSelected: (_) => setState(() => incidentFilter = option),
                ),
            ],
          ),
          if (filtered.isEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  t('No incidents in this view.', 'এই তালিকায় কোনো ঘটনা নেই।'),
                ),
              ),
            ),
          for (final incident in filtered) _incidentTile(incident),
        ],
      );
    },
  );

  Future<void> _review(RowData item, bool approve) async {
    final note = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          approve
              ? t('Verify this report?', 'প্রতিবেদনটি যাচাই করবেন?')
              : t('Do not accept this report?', 'প্রতিবেদনটি গ্রহণ করবেন না?'),
        ),
        content: TextField(
          controller: note,
          maxLength: 1000,
          maxLines: 2,
          decoration: InputDecoration(
            labelText: t('Review note', 'যাচাইয়ের কারণ বা মন্তব্য'),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(t('Cancel', 'ফিরে যান')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, note.text.trim()),
            child: Text(
              approve
                  ? t('Verify', 'যাচাই করুন')
                  : t('Do not accept', 'গ্রহণ করবেন না'),
            ),
          ),
        ],
      ),
    );
    note.dispose();
    if (reason == null) return;
    if (!approve && reason.length < 6) {
      _error(
        t(
          'Add a short reason before rejecting.',
          'গ্রহণ না করার কারণটি সংক্ষেপে লিখুন।',
        ),
      );
      return;
    }
    try {
      bool sent;
      if ((item['source'] ?? 'scenario') == 'scenario') {
        sent = await widget.repository.workflow(
          approve ? 'verify_observation' : 'dismiss_observation',
          target: item['id'].toString(),
          payload: {'note': reason},
        );
      } else {
        sent = await widget.repository.reviewIntake(
          item['id'].toString(),
          approve,
          note: reason,
        );
      }
      if (sent) {
        _error(
          approve
              ? t(
                  'Verified. The incident is now ready for assignment.',
                  'যাচাই হয়েছে। এখন ঘটনায় কর্মী নিয়োগ করা যাবে।',
                )
              : t(
                  'Review decision saved.',
                  'যাচাইয়ের সিদ্ধান্ত সংরক্ষিত হয়েছে।',
                ),
        );
        _reload();
      } else {
        _error(t('Saved for sync when connected.', 'সংযোগ ফিরলে পাঠানো হবে।'));
      }
    } catch (error) {
      _error(error);
    }
  }

  Widget _map() => FutureBuilder<List<RowData>>(
    future: mapData,
    builder: (context, snapshot) {
      if (!snapshot.hasData) return _waiting(snapshot.error);
      final incidents = snapshot.data!;
      return Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Text(
              t(
                'Map tiles need internet. Tap a marker to open an incident.',
                'মানচিত্র দেখতে ইন্টারনেট লাগবে। কোনো চিহ্নে চাপলে ঘটনার বিস্তারিত খুলবে।',
              ),
            ),
          ),
          Expanded(
            child: FlutterMap(
              options: const MapOptions(
                initialCenter: LatLng(23.8073, 90.3683),
                initialZoom: 14,
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'bd.nagarshield.nagar_shield_360',
                ),
                MarkerLayer(
                  markers: [
                    for (final incident in incidents)
                      if (incident['lat'] != null && incident['lng'] != null)
                        Marker(
                          point: LatLng(
                            (incident['lat'] as num).toDouble(),
                            (incident['lng'] as num).toDouble(),
                          ),
                          width: 44,
                          height: 44,
                          child: IconButton(
                            tooltip: incident['code'].toString(),
                            icon: const Icon(
                              Icons.location_on,
                              color: Color(0xFFB44438),
                            ),
                            onPressed: () =>
                                _openIncident(incident['id'].toString()),
                          ),
                        ),
                  ],
                ),
                const RichAttributionWidget(
                  attributions: [
                    TextSourceAttribution('OpenStreetMap contributors'),
                  ],
                ),
              ],
            ),
          ),
          SizedBox(
            height: 130,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                for (final incident in incidents)
                  SizedBox(width: 220, child: _incidentTile(incident)),
              ],
            ),
          ),
        ],
      );
    },
  );

  Widget _governance() => ListView(
    padding: const EdgeInsets.all(16),
    children: [
      _demoBanner(),
      Text(
        t('Who can act', 'কে কী করতে পারেন'),
        style: Theme.of(context).textTheme.titleLarge,
      ),
      ListTile(
        title: Text(t('Executive', 'নির্বাহী কর্মকর্তা')),
        subtitle: Text(
          t(
            'Reviews reports and oversees all demo departments.',
            'প্রতিবেদন যাচাই করেন; সব বিভাগের কাজ দেখতে পারেন।',
          ),
        ),
      ),
      ListTile(
        title: Text(t('Department head', 'বিভাগীয় প্রধান')),
        subtitle: Text(
          t(
            'Reviews and assigns work in the department.',
            'নিজ বিভাগের প্রতিবেদন যাচাই ও কাজ বণ্টন করেন।',
          ),
        ),
      ),
      ListTile(
        title: Text(t('Supervisor', 'তদারককারী')),
        subtitle: Text(
          t(
            'Assigns work in the team and approves completion.',
            'নিজ দলের কাজ দেন এবং শেষ হওয়া কাজ যাচাই করেন।',
          ),
        ),
      ),
      ListTile(
        title: Text(t('Field employee', 'মাঠকর্মী')),
        subtitle: Text(
          t(
            'Accepts assigned tasks and submits after-work evidence.',
            'নিজের কাজ গ্রহণ করেন এবং কাজের পরের প্রমাণ জমা দেন।',
          ),
        ),
      ),
      ListTile(
        title: Text(t('Survey operator', 'জরিপকর্মী')),
        subtitle: Text(
          t(
            'Submits survey observations for official review.',
            'জরিপের তথ্য জমা দেন; সিদ্ধান্ত কর্মকর্তা নেন।',
          ),
        ),
      ),
    ],
  );

  Widget _incidentTile(RowData incident) => Card(
    child: ListTile(
      title: Text(
        '${incident['code']} · ${incident['title_bn']}',
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      isThreeLine: true,
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${incident['area_bn']} · '
            '${WorkflowLabels.department(incident['department_id'].toString(), widget.bangla)}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 5),
          StatusPill(
            status: incident['status'].toString(),
            bangla: widget.bangla,
          ),
        ],
      ),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => _openIncident(incident['id'].toString()),
    ),
  );

  void _openIncident(String id) {
    Navigator.of(context)
        .push(
          MaterialPageRoute<void>(
            builder: (_) => IncidentDetail(
              repository: widget.repository,
              id: id,
              profile: widget.profile,
              bangla: widget.bangla,
            ),
          ),
        )
        .then((_) => _reload());
  }

  Widget _waiting(Object? error) => Center(
    child: error == null
        ? const CircularProgressIndicator()
        : Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.cloud_off_outlined, size: 42),
                const SizedBox(height: 10),
                Text(
                  t(
                    'Could not load shared data. Check the connection and retry.',
                    'তথ্য আনা যায়নি। ইন্টারনেট দেখে আবার চেষ্টা করুন।',
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 6),
                Text(
                  error.toString(),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                TextButton.icon(
                  onPressed: _reload,
                  icon: const Icon(Icons.refresh),
                  label: Text(t('Retry', 'আবার চেষ্টা')),
                ),
              ],
            ),
          ),
  );

  Widget _demoBanner() => Card(
    color: const Color(0xFFFFF2D8),
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Text(
        t(
          'DEMO DATA · Detection and priority values are simulated.',
          'ডেমোর তথ্য · শনাক্তকরণ ও অগ্রাধিকারের স্কোর নমুনা হিসেবে দেখানো হয়েছে।',
        ),
      ),
    ),
  );

  void _error(Object value) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(value.toString())));
  }
}
