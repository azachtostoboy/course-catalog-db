SELECT id, title, credits, likes
FROM courses
WHERE is_elective = false
ORDER BY likes DESC, id
    LIMIT 3 OFFSET 0;

SELECT id, title, credits, likes
FROM courses
WHERE is_elective = false
ORDER BY likes DESC, id
    LIMIT 3 OFFSET 3;

SELECT id, title, credits, is_elective, likes
FROM courses
WHERE id = 'api-design';

SELECT id, title, credits, is_elective, likes
FROM courses
WHERE id = 'no-such-course';

BEGIN;
UPDATE courses
SET likes = likes + 1
WHERE id = 'api-design'
    RETURNING id, likes;

UPDATE courses
SET likes = likes + 1
WHERE id = 'no-such-course'
    RETURNING id, likes;
ROLLBACK;

BEGIN;
INSERT INTO enrollments (course_id, student_id)
VALUES ('web-security', 3)
    RETURNING id, course_id, student_id;
ROLLBACK;

SELECT e.id, s.name AS student, c.title AS course
FROM enrollments e
         JOIN students s ON s.id = e.student_id
         JOIN courses c  ON c.id = e.course_id
ORDER BY e.id;

SELECT c.id, count(e.id) AS enrolled
FROM courses c
         LEFT JOIN enrollments e ON e.course_id = c.id
GROUP BY c.id
ORDER BY enrolled DESC, c.id;