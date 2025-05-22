 # 📊 Sincronización de Combustible – Samsara API

Este módulo integra y sincroniza datos de combustible, eficiencia, ubicación y catálogo de vehículos desde la API de **Samsara**, almacenándolos en una base de datos PostgreSQL para su análisis posterior, por ejemplo en Power BI.

---

## ⚙️ Funcionalidades principales

| Función                                       | Descripción |
|----------------------------------------------|-------------|
| `sincronizar_catalogo_vehiculos()`           | Sincroniza vehículos activos en la flota desde Samsara. |
| `obtener_estadisticas_combustible()`         | Descarga registros individuales de combustible (`fuelPercents`). |
| `procesar_estadistica()`                     | Guarda eventos de consumo o recarga en `vehicle_fuel_stats`. |
| `sincronizar_reporte_resumen_combustible()`  | Descarga resumen diario de consumo por vehículo desde `/fuel-energy`. |

---

## 🗃️ Tablas utilizadas

### 📌 `vehicles`
Catálogo general de unidades.

### 📌 `vehicle_fuel_stats`
Registros puntuales con variaciones de combustible.

| Campo (Español)             | Descripción                     |
|-----------------------------|---------------------------------|
| `vehiculo_id`               | ID del vehículo                 |
| `fecha_hora`                | Timestamp de registro           |
| `porcentaje_combustible`   | % de combustible en ese momento |
| `litros_consumidos`        | Litros consumidos               |
| `litros_recargados`        | Litros recargados               |
| `es_evento_recarga`        | Si el evento fue una recarga    |
| `latitud`, `longitud`      | Posición GPS                    |

### 📌 `reporte_combustible`
Resumen diario de cada vehículo.

| Campo (Español)                | Descripción                         |
|--------------------------------|-------------------------------------|
| `vehiculo_id`                  | ID de unidad                        |
| `fecha_reporte`                | Fecha del resumen                   |
| `litros_totales`              | Litros consumidos                   |
| `kilometros_recorridos`       | Kilómetros recorridos               |
| `rendimiento_km_por_litro`     | Rendimiento                         |
| `costo_combustible_usd`       | Costo estimado                      |
| `tiempo_motor_s`, `ralenti_s` | Tiempo encendido y ralentí (seg)    |

---

## 🔁 Equivalencia de nombres

| Inglés                    | Español                    |
|---------------------------|-----------------------------|
| `vehicle_id`              | `vehiculo_id`              |
| `timestamp`               | `fecha_hora`               |
| `fuel_percent`            | `porcentaje_combustible`   |
| `fuelConsumedMl`          | `litros_totales`           |
| `distanceTraveledMeters`  | `kilometros_recorridos`    |
| `refueled_liters`         | `litros_recargados`        |
| `fuel_consumed_liters`    | `litros_consumidos`        |
| `efficiency_km_l`         | `rendimiento_km_por_litro` |
| `engineRunTimeDurationMs` | `tiempo_motor_s`           |
| `engineIdleTimeDurationMs`| `tiempo_ralenti_s`         |

---

## ✅ Evita duplicados

- `vehicle_fuel_stats`: usa `(vehiculo_id, fecha_hora)` como clave única.
- `reporte_combustible`: evita repetir `vehiculo_id + fecha_reporte`.

---

## 🧪 Ejemplo de ejecución manual

```python
from api.samsara_client import sincronizar_reporte_resumen_combustible

sincronizar_reporte_resumen_combustible(
    "2025-05-01T00:00:00Z",
    "2025-05-01T23:59:59Z"
)
