# Backend de Conversión S10 (.S2K / .BAK) a JSON — Opción B

Este microservicio backend permite a la aplicación móvil **VFCOST** recibir directamente archivos de copia de seguridad binaria de **S10 Costos y Presupuestos (.S2K o .BAK)**, restaurarlos dinámicamente en Microsoft SQL Server mediante Docker, extraer toda la estructura relacional (presupuestos, subpresupuestos, partidas, APUs e insumos) y devolver un JSON estructurado listo para ser guardado y operado de forma 100% offline en el celular.

---

## 🏗️ Arquitectura de la Opción B

```
[ App Android VFCOST ]
       │
       │ 1. Sube archivo .S2K / .BAK vía Multipart POST
       ▼
[ Backend FastAPI :8000 ]
       │
       │ 2. Guarda temporalmente el archivo
       ▼
[ Contenedor SQL Server 2022 :1433 ]
       │ 3. RESTORE FILELISTONLY (Detecta nombres lógicos)
       │ 4. RESTORE DATABASE TempDB FROM DISK = '/tmp/...' WITH MOVE ...
       │ 5. SELECT de Presupuesto, SubPresupuesto, Partidas, APUs
       │ 6. DROP DATABASE TempDB (Limpieza inmediata)
       ▼
[ Backend FastAPI ]
       │ 7. Devuelve JSON estructurado
       ▼
[ App Android VFCOST ]
       │ 8. Guarda en SQLite/SharedPreferences local para trabajo en obra offline
```

---

## 🚀 Puesta en Marcha con Docker (1 solo comando)

En la carpeta `server/`:

```bash
docker compose up -d
```

Esto levantará automáticamente:
1. `s10_mssql_server`: Microsoft SQL Server 2022 oficial en Linux.
2. `s10_converter_api`: API FastAPI en `http://localhost:8000`.

### Verificar estado del servidor:
Abrir en el navegador o ejecutar:
```bash
curl http://localhost:8000/api/health
```

Respuesta esperada:
```json
{
  "status": "online",
  "service": "VFCOST S10 Cloud Converter",
  "version": "1.0.0",
  "mssql_connected": true,
  "mssql_host": "mssql"
}
```

---

## 🌐 Configuración en la App Android

1. En la app móvil, pulsar en **"Importar Backup S10 (.S2K)"**.
2. Por defecto se conecta a `http://10.0.2.2:8000` (dirección IP de la PC host desde el emulador Android).
3. Si estás probando en un teléfono físico conectado por Wi-Fi, pulsa el ícono de engranaje (⚙️) y cambia la URL a la IP de tu computadora (ej: `http://192.168.1.50:8000`).
4. Si está desplegado en un servidor en la nube (AWS, DigitalOcean, Google Cloud, Render, Railway), ingresa el dominio público (ej: `https://s10.tuempresa.com`).
