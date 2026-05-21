from pydantic import BaseModel


class AvanzarVentanaRequest(BaseModel):
    observacion: str | None = None
