import 'package:differentworld/features/activity_runtime/content_bank.dart';
import 'package:flutter/material.dart';

/// What a room can write for itself — one declaration per [ContentKind]
/// (docs/CONDITIONS.md, "authoring by playing").
///
/// The point of this file is that there is exactly ONE of it. Every
/// authoring surface — the library index, the per-kind list, the add/edit
/// form, the in-activity "add ours" strip — is generated from these specs, so
/// a new content kind gets a full CRUD door by adding a [ContentKindSpec]
/// here and nothing else. The alternative (a screen per kind) is how you end
/// up with a door for pictures and no door for the other fifteen, which is
/// exactly where this app was.
///
/// `picture` is deliberately ABSENT: its payload is an uploaded image, not
/// typed fields, so it keeps its own camera-shaped library at
/// `/games/pictures`. Everything else is text and fits one form.
/// What a kind is FOR, from the teacher's side. The library groups by this
/// rather than listing fifteen kinds flat: "ask the room" is a thing you want
/// to do; "this_or_that" is a thing the code calls a row.
enum ContentPurpose {
  ask('Ask the room'),
  move('Get them moving'),
  play('Play with words'),
  write('Write it down');

  const ContentPurpose(this.label);

  final String label;
}

@immutable
class ContentKindSpec {
  const ContentKindSpec({
    required this.kind,
    required this.title,
    required this.one,
    required this.many,
    required this.icon,
    required this.fields,
    required this.blurb,
    required this.purpose,
    this.summaryKey,
  });

  /// The `content_items.kind` these rows carry.
  final String kind;

  /// Library heading — "Our this-or-that pairs".
  final String title;

  /// Singular, lower case, for buttons — "pair" → "Add a pair".
  final String one;

  /// Plural, lower case, for counts — "3 pairs".
  final String many;

  final IconData icon;

  /// The form, in order. First field doubles as the row's headline unless
  /// [summaryKey] says otherwise.
  final List<ContentField> fields;

  /// One line under the library heading saying what the room is writing for.
  /// Never an instruction for how to use the screen — the screen is obvious;
  /// this says what the words are FOR (docs/CONDITIONS.md).
  final String blurb;

  /// What this kind is for — the group it sits under when a teacher is
  /// choosing what to write.
  final ContentPurpose purpose;

  /// Payload key to show as a row's headline, when it isn't the first field.
  final String? summaryKey;

  /// The row's headline in a list. Falls back to the first non-empty string
  /// so a malformed payload still renders something a teacher can delete.
  String summarize(Map<String, Object?> payload) {
    final key = summaryKey ?? fields.first.key;
    final primary = payload[key];
    if (primary is String && primary.trim().isNotEmpty) return primary.trim();
    for (final f in fields) {
      final v = payload[f.key];
      if (v is String && v.trim().isNotEmpty) return v.trim();
    }
    return 'Untitled $one';
  }

  /// The second line — the remaining fields, joined. Empty when there is
  /// nothing more to say, in which case the row shows one line.
  String detail(Map<String, Object?> payload) {
    final key = summaryKey ?? fields.first.key;
    final parts = <String>[];
    for (final f in fields) {
      if (f.key == key) continue;
      final v = payload[f.key];
      if (v is String && v.trim().isNotEmpty) {
        parts.add(v.trim());
      } else if (v is bool) {
        parts.add(v ? f.trueLabel ?? 'True' : f.falseLabel ?? 'False');
      } else if (v is List && v.isNotEmpty) {
        parts.add(v.join(' · '));
      }
    }
    return parts.join(' · ');
  }
}

/// How one payload key is edited.
enum ContentFieldShape {
  /// A single line.
  line,

  /// Several lines — a sentence or two.
  paragraph,

  /// A yes/no. Stored as a JSON bool.
  flag,

  /// One per line, stored as a JSON list of strings.
  list,
}

@immutable
class ContentField {
  const ContentField({
    required this.key,
    required this.label,
    required this.shape,
    this.hint,
    this.required = true,
    this.trueLabel,
    this.falseLabel,
  });

  /// The payload key. MUST match what the activity reads — these rows merge
  /// into the same bank the curated seeds live in, so a mismatched key is a
  /// row the game silently skips.
  final String key;

  final String label;
  final ContentFieldShape shape;

  /// Placeholder — a real example of valid input, never a restatement of the
  /// label.
  final String? hint;

  final bool required;

  /// [ContentFieldShape.flag] only.
  final String? trueLabel;
  final String? falseLabel;
}

/// Every authorable kind, in the order the library lists them: the ones a
/// room fills fastest first.
const List<ContentKindSpec> authorableKinds = [
  ContentKindSpec(
    kind: ContentKind.thisOrThat,
    purpose: ContentPurpose.ask,
    title: 'This or that',
    one: 'pair',
    many: 'pairs',
    icon: Icons.swap_horiz,
    blurb: 'Two things worth arguing about, and the word or.',
    fields: [
      ContentField(
        key: 'a',
        label: 'One thing',
        shape: ContentFieldShape.line,
        hint: 'Playground',
      ),
      ContentField(
        key: 'b',
        label: 'Or the other',
        shape: ContentFieldShape.line,
        hint: 'Gym',
      ),
    ],
  ),
  ContentKindSpec(
    kind: ContentKind.question,
    purpose: ContentPurpose.ask,
    title: 'Questions of the day',
    one: 'question',
    many: 'questions',
    icon: Icons.help_outline,
    blurb: 'Open enough that thirty children give thirty answers.',
    fields: [
      ContentField(
        key: 'text',
        label: 'The question',
        shape: ContentFieldShape.paragraph,
        hint: 'What is something you got better at this week?',
      ),
    ],
  ),
  ContentKindSpec(
    kind: ContentKind.doIt,
    purpose: ContentPurpose.move,
    title: 'Do its',
    one: 'do it',
    many: 'do its',
    icon: Icons.directions_run,
    blurb: 'Something to get up and actually do, here, today.',
    fields: [
      ContentField(
        key: 'text',
        label: 'What to do',
        shape: ContentFieldShape.paragraph,
        hint: 'Find three things outside that are older than you',
      ),
      ContentField(
        key: 'verb',
        label: 'The verb',
        shape: ContentFieldShape.line,
        hint: 'find',
      ),
      ContentField(
        key: 'emoji',
        label: 'An emoji',
        shape: ContentFieldShape.line,
        hint: '🔎',
        required: false,
      ),
    ],
  ),
  ContentKindSpec(
    kind: ContentKind.charades,
    purpose: ContentPurpose.move,
    title: 'Charades',
    one: 'prompt',
    many: 'prompts',
    icon: Icons.theater_comedy_outlined,
    blurb: 'The actor sees the word; the room only sees the category.',
    fields: [
      ContentField(
        key: 'word',
        label: 'The word to act out',
        shape: ContentFieldShape.line,
        hint: 'Riding a scooter',
      ),
      ContentField(
        key: 'category',
        label: 'What the room is told',
        shape: ContentFieldShape.line,
        hint: 'An action',
      ),
    ],
  ),
  ContentKindSpec(
    kind: ContentKind.riddle,
    purpose: ContentPurpose.play,
    title: 'Riddles',
    one: 'riddle',
    many: 'riddles',
    icon: Icons.psychology_outlined,
    blurb: 'Write the answer first, then point at it sideways.',
    summaryKey: 'prompt',
    fields: [
      ContentField(
        key: 'prompt',
        label: 'The riddle',
        shape: ContentFieldShape.paragraph,
        hint: 'What has hands but cannot clap?',
      ),
      ContentField(
        key: 'answer',
        label: 'The answer',
        shape: ContentFieldShape.line,
        hint: 'A clock',
      ),
    ],
  ),
  ContentKindSpec(
    kind: ContentKind.factOrFib,
    purpose: ContentPurpose.ask,
    title: 'Fact or fib',
    one: 'claim',
    many: 'claims',
    icon: Icons.fact_check_outlined,
    blurb: 'A claim the room votes on, then the real story.',
    fields: [
      ContentField(
        key: 'statement',
        label: 'The claim',
        shape: ContentFieldShape.paragraph,
        hint: 'Our school building is older than the town library',
      ),
      ContentField(
        key: 'isTrue',
        label: 'Is it true?',
        shape: ContentFieldShape.flag,
        trueLabel: 'Fact',
        falseLabel: 'Fib',
      ),
      ContentField(
        key: 'note',
        label: 'The real story',
        shape: ContentFieldShape.paragraph,
        hint: 'It opened in 1931, four years after the library.',
        required: false,
      ),
    ],
  ),
  ContentKindSpec(
    kind: ContentKind.category,
    purpose: ContentPurpose.ask,
    title: 'Categories',
    one: 'category',
    many: 'categories',
    icon: Icons.category_outlined,
    blurb: 'Anything a room can name five of, going round the circle.',
    fields: [
      ContentField(
        key: 'label',
        label: 'The category',
        shape: ContentFieldShape.line,
        hint: 'Something you find in a kitchen',
      ),
    ],
  ),
  ContentKindSpec(
    kind: ContentKind.storyStarter,
    purpose: ContentPurpose.write,
    title: 'Story starters',
    one: 'starter',
    many: 'starters',
    icon: Icons.auto_stories_outlined,
    blurb: 'A first line the room takes turns continuing.',
    fields: [
      ContentField(
        key: 'text',
        label: 'The opening line',
        shape: ContentFieldShape.paragraph,
        hint: 'The door at the end of the hall was open for the first time.',
      ),
    ],
  ),
  ContentKindSpec(
    kind: ContentKind.storyTwist,
    purpose: ContentPurpose.write,
    title: 'Story twists',
    one: 'twist',
    many: 'twists',
    icon: Icons.bolt_outlined,
    blurb: 'Dropped into a story already running.',
    fields: [
      ContentField(
        key: 'text',
        label: 'The twist',
        shape: ContentFieldShape.paragraph,
        hint: 'Everyone suddenly starts speaking backwards.',
      ),
    ],
  ),
  ContentKindSpec(
    kind: ContentKind.quote,
    purpose: ContentPurpose.ask,
    title: 'Quotes',
    one: 'quote',
    many: 'quotes',
    icon: Icons.format_quote_outlined,
    blurb: 'Short enough to sit with, open enough to argue with.',
    fields: [
      ContentField(
        key: 'text',
        label: 'The line',
        shape: ContentFieldShape.paragraph,
        hint: 'You can be scared and brave at the same time.',
      ),
      ContentField(
        key: 'author',
        label: 'Who said it',
        shape: ContentFieldShape.line,
        hint: 'Ms. Ruiz',
        required: false,
      ),
    ],
  ),
  ContentKindSpec(
    kind: ContentKind.line,
    purpose: ContentPurpose.move,
    title: 'Lines to perform',
    one: 'line',
    many: 'lines',
    icon: Icons.record_voice_over_outlined,
    blurb: 'A flat sentence — the acting comes from the as-if.',
    fields: [
      ContentField(
        key: 'text',
        label: 'The sentence',
        shape: ContentFieldShape.line,
        hint: 'I left my bag on the bus.',
      ),
    ],
  ),
  ContentKindSpec(
    kind: ContentKind.asIf,
    purpose: ContentPurpose.move,
    title: 'As ifs',
    one: 'as if',
    many: 'as ifs',
    icon: Icons.masks_outlined,
    blurb: 'The way to say the line — say it as if…',
    fields: [
      ContentField(
        key: 'text',
        label: 'As if…',
        shape: ContentFieldShape.line,
        hint: 'you are telling a secret in a library',
      ),
    ],
  ),
  ContentKindSpec(
    kind: ContentKind.rhymeWord,
    purpose: ContentPurpose.play,
    title: 'Rhyme words',
    one: 'word',
    many: 'words',
    icon: Icons.abc,
    blurb: 'A word with enough rhymes to go round twice.',
    fields: [
      ContentField(
        key: 'word',
        label: 'The word',
        shape: ContentFieldShape.line,
        hint: 'chair',
      ),
    ],
  ),
  ContentKindSpec(
    kind: ContentKind.writePrompt,
    purpose: ContentPurpose.write,
    title: 'Write to a friend',
    one: 'prompt',
    many: 'prompts',
    icon: Icons.drafts_outlined,
    blurb: 'What to write on the note everyone passes.',
    fields: [
      ContentField(
        key: 'text',
        label: 'The prompt',
        shape: ContentFieldShape.paragraph,
        hint: 'Tell them one thing you saw them do well this week.',
      ),
    ],
  ),
  ContentKindSpec(
    kind: ContentKind.scavengerThing,
    purpose: ContentPurpose.move,
    title: 'Scavenger list',
    one: 'thing to find',
    many: 'things to find',
    icon: Icons.travel_explore_outlined,
    blurb: 'What is actually outside your door — not a stock list.',
    fields: [
      ContentField(
        key: 'text',
        label: 'The thing to find',
        shape: ContentFieldShape.line,
        hint: 'Something older than you',
      ),
    ],
  ),
  ContentKindSpec(
    kind: ContentKind.fourCorners,
    purpose: ContentPurpose.move,
    title: 'Four corners',
    one: 'question',
    many: 'questions',
    icon: Icons.crop_square_outlined,
    blurb: 'A question with four answers — one per corner of the room.',
    summaryKey: 'question',
    fields: [
      ContentField(
        key: 'question',
        label: 'The question',
        shape: ContentFieldShape.paragraph,
        hint: 'Which would you rather be?',
      ),
      ContentField(
        key: 'a',
        label: 'Front left',
        shape: ContentFieldShape.line,
        hint: 'A bird',
      ),
      ContentField(
        key: 'b',
        label: 'Front right',
        shape: ContentFieldShape.line,
        hint: 'A fish',
      ),
      ContentField(
        key: 'c',
        label: 'Back left',
        shape: ContentFieldShape.line,
        hint: 'A bear',
      ),
      ContentField(
        key: 'd',
        label: 'Back right',
        shape: ContentFieldShape.line,
        hint: 'A snake',
      ),
    ],
  ),
  ContentKindSpec(
    kind: ContentKind.fillBlank,
    purpose: ContentPurpose.play,
    title: 'Fill in the blanks',
    one: 'template',
    many: 'templates',
    icon: Icons.short_text,
    blurb: 'Write {0} and {1} where the room shouts a word.',
    fields: [
      ContentField(
        key: 'template',
        label: 'The sentence',
        shape: ContentFieldShape.paragraph,
        hint: 'Our class pet is a {0} who loves to {1} all day.',
      ),
      ContentField(
        key: 'blanks',
        label: 'What to ask for, one per line',
        shape: ContentFieldShape.list,
        hint: 'an animal\nan action word',
      ),
    ],
  ),
];

/// The spec for [kind], or null when the kind has no typed form (`picture`,
/// or a kind added to [ContentKind] without a door here — which the
/// authorable-kinds test will fail on).
ContentKindSpec? specForKind(String kind) {
  for (final s in authorableKinds) {
    if (s.kind == kind) return s;
  }
  return null;
}
