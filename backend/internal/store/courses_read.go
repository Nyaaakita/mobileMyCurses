package store

import (
	"context"
	"encoding/json"
	"errors"

	"github.com/jackc/pgx/v5"
)

// CourseListRow — курс в каталоге с процентом прогресса пользователя.
type CourseListRow struct {
	Course
	ProgressPercent int `json:"progress_percent"`
	IsStarted       bool `json:"is_started"`
}

// ListPublishedCoursesForUser — опубликованные курсы и доля завершённых уроков (0–100).
func (s *Store) ListPublishedCoursesForUser(ctx context.Context, userID string) ([]CourseListRow, error) {
	rows, err := s.db.Query(ctx, `
		with lesson_counts as (
			select course_id, count(*)::int as n from lessons group by course_id
		),
		done_counts as (
			select l.course_id, count(*)::int as n
			from user_progress up
			join lessons l on l.id = up.lesson_id
			where up.user_id = $1::uuid and up.status = 'completed'
			group by l.course_id
		),
		started_counts as (
			select l.course_id, count(*)::int as n
			from user_progress up
			join lessons l on l.id = up.lesson_id
			where up.user_id = $1::uuid
			group by l.course_id
		)
		select c.id::text, c.title, c.description, c.cover_url, c.difficulty, c.estimated_minutes,
		       c.content_version, c.is_published,
		       case
		         when coalesce(lc.n, 0) = 0 then 0
		         else least(100, (coalesce(dc.n, 0) * 100 / lc.n))
		       end as progress_percent,
		       (coalesce(sc.n, 0) > 0) as is_started
		from courses c
		left join lesson_counts lc on lc.course_id = c.id
		left join done_counts dc on dc.course_id = c.id
		left join started_counts sc on sc.course_id = c.id
		where c.is_published = true
		order by c.created_at desc
	`, userID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	out := make([]CourseListRow, 0)
	for rows.Next() {
		var r CourseListRow
		if err := rows.Scan(
			&r.ID, &r.Title, &r.Description, &r.CoverURL, &r.Difficulty, &r.EstimatedMinutes,
			&r.ContentVersion, &r.IsPublished, &r.ProgressPercent, &r.IsStarted,
		); err != nil {
			return nil, err
		}
		out = append(out, r)
	}
	return out, rows.Err()
}

// GetPublishedCourse возвращает опубликованный курс по id.
func (s *Store) GetPublishedCourse(ctx context.Context, courseID string) (Course, error) {
	var c Course
	err := s.db.QueryRow(ctx, `
		select id::text, title, description, cover_url, difficulty, estimated_minutes, content_version, is_published
		from courses
		where id = $1::uuid and is_published = true
	`, courseID).Scan(
		&c.ID, &c.Title, &c.Description, &c.CoverURL, &c.Difficulty, &c.EstimatedMinutes,
		&c.ContentVersion, &c.IsPublished,
	)
	if errors.Is(err, pgx.ErrNoRows) {
		return Course{}, ErrNotFound
	}
	return c, err
}

// LessonEntity — урок из БД.
type LessonEntity struct {
	ID             string          `json:"id"`
	CourseID       string          `json:"course_id"`
	Title          string          `json:"title"`
	OrderIndex     int             `json:"order_index"`
	ContentVersion int             `json:"content_version"`
	Blocks         json.RawMessage `json:"blocks"`
}

// ListLessonsByCourse — уроки курса по возрастанию order_index.
func (s *Store) ListLessonsByCourse(ctx context.Context, courseID string) ([]LessonEntity, error) {
	rows, err := s.db.Query(ctx, `
		select id::text, course_id::text, title, order_index, content_version, blocks
		from lessons
		where course_id = $1::uuid
		order by order_index asc
	`, courseID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	list := make([]LessonEntity, 0)
	for rows.Next() {
		var e LessonEntity
		var raw []byte
		if err := rows.Scan(&e.ID, &e.CourseID, &e.Title, &e.OrderIndex, &e.ContentVersion, &raw); err != nil {
			return nil, err
		}
		e.Blocks = json.RawMessage(raw)
		list = append(list, e)
	}
	return list, rows.Err()
}

// GetLessonPublished проверяет, что урок принадлежит опубликованному курсу, и возвращает его.
func (s *Store) GetLessonPublished(ctx context.Context, lessonID string) (LessonEntity, error) {
	var e LessonEntity
	var raw []byte
	err := s.db.QueryRow(ctx, `
		select l.id::text, l.course_id::text, l.title, l.order_index, l.content_version, l.blocks
		from lessons l
		join courses c on c.id = l.course_id
		where l.id = $1::uuid and c.is_published = true
	`, lessonID).Scan(&e.ID, &e.CourseID, &e.Title, &e.OrderIndex, &e.ContentVersion, &raw)
	if errors.Is(err, pgx.ErrNoRows) {
		return LessonEntity{}, ErrNotFound
	}
	if err != nil {
		return LessonEntity{}, err
	}
	e.Blocks = json.RawMessage(raw)
	return e, nil
}
