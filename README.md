# course-catalog-db

PostgreSQL schema for the course catalog (Lab 6, “Advanced Web Technologies”).

- **ФИО:** Кешубаев Нурмухамед
- **Группа:** IT3-2304
- **Лабораторная работа:** №6 (PostgreSQL: Designing a Database Schema)

## How to run

PostgreSQL 16 or newer is required. Once, as the `postgres` superuser:

~~~sql
CREATE ROLE catalog_app LOGIN PASSWORD 'change-me';
CREATE DATABASE course_catalog OWNER catalog_app;
CREATE DATABASE idx_demo OWNER catalog_app;
CREATE DATABASE norm_demo OWNER catalog_app;
~~~

Then, from the project folder:

~~~bash
psql -h localhost -U catalog_app -d course_catalog -v ON_ERROR_STOP=1 -f schema.sql
psql -h localhost -U catalog_app -d course_catalog -v ON_ERROR_STOP=1 -f seed.sql
psql -h localhost -U catalog_app -d course_catalog -v ON_ERROR_STOP=1 -f queries.sql
~~~

The password `change-me` is for teaching; real projects keep passwords out of git.

## Schema

~~~mermaid
erDiagram
    COURSES ||--o{ ENROLLMENTS : "course enrollments"
    STUDENTS ||--o{ ENROLLMENTS : "student enrollments"
    COURSES {
        text id PK "course slug"
        text title
        text description
        integer credits
        boolean is_elective
        integer likes
    }
    STUDENTS {
        bigint id PK
        text name
        text email UK
    }
    ENROLLMENTS {
        bigint id PK
        text course_id FK
        bigint student_id FK
        timestamptz enrolled_at
    }
~~~

Схема состоит из трёх таблиц: `courses` (курсы), `students` (студенты) и связующей таблицы `enrollments` (записи на курсы). Между курсами и студентами реализована связь «многие-ко-многим» (many-to-many), которая раскрывается через промежуточную таблицу `enrollments` с двумя внешними ключами (`course_id` и `student_id`) и уникальным ограничением на пару `(course_id, student_id)`.

## Design decisions

- **Почему `courses.id` — это `text` (slug), а `students.id` — автоинкрементное число (`bigint`):** Курсы создаются редко и имеют человекочитаемые адреса в URL (`/courses/modern-frontend`), поэтому текстовый slug удобен для маршрутизации и чтения запросов. У студентов нет неизменяемого идентификатора в URL, их много, а имя и email могут меняться — поэтому для `students.id` выбран суррогатный ключ `bigint GENERATED ALWAYS AS IDENTITY`, который компактен (8 байт) и быстр в индексах.
- **Почему `RESTRICT` на `enrollments.course_id`, но `CASCADE` на `enrollments.student_id`:** Удаление курса, на который уже записаны студенты, привело бы к потере истории обучения, поэтому `ON DELETE RESTRICT` блокирует удаление такого курса. Запись на курс принадлежит конкретному студенту и не имеет смысла без него, поэтому при удалении студента `ON DELETE CASCADE` автоматически очищает его записи.
- **Почему `timestamptz` вместо `timestamp` и `text` вместо `varchar(n)`:** `timestamptz` сохраняет момент времени с привязкой к часовому поясу (UTC), исключая путаницу при работе в разных часовых поясах. В PostgreSQL `text` и `varchar(n)` хранятся одинаково и имеют одинаковую производительность, но `varchar(n)` требует миграций при изменении лимита длины.

## Constraint violation log

Commands were run with `\set VERBOSITY verbose`.

| # | What we violate | SQLSTATE | Constraint | API response |
|---|-----------------|----------|------------|--------------|
| 1 | NULL in courses.title | `23502` | `title` (COLUMN NAME, NOT NULL) | `422 Unprocessable Entity` |
| 2 | courses.credits = 0 | `23514` | `courses_credits_check` | `422 Unprocessable Entity` |
| 3 | courses.likes = -1 | `23514` | `courses_likes_check` | `500 Internal Server Error` |
| 4 | a one-letter student name | `23514` | `students_name_check` | `422 Unprocessable Entity` |
| 5 | a duplicate student email | `23505` | `students_email_key` | `409 Conflict` |
| 6 | a duplicate course id | `23505` | `courses_pkey` | `409 Conflict` |
| 7 | a repeated enrollment in a course | `23505` | `enrollments_course_id_student_id_key` | `409 Conflict` |
| 8 | enrolling in a nonexistent course | `23503` | `enrollments_course_id_fkey` | `404 Not Found` |
| 9 | enrolling a nonexistent student | `23503` | `enrollments_student_id_fkey` | `404 Not Found` |
| 10 | deleting a course that has enrollments | `23001` / `23503` | `enrollments_course_id_fkey` | `409 Conflict` |
| 11 | deleting a student (`daniyar@example.com`) | — | `enrollments_student_id_fkey` (`ON DELETE CASCADE`) | Записи студента удалились каскадно: 6 → 3, после `ROLLBACK` снова 6 |

**Почему нужно проверять ограничения в базе данных, если в коде API уже есть проверка Pydantic (`Field(min_length=2)`)?**  
База данных — последний рубеж защиты целостности данных. К одной базе могут обращаться разные сервисы, скрипты или администраторы через `psql` в обход FastAPI, а ограничения внутри PostgreSQL гарантируют, что невалидные данные никогда не попадут в таблицы.

## Index: EXPLAIN before and after

Query: `SELECT * FROM enrollments WHERE student_id = 777;`  
Database `idx_demo`: 500 courses, 20,000 students, 50,000 enrollments.

| Metric | Before the index | After the index |
|---|------------------|-----------------|
| Access method | `Seq Scan on enrollments` | `Bitmap Heap Scan` + `Bitmap Index Scan on enrollments_student_id_idx` |
| cost | `0.00..1042.00` | `4.31..15.59` |
| Rows Removed by Filter | `49997` | `0` |
| Execution Time | `3.636 ms` | `0.048 ms` |

Plan before the index:

~~~text
Seq Scan on enrollments  (cost=0.00..1042.00 rows=3 width=34)
  Filter: (student_id = 777)
~~~

Plan after the index:

~~~text
Bitmap Heap Scan on enrollments  (cost=4.31..15.59 rows=3 width=34)
  Recheck Cond: (student_id = 777)
  ->  Bitmap Index Scan on enrollments_student_id_idx  (cost=0.00..4.31 rows=3 width=0)
        Index Cond: (student_id = 777)
~~~

Answers to the questions:
1. **Почему PostgreSQL не создал индекс на `enrollments.student_id` автоматически, хотя индексы на `email` и `course_id` были?** PostgreSQL автоматически создаёт индексы только для `PRIMARY KEY` и `UNIQUE`, но не для `FOREIGN KEY`. У `email` есть `UNIQUE`, а `course_id` идёт первым столбцом в `UNIQUE (course_id, student_id)`, поэтому поиск по `course_id` использует этот индекс, а по второму столбцу (`student_id`) — нет.
2. **Почему поиск по первичному ключу на таблице `courses` (6 строк) использует `Seq Scan`, а на `enrollments` (50 000 строк) идёт через индекс?** Все 6 строк таблицы `courses` помещаются на одной странице памяти, и прочитать её подряд (`Seq Scan`, cost `1.07`) дешевле, чем обращаться к индексу и затем к таблице. На 50 000 строк чтение всей таблицы (`cost 1042`) намного дороже индексного поиска (`cost 15.59`).
3. **Назовите две операции, которые ускорит индекс на `student_id`:**
    1) Выборка записей конкретного студента (`SELECT ... FROM enrollments WHERE student_id = ...`).
    2) Каскадное удаление студента (`DELETE FROM students WHERE id = ...`), так как базе нужно быстро найти связанные строки в `enrollments` для `ON DELETE CASCADE`.

## Transaction

Scenario: enroll a new student in a course — two inserts in one transaction.

- **The second insert failed:** Первая команда `INSERT INTO students` выполнилась внутри транзакции (`course_catalog=*>`). Вторая команда `INSERT INTO enrollments` с несуществующим курсом `'no-such-course'` вызвала ошибку внешнего ключа `enrollments_course_id_fkey`, переведя транзакцию в состояние aborted (`course_catalog=!>`), где все последующие команды отклоняются до `ROLLBACK`. После `ROLLBACK;` первая вставка студента также отменилась (`count = 0`).
- **Window B saw:** До `COMMIT` окно B видело `0` строк (`count = 0`) благодаря уровню изоляции `read committed`. Сразу после `COMMIT` в окне A окно B увидело `1` строку (`count = 1`).
- **What would have happened without a transaction if the second insert had failed:** Без транзакции первая вставка студента сохранилась бы навсегда, а вторая упала бы с ошибкой — в базе остался бы студент без записи на курс («половина операции»).

## Self-review against the checklist

| What to check | Result |
|---------------|--------|
| Keys | **Yes.** У всех таблиц есть `PRIMARY KEY`, все связи защищены `FOREIGN KEY`. |
| Types | **Yes.** Идентификаторы — `bigint`, слаги и текст — `text`, счётчики — `integer`, флаги — `boolean`, время — `timestamptz`. |
| Required values | **Yes.** Все обязательные столбцы имеют `NOT NULL`. |
| Constraints | **Yes.** Доменные правила заданы через `CHECK` и `UNIQUE`, согласованы с Pydantic. |
| Deletion | **Yes.** `ON DELETE RESTRICT` на `course_id` и `ON DELETE CASCADE` на `student_id`. |
| Normalization | **Yes.** Таблицы нормализованы (3NF), дублирования данных нет. |
| Indexes and names | **Yes.** Добавлен индекс `enrollments_student_id_idx`, именование в `snake_case`. |