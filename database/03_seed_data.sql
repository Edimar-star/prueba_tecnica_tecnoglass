-- ============================================================
-- Tecnoglass | Sistema de Trazabilidad de Producción
-- Seed: Datos iniciales obligatorios
-- ============================================================

USE TecnoglassDB;
GO

-- ============================================================
-- Estaciones (orden fijo del flujo de manufactura)
-- ============================================================
SET IDENTITY_INSERT dbo.Estaciones ON;

INSERT INTO dbo.Estaciones (Id, Nombre, Orden) VALUES
(1, 'Corte',    1),
(2, 'Troquel',  2),
(3, 'Ensamble', 3),
(4, 'Empaque',  4);

SET IDENTITY_INSERT dbo.Estaciones OFF;
GO

-- ============================================================
-- Usuarios iniciales
-- Contraseñas en texto plano (ver README para hash):
--   admin     → Admin123!
--   operador1 → Operador123!
--
-- Los hashes siguientes son bcrypt cost=12 generados con passlib.
-- Para regenerarlos: python backend/create_admin.py
-- ============================================================
INSERT INTO dbo.Usuarios (Username, PasswordHash, Nombre, Rol) VALUES
(
    'admin',
    '$2b$12$LQv3c1yqBWVHxkd0LHAkCOYz6TtxMQJqhN8/LewYpfQNpOH9cPDpq',
    'Administrador del Sistema',
    'ADMIN'
),
(
    'operador1',
    '$2b$12$EixZaYVK1fsbw1ZfbX3OXePaWxn96p36WQoeG6Lruj3vjPGga31lW',
    'Operador Uno',
    'OPERADOR'
);
GO

-- Nota: los hashes de arriba son ejemplos. Ejecutar el script
-- backend/create_admin.py para crear usuarios con contraseñas reales.
