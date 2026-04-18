-- +goose Up
create table if not exists assignment_attempts (
    id uuid primary key default uuid_generate_v4(),
    user_id uuid not null references users(id) on delete cascade,
    assignment_id uuid not null references assignments(id) on delete cascade,
    lesson_id uuid not null references lessons(id) on delete cascade,
    status text not null,
    score int,
    answer_text text not null,
    language text,
    created_at timestamptz not null default now()
);

create index if not exists idx_assignment_attempts_user on assignment_attempts(user_id);
create index if not exists idx_assignment_attempts_assignment on assignment_attempts(assignment_id);
create index if not exists idx_assignment_attempts_lesson on assignment_attempts(lesson_id);
create index if not exists idx_assignment_attempts_created on assignment_attempts(created_at);

-- +goose Down
drop table if exists assignment_attempts;

