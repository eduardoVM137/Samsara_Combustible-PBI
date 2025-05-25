import os
import psycopg2
from psycopg2.extensions import ISOLATION_LEVEL_AUTOCOMMIT
from dotenv import load_dotenv
import winshell
import pythoncom  

load_dotenv()

DB_NAME = os.getenv("DB_NAME", "orange_pbi")
DB_USER = os.getenv("DB_USER", "postgres")
DB_PASSWORD = os.getenv("DB_PASSWORD", "admin1234")
DB_HOST = os.getenv("DB_HOST", "localhost")
DB_PORT = os.getenv("DB_PORT", "5432")
EXE_PATH = os.getenv("EXE_PATH", os.path.abspath("systray_launcher_enhanced.exe"))

def init_database():
    try:
        conn = psycopg2.connect(
            dbname="postgres",
            user=DB_USER,
            password=DB_PASSWORD,
            host=DB_HOST,
            port=DB_PORT
        )
        conn.set_isolation_level(ISOLATION_LEVEL_AUTOCOMMIT)

        with conn.cursor() as cur:
            cur.execute("SELECT 1 FROM pg_database WHERE datname = %s", (DB_NAME,))
            exists = cur.fetchone()

            if exists:
                print(f"[OK] La base de datos '{DB_NAME}' ya existe.")
            else:
                print(f"[CREANDO] Base de datos '{DB_NAME}'...")
                cur.execute(f"CREATE DATABASE {DB_NAME} OWNER {DB_USER}")
                print(f"[OK] Base de datos '{DB_NAME}' creada.")

        conn.close()
    except Exception as e:
        print(f"[ERROR] No se pudo verificar/crear la base de datos: {e}")

def create_tables():
    def tabla_existe(cur, nombre):
        cur.execute("""
            SELECT EXISTS (
                SELECT FROM information_schema.tables 
                WHERE table_schema = 'public' AND table_name = %s
            );
        """, (nombre,))
        return cur.fetchone()[0]

    try:
        conn = psycopg2.connect(
            dbname=DB_NAME,
            user=DB_USER,
            password=DB_PASSWORD,
            host=DB_HOST,
            port=DB_PORT
        )
        with conn.cursor() as cur:
            tablas = ['vehicles', 'reporte_combustible', 'vehicle_fuel_stats', 'vehicle_data_sync']
            for tabla in tablas:
                if tabla_existe(cur, tabla):
                    print(f"[OK] Tabla '{tabla}' ya existe.")

            cur.execute("""
                CREATE TABLE IF NOT EXISTS vehicles (
                    id TEXT PRIMARY KEY,
                    vin TEXT,
                    name TEXT,
                    license_plate TEXT,
                    make TEXT,
                    model TEXT,
                    year INT,
                    tank_capacity_liters NUMERIC(6,2)
                );
            """)

            cur.execute("""
                CREATE TABLE IF NOT EXISTS reporte_combustible (
                    id SERIAL PRIMARY KEY,
                    vehiculo_id TEXT REFERENCES vehicles(id),
                    fecha_reporte DATE NOT NULL,
                    litros_totales NUMERIC(10,2),
                    kilometros_recorridos NUMERIC(10,2),
                    rendimiento_km_por_litro NUMERIC(10,2),
                    costo_combustible_usd NUMERIC(10,2),
                    tiempo_motor_s INTEGER,
                    tiempo_ralenti_s INTEGER,
                    creado_el TIMESTAMPTZ DEFAULT NOW(),
                    UNIQUE(vehiculo_id, fecha_reporte)
                );
            """)

            cur.execute("""
                CREATE TABLE IF NOT EXISTS vehicle_data_sync (
                    vehicle_id TEXT REFERENCES vehicles(id),
                    data_type TEXT NOT NULL,
                    last_synced_at TIMESTAMP WITHOUT TIME ZONE,
                    PRIMARY KEY(vehicle_id, data_type)
                );
            """)

            cur.execute("""
                CREATE TABLE IF NOT EXISTS vehicle_fuel_stats (
                    id SERIAL PRIMARY KEY,
                    vehiculo_id TEXT REFERENCES vehicles(id),
                    fecha_hora TIMESTAMP WITHOUT TIME ZONE NOT NULL,
                    porcentaje_combustible NUMERIC(5,2),
                    litros_consumidos NUMERIC(10,2),
                    distance_meters NUMERIC(10,2),
                    efficiency_km_l NUMERIC(10,4),
                    latitud NUMERIC(9,6),
                    longitud NUMERIC(9,6),
                    litros_recargados NUMERIC(10,2),
                    porcentaje_recargado NUMERIC(5,2),
                    es_evento_recarga BOOLEAN,
                    UNIQUE(vehiculo_id, fecha_hora)
                );
            """)

        conn.commit()
        conn.close()
        print("[OK] Tablas creadas/verificadas correctamente.")
    except Exception as e:
        print(f"[ERROR] Al crear/verificar tablas: {e}")
def agregar_inicio_startup(nombre_app="PanaceaCombustible", ruta_exe=EXE_PATH):
    try:
        pythoncom.CoInitialize()
        startup_dir = winshell.startup()
        acceso_directo = os.path.join(startup_dir, f"{nombre_app}.lnk")

        if not os.path.exists(acceso_directo):
            with winshell.shortcut(acceso_directo) as acceso:
                acceso.path = ruta_exe
                acceso.description = "Inicio automático de Panacea"
                acceso.working_directory = os.path.dirname(ruta_exe)
            print(f"[OK] Acceso directo creado: {acceso_directo}")
        else:
            print(f"[INFO] Ya existe acceso en inicio: {acceso_directo}")
    except Exception as e:
        print(f"[ERROR] No se pudo crear el acceso directo en inicio: {e}")

if __name__ == "__main__":
    init_database()
    create_tables()
    agregar_inicio_startup()
