CREATE POLICY "Message sender can delete attachments"
  ON attachments
  FOR DELETE
  USING (
    EXISTS (
      SELECT 1
      FROM messages m
      WHERE m.id = attachments.message_id
        AND m.sender_id = auth.uid()
    )
  );

CREATE POLICY "Authenticated users can delete message attachment objects"
  ON storage.objects
  FOR DELETE
  USING (
    bucket_id = 'message-attachments'
    AND owner = auth.uid()
  );
