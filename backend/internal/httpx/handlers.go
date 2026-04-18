package httpx

import (
	"encoding/json"
	"errors"
	"fmt"
	"net/http"
	"strings"
	"time"

	"github.com/go-chi/chi/v5"
	"github.com/google/uuid"
	"golang.org/x/crypto/bcrypt"

	"lms/backend/internal/api"
	"lms/backend/internal/store"
)

type handler struct {
	dep Dependencies
}

func (h handler) health(w http.ResponseWriter, _ *http.Request) {
	h.writeJSON(w, http.StatusOK, map[string]string{"status": "ok"})
}

func (h handler) register(w http.ResponseWriter, r *http.Request) {
	var req api.RegisterRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		h.writeError(w, r, http.StatusBadRequest, "VALIDATION_ERROR", "invalid json", nil)
		return
	}

	req.Email = strings.TrimSpace(strings.ToLower(req.Email))
	req.Name = strings.TrimSpace(req.Name)
	if req.Email == "" || len(req.Password) < 8 || len(req.Name) < 2 {
		h.writeError(w, r, http.StatusBadRequest, "VALIDATION_ERROR", "invalid auth payload", map[string]interface{}{
			"fields": []api.ValidationFieldError{
				{Field: "email", Rule: "required", Message: "email is required"},
				{Field: "password", Rule: "min_length", Message: "password min length is 8"},
				{Field: "name", Rule: "min_length", Message: "name min length is 2"},
			},
		})
		return
	}

	hash, err := bcrypt.GenerateFromPassword([]byte(req.Password), bcrypt.DefaultCost)
	if err != nil {
		h.writeError(w, r, http.StatusInternalServerError, "INTERNAL_ERROR", "hash error", nil)
		return
	}

	user, err := h.dep.Store.CreateUser(r.Context(), req.Email, req.Name, string(hash), "student")
	if err != nil {
		h.writeError(w, r, http.StatusConflict, "CONFLICT", "cannot create user", nil)
		return
	}

	access, err := h.dep.AccessTokenManager.Sign(parseUUID(user.ID), user.Role)
	if err != nil {
		h.writeError(w, r, http.StatusInternalServerError, "INTERNAL_ERROR", "token error", nil)
		return
	}
	refresh, err := h.dep.RefreshTokenManager.Sign(parseUUID(user.ID), user.Role)
	if err != nil {
		h.writeError(w, r, http.StatusInternalServerError, "INTERNAL_ERROR", "token error", nil)
		return
	}

	h.writeJSON(w, http.StatusCreated, api.AuthTokensResponse{
		AccessToken:  access,
		RefreshToken: refresh,
		ExpiresIn:    int(h.dep.AccessTokenManager.TTL.Seconds()),
	})
}

func (h handler) login(w http.ResponseWriter, r *http.Request) {
	var req api.LoginRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		h.writeError(w, r, http.StatusBadRequest, "VALIDATION_ERROR", "invalid json", nil)
		return
	}
	req.Email = strings.TrimSpace(strings.ToLower(req.Email))

	user, err := h.dep.Store.GetUserByEmail(r.Context(), req.Email)
	if err != nil {
		h.writeError(w, r, http.StatusUnauthorized, "UNAUTHORIZED", "invalid credentials", nil)
		return
	}
	if err := bcrypt.CompareHashAndPassword([]byte(user.PasswordHash), []byte(req.Password)); err != nil {
		h.writeError(w, r, http.StatusUnauthorized, "UNAUTHORIZED", "invalid credentials", nil)
		return
	}

	access, err := h.dep.AccessTokenManager.Sign(parseUUID(user.ID), user.Role)
	if err != nil {
		h.writeError(w, r, http.StatusInternalServerError, "INTERNAL_ERROR", "token error", nil)
		return
	}
	refresh, err := h.dep.RefreshTokenManager.Sign(parseUUID(user.ID), user.Role)
	if err != nil {
		h.writeError(w, r, http.StatusInternalServerError, "INTERNAL_ERROR", "token error", nil)
		return
	}
	h.writeJSON(w, http.StatusOK, api.AuthTokensResponse{
		AccessToken:  access,
		RefreshToken: refresh,
		ExpiresIn:    int(h.dep.AccessTokenManager.TTL.Seconds()),
	})
}

func (h handler) refresh(w http.ResponseWriter, r *http.Request) {
	var req api.RefreshRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil || strings.TrimSpace(req.RefreshToken) == "" {
		h.writeError(w, r, http.StatusBadRequest, "VALIDATION_ERROR", "refresh_token required", nil)
		return
	}
	claims, err := h.dep.RefreshTokenManager.Parse(strings.TrimSpace(req.RefreshToken))
	if err != nil {
		h.writeError(w, r, http.StatusUnauthorized, "UNAUTHORIZED", "invalid refresh token", nil)
		return
	}
	access, err := h.dep.AccessTokenManager.Sign(parseUUID(claims.UserID), claims.Role)
	if err != nil {
		h.writeError(w, r, http.StatusInternalServerError, "INTERNAL_ERROR", "token error", nil)
		return
	}
	refresh, err := h.dep.RefreshTokenManager.Sign(parseUUID(claims.UserID), claims.Role)
	if err != nil {
		h.writeError(w, r, http.StatusInternalServerError, "INTERNAL_ERROR", "token error", nil)
		return
	}
	h.writeJSON(w, http.StatusOK, api.AuthTokensResponse{
		AccessToken:  access,
		RefreshToken: refresh,
		ExpiresIn:    int(h.dep.AccessTokenManager.TTL.Seconds()),
	})
}

func (h handler) logout(w http.ResponseWriter, r *http.Request) {
	h.writeJSON(w, http.StatusOK, map[string]bool{"ok": true})
}

func (h handler) me(w http.ResponseWriter, r *http.Request) {
	claims, ok := claimsFromContext(r.Context())
	if !ok {
		h.writeError(w, r, http.StatusUnauthorized, "UNAUTHORIZED", "missing claims", nil)
		return
	}
	user, err := h.dep.Store.GetUserByID(r.Context(), claims.UserID)
	if errors.Is(err, store.ErrNotFound) {
		h.writeError(w, r, http.StatusNotFound, "NOT_FOUND", "user not found", nil)
		return
	}
	if err != nil {
		h.writeError(w, r, http.StatusInternalServerError, "INTERNAL_ERROR", "cannot load user", nil)
		return
	}
	h.writeJSON(w, http.StatusOK, api.MeResponse{
		ID: user.ID, Email: user.Email, Name: user.Name, Role: user.Role,
	})
}

func (h handler) listCourses(w http.ResponseWriter, r *http.Request) {
	claims, ok := claimsFromContext(r.Context())
	if !ok {
		h.writeError(w, r, http.StatusUnauthorized, "UNAUTHORIZED", "missing claims", nil)
		return
	}
	courses, err := h.dep.Store.ListPublishedCoursesForUser(r.Context(), claims.UserID)
	if err != nil {
		h.writeError(w, r, http.StatusInternalServerError, "INTERNAL_ERROR", "cannot list courses", nil)
		return
	}
	h.writeJSON(w, http.StatusOK, courses)
}

func (h handler) getCourseDetails(w http.ResponseWriter, r *http.Request) {
	claims, ok := claimsFromContext(r.Context())
	if !ok {
		h.writeError(w, r, http.StatusUnauthorized, "UNAUTHORIZED", "missing claims", nil)
		return
	}
	courseID := chi.URLParam(r, "courseId")
	course, err := h.dep.Store.GetPublishedCourse(r.Context(), courseID)
	if errors.Is(err, store.ErrNotFound) {
		h.writeError(w, r, http.StatusNotFound, "NOT_FOUND", "course not found", nil)
		return
	}
	if err != nil {
		h.writeError(w, r, http.StatusInternalServerError, "INTERNAL_ERROR", "cannot load course", nil)
		return
	}
	lessons, err := h.dep.Store.ListLessonsByCourse(r.Context(), courseID)
	if err != nil {
		h.writeError(w, r, http.StatusInternalServerError, "INTERNAL_ERROR", "cannot load lessons", nil)
		return
	}
	prog, err := h.dep.Store.GetUserProgressForCourse(r.Context(), claims.UserID, courseID)
	if err != nil {
		h.writeError(w, r, http.StatusInternalServerError, "INTERNAL_ERROR", "cannot load progress", nil)
		return
	}
	summaries := buildLessonSummaries(lessons, prog)
	pct := courseProgressPercent(lessons, prog)
	h.writeJSON(w, http.StatusOK, map[string]interface{}{
		"id":                 course.ID,
		"title":              course.Title,
		"description":        course.Description,
		"cover_url":          course.CoverURL,
		"difficulty":         course.Difficulty,
		"estimated_minutes":  course.EstimatedMinutes,
		"content_version":    course.ContentVersion,
		"progress_percent":   pct,
		"lessons":            summaries,
	})
}

func (h handler) getLesson(w http.ResponseWriter, r *http.Request) {
	lessonID := chi.URLParam(r, "lessonId")
	le, err := h.dep.Store.GetLessonPublished(r.Context(), lessonID)
	if errors.Is(err, store.ErrNotFound) {
		h.writeError(w, r, http.StatusNotFound, "NOT_FOUND", "lesson not found", nil)
		return
	}
	if err != nil {
		h.writeError(w, r, http.StatusInternalServerError, "INTERNAL_ERROR", "cannot load lesson", nil)
		return
	}
	etag := fmt.Sprintf(`W/"v%d-%s"`, le.ContentVersion, le.ID)
	if inm := r.Header.Get("If-None-Match"); inm != "" && strings.TrimSpace(inm) == etag {
		w.Header().Set("ETag", etag)
		w.WriteHeader(http.StatusNotModified)
		return
	}
	w.Header().Set("ETag", etag)
	blocks := le.Blocks
	if len(blocks) == 0 {
		blocks = []byte("[]")
	}
	payload := struct {
		ID              string          `json:"id"`
		CourseID        string          `json:"course_id"`
		Title           string          `json:"title"`
		ContentVersion  int             `json:"content_version"`
		Blocks          json.RawMessage `json:"blocks"`
	}{
		ID:             le.ID,
		CourseID:       le.CourseID,
		Title:          le.Title,
		ContentVersion: le.ContentVersion,
		Blocks:         json.RawMessage(blocks),
	}
	h.writeJSON(w, http.StatusOK, payload)
}

func (h handler) getCourseProgress(w http.ResponseWriter, r *http.Request) {
	claims, ok := claimsFromContext(r.Context())
	if !ok {
		h.writeError(w, r, http.StatusUnauthorized, "UNAUTHORIZED", "missing claims", nil)
		return
	}
	courseID := chi.URLParam(r, "courseId")
	if _, err := h.dep.Store.GetPublishedCourse(r.Context(), courseID); errors.Is(err, store.ErrNotFound) {
		h.writeError(w, r, http.StatusNotFound, "NOT_FOUND", "course not found", nil)
		return
	} else if err != nil {
		h.writeError(w, r, http.StatusInternalServerError, "INTERNAL_ERROR", "cannot load course", nil)
		return
	}
	lessons, err := h.dep.Store.ListLessonsByCourse(r.Context(), courseID)
	if err != nil {
		h.writeError(w, r, http.StatusInternalServerError, "INTERNAL_ERROR", "cannot load lessons", nil)
		return
	}
	prog, err := h.dep.Store.GetUserProgressForCourse(r.Context(), claims.UserID, courseID)
	if err != nil {
		h.writeError(w, r, http.StatusInternalServerError, "INTERNAL_ERROR", "cannot load progress", nil)
		return
	}
	summaries := buildLessonSummaries(lessons, prog)
	pct := courseProgressPercent(lessons, prog)
	h.writeJSON(w, http.StatusOK, map[string]interface{}{
		"course_id":        courseID,
		"progress_percent": pct,
		"lessons":          summaries,
	})
}

func (h handler) progressBatch(w http.ResponseWriter, r *http.Request) {
	claims, ok := claimsFromContext(r.Context())
	if !ok {
		h.writeError(w, r, http.StatusUnauthorized, "UNAUTHORIZED", "missing claims", nil)
		return
	}

	var body api.ProgressBatchRequest
	if err := json.NewDecoder(r.Body).Decode(&body); err != nil {
		h.writeError(w, r, http.StatusBadRequest, "VALIDATION_ERROR", "invalid json", nil)
		return
	}
	if len(body.Items) == 0 {
		h.writeError(w, r, http.StatusBadRequest, "VALIDATION_ERROR", "items required", nil)
		return
	}
	if len(body.Items) > 200 {
		h.writeError(w, r, http.StatusBadRequest, "VALIDATION_ERROR", "too many items", nil)
		return
	}

	accepted := make([]string, 0)
	rejected := make([]api.RejectedProgressItem, 0)

	for _, it := range body.Items {
		if _, err := uuid.Parse(it.LessonID); err != nil {
			rejected = append(rejected, api.RejectedProgressItem{ClientEventID: it.ClientEventID, Reason: "invalid lesson_id"})
			continue
		}
		if _, err := uuid.Parse(it.ClientEventID); err != nil {
			rejected = append(rejected, api.RejectedProgressItem{ClientEventID: it.ClientEventID, Reason: "invalid client_event_id"})
			continue
		}
		if it.Status != "started" && it.Status != "completed" {
			rejected = append(rejected, api.RejectedProgressItem{ClientEventID: it.ClientEventID, Reason: "invalid status"})
			continue
		}
		if it.Score != nil && (*it.Score < 0 || *it.Score > 100) {
			rejected = append(rejected, api.RejectedProgressItem{ClientEventID: it.ClientEventID, Reason: "invalid score"})
			continue
		}
		_, err := h.dep.Store.GetLessonPublished(r.Context(), it.LessonID)
		if errors.Is(err, store.ErrNotFound) {
			rejected = append(rejected, api.RejectedProgressItem{ClientEventID: it.ClientEventID, Reason: "lesson not available"})
			continue
		}
		if err != nil {
			h.writeError(w, r, http.StatusInternalServerError, "INTERNAL_ERROR", "cannot validate lesson", nil)
			return
		}
		ts, err := time.Parse(time.RFC3339, it.UpdatedAt)
		if err != nil {
			rejected = append(rejected, api.RejectedProgressItem{ClientEventID: it.ClientEventID, Reason: "invalid updated_at"})
			continue
		}

		dup, err := h.dep.Store.ProgressClientEventExists(r.Context(), claims.UserID, it.ClientEventID)
		if err != nil {
			h.writeError(w, r, http.StatusInternalServerError, "INTERNAL_ERROR", "idempotency check failed", nil)
			return
		}
		if dup {
			accepted = append(accepted, it.ClientEventID)
			continue
		}

		if err := h.dep.Store.UpsertUserProgress(r.Context(), claims.UserID, it.LessonID, it.Status, it.Score, it.Answers, ts); err != nil {
			rejected = append(rejected, api.RejectedProgressItem{ClientEventID: it.ClientEventID, Reason: "cannot save progress"})
			continue
		}
		if err := h.dep.Store.RecordProgressClientEvent(r.Context(), claims.UserID, it.ClientEventID); err != nil {
			h.writeError(w, r, http.StatusInternalServerError, "INTERNAL_ERROR", "cannot record idempotency", nil)
			return
		}
		_ = h.dep.Store.AppendProgressEvent(r.Context(), claims.UserID, it)
		accepted = append(accepted, it.ClientEventID)
	}

	h.writeJSON(w, http.StatusOK, api.ProgressBatchResponse{Accepted: accepted, Rejected: rejected})
}

func (h handler) getQuizForStudent(w http.ResponseWriter, r *http.Request) {
	quizID := chi.URLParam(r, "quizId")
	q, err := h.dep.Store.GetQuizPublished(r.Context(), quizID)
	if errors.Is(err, store.ErrNotFound) {
		h.writeError(w, r, http.StatusNotFound, "NOT_FOUND", "quiz not found", nil)
		return
	}
	if err != nil {
		h.writeError(w, r, http.StatusInternalServerError, "INTERNAL_ERROR", "cannot load quiz", nil)
		return
	}
	safe, err := stripCorrectFromQuizJSON(q.Questions)
	if err != nil {
		h.writeError(w, r, http.StatusInternalServerError, "INTERNAL_ERROR", "cannot format quiz", nil)
		return
	}
	type out struct {
		ID        string          `json:"id"`
		Title     string          `json:"title"`
		Questions json.RawMessage `json:"questions"`
	}
	h.writeJSON(w, http.StatusOK, out{ID: q.ID, Title: q.Title, Questions: safe})
}

func (h handler) quizSubmit(w http.ResponseWriter, r *http.Request) {
	claims, ok := claimsFromContext(r.Context())
	if !ok {
		h.writeError(w, r, http.StatusUnauthorized, "UNAUTHORIZED", "missing claims", nil)
		return
	}
	quizID := chi.URLParam(r, "quizId")
	q, err := h.dep.Store.GetQuizPublished(r.Context(), quizID)
	if errors.Is(err, store.ErrNotFound) {
		h.writeError(w, r, http.StatusNotFound, "NOT_FOUND", "quiz not found", nil)
		return
	}
	if err != nil {
		h.writeError(w, r, http.StatusInternalServerError, "INTERNAL_ERROR", "cannot load quiz", nil)
		return
	}
	var body api.QuizSubmitRequest
	if err := json.NewDecoder(r.Body).Decode(&body); err != nil {
		h.writeError(w, r, http.StatusBadRequest, "VALIDATION_ERROR", "invalid json", nil)
		return
	}
	score, maxScore, passed := scoreQuiz(q.Questions, body.Answers)
	answersJSON, _ := json.Marshal(body.Answers)
	if err := h.dep.Store.CreateQuizAttempt(
		r.Context(),
		claims.UserID,
		q.ID,
		q.LessonID,
		score,
		maxScore,
		passed,
		answersJSON,
	); err != nil {
		h.writeError(w, r, http.StatusInternalServerError, "INTERNAL_ERROR", "cannot store quiz attempt", nil)
		return
	}
	progressStatus := "started"
	if passed {
		progressStatus = "completed"
	}
	if err := h.dep.Store.UpsertUserProgress(
		r.Context(),
		claims.UserID,
		q.LessonID,
		progressStatus,
		&score,
		answersJSON,
		time.Now().UTC(),
	); err != nil {
		h.writeError(w, r, http.StatusInternalServerError, "INTERNAL_ERROR", "cannot update user progress", nil)
		return
	}
	if err := h.dep.Store.AppendProgressEvent(r.Context(), claims.UserID, map[string]interface{}{
		"lesson_id":       q.LessonID,
		"status":          progressStatus,
		"score":           score,
		"answers":         body.Answers,
		"client_event_id": uuid.NewString(),
		"source":          "quiz_submit",
		"updated_at":      time.Now().UTC().Format(time.RFC3339Nano),
	}); err != nil {
		h.writeError(w, r, http.StatusInternalServerError, "INTERNAL_ERROR", "cannot append progress event", nil)
		return
	}
	h.writeJSON(w, http.StatusOK, api.QuizSubmitResponse{Score: score, MaxScore: maxScore, Passed: passed})
}

func (h handler) assignmentSubmit(w http.ResponseWriter, r *http.Request) {
	claims, ok := claimsFromContext(r.Context())
	if !ok {
		h.writeError(w, r, http.StatusUnauthorized, "UNAUTHORIZED", "missing claims", nil)
		return
	}
	assignID := chi.URLParam(r, "assignmentId")
	a, err := h.dep.Store.GetAssignmentPublished(r.Context(), assignID)
	if errors.Is(err, store.ErrNotFound) {
		h.writeError(w, r, http.StatusNotFound, "NOT_FOUND", "assignment not found", nil)
		return
	}
	if err != nil {
		h.writeError(w, r, http.StatusInternalServerError, "INTERNAL_ERROR", "cannot load assignment", nil)
		return
	}
	var body api.AssignmentSubmitRequest
	if err := json.NewDecoder(r.Body).Decode(&body); err != nil {
		h.writeError(w, r, http.StatusBadRequest, "VALIDATION_ERROR", "invalid json", nil)
		return
	}
	text := strings.TrimSpace(body.AnswerText)
	if text == "" {
		h.writeError(w, r, http.StatusBadRequest, "VALIDATION_ERROR", "answer_text required", nil)
		return
	}

	switch a.Kind {
	case "free_text":
		var cfg struct {
			Expected string `json:"expected"`
		}
		if err := json.Unmarshal(a.Config, &cfg); err != nil {
			h.writeError(w, r, http.StatusInternalServerError, "INTERNAL_ERROR", "bad assignment config", nil)
			return
		}
		ok := strings.EqualFold(text, strings.TrimSpace(cfg.Expected))
		if ok {
			score := 100
			if err := h.dep.Store.CreateAssignmentAttempt(
				r.Context(),
				claims.UserID,
				a.ID,
				a.LessonID,
				"accepted",
				&score,
				text,
				body.Language,
			); err != nil {
				h.writeError(w, r, http.StatusInternalServerError, "INTERNAL_ERROR", "cannot store assignment attempt", nil)
				return
			}
			answersJSON, _ := json.Marshal(map[string]interface{}{
				"answer_text": text,
				"language":    body.Language,
				"kind":        a.Kind,
			})
			if err := h.dep.Store.UpsertUserProgress(
				r.Context(),
				claims.UserID,
				a.LessonID,
				"completed",
				&score,
				answersJSON,
				time.Now().UTC(),
			); err != nil {
				h.writeError(w, r, http.StatusInternalServerError, "INTERNAL_ERROR", "cannot update user progress", nil)
				return
			}
			if err := h.dep.Store.AppendProgressEvent(r.Context(), claims.UserID, map[string]interface{}{
				"lesson_id":       a.LessonID,
				"status":          "completed",
				"score":           score,
				"answers":         map[string]interface{}{"answer_text": text, "language": body.Language},
				"client_event_id": uuid.NewString(),
				"source":          "assignment_submit",
				"updated_at":      time.Now().UTC().Format(time.RFC3339Nano),
			}); err != nil {
				h.writeError(w, r, http.StatusInternalServerError, "INTERNAL_ERROR", "cannot append progress event", nil)
				return
			}
			h.writeJSON(w, http.StatusOK, api.AssignmentSubmitResponse{Status: "accepted", Score: &score, Feedback: "Верно"})
			return
		}
		rejectedScore := ptrInt(0)
		if err := h.dep.Store.CreateAssignmentAttempt(
			r.Context(),
			claims.UserID,
			a.ID,
			a.LessonID,
			"rejected",
			rejectedScore,
			text,
			body.Language,
		); err != nil {
			h.writeError(w, r, http.StatusInternalServerError, "INTERNAL_ERROR", "cannot store assignment attempt", nil)
			return
		}
		answersJSON, _ := json.Marshal(map[string]interface{}{
			"answer_text": text,
			"language":    body.Language,
			"kind":        a.Kind,
		})
		if err := h.dep.Store.UpsertUserProgress(
			r.Context(),
			claims.UserID,
			a.LessonID,
			"started",
			rejectedScore,
			answersJSON,
			time.Now().UTC(),
		); err != nil {
			h.writeError(w, r, http.StatusInternalServerError, "INTERNAL_ERROR", "cannot update user progress", nil)
			return
		}
		if err := h.dep.Store.AppendProgressEvent(r.Context(), claims.UserID, map[string]interface{}{
			"lesson_id":       a.LessonID,
			"status":          "started",
			"score":           0,
			"answers":         map[string]interface{}{"answer_text": text, "language": body.Language},
			"client_event_id": uuid.NewString(),
			"source":          "assignment_submit",
			"updated_at":      time.Now().UTC().Format(time.RFC3339Nano),
		}); err != nil {
			h.writeError(w, r, http.StatusInternalServerError, "INTERNAL_ERROR", "cannot append progress event", nil)
			return
		}
		h.writeJSON(w, http.StatusOK, api.AssignmentSubmitResponse{Status: "rejected", Score: rejectedScore, Feedback: "Неверный ответ"})
	default:
		if err := h.dep.Store.CreateAssignmentAttempt(
			r.Context(),
			claims.UserID,
			a.ID,
			a.LessonID,
			"needs_review",
			nil,
			text,
			body.Language,
		); err != nil {
			h.writeError(w, r, http.StatusInternalServerError, "INTERNAL_ERROR", "cannot store assignment attempt", nil)
			return
		}
		answersJSON, _ := json.Marshal(map[string]interface{}{
			"answer_text": text,
			"language":    body.Language,
			"kind":        a.Kind,
		})
		if err := h.dep.Store.UpsertUserProgress(
			r.Context(),
			claims.UserID,
			a.LessonID,
			"started",
			nil,
			answersJSON,
			time.Now().UTC(),
		); err != nil {
			h.writeError(w, r, http.StatusInternalServerError, "INTERNAL_ERROR", "cannot update user progress", nil)
			return
		}
		if err := h.dep.Store.AppendProgressEvent(r.Context(), claims.UserID, map[string]interface{}{
			"lesson_id":       a.LessonID,
			"status":          "started",
			"score":           nil,
			"answers":         map[string]interface{}{"answer_text": text, "language": body.Language},
			"client_event_id": uuid.NewString(),
			"source":          "assignment_submit",
			"updated_at":      time.Now().UTC().Format(time.RFC3339Nano),
		}); err != nil {
			h.writeError(w, r, http.StatusInternalServerError, "INTERNAL_ERROR", "cannot append progress event", nil)
			return
		}
		h.writeJSON(w, http.StatusOK, api.AssignmentSubmitResponse{Status: "needs_review", Score: nil, Feedback: "Тип задания пока не автопроверяется"})
	}
}

func (h handler) adminCreateCourse(w http.ResponseWriter, r *http.Request) {
	claims, ok := claimsFromContext(r.Context())
	if !ok {
		h.writeError(w, r, http.StatusUnauthorized, "UNAUTHORIZED", "missing claims", nil)
		return
	}
	var req store.Course
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		h.writeError(w, r, http.StatusBadRequest, "VALIDATION_ERROR", "invalid json", nil)
		return
	}
	req.Title = strings.TrimSpace(req.Title)
	req.Description = strings.TrimSpace(req.Description)
	req.Difficulty = strings.TrimSpace(req.Difficulty)
	if len(req.Title) < 3 || len(req.Description) < 10 {
		h.writeError(w, r, http.StatusBadRequest, "VALIDATION_ERROR", "title or description too short", map[string]interface{}{
			"fields": []api.ValidationFieldError{
				{Field: "title", Rule: "min_length", Message: "title min length is 3"},
				{Field: "description", Rule: "min_length", Message: "description min length is 10"},
			},
		})
		return
	}
	if req.Difficulty == "" {
		req.Difficulty = "beginner"
	}
	if !validDifficulty(req.Difficulty) {
		h.writeError(w, r, http.StatusBadRequest, "VALIDATION_ERROR", "invalid difficulty", nil)
		return
	}
	if req.EstimatedMinutes <= 0 {
		req.EstimatedMinutes = 30
	}
	req.IsPublished = false
	course, err := h.dep.Store.CreateCourse(r.Context(), req, claims.UserID)
	if err != nil {
		h.writeError(w, r, http.StatusInternalServerError, "INTERNAL_ERROR", "cannot create course", nil)
		return
	}
	h.writeJSON(w, http.StatusCreated, course)
}

func (h handler) adminListCourses(w http.ResponseWriter, r *http.Request) {
	claims, ok := claimsFromContext(r.Context())
	if !ok {
		h.writeError(w, r, http.StatusUnauthorized, "UNAUTHORIZED", "missing claims", nil)
		return
	}
	courses, err := h.dep.Store.ListCoursesAdminByOwner(r.Context(), claims.UserID)
	if err != nil {
		h.writeError(w, r, http.StatusInternalServerError, "INTERNAL_ERROR", "cannot list courses", nil)
		return
	}
	h.writeJSON(w, http.StatusOK, courses)
}

func (h handler) adminGetCourse(w http.ResponseWriter, r *http.Request) {
	claims, ok := claimsFromContext(r.Context())
	if !ok {
		h.writeError(w, r, http.StatusUnauthorized, "UNAUTHORIZED", "missing claims", nil)
		return
	}
	courseID := chi.URLParam(r, "courseId")
	owned, err := h.dep.Store.IsCourseOwnedBy(r.Context(), courseID, claims.UserID)
	if err != nil {
		h.writeError(w, r, http.StatusInternalServerError, "INTERNAL_ERROR", "cannot check course access", nil)
		return
	}
	if !owned {
		h.writeError(w, r, http.StatusNotFound, "NOT_FOUND", "course not found", nil)
		return
	}
	course, err := h.dep.Store.GetCourseByID(r.Context(), courseID)
	if errors.Is(err, store.ErrNotFound) {
		h.writeError(w, r, http.StatusNotFound, "NOT_FOUND", "course not found", nil)
		return
	}
	if err != nil {
		h.writeError(w, r, http.StatusInternalServerError, "INTERNAL_ERROR", "cannot load course", nil)
		return
	}
	h.writeJSON(w, http.StatusOK, course)
}

func (h handler) adminUpdateCourse(w http.ResponseWriter, r *http.Request) {
	claims, ok := claimsFromContext(r.Context())
	if !ok {
		h.writeError(w, r, http.StatusUnauthorized, "UNAUTHORIZED", "missing claims", nil)
		return
	}
	courseID := chi.URLParam(r, "courseId")
	owned, err := h.dep.Store.IsCourseOwnedBy(r.Context(), courseID, claims.UserID)
	if err != nil {
		h.writeError(w, r, http.StatusInternalServerError, "INTERNAL_ERROR", "cannot check course access", nil)
		return
	}
	if !owned {
		h.writeError(w, r, http.StatusNotFound, "NOT_FOUND", "course not found", nil)
		return
	}
	var req api.AdminCourseUpdateRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		h.writeError(w, r, http.StatusBadRequest, "VALIDATION_ERROR", "invalid json", nil)
		return
	}
	if req.Difficulty != nil {
		*req.Difficulty = strings.TrimSpace(*req.Difficulty)
		if *req.Difficulty == "" {
			req.Difficulty = nil
		} else if !validDifficulty(*req.Difficulty) {
			h.writeError(w, r, http.StatusBadRequest, "VALIDATION_ERROR", "invalid difficulty", nil)
			return
		}
	}
	course, err := h.dep.Store.UpdateCourse(r.Context(), courseID, req.Title, req.Description, req.Difficulty, req.IsPublished)
	if errors.Is(err, store.ErrNotFound) {
		h.writeError(w, r, http.StatusNotFound, "NOT_FOUND", "course not found", nil)
		return
	}
	if err != nil {
		h.writeError(w, r, http.StatusInternalServerError, "INTERNAL_ERROR", "cannot update course", nil)
		return
	}
	h.writeJSON(w, http.StatusOK, course)
}

func (h handler) adminDeleteCourse(w http.ResponseWriter, r *http.Request) {
	claims, ok := claimsFromContext(r.Context())
	if !ok {
		h.writeError(w, r, http.StatusUnauthorized, "UNAUTHORIZED", "missing claims", nil)
		return
	}
	courseID := chi.URLParam(r, "courseId")
	owned, err := h.dep.Store.IsCourseOwnedBy(r.Context(), courseID, claims.UserID)
	if err != nil {
		h.writeError(w, r, http.StatusInternalServerError, "INTERNAL_ERROR", "cannot check course access", nil)
		return
	}
	if !owned {
		h.writeError(w, r, http.StatusNotFound, "NOT_FOUND", "course not found", nil)
		return
	}
	err = h.dep.Store.DeleteCourse(r.Context(), courseID)
	if errors.Is(err, store.ErrNotFound) {
		h.writeError(w, r, http.StatusNotFound, "NOT_FOUND", "course not found", nil)
		return
	}
	if err != nil {
		h.writeError(w, r, http.StatusInternalServerError, "INTERNAL_ERROR", "cannot delete course", nil)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

func (h handler) adminCreateLesson(w http.ResponseWriter, r *http.Request) {
	claims, ok := claimsFromContext(r.Context())
	if !ok {
		h.writeError(w, r, http.StatusUnauthorized, "UNAUTHORIZED", "missing claims", nil)
		return
	}
	courseID := chi.URLParam(r, "courseId")
	owned, err := h.dep.Store.IsCourseOwnedBy(r.Context(), courseID, claims.UserID)
	if err != nil {
		h.writeError(w, r, http.StatusInternalServerError, "INTERNAL_ERROR", "cannot check course access", nil)
		return
	}
	if !owned {
		h.writeError(w, r, http.StatusNotFound, "NOT_FOUND", "course not found", nil)
		return
	}
	var req api.AdminLessonCreateRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		h.writeError(w, r, http.StatusBadRequest, "VALIDATION_ERROR", "invalid json", nil)
		return
	}
	req.Title = strings.TrimSpace(req.Title)
	if len(req.Title) < 3 {
		h.writeError(w, r, http.StatusBadRequest, "VALIDATION_ERROR", "title too short", nil)
		return
	}
	order := req.OrderIndex
	if order <= 0 {
		mx, err := h.dep.Store.MaxLessonOrder(r.Context(), courseID)
		if err != nil {
			h.writeError(w, r, http.StatusInternalServerError, "INTERNAL_ERROR", "cannot order lesson", nil)
			return
		}
		order = mx + 1
	}
	lesson, err := h.dep.Store.CreateLesson(r.Context(), courseID, req.Title, order, req.Blocks)
	if err != nil {
		h.writeError(w, r, http.StatusInternalServerError, "INTERNAL_ERROR", "cannot create lesson", nil)
		return
	}
	h.writeJSON(w, http.StatusCreated, lesson)
}

func (h handler) adminListLessons(w http.ResponseWriter, r *http.Request) {
	claims, ok := claimsFromContext(r.Context())
	if !ok {
		h.writeError(w, r, http.StatusUnauthorized, "UNAUTHORIZED", "missing claims", nil)
		return
	}
	courseID := chi.URLParam(r, "courseId")
	owned, err := h.dep.Store.IsCourseOwnedBy(r.Context(), courseID, claims.UserID)
	if err != nil {
		h.writeError(w, r, http.StatusInternalServerError, "INTERNAL_ERROR", "cannot check course access", nil)
		return
	}
	if !owned {
		h.writeError(w, r, http.StatusNotFound, "NOT_FOUND", "course not found", nil)
		return
	}
	lessons, err := h.dep.Store.ListLessonsByCourse(r.Context(), courseID)
	if err != nil {
		h.writeError(w, r, http.StatusInternalServerError, "INTERNAL_ERROR", "cannot load lessons", nil)
		return
	}
	h.writeJSON(w, http.StatusOK, lessons)
}

func (h handler) adminUpdateLesson(w http.ResponseWriter, r *http.Request) {
	claims, ok := claimsFromContext(r.Context())
	if !ok {
		h.writeError(w, r, http.StatusUnauthorized, "UNAUTHORIZED", "missing claims", nil)
		return
	}
	lessonID := chi.URLParam(r, "lessonId")
	owned, err := h.dep.Store.IsLessonOwnedBy(r.Context(), lessonID, claims.UserID)
	if err != nil {
		h.writeError(w, r, http.StatusInternalServerError, "INTERNAL_ERROR", "cannot check lesson access", nil)
		return
	}
	if !owned {
		h.writeError(w, r, http.StatusNotFound, "NOT_FOUND", "lesson not found", nil)
		return
	}
	var patch struct {
		Title      *string          `json:"title"`
		OrderIndex *int             `json:"order_index"`
		Blocks     *json.RawMessage `json:"blocks"`
	}
	if err := json.NewDecoder(r.Body).Decode(&patch); err != nil {
		h.writeError(w, r, http.StatusBadRequest, "VALIDATION_ERROR", "invalid json", nil)
		return
	}
	if patch.Title != nil {
		t := strings.TrimSpace(*patch.Title)
		patch.Title = &t
		if len(*patch.Title) < 3 {
			h.writeError(w, r, http.StatusBadRequest, "VALIDATION_ERROR", "title too short", nil)
			return
		}
	}
	lesson, err := h.dep.Store.UpdateLesson(r.Context(), lessonID, patch.Title, patch.OrderIndex, patch.Blocks)
	if errors.Is(err, store.ErrNotFound) {
		h.writeError(w, r, http.StatusNotFound, "NOT_FOUND", "lesson not found", nil)
		return
	}
	if err != nil {
		h.writeError(w, r, http.StatusInternalServerError, "INTERNAL_ERROR", "cannot update lesson", nil)
		return
	}
	h.writeJSON(w, http.StatusOK, lesson)
}

func (h handler) adminDeleteLesson(w http.ResponseWriter, r *http.Request) {
	claims, ok := claimsFromContext(r.Context())
	if !ok {
		h.writeError(w, r, http.StatusUnauthorized, "UNAUTHORIZED", "missing claims", nil)
		return
	}
	lessonID := chi.URLParam(r, "lessonId")
	owned, err := h.dep.Store.IsLessonOwnedBy(r.Context(), lessonID, claims.UserID)
	if err != nil {
		h.writeError(w, r, http.StatusInternalServerError, "INTERNAL_ERROR", "cannot check lesson access", nil)
		return
	}
	if !owned {
		h.writeError(w, r, http.StatusNotFound, "NOT_FOUND", "lesson not found", nil)
		return
	}
	if err := h.dep.Store.DeleteLesson(r.Context(), lessonID); err != nil {
		if errors.Is(err, store.ErrNotFound) {
			h.writeError(w, r, http.StatusNotFound, "NOT_FOUND", "lesson not found", nil)
			return
		}
		h.writeError(w, r, http.StatusInternalServerError, "INTERNAL_ERROR", "cannot delete lesson", nil)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

func (h handler) adminReorderLessons(w http.ResponseWriter, r *http.Request) {
	claims, ok := claimsFromContext(r.Context())
	if !ok {
		h.writeError(w, r, http.StatusUnauthorized, "UNAUTHORIZED", "missing claims", nil)
		return
	}
	courseID := chi.URLParam(r, "courseId")
	owned, err := h.dep.Store.IsCourseOwnedBy(r.Context(), courseID, claims.UserID)
	if err != nil {
		h.writeError(w, r, http.StatusInternalServerError, "INTERNAL_ERROR", "cannot check course access", nil)
		return
	}
	if !owned {
		h.writeError(w, r, http.StatusNotFound, "NOT_FOUND", "course not found", nil)
		return
	}
	var req api.AdminLessonReorderRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil || len(req.LessonOrders) == 0 {
		h.writeError(w, r, http.StatusBadRequest, "VALIDATION_ERROR", "lesson_orders required", nil)
		return
	}
	m := make(map[string]int, len(req.LessonOrders))
	for _, lo := range req.LessonOrders {
		m[lo.LessonID] = lo.OrderIndex
	}
	if err := h.dep.Store.ReorderLessons(r.Context(), courseID, m); err != nil {
		h.writeError(w, r, http.StatusBadRequest, "VALIDATION_ERROR", "reorder failed", nil)
		return
	}
	h.writeJSON(w, http.StatusOK, map[string]string{"course_id": courseID, "status": "reordered"})
}

func (h handler) adminCreateQuiz(w http.ResponseWriter, r *http.Request) {
	claims, ok := claimsFromContext(r.Context())
	if !ok {
		h.writeError(w, r, http.StatusUnauthorized, "UNAUTHORIZED", "missing claims", nil)
		return
	}
	lessonID := chi.URLParam(r, "lessonId")
	owned, err := h.dep.Store.IsLessonOwnedBy(r.Context(), lessonID, claims.UserID)
	if err != nil {
		h.writeError(w, r, http.StatusInternalServerError, "INTERNAL_ERROR", "cannot check lesson access", nil)
		return
	}
	if !owned {
		h.writeError(w, r, http.StatusNotFound, "NOT_FOUND", "lesson not found", nil)
		return
	}
	var req api.AdminQuizUpsertRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		h.writeError(w, r, http.StatusBadRequest, "VALIDATION_ERROR", "invalid json", nil)
		return
	}
	req.Title = strings.TrimSpace(req.Title)
	if req.Title == "" || len(req.Questions) < 3 || string(req.Questions) == "null" {
		h.writeError(w, r, http.StatusBadRequest, "VALIDATION_ERROR", "title and questions required", map[string]interface{}{
			"fields": []api.ValidationFieldError{
				{Field: "title", Rule: "required", Message: "title is required"},
				{Field: "questions", Rule: "required", Message: "questions is required"},
			},
		})
		return
	}
	q, err := h.dep.Store.CreateQuiz(r.Context(), lessonID, req.Title, req.Questions)
	if err != nil {
		h.writeError(w, r, http.StatusInternalServerError, "INTERNAL_ERROR", "cannot create quiz", nil)
		return
	}
	h.writeJSON(w, http.StatusCreated, q)
}

func (h handler) adminGetQuizByLesson(w http.ResponseWriter, r *http.Request) {
	claims, ok := claimsFromContext(r.Context())
	if !ok {
		h.writeError(w, r, http.StatusUnauthorized, "UNAUTHORIZED", "missing claims", nil)
		return
	}
	lessonID := chi.URLParam(r, "lessonId")
	owned, err := h.dep.Store.IsLessonOwnedBy(r.Context(), lessonID, claims.UserID)
	if err != nil {
		h.writeError(w, r, http.StatusInternalServerError, "INTERNAL_ERROR", "cannot check lesson access", nil)
		return
	}
	if !owned {
		h.writeError(w, r, http.StatusNotFound, "NOT_FOUND", "lesson not found", nil)
		return
	}
	q, err := h.dep.Store.GetQuizByLesson(r.Context(), lessonID)
	if errors.Is(err, store.ErrNotFound) {
		h.writeError(w, r, http.StatusNotFound, "NOT_FOUND", "quiz not found", nil)
		return
	}
	if err != nil {
		h.writeError(w, r, http.StatusInternalServerError, "INTERNAL_ERROR", "cannot load quiz", nil)
		return
	}
	h.writeJSON(w, http.StatusOK, q)
}

func (h handler) adminUpdateQuiz(w http.ResponseWriter, r *http.Request) {
	claims, ok := claimsFromContext(r.Context())
	if !ok {
		h.writeError(w, r, http.StatusUnauthorized, "UNAUTHORIZED", "missing claims", nil)
		return
	}
	quizID := chi.URLParam(r, "quizId")
	owned, err := h.dep.Store.IsQuizOwnedBy(r.Context(), quizID, claims.UserID)
	if err != nil {
		h.writeError(w, r, http.StatusInternalServerError, "INTERNAL_ERROR", "cannot check quiz access", nil)
		return
	}
	if !owned {
		h.writeError(w, r, http.StatusNotFound, "NOT_FOUND", "quiz not found", nil)
		return
	}
	var req api.AdminQuizUpsertRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		h.writeError(w, r, http.StatusBadRequest, "VALIDATION_ERROR", "invalid json", nil)
		return
	}
	req.Title = strings.TrimSpace(req.Title)
	if req.Title == "" || len(req.Questions) < 3 {
		h.writeError(w, r, http.StatusBadRequest, "VALIDATION_ERROR", "title and questions required", map[string]interface{}{
			"fields": []api.ValidationFieldError{
				{Field: "title", Rule: "required", Message: "title is required"},
				{Field: "questions", Rule: "required", Message: "questions is required"},
			},
		})
		return
	}
	q, err := h.dep.Store.UpdateQuiz(r.Context(), quizID, req.Title, req.Questions)
	if errors.Is(err, store.ErrNotFound) {
		h.writeError(w, r, http.StatusNotFound, "NOT_FOUND", "quiz not found", nil)
		return
	}
	if err != nil {
		h.writeError(w, r, http.StatusInternalServerError, "INTERNAL_ERROR", "cannot update quiz", nil)
		return
	}
	h.writeJSON(w, http.StatusOK, q)
}

func (h handler) adminDeleteQuiz(w http.ResponseWriter, r *http.Request) {
	claims, ok := claimsFromContext(r.Context())
	if !ok {
		h.writeError(w, r, http.StatusUnauthorized, "UNAUTHORIZED", "missing claims", nil)
		return
	}
	quizID := chi.URLParam(r, "quizId")
	owned, err := h.dep.Store.IsQuizOwnedBy(r.Context(), quizID, claims.UserID)
	if err != nil {
		h.writeError(w, r, http.StatusInternalServerError, "INTERNAL_ERROR", "cannot check quiz access", nil)
		return
	}
	if !owned {
		h.writeError(w, r, http.StatusNotFound, "NOT_FOUND", "quiz not found", nil)
		return
	}
	err = h.dep.Store.DeleteQuiz(r.Context(), quizID)
	if errors.Is(err, store.ErrNotFound) {
		h.writeError(w, r, http.StatusNotFound, "NOT_FOUND", "quiz not found", nil)
		return
	}
	if err != nil {
		h.writeError(w, r, http.StatusInternalServerError, "INTERNAL_ERROR", "cannot delete quiz", nil)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

func (h handler) adminCourseLearnersStats(w http.ResponseWriter, r *http.Request) {
	claims, ok := claimsFromContext(r.Context())
	if !ok {
		h.writeError(w, r, http.StatusUnauthorized, "UNAUTHORIZED", "missing claims", nil)
		return
	}
	courseID := chi.URLParam(r, "courseId")
	owned, err := h.dep.Store.IsCourseOwnedBy(r.Context(), courseID, claims.UserID)
	if err != nil {
		h.writeError(w, r, http.StatusInternalServerError, "INTERNAL_ERROR", "cannot check course access", nil)
		return
	}
	if !owned {
		h.writeError(w, r, http.StatusNotFound, "NOT_FOUND", "course not found", nil)
		return
	}
	stats, err := h.dep.Store.AdminCourseLearnersStats(r.Context(), courseID)
	if err != nil {
		h.writeError(w, r, http.StatusInternalServerError, "INTERNAL_ERROR", "cannot load course analytics", nil)
		return
	}
	h.writeJSON(w, http.StatusOK, map[string]interface{}{
		"course_id": courseID,
		"learners":  stats,
	})
}

func validDifficulty(s string) bool {
	switch s {
	case "beginner", "intermediate", "advanced":
		return true
	default:
		return false
	}
}
