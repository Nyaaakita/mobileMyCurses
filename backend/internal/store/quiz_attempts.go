package store

import (
	"context"
	"encoding/json"
)

func (s *Store) CreateQuizAttempt(
	ctx context.Context,
	userID string,
	quizID string,
	lessonID string,
	score int,
	maxScore int,
	passed bool,
	answers json.RawMessage,
) error {
	raw := []byte("[]")
	if len(answers) > 0 && string(answers) != "null" {
		raw = answers
	}
	_, err := s.db.Exec(ctx, `
		insert into quiz_attempts (user_id, quiz_id, lesson_id, score, max_score, passed, answers)
		values ($1::uuid, $2::uuid, $3::uuid, $4, $5, $6, $7::jsonb)
	`, userID, quizID, lessonID, score, maxScore, passed, raw)
	return err
}

