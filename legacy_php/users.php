<?php
require_once '../config.php';
require_once '../database.php';

if (!isset($_SESSION['user_id']) || $_SESSION['user_role'] !== 'admin') {
    header("Location: ../login.php");
    exit;
}

// Verify CSRF
if ($_SERVER['REQUEST_METHOD'] === 'POST' && !csrf_verify()) {
    die('<div class="alert alert-error">Invalid request. Please go back and try again.</div>');
}

$db = Database::getInstance()->getConnection();
$message = '';

// Handle add user
if ($_SERVER['REQUEST_METHOD'] === 'POST' && isset($_POST['action']) && $_POST['action'] === 'add') {
    $username = trim($_POST['username']);
    $original_password = $_POST['password'];
    $password = password_hash($original_password, PASSWORD_DEFAULT);
    $role = $_POST['role'];

    try {
        $stmt = $db->prepare("INSERT INTO users (username, password, role) VALUES (?, ?, ?)");
        $stmt->execute([$username, $password, $role]);
        $message = "<div class='alert alert-success'>User added successfully.</div>";
    } catch (PDOException $e) {
        $message = "<div class='alert alert-error'>Error: Username may already exist.</div>";
    }
}

// Handle edit user
if ($_SERVER['REQUEST_METHOD'] === 'POST' && isset($_POST['action']) && $_POST['action'] === 'edit') {
    $user_id = (int)$_POST['user_id'];
    $username = trim($_POST['username']);
    $role = $_POST['role'];
    $password_raw = $_POST['password'];

    try {
        if (!empty($password_raw)) {
            $password_hash = password_hash($password_raw, PASSWORD_DEFAULT);
            $stmt = $db->prepare("UPDATE users SET username = ?, password = ?, role = ? WHERE id = ?");
            $stmt->execute([$username, $password_hash, $role, $user_id]);
        } else {
            $stmt = $db->prepare("UPDATE users SET username = ?, role = ? WHERE id = ?");
            $stmt->execute([$username, $role, $user_id]);
        }
        $message = "<div class='alert alert-success'>User updated successfully.</div>";
    } catch (PDOException $e) {
        $message = "<div class='alert alert-error'>Error: Username may already exist.</div>";
    }
}

// Handle delete
if ($_SERVER['REQUEST_METHOD'] === 'POST' && ($_POST['action'] ?? '') === 'delete') {
    $delete_id = (int)$_POST['delete_id'];
    if ($delete_id != $_SESSION['user_id']) { // prevent self delete
        $stmt = $db->prepare("DELETE FROM users WHERE id = ?");
        $stmt->execute([$delete_id]);
        $message = "<div class='alert alert-success'>User deleted successfully.</div>";
    }
}

// Fetch users
$users = $db->query("
    SELECT u.id, u.username, u.role, u.created_at, up.full_name 
    FROM users u 
    LEFT JOIN user_profiles up ON u.id = up.user_id 
    ORDER BY u.created_at DESC
")->fetchAll();

// Check if editing a user
$edit_user = null;
if (isset($_GET['action']) && $_GET['action'] === 'edit' && isset($_GET['id'])) {
    $edit_id = (int)$_GET['id'];
    $e_stmt = $db->prepare("
        SELECT u.id, u.username, u.role, up.full_name 
        FROM users u 
        LEFT JOIN user_profiles up ON u.id = up.user_id 
        WHERE u.id = ?
    ");
    $e_stmt->execute([$edit_id]);
    $edit_user = $e_stmt->fetch();
}

$current_page = 'users';
require_once '../includes/header.php';
?>

<div class="page-section">
    <div class="page-header">
        <div>
            <h2 class="page-title">Manage Users</h2>
            <p class="page-subtitle">Add, edit, delete users — or enter any portal as that user.</p>
        </div>
        <div style="display:flex;gap:10px;">
            <a href="recycle_bin.php" class="btn btn-sm btn-outline" style="width:auto;display:inline-flex;align-items:center;gap:6px;">
                <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><polyline points="3 6 5 6 21 6"/><path d="M19 6l-1 14H6L5 6"/><path d="M10 11v6M14 11v6"/><path d="M9 6V4h6v2"/></svg>
                Recycle Bin
            </a>
            <a href="dashboard.php" class="btn btn-sm btn-outline" style="width:auto;">← Dashboard</a>
        </div>
    </div>

    <?php echo $message; ?>

    <div class="two-col-layout">
        <!-- Add/Edit User Form -->
        <div class="panel-card form-panel">
            <h3><?php echo $edit_user ? 'Edit User: ' . htmlspecialchars($edit_user['username']) : 'Add New User'; ?></h3>
            <form method="POST" action="users.php<?php echo $edit_user ? '?action=edit&id=' . $edit_user['id'] : ''; ?>" style="margin-top: 15px;">
                <input type="hidden" name="action" value="<?php echo $edit_user ? 'edit' : 'add'; ?>">
                <input type="hidden" name="csrf_token" value="<?php echo csrf_token(); ?>">
                <?php if ($edit_user): ?>
                    <input type="hidden" name="user_id" value="<?php echo $edit_user['id']; ?>">
                <?php endif; ?>
                
                <div class="form-group">
                    <label>Username</label>
                    <input type="text" name="username" class="form-control" value="<?php echo $edit_user ? htmlspecialchars($edit_user['username']) : ''; ?>" required>
                </div>
                <div class="form-group">
                    <label>Password<?php echo $edit_user ? ' (leave blank to keep current)' : ''; ?></label>
                    <input type="password" name="password" class="form-control" <?php echo $edit_user ? '' : 'required'; ?>>
                </div>
                <div class="form-group">
                    <label>Role</label>
                    <select name="role" class="form-control" required>
                        <?php
                        $roles = ['participant', 'trainer', 'admin'];
                        $current_role = $edit_user ? $edit_user['role'] : 'participant';
                        foreach ($roles as $r) {
                            $selected = ($current_role === $r) ? 'selected' : '';
                            $label = ucfirst($r);
                            echo "<option value=\"$r\" $selected>$label</option>";
                        }
                        ?>
                    </select>
                </div>
                <div style="display: flex; gap: 10px; margin-top: 15px;">
                    <button type="submit" class="btn"><?php echo $edit_user ? 'Save Changes' : 'Add User'; ?></button>
                    <?php if ($edit_user): ?>
                        <a href="users.php" class="btn btn-outline" style="width: auto; text-align: center; line-height: 2.2;">Cancel</a>
                    <?php endif; ?>
                </div>
            </form>
        </div>

        <!-- User List -->
        <div class="panel-card table-panel">
            <div class="table-scroll">
                <table class="data-table">
                    <thead>
                        <tr>
                            <th>ID</th>
                            <th>Username</th>
                            <th>Name</th>
                            <th>Role</th>
                            <th>Created</th>
                            <th>Actions</th>
                        </tr>
                    </thead>
                    <tbody>
                        <?php foreach ($users as $u): ?>
                            <tr>
                                <td style="color:var(--text-muted);font-size:0.75rem;"><?php echo $u['id']; ?></td>
                                <td><strong><?php echo htmlspecialchars($u['username']); ?></strong></td>
                                <td style="font-size:0.85rem;color:var(--text-light);"><?php echo htmlspecialchars($u['full_name'] ?: '—'); ?></td>
                                <td>
                                    <span class="role-badge <?php echo htmlspecialchars($u['role']); ?>" style="font-size:0.65rem;padding:2px 8px;border-radius:12px;font-weight:600;text-transform:uppercase;letter-spacing:0.8px;">
                                        <?php echo ucfirst($u['role']); ?>
                                    </span>
                                </td>
                                <td style="font-size:0.78rem;color:var(--text-muted);"><?php echo date('d M Y', strtotime($u['created_at'])); ?></td>
                                <td>
                                    <div style="display:flex;gap:6px;align-items:center;flex-wrap:wrap;">
                                        <?php if ($u['role'] !== 'admin'): ?>
                                        <a href="impersonate.php?user_id=<?php echo $u['id']; ?>"
                                           class="btn btn-sm"
                                           style="width:auto;background:linear-gradient(135deg,#7c3aed,#6d28d9);border-color:#7c3aed;font-size:0.7rem;padding:4px 10px;"
                                           title="Enter portal as this user"
                                           onclick="return confirm('Enter the portal as <?php echo htmlspecialchars(addslashes($u['username'])); ?>?');">
                                            👁 Enter As
                                        </a>
                                        <?php endif; ?>
                                        <a href="users.php?action=edit&id=<?php echo $u['id']; ?>" class="btn btn-sm btn-outline" style="width:auto;font-size:0.7rem;padding:4px 10px;">Edit</a>
                                        <?php if ($u['id'] != $_SESSION['user_id']): ?>
                                        <form method="POST" style="display:inline"
                                              onsubmit="return confirm('Delete this user? Their content stays in the portal.')">
                                            <input type="hidden" name="action" value="delete">
                                            <input type="hidden" name="delete_id" value="<?php echo $u['id']; ?>">
                                            <input type="hidden" name="csrf_token" value="<?php echo csrf_token(); ?>">
                                            <button type="submit" class="btn btn-sm btn-danger" style="width:auto;font-size:0.7rem;padding:4px 10px;">Delete</button>
                                        </form>
                                        <?php endif; ?>
                                    </div>
                                </td>
                            </tr>
                        <?php endforeach; ?>
                    </tbody>
                </table>
            </div>
        </div>
    </div>
</div>

<?php require_once '../includes/footer.php'; ?>