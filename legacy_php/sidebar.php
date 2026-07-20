<?php
/**
 * Sidebar Navigation
 * Include inside dashboard-layout div, BEFORE main-content div.
 * Requires $current_page to be set before including.
 */
$role = $_SESSION['user_role'] ?? '';
$current_page = $current_page ?? '';

// Helper: returns 'active' if page matches
function nav_active(string|array $pages, string $current): string {
    if (is_array($pages)) return in_array($current, $pages) ? 'active' : '';
    return $current === $pages ? 'active' : '';
}

// Get username display
$_sb_username = $_SESSION['username'] ?? 'User';
$_sb_login_id = $_SESSION['login_id'] ?? ($_SESSION['username'] ?? '');
?>
<aside class="sidebar" id="sidebar">
    <div class="sidebar-header">
        <!-- Firefly Logo -->
        <div class="sidebar-logo-wrap">
            <img src="<?php echo BASE_URL; ?>/assets/icons/firefly-logo.svg"
                 alt="Firefly LMS"
                 onerror="this.onerror=null;this.src='<?php echo BASE_URL; ?>/assets/icons/firefly-logo.png';">
        </div>
        <div class="sidebar-username"><?php echo htmlspecialchars($_sb_username); ?></div>
        <?php if ($_sb_login_id && $_sb_login_id !== $_sb_username): ?>
        <div class="sidebar-userid"><?php echo htmlspecialchars($_sb_login_id); ?></div>
        <?php endif; ?>
    </div>

    <nav class="sidebar-nav">

        <!-- ── MAIN (all roles) ── -->
        <div class="nav-section-title">Main</div>
        <a href="<?php echo BASE_URL . '/' . $role; ?>/dashboard.php"
            class="<?php echo nav_active('dashboard', $current_page); ?>">
            <svg class="nav-icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
                <path d="M3 9l9-7 9 7v11a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2z"/>
                <polyline points="9 22 9 12 15 12 15 22"/>
            </svg>
            Home
        </a>

<?php if ($role === 'admin'): ?>

        <!-- ── ADMIN NAVIGATION ── -->
        <div class="nav-section-title">Management</div>
        <a href="<?php echo BASE_URL; ?>/admin/users.php"
            class="<?php echo nav_active('users', $current_page); ?>">
            <svg class="nav-icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
                <path d="M17 21v-2a4 4 0 0 0-4-4H5a4 4 0 0 0-4 4v2"/>
                <circle cx="9" cy="7" r="4"/>
                <path d="M23 21v-2a4 4 0 0 0-3-3.87"/><path d="M16 3.13a4 4 0 0 1 0 7.75"/>
            </svg>
            Manage Users
        </a>
        <a href="<?php echo BASE_URL; ?>/admin/static_pages.php"
            class="<?php echo nav_active('static_pages', $current_page); ?>">
            <svg class="nav-icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
                <path d="M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8z"/>
                <polyline points="14 2 14 8 20 8"/>
                <line x1="16" y1="13" x2="8" y2="13"/><line x1="16" y1="17" x2="8" y2="17"/>
            </svg>
            Static Pages
        </a>

        <div class="nav-section-title">Masters</div>
        <a href="<?php echo BASE_URL; ?>/admin/stores.php"
            class="<?php echo nav_active('stores', $current_page); ?>">
            <svg class="nav-icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
                <path d="M3 9l9-2 9 2v9a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2z"/>
                <polyline points="9 22 9 13 15 13 15 22"/>
            </svg>
            Store Master
        </a>
        <a href="<?php echo BASE_URL; ?>/admin/designations.php"
            class="<?php echo nav_active('designations', $current_page); ?>">
            <svg class="nav-icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
                <rect x="2" y="7" width="20" height="14" rx="2" ry="2"/>
                <path d="M16 21V5a2 2 0 0 0-2-2h-4a2 2 0 0 0-2 2v16"/>
            </svg>
            Designations
        </a>
        <a href="<?php echo BASE_URL; ?>/admin/departments.php"
            class="<?php echo nav_active('departments', $current_page); ?>">
            <svg class="nav-icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
                <rect x="3" y="3" width="7" height="9"/><rect x="14" y="3" width="7" height="5"/>
                <rect x="14" y="12" width="7" height="9"/><rect x="3" y="16" width="7" height="5"/>
            </svg>
            Departments
        </a>

        <div class="nav-section-title">System</div>
        <a href="<?php echo BASE_URL; ?>/admin/error_logs.php"
            class="<?php echo nav_active('error_logs', $current_page); ?>">
            <svg class="nav-icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
                <circle cx="12" cy="12" r="10"/>
                <line x1="12" y1="8" x2="12" y2="12"/>
                <line x1="12" y1="16" x2="12.01" y2="16"/>
            </svg>
            Error Logs
        </a>
        <a href="<?php echo BASE_URL; ?>/admin/diagnostics.php"
            class="<?php echo nav_active('diagnostics', $current_page); ?>">
            <svg class="nav-icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
                <polyline points="22 12 18 12 15 21 9 3 6 12 2 12"/>
            </svg>
            Diagnostics
        </a>
        <a href="<?php echo BASE_URL; ?>/admin/recycle_bin.php"
            class="<?php echo nav_active('recycle_bin', $current_page); ?>">
            <svg class="nav-icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
                <polyline points="3 6 5 6 21 6"/>
                <path d="M19 6l-1 14H6L5 6"/>
                <path d="M10 11v6M14 11v6"/>
                <path d="M9 6V4h6v2"/>
            </svg>
            Recycle Bin
        </a>
        <a href="<?php echo BASE_URL; ?>/admin/users.php"
            class="<?php echo nav_active(['users','impersonate'], $current_page); ?>"
            style="<?php echo isset($_SESSION['admin_origin']) ? 'color:#f59e0b;' : ''; ?>">
            <svg class="nav-icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
                <circle cx="11" cy="11" r="7"/>
                <line x1="21" y1="21" x2="16.65" y2="16.65"/>
            </svg>
            <?php echo isset($_SESSION['admin_origin']) ? '👁 Currently Impersonating' : 'Impersonate User'; ?>
        </a>


<?php elseif ($role === 'trainer'): ?>

        <!-- ── TRAINER NAVIGATION ── -->
        <div class="nav-section-title">Content</div>
        <a href="<?php echo BASE_URL; ?>/trainer/courses.php"
            class="<?php echo nav_active('courses', $current_page); ?>">
            <svg class="nav-icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
                <path d="M4 19.5A2.5 2.5 0 0 1 6.5 17H20"/>
                <path d="M6.5 2H20v20H6.5A2.5 2.5 0 0 1 4 19.5v-15A2.5 2.5 0 0 1 6.5 2z"/>
            </svg>
            Courses &amp; Content
        </a>
        <a href="<?php echo BASE_URL; ?>/trainer/quizzes.php"
            class="<?php echo nav_active('quizzes', $current_page); ?>">
            <svg class="nav-icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
                <circle cx="12" cy="12" r="10"/>
                <path d="M9.09 9a3 3 0 0 1 5.83 1c0 2-3 3-3 3"/>
                <line x1="12" y1="17" x2="12.01" y2="17"/>
            </svg>
            Quizzes
        </a>
        <a href="<?php echo BASE_URL; ?>/trainer/badges.php"
           class="<?php echo nav_active('badges', $current_page); ?>">
            <svg class="nav-icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
                <circle cx="12" cy="8" r="6"/>
                <path d="M15.477 12.89L17 22l-5-3-5 3 1.523-9.11"/>
            </svg>
            Badges
        </a>

        <div class="nav-section-title">People</div>
        <a href="<?php echo BASE_URL; ?>/trainer/participants.php"
            class="<?php echo nav_active('participants', $current_page); ?>">
            <svg class="nav-icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
                <path d="M16 21v-2a4 4 0 0 0-4-4H5a4 4 0 0 0-4 4v2"/>
                <circle cx="8.5" cy="7" r="4"/>
                <line x1="20" y1="8" x2="20" y2="14"/>
                <line x1="23" y1="11" x2="17" y2="11"/>
            </svg>
            Manage Participants
        </a>
        <a href="<?php echo BASE_URL; ?>/trainer/assignments.php"
            class="<?php echo nav_active('assignments', $current_page); ?>">
            <svg class="nav-icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
                <path d="M16 4h2a2 2 0 0 1 2 2v14a2 2 0 0 1-2 2H6a2 2 0 0 1-2-2V6a2 2 0 0 1 2-2h2"/>
                <rect x="8" y="2" width="8" height="4" rx="1" ry="1"/>
                <path d="M9 14l2 2 4-4"/>
            </svg>
            Assign Courses
        </a>
        <a href="<?php echo BASE_URL; ?>/trainer/quiz_assign.php"
            class="<?php echo nav_active('quiz_assign', $current_page); ?>">
            <svg class="nav-icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
                <path d="M16 4h2a2 2 0 0 1 2 2v14a2 2 0 0 1-2 2H6a2 2 0 0 1-2-2V6a2 2 0 0 1 2-2h2"/>
                <rect x="8" y="2" width="8" height="4" rx="1" ry="1"/>
                <line x1="9" y1="12" x2="15" y2="12"/>
                <line x1="9" y1="16" x2="15" y2="16"/>
            </svg>
            Assign Quizzes
        </a>

        <div class="nav-section-title">Masters</div>
        <a href="<?php echo BASE_URL; ?>/trainer/stores.php"
            class="<?php echo nav_active('stores', $current_page); ?>">
            <svg class="nav-icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
                <path d="M3 9l9-2 9 2v9a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2z"/>
                <polyline points="9 22 9 13 15 13 15 22"/>
            </svg>
            Store Master
        </a>
        <a href="<?php echo BASE_URL; ?>/trainer/designations.php"
            class="<?php echo nav_active('designations', $current_page); ?>">
            <svg class="nav-icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
                <rect x="2" y="7" width="20" height="14" rx="2" ry="2"/>
                <path d="M16 21V5a2 2 0 0 0-2-2h-4a2 2 0 0 0-2 2v16"/>
            </svg>
            Designations
        </a>
        <a href="<?php echo BASE_URL; ?>/trainer/departments.php"
            class="<?php echo nav_active('departments', $current_page); ?>">
            <svg class="nav-icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
                <rect x="3" y="3" width="7" height="9"/><rect x="14" y="3" width="7" height="5"/>
                <rect x="14" y="12" width="7" height="9"/><rect x="3" y="16" width="7" height="5"/>
            </svg>
            Departments
        </a>

        <div class="nav-section-title">Sessions</div>
        <a href="<?php echo BASE_URL; ?>/trainer/live.php"
            class="<?php echo nav_active('live', $current_page); ?>">
            <svg class="nav-icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
                <polygon points="23 7 16 12 23 17 23 7"/>
                <rect x="1" y="5" width="15" height="14" rx="2" ry="2"/>
            </svg>
            Live Quiz
        </a>
        <a href="<?php echo BASE_URL; ?>/trainer/activity.php"
           class="<?php echo nav_active('activity', $current_page); ?>">
            <svg class="nav-icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
                <polyline points="22 12 18 12 15 21 9 3 6 12 2 12"/>
            </svg>
            Live View
        </a>
        <a href="<?php echo BASE_URL; ?>/trainer/roleplay_tracker.php"
           class="<?php echo nav_active('roleplays', $current_page); ?>">
            <svg class="nav-icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
                <path d="M21 15a2 2 0 0 1-2 2H7l-4 4V5a2 2 0 0 1 2-2h14a2 2 0 0 1 2 2z"/>
            </svg>
            Roleplay Tracker
        </a>

        <div class="nav-section-title">Reports</div>
        <a href="<?php echo BASE_URL; ?>/trainer/reports.php"
            class="<?php echo nav_active('reports', $current_page); ?>">
            <svg class="nav-icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
                <line x1="18" y1="20" x2="18" y2="10"/>
                <line x1="12" y1="20" x2="12" y2="4"/>
                <line x1="6" y1="20" x2="6" y2="14"/>
            </svg>
            Reports &amp; Analytics
        </a>
        <a href="<?php echo BASE_URL; ?>/trainer/leaderboard.php"
            class="<?php echo nav_active('leaderboard', $current_page); ?>">
            <svg class="nav-icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
                <path d="M8 21H5a2 2 0 0 1-2-2v-5a2 2 0 0 1 2-2h3"/>
                <path d="M13.5 21H10a2 2 0 0 1-2-2V8a2 2 0 0 1 2-2h3.5"/>
                <path d="M19 21h-2a2 2 0 0 1-2-2V4a2 2 0 0 1 2-2h2a2 2 0 0 1 2 2v15a2 2 0 0 1-2 2z"/>
            </svg>
            Leaderboard
        </a>

        <div class="nav-section-title">Settings</div>
        <a href="<?php echo BASE_URL; ?>/trainer/smtp_settings.php"
           class="<?php echo nav_active('smtp_settings', $current_page); ?>">
            <svg class="nav-icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
                <path d="M4 4h16c1.1 0 2 .9 2 2v12c0 1.1-.9 2-2 2H4c-1.1 0-2-.9-2-2V6c0-1.1.9-2 2-2z"/>
                <polyline points="22,6 12,13 2,6"/>
            </svg>
            SMTP Settings
        </a>

<?php elseif ($role === 'participant'): ?>

        <!-- ── PARTICIPANT NAVIGATION ── -->
        <div class="nav-section-title">Learning</div>
        <a href="<?php echo BASE_URL; ?>/participant/courses.php"
            class="<?php echo nav_active(['courses', 'course_view', 'view_content'], $current_page); ?>">
            <svg class="nav-icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
                <path d="M4 19.5A2.5 2.5 0 0 1 6.5 17H20"/>
                <path d="M6.5 2H20v20H6.5A2.5 2.5 0 0 1 4 19.5v-15A2.5 2.5 0 0 1 6.5 2z"/>
            </svg>
            My Courses
        </a>
        <a href="<?php echo BASE_URL; ?>/participant/quizzes.php"
            class="<?php echo nav_active(['quizzes', 'take_quiz'], $current_page); ?>">
            <svg class="nav-icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
                <circle cx="12" cy="12" r="10"/>
                <path d="M9.09 9a3 3 0 0 1 5.83 1c0 2-3 3-3 3"/>
                <line x1="12" y1="17" x2="12.01" y2="17"/>
            </svg>
            My Quizzes
        </a>

        <div class="nav-section-title">Live</div>
        <a href="<?php echo BASE_URL; ?>/participant/join.php"
            class="<?php echo nav_active('join', $current_page); ?>">
            <svg class="nav-icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
                <polygon points="23 7 16 12 23 17 23 7"/>
                <rect x="1" y="5" width="15" height="14" rx="2" ry="2"/>
            </svg>
            Join Live Quiz
        </a>

        <div class="nav-section-title">Achievements</div>
        <a href="<?php echo BASE_URL; ?>/participant/leaderboard.php"
            class="<?php echo nav_active('leaderboard', $current_page); ?>">
            <svg class="nav-icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
                <path d="M8 21H5a2 2 0 0 1-2-2v-5a2 2 0 0 1 2-2h3"/>
                <path d="M13.5 21H10a2 2 0 0 1-2-2V8a2 2 0 0 1 2-2h3.5"/>
                <path d="M19 21h-2a2 2 0 0 1-2-2V4a2 2 0 0 1 2-2h2a2 2 0 0 1 2 2v15a2 2 0 0 1-2 2z"/>
            </svg>
            Leaderboard
        </a>
        <a href="<?php echo BASE_URL; ?>/participant/certificate.php"
            class="<?php echo nav_active('certificate', $current_page); ?>">
            <svg class="nav-icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
                <circle cx="12" cy="8" r="6"/>
                <path d="M15.477 12.89L17 22l-5-3-5 3 1.523-9.11"/>
            </svg>
            My Certificates
        </a>

<?php endif; ?>

    </nav>

    <div class="sidebar-footer">
        <a href="<?php echo BASE_URL; ?>/profile.php"
            class="footer-nav-link <?php echo nav_active('profile', $current_page); ?>">
            <svg class="nav-icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
                <path d="M20 21v-2a4 4 0 0 0-4-4H8a4 4 0 0 0-4 4v2"/>
                <circle cx="12" cy="7" r="4"/>
            </svg>
            My Profile
        </a>
        <a href="<?php echo BASE_URL; ?>/change_password.php"
            class="footer-nav-link <?php echo nav_active('change_password', $current_page); ?>">
            <svg class="nav-icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
                <rect x="3" y="11" width="18" height="11" rx="2" ry="2"/>
                <path d="M7 11V7a5 5 0 0 1 10 0v4"/>
            </svg>
            Change Password
        </a>
        <a href="<?php echo BASE_URL; ?>/logout.php" class="logout-link">
            <svg class="nav-icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
                <path d="M9 21H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h4"/>
                <polyline points="16 17 21 12 16 7"/>
                <line x1="21" y1="12" x2="9" y2="12"/>
            </svg>
            Sign Out
        </a>
    </div>

</aside>

<script>
function toggleSidebar() {
    const sidebar = document.getElementById('sidebar');
    const overlay = document.querySelector('.sidebar-overlay');
    const isOpen = sidebar.classList.contains('open');
    if (isOpen) {
        sidebar.classList.remove('open');
        overlay.classList.remove('show');
        document.body.style.overflow = '';
    } else {
        sidebar.classList.add('open');
        overlay.classList.add('show');
        document.body.style.overflow = 'hidden';
    }
}
</script>