 
# sync_scheduler.py

import schedule
import time
from pytz import timezone
import os
from datetime import datetime
from dotenv import load_dotenv

from api.samsara_client import (
    sincronizar_catalogo_vehiculos,
    obtener_estadisticas_combustible,
    sincronizar_reporte_resumen_combustible
)
from db.database import get_vehicle_capacities, get_last_sync_times, get_connection
from utils.logger import logger

# Cargar variables del entorno
load_dotenv()
INTERVAL = int(os.getenv("INTERVAL", 1))

def tarea_sincronizacion():
    """
    Ejecuta sincronización completa:
    - Catálogo de vehículos
    - Estadísticas individuales de combustible
    - Reporte diario resumido (una vez al día)
    """
    try:
        logger.info("---- INICIO DE SINCRONIZACIÓN ----")

        sincronizar_catalogo_vehiculos()
        capacidades = get_vehicle_capacities()
        sincronizaciones = get_last_sync_times("fuelPercents")
        obtener_estadisticas_combustible(capacidades, sincronizaciones)

        logger.info("---- Ejecutar sincronización resumen fuel-energy ----")
        # Ejecutar sincronización resumen fuel-energy
        sincronizar_resumen_fuel_energy_diario()

        logger.info("---- FIN DE SINCRONIZACIÓN ----")

    except Exception as e:
        logger.exception("Error durante la tarea de sincronización")

def sincronizar_resumen_fuel_energy_diario():
    """
    Sincroniza dos días:
    1. El día actual (si aún no ha sido insertado)
    2. El día de hace 3 días, eliminando datos previos y reinsertando (por posible latencia de Samsara)
    """
    zona_local = timezone('America/Mexico_City')
    hoy = datetime.now(zona_local).date()
    dia_a_recalcular = hoy - timedelta(days=3)

    fechas = [
        ("hoy", hoy, False),              # Insertar si no existe
        ("recalculo", dia_a_recalcular, True)  # Siempre recalcular (borrar e insertar)
    ]

    for etiqueta, fecha, forzar_recalculo in fechas:
        try:
            with get_connection() as conn:
                with conn.cursor() as cur:
                    cur.execute("SELECT COUNT(*) FROM reporte_combustible WHERE fecha_reporte = %s", (fecha,))
                    existe = cur.fetchone()[0] > 0

                    inicio = fecha.isoformat() + "T00:00:00Z"
                    fin = fecha.isoformat() + "T23:59:59Z"

                    if forzar_recalculo:
                        if existe:
                            logger.info(f"[REPORTE] Eliminando resumen previo del {fecha} por recálculo de 72h.")
                            cur.execute("DELETE FROM reporte_combustible WHERE fecha_reporte = %s", (fecha,))
                            conn.commit()

                        logger.info(f"[REPORTE] Recalculando resumen de {fecha}")
                        sincronizar_reporte_resumen_combustible(inicio, fin)

                    else:
                        if not existe:
                            logger.info(f"[REPORTE] Insertando resumen nuevo del día {fecha}")
                            sincronizar_reporte_resumen_combustible(inicio, fin)
                        else:
                            logger.info(f"[REPORTE] Ya existe resumen de hoy ({fecha}), se omite.")

        except Exception as e:
            logger.exception(f"[REPORTE] Error durante la sincronización del día {fecha}")



# def sincronizar_resumen_fuel_energy_diario():
#     """
#     Sincroniza dos días:
#     1. El día actual (si aún no ha sido insertado)
#     2. El día de hace 3 días, eliminando datos previos y reinsertando (por posible latencia de Samsara)
#     """
#     zona_local = timezone('America/Mexico_City')
#     hoy = datetime.now(zona_local).date()
#     dia_a_recalcular = hoy - timedelta(days=3)

#     fechas = [
#         ("hoy", hoy, False),              # Insertar si no existe
#         ("recalculo", dia_a_recalcular, True)  # Siempre recalcular (borrar e insertar)
#     ]

#     for etiqueta, fecha, forzar_recalculo in fechas:
#         try:
#             with get_connection() as conn:
#                 with conn.cursor() as cur:
#                     cur.execute("SELECT COUNT(*) FROM reporte_combustible WHERE fecha_reporte = %s", (fecha,))
#                     existe = cur.fetchone()[0] > 0

#                     inicio = fecha.isoformat() + "T00:00:00Z"
#                     fin = fecha.isoformat() + "T23:59:59Z"

#                     if forzar_recalculo:
#                         if existe:
#                             logger.info(f"[REPORTE] Eliminando resumen previo del {fecha} por recálculo de 72h.")
#                             cur.execute("DELETE FROM reporte_combustible WHERE fecha_reporte = %s", (fecha,))
#                             conn.commit()

#                         logger.info(f"[REPORTE] Recalculando resumen de {fecha}")
#                         sincronizar_reporte_resumen_combustible(inicio, fin)

#                     else:
#                         if not existe:
#                             logger.info(f"[REPORTE] Insertando resumen nuevo del día {fecha}")
#                             sincronizar_reporte_resumen_combustible(inicio, fin)
#                         else:
#                             logger.info(f"[REPORTE] Ya existe resumen de hoy ({fecha}), se omite.")

#         except Exception as e:
#             logger.exception(f"[REPORTE] Error durante la sincronización del día {fecha}")

# def sincronizar_resumen_fuel_energy_diario():
    """
    Solo ejecuta la descarga de resumen diario de combustible
    si aún no existe en la tabla para el día actual.
    """
    zona_local = timezone('America/Mexico_City')
    hoy = datetime.now(zona_local).date()
    try:
        with get_connection() as conn:
            with conn.cursor() as cur:
                cur.execute("""
                    SELECT COUNT(*) FROM reporte_combustible WHERE fecha_reporte = %s
                """, (hoy,))
                cantidad = cur.fetchone()[0]

                if cantidad == 0:
                    inicio = hoy.isoformat() + "T00:00:00Z"
                    fin = hoy.isoformat() + "T23:59:59Z"
                    logger.info(f"[REPORTE] Ejecutando resumen diario del {hoy}")
                    sincronizar_reporte_resumen_combustible(inicio, fin)
                else:
                    logger.info(f"[REPORTE] Ya existe resumen de {hoy}, se omite.")

    except Exception as e:
        logger.exception("Error validando o insertando resumen diario")

def iniciar_programador():
    """
    Inicializa el scheduler con el intervalo configurado por .env
    """
    schedule.every(INTERVAL).minutes.do(tarea_sincronizacion)
    logger.info(f"Programador activo. Ejecutando cada {INTERVAL} minuto(s).")

    while True:
        schedule.run_pending()
        time.sleep(5)
