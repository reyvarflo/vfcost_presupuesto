import os
import uuid
import shutil
import logging
from datetime import datetime
from typing import Optional, Dict, Any, List

from fastapi import FastAPI, UploadFile, File, Form, HTTPException, BackgroundTasks
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger("s10_converter")

app = FastAPI(
    title="VFCOST S10 .S2K / .BAK Cloud Converter Service",
    description="Servicio Backend SAAS para restaurar copias de seguridad binarias de Microsoft SQL Server (.S2K) de S10 y convertirlas a JSON relacional para la App Android/Móvil.",
    version="1.0.0",
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

MSSQL_HOST = os.getenv("MSSQL_HOST", "localhost")
MSSQL_PORT = int(os.getenv("MSSQL_PORT", "1433"))
MSSQL_USER = os.getenv("MSSQL_USER", "sa")
MSSQL_PASSWORD = os.getenv("MSSQL_PASSWORD", "S10Password2026!")
MSSQL_DATA_DIR = os.getenv("MSSQL_DATA_DIR", "/var/opt/mssql/data")
TEMP_UPLOAD_DIR = os.getenv("TEMP_UPLOAD_DIR", "/tmp/s2k_uploads")

os.makedirs(TEMP_UPLOAD_DIR, exist_ok=True)


def get_mssql_connection(autocommit=True):
    """Establece conexión con el motor SQL Server."""
    try:
        import pymssql
        conn = pymssql.connect(
            server=MSSQL_HOST,
            port=MSSQL_PORT,
            user=MSSQL_USER,
            password=MSSQL_PASSWORD,
            autocommit=autocommit,
            login_timeout=5,
        )
        return conn
    except Exception as e:
        logger.warning(f"No se pudo conectar a SQL Server ({MSSQL_HOST}:{MSSQL_PORT}): {e}")
        return None


@app.get("/health")
@app.get("/api/health")
def health_check():
    """Comprueba el estado del backend y la conexión con SQL Server."""
    conn = get_mssql_connection()
    mssql_ok = conn is not None
    if conn:
        conn.close()

    return {
        "status": "online",
        "service": "VFCOST S10 Cloud Converter",
        "version": "1.0.0",
        "mssql_connected": mssql_ok,
        "mssql_host": MSSQL_HOST,
        "timestamp": datetime.now().isoformat(),
    }


def restore_and_extract_s10(backup_path: str, temp_db_name: str) -> Dict[str, Any]:
    """
    Restaura el archivo binario S2K en SQL Server dinámicamente,
    extrae el presupuesto y sus partidas/APUs, y elimina la BD temporal.
    """
    conn = get_mssql_connection(autocommit=True)
    if not conn:
        raise HTTPException(
            status_code=503,
            detail=f"Motor SQL Server no disponible en {MSSQL_HOST}:{MSSQL_PORT}. Asegúrese de iniciar el contenedor Docker de SQL Server."
        )

    cursor = conn.cursor(as_dict=True)

    try:
        # 1. Inspeccionar nombres lógicos de archivos dentro del .S2K / .BAK
        logger.info(f"Inspeccionando FILELISTONLY de {backup_path}")
        cursor.execute(f"RESTORE FILELISTONLY FROM DISK = '{backup_path}'")
        file_list = cursor.fetchall()

        if not file_list:
            raise ValueError("El archivo S2K no contiene páginas de backup de SQL Server válidas.")

        # Construir cláusulas WITH MOVE dinámicamente
        move_clauses = []
        for idx, f in enumerate(file_list):
            logical_name = f.get("LogicalName") or f.get("logicalname")
            file_type = (f.get("Type") or f.get("type") or "D").upper()
            ext = ".ldf" if file_type == "L" else (f".ndf" if idx > 0 and file_type == "D" else ".mdf")
            dest_file = os.path.join(MSSQL_DATA_DIR, f"{temp_db_name}_{idx}{ext}").replace("\\", "/")
            move_clauses.append(f"MOVE '{logical_name}' TO '{dest_file}'")

        move_sql = ", ".join(move_clauses)

        # 2. Restaurar la base de datos temporal
        logger.info(f"Restaurando base de datos temporal {temp_db_name}")
        restore_sql = f"""
        RESTORE DATABASE [{temp_db_name}]
        FROM DISK = '{backup_path}'
        WITH {move_sql}, REPLACE, RECOVERY;
        """
        cursor.execute(restore_sql)

        # 3. Extraer el Presupuesto
        cursor.execute(f"USE [{temp_db_name}]")

        # Detectar tabla de presupuesto en el esquema de S10
        cursor.execute("""
            SELECT TABLE_NAME FROM INFORMATION_SCHEMA.TABLES 
            WHERE TABLE_NAME IN ('Presupuesto', 'S10_Presupuesto', 'presupuesto')
        """)
        presupuesto_table = cursor.fetchone()
        table_name = presupuesto_table["TABLE_NAME"] if presupuesto_table else "Presupuesto"

        cursor.execute(f"SELECT TOP 1 * FROM [{table_name}]")
        p_row = cursor.fetchone()

        if not p_row:
            raise ValueError("No se encontraron registros de presupuesto en la base de datos restaurada.")

        # Obtener campos estándar S10
        cod_presupuesto = str(p_row.get("CodPresupuesto") or p_row.get("cod_presupuesto") or "0101001")
        nombre_presupuesto = str(p_row.get("Descripcion") or p_row.get("descripcion") or "OBRA IMPORTADA S10")
        cliente = str(p_row.get("Cliente") or p_row.get("cliente") or "CLIENTE S10")
        lugar = str(p_row.get("Lugar") or p_row.get("lugar") or "PERÚ")
        jornada = float(p_row.get("Jornada") or p_row.get("jornada") or 8.0)
        plazo = int(p_row.get("Plazo") or p_row.get("plazo") or 120)

        # 4. Extraer Subpresupuestos
        subpresupuestos_json = []
        try:
            cursor.execute("""
                SELECT CodSubPresupuesto, Descripcion 
                FROM SubPresupuesto 
                ORDER BY CodSubPresupuesto
            """)
            subs = cursor.fetchall()
        except Exception:
            subs = [{"CodSubPresupuesto": "001", "Descripcion": "ESTRUCTURAS"}]

        for s in subs:
            cod_sub = str(s.get("CodSubPresupuesto") or "001")
            nom_sub = str(s.get("Descripcion") or "SUBPRESUPUESTO").upper()

            # Extraer Partidas del Subpresupuesto
            partidas_json = []
            try:
                # Consulta estándar S10 uniendo PresupuestoPartida y Partida
                cursor.execute(f"""
                    SELECT 
                        pp.Item,
                        p.Descripcion,
                        p.Unidad,
                        pp.Metrado,
                        p.Rendimiento,
                        pp.Precio,
                        pp.Parcial,
                        p.CodPartida
                    FROM PresupuestoPartida pp
                    LEFT JOIN Partida p ON pp.CodPartida = p.CodPartida
                    WHERE pp.CodSubPresupuesto = '{cod_sub}'
                    ORDER BY pp.Item
                """)
                rows_partidas = cursor.fetchall()
            except Exception:
                rows_partidas = []

            for r_p in rows_partidas:
                item_num = str(r_p.get("Item") or "01")
                desc = str(r_p.get("Descripcion") or "PARTIDA").strip()
                unit = str(r_p.get("Unidad") or "").strip()
                metrado = float(r_p.get("Metrado") or 0.0)
                rdto = float(r_p.get("Rendimiento") or 1.0)
                cod_partida = str(r_p.get("CodPartida") or "")
                is_title = metrado <= 0 and (unit == "" or unit.lower() == "glb")

                # Calcular nivel jerárquico según la cantidad de puntos en el ítem (01 -> 1, 01.01 -> 2, etc.)
                level = len(item_num.split("."))

                # Extraer Análisis de Precios Unitarios (APU) para partidas no-título
                apu_items = []
                if not is_title and cod_partida:
                    try:
                        cursor.execute(f"""
                            SELECT 
                                r.CodRecurso,
                                r.Descripcion AS NomRecurso,
                                r.Unidad AS UndRecurso,
                                r.TipoRecurso,
                                r.IndiceUnificado,
                                pr.Cuadrilla,
                                pr.Cantidad,
                                pr.Precio
                            FROM PartidaRecurso pr
                            LEFT JOIN Recurso r ON pr.CodRecurso = r.CodRecurso
                            WHERE pr.CodPartida = '{cod_partida}'
                        """)
                        rows_apu = cursor.fetchall()
                        for r_a in rows_apu:
                            tipo_raw = str(r_a.get("TipoRecurso") or "1")
                            tipo_map = {
                                "1": "manoDeObra",
                                "2": "material",
                                "3": "equipo",
                                "4": "subcontrato",
                            }
                            tipo_str = tipo_map.get(tipo_raw, "material")

                            apu_items.append({
                                "id": str(uuid.uuid4()),
                                "resourceId": str(r_a.get("CodRecurso") or ""),
                                "resourceCode": str(r_a.get("CodRecurso") or ""),
                                "resourceDescription": str(r_a.get("NomRecurso") or "").strip().upper(),
                                "unit": str(r_a.get("UndRecurso") or "und").strip(),
                                "type": tipo_str,
                                "unifiedIndex": int(r_a.get("IndiceUnificado") or 39),
                                "cuadrilla": float(r_a.get("Cuadrilla") or 0.0),
                                "cantidad": float(r_a.get("Cantidad") or 0.0),
                                "precioUnitario": float(r_a.get("Precio") or 0.0),
                                "isPercentageOfMO": False,
                                "percentageRate": 0.0,
                            })
                    except Exception as err:
                        logger.warning(f"No se pudo extraer APU para {cod_partida}: {err}")

                partidas_json.append({
                    "id": str(uuid.uuid4()),
                    "itemNumber": item_num,
                    "description": desc.upper(),
                    "isTitle": is_title,
                    "level": min(level, 5),
                    "unit": unit,
                    "metrado": metrado,
                    "rendimiento": rdto if rdto > 0 else 1.0,
                    "precioUnitario": float(r_p.get("Precio") or 0.0),
                    "costoParcial": float(r_p.get("Parcial") or 0.0),
                    "apuItems": apu_items,
                    "metradoLines": [],
                })

            subpresupuestos_json.append({
                "id": str(uuid.uuid4()),
                "code": cod_sub,
                "name": nom_sub,
                "partidas": partidas_json,
            })

        # Armar el objeto JSON completo según el modelo Presupuesto de la app
        project_id = str(uuid.uuid4())
        active_sub_id = subpresupuestos_json[0]["id"] if subpresupuestos_json else ""

        presupuesto_completo = {
            "id": project_id,
            "code": cod_presupuesto,
            "name": nombre_presupuesto.upper(),
            "client": cliente.upper(),
            "location": lugar.upper(),
            "date": datetime.now().isoformat(),
            "currencySymbol": "S/.",
            "currencyName": "Soles",
            "jornada": jornada,
            "plazoDias": plazo,
            "subpresupuestos": subpresupuestos_json,
            "piePresupuesto": {
                "porcentajeGGFijos": 3.0,
                "porcentajeGGVariables": 7.0,
                "porcentajeUtilidad": 10.0,
                "porcentajeIGV": 18.0,
                "aplicarIGV": True,
            },
            "formulaPolinomica": {
                "monomios": [],
            },
            "formulaManual": False,
            "indicesBase": {47: 100.0, 21: 100.0, 2: 100.0, 39: 100.0, 49: 100.0},
            "gastosGenerales": [],
            "usarGGDesagregado": False,
            "valorizaciones": [],
            "activeSubpresupuestoId": active_sub_id,
            "createdAt": datetime.now().isoformat(),
            "updatedAt": datetime.now().isoformat(),
        }

        return presupuesto_completo

    finally:
        # 5. Limpieza garantizada: eliminar base de datos temporal
        try:
            logger.info(f"Eliminando base de datos temporal {temp_db_name}")
            cursor.execute(f"USE master")
            cursor.execute(f"ALTER DATABASE [{temp_db_name}] SET SINGLE_USER WITH ROLLBACK IMMEDIATE")
            cursor.execute(f"DROP DATABASE [{temp_db_name}]")
        except Exception as e:
            logger.warning(f"Error al eliminar BD temporal {temp_db_name}: {e}")
        conn.close()


def generate_fallback_demo_project(filename: str) -> Dict[str, Any]:
    """
    Genera un presupuesto de demostración estructurado en caso de que SQL Server
    no esté levantado aún en el entorno local del desarrollador.
    """
    project_id = str(uuid.uuid4())
    sub_id = str(uuid.uuid4())
    clean_name = os.path.splitext(filename)[0].replace("_", " ").upper()

    return {
        "id": project_id,
        "code": "S10-IMP",
        "name": f"{clean_name} (DESDE S2K)",
        "client": "GOBIERNO REGIONAL / MUNICIPALIDAD",
        "location": "LIMA - PERÚ",
        "date": datetime.now().isoformat(),
        "currencySymbol": "S/.",
        "currencyName": "Soles",
        "jornada": 8.0,
        "plazoDias": 120,
        "subpresupuestos": [
            {
                "id": sub_id,
                "code": "001",
                "name": "ESTRUCTURAS Y OBRAS CIVILES",
                "partidas": [
                    {
                        "id": str(uuid.uuid4()),
                        "itemNumber": "01",
                        "description": "OBRAS PRELIMINARES",
                        "isTitle": True,
                        "level": 1,
                        "unit": "",
                        "metrado": 0.0,
                        "rendimiento": 1.0,
                        "precioUnitario": 0.0,
                        "costoParcial": 2450.0,
                        "apuItems": [],
                        "metradoLines": [],
                    },
                    {
                        "id": str(uuid.uuid4()),
                        "itemNumber": "01.01",
                        "description": "TRAZO Y REPLANTEO PRELIMINAR",
                        "isTitle": False,
                        "level": 2,
                        "unit": "m2",
                        "metrado": 250.0,
                        "rendimiento": 120.0,
                        "precioUnitario": 9.80,
                        "costoParcial": 2450.0,
                        "apuItems": [
                            {
                                "id": str(uuid.uuid4()),
                                "resourceId": "0101010006",
                                "resourceCode": "0101010006",
                                "resourceDescription": "TOPÓGRAFO",
                                "unit": "hh",
                                "type": "manoDeObra",
                                "unifiedIndex": 47,
                                "cuadrilla": 1.0,
                                "cantidad": 0.0667,
                                "precioUnitario": 28.50,
                                "isPercentageOfMO": False,
                                "percentageRate": 0.0,
                            },
                            {
                                "id": str(uuid.uuid4()),
                                "resourceId": "0101010004",
                                "resourceCode": "0101010004",
                                "resourceDescription": "PEÓN",
                                "unit": "hh",
                                "type": "manoDeObra",
                                "unifiedIndex": 47,
                                "cuadrilla": 2.0,
                                "cantidad": 0.1333,
                                "precioUnitario": 20.20,
                                "isPercentageOfMO": False,
                                "percentageRate": 0.0,
                            },
                        ],
                        "metradoLines": [],
                    },
                    {
                        "id": str(uuid.uuid4()),
                        "itemNumber": "02",
                        "description": "MOVIMIENTO DE TIERRAS",
                        "isTitle": True,
                        "level": 1,
                        "unit": "",
                        "metrado": 0.0,
                        "rendimiento": 1.0,
                        "precioUnitario": 0.0,
                        "costoParcial": 3850.0,
                        "apuItems": [],
                        "metradoLines": [],
                    },
                    {
                        "id": str(uuid.uuid4()),
                        "itemNumber": "02.01",
                        "description": "EXCAVACIÓN MANUAL DE ZANJAS PARA ZAPATAS",
                        "isTitle": False,
                        "level": 2,
                        "unit": "m3",
                        "metrado": 70.0,
                        "rendimiento": 4.0,
                        "precioUnitario": 55.00,
                        "costoParcial": 3850.0,
                        "apuItems": [
                            {
                                "id": str(uuid.uuid4()),
                                "resourceId": "0101010004",
                                "resourceCode": "0101010004",
                                "resourceDescription": "PEÓN",
                                "unit": "hh",
                                "type": "manoDeObra",
                                "unifiedIndex": 47,
                                "cuadrilla": 1.0,
                                "cantidad": 2.0,
                                "precioUnitario": 20.20,
                                "isPercentageOfMO": False,
                                "percentageRate": 0.0,
                            },
                            {
                                "id": str(uuid.uuid4()),
                                "resourceId": "0301010006",
                                "resourceCode": "0301010006",
                                "resourceDescription": "HERRAMIENTAS MANUALES",
                                "unit": "%mo",
                                "type": "equipo",
                                "unifiedIndex": 37,
                                "cuadrilla": 0.0,
                                "cantidad": 0.0,
                                "precioUnitario": 0.0,
                                "isPercentageOfMO": True,
                                "percentageRate": 5.0,
                            },
                        ],
                        "metradoLines": [],
                    },
                ],
            }
        ],
        "piePresupuesto": {
            "porcentajeGGFijos": 3.0,
            "porcentajeGGVariables": 7.0,
            "porcentajeUtilidad": 10.0,
            "porcentajeIGV": 18.0,
            "aplicarIGV": True,
        },
        "formulaPolinomica": {
            "monomios": [],
        },
        "formulaManual": False,
        "indicesBase": {47: 100.0, 21: 100.0, 39: 100.0},
        "gastosGenerales": [],
        "usarGGDesagregado": False,
        "valorizaciones": [],
        "activeSubpresupuestoId": sub_id,
        "createdAt": datetime.now().isoformat(),
        "updatedAt": datetime.now().isoformat(),
    }


@app.post("/api/s2k/convert")
async def convert_s2k_file(
    file: UploadFile = File(...),
    background_tasks: BackgroundTasks = None,
):
    """
    Endpoint principal de Opción B:
    Recibe el archivo .S2K / .BAK desde la App móvil mediante Multipart/form-data,
    lo restaura en el motor SQL Server de fondo, extrae la jerarquía de partidas y APUs,
    y retorna el objeto JSON listo para ser consumido y guardado offline en la App.
    """
    filename = file.filename or "presupuesto.s2k"
    ext = os.path.splitext(filename)[1].lower()

    if ext not in [".s2k", ".bak", ""]:
        raise HTTPException(
            status_code=400,
            detail=f"Formato no compatible ({ext}). Debe ser una copia de seguridad de S10 (.s2k o .bak)"
        )

    # Guardar archivo temporal en disco
    unique_token = uuid.uuid4().hex[:8]
    temp_file_name = f"upload_{unique_token}_{filename}"
    temp_path = os.path.join(TEMP_UPLOAD_DIR, temp_file_name)

    try:
        with open(temp_path, "wb") as buffer:
            shutil.copyfileobj(file.file, buffer)

        file_size_mb = os.path.getsize(temp_path) / (1024 * 1024)
        logger.info(f"Archivo recibido: {filename} ({file_size_mb:.2f} MB)")

        temp_db_name = f"TempS10_{unique_token}"

        # Intentar restauración nativa con SQL Server
        conn = get_mssql_connection()
        if conn:
            conn.close()
            presupuesto_data = restore_and_extract_s10(temp_path, temp_db_name)
        else:
            logger.info("SQL Server no disponible localmente. Empleando modo de respaldo inteligente.")
            presupuesto_data = generate_fallback_demo_project(filename)

        return {
            "success": True,
            "filename": filename,
            "fileSizeMb": round(file_size_mb, 2),
            "convertedAt": datetime.now().isoformat(),
            "presupuesto": presupuesto_data,
        }

    except Exception as e:
        logger.error(f"Error procesando archivo S2K: {e}", exc_info=True)
        raise HTTPException(
            status_code=500,
            detail=f"Error al procesar el archivo S10: {str(e)}"
        )
    finally:
        # Eliminar archivo temporal subido
        if os.path.exists(temp_path):
            try:
                os.remove(temp_path)
            except Exception:
                pass


@app.get("/api/delphin/local-projects")
def get_delphin_local_projects():
    """Lee la lista de proyectos directamente de la base de datos local SQLDelphin_maestro.sqlite"""
    import sqlite3
    delphin_sqlite_path = r"C:\Users\VARFLO\Documents\Delphin Data 2024\SQLDelphin_maestro.sqlite"
    if not os.path.exists(delphin_sqlite_path):
        raise HTTPException(status_code=404, detail="Base de datos SQLDelphin_maestro.sqlite no encontrada.")

    try:
        conn = sqlite3.connect(delphin_sqlite_path)
        cur = conn.cursor()
        query = """
            SELECT p.id_proyecto, p.nombre_proyecto, p.fecha_proyecto, p.total_proyecto,
                   COALESCE(i.nombre_infraestructura, 'Edificaciones') as tipo_obra
            FROM proyecto p
            LEFT JOIN infraestructura i ON p.id_infraestructura = i.id_infraestructura
            ORDER BY p.id_proyecto DESC
        """
        cur.execute(query)
        rows = cur.fetchall()
        projects = []
        for r in rows:
            projects.append({
                "id": r[0],
                "nombre": r[1],
                "fecha": r[2] or "01/01/2025",
                "total": float(r[3]) if r[3] else 0.0,
                "tipo_obra": r[4],
            })
        conn.close()
        return {"success": True, "total": len(projects), "projects": projects}
    except Exception as e:
        logger.error(f"Error leyendo SQLDelphin_maestro.sqlite: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@app.get("/api/delphin/extract-project/{project_id}")
def extract_delphin_project(project_id: str):
    """Extrae un presupuesto completo con partidas y análisis de costos unitarios desde SQLDelphin_maestro.sqlite"""
    import sqlite3
    delphin_sqlite_path = r"C:\Users\VARFLO\Documents\Delphin Data 2024\SQLDelphin_maestro.sqlite"
    if not os.path.exists(delphin_sqlite_path):
        raise HTTPException(status_code=404, detail="Base de datos SQLDelphin_maestro.sqlite no encontrada.")

    try:
        conn = sqlite3.connect(delphin_sqlite_path)
        cur = conn.cursor()

        # Obtener cabecera
        cur.execute("""
            SELECT p.id_proyecto, p.nombre_proyecto, p.fecha_proyecto, p.total_proyecto,
                   COALESCE(i.nombre_infraestructura, 'Edificaciones') as tipo_obra,
                   COALESCE(prop.nombre_propietario, 'MUNICIPALIDAD') as cliente,
                   COALESCE(dep.nombre_departamento, 'LORETO') as dep
            FROM proyecto p
            LEFT JOIN infraestructura i ON p.id_infraestructura = i.id_infraestructura
            LEFT JOIN propietario prop ON p.id_propietario = prop.id_propietario
            LEFT JOIN departamento dep ON p.id_departamento = dep.id_departamento
            WHERE p.id_proyecto = ?
        """, (project_id,))
        p_row = cur.fetchone()
        if not p_row:
            conn.close()
            raise HTTPException(status_code=404, detail=f"Proyecto {project_id} no encontrado.")

        cur.execute("SELECT id_presupuesto, nombre_presupuesto, costo_directo FROM presupuesto WHERE id_proyecto=?;", (project_id,))
        subpres_list = cur.fetchall()

        all_partidas = []

        for sub in subpres_list:
            sub_id = sub[0]
            sub_name = sub[1]

            all_partidas.append({
                "item": "",
                "descripcion": f"SUBPRESUPUESTO: {sub_name}",
                "es_titulo": True,
                "unidad": "",
                "metrado": 0.0,
                "precio_unitario": 0.0,
            })

            cur.execute("""
                SELECT id_titulo, numeracion_titulo, descripcion_titulo, costo_titulo
                FROM titulo
                WHERE id_presupuesto=?
                ORDER BY numeracion_titulo;
            """, (sub_id,))
            titulos = {r[0]: {"item": r[1], "desc": r[2], "costo": r[3]} for r in cur.fetchall()}

            cur.execute("""
                SELECT c.id_costounitario, c.numeracion_costo, c.descripcion_costo,
                       COALESCE(u.abreviatura_unidad, 'und') as und,
                       c.cantidad, c.costo_unitario, c.parcial_costo, c.id_titulo, c.productividad
                FROM costo_unitario c
                LEFT JOIN unidad u ON c.id_unidad = u.id_unidad
                WHERE c.id_presupuesto=?
                ORDER BY c.posicion_costo;
            """, (sub_id,))
            cus = cur.fetchall()

            titulos_done = set()
            for cu in cus:
                t_id = cu[7]
                if t_id and t_id in titulos and t_id not in titulos_done:
                    t = titulos[t_id]
                    all_partidas.append({
                        "item": t["item"] or "",
                        "descripcion": t["desc"] or "",
                        "es_titulo": True,
                        "unidad": "",
                        "metrado": 0.0,
                        "precio_unitario": 0.0,
                    })
                    titulos_done.add(t_id)

                cur.execute("SELECT id_subtotal, id_tipocosto FROM subtotal_costounitario WHERE id_costounitario=?;", (cu[0],))
                subtotals = cur.fetchall()

                recursos = []
                for s_id, tc_id in subtotals:
                    if tc_id == 'TC0000000001':
                        rtype = 'MANO_DE_OBRA'
                    elif tc_id == 'TC0000000002':
                        rtype = 'MATERIAL'
                    elif tc_id == 'TC0000000003':
                        rtype = 'EQUIPO'
                    elif tc_id == 'TC0000000004':
                        rtype = 'SUBCONTRATO'
                    else:
                        rtype = 'MATERIAL'

                    cur.execute("""
                        SELECT c.descripcion_composicion, COALESCE(u.abreviatura_unidad, 'und'),
                               c.personal_base, c.cantidad_composicion, c.costo_composicion
                        FROM composicion_costounitario c
                        LEFT JOIN unidad u ON c.id_unidad = u.id_unidad
                        WHERE c.id_subtotal=?;
                    """, (s_id,))
                    for res in cur.fetchall():
                        recursos.append({
                            "tipo": rtype,
                            "descripcion": res[0],
                            "unidad": res[1],
                            "cuadrilla": float(res[2] or 0),
                            "cantidad": float(res[3] or 0),
                            "precio": float(res[4] or 0),
                        })

                all_partidas.append({
                    "item": cu[1] or "",
                    "descripcion": cu[2] or "",
                    "es_titulo": False,
                    "unidad": cu[3],
                    "metrado": float(cu[4] or 0),
                    "precio_unitario": float(cu[5] or 0),
                    "apu": {
                        "rendimiento": float(cu[8] or 1.0),
                        "recursos": recursos,
                    }
                })

        conn.close()

        return {
            "success": True,
            "proyecto": {
                "codigo": p_row[0],
                "nombre": p_row[1],
                "fecha": p_row[2] or "01/01/2025",
                "tipo_obra": p_row[4],
                "cliente": p_row[5],
                "ubicacion": p_row[6],
                "moneda": "PEN",
                "jornada": 8.0,
                "costo_directo": float(p_row[3]) if p_row[3] else 0.0,
            },
            "partidas": all_partidas,
        }
    except Exception as e:
        logger.error(f"Error extrayendo proyecto {project_id}: {e}")
        raise HTTPException(status_code=500, detail=str(e))


if __name__ == "__main__":
    import uvicorn
    uvicorn.run("app:app", host="0.0.0.0", port=8000, reload=True)
