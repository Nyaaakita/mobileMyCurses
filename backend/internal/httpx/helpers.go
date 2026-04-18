package httpx

import "github.com/google/uuid"

func parseUUID(id string) uuid.UUID {
	parsed, err := uuid.Parse(id)
	if err != nil {
		return uuid.Nil
	}
	return parsed
}

func ptrInt(v int) *int {
	return &v
}
