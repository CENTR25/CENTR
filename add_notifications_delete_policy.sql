-- Migration: add_notifications_delete_policy
-- notifications had SELECT + UPDATE policies for users but no DELETE.
-- This allows users to dismiss/delete their own notifications.

CREATE POLICY "Users delete own notifications"
  ON public.notifications
  FOR DELETE
  TO authenticated
  USING (user_id = auth.uid());
