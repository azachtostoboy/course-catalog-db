DROP TABLE IF EXISTS registrations;

CREATE TABLE registrations (
                               id            integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
                               student_name  text,
                               student_email text,
                               course_id     text,
                               course_title  text,
                               credits       integer
);

INSERT INTO registrations
(student_name, student_email, course_id, course_title, credits) VALUES
                                                                    ('Aigerim Sadykova', 'aigerim@example.com',
                                                                     'modern-frontend', 'Modern Frontend: React & Next.js', 5),
                                                                    ('Aigerim Sadykova', 'aigerim@example.com',
                                                                     'ai-integration', 'AI/LLM Integration', 5),
                                                                    ('Daniyar Bekov', 'daniyar@example.com',
                                                                     'modern-frontend', 'Modern Frontend: React & Next.js', 5),
                                                                    ('Daniyar Bekov', 'daniyar@example.com',
                                                                     'backend-fastapi', 'Backend Foundations: FastAPI', 5),
                                                                    ('Daniyar Bekov', 'daniyar@example.com',
                                                                     'ai-integration', 'AI/LLM Integration', 5),
                                                                    ('Asel Omarova', 'asel@example.com',
                                                                     'ai-integration', 'AI/LLM Integration', 5);