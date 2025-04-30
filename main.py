import requests
import psycopg2
from psycopg2.extras import execute_values
from datetime import datetime, timedelta
import os
from dotenv import load_dotenv

load_dotenv()

# Configuración
API_TOKEN = os.getenv("SAMSARA_API_TOKEN") or os.getenv("SAMSARA_API_KEY")
DATABASE_URL = os.getenv("POSTGRES_CONN_STRING") or os.getenv("DATABASE_URL")
HEADERS = {
    "Authorization": f"Bearer {API_TOKEN}"
}
VEHICLE_IDS = []  # Llena esta lista con los IDs de tus vehículos
DATA_TYPE = "fuelPercents"
BASE_URL = "https://api.samsara.com/fleet/vehicles/stats/history"

def obtener_capacidades_de_tanques():
    conn = psycopg2.connect(DATABASE_URL)
    cur = conn.cursor()
    cur.execute("SELECT id, tank_capacity_liters FROM vehicles")
    capacidades = {row[0]: float(row[1]) for row in cur.fetchall()}
    cur.close()
    conn.close()
    return capacidades

def sync_vehicles():
    print("Sincronizando catálogo de vehículos...")

    url = "https://api.samsara.com/fleet/vehicles"
    page_url = url
    conn = psycopg2.connect(DATABASE_URL)
    cur = conn.cursor()

    while page_url:
        response = requests.get(page_url, headers=HEADERS)
        if response.status_code != 200:
            print(f"Error al sincronizar vehículos: {response.status_code} - {response.text}")
            break

        data = response.json()
        for vehicle in data.get("data", []):
            cur.execute("""
                INSERT INTO vehicles (id, vin, name, license_plate, make, model, year)
                VALUES (%s, %s, %s, %s, %s, %s, %s)
                ON CONFLICT (id) DO UPDATE SET
                    vin = EXCLUDED.vin,
                    name = EXCLUDED.name,
                    license_plate = EXCLUDED.license_plate,
                    make = EXCLUDED.make,
                    model = EXCLUDED.model,
                    year = EXCLUDED.year;
            """, (
                vehicle.get("id"),
                vehicle.get("vin"),
                vehicle.get("name"),
                vehicle.get("licensePlate"),
                vehicle.get("make"),
                vehicle.get("model"),
                int(vehicle.get("year")) if vehicle.get("year") else None
            ))

        page_url = data.get("pagination", {}).get("endCursor")
        if page_url:
            page_url = f"{url}?after={page_url}"

    conn.commit()
    cur.close()
    conn.close()

def get_last_sync_time(cursor, vehicle_id, data_type):
    cursor.execute(
        "SELECT last_synced_at FROM vehicle_data_sync WHERE vehicle_id = %s AND data_type = %s",
        (vehicle_id, data_type)
    )
    result = cursor.fetchone()
    return result[0] if result else (datetime.utcnow() - timedelta(hours=1))

def update_sync_time(cursor, vehicle_id, data_type, new_time):
    cursor.execute("""
        INSERT INTO vehicle_data_sync (vehicle_id, data_type, last_synced_at)
        VALUES (%s, %s, %s)
        ON CONFLICT (vehicle_id, data_type)
        DO UPDATE SET last_synced_at = EXCLUDED.last_synced_at;
    """, (vehicle_id, data_type, new_time))

def fetch_and_store_data():
    conn = psycopg2.connect(DATABASE_URL)
    cur = conn.cursor()
    capacidades = obtener_capacidades_de_tanques()

    for vehicle_id in VEHICLE_IDS:
        start_time = get_last_sync_time(cur, vehicle_id, DATA_TYPE).isoformat() + "Z"
        end_time = datetime.utcnow().isoformat() + "Z"

        params = {
            "vehicleIds": vehicle_id,
            "types": DATA_TYPE,
            "startTime": start_time,
            "endTime": end_time,
            "decorations": "gps"
        }

        response = requests.get(BASE_URL, headers=HEADERS, params=params)
        if response.status_code != 200:
            print(f"Error con vehículo {vehicle_id}: {response.status_code} - {response.text}")
            continue

        data = response.json()
        entries = []
        prev_fuel = None

        for stat in data.get("data", []):
            fuel_data = stat.get(DATA_TYPE, [])
            for point in fuel_data:
                fuel = point.get("value")
                time = point.get("time")
                gps = point.get("gps", {})
                lat = gps.get("lat")
                lon = gps.get("lon")

                is_refuel = False
                refueled_liters = None
                refueled_percent = None
                if prev_fuel is not None and fuel > prev_fuel:
                    is_refuel = True
                    refueled_percent = round(fuel - prev_fuel, 2)
                    capacidad = capacidades.get(vehicle_id, 200)  # fallback a 200 L si no se encuentra
                    refueled_liters = round((refueled_percent / 100.0) * capacidad, 2)


                entries.append((
                    vehicle_id,
                    time,
                    fuel,
                    None, None, None,
                    lat,
                    lon,
                    refueled_liters,
                    refueled_percent,
                    is_refuel
                ))

                prev_fuel = fuel

        if entries:
            execute_values(cur, """
                INSERT INTO vehicle_fuel_stats (
                    vehicle_id, timestamp, fuel_percent,
                    fuel_consumed_liters, distance_meters, efficiency_km_l,
                    latitude, longitude, refueled_liters, refueled_percent,
                    is_refuel_event
                ) VALUES %s
                ON CONFLICT (vehicle_id, timestamp) DO NOTHING
            """, entries)

            update_sync_time(cur, vehicle_id, DATA_TYPE, datetime.utcnow())

    conn.commit()
    cur.close()
    conn.close()

if __name__ == "__main__":
    sync_vehicles()
    fetch_and_store_data()
