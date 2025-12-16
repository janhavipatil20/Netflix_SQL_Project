-- SECTION 1: DATABASE SCHEMA (The Structure)

CREATE DATABASE IF NOT EXISTS netflix;
USE netflix;

-- 1. Main Content Table
CREATE TABLE titles (
    show_id INT PRIMARY KEY,
    type VARCHAR(50),              -- 'Movie' or 'TV Show'
    title VARCHAR(255) NOT NULL,
    director VARCHAR(255),         -- Primary director
    country VARCHAR(255),          -- Primary country
    date_added DATE,
    release_year INT,
    rating VARCHAR(50),
    duration_minutes INT,          -- Cleaned numeric duration
    season_count INT,              -- Cleaned numeric season count
    description TEXT
);

-- 2. Reference Tables (Normalization)
-- Genres
CREATE TABLE genres (
    genre_id INT AUTO_INCREMENT PRIMARY KEY,
    genre_name VARCHAR(100) UNIQUE
);

CREATE TABLE title_genres (
    show_id INT,
    genre_id INT,
    PRIMARY KEY (show_id, genre_id),
    FOREIGN KEY (show_id) REFERENCES titles(show_id),
    FOREIGN KEY (genre_id) REFERENCES genres(genre_id)
);

-- Directors
CREATE TABLE directors (
    director_id INT AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(255) UNIQUE
);

CREATE TABLE title_directors (
    show_id INT,
    director_id INT,
    PRIMARY KEY (show_id, director_id),
    FOREIGN KEY (show_id) REFERENCES titles(show_id),
    FOREIGN KEY (director_id) REFERENCES directors(director_id)
);

-- Cast
CREATE TABLE cast_members (
    cast_id INT AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(255) UNIQUE
);

CREATE TABLE title_cast (
    show_id INT,
    cast_id INT,
    PRIMARY KEY (show_id, cast_id),
    FOREIGN KEY (show_id) REFERENCES titles(show_id),
    FOREIGN KEY (cast_id) REFERENCES cast_members(cast_id)
);

-- Countries
CREATE TABLE countries (
    country_id INT AUTO_INCREMENT PRIMARY KEY,
    country_name VARCHAR(100) UNIQUE
);

CREATE TABLE title_countries (
    show_id INT,
    country_id INT,
    PRIMARY KEY (show_id, country_id),
    FOREIGN KEY (show_id) REFERENCES titles(show_id),
    FOREIGN KEY (country_id) REFERENCES countries(country_id)
);

-- 3. User Data Tables
CREATE TABLE users (
    user_id INT AUTO_INCREMENT PRIMARY KEY,
    join_date DATE,
    country VARCHAR(50),
    age_group VARCHAR(20)
);

CREATE TABLE view_history (
    view_id INT AUTO_INCREMENT PRIMARY KEY,
    user_id INT,
    show_id INT,
    watched_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    duration_watched_min INT,
    completed BOOLEAN, -- 1 if they finished the movie, 0 if not
    FOREIGN KEY (user_id) REFERENCES users(user_id),
    FOREIGN KEY (show_id) REFERENCES titles(show_id)
);

-- 4. Recommendation Engine Tables
-- Stores pre-calculated similarity scores (Content-Based Filtering)
CREATE TABLE title_similarity (
    title_a INT,
    title_b INT,
    score FLOAT,           -- Strength of similarity
    method VARCHAR(50),    -- 'Genre-Based'
    generated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (title_a, title_b),
    FOREIGN KEY (title_a) REFERENCES titles(show_id),
    FOREIGN KEY (title_b) REFERENCES titles(show_id)
);

-- Stores the final Top 10 recommendations for each user
CREATE TABLE recommendations (
    rec_id INT AUTO_INCREMENT PRIMARY KEY,
    user_id INT,
    title_id INT,
    score FLOAT,           -- The similarity score used for ranking
    generated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(user_id),
    FOREIGN KEY (title_id) REFERENCES titles(show_id)
);


-- SECTION 2: 15 SIMPLE QUERIES 

-- 1. Total Content Count
SELECT COUNT(*) AS total_content FROM titles;

-- 2. Content Type Breakdown
SELECT type, COUNT(*) AS count 
FROM titles 
GROUP BY type;

-- 3. Top 5 Genres
SELECT g.genre_name, COUNT(*) AS total_titles
FROM genres g
JOIN title_genres tg ON g.genre_id = tg.genre_id
GROUP BY g.genre_name
ORDER BY total_titles DESC
LIMIT 5;

-- 4. Recent Releases (Last 3 Years)
SELECT title, release_year 
FROM titles 
WHERE release_year >= 2022
ORDER BY release_year DESC
LIMIT 5;

-- 5. Indian Content
SELECT t.title, t.release_year
FROM titles t
JOIN title_countries tc ON t.show_id = tc.show_id
JOIN countries c ON tc.country_id = c.country_id
WHERE c.country_name = 'India'
LIMIT 10;

-- 6. Director Search ('Nolan')
SELECT t.title, d.name AS director
FROM titles t
JOIN title_directors td ON t.show_id = td.show_id
JOIN directors d ON td.director_id = d.director_id
WHERE d.name LIKE '%Nolan%';

-- 7. Longest Movies
SELECT title, duration_minutes 
FROM titles 
WHERE type = 'Movie' 
ORDER BY duration_minutes DESC 
LIMIT 5;

-- 8. Long-Running TV Shows
SELECT title, season_count 
FROM titles 
WHERE type = 'TV Show' AND season_count > 5
ORDER BY season_count DESC;

-- 9. Rating Distribution
SELECT rating, COUNT(*) AS total
FROM titles 
GROUP BY rating 
ORDER BY total DESC;

-- 10. Keyword Search ('Space' or 'Alien')
SELECT title, description 
FROM titles 
WHERE description LIKE '%space%' OR description LIKE '%alien%';

-- 11. User Demographics
SELECT country, COUNT(*) AS total_users
FROM users 
GROUP BY country 
ORDER BY total_users DESC;

-- 12. Active View Count
SELECT COUNT(*) AS total_views FROM view_history;

-- 13. Titles Added in 2021
SELECT COUNT(*) AS added_in_2021
FROM titles
WHERE YEAR(date_added) = 2021;

-- 14. Cast List for 'Inception'
SELECT c.name 
FROM cast_members c
JOIN title_cast tc ON c.cast_id = tc.cast_id
JOIN titles t ON tc.show_id = t.show_id
WHERE t.title = 'Inception';

-- 15. Oldest Content
SELECT title, release_year 
FROM titles 
WHERE type = 'Movie' 
ORDER BY release_year ASC 
LIMIT 5;


-- SECTION 3: 10 COMPLEX QUERIES 

-- 1. The Core Similarity Engine (Reading Pre-Computed Scores)
SELECT 
    t1.title AS Movie_A, 
    t2.title AS Movie_B, 
    ts.score AS Shared_Genres
FROM title_similarity ts
JOIN titles t1 ON ts.title_a = t1.show_id
JOIN titles t2 ON ts.title_b = t2.show_id
ORDER BY ts.score DESC
LIMIT 10;

-- 2. Recommendation Generator (CTE + Window Function)
WITH UserHistory AS (
    SELECT show_id 
    FROM view_history 
    WHERE user_id = 1 
),
PotentialRecs AS ( 
    SELECT 
       ts.title_b as Rec_Show_ID,
       SUM(ts.score) as Total_Score
    FROM title_similarity ts
    JOIN UserHistory uh ON ts.title_a = uh.show_id
    WHERE ts.title_b NOT IN (SELECT show_id FROM UserHistory)
    GROUP BY ts.title_b
) 
SELECT 
 t.title, 
 pr.Total_Score
FROM PotentialRecs pr
JOIN titles t ON pr.Rec_Show_ID = t.show_id
ORDER BY pr.Total_Score DESC
LIMIT 5;

-- 3. Binge-Watcher Analysis (Aggregation & Join)
SELECT 
    u.user_id, 
    u.country,
    SUM(vh.duration_watched_min) AS Total_Minutes_Watched
FROM users u
JOIN view_history vh ON u.user_id = vh.user_id
GROUP BY u.user_id, u.country
ORDER BY Total_Minutes_Watched DESC
LIMIT 5;

-- 4. Global Content Popularity (Multi-Table Join)
SELECT 
    g.genre_name, 
    COUNT(*) AS Views
FROM view_history vh
JOIN users u ON vh.user_id = u.user_id
JOIN title_genres tg ON vh.show_id = tg.show_id
JOIN genres g ON tg.genre_id = g.genre_id
WHERE u.country = 'USA'
GROUP BY g.genre_name
ORDER BY Views DESC
LIMIT 1;

-- 5. Completion Rate by Type (Case Logic)
SELECT 
    t.type,
    COUNT(*) AS Total_Views,
    SUM(CASE WHEN vh.completed = 1 THEN 1 ELSE 0 END) AS Completed_Views,
    ROUND((SUM(CASE WHEN vh.completed = 1 THEN 1 ELSE 0 END) / COUNT(*)) * 100, 2) AS Completion_Rate
FROM view_history vh
JOIN titles t ON vh.show_id = t.show_id
GROUP BY t.type;

-- 6. Director-Actor Collaboration (Group By & Having)
SELECT 
    d.name AS Director, 
    c.name AS Actor, 
    COUNT(*) AS Projects_Together
FROM title_directors td
JOIN title_cast tc ON td.show_id = tc.show_id
JOIN directors d ON td.director_id = d.director_id
JOIN cast_members c ON tc.cast_id = c.cast_id
GROUP BY d.name, c.name
HAVING Projects_Together >= 2
ORDER BY Projects_Together DESC
LIMIT 5;

-- 7. Cold Start / Zero Views (Left Join IS NULL)
SELECT t.title 
FROM titles t
LEFT JOIN view_history vh ON t.show_id = vh.show_id
WHERE vh.view_id IS NULL
LIMIT 10;

-- 8. Regional Exclusivity (Subquery)
SELECT t.title 
FROM titles t
JOIN title_countries tc1 ON t.show_id = tc1.show_id
JOIN countries c1 ON tc1.country_id = c1.country_id AND c1.country_name = 'India'
WHERE t.show_id NOT IN (
    SELECT t2.show_id 
    FROM titles t2
    JOIN title_countries tc2 ON t2.show_id = tc2.show_id
    JOIN countries c2 ON tc2.country_id = c2.country_id AND c2.country_name = 'USA'
)
LIMIT 10;

-- 9. The "Golden Year" (Window Function)
SELECT release_year, Avg_Duration 
FROM (
    SELECT 
        release_year, 
        AVG(duration_minutes) AS Avg_Duration,
        RANK() OVER (ORDER BY AVG(duration_minutes) DESC) as rnk
    FROM titles 
    WHERE type = 'Movie'
    GROUP BY release_year
) temp
WHERE rnk = 1;

-- 10. Churn Risk Analysis (Date Arithmetic)
SELECT 
    u.user_id, 
    MAX(vh.watched_at) as Last_Seen
FROM users u
JOIN view_history vh ON u.user_id = vh.user_id
GROUP BY u.user_id
HAVING MAX(vh.watched_at) < DATE_SUB(NOW(), INTERVAL 30 DAY);


