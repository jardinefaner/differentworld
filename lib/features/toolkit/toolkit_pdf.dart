import 'package:differentworld/features/action_words/verb_roles.dart';
import 'package:differentworld/features/action_words/verbs.dart';
import 'package:differentworld/features/spells/spells.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

/// The **printable toolkit** — the offline/physical layer (docs/VISION.md
/// "works when the sub walks in, works when the power's out"). The app's job
/// here is to GENERATE the binder pages it uniquely has data for, NOT to be
/// the binder. Built-in Helvetica so it prints fully OFFLINE.
///
/// Helvetica can't draw emoji, so these are WORD-forward cards — the verb word
/// in huge letters is what laminates and goes in the basket; a teacher can
/// sticker the emoji on after. `_ascii` maps the curriculum's curly quotes /
/// dashes into the Latin-1 subset Helvetica can render.
String _ascii(String s) => s
    .replaceAll('—', '-')
    .replaceAll('–', '-')
    .replaceAll('‘', "'")
    .replaceAll('’', "'")
    .replaceAll('“', '"')
    .replaceAll('”', '"')
    .replaceAll('→', '->')
    .replaceAll('…', '...')
    .replaceAll('•', '-')
    .replaceAll(' ', ' ');

/// How to act out each verb without words (the closing guessing game). Static
/// reference content; keyed by verb id.
const kVerbGestures = <String, String>{
  'carry': 'Mime lifting something heavy.',
  'listen': 'Cup your ear, close your eyes.',
  'play': 'Jump and clap.',
  'spark': 'Snap your fingers, jazz hands.',
  'flow': 'Wave your arms like water.',
  'build': 'Stack invisible blocks.',
  'watch': 'Hand over your eyes like binoculars.',
  'wait': 'Freeze completely.',
  'solve': "Scratch your chin, then snap - 'aha!'",
  'help': 'Extend a hand, palm up.',
  'echo': 'Cup your mouth, lean forward.',
  'shine': 'Arms wide, chest forward.',
};

pw.Page _bigCard(String big, String sub) => pw.Page(
  theme: pw.ThemeData.base(),
  pageFormat: PdfPageFormat.letter,
  margin: const pw.EdgeInsets.all(40),
  build: (ctx) => pw.Center(
    child: pw.Column(
      mainAxisAlignment: pw.MainAxisAlignment.center,
      children: [
        pw.Text(
          _ascii(big),
          textAlign: pw.TextAlign.center,
          style: pw.TextStyle(fontSize: 120, fontWeight: pw.FontWeight.bold),
        ),
        if (sub.isNotEmpty) ...[
          pw.SizedBox(height: 28),
          pw.Text(
            _ascii(sub),
            textAlign: pw.TextAlign.center,
            style: const pw.TextStyle(fontSize: 30, color: PdfColors.grey700),
          ),
        ],
      ],
    ),
  ),
);

/// 12 full-page verb cards (the word huge + its lens). Laminate, basket, pick 3.
Future<bool> printVerbCards() {
  final doc = pw.Document(creator: 'Different World');
  for (final v in kVerbs) {
    doc.addPage(_bigCard(v.label.toUpperCase(), v.lens));
  }
  return Printing.layoutPdf(onLayout: (_) => doc.save(), name: 'Verb cards');
}

/// The timer-spell cards (FREEZE, MOVE, …) — the classroom-management casts.
Future<bool> printTimerSpellCards() {
  final doc = pw.Document(creator: 'Different World');
  for (final s in kSpells) {
    doc.addPage(_bigCard(s.english.toUpperCase(), '${s.durationSeconds}s'));
  }
  return Printing.layoutPdf(
    onLayout: (_) => doc.save(),
    name: 'Timer spell cards',
  );
}

pw.Widget _heading(String t) => pw.Padding(
  padding: const pw.EdgeInsets.only(bottom: 12),
  child: pw.Text(
    _ascii(t),
    style: pw.TextStyle(fontSize: 26, fontWeight: pw.FontWeight.bold),
  ),
);

/// One-page reference: each verb's job (from the verb-roles data we built).
Future<bool> printVerbJobReference(Map<String, VerbRole> roles) {
  final doc = pw.Document(creator: 'Different World')
    ..addPage(
      pw.Page(
        theme: pw.ThemeData.base(),
        pageFormat: PdfPageFormat.letter,
        margin: const pw.EdgeInsets.all(48),
        build: (ctx) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            _heading('Verb -> Job'),
            for (final v in kVerbs)
              if (roles[v.id] case final r?)
                pw.Padding(
                  padding: const pw.EdgeInsets.only(bottom: 10),
                  child: pw.Row(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.SizedBox(
                        width: 130,
                        child: pw.Text(
                          _ascii(v.label.toUpperCase()),
                          style: pw.TextStyle(
                            fontSize: 14,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                      ),
                      pw.Expanded(
                        child: pw.Text(
                          _ascii(
                            r.jobs.isEmpty
                                ? r.jobTitle
                                : '${r.jobTitle}  -  ${r.jobs.first.job}',
                          ),
                          style: const pw.TextStyle(fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
          ],
        ),
      ),
    );
  return Printing.layoutPdf(
    onLayout: (_) => doc.save(),
    name: 'Verb to Job reference',
  );
}

/// One-page closing-game reference: how to act out each verb.
Future<bool> printGestureGuide() {
  final doc = pw.Document(creator: 'Different World')
    ..addPage(
      pw.Page(
        theme: pw.ThemeData.base(),
        pageFormat: PdfPageFormat.letter,
        margin: const pw.EdgeInsets.all(48),
        build: (ctx) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            _heading('Verb gestures (closing game)'),
            for (final v in kVerbs)
              pw.Padding(
                padding: const pw.EdgeInsets.only(bottom: 10),
                child: pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.SizedBox(
                      width: 130,
                      child: pw.Text(
                        _ascii(v.label.toUpperCase()),
                        style: pw.TextStyle(
                          fontSize: 14,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                    ),
                    pw.Expanded(
                      child: pw.Text(
                        _ascii(kVerbGestures[v.id] ?? ''),
                        style: const pw.TextStyle(fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  return Printing.layoutPdf(
    onLayout: (_) => doc.save(),
    name: 'Verb gesture guide',
  );
}

/// One-page reference card for the repair script + mood weather scale.
Future<bool> printReferenceCard() {
  final doc = pw.Document(creator: 'Different World')
    ..addPage(
      pw.Page(
        theme: pw.ThemeData.base(),
        pageFormat: PdfPageFormat.letter,
        margin: const pw.EdgeInsets.all(48),
        build: (ctx) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            _heading('The repair'),
            for (final q in const [
              '1.  What happened?',
              '2.  How did that feel?',
              '3.  What could we do differently?',
            ])
              pw.Padding(
                padding: const pw.EdgeInsets.only(bottom: 8),
                child: pw.Text(q, style: const pw.TextStyle(fontSize: 18)),
              ),
            pw.SizedBox(height: 28),
            _heading('Mood weather'),
            for (final m in const [
              '1   Stormy',
              '2   Rainy',
              '3   Cloudy',
              '4   Partly sunny',
              '5   Sunny',
            ])
              pw.Padding(
                padding: const pw.EdgeInsets.only(bottom: 6),
                child: pw.Text(m, style: const pw.TextStyle(fontSize: 18)),
              ),
          ],
        ),
      ),
    );
  return Printing.layoutPdf(
    onLayout: (_) => doc.save(),
    name: 'Reference card',
  );
}
