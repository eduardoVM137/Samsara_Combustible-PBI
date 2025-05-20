from pystray import Icon, MenuItem, Menu
from PIL import Image
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
    print("[INFO] Iniciando loop de scheduler...")
    while running:
        if not paused:
            schedule.run_pending()
        time.sleep(1)

def start_scheduler():
    print(f"[INFO] Intervalo configurado en {INTERVAL} minutos")
    schedule.every(INTERVAL).minutes.do(tarea_sincronizacion)
    thread = threading.Thread(target=loop_scheduler, daemon=True)
    thread.start()
    print("[INFO] Ejecutando sincronización inicial...")
    tarea_sincronizacion()

def toggle_pause(icon, item):
    global paused
    paused = not paused
    item.text = "Reanudar" if paused else "Pausar"
    estado = "[PAUSA] Pausado" if paused else "[RUN] Reanudado"
    print(estado)
    logger.info(estado)

def sync_now(icon, item):
    print("[SYNC] Sincronización manual ejecutada")
    logger.info("Sincronización manual ejecutada")
    tarea_sincronizacion()

def show_log(icon, item):
    log_path = os.path.abspath("samsara_sync.log")
    print(f"[LOG] Abriendo log: {log_path}")
    logger.info(f"Abrir log: {log_path}")
    webbrowser.open(log_path)

def show_status(icon, item):
    msg = "[PAUSA] En pausa" if paused else "[STATUS] En ejecución"
    print(msg)
    logger.info(msg)

def quit_action(icon, item):
    global running
    print("[EXIT] Finalizando aplicación...")
    logger.info("Cierre solicitado por el usuario.")
    running = False
    icon.stop()
    sys.exit(0)

def setup(icon):
    print("[OK] Icono cargado y programador iniciando...")
    start_scheduler()

# Cargar el ícono
icon_path = os.path.join(os.path.dirname(__file__), "icon.png")
if not os.path.exists(icon_path):
    print(f"[ERROR] Icono no encontrado en {icon_path}")
    sys.exit(1)

image = Image.open(icon_path)

menu = Menu(
    MenuItem("Ver log", show_log),
    MenuItem("Sincronizar ahora", sync_now),
    MenuItem("Pausar", toggle_pause),
    MenuItem("Mostrar estado", show_status),
    MenuItem("Salir", quit_action)
)

icon = Icon("SamsaraSync", image, "Sync Samsara", menu)
icon.run(setup=setup)
