# samsara_sync/db/database.py

import psycopg2
from psycopg2.extras import execute_values
import os
from dotenv import load_dotenv

load_dotenv()

DATABASE_URL = os.getenv("DATABASE_URL")

def get_connection():
    return psycopg2.connect(DATABASE_URL)

def get_vehicle_capacities():
    with get_connection() as conn:
        with conn.cursor() as cur:
            cur.execute("SELECT id, tank_capacity_liters FROM vehicles")
            return {str(row[0]): float(row[1]) for row in cur.fetchall()}

def get_last_sync_times(data_type):
    with get_connection() as conn:
        with conn.cursor() as cur:
            cur.execute("SELECT vehicle_id, last_synced_at FROM vehicle_data_sync WHERE data_type = %s", (data_type,))
            return {str(row[0]): row[1] for row in cur.fetchall()}

def update_sync_time(cur, vehicle_id, data_type, new_time):
    cur.execute("""
        INSERT INTO vehicle_data_sync (vehicle_id, data_type, last_synced_at)
        VALUES (%s, %s, %s)
        ON CONFLICT (vehicle_id, data_type)
        DO UPDATE SET last_synced_at = EXCLUDED.last_synced_at;
    """, (vehicle_id, data_type, new_time))
