<?php

declare(strict_types=1);

require_once __DIR__ . '/../src/bootstrap.php';
require_once __DIR__ . '/../src/repository.php';
require_once __DIR__ . '/../src/views.php';

$method = strtoupper((string) ($_SERVER['REQUEST_METHOD'] ?? 'GET'));
$page = $method === 'POST'
    ? (string) ($_POST['page'] ?? '')
    : (string) ($_GET['page'] ?? 'home');

$getRoutes = [
    'home', 'login', 'player-search', 'player-join-sport', 'player-order-equipment',
    'player-teams', 'player-fees', 'coach-search', 'coach-teams', 'coach-add-player',
    'admin-search', 'admin-people', 'admin-create-team', 'admin-assign-coach', 'admin-reports',
];
$postRoutes = [
    'login', 'logout', 'player-join-sport', 'player-leave-team', 'player-order-equipment',
    'coach-leave-team', 'coach-add-player', 'admin-create-team', 'admin-assign-coach',
];

try {
    if (!in_array($method, ['GET', 'POST'], true)) {
        header('Allow: GET, POST');
        render_http_error(405, 'This request method is not allowed.');
    }

    $allowedRoutes = $method === 'POST' ? $postRoutes : $getRoutes;
    if (!in_array($page, $allowedRoutes, true)) {
        $otherRoutes = $method === 'POST' ? $getRoutes : $postRoutes;
        if (in_array($page, $otherRoutes, true)) {
            header('Allow: ' . ($method === 'POST' ? 'GET' : 'POST'));
            render_http_error(405, 'This route does not allow that request method.');
        }
        render_http_error(404, 'The requested page was not found.');
    }

    if ($page === 'login' && $method === 'POST') {
        if (!verify_csrf()) {
            render_http_error(403, 'The session token is invalid or expired.');
        }
        $email = trim((string) ($_POST['email'] ?? ''));
        $password = (string) ($_POST['password'] ?? '');
        if (authenticate($email, $password)) {
            redirect('home');
        }
        set_flash('Invalid demo login.', 'error');
        redirect('login');
    }

    if ($page === 'login' && $method === 'GET') {
        if (current_person_id() !== 0) {
            redirect('home');
        }
        render_page('Demo Login', login_content());
        exit;
    }

    if ($page === 'logout' && $method === 'POST') {
        if (!verify_csrf()) {
            render_http_error(403, 'The session token is invalid or expired.');
        }
        destroy_session();
        redirect('login');
    }

    if (current_person_id() === 0) {
        redirect('login');
    }

    if ($method === 'POST' && !verify_csrf()) {
        render_http_error(403, 'The session token is invalid or expired.');
    }

    handle_post_routes($page);
    render_page_for_route($page);
} catch (Throwable $exception) {
    $correlationId = log_unexpected_exception($exception);
    render_http_error(500, 'The request could not be completed. Reference: ' . $correlationId);
}

function handle_post_routes(string $page): void
{
    if (($_SERVER['REQUEST_METHOD'] ?? 'GET') !== 'POST') {
        return;
    }

    if ($page === 'player-join-sport') {
        require_role('Player');
        $message = join_sport(current_person_id(), (int) ($_POST['sport_id'] ?? 0));
        set_flash($message, str_contains($message, 'saved') ? 'success' : 'error');
        redirect($page);
    }

    if ($page === 'player-leave-team') {
        require_role('Player');
        $message = leave_team_as_player(current_person_id(), (int) ($_POST['team_id'] ?? 0));
        set_flash($message, str_contains($message, 'removed') ? 'success' : 'error');
        redirect('player-teams');
    }

    if ($page === 'player-order-equipment') {
        require_role('Player');
        $saved = order_equipment(
            current_person_id(),
            (int) ($_POST['team_id'] ?? 0),
            (int) ($_POST['sport_id'] ?? 0),
            (int) ($_POST['item_id'] ?? 0),
            (string) ($_POST['size_label'] ?? ''),
            (int) ($_POST['quantity'] ?? 0)
        );
        set_flash($saved ? 'Equipment order saved.' : 'Order blocked because item, team, or size is invalid.', $saved ? 'success' : 'error');
        redirect($page);
    }

    if ($page === 'coach-leave-team') {
        require_role('Coach');
        leave_team_as_coach(current_person_id(), (int) ($_POST['team_id'] ?? 0));
        set_flash('Coach assignment removed.');
        redirect('coach-teams');
    }

    if ($page === 'coach-add-player') {
        require_role('Coach');
        $message = add_player_to_coach_team(
            current_person_id(),
            (int) ($_POST['player_id'] ?? 0),
            (int) ($_POST['team_id'] ?? 0)
        );
        set_flash($message, str_contains($message, 'added') ? 'success' : 'error');
        redirect($page);
    }

    if ($page === 'admin-create-team') {
        require_role('Admin');
        $message = create_team(
            trim((string) ($_POST['team_name'] ?? '')),
            (int) ($_POST['sport_id'] ?? 0),
            trim((string) ($_POST['age_group'] ?? '')),
            trim((string) ($_POST['season'] ?? ''))
        );
        set_flash($message, str_contains($message, 'created') ? 'success' : 'error');
        redirect($page);
    }

    if ($page === 'admin-assign-coach') {
        require_role('Admin');
        $message = assign_coach(
            (int) ($_POST['coach_id'] ?? 0),
            (int) ($_POST['team_id'] ?? 0),
            (string) ($_POST['coach_role'] ?? 'Assistant Coach')
        );
        set_flash($message, str_contains($message, 'saved') ? 'success' : 'error');
        redirect($page);
    }
}

function render_page_for_route(string $page): void
{
    match ($page) {
        'home' => render_page('Dashboard', dashboard_content()),
        'player-search' => player_search(),
        'player-join-sport' => player_join_sport(),
        'player-order-equipment' => player_order_equipment(),
        'player-teams' => player_teams_page(),
        'player-fees' => player_fees_page(),
        'coach-search' => coach_search(),
        'coach-teams' => coach_teams_page(),
        'coach-add-player' => coach_add_player_page(),
        'admin-search' => admin_search(),
        'admin-people' => admin_people_page(),
        'admin-create-team' => admin_create_team_page(),
        'admin-assign-coach' => admin_assign_coach_page(),
        'admin-reports' => admin_reports_page(),
        default => render_http_error(404, 'The requested page was not found.'),
    };
}

function login_content(): string
{
    return '<p>Use any demo account with password <code>demo123</code>.</p>
        <form method="post">
            ' . hidden_page('login') . '
            <label>Email <input type="email" name="email" value="riley.bennett@example.test" required></label>
            <label>Password <input type="password" name="password" required></label>
            <button type="submit">Sign in</button>
        </form>
        <p class="hint">Useful demos: james.walker@example.test, mike.torres@example.test, priya.nair@example.test, morgan.reed@example.test, riley.bennett@example.test.</p>';
}

function dashboard_content(): string
{
    return '<p>This demo builds the menu from the current person roles. Riley Bennett is both Player and Coach; Priya Nair is Coach and Admin.</p>';
}

function player_search(): void
{
    require_role('Player');
    $content = team_search_form('player-search') . table_for(all_teams((string) ($_GET['q'] ?? '')));
    render_page('Player Team Search', $content);
}

function player_join_sport(): void
{
    require_role('Player');
    $content = '<form method="post">' . hidden_page('player-join-sport') .
        '<label>Sport ' . sport_select('sport_id') . '</label><button type="submit">Register</button></form>';
    render_page('Join Sport', $content);
}

function player_order_equipment(): void
{
    require_role('Player');
    $requirements = equipment_fulfillment_for_player(current_person_id());
    $content = '<p>The application records each submitted order as a history row. Progress is the cumulative quantity ordered for each required team item.</p>';
    foreach ($requirements as $requirement) {
        $statusClass = $requirement['FulfillmentStatus'] === 'Complete' ? 'complete' : 'incomplete';
        $content .= '<section class="requirement-card ' . h($statusClass) . '">';
        $content .= '<h2>' . h($requirement['TeamName']) . ' · ' . h($requirement['ItemName']) . '</h2>';
        $content .= '<p>' . h($requirement['SportName']) . '</p>';
        $content .= '<dl class="fulfillment-summary">' .
            '<div><dt>Required quantity</dt><dd>' . h($requirement['MinQuantity']) . '</dd></div>' .
            '<div><dt>Ordered quantity</dt><dd>' . h($requirement['OrderedQuantity']) . '</dd></div>' .
            '<div><dt>Outstanding quantity</dt><dd>' . h($requirement['OutstandingQuantity']) . '</dd></div>' .
            '<div><dt>Status</dt><dd>' . h($requirement['FulfillmentStatus']) . '</dd></div>' .
            '</dl>';

        $history = equipment_order_history_for_player(
            current_person_id(),
            (int) $requirement['TeamID'],
            (int) $requirement['SportID'],
            (int) $requirement['ItemID']
        );
        $content .= '<section class="order-history" aria-labelledby="order-history-' . h($requirement['TeamID'] . '-' . $requirement['ItemID']) . '">' .
            '<h3 id="order-history-' . h($requirement['TeamID'] . '-' . $requirement['ItemID']) . '">Order history</h3>';
        if ($history === []) {
            $content .= '<p class="hint">No orders recorded yet.</p>';
        } else {
            $content .= '<div class="table-wrap" role="region" aria-label="Scrollable order history" tabindex="0"><table><thead><tr><th scope="col">Date</th><th scope="col">Size</th><th scope="col">Quantity</th></tr></thead><tbody>';
            foreach ($history as $order) {
                $content .= '<tr><td>' . h($order['OrderedAt']) . '</td><td>' . h($order['SizeLabel']) . '</td><td>' . h($order['Quantity']) . '</td></tr>';
            }
            $content .= '</tbody></table></div>';
        }
        $content .= '</section>';

        $sizeSelect = '<select name="size_label" required>';
        foreach (equipment_sizes((int) $requirement['ItemID']) as $size) {
            $sizeSelect .= '<option value="' . h($size['SizeLabel']) . '">' . h($size['SizeLabel']) . '</option>';
        }
        $sizeSelect .= '</select>';
        $defaultQuantity = max(1, (int) $requirement['OutstandingQuantity']);
        $actionLabel = $requirement['FulfillmentStatus'] === 'Complete' ? 'Add another order' : 'Add order';
        $content .= '<form method="post" class="inline-form">' . hidden_page('player-order-equipment') .
            '<input type="hidden" name="team_id" value="' . h($requirement['TeamID']) . '">' .
            '<input type="hidden" name="sport_id" value="' . h($requirement['SportID']) . '">' .
            '<input type="hidden" name="item_id" value="' . h($requirement['ItemID']) . '">' .
            '<label>Size ' . $sizeSelect . '</label>' .
            '<label>Quantity <input type="number" min="1" name="quantity" value="' . h($defaultQuantity) . '" required></label>' .
            '<button type="submit">' . h($actionLabel) . '</button></form></section>';
    }
    if ($requirements === []) {
        $content .= '<p class="empty">No required equipment is available for your teams.</p>';
    }
    render_page('Equipment Fulfillment', $content);
}

function player_teams_page(): void
{
    require_role('Player');
    $rows = player_teams(current_person_id());
    $forms = '';
    foreach ($rows as $row) {
        $forms .= '<form method="post" class="inline-form">' . hidden_page('player-leave-team') .
            '<input type="hidden" name="team_id" value="' . h($row['TeamID']) . '">' .
            '<button type="submit">Leave ' . h($row['TeamName']) . '</button></form>';
    }
    render_page('My Player Teams', table_for($rows) . $forms);
}

function player_fees_page(): void
{
    require_role('Player');
    render_page('Fees Owed', table_for(player_fees(current_person_id())));
}

function coach_search(): void
{
    require_role('Coach');
    render_page('Coach Team Search', team_search_form('coach-search') . table_for(all_teams((string) ($_GET['q'] ?? ''))));
}

function coach_teams_page(): void
{
    require_role('Coach');
    $rows = coach_teams(current_person_id());
    $forms = '';
    foreach ($rows as $row) {
        $forms .= '<form method="post" class="inline-form">' . hidden_page('coach-leave-team') .
            '<input type="hidden" name="team_id" value="' . h($row['TeamID']) . '">' .
            '<button type="submit">Leave ' . h($row['TeamName']) . '</button></form>';
    }
    render_page('My Coach Teams', table_for($rows) . $forms);
}

function coach_add_player_page(): void
{
    require_role('Coach');
    $groups = [];
    foreach (coach_add_player_options(current_person_id()) as $row) {
        $teamId = (string) $row['TeamID'];
        if (!isset($groups[$teamId])) {
            $groups[$teamId] = [
                'TeamID' => $row['TeamID'],
                'TeamName' => $row['TeamName'],
                'SportName' => $row['SportName'],
                'players' => [],
            ];
        }
        if ($row['PlayerID'] !== null) {
            $groups[$teamId]['players'][] = $row;
        }
    }

    $content = '<p class="hint">Choose a player who is registered for the team sport and is not already on that team.</p>';
    foreach ($groups as $group) {
        $content .= '<section class="selection-panel"><h2>' . h($group['TeamName']) . '</h2>';
        $content .= '<p class="hint">' . h($group['SportName']) . '</p>';
        if ($group['players'] === []) {
            $content .= '<p class="empty">No eligible unrostered players are available.</p></section>';
            continue;
        }
        $content .= '<form method="post">' . hidden_page('coach-add-player') .
            '<input type="hidden" name="team_id" value="' . h($group['TeamID']) . '">' .
            '<label>Player for ' . h($group['TeamName']) . ' <select name="player_id" required><option value="">Choose a player</option>';
        foreach ($group['players'] as $player) {
            $content .= '<option value="' . h($player['PlayerID']) . '">' . h($player['PlayerName']) . '</option>';
        }
        $content .= '</select></label><button type="submit">Add player</button></form></section>';
    }
    if ($groups === []) {
        $content .= '<p class="empty">You are not assigned to any teams.</p>';
    }
    render_page('Add Player To Team', $content);
}

function admin_search(): void
{
    require_role('Admin');
    render_page('Admin Team Search', team_search_form('admin-search') . table_for(all_teams((string) ($_GET['q'] ?? ''))));
}

function admin_people_page(): void
{
    require_role('Admin');
    render_page('People Directory', '<h2>Players</h2>' . table_for(admin_players()) . '<h2>Coaches</h2>' . table_for(admin_coaches()));
}

function admin_create_team_page(): void
{
    require_role('Admin');
    $content = '<form method="post">' . hidden_page('admin-create-team') .
        '<label>Team name <input name="team_name" required></label>' .
        '<label>Sport ' . sport_select('sport_id') . '</label>' .
        '<label>Age group <input name="age_group" value="U14" required></label>' .
        '<label>Season <input name="season" value="Spring 2026" required></label>' .
        '<button type="submit">Create team</button></form>';
    render_page('Create Team', $content);
}

function admin_assign_coach_page(): void
{
    require_role('Admin');
    $groups = [];
    foreach (admin_assign_coach_options() as $row) {
        $teamId = (string) $row['TeamID'];
        if (!isset($groups[$teamId])) {
            $groups[$teamId] = [
                'TeamID' => $row['TeamID'],
                'TeamName' => $row['TeamName'],
                'SportName' => $row['SportName'],
                'coaches' => [],
            ];
        }
        $groups[$teamId]['coaches'][] = $row;
    }

    $content = '<p class="hint">Only coaches eligible for each team sport are listed.</p>';
    foreach ($groups as $group) {
        $content .= '<section class="selection-panel"><h2>' . h($group['TeamName']) . '</h2>';
        $content .= '<p class="hint">' . h($group['SportName']) . '</p>';
        $content .= '<form method="post">' . hidden_page('admin-assign-coach') .
            '<input type="hidden" name="team_id" value="' . h($group['TeamID']) . '">' .
            '<label>Coach for ' . h($group['TeamName']) . ' <select name="coach_id" required><option value="">Choose a coach</option>';
        foreach ($group['coaches'] as $coach) {
            $label = $coach['CoachName'];
            if ($coach['CurrentRole'] !== null) {
                $label .= ' (' . $coach['CurrentRole'] . ')';
            }
            $content .= '<option value="' . h($coach['CoachID']) . '">' . h($label) . '</option>';
        }
        $content .= '</select></label>' .
            '<label>Role <select name="coach_role"><option>Head Coach</option><option>Assistant Coach</option></select></label>' .
            '<button type="submit">Assign coach</button></form></section>';
    }
    render_page('Assign Coach', $content);
}

function admin_reports_page(): void
{
    require_role('Admin');
    $content = '<p class="hint">These reports summarize the fictional seed data. Counts describe rows in the current fixture, and estimated value is units ordered multiplied by catalog unit price.</p>' .
        '<h2>Most popular sports</h2><p class="report-definition">Players registered for each sport.</p>' . table_for(report_popular_sports()) .
        '<h2>Players on most teams</h2><p class="report-definition">Roster memberships per player.</p>' . table_for(report_players_most_teams()) .
        '<h2>Coaches with most teams</h2><p class="report-definition">Team assignments per coach.</p>' . table_for(report_coaches_most_teams()) .
        '<h2>Average fee per player-team</h2><p class="report-definition">Average amount owed across player-team fee rows.</p>' . table_for(report_average_fee()) .
        '<h2>Top ten equipment items</h2><p class="report-definition">Units ordered and estimated catalog value from the fictional fixture.</p>' . table_for(report_top_equipment());
    render_page('Admin Analytics Reports', $content);
}
