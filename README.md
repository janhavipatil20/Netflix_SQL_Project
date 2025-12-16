# Netflix Recommendation System & SQL Analytics Project

## 📌 Project Overview
This project demonstrates a full-stack data engineering solution for a Netflix-style recommendation system. It involves analyzing a dataset of 8,000+ movies and TV shows to build a normalized Relational Database (3NF), a Python-based ETL pipeline, and a content-based recommendation engine using SQL.

## 🛠️ Tech Stack
* **Database:** MySQL (Relational Schema in 3NF)
* **Language:** Python (Pandas, SQLAlchemy)
* **SQL Skills:** Complex Joins, CTEs, Window Functions, Views, Normalization (1NF/2NF/3NF)

## 📂 Project Structure
1.  **Normalization:** Converted raw CSV data into a 3NF schema (Titles, Genres, Directors, Users, History).
2.  **ETL Pipeline:** Built a Python script (`netflix_etl.py`) to clean nulls, split comma-separated values, and load data into MySQL.
3.  **Recommendation Engine:** Designed a SQL-based algorithm to suggest movies based on shared genres and user history.

## 📊 Key Insights
* **Top Genre:** International Movies
* **Most Content Produced:** United States & India
* **Binge-Watching Trends:** Analyzed via mock user viewing history tables.

## 🚀 How to Run
1.  Install dependencies: `pip install -r requirements.txt`
2.  Set up your MySQL credentials in `netflix_etl.py`.
3.  Run the script: `python netflix_etl.py`
4.  Open `analysis_queries.sql` in MySQL Workbench to explore the insights.
