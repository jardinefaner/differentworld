import 'package:powersync/powersync.dart';

/// PowerSync local SQLite schema. Must mirror the synced columns in the
/// Supabase tables — see supabase/sync_rules.yaml + supabase/migrations/*.
///
/// PowerSync auto-adds the `id` column as TEXT PRIMARY KEY on every table;
/// don't declare it explicitly. Booleans and dates serialize to TEXT/INTEGER
/// per Postgres → SQLite conventions:
///   - timestamps & dates → TEXT (ISO 8601)
///   - booleans           → INTEGER (0/1)
///   - jsonb              → TEXT (raw JSON string)
const appSchema = Schema([
  Table('programs', [
    Column.text('name'),
    Column.text('slug'),
    Column.text('settings'),
    Column.text('created_at'),
    Column.text('updated_at'),
  ]),
  Table('profiles', [
    Column.text('program_id'),
    Column.text('display_name'),
    Column.text('role'),
    Column.text('avatar_url'),
    Column.text('created_at'),
    Column.text('updated_at'),
  ]),
  Table('classrooms', [
    Column.text('program_id'),
    Column.text('name'),
    Column.text('age_range'),
    Column.text('color'),
    Column.text('created_at'),
    Column.text('updated_at'),
  ]),
  Table('enrollments', [
    Column.text('profile_id'),
    Column.text('classroom_id'),
    Column.text('program_id'),
    Column.text('role'),
    Column.text('created_at'),
  ]),
  Table('students', [
    Column.text('program_id'),
    Column.text('classroom_id'),
    Column.text('first_name'),
    Column.text('last_name'),
    Column.text('dob'),
    Column.text('photo_url'),
    Column.text('allergies'),
    Column.text('notes'),
    Column.text('created_at'),
    Column.text('updated_at'),
  ]),
  Table('guardians', [
    Column.text('program_id'),
    Column.text('name'),
    Column.text('relationship'),
    Column.text('phone'),
    Column.text('email'),
    Column.integer('authorized_for_pickup'),
    Column.text('notes'),
    Column.text('created_at'),
    Column.text('updated_at'),
  ]),
  Table('student_guardians', [
    Column.text('student_id'),
    Column.text('guardian_id'),
    Column.text('program_id'),
    Column.integer('is_primary'),
    Column.text('created_at'),
  ]),
  Table('attendance_records', [
    Column.text('program_id'),
    Column.text('classroom_id'),
    Column.text('student_id'),
    Column.text('date'),
    Column.text('status'),
    Column.text('notes'),
    Column.text('recorded_by'),
    Column.text('recorded_at'),
    Column.text('updated_at'),
  ]),
]);
