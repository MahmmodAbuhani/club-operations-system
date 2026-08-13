DROP VIEW IF EXISTS EquipmentFulfillment;
DROP VIEW IF EXISTS FeesOwed;
DROP TRIGGER IF EXISTS plays_on_before_insert_capacity;
DROP TRIGGER IF EXISTS plays_on_after_delete_capacity;
DROP TRIGGER IF EXISTS plays_on_before_update_membership;
DROP TRIGGER IF EXISTS sport_before_update_capacity;
DROP TABLE IF EXISTS EquipmentOrder;
DROP TABLE IF EXISTS Requires;
DROP TABLE IF EXISTS CoachesFor;
DROP TABLE IF EXISTS PlaysOn;
DROP TABLE IF EXISTS CanCoach;
DROP TABLE IF EXISTS Registers;
DROP TABLE IF EXISTS UniformItemSize;
DROP TABLE IF EXISTS UniformItem;
DROP TABLE IF EXISTS Team;
DROP TABLE IF EXISTS Sport;
DROP TABLE IF EXISTS Admin;
DROP TABLE IF EXISTS Coach;
DROP TABLE IF EXISTS Player;
DROP TABLE IF EXISTS Person;

CREATE TABLE Person (
    PersonID INT PRIMARY KEY,
    FirstName VARCHAR(60) NOT NULL,
    LastName VARCHAR(60) NOT NULL,
    Email VARCHAR(120) NOT NULL UNIQUE,
    Phone VARCHAR(30),
    PasswordHash VARCHAR(255) NOT NULL
);

CREATE TABLE Player (
    PersonID INT PRIMARY KEY,
    GuardianName VARCHAR(120),
    BirthDate DATE,
    FOREIGN KEY (PersonID) REFERENCES Person(PersonID)
        ON DELETE CASCADE
);

CREATE TABLE Coach (
    PersonID INT PRIMARY KEY,
    CertificationLevel VARCHAR(80),
    FOREIGN KEY (PersonID) REFERENCES Person(PersonID)
        ON DELETE CASCADE
);

CREATE TABLE Admin (
    PersonID INT PRIMARY KEY,
    AdminTitle VARCHAR(80) NOT NULL,
    FOREIGN KEY (PersonID) REFERENCES Person(PersonID)
        ON DELETE CASCADE
);

CREATE TABLE Sport (
    SportID INT PRIMARY KEY,
    SportName VARCHAR(80) NOT NULL UNIQUE,
    MaxRosterSize INT NOT NULL CHECK (MaxRosterSize > 0),
    RegistrationFee DECIMAL(8, 2) NOT NULL CHECK (RegistrationFee >= 0)
);

CREATE TABLE Team (
    TeamID INT PRIMARY KEY AUTO_INCREMENT,
    TeamName VARCHAR(100) NOT NULL,
    SportID INT NOT NULL,
    AgeGroup VARCHAR(30) NOT NULL,
    Season VARCHAR(30) NOT NULL,
    CurrentRosterSize INT NOT NULL DEFAULT 0 CHECK (CurrentRosterSize >= 0),
    FOREIGN KEY (SportID) REFERENCES Sport(SportID),
    UNIQUE (SportID, TeamName),
    UNIQUE (TeamID, SportID)
);

CREATE TABLE UniformItem (
    ItemID INT PRIMARY KEY,
    ItemName VARCHAR(100) NOT NULL UNIQUE,
    UnitPrice DECIMAL(8, 2) NOT NULL CHECK (UnitPrice >= 0)
);

CREATE TABLE UniformItemSize (
    ItemID INT NOT NULL,
    SizeLabel VARCHAR(20) NOT NULL,
    PRIMARY KEY (ItemID, SizeLabel),
    FOREIGN KEY (ItemID) REFERENCES UniformItem(ItemID)
        ON DELETE CASCADE
);

CREATE TABLE Registers (
    PersonID INT NOT NULL,
    SportID INT NOT NULL,
    RegistrationDate DATE NOT NULL,
    PRIMARY KEY (PersonID, SportID),
    FOREIGN KEY (PersonID) REFERENCES Player(PersonID)
        ON DELETE CASCADE,
    FOREIGN KEY (SportID) REFERENCES Sport(SportID)
);

CREATE TABLE CanCoach (
    PersonID INT NOT NULL,
    SportID INT NOT NULL,
    PRIMARY KEY (PersonID, SportID),
    FOREIGN KEY (PersonID) REFERENCES Coach(PersonID)
        ON DELETE CASCADE,
    FOREIGN KEY (SportID) REFERENCES Sport(SportID)
);

CREATE TABLE PlaysOn (
    PersonID INT NOT NULL,
    TeamID INT NOT NULL,
    SportID INT NOT NULL,
    JoinedAt DATE NOT NULL,
    UniformNumber INT,
    PRIMARY KEY (PersonID, TeamID),
    UNIQUE (PersonID, TeamID, SportID),
    CONSTRAINT uq_plays_on_team_uniform UNIQUE (TeamID, UniformNumber),
    CONSTRAINT fk_plays_on_registration FOREIGN KEY (PersonID, SportID)
        REFERENCES Registers(PersonID, SportID),
    CONSTRAINT fk_plays_on_team_sport FOREIGN KEY (TeamID, SportID)
        REFERENCES Team(TeamID, SportID),
    CHECK (UniformNumber IS NULL OR UniformNumber BETWEEN 0 AND 99)
);

CREATE TABLE CoachesFor (
    PersonID INT NOT NULL,
    TeamID INT NOT NULL,
    SportID INT NOT NULL,
    CoachRole VARCHAR(30) NOT NULL,
    HeadCoachTeamID INT GENERATED ALWAYS AS (
        CASE WHEN CoachRole = 'Head Coach' THEN TeamID ELSE NULL END
    ) STORED,
    PRIMARY KEY (PersonID, TeamID),
    CONSTRAINT uq_coaches_for_one_head UNIQUE (HeadCoachTeamID),
    CONSTRAINT fk_coaches_for_eligibility FOREIGN KEY (PersonID, SportID)
        REFERENCES CanCoach(PersonID, SportID),
    CONSTRAINT fk_coaches_for_team_sport FOREIGN KEY (TeamID, SportID)
        REFERENCES Team(TeamID, SportID),
    CHECK (CoachRole IN ('Head Coach', 'Assistant Coach'))
);

CREATE TABLE Requires (
    SportID INT NOT NULL,
    ItemID INT NOT NULL,
    MinQuantity INT NOT NULL DEFAULT 1 CHECK (MinQuantity > 0),
    PRIMARY KEY (SportID, ItemID),
    FOREIGN KEY (SportID) REFERENCES Sport(SportID)
        ON DELETE CASCADE,
    FOREIGN KEY (ItemID) REFERENCES UniformItem(ItemID)
        ON DELETE CASCADE
);

CREATE TABLE EquipmentOrder (
    OrderID INT PRIMARY KEY AUTO_INCREMENT,
    PersonID INT NOT NULL,
    TeamID INT NOT NULL,
    SportID INT NOT NULL,
    ItemID INT NOT NULL,
    SizeLabel VARCHAR(20) NOT NULL,
    Quantity INT NOT NULL CHECK (Quantity > 0),
    OrderedAt DATE NOT NULL,
    CONSTRAINT fk_equipment_order_membership FOREIGN KEY (PersonID, TeamID, SportID)
        REFERENCES PlaysOn(PersonID, TeamID, SportID),
    CONSTRAINT fk_equipment_order_requirement FOREIGN KEY (SportID, ItemID)
        REFERENCES Requires(SportID, ItemID),
    CONSTRAINT fk_equipment_order_size FOREIGN KEY (ItemID, SizeLabel)
        REFERENCES UniformItemSize(ItemID, SizeLabel)
);

DELIMITER //
CREATE TRIGGER plays_on_before_insert_capacity
BEFORE INSERT ON PlaysOn
FOR EACH ROW
BEGIN
    UPDATE Team t
    JOIN Sport s ON s.SportID = t.SportID
    SET t.CurrentRosterSize = t.CurrentRosterSize + 1
    WHERE t.TeamID = NEW.TeamID
      AND t.SportID = NEW.SportID
      AND t.CurrentRosterSize < s.MaxRosterSize;

    IF ROW_COUNT() <> 1 THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'roster_capacity_exceeded';
    END IF;
END//

CREATE TRIGGER plays_on_after_delete_capacity
AFTER DELETE ON PlaysOn
FOR EACH ROW
BEGIN
    UPDATE Team
    SET CurrentRosterSize = CurrentRosterSize - 1
    WHERE TeamID = OLD.TeamID
      AND CurrentRosterSize > 0;

    IF ROW_COUNT() <> 1 THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'roster_counter_underflow';
    END IF;
END//

CREATE TRIGGER plays_on_before_update_membership
BEFORE UPDATE ON PlaysOn
FOR EACH ROW
BEGIN
    IF NEW.PersonID <> OLD.PersonID
       OR NEW.TeamID <> OLD.TeamID
       OR NEW.SportID <> OLD.SportID THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'roster_membership_key_immutable';
    END IF;
END//

CREATE TRIGGER sport_before_update_capacity
BEFORE UPDATE ON Sport
FOR EACH ROW
BEGIN
    IF NEW.MaxRosterSize < OLD.MaxRosterSize
       AND EXISTS (
           SELECT 1
           FROM Team t
           WHERE t.SportID = OLD.SportID
             AND t.CurrentRosterSize > NEW.MaxRosterSize
       ) THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'roster_capacity_below_occupancy';
    END IF;
END//
DELIMITER ;

CREATE VIEW FeesOwed AS
SELECT
    eo.PersonID,
    eo.TeamID,
    CONCAT(p.FirstName, ' ', p.LastName) AS PlayerName,
    t.TeamName,
    SUM(eo.Quantity * ui.UnitPrice) AS AmountOwed
FROM EquipmentOrder eo
JOIN UniformItem ui ON ui.ItemID = eo.ItemID
JOIN Person p ON p.PersonID = eo.PersonID
JOIN Team t ON t.TeamID = eo.TeamID
GROUP BY eo.PersonID, eo.TeamID, p.FirstName, p.LastName, t.TeamName;

CREATE VIEW EquipmentFulfillment AS
SELECT
    po.PersonID,
    po.TeamID,
    po.SportID,
    r.ItemID,
    ui.ItemName,
    r.MinQuantity,
    COALESCE(SUM(eo.Quantity), 0) AS OrderedQuantity,
    GREATEST(r.MinQuantity - COALESCE(SUM(eo.Quantity), 0), 0) AS OutstandingQuantity,
    CASE
        WHEN COALESCE(SUM(eo.Quantity), 0) >= r.MinQuantity THEN 'Complete'
        ELSE 'Incomplete'
    END AS FulfillmentStatus
FROM PlaysOn po
JOIN Requires r ON r.SportID = po.SportID
JOIN UniformItem ui ON ui.ItemID = r.ItemID
LEFT JOIN EquipmentOrder eo
    ON eo.PersonID = po.PersonID
   AND eo.TeamID = po.TeamID
   AND eo.SportID = po.SportID
   AND eo.ItemID = r.ItemID
GROUP BY
    po.PersonID,
    po.TeamID,
    po.SportID,
    r.ItemID,
    ui.ItemName,
    r.MinQuantity;
