-- ============================================================
-- Tecnoglass | Sistema de Trazabilidad de Producción
-- DDL: Creación de base de datos y tablas
-- ============================================================

USE master;
GO

IF NOT EXISTS (SELECT name FROM sys.databases WHERE name = 'TecnoglassDB')
    CREATE DATABASE TecnoglassDB;
GO

USE TecnoglassDB;
GO

-- ============================================================
-- Tabla: Usuarios
-- ============================================================
IF OBJECT_ID('dbo.Usuarios', 'U') IS NOT NULL DROP TABLE dbo.Usuarios;
GO

CREATE TABLE dbo.Usuarios (
    Id            INT            IDENTITY(1,1) NOT NULL,
    Username      NVARCHAR(100)                NOT NULL,
    PasswordHash  NVARCHAR(255)                NOT NULL,
    Nombre        NVARCHAR(200)                NOT NULL,
    Rol           NVARCHAR(50)                 NOT NULL CONSTRAINT DF_Usuarios_Rol DEFAULT 'OPERADOR',
    Activo        BIT                          NOT NULL CONSTRAINT DF_Usuarios_Activo DEFAULT 1,
    FechaCreacion DATETIME2                    NOT NULL CONSTRAINT DF_Usuarios_Fecha DEFAULT GETDATE(),
    CONSTRAINT PK_Usuarios        PRIMARY KEY (Id),
    CONSTRAINT UQ_Usuarios_User   UNIQUE (Username),
    CONSTRAINT CK_Usuarios_Rol    CHECK (Rol IN ('ADMIN', 'OPERADOR'))
);
GO

-- ============================================================
-- Tabla: Estaciones
-- ============================================================
IF OBJECT_ID('dbo.Estaciones', 'U') IS NOT NULL DROP TABLE dbo.Estaciones;
GO

CREATE TABLE dbo.Estaciones (
    Id     INT           IDENTITY(1,1) NOT NULL,
    Nombre NVARCHAR(100)               NOT NULL,
    Orden  INT                         NOT NULL,
    CONSTRAINT PK_Estaciones      PRIMARY KEY (Id),
    CONSTRAINT UQ_Estaciones_Ord  UNIQUE (Orden)
);
GO

-- ============================================================
-- Tabla: OrdenesProd
-- ============================================================
IF OBJECT_ID('dbo.OrdenesProd', 'U') IS NOT NULL DROP TABLE dbo.OrdenesProd;
GO

CREATE TABLE dbo.OrdenesProd (
    Id               INT           IDENTITY(1,1) NOT NULL,
    Codigo           NVARCHAR(50)                NOT NULL,
    TotalVentanas    INT                         NOT NULL,
    Estado           NVARCHAR(20)                NOT NULL CONSTRAINT DF_Ordenes_Estado DEFAULT 'ACTIVA',
    UsuarioCreadorId INT                         NOT NULL,
    FechaCreacion    DATETIME2                   NOT NULL CONSTRAINT DF_Ordenes_Fecha DEFAULT GETDATE(),
    FechaCompletada  DATETIME2                   NULL,
    CONSTRAINT PK_OrdenesProd         PRIMARY KEY (Id),
    CONSTRAINT UQ_OrdenesProd_Codigo  UNIQUE (Codigo),
    CONSTRAINT FK_Ordenes_Usuario     FOREIGN KEY (UsuarioCreadorId) REFERENCES dbo.Usuarios(Id),
    CONSTRAINT CK_Ordenes_Estado      CHECK (Estado IN ('ACTIVA', 'COMPLETADA')),
    CONSTRAINT CK_Ordenes_Total       CHECK (TotalVentanas > 0)
);
GO

-- ============================================================
-- Tabla: Ventanas
-- ============================================================
IF OBJECT_ID('dbo.Ventanas', 'U') IS NOT NULL DROP TABLE dbo.Ventanas;
GO

CREATE TABLE dbo.Ventanas (
    Id                UNIQUEIDENTIFIER NOT NULL CONSTRAINT DF_Ventanas_Id DEFAULT NEWID(),
    CodigoQR          NVARCHAR(100)    NOT NULL,
    OrdenProduccionId INT              NOT NULL,
    EstacionActualId  INT              NULL,
    Estado            NVARCHAR(20)     NOT NULL CONSTRAINT DF_Ventanas_Estado DEFAULT 'PENDIENTE',
    FechaCreacion     DATETIME2        NOT NULL CONSTRAINT DF_Ventanas_Fecha DEFAULT GETDATE(),
    CONSTRAINT PK_Ventanas           PRIMARY KEY (Id),
    CONSTRAINT UQ_Ventanas_QR        UNIQUE (CodigoQR),
    CONSTRAINT FK_Ventanas_Orden     FOREIGN KEY (OrdenProduccionId) REFERENCES dbo.OrdenesProd(Id),
    CONSTRAINT FK_Ventanas_Estacion  FOREIGN KEY (EstacionActualId)  REFERENCES dbo.Estaciones(Id),
    CONSTRAINT CK_Ventanas_Estado    CHECK (Estado IN ('PENDIENTE', 'EN_PROCESO', 'COMPLETADA'))
);
GO

-- ============================================================
-- Tabla: MovimientosVentana  (historial de trazabilidad)
-- ============================================================
IF OBJECT_ID('dbo.MovimientosVentana', 'U') IS NOT NULL DROP TABLE dbo.MovimientosVentana;
GO

CREATE TABLE dbo.MovimientosVentana (
    Id              INT              IDENTITY(1,1) NOT NULL,
    VentanaId       UNIQUEIDENTIFIER               NOT NULL,
    EstacionId      INT                            NOT NULL,
    UsuarioId       INT                            NOT NULL,
    FechaMovimiento DATETIME2                      NOT NULL CONSTRAINT DF_Movimientos_Fecha DEFAULT GETDATE(),
    Observacion     NVARCHAR(500)                  NULL,
    CONSTRAINT PK_Movimientos          PRIMARY KEY (Id),
    CONSTRAINT FK_Mov_Ventana          FOREIGN KEY (VentanaId)  REFERENCES dbo.Ventanas(Id),
    CONSTRAINT FK_Mov_Estacion         FOREIGN KEY (EstacionId) REFERENCES dbo.Estaciones(Id),
    CONSTRAINT FK_Mov_Usuario          FOREIGN KEY (UsuarioId)  REFERENCES dbo.Usuarios(Id)
);
GO

-- ============================================================
-- Tabla: AuditoriaAcciones
-- ============================================================
IF OBJECT_ID('dbo.AuditoriaAcciones', 'U') IS NOT NULL DROP TABLE dbo.AuditoriaAcciones;
GO

CREATE TABLE dbo.AuditoriaAcciones (
    Id         INT            IDENTITY(1,1) NOT NULL,
    Tabla      NVARCHAR(100)                NOT NULL,
    Accion     NVARCHAR(50)                 NOT NULL,
    RegistroId NVARCHAR(100)                NULL,
    UsuarioId  INT                          NULL,
    Fecha      DATETIME2                    NOT NULL CONSTRAINT DF_Auditoria_Fecha DEFAULT GETDATE(),
    Detalle    NVARCHAR(MAX)                NULL,
    CONSTRAINT PK_Auditoria       PRIMARY KEY (Id),
    CONSTRAINT FK_Audit_Usuario   FOREIGN KEY (UsuarioId) REFERENCES dbo.Usuarios(Id)
);
GO

-- ============================================================
-- Índices
-- ============================================================
CREATE INDEX IX_Ventanas_OrdenId      ON dbo.Ventanas          (OrdenProduccionId);
CREATE INDEX IX_Ventanas_EstacionId   ON dbo.Ventanas          (EstacionActualId);
CREATE INDEX IX_Ventanas_Estado       ON dbo.Ventanas          (Estado);
CREATE INDEX IX_Movimientos_Ventana   ON dbo.MovimientosVentana (VentanaId);
CREATE INDEX IX_Movimientos_Fecha     ON dbo.MovimientosVentana (FechaMovimiento DESC);
CREATE INDEX IX_Ordenes_Estado        ON dbo.OrdenesProd        (Estado);
GO
