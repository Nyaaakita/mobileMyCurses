package store

import (
	"context"
	"errors"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
)

var ErrNotFound = errors.New("not found")

func (s *Store) CreateUser(ctx context.Context, email, name, passwordHash, role string) (User, error) {
	id := uuid.New()
	var user User
	err := s.db.QueryRow(ctx, `
		insert into users (id, email, name, password_hash, role)
		values ($1, $2, $3, $4, $5)
		returning id::text, email, name, password_hash, role, created_at
	`, id, email, name, passwordHash, role).Scan(
		&user.ID, &user.Email, &user.Name, &user.PasswordHash, &user.Role, &user.CreatedAt,
	)
	return user, err
}

func (s *Store) GetUserByEmail(ctx context.Context, email string) (User, error) {
	var user User
	err := s.db.QueryRow(ctx, `
		select id::text, email, name, password_hash, role, created_at
		from users
		where email = $1
	`, email).Scan(&user.ID, &user.Email, &user.Name, &user.PasswordHash, &user.Role, &user.CreatedAt)
	if errors.Is(err, pgx.ErrNoRows) {
		return User{}, ErrNotFound
	}
	return user, err
}

func (s *Store) GetUserByID(ctx context.Context, id string) (User, error) {
	var user User
	err := s.db.QueryRow(ctx, `
		select id::text, email, name, password_hash, role, created_at
		from users
		where id = $1
	`, id).Scan(&user.ID, &user.Email, &user.Name, &user.PasswordHash, &user.Role, &user.CreatedAt)
	if errors.Is(err, pgx.ErrNoRows) {
		return User{}, ErrNotFound
	}
	return user, err
}

func (s *Store) ListPublishedCourses(ctx context.Context) ([]Course, error) {
	rows, err := s.db.Query(ctx, `
		select id::text, title, description, cover_url, difficulty, estimated_minutes, content_version, is_published
		from courses
		where is_published = true
		order by created_at desc
	`)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	courses := make([]Course, 0)
	for rows.Next() {
		var c Course
		if err := rows.Scan(&c.ID, &c.Title, &c.Description, &c.CoverURL, &c.Difficulty, &c.EstimatedMinutes, &c.ContentVersion, &c.IsPublished); err != nil {
			return nil, err
		}
		courses = append(courses, c)
	}
	return courses, rows.Err()
}

func (s *Store) CreateCourse(ctx context.Context, c Course, creatorID string) (Course, error) {
	id := uuid.New()
	var out Course
	err := s.db.QueryRow(ctx, `
		insert into courses (id, title, description, cover_url, difficulty, estimated_minutes, is_published, content_version, creator_id)
		values ($1, $2, $3, $4, $5, $6, $7, 1, $8::uuid)
		returning id::text, title, description, cover_url, difficulty, estimated_minutes, content_version, is_published
	`, id, c.Title, c.Description, c.CoverURL, c.Difficulty, c.EstimatedMinutes, c.IsPublished, creatorID).Scan(
		&out.ID, &out.Title, &out.Description, &out.CoverURL, &out.Difficulty, &out.EstimatedMinutes, &out.ContentVersion, &out.IsPublished,
	)
	return out, err
}

