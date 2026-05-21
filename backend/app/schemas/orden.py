from pydantic import BaseModel, field_validator


class CrearOrdenRequest(BaseModel):
    codigo: str
    total_ventanas: int

    @field_validator("codigo")
    @classmethod
    def codigo_no_vacio(cls, v: str) -> str:
        if not v.strip():
            raise ValueError("El código no puede estar vacío")
        return v.strip().upper()

    @field_validator("total_ventanas")
    @classmethod
    def ventanas_positivas(cls, v: int) -> int:
        if v <= 0:
            raise ValueError("La cantidad de ventanas debe ser mayor a 0")
        return v


class EditarOrdenRequest(BaseModel):
    codigo: str

    @field_validator("codigo")
    @classmethod
    def codigo_no_vacio(cls, v: str) -> str:
        if not v.strip():
            raise ValueError("El código no puede estar vacío")
        return v.strip().upper()


class AgregarVentanasRequest(BaseModel):
    cantidad: int

    @field_validator("cantidad")
    @classmethod
    def cantidad_positiva(cls, v: int) -> int:
        if v <= 0:
            raise ValueError("La cantidad debe ser mayor a 0")
        return v
