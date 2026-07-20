<?php
require_once '../config.php';
require_once '../database.php';

if (!isset($_SESSION['user_id']) || $_SESSION['user_role'] !== 'trainer') {
    header("Location: ../login.php");
    exit;
}

/**
 * Synchronize designation, department, and store master tables with newly imported or entered data.
 */
function sync_masters($db, $store_code, $city, $designation, $department) {
    $store_code = trim($store_code);
    $city = trim($city);
    $designation = trim($designation);
    $department = trim($department);

    // 1. Sync Store Master
    if ($store_code !== '') {
        $stmt = $db->prepare("SELECT id FROM stores WHERE LOWER(store_code) = LOWER(?)");
        $stmt->execute([$store_code]);
        if (!$stmt->fetch()) {
            // Store does not exist — insert it
            $store_name = $store_code . " Store";
            $ins = $db->prepare("INSERT INTO stores (store_code, store_name, city) VALUES (?, ?, ?)");
            $ins->execute([$store_code, $store_name, $city]);
        }
    }

    // 2. Sync Designation Master
    if ($designation !== '') {
        $stmt = $db->prepare("SELECT id FROM designations WHERE LOWER(designation_name) = LOWER(?)");
        $stmt->execute([$designation]);
        if (!$stmt->fetch()) {
            // Designation does not exist — insert it
            $ins = $db->prepare("INSERT INTO designations (designation_name) VALUES (?)");
            $ins->execute([$designation]);
        }
    }

    // 3. Sync Department Master
    if ($department !== '') {
        $stmt = $db->prepare("SELECT id FROM departments WHERE LOWER(department_name) = LOWER(?)");
        $stmt->execute([$department]);
        if (!$stmt->fetch()) {
            // Department does not exist — insert it
            $ins = $db->prepare("INSERT INTO departments (department_name) VALUES (?)");
            $ins->execute([$department]);
        }
    }
}

// Handle CSV template download
if (isset($_GET['action']) && $_GET['action'] === 'download_template') {
    header('Content-Type: text/csv; charset=utf-8');
    header('Content-Disposition: attachment; filename=participants_template.csv');
    $output = fopen('php://output', 'w');
    
    // UTF-8 BOM for Excel compatibility
    fprintf($output, chr(0xEF).chr(0xBB).chr(0xBF));
    
    fputcsv($output, ['username', 'password', 'full_name', 'mobile_number', 'email_id', 'store_code', 'city', 'designation', 'department', 'reporting_manager_name', 'nsm_vp_name']);
    fputcsv($output, ['john_doe', 'Pass1234', 'John Doe', '9876543210', 'john@example.com', 'ST001', 'New York', 'Sales Associate', 'Sales', 'Jane Manager', 'Sarah VP']);
    fputcsv($output, ['alice_smith', 'Pass5678', 'Alice Smith', '8765432109', 'alice@example.com', 'ST002', 'Los Angeles', 'Store Manager', 'Operations', 'John Manager', 'Sarah VP']);
    fclose($output);
    exit;
}

// Handle CSV export of all participants
if (isset($_GET['action']) && $_GET['action'] === 'export') {
    $db_export = Database::getInstance()->getConnection();
    header('Content-Type: text/csv; charset=utf-8');
    header('Content-Disposition: attachment; filename=participants_export_' . date('Y-m-d') . '.csv');
    $output = fopen('php://output', 'w');
    
    // UTF-8 BOM for Excel compatibility
    fprintf($output, chr(0xEF).chr(0xBB).chr(0xBF));
    
    // Column Headers
    fputcsv($output, [
        'ID', 
        'Username', 
        'Full Name', 
        'Mobile Number', 
        'Email ID', 
        'Store Code', 
        'City', 
        'Designation', 
        'Department', 
        'Reporting Manager', 
        'NSM/VP Name', 
        'Created At'
    ]);
    
    // Fetch all participants with profiles
    $export_stmt = $db_export->query("
        SELECT u.id, u.username, u.created_at, 
               up.full_name, up.mobile_number, up.email_id, up.store_code, up.city, 
               up.designation, up.department, up.reporting_manager_name, up.nsm_vp_name 
        FROM users u 
        LEFT JOIN user_profiles up ON u.id = up.user_id 
        WHERE u.role = 'participant' 
        ORDER BY u.created_at DESC
    ");
    
    while ($row = $export_stmt->fetch(PDO::FETCH_ASSOC)) {
        fputcsv($output, [
            $row['id'],
            $row['username'],
            $row['full_name'] ?? '',
            $row['mobile_number'] ?? '',
            $row['email_id'] ?? '',
            $row['store_code'] ?? '',
            $row['city'] ?? '',
            $row['designation'] ?? '',
            $row['department'] ?? '',
            $row['reporting_manager_name'] ?? '',
            $row['nsm_vp_name'] ?? '',
            $row['created_at']
        ]);
    }
    
    fclose($output);
    exit;
}

// Handle AJAX Team retrieval
if (isset($_GET['action']) && $_GET['action'] === 'get_team' && isset($_GET['user_id'])) {
    $db = Database::getInstance()->getConnection();
    $user_id = (int)$_GET['user_id'];
    
    // Fetch manager details
    $m_stmt = $db->prepare("
        SELECT u.username, up.full_name 
        FROM users u 
        LEFT JOIN user_profiles up ON u.id = up.user_id 
        WHERE u.id = ? AND u.role = 'participant'
    ");
    $m_stmt->execute([$user_id]);
    $manager = $m_stmt->fetch(PDO::FETCH_ASSOC);
    
    if (!$manager) {
        header('Content-Type: application/json');
        echo json_encode(['error' => 'Participant not found']);
        exit;
    }
    
    $full_name = trim($manager['full_name'] ?? '');
    $username = trim($manager['username'] ?? '');
    
    // Fetch team members
    $t_stmt = $db->prepare("
        SELECT u.id, u.username, up.full_name, up.store_code, up.city 
        FROM users u 
        JOIN user_profiles up ON u.id = up.user_id 
        WHERE u.role = 'participant' 
          AND (
              (up.reporting_manager_name = ? AND ? != '')
              OR (up.reporting_manager_name = ?)
          )
        ORDER BY up.full_name ASC
    ");
    $t_stmt->execute([$full_name, $full_name, $username]);
    $team = $t_stmt->fetchAll(PDO::FETCH_ASSOC);
    
    header('Content-Type: application/json');
    echo json_encode([
        'manager' => $full_name ?: $username,
        'team' => $team
    ]);
    exit;
}

// Handle AJAX Participant Details retrieval
if (isset($_GET['action']) && $_GET['action'] === 'get_participant' && isset($_GET['user_id'])) {
    $db = Database::getInstance()->getConnection();
    $user_id = (int)$_GET['user_id'];
    
    $stmt = $db->prepare("
        SELECT u.id, u.username, up.full_name, up.mobile_number, up.email_id, up.store_code, up.city, up.designation, up.department, up.reporting_manager_name, up.nsm_vp_name 
        FROM users u 
        LEFT JOIN user_profiles up ON u.id = up.user_id 
        WHERE u.id = ? AND u.role = 'participant'
    ");
    $stmt->execute([$user_id]);
    $participant = $stmt->fetch(PDO::FETCH_ASSOC);
    
    header('Content-Type: application/json');
    if ($participant) {
        echo json_encode($participant);
    } else {
        echo json_encode(['error' => 'Participant not found']);
    }
    exit;
}

// Verify CSRF
if ($_SERVER['REQUEST_METHOD'] === 'POST' && !csrf_verify()) {
    die('<div class="alert alert-error">Invalid request. Please go back and try again.</div>');
}

$db = Database::getInstance()->getConnection();
$message = '';

$t_stmt = $db->prepare("SELECT gemini_api_key FROM trainer_smtp_settings WHERE user_id = ?");
$t_stmt->execute([$_SESSION['user_id']]);
$has_trainer_gemini = ($t_stmt->fetchColumn() > 0) || !empty(GEMINI_API_KEY);

// Handle Add Participant
if ($_SERVER['REQUEST_METHOD'] === 'POST' && isset($_POST['action']) && $_POST['action'] === 'add') {
    $username = trim($_POST['username'] ?? '');
    $password = trim($_POST['password'] ?? '');
    $full_name = trim($_POST['full_name'] ?? '');
    $mobile_number = trim($_POST['mobile_number'] ?? '');
    $email_id = trim($_POST['email_id'] ?? '');
    $store_code = trim($_POST['store_code'] ?? '');
    
    // Fetch city from Store Master only
    $city = '';
    if (!empty($store_code)) {
        $st_stmt = $db->prepare("SELECT city FROM stores WHERE store_code = ?");
        $st_stmt->execute([$store_code]);
        $city = $st_stmt->fetchColumn() ?: '';
    }
    $designation = trim($_POST['designation'] ?? '');
    $department = trim($_POST['department'] ?? '');
    $reporting_manager_name = trim($_POST['reporting_manager_name'] ?? '');
    $nsm_vp_name = trim($_POST['nsm_vp_name'] ?? '');

    if (strlen($username) < 3) {
        $message = "<div class='alert alert-error'>Username must be at least 3 characters.</div>";
    } elseif (strlen($password) < 4) {
        $message = "<div class='alert alert-error'>Password must be at least 4 characters.</div>";
    } else {
        // Check if username already exists
        $stmt = $db->prepare("SELECT id FROM users WHERE username = ?");
        $stmt->execute([$username]);
        if ($stmt->fetch()) {
            $message = "<div class='alert alert-error'>Username '$username' already exists. Please choose a different one.</div>";
        } else {
            $db->beginTransaction();
            try {
                $hashed = password_hash($password, PASSWORD_DEFAULT);
                $stmt = $db->prepare("INSERT INTO users (username, password, role) VALUES (?, ?, 'participant')");
                $stmt->execute([$username, $hashed]);
                $user_id = $db->lastInsertId();

                $stmt_profile = $db->prepare("INSERT INTO user_profiles (user_id, full_name, mobile_number, email_id, store_code, city, reporting_manager_name, nsm_vp_name, designation, department) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)");
                $stmt_profile->execute([$user_id, $full_name, $mobile_number, $email_id, $store_code, $city, $reporting_manager_name, $nsm_vp_name, $designation, $department]);

                sync_masters($db, $store_code, $city, $designation, $department);

                $db->commit();
                $message = "<div class='alert alert-success'>
  Participant <strong>" . htmlspecialchars($username) . "</strong> created.
  Share the login credentials with them directly — do not display passwords here.
</div>";
            } catch (Exception $e) {
                $db->rollBack();
                $message = "<div class='alert alert-error'>Failed to create participant. Error: " . htmlspecialchars($e->getMessage()) . "</div>";
            }
        }
    }
}

// Handle Edit Participant
if ($_SERVER['REQUEST_METHOD'] === 'POST' && isset($_POST['action']) && $_POST['action'] === 'edit') {
    $edit_id = (int)$_POST['edit_id'];
    $username = trim($_POST['username'] ?? '');
    $password = trim($_POST['password'] ?? '');
    $full_name = trim($_POST['full_name'] ?? '');
    $mobile_number = trim($_POST['mobile_number'] ?? '');
    $email_id = trim($_POST['email_id'] ?? '');
    $store_code = trim($_POST['store_code'] ?? '');
    
    // Fetch city from Store Master only
    $city = '';
    if (!empty($store_code)) {
        $st_stmt = $db->prepare("SELECT city FROM stores WHERE store_code = ?");
        $st_stmt->execute([$store_code]);
        $city = $st_stmt->fetchColumn() ?: '';
    }
    $designation = trim($_POST['designation'] ?? '');
    $department = trim($_POST['department'] ?? '');
    $reporting_manager_name = trim($_POST['reporting_manager_name'] ?? '');
    $nsm_vp_name = trim($_POST['nsm_vp_name'] ?? '');

    // Verify if participant exists
    $stmt = $db->prepare("SELECT username FROM users WHERE id = ? AND role = 'participant'");
    $stmt->execute([$edit_id]);
    $existing = $stmt->fetch();

    if (!$existing) {
        $message = "<div class='alert alert-error'>Participant not found.</div>";
    } elseif (strlen($username) < 3) {
        $message = "<div class='alert alert-error'>Username must be at least 3 characters.</div>";
    } else {
        // Check username uniqueness if changing it
        if ($username !== $existing['username']) {
            $stmt = $db->prepare("SELECT id FROM users WHERE username = ?");
            $stmt->execute([$username]);
            if ($stmt->fetch()) {
                $message = "<div class='alert alert-error'>Username '$username' already exists. Please choose a different one.</div>";
                goto skip_update;
            }
        }

        $db->beginTransaction();
        try {
            // 1. Update user username and optional password
            if (!empty($password)) {
                if (strlen($password) < 4) {
                    throw new Exception("Password must be at least 4 characters.");
                }
                $hashed = password_hash($password, PASSWORD_DEFAULT);
                $stmt = $db->prepare("UPDATE users SET username = ?, password = ? WHERE id = ?");
                $stmt->execute([$username, $hashed, $edit_id]);
            } else {
                $stmt = $db->prepare("UPDATE users SET username = ? WHERE id = ?");
                $stmt->execute([$username, $edit_id]);
            }

            // 2. Update user profile
            $stmt_profile_check = $db->prepare("SELECT id FROM user_profiles WHERE user_id = ?");
            $stmt_profile_check->execute([$edit_id]);
            if ($stmt_profile_check->fetch()) {
                $stmt_profile = $db->prepare("
                    UPDATE user_profiles 
                    SET full_name = ?, mobile_number = ?, email_id = ?, store_code = ?, city = ?, reporting_manager_name = ?, nsm_vp_name = ?, designation = ?, department = ? 
                    WHERE user_id = ?
                ");
                $stmt_profile->execute([$full_name, $mobile_number, $email_id, $store_code, $city, $reporting_manager_name, $nsm_vp_name, $designation, $department, $edit_id]);
            } else {
                $stmt_profile = $db->prepare("
                    INSERT INTO user_profiles (user_id, full_name, mobile_number, email_id, store_code, city, reporting_manager_name, nsm_vp_name, designation, department) 
                    VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                ");
                $stmt_profile->execute([$edit_id, $full_name, $mobile_number, $email_id, $store_code, $city, $reporting_manager_name, $nsm_vp_name, $designation, $department]);
            }

            sync_masters($db, $store_code, $city, $designation, $department);

            $db->commit();
            $message = "<div class='alert alert-success'>Participant <strong>" . htmlspecialchars($username) . "</strong> successfully updated.</div>";
        } catch (Exception $e) {
            $db->rollBack();
            $message = "<div class='alert alert-error'>Failed to update participant. Error: " . htmlspecialchars($e->getMessage()) . "</div>";
        }
    }
    skip_update:
}

// Handle Bulk Upload Participants
if ($_SERVER['REQUEST_METHOD'] === 'POST' && isset($_POST['action']) && $_POST['action'] === 'bulk_upload') {
    if (!isset($_FILES['csv_file']) || $_FILES['csv_file']['error'] !== UPLOAD_ERR_OK) {
        $message = "<div class='alert alert-error'>Please select a valid CSV file to upload.</div>";
    } else {
        $file_tmp = $_FILES['csv_file']['tmp_name'];
        if (($handle = fopen($file_tmp, "r")) !== FALSE) {
            // Read header row
            $headers = fgetcsv($handle, 1000, ",");
            if ($headers) {
                // Remove BOM if present
                if (substr($headers[0], 0, 3) == pack("CCC", 0xef, 0xbb, 0xbf)) {
                    $headers[0] = substr($headers[0], 3);
                }
                $header_map = [];
                foreach ($headers as $index => $col_name) {
                    $header_map[trim(strtolower($col_name))] = $index;
                }
                
                // Validate required columns: username, password
                if (!isset($header_map['username']) || !isset($header_map['password'])) {
                    $message = "<div class='alert alert-error'>CSV must contain at least 'username' and 'password' columns.</div>";
                } else {
                    $success_count = 0;
                    $error_rows = [];
                    $row_number = 1;
                    
                    // Fetch stores to map store_code to city if needed
                    $store_city_map = [];
                    $stores_stmt = $db->query("SELECT store_code, city FROM stores");
                    while ($st = $stores_stmt->fetch(PDO::FETCH_ASSOC)) {
                        $store_city_map[trim(strtolower($st['store_code']))] = $st['city'];
                    }
                    
                    $db->beginTransaction();
                    try {
                        while (($data = fgetcsv($handle, 1000, ",")) !== FALSE) {
                            $row_number++;
                            
                            // Get values using mapped header indices
                            $username = isset($header_map['username']) ? trim($data[$header_map['username']] ?? '') : '';
                            $password = isset($header_map['password']) ? trim($data[$header_map['password']] ?? '') : '';
                            $full_name = isset($header_map['full_name']) ? trim($data[$header_map['full_name']] ?? '') : '';
                            $mobile_number = isset($header_map['mobile_number']) ? trim($data[$header_map['mobile_number']] ?? '') : '';
                            $email_id = isset($header_map['email_id']) ? trim($data[$header_map['email_id']] ?? '') : '';
                            $store_code = isset($header_map['store_code']) ? trim($data[$header_map['store_code']] ?? '') : '';
                            $city = isset($header_map['city']) ? trim($data[$header_map['city']] ?? '') : '';
                            $designation = isset($header_map['designation']) ? trim($data[$header_map['designation']] ?? '') : '';
                            $department = isset($header_map['department']) ? trim($data[$header_map['department']] ?? '') : '';
                            $reporting_manager_name = isset($header_map['reporting_manager_name']) ? trim($data[$header_map['reporting_manager_name']] ?? '') : '';
                            $nsm_vp_name = isset($header_map['nsm_vp_name']) ? trim($data[$header_map['nsm_vp_name']] ?? '') : '';
                            
                            // Skip completely empty rows
                            if (empty($username) && empty($password) && empty($full_name)) {
                                continue;
                            }
                            
                            // Validations
                            if (strlen($username) < 3) {
                                $error_rows[] = "Row $row_number: Username must be at least 3 characters.";
                                continue;
                            }
                            if (strlen($password) < 4) {
                                $error_rows[] = "Row $row_number ($username): Password must be at least 4 characters.";
                                continue;
                            }
                            
                            // Check uniqueness
                            $stmt = $db->prepare("SELECT id FROM users WHERE username = ?");
                            $stmt->execute([$username]);
                            if ($stmt->fetch()) {
                                $error_rows[] = "Row $row_number ($username): Username already exists.";
                                continue;
                            }
                            
                            // Autofill city from store code
                            if (empty($city) && !empty($store_code)) {
                                $store_key = trim(strtolower($store_code));
                                if (isset($store_city_map[$store_key])) {
                                    $city = $store_city_map[$store_key];
                                }
                            }
                            
                            $hashed = password_hash($password, PASSWORD_DEFAULT);
                            $stmt = $db->prepare("INSERT INTO users (username, password, role) VALUES (?, ?, 'participant')");
                            $stmt->execute([$username, $hashed]);
                            $user_id = $db->lastInsertId();
                            
                            $stmt_profile = $db->prepare("INSERT INTO user_profiles (user_id, full_name, mobile_number, email_id, store_code, city, reporting_manager_name, nsm_vp_name, designation, department) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)");
                            $stmt_profile->execute([$user_id, $full_name, $mobile_number, $email_id, $store_code, $city, $reporting_manager_name, $nsm_vp_name, $designation, $department]);
                            
                            sync_masters($db, $store_code, $city, $designation, $department);

                            $success_count++;
                        }
                        $db->commit();
                        
                        $message = "<div class='alert alert-success'>Bulk upload completed. <strong>$success_count</strong> participants created successfully.</div>";
                        if (!empty($error_rows)) {
                            $message .= "<div class='alert alert-error' style='margin-top: 10px;'>";
                            $message .= "<strong>Errors occurred in some rows:</strong><ul style='margin-top: 5px; padding-left: 20px; font-size: 0.9rem;'>";
                            foreach (array_slice($error_rows, 0, 10) as $err) {
                                $message .= "<li>" . htmlspecialchars($err) . "</li>";
                            }
                            if (count($error_rows) > 10) {
                                $message .= "<li>...and " . (count($error_rows) - 10) . " more errors.</li>";
                            }
                            $message .= "</ul></div>";
                        }
                    } catch (Exception $e) {
                        $db->rollBack();
                        $message = "<div class='alert alert-error'>Failed to complete bulk upload. Database transaction rolled back. Error: " . htmlspecialchars($e->getMessage()) . "</div>";
                    }
                }
            } else {
                $message = "<div class='alert alert-error'>CSV file is empty or invalid.</div>";
            }
            fclose($handle);
        } else {
            $message = "<div class='alert alert-error'>Failed to open the uploaded file.</div>";
        }
    }
}

// Handle Delete Participant
if ($_SERVER['REQUEST_METHOD'] === 'POST' && ($_POST['action'] ?? '') === 'delete') {
    $del_id = (int)$_POST['delete_id'];
    // Ensure we're only deleting participants (not admins or trainers)
    $stmt = $db->prepare("SELECT username FROM users WHERE id = ? AND role = 'participant'");
    $stmt->execute([$del_id]);
    $del_user = $stmt->fetch();

    if ($del_user) {
        $stmt = $db->prepare("DELETE FROM users WHERE id = ? AND role = 'participant'");
        if ($stmt->execute([$del_id])) {
            $message = "<div class='alert alert-success'>Participant '" . htmlspecialchars($del_user['username']) . "' deleted.</div>";
        }
    } else {
        $message = "<div class='alert alert-error'>Participant not found or cannot be deleted.</div>";
    }
}

// Fetch all participants with profile details and subordinate count
$participants = $db->query("
    SELECT u.id, u.username, u.created_at, up.full_name, up.store_code, up.city, up.designation, up.department,
           (
               SELECT COUNT(*) 
               FROM user_profiles sub_up 
               JOIN users sub_u ON sub_up.user_id = sub_u.id 
               WHERE sub_u.role = 'participant'
                 AND (
                     (sub_up.reporting_manager_name = up.full_name AND up.full_name IS NOT NULL AND up.full_name != '')
                     OR (sub_up.reporting_manager_name = u.username COLLATE utf8mb4_unicode_ci)
                 )
           ) AS subordinate_count
    FROM users u 
    LEFT JOIN user_profiles up ON u.id = up.user_id 
    WHERE u.role = 'participant' 
    ORDER BY u.created_at DESC
")->fetchAll();

// Fetch all stores for the dropdown selection
$stores = $db->query("SELECT id, store_name, store_code, city FROM stores ORDER BY store_name ASC")->fetchAll();

// Fetch all designations for the dropdown selection
$designation_list = $db->query("SELECT id, designation_name FROM designations ORDER BY designation_name ASC")->fetchAll();

// Fetch all departments for the dropdown selection
$department_list = $db->query("SELECT id, department_name FROM departments ORDER BY department_name ASC")->fetchAll();

$page_title = 'Participants';

$current_page = 'participants';
require_once '../includes/header.php';
?>

<div class="page-section">
    <div class="page-header">
        <h2 class="page-title">Manage Participants</h2>
        <a href="dashboard.php" class="btn btn-sm btn-outline">← Dashboard</a>
    </div>

    <?php echo $message; ?>

    <div class="two-col-layout">
        <!-- Add Participant Form -->
        <style>
            .tab-container {
                margin-bottom: 16px;
            }
            .tabs-nav {
                display: flex;
                border-bottom: 1px solid var(--border-color, rgba(255,255,255,0.1));
                margin-bottom: 20px;
                gap: 8px;
            }
            .tab-btn {
                background: none;
                border: none;
                color: var(--text-light, #aaa);
                padding: 10px 16px;
                cursor: pointer;
                font-family: var(--font-heading), sans-serif;
                font-size: 0.95rem;
                font-weight: 500;
                position: relative;
                transition: color 0.2s ease;
            }
            .tab-btn:hover {
                color: var(--text-color, #fff);
            }
            .tab-btn.active {
                color: var(--secondary-color, #b1935e);
                font-weight: 600;
            }
            .tab-btn.active::after {
                content: '';
                position: absolute;
                bottom: -1px;
                left: 0;
                right: 0;
                height: 2px;
                background-color: var(--secondary-color, #b1935e);
                border-radius: 2px;
            }
            .tab-content {
                animation: fadeIn 0.3s ease;
            }
            @keyframes fadeIn {
                from { opacity: 0; transform: translateY(4px); }
                to { opacity: 1; transform: translateY(0); }
            }
            .upload-box {
                border: 2px dashed var(--border-color, rgba(255,255,255,0.1));
                border-radius: var(--radius-sm, 6px);
                padding: 30px 20px;
                text-align: center;
                cursor: pointer;
                transition: border-color 0.2s ease, background-color 0.2s ease;
                background: rgba(255, 255, 255, 0.02);
                margin-bottom: 20px;
            }
            .upload-box:hover {
                border-color: var(--secondary-color, #b1935e);
                background: rgba(255, 255, 255, 0.04);
            }
            .upload-box-icon {
                font-size: 2.2rem;
                margin-bottom: 10px;
                color: var(--text-light, #aaa);
            }
            .upload-box-text {
                font-size: 0.9rem;
                color: var(--text-light, #aaa);
                margin-bottom: 5px;
            }
            .upload-box-filename {
                font-size: 0.88rem;
                font-weight: 600;
                color: var(--secondary-color, #b1935e);
                display: none;
                margin-top: 10px;
                word-break: break-all;
            }
            .info-box {
                background: rgba(177, 147, 158, 0.05);
                border: 1px solid rgba(177, 147, 94, 0.15);
                border-radius: var(--radius-sm, 6px);
                padding: 16px;
                margin-bottom: 20px;
            }
            .info-box h4 {
                margin: 0 0 8px 0;
                color: var(--secondary-color, #b1935e);
                font-size: 0.92rem;
                font-weight: 600;
            }
        </style>

        <div class="panel-card form-panel" style="padding: 20px 24px;">
            <div class="tabs-nav">
                <button type="button" class="tab-btn active" data-tab="single">Add Single</button>
                <button type="button" class="tab-btn" data-tab="bulk">Bulk Upload</button>
            </div>

            <!-- Tab Content: Single Add -->
            <div class="tab-content" id="tab-single">
                <h3 style="margin-bottom: 15px;">Add New Participant</h3>
                <form method="POST" action="participants.php" style="margin-top: 15px;">
                    <input type="hidden" name="action" value="add">
                    <input type="hidden" name="csrf_token" value="<?php echo csrf_token(); ?>">

                    <div class="form-group">
                        <label>Username</label>
                        <input type="text" name="username" class="form-control" required minlength="3" placeholder="Enter username">
                    </div>

                    <div class="form-group">
                        <label>Password</label>
                        <input type="text" name="password" class="form-control" required minlength="4" placeholder="Enter password">
                        <small style="color: #666;">Enter password to share with the participant.</small>
                    </div>

                    <div class="form-group">
                        <label>Full Name</label>
                        <input type="text" name="full_name" class="form-control" required placeholder="Enter full name">
                    </div>

                    <div class="form-group">
                        <label>Mobile Number</label>
                        <input type="text" name="mobile_number" class="form-control" placeholder="Enter mobile number">
                    </div>

                    <div class="form-group">
                        <label>Email Id</label>
                        <input type="email" name="email_id" class="form-control" placeholder="Enter email address">
                    </div>

                    <div class="form-group">
                        <label for="store_code_select">Store Code</label>
                        <select name="store_code" id="store_code_select" class="form-control" required>
                            <option value="">-- Select Store --</option>
                            <?php foreach ($stores as $store): ?>
                                <option value="<?php echo htmlspecialchars($store['store_code']); ?>" data-city="<?php echo htmlspecialchars($store['city'] ?? ''); ?>">
                                    <?php echo htmlspecialchars($store['store_name'] . ' (' . $store['store_code'] . ')'); ?>
                                </option>
                            <?php endforeach; ?>
                        </select>
                    </div>

                    <div class="form-group">
                        <label for="city_input">City</label>
                        <input type="text" name="city" id="city_input" class="form-control" placeholder="City will be autofilled" readonly>
                    </div>

                    <div class="form-group">
                        <label for="designation_select">Designation</label>
                        <select name="designation" id="designation_select" class="form-control">
                            <option value="">-- Select Designation --</option>
                            <?php foreach ($designation_list as $desg): ?>
                                <option value="<?php echo htmlspecialchars($desg['designation_name']); ?>">
                                    <?php echo htmlspecialchars($desg['designation_name']); ?>
                                </option>
                            <?php endforeach; ?>
                        </select>
                    </div>

                    <div class="form-group">
                        <label for="department_select">Department</label>
                        <select name="department" id="department_select" class="form-control">
                            <option value="">-- Select Department --</option>
                            <?php foreach ($department_list as $dept): ?>
                                <option value="<?php echo htmlspecialchars($dept['department_name']); ?>">
                                    <?php echo htmlspecialchars($dept['department_name']); ?>
                                </option>
                            <?php endforeach; ?>
                        </select>
                    </div>

                    <div class="form-group">
                        <label>Reporting Manager Name</label>
                        <input type="text" name="reporting_manager_name" class="form-control" placeholder="Enter manager's name">
                    </div>

                    <div class="form-group">
                        <label>NSM/VP Name</label>
                        <input type="text" name="nsm_vp_name" class="form-control" placeholder="Enter NSM/VP name">
                    </div>

                    <button type="submit" class="btn">Create Participant</button>
                </form>
            </div>

            <!-- Tab Content: Bulk Upload -->
            <div class="tab-content" id="tab-bulk" style="display: none;">
                <div class="info-box">
                    <h4>Bulk Upload via CSV</h4>
                    <p style="font-size: 0.82rem; color: var(--text-light, #aaa); margin-bottom: 12px; line-height: 1.5;">
                        Register multiple participants simultaneously. Populate the details in the CSV template and upload below.
                    </p>
                    <a href="participants.php?action=download_template" class="btn btn-sm btn-outline" style="width: auto; display: inline-block;">
                        📥 Download CSV Template
                    </a>
                </div>
                
                <form method="POST" action="participants.php" enctype="multipart/form-data" style="margin-top: 15px;">
                    <input type="hidden" name="action" value="bulk_upload">
                    <input type="hidden" name="csrf_token" value="<?php echo csrf_token(); ?>">
                    
                    <div class="form-group">
                        <label>Select CSV File</label>
                        <div class="upload-box" onclick="document.getElementById('csv_file_input').click()">
                            <div class="upload-box-icon">📄</div>
                            <div class="upload-box-text">Click to browse or drop CSV file here</div>
                            <div class="upload-box-filename" id="csv_filename">No file chosen</div>
                            <input type="file" name="csv_file" id="csv_file_input" accept=".csv" required style="display:none;">
                        </div>
                    </div>
                    
                    <div class="info-box" style="background: rgba(255, 255, 255, 0.01); border-color: var(--border-color, rgba(255,255,255,0.1));">
                        <h4 style="color: var(--text-color, #fff); font-size: 0.85rem; margin-bottom: 5px;">Expected Columns:</h4>
                        <ul style="padding-left: 20px; font-size: 0.8rem; color: var(--text-light, #aaa); line-height: 1.6; margin: 0;">
                            <li><strong>username</strong> (Required, min 3 chars, unique)</li>
                            <li><strong>password</strong> (Required, min 4 chars)</li>
                            <li><strong>full_name</strong> (Recommended)</li>
                            <li><strong>mobile_number</strong>, <strong>email_id</strong></li>
                            <li><strong>store_code</strong> (Optional, matches Store Master)</li>
                            <li><strong>city</strong> (Autofilled from Store Master if empty)</li>
                            <li><strong>designation</strong> (Optional, matches Designation Master)</li>
                            <li><strong>department</strong> (Optional, matches Department Master)</li>
                            <li><strong>reporting_manager_name</strong>, <strong>nsm_vp_name</strong></li>
                        </ul>
                    </div>
                    
                    <button type="submit" class="btn">Upload and Register</button>
                </form>
            </div>
        </div>

        <!-- Participants List -->
        <div class="panel-card table-panel">
            <div style="display: flex; justify-content: space-between; align-items: center; margin-bottom: 15px; flex-wrap: wrap; gap: 10px;">
                <h3 style="margin: 0;">All Participants (<?php echo count($participants); ?>)</h3>
                <a href="participants.php?action=export" class="btn btn-sm btn-outline" style="width: auto; display: inline-flex; align-items: center; gap: 6px; padding: 6px 12px; font-size: 0.82rem;">
                    📥 Export CSV
                </a>
            </div>
            <div class="table-scroll">
                <table id="dataTable" class="data-table">
                    <thead>
                        <tr>
                            <th>ID</th>
                            <th>Username</th>
                            <th>Full Name</th>
                            <th>Store Code</th>
                            <th>City</th>
                            <th>Designation</th>
                            <th>Department</th>
                            <th>Created</th>
                            <?php if ($has_trainer_gemini): ?>
                            <th>AI Risk</th>
                            <?php endif; ?>
                            <th>Actions</th>
                        </tr>
                    </thead>
                    <tbody>
                        <?php foreach ($participants as $p): ?>
                            <tr>
                                <td>
                                    <?php echo $p['id']; ?>
                                </td>
                                <td style="font-weight: 500;">
                                    <?php echo htmlspecialchars($p['username']); ?>
                                </td>
                                <td>
                                    <?php echo htmlspecialchars($p['full_name'] ?? ''); ?>
                                </td>
                                <td>
                                    <?php echo htmlspecialchars($p['store_code'] ?? ''); ?>
                                </td>
                                <td>
                                    <?php echo htmlspecialchars($p['city'] ?? ''); ?>
                                </td>
                                <td>
                                    <?php echo htmlspecialchars($p['designation'] ?? 'N/A'); ?>
                                </td>
                                <td>
                                    <?php echo htmlspecialchars($p['department'] ?? 'N/A'); ?>
                                </td>
                                <td style="font-size: 0.85rem; color: #666;">
                                    <?php echo date('d M Y', strtotime($p['created_at'])); ?>
                                </td>
                                <?php if ($has_trainer_gemini): ?>
                                <td>
                                    <?php
                                    $risk_cached = $db->prepare("SELECT risk_level, reason FROM ai_risk_scores WHERE user_id = ? AND trainer_id = ? AND calculated_at > DATE_SUB(NOW(), INTERVAL 7 DAY)");
                                    $risk_cached->execute([$p['id'], $_SESSION['user_id']]);
                                    $risk = $risk_cached->fetch();
                                    $risk_styles = [
                                        'on_track'    => 'background:rgba(16, 185, 129, 0.15);color:#10b981;border:1px solid rgba(16, 185, 129, 0.3)',
                                        'needs_nudge' => 'background:rgba(245, 158, 11, 0.15);color:#f59e0b;border:1px solid rgba(245, 158, 11, 0.3)',
                                        'at_risk'     => 'background:rgba(239, 68, 68, 0.15);color:#ef4444;border:1px solid rgba(239, 68, 68, 0.3)',
                                    ];
                                    $risk_labels = ['on_track'=>'On Track','needs_nudge'=>'Needs Nudge','at_risk'=>'At Risk'];
                                    if ($risk):
                                        $style = $risk_styles[$risk['risk_level']] ?? '';
                                        $label = $risk_labels[$risk['risk_level']] ?? $risk['risk_level'];
                                    ?>
                                    <span style="<?= $style ?>;font-size:0.7rem;font-weight:600;padding:4px 10px;border-radius:20px;white-space:nowrap;display:inline-block;"
                                          title="<?= htmlspecialchars($risk['reason']) ?>">
                                        <?= $label ?>
                                    </span>
                                    <?php else: ?>
                                    <button onclick="scoreRisk(<?= $p['id'] ?>, this)"
                                        class="btn btn-sm btn-outline" style="font-size:0.68rem;padding:3px 8px;line-height:1;width:auto;">
                                        Score
                                    </button>
                                    <?php endif; ?>
                                </td>
                                <?php endif; ?>
                                <td>
                                    <button onclick="openTeamModal(<?= $p['id'] ?>)"
                                        class="btn btn-sm btn-outline" style="font-size:0.7rem;padding:4px 10px;margin-right:6px;width:auto;display:inline-block;vertical-align:middle;">
                                        👥 Team (<?= (int)$p['subordinate_count'] ?>)
                                    </button>
                                    <button onclick="openEditModal(<?= $p['id'] ?>)"
                                        class="btn btn-sm btn-outline" style="font-size:0.7rem;padding:4px 10px;margin-right:6px;width:auto;display:inline-block;vertical-align:middle;">
                                        ✏️ Edit
                                    </button>
                                    <?php if ($has_trainer_gemini): ?>
                                    <button onclick="nudgeParticipant(<?= $p['id'] ?>, '<?= htmlspecialchars($p['full_name'] ?: $p['username']) ?>')"
                                        class="btn btn-sm btn-outline" style="font-size:0.7rem;padding:4px 10px;margin-right:6px;width:auto;display:inline-block;vertical-align:middle;">
                                        ✨ Nudge
                                    </button>
                                    <?php endif; ?>
                                    <form method="POST" style="display:inline-block;vertical-align:middle;" onsubmit="return confirm('Delete this participant? This will also remove all their assignments and progress.');">
                                        <input type="hidden" name="action" value="delete">
                                        <input type="hidden" name="delete_id" value="<?php echo $p['id']; ?>">
                                        <input type="hidden" name="csrf_token" value="<?php echo csrf_token(); ?>">
                                        <button type="submit" class="link-danger" style="background:none;border:none;cursor:pointer;padding:0;font-size:0.9rem;">Delete</button>
                                    </form>
                                </td>
                        <?php endforeach; ?>
                    </tbody>
                </table>

            </div>
        </div>
    </div>
</div>

<script>
// Run vanilla JS tab toggling and autofill immediately or on DOMContentLoaded
document.addEventListener('DOMContentLoaded', function() {
    // Tab toggling logic
    var tabButtons = document.querySelectorAll('.tab-btn');
    var tabContents = document.querySelectorAll('.tab-content');
    
    tabButtons.forEach(function(btn) {
        btn.addEventListener('click', function() {
            var targetTab = btn.getAttribute('data-tab');
            
            // Toggle active state on buttons
            tabButtons.forEach(function(b) {
                b.classList.remove('active');
            });
            btn.classList.add('active');
            
            // Show target tab content, hide others
            tabContents.forEach(function(content) {
                if (content.id === 'tab-' + targetTab) {
                    content.style.display = 'block';
                } else {
                    content.style.display = 'none';
                }
            });
        });
    });

    // Update uploader layout with file name on change
    var fileInput = document.getElementById('csv_file_input');
    var fileNameSpan = document.getElementById('csv_filename');
    var uploadBoxText = document.querySelector('.upload-box-text');
    
    if (fileInput) {
        fileInput.addEventListener('change', function() {
            var file = fileInput.files[0];
            if (file) {
                if (fileNameSpan) {
                    fileNameSpan.textContent = file.name;
                    fileNameSpan.style.display = 'block';
                }
                if (uploadBoxText) uploadBoxText.textContent = 'Selected file:';
            } else {
                if (fileNameSpan) {
                    fileNameSpan.textContent = 'No file chosen';
                    fileNameSpan.style.display = 'none';
                }
                if (uploadBoxText) uploadBoxText.textContent = 'Click to browse or drop CSV file here';
            }
        });
    }

    // Handle store selection change to autofill city
    var storeSelect = document.getElementById('store_code_select');
    var cityInput = document.getElementById('city_input');
    if (storeSelect && cityInput) {
        storeSelect.addEventListener('change', function() {
            var selectedOpt = storeSelect.options[storeSelect.selectedIndex];
            var city = selectedOpt ? (selectedOpt.getAttribute('data-city') || '') : '';
            cityInput.value = city;
        });
    }

    // Handle edit store selection change to autofill city
    var editStoreSelect = document.getElementById('edit_store_code');
    var editCityInput = document.getElementById('edit_city');
    if (editStoreSelect && editCityInput) {
        editStoreSelect.addEventListener('change', function() {
            var selectedOpt = editStoreSelect.options[editStoreSelect.selectedIndex];
            var city = selectedOpt ? (selectedOpt.getAttribute('data-city') || '') : '';
            editCityInput.value = city;
        });
    }
});

// Run jQuery/DataTable initialization only after all scripts (including footer) are fully loaded
window.addEventListener('load', function() {
    if (typeof $ !== 'undefined' && $.fn.DataTable) {
        $('#dataTable').DataTable({
            "pageLength": 10,
            "lengthMenu": [5, 10, 25, 50],
            "ordering": true,
            "language": {
                "search": "Search Participants:"
            }
        });
    }
});
</script>

<!-- Team View modal -->
<div id="team-modal" style="display:none;position:fixed;inset:0;background:rgba(0,0,0,0.5);z-index:999;
     align-items:center;justify-content:center;padding:20px;backdrop-filter:blur(3px);">
    <div style="background:var(--surface, #ffffff);color:var(--text-color, #2b2b2b);border:1px solid var(--border-color, #e3ded8);
                border-radius:12px;padding:28px;max-width:600px;width:100%;
                max-height:85vh;overflow-y:auto;position:relative;box-shadow:var(--shadow-lg);">
        <h3 style="font-family:var(--font-heading);margin-bottom:6px;font-size:1.3rem;color:var(--secondary-color, #0d0d0d);">Team Managed by <span id="team-manager-name" style="color:var(--accent-color, #004e54); font-weight: 600;"></span></h3>
        <p style="font-size:0.8rem;color:var(--text-light, #6e7072);margin-bottom:18px;">
            List of participants who report to this manager.
        </p>
        
        <div id="team-list-container" style="margin-bottom: 20px; overflow-x: auto;">
            <!-- Render list here -->
        </div>
        
        <div style="display:flex;justify-content:flex-end;">
            <button onclick="closeTeamModal()" class="btn btn-sm btn-outline" style="width:auto;padding:10px 20px;">Close</button>
        </div>
    </div>
</div>

<!-- Edit Participant modal -->
<div id="edit-modal" style="display:none;position:fixed;inset:0;background:rgba(0,0,0,0.5);z-index:999;
     align-items:center;justify-content:center;padding:20px;backdrop-filter:blur(3px);">
    <div style="background:var(--surface, #ffffff);color:var(--text-color, #2b2b2b);border:1px solid var(--border-color, #e3ded8);
                border-radius:12px;padding:28px;max-width:550px;width:100%;
                max-height:85vh;overflow-y:auto;position:relative;box-shadow:var(--shadow-lg);">
        <h3 style="font-family:var(--font-heading);margin-bottom:6px;font-size:1.3rem;color:var(--secondary-color, #0d0d0d);">Edit Participant Details</h3>
        <p style="font-size:0.8rem;color:var(--text-light, #6e7072);margin-bottom:18px;">
            Update participant account and profile settings.
        </p>
        
        <form method="POST" action="participants.php" style="margin-top: 15px;">
            <input type="hidden" name="action" value="edit">
            <input type="hidden" id="edit_id" name="edit_id">
            <input type="hidden" name="csrf_token" value="<?php echo csrf_token(); ?>">

            <div class="form-group">
                <label>Username</label>
                <input type="text" id="edit_username" name="username" class="form-control" required minlength="3">
            </div>

            <div class="form-group">
                <label>Password (Optional)</label>
                <input type="text" name="password" class="form-control" placeholder="Leave blank to keep unchanged">
                <small style="color: #666;">Enter a new password if you wish to reset it.</small>
            </div>

            <div class="form-group">
                <label>Full Name</label>
                <input type="text" id="edit_full_name" name="full_name" class="form-control" required>
            </div>

            <div class="form-group">
                <label>Mobile Number</label>
                <input type="text" id="edit_mobile_number" name="mobile_number" class="form-control">
            </div>

            <div class="form-group">
                <label>Email Id</label>
                <input type="email" id="edit_email_id" name="email_id" class="form-control">
            </div>

            <div class="form-group">
                <label for="edit_store_code">Store Code</label>
                <select name="store_code" id="edit_store_code" class="form-control" required>
                    <option value="">-- Select Store --</option>
                    <?php foreach ($stores as $store): ?>
                        <option value="<?php echo htmlspecialchars($store['store_code']); ?>" data-city="<?php echo htmlspecialchars($store['city'] ?? ''); ?>">
                            <?php echo htmlspecialchars($store['store_name'] . ' (' . $store['store_code'] . ')'); ?>
                        </option>
                    <?php endforeach; ?>
                </select>
            </div>

            <div class="form-group">
                <label for="edit_city">City</label>
                <input type="text" name="city" id="edit_city" class="form-control" placeholder="City will be autofilled" readonly>
            </div>

            <div class="form-group">
                <label for="edit_designation">Designation</label>
                <select name="designation" id="edit_designation" class="form-control">
                    <option value="">-- Select Designation --</option>
                    <?php foreach ($designation_list as $desg): ?>
                        <option value="<?php echo htmlspecialchars($desg['designation_name']); ?>">
                            <?php echo htmlspecialchars($desg['designation_name']); ?>
                        </option>
                    <?php endforeach; ?>
                </select>
            </div>

            <div class="form-group">
                <label for="edit_department">Department</label>
                <select name="department" id="edit_department" class="form-control">
                    <option value="">-- Select Department --</option>
                    <?php foreach ($department_list as $dept): ?>
                        <option value="<?php echo htmlspecialchars($dept['department_name']); ?>">
                            <?php echo htmlspecialchars($dept['department_name']); ?>
                        </option>
                    <?php endforeach; ?>
                </select>
            </div>

            <div class="form-group">
                <label>Reporting Manager Name</label>
                <input type="text" id="edit_reporting_manager_name" name="reporting_manager_name" class="form-control">
            </div>

            <div class="form-group">
                <label>NSM/VP Name</label>
                <input type="text" id="edit_nsm_vp_name" name="nsm_vp_name" class="form-control">
            </div>

            <div style="display:flex;justify-content:flex-end;gap:12px;margin-top:20px;">
                <button type="button" onclick="closeEditModal()" class="btn btn-sm btn-outline" style="width:auto;padding:10px 20px;">Cancel</button>
                <button type="submit" class="btn btn-sm btn-accent" style="width:auto;padding:10px 20px;">Save Changes</button>
            </div>
        </form>
    </div>
</div>

<script>
function openTeamModal(userId) {
    var modal = document.getElementById('team-modal');
    var managerSpan = document.getElementById('team-manager-name');
    var container = document.getElementById('team-list-container');
    
    modal.style.display = 'flex';
    managerSpan.textContent = 'loading...';
    container.innerHTML = '<div style="text-align:center;padding:20px;color:var(--text-light, #aaa);">Loading team members...</div>';
    
    fetch('participants.php?action=get_team&user_id=' + userId)
        .then(function(r) { return r.json(); })
        .then(function(data) {
            if (data.error) {
                container.innerHTML = '<div class="alert alert-error">' + data.error + '</div>';
                return;
            }
            
            managerSpan.textContent = data.manager;
            
            if (data.team.length === 0) {
                container.innerHTML = '<div style="text-align:center;padding:30px 10px;color:var(--text-light, #aaa);background:rgba(255,255,255,0.02);border-radius:8px;">' +
                    'No participants report to this manager.</div>';
                return;
            }
            
            var html = '<table class="data-table" style="width:100%;border-collapse:collapse;margin-top:10px;">';
            html += '<thead><tr style="border-bottom:1px solid var(--border-color, #e3ded8);">';
            html += '<th style="text-align:left;padding:12px 10px;font-size:0.85rem;color:var(--text-light, #6e7072);font-weight:600;">Username</th>';
            html += '<th style="text-align:left;padding:12px 10px;font-size:0.85rem;color:var(--text-light, #6e7072);font-weight:600;">Full Name</th>';
            html += '<th style="text-align:left;padding:12px 10px;font-size:0.85rem;color:var(--text-light, #6e7072);font-weight:600;">Store Code</th>';
            html += '<th style="text-align:left;padding:12px 10px;font-size:0.85rem;color:var(--text-light, #6e7072);font-weight:600;">City</th>';
            html += '</tr></thead><tbody>';
            
            data.team.forEach(function(member) {
                html += '<tr style="border-bottom:1px solid var(--border-light, #edeae4);">';
                html += '<td style="padding:12px 10px;font-weight:500;color:var(--text-color, #2b2b2b);">' + escapeHtml(member.username) + '</td>';
                html += '<td style="padding:12px 10px;color:var(--text-color, #2b2b2b);">' + escapeHtml(member.full_name || 'N/A') + '</td>';
                html += '<td style="padding:12px 10px;color:var(--text-color, #2b2b2b);">' + escapeHtml(member.store_code || 'N/A') + '</td>';
                html += '<td style="padding:12px 10px;color:var(--text-color, #2b2b2b);">' + escapeHtml(member.city || 'N/A') + '</td>';
                html += '</tr>';
            });
            
            html += '</tbody></table>';
            container.innerHTML = html;
        })
        .catch(function() {
            container.innerHTML = '<div class="alert alert-error">Failed to load team data.</div>';
        });
}

function closeTeamModal() {
    document.getElementById('team-modal').style.display = 'none';
}

function openEditModal(userId) {
    var modal = document.getElementById('edit-modal');
    modal.style.display = 'flex';
    
    // Fetch details
    fetch('participants.php?action=get_participant&user_id=' + userId)
        .then(function(r) { return r.json(); })
        .then(function(data) {
            if (data.error) {
                alert(data.error);
                closeEditModal();
                return;
            }
            
            document.getElementById('edit_id').value = data.id;
            document.getElementById('edit_username').value = data.username || '';
            document.getElementById('edit_full_name').value = data.full_name || '';
            document.getElementById('edit_mobile_number').value = data.mobile_number || '';
            document.getElementById('edit_email_id').value = data.email_id || '';
            document.getElementById('edit_store_code').value = data.store_code || '';
            document.getElementById('edit_city').value = data.city || '';
            document.getElementById('edit_designation').value = data.designation || '';
            document.getElementById('edit_department').value = data.department || '';
            document.getElementById('edit_reporting_manager_name').value = data.reporting_manager_name || '';
            document.getElementById('edit_nsm_vp_name').value = data.nsm_vp_name || '';
        })
        .catch(function() {
            alert('Failed to fetch participant details.');
            closeEditModal();
        });
}

function closeEditModal() {
    document.getElementById('edit-modal').style.display = 'none';
}

function escapeHtml(text) {
    if (!text) return '';
    return text
        .replace(/&/g, "&amp;")
        .replace(/</g, "&lt;")
        .replace(/>/g, "&gt;")
        .replace(/"/g, "&quot;")
        .replace(/'/g, "&#039;");
}
</script>

<?php if ($has_trainer_gemini): ?>
<!-- Nudge preview modal -->
<div id="nudge-modal" style="display:none;position:fixed;inset:0;background:rgba(0,0,0,0.66);z-index:99999;
     align-items:center;justify-content:center;padding:20px;backdrop-filter:blur(5px);">
    <div style="background:var(--panel-bg, #1e1e2d);color:var(--text-color, #fff);border:1px solid var(--border-color, #333);
                border-radius:12px;padding:28px;max-width:560px;width:100%;
                max-height:85vh;overflow-y:auto;position:relative;box-shadow:0 10px 40px rgba(0,0,0,0.65);">
        <h3 style="font-family:var(--font-heading);margin-bottom:6px;font-size:1.3rem;">AI Nudge Email Preview</h3>
        <p style="font-size:0.8rem;color:var(--text-light, #aaa);margin-bottom:18px;">
            To: <span id="nudge-email-to" style="font-weight:600;color:var(--secondary-color, #4f46e5);"></span>
        </p>
        <textarea id="nudge-preview-text"
            style="background:var(--bg-card, #151521);border:1px solid var(--border-color, #333);
                   border-radius:8px;padding:18px;font-size:0.9rem;line-height:1.7;color:var(--text-color,#fff);
                   margin-bottom:20px;width:100%;height:220px;resize:vertical;font-family:inherit;box-sizing:border-box;outline:none;display:block;"></textarea>
        <div style="display:flex;gap:12px;flex-wrap:wrap;justify-content:flex-end;">
            <button onclick="closeNudge()" class="btn btn-sm btn-outline" style="width:auto;padding:10px 20px;">Cancel</button>
            <button onclick="sendNudge()" id="nudge-send-btn" class="btn btn-sm btn-accent" style="width:auto;padding:10px 20px;">
                Send Email
            </button>
        </div>
    </div>
</div>

<script>
var currentNudgePid = null;
function nudgeParticipant(pid, name) {
    currentNudgePid = pid;
    var modal = document.getElementById('nudge-modal');
    var preview = document.getElementById('nudge-preview-text');
    var emailTo = document.getElementById('nudge-email-to');
    modal.style.display = 'flex';
    preview.value = 'AI is writing a personalised message for ' + name + '…';
    emailTo.textContent = name;

    var fd = new FormData();
    fd.append('participant_id', pid);
    fd.append('action', 'preview');
    fd.append('csrf_token', '<?= csrf_token() ?>');

    fetch('ai_nudge_email.php', { method: 'POST', body: fd })
        .then(function(r){ return r.json(); })
        .then(function(data) {
            if (data.preview) {
                preview.value = data.preview;
                emailTo.textContent = data.name + (data.email ? ' <' + data.email + '>' : ' (no email set)');
            } else {
                preview.value = 'Error: ' + (data.error || 'Failed');
            }
        })
        .catch(function(){ preview.value = 'Failed to generate. Please try again.'; });
}
function sendNudge() {
    var btn = document.getElementById('nudge-send-btn');
    var preview = document.getElementById('nudge-preview-text');
    btn.disabled = true; btn.textContent = 'Sending…';
    var fd = new FormData();
    fd.append('participant_id', currentNudgePid);
    fd.append('action', 'send');
    fd.append('body', preview.value);
    fd.append('csrf_token', '<?= csrf_token() ?>');
    fetch('ai_nudge_email.php', { method: 'POST', body: fd })
        .then(function(r){ return r.json(); })
        .then(function(data) {
            btn.disabled = false; btn.textContent = 'Send Email';
            if (data.ok) {
                closeNudge();
                alert(data.msg || 'Sent!');
            } else {
                alert('Error: ' + (data.error || data.msg || 'Failed to send'));
            }
        })
        .catch(function(){
            btn.disabled = false; btn.textContent = 'Send Email';
            alert('Request failed. Please check network/SMTP settings.');
        });
}
function closeNudge() {
    document.getElementById('nudge-modal').style.display = 'none';
}
function scoreRisk(participantId, btn) {
    btn.disabled = true; btn.textContent = '…';
    var fd = new FormData();
    fd.append('participant_id', participantId);
    fd.append('csrf_token', '<?= csrf_token() ?>');
    fetch('ai_risk_score.php', { method: 'POST', body: fd })
        .then(function(r){ return r.json(); })
        .then(function(data) {
            location.reload(); // reload to show cached result
        })
        .catch(function(){ btn.disabled = false; btn.textContent = 'Score'; });
}
</script>
<?php endif; ?>

<?php require_once '../includes/footer.php'; ?>