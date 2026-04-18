package httpx

import (
	"encoding/json"
	"net/http"
	"sync"
	"time"

	"lms/backend/internal/api"

	"golang.org/x/time/rate"
)

func (h handler) requireAuth(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		token := bearerToken(r.Header.Get("Authorization"))
		if token == "" {
			h.writeError(w, r, http.StatusUnauthorized, "UNAUTHORIZED", "missing bearer token", nil)
			return
		}

		claims, err := h.dep.AccessTokenManager.Parse(token)
		if err != nil {
			h.writeError(w, r, http.StatusUnauthorized, "UNAUTHORIZED", "invalid token", nil)
			return
		}

		ctx := withClaims(r.Context(), ClaimsIdentity{UserID: claims.UserID, Role: claims.Role})
		next.ServeHTTP(w, r.WithContext(ctx))
	})
}

var (
	authLimiterMu sync.Mutex
	authLimiters  = map[string]*rate.Limiter{}
)

func (h handler) authRateLimit() func(http.Handler) http.Handler {
	rps := h.dep.AuthRateLimitRPS
	burst := h.dep.AuthRateLimitBurst
	if rps <= 0 {
		rps = 5
	}
	if burst <= 0 {
		burst = 10
	}
	return func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			ip := r.RemoteAddr
			key := ip + "|" + r.URL.Path
			authLimiterMu.Lock()
			lim, ok := authLimiters[key]
			if !ok {
				lim = rate.NewLimiter(rate.Every(time.Second/time.Duration(rps)), burst)
				authLimiters[key] = lim
			}
			authLimiterMu.Unlock()
			if !lim.Allow() {
				h.writeError(w, r, http.StatusTooManyRequests, "RATE_LIMITED", "too many requests", nil)
				return
			}
			next.ServeHTTP(w, r)
		})
	}
}

func (h handler) requireRole(role string) func(http.Handler) http.Handler {
	return func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			claims, ok := claimsFromContext(r.Context())
			if !ok || claims.Role != role {
				h.writeError(w, r, http.StatusForbidden, "FORBIDDEN", "insufficient role", nil)
				return
			}
			next.ServeHTTP(w, r)
		})
	}
}

func (h handler) writeJSON(w http.ResponseWriter, status int, payload interface{}) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	_ = json.NewEncoder(w).Encode(payload)
}

func (h handler) writeError(w http.ResponseWriter, r *http.Request, status int, code, message string, details interface{}) {
	h.writeJSON(w, status, api.ErrorResponse{
		ErrorCode: code,
		Message:   message,
		Details:   details,
		RequestID: r.Header.Get("X-Request-ID"),
	})
}
