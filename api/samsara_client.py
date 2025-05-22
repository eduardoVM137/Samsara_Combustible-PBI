# ───────────────────────────────────────────────────────────────
# Equivalencia de campos: Inglés → Español
#
# vehicle_id               → vehiculo_id
# timestamp                → fecha_hora
# fuel_percent             → porcentaje_combustible
# fuel_consumed_liters     → litros_consumidos
# refueled_liters          → litros_recargados
# refueled_percent         → porcentaje_recargado
# is_refuel_event          → es_evento_recarga
# distance_meters          → distancia_metros
# efficiency_km_l          → rendimiento_km_por_litro
# latitude / longitude     → latitud / longitud
# engineRunTimeDurationMs  → tiempo_motor_s
# engineIdleTimeDurationMs→ tiempo_ralenti_s
# fuelConsumedMl           → litros_totales
# distanceTraveledMeters   → kilometros_recorridos
# cost                     → costo_combustible_usd
# fecha                    → fecha_reporte
# ───────────────────────────────────────────────────────────────

import os
import requests
from datetime import datetime, timedelta, timezone 
from pytz import timezone as pytz_timezone
from db.database import get_connection, update_sync_time, get_vehicle_capacities, get_last_sync_times
from utils.logger import logger
 
TOKEN_API = os.getenv("SAMSARA_API_TOKEN")
CABECERAS = {"Authorization": f"Bearer {TOKEN_API}"}
URL_HISTORICO = "https://api.samsara.com/fleet/vehicles/stats/history"
URL_FUEL_ENERGY = "https://api.samsara.com/fleet/reports/vehicles/fuel-energy"
TIPO_DATO = "fuelPercents" 
from dotenv import load_dotenv 
def obtener_fecha_manual():
    load_dotenv()
    valor = os.getenv("FECHA_CONSULTA")
    return datetime.strptime(valor, "%Y-%m-%d").date() if valor else datetime.now(timezone.utc).date()

def sincronizar_catalogo_vehiculos():
    obtener_fecha_manual()
    logger.info("Sincronizando catálogo de vehículos...")
    url = "https://api.samsara.com/fleet/vehicles"
    pagina = url

    with get_connection() as conn:
        with conn.cursor() as cur:
            while pagina:
                respuesta = requests.get(pagina, headers=CABECERAS)
                if respuesta.status_code != 200:
                    logger.error(f"Error {respuesta.status_code} - {respuesta.text}")
                    break

                datos = respuesta.json()
                for vehiculo in datos.get("data", []):
                    vin = vehiculo.get("vin")
                    if not vin:
                        continue

                    cur.execute("SELECT 1 FROM vehicles WHERE vin = %s", (vin,))
                    if cur.fetchone():
                        continue

                    cur.execute("""
                        INSERT INTO vehicles (id, vin, name, license_plate, make, model, year)
                        VALUES (%s, %s, %s, %s, %s, %s, %s)
                        ON CONFLICT (id) DO NOTHING
                    """, (
                        vehiculo.get("id"),
                        vin,
                        vehiculo.get("name"),
                        vehiculo.get("licensePlate"),
                        vehiculo.get("make"),
                        vehiculo.get("model"),
                        int(vehiculo.get("year")) if vehiculo.get("year") else None
                    ))

                pagina = f"{url}?after={datos.get('pagination', {}).get('endCursor')}" if datos.get("pagination", {}).get("endCursor") else None
        conn.commit()
    logger.info("Catálogo sincronizado.")

def obtener_estadisticas_combustible(capacidades, sincronizaciones, fecha_inicio_forzada=None, fecha_fin_forzada=None):
    logger.info("Descargando datos históricos de combustible...")
    ids_vehiculos = list(capacidades.keys())

    with get_connection() as conn:
        with conn.cursor() as cur:
            # Se usa fecha manual o la más antigua registrada
            if not fecha_inicio_forzada and not fecha_fin_forzada:
                base = obtener_fecha_manual()
                fecha_inicio = f"{base.isoformat()}T00:00:00Z"
                fecha_fin = f"{base.isoformat()}T23:59:59Z"
            else:
                # En caso de que se haya forzado el rango
                fecha_inicio = fecha_inicio_forzada
                fecha_fin = fecha_fin_forzada

            url = f"{URL_HISTORICO}?vehicleIds={','.join(ids_vehiculos)}&startTime={fecha_inicio}&endTime={fecha_fin}&types={TIPO_DATO}&decorations=gps,obdOdometerMeters"
            
            try:
                respuesta = requests.get(url, headers=CABECERAS)
                if respuesta.status_code != 200:
                    logger.error(f"Error API: {respuesta.status_code} - {respuesta.text}")
                    return

                registros = respuesta.json().get("data", [])
                for registro in registros:
                    procesar_estadistica(registro, capacidades, cur)

                conn.commit()
                logger.info("Estadísticas guardadas correctamente.")
            except Exception as e:
                logger.exception("Error procesando estadísticas de combustible")



def procesar_estadistica(registro, capacidades, cur, fecha_filtro=None):
    obtener_fecha_manual()
    vehiculo_id = str(registro.get("id"))
    if not vehiculo_id:
        logger.warning("[AVISO] Entrada sin ID de vehículo: %s", registro)
        return

    capacidad = capacidades.get(vehiculo_id, 200)
    datos = registro.get("fuelPercents", [])
    logger.info("[PROCESO] %s con %d registros", vehiculo_id, len(datos))

    anterior_porcentaje = None
    registros_insertados = 0
    CAMBIO_MINIMO = 2
    UMBRAL_RECARGA = 5

    for entrada in datos:
        porcentaje = entrada.get("value")
        fecha = entrada.get("time")

        if fecha_filtro and not fecha.startswith(fecha_filtro):
            continue

        decoraciones = entrada.get("decorations", {})
        gps = decoraciones.get("gps", {})
        latitud = gps.get("latitude")
        longitud = gps.get("longitude")

        if anterior_porcentaje is not None and porcentaje is not None:
            diferencia = round(porcentaje - anterior_porcentaje, 2)

            if abs(diferencia) < CAMBIO_MINIMO:
                anterior_porcentaje = porcentaje
                continue

            litros = round(abs(diferencia) * capacidad / 100, 2)
            es_recarga = diferencia >= UMBRAL_RECARGA
            es_consumo = diferencia < 0

            if litros > 0.01:
                try:
                    cur.execute("""
                        INSERT INTO vehicle_fuel_stats (
                            vehiculo_id,
                            porcentaje_combustible,
                            litros_recargados,
                            porcentaje_recargado,
                            litros_consumidos,
                            es_evento_recarga,
                            latitud,
                            longitud,
                            fecha_hora
                        ) VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s)
                        ON CONFLICT (vehiculo_id, fecha_hora) DO NOTHING
                    """, (
                        vehiculo_id,
                        porcentaje,
                        litros if es_recarga else 0,
                        diferencia if es_recarga else 0,
                        litros if es_consumo else 0,
                        es_recarga,
                        latitud,
                        longitud,
                        fecha
                    ))
                    registros_insertados += 1
                except Exception as e:
                    logger.exception("Error insertando evento de combustible")

        anterior_porcentaje = porcentaje

    logger.info("[FINAL] %s: %d registros insertados", vehiculo_id, registros_insertados)
    try:
        update_sync_time(cur, vehiculo_id, TIPO_DATO, datetime.now(timezone.utc))
    except Exception as e:
        logger.exception("Error actualizando tiempo de sincronización")

def sincronizar_reporte_resumen_combustible(fecha_inicio: str, fecha_fin: str):
    obtener_fecha_manual()
    logger.info(f"[REPORTE] Consultando fuel-energy de {fecha_inicio} a {fecha_fin}")
    url = URL_FUEL_ENERGY
    parametros = {
        "startDate": fecha_inicio,
        "endDate": fecha_fin,
        "energyType": "fuel"
    }

    try:
        respuesta = requests.get(url, headers=CABECERAS, params=parametros)
        if respuesta.status_code != 200:
            logger.error(f"[ERROR] Fallo API: {respuesta.status_code} - {respuesta.text}")
            return

        reportes = respuesta.json().get("data", {}).get("vehicleReports", [])
        registros = 0

        with get_connection() as conn:
            with conn.cursor() as cur:
                for reporte in reportes:
                    vehiculo = reporte.get("vehicle", {})
                    vehiculo_id = vehiculo.get("id")
                    if not vehiculo_id:
                        continue

                    try:
                        litros = round(reporte.get("fuelConsumedMl", 0) / 1000, 2)
                        km = round(reporte.get("distanceTraveledMeters", 0) / 1000, 2)
                        rendimiento = round(km / litros, 2) if litros > 0 else None
                        costo = reporte.get("estFuelEnergyCost", {}).get("amount")
                        motor_s = int(reporte.get("engineRunTimeDurationMs", 0) / 1000)
                        ralenti_s = int(reporte.get("engineIdleTimeDurationMs", 0) / 1000)

                        # Usar la fecha configurada o UTC
                        fecha_reporte = datetime.strptime(fecha_inicio[:10], "%Y-%m-%d").date()
                        logger.debug(f"[REPORTE] Insertando para fecha: {fecha_reporte} y vehículo: {vehiculo_id}")

                        cur.execute("""
                            INSERT INTO reporte_combustible (
                                vehiculo_id,
                                fecha_reporte,
                                litros_totales,
                                kilometros_recorridos,
                                rendimiento_km_por_litro,
                                costo_combustible_usd,
                                tiempo_motor_s,
                                tiempo_ralenti_s
                            ) VALUES (%s, %s, %s, %s, %s, %s, %s, %s)
                            ON CONFLICT DO NOTHING
                        """, (
                            vehiculo_id,
                            fecha_reporte,
                            litros,
                            km,
                            rendimiento,
                            costo,
                            motor_s,
                            ralenti_s
                        ))
                        registros += 1
                    except Exception as e:
                        logger.exception(f"[ERROR] Al guardar resumen del vehículo {vehiculo_id}")

            conn.commit()
        logger.info(f"[REPORTE] {registros} resúmenes guardados correctamente.")

    except Exception as e:
        logger.exception("Error al obtener reporte fuel-energy")



def limpiar_y_actualizar_fuel_stats_dia(fecha_obj):
    obtener_fecha_manual()
    fecha_str = fecha_obj.isoformat()
    inicio = f"{fecha_str}T00:00:00Z"
    fin = f"{fecha_str}T23:59:59Z"

    try:
        logger.info(f"[FUEL-STATS] Eliminando registros de {fecha_str} para recalcular...")
        with get_connection() as conn:
            with conn.cursor() as cur:
                cur.execute("""
                    DELETE FROM vehicle_fuel_stats
                    WHERE DATE(fecha_hora AT TIME ZONE 'UTC' AT TIME ZONE 'America/Mexico_City') = %s
                """, (fecha_str,))

                capacidades = get_vehicle_capacities()
                ids = list(capacidades.keys())
                url = f"{URL_HISTORICO}?vehicleIds={','.join(ids)}&startTime={inicio}&endTime={fin}&types={TIPO_DATO}&decorations=gps,obdOdometerMeters"

                respuesta = requests.get(url, headers=CABECERAS)
                datos = respuesta.json().get("data", [])

                for registro in datos:
                    procesar_estadistica(registro, capacidades, cur, fecha_filtro=fecha_str)
                conn.commit()
    except Exception as e:
        logger.exception(f"[FUEL-STATS] Error actualizando registros del {fecha_str}")


def recalcular_resumen_combustible_dia(fecha_obj):
    obtener_fecha_manual()
    fecha_str = fecha_obj.isoformat()
    inicio = f"{fecha_str}T00:00:00Z"
    fin = f"{fecha_str}T23:59:59Z"

    try:
        logger.info(f"[REPORTE] Eliminando resumen previo del {fecha_str} por recálculo de 72h.")
        with get_connection() as conn:
            with conn.cursor() as cur:
                cur.execute("DELETE FROM reporte_combustible WHERE fecha_reporte = %s", (fecha_str,))
                conn.commit()

        logger.info(f"[REPORTE] Recalculando resumen de {fecha_str}")
        sincronizar_reporte_resumen_combustible(inicio, fin)
    except Exception as e:
        logger.exception(f"[REPORTE] Error recalculando resumen del día {fecha_str}")


def sincronizar_eventos_combustible():
    obtener_fecha_manual()
    logger.info("[SYNC] Iniciando sincronización de eventos de combustible")

    # Usamos UTC o fecha del .env para todos los cálculos
    base = obtener_fecha_manual()

    ayer = base - timedelta(days=1)
    menos_tres = base - timedelta(days=3)
 

    limpiar_y_actualizar_fuel_stats_dia(ayer)
    recalcular_resumen_combustible_dia(menos_tres)

    logger.info("[SYNC] Sincronización extendida de combustible completada")

