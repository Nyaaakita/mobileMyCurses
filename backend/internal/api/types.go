package api

import "encoding/json"

type RegisterRequest struct {
	Email    string `json:"email"`
	Password string `json:"password"`
	Name     string `json:"name"`
}

type LoginRequest struct {
	Email    string `json:"email"`
	Password string `json:"password"`
}

type AuthTokensResponse struct {
	AccessToken  string `json:"access_token"`
	RefreshToken string `json:"refresh_token"`
	ExpiresIn    int    `json:"expires_in"`
}

type MeResponse struct {
	ID    string `json:"id"`
	Email string `json:"email"`
	Name  string `json:"name"`
	Role  string `json:"role"`
}

type ProgressBatchRequest struct {
	Items []ProgressItem `json:"items"`
}

type ProgressItem struct {
	LessonID      string          `json:"lesson_id"`
	Status        string          `json:"status"`
	Score         *int            `json:"score"`
	Answers       json.RawMessage `json:"answers"`
	UpdatedAt     string          `json:"updated_at"`
	ClientEventID string          `json:"client_event_id"`
}

type ProgressBatchResponse struct {
	Accepted []string                `json:"accepted"`
	Rejected []RejectedProgressItem `json:"rejected"`
}

type RejectedProgressItem struct {
	ClientEventID string `json:"client_event_id"`
	Reason        string `json:"reason"`
}

type RefreshRequest struct {
	RefreshToken string `json:"refresh_token"`
}

type QuizSubmitRequest struct {
	Answers []QuizAnswerIn `json:"answers"`
}

type QuizAnswerIn struct {
	QuestionID        string   `json:"question_id"`
	SelectedOptionIDs []string `json:"selected_option_ids"`
}

type QuizSubmitResponse struct {
	Score    int  `json:"score"`
	MaxScore int  `json:"max_score"`
	Passed   bool `json:"passed"`
}

type AssignmentSubmitRequest struct {
	AnswerText string  `json:"answer_text"`
	Language   *string `json:"language"`
}

type AssignmentSubmitResponse struct {
	Status   string `json:"status"`
	Score    *int   `json:"score"`
	Feedback string `json:"feedback"`
}

type AdminCourseUpdateRequest struct {
	Title        *string `json:"title"`
	Description  *string `json:"description"`
	Difficulty   *string `json:"difficulty"`
	IsPublished  *bool   `json:"is_published"`
}

type AdminLessonCreateRequest struct {
	Title      string          `json:"title"`
	OrderIndex int             `json:"order_index"`
	Blocks     json.RawMessage `json:"blocks"`
}

type AdminLessonReorderRequest struct {
	LessonOrders []LessonOrder `json:"lesson_orders"`
}

type LessonOrder struct {
	LessonID   string `json:"lesson_id"`
	OrderIndex int    `json:"order_index"`
}

type AdminQuizUpsertRequest struct {
	Title     string          `json:"title"`
	Questions json.RawMessage `json:"questions"`
}
