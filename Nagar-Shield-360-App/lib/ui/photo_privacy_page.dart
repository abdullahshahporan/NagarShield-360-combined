import 'dart:io';

import 'package:flutter/material.dart';

import '../photo_privacy.dart';

Future<String?> reviewProtectedPhoto(
  BuildContext context,
  String path, {
  required bool bangla,
}) => Navigator.of(context).push<String>(
  MaterialPageRoute(
    builder: (_) => PhotoPrivacyPage(path: path, bangla: bangla),
  ),
);

class PhotoPrivacyPage extends StatefulWidget {
  const PhotoPrivacyPage({
    super.key,
    required this.path,
    required this.bangla,
    this.privacy,
  });
  final String path;
  final bool bangla;
  final PhotoPrivacy? privacy;
  @override
  State<PhotoPrivacyPage> createState() => _PhotoPrivacyPageState();
}

class _PhotoPrivacyPageState extends State<PhotoPrivacyPage> {
  late final engine = widget.privacy ?? PhotoPrivacy();
  final masks = <Rect>[];
  final generated = <String>{};
  ProtectedPhoto? photo;
  Offset? start;
  Offset? end;
  bool working = true;
  bool confirmed = false;
  String? error;

  String t(String en, String bn) => widget.bangla ? bn : en;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _prepare();
    });
  }

  Future<void> _prepare() async {
    try {
      final next = await engine.protect(
        widget.path,
        confirmExplicit: (_) => _confirmExplicit(),
      );
      if (!mounted) {
        await _delete(next.path);
        return;
      }
      generated.add(next.path);
      setState(() {
        photo = next;
        working = false;
      });
    } on PhotoProtectionException catch (e) {
      if (!mounted) return;
      if (e.declined) {
        Navigator.pop(context);
        return;
      }
      setState(() {
        working = false;
        error = t(
          'The photo could not be checked. Choose another photo. The original has not been attached.',
          'ছবিটি পরীক্ষা করা যায়নি। অন্য ছবি নিন। মূল ছবিটি যুক্ত করা হয়নি।',
        );
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          working = false;
          error = t(
            'Photo checks failed. Choose another photo; the original was not attached.',
            'ছবি পরীক্ষা সম্পন্ন হয়নি। অন্য ছবি নিন; মূল ছবিটি যুক্ত করা হয়নি।',
          );
        });
      }
    }
  }

  Future<bool> _confirmExplicit() async {
    if (!mounted) return false;
    setState(() => working = false);
    final consent = await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (dialogContext) => AlertDialog(
            title: Text(t('Send this image?', 'এই ছবিটি পাঠাতে চান?')),
            content: Text(
              t(
                'This image may contain nudity or explicit content. Are you sure you want to include it in your report? It will not be blurred or blocked because of this warning.',
                'এই ছবিতে নগ্নতা বা অশোভন বিষয়বস্তু থাকতে পারে। আপনি কি নিশ্চিত ছবিটি প্রতিবেদনে দিতে চান? এই সতর্কতার কারণে ছবিটি ঝাপসা বা বন্ধ করা হবে না।',
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: Text(t('No, choose another', 'না, অন্য ছবি')),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: Text(t('Yes, continue', 'হ্যাঁ, চালিয়ে যান')),
              ),
            ],
          ),
        ) ??
        false;
    if (mounted && consent) {
      setState(() => working = true);
    }
    return consent;
  }

  Future<void> _use() async {
    if (!confirmed || working || photo == null) return;
    setState(() => working = true);
    try {
      final chosen = masks.isEmpty ? photo! : await engine.mask(photo!, masks);
      generated.add(chosen.path);
      if (!mounted) {
        await _delete(chosen.path);
        return;
      }
      generated.remove(chosen.path);
      Navigator.pop(context, chosen.path);
    } catch (_) {
      if (mounted) {
        setState(() {
          working = false;
          error = t(
            'Could not save the protected copy. Choose another photo.',
            'ঢাকা ছবিটি সংরক্ষণ হয়নি। অন্য ছবি নিন।',
          );
        });
      }
    }
  }

  static Future<void> _delete(String path) async {
    try {
      await File(path).delete();
    } catch (_) {
      /* Temporary file already removed. */
    }
  }

  @override
  void dispose() {
    for (final path in generated) {
      _delete(path);
    }
    super.dispose();
  }

  Offset _point(Offset p, Size size) => Offset(
    (p.dx / size.width).clamp(0.0, 1.0),
    (p.dy / size.height).clamp(0.0, 1.0),
  );

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(t('Photo privacy', 'ছবির গোপনীয়তা'))),
    body: SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (working) ...[
              const LinearProgressIndicator(),
              const SizedBox(height: 12),
              Text(
                t(
                  'Checking content and protecting faces and detected text on this phone…',
                  'ফোনেই বিষয়বস্তু পরীক্ষা এবং মুখ ও শনাক্ত লেখা ঢাকা হচ্ছে…',
                ),
              ),
            ],
            if (error != null) ...[
              const Icon(Icons.gpp_bad_outlined, size: 48),
              const SizedBox(height: 12),
              Text(error!, style: Theme.of(context).textTheme.titleMedium),
            ],
            if (photo != null && error == null) ...[
              Text(
                t(
                  '${photo!.faces} faces and ${photo!.textRegions} text areas protected. Drag to cover anything missed.',
                  '${photo!.faces}টি মুখ ও ${photo!.textRegions}টি লেখার অংশ ঢাকা হয়েছে। বাদ পড়া অংশে আঙুল টেনে ঢাকুন।',
                ),
              ),
              const SizedBox(height: 8),
              Text(
                t(
                  'Small faces or unsupported scripts may be missed. Check the whole image before sharing.',
                  'ছোট মুখ বা বাংলা লেখা বাদ পড়তে পারে। পাঠানোর আগে পুরো ছবি দেখে নিন।',
                ),
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 12),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final source = Size(
                      photo!.width.toDouble(),
                      photo!.height.toDouble(),
                    );
                    final size = applyBoxFit(
                      BoxFit.contain,
                      source,
                      constraints.biggest,
                    ).destination;
                    return Center(
                      child: SizedBox(
                        width: size.width,
                        height: size.height,
                        child: GestureDetector(
                          onPanStart: working
                              ? null
                              : (d) => setState(() {
                                  start = _point(d.localPosition, size);
                                  end = start;
                                  confirmed = false;
                                }),
                          onPanUpdate: working
                              ? null
                              : (d) => setState(
                                  () => end = _point(d.localPosition, size),
                                ),
                          onPanEnd: working
                              ? null
                              : (_) => setState(() {
                                  if (start != null && end != null) {
                                    final rect = Rect.fromPoints(start!, end!);
                                    if (rect.width > .005 &&
                                        rect.height > .005) {
                                      masks.add(rect);
                                    }
                                  }
                                  start = null;
                                  end = null;
                                }),
                          child: CustomPaint(
                            foregroundPainter: _MaskPainter([
                              ...masks,
                              if (start != null && end != null)
                                Rect.fromPoints(start!, end!),
                            ]),
                            child: Image.file(
                              File(photo!.path),
                              fit: BoxFit.fill,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              TextButton.icon(
                onPressed: working || masks.isEmpty
                    ? null
                    : () => setState(() {
                        masks.removeLast();
                        confirmed = false;
                      }),
                icon: const Icon(Icons.undo),
                label: Text(
                  t('Undo last manual cover', 'শেষ হাতে ঢাকা অংশ ফিরিয়ে নিন'),
                ),
              ),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: confirmed,
                onChanged: working
                    ? null
                    : (v) => setState(() => confirmed = v ?? false),
                title: Text(
                  t(
                    'I checked that no personal information remains visible.',
                    'ব্যক্তিগত তথ্য দেখা যাচ্ছে না, দেখে নিশ্চিত হয়েছি।',
                  ),
                ),
              ),
              FilledButton.icon(
                onPressed: working || !confirmed ? null : _use,
                icon: const Icon(Icons.verified_user_outlined),
                label: Text(
                  t('Use protected photo', 'ঢাকা ছবিটি ব্যবহার করুন'),
                ),
              ),
            ] else
              const Spacer(),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(t('Choose another photo', 'অন্য ছবি নিন')),
            ),
          ],
        ),
      ),
    ),
  );
}

class _MaskPainter extends CustomPainter {
  _MaskPainter(this.rects);
  final List<Rect> rects;
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = const Color(0xff173b36);
    for (final rect in rects) {
      canvas.drawRect(
        Rect.fromLTRB(
          rect.left * size.width,
          rect.top * size.height,
          rect.right * size.width,
          rect.bottom * size.height,
        ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_MaskPainter oldDelegate) => true;
}
