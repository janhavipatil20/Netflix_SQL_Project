import pandas as pd
import unicodedata
from sqlalchemy import create_engine, text

# ========= CONFIG =========
# 1. Update Path
CSV_PATH   = r"C:\Users\Lenovo\Desktop\Netflix_Project\netflix_titles.csv"

# 2. Update Password
MYSQL_USER = "root"
MYSQL_PASS = "Root123"  # <--- ENTER PASSWORD HERE
MYSQL_HOST = "localhost"
MYSQL_DB   = "netflix"

TRUNCATE_BEFORE_LOAD = True
# ==========================

def split_and_strip(cell):
    if pd.isna(cell):
        return []
    return [x.strip() for x in str(cell).split(",") if x.strip()]

def parse_duration(d):
    if pd.isna(d):
        return (None, None)
    s = str(d)
    if "min" in s:
        try:
            return (int(s.split("min")[0].strip()), None)
        except:
            return (None, None)
    if "Season" in s:
        try:
            return (None, int(s.split("Season")[0].strip()))
        except:
            return (None, None)
    return (None, None)

# --- NEW FUNCTION: The Accent Killer ---
def generate_key(text):
    """
    Converts 'Nicolás López' -> 'nicolas lopez'.
    This ensures Python and MySQL agree on duplicates.
    """
    if not text:
        return ""
    # 1. Lowercase
    text = text.lower().strip()
    # 2. Remove Accents (normalize unicode)
    text = unicodedata.normalize('NFKD', text).encode('ASCII', 'ignore').decode('utf-8')
    return text

def main():
    print("--- STARTING ETL PROCESS (FINAL) ---")
    
    # 1) READ CSV
    try:
        df = pd.read_csv(CSV_PATH)
        print(f"[ETL] Loaded CSV with {len(df)} rows")
    except FileNotFoundError:
        print("CRITICAL ERROR: CSV file not found. Check path in CONFIG.")
        return

    # 2) CLEANING
    df["date_added_clean"] = pd.to_datetime(df["date_added"], errors="coerce")
    dur = df["duration"].apply(parse_duration)
    df["duration_minutes"] = [x[0] for x in dur]
    df["season_count"]     = [x[1] for x in dur]

    # 3) PREPARE TITLES
    titles = df[[
        "show_id", "title", "type", "release_year",
        "duration_minutes", "season_count", "description",
        "date_added_clean", "rating"
    ]].rename(columns={"date_added_clean": "date_added"})

    # 4) GENRES
    all_genres = {} 
    genres_rows = []
    tg_rows = []

    for _, row in df[["show_id", "listed_in"]].iterrows():
        show_id = row["show_id"]
        for g in split_and_strip(row["listed_in"]):
            g_key = generate_key(g) # Uses new safer key
            
            if g_key not in all_genres:
                all_genres[g_key] = len(all_genres) + 1
                genres_rows.append({"genre_id": all_genres[g_key], "genre_name": g})
            tg_rows.append({"show_id": show_id, "genre_id": all_genres[g_key]})

    genres = pd.DataFrame(genres_rows)
    title_genres = pd.DataFrame(tg_rows).drop_duplicates()

    # 5) CAST
    all_cast = {}
    cast_rows = []
    tc_rows = []

    for _, row in df[["show_id", "cast"]].iterrows():
        show_id = row["show_id"]
        for c in split_and_strip(row["cast"]):
            c_key = generate_key(c)
            
            if c_key not in all_cast:
                all_cast[c_key] = len(all_cast) + 1
                cast_rows.append({"cast_id": all_cast[c_key], "name": c})
            tc_rows.append({"show_id": show_id, "cast_id": all_cast[c_key]})

    cast_members = pd.DataFrame(cast_rows)
    title_cast = pd.DataFrame(tc_rows).drop_duplicates()

    # 6) COUNTRIES
    all_countries = {}
    country_rows = []
    tco_rows = []

    for _, row in df[["show_id", "country"]].iterrows():
        show_id = row["show_id"]
        for c in split_and_strip(row["country"]):
            c_key = generate_key(c)
            
            if c_key not in all_countries:
                all_countries[c_key] = len(all_countries) + 1
                country_rows.append({"country_id": all_countries[c_key], "country_name": c})
            tco_rows.append({"show_id": show_id, "country_id": all_countries[c_key]})

    countries = pd.DataFrame(country_rows)
    title_countries = pd.DataFrame(tco_rows).drop_duplicates()

    # 7) DIRECTORS (Fixed Logic)
    all_dir = {}
    dir_rows = []
    td_rows = []

    for _, row in df[["show_id", "director"]].iterrows():
        show_id = row["show_id"]
        if pd.isna(row["director"]):
            continue
        for d in split_and_strip(row["director"]):
            d_key = generate_key(d) # This turns 'Nicolás' into 'nicolas'
            
            if d_key not in all_dir:
                all_dir[d_key] = len(all_dir) + 1
                dir_rows.append({"director_id": all_dir[d_key], "name": d})
            td_rows.append({"show_id": show_id, "director_id": all_dir[d_key]})

    directors = pd.DataFrame(dir_rows)
    title_directors = pd.DataFrame(td_rows).drop_duplicates()

    # 8) LOAD TO MYSQL
    print("[ETL] Connecting to MySQL...")
    try:
        engine_url = f"mysql+mysqlconnector://{MYSQL_USER}:{MYSQL_PASS}@{MYSQL_HOST}/{MYSQL_DB}?charset=utf8mb4"
        engine = create_engine(engine_url)

        with engine.begin() as conn:
            if TRUNCATE_BEFORE_LOAD:
                print("[ETL] Truncating tables to start fresh...")
                conn.execute(text("SET FOREIGN_KEY_CHECKS = 0"))
                tables = ["title_directors", "directors", "title_countries", "countries", 
                          "title_cast", "cast_members", "title_genres", "genres", "titles"]
                for t in tables:
                    conn.execute(text(f"TRUNCATE TABLE {t}"))
                conn.execute(text("SET FOREIGN_KEY_CHECKS = 1"))
                print("[ETL] Truncate successful.")

        print("[ETL] Inserting Data (this may take 30 seconds)...")
        
        # Load tables
        titles.to_sql("titles", con=engine, if_exists="append", index=False)
        genres.to_sql("genres", con=engine, if_exists="append", index=False)
        cast_members.to_sql("cast_members", con=engine, if_exists="append", index=False)
        countries.to_sql("countries", con=engine, if_exists="append", index=False)
        directors.to_sql("directors", con=engine, if_exists="append", index=False)
        
        title_genres.to_sql("title_genres", con=engine, if_exists="append", index=False)
        title_cast.to_sql("title_cast", con=engine, if_exists="append", index=False)
        title_countries.to_sql("title_countries", con=engine, if_exists="append", index=False)
        title_directors.to_sql("title_directors", con=engine, if_exists="append", index=False)

        print("\n[SUCCESS] All data loaded successfully! You are done.")

    except Exception as e:
        print(f"\n[ERROR] Database Load Failed: {e}")

if __name__ == "__main__":
    main()