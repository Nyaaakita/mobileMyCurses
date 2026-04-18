package store

import "context"

type AdminCourseLearnerStats struct {
	UserID           string  `json:"user_id"`
	Name             string  `json:"name"`
	Email            string  `json:"email"`
	StartedAt        string  `json:"started_at"`
	CompletedLessons int     `json:"completed_lessons"`
	TotalLessons     int     `json:"total_lessons"`
	ProgressPercent  int     `json:"progress_percent"`
	QuizzesTotal     int     `json:"quizzes_total"`
	QuizzesDone      int     `json:"quizzes_done"`
	QuizFirstScore   int     `json:"quiz_first_score"`
	QuizLastScore    int     `json:"quiz_last_score"`
	QuizAvgScore     float64 `json:"quiz_avg_score"`
	QuizStatsByTest  []AdminLearnerQuizStats `json:"quiz_stats_by_test"`
}

type AdminLearnerQuizStats struct {
	LessonID       string  `json:"lesson_id"`
	LessonTitle    string  `json:"lesson_title"`
	QuizID         string  `json:"quiz_id"`
	QuizTitle      string  `json:"quiz_title"`
	AttemptsCount  int     `json:"attempts_count"`
	FirstScore     int     `json:"first_score"`
	LastScore      int     `json:"last_score"`
	AverageScore   float64 `json:"average_score"`
}

func (s *Store) AdminCourseLearnersStats(ctx context.Context, courseID string) ([]AdminCourseLearnerStats, error) {
	rows, err := s.db.Query(ctx, `
		with lesson_counts as (
			select
				l.course_id::text as course_id,
				count(*)::int as total_lessons,
				count(*) filter (where q.id is not null)::int as quizzes_total
			from lessons l
			left join quizzes q on q.lesson_id = l.id
			where l.course_id = $1::uuid
			group by l.course_id
		),
		learners as (
			select
				u.id::text as user_id,
				u.name as name,
				u.email as email
			from users u
			join user_progress up on up.user_id = u.id
			join lessons l on l.id = up.lesson_id
			where l.course_id = $1::uuid
			group by u.id, u.name, u.email
		),
		progress_per_user as (
			select
				up.user_id::text as user_id,
				min(up.updated_at) as started_at,
				count(distinct up.lesson_id) filter (where up.status = 'completed')::int as completed_lessons
			from user_progress up
			join lessons l on l.id = up.lesson_id
			where l.course_id = $1::uuid
			group by up.user_id
		),
		quiz_attempts_in_course as (
			select
				qa.user_id::text as user_id,
				qa.quiz_id::text as quiz_id,
				qa.score as score,
				qa.created_at as created_at
			from quiz_attempts qa
			join lessons l on l.id = qa.lesson_id
			where l.course_id = $1::uuid
			  and jsonb_array_length(coalesce(qa.answers, '[]'::jsonb)) > 0
		),
		quiz_stats as (
			select
				q.user_id,
				count(distinct q.quiz_id)::int as quizzes_done,
				coalesce(avg(q.score), 0)::float8 as quiz_avg_score
			from quiz_attempts_in_course q
			group by q.user_id
		),
		quiz_first as (
			select distinct on (q.user_id)
				q.user_id,
				q.score as quiz_first_score
			from quiz_attempts_in_course q
			order by q.user_id, q.created_at asc
		),
		quiz_last as (
			select distinct on (q.user_id)
				q.user_id,
				q.score as quiz_last_score
			from quiz_attempts_in_course q
			order by q.user_id, q.created_at desc
		)
		select
			lu.user_id,
			lu.name,
			lu.email,
			coalesce(to_char(pp.started_at at time zone 'utc', 'YYYY-MM-DD"T"HH24:MI:SS"Z"'), '') as started_at,
			coalesce(pp.completed_lessons, 0) as completed_lessons,
			coalesce(lc.total_lessons, 0) as total_lessons,
			case
				when coalesce(lc.total_lessons, 0) = 0 then 0
				else least(100, (coalesce(pp.completed_lessons, 0) * 100 / lc.total_lessons))
			end as progress_percent,
			coalesce(lc.quizzes_total, 0) as quizzes_total,
			coalesce(qs.quizzes_done, 0) as quizzes_done,
			coalesce(qf.quiz_first_score, 0) as quiz_first_score,
			coalesce(ql.quiz_last_score, 0) as quiz_last_score,
			coalesce(qs.quiz_avg_score, 0) as quiz_avg_score
		from learners lu
		left join lesson_counts lc on lc.course_id = $1::text
		left join progress_per_user pp on pp.user_id = lu.user_id
		left join quiz_stats qs on qs.user_id = lu.user_id
		left join quiz_first qf on qf.user_id = lu.user_id
		left join quiz_last ql on ql.user_id = lu.user_id
		order by pp.started_at desc nulls last
	`, courseID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	out := make([]AdminCourseLearnerStats, 0)
	for rows.Next() {
		var x AdminCourseLearnerStats
		if err := rows.Scan(
			&x.UserID,
			&x.Name,
			&x.Email,
			&x.StartedAt,
			&x.CompletedLessons,
			&x.TotalLessons,
			&x.ProgressPercent,
			&x.QuizzesTotal,
			&x.QuizzesDone,
			&x.QuizFirstScore,
			&x.QuizLastScore,
			&x.QuizAvgScore,
		); err != nil {
			return nil, err
		}
		perQuiz, err := s.AdminLearnerQuizStatsByCourse(ctx, courseID, x.UserID)
		if err != nil {
			return nil, err
		}
		x.QuizStatsByTest = perQuiz
		out = append(out, x)
	}
	return out, rows.Err()
}

func (s *Store) AdminLearnerQuizStatsByCourse(
	ctx context.Context,
	courseID string,
	userID string,
) ([]AdminLearnerQuizStats, error) {
	rows, err := s.db.Query(ctx, `
		with attempts as (
			select
				qa.quiz_id::text as quiz_id,
				qa.lesson_id::text as lesson_id,
				qa.score as score,
				qa.created_at as created_at
			from quiz_attempts qa
			join lessons l on l.id = qa.lesson_id
			where l.course_id = $1::uuid
			  and qa.user_id = $2::uuid
			  and jsonb_array_length(coalesce(qa.answers, '[]'::jsonb)) > 0
		),
		agg as (
			select
				a.quiz_id,
				a.lesson_id,
				count(*)::int as attempts_count,
				coalesce(avg(a.score), 0)::float8 as average_score
			from attempts a
			group by a.quiz_id, a.lesson_id
		),
		firsts as (
			select distinct on (a.quiz_id)
				a.quiz_id,
				a.score as first_score
			from attempts a
			order by a.quiz_id, a.created_at asc
		),
		lasts as (
			select distinct on (a.quiz_id)
				a.quiz_id,
				a.score as last_score
			from attempts a
			order by a.quiz_id, a.created_at desc
		)
		select
			l.id::text as lesson_id,
			l.title as lesson_title,
			q.id::text as quiz_id,
			q.title as quiz_title,
			a.attempts_count,
			coalesce(f.first_score, 0) as first_score,
			coalesce(ls.last_score, 0) as last_score,
			a.average_score
		from agg a
		join lessons l on l.id::text = a.lesson_id
		join quizzes q on q.id::text = a.quiz_id
		left join firsts f on f.quiz_id = a.quiz_id
		left join lasts ls on ls.quiz_id = a.quiz_id
		order by l.order_index asc, q.created_at asc
	`, courseID, userID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	out := make([]AdminLearnerQuizStats, 0)
	for rows.Next() {
		var x AdminLearnerQuizStats
		if err := rows.Scan(
			&x.LessonID,
			&x.LessonTitle,
			&x.QuizID,
			&x.QuizTitle,
			&x.AttemptsCount,
			&x.FirstScore,
			&x.LastScore,
			&x.AverageScore,
		); err != nil {
			return nil, err
		}
		out = append(out, x)
	}
	return out, rows.Err()
}

