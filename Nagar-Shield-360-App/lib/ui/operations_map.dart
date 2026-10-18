import 'package:flutter/material.dart';

class OperationsMap extends StatelessWidget {
  const OperationsMap({
    super.key,
    required this.map,
    required this.tasks,
    required this.bangla,
    required this.selectedId,
    required this.onSelect,
    required this.showFlight,
    required this.onFlightToggle,
    required this.permission,
    required this.onPermission,
    required this.surveyComplete,
    required this.onSurveyComplete,
    required this.onDraftTask,
  });

  final Map<String, dynamic> map;
  final List<dynamic> tasks;
  final bool bangla;
  final String selectedId;
  final ValueChanged<String> onSelect;
  final bool showFlight;
  final VoidCallback onFlightToggle;
  final bool permission;
  final ValueChanged<bool> onPermission;
  final bool surveyComplete;
  final VoidCallback onSurveyComplete;
  final ValueChanged<int> onDraftTask;

  Map<String, dynamic> obj(dynamic value) =>
      Map<String, dynamic>.from(value as Map);
  List<dynamic> list(dynamic value) => List<dynamic>.from(value as List);
  String copy(dynamic value) {
    final text = obj(value);
    return (text[bangla ? 'bn' : 'en'] ?? '').toString();
  }

  String t(String en, String bn) => bangla ? bn : en;

  @override
  Widget build(BuildContext context) {
    final assets = list(map['assets']).map(obj).toList();
    final selected = assets.firstWhere(
      (asset) => asset['id'] == selectedId,
      orElse: () => assets.first,
    );
    final survey = obj(map['survey']);
    final blindSpot = obj(map['blindSpot']);
    final task = obj(tasks[(selected['taskIndex'] as num).toInt()]);
    final trace = <Map<String, dynamic>>[selected];
    final visited = <String>{selected['id'].toString()};
    var cursor = selected;
    while (true) {
      final nextId = (cursor['downstreamId'] ?? cursor['downstream'])
          .toString();
      final matches = assets.where((asset) => asset['id'] == nextId);
      if (matches.isEmpty || visited.contains(nextId)) break;
      cursor = matches.first;
      trace.add(cursor);
      visited.add(nextId);
    }
    final terminal = cursor['downstream'] == '—'
        ? ''
        : cursor['downstream'].toString();
    return Column(
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  copy(map['label']),
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 6),
                Text(
                  t(
                    'Illustrative ward map, not surveyed coordinates',
                    'নমুনা ওয়ার্ড মানচিত্র, জরিপ করা স্থানাঙ্ক নয়',
                  ),
                ),
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: SizedBox(
                    height: 320,
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final width = constraints.maxWidth;
                        return Stack(
                          children: [
                            Positioned.fill(
                              child: CustomPaint(
                                painter: _WardMapPainter(
                                  map,
                                  showFlight,
                                  trace,
                                ),
                              ),
                            ),
                            for (final raw in list(map['cameras']))
                              Builder(
                                builder: (context) {
                                  final point = list(raw);
                                  return Positioned(
                                    left:
                                        (point[0] as num).toDouble() *
                                            width /
                                            100 -
                                        12,
                                    top:
                                        (point[1] as num).toDouble() * 3.2 - 12,
                                    child: const CircleAvatar(
                                      radius: 12,
                                      backgroundColor: Color(0xFF59436D),
                                      child: Icon(
                                        Icons.videocam_outlined,
                                        size: 14,
                                        color: Colors.white,
                                      ),
                                    ),
                                  );
                                },
                              ),
                            for (final asset in assets)
                              Positioned(
                                left:
                                    (asset['x'] as num).toDouble() *
                                        width /
                                        100 -
                                    23,
                                top: (asset['y'] as num).toDouble() * 3.2 - 23,
                                child: Tooltip(
                                  message:
                                      '${asset['id']} · ${copy(asset['label'])}',
                                  child: IconButton.filledTonal(
                                    onPressed: () =>
                                        onSelect(asset['id'].toString()),
                                    icon: Icon(
                                      selected['id'] == asset['id']
                                          ? Icons.location_on
                                          : Icons.circle,
                                      size: 20,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        );
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 10,
                  runSpacing: 5,
                  children: [
                    Text(t('Blue: drain flow', 'নীল: ড্রেনের প্রবাহ')),
                    Text(t('Green: survey area', 'সবুজ: জরিপ এলাকা')),
                    Text(t('Purple: CCTV', 'বেগুনি: CCTV')),
                    Text(
                      t(
                        'Orange: possible blind area and asset link',
                        'কমলা: সম্ভাব্য আড়াল ও স্থাপনা সংযোগ',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  t(
                    'A field engineer must confirm the real connections.',
                    'প্রকৃত সংযোগ মাঠের প্রকৌশলী নিশ্চিত করবেন।',
                  ),
                ),
              ],
            ),
          ),
        ),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${selected['id']} · ${copy(selected['label'])}',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  '${t('Next connection', 'পরের সংযোগ')}: ${selected['downstream']}',
                ),
                Text(
                  '${t('Connected path', 'সংযুক্ত পথ')}: '
                  '${trace.map((asset) => asset['id']).join(' → ')}'
                  '${terminal.isEmpty ? '' : ' → $terminal'}',
                ),
                Text(
                  t(
                    'This is a lead for inspection, not a confirmed cause.',
                    'এটি পরীক্ষার ইঙ্গিত, নিশ্চিত কারণ নয়।',
                  ),
                ),
                Text(
                  '${t('Suggested team', 'প্রস্তাবিত দল')}: ${copy(task['team'])}',
                ),
                const SizedBox(height: 10),
                FilledButton.icon(
                  onPressed: () =>
                      onDraftTask((selected['taskIndex'] as num).toInt()),
                  icon: const Icon(Icons.assignment_outlined),
                  label: Text(
                    t(
                      'Draft work from this map point',
                      'এই স্থাপনা থেকে কাজের খসড়া',
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  t(
                    'This opens a sample mission, not a real assignment.',
                    'এটি নমুনা mission খুলবে, বাস্তব দায়িত্ব নয়।',
                  ),
                ),
              ],
            ),
          ),
        ),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  t('What the cameras cannot see', 'ক্যামেরায় যা দেখা যায় না'),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  copy(blindSpot['label']),
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                Text(copy(blindSpot['reason'])),
                const SizedBox(height: 8),
                FilledButton.tonalIcon(
                  onPressed: () =>
                      onDraftTask((blindSpot['taskIndex'] as num).toInt()),
                  icon: const Icon(Icons.visibility_off_outlined),
                  label: Text(
                    t(
                      'Draft a field check for this blind area',
                      'আড়ালের জায়গায় মাঠ যাচাইয়ের খসড়া',
                    ),
                  ),
                ),
                Text(
                  t(
                    'Orange area is approximate, not surveyed camera coverage.',
                    'কমলা এলাকা আনুমানিক; camera coverage জরিপ করা নয়।',
                  ),
                ),
              ],
            ),
          ),
        ),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  t(
                    'Approved drone survey plan',
                    'অনুমোদনসাপেক্ষ ড্রোন জরিপ পরিকল্পনা',
                  ),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Text(copy(survey['scope'])),
                const SizedBox(height: 5),
                Text(
                  t(
                    '${list(map['cameras']).length} sample camera points cannot cover every hidden area. Use approved survey or a field visit for blind spots.',
                    '${list(map['cameras']).length}টি নমুনা camera point আড়ালের সব জায়গা দেখে না। জরিপ বা মাঠ পরিদর্শন দরকার।',
                  ),
                ),
                const SizedBox(height: 5),
                Text(copy(survey['permission'])),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: showFlight,
                  onChanged: (_) => onFlightToggle(),
                  title: Text(
                    t('Show sample flight path', 'নমুনা উড্ডয়ন পথ দেখান'),
                  ),
                ),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: permission,
                  onChanged: (value) => onPermission(value ?? false),
                  title: Text(
                    t(
                      'Permissions reviewed (sample)',
                      'অনুমতি যাচাই হয়েছে (নমুনা)',
                    ),
                  ),
                ),
                FilledButton.tonalIcon(
                  onPressed: permission && !surveyComplete
                      ? onSurveyComplete
                      : null,
                  icon: const Icon(Icons.flight_outlined),
                  label: Text(
                    surveyComplete
                        ? t('Sample survey logged', 'নমুনা জরিপ নথিভুক্ত')
                        : t(
                            'Mark sample survey complete',
                            'নমুনা জরিপ সম্পন্ন দেখান',
                          ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  t(
                    'No hardware is controlled from this screen.',
                    'এই screen থেকে কোনো ড্রোন চালানো হয় না।',
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _WardMapPainter extends CustomPainter {
  const _WardMapPainter(this.map, this.showFlight, this.trace);
  final Map<String, dynamic> map;
  final bool showFlight;
  final List<Map<String, dynamic>> trace;

  List<dynamic> list(dynamic value) => List<dynamic>.from(value as List);
  Map<String, dynamic> obj(dynamic value) =>
      Map<String, dynamic>.from(value as Map);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 100, size.height / 100);
    canvas.drawRect(
      const Rect.fromLTWH(0, 0, 100, 100),
      Paint()..color = const Color(0xFFE8F1E8),
    );
    for (final raw in list(map['buildings'])) {
      final rect = list(raw);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(
            (rect[0] as num).toDouble(),
            (rect[1] as num).toDouble(),
            (rect[2] as num).toDouble(),
            (rect[3] as num).toDouble(),
          ),
          const Radius.circular(1),
        ),
        Paint()..color = const Color(0xFFCBDACB),
      );
    }
    for (final raw in list(map['roads'])) {
      _line(canvas, list(raw), const Color(0xFFFFFFFF), 7);
    }
    for (final raw in list(map['drains'])) {
      _line(canvas, list(obj(raw)['points']), const Color(0xFF438DAF), 1.6);
    }
    final blind = obj(map['blindSpot']);
    final blindPath = Path();
    for (final entry in list(blind['polygon']).asMap().entries) {
      final point = list(entry.value);
      final x = (point[0] as num).toDouble();
      final y = (point[1] as num).toDouble();
      entry.key == 0 ? blindPath.moveTo(x, y) : blindPath.lineTo(x, y);
    }
    blindPath.close();
    canvas.drawPath(blindPath, Paint()..color = const Color(0x55D97745));
    canvas.drawPath(
      blindPath,
      Paint()
        ..color = const Color(0xFFB75636)
        ..style = PaintingStyle.stroke
        ..strokeWidth = .8,
    );
    if (trace.length > 1) {
      _line(
        canvas,
        trace.map((asset) => [asset['x'], asset['y']]).toList(),
        const Color(0xFFBD6237),
        1.5,
      );
    }
    if (showFlight) {
      final survey = obj(map['survey']);
      final polygon = Path();
      final vertices = list(survey['polygon']);
      for (var index = 0; index < vertices.length; index++) {
        final point = list(vertices[index]);
        final x = (point[0] as num).toDouble();
        final y = (point[1] as num).toDouble();
        index == 0 ? polygon.moveTo(x, y) : polygon.lineTo(x, y);
      }
      polygon.close();
      canvas.drawPath(polygon, Paint()..color = const Color(0x5578B881));
      canvas.drawPath(
        polygon,
        Paint()
          ..color = const Color(0xFF4E9A68)
          ..style = PaintingStyle.stroke
          ..strokeWidth = .7,
      );
      _line(canvas, list(survey['route']), const Color(0xFFE4AA42), 1);
      final launch = list(survey['launch']);
      canvas.drawCircle(
        Offset((launch[0] as num).toDouble(), (launch[1] as num).toDouble()),
        2,
        Paint()..color = const Color(0xFFDF9030),
      );
    }
    canvas.restore();
  }

  void _line(Canvas canvas, List<dynamic> points, Color color, double width) {
    final path = Path();
    for (var index = 0; index < points.length; index++) {
      final point = list(points[index]);
      final x = (point[0] as num).toDouble();
      final y = (point[1] as num).toDouble();
      index == 0 ? path.moveTo(x, y) : path.lineTo(x, y);
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = width
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(covariant _WardMapPainter oldDelegate) =>
      oldDelegate.map != map ||
      oldDelegate.showFlight != showFlight ||
      oldDelegate.trace.first['id'] != trace.first['id'];
}
