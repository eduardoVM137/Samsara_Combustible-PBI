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
from collections import defaultdict
import time  
from math import ceil
TOKEN_API = os.getenv("SAMSARA_API_TOKEN")
CABECERAS = {"Authorization": f"Bearer {TOKEN_API}"}
URL_HISTORICO = "https://api.samsara.com/fleet/vehicles/stats/history"
URL_FUEL_ENERGY = "https://api.samsara.com/fleet/reports/vehicles/fuel-energy"
TIPO_DATO = "fuelPercents" 


def sincronizar_catalogo_vehiculos():

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
# reportes de vehicle_fuel_statts en un periodo(generalmente hoy),considerar que se envian id de vehiculs necesito olvidarlodef 
def chunks(lst, n):
    # Generador que divide una lista en sublistas de tamaño n
    for i in range(0, len(lst), n):
        yield lst[i:i + n]
def getHistorical_stats(capacidades, lista_ultima_sincronizacion, mifecha_inicio, mifecha_fin):
    # Inicia la descarga de datos históricos de combustible
    logger.info("Iniciando descarga de datos históricos de combustible...")

    ids_vehiculos = list(capacidades.keys())
    dias_totales = (mifecha_fin - mifecha_inicio).days + 1
    total_lotes = ceil(len(ids_vehiculos) / 10)  # Procesa en lotes de 10 vehículos

    with get_connection() as conn:
        with conn.cursor() as cur:
            # Recorre cada día del rango solicitado
            for dia in range(dias_totales):
                fecha_actual = mifecha_inicio + timedelta(days=dia)
                fecha_inicio = f"{fecha_actual.isoformat()}T00:00:00Z"
                fecha_fin = f"{fecha_actual.isoformat()}T23:59:59Z"
                logger.info("[Día %d/%d] Fecha: %s", dia+1, dias_totales, fecha_actual)

                lote_actual = 1
                # Procesa los vehículos en lotes de 10
                for lote in chunks(ids_vehiculos, 10):
                    logger.info("Procesando lote %d/%d: %s", lote_actual, total_lotes, lote)
                    lote_actual += 1

                    # Construye la URL base para la consulta de la API
                    url_base = (
                        f"{URL_HISTORICO}?vehicleIds={','.join(lote)}"
                        f"&startTime={fecha_inicio}&endTime={fecha_fin}"
                        f"&types={TIPO_DATO}&decorations=gps,obdOdometerMeters"
                    )

                    end_cursor = None
                    pagina = 1
                    seen_cursors = set()
                    vehiculos_agrupados = defaultdict(list)

                    # Maneja la paginación de la API
                    while True:
                        url = url_base + (f"&startingAfter={end_cursor}" if end_cursor else "")
                        logger.info("[Página %d] Solicitando datos con cursor: %s", pagina, end_cursor)

                        try:
                            respuesta = requests.get(url, headers=CABECERAS)

                            # Si hay rate limit, espera y reintenta
                            if respuesta.status_code == 429:
                                logger.warning("Rate limit alcanzado. Esperando 10 segundos...")
                                time.sleep(10)
                                continue

                            # Si hay error, sale del ciclo de paginación
                            if respuesta.status_code != 200:
                                logger.error("[Página %d] Error API: %s - %s", pagina, respuesta.status_code, respuesta.text)
                                break

                            data_json = respuesta.json()
                            registros = data_json.get("data", [])

                            logger.info("[Página %d] Registros obtenidos: %d", pagina, len(registros))

                            # Agrupa los registros de fuelPercents por vehículo
                            for registro in registros:
                                vehiculo_id = str(registro.get("id"))
                                if not vehiculo_id:
                                    continue
                                vehiculos_agrupados[vehiculo_id].extend(registro.get("fuelPercents", []))

                            # Manejo de paginación
                            pagination = data_json.get("pagination", {})
                            end_cursor = pagination.get("endCursor")
                            has_next = pagination.get("hasNextPage", False)

                            logger.info("[Página %d] hasNextPage = %s | endCursor = %s", pagina, has_next, end_cursor)

                            # Evita bucles infinitos por cursor repetido
                            if end_cursor in seen_cursors:
                                logger.warning("[Página %d] Cursor repetido detectado: posible bucle de paginación", pagina)
                                break
                            seen_cursors.add(end_cursor)

                            # Si no hay más páginas, termina el ciclo
                            if not has_next:
                                logger.info("[Página %d] Fin de paginación alcanzado.", pagina)
                                break

                            pagina += 1
                            time.sleep(0.3)  # Espera corta entre páginas para no saturar la API

                        except Exception:
                            logger.exception("Error procesando datos históricos de combustible.")
                            break

                    # Procesa los registros agrupados por vehículo
                    for vehiculo_id, lista_registros in vehiculos_agrupados.items():
                        lista_registros.sort(key=lambda r: r["time"])
                        postVehicle_fuel_stats({"id": vehiculo_id, "fuelPercents": lista_registros}, capacidades, cur)

                    conn.commit()
                    logger.info("Lote procesado correctamente. Esperando 0.5 segundos...")
                    time.sleep(0.5)
def postVehicle_fuel_stats(registro_vehiculo, capacidades_vehiculos, cursor_bd):
    # Obtiene el ID del vehículo
    vehiculo_id = str(registro_vehiculo.get("id"))
    if not vehiculo_id:
        logger.warning("[SKIP] Vehículo sin ID válido: %s", registro_vehiculo)
        return

    # Obtiene la capacidad del tanque, por defecto 200 si no está definida
    capacidad_tanque = capacidades_vehiculos.get(vehiculo_id, 200)
    registros_combustible = registro_vehiculo.get("fuelPercents", [])
    logger.info("[VEHÍCULO %s] %d registros", vehiculo_id, len(registros_combustible))

    # Variables para el procesamiento de eventos
    porcentaje_anterior = None
    fecha_anterior = None
    total_inserts = 0

    # Umbrales y ventanas de control para la lógica de recarga/consumo
    CAMBIO_MINIMO_PORCENTAJE = 2
    UMBRAL_RECARGA_PORCENTAJE = 5
    UMBRAL_RECARGA_FUERTE = 10
    VENTANA_REBOTE_MINUTOS = 3
    VENTANA_ACUMULATIVA_MINUTOS = 10
    TIEMPO_MIN_ENTRE_EVENTOS = 30

    # Variables para controlar rebotes y acumulaciones de recarga
    tiempo_ultima_recarga_fuerte = None
    porcentaje_acumulado_recarga = 0
    fecha_inicio_acumulacion = None
    acumulando = False

    # Procesa cada registro de porcentaje de combustible
    for registro in registros_combustible:
        porcentaje_actual = registro.get("value")
        fecha_registro = registro.get("time")
        if not porcentaje_actual or not fecha_registro:
            continue  # Ignora registros incompletos

        # Convierte la fecha a objeto datetime
        fecha_dt = datetime.fromisoformat(fecha_registro.replace("Z", "+00:00"))
        gps = registro.get("decorations", {}).get("gps", {})
        latitud = gps.get("latitude")
        longitud = gps.get("longitude")

        if porcentaje_anterior is not None:
            # Calcula la diferencia de porcentaje y el tiempo entre eventos
            diferencia = round(porcentaje_actual - porcentaje_anterior, 2)
            tiempo_diferencia = (fecha_dt - fecha_anterior).total_seconds() if fecha_anterior else None

            # Ignora eventos dentro de la ventana de rebote tras una recarga fuerte
            if tiempo_ultima_recarga_fuerte and fecha_dt < tiempo_ultima_recarga_fuerte + timedelta(minutes=VENTANA_REBOTE_MINUTOS):
                logger.info("[IGNORADO] Rebote post-recarga fuerte en %s", fecha_dt)
                porcentaje_anterior = porcentaje_actual
                fecha_anterior = fecha_dt
                continue

            # Acumula recargas pequeñas dentro de la ventana acumulativa
            if diferencia > 0:
                if not acumulando:
                    fecha_inicio_acumulacion = fecha_anterior if fecha_anterior else fecha_dt
                    porcentaje_acumulado_recarga = diferencia
                    acumulando = True
                elif (fecha_dt - fecha_inicio_acumulacion).total_seconds() < VENTANA_ACUMULATIVA_MINUTOS * 60:
                    porcentaje_acumulado_recarga += diferencia
                else:
                    fecha_inicio_acumulacion = fecha_anterior if fecha_anterior else fecha_dt
                    porcentaje_acumulado_recarga = diferencia
            else:
                # Si hay consumo, resetea la acumulación
                porcentaje_acumulado_recarga = 0
                fecha_inicio_acumulacion = None
                acumulando = False

            # Determina si es recarga por diferencia o por acumulación
            recarga_por_diferencia = diferencia >= UMBRAL_RECARGA_PORCENTAJE
            recarga_por_acumulacion = porcentaje_acumulado_recarga >= UMBRAL_RECARGA_PORCENTAJE
            es_recarga = recarga_por_diferencia or recarga_por_acumulacion
            es_consumo = diferencia < -CAMBIO_MINIMO_PORCENTAJE

            # Usa el total acumulado si fue por acumulación
            porcentaje_total_recarga = porcentaje_acumulado_recarga if recarga_por_acumulacion else diferencia
            litros_total_recarga = round(abs(porcentaje_total_recarga) * capacidad_tanque / 100, 2)

            litros_recargados = litros_total_recarga if es_recarga and porcentaje_total_recarga > 0 else 0
            litros_consumidos = round(abs(diferencia) * capacidad_tanque / 100, 2) if es_consumo else 0
            porcentaje_recargado = porcentaje_total_recarga if es_recarga and porcentaje_total_recarga > 0 else 0

            # Si la recarga es fuerte, marca el tiempo para la ventana de rebote
            if es_recarga and porcentaje_total_recarga >= UMBRAL_RECARGA_FUERTE:
                tiempo_ultima_recarga_fuerte = fecha_dt

            # Ignora eventos duplicados exactos sin litros ni consumo
            if porcentaje_anterior == porcentaje_actual and fecha_anterior == fecha_dt and litros_recargados == 0 and litros_consumidos == 0:
                logger.info("[IGNORADO] Evento duplicado exacto en %s", fecha_dt)
                porcentaje_anterior = porcentaje_actual
                fecha_anterior = fecha_dt
                continue

            # Ignora eventos muy cercanos en el tiempo y sin cambio relevante
            if tiempo_diferencia is not None and tiempo_diferencia < TIEMPO_MIN_ENTRE_EVENTOS and abs(diferencia) < CAMBIO_MINIMO_PORCENTAJE:
                logger.info("[IGNORADO] Evento ignorado por ser muy cercano (%ss) y sin cambio relevante", tiempo_diferencia)
                porcentaje_anterior = porcentaje_actual
                fecha_anterior = fecha_dt
                continue

            # Log de advertencia si se marca recarga o consumo pero no hay litros
            if es_recarga and litros_recargados == 0:
                logger.warning("Recarga marcada sin litros (%s%% en %s)", porcentaje_total_recarga, fecha_dt)
            if es_consumo and litros_consumidos == 0:
                logger.warning("Consumo marcado sin litros (%s%% en %s)", diferencia, fecha_dt)

            # Inserta o actualiza el registro en la base de datos
            try:
                cursor_bd.execute("""
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
                    ON CONFLICT (vehiculo_id, fecha_hora) DO UPDATE
                    SET porcentaje_combustible = EXCLUDED.porcentaje_combustible,
                        litros_recargados = EXCLUDED.litros_recargados,
                        porcentaje_recargado = EXCLUDED.porcentaje_recargado,
                        litros_consumidos = EXCLUDED.litros_consumidos,
                        es_evento_recarga = EXCLUDED.es_evento_recarga,
                        latitud = EXCLUDED.latitud,
                        longitud = EXCLUDED.longitud
                    WHERE
                        vehicle_fuel_stats.porcentaje_combustible IS DISTINCT FROM EXCLUDED.porcentaje_combustible OR
                        vehicle_fuel_stats.litros_recargados IS DISTINCT FROM EXCLUDED.litros_recargados OR
                        vehicle_fuel_stats.porcentaje_recargado IS DISTINCT FROM EXCLUDED.porcentaje_recargado OR
                        vehicle_fuel_stats.litros_consumidos IS DISTINCT FROM EXCLUDED.litros_consumidos OR
                        vehicle_fuel_stats.es_evento_recarga IS DISTINCT FROM EXCLUDED.es_evento_recarga OR
                        vehicle_fuel_stats.latitud IS DISTINCT FROM EXCLUDED.latitud OR
                        vehicle_fuel_stats.longitud IS DISTINCT FROM EXCLUDED.longitud
                """, (
                    vehiculo_id,
                    porcentaje_actual,
                    litros_recargados,
                    porcentaje_recargado,
                    litros_consumidos,
                    es_recarga,
                    latitud,
                    longitud,
                    fecha_dt
                ))
                total_inserts += 1
            except Exception as err:
                logger.exception("Error insertando registro para %s en %s", vehiculo_id, fecha_dt)

            # Si se detectó recarga, reinicia los acumuladores
            if es_recarga:
                porcentaje_acumulado_recarga = 0
                fecha_inicio_acumulacion = None
                acumulando = False

        # Actualiza los valores anteriores para la siguiente iteración
        porcentaje_anterior = porcentaje_actual
        fecha_anterior = fecha_dt

    logger.info("[FINAL] Vehículo %s: %d registros insertados", vehiculo_id, total_inserts)




#           Fin de la función postVehicle_fuel_stats
#           Inicio  de la función reporte_combustible


def sync_fuel_energy_summary(start_date, end_date):
    # Inicia la sincronización del resumen de combustible para el rango de fechas dado
    logger.info(f"[FUEL-ENERGY] Sincronizando resumen de combustible entre {start_date} y {end_date}")

    try:
        # Intenta convertir las fechas de entrada a objetos date
        start_dt = datetime.strptime(str(start_date), "%Y-%m-%d").date()
        end_dt = datetime.strptime(str(end_date), "%Y-%m-%d").date()
    except Exception:
        logger.error("[FUEL-ENERGY] Formato de fecha inválido. Use 'YYYY-MM-DD', datetime o date")
        return

    # Valida que la fecha final no sea anterior a la inicial
    if end_dt < start_dt:
        logger.warning("[FUEL-ENERGY] Fecha final es anterior a fecha inicial. Cancelando.")
        return

    total_days = (end_dt - start_dt).days + 1  # Calcula el número de días a procesar

    try:
        # Obtiene todos los IDs de vehículos y los divide en lotes de 20 para optimizar las llamadas a la API
        all_vehicle_ids = get_vehicle_capacities().keys()
        vehicle_chunks = list(chunks(list(all_vehicle_ids), 20))

        # Recorre cada día del rango solicitado
        for i in range(total_days):
            current_day = start_dt + timedelta(days=i)
            # Define el inicio y fin del día con zona horaria -07:00 (ajustar si es necesario)
            day_start = f"{current_day}T00:00:00.00-07:00"
            day_end = f"{current_day}T23:59:59.99-07:00"

            logger.info(f"[FUEL-ENERGY] Día {i+1}/{total_days}: {day_start} a {day_end}")

            # Procesa los vehículos en lotes
            for chunk_index, vehicle_ids in enumerate(vehicle_chunks):
                logger.info(f"[Lote {chunk_index+1}/{len(vehicle_chunks)}] Vehículos: {vehicle_ids}")

                page = 1
                end_cursor = None
                seen_cursors = set()  # Para evitar bucles infinitos de paginación

                with get_connection() as conn:
                    with conn.cursor() as cur:
                        while True:
                            # Prepara los parámetros para la consulta a la API
                            params = {
                                "startDate": day_start,
                                "endDate": day_end,
                                "energyType": "fuel",
                                "vehicleIds": ",".join(vehicle_ids)
                            }
                            if end_cursor:
                                params["startingAfter"] = end_cursor

                            logger.info(f"[Página {page}] Solicitando con cursor: {end_cursor}")
                            response = requests.get(URL_FUEL_ENERGY, headers=CABECERAS, params=params)

                            # Si la API responde con error, lo registra y termina la paginación de ese lote
                            if response.status_code != 200:
                                logger.error(f"[ERROR] API: {response.status_code} - {response.text}")
                                break

                            # Obtiene los datos de la respuesta
                            data = response.json().get("data", {}).get("vehicleReports", [])
                            pagination = response.json().get("pagination", {})
                            end_cursor = pagination.get("endCursor")
                            has_next = pagination.get("hasNextPage", False)

                            logger.info(f"[Página {page}] Registros obtenidos: {len(data)} | hasNext: {has_next}")

                            # Inserta cada reporte de vehículo en la base de datos
                            for report in data:
                                vehicle = report.get("vehicle", {})
                                vehicle_id = vehicle.get("id")
                                if not vehicle_id:
                                    continue

                                try:
                                    # Obtiene la fecha del reporte, litros consumidos, km recorridos, rendimiento, costo, tiempos de motor y ralentí
                                    ts = report.get("startMs")
                                    report_date = datetime.fromtimestamp(int(ts) / 1000).date() if ts else current_day

                                    litros = round(report.get("fuelConsumedMl", 0) / 1000, 2)
                                    km = round(report.get("distanceTraveledMeters", 0) / 1000, 2)
                                    rendimiento = round(km / litros, 2) if litros > 0 else None
                                    costo = report.get("estFuelEnergyCost", {}).get("amount")
                                    motor_s = int(report.get("engineRunTimeDurationMs", 0) / 1000)
                                    ralenti_s = int(report.get("engineIdleTimeDurationMs", 0) / 1000)

                                    # Inserta o actualiza el registro en la tabla reporte_combustible
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
                                        ON CONFLICT (vehiculo_id, fecha_reporte) DO UPDATE SET
                                            litros_totales = EXCLUDED.litros_totales,
                                            kilometros_recorridos = EXCLUDED.kilometros_recorridos,
                                            rendimiento_km_por_litro = EXCLUDED.rendimiento_km_por_litro,
                                            costo_combustible_usd = EXCLUDED.costo_combustible_usd,
                                            tiempo_motor_s = EXCLUDED.tiempo_motor_s,
                                            tiempo_ralenti_s = EXCLUDED.tiempo_ralenti_s
                                    """, (
                                        vehicle_id,
                                        report_date,
                                        litros,
                                        km,
                                        rendimiento,
                                        costo,
                                        motor_s,
                                        ralenti_s
                                    ))
                                except Exception as e:
                                    logger.exception(f"[ERROR] Al insertar reporte de vehículo {vehicle_id}")

                            conn.commit()

                            # Si no hay más páginas o el cursor ya fue visto, termina la paginación
                            if not has_next or end_cursor in seen_cursors:
                                break
                            seen_cursors.add(end_cursor)
                            page += 1
                            time.sleep(0.5)  # Espera recomendada para no saturar la API

        logger.info("[FUEL-ENERGY] Sincronización completa.")

    except Exception as e:
        logger.exception("[FUEL-ENERGY] Error en la sincronización de fuel-energy")