# sync_scheduler.py

import schedule
import time
from pytz import timezone
import os
from datetime import datetime, timedelta
from dotenv import load_dotenv

from api.samsara_client import (
    sincronizar_catalogo_vehiculos,
    obtener_estadisticas_combustible,
    sincronizar_reporte_resumen_combustible,
    sincronizar_eventos_combustible
)
from db.database import get_vehicle_capacities, get_last_sync_times
from utils.logger import logger

# Cargar .env
load_dotenv()
INTERVAL = int(os.getenv("INTERVAL", 5))
FECHA_MANUAL = os.getenv("FECHA_CONSULTA")  # Ejemplo: "2025-05-21"

def tarea_sincronizacion():
    """
    Sincronización completa:
    - Catálogo de vehículos
    - Eventos recientes de combustible
    - Resumen diario si no existe
    - Corrección de día anterior y día menos 3
    """
    try:
        logger.info("---- INICIO DE SINCRONIZACIÓN ----")

        sincronizar_catalogo_vehiculos()
        capacidades = get_vehicle_capacities()
        sincronizaciones = get_last_sync_times("fuelPercents")
        obtener_estadisticas_combustible(capacidades, sincronizaciones)

        # Usar la fecha manual si está definida, si no usar la fecha actual
        zona_local = timezone("America/Mexico_City")
        fecha_base = datetime.strptime(FECHA_MANUAL, "%Y-%m-%d").date() if FECHA_MANUAL else datetime.now(zona_local).date()

        inicio = fecha_base.isoformat() + "T00:00:00Z"
        fin = fecha_base.isoformat() + "T23:59:59Z"

        logger.info(f"[REPORTE] Intentando insertar resumen diario del {fecha_base}")
        sincronizar_reporte_resumen_combustible(inicio, fin)

        # Corrección: día anterior y hace 3 días
        sincronizar_eventos_combustible()

        logger.info("---- FIN DE SINCRONIZACIÓN ----")
    except Exception as e:
        logger.exception("Error durante la sincronización")

def iniciar_programador():
    """
    Inicia el programador con el intervalo de ejecución configurado
    """
    schedule.every(INTERVAL).minutes.do(tarea_sincronizacion)
    logger.info(f"Programador iniciado. Ejecutando cada {INTERVAL} minutos.")
    while True:
        schedule.run_pending()
        time.sleep(5)
