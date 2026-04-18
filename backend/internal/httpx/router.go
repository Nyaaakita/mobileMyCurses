package httpx

import (
	"net/http"
	"strings"

	"github.com/go-chi/chi/v5"
	"github.com/go-chi/chi/v5/middleware"

	"lms/backend/internal/auth"
	"lms/backend/internal/store"
)

type Dependencies struct {
	Store               *store.Store
	AccessTokenManager  auth.TokenManager
	RefreshTokenManager auth.TokenManager
	JWTSecret           string
	AuthRateLimitRPS    int
	AuthRateLimitBurst  int
}

func NewRouter(dep Dependencies) http.Handler {
	h := handler{dep: dep}
	r := chi.NewRouter()
	r.Use(middleware.RequestID, middleware.Recoverer, middleware.RealIP, middleware.Logger)

	r.Get("/healthz", h.health)

	r.Route("/api/v1", func(r chi.Router) {
		r.Route("/auth", func(r chi.Router) {
			r.With(h.authRateLimit()).Post("/register", h.register)
			r.With(h.authRateLimit()).Post("/login", h.login)
			r.With(h.authRateLimit()).Post("/refresh", h.refresh)
			r.With(h.requireAuth).Get("/me", h.me)
			r.With(h.requireAuth).Post("/logout", h.logout)
		})

		r.With(h.requireAuth).Get("/courses", h.listCourses)
		r.With(h.requireAuth).Get("/courses/{courseId}", h.getCourseDetails)
		r.With(h.requireAuth).Get("/lessons/{lessonId}", h.getLesson)
		r.With(h.requireAuth).Get("/progress/courses/{courseId}", h.getCourseProgress)
		r.With(h.requireAuth).Put("/progress/batch", h.progressBatch)
		r.With(h.requireAuth).Get("/quizzes/{quizId}", h.getQuizForStudent)
		r.With(h.requireAuth).Post("/quizzes/{quizId}/submit", h.quizSubmit)
		r.With(h.requireAuth).Post("/assignments/{assignmentId}/submit", h.assignmentSubmit)

		r.Route("/admin", func(r chi.Router) {
			r.Use(h.requireAuth, h.requireRole("admin"))
			r.Get("/courses", h.adminListCourses)
			r.Get("/courses/{courseId}", h.adminGetCourse)
			r.Post("/courses", h.adminCreateCourse)
			r.Patch("/courses/{courseId}", h.adminUpdateCourse)
			r.Delete("/courses/{courseId}", h.adminDeleteCourse)
			r.Get("/courses/{courseId}/lessons", h.adminListLessons)
			r.Get("/courses/{courseId}/learners-stats", h.adminCourseLearnersStats)
			r.Post("/courses/{courseId}/lessons", h.adminCreateLesson)
			r.Patch("/lessons/{lessonId}", h.adminUpdateLesson)
			r.Delete("/lessons/{lessonId}", h.adminDeleteLesson)
			r.Patch("/courses/{courseId}/lessons/reorder", h.adminReorderLessons)
			r.Get("/lessons/{lessonId}/quiz", h.adminGetQuizByLesson)
			r.Post("/lessons/{lessonId}/quiz", h.adminCreateQuiz)
			r.Patch("/quizzes/{quizId}", h.adminUpdateQuiz)
			r.Delete("/quizzes/{quizId}", h.adminDeleteQuiz)
		})
	})

	return r
}

type ClaimsIdentity struct {
	UserID string
	Role   string
}

func bearerToken(header string) string {
	if header == "" {
		return ""
	}
	parts := strings.SplitN(header, " ", 2)
	if len(parts) != 2 || !strings.EqualFold(parts[0], "bearer") {
		return ""
	}
	return strings.TrimSpace(parts[1])
}
