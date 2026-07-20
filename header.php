<?php
// Compute avatar initials from username
$_av_name = $_SESSION['username'] ?? 'U';
$_av_parts = explode(' ', trim($_av_name));
$_av_initials = strtoupper(mb_substr($_av_parts[0], 0, 1));
if (count($_av_parts) > 1) {
    $_av_initials .= strtoupper(mb_substr(end($_av_parts), 0, 1));
}
$_av_role = $_SESSION['user_role'] ?? 'participant';
$_av_role_label = ucfirst($_av_role);
?>
<!DOCTYPE html>
<html lang="en">

<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title><?php echo isset($page_title) ? htmlspecialchars($page_title) . ' — Firefly LMS' : 'Firefly LMS Portal'; ?></title>

    <!-- Favicon -->
    <link rel="icon" type="image/png" sizes="192x192" href="<?php echo BASE_URL; ?>/assets/icons/firefly-icon.png">
    <link rel="shortcut icon" href="<?php echo BASE_URL; ?>/assets/icons/firefly-icon.png">
    <link rel="apple-touch-icon" href="<?php echo BASE_URL; ?>/assets/icons/firefly-logo.png">

    <!-- Fonts: Inter -->
    <link rel="preconnect" href="https://fonts.googleapis.com">
    <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
    <link href="https://fonts.googleapis.com/css2?family=Inter:wght@300;400;500;600;700&display=swap" rel="stylesheet">

    <!-- Stylesheets -->
    <link rel="stylesheet" href="<?php echo BASE_URL; ?>/assets/css/style.css">
    <link rel="stylesheet" href="https://cdn.datatables.net/1.13.7/css/jquery.dataTables.min.css">
    <script src="https://code.jquery.com/jquery-3.7.1.min.js"></script>
    <script src="https://cdn.datatables.net/1.13.7/js/jquery.dataTables.min.js"></script>

    <!-- PWA -->
    <link rel="manifest" href="<?php echo BASE_URL; ?>/manifest.json">
    <meta name="theme-color" content="#0f172a">
    <meta name="apple-mobile-web-app-capable" content="yes">
    <meta name="apple-mobile-web-app-status-bar-style" content="black-translucent">
    <meta name="apple-mobile-web-app-title" content="Firefly LMS">

    <!-- Open Graph -->
    <meta property="og:title" content="Firefly LMS">
    <meta property="og:description" content="Firefly Diamonds Internal Learning Management System">
    <meta property="og:image" content="<?php echo BASE_URL; ?>/assets/icons/firefly-logo.png">
</head>

<body
    data-page="<?= htmlspecialchars($current_page ?? 'dashboard') ?>"
    data-item-id="<?= htmlspecialchars((string)($active_item_id ?? '')) ?>"
    data-item-label="<?= htmlspecialchars($active_item_label ?? '') ?>"
>
<?php if (isset($_SESSION['user_id'])): ?>
    <!-- DASHBOARD LAYOUT -->
    <header class="top-bar">
        <div class="top-bar-left">
            <button class="hamburger" onclick="toggleSidebar()" aria-label="Toggle sidebar">
                <span></span><span></span><span></span>
            </button>
            <div class="logo">
                <a href="<?php echo BASE_URL; ?>" style="display:flex;align-items:center;gap:9px;text-decoration:none;">
                    <img src="<?php echo BASE_URL; ?>/assets/icons/firefly-icon.png"
                         alt="Firefly LMS"
                         class="logo-img">
                    <span class="logo-text">Firefly LMS</span>
                </a>
            </div>
        </div>

        <div class="top-bar-center">
            <?php if (isset($page_title)): ?>
            <div class="top-bar-breadcrumb">
                <span class="bc-current"><?php echo htmlspecialchars($page_title); ?></span>
            </div>
            <?php endif; ?>
        </div>

        <div class="top-bar-right">
            <span class="top-bar-role-badge <?php echo htmlspecialchars($_av_role); ?>">
                <?php echo $_av_role_label; ?>
            </span>
            <span class="top-bar-username">
                <strong><?php echo htmlspecialchars($_SESSION['username']); ?></strong>
            </span>
            <div class="user-avatar" title="<?php echo htmlspecialchars($_SESSION['username']); ?>">
                <?php echo htmlspecialchars($_av_initials); ?>
            </div>
            <a href="<?php echo BASE_URL; ?>/logout.php" class="top-bar-logout" title="Sign out">
                <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
                    <path d="M9 21H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h4"/>
                    <polyline points="16 17 21 12 16 7"/>
                    <line x1="21" y1="12" x2="9" y2="12"/>
                </svg>
                Sign out
            </a>
        </div>
    </header>

    <?php if (isset($_SESSION['admin_origin'])): ?>
    <!-- IMPERSONATION BANNER -->
    <div id="impersonation-banner" style="
        background: linear-gradient(90deg, #92400e, #b45309);
        color: #fff;
        padding: 9px 20px;
        display: flex;
        align-items: center;
        justify-content: space-between;
        gap: 12px;
        font-size: 0.8rem;
        font-weight: 500;
        position: sticky;
        top: 60px;
        z-index: 98;
        box-shadow: 0 2px 8px rgba(180,83,9,0.35);
        border-bottom: 2px solid rgba(255,255,255,0.15);
    ">
        <div style="display:flex;align-items:center;gap:10px;">
            <span style="font-size:1.1rem;">&#128065;</span>
            <span>
                <strong>Admin View:</strong>
                You are browsing as
                <strong style="background:rgba(255,255,255,0.15);padding:1px 7px;border-radius:4px;">
                    <?php echo htmlspecialchars($_SESSION['username']); ?>
                </strong>
                <span style="opacity:0.75;margin-left:4px;">(<?php echo ucfirst($_SESSION['user_role']); ?>)</span>
            </span>
        </div>
        <a href="<?php echo BASE_URL; ?>/admin/impersonate_exit.php"
           style="background:#fff;color:#92400e;padding:5px 14px;border-radius:6px;font-weight:700;font-size:0.76rem;text-decoration:none;white-space:nowrap;flex-shrink:0;box-shadow:0 1px 4px rgba(0,0,0,0.15);"
           title="Return to your Admin session">
            &#8592; Exit &amp; Return to Admin
        </a>
    </div>
    <?php endif; ?>

    <div class="sidebar-overlay" onclick="toggleSidebar()"></div>

    <?php if (isset($_SESSION['user_id'])): ?>
    <div id="pwa-install-banner" class="pwa-banner">
        <span>📱 Add Firefly LMS to your home screen for faster access</span>
        <div style="display:flex;gap:8px;flex-shrink:0;align-items:center;">
            <button onclick="installPWA()" class="btn btn-accent btn-sm" style="width:auto;">Install App</button>
            <button onclick="document.getElementById('pwa-install-banner').classList.remove('show')"
                style="background:none;border:none;color:rgba(255,255,255,0.5);cursor:pointer;font-size:1rem;padding:0 5px;">✕</button>
        </div>
    </div>
    <?php endif; ?>

    <div class="dashboard-layout">
        <?php require_once __DIR__ . '/sidebar.php'; ?>
        <div class="main-content">
            <?php if (!empty($_SESSION['flash_error'])): ?>
            <div class="alert alert-error" style="margin-bottom:20px;">
                <?= htmlspecialchars($_SESSION['flash_error']) ?>
            </div>
            <?php unset($_SESSION['flash_error']); endif; ?>

            <?php if (!empty($_SESSION['flash_success'])): ?>
            <div class="alert alert-success" style="margin-bottom:20px;">
                <?= htmlspecialchars($_SESSION['flash_success']) ?>
            </div>
            <?php unset($_SESSION['flash_success']); endif; ?>
<?php else: ?>
    <!-- SIMPLE LAYOUT (login, etc.) -->
    <main class="container">
<?php endif; ?>

<?php
/**
 * Show a friendly error page and stop execution.
 */
function lms_error(string $message, string $back_url = '', string $back_label = 'Go Back'): never {
    echo '<div style="max-width:480px;margin:60px auto;text-align:center;">';
    echo '<div class="panel-card" style="padding:40px 28px;">';
    echo '<div style="font-size:3rem;margin-bottom:16px;">⚠️</div>';
    echo '<h2 style="font-size:1.3rem;margin-bottom:10px;color:var(--secondary-color);">Something went wrong</h2>';
    echo '<p style="color:var(--text-light);margin-bottom:24px;line-height:1.6;">' . htmlspecialchars($message) . '</p>';
    if ($back_url) {
        echo '<a href="' . htmlspecialchars($back_url) . '" class="btn btn-sm btn-outline" style="width:auto;">';
        echo '← ' . htmlspecialchars($back_label) . '</a>';
    }
    echo '</div></div>';
    require_once __DIR__ . '/footer.php';
    exit;
}
?>
