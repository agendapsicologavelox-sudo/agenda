-- ============================================================
--  AGENDAMENTO PSICÓLOGA — Setup do Banco de Dados Supabase
--  Cole e execute no SQL Editor do seu projeto Supabase
-- ============================================================

-- Extensão para hash SHA-256
CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- ── Tabelas ──────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS access_codes (
  id         SERIAL PRIMARY KEY,
  code       TEXT UNIQUE NOT NULL,
  name       TEXT NOT NULL,
  email      TEXT NOT NULL,
  active     BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS time_slots (
  id         SERIAL PRIMARY KEY,
  date       DATE NOT NULL,
  time       TIME NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(date, time)
);

CREATE TABLE IF NOT EXISTS bookings (
  id        SERIAL PRIMARY KEY,
  slot_id   INTEGER UNIQUE NOT NULL REFERENCES time_slots(id) ON DELETE CASCADE,
  code_id   INTEGER NOT NULL REFERENCES access_codes(id) ON DELETE CASCADE,
  booked_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS admin_config (
  id            INTEGER PRIMARY KEY DEFAULT 1,
  password_hash TEXT NOT NULL
);

-- ── Senha Admin padrão: "admin123" ───────────────────────────
-- IMPORTANTE: Troque a senha no painel Admin assim que configurar!
INSERT INTO admin_config (id, password_hash)
VALUES (1, encode(digest('admin123', 'sha256'), 'hex'))
ON CONFLICT (id) DO NOTHING;

-- ── View de disponibilidade (não expõe quem agendou) ─────────
CREATE OR REPLACE VIEW slot_availability AS
SELECT
  ts.id,
  ts.date::text,
  ts.time::text,
  CASE WHEN b.id IS NOT NULL THEN true ELSE false END AS booked,
  b.code_id  -- usado internamente para verificar "é meu agendamento"
FROM time_slots ts
LEFT JOIN bookings b ON b.slot_id = ts.id;

-- ── Desabilitar RLS (sistema interno da empresa) ─────────────
ALTER TABLE access_codes  DISABLE ROW LEVEL SECURITY;
ALTER TABLE time_slots    DISABLE ROW LEVEL SECURITY;
ALTER TABLE bookings      DISABLE ROW LEVEL SECURITY;
ALTER TABLE admin_config  DISABLE ROW LEVEL SECURITY;

-- ── Permissões para a chave anônima ──────────────────────────
GRANT SELECT ON access_codes  TO anon;
GRANT SELECT ON time_slots    TO anon;
GRANT SELECT, INSERT, DELETE ON bookings TO anon;
GRANT SELECT ON slot_availability TO anon;
GRANT USAGE, SELECT ON SEQUENCE bookings_id_seq TO anon;

-- Bloquear acesso anon à tabela admin_config
REVOKE ALL ON admin_config FROM anon;

-- ── Mensagem de confirmação ───────────────────────────────────
SELECT 'Setup concluído com sucesso! Senha admin padrão: admin123' AS resultado;
