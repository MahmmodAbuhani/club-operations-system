-- Demo password for every seeded account is demo123.
-- The hash below was generated with PHP password_hash('demo123', PASSWORD_DEFAULT).
SET @demo_hash = '$2y$10$mdsW.Y0WU/B7Uvtll6gNseZbdonbMv8YUfDwDnHOtLjGAqajkTgP6';

INSERT INTO Person (PersonID, FirstName, LastName, Email, Phone, PasswordHash) VALUES
(1, 'James', 'Walker', 'james.walker@example.test', '555-0101', @demo_hash),
(2, 'Aisha', 'Patel', 'aisha.patel@example.test', '555-0102', @demo_hash),
(3, 'Sophia', 'Garcia', 'sophia.garcia@example.test', '555-0103', @demo_hash),
(4, 'Liam', 'Chen', 'liam.chen@example.test', '555-0104', @demo_hash),
(5, 'Emma', 'Davis', 'emma.davis@example.test', '555-0105', @demo_hash),
(6, 'Noah', 'Brown', 'noah.brown@example.test', '555-0106', @demo_hash),
(7, 'Olivia', 'Wilson', 'olivia.wilson@example.test', '555-0107', @demo_hash),
(8, 'Mason', 'Lee', 'mason.lee@example.test', '555-0108', @demo_hash),
(9, 'Isabella', 'Martinez', 'isabella.martinez@example.test', '555-0109', @demo_hash),
(10, 'Ethan', 'Clark', 'ethan.clark@example.test', '555-0110', @demo_hash),
(11, 'Mia', 'Rodriguez', 'mia.rodriguez@example.test', '555-0111', @demo_hash),
(12, 'Lucas', 'Young', 'lucas.young@example.test', '555-0112', @demo_hash),
(13, 'Ava', 'King', 'ava.king@example.test', '555-0113', @demo_hash),
(14, 'Logan', 'Wright', 'logan.wright@example.test', '555-0114', @demo_hash),
(15, 'Amelia', 'Scott', 'amelia.scott@example.test', '555-0115', @demo_hash),
(16, 'Benjamin', 'Green', 'benjamin.green@example.test', '555-0116', @demo_hash),
(17, 'Harper', 'Adams', 'harper.adams@example.test', '555-0117', @demo_hash),
(18, 'Elijah', 'Baker', 'elijah.baker@example.test', '555-0118', @demo_hash),
(19, 'Charlotte', 'Nelson', 'charlotte.nelson@example.test', '555-0119', @demo_hash),
(20, 'William', 'Carter', 'william.carter@example.test', '555-0120', @demo_hash),
(21, 'Evelyn', 'Mitchell', 'evelyn.mitchell@example.test', '555-0121', @demo_hash),
(22, 'Henry', 'Perez', 'henry.perez@example.test', '555-0122', @demo_hash),
(23, 'Grace', 'Turner', 'grace.turner@example.test', '555-0123', @demo_hash),
(24, 'Mike', 'Torres', 'mike.torres@example.test', '555-0124', @demo_hash),
(25, 'Sarah', 'Johnson', 'sarah.johnson@example.test', '555-0125', @demo_hash),
(26, 'Daniel', 'Hall', 'daniel.hall@example.test', '555-0126', @demo_hash),
(27, 'Rachel', 'Allen', 'rachel.allen@example.test', '555-0127', @demo_hash),
(28, 'Omar', 'Haddad', 'omar.haddad@example.test', '555-0128', @demo_hash),
(29, 'Nina', 'Brooks', 'nina.brooks@example.test', '555-0129', @demo_hash),
(30, 'Priya', 'Nair', 'priya.nair@example.test', '555-0130', @demo_hash),
(31, 'Morgan', 'Reed', 'morgan.reed@example.test', '555-0131', @demo_hash),
(32, 'Riley', 'Bennett', 'riley.bennett@example.test', '555-0132', @demo_hash);

INSERT INTO Player (PersonID, GuardianName, BirthDate) VALUES
(1, 'Dana Walker', '2011-04-10'), (2, 'Ravi Patel', '2012-07-18'),
(3, 'Elena Garcia', '2010-02-02'), (4, 'Mei Chen', '2011-09-13'),
(5, 'Robin Davis', '2013-05-19'), (6, 'Taylor Brown', '2012-11-21'),
(7, 'Casey Wilson', '2011-03-04'), (8, 'Jordan Lee', '2010-08-15'),
(9, 'Rosa Martinez', '2012-06-12'), (10, 'Andre Clark', '2011-01-28'),
(11, 'Sofia Rodriguez', '2013-12-01'), (12, 'Grace Young', '2010-10-09'),
(13, 'Pat King', '2011-05-17'), (14, 'Sam Wright', '2012-04-30'),
(15, 'Jamie Scott', '2011-07-07'), (16, 'Terry Green', '2010-03-23'),
(17, 'Blair Adams', '2012-09-25'), (18, 'Lee Baker', '2011-06-14'),
(19, 'Quinn Nelson', '2013-02-11'), (20, 'Drew Carter', '2010-12-12'),
(21, 'Ari Mitchell', '2012-08-03'), (22, 'Reese Perez', '2011-11-29'),
(32, 'Cameron Bennett', '2010-01-05');

INSERT INTO Coach (PersonID, CertificationLevel) VALUES
(24, 'National D'), (25, 'National C'), (26, 'Youth Level 2'),
(27, 'Youth Level 2'), (28, 'Baseball Fundamentals'), (29, 'Tennis Instructor'),
(30, 'League Operations'), (32, 'Player-Coach Apprentice');

INSERT INTO Admin (PersonID, AdminTitle) VALUES
(30, 'Program Coordinator'), (31, 'League Administrator');

INSERT INTO Sport (SportID, SportName, MaxRosterSize, RegistrationFee) VALUES
(1, 'Soccer', 18, 120.00), (2, 'Basketball', 12, 95.00),
(3, 'Volleyball', 12, 90.00), (4, 'Baseball', 15, 110.00),
(5, 'Tennis', 8, 85.00), (6, 'Football', 18, 135.00);

INSERT INTO Team (TeamID, TeamName, SportID, AgeGroup, Season) VALUES
(1, 'Lions FC', 1, 'U14', 'Spring 2026'), (2, 'River City FC', 1, 'U16', 'Spring 2026'),
(3, 'North Stars', 2, 'U14', 'Spring 2026'), (4, 'Downtown Hoops', 2, 'U16', 'Spring 2026'),
(5, 'Volley Aces', 3, 'U14', 'Spring 2026'), (6, 'Diamond Hawks', 4, 'U15', 'Spring 2026'),
(7, 'Baseline Club', 5, 'U14', 'Spring 2026'), (8, 'Gridiron Juniors', 6, 'U16', 'Spring 2026'),
(9, 'Southside Strikers', 1, 'U12', 'Spring 2026'), (10, 'Court Kings', 2, 'U12', 'Spring 2026');

INSERT INTO UniformItem (ItemID, ItemName, UnitPrice) VALUES
(1, 'Jersey', 35.00), (2, 'Shorts', 25.00), (3, 'Shin Guards', 18.00),
(4, 'Cleats', 70.00), (5, 'Socks', 8.00), (6, 'Basketball', 22.00),
(7, 'Cap', 15.00), (8, 'Glove', 30.00), (9, 'Tennis Racket', 65.00),
(10, 'Football Pads', 90.00), (11, 'Water Bottle', 10.00), (12, 'Warmup Jacket', 55.00);

INSERT INTO UniformItemSize (ItemID, SizeLabel) VALUES
(1, 'YS'), (1, 'YM'), (1, 'YL'), (1, 'S'), (1, 'M'), (1, 'L'),
(2, 'YS'), (2, 'YM'), (2, 'YL'), (2, 'S'), (2, 'M'), (2, 'L'),
(3, 'S'), (3, 'M'), (3, 'L'), (4, '4'), (4, '5'), (4, '6'), (4, '7'), (4, '8'),
(5, 'S'), (5, 'M'), (5, 'L'), (6, 'Standard'), (7, 'Youth'), (7, 'Adult'),
(8, 'Left'), (8, 'Right'), (9, '25'), (9, '26'), (9, '27'),
(10, 'S'), (10, 'M'), (10, 'L'), (11, 'Standard'), (12, 'S'), (12, 'M'), (12, 'L');

INSERT INTO Requires (SportID, ItemID, MinQuantity) VALUES
(1, 1, 1), (1, 2, 1), (1, 3, 1), (1, 4, 1), (1, 5, 2), (1, 11, 1),
(2, 1, 1), (2, 2, 1), (2, 6, 1), (2, 11, 1), (2, 12, 1),
(3, 1, 1), (3, 2, 1), (3, 5, 2), (3, 11, 1),
(4, 1, 1), (4, 7, 1), (4, 8, 1), (4, 11, 1),
(5, 1, 1), (5, 9, 1), (5, 11, 1),
(6, 1, 1), (6, 10, 1), (6, 11, 1), (6, 12, 1);

INSERT INTO Registers (PersonID, SportID, RegistrationDate) VALUES
(1, 1, '2026-03-01'), (1, 2, '2026-03-03'), (2, 1, '2026-03-01'),
(2, 3, '2026-03-04'), (3, 1, '2026-03-01'), (3, 5, '2026-03-05'),
(4, 1, '2026-03-02'), (5, 2, '2026-03-02'), (6, 2, '2026-03-02'),
(7, 3, '2026-03-04'), (8, 4, '2026-03-06'), (9, 4, '2026-03-06'),
(10, 5, '2026-03-07'), (11, 6, '2026-03-08'), (12, 6, '2026-03-08'),
(13, 1, '2026-03-09'), (14, 1, '2026-03-09'), (15, 1, '2026-03-09'),
(16, 2, '2026-03-10'), (17, 2, '2026-03-10'), (18, 3, '2026-03-11'),
(19, 4, '2026-03-11'), (20, 5, '2026-03-12'), (21, 6, '2026-03-12'),
(22, 1, '2026-03-12'), (32, 1, '2026-03-13'), (32, 2, '2026-03-13');

INSERT INTO CanCoach (PersonID, SportID) VALUES
(24, 1), (24, 2), (24, 3), (25, 1), (25, 2), (25, 6),
(26, 2), (26, 3), (26, 4), (27, 1), (27, 3), (27, 4), (27, 5),
(28, 4), (28, 6), (29, 5), (30, 1), (30, 2), (32, 1);

INSERT INTO PlaysOn (PersonID, TeamID, SportID, JoinedAt, UniformNumber) VALUES
(1, 1, 1, '2026-03-15', 7), (1, 3, 2, '2026-03-17', 11), (2, 1, 1, '2026-03-15', 12),
(2, 5, 3, '2026-03-18', 4), (3, 2, 1, '2026-03-16', 8), (3, 7, 5, '2026-03-19', 16),
(4, 2, 1, '2026-03-16', 10), (5, 3, 2, '2026-03-17', 3), (6, 4, 2, '2026-03-17', 20),
(7, 5, 3, '2026-03-18', 6), (8, 6, 4, '2026-03-19', 2), (9, 6, 4, '2026-03-19', 9),
(10, 7, 5, '2026-03-20', 17), (11, 8, 6, '2026-03-21', 55), (12, 8, 6, '2026-03-21', 21),
(13, 9, 1, '2026-03-22', 13), (14, 9, 1, '2026-03-22', 14), (15, 1, 1, '2026-03-22', 15),
(16, 10, 2, '2026-03-23', 22), (17, 10, 2, '2026-03-23', 23), (18, 5, 3, '2026-03-24', 18),
(19, 6, 4, '2026-03-24', 19), (20, 7, 5, '2026-03-24', 5), (21, 8, 6, '2026-03-25', 1),
(22, 9, 1, '2026-03-25', 24), (32, 1, 1, '2026-03-25', 32), (32, 4, 2, '2026-03-25', 33);

INSERT INTO CoachesFor (PersonID, TeamID, SportID, CoachRole) VALUES
(24, 1, 1, 'Head Coach'), (25, 1, 1, 'Assistant Coach'), (25, 2, 1, 'Head Coach'),
(30, 2, 1, 'Assistant Coach'), (26, 3, 2, 'Head Coach'), (24, 3, 2, 'Assistant Coach'),
(30, 4, 2, 'Head Coach'), (26, 4, 2, 'Assistant Coach'), (26, 5, 3, 'Head Coach'),
(27, 5, 3, 'Assistant Coach'), (28, 6, 4, 'Head Coach'), (27, 6, 4, 'Assistant Coach'),
(29, 7, 5, 'Head Coach'), (27, 7, 5, 'Assistant Coach'), (28, 8, 6, 'Head Coach'),
(25, 8, 6, 'Assistant Coach'), (27, 9, 1, 'Head Coach'), (32, 9, 1, 'Assistant Coach'),
(24, 10, 2, 'Head Coach');

INSERT INTO EquipmentOrder (PersonID, TeamID, SportID, ItemID, SizeLabel, Quantity, OrderedAt) VALUES
(1, 1, 1, 1, 'YM', 1, '2026-03-20'), (1, 1, 1, 3, 'M', 1, '2026-03-20'), (1, 3, 2, 6, 'Standard', 1, '2026-03-22'),
(2, 1, 1, 1, 'YL', 1, '2026-03-20'), (2, 5, 3, 5, 'M', 2, '2026-03-22'),
(3, 2, 1, 1, 'S', 1, '2026-03-21'), (3, 7, 5, 9, '26', 1, '2026-03-23'),
(4, 2, 1, 4, '6', 1, '2026-03-21'), (5, 3, 2, 1, 'YM', 1, '2026-03-22'),
(6, 4, 2, 6, 'Standard', 1, '2026-03-22'), (7, 5, 3, 1, 'YL', 1, '2026-03-23'),
(8, 6, 4, 8, 'Right', 1, '2026-03-24'), (9, 6, 4, 7, 'Youth', 1, '2026-03-24'),
(10, 7, 5, 9, '25', 1, '2026-03-25'), (11, 8, 6, 10, 'M', 1, '2026-03-26'),
(12, 8, 6, 12, 'M', 1, '2026-03-26'), (13, 9, 1, 1, 'YS', 1, '2026-03-27'),
(14, 9, 1, 2, 'YM', 1, '2026-03-27'), (15, 1, 1, 3, 'S', 1, '2026-03-27'),
(16, 10, 2, 1, 'YM', 1, '2026-03-28'), (17, 10, 2, 6, 'Standard', 2, '2026-03-28'),
(18, 5, 3, 11, 'Standard', 1, '2026-03-29'), (19, 6, 4, 8, 'Left', 1, '2026-03-29'),
(20, 7, 5, 11, 'Standard', 1, '2026-03-29'), (21, 8, 6, 10, 'S', 1, '2026-03-30'),
(22, 9, 1, 5, 'S', 2, '2026-03-30'), (32, 1, 1, 1, 'S', 1, '2026-03-30'),
(32, 4, 2, 12, 'S', 1, '2026-03-30');

INSERT INTO EquipmentOrder (PersonID, TeamID, SportID, ItemID, SizeLabel, Quantity, OrderedAt)
SELECT
    po.PersonID,
    po.TeamID,
    po.SportID,
    r.ItemID,
    MIN(uis.SizeLabel) AS SizeLabel,
    1 + ((po.PersonID + r.ItemID) MOD 2) AS Quantity,
    DATE_ADD('2026-04-01', INTERVAL ((po.PersonID + po.TeamID + r.ItemID) MOD 21) DAY) AS OrderedAt
FROM PlaysOn po
JOIN Team t ON t.TeamID = po.TeamID
JOIN Requires r ON r.SportID = t.SportID
JOIN UniformItemSize uis ON uis.ItemID = r.ItemID
GROUP BY po.PersonID, po.TeamID, r.ItemID
ORDER BY po.PersonID, po.TeamID, r.ItemID
LIMIT 64;
