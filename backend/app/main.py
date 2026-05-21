from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.core.config import settings
from app.routers import auth, dashboard, ordenes, ventanas

app = FastAPI(
    title="Tecnoglass — Sistema de Trazabilidad de Producción",
    description="API REST para monitoreo y trazabilidad de líneas de manufactura de ventanería",
    version="1.0.0",
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.cors_origins_list,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(auth.router,      prefix="/api")
app.include_router(ordenes.router,   prefix="/api")
app.include_router(ventanas.router,  prefix="/api")
app.include_router(dashboard.router, prefix="/api")


@app.get("/", tags=["Health"])
def health():
    return {"status": "ok", "service": "Tecnoglass Production API"}
