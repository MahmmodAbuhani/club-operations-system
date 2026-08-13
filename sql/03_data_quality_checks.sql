DROP PROCEDURE IF EXISTS assert_zero;

DELIMITER //
CREATE PROCEDURE assert_zero(IN check_name VARCHAR(120), IN violation_count INT)
BEGIN
    IF violation_count <> 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = check_name;
    END IF;
END//
DELIMITER ;

DROP TEMPORARY TABLE IF EXISTS DataQualityResults;
CREATE TEMPORARY TABLE DataQualityResults (
    CheckName VARCHAR(120) NOT NULL,
    ActualValue DECIMAL(12, 2) NOT NULL,
    ExpectedValue DECIMAL(12, 2) NOT NULL,
    Status VARCHAR(20) NOT NULL
);

INSERT INTO DataQualityResults
SELECT 'Person rows', COUNT(*), 32, IF(COUNT(*) = 32, 'PASS', 'FAIL') FROM Person
UNION ALL SELECT 'Player rows', COUNT(*), 23, IF(COUNT(*) = 23, 'PASS', 'FAIL') FROM Player
UNION ALL SELECT 'Coach rows', COUNT(*), 8, IF(COUNT(*) = 8, 'PASS', 'FAIL') FROM Coach
UNION ALL SELECT 'Admin rows', COUNT(*), 2, IF(COUNT(*) = 2, 'PASS', 'FAIL') FROM Admin
UNION ALL SELECT 'Sport rows', COUNT(*), 6, IF(COUNT(*) = 6, 'PASS', 'FAIL') FROM Sport
UNION ALL SELECT 'Team rows', COUNT(*), 10, IF(COUNT(*) = 10, 'PASS', 'FAIL') FROM Team
UNION ALL SELECT 'Equipment order rows', COUNT(*), 92, IF(COUNT(*) = 92, 'PASS', 'FAIL') FROM EquipmentOrder;

INSERT INTO DataQualityResults
SELECT 'Roster cap violations', COUNT(*), 0, IF(COUNT(*) = 0, 'PASS', 'FAIL')
FROM (
    SELECT t.TeamID
    FROM Team t
    JOIN Sport s ON s.SportID = t.SportID
    GROUP BY t.TeamID, t.CurrentRosterSize, s.MaxRosterSize
    HAVING t.CurrentRosterSize > s.MaxRosterSize
) violations;

INSERT INTO DataQualityResults
SELECT 'Demo teams without exactly one head coach', COUNT(*), 0, IF(COUNT(*) = 0, 'PASS', 'FAIL')
FROM (
    SELECT t.TeamID
    FROM Team t
    LEFT JOIN CoachesFor cf
        ON cf.TeamID = t.TeamID
       AND cf.CoachRole = 'Head Coach'
    GROUP BY t.TeamID
    HAVING COUNT(cf.PersonID) <> 1
) violations;

INSERT INTO DataQualityResults
SELECT 'Roster counter mismatches', COUNT(*), 0, IF(COUNT(*) = 0, 'PASS', 'FAIL')
FROM (
    SELECT t.TeamID
    FROM Team t
    LEFT JOIN PlaysOn po ON po.TeamID = t.TeamID
    GROUP BY t.TeamID, t.CurrentRosterSize
    HAVING COUNT(po.PersonID) <> t.CurrentRosterSize
) violations;

INSERT INTO DataQualityResults
SELECT 'Coach eligibility violations', COUNT(*), 0, IF(COUNT(*) = 0, 'PASS', 'FAIL')
FROM CoachesFor cf
LEFT JOIN CanCoach cc ON cc.PersonID = cf.PersonID AND cc.SportID = cf.SportID
WHERE cc.PersonID IS NULL;

INSERT INTO DataQualityResults
SELECT 'Invalid equipment orders', COUNT(*), 0, IF(COUNT(*) = 0, 'PASS', 'FAIL')
FROM EquipmentOrder eo
LEFT JOIN Requires r ON r.SportID = eo.SportID AND r.ItemID = eo.ItemID
WHERE r.SportID IS NULL;

INSERT INTO DataQualityResults
SELECT 'Roster membership order violations', COUNT(*), 0, IF(COUNT(*) = 0, 'PASS', 'FAIL')
FROM EquipmentOrder eo
LEFT JOIN PlaysOn po
    ON po.PersonID = eo.PersonID
   AND po.TeamID = eo.TeamID
   AND po.SportID = eo.SportID
WHERE po.PersonID IS NULL;

INSERT INTO DataQualityResults
SELECT 'Equipment fulfillment cardinality difference', ABS(expected.ExpectedRows - actual.ActualRows), 0,
       IF(expected.ExpectedRows = actual.ActualRows, 'PASS', 'FAIL')
FROM (
    SELECT COUNT(*) AS ExpectedRows
    FROM PlaysOn po
    JOIN Requires r ON r.SportID = po.SportID
) expected
CROSS JOIN (
    SELECT COUNT(*) AS ActualRows FROM EquipmentFulfillment
) actual;

INSERT INTO DataQualityResults
SELECT 'Equipment fulfillment aggregate mismatches', COUNT(*), 0, IF(COUNT(*) = 0, 'PASS', 'FAIL')
FROM EquipmentFulfillment ef
LEFT JOIN (
    SELECT PersonID, TeamID, SportID, ItemID, SUM(Quantity) AS OrderedQuantity
    FROM EquipmentOrder
    GROUP BY PersonID, TeamID, SportID, ItemID
) totals
    ON totals.PersonID = ef.PersonID
   AND totals.TeamID = ef.TeamID
   AND totals.SportID = ef.SportID
   AND totals.ItemID = ef.ItemID
WHERE ef.OrderedQuantity <> COALESCE(totals.OrderedQuantity, 0)
   OR ef.OutstandingQuantity <> GREATEST(ef.MinQuantity - COALESCE(totals.OrderedQuantity, 0), 0)
   OR ef.FulfillmentStatus <> IF(COALESCE(totals.OrderedQuantity, 0) >= ef.MinQuantity, 'Complete', 'Incomplete');

INSERT INTO DataQualityResults
SELECT 'FeesOwed reconciliation difference', ABS(raw.TotalFees - viewed.TotalFees), 0, IF(ABS(raw.TotalFees - viewed.TotalFees) < 0.01, 'PASS', 'FAIL')
FROM (
    SELECT SUM(eo.Quantity * ui.UnitPrice) AS TotalFees
    FROM EquipmentOrder eo
    JOIN UniformItem ui ON ui.ItemID = eo.ItemID
) raw
CROSS JOIN (
    SELECT SUM(AmountOwed) AS TotalFees
    FROM FeesOwed
) viewed;

SELECT CheckName, ActualValue, ExpectedValue, Status
FROM DataQualityResults
ORDER BY CheckName;

SET @failed_checks = (
    SELECT COUNT(*)
    FROM DataQualityResults
    WHERE Status <> 'PASS'
);

CALL assert_zero('Club Operations System data quality checks failed', @failed_checks);

DROP PROCEDURE IF EXISTS assert_zero;
