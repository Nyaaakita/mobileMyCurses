package store

import (
	"context"
	"encoding/json"
	"os"
	"testing"
	"time"

	"lms/backend/internal/db"
	"lms/backend/internal/migrate"
)

func TestAdminFlow_Integration(t *testing.T) {
	dsn := os.Getenv("TEST_DATABASE_URL")
	if dsn == "" {
		t.Skip("TEST_DATABASE_URL is not set")
	}

	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()
	pool, err := db.Open(ctx, dsn)
	if err != nil {
		t.Fatalf("open db: %v", err)
	}
	defer pool.Close()
	if err := migrate.Up(ctx, pool); err != nil {
		t.Fatalf("migrate up: %v", err)
	}

	s := New(pool)
	course, err := s.CreateCourse(ctx, Course{
		Title:            "Integration Course",
		Description:      "Long enough description for integration test",
		Difficulty:       "beginner",
		EstimatedMinutes: 45,
		IsPublished:      true,
	}, "00000000-0000-4000-8000-0000000000ad")
	if err != nil {
		t.Fatalf("create course: %v", err)
	}

	lesson, err := s.CreateLesson(ctx, course.ID, "Lesson A", 1, json.RawMessage(`[]`))
	if err != nil {
		t.Fatalf("create lesson: %v", err)
	}
	lesson2, err := s.CreateLesson(ctx, course.ID, "Lesson B", 2, json.RawMessage(`[]`))
	if err != nil {
		t.Fatalf("create lesson2: %v", err)
	}

	if err := s.ReorderLessons(ctx, course.ID, map[string]int{
		lesson.ID:  2,
		lesson2.ID: 1,
	}); err != nil {
		t.Fatalf("reorder lessons: %v", err)
	}

	quiz, err := s.CreateQuiz(ctx, lesson.ID, "Quiz 1", json.RawMessage(`[]`))
	if err != nil {
		t.Fatalf("create quiz: %v", err)
	}
	if _, err := s.UpdateQuiz(ctx, quiz.ID, "Quiz 1 updated", json.RawMessage(`[]`)); err != nil {
		t.Fatalf("update quiz: %v", err)
	}
	if err := s.DeleteQuiz(ctx, quiz.ID); err != nil {
		t.Fatalf("delete quiz: %v", err)
	}
}
