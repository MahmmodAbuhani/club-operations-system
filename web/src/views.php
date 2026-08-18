<?php

declare(strict_types=1);

function render_page(string $title, string $content): void
{
    $flash = take_flash();
    echo '<!doctype html><html lang="en"><head><meta charset="utf-8">';
    echo '<meta name="viewport" content="width=device-width, initial-scale=1">';
    echo '<title>' . h($title) . ' | Club Operations System</title>';
    echo '<link rel="stylesheet" href="assets/style.css"></head><body>';
    echo '<header><a class="brand" href="?page=home">Club Operations System</a>';
    if (current_person_id() !== 0) {
        echo '<span>' . h(current_person_name()) . ' · ' . h(implode(', ', current_roles())) . '</span>';
        echo '<form method="post" class="logout-form">' . hidden_page('logout') . '<button type="submit">Sign out</button></form>';
    }
    echo '</header><main>';
    echo navigation();
    if ($flash !== null) {
        $role = $flash['type'] === 'error' ? 'alert' : 'status';
        echo '<p class="alert ' . h($flash['type']) . '" role="' . $role . '">' . h($flash['message']) . '</p>';
    }
    echo '<section class="panel"><h1>' . h($title) . '</h1>' . $content . '</section>';
    echo '</main></body></html>';
}

function navigation(): string
{
    if (current_person_id() === 0) {
        return '';
    }

    $links = [navigation_link('home', 'Home')];
    if (has_role('Player')) {
        $links[] = navigation_link('player-search', 'Player Search');
        $links[] = navigation_link('player-join-sport', 'Join Sport');
        $links[] = navigation_link('player-order-equipment', 'Order Equipment');
        $links[] = navigation_link('player-teams', 'My Teams');
        $links[] = navigation_link('player-fees', 'Fees Owed');
    }
    if (has_role('Coach')) {
        $links[] = navigation_link('coach-search', 'Coach Search');
        $links[] = navigation_link('coach-teams', 'Coach Teams');
        $links[] = navigation_link('coach-add-player', 'Add Player');
    }
    if (has_role('Admin')) {
        $links[] = navigation_link('admin-search', 'Admin Search');
        $links[] = navigation_link('admin-people', 'People');
        $links[] = navigation_link('admin-create-team', 'Create Team');
        $links[] = navigation_link('admin-assign-coach', 'Assign Coach');
        $links[] = navigation_link('admin-reports', 'Reports');
    }
    return '<nav aria-label="Application navigation">' . implode('', $links) . '</nav>';
}

function navigation_link(string $route, string $label): string
{
    $current = (string) ($_GET['page'] ?? 'home');
    $currentAttribute = $current === $route ? ' aria-current="page"' : '';
    return '<a href="?page=' . h($route) . '"' . $currentAttribute . '>' . h($label) . '</a>';
}

function table_for(array $rows): string
{
    if ($rows === []) {
        return '<p class="empty">No rows found.</p>';
    }

    $columns = array_keys($rows[0]);
    $html = '<div class="table-wrap" role="region" aria-label="Scrollable data table" tabindex="0"><table><thead><tr>';
    foreach ($columns as $column) {
        $html .= '<th scope="col">' . h(human_column_label((string) $column)) . '</th>';
    }
    $html .= '</tr></thead><tbody>';
    foreach ($rows as $row) {
        $html .= '<tr>';
        foreach ($columns as $column) {
            $html .= '<td>' . h(format_table_value((string) $column, $row[$column] ?? null)) . '</td>';
        }
        $html .= '</tr>';
    }
    return $html . '</tbody></table></div>';
}

function human_column_label(string $column): string
{
    return match ($column) {
        'SportName' => 'Sport',
        'RegisteredPlayers' => 'Registered players',
        'PlayerName' => 'Player',
        'CoachName' => 'Coach',
        'PlayerTeamFeeRows' => 'Player-team records',
        'AverageFee' => 'Average fee owed',
        'ItemName' => 'Equipment item',
        'UnitsOrdered' => 'Units ordered',
        'Revenue' => 'Estimated value',
        default => trim(preg_replace('/(?<!^)([A-Z])/', ' $1', $column) ?? $column),
    };
}

function format_table_value(string $column, mixed $value): string
{
    if ($value === null || $value === '') {
        return 'n/a';
    }
    if (in_array($column, ['AverageFee', 'Revenue'], true)) {
        return '$' . number_format((float) $value, 2);
    }
    return (string) $value;
}

function hidden_page(string $page, bool $includeCsrf = true): string
{
    $html = '<input type="hidden" name="page" value="' . h($page) . '">';
    return $includeCsrf ? $html . csrf_field() : $html;
}

function team_search_form(string $page): string
{
    return '<form method="get" class="inline-form">' .
        hidden_page($page, false) .
        '<label>Search teams <input name="q" value="' . h($_GET['q'] ?? '') . '"></label>' .
        '<button type="submit">Search</button></form>';
}

function sport_select(string $name): string
{
    $html = '<select name="' . h($name) . '">';
    foreach (all_sports() as $sport) {
        $html .= '<option value="' . h($sport['SportID']) . '">' . h($sport['SportName']) . '</option>';
    }
    return $html . '</select>';
}
