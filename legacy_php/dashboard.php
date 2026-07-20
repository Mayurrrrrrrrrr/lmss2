<?php
require_once '../config.php';
require_once '../database.php';

if (!isset($_SESSION['user_id']) || $_SESSION['user_role'] !== 'admin') {
    header("Location: ../login.php");
    exit;
}

$db = Database::getInstance()->getConnection();

// Fetch statistics
$total_users = $db->query("SELECT COUNT(*) FROM users")->fetchColumn();
$total_trainers = $db->query("SELECT COUNT(*) FROM users WHERE role = 'trainer'")->fetchColumn();
$total_participants = $db->query("SELECT COUNT(*) FROM users WHERE role = 'participant'")->fetchColumn();
$total_courses = $db->query("SELECT COUNT(*) FROM courses")->fetchColumn();
$total_pages = $db->query("SELECT COUNT(*) FROM static_pages")->fetchColumn();

// Fetch weekly added counts (velocity)
$new_users = $db->query("SELECT COUNT(*) FROM users WHERE created_at > DATE_SUB(NOW(), INTERVAL 7 DAY)")->fetchColumn();
$new_trainers = $db->query("SELECT COUNT(*) FROM users WHERE role = 'trainer' AND created_at > DATE_SUB(NOW(), INTERVAL 7 DAY)")->fetchColumn();
$new_participants = $db->query("SELECT COUNT(*) FROM users WHERE role = 'participant' AND created_at > DATE_SUB(NOW(), INTERVAL 7 DAY)")->fetchColumn();
$new_courses = $db->query("SELECT COUNT(*) FROM courses WHERE created_at > DATE_SUB(NOW(), INTERVAL 7 DAY)")->fetchColumn();
$new_pages = $db->query("SELECT COUNT(*) FROM static_pages WHERE created_at > DATE_SUB(NOW(), INTERVAL 7 DAY)")->fetchColumn();

// Fetch recent static pages
$pages = $db->query("SELECT id, title, url_slug, created_at FROM static_pages ORDER BY created_at DESC LIMIT 6")->fetchAll();

// Fetch recent logins for Activity Feed
$recent_logins = $db->query("
    SELECT ll.login_time, u.username, u.role
    FROM login_logs ll
    JOIN users u ON ll.user_id = u.id
    ORDER BY ll.login_time DESC
    LIMIT 5
")->fetchAll();

function get_time_ago($timestamp_str) {
    $time = strtotime($timestamp_str);
    $difference = time() - $time;
    
    if ($difference < 1) {
        return 'just now';
    }
    
    $intervals = [
        31536000 => 'year',
        2592000  => 'month',
        604800   => 'week',
        86400    => 'day',
        3600     => 'hour',
        60       => 'minute',
        1        => 'second'
    ];
    
    foreach ($intervals as $secs => $label) {
        $div = $difference / $secs;
        if ($div >= 1) {
            $value = round($div);
            return $value . ' ' . $label . ($value > 1 ? 's' : '') . ' ago';
        }
    }
    return $timestamp_str;
}

$page_title = 'Admin Dashboard';
$current_page = 'dashboard';
require_once '../includes/header.php';
?>

<h2 class="page-title">Welcome back, <?php echo htmlspecialchars($_SESSION['username']); ?></h2>
<p class="page-subtitle">Portal management and overview dashboard.</p>

<!-- Stats Row -->
<div class="stats-row">
    <div class="stat-card">
        <div class="stat-icon bg-gradient-primary">
            <svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
                <path d="M17 21v-2a4 4 0 0 0-4-4H5a4 4 0 0 0-4 4v2"></path>
                <circle cx="9" cy="7" r="4"></circle>
                <path d="M23 21v-2a4 4 0 0 0-3-3.87"></path>
                <path d="M16 3.13a4 4 0 0 1 0 7.75"></path>
            </svg>
        </div>
        <div class="stat-info">
            <div class="stat-number"><?php echo $total_users; ?></div>
            <div class="stat-label">Total Users</div>
            <?php if ($new_users > 0): ?>
                <span class="stat-trend">
                    <svg width="10" height="10" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="3" stroke-linecap="round" stroke-linejoin="round">
                        <line x1="12" y1="19" x2="12" y2="5"></line>
                        <polyline points="5 12 12 5 19 12"></polyline>
                    </svg>
                    +<?php echo $new_users; ?> this week
                </span>
            <?php endif; ?>
        </div>
    </div>
    <div class="stat-card">
        <div class="stat-icon bg-gradient-accent">
            <svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
                <path d="M4 19.5A2.5 2.5 0 0 1 6.5 17H20"></path>
                <path d="M6.5 2H20v20H6.5A2.5 2.5 0 0 1 4 19.5v-15A2.5 2.5 0 0 1 6.5 2z"></path>
            </svg>
        </div>
        <div class="stat-info">
            <div class="stat-number"><?php echo $total_trainers; ?></div>
            <div class="stat-label">Trainers</div>
            <?php if ($new_trainers > 0): ?>
                <span class="stat-trend">
                    <svg width="10" height="10" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="3" stroke-linecap="round" stroke-linejoin="round">
                        <line x1="12" y1="19" x2="12" y2="5"></line>
                        <polyline points="5 12 12 5 19 12"></polyline>
                    </svg>
                    +<?php echo $new_trainers; ?> this week
                </span>
            <?php endif; ?>
        </div>
    </div>
    <div class="stat-card">
        <div class="stat-icon bg-gradient-dark">
            <svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
                <path d="M16 21v-2a4 4 0 0 0-4-4H5a4 4 0 0 0-4 4v2"></path>
                <circle cx="8.5" cy="7" r="4"></circle>
                <polyline points="17 11 19 13 23 9"></polyline>
            </svg>
        </div>
        <div class="stat-info">
            <div class="stat-number"><?php echo $total_participants; ?></div>
            <div class="stat-label">Participants</div>
            <?php if ($new_participants > 0): ?>
                <span class="stat-trend">
                    <svg width="10" height="10" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="3" stroke-linecap="round" stroke-linejoin="round">
                        <line x1="12" y1="19" x2="12" y2="5"></line>
                        <polyline points="5 12 12 5 19 12"></polyline>
                    </svg>
                    +<?php echo $new_participants; ?> this week
                </span>
            <?php endif; ?>
        </div>
    </div>
    <div class="stat-card">
        <div class="stat-icon bg-gradient-primary">
            <svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
                <rect x="2" y="7" width="20" height="14" rx="2" ry="2"></rect>
                <path d="M16 21V5a2 2 0 0 0-2-2h-4a2 2 0 0 0-2 2v16"></path>
            </svg>
        </div>
        <div class="stat-info">
            <div class="stat-number"><?php echo $total_courses; ?></div>
            <div class="stat-label">Courses</div>
            <?php if ($new_courses > 0): ?>
                <span class="stat-trend">
                    <svg width="10" height="10" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="3" stroke-linecap="round" stroke-linejoin="round">
                        <line x1="12" y1="19" x2="12" y2="5"></line>
                        <polyline points="5 12 12 5 19 12"></polyline>
                    </svg>
                    +<?php echo $new_courses; ?> this week
                </span>
            <?php endif; ?>
        </div>
    </div>
    <div class="stat-card">
        <div class="stat-icon bg-gradient-accent">
            <svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
                <path d="M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8z"></path>
                <polyline points="14 2 14 8 20 8"></polyline>
            </svg>
        </div>
        <div class="stat-info">
            <div class="stat-number"><?php echo $total_pages; ?></div>
            <div class="stat-label">Static Pages</div>
            <?php if ($new_pages > 0): ?>
                <span class="stat-trend">
                    <svg width="10" height="10" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="3" stroke-linecap="round" stroke-linejoin="round">
                        <line x1="12" y1="19" x2="12" y2="5"></line>
                        <polyline points="5 12 12 5 19 12"></polyline>
                    </svg>
                    +<?php echo $new_pages; ?> this week
                </span>
            <?php endif; ?>
        </div>
    </div>
</div>

<h3 class="section-heading" style="margin-top: 40px; margin-bottom: 15px;">Quick Actions</h3>
<div class="quick-actions">
    <a href="users.php" class="action-card">
        <div class="action-icon bg-gradient-primary">
            <svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                <path d="M17 21v-2a4 4 0 0 0-4-4H5a4 4 0 0 0-4 4v2"></path>
                <circle cx="9" cy="7" r="4"></circle>
            </svg>
        </div>
        <h3>Manage Users</h3>
        <p>Create, update, and delete portal users and their roles.</p>
        <span class="action-arrow">Manage →</span>
    </a>
    <a href="static_pages.php" class="action-card">
        <div class="action-icon bg-gradient-accent">
            <svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                <path d="M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8z"></path>
            </svg>
        </div>
        <h3>Static Pages</h3>
        <p>Edit custom information pages and resources on the site.</p>
        <span class="action-arrow">Edit Pages →</span>
    </a>
    <a href="error_logs.php" class="action-card">
        <div class="action-icon bg-gradient-dark" style="background: linear-gradient(135deg, #ef4444, #b91c1c);">
            <svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                <circle cx="12" cy="12" r="10"></circle>
                <line x1="12" y1="8" x2="12" y2="12"></line>
                <line x1="12" y1="16" x2="12.01" y2="16"></line>
            </svg>
        </div>
        <h3>System Error Logs</h3>
        <p>Monitor global error reports, warnings, exceptions, and resolve them.</p>
        <span class="action-arrow" style="color: #ef4444;">View Logs →</span>
    </a>
    <a href="users.php" class="action-card">
        <div class="action-icon" style="background: linear-gradient(135deg, #7c3aed, #6d28d9);">
            <svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                <circle cx="11" cy="11" r="7"/>
                <line x1="21" y1="21" x2="16.65" y2="16.65"/>
                <path d="M9 11l2 2 4-4"/>
            </svg>
        </div>
        <h3>Impersonate User</h3>
        <p>Enter the portal as any trainer or participant to see exactly what they see.</p>
        <span class="action-arrow" style="color:#7c3aed;">Enter As →</span>
    </a>
    <a href="recycle_bin.php" class="action-card">
        <div class="action-icon" style="background: linear-gradient(135deg, #dc2626, #991b1b);">
            <svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                <polyline points="3 6 5 6 21 6"/>
                <path d="M19 6l-1 14H6L5 6"/>
                <path d="M10 11v6M14 11v6"/>
                <path d="M9 6V4h6v2"/>
            </svg>
        </div>
        <h3>Recycle Bin</h3>
        <p>Restore or permanently purge deleted courses, quizzes, and content.</p>
        <span class="action-arrow" style="color:#dc2626;">Open Bin →</span>
    </a>
</div>


<h3 class="section-heading" style="margin-top: 40px; margin-bottom: 15px;">Recent System Activity</h3>
<div class="panel-card">
    <div class="activity-feed">
        <?php if (empty($recent_logins)): ?>
            <div class="no-activity-msg">No recent activity.</div>
        <?php else: ?>
            <?php foreach ($recent_logins as $login): ?>
                <div class="activity-item">
                    <div class="activity-icon-wrapper <?php echo htmlspecialchars($login['role']); ?>">
                        <?php if ($login['role'] === 'admin'): ?>
                            <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
                                <path d="M12 22s8-4 8-10V5l-8-3-8 3v7c0 6 8 10 8 10z"/>
                            </svg>
                        <?php elseif ($login['role'] === 'trainer'): ?>
                            <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
                                <path d="M2 3h6a4 4 0 0 1 4 4v14a3 3 0 0 0-3-3H2z"/>
                                <path d="M22 3h-6a4 4 0 0 0-4 4v14a3 3 0 0 1 3-3h7z"/>
                            </svg>
                        <?php else: ?>
                            <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
                                <path d="M20 21v-2a4 4 0 0 0-4-4H8a4 4 0 0 0-4 4v2"/>
                                <circle cx="12" cy="7" r="4"/>
                            </svg>
                        <?php endif; ?>
                    </div>
                    <div class="activity-text">
                        User <strong><?php echo htmlspecialchars($login['username']); ?></strong> logged in as <span class="role-badge <?php echo htmlspecialchars($login['role']); ?>"><?php echo htmlspecialchars(ucfirst($login['role'])); ?></span>
                    </div>
                    <div class="activity-time">
                        <?php echo get_time_ago($login['login_time']); ?>
                    </div>
                </div>
            <?php endforeach; ?>
        <?php endif; ?>
    </div>
</div>

<h3 class="section-heading" style="margin-top: 40px; margin-bottom: 15px;">Recent Static Pages</h3>
<div class="pages-grid">
    <?php if (empty($pages)): ?>
        <div class="no-pages-msg">
            <svg width="48" height="48" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5">
                <path d="M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8z" />
                <polyline points="14 2 14 8 20 8" />
            </svg>
            No pages published yet. <a href="static_pages.php" style="color: var(--accent-color);">Create one →</a>
        </div>
    <?php else: ?>
        <?php foreach ($pages as $p): ?>
            <a href="<?php echo BASE_URL; ?>/page.php?slug=<?php echo urlencode($p['url_slug']); ?>" class="page-card">
                <div class="card-accent"></div>
                <div class="card-body">
                    <h3><?php echo htmlspecialchars($p['title']); ?></h3>
                    <div class="card-slug">/page/<?php echo htmlspecialchars($p['url_slug']); ?></div>
                    <div class="card-date">Published <?php echo date('M d, Y', strtotime($p['created_at'])); ?></div>
                </div>
            </a>
        <?php endforeach; ?>
    <?php endif; ?>
</div>

<?php require_once '../includes/footer.php'; ?>