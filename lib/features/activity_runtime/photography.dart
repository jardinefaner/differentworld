import 'package:differentworld/features/activity_runtime/activity_script.dart';

/// The Photography archetype (docs/ACTIVITY_RUNTIME.md §5) — the
/// "do-and-cull" loop, minimal first cut: **shoot → gallery**.
///
///   shoot   — full-screen camera, the instruction in the overlay, take
///             as many photos as you like, then Done.
///   gallery — everything you captured, full-screen.
///
/// `prompt` is what the camera overlay tells the learner ("find a
/// shadow", "capture something blue"). The cull step ("keep your 3 best,
/// delete the rest") is a follow-up phase; this first cut proves the
/// open-straight-to-camera → shoot-freely → see-the-gallery feel.
ScriptedActivity photographyActivity({
  String prompt = 'Capture what you see',
}) => ScriptedActivity(
  id: 'photography',
  title: 'Photo studio',
  phases: [
    Phase(
      id: 'shoot',
      mode: ActivityMode.shoot,
      prompt: prompt,
      pacing: PacingKind.perLearner,
    ),
    const Phase(
      id: 'gallery',
      mode: ActivityMode.present,
      prompt: 'Everything you captured',
    ),
  ],
);
