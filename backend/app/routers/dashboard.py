from fastapi import APIRouter, Depends

from app.core.database import advance_resultset, get_db, rows_to_dicts
from app.dependencies import get_current_user

router = APIRouter(prefix="/dashboard", tags=["Dashboard"])


@router.get("/resumen")
def resumen(current_user: dict = Depends(get_current_user)):
    with get_db() as conn:
        cursor = conn.cursor()
        cursor.execute("EXEC dbo.sp_DashboardResumen")
        ordenes = rows_to_dicts(cursor)
        advance_resultset(cursor)
        distribucion = rows_to_dicts(cursor)

    return {"ordenes": ordenes, "distribucion_estaciones": distribucion}
