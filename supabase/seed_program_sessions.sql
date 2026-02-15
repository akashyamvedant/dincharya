-- ============================================
-- Seed program_sessions: link existing sessions to programs
-- Run this in Supabase SQL Editor AFTER phase2_migration.sql
-- ============================================

-- This will link random existing sessions from the same category to each program.
-- Each program gets its sessions filled based on total_sessions count.

DO $$
DECLARE
  prog RECORD;
  sess RECORD;
  seq_idx INTEGER;
BEGIN
  FOR prog IN SELECT id, category, total_sessions FROM public.programs WHERE is_active = true
  LOOP
    seq_idx := 0;
    -- For 'mixed' category, pick from all categories
    IF prog.category = 'mixed' THEN
      FOR sess IN
        SELECT id FROM public.sessions
        WHERE is_active = true
        ORDER BY random()
        LIMIT prog.total_sessions
      LOOP
        INSERT INTO public.program_sessions (program_id, session_id, sequence_order, day_number)
        VALUES (prog.id, sess.id, seq_idx, seq_idx + 1)
        ON CONFLICT (program_id, sequence_order) DO NOTHING;
        seq_idx := seq_idx + 1;
      END LOOP;
    ELSE
      FOR sess IN
        SELECT id FROM public.sessions
        WHERE is_active = true AND category = prog.category
        ORDER BY random()
        LIMIT prog.total_sessions
      LOOP
        INSERT INTO public.program_sessions (program_id, session_id, sequence_order, day_number)
        VALUES (prog.id, sess.id, seq_idx, seq_idx + 1)
        ON CONFLICT (program_id, sequence_order) DO NOTHING;
        seq_idx := seq_idx + 1;
      END LOOP;
    END IF;

    -- Update total_sessions to the actual count linked
    UPDATE public.programs
      SET total_sessions = seq_idx
      WHERE id = prog.id AND seq_idx > 0;
  END LOOP;
END $$;
