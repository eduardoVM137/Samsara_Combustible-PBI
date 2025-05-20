# sync_scheduler.py

import schedule
import time
import os
from dotenv import load_dotenv
from api.samsara_client import sync_vehicle_catalog, fetch_fuel_stats
from db.database import get_vehicle_capacities, get_last_sync_times
from utils.logger import logger

# Cargar .env y obtener intervalo en minutos
load_dotenv()
INTERVAL = int(os.getenv("SYNC_INTERVAL_MINUTES", 1))  # default: 30 minutos

# Esta función puede llamarse también desde el systray
def tarea_sincronizacion():
    try:
        logger.info("---- INICIO DE SINCRONIZACIÓN ----")
        sync_vehicle_catalog()
        capacidades = get_vehicle_capacities()
        sincronizaciones = get_last_sync_times("fuelPercents")
        fetch_fuel_stats(capacidades, sincronizaciones)
        logger.info("---- FIN DE SINCRONIZACIÓN ----")
    except Exception as e:
        logger.exception("Error durante la tarea de sincronización")

# Función usada desde main.py si se ejecuta directamente
def iniciar_programador():
    schedule.every(INTERVAL).minutes.do(tarea_sincronizacion)
    logger.info(f"Programador iniciado. Ejecutando cada {INTERVAL} minutos.")
    while True:
        schedule.run_pending()
        time.sleep(5)
