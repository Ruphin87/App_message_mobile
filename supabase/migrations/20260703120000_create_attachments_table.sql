CREATE TABLE IF NOT EXISTS attachments (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  message_id UUID NOT NULL REFERENCES messages(id) ON DELETE CASCADE,
  file_url TEXT NOT NULL,
  file_type TEXT NOT NULL CHECK (file_type IN ('image', 'pdf', 'audio', 'document')),
  file_name TEXT,
  file_size INTEGER,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_attachments_message_id
  ON attachments(message_id);

ALTER TABLE attachments ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Participants can read attachments"
  ON attachments
  FOR SELECT
  USING (
    EXISTS (
      SELECT 1
      FROM messages m
      JOIN conversations c ON c.id = m.conversation_id
      WHERE m.id = attachments.message_id
        AND (c.user1 = auth.uid() OR c.user2 = auth.uid())
    )
  );

CREATE POLICY "Message sender can create attachments"
  ON attachments
  FOR INSERT
  WITH CHECK (
    EXISTS (
      SELECT 1
      FROM messages m
      WHERE m.id = attachments.message_id
        AND m.sender_id = auth.uid()
    )
  );

INSERT INTO storage.buckets (id, name, public)
VALUES ('message-attachments', 'message-attachments', true)
ON CONFLICT (id) DO UPDATE SET public = EXCLUDED.public;

CREATE POLICY "Participants can upload message attachments"
  ON storage.objects
  FOR INSERT
  WITH CHECK (
    bucket_id = 'message-attachments'
    AND auth.role() = 'authenticated'
  );

CREATE POLICY "Public can read message attachments"
  ON storage.objects
  FOR SELECT
  USING (bucket_id = 'message-attachments');
