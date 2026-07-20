<?php
require_once '../config.php';
require_once '../database.php';

if (!isset($_SESSION['user_id']) || $_SESSION['user_role'] !== 'trainer') {
    header("Location: ../login.php");
    exit;
}

$db = Database::getInstance()->getConnection();
$role_dir = 'trainer';
$page_title = 'Designation Master';
$current_page = 'designations';
require_once '../includes/header.php';

require_once '../includes/designations_shared.php';

require_once '../includes/footer.php';
?>
