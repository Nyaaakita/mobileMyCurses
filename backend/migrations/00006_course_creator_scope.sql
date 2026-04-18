-- +goose Up
alter table courses
    add column if not exists creator_id uuid references users(id);

update courses c
set creator_id = u.id
from (
    select id
    from users
    where role = 'admin'
    order by created_at asc
    limit 1
) u
where c.creator_id is null;

alter table courses
    alter column creator_id set not null;

create index if not exists idx_courses_creator_id on courses(creator_id);

-- +goose Down
drop index if exists idx_courses_creator_id;
alter table courses drop column if exists creator_id;
