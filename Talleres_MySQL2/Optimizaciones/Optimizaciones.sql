use BancoDB;

DESCRIBE Cuentas;
desc historial_transferencias;


-- 1. Agregar las columnas faltantes a la tabla Cuentas
ALTER TABLE Cuentas 
ADD COLUMN tipo_cuenta VARCHAR(20) NOT NULL DEFAULT 'Ahorros',
ADD COLUMN fecha_apertura DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP;

-- 2. Agregar la columna faltante a historial_transferencias
ALTER TABLE historial_transferencias 
ADD COLUMN estado_transferencia VARCHAR(20) NOT NULL DEFAULT 'Exitosa';

-- Asignar variaciones en Cuentas
UPDATE Cuentas SET tipo_cuenta = 'Corriente' WHERE MOD(id_cuenta, 2) = 0;

-- Asignar variaciones en historial_transferencias
UPDATE historial_transferencias SET estado_transferencia = 'Fallida' WHERE MOD(id_transferencia, 15) = 0;

USE BancoDB;

USE BancoDB;

-- ==============================================================================
-- PARTE 1: DEMOSTRACIÓN GUIADA EN CLASE (PROFESOR)
-- ==============================================================================

-- PROBLEMA: Búsqueda de transferencias por estado y rango de fechas sin índice secundario.
-- Analizar el costo de ejecución antes de optimizar:
EXPLAIN ANALYZE
SELECT id_transferencia, cuenta_origen, monto, fecha
FROM historial_transferencias
WHERE estado_transferencia = 'Exitosa'
  AND fecha >= '2026-01-01 00:00:00';

-- SOLUCIÓN DEMOSTRATIVA: Crear índice compuesto ordenado por discriminación.
-- Nota: Si el índice ya existe, primero se elimina para evitar duplicados
ALTER TABLE historial_transferencias DROP INDEX idx_transf_estado_fecha;
CREATE INDEX idx_transf_estado_fecha ON historial_transferencias(estado_transferencia, fecha);

-- RE-EVALUACIÓN:
EXPLAIN ANALYZE
SELECT id_transferencia, cuenta_origen, monto, fecha
FROM historial_transferencias
WHERE estado_transferencia = 'Exitosa'
  AND fecha >= '2026-01-01 00:00:00';


-- ==============================================================================
-- PARTE 2: EJERCICIOS PRÁCTICOS PARA LOS ESTUDIANTES (RESUELTOS)
-- ==============================================================================

-- ------------------------------------------------------------------------------
-- EJERCICIO 1: Diagnóstico de "Non-Sargable Query" (Uso de Funciones en WHERE)
-- ------------------------------------------------------------------------------

-- BASE INEFICIENTE:
EXPLAIN ANALYZE
SELECT * 
FROM historial_transferencias 
WHERE DATE(fecha) = '2026-02-15';

/*
 RESPUESTAS:
 1. Explica por qué el índice 'idx_transf_estado_fecha' NO es utilizado por MySQL:
    Al envolver la columna 'fecha' en la función DATE(), MySQL debe ejecutar la función 
    fila por fila en lugar de buscar directamente en la estructura B-Tree del índice.

 2 y 3. Consulta reescrita de forma sargable y análisis con EXPLAIN ANALYZE:
*/
EXPLAIN ANALYZE
SELECT * 
FROM historial_transferencias 
WHERE fecha >= '2026-02-15 00:00:00' 
  AND fecha <  '2026-02-16 00:00:00';


-- ------------------------------------------------------------------------------
-- EJERCICIO 2: Optimización mediante Índices Cubrientes (Covering Index)
-- ------------------------------------------------------------------------------

-- BASE INEFICIENTE:
EXPLAIN ANALYZE
SELECT titular, saldo, tipo_cuenta
FROM Cuentas
WHERE estado = 'Activa';

/*
 RESPUESTAS:
 1. Analiza el impacto de usar SELECT * vs seleccionar solo los campos estrictamente necesarios:
    Usar SELECT * obliga a consultar la tabla física en disco. Limitar las columnas 
    permite que el índice contenga todo lo requerido sin tocar la tabla principal.

 2. Diseña un Índice Cubriente:
*/
ALTER TABLE Cuentas DROP INDEX idx_cuentas_cubriente;
CREATE INDEX idx_cuentas_cubriente ON Cuentas(estado, titular, saldo, tipo_cuenta);

-- 3. Verifica que la salida indique "Using index":
EXPLAIN ANALYZE
SELECT titular, saldo, tipo_cuenta
FROM Cuentas
WHERE estado = 'Activa';


-- ------------------------------------------------------------------------------
-- EJERCICIO 3: Optimización de Filtros Combinados y JOINs
-- ------------------------------------------------------------------------------

-- BASE INEFICIENTE:
EXPLAIN ANALYZE
SELECT c.id_cuenta, c.titular, ht.id_transferencia, ht.monto, ht.fecha
FROM Cuentas c
JOIN historial_transferencias ht ON c.id_cuenta = ht.cuenta_origen
WHERE c.estado = 'Activa'
  AND ht.monto > 300000.00;

/*
 RESPUESTAS:
 1. Identifica cuál tabla es escaneada por completo:
    Se escanean 'Cuentas' e 'historial_transferencias' al no tener índices para el WHERE y el JOIN.

 2 y 3. Índices necesarios y justificación del orden de columnas:
    - En 'Cuentas': (estado, id_cuenta) filtra el estado y acelera la unión por id.
    - En 'historial_transferencias': (cuenta_origen, monto) une las tablas por cuenta origen 
      y evalúa el filtro de monto eficientemente.
*/
ALTER TABLE Cuentas DROP INDEX idx_cuentas_estado;
CREATE INDEX idx_cuentas_estado ON Cuentas(estado, id_cuenta);

ALTER TABLE historial_transferencias DROP INDEX idx_transf_origen_monto;
CREATE INDEX idx_transf_origen_monto ON historial_transferencias(cuenta_origen, monto);

-- Verificación optimizada:
EXPLAIN ANALYZE
SELECT c.id_cuenta, c.titular, ht.id_transferencia, ht.monto, ht.fecha
FROM Cuentas c
JOIN historial_transferencias ht ON c.id_cuenta = ht.cuenta_origen
WHERE c.estado = 'Activa'
  AND ht.monto > 300000.00;