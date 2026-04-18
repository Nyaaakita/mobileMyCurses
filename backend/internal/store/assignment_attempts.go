package store

import "context"

func (s *Store) CreateAssignmentAttempt(
	ctx context.Context,
	userID string,
	assignmentID string,
	lessonID string,
	status string,
	score *int,
	answerText string,
	language *string,
) error {
	_, err := s.db.Exec(ctx, `
		insert into assignment_attempts (user_id, assignment_id, lesson_id, status, score, answer_text, language)
		values ($1::uuid, $2::uuid, $3::uuid, $4, $5, $6, $7)
	`, userID, assignmentID, lessonID, status, score, answerText, language)
	return err
}

