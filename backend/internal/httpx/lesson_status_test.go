package httpx

import (
	"testing"

	"lms/backend/internal/store"
)

func TestCourseProgressPercent(t *testing.T) {
	lessons := []store.LessonEntity{
		{ID: "l1", Title: "A", OrderIndex: 1},
		{ID: "l2", Title: "B", OrderIndex: 2},
		{ID: "l3", Title: "C", OrderIndex: 3},
	}
	prog := map[string]store.ProgressState{
		"l1": {Status: "completed"},
		"l2": {Status: "started"},
		"l3": {Status: "completed"},
	}
	got := courseProgressPercent(lessons, prog)
	if got != 66 {
		t.Fatalf("expected 66, got %d", got)
	}
}

func TestBuildLessonSummaries(t *testing.T) {
	lessons := []store.LessonEntity{
		{ID: "l1", Title: "A", OrderIndex: 1},
		{ID: "l2", Title: "B", OrderIndex: 2},
		{ID: "l3", Title: "C", OrderIndex: 3},
	}
	prog := map[string]store.ProgressState{
		"l1": {Status: "completed"},
		"l2": {Status: "started"},
	}
	out := buildLessonSummaries(lessons, prog)
	if len(out) != 3 {
		t.Fatalf("expected 3 lessons, got %d", len(out))
	}
	if out[0].Status != "done" {
		t.Fatalf("lesson1 expected done, got %s", out[0].Status)
	}
	if out[1].Status != "available" {
		t.Fatalf("lesson2 expected available, got %s", out[1].Status)
	}
	if out[2].Status != "locked" {
		t.Fatalf("lesson3 expected locked, got %s", out[2].Status)
	}
}
