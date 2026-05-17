-- Different World — PowerSync replication setup
--
-- Creates the `powersync` publication that the PowerSync service tails
-- via logical replication. Every table here must also appear in
-- supabase/sync_rules.yaml — adding a table to one and forgetting the
-- other is the most common sync bug.
--
-- REPLICA IDENTITY FULL ensures the full pre-image of a row is written
-- to the WAL on UPDATE/DELETE. PowerSync needs this to compute deltas
-- and to handle deletes that target rows not addressable by PK alone.

alter table public.programs           replica identity full;
alter table public.profiles           replica identity full;
alter table public.classrooms         replica identity full;
alter table public.enrollments        replica identity full;
alter table public.students           replica identity full;
alter table public.guardians          replica identity full;
alter table public.student_guardians  replica identity full;
alter table public.attendance_records replica identity full;

create publication powersync for table
  public.programs,
  public.profiles,
  public.classrooms,
  public.enrollments,
  public.students,
  public.guardians,
  public.student_guardians,
  public.attendance_records;
