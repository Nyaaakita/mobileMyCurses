package store

import "time"

type User struct {
	ID           string
	Email        string
	Name         string
	PasswordHash string
	Role         string
	CreatedAt    time.Time
}

type Course struct {
	ID               string `json:"id"`
	Title            string `json:"title"`
	Description      string `json:"description"`
	CoverURL         *string `json:"cover_url"`
	Difficulty       string `json:"difficulty"`
	EstimatedMinutes int    `json:"estimated_minutes"`
	ContentVersion   int    `json:"content_version"`
	IsPublished      bool   `json:"is_published"`
}

type LessonSummary struct {
	ID         string `json:"id"`
	Title      string `json:"title"`
	OrderIndex int    `json:"order_index"`
	Status     string `json:"status"`
}
