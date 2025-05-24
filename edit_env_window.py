import sys
import os
from tkinter import Tk, Label, Entry, Button, StringVar, messagebox

def resource_path(relative_path):
    if hasattr(sys, '_MEIPASS'):
        return os.path.join(sys._MEIPASS, relative_path)
    return os.path.join(os.path.abspath("."), relative_path)

def main():
    env_path = resource_path(".env")
    valores = {
        "SAMSARA_API_TOKEN": "",
        "DATABASE_URL": "",
        "INTERVAL": ""
    }
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
                for key, val in nuevos.items():
                    if key not in claves_actualizadas:
                        f.write(f"{key}={val}\n")
            messagebox.showinfo("Éxito", "Configuración guardada correctamente.")
            root.destroy()
        except Exception as e:
            messagebox.showerror("Error", f"No se pudo guardar la configuración:\n{e}")

    Button(root, text="Guardar", command=guardar, bg="#1e90ff", fg="white").pack(pady=10)
    root.mainloop()

if __name__ == "__main__":
    main()