<?php
require_once '../config.php';
require_once '../database.php';

if (!isset($_SESSION['user_id']) || $_SESSION['user_role'] !== 'admin') {
    header("Location: ../login.php");
    exit;
}

$db  = Database::getInstance()->getConnection();
$msg = '';

// ── RESTORE ACTION ──────────────────────────────────────────────────────────
if ($_SERVER['REQUEST_METHOD'] === 'POST' && isset($_POST['action']) && $_POST['action'] === 'restore') {
    if (!csrf_verify()) die('<div class="alert alert-error">Invalid request.</div>');
    $type = $_POST['type'] ?? '';
    $id   = (int)($_POST['id'] ?? 0);
    $map  = ['course' => 'courses', 'module' => 'modules', 'chapter' => 'chapters', 'quiz' => 'quizzes', 'question' => 'questions'];
    if ($id && isset($map[$type])) {
        $tbl  = $map[$type];
        $stmt = $db->prepare("UPDATE `$tbl` SET deleted_at = NULL WHERE id = ?");
        $stmt->execute([$id]);
        $msg = "<div class='alert alert-success'>✅ Restored successfully.</div>";
    }
}

// ── PERMANENT DELETE ACTION ──────────────────────────────────────────────────
if ($_SERVER['REQUEST_METHOD'] === 'POST' && isset($_POST['action']) && $_POST['action'] === 'purge') {
    if (!csrf_verify()) die('<div class="alert alert-error">Invalid request.</div>');
    $type = $_POST['type'] ?? '';
    $id   = (int)($_POST['id'] ?? 0);
    $map  = ['course' => 'courses', 'module' => 'modules', 'chapter' => 'chapters', 'quiz' => 'quizzes', 'question' => 'questions'];
    if ($id && isset($map[$type])) {
        $tbl  = $map[$type];
        $stmt = $db->prepare("DELETE FROM `$tbl` WHERE id = ? AND deleted_at IS NOT NULL");
        $stmt->execute([$id]);
        $msg = "<div class='alert alert-warning'>🗑 Permanently deleted.</div>";
    }
}

// ── BULK PURGE ALL ────────────────────────────────────────────────────────────
if ($_SERVER['REQUEST_METHOD'] === 'POST' && isset($_POST['action']) && $_POST['action'] === 'purge_all') {
    if (!csrf_verify()) die('<div class="alert alert-error">Invalid request.</div>');
    foreach (['courses', 'modules', 'chapters', 'quizzes', 'questions'] as $tbl) {
        $db->exec("DELETE FROM `$tbl` WHERE deleted_at IS NOT NULL");
    }
    $msg = "<div class='alert alert-warning'>🗑 All items permanently purged from recycle bin.</div>";
}

// ── FETCH DELETED ITEMS ──────────────────────────────────────────────────────
$deleted_courses = $db->query("
    SELECT c.id, c.title, c.deleted_at, u.username AS trainer
    FROM courses c
    LEFT JOIN users u ON c.created_by = u.id
    WHERE c.deleted_at IS NOT NULL
    ORDER BY c.deleted_at DESC
")->fetchAll();

$deleted_modules = $db->query("
    SELECT m.id, m.title, m.deleted_at, c.title AS course_title, u.username AS trainer
    FROM modules m
    LEFT JOIN courses c ON m.course_id = c.id
    LEFT JOIN users u ON c.created_by = u.id
    WHERE m.deleted_at IS NOT NULL
    ORDER BY m.deleted_at DESC
")->fetchAll();

$deleted_chapters = $db->query("
    SELECT ch.id, ch.title, ch.deleted_at, ch.content_type, m.title AS module_title, c.title AS course_title, u.username AS trainer
    FROM chapters ch
    LEFT JOIN modules m ON ch.module_id = m.id
    LEFT JOIN courses c ON m.course_id = c.id
    LEFT JOIN users u ON c.created_by = u.id
    WHERE ch.deleted_at IS NOT NULL
    ORDER BY ch.deleted_at DESC
")->fetchAll();

$deleted_quizzes = $db->query("
    SELECT q.id, q.title, q.deleted_at, u.username AS trainer
    FROM quizzes q
    LEFT JOIN users u ON q.created_by = u.id
    WHERE q.deleted_at IS NOT NULL
    ORDER BY q.deleted_at DESC
")->fetchAll();

$deleted_questions = $db->query("
    SELECT qn.id, LEFT(qn.text, 80) AS title, qn.deleted_at, qz.title AS quiz_title, u.username AS trainer
    FROM questions qn
    LEFT JOIN quizzes qz ON qn.quiz_id = qz.id
    LEFT JOIN users u ON qz.created_by = u.id
    WHERE qn.deleted_at IS NOT NULL
    ORDER BY qn.deleted_at DESC
")->fetchAll();

$total_deleted = count($deleted_courses) + count($deleted_modules) + count($deleted_chapters) + count($deleted_quizzes) + count($deleted_questions);

$page_title   = 'Recycle Bin';
$current_page = 'recycle_bin';
require_once '../includes/header.php';
?>

<div class="page-section">
    <div class="page-header">
        <div>
            <h2 class="page-title">🗑 Recycle Bin</h2>
            <p class="page-subtitle">All trainer-deleted content lives here. Restore or permanently purge.</p>
        </div>
        <div style="display:flex;gap:10px;align-items:center;">
            <?php if ($total_deleted > 0): ?>
            <form method="POST" onsubmit="return confirm('Permanently delete ALL <?php echo $total_deleted; ?> items? This cannot be undone.');">
                <input type="hidden" name="action" value="purge_all">
                <input type="hidden" name="csrf_token" value="<?php echo csrf_token(); ?>">
                <button class="btn btn-danger btn-sm" style="width:auto;">🗑 Purge All (<?php echo $total_deleted; ?>)</button>
            </form>
            <?php endif; ?>
            <a href="dashboard.php" class="btn btn-sm btn-outline" style="width:auto;">← Dashboard</a>
        </div>
    </div>

    <?php echo $msg; ?>

    <?php if ($total_deleted === 0): ?>
    <div class="panel-card" style="text-align:center;padding:60px 20px;">
        <div style="font-size:3rem;margin-bottom:16px;">✨</div>
        <h3 style="font-weight:600;margin-bottom:8px;">Recycle Bin is Empty</h3>
        <p style="color:var(--text-light);">No deleted content found. All data is intact.</p>
    </div>
    <?php else: ?>

    <?php
    // Helper to render a section
    function rb_section(string $icon, string $label, string $type, array $rows, PDO $db, $csrf): void {
        if (empty($rows)) return;
        ?>
        <div class="panel-card" style="margin-bottom:24px;">
            <h3 style="font-size:1rem;font-weight:600;margin-bottom:16px;display:flex;align-items:center;gap:8px;">
                <?php echo $icon; ?> <?php echo $label; ?>
                <span style="background:rgba(239,68,68,0.1);color:#dc2626;padding:2px 8px;border-radius:20px;font-size:0.68rem;font-weight:600;margin-left:4px;"><?php echo count($rows); ?></span>
            </h3>
            <div class="table-scroll">
                <table class="data-table">
                    <thead>
                        <tr>
                            <th>ID</th>
                            <th>Title / Content</th>
                            <th>Trainer</th>
                            <?php if ($type === 'module'): ?><th>Course</th><?php endif; ?>
                            <?php if ($type === 'chapter'): ?><th>Module → Course</th><?php endif; ?>
                            <?php if ($type === 'question'): ?><th>Quiz</th><?php endif; ?>
                            <th>Deleted</th>
                            <th>Actions</th>
                        </tr>
                    </thead>
                    <tbody>
                        <?php foreach ($rows as $row): ?>
                        <tr>
                            <td style="color:var(--text-muted);font-size:0.75rem;"><?php echo $row['id']; ?></td>
                            <td>
                                <strong><?php echo htmlspecialchars($row['title']); ?></strong>
                                <?php if ($type === 'chapter' && !empty($row['content_type'])): ?>
                                <span style="font-size:0.68rem;background:var(--accent-pale);color:var(--accent-dark);padding:1px 6px;border-radius:10px;margin-left:6px;"><?php echo htmlspecialchars($row['content_type']); ?></span>
                                <?php endif; ?>
                            </td>
                            <td style="font-size:0.82rem;color:var(--text-light);"><?php echo htmlspecialchars($row['trainer'] ?? '—'); ?></td>
                            <?php if ($type === 'module'): ?>
                            <td style="font-size:0.82rem;color:var(--text-light);"><?php echo htmlspecialchars($row['course_title'] ?? '—'); ?></td>
                            <?php endif; ?>
                            <?php if ($type === 'chapter'): ?>
                            <td style="font-size:0.82rem;color:var(--text-light);"><?php echo htmlspecialchars($row['module_title'] ?? '—'); ?> → <?php echo htmlspecialchars($row['course_title'] ?? '—'); ?></td>
                            <?php endif; ?>
                            <?php if ($type === 'question'): ?>
                            <td style="font-size:0.82rem;color:var(--text-light);"><?php echo htmlspecialchars($row['quiz_title'] ?? '—'); ?></td>
                            <?php endif; ?>
                            <td style="font-size:0.78rem;color:var(--text-muted);white-space:nowrap;"><?php echo date('d M Y, H:i', strtotime($row['deleted_at'])); ?></td>
                            <td>
                                <div style="display:flex;gap:6px;align-items:center;">
                                    <form method="POST" style="display:inline;">
                                        <input type="hidden" name="action" value="restore">
                                        <input type="hidden" name="type" value="<?php echo $type; ?>">
                                        <input type="hidden" name="id" value="<?php echo $row['id']; ?>">
                                        <input type="hidden" name="csrf_token" value="<?php echo $csrf; ?>">
                                        <button class="btn btn-accent btn-sm" style="width:auto;padding:4px 10px;font-size:0.72rem;" title="Restore">↩ Restore</button>
                                    </form>
                                    <form method="POST" style="display:inline;" onsubmit="return confirm('Permanently delete this? Cannot be undone.');">
                                        <input type="hidden" name="action" value="purge">
                                        <input type="hidden" name="type" value="<?php echo $type; ?>">
                                        <input type="hidden" name="id" value="<?php echo $row['id']; ?>">
                                        <input type="hidden" name="csrf_token" value="<?php echo $csrf; ?>">
                                        <button class="btn btn-danger btn-sm" style="width:auto;padding:4px 10px;font-size:0.72rem;" title="Permanently Delete">🗑</button>
                                    </form>
                                </div>
                            </td>
                        </tr>
                        <?php endforeach; ?>
                    </tbody>
                </table>
            </div>
        </div>
    <?php
    }

    $csrf_tok = csrf_token();
    rb_section('📚', 'Deleted Courses',   'course',   $deleted_courses,   $db, $csrf_tok);
    rb_section('📁', 'Deleted Modules',   'module',   $deleted_modules,   $db, $csrf_tok);
    rb_section('📄', 'Deleted Chapters',  'chapter',  $deleted_chapters,  $db, $csrf_tok);
    rb_section('❓', 'Deleted Quizzes',   'quiz',     $deleted_quizzes,   $db, $csrf_tok);
    rb_section('💬', 'Deleted Questions', 'question', $deleted_questions, $db, $csrf_tok);
    ?>

    <?php endif; ?>
</div>

<?php require_once '../includes/footer.php'; ?>
