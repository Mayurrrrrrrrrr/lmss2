<?php
/**
 * Shared Designations Management UI and Controller
 * This file is included by admin/designations.php and trainer/designations.php.
 * The variables $db and $role_dir must be defined before including this file.
 */

if (!isset($db) || !isset($role_dir)) {
    die('Required configuration missing.');
}

$message = '';

// Handle Add Designation
if ($_SERVER['REQUEST_METHOD'] === 'POST' && isset($_POST['action']) && $_POST['action'] === 'add') {
    if (!csrf_verify()) {
        die('<div class="alert alert-error">Invalid request. Please go back and try again.</div>');
    }

    $designation_name = trim($_POST['designation_name'] ?? '');

    if (empty($designation_name)) {
        $message = '<div class="alert alert-error">Designation Name is required.</div>';
    } else {
        // Check uniqueness of designation_name
        $check_stmt = $db->prepare("SELECT id FROM designations WHERE designation_name = ?");
        $check_stmt->execute([$designation_name]);
        if ($check_stmt->fetch()) {
            $message = '<div class="alert alert-error">Designation <strong>' . htmlspecialchars($designation_name) . '</strong> already exists.</div>';
        } else {
            try {
                $stmt = $db->prepare("INSERT INTO designations (designation_name) VALUES (?)");
                if ($stmt->execute([$designation_name])) {
                    $message = '<div class="alert alert-success">Designation <strong>' . htmlspecialchars($designation_name) . '</strong> successfully added.</div>';
                }
            } catch (Exception $e) {
                $message = '<div class="alert alert-error">Error saving designation: ' . htmlspecialchars($e->getMessage()) . '</div>';
            }
        }
    }
}

// Handle Delete Designation
if ($_SERVER['REQUEST_METHOD'] === 'POST' && isset($_POST['action']) && $_POST['action'] === 'delete') {
    if (!csrf_verify()) {
        die('<div class="alert alert-error">Invalid request. Please go back and try again.</div>');
    }

    $delete_id = (int)($_POST['delete_id'] ?? 0);

    // Verify if designation exists
    $stmt = $db->prepare("SELECT designation_name FROM designations WHERE id = ?");
    $stmt->execute([$delete_id]);
    $designation = $stmt->fetch();

    if ($designation) {
        $name = $designation['designation_name'];

        // Prevent deletion if the designation is currently assigned to any participants/profiles
        $check_stmt = $db->prepare("SELECT COUNT(*) FROM user_profiles WHERE designation = ?");
        $check_stmt->execute([$name]);
        $associated_count = $check_stmt->fetchColumn();

        if ($associated_count > 0) {
            $message = '<div class="alert alert-error">Cannot delete designation <strong>' . htmlspecialchars($name) . '</strong> because it is currently assigned to ' . $associated_count . ' participant profile(s). Reassign them before deleting.</div>';
        } else {
            try {
                $del_stmt = $db->prepare("DELETE FROM designations WHERE id = ?");
                if ($del_stmt->execute([$delete_id])) {
                    $message = '<div class="alert alert-success">Designation <strong>' . htmlspecialchars($name) . '</strong> deleted successfully.</div>';
                }
            } catch (Exception $e) {
                $message = '<div class="alert alert-error">Error deleting designation: ' . htmlspecialchars($e->getMessage()) . '</div>';
            }
        }
    } else {
        $message = '<div class="alert alert-error">Designation not found.</div>';
    }
}

// Fetch all designations
$designations = $db->query("SELECT * FROM designations ORDER BY designation_name ASC")->fetchAll();
?>

<div class="page-section">
    <div class="page-header">
        <h2 class="page-title">Designation Master Management</h2>
        <a href="dashboard.php" class="btn btn-sm btn-outline">← Dashboard</a>
    </div>

    <?php echo $message; ?>

    <div class="two-col-layout" style="margin-top: 20px;">
        <!-- Add Designation Form -->
        <div class="panel-card form-panel">
            <h3>Add New Designation</h3>
            <form method="POST" action="designations.php" style="margin-top: 15px;">
                <input type="hidden" name="action" value="add">
                <input type="hidden" name="csrf_token" value="<?php echo csrf_token(); ?>">

                <div class="form-group" style="margin-bottom: 20px;">
                    <label for="designation_name">Designation Name</label>
                    <input type="text" id="designation_name" name="designation_name" class="form-control" required placeholder="e.g. Sales Executive">
                </div>

                <button type="submit" class="btn">Create Designation</button>
            </form>
        </div>

        <!-- Designations List -->
        <div class="panel-card table-panel">
            <h3 style="margin-bottom: 15px;">All Registered Designations (<?php echo count($designations); ?>)</h3>
            <div class="table-scroll">
                <table class="data-table datatable">
                    <thead>
                        <tr>
                            <th>Designation Name</th>
                            <th>Actions</th>
                        </tr>
                    </thead>
                    <tbody>
                        <?php foreach ($designations as $d): ?>
                            <tr>
                                <td style="font-weight: 500;">
                                    <?php echo htmlspecialchars($d['designation_name']); ?>
                                </td>
                                <td>
                                    <form method="POST" action="designations.php" style="display:inline" onsubmit="return confirm('Delete this designation? This action cannot be undone.');">
                                        <input type="hidden" name="action" value="delete">
                                        <input type="hidden" name="delete_id" value="<?php echo $d['id']; ?>">
                                        <input type="hidden" name="csrf_token" value="<?php echo csrf_token(); ?>">
                                        <button type="submit" class="link-danger" style="background:none;border:none;cursor:pointer;padding:0;font-size:0.9rem;color: #b91c1c;">
                                            Delete
                                        </button>
                                    </form>
                                </td>
                            </tr>
                        <?php endforeach; ?>
                    </tbody>
                </table>
            </div>
        </div>
    </div>
</div>
