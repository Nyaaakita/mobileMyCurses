package httpx

import "lms/backend/internal/store"

func courseProgressPercent(lessons []store.LessonEntity, prog map[string]store.ProgressState) int {
	if len(lessons) == 0 {
		return 0
	}
	done := 0
	for i := range lessons {
		if prog[lessons[i].ID].Status == "completed" {
			done++
		}
	}
	return (done * 100) / len(lessons)
}

func buildLessonSummaries(lessons []store.LessonEntity, prog map[string]store.ProgressState) []store.LessonSummary {
	out := make([]store.LessonSummary, 0, len(lessons))
	for i := range lessons {
		le := lessons[i]
		state := prog[le.ID].Status
		done := state == "completed"
		prevDone := i == 0
		if !prevDone {
			prevID := lessons[i-1].ID
			prevDone = prog[prevID].Status == "completed"
		}
		ui := "locked"
		if done {
			ui = "done"
		} else if prevDone {
			ui = "available"
		}
		out = append(out, store.LessonSummary{
			ID:         le.ID,
			Title:      le.Title,
			OrderIndex: le.OrderIndex,
			Status:     ui,
		})
	}
	return out
}
