import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'operations_map.dart';
import 'preset_media.dart';

/// A local rehearsal of the proposed planning loop. It never writes to Supabase.
/// The real incident and task workflow remains in OfficialPages.
class OperationsLab extends StatefulWidget {
  const OperationsLab({super.key, required this.bangla});

  final bool bangla;

  @override
  State<OperationsLab> createState() => _OperationsLabState();
}

class _OperationsLabState extends State<OperationsLab> {
  static const green = Color(0xFF173F35);
  static const mint = Color(0xFFE8F3E8);
  final ScrollController scrollController = ScrollController();
  Map<String, dynamic>? seed;
  String? loadError;
  int caseIndex = 0;
  int step = 0;
  String? choice;
  bool approved = false;
  bool showFlight = true;
  bool flightPermission = false;
  bool surveyComplete = false;
  bool rain = false;
  bool crisis = false;
  bool resourceReady = true;
  bool watchScheduled = false;
  bool watchAlert = false;
  bool showPublicUpdate = false;
  bool sceneCleared = false;
  int responseModeIndex = 0;
  final Map<String, String> partnerStatuses = {};
  final Set<String> responderAcknowledged = {};
  String? selectedAssetId;
  int? focusTask;
  int mediaIndex = 0;
  final Set<int> assigned = {};
  final Set<int> done = {};
  final Set<int> checked = {};
  final Set<String> usedEvidence = {};

  @override
  void initState() {
    super.initState();
    rootBundle
        .load('assets/operations-seed.json')
        .then((bytes) {
          if (mounted) {
            setState(() {
              seed =
                  jsonDecode(
                        utf8.decode(
                          bytes.buffer.asUint8List(
                            bytes.offsetInBytes,
                            bytes.lengthInBytes,
                          ),
                        ),
                      )
                      as Map<String, dynamic>;
              _resetCase();
            });
          }
        })
        .catchError((Object error) {
          if (mounted) setState(() => loadError = error.toString());
        });
  }

  String t(String en, String bn) => widget.bangla ? bn : en;
  String copy(dynamic value) {
    final text = Map<String, dynamic>.from(value as Map);
    return (text[widget.bangla ? 'bn' : 'en'] ?? '').toString();
  }

  Map<String, dynamic> obj(dynamic value) =>
      Map<String, dynamic>.from(value as Map);
  List<dynamic> list(dynamic value) => List<dynamic>.from(value as List);
  Map<String, dynamic> get current => obj(list(seed!['cases'])[caseIndex]);

  int score(Map<String, dynamic> option) =>
      (((option['reach'] as num) * 4 +
                  (option['safety'] as num) * 3 +
                  (option['recurrence'] as num) * 2 +
                  (option['access'] as num)) *
              2)
          .round();

  int evidenceBoost(String optionId) => list(current['media'])
      .map(obj)
      .where(
        (media) =>
            usedEvidence.contains(media['id']) && media['optionId'] == optionId,
      )
      .fold(0, (total, media) => total + (media['boost'] as num).toInt());

  int recommendationScore(Map<String, dynamic> option) =>
      (score(option) + evidenceBoost(option['id'].toString()))
          .clamp(0, 100)
          .toInt();

  List<Map<String, dynamic>> get ranked {
    final values = list(current['options']).map(obj).toList();
    values.sort(
      (a, b) => recommendationScore(b).compareTo(recommendationScore(a)),
    );
    return values;
  }

  Map<String, dynamic> get selected => ranked.firstWhere(
    (item) => item['id'] == choice,
    orElse: () => ranked.first,
  );

  void _resetCase() {
    step = 0;
    choice = null;
    approved = false;
    showFlight = true;
    flightPermission = false;
    surveyComplete = false;
    rain = false;
    crisis = false;
    resourceReady = true;
    watchScheduled = false;
    watchAlert = false;
    showPublicUpdate = false;
    sceneCleared = false;
    responseModeIndex = 0;
    partnerStatuses.clear();
    responderAcknowledged.clear();
    focusTask = null;
    mediaIndex = 0;
    final item = current;
    selectedAssetId = obj(
      list(obj(item['map'])['assets']).first,
    )['id'].toString();
    usedEvidence
      ..clear()
      ..addAll(
        list(item['media'])
            .map(obj)
            .where((media) => media['initiallyUsed'] == true)
            .map((media) => media['id'].toString()),
      );
    assigned.clear();
    done.clear();
    checked.clear();
  }

  void reset([int? next]) => setState(() {
    caseIndex = next ?? caseIndex;
    _resetCase();
    _scrollTop();
  });

  void _scrollTop() => WidgetsBinding.instance.addPostFrameCallback((_) {
    if (mounted && scrollController.hasClients) scrollController.jumpTo(0);
  });

  @override
  void dispose() {
    scrollController.dispose();
    super.dispose();
  }

  Widget panel(String eyebrow, String title, List<Widget> children) => Card(
    margin: const EdgeInsets.only(bottom: 12),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            eyebrow,
            style: const TextStyle(
              fontSize: 11,
              color: Color(0xFF5A9C70),
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            title,
            style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    ),
  );

  Widget paragraph(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Text(text, style: const TextStyle(height: 1.45)),
  );

  String source(String value) => switch (value) {
    'citizen' => t('Citizen', 'নাগরিক'),
    'camera' => t('Approved CCTV', 'অনুমোদিত CCTV'),
    'drone' => t('Approved drone survey', 'অনুমোদিত ড্রোন জরিপ'),
    'field' => t('Field worker', 'মাঠকর্মী'),
    _ => value,
  };

  @override
  Widget build(BuildContext context) {
    if (loadError != null) return Center(child: Text(loadError!));
    if (seed == null) return const Center(child: CircularProgressIndicator());
    final item = current;
    final allDone = done.length == list(item['tasks']).length;
    final allChecked = checked.length == list(item['verify']).length;
    const stepIcons = [
      Icons.map_outlined,
      Icons.visibility_outlined,
      Icons.account_tree_outlined,
      Icons.groups_outlined,
      Icons.fact_check_outlined,
    ];
    final stepLabels = [
      t('Map & survey', 'মানচিত্র ও জরিপ'),
      t('Observe', 'দেখুন'),
      t('Decide', 'সিদ্ধান্ত'),
      t('Mission', 'কাজ'),
      t('Verify', 'যাচাই'),
    ];

    return ListView(
      controller: scrollController,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: green,
            borderRadius: BorderRadius.circular(17),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                t('CITY OPERATIONS REHEARSAL', 'সিটি অপারেশনের অনুশীলন'),
                style: const TextStyle(
                  color: Color(0xFFC5E9A2),
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                t(
                  'From signals to a verified result',
                  'খবর থেকে যাচাই করা ফল পর্যন্ত',
                ),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 23,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                copy(seed!['notice']),
                style: const TextStyle(color: Color(0xFFD4E7D9), height: 1.4),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Text(
          t('Choose a connected city problem', 'সম্পর্কিত সমস্যা বেছে নিন'),
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 62,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: list(seed!['cases']).length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final option = obj(list(seed!['cases'])[index]);
              return ChoiceChip(
                selected: caseIndex == index,
                label: SizedBox(
                  width: 160,
                  child: Text(copy(option['title']), maxLines: 2),
                ),
                onSelected: (_) => reset(index),
              );
            },
          ),
        ),
        const SizedBox(height: 10),
        Card(
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                height: 145,
                width: double.infinity,
                child: SvgPicture.asset(
                  'assets/presets/${item['image']}.svg',
                  fit: BoxFit.cover,
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${item['code']} · ${copy(item['area'])}',
                      style: const TextStyle(color: Color(0xFF648370)),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      copy(item['title']),
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 5),
                    Text(copy(item['story'])),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 7,
          runSpacing: 7,
          children: [
            for (var index = 0; index < stepLabels.length; index++)
              ChoiceChip(
                avatar: Icon(stepIcons[index], size: 16),
                label: Text('${index + 1}. ${stepLabels[index]}'),
                selected: step == index,
                onSelected: (_) {
                  setState(() => step = index);
                  _scrollTop();
                },
              ),
          ],
        ),
        const SizedBox(height: 14),
        if (step == 0)
          OperationsMap(
            map: obj(item['map']),
            tasks: list(item['tasks']),
            bangla: widget.bangla,
            selectedId: selectedAssetId!,
            onSelect: (value) => setState(() => selectedAssetId = value),
            showFlight: showFlight,
            onFlightToggle: () => setState(() => showFlight = !showFlight),
            permission: flightPermission,
            onPermission: (value) => setState(() {
              flightPermission = value;
              if (!value) surveyComplete = false;
            }),
            surveyComplete: surveyComplete,
            onSurveyComplete: () => setState(() => surveyComplete = true),
            onDraftTask: (index) => setState(() {
              focusTask = index;
              step = 3;
              _scrollTop();
            }),
          ),
        if (step == 1) ...observe(item),
        if (step == 2) ...decide(item),
        if (step == 3) ...mission(item),
        if (step == 4) ...follow(item, allDone, allChecked),
        OutlinedButton.icon(
          onPressed: () => reset(),
          icon: const Icon(Icons.restart_alt),
          label: Text(t('Restart rehearsal', 'অনুশীলন আবার শুরু')),
        ),
      ],
    );
  }

  List<Widget> observe(Map<String, dynamic> item) => [
    mediaReview(item),
    panel(
      t('SOURCE · AGE · LIMIT', 'উৎস · সময় · সীমা'),
      t('One place, several signals', 'এক জায়গা, কয়েকটি খবর'),
      [
        for (final raw in list(item['signals'])) ...[
          Builder(
            builder: (context) {
              final signal = obj(raw);
              return ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const CircleAvatar(
                  child: Icon(Icons.visibility_outlined),
                ),
                title: Text(source(signal['source'].toString())),
                subtitle: Text(
                  '${copy(signal['text'])}\n${copy(signal['limit'])}',
                ),
                trailing: Text(
                  signal['age'].toString(),
                  style: const TextStyle(fontSize: 11),
                ),
              );
            },
          ),
          const Divider(height: 1),
        ],
      ],
    ),
    panel(
      t('REVIEW DUPLICATES', 'একই খবর মিলিয়ে দেখুন'),
      t('Keep the sources', 'উৎসগুলো রেখে দিন'),
      [paragraph(copy(item['duplicate']))],
    ),
    panel(
      t('ILLUSTRATIVE ASSET PATH', 'নমুনা স্থাপনা সংযোগ'),
      t('What connects to what?', 'কোন জায়গা কোথায় যুক্ত?'),
      [
        for (final asset in list(item['assetPath']).asMap().entries)
          ListTile(
            dense: true,
            leading: CircleAvatar(radius: 15, child: Text('${asset.key + 1}')),
            title: Text(asset.value.toString()),
          ),
        paragraph(
          t(
            'Field checks correct this map.',
            'মাঠের তথ্য দিয়ে এই মানচিত্র ঠিক করতে হবে।',
          ),
        ),
      ],
    ),
  ];

  Widget mediaReview(Map<String, dynamic> item) {
    final media = list(item['media']).map(obj).toList();
    final selectedMedia = media[mediaIndex];
    final box = list(selectedMedia['box']);
    return panel(
      t('SAMPLE FOOTAGE · HUMAN REVIEW', 'নমুনা footage · মানুষের যাচাই'),
      t('What does the footage actually show?', 'footage-এ আসলে কী দেখা যায়?'),
      [
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (var index = 0; index < media.length; index++)
              ChoiceChip(
                selected: mediaIndex == index,
                label: Text(
                  '${source(media[index]['source'].toString())} · ${media[index]['age']}',
                ),
                onSelected: (_) => setState(() => mediaIndex = index),
              ),
          ],
        ),
        const SizedBox(height: 9),
        SizedBox(
          height: 210,
          child: LayoutBuilder(
            builder: (context, constraints) => Stack(
              children: [
                Positioned.fill(
                  child: PresetMedia(
                    key: ValueKey(selectedMedia['id']),
                    id: selectedMedia['preset'].toString(),
                    isVideo: selectedMedia['kind'] == 'video',
                    bangla: widget.bangla,
                  ),
                ),
                Positioned(
                  left: (box[0] as num).toDouble() * constraints.maxWidth / 100,
                  top: (box[1] as num).toDouble() * 2.1,
                  width:
                      (box[2] as num).toDouble() * constraints.maxWidth / 100,
                  height: (box[3] as num).toDouble() * 2.1,
                  child: IgnorePointer(
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0x44C4E984),
                        border: Border.all(
                          color: const Color(0xFFC4E984),
                          width: 2,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        paragraph(
          '${t('Sample confidence', 'নমুনা confidence')}: ${((selectedMedia['confidence'] as num) * 100).round()}% · ${selectedMedia['timeRange']}',
        ),
        paragraph(copy(selectedMedia['finding'])),
        paragraph('${t('Limit', 'সীমা')}: ${copy(selectedMedia['limit'])}'),
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          value: usedEvidence.contains(selectedMedia['id']),
          onChanged: (value) => setState(() {
            value == true
                ? usedEvidence.add(selectedMedia['id'].toString())
                : usedEvidence.remove(selectedMedia['id'].toString());
            choice = null;
            approved = false;
            assigned.clear();
            done.clear();
            checked.clear();
          }),
          title: Text(
            t(
              'Use this evidence in the recommendation',
              'এই evidence পরামর্শে ধরুন',
            ),
          ),
        ),
        paragraph(
          t(
            'Boxes and confidence are seeded examples, not live AI inference.',
            'box ও confidence নমুনা; লাইভ AI শনাক্তকরণ নয়।',
          ),
        ),
      ],
    );
  }

  List<Widget> decide(Map<String, dynamic> item) => [
    panel(
      t('HYPOTHESIS · HUMAN CHECK', 'ধারণা · মানুষের যাচাই'),
      copy(item['hypothesis']),
      [
        paragraph(copy(item['reason'])),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: mint,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(copy(item['fieldCheck'])),
        ),
        const SizedBox(height: 9),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF2DF),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            usedEvidence.isEmpty
                ? t(
                    'No footage was accepted. Check the site before setting priority.',
                    'কোনো footage গ্রহণ করা হয়নি। অগ্রাধিকার দেওয়ার আগে মাঠে দেখুন।',
                  )
                : list(item['media'])
                      .map(obj)
                      .any(
                        (media) =>
                            usedEvidence.contains(media['id']) &&
                            (media['confidence'] as num) < .7,
                      )
                ? t(
                    'Some accepted evidence is uncertain or old. Review the limits.',
                    'গ্রহণ করা কিছু evidence অনিশ্চিত বা পুরোনো। সীমা দেখে সিদ্ধান্ত নিন।',
                  )
                : t(
                    'Footage still cannot confirm the root cause without a site check.',
                    'মাঠে না দেখে footage দিয়ে মূল কারণ নিশ্চিত করা যায় না।',
                  ),
          ),
        ),
      ],
    ),
    panel(
      t('EXPLAINED PRIORITY', 'কারণসহ অগ্রাধিকার'),
      t('Where should the team check first?', 'দল আগে কোথায় দেখবে?'),
      [
        paragraph(
          t(
            'Illustrative score: reach 40%, safety 30%, recurrence 20%, access 10%, plus small adjustments from reviewed footage. An officer may override it.',
            'নমুনা তুলনা: প্রভাব ৪০%, নিরাপত্তা ৩০%, পুনরাবৃত্তি ২০%, প্রবেশ ১০%; review করা footage থেকে ছোট পরিবর্তন যোগ হয়। কর্মকর্তা চাইলে বদলাতে পারেন।',
          ),
        ),
        for (final option in ranked)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(
              selected['id'] == option['id']
                  ? Icons.radio_button_checked
                  : Icons.radio_button_unchecked,
              color: const Color(0xFF267956),
            ),
            title: Text(
              '${copy(option['title'])} · ${recommendationScore(option)}/100',
            ),
            subtitle: Text(
              '${copy(option['why'])}\n${t('Base', 'মূল')} ${score(option)} + evidence ${evidenceBoost(option['id'].toString())}',
            ),
            onTap: () => setState(() {
              choice = option['id'].toString();
              approved = false;
              assigned.clear();
              done.clear();
              checked.clear();
            }),
          ),
        const Divider(),
        Text(
          t('Evidence behind this choice', 'এই পছন্দের পেছনের evidence'),
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        for (final raw
            in list(item['media'])
                .map(obj)
                .where(
                  (media) =>
                      usedEvidence.contains(media['id']) &&
                      media['optionId'] == selected['id'],
                ))
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text('+${raw['boost']} · ${copy(raw['finding'])}'),
            subtitle: Text(
              '${source(raw['source'].toString())}: ${copy(raw['limit'])}',
            ),
          ),
        paragraph(
          t(
            'These are reviewable suggestions, not a validated risk model.',
            'এগুলো যাচাইযোগ্য পরামর্শ, যাচাইকৃত risk model নয়।',
          ),
        ),
      ],
    ),
  ];

  List<Widget> mission(Map<String, dynamic> item) => [
    panel(
      t('ONE CASE OWNER', 'একজন মূল দায়িত্বশীল'),
      t('One coordinated mission', 'একটি সমন্বিত কাজ'),
      [
        if (watchAlert)
          Card(
            color: const Color(0xFFFFF3DC),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    t('Possible repeat issue', 'সম্ভাব্য পুনরাবৃত্তি'),
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  Text(copy(obj(item['watch'])['reason'])),
                  Text(
                    t(
                      'This is a new draft. Earlier completion does not prove the current state.',
                      'এটি নতুন খসড়া। আগের সমাপ্তি বর্তমান অবস্থার প্রমাণ নয়।',
                    ),
                  ),
                ],
              ),
            ),
          ),
        if (focusTask != null)
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF3DC),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Text(
              '${t('Selected on map', 'মানচিত্রে বাছা')}: '
              '${copy(obj(list(item['tasks'])[focusTask!])['team'])} · '
              '${copy(obj(list(item['tasks'])[focusTask!])['action'])}',
            ),
          ),
        paragraph('${t('Owner', 'দায়িত্ব')}: ${copy(item['owner'])}'),
        paragraph(
          '${t('First check', 'আগে পরীক্ষা')}: ${copy(selected['title'])}',
        ),
        paragraph(
          '${t('Resources', 'দল ও সরঞ্জাম')}: ${copy(item['resources'])}',
        ),
        paragraph('${t('Route', 'পথ')}: ${copy(item['route'])}'),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(
            '${copy(obj(item['capacity'])['resource'])} '
            '${t('ready (sample)', 'প্রস্তুত (নমুনা)')}',
          ),
          value: resourceReady,
          onChanged: (value) => setState(() {
            resourceReady = value;
            if (!value) {
              final blocked = (obj(item['capacity'])['taskIndex'] as num)
                  .toInt();
              assigned.remove(blocked);
              done.remove(blocked);
              checked.clear();
            }
          }),
        ),
        if (!resourceReady) ...[
          paragraph(copy(obj(item['capacity'])['whenMissing'])),
          paragraph(
            '${t('Alternative', 'বিকল্প')}: '
            '${copy(obj(item['capacity'])['fallback'])}',
          ),
        ],
        FilledButton.icon(
          onPressed: () => setState(() {
            approved = !approved;
            if (!approved) {
              assigned.clear();
              done.clear();
              checked.clear();
            }
          }),
          icon: const Icon(Icons.verified_user_outlined),
          label: Text(
            approved
                ? t('Withdraw rehearsal approval', 'নমুনা অনুমোদন প্রত্যাহার')
                : t('Approve sample mission', 'নমুনা mission অনুমোদন'),
          ),
        ),
        const SizedBox(height: 8),
        paragraph(
          t(
            'This does not assign a real task or write to Supabase.',
            'এতে বাস্তব দায়িত্ব দেওয়া হয় না বা Supabase-এ কিছু লেখা হয় না।',
          ),
        ),
      ],
    ),
    panel(
      t('MAP → ASSIGNMENT → UPDATE', 'মানচিত্র → দায়িত্ব → update'),
      '${assigned.length} ${t('assigned', 'দায়িত্ব দেওয়া')} · ${done.length} ${t('submitted', 'জমা')}',
      [
        for (final entry in list(item['tasks']).asMap().entries)
          Builder(
            builder: (context) {
              final task = obj(entry.value);
              return Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: focusTask == entry.key
                      ? const Color(0xFFFFF3DC)
                      : const Color(0xFFF2F7F1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      copy(task['team']),
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    Text(copy(task['action'])),
                    const SizedBox(height: 8),
                    OutlinedButton(
                      onPressed:
                          approved &&
                              (resourceReady ||
                                  entry.key !=
                                      (obj(item['capacity'])['taskIndex']
                                              as num)
                                          .toInt())
                          ? () => setState(() {
                              if (!assigned.contains(entry.key)) {
                                assigned.add(entry.key);
                              } else if (!done.contains(entry.key)) {
                                done.add(entry.key);
                              } else {
                                done.remove(entry.key);
                                checked.clear();
                              }
                            })
                          : null,
                      child: Text(
                        !resourceReady &&
                                entry.key ==
                                    (obj(item['capacity'])['taskIndex'] as num)
                                        .toInt()
                            ? t(
                                'Resource or permission missing',
                                'সরঞ্জাম বা অনুমতি নেই',
                              )
                            : done.contains(entry.key)
                            ? t('Submitted · reopen', 'জমা · আবার খুলুন')
                            : assigned.contains(entry.key)
                            ? t(
                                'Assigned · submit update',
                                'দেওয়া · update দিন',
                              )
                            : t('Assign sample team', 'নমুনা দলকে দায়িত্ব দিন'),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        paragraph(
          t(
            'Use Incidents and Tasks for the real shared workflow.',
            'বাস্তব shared workflow-এর জন্য ঘটনা ও কাজের পাতা ব্যবহার করুন।',
          ),
        ),
      ],
    ),
    if (item['responseModes'] != null) responseDesk(item),
    coordinationBoard(item),
  ];

  Widget responseDesk(Map<String, dynamic> item) {
    final modes = list(item['responseModes']).map(obj).toList();
    final mode = modes[responseModeIndex];
    final units = list(mode['units']).map(obj).toList();
    final allAcknowledged = units.every(
      (unit) => responderAcknowledged.contains(unit['id'].toString()),
    );
    return panel(
      t('RESPONDER HANDOFF · SAMPLE', 'জরুরি unit handoff · নমুনা'),
      t(
        'Who leads a crash or fire response?',
        'দুর্ঘটনা বা আগুনে কে নেতৃত্ব দেবে?',
      ),
      [
        Wrap(
          spacing: 7,
          children: [
            for (final entry in modes.asMap().entries)
              ChoiceChip(
                label: Text(copy(entry.value['label'])),
                selected: responseModeIndex == entry.key,
                onSelected: (_) => setState(() {
                  responseModeIndex = entry.key;
                  responderAcknowledged.clear();
                  sceneCleared = false;
                }),
              ),
          ],
        ),
        paragraph(
          '${t('Scene lead', 'ঘটনাস্থলের নেতৃত্ব')}: ${copy(mode['lead'])}',
        ),
        paragraph(copy(mode['sceneRule'])),
        paragraph(
          '${t('Safe route', 'নিরাপদ পথ')}: ${copy(mode['safeRoute'])}',
        ),
        paragraph(
          '${t('City role', 'DNCC-এর ভূমিকা')}: ${copy(mode['cityRole'])}',
        ),
        paragraph(
          '${t('Escalation', 'এস্কালেশন')}: ${copy(mode['escalation'])}',
        ),
        Text(
          '${responderAcknowledged.length}/${units.length} '
          '${t('sample acknowledgements', 'নমুনা সাড়া')}',
        ),
        for (final unit in units)
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            value: responderAcknowledged.contains(unit['id'].toString()),
            onChanged: (value) => setState(() {
              final id = unit['id'].toString();
              value == true
                  ? responderAcknowledged.add(id)
                  : responderAcknowledged.remove(id);
              sceneCleared = false;
            }),
            title: Text(copy(unit['name'])),
            subtitle: Text(copy(unit['action'])),
          ),
        FilledButton.tonal(
          onPressed: allAcknowledged && !sceneCleared
              ? () => setState(() => sceneCleared = true)
              : null,
          child: Text(
            sceneCleared
                ? t(
                    'Sample lead clearance recorded',
                    'Lead unit-এর নমুনা clearance নথিভুক্ত',
                  )
                : t(
                    'Record sample scene clearance by lead unit',
                    'Lead unit-এর নমুনা clearance নথিভুক্ত করুন',
                  ),
          ),
        ),
        paragraph(
          t(
            'Acknowledgement is not scene clearance. DNCC resumes its own work only after the incident lead releases the area. No message is sent from this screen.',
            'সাড়া দেওয়া মানেই ঘটনাস্থল নিরাপদ নয়। Incident lead ছাড়ার অনুমতি দেওয়ার পরেই DNCC নিজের কাজ শুরু করবে। এই screen থেকে বার্তা পাঠানো হয় না.',
          ),
        ),
      ],
    );
  }

  Widget coordinationBoard(Map<String, dynamic> item) {
    final coordination = obj(item['coordination']);
    final partners = <Map<String, dynamic>>[
      for (final entry in list(item['tasks']).asMap().entries)
        {
          'id': 'team-${entry.key}',
          'who': obj(entry.value)['team'],
          'action': obj(entry.value)['action'],
        },
      for (final entry in list(coordination['external']).asMap().entries)
        {
          'id': 'external-${entry.key}',
          'who': obj(entry.value)['who'],
          'action': obj(entry.value)['action'],
        },
    ];
    final acknowledged = partners
        .where((partner) => partnerStatuses[partner['id']] == 'acknowledged')
        .length;
    final blocked = partners
        .where((partner) => partnerStatuses[partner['id']] == 'blocked')
        .length;
    return panel(
      t('ONE CASE · SHARED COORDINATION', 'একটি case · সবার সমন্বয়'),
      t('Departments and partners', 'বিভাগ ও অংশীদার'),
      [
        paragraph(
          '${t('Case coordinator', 'সমন্বয়ের দায়িত্ব')}: '
          '${copy(item['owner'])}',
        ),
        paragraph(
          '$acknowledged/${partners.length} '
          '${t('acknowledged', 'সাড়া দিয়েছে')} · $blocked '
          '${t('blocked', 'বাধা')} · '
          '${partners.length - acknowledged - blocked} '
          '${t('waiting', 'অপেক্ষায়')}',
        ),
        for (final partner in partners)
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(copy(partner['who'])),
            subtitle: Text(copy(partner['action'])),
            trailing: DropdownButton<String>(
              value: partnerStatuses[partner['id']] ?? 'waiting',
              items: [
                DropdownMenuItem(
                  value: 'waiting',
                  child: Text(t('Waiting', 'বাকি')),
                ),
                DropdownMenuItem(
                  value: 'acknowledged',
                  child: Text(t('Ack', 'সাড়া')),
                ),
                DropdownMenuItem(
                  value: 'blocked',
                  child: Text(t('Blocked', 'বাধা')),
                ),
              ],
              onChanged: (value) => setState(
                () => partnerStatuses[partner['id'].toString()] =
                    value ?? 'waiting',
              ),
            ),
          ),
        if (blocked > 0 || acknowledged < partners.length)
          paragraph(
            '${t('Escalation', 'এস্কালেশন')}: '
            '${copy(coordination['escalation'])}',
          ),
        OutlinedButton.icon(
          onPressed: () => setState(() => showPublicUpdate = !showPublicUpdate),
          icon: const Icon(Icons.message_outlined),
          label: Text(
            showPublicUpdate
                ? t('Hide citizen update draft', 'নাগরিক update-এর খসড়া লুকান')
                : t(
                    'Preview citizen update draft',
                    'নাগরিক update-এর খসড়া দেখুন',
                  ),
          ),
        ),
        if (showPublicUpdate) ...[
          paragraph(copy(coordination['publicUpdate'])),
          paragraph(
            t(
              'Preview only. An authorized officer sends a verified update through the real incident workflow.',
              'শুধু preview। যাচাই করা update অনুমোদিত কর্মকর্তা বাস্তব incident workflow দিয়ে পাঠাবেন.',
            ),
          ),
        ],
      ],
    );
  }

  List<Widget> follow(
    Map<String, dynamic> item,
    bool allDone,
    bool allChecked,
  ) => [
    panel(
      t('PREVENT · REPRIORITIZE', 'আগে ব্যবস্থা · নতুন অগ্রাধিকার'),
      t('What changed?', 'পরিস্থিতি বদলালে কী করবেন?'),
      [
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(t('Heavy rain forecast', 'ভারী বৃষ্টির পূর্বাভাস')),
          value: rain,
          onChanged: (value) => setState(() => rain = value),
        ),
        if (rain) paragraph(copy(item['prevention'])),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(t('Emergency rehearsal', 'জরুরি অবস্থার অনুশীলন')),
          value: crisis,
          onChanged: (value) => setState(() => crisis = value),
        ),
        if (crisis) ...[
          paragraph(copy(item['crisis'])),
          paragraph(
            t(
              'An officer approves any change to active missions.',
              'চলমান mission বদলালে কর্মকর্তা অনুমোদন করবেন।',
            ),
          ),
        ],
      ],
    ),
    panel(
      t('CHECK THE RESULT', 'ফল যাচাই'),
      t('Completion needs evidence', 'কাজ শেষের প্রমাণ দরকার'),
      [
        for (final entry in list(item['verify']).asMap().entries)
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            value: checked.contains(entry.key),
            onChanged: allDone
                ? (value) => setState(() {
                    if (value == true) {
                      checked.add(entry.key);
                    } else {
                      checked.remove(entry.key);
                      watchScheduled = false;
                    }
                  })
                : null,
            title: Text(copy(entry.value)),
          ),
        paragraph(
          allChecked
              ? t(
                  'Sample result checked. Revisit after rain or at the same busy hour.',
                  'নমুনা ফল যাচাই হয়েছে। বৃষ্টি বা একই ব্যস্ত সময়ে আবার দেখুন।',
                )
              : allDone
              ? t(
                  'Now check the submitted field work.',
                  'এখন মাঠের জমা দেওয়া কাজ যাচাই করুন।',
                )
              : t(
                  'First approve and submit every sample team task.',
                  'আগে নমুনা mission অনুমোদন করে দলের সব কাজ জমা দিন।',
                ),
        ),
      ],
    ),
    panel(
      t('REPEAT-ISSUE WATCH', 'পুনরাবৃত্তি নজরদারি'),
      t('Check beyond the first completion', 'প্রথম সমাপ্তির পরেও দেখুন'),
      [
        paragraph(
          '${t('When', 'কখন')}: ${copy(obj(item['watch'])['trigger'])}',
        ),
        paragraph(
          '${t('Where', 'কোথায়')}: ${copy(obj(item['watch'])['location'])}',
        ),
        paragraph(copy(obj(item['watch'])['reason'])),
        FilledButton.tonal(
          onPressed: allChecked && !watchScheduled
              ? () => setState(() => watchScheduled = true)
              : null,
          child: Text(
            watchScheduled
                ? t('Sample follow-up scheduled', 'নমুনা follow-up নির্ধারিত')
                : t('Schedule sample follow-up', 'নমুনা follow-up নির্ধারণ'),
          ),
        ),
        if (watchScheduled) ...[
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: () => setState(() {
              watchAlert = true;
              watchScheduled = false;
              focusTask = (obj(item['watch'])['taskIndex'] as num).toInt();
              approved = false;
              assigned.clear();
              done.clear();
              checked.clear();
              step = 3;
              _scrollTop();
            }),
            child: Text(
              t(
                'Rehearse a repeat issue nearby',
                'পাশে পুনরাবৃত্তির সংকেত অনুশীলন',
              ),
            ),
          ),
        ],
        paragraph(
          t(
            'No real reminder or task is created here.',
            'এখানে বাস্তব reminder বা কাজ তৈরি হয় না।',
          ),
        ),
      ],
    ),
    panel(
      t('PILOT OWNERSHIP', 'পাইলটের দায়িত্ব'),
      t('Who handles the difficult parts?', 'কঠিন বিষয়গুলো কে সামলাবে?'),
      [
        for (final raw in list(seed!['stakeholders'])) ...[
          Builder(
            builder: (context) {
              final partner = obj(raw);
              return ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(copy(partner['who'])),
                subtitle: Text(
                  '${copy(partner['challenge'])}\n${copy(partner['response'])}',
                ),
              );
            },
          ),
          const Divider(height: 1),
        ],
      ],
    ),
  ];
}
