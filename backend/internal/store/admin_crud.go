package store

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"slices"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
)

func (s *Store) ListCoursesAdmin(ctx context.Context) ([]Course, error) {
	rows, err := s.db.Query(ctx, `
		select id::text, title, description, cover_url, difficulty, estimated_minutes, content_version, is_published
		from courses
		order by created_at desc
	`)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	out := make([]Course, 0)
	for rows.Next() {
		var c Course
		if err := rows.Scan(&c.ID, &c.Title, &c.Description, &c.CoverURL, &c.Difficulty, &c.EstimatedMinutes, &c.ContentVersion, &c.IsPublished); err != nil {
			return nil, err
		}
		out = append(out, c)
	}
	return out, rows.Err()
}

func (s *Store) ListCoursesAdminByOwner(ctx context.Context, ownerUserID string) ([]Course, error) {
	rows, err := s.db.Query(ctx, `
		select id::text, title, description, cover_url, difficulty, estimated_minutes, content_version, is_published
		from courses
		where creator_id = $1::uuid
		order by created_at desc
	`, ownerUserID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	out := make([]Course, 0)
	for rows.Next() {
		var c Course
		if err := rows.Scan(&c.ID, &c.Title, &c.Description, &c.CoverURL, &c.Difficulty, &c.EstimatedMinutes, &c.ContentVersion, &c.IsPublished); err != nil {
			return nil, err
		}
		out = append(out, c)
	}
	return out, rows.Err()
}

func (s *Store) IsCourseOwnedBy(ctx context.Context, courseID, ownerUserID string) (bool, error) {
	var ok bool
	err := s.db.QueryRow(ctx, `
		select exists (
			select 1
			from courses
			where id = $1::uuid and creator_id = $2::uuid
		)
	`, courseID, ownerUserID).Scan(&ok)
	return ok, err
}

func (s *Store) IsLessonOwnedBy(ctx context.Context, lessonID, ownerUserID string) (bool, error) {
	var ok bool
	err := s.db.QueryRow(ctx, `
		select exists (
			select 1
			from lessons l
			join courses c on c.id = l.course_id
			where l.id = $1::uuid and c.creator_id = $2::uuid
		)
	`, lessonID, ownerUserID).Scan(&ok)
	return ok, err
}

func (s *Store) IsQuizOwnedBy(ctx context.Context, quizID, ownerUserID string) (bool, error) {
	var ok bool
	err := s.db.QueryRow(ctx, `
		select exists (
			select 1
			from quizzes q
			join lessons l on l.id = q.lesson_id
			join courses c on c.id = l.course_id
			where q.id = $1::uuid and c.creator_id = $2::uuid
		)
	`, quizID, ownerUserID).Scan(&ok)
	return ok, err
}

// GetCourseByID — курс без фильтра по публикации (админ).
func (s *Store) GetCourseByID(ctx context.Context, courseID string) (Course, error) {
	var c Course
	err := s.db.QueryRow(ctx, `
		select id::text, title, description, cover_url, difficulty, estimated_minutes, content_version, is_published
		from courses where id = $1::uuid
	`, courseID).Scan(
		&c.ID, &c.Title, &c.Description, &c.CoverURL, &c.Difficulty, &c.EstimatedMinutes, &c.ContentVersion, &c.IsPublished,
	)
	if errors.Is(err, pgx.ErrNoRows) {
		return Course{}, ErrNotFound
	}
	return c, err
}

func (s *Store) BumpCourseVersion(ctx context.Context, courseID string) error {
	_, err := s.db.Exec(ctx, `
		update courses set content_version = content_version + 1, updated_at = now() where id = $1::uuid
	`, courseID)
	return err
}

// UpdateCourse частичное обновление курса; bump content_version.
func (s *Store) UpdateCourse(ctx context.Context, courseID string, title, description, difficulty *string, isPublished *bool) (Course, error) {
	ct, err := s.db.Exec(ctx, `
		update courses set
			title = coalesce($2, title),
			description = coalesce($3, description),
			difficulty = coalesce($4, difficulty),
			is_published = coalesce($5, is_published),
			content_version = content_version + 1,
			updated_at = now()
		where id = $1::uuid
	`, courseID, title, description, difficulty, isPublished)
	if err != nil {
		return Course{}, err
	}
	if ct.RowsAffected() == 0 {
		return Course{}, ErrNotFound
	}
	return s.GetCourseByID(ctx, courseID)
}

func (s *Store) DeleteCourse(ctx context.Context, courseID string) error {
	ct, err := s.db.Exec(ctx, `delete from courses where id = $1::uuid`, courseID)
	if err != nil {
		return err
	}
	if ct.RowsAffected() == 0 {
		return ErrNotFound
	}
	return nil
}

// MaxLessonOrder возвращает максимальный order_index урока курса (0, если уроков нет).
func (s *Store) MaxLessonOrder(ctx context.Context, courseID string) (int, error) {
	var m *int
	err := s.db.QueryRow(ctx, `
		select max(order_index) from lessons where course_id = $1::uuid
	`, courseID).Scan(&m)
	if err != nil {
		return 0, err
	}
	if m == nil {
		return 0, nil
	}
	return *m, nil
}

// CreateLesson создаёт урок с JSONB blocks.
func (s *Store) CreateLesson(ctx context.Context, courseID, title string, orderIndex int, blocks json.RawMessage) (LessonEntity, error) {
	var b interface{}
	if len(blocks) > 0 && string(blocks) != "null" {
		b = blocks
	} else {
		b = []byte("[]")
	}
	id := uuid.New()
	var e LessonEntity
	var raw []byte
	err := s.db.QueryRow(ctx, `
		insert into lessons (id, course_id, title, order_index, content_version, blocks)
		values ($1, $2::uuid, $3, $4, 1, $5::jsonb)
		returning id::text, course_id::text, title, order_index, content_version, blocks
	`, id, courseID, title, orderIndex, b).Scan(&e.ID, &e.CourseID, &e.Title, &e.OrderIndex, &e.ContentVersion, &raw)
	if err != nil {
		return LessonEntity{}, err
	}
	e.Blocks = json.RawMessage(raw)
	_ = s.BumpCourseVersion(ctx, courseID)
	return e, nil
}

// UpdateLesson: blocks != nil — обновить blocks; blocks == nil — поле blocks не трогать.
func (s *Store) UpdateLesson(ctx context.Context, lessonID string, title *string, orderIndex *int, blocks *json.RawMessage) (LessonEntity, error) {
	hasBlocks := blocks != nil && len(*blocks) > 0 && string(*blocks) != "null"
	var b interface{}
	if hasBlocks {
		b = *blocks
	}
	var e LessonEntity
	var err error
	var raw []byte
	if hasBlocks {
		err = s.db.QueryRow(ctx, `
			update lessons set
				title = coalesce($2, title),
				order_index = coalesce($3, order_index),
				blocks = $4::jsonb,
				content_version = content_version + 1,
				updated_at = now()
			where id = $1::uuid
			returning id::text, course_id::text, title, order_index, content_version, blocks
		`, lessonID, title, orderIndex, b).Scan(&e.ID, &e.CourseID, &e.Title, &e.OrderIndex, &e.ContentVersion, &raw)
	} else {
		err = s.db.QueryRow(ctx, `
			update lessons set
				title = coalesce($2, title),
				order_index = coalesce($3, order_index),
				content_version = content_version + 1,
				updated_at = now()
			where id = $1::uuid
			returning id::text, course_id::text, title, order_index, content_version, blocks
		`, lessonID, title, orderIndex).Scan(&e.ID, &e.CourseID, &e.Title, &e.OrderIndex, &e.ContentVersion, &raw)
	}
	e.Blocks = json.RawMessage(raw)
	if errors.Is(err, pgx.ErrNoRows) {
		return LessonEntity{}, ErrNotFound
	}
	if err != nil {
		return LessonEntity{}, err
	}
	_ = s.BumpCourseVersion(ctx, e.CourseID)
	return e, nil
}

// ReorderLessons выставляет order_index для списка уроков одного курса.
// Двухфазное обновление обязательно: иначе при обмене двумя индексами срабатывает
// unique(course_id, order_index) и транзакция падает.
func (s *Store) ReorderLessons(ctx context.Context, courseID string, orders map[string]int) error {
	if len(orders) == 0 {
		return nil
	}
	tx, err := s.db.Begin(ctx)
	if err != nil {
		return err
	}
	defer tx.Rollback(ctx)

	ids := make([]string, 0, len(orders))
	for id := range orders {
		ids = append(ids, id)
	}
	slices.Sort(ids)

	const tempBase = -1_000_000
	for i, lid := range ids {
		ct, err := tx.Exec(ctx, `
			update lessons set order_index = $3, updated_at = now()
			where id = $1::uuid and course_id = $2::uuid
		`, lid, courseID, tempBase-i)
		if err != nil {
			return err
		}
		if ct.RowsAffected() == 0 {
			return fmt.Errorf("lesson %s not in course", lid)
		}
	}

	for lid, ord := range orders {
		ct, err := tx.Exec(ctx, `
			update lessons set order_index = $3, updated_at = now()
			where id = $1::uuid and course_id = $2::uuid
		`, lid, courseID, ord)
		if err != nil {
			return err
		}
		if ct.RowsAffected() == 0 {
			return fmt.Errorf("lesson %s not in course", lid)
		}
	}

	if err := tx.Commit(ctx); err != nil {
		return err
	}
	return s.BumpCourseVersion(ctx, courseID)
}

func (s *Store) DeleteLesson(ctx context.Context, lessonID string) error {
	ct, err := s.db.Exec(ctx, `delete from lessons where id = $1::uuid`, lessonID)
	if err != nil {
		return err
	}
	if ct.RowsAffected() == 0 {
		return ErrNotFound
	}
	return nil
}

func (s *Store) CreateQuiz(ctx context.Context, lessonID, title string, questions json.RawMessage) (QuizEntity, error) {
	var qjson interface{} = questions
	id := uuid.New()
	var q QuizEntity
	var raw []byte
	err := s.db.QueryRow(ctx, `
		insert into quizzes (id, lesson_id, title, questions)
		values ($1, $2::uuid, $3, $4::jsonb)
		returning id::text, lesson_id::text, title, questions
	`, id, lessonID, title, qjson).Scan(&q.ID, &q.LessonID, &q.Title, &raw)
	if err != nil {
		return QuizEntity{}, err
	}
	q.Questions = json.RawMessage(raw)
	var cid string
	if err := s.db.QueryRow(ctx, `select course_id::text from lessons where id = $1::uuid`, lessonID).Scan(&cid); err == nil {
		_ = s.BumpCourseVersion(ctx, cid)
	}
	return q, nil
}

func (s *Store) GetQuizByLesson(ctx context.Context, lessonID string) (QuizEntity, error) {
	var q QuizEntity
	var raw []byte
	err := s.db.QueryRow(ctx, `
		select id::text, lesson_id::text, title, questions
		from quizzes
		where lesson_id = $1::uuid
		order by updated_at desc
		limit 1
	`, lessonID).Scan(&q.ID, &q.LessonID, &q.Title, &raw)
	if errors.Is(err, pgx.ErrNoRows) {
		return QuizEntity{}, ErrNotFound
	}
	if err != nil {
		return QuizEntity{}, err
	}
	q.Questions = json.RawMessage(raw)
	return q, nil
}

func (s *Store) UpdateQuiz(ctx context.Context, quizID, title string, questions json.RawMessage) (QuizEntity, error) {
	var q QuizEntity
	var raw []byte
	err := s.db.QueryRow(ctx, `
		update quizzes set title = $2, questions = $3::jsonb, updated_at = now()
		where id = $1::uuid
		returning id::text, lesson_id::text, title, questions
	`, quizID, title, questions).Scan(&q.ID, &q.LessonID, &q.Title, &raw)
	if errors.Is(err, pgx.ErrNoRows) {
		return QuizEntity{}, ErrNotFound
	}
	if err != nil {
		return QuizEntity{}, err
	}
	q.Questions = json.RawMessage(raw)
	var cid string
	if err := s.db.QueryRow(ctx, `select course_id::text from lessons where id = $1::uuid`, q.LessonID).Scan(&cid); err == nil {
		_ = s.BumpCourseVersion(ctx, cid)
	}
	return q, nil
}

func (s *Store) DeleteQuiz(ctx context.Context, quizID string) error {
	var lessonID string
	err := s.db.QueryRow(ctx, `select lesson_id::text from quizzes where id = $1::uuid`, quizID).Scan(&lessonID)
	if errors.Is(err, pgx.ErrNoRows) {
		return ErrNotFound
	}
	if err != nil {
		return err
	}
	_, err = s.db.Exec(ctx, `delete from quizzes where id = $1::uuid`, quizID)
	if err != nil {
		return err
	}
	var cid string
	if err := s.db.QueryRow(ctx, `select course_id::text from lessons where id = $1::uuid`, lessonID).Scan(&cid); err == nil {
		_ = s.BumpCourseVersion(ctx, cid)
	}
	return nil
}
