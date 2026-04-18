-- +goose Up
create table if not exists quiz_attempts (
    id uuid primary key default uuid_generate_v4(),
    user_id uuid not null references users(id) on delete cascade,
    quiz_id uuid not null references quizzes(id) on delete cascade,
    lesson_id uuid not null references lessons(id) on delete cascade,
    score int not null,
    max_score int not null,
    passed bool not null,
    answers jsonb not null default '[]'::jsonb,
    created_at timestamptz not null default now()
);

create index if not exists idx_quiz_attempts_user on quiz_attempts(user_id);
create index if not exists idx_quiz_attempts_quiz on quiz_attempts(quiz_id);
create index if not exists idx_quiz_attempts_lesson on quiz_attempts(lesson_id);
create index if not exists idx_quiz_attempts_created on quiz_attempts(created_at);

-- Бекфилл из user_progress для уже пройденных квиз-уроков.
insert into quiz_attempts (user_id, quiz_id, lesson_id, score, max_score, passed, answers, created_at)
select
    up.user_id,
    q.id as quiz_id,
    l.id as lesson_id,
    coalesce(up.score, 0) as score,
    100 as max_score,
    coalesce(up.score, 0) >= 60 as passed,
    coalesce(up.answers, '[]'::jsonb) as answers,
    up.updated_at
from user_progress up
join lessons l on l.id = up.lesson_id
join quizzes q on q.lesson_id = l.id
where up.status = 'completed' or up.score is not null;

-- +goose Down
drop table if exists quiz_attempts;

