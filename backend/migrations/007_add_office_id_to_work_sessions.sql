-- Migration: 007_add_office_id_to_work_sessions
-- Direction: up

ALTER TABLE work_sessions
  ADD COLUMN office_id UUID REFERENCES offices(id) ON DELETE SET NULL;

-- Direction: down
-- ALTER TABLE work_sessions DROP COLUMN office_id;