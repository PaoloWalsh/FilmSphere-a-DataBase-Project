-- Aggiorno la banda disponibile di un server dopo che finisce la visualizzazione
DROP TRIGGER IF EXISTS AggiornaBandaDisponibileTrigger;
DELIMITER $$
CREATE TRIGGER AggiornaBandaDisponibileTrigger
AFTER UPDATE ON Visualizzazione
FOR EACH ROW
BEGIN
	IF NEW.TempoFineV <> OLD.TempoFineV THEN
		CALL AggiornaBandaDisponibile(NEW.TimeStampV, NEW.TimeStampC, NEW.CodiceDispositivo);
	END IF;
END $$
DELIMITER ;

DROP PROCEDURE IF EXISTS AggiornaBandaDisponibile;
DELIMITER $$
CREATE PROCEDURE AggiornaBandaDisponibile(IN TimeStampV_ TIMESTAMP, IN TimeStampC_ TIMESTAMP, IN CodiceDispositivo_ VARCHAR(50))
BEGIN
	DECLARE ServerT_ VARCHAR(50);
    DECLARE BandaFilm_ VARCHAR(50);
    SET ServerT_ = (SELECT CodiceServer FROM Presso WHERE TimeStampV = TimeStampV_ AND TimeStampC = TimeStampC_ AND CodiceDispositivo = CodiceDispositivo_);
    SET BandaFilm_ = 
		(
			SELECT IF(FV.Risoluzione = '720p', 3, IF(FV.Risoluzione = '1080p', 5, IF(FV.Risoluzione = '4k', 15, 0)))
            FROM Visualizzazione NATURAL JOIN FileFilm NATURAL JOIN Contenitore NATURAL JOIN FormatoVideo FV
            WHERE TimeStampV = TimeStampV_ AND TimeStampC = TimeStampC_ AND CodiceDispositivo = CodiceDispositivo_
        );
        
	UPDATE ServerCDN
    SET BandaDisponibile = BandaDisponibile + BandaFilm_
    WHERE CodiceServer = ServerT_;
END $$
DELIMITER ;