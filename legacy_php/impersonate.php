<?php
require_once '../config.php';
require_once '../database.php';

// Only admins can impersonate
if (!isset($_SESSION['user_id']) || $_SESSION['user_role'] !== 'admin') {
    header("Location: ../login.php");
    exit;
}

// Already impersonating? Exit first
if (isset($_SESSION['admin_origin'])) {
    header("Location: impersonate_exit.php");
    exit;
}

// Validate target user
$target_id = (int)($_GET['user_id'] ?? 0);
if (!$target_id) {
    $_SESSION['flash_error'] = 'Invalid user selected for impersonation.';
    header("Location: users.php");
    exit;
}

$db = Database::getInstance()->getConnection();
$stmt = $db->prepare("SELECT id, username, role FROM users WHERE id = ?");
$stmt->execute([$target_id]);
$target = $stmt->fetch();

if (!$target) {
    $_SESSION['flash_error'] = 'User not found.';
    header("Location: users.php");
    exit;
}

// Cannot impersonate another admin
if ($target['role'] === 'admin') {
    $_SESSION['flash_error'] = 'You cannot impersonate another admin account.';
    header("Location: users.php");
    exit;
}

// Store admin origin session data
$_SESSION['admin_origin'] = [
    'user_id'   => $_SESSION['user_id'],
    'username'  => $_SESSION['username'],
    'user_role' => $_SESSION['user_role'],
    'return_url' => BASE_URL . '/admin/users.php',
];

// Swap session to target user
$_SESSION['user_id']   = $target['id'];
$_SESSION['username']  = $target['username'];
$_SESSION['user_role'] = $target['role'];

// Log the impersonation event
try {
    $log = $db->prepare("
        INSERT INTO system_errors (error_type, error_message, file_path, role)
        VALUES ('Impersonation', ?, 'admin/impersonate.php', 'admin')
    ");
    $msg = "Admin [ID:{$_SESSION['admin_origin']['user_id']}] entered as user [{$target['username']}] (role: {$target['role']})";
    $log->execute([$msg]);
} catch (Exception $e) {
    // Non-critical, continue
}

// Redirect to the target user's dashboard
$role = $target['role'];
header("Location: " . BASE_URL . "/{$role}/dashboard.php");
exit;
