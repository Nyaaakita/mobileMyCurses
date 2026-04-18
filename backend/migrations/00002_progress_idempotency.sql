-- +goose Up
create table if not exists progress_idempotency (
    user_id uuid not null references users(id) on delete cascade,
    client_event_id uuid not null,
    created_at timestamptz not null default now(),
    primary key (user_id, client_event_id)
);

create index if not exists idx_progress_idem_user on progress_idempotency(user_id);

-- +goose Down
drop table if exists progress_idempotency;
