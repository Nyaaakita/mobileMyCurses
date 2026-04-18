-- +goose Up
-- Демо: admin@example.com / password123
insert into users (id, email, name, password_hash, role) values
(
    '00000000-0000-4000-8000-0000000000ad'::uuid,
    'admin@example.com',
    'Admin',
    '$2a$10$Kw8A76UE.zwHyiiKFGnYn.XvQLoGg.8xTFsfHA4AfiekvpeOWA1lm',
    'admin'
)
on conflict (email) do nothing;

insert into courses (id, title, description, difficulty, estimated_minutes, is_published, content_version) values
(
    'a0000000-0000-4000-8000-000000000001'::uuid,
    'Введение в Go',
    'Короткий демонстрационный курс: урок с текстом и заданием, урок с тестом.',
    'beginner',
    45,
    true,
    1
)
on conflict (id) do nothing;

insert into lessons (id, course_id, title, order_index, content_version, blocks) values
(
    'b0000000-0000-4000-8000-000000000001'::uuid,
    'a0000000-0000-4000-8000-000000000001'::uuid,
    'Первый урок',
    1,
    1,
    $b1$
    [
      {"id":"m1","type":"markdown","payload":{"text":"# Добро пожаловать\nНапишите в задании слово **hello** (латиницей, без кавычек)."}},
      {"id":"blk-a","type":"assignment","payload":{"assignment_id":"d0000000-0000-4000-8000-000000000001"}}
    ]
    $b1$::jsonb
)
on conflict (id) do nothing;

insert into assignments (id, lesson_id, kind, config) values
(
    'd0000000-0000-4000-8000-000000000001'::uuid,
    'b0000000-0000-4000-8000-000000000001'::uuid,
    'free_text',
    '{"expected":"hello"}'::jsonb
)
on conflict (id) do nothing;

insert into lessons (id, course_id, title, order_index, content_version, blocks) values
(
    'b0000000-0000-4000-8000-000000000002'::uuid,
    'a0000000-0000-4000-8000-000000000001'::uuid,
    'Мини-тест',
    2,
    1,
    '[]'::jsonb
)
on conflict (id) do nothing;

insert into quizzes (id, lesson_id, title, questions) values
(
    'c0000000-0000-4000-8000-000000000001'::uuid,
    'b0000000-0000-4000-8000-000000000002'::uuid,
    'Арифметика',
    $qq$
    [
      {
        "id":"q1",
        "text":"Сколько будет 2 + 2?",
        "type":"single_choice",
        "options":[
          {"id":"o1","text":"3","is_correct":false},
          {"id":"o2","text":"4","is_correct":true}
        ]
      }
    ]
    $qq$::jsonb
)
on conflict (id) do nothing;

update lessons
set blocks = $b2$
[
  {"id":"blk-q","type":"quiz","payload":{"quiz_id":"c0000000-0000-4000-8000-000000000001"}}
]
$b2$::jsonb,
    content_version = 2,
    updated_at = now()
where id = 'b0000000-0000-4000-8000-000000000002'::uuid;

-- +goose Down
delete from quizzes where id = 'c0000000-0000-4000-8000-000000000001'::uuid;
delete from assignments where id = 'd0000000-0000-4000-8000-000000000001'::uuid;
delete from lessons where course_id = 'a0000000-0000-4000-8000-000000000001'::uuid;
delete from courses where id = 'a0000000-0000-4000-8000-000000000001'::uuid;
delete from users where id = '00000000-0000-4000-8000-0000000000ad'::uuid;
