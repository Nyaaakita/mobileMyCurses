package httpx

import (
	"encoding/json"
	"sort"

	"lms/backend/internal/api"
)

type quizQuestion struct {
	ID      string `json:"id"`
	Type    string `json:"type"`
	Options []struct {
		ID        string `json:"id"`
		IsCorrect bool   `json:"is_correct"`
	} `json:"options"`
}

func scoreQuiz(questionsJSON json.RawMessage, answers []api.QuizAnswerIn) (score int, maxScore int, passed bool) {
	var qs []quizQuestion
	if err := json.Unmarshal(questionsJSON, &qs); err != nil || len(qs) == 0 {
		return 0, 100, false
	}
	maxScore = 100
	answerMap := make(map[string][]string, len(answers))
	for _, a := range answers {
		cp := append([]string(nil), a.SelectedOptionIDs...)
		sort.Strings(cp)
		answerMap[a.QuestionID] = cp
	}
	correctN := 0
	for _, q := range qs {
		sel := answerMap[q.ID]
		correctIDs := make([]string, 0)
		for _, o := range q.Options {
			if o.IsCorrect {
				correctIDs = append(correctIDs, o.ID)
			}
		}
		sort.Strings(correctIDs)
		if stringSlicesEqual(sel, correctIDs) {
			correctN++
		}
	}
	score = correctN * 100 / len(qs)
	passed = score >= 60
	return score, maxScore, passed
}

func stringSlicesEqual(a, b []string) bool {
	if len(a) != len(b) {
		return false
	}
	for i := range a {
		if a[i] != b[i] {
			return false
		}
	}
	return true
}
