from pystray import Icon, MenuItem, Menu
from PIL import Image, ImageDraw
import threading
import os
import sys
import webbrowser
import time
import schedule
from tkinter import simpledialog, Tk
from tkinter import Tk, Label, Button
from tkcalendar import DateEntry
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

def editar_fecha_manual(icon, item):
    def abrir_dialogo():
        try:

            def guardar_fechas():
                nueva_fecha_inicio = cal_inicio.get_date().strftime("%Y-%m-%d")
                nueva_fecha_fin = cal_fin.get_date().strftime("%Y-%m-%d")
                root.destroy()

                if nueva_fecha_inicio and nueva_fecha_fin:
                    with open(".env", "r") as f:
                        lineas = f.readlines()
                    modificada_inicio = False
                    modificada_fin = False
                    with open(".env", "w") as f:
                        for linea in lineas:
                            if linea.startswith("FECHA_CONSULTA_INICIO="):
                                f.write(f"FECHA_CONSULTA_INICIO={nueva_fecha_inicio}\n")
                                modificada_inicio = True
                            elif linea.startswith("FECHA_CONSULTA_FIN="):
                                f.write(f"FECHA_CONSULTA_FIN={nueva_fecha_fin}\n")
                                modificada_fin = True
                            else:
                                f.write(linea)
                        if not modificada_inicio:
                            f.write(f"FECHA_CONSULTA_INICIO={nueva_fecha_inicio}\n")
                        if not modificada_fin:
                            f.write(f"FECHA_CONSULTA_FIN={nueva_fecha_fin}\n")

                    logger.info(f"[MANUAL] FECHA_CONSULTA_INICIO actualizada a {nueva_fecha_inicio}")
                    logger.info(f"[MANUAL] FECHA_CONSULTA_FIN actualizada a {nueva_fecha_fin}")

            root = Tk()
            root.title("Selecciona el rango de fechas")
            Label(root, text="Fecha de inicio:").pack()
            cal_inicio = DateEntry(root, date_pattern="yyyy-mm-dd")
            cal_inicio.pack()
            Label(root, text="Fecha de fin:").pack()
            cal_fin = DateEntry(root, date_pattern="yyyy-mm-dd")
            cal_fin.pack()
            Button(root, text="Guardar", command=guardar_fechas).pack()
            root.mainloop()
        except Exception as e:
            logger.exception("Error al editar el rango de fechas manualmente")

    threading.Thread(target=abrir_dialogo, daemon=True).start()

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
    MenuItem("Editar fecha manual", editar_fecha_manual),
    MenuItem("Salir", quit_action)
)

# Iniciar scheduler y lanzar ícono
start_scheduler()
icon = Icon("SamsaraSync", create_image(), "Sync Samsara", menu)
logger.info("Icono cargado y systray en ejecución.")
icon.run()
