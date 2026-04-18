package store

import (
	"context"
	"encoding/json"
	"errors"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
)

// ProgressState — строка user_progress для урока.
type ProgressState struct {
	LessonID string
	Status   string
	Score    *int
}

// GetUserProgressForCourse — статусы по lesson_id для пользователя в рамках курса.
func (s *Store) GetUserProgressForCourse(ctx context.Context, userID, courseID string) (map[string]ProgressState, error) {
	rows, err := s.db.Query(ctx, `
		select up.lesson_id::text, up.status, up.score
		from user_progress up
		join lessons l on l.id = up.lesson_id
		where up.user_id = $1::uuid and l.course_id = $2::uuid
	`, userID, courseID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	m := make(map[string]ProgressState)
	for rows.Next() {
		var st ProgressState
		if err := rows.Scan(&st.LessonID, &st.Status, &st.Score); err != nil {
			return nil, err
		}
		m[st.LessonID] = st
	}
	return m, rows.Err()
}

// ProgressClientEventExists — уже обработанное client_event_id (идемпотентность).
func (s *Store) ProgressClientEventExists(ctx context.Context, userID, clientEventID string) (bool, error) {
	uid, err := uuid.Parse(userID)
	if err != nil {
		return false, err
	}
	eid, err := uuid.Parse(clientEventID)
	if err != nil {
		return false, err
	}
	var one int
	qerr := s.db.QueryRow(ctx, `
		select 1 from progress_idempotency where user_id = $1 and client_event_id = $2
	`, uid, eid).Scan(&one)
	if errors.Is(qerr, pgx.ErrNoRows) {
		return false, nil
	}
	if qerr != nil {
		return false, qerr
	}
	return true, nil
}

// RecordProgressClientEvent фиксирует успешно применённое событие (после upsert прогресса).
func (s *Store) RecordProgressClientEvent(ctx context.Context, userID, clientEventID string) error {
	uid, err := uuid.Parse(userID)
	if err != nil {
		return err
	}
	eid, err := uuid.Parse(clientEventID)
	if err != nil {
		return err
	}
	_, err = s.db.Exec(ctx, `
		insert into progress_idempotency (user_id, client_event_id)
		values ($1, $2)
		on conflict (user_id, client_event_id) do nothing
	`, uid, eid)
	return err
}

// UpsertUserProgress обновляет или создаёт прогресс по уроку (last-write-wins по updated_at клиента в теле).
func (s *Store) UpsertUserProgress(ctx context.Context, userID, lessonID, status string, score *int, answers json.RawMessage, updatedAt time.Time) error {
	uid, err := uuid.Parse(userID)
	if err != nil {
		return err
	}
	lid, err := uuid.Parse(lessonID)
	if err != nil {
		return err
	}
	var ans interface{}
	if len(answers) > 0 && string(answers) != "null" {
		ans = answers
	} else {
		ans = nil
	}
	_, err = s.db.Exec(ctx, `
		insert into user_progress (user_id, lesson_id, status, score, answers, updated_at)
		values ($1, $2, $3, $4, $5::jsonb, $6)
		on conflict (user_id, lesson_id) do update set
			status = case
				when user_progress.status = 'completed' and excluded.status = 'started' then user_progress.status
				else excluded.status
			end,
			score = coalesce(excluded.score, user_progress.score),
			answers = coalesce(excluded.answers, user_progress.answers),
			updated_at = excluded.updated_at
	`, uid, lid, status, score, ans, updatedAt.UTC())
	return err
}

// AppendProgressEvent логирует сырое событие (аудит).
func (s *Store) AppendProgressEvent(ctx context.Context, userID string, payload any) error {
	raw, err := json.Marshal(payload)
	if err != nil {
		return err
	}
	_, err = s.db.Exec(ctx, `
		insert into progress_events (id, user_id, payload, created_at)
		values ($1, $2::uuid, $3, $4)
	`, uuid.New(), userID, raw, time.Now().UTC())
	return err
}
