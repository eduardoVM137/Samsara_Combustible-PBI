import os
import requests
from datetime import datetime, timedelta, timezone
from dotenv import load_dotenv

from db.database import get_connection, update_sync_time
from utils.logger import logger

load_dotenv()
API_TOKEN = os.getenv("SAMSARA_API_TOKEN")
HEADERS = {"Authorization": f"Bearer {API_TOKEN}"}
BASE_URL = "https://api.samsara.com/fleet/vehicles/stats/history"
DATA_TYPE = "fuelPercents"

def sync_vehicle_catalog():
    logger.info("Sincronizando catálogo de vehículos...")
    print("[CATALOGO] Iniciando sincronización de vehículos...")
    url = "https://api.samsara.com/fleet/vehicles"
    page_url = url

    with get_connection() as conn:
        with conn.cursor() as cur:
            while page_url:
                response = requests.get(page_url, headers=HEADERS)
                if response.status_code != 200:
                    logger.error(f"Error: {response.status_code} - {response.text}")
                    print("[ERROR] No se pudo sincronizar vehículos.")
                    break

                data = response.json()
                for vehicle in data.get("data", []):
                    vin = vehicle.get("vin")
                    if not vin:
                        continue

                    cur.execute("SELECT 1 FROM vehicles WHERE vin = %s", (vin,))
                    if cur.fetchone():
                        continue

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
                    print(f"[CATALOGO] Insertado: {vin} - {vehicle.get('name')}")

                next_cursor = data.get("pagination", {}).get("endCursor")
                page_url = f"{url}?after={next_cursor}" if next_cursor else None

        conn.commit()
    logger.info("Catálogo sincronizado.")
    print("[CATALOGO] Sincronización finalizada.")

def fetch_fuel_stats(capacidades, sync_data):
    print("[SYNC] Iniciando sincronización reducida (una sola petición)...")
    logger.info("Descargando datos históricos (una sola llamada)...")

    vehicle_ids = list(capacidades.keys())
    default_start = datetime.now(timezone.utc) - timedelta(hours=1)

    with get_connection() as conn:
        with conn.cursor() as cur:
            start_time = min(sync_data.get(vid, default_start).replace(tzinfo=timezone.utc) for vid in vehicle_ids)
            start_str = start_time.isoformat().replace("+00:00", "Z")
            end_str = datetime.now(timezone.utc).isoformat().replace("+00:00", "Z")

            url = f"{BASE_URL}?vehicleIds={','.join(vehicle_ids)}&startTime={start_str}&endTime={end_str}&types={DATA_TYPE}&decorations=gps"
            try:
                response = requests.get(url, headers=HEADERS)
                if response.status_code != 200:
                    print(f"[ERROR] Petición API falló: {response.status_code} - {response.text}")
                    logger.error(f"Error API: {response.status_code} - {response.text}")
                    return

                stats = response.json().get("data", [])
                print(f"[API] Datos recibidos: {len(stats)} vehículos")

                for stat in stats:
                    process_stat_data(stat, capacidades, cur)

                conn.commit()
                print("[SYNC] Datos insertados exitosamente.")
            except Exception as e:
                print(f"[ERROR] Fallo en la petición o procesamiento: {e}")
                logger.exception("Error durante la sincronización reducida")
                
def process_stat_data(stat, capacidades, cur):
    vehicle_id = str(stat.get("id"))
    if not vehicle_id:
        print("[AVISO] Entrada sin ID de vehículo:", stat)
        return

    capacidad = capacidades.get(vehicle_id, 200)
    fuel_data = stat.get("fuelPercents", [])
    print(f"[PROCESO] Procesando {vehicle_id} con {len(fuel_data)} registros")

    last_percent = None
    registros = 0

    for entry in fuel_data:
        percent = entry.get("value")
        timestamp = entry.get("time")

        decorations = entry.get("decorations", {})
        gps = decorations.get("gps", {})
        lat = gps.get("latitude")
        lon = gps.get("longitude")

        if last_percent is not None and percent is not None:
            diff = round(percent - last_percent, 2)
            litros = round(abs(diff) * capacidad / 100, 2)
            is_refuel = diff > 0
            is_consumo = diff < 0

            if litros > 0.01:
                try:
                    cur.execute("""
                        INSERT INTO vehicle_fuel_stats (
                            vehicle_id, fuel_percent, refueled_liters, refueled_percent,
                            fuel_consumed_liters, is_refuel_event, latitude, longitude, timestamp
                        ) VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s)
                        ON CONFLICT (vehicle_id, timestamp) DO NOTHING
                    """, (
                        vehicle_id,
                        percent,
                        litros if is_refuel else 0,
                        diff if is_refuel else 0,
                        litros if is_consumo else 0,
                        is_refuel,
                        lat if lat is not None else None,
                        lon if lon is not None else None,
                        timestamp
                    ))
                    registros += 1
                    print(f"[INSERT] {vehicle_id} - {'Refuel' if is_refuel else 'Consumo'}: {litros} L @ {timestamp}")
                except Exception as e:
                    print(f"[ERROR] Fallo al insertar en BD: {e}")
                    logger.exception("Error insertando en la base de datos")

        last_percent = percent

    print(f"[FINAL] {vehicle_id}: {registros} registros insertados")

    try:
        update_sync_time(cur, vehicle_id, "fuelPercents", datetime.now(timezone.utc))
    except Exception as e:
        print(f"[ERROR] Fallo al actualizar sincronización: {e}")
        logger.exception("Error actualizando tiempo de sync")

# def process_stat_data(stat, capacidades, cur):
#     vehicle_info = stat.get("vehicle")
#     if not vehicle_info:
#         print("[AVISO] Objeto 'vehicle' no presente en los datos.")
#         return

#     vehicle_id = str(vehicle_info["id"])
#     capacidad = capacidades.get(vehicle_id, 200)
#     fuel_data = stat.get("fuelPercents", [])
#     print(f"[PROCESO] Procesando {vehicle_id} con {len(fuel_data)} registros")

#     last_percent = None
#     registros = 0

#     for entry in fuel_data:
#         percent = entry.get("value")
#         timestamp = entry.get("time")
#         gps = entry.get("gps", {})
#         lat = gps.get("latitude")
#         lon = gps.get("longitude")

#         if last_percent is not None:
#             diff = round(percent - last_percent, 2)
#             litros = round(abs(diff) * capacidad / 100, 2)
#             is_refuel = diff > 0
#             is_consumo = diff < 0

#             if litros > 0.01:
#                 try:
#                     cur.execute("""
#                         INSERT INTO vehicle_fuel_stats (
#                             vehicle_id, fuel_percent, refueled_liters, refueled_percent,
#                             fuel_consumed_liters, is_refuel_event, latitude, longitude, timestamp
#                         ) VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s)
#                         ON CONFLICT (vehicle_id, timestamp) DO NOTHING
#                     """, (
#                         vehicle_id,
#                         percent,
#                         litros if is_refuel else 0,
#                         diff if is_refuel else 0,
#                         litros if is_consumo else 0,
#                         is_refuel,
#                         lat if lat is not None else None,
#                         lon if lon is not None else None,
#                         timestamp
#                     ))
#                     registros += 1
#                     print(f"[INSERT] {vehicle_id} - {'Refuel' if is_refuel else 'Consumo'}: {litros} L @ {timestamp}")
#                 except Exception as e:
#                     print(f"[ERROR] Fallo al insertar en BD: {e}")
#                     logger.exception("Error insertando en la base de datos")

#         last_percent = percent

#     print(f"[FINAL] {vehicle_id}: {registros} registros insertados")
#     try:
#         update_sync_time(cur, vehicle_id, DATA_TYPE, datetime.now(timezone.utc))
#     except Exception as e:
#         print(f"[ERROR] Fallo al actualizar sincronización: {e}")
#         logger.exception("Error actualizando tiempo de sync")
