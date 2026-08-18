<?php

declare(strict_types=1);

function authenticate(string $email, string $password): bool
{
    $person = fetch_one(
        'SELECT PersonID, FirstName, LastName, PasswordHash FROM Person WHERE Email = ?',
        [$email]
    );

    if ($person === null || !password_verify($password, $person['PasswordHash'])) {
        return false;
    }

    session_regenerate_id(true);
    $_SESSION['person_id'] = (int) $person['PersonID'];
    $_SESSION['person_name'] = $person['FirstName'] . ' ' . $person['LastName'];
    $_SESSION['roles'] = roles_for_person((int) $person['PersonID']);
    $_SESSION['csrf_token'] = bin2hex(random_bytes(32));
    return true;
}

function roles_for_person(int $personId): array
{
    $roles = [];
    foreach (['Player' => 'Player', 'Coach' => 'Coach', 'Admin' => 'Admin'] as $role => $table) {
        $row = fetch_one("SELECT PersonID FROM {$table} WHERE PersonID = ?", [$personId]);
        if ($row !== null) {
            $roles[] = $role;
        }
    }
    return $roles;
}

function all_sports(): array
{
    return fetch_all('SELECT SportID, SportName FROM Sport ORDER BY SportName');
}

function all_teams(?string $search = null): array
{
    $searchText = trim((string) $search);
    $term = '%' . $searchText . '%';
    return fetch_all(
        'SELECT t.TeamID, t.TeamName, s.SportName, t.AgeGroup, t.Season, s.MaxRosterSize,
                t.CurrentRosterSize AS CurrentRoster,
                s.MaxRosterSize - t.CurrentRosterSize AS OpenSlots
         FROM Team t
         JOIN Sport s ON s.SportID = t.SportID
         WHERE ? = \'\' OR t.TeamName LIKE ? OR s.SportName LIKE ? OR t.AgeGroup LIKE ?
         ORDER BY s.SportName, t.TeamName',
        [$searchText, $term, $term, $term]
    );
}

function player_teams(int $personId): array
{
    return fetch_all(
        'SELECT t.TeamID, t.TeamName, s.SportName, t.AgeGroup, t.Season, po.UniformNumber
         FROM PlaysOn po
         JOIN Team t ON t.TeamID = po.TeamID
         JOIN Sport s ON s.SportID = t.SportID
         WHERE po.PersonID = ?
         ORDER BY s.SportName, t.TeamName',
        [$personId]
    );
}

function join_sport(int $personId, int $sportId): string
{
    if (fetch_one('SELECT SportID FROM Sport WHERE SportID = ?', [$sportId]) === null) {
        return 'That sport is not available.';
    }

    $inserted = execute_sql(
        'INSERT IGNORE INTO Registers (PersonID, SportID, RegistrationDate) VALUES (?, ?, CURRENT_DATE)',
        [$personId, $sportId]
    );

    return $inserted === 1
        ? 'Sport registration saved.'
        : 'You are already registered for this sport.';
}

function leave_team_as_player(int $personId, int $teamId): string
{
    try {
        execute_sql('DELETE FROM PlaysOn WHERE PersonID = ? AND TeamID = ?', [$personId, $teamId]);
    } catch (PDOException $exception) {
        if ($exception->getCode() === '23000'
            && str_contains($exception->getMessage(), 'fk_equipment_order_membership')) {
            return 'Team membership retained because equipment order history exists.';
        }
        throw $exception;
    }

    return 'Team membership removed.';
}

function player_fees(int $personId): array
{
    return fetch_all(
        'SELECT TeamName, AmountOwed FROM FeesOwed WHERE PersonID = ? ORDER BY AmountOwed DESC, TeamName',
        [$personId]
    );
}

function equipment_fulfillment_for_player(int $personId): array
{
    return fetch_all(
        "SELECT ef.TeamID, ef.SportID, t.TeamName, s.SportName, ef.ItemID, ef.ItemName,
                ef.MinQuantity, ef.OrderedQuantity, ef.OutstandingQuantity, ef.FulfillmentStatus
         FROM EquipmentFulfillment ef
         JOIN Team t ON t.TeamID = ef.TeamID
         JOIN Sport s ON s.SportID = ef.SportID
         WHERE ef.PersonID = ?
         ORDER BY (ef.FulfillmentStatus = 'Incomplete') DESC, t.TeamName, ef.ItemName",
        [$personId]
    );
}

function equipment_order_history_for_player(int $personId, int $teamId, int $sportId, int $itemId): array
{
    return fetch_all(
        'SELECT OrderedAt, SizeLabel, Quantity
         FROM EquipmentOrder
         WHERE PersonID = ? AND TeamID = ? AND SportID = ? AND ItemID = ?
         ORDER BY OrderedAt DESC, OrderID DESC',
        [$personId, $teamId, $sportId, $itemId]
    );
}

function equipment_sizes(int $itemId): array
{
    return fetch_all(
        'SELECT SizeLabel FROM UniformItemSize WHERE ItemID = ? ORDER BY SizeLabel',
        [$itemId]
    );
}

function order_equipment(int $personId, int $teamId, int $sportId, int $itemId, string $sizeLabel, int $quantity): bool
{
    $valid = fetch_one(
        'SELECT r.ItemID
         FROM PlaysOn po
         JOIN Requires r ON r.SportID = po.SportID AND r.ItemID = ?
         JOIN UniformItemSize uis ON uis.ItemID = r.ItemID AND uis.SizeLabel = ?
         WHERE po.PersonID = ? AND po.TeamID = ? AND po.SportID = ?',
        [$itemId, $sizeLabel, $personId, $teamId, $sportId]
    );

    if ($valid === null || $quantity < 1) {
        return false;
    }

    execute_sql(
        'INSERT INTO EquipmentOrder (PersonID, TeamID, SportID, ItemID, SizeLabel, Quantity, OrderedAt)
         VALUES (?, ?, ?, ?, ?, ?, CURRENT_DATE)',
        [$personId, $teamId, $sportId, $itemId, $sizeLabel, $quantity]
    );
    return true;
}

function coach_teams(int $personId): array
{
    return fetch_all(
        'SELECT t.TeamID, t.TeamName, s.SportName, t.AgeGroup, t.Season, cf.CoachRole
         FROM CoachesFor cf
         JOIN Team t ON t.TeamID = cf.TeamID
         JOIN Sport s ON s.SportID = t.SportID
         WHERE cf.PersonID = ?
         ORDER BY s.SportName, t.TeamName',
        [$personId]
    );
}

function coach_add_player_options(int $coachId): array
{
    return fetch_all(
        'SELECT t.TeamID, t.TeamName, s.SportName,
                p.PersonID AS PlayerID,
                CONCAT(p.FirstName, CHAR(32), p.LastName) AS PlayerName
         FROM CoachesFor cf
         JOIN Team t ON t.TeamID = cf.TeamID
         JOIN Sport s ON s.SportID = t.SportID
         LEFT JOIN Registers r ON r.SportID = t.SportID
         LEFT JOIN Player pl ON pl.PersonID = r.PersonID
         LEFT JOIN Person p ON p.PersonID = pl.PersonID
         LEFT JOIN PlaysOn po ON po.PersonID = p.PersonID AND po.TeamID = t.TeamID
         WHERE cf.PersonID = ? AND po.PersonID IS NULL
         ORDER BY s.SportName, t.TeamName, PlayerName',
        [$coachId]
    );
}

function leave_team_as_coach(int $personId, int $teamId): void
{
    execute_sql('DELETE FROM CoachesFor WHERE PersonID = ? AND TeamID = ?', [$personId, $teamId]);
}

function add_player_to_coach_team(int $coachId, int $playerId, int $teamId): string
{
    $team = fetch_one(
        'SELECT t.TeamID, t.SportID, s.MaxRosterSize, t.CurrentRosterSize
         FROM Team t
         JOIN Sport s ON s.SportID = t.SportID
         JOIN CoachesFor cf ON cf.TeamID = t.TeamID
         WHERE t.TeamID = ? AND cf.PersonID = ?
         GROUP BY t.TeamID, t.SportID, s.MaxRosterSize, t.CurrentRosterSize',
        [$teamId, $coachId]
    );

    if ($team === null) {
        return 'You can only add players to teams you coach.';
    }
    if ((int) $team['CurrentRosterSize'] >= (int) $team['MaxRosterSize']) {
        return 'Roster cap reached for this team.';
    }

    $registered = fetch_one(
        'SELECT PersonID FROM Registers WHERE PersonID = ? AND SportID = ?',
        [$playerId, (int) $team['SportID']]
    );
    if ($registered === null) {
        return 'Player must register for the team sport before joining the roster.';
    }

    try {
        execute_sql(
            'INSERT IGNORE INTO PlaysOn (PersonID, TeamID, SportID, JoinedAt, UniformNumber) VALUES (?, ?, ?, CURRENT_DATE, NULL)',
            [$playerId, $teamId, (int) $team['SportID']]
        );
    } catch (PDOException $exception) {
        $errorInfo = $exception->errorInfo ?? [];
        if (($errorInfo[0] ?? null) === '45000'
            && ($errorInfo[2] ?? null) === 'roster_capacity_exceeded') {
            return 'Roster cap reached for this team.';
        }
        throw $exception;
    }
    return 'Player added or already present on the roster.';
}

function admin_players(): array
{
    return fetch_all(
        'SELECT p.PersonID, CONCAT(p.FirstName, CHAR(32), p.LastName) AS PlayerName, p.Email,
                COUNT(po.TeamID) AS Teams
         FROM Player pl
         JOIN Person p ON p.PersonID = pl.PersonID
         LEFT JOIN PlaysOn po ON po.PersonID = pl.PersonID
         GROUP BY p.PersonID, p.FirstName, p.LastName, p.Email
         ORDER BY PlayerName'
    );
}

function admin_coaches(): array
{
    return fetch_all(
        'SELECT p.PersonID, CONCAT(p.FirstName, CHAR(32), p.LastName) AS CoachName, c.CertificationLevel,
                COUNT(cf.TeamID) AS Teams
         FROM Coach c
         JOIN Person p ON p.PersonID = c.PersonID
         LEFT JOIN CoachesFor cf ON cf.PersonID = c.PersonID
         GROUP BY p.PersonID, p.FirstName, p.LastName, c.CertificationLevel
         ORDER BY CoachName'
    );
}

function create_team(string $teamName, int $sportId, string $ageGroup, string $season): string
{
    if ($teamName === '' || $ageGroup === '' || $season === '') {
        return 'Team name, age group, and season are required.';
    }

    try {
        execute_sql(
            'INSERT INTO Team (TeamName, SportID, AgeGroup, Season) VALUES (?, ?, ?, ?)',
            [$teamName, $sportId, $ageGroup, $season]
        );
    } catch (PDOException $exception) {
        if ($exception->getCode() === '23000') {
            return 'A team with this sport and name already exists.';
        }
        throw $exception;
    }

    return 'Team created.';
}

function assign_coach(int $coachId, int $teamId, string $role): string
{
    $team = fetch_one('SELECT SportID FROM Team WHERE TeamID = ?', [$teamId]);
    if ($team === null) {
        return 'Team not found.';
    }

    $eligible = fetch_one(
        'SELECT PersonID FROM CanCoach WHERE PersonID = ? AND SportID = ?',
        [$coachId, (int) $team['SportID']]
    );
    if ($eligible === null) {
        return 'Coach is not eligible for this sport.';
    }

    if ($role === 'Head Coach') {
        $headCoach = fetch_one(
            'SELECT PersonID FROM CoachesFor WHERE TeamID = ? AND CoachRole = ? AND PersonID <> ?',
            [$teamId, 'Head Coach', $coachId]
        );
        if ($headCoach !== null) {
            return 'This team already has a head coach.';
        }
    }

    execute_sql(
        'INSERT INTO CoachesFor (PersonID, TeamID, SportID, CoachRole) VALUES (?, ?, ?, ?)
         ON DUPLICATE KEY UPDATE CoachRole = ?',
        [$coachId, $teamId, (int) $team['SportID'], $role, $role]
    );
    return 'Coach assignment saved.';
}

function admin_assign_coach_options(): array
{
    return fetch_all(
        'SELECT t.TeamID, t.TeamName, s.SportName,
                p.PersonID AS CoachID,
                CONCAT(p.FirstName, CHAR(32), p.LastName) AS CoachName,
                cf.CoachRole AS CurrentRole
         FROM Team t
         JOIN Sport s ON s.SportID = t.SportID
         JOIN CanCoach cc ON cc.SportID = t.SportID
         JOIN Coach c ON c.PersonID = cc.PersonID
         JOIN Person p ON p.PersonID = c.PersonID
         LEFT JOIN CoachesFor cf ON cf.PersonID = p.PersonID AND cf.TeamID = t.TeamID
         ORDER BY s.SportName, t.TeamName, CoachName'
    );
}

function report_popular_sports(): array
{
    return fetch_all(
        'SELECT s.SportName, COUNT(r.PersonID) AS RegisteredPlayers
         FROM Sport s
         LEFT JOIN Registers r ON r.SportID = s.SportID
         GROUP BY s.SportID, s.SportName
         ORDER BY RegisteredPlayers DESC, s.SportName'
    );
}

function report_players_most_teams(): array
{
    return fetch_all(
        'SELECT CONCAT(p.FirstName, CHAR(32), p.LastName) AS PlayerName, COUNT(po.TeamID) AS Teams
         FROM Player pl
         JOIN Person p ON p.PersonID = pl.PersonID
         LEFT JOIN PlaysOn po ON po.PersonID = pl.PersonID
         GROUP BY p.PersonID, p.FirstName, p.LastName
         ORDER BY Teams DESC, PlayerName
         LIMIT 10'
    );
}

function report_coaches_most_teams(): array
{
    return fetch_all(
        'SELECT CONCAT(p.FirstName, CHAR(32), p.LastName) AS CoachName, COUNT(cf.TeamID) AS Teams
         FROM Coach c
         JOIN Person p ON p.PersonID = c.PersonID
         LEFT JOIN CoachesFor cf ON cf.PersonID = c.PersonID
         GROUP BY p.PersonID, p.FirstName, p.LastName
         ORDER BY Teams DESC, CoachName
         LIMIT 10'
    );
}

function report_average_fee(): array
{
    return fetch_all(
        'SELECT COUNT(*) AS PlayerTeamFeeRows, ROUND(AVG(AmountOwed), 2) AS AverageFee
         FROM FeesOwed'
    );
}

function report_top_equipment(): array
{
    return fetch_all(
        'SELECT ui.ItemName, SUM(eo.Quantity) AS UnitsOrdered,
                ROUND(SUM(eo.Quantity * ui.UnitPrice), 2) AS Revenue
         FROM EquipmentOrder eo
         JOIN UniformItem ui ON ui.ItemID = eo.ItemID
         GROUP BY ui.ItemID, ui.ItemName
         ORDER BY UnitsOrdered DESC, ui.ItemName
         LIMIT 10'
    );
}
