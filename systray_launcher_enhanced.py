from pystray import Icon, MenuItem, Menu
from PIL import Image, ImageDraw
import threading
import os
import sys
import webbrowser
import time
import schedule

from sync_scheduler import tarea_sincronizacion, INTERVAL
from utils.logger import logger

# Control de ejecución
paused = False
running = False

def loop_scheduler():
    global running
    running = True
    logger.info("Iniciando loop del scheduler...")
    while running:
        if not paused:
            schedule.run_pending()
        time.sleep(1)

def start_scheduler():
    logger.info(f"Intervalo configurado en {INTERVAL} minutos")
    schedule.every(INTERVAL).minutes.do(tarea_sincronizacion)
    thread = threading.Thread(target=loop_scheduler, daemon=True)
    thread.start()
    logger.info("Ejecutando sincronización inicial...")
    tarea_sincronizacion()

def toggle_pause(icon, item):
    global paused
    paused = not paused
    item.text = "Reanudar" if paused else "Pausar"
    estado = "[PAUSA] Pausado" if paused else "[RUN] Reanudado"
    print(estado)
    logger.info(estado)

def sync_now(icon, item):
    logger.info("Sincronización manual ejecutada")
    tarea_sincronizacion()

def show_log(icon, item):
    log_path = os.path.abspath("samsara_sync.log")
    logger.info(f"Abrir log: {log_path}")
    webbrowser.open(log_path)

def show_status(icon, item):
    msg = "[PAUSA] En pausa" if paused else "[STATUS] En ejecución"
    print(msg)
    logger.info(msg)

def quit_action(icon, item):
    global running
    logger.info("Cierre solicitado por el usuario.")
    running = False
    icon.stop()
    sys.exit(0)

def create_image():
    """Crea un ícono dinámico rojo para la bandeja del sistema."""
    image = Image.new("RGB", (64, 64), (255, 255, 255))
    draw = ImageDraw.Draw(image)
    draw.rectangle((16, 16, 48, 48), fill=(255, 0, 0))
    return image

# Menú del systray
menu = Menu(
    MenuItem("Ver log", show_log),
    MenuItem("Sincronizar ahora", sync_now),
    MenuItem("Pausar", toggle_pause),
    MenuItem("Mostrar estado", show_status),
    MenuItem("Salir", quit_action)
)

# Iniciar scheduler y lanzar ícono
start_scheduler()
icon = Icon("SamsaraSync", create_image(), "Sync Samsara", menu)
logger.info("Icono cargado y systray en ejecución.")
icon.run()
