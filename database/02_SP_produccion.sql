-- ============================================================
-- Tecnoglass | Sistema de Trazabilidad de Producción
-- Stored Procedures
-- ============================================================

USE TecnoglassDB;
GO

-- ============================================================
-- SP1: sp_LoginUsuario
-- Retorna datos del usuario para validación en capa de aplicación
-- ============================================================
CREATE OR ALTER PROCEDURE dbo.sp_LoginUsuario
    @Username NVARCHAR(100)
AS
BEGIN
    SET NOCOUNT ON;
    SELECT Id, Username, PasswordHash, Nombre, Rol, Activo
    FROM dbo.Usuarios
    WHERE Username = @Username AND Activo = 1;
END;
GO

-- ============================================================
-- SP2: sp_CrearOrdenProduccion
-- Crea una orden de producción y genera todas sus ventanas
-- ============================================================
CREATE OR ALTER PROCEDURE dbo.sp_CrearOrdenProduccion
    @Codigo       NVARCHAR(50),
    @TotalVentanas INT,
    @UsuarioId    INT
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRANSACTION;
    BEGIN TRY

        IF @TotalVentanas <= 0
            THROW 50001, N'La cantidad de ventanas debe ser mayor a 0.', 1;

        IF EXISTS (SELECT 1 FROM dbo.OrdenesProd WHERE Codigo = @Codigo)
            THROW 50002, N'Ya existe una orden con ese código.', 1;

        IF NOT EXISTS (SELECT 1 FROM dbo.Usuarios WHERE Id = @UsuarioId AND Activo = 1)
            THROW 50003, N'Usuario no válido.', 1;

        INSERT INTO dbo.OrdenesProd (Codigo, TotalVentanas, UsuarioCreadorId, Estado, FechaCreacion)
        VALUES (@Codigo, @TotalVentanas, @UsuarioId, 'ACTIVA', GETDATE());

        DECLARE @NuevaOrdenId INT = SCOPE_IDENTITY();

        -- Generar ventanas con GUID único
        DECLARE @i INT = 1;
        DECLARE @VentanaGUID UNIQUEIDENTIFIER;

        WHILE @i <= @TotalVentanas
        BEGIN
            SET @VentanaGUID = NEWID();

            INSERT INTO dbo.Ventanas (Id, CodigoQR, OrdenProduccionId, Estado, FechaCreacion)
            VALUES (@VentanaGUID, CAST(@VentanaGUID AS NVARCHAR(36)), @NuevaOrdenId, 'PENDIENTE', GETDATE());

            SET @i = @i + 1;
        END

        INSERT INTO dbo.AuditoriaAcciones (Tabla, Accion, RegistroId, UsuarioId, Fecha, Detalle)
        VALUES ('OrdenesProd', 'CREAR', CAST(@NuevaOrdenId AS NVARCHAR(50)), @UsuarioId, GETDATE(),
                N'Orden creada: ' + @Codigo + N' con ' + CAST(@TotalVentanas AS NVARCHAR(10)) + N' ventanas');

        COMMIT TRANSACTION;

        SELECT o.Id, o.Codigo, o.TotalVentanas, o.Estado, o.FechaCreacion,
               u.Nombre AS UsuarioCreador
        FROM dbo.OrdenesProd o
        INNER JOIN dbo.Usuarios u ON u.Id = o.UsuarioCreadorId
        WHERE o.Id = @NuevaOrdenId;

    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO

-- ============================================================
-- SP3: sp_AvanzarVentana
-- Mueve una ventana a la siguiente estación con control de concurrencia.
-- Verifica automáticamente si la orden queda completada.
-- ============================================================
CREATE OR ALTER PROCEDURE dbo.sp_AvanzarVentana
    @VentanaId   UNIQUEIDENTIFIER,
    @UsuarioId   INT,
    @Observacion NVARCHAR(500) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRANSACTION;
    BEGIN TRY

        DECLARE @EstacionActualId  INT;
        DECLARE @EstadoVentana     NVARCHAR(20);
        DECLARE @OrdenProduccionId INT;

        -- UPDLOCK + ROWLOCK previene que dos procesos avancen la misma ventana simultáneamente
        SELECT
            @EstacionActualId  = v.EstacionActualId,
            @EstadoVentana     = v.Estado,
            @OrdenProduccionId = v.OrdenProduccionId
        FROM dbo.Ventanas v WITH (UPDLOCK, ROWLOCK)
        WHERE v.Id = @VentanaId;

        IF @EstadoVentana IS NULL
            THROW 50010, N'Ventana no encontrada.', 1;

        IF @EstadoVentana = 'COMPLETADA'
            THROW 50011, N'La ventana ya completó todas las estaciones.', 1;

        -- Determinar siguiente estación
        DECLARE @SiguienteEstacionId  INT;
        DECLARE @MaxOrden             INT = (SELECT MAX(Orden) FROM dbo.Estaciones);
        DECLARE @OrdenActual          INT;

        IF @EstacionActualId IS NULL
        BEGIN
            SELECT TOP 1 @SiguienteEstacionId = Id
            FROM dbo.Estaciones
            ORDER BY Orden ASC;
        END
        ELSE
        BEGIN
            SET @OrdenActual = (SELECT Orden FROM dbo.Estaciones WHERE Id = @EstacionActualId);

            IF @OrdenActual = @MaxOrden
                THROW 50012, N'La ventana ya se encuentra en la última estación.', 1;

            SELECT @SiguienteEstacionId = Id
            FROM dbo.Estaciones
            WHERE Orden = @OrdenActual + 1;
        END

        -- Estado según posición: COMPLETADA sólo al llegar a la última estación (Empaque)
        DECLARE @OrdenSiguiente INT     = (SELECT Orden FROM dbo.Estaciones WHERE Id = @SiguienteEstacionId);
        DECLARE @NuevoEstado    NVARCHAR(20) = CASE WHEN @OrdenSiguiente = @MaxOrden THEN 'COMPLETADA' ELSE 'EN_PROCESO' END;

        UPDATE dbo.Ventanas
        SET EstacionActualId = @SiguienteEstacionId,
            Estado           = @NuevoEstado
        WHERE Id = @VentanaId;

        INSERT INTO dbo.MovimientosVentana (VentanaId, EstacionId, UsuarioId, FechaMovimiento, Observacion)
        VALUES (@VentanaId, @SiguienteEstacionId, @UsuarioId, GETDATE(), @Observacion);

        -- Verificar si toda la orden quedó completada
        IF NOT EXISTS (
            SELECT 1 FROM dbo.Ventanas
            WHERE OrdenProduccionId = @OrdenProduccionId
              AND Estado <> 'COMPLETADA'
        )
        BEGIN
            UPDATE dbo.OrdenesProd
            SET Estado = 'COMPLETADA', FechaCompletada = GETDATE()
            WHERE Id = @OrdenProduccionId;

            INSERT INTO dbo.AuditoriaAcciones (Tabla, Accion, RegistroId, UsuarioId, Fecha, Detalle)
            VALUES ('OrdenesProd', 'COMPLETAR', CAST(@OrdenProduccionId AS NVARCHAR(50)), @UsuarioId, GETDATE(),
                    N'Orden completada automáticamente al empacar última ventana');
        END

        COMMIT TRANSACTION;

        SELECT v.Id, v.CodigoQR, v.Estado, v.OrdenProduccionId,
               v.EstacionActualId, e.Nombre AS EstacionActual, e.Orden AS OrdenEstacion
        FROM dbo.Ventanas v
        LEFT JOIN dbo.Estaciones e ON e.Id = v.EstacionActualId
        WHERE v.Id = @VentanaId;

    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO

-- ============================================================
-- SP4: sp_ObtenerTrazabilidad
-- Retorna info de la ventana y su historial completo de movimientos
-- ============================================================
CREATE OR ALTER PROCEDURE dbo.sp_ObtenerTrazabilidad
    @VentanaId UNIQUEIDENTIFIER
AS
BEGIN
    SET NOCOUNT ON;

    IF NOT EXISTS (SELECT 1 FROM dbo.Ventanas WHERE Id = @VentanaId)
        THROW 50020, N'Ventana no encontrada.', 1;

    -- Resultado 1: datos de la ventana
    SELECT v.Id, v.CodigoQR, v.Estado, v.FechaCreacion,
           v.OrdenProduccionId, o.Codigo AS CodigoOrden,
           v.EstacionActualId, e.Nombre AS EstacionActual, e.Orden AS OrdenEstacion
    FROM dbo.Ventanas v
    INNER JOIN dbo.OrdenesProd o ON o.Id = v.OrdenProduccionId
    LEFT  JOIN dbo.Estaciones  e ON e.Id = v.EstacionActualId
    WHERE v.Id = @VentanaId;

    -- Resultado 2: historial cronológico de movimientos
    SELECT mv.Id, mv.FechaMovimiento, mv.Observacion,
           mv.EstacionId, est.Nombre AS NombreEstacion, est.Orden AS OrdenEstacion,
           mv.UsuarioId, u.Nombre AS NombreUsuario
    FROM dbo.MovimientosVentana mv
    INNER JOIN dbo.Estaciones est ON est.Id = mv.EstacionId
    INNER JOIN dbo.Usuarios   u   ON u.Id   = mv.UsuarioId
    WHERE mv.VentanaId = @VentanaId
    ORDER BY mv.FechaMovimiento ASC;
END;
GO

-- ============================================================
-- SP5: sp_ObtenerVentanaPorQR
-- ============================================================
CREATE OR ALTER PROCEDURE dbo.sp_ObtenerVentanaPorQR
    @CodigoQR NVARCHAR(100)
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @VentanaId UNIQUEIDENTIFIER;

    SELECT @VentanaId = Id FROM dbo.Ventanas WHERE CodigoQR = @CodigoQR;

    IF @VentanaId IS NULL
        THROW 50021, N'No se encontró ninguna ventana con ese código QR.', 1;

    EXEC dbo.sp_ObtenerTrazabilidad @VentanaId = @VentanaId;
END;
GO

-- ============================================================
-- SP6: sp_DashboardResumen
-- Dashboard: órdenes activas con % avance + distribución por estación
-- ============================================================
CREATE OR ALTER PROCEDURE dbo.sp_DashboardResumen
AS
BEGIN
    SET NOCOUNT ON;

    -- Resultado 1: resumen de todas las órdenes
    SELECT
        o.Id,
        o.Codigo,
        o.TotalVentanas,
        o.Estado,
        o.FechaCreacion,
        o.FechaCompletada,
        u.Nombre AS UsuarioCreador,
        COUNT(CASE WHEN v.Estado = 'COMPLETADA'  THEN 1 END) AS VentanasCompletadas,
        COUNT(CASE WHEN v.Estado = 'EN_PROCESO'  THEN 1 END) AS VentanasEnProceso,
        COUNT(CASE WHEN v.Estado = 'PENDIENTE'   THEN 1 END) AS VentanasPendientes,
        CAST(
            COUNT(CASE WHEN v.Estado = 'COMPLETADA' THEN 1 END) * 100.0 / o.TotalVentanas
            AS DECIMAL(5,2)
        ) AS PorcentajeAvance
    FROM dbo.OrdenesProd o
    LEFT  JOIN dbo.Ventanas  v ON v.OrdenProduccionId = o.Id
    INNER JOIN dbo.Usuarios  u ON u.Id = o.UsuarioCreadorId
    GROUP BY o.Id, o.Codigo, o.TotalVentanas, o.Estado,
             o.FechaCreacion, o.FechaCompletada, u.Nombre
    ORDER BY o.Estado ASC, o.FechaCreacion DESC;

    -- Resultado 2: distribución de ventanas por estación (sólo órdenes ACTIVAS)
    SELECT
        e.Id   AS EstacionId,
        e.Nombre AS NombreEstacion,
        e.Orden,
        COUNT(v.Id) AS CantidadVentanas
    FROM dbo.Estaciones e
    LEFT JOIN dbo.Ventanas v ON v.EstacionActualId = e.Id
        AND EXISTS (
            SELECT 1 FROM dbo.OrdenesProd op
            WHERE op.Id = v.OrdenProduccionId AND op.Estado = 'ACTIVA'
        )
    GROUP BY e.Id, e.Nombre, e.Orden
    ORDER BY e.Orden;
END;
GO

-- ============================================================
-- SP7: sp_ListarOrdenes
-- ============================================================
CREATE OR ALTER PROCEDURE dbo.sp_ListarOrdenes
    @Estado NVARCHAR(20) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        o.Id,
        o.Codigo,
        o.TotalVentanas,
        o.Estado,
        o.FechaCreacion,
        o.FechaCompletada,
        u.Nombre AS UsuarioCreador,
        COUNT(CASE WHEN v.Estado = 'COMPLETADA' THEN 1 END) AS VentanasCompletadas,
        CAST(
            COUNT(CASE WHEN v.Estado = 'COMPLETADA' THEN 1 END) * 100.0 / o.TotalVentanas
            AS DECIMAL(5,2)
        ) AS PorcentajeAvance
    FROM dbo.OrdenesProd o
    LEFT  JOIN dbo.Ventanas v ON v.OrdenProduccionId = o.Id
    INNER JOIN dbo.Usuarios u ON u.Id = o.UsuarioCreadorId
    WHERE (@Estado IS NULL OR o.Estado = @Estado)
    GROUP BY o.Id, o.Codigo, o.TotalVentanas, o.Estado,
             o.FechaCreacion, o.FechaCompletada, u.Nombre
    ORDER BY o.FechaCreacion DESC;
END;
GO

-- ============================================================
-- SP8: sp_ObtenerOrdenDetalle
-- ============================================================
CREATE OR ALTER PROCEDURE dbo.sp_ObtenerOrdenDetalle
    @OrdenId INT
AS
BEGIN
    SET NOCOUNT ON;

    IF NOT EXISTS (SELECT 1 FROM dbo.OrdenesProd WHERE Id = @OrdenId)
        THROW 50030, N'Orden de producción no encontrada.', 1;

    -- Resultado 1: cabecera de la orden
    SELECT o.Id, o.Codigo, o.TotalVentanas, o.Estado, o.FechaCreacion, o.FechaCompletada,
           u.Nombre AS UsuarioCreador,
           COUNT(CASE WHEN v.Estado = 'COMPLETADA' THEN 1 END) AS VentanasCompletadas,
           COUNT(CASE WHEN v.Estado = 'EN_PROCESO'  THEN 1 END) AS VentanasEnProceso,
           COUNT(CASE WHEN v.Estado = 'PENDIENTE'   THEN 1 END) AS VentanasPendientes,
           CAST(
               COUNT(CASE WHEN v.Estado = 'COMPLETADA' THEN 1 END) * 100.0 / o.TotalVentanas
               AS DECIMAL(5,2)
           ) AS PorcentajeAvance
    FROM dbo.OrdenesProd o
    INNER JOIN dbo.Usuarios u ON u.Id = o.UsuarioCreadorId
    LEFT  JOIN dbo.Ventanas v ON v.OrdenProduccionId = o.Id
    WHERE o.Id = @OrdenId
    GROUP BY o.Id, o.Codigo, o.TotalVentanas, o.Estado,
             o.FechaCreacion, o.FechaCompletada, u.Nombre;

    -- Resultado 2: listado de ventanas con su estación actual
    SELECT v.Id, v.CodigoQR, v.Estado, v.FechaCreacion,
           v.EstacionActualId,
           e.Nombre AS EstacionActual,
           e.Orden  AS OrdenEstacion
    FROM dbo.Ventanas  v
    LEFT JOIN dbo.Estaciones e ON e.Id = v.EstacionActualId
    WHERE v.OrdenProduccionId = @OrdenId
    ORDER BY v.FechaCreacion ASC;
END;
GO

-- ============================================================
-- SP9: sp_EditarOrden
-- Cambia el código de una orden de producción
-- ============================================================
CREATE OR ALTER PROCEDURE dbo.sp_EditarOrden
    @OrdenId     INT,
    @NuevoCodigo NVARCHAR(50),
    @UsuarioId   INT
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRANSACTION;
    BEGIN TRY

        IF NOT EXISTS (SELECT 1 FROM dbo.OrdenesProd WHERE Id = @OrdenId)
            THROW 50040, N'Orden de producción no encontrada.', 1;

        IF EXISTS (SELECT 1 FROM dbo.OrdenesProd WHERE Codigo = @NuevoCodigo AND Id <> @OrdenId)
            THROW 50041, N'Ya existe una orden con ese código.', 1;

        UPDATE dbo.OrdenesProd SET Codigo = @NuevoCodigo WHERE Id = @OrdenId;

        INSERT INTO dbo.AuditoriaAcciones (Tabla, Accion, RegistroId, UsuarioId, Fecha, Detalle)
        VALUES ('OrdenesProd', 'EDITAR', CAST(@OrdenId AS NVARCHAR(50)), @UsuarioId, GETDATE(),
                N'Código actualizado a: ' + @NuevoCodigo);

        COMMIT TRANSACTION;

        SELECT o.Id, o.Codigo, o.TotalVentanas, o.Estado, o.FechaCreacion, o.FechaCompletada,
               u.Nombre AS UsuarioCreador
        FROM dbo.OrdenesProd o
        INNER JOIN dbo.Usuarios u ON u.Id = o.UsuarioCreadorId
        WHERE o.Id = @OrdenId;

    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO

-- ============================================================
-- SP10: sp_EliminarOrden
-- Elimina una orden y sus ventanas sólo si ninguna fue iniciada
-- (iniciada = estado distinto a PENDIENTE)
-- ============================================================
CREATE OR ALTER PROCEDURE dbo.sp_EliminarOrden
    @OrdenId   INT,
    @UsuarioId INT
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRANSACTION;
    BEGIN TRY

        DECLARE @Codigo NVARCHAR(50);
        SELECT @Codigo = Codigo FROM dbo.OrdenesProd WHERE Id = @OrdenId;

        IF @Codigo IS NULL
            THROW 50042, N'Orden de producción no encontrada.', 1;

        IF EXISTS (
            SELECT 1 FROM dbo.Ventanas
            WHERE OrdenProduccionId = @OrdenId AND Estado <> 'PENDIENTE'
        )
            THROW 50043, N'No se puede eliminar la orden porque tiene ventanas iniciadas.', 1;

        -- Las ventanas PENDIENTE no tienen movimientos, sin riesgo de FK en MovimientosVentana
        DELETE FROM dbo.Ventanas WHERE OrdenProduccionId = @OrdenId;
        DELETE FROM dbo.OrdenesProd WHERE Id = @OrdenId;

        INSERT INTO dbo.AuditoriaAcciones (Tabla, Accion, RegistroId, UsuarioId, Fecha, Detalle)
        VALUES ('OrdenesProd', 'ELIMINAR', CAST(@OrdenId AS NVARCHAR(50)), @UsuarioId, GETDATE(),
                N'Orden eliminada: ' + @Codigo);

        COMMIT TRANSACTION;

    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO

-- ============================================================
-- SP11: sp_AgregarVentanas
-- Agrega N ventanas PENDIENTE a una orden y actualiza TotalVentanas
-- ============================================================
CREATE OR ALTER PROCEDURE dbo.sp_AgregarVentanas
    @OrdenId   INT,
    @Cantidad  INT,
    @UsuarioId INT
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRANSACTION;
    BEGIN TRY

        IF NOT EXISTS (SELECT 1 FROM dbo.OrdenesProd WHERE Id = @OrdenId)
            THROW 50044, N'Orden de producción no encontrada.', 1;

        IF @Cantidad <= 0
            THROW 50045, N'La cantidad de ventanas a agregar debe ser mayor a 0.', 1;

        DECLARE @i INT = 1;
        DECLARE @VentanaGUID UNIQUEIDENTIFIER;

        WHILE @i <= @Cantidad
        BEGIN
            SET @VentanaGUID = NEWID();
            INSERT INTO dbo.Ventanas (Id, CodigoQR, OrdenProduccionId, Estado, FechaCreacion)
            VALUES (@VentanaGUID, CAST(@VentanaGUID AS NVARCHAR(36)), @OrdenId, 'PENDIENTE', GETDATE());
            SET @i = @i + 1;
        END

        UPDATE dbo.OrdenesProd SET TotalVentanas = TotalVentanas + @Cantidad WHERE Id = @OrdenId;

        INSERT INTO dbo.AuditoriaAcciones (Tabla, Accion, RegistroId, UsuarioId, Fecha, Detalle)
        VALUES ('OrdenesProd', 'AGREGAR_VENTANAS', CAST(@OrdenId AS NVARCHAR(50)), @UsuarioId, GETDATE(),
                CAST(@Cantidad AS NVARCHAR(10)) + N' ventanas agregadas');

        COMMIT TRANSACTION;

    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO

-- ============================================================
-- SP12: sp_EliminarVentana
-- Elimina una ventana PENDIENTE; falla si ya fue iniciada
-- Impide que la orden quede con 0 ventanas
-- ============================================================
CREATE OR ALTER PROCEDURE dbo.sp_EliminarVentana
    @VentanaId UNIQUEIDENTIFIER,
    @UsuarioId INT
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRANSACTION;
    BEGIN TRY

        DECLARE @Estado            NVARCHAR(20);
        DECLARE @OrdenProduccionId INT;

        SELECT @Estado = Estado, @OrdenProduccionId = OrdenProduccionId
        FROM dbo.Ventanas WHERE Id = @VentanaId;

        IF @Estado IS NULL
            THROW 50050, N'Ventana no encontrada.', 1;

        IF @Estado <> 'PENDIENTE'
            THROW 50051, N'No se puede eliminar una ventana que ya fue iniciada.', 1;

        IF (SELECT TotalVentanas FROM dbo.OrdenesProd WHERE Id = @OrdenProduccionId) <= 1
            THROW 50052, N'La orden debe tener al menos una ventana.', 1;

        DELETE FROM dbo.Ventanas WHERE Id = @VentanaId;
        UPDATE dbo.OrdenesProd SET TotalVentanas = TotalVentanas - 1 WHERE Id = @OrdenProduccionId;

        INSERT INTO dbo.AuditoriaAcciones (Tabla, Accion, RegistroId, UsuarioId, Fecha, Detalle)
        VALUES ('Ventanas', 'ELIMINAR', CAST(@VentanaId AS NVARCHAR(36)), @UsuarioId, GETDATE(),
                N'Ventana eliminada de orden ' + CAST(@OrdenProduccionId AS NVARCHAR(10)));

        COMMIT TRANSACTION;

    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO
