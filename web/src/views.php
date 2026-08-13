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

    $links = ['<a href="?page=home">Home</a>'];
    if (has_role('Player')) {
        $links[] = '<a href="?page=player-search">Player Search</a>';
        $links[] = '<a href="?page=player-join-sport">Join Sport</a>';
        $links[] = '<a href="?page=player-order-equipment">Order Equipment</a>';
        $links[] = '<a href="?page=player-teams">My Teams</a>';
        $links[] = '<a href="?page=player-fees">Fees Owed</a>';
    }
    if (has_role('Coach')) {
        $links[] = '<a href="?page=coach-search">Coach Search</a>';
        $links[] = '<a href="?page=coach-teams">Coach Teams</a>';
        $links[] = '<a href="?page=coach-add-player">Add Player</a>';
    }
    if (has_role('Admin')) {
        $links[] = '<a href="?page=admin-search">Admin Search</a>';
        $links[] = '<a href="?page=admin-people">People</a>';
        $links[] = '<a href="?page=admin-create-team">Create Team</a>';
        $links[] = '<a href="?page=admin-assign-coach">Assign Coach</a>';
        $links[] = '<a href="?page=admin-reports">Reports</a>';
    }
    return '<nav>' . implode('', $links) . '</nav>';
}

function table_for(array $rows): string
{
    if ($rows === []) {
        return '<p class="empty">No rows found.</p>';
    }

    $columns = array_keys($rows[0]);
    $html = '<div class="table-wrap"><table><thead><tr>';
    foreach ($columns as $column) {
        $html .= '<th scope="col">' . h((string) $column) . '</th>';
    }
    $html .= '</tr></thead><tbody>';
    foreach ($rows as $row) {
        $html .= '<tr>';
        foreach ($columns as $column) {
            $html .= '<td>' . h($row[$column] ?? '') . '</td>';
        }
        $html .= '</tr>';
    }
    return $html . '</tbody></table></div>';
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
