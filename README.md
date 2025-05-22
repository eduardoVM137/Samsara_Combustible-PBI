# Samsara Combustible

Este proyecto sincroniza datos de combustible de la API de Samsara, almacenando:

- Eventos de consumo y recarga (`vehicle_fuel_stats`)
- Resúmenes diarios por vehículo (`reporte_combustible`)
- Catálogo de vehículos (`vehicles`)

## 🧩 Componentes principales

- **samsara_client.py** – Módulo principal que contiene:
  - `sincronizar_catalogo_vehiculos`: Inserta los vehículos si no existen.
  - `obtener_estadisticas_combustible`: Obtiene `fuelPercents` y guarda eventos.
  - `procesar_estadistica`: Guarda cada cambio significativo de nivel de combustible.
  - `sincronizar_reporte_resumen_combustible`: Descarga resúmenes desde `/fuel-energy`.
  - `limpiar_y_actualizar_fuel_stats_dia_anterior`: Elimina registros del día anterior y los actualiza.
  - `recalcular_resumen_combustible_dia_menos_3`: Vuelve a insertar resúmenes de hace 3 días.
  - `sincronizar_eventos_combustible`: Ejecuta ambos procesos anteriores juntos.

- **sync_scheduler.py** – Ejecuta automáticamente la sincronización cada X minutos.
- **db/database.py** – Conexión a PostgreSQL y utilidades.
- **utils/logger.py** – Logger de eventos.

## 🗃️ Tablas involucradas

| Tabla                  | Descripción |
|------------------------|-------------|
| `vehicles`             | Vehículos registrados. |
| `vehicle_fuel_stats`   | Cambios de nivel de combustible por timestamp. |
| `reporte_combustible`  | Resumen diario por vehículo. |
| `vehicle_data_sync`    | Marca el último punto sincronizado. |

## ⚙️ .env requerido

```env
SAMSARA_API_TOKEN=tu_token
INTERVAL=5
