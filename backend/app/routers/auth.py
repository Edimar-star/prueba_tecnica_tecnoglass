from fastapi import APIRouter, Depends, HTTPException, status

from app.core.database import get_db, row_to_dict
from app.core.security import create_access_token, verify_password
from app.dependencies import get_current_user
from app.schemas.auth import LoginRequest, TokenResponse

router = APIRouter(prefix="/auth", tags=["Autenticación"])


@router.post("/login", response_model=TokenResponse)
def login(body: LoginRequest):
    with get_db() as conn:
        cursor = conn.cursor()
        cursor.execute("EXEC dbo.sp_LoginUsuario @Username=?", (body.username,))
        user = row_to_dict(cursor)

    if not user:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Credenciales inválidas")

    if not verify_password(body.password, user["PasswordHash"]):
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Credenciales inválidas")

    token = create_access_token({
        "sub": str(user["Id"]),
        "username": user["Username"],
        "rol": user["Rol"],
    })

    return TokenResponse(
        access_token=token,
        usuario={
            "id": user["Id"],
            "username": user["Username"],
            "nombre": user["Nombre"],
            "rol": user["Rol"],
        },
    )


@router.get("/me")
def me(current_user: dict = Depends(get_current_user)):
    return current_user
