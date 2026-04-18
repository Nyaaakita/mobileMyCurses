package httpx

import (
	"bytes"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"
)

func TestAdminCreateCourse_ValidationError(t *testing.T) {
	h := handler{}
	body := []byte(`{"title":"ab","description":"short","difficulty":"beginner"}`)
	req := httptest.NewRequest(http.MethodPost, "/api/v1/admin/courses", bytes.NewReader(body))
	req = req.WithContext(withClaims(req.Context(), ClaimsIdentity{UserID: "00000000-0000-4000-8000-0000000000ad", Role: "admin"}))
	rr := httptest.NewRecorder()
	h.adminCreateCourse(rr, req)

	if rr.Code != http.StatusBadRequest {
		t.Fatalf("expected 400, got %d", rr.Code)
	}
	var payload map[string]interface{}
	if err := json.Unmarshal(rr.Body.Bytes(), &payload); err != nil {
		t.Fatalf("decode response: %v", err)
	}
	if payload["error_code"] != "VALIDATION_ERROR" {
		t.Fatalf("unexpected error_code: %v", payload["error_code"])
	}
}
