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
from datetime import datetime, timedelta, timezone

def fetch_and_store_data():
    print("[INFO] Sincronizando datos históricos de combustible...")

    conn = psycopg2.connect(DATABASE_URL)
    cur = conn.cursor()

    # Obtener capacidades por unidad
    cur.execute("SELECT id, tank_capacity_liters FROM vehicles")
    capacidades = {str(row[0]): float(row[1]) for row in cur.fetchall()}

    # Obtener sincronización por unidad
    cur.execute("SELECT vehicle_id, last_synced_at FROM vehicle_data_sync WHERE data_type = %s", (DATA_TYPE,))
    sync_data = {row[0]: row[1] for row in cur.fetchall()}

    # Tiempo por default si no hay registro
    default_start = datetime.now(timezone.utc) - timedelta(hours=1)

    vehicle_ids = list(capacidades.keys())
    vehicle_ids_str = ",".join(vehicle_ids)

    start_time = min(sync_data.get(v_id, default_start) for v_id in vehicle_ids)
    start_time_str = start_time.replace(tzinfo=timezone.utc).isoformat().replace("+00:00", "Z")
    end_time_str = datetime.now(timezone.utc).isoformat().replace("+00:00", "Z")

    print(f"[INFO] Descargando datos desde {start_time_str} hasta {end_time_str} para {len(vehicle_ids)} unidades...")

    url = f"{BASE_URL}?vehicleIds={vehicle_ids_str}&startTime={start_time_str}&endTime={end_time_str}&types=fuelPercents&decorations=gps"
    response = requests.get(url, headers=HEADERS)

    if response.status_code != 200:
        print(f"[ERROR] {response.status_code} - {response.text}")
        return

    stats_data = response.json().get("data", [])

    for vehicle_stat in stats_data:
        vehicle_info = vehicle_stat.get("vehicle")
        if not vehicle_info:
            continue  # Saltar si no viene el objeto vehicle

        vehicle_id = str(vehicle_info["id"])

        fuel_data = vehicle_stat.get("fuelPercents", [])
        capacidad = capacidades.get(vehicle_id, 200)
        get_last_sync_time = sync_data.get(cur,vehicle_id, default_start)

        last_percent = None

        for entry in fuel_data:
            fuel_percent = entry.get("value")
            timestamp = entry.get("time")
            gps = entry.get("gps", {})
            lat = gps.get("latitude")
            lon = gps.get("longitude")

            if last_percent is not None:
                diff = round(fuel_percent - last_percent, 2)
                litros = round(abs(diff) * capacidad / 100, 2)
                is_refuel = diff > 0
                is_consumo = diff < 0

                if litros > 0.01:
                    cur.execute("""
                        INSERT INTO vehicle_fuel_stats (
                            vehicle_id, fuel_percent, refueled_liters, refueled_percent,
                            fuel_consumed_liters, is_refuel_event, latitude, longitude, timestamp
                        ) VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s)
                        ON CONFLICT (vehicle_id, timestamp) DO NOTHING
                    """, (
                        vehicle_id,
                        fuel_percent,
                        litros if is_refuel else 0,
                        diff if is_refuel else 0,
                        litros if is_consumo else 0,
                        is_refuel,
                        lat if lat is not None else None,
                        lon if lon is not None else None,
                        timestamp
                    ))

            last_percent = fuel_percent

        update_sync_time(cur, vehicle_id, DATA_TYPE, datetime.now(timezone.utc))

    conn.commit()
    cur.close()
    conn.close()
    print("[INFO] Sincronización de datos finalizada.")
  

if __name__ == "__main__":
    sync_vehicles()
    fetch_and_store_data()
