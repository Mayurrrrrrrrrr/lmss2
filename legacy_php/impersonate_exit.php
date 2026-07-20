<?php
require_once '../config.php';

// Must be in an impersonation session to exit
if (!isset($_SESSION['admin_origin'])) {
    header("Location: ../login.php");
    exit;
}

// Restore admin session
$origin = $_SESSION['admin_origin'];
$_SESSION['user_id']   = $origin['user_id'];
$_SESSION['username']  = $origin['username'];
$_SESSION['user_role'] = $origin['role'] ?? 'admin';

unset($_SESSION['admin_origin']);

// Return to where admin came from
$return_url = $origin['return_url'] ?? BASE_URL . '/admin/dashboard.php';
header("Location: " . $return_url);
exit;
