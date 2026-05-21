from fastapi import APIRouter, Depends, HTTPException, Query, status

from app.core.database import advance_resultset, get_db, row_to_dict, rows_to_dicts
from app.dependencies import get_current_user
from app.schemas.orden import AgregarVentanasRequest, CrearOrdenRequest, EditarOrdenRequest

router = APIRouter(prefix="/ordenes", tags=["Órdenes de Producción"])


@router.post("", status_code=status.HTTP_201_CREATED)
def crear_orden(body: CrearOrdenRequest, current_user: dict = Depends(get_current_user)):
    with get_db() as conn:
        cursor = conn.cursor()
        try:
            cursor.execute(
                "EXEC dbo.sp_CrearOrdenProduccion @Codigo=?, @TotalVentanas=?, @UsuarioId=?",
                (body.codigo, body.total_ventanas, current_user["id"]),
            )
            orden = row_to_dict(cursor)
        except Exception as exc:
            _handle_sp_error(exc)

    return orden


@router.get("")
def listar_ordenes(
    estado: str | None = Query(default=None, pattern="^(ACTIVA|COMPLETADA)$"),
    current_user: dict = Depends(get_current_user),
):
    with get_db() as conn:
        cursor = conn.cursor()
        cursor.execute("EXEC dbo.sp_ListarOrdenes @Estado=?", (estado,))
        return rows_to_dicts(cursor)


@router.get("/{orden_id}")
def detalle_orden(orden_id: int, current_user: dict = Depends(get_current_user)):
    with get_db() as conn:
        cursor = conn.cursor()
        try:
            cursor.execute("EXEC dbo.sp_ObtenerOrdenDetalle @OrdenId=?", (orden_id,))
            cabecera = row_to_dict(cursor)
            advance_resultset(cursor)
            ventanas = rows_to_dicts(cursor)
        except Exception as exc:
            _handle_sp_error(exc)

    if not cabecera:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Orden no encontrada")

    return {**cabecera, "ventanas": ventanas}


@router.put("/{orden_id}")
def editar_orden(orden_id: int, body: EditarOrdenRequest, current_user: dict = Depends(get_current_user)):
    with get_db() as conn:
        cursor = conn.cursor()
        try:
            cursor.execute(
                "EXEC dbo.sp_EditarOrden @OrdenId=?, @NuevoCodigo=?, @UsuarioId=?",
                (orden_id, body.codigo, current_user["id"]),
            )
            orden = row_to_dict(cursor)
        except Exception as exc:
            _handle_sp_error(exc)

    if not orden:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Orden no encontrada")
    return orden


@router.delete("/{orden_id}", status_code=status.HTTP_204_NO_CONTENT)
def eliminar_orden(orden_id: int, current_user: dict = Depends(get_current_user)):
    with get_db() as conn:
        cursor = conn.cursor()
        try:
            cursor.execute(
                "EXEC dbo.sp_EliminarOrden @OrdenId=?, @UsuarioId=?",
                (orden_id, current_user["id"]),
            )
        except Exception as exc:
            _handle_sp_error(exc)


@router.post("/{orden_id}/ventanas", status_code=status.HTTP_201_CREATED)
def agregar_ventanas(
    orden_id: int,
    body: AgregarVentanasRequest,
    current_user: dict = Depends(get_current_user),
):
    with get_db() as conn:
        cursor = conn.cursor()
        try:
            cursor.execute(
                "EXEC dbo.sp_AgregarVentanas @OrdenId=?, @Cantidad=?, @UsuarioId=?",
                (orden_id, body.cantidad, current_user["id"]),
            )
        except Exception as exc:
            _handle_sp_error(exc)

    return {"ventanas_agregadas": body.cantidad}


@router.delete("/{orden_id}/ventanas/{ventana_id}", status_code=status.HTTP_204_NO_CONTENT)
def eliminar_ventana_de_orden(
    orden_id: int,
    ventana_id: str,
    current_user: dict = Depends(get_current_user),
):
    with get_db() as conn:
        cursor = conn.cursor()
        try:
            cursor.execute(
                "EXEC dbo.sp_EliminarVentana @VentanaId=?, @UsuarioId=?",
                (ventana_id, current_user["id"]),
            )
        except Exception as exc:
            _handle_sp_error(exc)


def _handle_sp_error(exc: Exception):
    msg = str(exc)
    for code, http_code, detail in [
        ("50001", status.HTTP_422_UNPROCESSABLE_ENTITY, "Cantidad de ventanas inválida"),
        ("50002", status.HTTP_409_CONFLICT,              "Ya existe una orden con ese código"),
        ("50030", status.HTTP_404_NOT_FOUND,             "Orden no encontrada"),
        ("50040", status.HTTP_404_NOT_FOUND,             "Orden no encontrada"),
        ("50041", status.HTTP_409_CONFLICT,              "Ya existe una orden con ese código"),
        ("50042", status.HTTP_404_NOT_FOUND,             "Orden no encontrada"),
        ("50043", status.HTTP_409_CONFLICT,              "No se puede eliminar la orden porque tiene ventanas iniciadas"),
        ("50044", status.HTTP_404_NOT_FOUND,             "Orden no encontrada"),
        ("50045", status.HTTP_422_UNPROCESSABLE_ENTITY,  "La cantidad de ventanas a agregar debe ser mayor a 0"),
        ("50050", status.HTTP_404_NOT_FOUND,             "Ventana no encontrada"),
        ("50051", status.HTTP_409_CONFLICT,              "No se puede eliminar una ventana que ya fue iniciada"),
        ("50052", status.HTTP_409_CONFLICT,              "La orden debe tener al menos una ventana"),
    ]:
        if code in msg:
            raise HTTPException(status_code=http_code, detail=detail)
    raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail=msg)
