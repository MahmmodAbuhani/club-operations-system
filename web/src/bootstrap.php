<?php

declare(strict_types=1);

$cookieSecure = getenv('SPORTLFC_COOKIE_SECURE') === '1';
ini_set('session.use_strict_mode', '1');
ini_set('session.use_only_cookies', '1');
ini_set('display_errors', '0');
error_reporting(E_ALL);
session_name('sportlfc_session');
session_set_cookie_params([
    'lifetime' => 0,
    'path' => '/',
    'secure' => $cookieSecure,
    'httponly' => true,
    'samesite' => 'Lax',
]);
session_start();

if (empty($_SESSION['csrf_token'])) {
    $_SESSION['csrf_token'] = bin2hex(random_bytes(32));
}

function env_value(string $key, string $default): string
{
    $value = getenv($key);
    return $value === false || $value === '' ? $default : $value;
}

function db(): PDO
{
    static $pdo = null;

    if ($pdo === null) {
        $host = env_value('SPORTLFC_DB_HOST', '127.0.0.1');
        $name = env_value('SPORTLFC_DB_NAME', 'sportlfc');
        $user = env_value('SPORTLFC_DB_USER', 'sportlfc');
        $pass = env_value('SPORTLFC_DB_PASS', 'sportlfcpass');
        $dsn = "mysql:host={$host};dbname={$name};charset=utf8mb4";

        $pdo = new PDO($dsn, $user, $pass, [
            PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
            PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
            PDO::ATTR_EMULATE_PREPARES => false,
        ]);
    }

    return $pdo;
}

function h(mixed $value): string
{
    return htmlspecialchars((string) $value, ENT_QUOTES, 'UTF-8');
}

function fetch_all(string $sql, array $params = []): array
{
    $stmt = db()->prepare($sql);
    $stmt->execute($params);
    return $stmt->fetchAll();
}

function fetch_one(string $sql, array $params = []): ?array
{
    $rows = fetch_all($sql, $params);
    return $rows[0] ?? null;
}

function execute_sql(string $sql, array $params = []): int
{
    $stmt = db()->prepare($sql);
    $stmt->execute($params);
    return $stmt->rowCount();
}

function csrf_token(): string
{
    return (string) ($_SESSION['csrf_token'] ?? '');
}

function csrf_field(): string
{
    return '<input type="hidden" name="csrf_token" value="' . h(csrf_token()) . '">';
}

function verify_csrf(): bool
{
    $submitted = (string) ($_POST['csrf_token'] ?? '');
    return $submitted !== '' && hash_equals(csrf_token(), $submitted);
}

function current_person_id(): int
{
    return (int) ($_SESSION['person_id'] ?? 0);
}

function current_person_name(): string
{
    return (string) ($_SESSION['person_name'] ?? 'Guest');
}

function current_roles(): array
{
    return $_SESSION['roles'] ?? [];
}

function has_role(string $role): bool
{
    return in_array($role, current_roles(), true);
}

function require_login(): void
{
    if (current_person_id() === 0) {
        redirect('login');
    }
}

function require_role(string $role): void
{
    require_login();
    if (!has_role($role)) {
        http_response_code(403);
        render_page('Forbidden', '<p class="alert error">This role cannot access that page.</p>');
        exit;
    }
}

function redirect(string $route, int $status = 303): never
{
    http_response_code($status);
    header('Location: ?page=' . urlencode($route));
    exit;
}

function destroy_session(): void
{
    $_SESSION = [];
    if (ini_get('session.use_cookies')) {
        $params = session_get_cookie_params();
        setcookie(session_name(), '', [
            'expires' => time() - 42000,
            'path' => $params['path'],
            'domain' => $params['domain'],
            'secure' => $params['secure'],
            'httponly' => $params['httponly'],
            'samesite' => $params['samesite'] ?? 'Lax',
        ]);
    }
    session_destroy();
}

function render_http_error(int $status, string $message): never
{
    http_response_code($status);
    render_page((string) $status, '<p class="alert error" role="alert">' . h($message) . '</p>');
    exit;
}

function log_unexpected_exception(Throwable $exception): string
{
    $correlationId = bin2hex(random_bytes(8));
    error_log(sprintf('[Club Operations System %s] %s', $correlationId, (string) $exception));
    return $correlationId;
}

function set_flash(string $message, string $type = 'success'): void
{
    $_SESSION['flash'] = ['message' => $message, 'type' => $type];
}

function take_flash(): ?array
{
    $flash = $_SESSION['flash'] ?? null;
    unset($_SESSION['flash']);
    return $flash;
}
