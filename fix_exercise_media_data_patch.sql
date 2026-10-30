-- Patch: copy trainer-uploaded image_urls from the duplicate exercise onto the
-- canonical seed row so students see the trainer's photo without any app update.
--
-- Trainer copy:  4c385ee7 ("Jalón unilaterall", double-l) -- has image_urls
-- Seed original: 6b5bc8cc ("Jalón unilateral")            -- image_urls was NULL
--
-- All active student routines point at the seed id. After this patch the student
-- routine select (routine_exercises(*, exercises(*))) returns the image correctly.
-- Applied 2026-10-30 via Supabase MCP.

UPDATE exercises
SET
  image_urls = (
    SELECT image_urls
    FROM exercises
    WHERE id = '4c385ee7-aaa3-42b2-96c0-c6d440ece038'
  ),
  video_url = COALESCE(
    video_url,
    (SELECT video_url FROM exercises WHERE id = '4c385ee7-aaa3-42b2-96c0-c6d440ece038')
  )
WHERE id = '6b5bc8cc-b4f1-493a-9f72-1a0531bf810f'
  AND created_by_trainer IS NULL; -- safety: only touch the seed row
