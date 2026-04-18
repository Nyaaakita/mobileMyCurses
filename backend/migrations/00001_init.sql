-- +goose Up
create extension if not exists "uuid-ossp";

create table if not exists users (
    id uuid primary key,
    email text not null unique,
    name text not null,
    password_hash text not null,
    role text not null check (role in ('student', 'admin')),
    created_at timestamptz not null default now()
);

create table if not exists courses (
    id uuid primary key,
    title text not null,
    description text not null,
    cover_url text,
    difficulty text not null check (difficulty in ('beginner', 'intermediate', 'advanced')),
    estimated_minutes int not null default 30,
    content_version int not null default 1,
    is_published bool not null default false,
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now()
);

create table if not exists lessons (
    id uuid primary key default uuid_generate_v4(),
    course_id uuid not null references courses(id) on delete cascade,
    title text not null,
    order_index int not null,
    content_version int not null default 1,
    blocks jsonb not null default '[]'::jsonb,
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now(),
    unique(course_id, order_index)
);

create table if not exists quizzes (
    id uuid primary key default uuid_generate_v4(),
    lesson_id uuid not null references lessons(id) on delete cascade,
    title text not null,
    questions jsonb not null default '[]'::jsonb,
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now()
);

create table if not exists assignments (
    id uuid primary key default uuid_generate_v4(),
    lesson_id uuid not null references lessons(id) on delete cascade,
    kind text not null check (kind in ('code_challenge', 'ordering', 'free_text')),
    config jsonb not null default '{}'::jsonb,
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now()
);

create table if not exists user_progress (
    id uuid primary key default uuid_generate_v4(),
    user_id uuid not null references users(id) on delete cascade,
    lesson_id uuid not null references lessons(id) on delete cascade,
    status text not null check (status in ('started', 'completed')),
    score int,
    answers jsonb,
    client_version int not null default 1,
    updated_at timestamptz not null default now(),
    unique(user_id, lesson_id)
);

create table if not exists progress_events (
    id uuid primary key,
    user_id uuid not null references users(id) on delete cascade,
    payload jsonb not null,
    created_at timestamptz not null default now()
);

create index if not exists idx_courses_published on courses(is_published);
create index if not exists idx_lessons_course on lessons(course_id);
create index if not exists idx_progress_user on user_progress(user_id);

-- +goose Down
drop table if exists progress_events;
drop table if exists user_progress;
drop table if exists assignments;
drop table if exists quizzes;
drop table if exists lessons;
drop table if exists courses;
drop table if exists users;
