use BancoDB;

CREATE TABLE IF NOT EXISTS auditoria_saldos (
    id_log INT AUTO_INCREMENT PRIMARY KEY,
    id_cuenta INT NOT NULL,
    saldo_anterior DECIMAL(10,2) NOT NULL,
    saldo_nuevo DECIMAL(10,2) NOT NULL,
    usuario VARCHAR(100) NOT NULL,
    fecha_modificacion TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (id_cuenta) REFERENCES Cuentas (id_cuenta)
);

CREATE TABLE IF NOT EXISTS metricas_diarias (
    id_metrica INT AUTO_INCREMENT PRIMARY KEY,
    fecha_metrica DATE NOT NULL,
    total_cuentas INT NOT NULL,
    saldo_total_sistema DECIMAL(12,2) NOT NULL,
    fecha_registro TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

SET GLOBAL event_scheduler = ON;

DELIMITER //

DROP TRIGGER IF EXISTS trg_auditar_cambio_saldo //

CREATE TRIGGER trg_auditar_cambio_saldo
AFTER UPDATE ON Cuentas
FOR EACH ROW
BEGIN
    -- Detectar si hubo una modificación efectiva en la columna saldo
    IF OLD.saldo <> NEW.saldo THEN
        INSERT INTO auditoria_saldos (
            id_cuenta, 
            saldo_anterior, 
            saldo_nuevo, 
            usuario
        ) 
        VALUES (
            NEW.id_cuenta, 
            OLD.saldo, 
            NEW.saldo, 
            USER()
        );
    END IF;
END //

DELIMITER ;

INSERT INTO Cuentas (id_cuenta, saldo) 
VALUES (3, 1000.00) 
ON DUPLICATE KEY UPDATE saldo = saldo;
UPDATE Cuentas SET saldo = saldo + 500.00 WHERE id_cuenta = 3;
SELECT * FROM auditoria_saldos;

SHOW TRIGGERS WHERE `Table` = 'Cuentas';

/*evento*/

DELIMITER //

DROP EVENT IF EXISTS evt_registrar_metricas_diarias //

CREATE EVENT evt_registrar_metricas_diarias
ON SCHEDULE EVERY 10 day
STARTS CURRENT_TIMESTAMP
ON COMPLETION PRESERVE
COMMENT 'Consolida el saldo total y cantidad de cuentas activas diariamente'
DO
BEGIN
    INSERT INTO metricas_diarias (fecha_metrica, total_cuentas, saldo_total_sistema)
    SELECT 
        CURDATE(),
        COUNT(id_cuenta),
        IFNULL(SUM(saldo), 0.00)
    FROM Cuentas
    WHERE estado = 'Activa';
END //

DELIMITER ;

SHOW EVENTS FROM BancoDB;
SELECT * FROM metricas_diarias;

ALTER EVENT evt_registrar_metricas_diarias DISABLE;


-- ejercicio de trigger

DELIMITER //

DROP TRIGGER IF EXISTS trg_validar_transferencia //

CREATE TRIGGER trg_validar_transferencia
BEFORE INSERT ON historial_transferencias
FOR EACH ROW
BEGIN
    IF NEW.monto <= 0 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Error: El monto de la transferencia debe ser mayor a cero.';
    END IF;

    IF NEW.cuenta_origen = NEW.cuenta_destino THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Error: La cuenta de origen y destino no pueden ser iguales.';
    END IF;
END //

DELIMITER ;

-- ejercicio del evento


DELIMITER //

DROP EVENT IF EXISTS evt_inactivar_cuentas_vacias //

CREATE EVENT evt_inactivar_cuentas_vacias
ON SCHEDULE EVERY 1 DAY
STARTS CURRENT_TIMESTAMP
ON COMPLETION PRESERVE
COMMENT 'Cambia a Inactiva el estado de las cuentas con saldo igual a 0.00'
DO
BEGIN
    UPDATE Cuentas 
    SET estado = 'Inactiva' 
    WHERE saldo = 0.00 
      AND estado = 'Activa';
END //

DELIMITER ;

ALTER TABLE Cuentas ADD COLUMN estado VARCHAR(20) DEFAULT 'Activa';

INSERT INTO Cuentas (id_cuenta, titular, saldo, estado) VALUES
(101, 'Laura Gómez', 0.00, 'Activa'),
(102, 'Pedro Martínez', 150.00, 'Activa'),
(103, 'Sofía Ramírez', 0.00, 'Inactiva');

SELECT * FROM Cuentas WHERE id_cuenta IN (101, 102, 103);

UPDATE Cuentas 
SET estado = 'Inactiva' 
WHERE saldo = 0.00 
  AND estado = 'Activa';

SELECT * FROM Cuentas WHERE id_cuenta IN (101, 102, 103);

show events from BancoDB;


-- desactivacion del evento evt_inactivar_cuentas_vacias
ALTER EVENT evt_inactivar_cuentas_vacias DISABLE;


































