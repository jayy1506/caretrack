-- Migration 0003: Rate Limiting Table for Edge Functions
create table if not exists rate_limits (
  key text primary key,
  count int not null default 1,
  reset_at timestamptz not null,
  created_at timestamptz not null default now()
);

-- Index for expiring old rate limit windows
create index if not exists idx_rate_limits_reset_at on rate_limits (reset_at);

-- RLS: Service role only can read and write rate_limits
alter table rate_limits enable row level security;
