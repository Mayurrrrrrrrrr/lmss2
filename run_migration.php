<?php
// One-time migration runner — DELETE THIS FILE AFTER USE
// Secured: only works from localhost
if (!in_array($_SERVER['REMOTE_ADDR'] ?? '', ['127.0.0.1', '::1'])) {
    http_response_code(403);
    die('Forbidden');
}

require_once __DIR__ . '/config.php';
require_once __DIR__ . '/database.php';

$db = Database::getInstance()->getConnection();
$results = [];

$tables = ['courses', 'modules', 'chapters', 'quizzes', 'questions'];
foreach ($tables as $table) {
    // Check if column already exists before trying to add it
    $chk = $db->query("SHOW COLUMNS FROM `$table` LIKE 'deleted_at'")->fetchAll();
    if (empty($chk)) {
        $db->exec("ALTER TABLE `$table` ADD COLUMN `deleted_at` TIMESTAMP NULL DEFAULT NULL");
        $results[] = "✅ $table.deleted_at — Added";
    } else {
        $results[] = "ℹ️  $table.deleted_at — Already exists, skipped";
    }
}

// Add indexes
foreach (['courses', 'quizzes'] as $t) {
    try {
        $db->exec("ALTER TABLE `$t` ADD INDEX `idx_deleted_at` (`deleted_at`)");
        $results[] = "✅ Index on $t.deleted_at — added";
    } catch (PDOException $e) {
        $results[] = "ℹ️  Index on $t.deleted_at — " . $e->getMessage();
    }
}

header('Content-Type: text/plain');
echo implode("\n", $results) . "\nDone.\n";
