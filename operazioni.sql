-- ------------------- -- 
-- Calcolo Rating Film --
-- ------------------- -- 

USE FilmSphere;
DROP PROCEDURE IF EXISTS CalcoloRatingFilm;
DELIMITER $$
CREATE PROCEDURE CalcoloRatingFilm(in CF varchar(50))-- , OUT Rating INT)
sp :BEGIN
	DECLARE UT VARCHAR(50);
    DECLARE FILM VARCHAR(50);
    DECLARE UP INT DEFAULT 0;
    DECLARE DOWN INT DEFAULT 0;
    DECLARE PESO FLOAT DEFAULT 0;
    DECLARE VOTO FLOAT DEFAULT 0;
    DECLARE FVOTO FLOAT DEFAULT 0;
    DECLARE FPESO FLOAT DEFAULT 0;
    DECLARE SOMMAVOTI FLOAT DEFAULT 0;
    DECLARE SOMMAPESI FLOAT DEFAULT 0;
    DECLARE NOMEPREMIO_ VARCHAR(50);
    DECLARE VOLTEPREMIO_ VARCHAR(50);
    DECLARE SOMMAPREMI FLOAT DEFAULT 0;
    DECLARE MEDIA FLOAT DEFAULT 0;
    DECLARE MEDIAFINALE FLOAT DEFAULT 0;
	DECLARE FINITO INT DEFAULT 0;
    
	DECLARE cur CURSOR FOR
	WITH
		FilmRecensioni as
    (
		SELECT *
        FROM Recensione R 
        WHERE R.CodiceFilm = CF
    )
    SELECT Valutazione, Upvote, Downvote
    FROM FilmRecensioni;
    
    DECLARE cur2 CURSOR FOR
    SELECT *
    FROM AppoggioRating;
    
    DECLARE cur3 CURSOR FOR
    SELECT NomePremio, count(*) as VoltePremio
    FROM Vincita
    WHERE CodiceFilm = CF
    GROUP BY CodiceFilm, NomePremio;
    
    DECLARE CONTINUE HANDLER FOR NOT FOUND SET FINITO = 1;
    
    IF NOT EXISTS (SELECT *
					FROM Film F INNER JOIN Recensione R ON F.CodiceFilm = R.CodiceFilm
					WHERE F.CodiceFilm = CF) THEN
		LEAVE sp;
    END IF;
    
    DROP TABLE IF EXISTS `AppoggioRating`;
    CREATE TABLE `AppoggioRating` (
        Voto_ float not null,
        Peso_ float not null
    );
    
    OPEN cur;	-- LOOP per il calcolo del peso di una recensione
    SCAN: LOOP
		FETCH cur INTO VOTO, UP, DOWN;
        IF FINITO = 1 THEN
			LEAVE SCAN;
		END IF;
		IF (UP-DOWN) >= 0 THEN
			SET PESO = (UP-DOWN);
		ELSE
			SET PESO = 1/(DOWN-UP);
		END IF;
		INSERT INTO AppoggioRating VALUES (VOTO, PESO);
	END LOOP SCAN;
    CLOSE cur;
    SET FINITO = 0;
    
    
    
	OPEN cur2;		-- calcolo media pesata delle recensioni
    
    SCAN2: LOOP
		FETCH cur2 INTO FVOTO, FPESO;
        IF FINITO = 1 THEN
			LEAVE SCAN2;
		END IF;
        SET SOMMAVOTI = SOMMAVOTI + (FVOTO*FPESO);
        SET SOMMAPESI = SOMMAPESI + FPESO;
	END LOOP SCAN2;
    CLOSE cur2;
    SET FINITO = 0;
    SET MEDIA = SOMMAVOTI/SOMMAPESI;
    SET MEDIA = (MEDIA * 9)/10;
    
    
    
    OPEN cur3;
    SCAN3: LOOP
		FETCH cur3 INTO NOMEPREMIO_, VOLTEPREMIO_;
         IF FINITO = 1 THEN
			LEAVE SCAN3;
		END IF;
        
		IF NOMEPREMIO_ = 'Oscar' THEN
			SET SOMMAPREMI = 0.2 * VOLTEPREMIO_;
		ELSEIF NOMEPREMIO_ = 'Golden Globe Awards' THEN
			SET SOMMAPREMI = 0.18 * VOLTEPREMIO_;
		ELSEIF NOMEPREMIO_ = 'BAFTA' THEN
			SET SOMMAPREMI = 0.16 * VOLTEPREMIO_;
		ELSEIF NOMEPREMIO_ = 'Cannes Film Festival Awards' THEN
			SET SOMMAPREMI = 0.19 * VOLTEPREMIO_;
		ELSEIF NOMEPREMIO_ = 'Venice Film Festival Awards' THEN
			SET SOMMAPREMI = 0.19 * VOLTEPREMIO_;
    END IF;
    END LOOP SCAN3;
    CLOSE cur3;
    
    IF(SOMMAPREMI > 1) THEN
		SET SOMMAPREMI = 1;
	END IF;
    
    SET MEDIAFINALE = MEDIA + SOMMAPREMI;
    
    UPDATE Film F
    SET F.Rating = MEDIAFINALE
    WHERE F.CodiceFilm = CF;
    
    DROP TABLE IF EXISTS `AppoggioRating`;
END $$
DELIMITER ;

DROP PROCEDURE IF EXISTS AggiornaRating;
DELIMITER $$
CREATE PROCEDURE AggiornaRating()
BEGIN
	DECLARE FILM VARCHAR(50);
    DECLARE FINITO INT DEFAULT 0;
    
	DECLARE cur CURSOR FOR
    SELECT CodiceFilm
    FROM Film;
    
    DECLARE CONTINUE HANDLER FOR NOT FOUND SET FINITO = 1;
    OPEN cur;
    SCAN: LOOP
		FETCH cur INTO FILM;
        IF FINITO = 1 THEN
			LEAVE SCAN;
		END IF;
        CALL CalcoloRatingFilm(FILM);
	END LOOP SCAN;
    CLOSE CUR;
END $$
DELIMITER ;

DROP EVENT IF EXISTS AggiornaRatingEvento;
CREATE EVENT AggiornaRatingEvento
ON SCHEDULE EVERY 1 DAY
STARTS '2023-01-01 00:00:00'
DO
    CALL AggiornaRating();

-- ------------------------- -- 
-- Raccomandazione Contenuti --
-- ------------------------- -- 

USE FilmSphere;
DROP PROCEDURE IF EXISTS CalcoloRaccomandazioneContenuti;
DELIMITER $$
CREATE PROCEDURE CalcoloRaccomandazioneContenuti(IN UT VARCHAR(50))
BEGIN
	DECLARE APPOGGIO INT DEFAULT 0;

	DECLARE GENERE1 VARCHAR(50);
    DECLARE GENERE2 VARCHAR(50);
    DECLARE GENERE3 VARCHAR(50);
    DECLARE FGENERE VARCHAR(50);
    
    DECLARE ATTORE1 VARCHAR(50);
    DECLARE ATTORE2 VARCHAR(50);
    DECLARE ATTORE3 VARCHAR(50);
    DECLARE ATTORE4 VARCHAR(50);
    DECLARE ATTORE5 VARCHAR(50);
    DECLARE FATTORE VARCHAR(50);
    
    DECLARE REGISTA1 VARCHAR(50);
    DECLARE REGISTA2 VARCHAR(50);
    DECLARE REGISTA3 VARCHAR(50);
    DECLARE FREGISTA VARCHAR(50);
    
    DECLARE FILMP VARCHAR(50); -- FILM PRECEDENTE PER CALCOLARE PUNTEGGIO
    DECLARE FFILM VARCHAR(50); -- FETCH DEI FILM
    DECLARE FGENERE_ VARCHAR(50); 
    DECLARE FATTORE_ VARCHAR(50);
    DECLARE FREGISTA_ VARCHAR(50);
    DECLARE FRATING FLOAT DEFAULT 0;
    
    DECLARE FPUNTEGGIO INT DEFAULT 0;
	
    DECLARE I INT DEFAULT 0;
    DECLARE FINITO INT DEFAULT 0;
    
    DECLARE CursoreGeneri CURSOR FOR
	WITH TopGeneri as (
    SELECT NomeGenere, COUNT(*) as NFilm
    FROM Connessione C INNER JOIN Visualizzazione V 
		on C.TimeStampC = V.TimeStampC AND C.CodiceDispositivo = V.CodiceDispositivo
        INNER JOIN FileFilm FF on V.CodiceFile = FF.CodiceFile 
		INNER JOIN Classificazione CC on FF.CodiceFilm = CC.CodiceFilm
	WHERE C.CodiceUtente = UT
    GROUP BY C.CodiceUtente, CC.NomeGenere
    ORDER BY NFilm DESC
    LIMIT 3
    )
    SELECT * 
    FROM TopGeneri;
    
	DECLARE CursoreAttori CURSOR FOR
    WITH TopAttori as (
    SELECT P.CodiceAttore, COUNT(*) as VolteAttore
    FROM Connessione C INNER JOIN Visualizzazione V 
		on C.TimeStampC = V.TimeStampC AND C.CodiceDispositivo = V.CodiceDispositivo
        INNER JOIN FileFilm FF on V.CodiceFile = FF.CodiceFile 
        INNER JOIN Partecipazione P on FF.CodiceFilm = P.CodiceFilm
	WHERE C.CodiceUtente = UT
    GROUP BY CodiceUtente, P.CodiceAttore
    ORDER BY VolteAttore DESC
    LIMIT 5
    )
    SELECT *
    FROM TopAttori;
    
    DECLARE CursoreRegisti CURSOR FOR
    WITH TopRegisti as (
	SELECT F.Regista, COUNT(*) as VolteRegista
    FROM Connessione C INNER JOIN Visualizzazione V 
		on C.TimeStampC = V.TimeStampC AND C.CodiceDispositivo = V.CodiceDispositivo
        INNER JOIN FileFilm FF on V.CodiceFile = FF.CodiceFile 
        INNER JOIN Film F on FF.CodiceFilm = F.CodiceFilm
	WHERE C.CodiceUtente = UT
    GROUP BY CodiceUtente, F.Regista
    ORDER BY VolteRegista DESC
    LIMIT 3
    )
	SELECT *
    FROM TopRegisti;
    
    DECLARE CusoreFilmNVistiAttori CURSOR FOR	
    WITH FilmNVisti AS (
		SELECT F.CodiceFilm
		FROM Film F
		WHERE F.CodiceFilm NOT IN 
			(SELECT FF.CodiceFilm
			FROM Connessione C INNER JOIN Visualizzazione V on C.CodiceDispositivo = V.CodiceDispositivo
				AND C.TimeStampC = V.TimeStampC INNER JOIN FileFilm FF on V.CodiceFile = FF.CodiceFile
			WHERE C.CodiceUtente = UT
			)
	), FilmNVistiAttori as (
		SELECT FN.CodiceFilm, P.CodiceAttore
        FROM FilmNVisti FN NATURAL JOIN Partecipazione P
    )
    SELECT *					-- Film non visti con accanto i propri attori
    FROM FilmNVistiAttori
    ORDER BY CodiceFilm;
    
    DECLARE CursoreFilmNVistiGeneri CURSOR FOR
    WITH FilmNVisti AS (
		SELECT F.CodiceFilm
		FROM Film F
		WHERE F.CodiceFilm NOT IN 
			(SELECT FF.CodiceFilm
			FROM Connessione C INNER JOIN Visualizzazione V on C.CodiceDispositivo = V.CodiceDispositivo
				AND C.TimeStampC = V.TimeStampC INNER JOIN FileFilm FF on V.CodiceFile = FF.CodiceFile
			WHERE C.CodiceUtente = UT
			)
	), FilmNVistiGeneri as (
		SELECT FN.CodiceFilm, C.NomeGenere
        FROM FilmNVisti FN NATURAL JOIN Classificazione C
    )
    SELECT *			-- Film non visti con accanto i propri generi
    FROM FilmNVistiGeneri
    ORDER BY CodiceFilm;
    
    DECLARE CursoreFilmNVistiRegisti CURSOR FOR
    WITH FilmNVistiRegisti as (
		SELECT F.CodiceFilm, F.Regista, F.Rating
		FROM Film F
		WHERE F.CodiceFilm NOT IN 
			(SELECT FF.CodiceFilm
			FROM Connessione C INNER JOIN Visualizzazione V on C.CodiceDispositivo = V.CodiceDispositivo
				AND C.TimeStampC = V.TimeStampC INNER JOIN FileFilm FF on V.CodiceFile = FF.CodiceFile
			WHERE C.CodiceUtente = UT
			)
	)
    SELECT *					-- Film non visti con accanto il proprio regista
    FROM FilmNVistiRegisti;
    
    DECLARE CursoreAppoggio CURSOR FOR
    SELECT * 
    FROM AppoggioRaccomandazioni;
    
    DECLARE CONTINUE HANDLER FOR NOT FOUND SET FINITO = 1;
    
    
    OPEN CursoreGeneri;
    WHILE I < 3 DO
		FETCH CursoreGeneri INTO FGENERE, APPOGGIO;
		IF I = 0 THEN
			SET GENERE1 = FGENERE;
		ELSEIF I = 1 THEN
			SET GENERE2 = FGENERE;
		ELSEIF I = 2 THEN
			SET GENERE3 = FGENERE;
		END IF;
        SET I = I + 1;
	END WHILE;
    CLOSE CursoreGeneri;
    
    SET I = 0;
    OPEN CursoreAttori;
    WHILE I < 5 DO
		FETCH CursoreAttori INTO FATTORE, APPOGGIO;
		IF I = 0 THEN
			SET ATTORE1 = FATTORE;
		ELSEIF I = 1 THEN
			SET ATTORE2 = FATTORE;
		ELSEIF I = 2 THEN
			SET ATTORE3 = FATTORE;
		ELSEIF I = 3 THEN
			SET ATTORE4 = FATTORE;
		ELSEIF I = 4 THEN
			SET ATTORE5 = FATTORE;
		END IF;
        SET I = I + 1;
	END WHILE;
	CLOSE CursoreAttori;
  
    SET I = 0;
    OPEN CursoreRegisti;
    WHILE I < 3 DO
		FETCH CursoreRegisti INTO FREGISTA, APPOGGIO;
		IF I = 0 THEN
			SET REGISTA1 = FREGISTA;
		ELSEIF I = 1 THEN
			SET REGISTA2 = FREGISTA;
		ELSEIF I = 2 THEN
			SET REGISTA3 = FREGISTA;
		END IF;
        SET I = I + 1;
	END WHILE;
    CLOSE CursoreRegisti;
    
    DROP TABLE IF EXISTS `AppoggioRaccomandazioni`;
    CREATE TABLE `AppoggioRaccomandazioni` (
		`CodiceFilm` VARCHAR(50) NOT NULL,
        `Punteggio` INT NOT NULL,
        PRIMARY KEY (`CodiceFilm`)
    );
    
    SET FINITO = 0;
    SET I = 0;
    SET FPUNTEGGIO = 0;
    OPEN CursoreFilmNVistiGeneri;
    SCANG: LOOP
		FETCH CursoreFilmNVistiGeneri INTO FFILM, FGENERE_;			-- FILMP è il film di cui sto calcolando il punteggio
		IF FINITO = 1 THEN
			LEAVE SCANG;
		END IF;
        IF I = 0 THEN
			SET FILMP = FFILM;
		END IF;
        IF FFILM <> FILMP THEN
			-- INSERISCI IN APPOGGIO
            /*
            IF PUNTEGGIO <> 0 THEN -- PER DUBUG
				select PUNTEGGIO;
			END IF;*/
            INSERT INTO AppoggioRaccomandazioni VALUES (FILMP, FPUNTEGGIO);
			SET FPUNTEGGIO = 0;
            SET FILMP = FFILM;
		END IF;
        IF FGENERE_ = GENERE1 THEN
			SET FPUNTEGGIO = FPUNTEGGIO + 100;
		ELSEIF FGENERE_ = GENERE2 THEN
			SET FPUNTEGGIO = FPUNTEGGIO + 85;
		ELSEIF FGENERE_ = GENERE3 THEN
			SET FPUNTEGGIO = FPUNTEGGIO + 70;
		END IF;
		SET I = I + 1;
    END LOOP SCANG;
    CLOSE CursoreFilmNVistiGeneri;
    INSERT INTO AppoggioRaccomandazioni VALUES (FILMP, FPUNTEGGIO); -- aggiungo l'ultimo record 
    
	SET FINITO = 0;
    SET I = 0;
    SET FPUNTEGGIO = 0;
    
    OPEN CursoreFilmNVistiRegisti;
    SCANR: LOOP
		FETCH CursoreFilmNVistiRegisti INTO FFILM, FREGISTA_, FRATING;		-- FILMP è il film di cui sto calcolando il punteggio
		IF FINITO = 1 THEN
			LEAVE SCANR;
		END IF;
        IF I = 0 THEN
			SET FILMP = FFILM;
		END IF;
        IF FFILM <> FILMP THEN
			-- INSERISCI IN APPOGGIO
            UPDATE AppoggioRaccomandazioni SET Punteggio = Punteggio + FPUNTEGGIO WHERE CodiceFilm = FILMP;
			SET FPUNTEGGIO = 0;
            SET FILMP = FFILM;
		END IF;
        IF FREGISTA_ = REGISTA1 OR FREGISTA_ = REGISTA2 OR FREGISTA_ = REGISTA3 THEN
			SET FPUNTEGGIO = FPUNTEGGIO + 35;
		END IF;
        SET FPUNTEGGIO = FPUNTEGGIO + (FRATING * 50);
		SET I = I + 1;
	END LOOP SCANR;
    CLOSE CursoreFilmNVistiRegisti;
    
    UPDATE AppoggioRaccomandazioni SET Punteggio = Punteggio + FPUNTEGGIO WHERE CodiceFilm = FILMP;	-- aggiungo l'ultimo record
    
    SET FPUNTEGGIO = 0;
    SET FINITO = 0;
    SET I = 0;
    OPEN CusoreFilmNVistiAttori;
    SCANA: LOOP
		FETCH CusoreFilmNVistiAttori INTO FFILM, FATTORE_;			-- FILMP è il film di cui sto calcolando il punteggio
        IF FINITO = 1 THEN
			LEAVE SCANA;
		END IF;
        IF I = 0 THEN
			SET FILMP = FFILM;
		END IF;
        IF FFILM <> FILMP THEN
            UPDATE AppoggioRaccomandazioni 
            SET Punteggio = Punteggio + FPUNTEGGIO
			WHERE CodiceFilm = FILMP;
			SET FPUNTEGGIO = 0;
            SET FILMP = FFILM;
		END IF;
        IF (FATTORE_ = ATTORE1) OR (FATTORE_ = ATTORE2) OR (FATTORE_ = ATTORE3) OR (FATTORE_ = ATTORE4) OR (FATTORE_ = ATTORE5) THEN
			SET FPUNTEGGIO = FPUNTEGGIO + 25;
		END IF;
        SET I = I + 1;
	END LOOP SCANA;
    CLOSE CusoreFilmNVistiAttori;
    
    UPDATE AppoggioRaccomandazioni SET Punteggio = Punteggio + FPUNTEGGIO WHERE CodiceFilm = FILMP;	-- aggiungo l'ultimo record

    DELETE FROM Raccomandazioni
    WHERE CodiceUtente = UT;
    
    INSERT INTO Raccomandazioni (CodiceUtente, CodiceFilm, Punteggio)
    SELECT UT, A.CodiceFilm, A.Punteggio
    FROM AppoggioRaccomandazioni A
    ORDER BY A.Punteggio DESC
    LIMIT 5;
    
	DROP TABLE AppoggioRaccomandazioni;
END $$
DELIMITER ;

DROP PROCEDURE IF EXISTS RaccomandazioneContenuti;
DELIMITER $$
CREATE PROCEDURE RaccomandazioneContenuti()
BEGIN
	DECLARE FINITO INT DEFAULT 0;
    DECLARE FUTENTE VARCHAR(50);
    
    DECLARE CUtente CURSOR FOR
    SELECT CodiceUtente
    FROM Utente;
    
	DECLARE CONTINUE HANDLER FOR NOT FOUND SET FINITO = 1;
    OPEN CUtente;
    SCAN: LOOP
		FETCH CUtente INTO FUTENTE;
        IF FINITO = 1 THEN
			LEAVE SCAN;
		END IF;
        CALL CalcoloRaccomandazioneContenuti(FUTENTE);
	END LOOP;
    CLOSE CUtente;
END $$
DELIMITER ;

DROP EVENT IF EXISTS AggiornaRaccomandazioniEvento;
CREATE EVENT AggiornaRaccomandazioniEvento
ON SCHEDULE EVERY 1 DAY
STARTS '2023-01-01 00:00:00'
DO
    CALL RaccomandazioneContenuti();
    
DROP PROCEDURE IF EXISTS MostraRaccomandazioni;
DELIMITER $$
CREATE PROCEDURE MostraRaccomandazioni(IN UT VARCHAR(50))
BEGIN
	IF UT NOT IN (SELECT CodiceUtente
				 FROM Utente) THEN
		SIGNAL SQLSTATE '45000'
		SET MESSAGE_TEXT = "Utente non valido";
	END IF;
	
    SELECT *
	FROM Raccomandazioni
    WHERE CodiceUtente = UT;
END $$
DELIMITER ;

-- ------------------------- -- 
-- Connessione Utente Server --
-- ------------------------- --

USE FilmSphere;
DROP PROCEDURE IF EXISTS ConnessioneUtenteServer;
DELIMITER $$
CREATE PROCEDURE ConnessioneUtenteServer (IN _CodiceUtente VARCHAR(50),
    IN _TimeStampC TIMESTAMP, IN _CodiceDispositivo VARCHAR(50), IN _Ip VARCHAR(50),
    IN _TempoFineC TIMESTAMP, IN _Longitudine FLOAT, IN _Latitudine FLOAT,
    IN _CodiceFilm VARCHAR(50))
BEGIN

	-- devo trovare lo stato da cui faccio la connessione e leggere la prima lingua
    DECLARE StatoC VARCHAR(50);
    DECLARE Lingua VARCHAR(50);
    DECLARE RisoluzioneMAX VARCHAR(50);
    DECLARE CodiceServerF VARCHAR(50);
    DECLARE LongiServerF FLOAT;
    DECLARE LatiServerF FLOAT;
    DECLARE Distanza INT DEFAULT 0;
    DECLARE LarghezzaBandaF INT;
    DECLARE BandaDisponibileF INT;
    DECLARE RCapacita FLOAT;
    DECLARE IndiceServer FLOAT;
    DECLARE FINITO INT DEFAULT 0;
    DECLARE TopServer VARCHAR(50);
    DECLARE FileV VARCHAR(50);
    DECLARE BandaUtilizzata INT;
    
	DECLARE CursoreServer CURSOR FOR	-- SERVER
		WITH FileTarget AS (
			SELECT distinct FF.CodiceFile
			FROM FileFilm FF NATURAL JOIN DisponibilitaAudio DA NATURAL JOIN Contenitore C NATURAL JOIN FormatoVideo FV
			NATURAL JOIN ServerCDN SC NATURAL JOIN Stato S 
			WHERE DA.NomeLingua = (SELECT PrimaLingua
									FROM Stato 
									WHERE (Latitudine = _Latitudine) AND (Longitudine = _Longitudine)
									) AND FF.CodiceFilm = _CodiceFilm AND  FV.Risoluzione = (SELECT PA.Definizione
																							FROM PagamentoEffettuato PE INNER JOIN PianoAbbonamento PA ON PE.PianoAbbonamento = PA.NomeAbbonamento
																							WHERE PE.CodiceUtente = _CodiceUtente
																							ORDER BY PE.Data DESC
																							LIMIT 1
																							)
				AND C.CodiceContenitore NOT IN (SELECT I.CodiceContenitore
												FROM IndisponibilitaFormato I
												WHERE I.NomeStato = (SELECT NomeStato
																	FROM Stato 
																	WHERE (Latitudine = _Latitudine) AND (Longitudine = _Longitudine)
                                                                    )
											  )
	)
	SELECT	DISTINCT SC.CodiceServer, S.Latitudine, S.Longitudine, SC.LarghezzaBanda, SC.BandaDisponibile
	FROM ServerCDN SC NATURAL JOIN Stato S NATURAL JOIN DisponibilitaImmediata DI
	WHERE DI.CodiceFile IN (SELECT *
							FROM FileTarget);

	DECLARE CONTINUE HANDLER FOR NOT FOUND SET FINITO = 1;
    
    -- Cotrollo se la connessione può esistere se esiste già una connessione con lo stesso timestampc e lo stesso CodiceDispositivo ma CodiceUtente diverso allora l'input è non valido in quanto impossibile
    IF _CodiceUtente <> (SELECT CodiceUtente
						FROM Connessione
						WHERE TimeStampC = _TimeStampC AND CodiceDispositivo = _CodiceDispositivo) THEN
                        
		SIGNAL SQLSTATE '45000'
		SET MESSAGE_TEXT = "La connessione fornita in input non può esistere";                 
	END IF;

	SET StatoC = (SELECT NomeStato
         FROM Stato 
         WHERE Longitudine = _Longitudine AND Latitudine = _Latitudine
        );
	
	SET Lingua = 
		(SELECT PrimaLingua
         FROM Stato 
         WHERE (Latitudine = _Latitudine) AND (Longitudine = _Longitudine)
        );
        
	SET RisoluzioneMAX = 
		(SELECT PA.Definizione
         FROM PagamentoEffettuato PE INNER JOIN PianoAbbonamento PA ON PE.PianoAbbonamento = PA.NomeAbbonamento
         WHERE PE.CodiceUtente = _CodiceUtente
         ORDER BY PE.Data DESC
         LIMIT 1
        );

    
	DROP TABLE IF EXISTS AppoggioServer;
    CREATE TABLE AppoggioServer(
		CodiceServer VARCHAR(50),
        Indice FLOAT
	);
	OPEN CursoreServer;
	SCAN: LOOP
		FETCH CursoreServer INTO CodiceServerF, LatiServerF, LongiServerF, LarghezzaBandaF, BandaDisponibileF;
        IF FINITO = 1 THEN
			LEAVE SCAN;
		END IF;
        SET Distanza = ST_DISTANCE_SPHERE(
			POINT(LongiServerF, LatiServerF),
			POINT(_Longitudine, _Latitudine)
			)/1000;
		IF Distanza = 0 THEN
			SET Distanza = 1;
		END IF;
        SET RCapacita = (LarghezzaBandaF / BandaDisponibileF);
        SET IndiceServer = (1 - RCapacita)/(POW(Distanza, 2));
        INSERT INTO AppoggioServer VALUES (CodiceServerF, IndiceServer);
	END LOOP SCAN;
    CLOSE CursoreServer;
	INSERT INTO AppoggioServer VALUES (CodiceServerF, IndiceServer); -- inserisco a mano i dati dell'ultimo server
	
	SET TopServer = (SELECT CodiceServer
					FROM AppoggioServer
                    ORDER BY Indice
                    LIMIT 1);
                    
	DROP TABLE AppoggioServer;
    
    SET FileV = (SELECT CodiceFile	
				FROM DisponibilitaImmediata DI NATURAL JOIN FileFilm FF NATURAL JOIN DisponibilitaAudio DA NATURAL JOIN Contenitore C NATURAL JOIN FormatoVideo FV
					NATURAL JOIN ServerCDN SC NATURAL JOIN Stato S 
				WHERE DA.NomeLingua = Lingua AND FV.Risoluzione = RisoluzioneMAX AND CodiceServer = TopServer AND FF.CodiceFilm = _CodiceFilm
				AND C.CodiceContenitore NOT IN (SELECT I.CodiceContenitore
											FROM IndisponibilitaFormato I
											WHERE I.NomeStato = StatoC)
				LIMIT 1);
    
    IF FileV IS NULL THEN
		SIGNAL SQLSTATE '45000'
		SET MESSAGE_TEXT = "Il contenuto selezionato non è al momeneto disponibile";
	END IF;
    
    IF NOT EXISTS (SELECT *		-- AGGIUNGO LA CONNESSIONE SE NON GIà PRESENTE
					FROM Connessione C
					WHERE C.TimeStampC = _TimeStampC AND C.CodiceDispositivo = _CodiceDispositivo) THEN
			INSERT INTO Connessione VALUES (_TimeStampC, _CodiceDispositivo, _CodiceUtente, _Ip, _TempoFineC, _Latitudine, _Longitudine);
	END IF;
    
	INSERT INTO Visualizzazione VALUES (current_timestamp(), _TimeStampC, _CodiceDispositivo, NULL, FileV);
    
	INSERT INTO Presso VALUES (TopServer, current_timestamp(), _TimeStampC, _CodiceDispositivo);
    
    SET BandaUtilizzata = (SELECT IF(FV.Risoluzione = '720p', 3, IF(FV.Risoluzione = '1080p', 5, IF(FV.Risoluzione = '4k', 15, 0)))
		FROM FileFilm FF NATURAL JOIN Contenitore C NATURAL JOIN FormatoVideo FV
		WHERE FF.CodiceFile = FileV
		);
    
    UPDATE ServerCDN		-- aggiorno la banda disponibile del server dopo che mi ci connetto
    SET	BandaDisponibile = BandaDisponibile - BandaUtilizzata
    WHERE CodiceServer = TopServer;
    
	SELECT TopServer, FileV;
END $$
DELIMITER ;
-- call connessioneutenteserver('U052YZ', '2023-01-01 04:15:30', 'D029GH', '192.168.1.1', '2023-01-01 05:30:45', -95.7129, 37.0902, 'W678KL');


-- -------------------------- -- 
-- Acquisto Piano Abbonamento --
-- -------------------------- --

USE FilmSphere;
DROP PROCEDURE IF EXISTS AcquistoAbbonamento;
DELIMITER $$
CREATE PROCEDURE AcquistoAbbonamento(_CodiceUtente VARCHAR(50),
    _Nome VARCHAR(50),
    _Cognome VARCHAR(50),
    _Email VARCHAR(50) ,
    _Password VARCHAR(50) ,
    _PagamentoPredefinito BIGINT ,
    _NumeroCarta BIGINT ,
    _AnnoScadenza INT ,
    _MeseScadenza INT ,
    _Tipo VARCHAR(50) ,
    _CVV INT ,
    _Circuito VARCHAR(50) ,
	_NomeAbbonamento VARCHAR(50) ,
    _Prezzo FLOAT ,
    _Definizione VARCHAR(50) ,
    _Anteprime BOOLEAN ,
    _Esclusive BOOLEAN)
BEGIN 
	
    DECLARE _Importo INT;
    
    SET _Importo = (SELECT Prezzo FROM PianoAbbonamento WHERE NomeAbbonamento = _NomeAbbonamento);
    
    IF DATEDIFF(current_date(), (SELECT PE.Data
		FROM PagamentoEffettuato PE
        WHERE PE.CodiceUtente = _CodiceUtente
        ORDER BY PE.Data DESC
        LIMIT 1)) < 30 THEN
		
        SIGNAL SQLSTATE '45000'
		SET MESSAGE_TEXT = "CUtente ha già un abbonamento attivo";
	END IF;
    
    IF _AnnoScadenza < YEAR(current_date()) OR (_AnnoScadenza = YEAR(current_date()) AND _MeseScadenza < MONTH(current_date())) THEN
		SIGNAL SQLSTATE '45000'
		SET MESSAGE_TEXT = "Carta di Credito scaduta";
	END IF;
	IF _CodiceUtente NOT IN (SELECT CodiceUtente FROM Utente) THEN
		INSERT INTO Utente VALUES (_CodiceUtente ,_Nome ,_Cognome ,_Email ,_Password ,_NumeroCarta);
	ELSEIF _CodiceUtente IN (SELECT CodiceUtente FROM Utente) 
		AND _PagamentoPredefinito <> (SELECT PagamentoPredefinito FROM Utente WHERE CodiceUtente = _CodiceUtente) THEN
        UPDATE Utente SET PagamentoPredefinito = _PagamentoPredefinito WHERE CodiceUtente = _CodiceUtente;
	END IF;
    
	IF _NumeroCarta NOT IN (SELECT NumeroCarta FROM CartaDiCredito) THEN
		INSERT INTO CartaDiCredito VALUES (_NumeroCarta, _AnnoScadenza, _MeseScadenza, _Tipo, _CVV, _Circuito);
	END IF;
    
    
    INSERT INTO PagamentoEffettuato VALUES (_CodiceUtente, current_date(), _Importo, _NumeroCarta, _NomeAbbonamento);
    INSERT INTO PagamentoAtteso VALUES (_CodiceUtente, DATE_ADD(current_date(), INTERVAL 30 DAY), _Importo, _NomeAbbonamento);
    SELECT 'Acquisto Effettuato';
END $$
DELIMITER ;

-- call AcquistoAbbonamento ('U052YZ', 'Alice', 'Rossi', 'alice.rossi@email.com', 'password123', 1234567890123456, 1234567890123456, 2024, 11, 'Carta Credito', 345, 'MasterCard', 'Basic', 5, 'SD', False, False);



-- ------------------- --
-- Calcolo Classifiche --
-- ------------------- --

USE FilmSphere;
DROP PROCEDURE IF EXISTS Classifiche;
DELIMITER $$
CREATE PROCEDURE Classifiche()
BEGIN
	CALL CalcoloClassificaRating();
	CALL CalcoloClassificaStato();
	CALL CalcoloClassificaPaeseProduzione();
    CALL CalcoloClassificaPianoAbbonamento();
    CALL CalcoloClassifcaContenitore();
END $$
DELIMITER ;

DROP PROCEDURE IF EXISTS CalcoloClassificaRating;
DELIMITER $$
CREATE PROCEDURE CalcoloClassificaRating()
BEGIN
	DELETE FROM ClassificaRating;
    INSERT INTO ClassificaRating 
		SELECT CodiceFilm, RANK() OVER (ORDER BY Rating DESC) AS Posizione, Rating
		FROM Film;
	SELECT *
	FROM ClassificaRating
	ORDER BY Posizione;
END $$
DELIMITER ;

DROP PROCEDURE IF EXISTS CalcoloClassificaStato;
DELIMITER $$
CREATE PROCEDURE CalcoloClassificaStato()
BEGIN
	DELETE FROM ClassificaStato;
    INSERT INTO ClassificaStato
    WITH RankedResults as (
	SELECT F.CodiceFilm, S.NomeStato, ROW_NUMBER() OVER (PARTITION BY S.NomeStato ORDER BY COUNT(*) DESC) AS Posizione, COUNT(*) AS VolteVisualizzato
	FROM Connessione C NATURAL JOIN Stato S NATURAL JOIN Visualizzazione V NATURAL JOIN FileFilm FF
		NATURAL JOIN Film F
	WHERE week(TimeStampC) = 1 -- week(current_date())
	GROUP BY F.CodiceFilm, S.NomeStato
	ORDER BY S.NomeStato, VolteVisualizzato DESC
	)
	SELECT *
    FROM RankedResults
    WHERE Posizione <= 10
    ORDER BY NomeStato, VolteVisualizzato DESC;
    
    SELECT *
	FROM ClassificaStato
	ORDER BY NomeStato, Posizione;
END $$
DELIMITER ;

DROP PROCEDURE IF EXISTS CalcoloClassificaPaeseProduzione;
DELIMITER $$
CREATE PROCEDURE CalcoloClassificaPaeseProduzione()
BEGIN
	DELETE FROM ClassificaPaeseProduzione;
    INSERT INTO ClassificaPaeseProduzione
	WITH RankedResults_ as (
	SELECT F.CodiceFilm, F.PaeseProduzione,ROW_NUMBER() OVER (PARTITION BY F.PaeseProduzione ORDER BY COUNT(*) DESC) AS Posizione, COUNT(*) AS VolteVisualizzato
	FROM Connessione C NATURAL JOIN Stato S NATURAL JOIN Visualizzazione V NATURAL JOIN FileFilm FF
		NATURAL JOIN Film F
	WHERE week(TimeStampC) = 1 -- week(current_date())
	GROUP BY F.CodiceFilm, F.PaeseProduzione
	ORDER BY F.PaeseProduzione, VolteVisualizzato DESC
	)
    SELECT *
	FROM RankedResults_
	WHERE Posizione <= 10;
    
    SELECT *
	FROM ClassificaPaeseProduzione
	ORDER BY PaeseProduzione, Posizione;
END $$
DELIMITER ;

DROP PROCEDURE IF EXISTS CalcoloClassificaPianoAbbonamento;
DELIMITER $$
CREATE PROCEDURE CalcoloClassificaPianoAbbonamento()
BEGIN
	DELETE FROM ClassificaPianoAbbonamento;
    INSERT INTO ClassificaPianoAbbonamento
	WITH UtentePiano as (
	SELECT U.CodiceUtente, PE.PianoAbbonamento
	FROM Utente U NATURAL JOIN PagamentoEffettuato PE
	WHERE PE.Data = (SELECT MAX(PE.Data)
				FROM PagamentoEffettuato PE1
				WHERE PE1.CodiceUtente = U.CodiceUtente)
    ) , RankedResults as (
	SELECT F.CodiceFilm, UP.PianoAbbonamento, ROW_NUMBER() OVER (PARTITION BY UP.PianoAbbonamento ORDER BY COUNT(*) DESC) AS Posizione, COUNT(*) AS VolteVisualizzato
	FROM Connessione C NATURAL JOIN Visualizzazione V NATURAL JOIN FileFilm FF
		NATURAL JOIN Film F NATURAL JOIN UtentePiano UP
	WHERE week(TimeStampC) = 1 -- week(current_date())
	GROUP BY F.CodiceFilm, UP.PianoAbbonamento
	ORDER BY UP.PianoAbbonamento, VolteVisualizzato DESC
	)
	SELECT *
    FROM RankedResults
    WHERE Posizione <= 10
    ORDER BY PianoAbbonamento, VolteVisualizzato DESC;
    
    SELECT *
	FROM ClassificaPianoAbbonamento
	ORDER BY PianoAbbonamento, Posizione;
END $$
DELIMITER ;


DROP PROCEDURE IF EXISTS CalcoloClassifcaContenitore;
DELIMITER $$
CREATE PROCEDURE CalcoloClassifcaContenitore()
BEGIN
	DELETE FROM ClassificaContenitore;
    INSERT INTO ClassificaContenitore
    WITH RankedResults as (
		SELECT F.CodiceFilm, CO.CodiceContenitore , ROW_NUMBER() OVER (PARTITION BY F.CodiceFilm ORDER BY COUNT(*) DESC) AS Posizione, COUNT(*) AS VolteVisualizzato
		FROM Connessione C NATURAL JOIN  Visualizzazione V NATURAL JOIN FileFilm FF
			NATURAL JOIN Film F NATURAL JOIN Contenitore CO
		WHERE week(TimeStampC) = 1 -- week(current_date())
		GROUP BY F.CodiceFilm, CO.CodiceContenitore
		ORDER BY F.CodiceFilm, VolteVisualizzato DESC
	)
	SELECT *
    FROM RankedResults
    WHERE Posizione <= 10
    ORDER BY CodiceFilm, VolteVisualizzato DESC;
    
    SELECT *
	FROM ClassificaContenitore
	ORDER BY CodiceFilm, Posizione;
END $$
DELIMITER ;

DROP EVENT IF EXISTS AggiornaClassificheEvento;
CREATE EVENT AggiornaClassificheEvento
ON SCHEDULE EVERY 7 DAY
STARTS '2023-01-01 00:00:00'
DO
    CALL Classifiche();

-- ------------------------ -- 
-- Bilanciamento del Carico --
-- ------------------------ -- 

USE FilmSphere;
DROP PROCEDURE IF EXISTS BilanciamentoCarico; 
DELIMITER $$
CREATE PROCEDURE BilanciamentoCarico()
BEGIN

	DECLARE FINITO INT DEFAULT 0;
    DECLARE SSorgente_ VARCHAR(50);
    DECLARE File_ VARCHAR(50);
    DECLARE SVicino_ VARCHAR(50);
    DECLARE SDestinazione_ VARCHAR(50);
    DECLARE NumeroFile INT;
    DECLARE I INT DEFAULT 0;
    DECLARE NomeStato_ VARCHAR(50);
    DECLARE CodiceFilm_ VARCHAR(50);
    DECLARE ServerClassifica_ VARCHAR(50);
    
    
    -- PER OTTENERE UN OUTPUT NON VUOTO SOSTITUIRE TUTTE LE CURRENT_WEEK () CON 1
    
	
	DECLARE CursoreSorgenti CURSOR FOR
	With FileBandaOccupata as(
		SELECT FF.CodiceFile, IF(FV.Risoluzione = '720p', 3, IF(FV.Risoluzione = '1080p', 5, IF(FV.Risoluzione = '4k', 15, 0))) as BandaOccupata
		FROM FileFilm FF NATURAL JOIN Contenitore C NATURAL JOIN FormatoVideo FV
	), ServerBandaOra as (
		SELECT SC.CodiceServer, AVG(FF.BandaOccupata) as BandaMedia, DAYOFWEEK(V.TimeStampV) as GiornoSettimana, HOUR(V.TimeStampV) as OraGiorno
		FROM Visualizzazione V NATURAL JOIN ServerCDN SC NATURAL JOIN FileBandaOccupata FF NATURAL JOIN Contenitore CO 
			NATURAL JOIN FormatoVideo
		WHERE WEEK(V.TimeStampV) = 1
		GROUP BY SC.CodiceServer, DAYOFWEEK(V.TimeStampV), HOUR(V.TimeStampV)
		ORDER BY SC.CodiceServer, DAYOFWEEK(V.TimeStampV), HOUR(V.TimeStampV)
	), ServerRanked as (
    	SELECT CodiceServer, AVG(BandaMedia) as BandaMedia, row_number() over() as Posizione
		FROM ServerBandaOra
		GROUP BY CodiceServer
    ), ServerSorgenti as (
		SELECT CodiceServer
		FROM ServerRanked 
		WHERE Posizione <= 5
    ), ServerDestinazioni as (
		SELECT *
		FROM ServerRanked
		WHERE Posizione > 5
    )
	SELECT CodiceServer, CodiceFile
    FROM ServerSorgenti NATURAL JOIN DisponibilitaImmediata
    ORDER BY CodiceServer;
    
    DECLARE CursoreDestinazioni CURSOR FOR
    SELECT CodiceServer
    FROM ServerDestinazioni;
    
    
    DECLARE CursoreSSFilm CURSOR FOR
    WITH FileBandaOccupata as(
		SELECT FF.CodiceFile, IF(FV.Risoluzione = '720p', 3, IF(FV.Risoluzione = '1080p', 5, IF(FV.Risoluzione = '4k', 15, 0))) as BandaOccupata
		FROM FileFilm FF NATURAL JOIN Contenitore C NATURAL JOIN FormatoVideo FV
	), ServerBandaOra as (
		SELECT SC.CodiceServer, SUM(FF.BandaOccupata) as BandaOccupataOra,DAYOFWEEK(V.TimeStampV) as GiornoSettimana, HOUR(V.TimeStampV) as OraGiorno
		FROM Visualizzazione V NATURAL JOIN ServerCDN SC NATURAL JOIN FileBandaOccupata FF NATURAL JOIN Contenitore CO 
			NATURAL JOIN FormatoVideo
		WHERE WEEK(V.TimeStampV) = 1
		GROUP BY SC.CodiceServer, DAYOFWEEK(V.TimeStampV), HOUR(V.TimeStampV)
		ORDER BY SC.CodiceServer, DAYOFWEEK(V.TimeStampV), HOUR(V.TimeStampV)
	), ServerRanked as (
    	SELECT CodiceServer, AVG(BandaOccupataOra) as BandaMedia, row_number() over() as Posizione
		FROM ServerBandaOra
		GROUP BY CodiceServer
    ), ServerSorgenti as (
		SELECT CodiceServer
		FROM ServerRanked
		WHERE Posizione <= 5
    ), ServerTopFilm_ as (
		SELECT CodiceServer, CodiceFile, count(*) as NumeroVisualizzazioni, ROW_NUMBER () OVER (PARTITION BY CodiceServer ORDER BY count(*) DESC) as Posizione
		FROM ServerCDN NATURAL JOIN Visualizzazione NATURAL JOIN Presso
		GROUP BY CodiceFile, CodiceServer
		ORDER BY CodiceServer, NumeroVisualizzazioni DESC
    ), ServerTopFilm as (	-- Sono i server sorgenti con accanto i 3 file più richiesti
		SELECT CodiceServer, CodiceFile
        FROM ServerTopFilm_ NATURAL JOIN ServerSorgenti
        WHERE Posizione <= 3
    )
    SELECT *
    FROM ServerTopFilm;
    
    DECLARE CONTINUE HANDLER FOR NOT FOUND SET FINITO = 1;
    
    DROP TABLE IF EXISTS AppoggioBilanciamento;
    CREATE TABLE AppoggioBilanciamento (
		ServerSorgente VARCHAR(50) NOT NULL,
        CodiceFile VARCHAR(50) NOT NULL,
        ServerDestinazione VARCHAR(50) NOT NULL
    );
    
    -- SSorgente_ 
    -- File_ 
    OPEN CursoreSSFilm;
    
    SCAN : LOOP
		FETCH CursoreSSFilm INTO SSorgente_, File_;
		IF FINITO = 1 THEN
			LEAVE SCAN;
		END IF;
        SET SVicino_ = (
						WITH StatoServer as (
							SELECT SC.CodiceServer, SV.Latitudine as LatiServer, SV.Longitudine as LongiServer
							FROM  ServerCDN SC NATURAL JOIN Stato SV
						), StatoServerVicino as (
						SELECT SC.CodiceServer, SV.Latitudine as LatiServer, SV.Longitudine as LongiServer, S.NomeStato, ST_DISTANCE_SPHERE( POINT(S.Longitudine, S.Latitudine), 
																																			POINT(SV.Longitudine, SV.Latitudine) )/1000 as Distanza
						FROM  ServerCDN SC NATURAL JOIN Stato SV CROSS JOIN Stato S
					), StatoServerPunteggio as (
						SELECT NomeStato, CodiceServer , Distanza, RANK () OVER (PARTITION BY NomeStato ORDER BY Distanza) as Punteggio
						FROM StatoServerVicino
					), StatoServerPiuVicino as (
						SELECT NomeStato, CodiceServer AS ServerPiuVicino, Distanza
						FROM StatoServerPunteggio
						WHERE Punteggio = 1
					)
					SELECT ServerPiuVicino
					FROM StatoServerPiuVicino NATURAL JOIN Stato NATURAL JOIN Connessione C NATURAL JOIN Visualizzazione V INNER JOIN Presso P ON P.CodiceDispositivo = V.CodiceDispositivo
						and V.TimeStampV = P.TimeStampV AND V.TimeStampC = P.TimeStampC
					WHERE P.CodiceServer = SSorgente_ AND V.CodiceFile = File_
					GROUP BY ServerPiuVicino
					ORDER BY COUNT(*) DESC
					LIMIT 1
					); -- Ho messo in SVicino_ il server più vicino allo stato da cui proviene la maggiorparte delle connessioni che hanno richiesto il file_
		
        
		IF SVicino_ IN (With FileBandaOccupata as(		-- Se il server trovato prima è tra i server destinazioni allora sposto il file in quel server
								SELECT FF.CodiceFile, IF(FV.Risoluzione = '720p', 3, IF(FV.Risoluzione = '1080p', 5, IF(FV.Risoluzione = '4k', 15, 0))) as BandaOccupata
								FROM FileFilm FF NATURAL JOIN Contenitore C NATURAL JOIN FormatoVideo FV
						), ServerBandaOra as (
							SELECT SC.CodiceServer, SUM(FF.BandaOccupata) as BandaOccupataOra,DAYOFWEEK(V.TimeStampV) as GiornoSettimana, HOUR(V.TimeStampV) as OraGiorno
							FROM Visualizzazione V NATURAL JOIN ServerCDN SC NATURAL JOIN FileBandaOccupata FF NATURAL JOIN Contenitore CO 
								NATURAL JOIN FormatoVideo
							WHERE WEEK(V.TimeStampV) = 1
							GROUP BY SC.CodiceServer, DAYOFWEEK(V.TimeStampV), HOUR(V.TimeStampV)
							ORDER BY SC.CodiceServer, DAYOFWEEK(V.TimeStampV), HOUR(V.TimeStampV)
						), ServerRanked as (
							SELECT CodiceServer, AVG(BandaOccupataOra) as BandaMedia, row_number() over() as Posizione
							FROM ServerBandaOra
							GROUP BY CodiceServer
						), ServerDestinazioni as (
							SELECT *
							FROM ServerRanked							
                            WHERE Posizione > 5
						)
						SELECT CodiceServer
						FROM ServerDestinazioni) THEN
			INSERT INTO AppoggioBilanciamento VALUES (SSorgente_, File_, SVicino_);
			
		END IF;
	END LOOP;
    CLOSE CursoreSSFilm;
    
    SET FINITO = 0;
    
    OPEN CursoreSorgenti;
    
    SCAN1: LOOP
		FETCH CursoreSorgenti INTO SSorgente_, File_;
        IF FINITO = 1 THEN
			LEAVE SCAN1;
		END IF;
        IF EXISTS (SELECT CodiceFilm, NomeStato
			FROM ClassificaStato CS NATURAL JOIN FileFilm FF
			WHERE FF.CodiceFile = File_) THEN
            SET NumeroFile = (SELECT (COUNT(*) * 8)/10
							  FROM DisponibilitaImmediata DI NATURAL JOIN FileFilm FF
                              WHERE DI.CodiceServer = SSorgente_ AND FF.CodiceFile = File_);
			-- WHILE I < NumeroFile DO
            SET NomeStato_ = (SELECT NomeStato
							FROM ClassificaStato CS NATURAL JOIN FileFilm FF
							WHERE FF.CodiceFile = File_);
            SET CodiceFilm_ = (SELECT CodiceFilm
							FROM ClassificaStato CS NATURAL JOIN FileFilm FF
							WHERE FF.CodiceFile = File_);
			CALL StatoServer (NomeStato_, ServerClassifica_);
            INSERT INTO AppoggioBilanciamento (ServerSorgente, CodiceFile, ServerDestinazione)
            SELECT  SSorgente_, FF.CodiceFile, ServerClassifica_
            FROM DisponibilitaImmediata DI NATURAL JOIN FileFilm FF
            WHERE DI.CodiceServer = SSorgente_ AND FF.CodiceFile = File_
            LIMIT NumeroFile;
		END IF;
    END LOOP;
    CLOSE CursoreSorgenti;
    
    SELECT distinct *
    FROM AppoggioBilanciamento;
	DROP TABLE IF EXISTS AppoggioBilanciamento;

END $$
DELIMITER ;

DROP EVENT IF EXISTS AggiornaBilanciamentoEvento;
CREATE EVENT AggiornaBilanciamentoEvento
ON SCHEDULE EVERY 7 DAY
STARTS '2023-01-01 00:00:00'
DO
    CALL BilanciamentoCarico();


USE FilmSphere;
DROP PROCEDURE IF EXISTS StatoServer; -- Funzione di utilità
DELIMITER $$
CREATE PROCEDURE StatoServer(IN _Stato VARCHAR(50), OUT Server_ VARCHAR(50))
BEGIN	
	
    SET Server_ = (
	WITH StatoServer as (
							SELECT SC.CodiceServer, SV.Latitudine as LatiServer, SV.Longitudine as LongiServer
							FROM  ServerCDN SC NATURAL JOIN Stato SV
						), StatoServerVicino as (
						SELECT SC.CodiceServer, SV.Latitudine as LatiServer, SV.Longitudine as LongiServer, S.NomeStato, ST_DISTANCE_SPHERE( POINT(S.Longitudine, S.Latitudine), 
																																			 POINT(SV.Longitudine, SV.Latitudine) )/1000 as Distanza
						FROM  ServerCDN SC NATURAL JOIN Stato SV CROSS JOIN Stato S
					), StatoServerPunteggio as (
						SELECT NomeStato, CodiceServer , Distanza, RANK () OVER (PARTITION BY NomeStato ORDER BY Distanza) as Punteggio
						FROM StatoServerVicino
					), StatoServerPiuVicino as (
						SELECT NomeStato, CodiceServer AS ServerPiuVicino, Distanza
						FROM StatoServerPunteggio
						WHERE Punteggio = 1
					)
                    SELECT ServerPiuVicino
                    FROM StatoServerPiuVicino
                    WHERE NomeStato = _Stato
                    LIMIT 1 -- serve perché gli stati uniti hanno 3 server cdn
                    );
END $$
DELIMITER ;

-- ---------------- -- 
-- Inserimento Film --
-- ---------------- -- 

USE FilmSphere;
DROP PROCEDURE IF EXISTS InserimentoFilm; 
DELIMITER $$
CREATE PROCEDURE InserimentoFilm(
	IN CodiceFilm_ VARCHAR(50) ,
    IN Titolo_ VARCHAR(50) ,
    IN Anno_ INT ,
    IN PaeseProduzione_ VARCHAR(50) ,
    IN Descrizione_ VARCHAR(3000) ,
    IN Durata_ INT ,
    IN Esclusiva_ BOOLEAN ,
    IN Anteprima_ BOOLEAN ,
    IN Rating_ FLOAT ,
    IN Regista_ VARCHAR(50) ,
    IN Genere1_ VARCHAR(50) ,
    IN Genere2_ VARCHAR(50) ,
	IN CodiceAttore1_ VARCHAR(50),
    IN Nome1_ VARCHAR(50),
    IN Cognome1_ VARCHAR(50),
	IN CodiceAttore2_ VARCHAR(50),
    IN Nome2_ VARCHAR(50),
    IN Cognome2_ VARCHAR(50),
    IN CodiceAttore3_ VARCHAR(50),
	IN Nome3_ VARCHAR(50),
	IN Cognome3_ VARCHAR(50),
    IN CodiceAttore4_ VARCHAR(50),
	IN Nome4_ VARCHAR(50),
	IN Cognome4_ VARCHAR(50),
    IN CodiceAttore5_ VARCHAR(50),
	IN Nome5_ VARCHAR(50),
	IN Cognome5_ VARCHAR(50),
    IN CodiceVincita_ VARCHAR(50) ,
    IN Data_ DATE ,
    IN NomePremio_ VARCHAR(50) ,
    IN Categoria_ VARCHAR(50) ,
	IN CodiceFile1_ VARCHAR(50),
    IN CodiceFilm1_ VARCHAR(50),
    IN Dimensione1_ INT,
    IN CodiceContenitore1_ VARCHAR(50),
	IN CodiceFile2_ VARCHAR(50),
    IN CodiceFilm2_ VARCHAR(50),
    IN Dimensione2_ INT,
    IN CodiceContenitore2_ VARCHAR(50),
    IN CodiceFile3_ VARCHAR(50),
    IN CodiceFilm3_ VARCHAR(50),
    IN Dimensione3_ INT,
    IN CodiceContenitore3_ VARCHAR(50),
    IN CodiceFile4_ VARCHAR(50),
    IN CodiceFilm4_ VARCHAR(50),
    IN Dimensione4_ INT,
    IN CodiceContenitore4_ VARCHAR(50),
    IN CodiceFile5_ VARCHAR(50),
    IN CodiceFilm5_ VARCHAR(50),
    IN Dimensione5_ INT,
    IN CodiceContenitore5_ VARCHAR(50)
)
BEGIN
	UPDATE Film 
    SET Anteprima = 0
    WHERE Anteprima = 1;
    
    IF EXISTS (SELECT * FROM Film WHERE CodiceFilm = CodiceFilm_) THEN
		SIGNAL SQLSTATE '45000'
		SET MESSAGE_TEXT = "Il Film è già presente nella base di dati";
	END IF;
        
    INSERT INTO Film VALUES (CodiceFilm_, Titolo_, Anno_, PaeseProduzione_, Descrizione_, Durata_, Esclusiva_, Anteprima_, Rating_, Regista_);
    INSERT INTO Classificazione VALUES (Genere1_, CodiceFilm_) , (Genere2_, CodiceFilm_);
    
    IF NOT EXISTS (SELECT * FROM Attore WHERE CodiceAttore = CodiceAttore1_) THEN	-- Inserisco gli attori se non presenti
		INSERT INTO Attore VALUES (CodiceAttore1_, Nome1_, Cognome1_);
	END IF;
	IF NOT EXISTS (SELECT * FROM Attore WHERE CodiceAttore = CodiceAttore2_) THEN
		INSERT INTO Attore VALUES (CodiceAttore2_, Nome2_, Cognome2_);
	END IF;
    IF NOT EXISTS (SELECT * FROM Attore WHERE CodiceAttore = CodiceAttore3_) THEN
		INSERT INTO Attore VALUES (CodiceAttore3_, Nome3_, Cognome3_);
	END IF;
    IF NOT EXISTS (SELECT * FROM Attore WHERE CodiceAttore = CodiceAttore4_) THEN
		INSERT INTO Attore VALUES (CodiceAttore4_, Nome4_, Cognome4_);
	END IF;
    IF NOT EXISTS (SELECT * FROM Attore WHERE CodiceAttore = CodiceAttore5_) THEN
		INSERT INTO Attore VALUES (CodiceAttore5_, Nome5_, Cognome5_);
	END IF;
    -- Inserimento Vincita
    INSERT INTO Vincita VALUES (CodiceVincita_, Data_, CodiceFilm_, NomePremio_, Categoria_);
    -- Inserimento File
    INSERT INTO FileFilm VALUES (CodiceFile1_ , CodiceFilm1_ , Dimensione1_ , CodiceContenitore1_), (CodiceFile2_ , CodiceFilm2_ , Dimensione2_ , CodiceContenitore2_), (CodiceFile3_ , CodiceFilm3_ , Dimensione3_ , CodiceContenitore3_), (CodiceFile4_ , CodiceFilm4_ , Dimensione4_ , CodiceContenitore4_), (CodiceFile5_ , CodiceFilm5_ , Dimensione5_ , CodiceContenitore5_);

END $$
DELIMITER ;

-- ------- -- 
-- Caching --
-- ------- -- 

USE FilmSphere;
DROP PROCEDURE IF EXISTS Caching;
DELIMITER $$
CREATE PROCEDURE Caching(IN UT VARCHAR(50))
BEGIN
	
    DECLARE StatoTarget_ VARCHAR(50);
    DECLARE ServerTarget_ VARCHAR(50);
    
    DECLARE CursoreFilm CURSOR FOR
    SELECT CodiceFilm
    FROM Raccomandazioni
    WHERE CodiceUtente = UT;
    
    
    
    SET StatoTarget_ = 
		(
			SELECT NomeStato
            FROM Connessione C NATURAL JOIN Stato S
            WHERE C.CodiceUtente = UT AND MONTH(C.TimeStampC) = MONTH(CURRENT_DATE)
            GROUP BY NomeStato
            ORDER BY COUNT(*)
            LIMIT 1
        );
      
      
        
	CALL StatoServer(StatoTarget_, ServerTarget_);
    
    
    
    INSERT IGNORE INTO DisponibilitaImmediata (CodiceServer, CodiceFile)
    WITH FileTarget AS (
			SELECT DISTINCT FF.CodiceFile
			FROM FileFilm FF NATURAL JOIN DisponibilitaAudio DA NATURAL JOIN Contenitore C NATURAL JOIN FormatoVideo FV
				NATURAL JOIN ServerCDN SC NATURAL JOIN Stato S NATURAL JOIN Raccomandazioni RA
			WHERE DA.NomeLingua = S.PrimaLingua AND S.NomeStato = StatoTarget_
									 AND RA.CodiceUtente = UT AND  FV.Risoluzione = (SELECT PA.Definizione
																							FROM PagamentoEffettuato PE INNER JOIN PianoAbbonamento PA ON PE.PianoAbbonamento = PA.NomeAbbonamento
																							WHERE PE.CodiceUtente = UT
																							ORDER BY PE.Data DESC
																							LIMIT 1
																							)
				AND C.CodiceContenitore NOT IN (SELECT I.CodiceContenitore
												FROM IndisponibilitaFormato I
												WHERE I.NomeStato = StatoTarget_))
			
            SELECT ServerTarget_, CodiceFile
            FROM FileTarget;

    
END $$
DELIMITER ;

DROP PROCEDURE IF EXISTS CachingTotale;
DELIMITER $$
CREATE PROCEDURE CachingTotale()
BEGIN
	DECLARE FINITO INT DEFAULT 0;
    DECLARE FUTENTE VARCHAR(50);
    
    DECLARE CUtente CURSOR FOR
    SELECT CodiceUtente
    FROM Utente;
    
	DECLARE CONTINUE HANDLER FOR NOT FOUND SET FINITO = 1;
    OPEN CUtente;
    SCAN: LOOP
		FETCH CUtente INTO FUTENTE;
        IF FINITO = 1 THEN
			LEAVE SCAN;
		END IF;
        CALL Caching(FUTENTE);
	END LOOP;
    CLOSE CUtente;
END $$
DELIMITER ;

DROP EVENT IF EXISTS AggiornaCachingEvento;
CREATE EVENT AggiornaCachingEvento
ON SCHEDULE EVERY 7 DAY
STARTS '2023-01-01 00:00:01'
DO
    CALL CachingTotale();
    
-- ----------------------- -- 
-- Analisi Visualizzazioni --
-- ----------------------- --

USE FilmSphere;
DROP PROCEDURE IF EXISTS AnalisiVisualizzazioni;
DELIMITER $$
CREATE PROCEDURE AnalisiVisualizzazioni ()
BEGIN
	CALL OraMaggiormenteAttiva();
	CALL OraMenoAttiva();
    CALL GiornoMaggiorementeAttivo();
    CALL GiornoMenoAttivo();
    CALL MeseMaggiorementeAttivo();
    CALL MeseMenoAttivo();
    CALL FilmMaggioreRitenzione();
    CALL FilmMinoreRitenzione();
END $$ 
DELIMITER ;

DROP PROCEDURE IF EXISTS OraMaggiormenteAttiva;
DELIMITER $$
CREATE PROCEDURE OraMaggiormenteAttiva ()
BEGIN

	SELECT HOUR(TimeStampV) as OraMaggiormenteAttiva
    FROM Visualizzazione
    WHERE MONTH(TimeStampV) BETWEEN (MONTH(current_date())-3) AND (MONTH(current_date())+3)
    GROUP BY HOUR(TimeStampV)
    ORDER BY COUNT(*) DESC
    LIMIT 1;
    
END $$ 
DELIMITER ;

DROP PROCEDURE IF EXISTS OraMenoAttiva;
DELIMITER $$
CREATE PROCEDURE OraMenoAttiva ()
BEGIN
    
    SELECT HOUR(TimeStampV) as OraMenoAttiva
    FROM Visualizzazione
    WHERE MONTH(TimeStampV) BETWEEN (MONTH(current_date())-3) AND (MONTH(current_date())+3)
    GROUP BY HOUR(TimeStampV)
    ORDER BY COUNT(*) ASC
    LIMIT 1;
    
END $$ 
DELIMITER ;

DROP PROCEDURE IF EXISTS GiornoMaggiorementeAttivo;
DELIMITER $$
CREATE PROCEDURE GiornoMaggiorementeAttivo ()
BEGIN

	SELECT DAYOFWEEK(TimeStampV) as GiornoMaggiorementeAttivo
    FROM Visualizzazione
    WHERE MONTH(TimeStampV) BETWEEN (MONTH(current_date())-3) AND (MONTH(current_date())+3)
    GROUP BY DAYOFWEEK(TimeStampV)
    ORDER BY COUNT(*) DESC
    LIMIT 1;
    
END $$ 
DELIMITER ;

DROP PROCEDURE IF EXISTS GiornoMenoAttivo;
DELIMITER $$
CREATE PROCEDURE GiornoMenoAttivo ()
BEGIN

    SELECT DAYOFWEEK(TimeStampV) as GiornoMenoAttivo
    FROM Visualizzazione
    WHERE MONTH(TimeStampV) BETWEEN (MONTH(current_date())-3) AND (MONTH(current_date())+3)
    GROUP BY DAYOFWEEK(TimeStampV)
    ORDER BY COUNT(*) ASC
    LIMIT 1;
    
END $$ 
DELIMITER ;

DROP PROCEDURE IF EXISTS MeseMaggiorementeAttivo;
DELIMITER $$
CREATE PROCEDURE MeseMaggiorementeAttivo ()
BEGIN

	SELECT MONTH(TimeStampV) as MeseMaggiorementeAttivo
    FROM Visualizzazione
    WHERE MONTH(TimeStampV) BETWEEN (MONTH(current_date())-3) AND (MONTH(current_date())+3)
    GROUP BY MONTH(TimeStampV)
    ORDER BY COUNT(*) DESC
    LIMIT 1;
    
END $$ 
DELIMITER ;

DROP PROCEDURE IF EXISTS MeseMenoAttivo;
DELIMITER $$
CREATE PROCEDURE MeseMenoAttivo ()
BEGIN

    SELECT MONTH(TimeStampV) as MeseMenoAttivo
    FROM Visualizzazione
    WHERE MONTH(TimeStampV) BETWEEN (MONTH(current_date())-3) AND (MONTH(current_date())+3)
    GROUP BY MONTH(TimeStampV)
    ORDER BY COUNT(*) ASC
    LIMIT 1;
    
END $$ 
DELIMITER ;

DROP PROCEDURE IF EXISTS FilmMaggioreRitenzione;
DELIMITER $$
CREATE PROCEDURE FilmMaggioreRitenzione ()
BEGIN

	WITH FilmR as (
		SELECT F.CodiceFilm, (((TIMESTAMPDIFF(MINUTE, V.TimeStampV, V.TempoFineV) * 0.95) * 100) / F.Durata) AS Ritenzione
		FROM Visualizzazione V NATURAL JOIN FileFilm FF NATURAL JOIN Film F
    ), FilmRitenzione as (
		SELECT CodiceFilm, AVG(Ritenzione) AS RitenzioneMedia
        FROM FilmR
        GROUP BY CodiceFilm
    )

    SELECT *
    FROM FilmRitenzione NATURAL JOIN Film
	ORDER BY RitenzioneMedia DESC
    LIMIT 20;

END $$ 
DELIMITER ;

DROP PROCEDURE IF EXISTS FilmMinoreRitenzione;
DELIMITER $$
CREATE PROCEDURE FilmMinoreRitenzione ()
BEGIN

	WITH FilmR as (
		SELECT F.CodiceFilm, (((TIMESTAMPDIFF(MINUTE, V.TimeStampV, V.TempoFineV) * 0.95) * 100) / F.Durata) AS Ritenzione
		FROM Visualizzazione V NATURAL JOIN FileFilm FF NATURAL JOIN Film F
    ), FilmRitenzione as (
		SELECT CodiceFilm, AVG(Ritenzione) AS RitenzioneMedia
        FROM FilmR
        GROUP BY CodiceFilm
    )

    SELECT *
    FROM FilmRitenzione NATURAL JOIN Film
	ORDER BY RitenzioneMedia ASC
    LIMIT 20;

END $$ 
DELIMITER ;

DROP EVENT IF EXISTS AnalisiVisualizzazioniEvento;
CREATE EVENT AnalisiVisualizzazioniEvento
ON SCHEDULE EVERY 3 MONTH
STARTS '2023-01-01 00:00:00'
DO
    CALL AnalisiVisualizzazioni();
