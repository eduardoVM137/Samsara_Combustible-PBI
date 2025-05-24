from pystray import Icon, MenuItem, Menu
from PIL import Image
import threading
import os
import sys
import webbrowser
import time
import schedule
from tkinter import Tk, Label, Button, PhotoImage, messagebox
from tkcalendar import DateEntry
from sync_scheduler import tarea_sincronizacion, INTERVAL, obtener_fecha_inicio_manual, obtener_fecha_fin_manual
from utils.logger import logger
import tkinter as tk

# Control de ejecución
paused = False
running = False

def run_in_tk_mainloop(func):
    try:
        root = tk._default_root
        if root is None:
            root = tk.Tk()
            root.withdraw()
        root.after(0, func)
    except Exception:
        # Silenciar el error, ya que Tkinter no siempre tiene un mainloop activo
        func()


def resource_path(relative_path):
    """Obtiene la ruta absoluta al recurso, compatible con PyInstaller."""
    if hasattr(sys, '_MEIPASS'):
        return os.path.join(sys._MEIPASS, relative_path)
    return os.path.join(os.path.abspath("."), relative_path)

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

    # Sincronización inicial en un hilo aparte con ventana de carga animada
    def sync_inicial_con_carga():
        try:
            import itertools

            loading = Tk()
            loading.title("Panacea Combustible")
            loading.geometry("320x100")
            loading.resizable(False, False)
            Label(loading, text="Sincronizando datos iniciales...", font=("Arial", 12, "bold"), fg="#1e90ff").pack(pady=(15, 0))
            status = Label(loading, text="Por favor espera", font=("Arial", 10))
            status.pack(pady=(10, 0))

            # Animación simple de spinner textual
            spinner = itertools.cycle(["⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏"])
            running_spinner = True

            def animate():
                if running_spinner:
                    status.config(text=f"Por favor espera {next(spinner)}")
                    loading.after(120, animate)

            animate()

            # Ejecuta la sincronización real
            def sync_and_close():
                try:
                    tarea_sincronizacion()
                finally:
                    nonlocal running_spinner
                    running_spinner = False
                    loading.destroy()

            threading.Thread(target=sync_and_close, daemon=True).start()
            loading.mainloop()
        except Exception as e:
            logger.exception("Error en la sincronización inicial")
            try:
                loading.destroy()
            except:
                pass

    threading.Thread(target=sync_inicial_con_carga, daemon=True).start()

def toggle_pause(icon, item):
    global paused
    paused = not paused
    item.text = "Reanudar" if paused else "Pausar"
    estado = "[PAUSA] Pausado" if paused else "[RUN] Reanudado"
    print(estado)
    logger.info(estado)

def sync_now(icon, item):
    logger.info("Sincronización manual ejecutada")
    # Mostrar ventana de carga también para sincronización manual
    def sync_manual_con_carga():
        try:
            import itertools
            loading = Tk()
            loading.title("Panacea Combustible")
            loading.geometry("320x100")
            loading.resizable(False, False)
            Label(loading, text="Sincronizando manualmente...", font=("Arial", 12, "bold"), fg="#1e90ff").pack(pady=(15, 0))
            status = Label(loading, text="Por favor espera", font=("Arial", 10))
            status.pack(pady=(10, 0))
            spinner = itertools.cycle(["⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏"])
            running_spinner = True
            def animate():
                if running_spinner:
                    status.config(text=f"Por favor espera {next(spinner)}")
                    loading.after(120, animate)
            animate()
            def sync_and_close():
                try:
                    tarea_sincronizacion()
                finally:
                    nonlocal running_spinner
                    running_spinner = False
                    loading.destroy()
            threading.Thread(target=sync_and_close, daemon=True).start()
            loading.mainloop()
        except Exception as e:
            logger.exception("Error en la sincronización manual")
            try:
                loading.destroy()
            except:
                pass
    threading.Thread(target=sync_manual_con_carga, daemon=True).start()

def show_log(icon, item):
    # El log estará junto al ejecutable
    log_path = resource_path("samsara_sync.log")
    logger.info(f"Abrir log: {log_path}")

    # Si el archivo no existe, créalo vacío
    if not os.path.exists(log_path):
        try:
            with open(log_path, "w", encoding="utf-8") as f:
                f.write("Log de Panacea Combustible\n")
        except Exception as e:
            logger.error(f"No se pudo crear el archivo de log: {e}")
            messagebox.showerror("Error", f"No se pudo crear el archivo de log:\n{e}")
            return

    webbrowser.open(log_path)

def show_status(icon, item):
    msg = "[PAUSA] En pausa" if paused else "[STATUS] En ejecución"
    print(msg)
    logger.info(msg)

def show_about(icon, item):
    import tkinter as tk
    from tkinter import messagebox

    def abrir_github():
        webbrowser.open("https://github.com/eduardoVM137")  # Cambia por tu enlace real

    about = tk.Tk()
    about.title("Acerca de Panacea Combustible")
    about.geometry("350x180")
    about.resizable(False, False)

    Label(about, text="Sincronizador de Combustible", font=("Arial", 12, "bold"), fg="#97311f").pack(pady=(10, 0))
    Label(about, text="Panacea Strategy", font=("Arial", 10)).pack()
    web_label = Label(about, text="https://www.panaceast.com/", fg="#927E63", cursor="hand2")
    web_label.pack()
    web_label.bind("<Button-1>", lambda e: webbrowser.open("https://www.panaceast.com/"))
    Label(about, text="Desing by Eduardo V.", font=("Arial", 9)).pack(pady=(10, 0))

    # Enlace a GitHub
    link = Label(about, text="Mi GitHub", fg="blue", cursor="hand2", font=("Arial", 9, "underline"))
    link.pack()
    link.bind("<Button-1>", lambda e: abrir_github())

    Button(about, text="Cerrar", command=about.destroy, bg="#f54d4d", fg="white").pack(pady=10)
    about.mainloop()

def modo_manual():
    # Ejecuta sincronización solo una vez con las fechas del .env
    fecha_inicio = obtener_fecha_inicio_manual()
    fecha_fin = obtener_fecha_fin_manual()
    tarea_sincronizacion(fecha_inicio, fecha_fin)

def editar_fecha_manual(icon, item):
    try:
        root = Tk()
        root.title("Panacea Combustible - Selecciona el rango de fechas")
        # Si tienes el logo, descomenta la siguiente línea y pon el archivo en la carpeta
        #logo = PhotoImage(file=resource_path("panacea_logo.png"))
        #Label(root, image=logo).pack()
        Label(root, text="Panacea Combustible", font=("Arial", 14, "bold"), fg="#851f18").pack(pady=(10, 0))
        web_label = Label(root, text="https://www.panaceast.com/", fg="#927E63", cursor="hand2")
        web_label.pack()
        web_label.bind("<Button-1>", lambda e: webbrowser.open("https://www.panaceast.com/"))
        Label(root, text="Fecha de inicio:").pack()
        cal_inicio = DateEntry(root, date_pattern="yyyy-mm-dd")
        cal_inicio.pack()
        Label(root, text="Fecha de fin:").pack()
        cal_fin = DateEntry(root, date_pattern="yyyy-mm-dd")
        cal_fin.pack()

        def guardar_fechas():
            nueva_fecha_inicio = cal_inicio.get_date().strftime("%Y-%m-%d")
            nueva_fecha_fin = cal_fin.get_date().strftime("%Y-%m-%d")
            root.destroy()

            if nueva_fecha_inicio and nueva_fecha_fin:
                env_path = resource_path(".env")
                try:
                    with open(env_path, "r") as f:
                        lineas = f.readlines()
                except FileNotFoundError:
                    lineas = []
                modificada_inicio = False
                modificada_fin = False
                with open(env_path, "w") as f:
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
                # Ejecuta sincronización manual solo una vez con las fechas del .env
                modo_manual()

        Button(root, text="Guardar", command=guardar_fechas, bg="#1e90ff", fg="white").pack(pady=10)
        root.mainloop()
    except Exception as e:
        logger.exception("Error al editar el rango de fechas manualmente")

def editar_configuracion_env(icon, item):
    # Lanza la ventana de edición en un proceso aparte
    import subprocess
    python_exe = sys.executable
    script_path = resource_path("edit_env_window.py")
    subprocess.Popen([python_exe, script_path])

def abrir_dialogo():
    try:
        from tkinter import Tk, Label, Entry, Button, StringVar, messagebox

        env_path = resource_path(".env")
        # Valores por defecto
        valores = {
            "SAMSARA_API_TOKEN": "",
            "DATABASE_URL": "",
            "INTERVAL": ""
        }
        # Leer valores actuales
        try:
            with open(env_path, "r", encoding="utf-8") as f:
                for linea in f:
                    for key in valores:
                        if linea.startswith(f"{key}="):
                            valores[key] = linea.strip().split("=", 1)[1]
        except FileNotFoundError:
            pass

        root = Tk()
        root.title("Editar configuración .env")
        root.geometry("500x220")
        root.resizable(False, False)

        Label(root, text="SAMSARA_API_TOKEN:").pack()
        token_var = StringVar(value=valores["SAMSARA_API_TOKEN"])
        Entry(root, textvariable=token_var, width=60).pack()

        Label(root, text="DATABASE_URL:").pack()
        db_var = StringVar(value=valores["DATABASE_URL"])
        Entry(root, textvariable=db_var, width=60).pack()

        Label(root, text="INTERVAL (minutos):").pack()
        interval_var = StringVar(value=valores["INTERVAL"])
        Entry(root, textvariable=interval_var, width=20).pack()

        def guardar():
            nuevos = {
                "SAMSARA_API_TOKEN": token_var.get().strip(),
                "DATABASE_URL": db_var.get().strip(),
                "INTERVAL": interval_var.get().strip()
            }
            # Leer todas las líneas y reemplazar solo los campos editados
            try:
                try:
                    with open(env_path, "r", encoding="utf-8") as f:
                        lineas = f.readlines()
                except FileNotFoundError:
                    lineas = []
                claves_actualizadas = set()
                with open(env_path, "w", encoding="utf-8") as f:
                    for linea in lineas:
                        escrito = False
                        for key, val in nuevos.items():
                            if linea.startswith(f"{key}="):
                                f.write(f"{key}={val}\n")
                                claves_actualizadas.add(key)
                                escrito = True
                                break
                        if not escrito:
                            f.write(linea)
                    # Si algún campo no estaba, lo agregamos
                    for key, val in nuevos.items():
                        if key not in claves_actualizadas:
                            f.write(f"{key}={val}\n")
                messagebox.showinfo("Éxito", "Configuración guardada correctamente.")
                root.destroy()
            except Exception as e:
                messagebox.showerror("Error", f"No se pudo guardar la configuración:\n{e}")

        Button(root, text="Guardar", command=guardar, bg="#1e90ff", fg="white").pack(pady=10)
        root.mainloop()
    except Exception as e:
        logger.exception("Error al editar configuración .env")

def quit_action(icon, item):
    global running
    logger.info("Cierre solicitado por el usuario.")
    running = False
    icon.stop()
    sys.exit(0)

def create_image():
    return Image.open(resource_path("icon.ico"))

# Menú del systray con identidad Panacea
menu = Menu(
    MenuItem("Ver log", show_log),
    MenuItem("Sincronizar ahora", sync_now),
    MenuItem("Pausar", toggle_pause),
    MenuItem("Mostrar estado", show_status),
    MenuItem("Editar fecha manual", editar_fecha_manual),
    MenuItem("Editar configuración .env", editar_configuracion_env),  # <-- aquí
    MenuItem("Acerca de Panacea", show_about),
    MenuItem("Salir", quit_action)
)

# Iniciar scheduler y lanzar ícono
start_scheduler()
icon = Icon("PanaceaSync", create_image(), "Panacea Combustible", menu)
logger.info("Icono cargado y systray en ejecución.")
icon.run()
