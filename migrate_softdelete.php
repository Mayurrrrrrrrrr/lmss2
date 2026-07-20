<?php
// Run from CLI: php /var/www/html/lms/migrate_softdelete.php
// Reads credentials from the .env file to avoid shell escaping issues
$env_file = '/var/www/html/lms/.env';
if (!file_exists($env_file)) die("Cannot find .env at $env_file\n");
$env = parse_ini_file($env_file);
$dsn  = "mysql:host={$env['DB_HOST']};dbname={$env['DB_NAME']};charset=utf8mb4";
$pdo  = new PDO($dsn, $env['DB_USER'], $env['DB_PASS'], [PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION]);

$tables = ['courses', 'modules', 'chapters', 'quizzes', 'questions'];
foreach ($tables as $table) {
    // Check if column already exists
    $chk = $pdo->query("SHOW COLUMNS FROM `$table` LIKE 'deleted_at'")->fetchAll();
    if (empty($chk)) {
        $pdo->exec("ALTER TABLE `$table` ADD COLUMN `deleted_at` TIMESTAMP NULL DEFAULT NULL");
        echo "Added deleted_at to $table\n";
    } else {
        echo "deleted_at already exists on $table — skipped\n";
    }
}

// Add index for performance on the most-queried tables
foreach (['courses','quizzes'] as $t) {
    try {
        $pdo->exec("ALTER TABLE `$t` ADD INDEX idx_deleted_at (deleted_at)");
        echo "Index added on $t.deleted_at\n";
    } catch (PDOException $e) {
        echo "Index on $t.deleted_at already exists — skipped\n";
    }
}
echo "Migration complete.\n";
