package store

import (
	"context"
	"encoding/json"
	"errors"

	"github.com/jackc/pgx/v5"
)

type QuizEntity struct {
	ID        string          `json:"id"`
	LessonID  string          `json:"lesson_id"`
	Title     string          `json:"title"`
	Questions json.RawMessage `json:"questions"`
}

// GetQuizPublished загружает квиз, если урок принадлежит опубликованному курсу.
func (s *Store) GetQuizPublished(ctx context.Context, quizID string) (QuizEntity, error) {
	var q QuizEntity
	var raw []byte
	err := s.db.QueryRow(ctx, `
		select q.id::text, q.lesson_id::text, q.title, q.questions
		from quizzes q
		join lessons l on l.id = q.lesson_id
		join courses c on c.id = l.course_id
		where q.id = $1::uuid and c.is_published = true
	`, quizID).Scan(&q.ID, &q.LessonID, &q.Title, &raw)
	if errors.Is(err, pgx.ErrNoRows) {
		return QuizEntity{}, ErrNotFound
	}
	if err != nil {
		return QuizEntity{}, err
	}
	q.Questions = json.RawMessage(raw)
	return q, nil
}

type AssignmentEntity struct {
	ID       string
	LessonID string
	Kind     string
	Config   []byte
}

// GetAssignmentPublished — задание в опубликованном курсе.
func (s *Store) GetAssignmentPublished(ctx context.Context, assignmentID string) (AssignmentEntity, error) {
	var a AssignmentEntity
	err := s.db.QueryRow(ctx, `
		select a.id::text, a.lesson_id::text, a.kind, a.config
		from assignments a
		join lessons l on l.id = a.lesson_id
		join courses c on c.id = l.course_id
		where a.id = $1::uuid and c.is_published = true
	`, assignmentID).Scan(&a.ID, &a.LessonID, &a.Kind, &a.Config)
	if errors.Is(err, pgx.ErrNoRows) {
		return AssignmentEntity{}, ErrNotFound
	}
	return a, err
}
