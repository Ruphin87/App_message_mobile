CREATE TABLE users (
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  nom TEXT NOT NULL,
  email TEXT NOT NULL UNIQUE,
  photo TEXT,
  date_creation TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

ALTER TABLE users ENABLE ROW LEVEL SECURITY;

CREATE POLICY "select_own_user" ON users FOR SELECT
  TO authenticated USING (auth.uid() = id);

CREATE POLICY "insert_own_user" ON users FOR INSERT
  TO authenticated WITH CHECK (auth.uid() = id);

CREATE POLICY "update_own_user" ON users FOR UPDATE
  TO authenticated USING (auth.uid() = id) WITH CHECK (auth.uid() = id);

CREATE POLICY "delete_own_user" ON users FOR DELETE
  TO authenticated USING (auth.uid() = id);

CREATE INDEX idx_users_email ON users(email);