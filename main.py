import requests
import psycopg2
from psycopg2.extras import execute_values
from datetime import datetime, timedelta
import os
from dotenv import load_dotenv

from datetime import datetime, timedelta, timezone 
load_dotenv()

# Configuración
API_TOKEN = os.getenv("SAMSARA_API_TOKEN") or os.getenv("SAMSARA_API_KEY")
DATABASE_URL = os.getenv("POSTGRES_CONN_STRING") or os.getenv("DATABASE_URL")
HEADERS = {
    "Authorization": f"Bearer {API_TOKEN}"
}
VEHICLE_IDS = []  # Llena esta lista con los IDs de tus vehiculos
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
            vin = vehicle.get("vin")
            if not vin:
                continue  # ignora vehículos sin VIN

            # Verificar si ya existe el VIN antes de insertar
            cur.execute("SELECT 1 FROM vehicles WHERE vin = %s", (vin,))
            existe = cur.fetchone()

            if not existe:
                cur.execute("""
                    INSERT INTO vehicles (id, vin, name, license_plate, make, model, year)
                    VALUES (%s, %s, %s, %s, %s, %s, %s)
                """, (
                    vehicle.get("id"),
                    vin,
                    vehicle.get("name"),
                    vehicle.get("licensePlate"),
                    vehicle.get("make"),
                    vehicle.get("model"),
                    int(vehicle.get("year")) if vehicle.get("year") else None
                ))
                print(f"Insertado: {vin} - {vehicle.get('name')}")

        page_url = data.get("pagination", {}).get("endCursor")
        if page_url:
            page_url = f"{url}?after={page_url}"

    conn.commit()
    cur.close()
    conn.close()
    print("Catálogo de vehículos sincronizado (solo nuevos insertados).")
 

def get_last_sync_time(cursor, vehicle_id, data_type):
    cursor.execute(
        "SELECT last_synced_at FROM vehicle_data_sync WHERE vehicle_id = %s AND data_type = %s",
        (vehicle_id, data_type)
    )
    result = cursor.fetchone()
 
    return result[0] if result else (datetime.now(timezone.utc) - timedelta(hours=1))

def update_sync_time(cursor, vehicle_id, data_type, new_time):
    cursor.execute("""
        INSERT INTO vehicle_data_sync (vehicle_id, data_type, last_synced_at)
        VALUES (%s, %s, %s)
        ON CONFLICT (vehicle_id, data_type)
        DO UPDATE SET last_synced_at = EXCLUDED.last_synced_at;
    """, (vehicle_id, data_type, new_time))

def fetch_and_store_data():
    print("[INFO] Sincronizando datos históricos de combustible...")

    conn = psycopg2.connect(DATABASE_URL)
    cur = conn.cursor()

    # Obtener capacidades de tanque
    cur.execute("SELECT id, tank_capacity_liters FROM vehicles")
    capacidades = {str(row[0]): float(row[1]) for row in cur.fetchall()}

    for vehicle_id in capacidades.keys():
        last_sync = get_last_sync_time(cur, vehicle_id, DATA_TYPE)
        start_time = last_sync.replace(tzinfo=timezone.utc).isoformat().replace("+00:00", "Z")
        end_time = datetime.now(timezone.utc).isoformat().replace("+00:00", "Z")

        print(f"[INFO] [{vehicle_id}] Descargando datos desde {start_time} hasta {end_time}...")

        url = f"{BASE_URL}?vehicleIds={vehicle_id}&startTime={start_time}&endTime={end_time}&types=fuelPercents&decorations=gps"
        response = requests.get(url, headers=HEADERS)

        if response.status_code != 200:
            print(f"[ERROR] {response.status_code} - {response.text}")
            continue

        stats = response.json().get("data", [])
        fuel_data = stats[0]["fuelPercents"] if stats and "fuelPercents" in stats[0] else []

        last_percent = None
        rows_to_insert = []

        for entry in fuel_data:
            fuel_percent = entry.get("value")
            timestamp = entry.get("time")
            gps = entry.get("gps", {})
            lat = gps.get("latitude")
            lon = gps.get("longitude")

            if last_percent is not None:
                diff = round(fuel_percent - last_percent, 2)
                litros = round(abs(diff) * capacidades.get(vehicle_id, 200) / 100, 2)
                is_refuel = diff > 0
                is_consumo = diff < 0

                if litros > 0.01:  # Solo eventos significativos
                    rows_to_insert.append((
                        vehicle_id,
                        fuel_percent,
                        litros if is_refuel else 0,
                        diff if is_refuel else 0,
                        litros if is_consumo else 0,
                        is_refuel,
                        lat,
                        lon,
                        timestamp
                    ))

            last_percent = fuel_percent

        if rows_to_insert:
            execute_values(cur, """
                INSERT INTO vehicle_fuel_stats (
                    vehicle_id, fuel_percent, refueled_liters, refueled_percent,
                    fuel_consumed_liters, is_refuel_event,
                    latitude, longitude, timestamp
                ) VALUES %s
                ON CONFLICT (vehicle_id, timestamp) DO NOTHING
            """, rows_to_insert)

            print(f"[OK] {len(rows_to_insert)} registros insertados para unidad {vehicle_id}")

        update_sync_time(cur, vehicle_id, DATA_TYPE, datetime.now(timezone.utc))

    conn.commit()
    cur.close()
    conn.close()
    print("[OK] Sincronización de datos finalizada.")
    print("[INFO] Sincronizando datos históricos de combustible...")

    conn = psycopg2.connect(DATABASE_URL)
    cur = conn.cursor()

    # Obtener capacidades de tanque
    cur.execute("SELECT id, tank_capacity_liters FROM vehicles")
    capacidades = {str(row[0]): float(row[1]) for row in cur.fetchall()}

    for vehicle_id in capacidades.keys():
        last_sync = get_last_sync_time(cur, vehicle_id, DATA_TYPE)
        start_time = last_sync.isoformat().replace("+00:00", "Z") if last_sync.tzinfo else last_sync.replace(tzinfo=timezone.utc).isoformat().replace("+00:00", "Z")
        end_time = datetime.now(timezone.utc).isoformat().replace("+00:00", "Z")

        print(f"[INFO] [{vehicle_id}] Descargando datos desde {start_time} hasta {end_time}...")

        url = f"{BASE_URL}?vehicleIds={vehicle_id}&startTime={start_time}&endTime={end_time}&types=fuelPercents&decorations=gps"
        response = requests.get(url, headers=HEADERS)

        if response.status_code != 200:
            print(f"[ERROR] {response.status_code} - {response.text}")
            continue

        stats = response.json().get("data", [])
        fuel_data = stats[0]["fuelPercents"] if stats and "fuelPercents" in stats[0] else []

        last_percent = None
        last_timestamp = None
        for entry in fuel_data:
            fuel_percent = entry.get("value")
            timestamp = entry.get("time")
            gps = entry.get("gps", {})
            lat = gps.get("latitude")
            lon = gps.get("longitude")

            if last_percent is not None:
                diff = round(fuel_percent - last_percent, 2)
                litros = round(abs(diff) * capacidades.get(vehicle_id, 200) / 100, 2)
                is_refuel = diff > 0
                is_consumo = diff < 0

                if litros > 0.01:
                    cur.execute("""
                        INSERT INTO vehicle_fuel_stats (
                            vehicle_id, fuel_percent, refueled_liters, refueled_percent,
                            fuel_consumed_liters, is_refuel_event,
                            latitude, longitude, timestamp
                        )
                        VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s)
                        ON CONFLICT (vehicle_id, timestamp) DO NOTHING
                    """, (
                        vehicle_id,
                        fuel_percent,
                        litros if is_refuel else 0,
                        diff if is_refuel else 0,
                        litros if is_consumo else 0,
                        is_refuel,
                        lat,
                        lon,
                        timestamp
                    ))

            last_percent = fuel_percent
            last_timestamp = timestamp

        update_sync_time(cur, vehicle_id, DATA_TYPE, datetime.now(timezone.utc))

    conn.commit()
    cur.close()
    conn.close()
    print("[OK] Datos históricos insertados en vehicle_fuel_stats.")




if __name__ == "__main__":
    sync_vehicles()
    fetch_and_store_data()
