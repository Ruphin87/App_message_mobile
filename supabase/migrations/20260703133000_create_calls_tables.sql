CREATE TABLE IF NOT EXISTS calls (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  caller_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  receiver_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  media_type TEXT NOT NULL CHECK (media_type IN ('audio', 'video')),
  status TEXT NOT NULL DEFAULT 'ringing'
    CHECK (status IN ('ringing', 'accepted', 'declined', 'ended', 'missed')),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  answered_at TIMESTAMPTZ,
  ended_at TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS idx_calls_caller_id ON calls(caller_id);
CREATE INDEX IF NOT EXISTS idx_calls_receiver_id ON calls(receiver_id);
CREATE INDEX IF NOT EXISTS idx_calls_status ON calls(status);

ALTER TABLE calls ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Participants can read calls"
  ON calls
  FOR SELECT
  USING (caller_id = auth.uid() OR receiver_id = auth.uid());

CREATE POLICY "Users can create outgoing calls"
  ON calls
  FOR INSERT
  WITH CHECK (caller_id = auth.uid());

CREATE POLICY "Participants can update calls"
  ON calls
  FOR UPDATE
  USING (caller_id = auth.uid() OR receiver_id = auth.uid())
  WITH CHECK (caller_id = auth.uid() OR receiver_id = auth.uid());

CREATE TABLE IF NOT EXISTS call_events (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  call_id UUID NOT NULL REFERENCES calls(id) ON DELETE CASCADE,
  sender_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  event_type TEXT NOT NULL CHECK (event_type IN ('offer', 'answer', 'candidate')),
  payload JSONB NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_call_events_call_id_created_at
  ON call_events(call_id, created_at);

ALTER TABLE call_events ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Participants can read call events"
  ON call_events
  FOR SELECT
  USING (
    EXISTS (
      SELECT 1
      FROM calls c
      WHERE c.id = call_events.call_id
        AND (c.caller_id = auth.uid() OR c.receiver_id = auth.uid())
    )
  );

CREATE POLICY "Participants can create call events"
  ON call_events
  FOR INSERT
  WITH CHECK (
    sender_id = auth.uid()
    AND EXISTS (
      SELECT 1
      FROM calls c
      WHERE c.id = call_events.call_id
        AND (c.caller_id = auth.uid() OR c.receiver_id = auth.uid())
    )
  );
