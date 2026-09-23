use BancoDB;

create table if not exists Cuentas(
id_cuenta INT PRIMARY KEY,
titular VARCHAR(100),
saldo DECIMAL(10,2)
);

desc Cuentas;

CREATE TABLE if not exists historial_transferencias (
id_transferencia INT AUTO_INCREMENT PRIMARY KEY,
cuenta_origen INT,
cuenta_destino INT,
monto DECIMAL(10,2),
fecha TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

insert ignore into Cuentas (id_cuenta, titular, saldo)
values (1, 'Ana López', 5000.00),
(2, 'Carlos Pérez', 3000.00);


DELIMITER //

DROP PROCEDURE IF EXISTS TransferirFondos //

CREATE PROCEDURE TransferirFondos(
    IN p_origen INT,
    IN p_destino INT,
    IN p_monto DECIMAL(10,2),
    OUT p_codigo_respuesta INT
)
BEGIN
    DECLARE v_saldo DECIMAL(10,2);

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        SET p_codigo_respuesta = 500;
    END;

    START TRANSACTION;

    SELECT saldo INTO v_saldo
    FROM Cuentas
    WHERE id_cuenta = p_origen
    FOR UPDATE;

    IF v_saldo IS NOT NULL AND v_saldo >= p_monto THEN
        UPDATE Cuentas
        SET saldo = saldo - p_monto
        WHERE id_cuenta = p_origen;

        UPDATE Cuentas
        SET saldo = saldo + p_monto
        WHERE id_cuenta = p_destino;

        INSERT INTO historial_transferencias (cuenta_origen, cuenta_destino, monto)
        VALUES (p_origen, p_destino, p_monto);

        COMMIT;

        SET p_codigo_respuesta = 200;
    ELSE
    
        ROLLBACK;
        SET p_codigo_respuesta = 400;
    END IF;

END //

DELIMITER ;

CALL TransferirFondos(1,2,1000,@codigo);
SELECT @codigo;

CALL TransferirFondos(1, 2, 10000, @codigo);
SELECT @codigo;



































