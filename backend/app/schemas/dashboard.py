from pydantic import BaseModel


class DashboardResponse(BaseModel):
    ordenes: list[dict]
    distribucion_estaciones: list[dict]
