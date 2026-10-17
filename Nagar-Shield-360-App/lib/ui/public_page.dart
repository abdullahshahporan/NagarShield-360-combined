import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

import '../app_config.dart';
import '../nagar_repository.dart';
import 'notice.dart';
import 'public_status_card.dart';
import 'photo_privacy_page.dart';

class PublicPage extends StatefulWidget {
  const PublicPage({
    super.key,
    required this.repository,
    required this.bangla,
    this.demoSlot,
    required this.onBack,
  });
  final NagarRepository repository;
  final bool bangla;
  final String? demoSlot;
  final VoidCallback onBack;

  @override
  State<PublicPage> createState() => _PublicPageState();
}

class _PublicPageState extends State<PublicPage> {
  final title = TextEditingController();
  final details = TextEditingController();
  final area = TextEditingController();
  final lat = TextEditingController();
  final lng = TextEditingController();
  final selected = <String>{};
  String precision = 'approximate';
  String? imagePath;
  bool imageProtected = false;
  bool pickingPhoto = false;
  bool consent = false;
  bool busy = false;
  bool tracking = false;
  String? message;
  List<RowData> local = [];
  List<RowData> remote = [];
  Timer? draftTimer;
  bool restoringDraft = true;

  static const categories = {
    'DRAIN_OBSTRUCTION': ['Drain problem', 'ড্রেনের সমস্যা'],
    'STANDING_WATER': ['Standing water', 'জমে থাকা পানি'],
    'WASTE': ['Waste', 'বর্জ্য'],
    'FOOTPATH_OBSTRUCTION': ['Footpath access', 'ফুটপাতে বাধা'],
    'ACCESS_OBSTRUCTION': ['Drain access', 'ড্রেনে প্রবেশে বাধা'],
    'WATER_CONTAINER': ['Water container', 'পানি জমার পাত্র'],
  };

  @override
  void initState() {
    super.initState();
    for (final controller in [title, details, area, lat, lng]) {
      controller.addListener(_scheduleDraft);
    }
    _restoreDraft();
    _load();
  }

  Future<void> _restoreDraft() async {
    final draft = await widget.repository.publicDraft();
    if (!mounted) return;
    if (draft != null) {
      title.text = draft['title']?.toString() ?? '';
      details.text = draft['details']?.toString() ?? '';
      area.text = draft['area']?.toString() ?? '';
      lat.text = draft['lat']?.toString() ?? '';
      lng.text = draft['lng']?.toString() ?? '';
      final categories = draft['categories'];
      if (categories is List) selected.addAll(categories.cast<String>());
      precision = draft['precision']?.toString() ?? 'approximate';
      consent = draft['consent'] == true;
      final path = draft['image_path']?.toString();
      imagePath = path != null && await File(path).exists() ? path : null;
      imageProtected = draft['photo_protection'] == 1;
    }
    if (!mounted) return;
    restoringDraft = false;
    setState(() {});
  }

  void _scheduleDraft() {
    if (restoringDraft) return;
    draftTimer?.cancel();
    draftTimer = Timer(const Duration(milliseconds: 300), _persistDraft);
  }

  Future<void> _persistDraft() => widget.repository.savePublicDraft({
    'title': title.text,
    'details': details.text,
    'area': area.text,
    'lat': lat.text,
    'lng': lng.text,
    'categories': selected.toList(),
    'precision': precision,
    'consent': consent,
    'image_path': imagePath,
    'photo_protection': imageProtected ? 1 : 0,
  });

  bool get _hasDraftContent =>
      title.text.isNotEmpty ||
      details.text.isNotEmpty ||
      area.text.isNotEmpty ||
      lat.text.isNotEmpty ||
      lng.text.isNotEmpty ||
      selected.isNotEmpty ||
      imagePath != null;

  Future<void> _load() async {
    final a = await widget.repository.localReports();
    final b = await widget.repository.publicReportStatuses();
    if (mounted) {
      setState(() {
        local = a;
        remote = b;
      });
    }
  }

  String t(String en, String bn) => widget.bangla ? bn : en;

  Future<void> _gps() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        throw StateError(
          t('Turn on location services.', 'অবস্থান সেবা চালু করুন।'),
        );
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        throw StateError(
          t(
            'Location permission denied. Enter coordinates.',
            'অবস্থানের অনুমতি নেই। স্থানাঙ্ক লিখুন।',
          ),
        );
      }
      final position = await Geolocator.getCurrentPosition();
      lat.text = position.latitude.toStringAsFixed(6);
      lng.text = position.longitude.toStringAsFixed(6);
      if (mounted) setState(() => message = null);
    } catch (error) {
      if (mounted) setState(() => message = error.toString());
    }
  }

  Future<void> _photo() async {
    if (pickingPhoto || busy) return;
    setState(() => pickingPhoto = true);
    try {
      final picked = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 85,
      );
      if (picked == null || !mounted) return;
      final protected = await reviewProtectedPhoto(
        context,
        picked.path,
        bangla: widget.bangla,
      );
      if (protected == null || !mounted) return;
      final root = await getApplicationDocumentsDirectory();
      final folder = Directory('${root.path}/report_draft');
      await folder.create(recursive: true);
      final stored = await File(protected).copy(
        '${folder.path}/protected-${DateTime.now().microsecondsSinceEpoch}.jpg',
      );
      await File(protected).delete();
      if (!mounted) return;
      setState(() {
        imagePath = stored.path;
        imageProtected = true;
      });
      _scheduleDraft();
    } catch (_) {
      if (mounted) {
        setState(
          () => message = t(
            'Could not attach the protected photo. Try another photo.',
            'ঢাকা ছবিটি যোগ হয়নি। অন্য ছবি নিন।',
          ),
        );
      }
    } finally {
      if (mounted) setState(() => pickingPhoto = false);
    }
  }

  Future<void> _submit() async {
    if (busy || pickingPhoto) return;
    if (imagePath != null && !imageProtected) {
      setState(() => pickingPhoto = true);
      try {
        final safe = await reviewProtectedPhoto(
          context,
          imagePath!,
          bangla: widget.bangla,
        );
        if (safe == null || !mounted) return;
        final root = await getApplicationDocumentsDirectory();
        final folder = Directory('${root.path}/report_draft');
        await folder.create(recursive: true);
        final stored = await File(safe).copy(
          '${folder.path}/protected-${DateTime.now().microsecondsSinceEpoch}.jpg',
        );
        await File(safe).delete();
        if (!mounted) return;
        setState(() {
          imagePath = stored.path;
          imageProtected = true;
        });
        await _persistDraft();
      } catch (_) {
        if (mounted) {
          setState(
            () => message = t(
              'Could not save the protected photo. Please try again.',
              'ঢাকা ছবিটি সংরক্ষণ হয়নি। আবার চেষ্টা করুন।',
            ),
          );
        }
        return;
      } finally {
        if (mounted) setState(() => pickingPhoto = false);
      }
      if (!mounted) return;
    }
    if (!consent) {
      setState(
        () => message = t(
          'Please accept the privacy notice.',
          'গোপনীয়তা নির্দেশনা মেনে নিন।',
        ),
      );
      return;
    }
    final latitude = double.tryParse(lat.text.trim());
    final longitude = double.tryParse(lng.text.trim());
    if (latitude == null ||
        longitude == null ||
        latitude < -90 ||
        latitude > 90 ||
        longitude < -180 ||
        longitude > 180) {
      setState(
        () => message = t('Enter a valid location.', 'সঠিক অবস্থান দিন।'),
      );
      return;
    }
    setState(() {
      busy = true;
      message = null;
    });
    try {
      await widget.repository.queuePublicReport(
        title: title.text,
        description: details.text,
        categories: selected.toList(),
        area: area.text,
        lat: latitude,
        lng: longitude,
        precision: precision,
        imagePath: imagePath,
      );
      draftTimer?.cancel();
      restoringDraft = true;
      await widget.repository.clearPublicDraft();
      title.clear();
      details.clear();
      area.clear();
      lat.clear();
      lng.clear();
      selected.clear();
      imagePath = null;
      imageProtected = false;
      consent = false;
      restoringDraft = false;
      await widget.repository.flushReports();
      await _load();
      if (mounted) {
        setState(() {
          tracking = true;
          message = t(
            'Saved. Check whether it is queued or submitted below.',
            'সংরক্ষিত হয়েছে। নিচে জমা বা অপেক্ষার অবস্থা দেখুন।',
          );
        });
      }
    } catch (error) {
      if (mounted) setState(() => message = error.toString());
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  void dispose() {
    draftTimer?.cancel();
    if (!restoringDraft && _hasDraftContent) unawaited(_persistDraft());
    title.dispose();
    details.dispose();
    area.dispose();
    lat.dispose();
    lng.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(
        tracking
            ? t('My reports', 'আমার প্রতিবেদন')
            : t('Report a problem', 'সমস্যা জানান'),
      ),
      leading: BackButton(onPressed: widget.onBack),
      actions: [
        TextButton(
          onPressed: () async {
            setState(() => tracking = !tracking);
            await _load();
          },
          child: Text(
            tracking
                ? t('New report', 'নতুন')
                : t('My reports', 'আমার প্রতিবেদন'),
          ),
        ),
      ],
    ),
    body: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (AppConfig.hasPublicDemoIdentity)
          Notice(
            t(
              'DEMO CITIZEN ${widget.demoSlot ?? AppConfig.publicDemoSlot} · Use a different letter on another test phone. Devices with the same letter share report history.',
              'ডেমো নাগরিক ${widget.demoSlot ?? AppConfig.publicDemoSlot} · অন্য পরীক্ষার ফোনে আলাদা অক্ষর বেছে নিন। একই অক্ষর নিলে প্রতিবেদনের তালিকাও একই হবে।',
            ),
          ),
        ...tracking ? _trackingWidgets() : _reportWidgets(),
      ],
    ),
  );

  List<Widget> _trackingWidgets() => [
    if (message != null) Notice(message!),
    FilledButton.icon(
      onPressed: busy
          ? null
          : () async {
              setState(() => busy = true);
              await widget.repository.flushReports();
              await _load();
              if (mounted) setState(() => busy = false);
            },
      icon: const Icon(Icons.sync),
      label: Text(t('Retry queued reports', 'অপেক্ষার প্রতিবেদন পাঠান')),
    ),
    const SizedBox(height: 12),
    for (final row in local)
      PublicStatusCard(
        report:
            remote
                .where((item) => item['id'] == row['remote_id'])
                .firstOrNull ??
            {'title': row['title'], 'status': row['status']},
        bangla: widget.bangla,
      ),
    if (remote.isNotEmpty) ...[
      const Divider(),
      Text(
        t('Shared status', 'প্রতিবেদনের সর্বশেষ অবস্থা'),
        style: Theme.of(context).textTheme.titleMedium,
      ),
      for (final row in remote)
        if (!local.any((item) => item['remote_id'] == row['id']))
          PublicStatusCard(report: row, bangla: widget.bangla),
    ],
  ];

  List<Widget> _reportWidgets() => [
    if (message != null) Notice(message!),
    Text(
      t(
        'Choose every issue visible at this location.',
        'এই স্থানের সব দৃশ্যমান সমস্যা নির্বাচন করুন।',
      ),
    ),
    const SizedBox(height: 8),
    Wrap(
      spacing: 7,
      children: [
        for (final entry in categories.entries)
          FilterChip(
            label: Text(entry.value[widget.bangla ? 1 : 0]),
            selected: selected.contains(entry.key),
            onSelected: (value) {
              setState(() {
                value ? selected.add(entry.key) : selected.remove(entry.key);
              });
              _scheduleDraft();
            },
          ),
      ],
    ),
    const SizedBox(height: 12),
    TextField(
      controller: title,
      maxLength: 120,
      decoration: InputDecoration(
        labelText: t('Short title', 'সংক্ষিপ্ত শিরোনাম'),
        border: const OutlineInputBorder(),
      ),
    ),
    const SizedBox(height: 8),
    TextField(
      controller: details,
      maxLines: 3,
      maxLength: 2000,
      decoration: InputDecoration(
        labelText: t(
          'Details or reason for no photo',
          'বিবরণ অথবা ছবি না দেওয়ার কারণ',
        ),
        border: const OutlineInputBorder(),
      ),
    ),
    OutlinedButton.icon(
      onPressed: busy || pickingPhoto ? null : _photo,
      icon: const Icon(Icons.photo_library_outlined),
      label: Text(
        imagePath == null
            ? t('Add photo (optional)', 'ছবি যোগ করুন (ঐচ্ছিক)')
            : t('Photo selected', 'ছবি নির্বাচিত'),
      ),
    ),
    if (imagePath != null) ...[
      const SizedBox(height: 8),
      ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.file(
          File(imagePath!),
          height: 180,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) =>
              Text(t('Photo preview unavailable', 'ছবির পূর্বরূপ পাওয়া যায়নি')),
        ),
      ),
      Text(
        t(
          'Content checked. Faces and recognized text protected on this phone. Review for anything missed before sharing.',
          'বিষয়বস্তু পরীক্ষা হয়েছে। ফোনেই মুখ ও শনাক্ত লেখা ঢাকা হয়েছে। বাদ পড়া ব্যক্তিগত অংশ আছে কি না দেখে নিন।',
        ),
      ),
      TextButton(
        onPressed: () {
          setState(() {
            imagePath = null;
            imageProtected = false;
          });
          _scheduleDraft();
        },
        child: Text(t('Remove photo', 'ছবি বাদ দিন')),
      ),
    ],
    const SizedBox(height: 12),
    TextField(
      controller: area,
      decoration: InputDecoration(
        labelText: t('Landmark or area', 'এলাকা বা পরিচিত স্থান'),
        border: const OutlineInputBorder(),
      ),
    ),
    const SizedBox(height: 12),
    OutlinedButton.icon(
      onPressed: _gps,
      icon: const Icon(Icons.my_location),
      label: Text(t('Use current location', 'বর্তমান অবস্থান নিন')),
    ),
    const SizedBox(height: 8),
    Row(
      children: [
        Expanded(
          child: TextField(
            controller: lat,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Latitude',
              border: OutlineInputBorder(),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: TextField(
            controller: lng,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Longitude',
              border: OutlineInputBorder(),
            ),
          ),
        ),
      ],
    ),
    DropdownButtonFormField<String>(
      initialValue: precision,
      items: [
        DropdownMenuItem(
          value: 'approximate',
          child: Text(t('Approximate location', 'আনুমানিক অবস্থান')),
        ),
        DropdownMenuItem(
          value: 'exact',
          child: Text(t('Exact location', 'সঠিক অবস্থান')),
        ),
      ],
      onChanged: (value) {
        setState(() => precision = value!);
        _scheduleDraft();
      },
    ),
    const SizedBox(height: 16),
    CheckboxListTile(
      value: consent,
      onChanged: (value) {
        setState(() => consent = value ?? false);
        _scheduleDraft();
      },
      title: Text(
        t(
          'Staff may review this report. Avoid private interiors and identifiable people.',
          'কর্মকর্তারা এই প্রতিবেদন দেখবেন। ছবিতে কারও মুখ বা ব্যক্তিগত জায়গা যেন না থাকে।',
        ),
      ),
    ),
    FilledButton(
      onPressed: busy ? null : _submit,
      child: Text(
        busy
            ? t('Saving…', 'সংরক্ষণ হচ্ছে…')
            : t('Submit report', 'প্রতিবেদন জমা দিন'),
      ),
    ),
    const SizedBox(height: 8),
    Text(
      t(
        'Offline reports stay on this device until a shared connection succeeds.',
        'ইন্টারনেট না থাকলে প্রতিবেদন এই ফোনে থাকবে। সংযোগ ফিরলে পাঠানো হবে।',
      ),
      style: Theme.of(context).textTheme.bodySmall,
    ),
  ];
}
