import 'package:differentworld/features/action_words/curriculum.dart';
import 'package:differentworld/features/action_words/spell_words.dart';
import 'package:differentworld/features/action_words/verb_roles.dart';
import 'package:differentworld/features/action_words/verbs.dart';
import 'package:differentworld/features/action_words/world_blocks.dart';
import 'package:differentworld/features/action_words/world_rules.dart';
// `spells.dart` also exports a `SpellWord` (a timer-spell's foreign word) —
// hide it so the beautiful-word `SpellWord` from `spell_words.dart` wins here.
import 'package:differentworld/features/spells/spells.dart' hide SpellWord;
import 'package:differentworld/shared/print/pdf_output.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

/// The **printable toolkit** — the offline/physical layer (docs/VISION.md
/// "works when the sub walks in, works when the power's out"). The app's job
/// here is to GENERATE the binder pages it uniquely has data for, NOT to be
/// the binder. Built-in Helvetica so it prints fully OFFLINE.
///
/// Helvetica can't draw emoji, so these are WORD-forward cards — the verb word
/// in huge letters is what laminates and goes in the basket; a teacher can
/// sticker the emoji on after. `_ascii` maps the curriculum's curly quotes /
/// dashes into the Latin-1 subset Helvetica can render. The built-in PDF
/// Helvetica has NO Unicode support (it warns + drops the glyph), so we also
/// fold accents to plain ASCII — a translated word like "Arrête" prints as
/// "Arrete"; the phonetic hint beside it ("ah-RET") carries the real sound.
String _ascii(String s) {
  var out = s
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
  _accentFolds.forEach((from, to) => out = out.replaceAll(from, to));
  return out;
}

/// Accented Latin → plain ASCII, so the built-in Helvetica never hits a glyph
/// it can't draw (the "Helvetica has no Unicode support" warning).
const Map<String, String> _accentFolds = {
  'á': 'a',
  'à': 'a',
  'â': 'a',
  'ä': 'a',
  'ã': 'a',
  'å': 'a',
  'é': 'e',
  'è': 'e',
  'ê': 'e',
  'ë': 'e',
  'í': 'i',
  'ì': 'i',
  'î': 'i',
  'ï': 'i',
  'ó': 'o',
  'ò': 'o',
  'ô': 'o',
  'ö': 'o',
  'õ': 'o',
  'ú': 'u',
  'ù': 'u',
  'û': 'u',
  'ü': 'u',
  'ç': 'c',
  'ñ': 'n',
  'ß': 'ss',
  'Á': 'A',
  'À': 'A',
  'Â': 'A',
  'Ä': 'A',
  'É': 'E',
  'È': 'E',
  'Ê': 'E',
  'Ë': 'E',
  'Í': 'I',
  'Î': 'I',
  'Ó': 'O',
  'Ô': 'O',
  'Ö': 'O',
  'Ú': 'U',
  'Ü': 'U',
  'Ç': 'C',
  'Ñ': 'N',
};

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

/// The bundled monochrome emoji font (subset to the card glyphs), loaded once.
/// Helvetica can't draw emoji; this is the fallback that can. Cached so a
/// multi-copy print doesn't re-decode it.
pw.Font? _emojiFontCache;
Future<pw.Font> _emojiFont() async => _emojiFontCache ??= pw.Font.ttf(
  await rootBundle.load('assets/fonts/NotoEmoji.ttf'),
);

/// One verb card: the emoji big up top (now that we embed an emoji font), the
/// verb word huge, its lens underneath. Laminate, basket, pick 3.
pw.Page _verbCard(Verb v, pw.Font emoji) => pw.Page(
  theme: pw.ThemeData.base(),
  pageFormat: PdfPageFormat.letter,
  margin: const pw.EdgeInsets.all(40),
  build: (ctx) => pw.Center(
    child: pw.Column(
      mainAxisAlignment: pw.MainAxisAlignment.center,
      children: [
        pw.Text(v.emoji, style: pw.TextStyle(font: emoji, fontSize: 130)),
        pw.SizedBox(height: 18),
        pw.Text(
          _ascii(v.label.toUpperCase()),
          textAlign: pw.TextAlign.center,
          style: pw.TextStyle(fontSize: 92, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 20),
        pw.Text(
          _ascii(v.lens),
          textAlign: pw.TextAlign.center,
          style: const pw.TextStyle(fontSize: 28, color: PdfColors.grey700),
        ),
      ],
    ),
  ),
);

/// 12 full-page verb cards — emoji + the word + its lens. Laminate, basket,
/// pick 3.
Future<bool> printVerbCards({int copies = 1}) async {
  final emoji = await _emojiFont();
  return emitPdf(
    name: 'Verb cards',
    copies: copies,
    pages: () => [for (final v in kVerbs) _verbCard(v, emoji)],
  );
}

/// One full-page wall-question poster: the world + day on top, the question
/// huge and centered (it wraps — questions are sentences, not single words),
/// the room's name at the foot. Print one per program day, laminate, and put
/// the day's question on the Wall.
pw.Page _wallQuestionPage(WorldBlock block, int day, String question) =>
    pw.Page(
      theme: pw.ThemeData.base(),
      pageFormat: PdfPageFormat.letter,
      margin: const pw.EdgeInsets.all(44),
      build: (ctx) => pw.Column(
        children: [
          pw.Text(
            '${_ascii(block.name).toUpperCase()}  -  DAY $day',
            style: pw.TextStyle(
              fontSize: 20,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.grey600,
              letterSpacing: 1.5,
            ),
          ),
          pw.Expanded(
            child: pw.Center(
              child: pw.Text(
                _ascii(question),
                textAlign: pw.TextAlign.center,
                style: pw.TextStyle(
                  fontSize: 56,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ),
          ),
          pw.Text(
            'THE WALL  -  differentworld',
            style: const pw.TextStyle(fontSize: 14, color: PdfColors.grey500),
          ),
        ],
      ),
    );

/// A single day's teacher sheet: world + day header, the day's title, the
/// minute-by-minute focus, and the room/soundtrack — what a sub needs to run
/// the day from paper.
pw.Page _dayFocusPage(WorldBlock block, int day, JourneyDay d) => pw.Page(
  theme: pw.ThemeData.base(),
  pageFormat: PdfPageFormat.letter,
  margin: const pw.EdgeInsets.all(48),
  build: (ctx) => pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Text(
        _ascii('${block.name.toUpperCase()}  -  DAY $day'),
        style: const pw.TextStyle(
          fontSize: 12,
          letterSpacing: 3,
          color: PdfColors.grey600,
        ),
      ),
      pw.SizedBox(height: 4),
      pw.Text(
        _ascii(d.title),
        style: pw.TextStyle(fontSize: 30, fontWeight: pw.FontWeight.bold),
      ),
      pw.SizedBox(height: 18),
      _heading('Today’s focus'),
      pw.Text(_ascii(d.focus), style: const pw.TextStyle(fontSize: 14)),
      pw.SizedBox(height: 20),
      _heading('The room'),
      pw.Text(
        _ascii(block.room),
        style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey800),
      ),
      pw.SizedBox(height: 8),
      pw.Text(
        _ascii('Soundtrack: ${block.soundtrack}'),
        style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey700),
      ),
    ],
  ),
);

/// One day's offline pack: the wall-question poster + the teacher day sheet.
/// "For each day, print what you need" — generated, not hand-assembled.
Future<bool> printDay({
  required WorldBlock block,
  required int day,
  required JourneyDay journeyDay,
  String? wallQuestion,
  int copies = 1,
}) => emitPdf(
  name: 'Day $day - ${journeyDay.title}',
  copies: copies,
  pages: () => [
    if (wallQuestion != null && wallQuestion.isNotEmpty)
      _wallQuestionPage(block, day, wallQuestion),
    _dayFocusPage(block, day, journeyDay),
  ],
);

/// The 50-question wall deck — every program day's question as a full-page
/// poster, in journey order. The authored prompts of the 50-day experience,
/// ready to laminate and put up one per day (ASSETS Bundle 3). Offline-safe
/// (built-in Helvetica).
Future<bool> printWallQuestionDeck(List<WorldBlock> blocks, {int copies = 1}) =>
    emitPdf(
      name: 'Wall question deck',
      copies: copies,
      pages: () => [
        for (final block in blocks)
          for (var i = 0; i < block.wallQuestions.length; i++)
            // Pair each question with its day number (the world's days carry
            // the 1..50 program-day numbers); fall back to positional.
            _wallQuestionPage(
              block,
              i < block.days.length ? block.days[i].day : i + 1,
              block.wallQuestions[i],
            ),
      ],
    );

/// One spell card: the English command huge, then every language version to
/// read aloud — the word + a phonetic hint + the language. The pronunciation
/// reference for the classroom-management casts (FREEZE, MOVE, …).
pw.Page _spellCard(Spell s) => pw.Page(
  theme: pw.ThemeData.base(),
  pageFormat: PdfPageFormat.letter,
  margin: const pw.EdgeInsets.all(44),
  build: (ctx) => pw.Column(
    children: [
      pw.SizedBox(height: 28),
      pw.Text(
        _ascii(s.english.toUpperCase()),
        style: pw.TextStyle(fontSize: 88, fontWeight: pw.FontWeight.bold),
      ),
      pw.SizedBox(height: 4),
      pw.Text(
        spellTimeLabel(s.durationSeconds),
        style: const pw.TextStyle(fontSize: 22, color: PdfColors.grey500),
      ),
      pw.SizedBox(height: 34),
      pw.Text(
        'SAY IT IN',
        style: pw.TextStyle(
          fontSize: 13,
          letterSpacing: 3,
          fontWeight: pw.FontWeight.bold,
          color: PdfColors.grey600,
        ),
      ),
      pw.SizedBox(height: 16),
      for (final w in s.words)
        pw.Padding(
          padding: const pw.EdgeInsets.only(bottom: 16),
          child: pw.Column(
            children: [
              // _ascii folds accents (Arrête → Arrete) so Helvetica renders it
              // — the phonetic hint below carries the real sound.
              pw.Text(
                _ascii(w.word),
                style: pw.TextStyle(
                  fontSize: 32,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 2),
              pw.Text(
                _ascii('"${w.pronunciation}"   -   ${w.language}'),
                style: const pw.TextStyle(
                  fontSize: 17,
                  color: PdfColors.grey700,
                ),
              ),
            ],
          ),
        ),
    ],
  ),
);

/// The timer-spell cards (FREEZE, MOVE, …) — each with all its language
/// versions + pronunciations to read aloud.
Future<bool> printTimerSpellCards({int copies = 1}) => emitPdf(
  name: 'Timer spell cards',
  copies: copies,
  pages: () => [for (final s in kSpells) _spellCard(s)],
);

/// The back of a spell-word card: the word, its meaning, the gesture, and the
/// "use it 3 times" promise.
pw.Page _spellWordBack(SpellWord w) => pw.Page(
  theme: pw.ThemeData.base(),
  pageFormat: PdfPageFormat.letter,
  margin: const pw.EdgeInsets.all(48),
  build: (ctx) => pw.Center(
    child: pw.Column(
      mainAxisAlignment: pw.MainAxisAlignment.center,
      children: [
        pw.Text(
          _ascii(w.word),
          textAlign: pw.TextAlign.center,
          style: pw.TextStyle(fontSize: 44, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 24),
        pw.Text(
          _ascii(w.meaning),
          textAlign: pw.TextAlign.center,
          style: const pw.TextStyle(fontSize: 28),
        ),
        if (w.gesture.isNotEmpty) ...[
          pw.SizedBox(height: 30),
          pw.Text(
            'GESTURE',
            style: pw.TextStyle(
              fontSize: 15,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.grey600,
              letterSpacing: 2,
            ),
          ),
          pw.SizedBox(height: 6),
          pw.Text(
            _ascii(w.gesture),
            textAlign: pw.TextAlign.center,
            style: const pw.TextStyle(fontSize: 22, color: PdfColors.grey700),
          ),
        ],
        pw.SizedBox(height: 40),
        pw.Container(
          padding: const pw.EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: pw.BoxDecoration(
            border: pw.Border.all(width: 1.5),
            borderRadius: pw.BorderRadius.circular(10),
          ),
          child: pw.Text(
            _ascii('Use it 3 times today and it is yours.'),
            style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold),
          ),
        ),
      ],
    ),
  ),
);

/// 30 spell-word cards — the WORD huge on the front, its meaning + gesture +
/// "use 3x to earn" on the back. Print double-sided, cut, hand them out as
/// they're earned (docs/ASSETS.md "each one feels precious").
Future<bool> printSpellWordCards(List<SpellWord> words, {int copies = 1}) =>
    emitPdf(
      name: 'Spell word cards',
      copies: copies,
      pages: () => [
        for (final w in words) ...[
          _bigCard(w.word, 'a word to earn'),
          _spellWordBack(w),
        ],
      ],
    );

pw.Widget _heading(String t) => pw.Padding(
  padding: const pw.EdgeInsets.only(bottom: 12),
  child: pw.Text(
    _ascii(t),
    style: pw.TextStyle(fontSize: 26, fontWeight: pw.FontWeight.bold),
  ),
);

/// One "VERB — description" row of a one-page reference list.
pw.Widget _verbRefRow(String label, String text) => pw.Padding(
  padding: const pw.EdgeInsets.only(bottom: 10),
  child: pw.Row(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.SizedBox(
        width: 130,
        child: pw.Text(
          _ascii(label.toUpperCase()),
          style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
        ),
      ),
      pw.Expanded(
        child: pw.Text(_ascii(text), style: const pw.TextStyle(fontSize: 13)),
      ),
    ],
  ),
);

/// A single letter-format reference page — heading + rows.
pw.Page _referencePage(String heading, List<pw.Widget> rows) => pw.Page(
  theme: pw.ThemeData.base(),
  pageFormat: PdfPageFormat.letter,
  margin: const pw.EdgeInsets.all(48),
  build: (ctx) => pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [_heading(heading), ...rows],
  ),
);

/// One-page reference: each verb's job (from the verb-roles data we built).
Future<bool> printVerbJobReference(
  Map<String, VerbRole> roles, {
  int copies = 1,
}) => emitPdf(
  name: 'Verb to Job reference',
  copies: copies,
  pages: () => [
    _referencePage('Verb -> Job', [
      for (final v in kVerbs)
        if (roles[v.id] case final r?)
          _verbRefRow(
            v.label,
            r.jobs.isEmpty
                ? r.jobTitle
                : '${r.jobTitle}  -  ${r.jobs.first.job}',
          ),
    ]),
  ],
);

/// One-page closing-game reference: how to act out each verb.
Future<bool> printGestureGuide({int copies = 1}) => emitPdf(
  name: 'Verb gesture guide',
  copies: copies,
  pages: () => [
    _referencePage('Verb gestures (closing game)', [
      for (final v in kVerbs) _verbRefRow(v.label, kVerbGestures[v.id] ?? ''),
    ]),
  ],
);

List<String> _verbLabels(List<String> ids) => [
  for (final id in ids)
    if (verbById(id) case final v?) v.label,
];

/// One reveal card per world (the closing "you were... AN ANT!" moment). The
/// world NAME huge + the verbs that map to it. Hold it up, flip, reveal.
Future<bool> printWorldRevealCards(
  List<CurriculumWorld> worlds, {
  int copies = 1,
}) => emitPdf(
  name: 'World reveal cards',
  copies: copies,
  pages: () => [
    for (final w in worlds)
      pw.Page(
        theme: pw.ThemeData.base(),
        pageFormat: PdfPageFormat.letter,
        margin: const pw.EdgeInsets.all(40),
        build: (ctx) => pw.Center(
          child: pw.Column(
            mainAxisAlignment: pw.MainAxisAlignment.center,
            children: [
              pw.Text(
                _ascii('WEEK ${w.week}'),
                style: const pw.TextStyle(
                  fontSize: 16,
                  letterSpacing: 4,
                  color: PdfColors.grey600,
                ),
              ),
              pw.SizedBox(height: 12),
              pw.Text(
                _ascii(w.name.toUpperCase()),
                textAlign: pw.TextAlign.center,
                style: pw.TextStyle(
                  fontSize: 60,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 28),
              pw.Text(
                _ascii(_verbLabels(w.featuredVerbs).join('   -   ')),
                textAlign: pw.TextAlign.center,
                style: const pw.TextStyle(
                  fontSize: 20,
                  color: PdfColors.grey700,
                ),
              ),
            ],
          ),
        ),
      ),
  ],
);

/// One summary poster per world: name, the central question, the verbs, the
/// rules. Posted on the wall when that world is active.
Future<bool> printWorldSummaryCards(
  List<CurriculumWorld> worlds, {
  int copies = 1,
}) => emitPdf(
  name: 'World summary cards',
  copies: copies,
  pages: () => [
    for (final w in worlds)
      if (rulesForWorld(w.id) case final rules)
        pw.Page(
          theme: pw.ThemeData.base(),
          pageFormat: PdfPageFormat.letter,
          margin: const pw.EdgeInsets.all(48),
          build: (ctx) => pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                _ascii('WEEK ${w.week}'),
                style: const pw.TextStyle(
                  fontSize: 12,
                  letterSpacing: 3,
                  color: PdfColors.grey600,
                ),
              ),
              pw.Text(
                _ascii(w.name),
                style: pw.TextStyle(
                  fontSize: 34,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              if (w.question.isNotEmpty) ...[
                pw.SizedBox(height: 6),
                pw.Text(
                  _ascii('"${w.question}"'),
                  style: pw.TextStyle(
                    fontSize: 16,
                    fontStyle: pw.FontStyle.italic,
                    color: PdfColors.grey800,
                  ),
                ),
              ],
              pw.SizedBox(height: 20),
              _heading('The verbs'),
              pw.Text(
                _ascii(_verbLabels(w.featuredVerbs).join('   -   ')),
                style: const pw.TextStyle(fontSize: 14),
              ),
              if (rules.isNotEmpty) ...[
                pw.SizedBox(height: 18),
                _heading('The rules of this world'),
                for (final r in rules)
                  pw.Padding(
                    padding: const pw.EdgeInsets.only(bottom: 6),
                    child: pw.Text(
                      _ascii('-  ${r.text}'),
                      style: const pw.TextStyle(fontSize: 13),
                    ),
                  ),
              ],
            ],
          ),
        ),
  ],
);

/// One-page reference card for the repair script + mood weather scale.
Future<bool> printReferenceCard({int copies = 1}) => emitPdf(
  name: 'Reference card',
  copies: copies,
  pages: () => [
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
  ],
);
