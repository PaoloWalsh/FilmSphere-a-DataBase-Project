USE FilmSphere;

-- Controllo l'anno di un nuovo film
DROP TRIGGER IF EXISTS CheckAnnoFilm;
DELIMITER $$
CREATE TRIGGER CheckAnnoFilm
BEFORE INSERT ON Film
FOR EACH ROW
BEGIN
	DECLARE current_year INT;
    SET current_year = YEAR(CURDATE());
    
	IF (NEW.Anno > current_year) THEN
		SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'L\'Anno di uscita del Film deve essere inferiore all\'anno corrente';
	END IF;
END $$
DELIMITER ;

-- Controllo la data di una Vincita
DROP TRIGGER IF EXISTS CheckDataVincita;
DELIMITER $$
CREATE TRIGGER CheckDataVincita
BEFORE INSERT ON Vincita
FOR EACH ROW
BEGIN
	IF (NEW.Data > current_date()) THEN
		SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'La Data della Vincita non può essere futura';
	END IF;
END $$
DELIMITER ;

-- Controllo la data di una PagamentoEffettuato
DROP TRIGGER IF EXISTS CheckDataPagamentoEffettuato;
DELIMITER $$
CREATE TRIGGER CheckDataPagamentoEffettuato
BEFORE INSERT ON PagamentoEffettuato
FOR EACH ROW
BEGIN
	IF (NEW.Data > current_date()) THEN
		SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'La Data del PagamentoEffettuato non può essere futura';
	END IF;
END $$
DELIMITER ;

-- Controllo la data di una PagamentoAtteso
DROP TRIGGER IF EXISTS CheckDataPagamentoAtteso;
DELIMITER $$
CREATE TRIGGER CheckDataPagamentoAtteso
BEFORE INSERT ON PagamentoAtteso
FOR EACH ROW
BEGIN
	IF (NEW.Data <= current_date()) THEN
		SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'La Data del PagamentoAtteso deve essere futura';
	END IF;
END $$
DELIMITER ;