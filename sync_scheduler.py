# sync_scheduler.py

import schedule
import time
from pytz import timezone
import os
from datetime import datetime, timezone, timedelta
from dotenv import load_dotenv
load_dotenv()
from api.samsara_client import (
    sincronizar_catalogo_vehiculos,
    getHistorical_stats,
    sync_fuel_energy_summary
)
from db.database import get_vehicle_capacities, get_last_sync_times
from utils.logger import logger

INTERVAL = int(os.getenv("INTERVAL", 720))

def obtener_fecha_inicio_manual():
    load_dotenv(override=True)
    valor = os.getenv("FECHA_CONSULTA_INICIO")
    logger.info(f"[DEBUG] FECHA_CONSULTA_INICIO leída: {valor}")
    return datetime.strptime(valor, "%Y-%m-%d").date() if valor else datetime.now(timezone.utc).date()

def obtener_fecha_fin_manual():
    load_dotenv(override=True)
    valor = os.getenv("FECHA_CONSULTA_FIN")
    logger.info(f"[DEBUG] FECHA_CONSULTA_FIN leída: {valor}")
    return datetime.strptime(valor, "%Y-%m-%d").date() if valor else datetime.now(timezone.utc).date()

def tarea_sincronizacion(fecha_inicio=None, fecha_fin=None):
    """
    Si no se pasan fechas, usa la fecha actual (modo automático).
    Si se pasan fechas, usa esas fechas (modo manual).
    """
    try:
        logger.info("---- INICIO DE SINCRONIZACIÓN ----")
        sincronizar_catalogo_vehiculos()
        capacidades = get_vehicle_capacities()
        sincronizaciones = get_last_sync_times("fuelPercents")

        if fecha_inicio is None or fecha_fin is None:
            # Modo automático: usa la fecha actual
            fecha_fin = datetime.now(timezone.utc).date()
            fecha_inicio = fecha_fin
            logger.info(f"[AUTO] Sincronizando con fecha actual: {fecha_inicio}")
        else:
            logger.info(f"[MANUAL] Sincronizando con fechas: {fecha_inicio} a {fecha_fin}")

        # Ajuste para reporte_combustible: si la fecha final es hoy, retrocede 3 días
        hoy = datetime.now(timezone.utc).date()
        if fecha_fin == hoy:
            fecha_inicio_reporte = hoy - timedelta(days=3)
            logger.info(f"[REPORTE] Fecha final es hoy. Ajustando fecha de inicio de reporte_combustible a {fecha_inicio_reporte}")
        else:
            fecha_inicio_reporte = fecha_inicio

        getHistorical_stats(capacidades, sincronizaciones, fecha_inicio, fecha_fin)
        logger.info("---- Desarrollo DE SINCRONIZACIÓN ----")
        logger.info(f"[REPORTE] Intentando no insertar resumen diario del {fecha_inicio_reporte} al {fecha_fin}")
        sync_fuel_energy_summary(fecha_inicio_reporte, fecha_fin)
        logger.info("---- FIN DE SINCRONIZACIÓN ----")
    except Exception as e:
        logger.exception("Error durante la sincronización")

def modo_manual():
    # Lee fechas del .env y ejecuta sincronización solo una vez
    fecha_inicio = obtener_fecha_inicio_manual()
    fecha_fin = obtener_fecha_fin_manual()
    tarea_sincronizacion(fecha_inicio, fecha_fin)

def modo_automatico():
    # Ejecuta sincronización cada INTERVAL minutos con la fecha actual
    schedule.every(INTERVAL).minutes.do(tarea_sincronizacion)
    logger.info(f"[AUTO] Scheduler iniciado cada {INTERVAL} minutos.")
    while True:
        schedule.run_pending()
        time.sleep(1)

