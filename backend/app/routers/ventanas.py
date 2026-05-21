from fastapi import APIRouter, Depends, HTTPException, status

from app.core.database import advance_resultset, get_db, row_to_dict, rows_to_dicts
from app.dependencies import get_current_user
from app.schemas.ventana import AvanzarVentanaRequest
from app.services.qr_service import generate_qr_base64

router = APIRouter(prefix="/ventanas", tags=["Ventanas"])


@router.post("/{ventana_id}/avanzar")
def avanzar_ventana(
    ventana_id: str,
    body: AvanzarVentanaRequest,
    current_user: dict = Depends(get_current_user),
):
    with get_db() as conn:
        cursor = conn.cursor()
        try:
            cursor.execute(
                "EXEC dbo.sp_AvanzarVentana @VentanaId=?, @UsuarioId=?, @Observacion=?",
                (ventana_id, current_user["id"], body.observacion),
            )
            ventana = row_to_dict(cursor)
        except Exception as exc:
            _handle_sp_error(exc)

    return ventana


@router.get("/{ventana_id}/trazabilidad")
def trazabilidad(ventana_id: str, current_user: dict = Depends(get_current_user)):
    with get_db() as conn:
        cursor = conn.cursor()
        try:
            cursor.execute("EXEC dbo.sp_ObtenerTrazabilidad @VentanaId=?", (ventana_id,))
            ventana = row_to_dict(cursor)
            advance_resultset(cursor)
            movimientos = rows_to_dicts(cursor)
        except Exception as exc:
            _handle_sp_error(exc)

    if not ventana:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Ventana no encontrada")

    return {**ventana, "movimientos": movimientos}


@router.get("/qr/{codigo_qr}")
def por_qr(codigo_qr: str, current_user: dict = Depends(get_current_user)):
    with get_db() as conn:
        cursor = conn.cursor()
        try:
            cursor.execute("EXEC dbo.sp_ObtenerVentanaPorQR @CodigoQR=?", (codigo_qr,))
            ventana = row_to_dict(cursor)
            advance_resultset(cursor)
            movimientos = rows_to_dicts(cursor)
        except Exception as exc:
            _handle_sp_error(exc)

    return {**ventana, "movimientos": movimientos}


@router.get("/{ventana_id}/qr-imagen")
def qr_imagen(ventana_id: str, current_user: dict = Depends(get_current_user)):
    """Retorna el QR de la ventana como imagen base64 PNG."""
    qr_b64 = generate_qr_base64(ventana_id)
    return {"ventana_id": ventana_id, "qr_base64": qr_b64}


def _handle_sp_error(exc: Exception):
    msg = str(exc)
    for code, http_code, detail in [
        ("50010", status.HTTP_404_NOT_FOUND,          "Ventana no encontrada"),
        ("50011", status.HTTP_409_CONFLICT,            "La ventana ya completó todas las estaciones"),
        ("50012", status.HTTP_409_CONFLICT,            "La ventana ya está en la última estación"),
        ("50020", status.HTTP_404_NOT_FOUND,          "Ventana no encontrada"),
        ("50021", status.HTTP_404_NOT_FOUND,          "Código QR no encontrado"),
    ]:
        if code in msg:
            raise HTTPException(status_code=http_code, detail=detail)
    raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail=msg)
