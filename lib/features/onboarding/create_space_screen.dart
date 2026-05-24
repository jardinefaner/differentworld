import 'package:differentworld/core/auth/auth_providers.dart';
import 'package:differentworld/core/db/drift_provider.dart';
import 'package:differentworld/shared/widgets/content_header.dart';
import 'package:differentworld/shared/widgets/edge_scaffold.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

/// First-time onboarding for a Member with no Space — creates one and
/// promotes them to director. UI labels "Program" because that's the
/// domain-specific term in the classroom-app instance; the engine just
/// sees Space + Member.
class CreateSpaceScreen extends ConsumerStatefulWidget {
  const CreateSpaceScreen({super.key});

  @override
  ConsumerState<CreateSpaceScreen> createState() =>
      _CreateSpaceScreenState();
}

class _CreateSpaceScreenState extends ConsumerState<CreateSpaceScreen> {
  final _nameController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_submitting) return;
    final form = _formKey.currentState;
    if (form == null || !form.validate()) return;
    final name = _nameController.text.trim();

    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      final db = ref.read(appDatabaseProvider).value;
      final session = ref.read(sessionProvider);
      if (db == null || session == null) {
        throw StateError('Database or session not ready.');
      }
      await db.createSpaceForMember(
        spaceId: const Uuid().v4(),
        spaceName: name,
        memberId: session.user.id,
      );
      // Pop ourselves off the navigator. CreateSpaceScreen was pushed
      // via MaterialPageRoute from JoinOrCreateScreen, so the root
      // route ('/') is still rendering whatever _Home picks based on
      // the current member.spaceId. Without this pop the user stays
      // staring at the now-stale form even though the home screen is
      // the new content underneath. The Drift currentMember stream
      // emits a new member with spaceId set ~immediately after the
      // local write, so by the time we pop, '/' is already
      // _SignedInHome.
      if (mounted) Navigator.of(context).pop();
    } on Exception catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } catch (e, st) {
      // Catch Error (StateError, AssertionError, etc.) too — the
      // narrower `on Exception` clause above missed Dart Errors,
      // which silently crashed the future and left the spinner stuck.
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: e,
          stack: st,
          library: 'onboarding',
          context: ErrorDescription('CreateSpaceScreen._submit'),
        ),
      );
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _signOut() async {
    await ref.read(authActionsProvider).signOut();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return EdgeScaffold(
      // Onboarding: showBack false (no place to back-pop to), sign-out
      // moves to the actions slot of the floating chrome instead of
      // an AppBar action. ContentHeader inside the body carries the
      // page title — same chrome system as every other screen.
      showBack: false,
      actions: [
        IconButton(
          tooltip: 'Sign out',
          icon: const Icon(Icons.logout),
          onPressed: _signOut,
        ),
      ],
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const ContentHeader(
                    title: 'Set up your program',
                  ),
                  // Softer hero — gradient squircle keeps the same
                  // visual family as the login wordmark so the
                  // onboarding flow reads as one piece.
                  Center(
                    child: Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              theme.colorScheme.primary,
                              theme.colorScheme.tertiary,
                            ],
                          ),
                        ),
                        child: Icon(
                          Icons.cottage_outlined,
                          size: 36,
                          color: theme.colorScheme.onPrimary,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      "What's your program called?",
                      style: theme.textTheme.headlineSmall,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'This is the program your classrooms, students, and '
                      'team will live under. You can edit it later in Settings.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 28),
                    TextFormField(
                      controller: _nameController,
                      // Do NOT autofocus — the keyboard popping up
                      // immediately covers the explanatory copy. The
                      // user taps when they're ready.
                      textCapitalization: TextCapitalization.words,
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) => _submit(),
                      decoration: const InputDecoration(
                        labelText: 'Program name',
                        hintText: 'e.g. Sunshine Preschool',
                        prefixIcon: Icon(Icons.school_outlined),
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        final v = value?.trim() ?? '';
                        if (v.isEmpty) {
                          return 'Your program needs a name — what do '
                              'families call you?';
                        }
                        if (v.length < 2) return 'A little longer, please.';
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: _submitting ? null : _submit,
                      icon: _submitting
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.check),
                      label: const Text('Create program'),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 16),
                      Text(
                        _error!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.error,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
    );
  }
}
