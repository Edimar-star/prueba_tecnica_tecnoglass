# Tecnoglass — Sistema de Trazabilidad de Producción

Sistema Fullstack para digitalizar y monitorear la línea de manufactura de ventanería.

---

## Stack Tecnológico

| Capa           | Tecnología                                        |
|----------------|---------------------------------------------------|
| Backend        | Python 3.11+ · FastAPI · Uvicorn                  |
| Frontend       | Angular 17+ · Standalone Components · Signals     |
| Base de datos  | SQL Server 2022 · Stored Procedures               |
| Autenticación  | JWT (python-jose · passlib/bcrypt)                |
| Infraestructura| Docker · Docker Compose · Nginx                   |

---

## Estructura del Repositorio

```
tecnoglass-produccion/
├── database/
│   ├── 01_DDL_tablas.sql          # Creación de BD y tablas
│   ├── 02_SP_produccion.sql       # Stored Procedures (12 SPs)
│   ├── 03_seed_data.sql           # Datos iniciales (estaciones + usuarios)
│   └── init.sh                    # Script de inicialización para uso local
├── backend/
│   ├── app/
│   │   ├── core/                  # config, seguridad JWT, conexión BD
│   │   ├── routers/               # auth, ordenes, ventanas, dashboard
│   │   ├── schemas/               # Modelos Pydantic (validación de entrada)
│   │   └── services/              # qr_service
│   ├── Dockerfile
│   ├── create_admin.py            # Script para crear usuarios con hash real
│   ├── requirements.txt
│   └── .env.example
└── frontend/
    ├── src/app/
    │   ├── core/                  # models, auth, interceptors, services
    │   ├── features/              # login, dashboard, ordenes, trazabilidad
    │   └── shared/                # navbar
    ├── nginx.conf.template        # Config Nginx con ${BACKEND_HOST} parametrizable
    └── Dockerfile
```

---

## Ejecución con Docker (recomendado)

> Requiere **Docker Desktop** y **Docker Compose v2.1+**

```bash
# Desde la raíz del repositorio
docker compose up --build
```

| Servicio    | URL                        |
|-------------|----------------------------|
| Frontend    | http://localhost:4200      |
| Backend API | http://localhost:8000      |
| Swagger UI  | http://localhost:8000/docs |
| SQL Server  | localhost:1433             |
| Adminer     | http://localhost:8080      |

**Primera ejecución:** Docker levanta SQL Server, espera a que esté listo mediante healthcheck, ejecuta los scripts de base de datos y luego arranca backend y frontend. Toma aproximadamente 2-3 minutos.

**Reiniciar preservando datos:**
```bash
docker compose down && docker compose up
```

**Resetear completamente (borra todos los datos):**
```bash
docker compose down -v && docker compose up --build
```

### Adminer (gestor visual de BD)

Disponible en `http://localhost:8080`. Datos de conexión:

| Campo      | Valor           |
|------------|-----------------|
| Sistema    | MS SQL          |
| Servidor   | `sqlserver`     |
| Usuario    | `sa`            |
| Contraseña | `TecnoGlass2024!` |
| Base datos | `TecnoglassDB`  |

---

## Ejecución Local (sin Docker)

### Requisitos previos

- SQL Server 2019+ (o Express) con ODBC Driver 17/18 for SQL Server
- Python 3.11+
- Node.js 18+ y npm 9+

### 1. Base de datos

```bash
# Opción A — script automatizado (requiere sqlcmd en PATH)
bash database/init.sh

# Opción B — manual en SSMS o sqlcmd
sqlcmd -S localhost -U sa -P TuPassword -i database/01_DDL_tablas.sql
sqlcmd -S localhost -U sa -P TuPassword -i database/02_SP_produccion.sql
sqlcmd -S localhost -U sa -P TuPassword -i database/03_seed_data.sql
```

El script `init.sh` es idempotente: si la base de datos ya existe y tiene las tablas, sale sin hacer nada.

Variables de entorno que acepta `init.sh`:

| Variable      | Defecto          | Descripción                   |
|---------------|------------------|-------------------------------|
| `SQLCMD_PATH` | `sqlcmd`         | Ruta al ejecutable sqlcmd     |
| `DB_SERVER`   | `localhost`      | Host del servidor             |
| `DB_USER`     | `sa`             | Usuario                       |
| `DB_PASSWORD` | `TecnoGlass2024!`| Contraseña                    |
| `SQL_DIR`     | directorio del script | Carpeta con los .sql     |

### 2. Backend

```bash
cd backend

# Crear entorno virtual e instalar dependencias
python -m venv venv
venv\Scripts\activate        # Windows
# source venv/bin/activate   # Linux/Mac
pip install -r requirements.txt

# Configurar variables de entorno
cp .env.example .env
# Editar .env con las credenciales de SQL Server

# Crear usuarios iniciales con hashes bcrypt reales
python create_admin.py

# Arrancar
uvicorn app.main:app --reload --port 8000
```

Variables clave en `.env`:
```
DB_SERVER=localhost
DB_NAME=TecnoglassDB
DB_USER=sa
DB_PASSWORD=TuContraseña
DB_DRIVER=ODBC Driver 18 for SQL Server
JWT_SECRET_KEY=secreto_aleatorio_minimo_32_caracteres
```

### 3. Frontend

```bash
cd frontend
npm install
npm start
# → http://localhost:4200
```

---

## Credenciales por Defecto

| Usuario   | Contraseña   | Rol      |
|-----------|--------------|----------|
| admin     | Admin123!    | ADMIN    |
| operador1 | Operador123! | OPERADOR |

---

## API REST — Endpoints

### Autenticación

| Método | Endpoint          | Descripción             |
|--------|-------------------|-------------------------|
| POST   | `/api/auth/login` | Login, retorna JWT      |
| GET    | `/api/auth/me`    | Usuario autenticado     |

### Órdenes de Producción

| Método | Endpoint                                  | Descripción                        |
|--------|-------------------------------------------|------------------------------------|
| POST   | `/api/ordenes`                            | Crear orden + generar ventanas     |
| GET    | `/api/ordenes`                            | Listar órdenes (`?estado=ACTIVA`)  |
| GET    | `/api/ordenes/{id}`                       | Detalle con listado de ventanas    |
| PUT    | `/api/ordenes/{id}`                       | Editar código de la orden          |
| DELETE | `/api/ordenes/{id}`                       | Eliminar (solo si sin iniciadas)   |
| POST   | `/api/ordenes/{id}/ventanas`              | Agregar ventanas a la orden        |
| DELETE | `/api/ordenes/{id}/ventanas/{ventana_id}` | Eliminar ventana PENDIENTE         |

### Ventanas

| Método | Endpoint                            | Descripción                           |
|--------|-------------------------------------|---------------------------------------|
| POST   | `/api/ventanas/{id}/avanzar`        | Avanzar a siguiente estación          |
| GET    | `/api/ventanas/{id}/trazabilidad`   | Estación actual + historial completo  |
| GET    | `/api/ventanas/qr/{codigo}`         | Buscar ventana por código QR          |
| GET    | `/api/ventanas/{id}/qr-imagen`      | QR como imagen base64 PNG             |

### Dashboard

| Método | Endpoint                 | Descripción                                   |
|--------|--------------------------|-----------------------------------------------|
| GET    | `/api/dashboard/resumen` | Resumen de órdenes + distribución por estación|

La documentación interactiva completa está disponible en `http://localhost:8000/docs`.

---

## Flujo de Manufactura

```
PENDIENTE → [Corte] → [Troquel] → [Ensamble] → [Empaque] = COMPLETADA
```

- Cada llamada a `POST /api/ventanas/{id}/avanzar` mueve la ventana exactamente una estación.
- Al llegar a Empaque la ventana queda `COMPLETADA`.
- Cuando **todas las ventanas** de una orden alcanzan Empaque, la orden pasa automáticamente a `COMPLETADA` (lógica en el SP, dentro de la misma transacción).
- El avance usa `WITH (UPDLOCK, ROWLOCK)` para prevenir que dos operadores avancen la misma ventana simultáneamente.

---

## Reglas de Negocio para Edición

| Operación              | Restricción                                              |
|------------------------|----------------------------------------------------------|
| Eliminar orden         | Solo si ninguna ventana fue iniciada (todas `PENDIENTE`) |
| Eliminar ventana       | Solo si la ventana está en estado `PENDIENTE`            |
| Agregar ventanas       | Sin restricción mientras la orden exista                 |
| Editar código de orden | El nuevo código no puede estar en uso por otra orden     |
