import 'dart:async';

import 'package:differentworld/core/db/app_database.dart';
import 'package:differentworld/features/subjects/subjects_providers.dart';
import 'package:differentworld/features/surveys/survey_templates.dart';
import 'package:differentworld/features/surveys/surveys_providers.dart';
import 'package:differentworld/features/surveys/widgets/chibi_smiley.dart';
import 'package:differentworld/shared/widgets/dismiss_guard.dart';
import 'package:differentworld/shared/widgets/edge_scaffold.dart';
import 'package:differentworld/shared/widgets/person_avatar.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// `/surveys/:templateId/take/:subjectId`
///
/// One-question-at-a-time survey runner for TK–3rd graders. The
/// instructor reads the prompt out loud; the kid taps a smiley (or
/// checks options, or speaks the answer for the instructor to type).
class SurveyTakeScreen extends ConsumerStatefulWidget {
  const SurveyTakeScreen({
    required this.templateId,
    required this.subjectId,
    super.key,
  });

  final String templateId;
  final String subjectId;

  @override
  ConsumerState<SurveyTakeScreen> createState() => _SurveyTakeScreenState();
}

class _SurveyTakeScreenState extends ConsumerState<SurveyTakeScreen> {
  late final PageController _page;
  SurveyAnswers _answers = SurveyAnswers();
  int _index = 0;
  bool _seeded = false;
  bool _saving = false;
  String? _error;

  SurveyTemplate? get _template => SurveyTemplates.byId(widget.templateId);

  @override
  void initState() {
    super.initState();
    _page = PageController();
  }

  @override
  void dispose() {
    _page.dispose();
    super.dispose();
  }

  /// Seed local answers from any existing draft response. Runs once.
  void _seed(SurveyResponse? row) {
    if (_seeded) return;
    _seeded = true;
    if (row != null) {
      _answers = SurveyAnswers.fromJson(row.answers);
    }
  }

  /// Autosave the draft. Cheap because answers JSON is tiny; the
  /// upsert is one row per (subject, template) and PowerSync uploads
  /// in the background.
  Future<void> _autosave() async {
    final t = _template;
    if (t == null) return;
    try {
      await ref.read(surveyActionsProvider).save(
            templateId: t.id,
            subjectId: widget.subjectId,
            answers: _answers,
            complete: false,
          );
    } on Exception catch (e, st) {
      FlutterError.reportError(
        FlutterErrorDetails(exception: e, stack: st, library: 'surveys'),
      );
    }
  }

  Future<void> _submit() async {
    final t = _template;
    if (t == null) return;
    final missing = t.scored.where((q) => !_answers.isAnswered(q)).toList();
    if (missing.isNotEmpty) {
      // Jump to the first unanswered scored question so the instructor
      // can finish it.
      final idx = t.questions.indexOf(missing.first);
      if (idx >= 0) {
        await _page.animateToPage(
          idx,
          duration: const Duration(milliseconds: 240),
          curve: Curves.easeOut,
        );
      }
      setState(() => _error = "There's one more answer needed before finishing.");
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref.read(surveyActionsProvider).save(
            templateId: t.id,
            subjectId: widget.subjectId,
            answers: _answers,
            complete: true,
          );
      if (!mounted) return;
      context.pop();
    } on Exception catch (e, st) {
      FlutterError.reportError(
        FlutterErrorDetails(exception: e, stack: st, library: 'surveys'),
      );
      if (!mounted) return;
      setState(() => _error = 'Could not submit. Please try again.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = _template;
    if (t == null) {
      return const EdgeScaffold(
        body: Center(child: Text('Survey not found.')),
      );
    }
    ref
        .watch(
          surveyResponseProvider(
            (templateId: widget.templateId, subjectId: widget.subjectId),
          ),
        )
        .whenData(_seed);

    final subjectAsync = ref.watch(subjectByIdProvider(widget.subjectId));
    final subject = subjectAsync.value;

    final total = t.questions.length;
    final answeredScored =
        t.scored.where((q) => _answers.isAnswered(q)).length;

    return DismissGuard(
      isDirty: () => !_seeded || _answers.toJson() != '{}',
      child: EdgeScaffold(
        body: Column(
          children: [
            const SizedBox(height: 56),
            _SurveyHeader(
              template: t,
              subject: subject,
              progressIndex: _index + 1,
              progressTotal: total,
              answeredScored: answeredScored,
              scoredTotal: t.scored.length,
            ),
            const SizedBox(height: 8),
            Expanded(
              child: PageView.builder(
                controller: _page,
                onPageChanged: (i) => setState(() => _index = i),
                itemCount: total,
                itemBuilder: (_, i) {
                  final q = t.questions[i];
                  return _QuestionPage(
                    question: q,
                    answers: _answers,
                    onAnswered: (next) {
                      setState(() => _answers = next);
                      unawaited(_autosave());
                    },
                  );
                },
              ),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
                child: Text(
                  _error!,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.error,
                  ),
                ),
              ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                child: Row(
                  children: [
                    TextButton.icon(
                      onPressed: _index == 0
                          ? null
                          : () {
                              unawaited(HapticFeedback.selectionClick());
                              unawaited(_page.previousPage(
                                duration: const Duration(milliseconds: 240),
                                curve: Curves.easeOut,
                              ));
                            },
                      icon: const Icon(Icons.arrow_back),
                      label: const Text('Back'),
                    ),
                    const Spacer(),
                    if (_index < total - 1)
                      FilledButton.icon(
                        onPressed: () {
                          unawaited(HapticFeedback.selectionClick());
                          unawaited(_page.nextPage(
                            duration: const Duration(milliseconds: 240),
                            curve: Curves.easeOut,
                          ));
                        },
                        icon: const Icon(Icons.arrow_forward),
                        label: const Text('Next'),
                      )
                    else
                      FilledButton.icon(
                        onPressed: _saving ? null : _submit,
                        icon: _saving
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.check_circle_outline),
                        label: const Text('Finish'),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SurveyHeader extends StatelessWidget {
  const _SurveyHeader({
    required this.template,
    required this.subject,
    required this.progressIndex,
    required this.progressTotal,
    required this.answeredScored,
    required this.scoredTotal,
  });

  final SurveyTemplate template;
  final Subject? subject;
  final int progressIndex;
  final int progressTotal;
  final int answeredScored;
  final int scoredTotal;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final name = subject == null
        ? 'Survey'
        : '${subject!.firstName} ${subject!.lastName}';
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              if (subject != null)
                PersonAvatar(
                  name: name,
                  photoUrl: subject!.photoUrl,
                ),
              if (subject != null) const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: theme.textTheme.titleMedium),
                    Text(
                      '${template.title} · ${template.year}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                '$answeredScored / $scoredTotal',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progressIndex / progressTotal,
              minHeight: 6,
              backgroundColor:
                  theme.colorScheme.surfaceContainerHighest,
            ),
          ),
        ],
      ),
    );
  }
}

class _QuestionPage extends StatelessWidget {
  const _QuestionPage({
    required this.question,
    required this.answers,
    required this.onAnswered,
  });

  final SurveyQuestion question;
  final SurveyAnswers answers;
  final ValueChanged<SurveyAnswers> onAnswered;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (question.isPractice)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _PracticeBadge(theme: theme),
            ),
          Text(
            question.prompt,
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineSmall,
          ),
          const SizedBox(height: 24),
          switch (question.kind) {
            SurveyQuestionKind.agree3 => _Agree3Row(
                question: question,
                answers: answers,
                onAnswered: onAnswered,
              ),
            SurveyQuestionKind.multiselect => _MultiselectList(
                question: question,
                answers: answers,
                onAnswered: onAnswered,
              ),
            SurveyQuestionKind.text => _TextAnswer(
                question: question,
                answers: answers,
                onAnswered: onAnswered,
              ),
          },
        ],
      ),
    );
  }
}

class _PracticeBadge extends StatelessWidget {
  const _PracticeBadge({required this.theme});
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Align(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: theme.colorScheme.tertiaryContainer,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          'PRACTICE',
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onTertiaryContainer,
            letterSpacing: 1.4,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

class _Agree3Row extends StatelessWidget {
  const _Agree3Row({
    required this.question,
    required this.answers,
    required this.onAnswered,
  });

  final SurveyQuestion question;
  final SurveyAnswers answers;
  final ValueChanged<SurveyAnswers> onAnswered;

  @override
  Widget build(BuildContext context) {
    final selected = answers.agree3(question.key);
    return LayoutBuilder(
      builder: (context, c) {
        // Three big smileys; fit comfortably on a 360dp phone with
        // 24dp side padding (3 × ~100 with gaps).
        final smileySize = ((c.maxWidth - 32) / 3).clamp(96.0, 160.0);
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final mood in ChibiMood.values)
              _SmileyChoice(
                mood: mood,
                isPractice: question.isPractice,
                size: smileySize,
                selected: selected == mood.index,
                dimmed: selected != null && selected != mood.index,
                onTap: () {
                  unawaited(HapticFeedback.selectionClick());
                  final next = SurveyAnswers.fromJson(answers.toJson())
                    ..setAgree3(question.key, mood.index);
                  onAnswered(next);
                },
              ),
          ],
        );
      },
    );
  }
}

class _SmileyChoice extends StatelessWidget {
  const _SmileyChoice({
    required this.mood,
    required this.size,
    required this.selected,
    required this.dimmed,
    required this.isPractice,
    required this.onTap,
  });

  final ChibiMood mood;
  final double size;
  final bool selected;
  final bool dimmed;
  final bool isPractice;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Practice questions use feeling-flavored labels ("Not great /
    // Okay / Great!"); real questions use the survey's
    // "Disagree / Kind of agree / Agree!" labels.
    final label = isPractice ? mood.feelingLabel : mood.label;
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(size / 2),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ChibiSmiley(
                mood: mood,
                size: size,
                selected: selected,
                dimmed: dimmed,
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: size,
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: dimmed
                        ? theme.colorScheme.onSurfaceVariant
                        : theme.colorScheme.onSurface,
                    fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MultiselectList extends StatelessWidget {
  const _MultiselectList({
    required this.question,
    required this.answers,
    required this.onAnswered,
  });

  final SurveyQuestion question;
  final SurveyAnswers answers;
  final ValueChanged<SurveyAnswers> onAnswered;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final picked = answers.multiselect(question.key).toSet();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Tap each one that fits — you can pick several.',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
        for (final opt in question.options) ...[
          _MultiselectTile(
            label: opt.label,
            selected: picked.contains(opt.key),
            onTap: () {
              unawaited(HapticFeedback.selectionClick());
              final next = picked.toSet();
              if (next.contains(opt.key)) {
                next.remove(opt.key);
              } else {
                next.add(opt.key);
              }
              final updated = SurveyAnswers.fromJson(answers.toJson())
                ..setMultiselect(question.key, next.toList());
              onAnswered(updated);
            },
          ),
          const SizedBox(height: 8),
        ],
        // Explicit "I'm done picking" so an empty list is still a
        // recorded answer (vs. the kid hasn't engaged yet).
        Align(
          child: TextButton(
            onPressed: () {
              final updated = SurveyAnswers.fromJson(answers.toJson())
                ..setMultiselect(question.key, picked.toList());
              onAnswered(updated);
            },
            child: Text(
              picked.isEmpty ? "None of these · I'm done" : "I'm done",
            ),
          ),
        ),
      ],
    );
  }
}

class _MultiselectTile extends StatelessWidget {
  const _MultiselectTile({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: selected
          ? theme.colorScheme.primaryContainer
          : theme.colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(14),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Icon(
                selected
                    ? Icons.check_circle
                    : Icons.radio_button_unchecked,
                color: selected
                    ? theme.colorScheme.onPrimaryContainer
                    : theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: selected
                        ? theme.colorScheme.onPrimaryContainer
                        : theme.colorScheme.onSurface,
                    fontWeight:
                        selected ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TextAnswer extends StatefulWidget {
  const _TextAnswer({
    required this.question,
    required this.answers,
    required this.onAnswered,
  });

  final SurveyQuestion question;
  final SurveyAnswers answers;
  final ValueChanged<SurveyAnswers> onAnswered;

  @override
  State<_TextAnswer> createState() => _TextAnswerState();
}

class _TextAnswerState extends State<_TextAnswer> {
  late final TextEditingController _controller;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: widget.answers.text(widget.question.key),
    );
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String v) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      final updated = SurveyAnswers.fromJson(widget.answers.toJson())
        ..setText(widget.question.key, v.trim());
      widget.onAnswered(updated);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Write here, or say it out loud and the teacher will type it.',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _controller,
          minLines: 3,
          maxLines: 6,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            hintText: 'Type what they said…',
          ),
          onChanged: _onChanged,
        ),
      ],
    );
  }
}
