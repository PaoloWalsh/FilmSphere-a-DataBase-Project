/* creazione tabelle */
SET NAMES latin1;
SET FOREIGN_KEY_CHECKS = 0;
SET SQL_SAFE_UPDATES = 0;

BEGIN;
DROP DATABASE IF EXISTS `FilmSphere`;
CREATE DATABASE IF NOT EXISTS `FilmSphere`;
COMMIT;

USE `FilmSphere`; 

-- ---------------------- --
-- TABELLE AREA CONTENUTI --
-- ---------------------- --

DROP TABLE IF EXISTS `Film`;
CREATE TABLE `Film` (
	`CodiceFilm` VARCHAR(50) NOT NULL,
    `Titolo` VARCHAR(50) NOT NULL,
    `Anno` INT NOT NULL,
    `PaeseProduzione` VARCHAR(50) NOT NULL,
    `Descrizione` VARCHAR(3000) NOT NULL,
    `Durata` INT NOT NULL,
    `Esclusiva` BOOLEAN NOT NULL,
    `Anteprima` BOOLEAN NOT NULL,
    `Rating` FLOAT NOT NULL,
    `Regista` VARCHAR(50) NOT NULL,
  PRIMARY KEY (`CodiceFilm`),
  -- CHECK(`Anno` <= YEAR(CURRENT_DATE())),
  FOREIGN KEY (Regista) REFERENCES Regista (CodiceRegista)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

DROP TABLE IF EXISTS `Attore`;
CREATE TABLE `Attore` (
	`CodiceAttore` VARCHAR(50) NOT NULL,
    `Nome` VARCHAR(50) NOT NULL,
    `Cognome`VARCHAR(50) NOT NULL,
    PRIMARY KEY (`CodiceAttore`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

DROP TABLE IF EXISTS `Regista`;
CREATE TABLE `Regista` (
	`CodiceRegista` VARCHAR(50) NOT NULL,
    `Nome` VARCHAR(50) NOT NULL,
    `Cognome`VARCHAR(50) NOT NULL,
    PRIMARY KEY (`CodiceRegista`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

DROP TABLE IF EXISTS `Genere`;
CREATE TABLE `Genere` (
	`NomeGenere` VARCHAR(50) NOT NULL,
    PRIMARY KEY (`NomeGenere`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

DROP TABLE IF EXISTS `Recensione`;
CREATE TABLE `Recensione` (
	`CodiceFilm` VARCHAR(50) NOT NULL,
    `CodiceUtente` VARCHAR(50) NOT NULL,
    `Valutazione` FLOAT NOT NULL,
    `Descrizione` VARCHAR(3000) NOT NULL,
    `Upvote` INT NOT NULL,
    `Downvote` INT NOT NULL,
    PRIMARY KEY (`CodiceFilm`, `CodiceUtente`),
    CHECK (`Valutazione` >= 0 AND `Valutazione` <= 10),
    FOREIGN KEY (CodiceFilm) REFERENCES Film (CodiceFilm),
    FOREIGN KEY (CodiceUtente) REFERENCES Utente (CodiceUtente)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

DROP TABLE IF EXISTS `Vincita`;
CREATE TABLE `Vincita` (
	`CodiceVincita` VARCHAR(50) NOT NULL,
    `Data` DATE NOT NULL,
    `CodiceFilm` VARCHAR(50) NOT NULL,
    `NomePremio` VARCHAR(50) NOT NULL,
    `Categoria` VARCHAR(50) NOT NULL,
    PRIMARY KEY (`CodiceVincita`),
    -- CHECK(`Data` <= CURRENT_DATE()),
    FOREIGN KEY (CodiceFilm) REFERENCES Film (CodiceFilm),
    FOREIGN KEY (NomePremio) REFERENCES Premio (NomePremio)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

DROP TABLE IF EXISTS `Premio`;
CREATE TABLE `Premio` (
	`NomePremio` VARCHAR(50) NOT NULL,
    `Categoria` VARCHAR(50) NOT NULL,
    PRIMARY KEY (`NomePremio`, `Categoria`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

DROP TABLE IF EXISTS `VincitaAttore`;
CREATE TABLE `VincitaAttore` (
	`CodiceVincita` VARCHAR(50) NOT NULL,
    `CodiceAttore` VARCHAR(50) NOT NULL,
    PRIMARY KEY (`CodiceVincita`),
    FOREIGN KEY (CodiceAttore) REFERENCES Attore (CodiceAttore),
    FOREIGN KEY (CodiceVincita) REFERENCES Vincita (CodiceVincita)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

DROP TABLE IF EXISTS `VincitaRegista`;
CREATE TABLE `VincitaRegista` (
	`CodiceVincita` VARCHAR(50) NOT NULL,
    `CodiceRegista` VARCHAR(50) NOT NULL,
    PRIMARY KEY (`CodiceVincita`),
	FOREIGN KEY (CodiceRegista) REFERENCES Regista (CodiceRegista),	
    FOREIGN KEY (CodiceVincita) REFERENCES Vincita (CodiceVincita)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

DROP TABLE IF EXISTS `Partecipazione`;
CREATE TABLE `Partecipazione` (
	`CodiceFilm` VARCHAR(50) NOT NULL,
    `CodiceAttore` VARCHAR(50) NOT NULL,
    PRIMARY KEY (`CodiceFilm`, `CodiceAttore`),
    
    FOREIGN KEY (CodiceFilm) REFERENCES Film (CodiceFilm),
    FOREIGN KEY (CodiceAttore) REFERENCES Attore (CodiceAttore)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

DROP TABLE IF EXISTS `Classificazione`;
CREATE TABLE `Classificazione` (
	`NomeGenere` VARCHAR(50) NOT NULL,
    `CodiceFilm` VARCHAR(50) NOT NULL,
    PRIMARY KEY (`NomeGenere`, `CodiceFilm`),
    FOREIGN KEY (CodiceFilm) REFERENCES Film (CodiceFilm)
    ) ENGINE=InnoDB DEFAULT CHARSET=latin1;

-- ---------------------- --
-- TABELLE AREA FORMATI   --
-- ---------------------- --

DROP TABLE IF EXISTS `FileFilm`;
CREATE TABLE `FileFilm` (
	`CodiceFile` VARCHAR(50) NOT NULL,
    `CodiceFilm` VARCHAR(50) NOT NULL,
    `Dimensione` INT NOT NULL,
    `CodiceContenitore` VARCHAR(50) NOT NULL,
    PRIMARY KEY (`CodiceFile`),
	CHECK(`Dimensione` > 0),
    FOREIGN KEY (CodiceFilm) REFERENCES Film (CodiceFilm),
    FOREIGN KEY (CodiceContenitore) REFERENCES Contenitore (CodiceContenitore)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

DROP TABLE IF EXISTS `Contenitore`;
CREATE TABLE `Contenitore` (
	`CodiceContenitore` VARCHAR(50) NOT NULL,
    `CodecVideo` VARCHAR(50) NOT NULL,
    `CodecAudio` VARCHAR(50) NOT NULL,
    PRIMARY KEY (`CodiceContenitore`),
    FOREIGN KEY (CodecAudio) REFERENCES FormatoAudio (CodecAudio),
    FOREIGN KEY (CodecVideo) REFERENCES FormatoVideo (CodecVideo)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

DROP TABLE IF EXISTS `FormatoVideo`;
CREATE TABLE `FormatoVideo` (
	`CodecVideo` VARCHAR(50) NOT NULL,
    `QualitaVideo` INT NOT NULL,
    `Risoluzione` VARCHAR(50) NOT NULL,
    PRIMARY KEY (`CodecVideo`),
    CHECK(`QualitaVideo` > 0 AND `QualitaVideo` <= 5)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

DROP TABLE IF EXISTS `FormatoAudio`;
CREATE TABLE `FormatoAudio` (
	`CodecAudio` VARCHAR(50) NOT NULL,
    `QualitaAudio` INT NOT NULL,
    PRIMARY KEY (`CodecAudio`),
    CHECK(`QualitaAudio` > 0 AND `QualitaAudio` <= 5)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

DROP TABLE IF EXISTS `Lingua`;
CREATE TABLE `Lingua` (
	`NomeLingua` VARCHAR(50) NOT NULL,
    PRIMARY KEY (`NomeLingua`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

DROP TABLE IF EXISTS `Stato`;
CREATE TABLE `Stato` (
	`NomeStato` VARCHAR(50) NOT NULL,
    `Longitudine` FLOAT NOT NULL,
    `Latitudine` FLOAT NOT NULL,
    `PrimaLingua` VARCHAR(50) NOT NULL,
    PRIMARY KEY (`NomeStato`),
    CHECK(`Latitudine` >= -90 AND `Latitudine` <= 90),
    CHECK(`Longitudine` >= -180 AND `Longitudine` <= 180),
    FOREIGN KEY (PrimaLingua) REFERENCES Lingua (NomeLingua)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

DROP TABLE IF EXISTS `DisponibilitaSottotitoli`;
CREATE TABLE `DisponibilitaSottotitoli` (
	`CodiceFile` VARCHAR(50) NOT NULL,
    `NomeLingua` VARCHAR(50) NOT NULL,
    PRIMARY KEY (`CodiceFile`, `NomeLingua`),
    FOREIGN KEY (CodiceFile) REFERENCES FileFilm (CodiceFile),
    FOREIGN KEY (NomeLingua) REFERENCES Lingua (NomeLingua)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

DROP TABLE IF EXISTS `DisponibilitaAudio`;
CREATE TABLE `DisponibilitaAudio` (
	`CodiceFile` VARCHAR(50) NOT NULL,
    `NomeLingua` VARCHAR(50) NOT NULL,
    PRIMARY KEY (`CodiceFile`, `NomeLingua`),
    FOREIGN KEY (CodiceFile) REFERENCES FileFilm (CodiceFile),
    FOREIGN KEY (NomeLingua) REFERENCES Lingua (NomeLingua)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

DROP TABLE IF EXISTS `IndisponibilitaFormato`;
CREATE TABLE `IndisponibilitaFormato` (
	`CodiceContenitore` VARCHAR(50) NOT NULL,
    `NomeStato` VARCHAR(50) NOT NULL,
    PRIMARY KEY (`CodiceContenitore`, `NomeStato`),
    FOREIGN KEY (CodiceContenitore) REFERENCES Contenitore (CodiceContenitore),
    FOREIGN KEY (NomeStato) REFERENCES Stato (NomeStato)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;


-- ---------------------- --
-- TABELLE AREA CLIENTI   --
-- ---------------------- --

DROP TABLE IF EXISTS `Utente`;
CREATE TABLE `Utente` (
	`CodiceUtente` VARCHAR(50) NOT NULL,
    `Nome` VARCHAR(50) NOT NULL,
    `Cognome` VARCHAR(50) NOT NULL,
    `Email` VARCHAR(50) NOT NULL,
    `Password` VARCHAR(50) NOT NULL,
    `PagamentoPredefinito` BIGINT NOT NULL,
    PRIMARY KEY (`CodiceUtente`),
	FOREIGN KEY (PagamentoPredefinito) REFERENCES CartaDiCredito (NumeroCarta)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

DROP TABLE IF EXISTS `Dispositivo`;
CREATE TABLE `Dispositivo` (
	`CodiceDispositivo` VARCHAR(50) NOT NULL,
    `Categoria` VARCHAR(50) NOT NULL,
    `Risoluzione` VARCHAR(50) NOT NULL,
    `RapportoAspetto` VARCHAR(50) NOT NULL,
    PRIMARY KEY (`CodiceDispositivo`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

DROP TABLE IF EXISTS `CartaDiCredito`;
CREATE TABLE `CartaDiCredito` (
	`NumeroCarta` BIGINT NOT NULL,
    `AnnoScadenza` INT NOT NULL,
    `MeseScadenza` INT NOT NULL,
    `Tipo` VARCHAR(50) NOT NULL,
    `CVV` INT NOT NULL,
    `Circuito` VARCHAR(50) NOT NULL,
    PRIMARY KEY (`NumeroCarta`),
    CHECK(`AnnoScadenza` >= 0),
    CHECK(`MeseScadenza` >= 0 AND `MeseScadenza` <= 12)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

DROP TABLE IF EXISTS `PagamentoEffettuato`;
CREATE TABLE `PagamentoEffettuato` (
	`CodiceUtente` VARCHAR(50) NOT NULL,
    `Data` DATE NOT NULL,
    `Importo` INT NOT NULL,
    `AddebitoCarta` BIGINT NOT NULL,
    `PianoAbbonamento` VARCHAR(50) NOT NULL,
    PRIMARY KEY (`CodiceUtente`, `Data`),
    -- CHECK(`Data` <= CURRENT_DATE()),
    FOREIGN KEY (CodiceUtente) REFERENCES Utente (CodiceUtente),
    FOREIGN KEY (AddebitoCarta) REFERENCES CartaDiCredito (NumeroCarta),
    FOREIGN KEY (PianoAbbonamento) REFERENCES PianoAbbonamento (NomeAbbonamento)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

DROP TABLE IF EXISTS `PagamentoAtteso`;
CREATE TABLE `PagamentoAtteso` (
	`CodiceUtente` VARCHAR(50) NOT NULL,
    `Data` DATE NOT NULL,
    `Importo` INT NOT NULL,
    `PianoAbbonamento` VARCHAR(50) NOT NULL,
    PRIMARY KEY (`CodiceUtente`),
    -- CHECK(`Data` > CURRENT_DATE()),
    FOREIGN KEY (CodiceUtente) REFERENCES Utente (CodiceUtente),
    FOREIGN KEY (PianoAbbonamento) REFERENCES PianoAbbonamento (NomeAbbonamento)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

DROP TABLE IF EXISTS `PianoAbbonamento`;
CREATE TABLE `PianoAbbonamento` (
	`NomeAbbonamento` VARCHAR(50) NOT NULL,
    `Prezzo` FLOAT NOT NULL,
    `Definizione` VARCHAR(50) NOT NULL,
    `Anteprime` BOOLEAN NOT NULL,
    `Esclusive` BOOLEAN NOT NULL,
    PRIMARY KEY (`NomeAbbonamento`),
    CHECK(`Prezzo` = 5 OR `Prezzo` = 10 OR `Prezzo` = 12.5 OR `Prezzo` = 15 OR `Prezzo` = 20)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

DROP TABLE IF EXISTS `Connessione`;	
CREATE TABLE `Connessione` (
	`TimeStampC` TIMESTAMP NOT NULL,
    `CodiceDispositivo` VARCHAR(50) NOT NULL,
    `CodiceUtente` VARCHAR(50) NOT NULL,
    `Ip` VARCHAR(50) NOT NULL,
    `TempoFineC` TIMESTAMP, -- può essere null
    `Longitudine` FLOAT NOT NULL,
    `Latitudine` FLOAT NOT NULL,
    PRIMARY KEY (`TimeStampC`, `CodiceDispositivo`),
    CHECK(`TimeStampC` <= `TempoFineC`),
    CHECK(`Latitudine` >= -90 AND `Latitudine` <= 90),
    CHECK(`Longitudine` >= -180 AND `Longitudine` <= 180),
    FOREIGN KEY (CodiceUtente) REFERENCES Utente (CodiceUtente),
    FOREIGN KEY (CodiceDispositivo) REFERENCES Dispositivo (CodiceDispositivo)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

DROP TABLE IF EXISTS `Visualizzazione`;
CREATE TABLE `Visualizzazione` (
	`TimeStampV` TIMESTAMP NOT NULL,
    `TimeStampC` TIMESTAMP NOT NULL,
    `CodiceDispositivo` VARCHAR(50) NOT NULL,
    `TempoFineV` TIMESTAMP, -- può essere null
    `CodiceFile` VARCHAR(50) NOT NULL,
    PRIMARY KEY (`TimeStampV`, `TimeStampC`, `CodiceDispositivo`),
    CHECK(`TimeStampV` <= `TempoFineV`),
    FOREIGN KEY (CodiceFile) REFERENCES FileFilm (CodiceFile),
    FOREIGN KEY (TimeStampC, CodiceDispositivo) REFERENCES Connessione (TimeStampC, CodiceDispositivo)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

-- ---------------------- --
-- TABELLE AREA STREAMING --
-- ---------------------- --

DROP TABLE IF EXISTS `ServerCDN`; 
CREATE TABLE `ServerCDN` (
    `CodiceServer` VARCHAR(50) NOT NULL,
    `CapacitaMassimaTrasmissione` INT NOT NULL,
    `LarghezzaBanda` INT NOT NULL,
    `BandaDisponibile` INT NOT NULL,
    `NomeStato` VARCHAR(50) NOT NULL,
    PRIMARY KEY (`CodiceServer`),
    FOREIGN KEY (NomeStato) REFERENCES Stato (NomeStato)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

DROP TABLE IF EXISTS `Presso`; 
CREATE TABLE `Presso` (
    `CodiceServer` VARCHAR(50) NOT NULL,
    `TimeStampV` TIMESTAMP NOT NULL,
    `TimeStampC` TIMESTAMP NOT NULL,
    `CodiceDispositivo` VARCHAR(50) NOT NULL,
    PRIMARY KEY (`CodiceServer`, `TimeStampV`, `TimeStampC`, `CodiceDispositivo`),
    FOREIGN KEY (TimeStampV, TimeStampC, CodiceDispositivo) REFERENCES Visualizzazione (TimeStampV, TimeStampC, CodiceDispositivo),
    FOREIGN KEY (CodiceServer) REFERENCES ServerCDN (CodiceServer)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

DROP TABLE IF EXISTS `DisponibilitaImmediata`; 
CREATE TABLE `DisponibilitaImmediata` (
    `CodiceServer` VARCHAR(50) NOT NULL,
    `CodiceFile` VARCHAR(50) NOT NULL,
    PRIMARY KEY (`CodiceServer`, `CodiceFile`),
    FOREIGN KEY (CodiceFile) REFERENCES FileFilm (CodiceFile),
    FOREIGN KEY (CodiceServer) REFERENCES ServerCDN (CodiceServer)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

-- MV

DROP TABLE IF EXISTS `Raccomandazioni`;
CREATE TABLE `Raccomandazioni` (
	`CodiceUtente` VARCHAR(50) NOT NULL,
    `CodiceFilm` VARCHAR(50) NOT NULL,
    `Punteggio` FLOAT NOT NULL,
    PRIMARY KEY (`CodiceUtente` , `CodiceFilm`),
    FOREIGN KEY (CodiceUtente) REFERENCES Utente (CodiceUtente),
    FOREIGN KEY (CodiceFilm) REFERENCES Film (CodiceFilm)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

DROP TABLE IF EXISTS `ClassificaRating`;
CREATE TABLE `ClassificaRating` (
	`CodiceFilm` VARCHAR(50) NOT NULL,
    `Posizione` INT NOT NULL,
    `Rating` FLOAT NOT NULL,
    PRIMARY KEY(`CodiceFilm`),
    FOREIGN KEY (CodiceFilm) REFERENCES Film (CodiceFilm)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

DROP TABLE IF EXISTS `ClassificaStato`;
CREATE TABLE `ClassificaStato` (
	`CodiceFilm` VARCHAR(50) NOT NULL,
    `NomeStato` VARCHAR(50) NOT NULL,
    `Posizione` INT NOT NULL,
    `Visualizzazioni` INT NOT NULL,
    PRIMARY KEY(`CodiceFilm`, `NomeStato`),
    FOREIGN KEY (CodiceFilm) REFERENCES Film (CodiceFilm),
    FOREIGN KEY (NomeStato) REFERENCES Stato (NomeStato)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

DROP TABLE IF EXISTS `ClassificaPaeseProduzione`;
CREATE TABLE `ClassificaPaeseProduzione` (
	`CodiceFilm` VARCHAR(50) NOT NULL,
    `PaeseProduzione` VARCHAR(50) NOT NULL,
    `Posizione` INT NOT NULL,
    `Visualizzazioni` INT NOT NULL,
    PRIMARY KEY(`CodiceFilm`, `PaeseProduzione`),
    FOREIGN KEY (CodiceFilm) REFERENCES Film (CodiceFilm)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

DROP TABLE IF EXISTS `ClassificaPianoAbbonamento`;
CREATE TABLE `ClassificaPianoAbbonamento` (
	`CodiceFilm` VARCHAR(50) NOT NULL,
    `PianoAbbonamento` VARCHAR(50) NOT NULL,
    `Posizione` INT NOT NULL,
    `Visualizzazioni` INT NOT NULL,
    PRIMARY KEY(`CodiceFilm`, `PianoAbbonamento`),
    FOREIGN KEY (CodiceFilm) REFERENCES Film (CodiceFilm),
    FOREIGN KEY (PianoAbbonamento) REFERENCES PianoAbbonamento (NomeAbbonamento)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

DROP TABLE IF EXISTS `ClassificaContenitore`;
CREATE TABLE `ClassificaContenitore` (
	`CodiceFilm` VARCHAR(50) NOT NULL,
    `CodiceContenitore` VARCHAR(50) NOT NULL,
    `Posizione` INT NOT NULL,
    `Visualizzazioni` INT NOT NULL,
    PRIMARY KEY(`CodiceFilm`, `CodiceContenitore`),
    FOREIGN KEY (CodiceFilm) REFERENCES Film (CodiceFilm),
    FOREIGN KEY (CodiceContenitore) REFERENCES Contenitore (CodiceContenitore)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;
