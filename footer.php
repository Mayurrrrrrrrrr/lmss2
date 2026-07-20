<?php
$_ft_role = $_SESSION['user_role'] ?? '';
$_ft_page = $current_page ?? '';

// Helper to check active state for bottom nav
function _bn_active(string|array $pages, string $current): string {
    if (is_array($pages)) return in_array($current, $pages) ? ' active' : '';
    return $current === $pages ? ' active' : '';
}
?>
<?php if (isset($_SESSION['user_id'])): ?>
    </div><!-- /.main-content -->
    </div><!-- /.dashboard-layout -->

    <?php if ($_ft_role === 'trainer'): ?>
    <!-- ── TRAINER MOBILE BOTTOM NAV ── -->
    <nav class="bottom-nav" id="bottom-nav">
        <div class="bottom-nav-inner">
            <a href="<?php echo BASE_URL; ?>/trainer/dashboard.php"
               class="bottom-nav-item<?php echo _bn_active('dashboard', $_ft_page); ?>">
                <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-linecap="round" stroke-linejoin="round">
                    <path d="M3 9l9-7 9 7v11a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2z"/>
                    <polyline points="9 22 9 12 15 12 15 22"/>
                </svg>
                <span>Home</span>
            </a>
            <a href="<?php echo BASE_URL; ?>/trainer/courses.php"
               class="bottom-nav-item<?php echo _bn_active('courses', $_ft_page); ?>">
                <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-linecap="round" stroke-linejoin="round">
                    <path d="M4 19.5A2.5 2.5 0 0 1 6.5 17H20"/>
                    <path d="M6.5 2H20v20H6.5A2.5 2.5 0 0 1 4 19.5v-15A2.5 2.5 0 0 1 6.5 2z"/>
                </svg>
                <span>Courses</span>
            </a>
            <a href="<?php echo BASE_URL; ?>/trainer/participants.php"
               class="bottom-nav-item<?php echo _bn_active('participants', $_ft_page); ?>">
                <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-linecap="round" stroke-linejoin="round">
                    <path d="M16 21v-2a4 4 0 0 0-4-4H5a4 4 0 0 0-4 4v2"/>
                    <circle cx="8.5" cy="7" r="4"/>
                    <line x1="20" y1="8" x2="20" y2="14"/>
                    <line x1="23" y1="11" x2="17" y2="11"/>
                </svg>
                <span>People</span>
            </a>
            <a href="<?php echo BASE_URL; ?>/trainer/reports.php"
               class="bottom-nav-item<?php echo _bn_active('reports', $_ft_page); ?>">
                <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-linecap="round" stroke-linejoin="round">
                    <line x1="18" y1="20" x2="18" y2="10"/>
                    <line x1="12" y1="20" x2="12" y2="4"/>
                    <line x1="6" y1="20" x2="6" y2="14"/>
                </svg>
                <span>Reports</span>
            </a>
            <a href="#" class="bottom-nav-item" onclick="toggleSidebar();return false;">
                <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-linecap="round" stroke-linejoin="round">
                    <line x1="3" y1="12" x2="21" y2="12"/>
                    <line x1="3" y1="6" x2="21" y2="6"/>
                    <line x1="3" y1="18" x2="21" y2="18"/>
                </svg>
                <span>More</span>
            </a>
        </div>
    </nav>

    <?php elseif ($_ft_role === 'participant'): ?>
    <!-- ── PARTICIPANT MOBILE BOTTOM NAV ── -->
    <nav class="bottom-nav" id="bottom-nav">
        <div class="bottom-nav-inner">
            <a href="<?php echo BASE_URL; ?>/participant/dashboard.php"
               class="bottom-nav-item<?php echo _bn_active('dashboard', $_ft_page); ?>">
                <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-linecap="round" stroke-linejoin="round">
                    <path d="M3 9l9-7 9 7v11a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2z"/>
                    <polyline points="9 22 9 12 15 12 15 22"/>
                </svg>
                <span>Home</span>
            </a>
            <a href="<?php echo BASE_URL; ?>/participant/courses.php"
               class="bottom-nav-item<?php echo _bn_active(['courses','course_view','view_content'], $_ft_page); ?>">
                <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-linecap="round" stroke-linejoin="round">
                    <path d="M4 19.5A2.5 2.5 0 0 1 6.5 17H20"/>
                    <path d="M6.5 2H20v20H6.5A2.5 2.5 0 0 1 4 19.5v-15A2.5 2.5 0 0 1 6.5 2z"/>
                </svg>
                <span>Courses</span>
            </a>
            <a href="<?php echo BASE_URL; ?>/participant/quizzes.php"
               class="bottom-nav-item<?php echo _bn_active(['quizzes','take_quiz'], $_ft_page); ?>">
                <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-linecap="round" stroke-linejoin="round">
                    <circle cx="12" cy="12" r="10"/>
                    <path d="M9.09 9a3 3 0 0 1 5.83 1c0 2-3 3-3 3"/>
                    <line x1="12" y1="17" x2="12.01" y2="17"/>
                </svg>
                <span>Quizzes</span>
            </a>
            <a href="<?php echo BASE_URL; ?>/participant/leaderboard.php"
               class="bottom-nav-item<?php echo _bn_active('leaderboard', $_ft_page); ?>">
                <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-linecap="round" stroke-linejoin="round">
                    <path d="M8 21H5a2 2 0 0 1-2-2v-5a2 2 0 0 1 2-2h3"/>
                    <path d="M13.5 21H10a2 2 0 0 1-2-2V8a2 2 0 0 1 2-2h3.5"/>
                    <path d="M19 21h-2a2 2 0 0 1-2-2V4a2 2 0 0 1 2-2h2a2 2 0 0 1 2 2v15a2 2 0 0 1-2 2z"/>
                </svg>
                <span>Ranks</span>
            </a>
            <a href="<?php echo BASE_URL; ?>/profile.php"
               class="bottom-nav-item<?php echo _bn_active('profile', $_ft_page); ?>">
                <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-linecap="round" stroke-linejoin="round">
                    <path d="M20 21v-2a4 4 0 0 0-4-4H8a4 4 0 0 0-4 4v2"/>
                    <circle cx="12" cy="7" r="4"/>
                </svg>
                <span>Profile</span>
            </a>
        </div>
    </nav>

    <?php elseif ($_ft_role === 'admin'): ?>
    <!-- ── ADMIN MOBILE BOTTOM NAV ── -->
    <nav class="bottom-nav" id="bottom-nav">
        <div class="bottom-nav-inner">
            <a href="<?php echo BASE_URL; ?>/admin/dashboard.php"
               class="bottom-nav-item<?php echo _bn_active('dashboard', $_ft_page); ?>">
                <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-linecap="round" stroke-linejoin="round">
                    <path d="M3 9l9-7 9 7v11a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2z"/>
                    <polyline points="9 22 9 12 15 12 15 22"/>
                </svg>
                <span>Home</span>
            </a>
            <a href="<?php echo BASE_URL; ?>/admin/users.php"
               class="bottom-nav-item<?php echo _bn_active('users', $_ft_page); ?>">
                <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-linecap="round" stroke-linejoin="round">
                    <path d="M17 21v-2a4 4 0 0 0-4-4H5a4 4 0 0 0-4 4v2"/>
                    <circle cx="9" cy="7" r="4"/>
                    <path d="M23 21v-2a4 4 0 0 0-3-3.87"/>
                    <path d="M16 3.13a4 4 0 0 1 0 7.75"/>
                </svg>
                <span>Users</span>
            </a>
            <a href="<?php echo BASE_URL; ?>/admin/error_logs.php"
               class="bottom-nav-item<?php echo _bn_active('error_logs', $_ft_page); ?>">
                <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-linecap="round" stroke-linejoin="round">
                    <circle cx="12" cy="12" r="10"/>
                    <line x1="12" y1="8" x2="12" y2="12"/>
                    <line x1="12" y1="16" x2="12.01" y2="16"/>
                </svg>
                <span>Logs</span>
            </a>
            <a href="<?php echo BASE_URL; ?>/admin/static_pages.php"
               class="bottom-nav-item<?php echo _bn_active('static_pages', $_ft_page); ?>">
                <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-linecap="round" stroke-linejoin="round">
                    <path d="M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8z"/>
                    <polyline points="14 2 14 8 20 8"/>
                </svg>
                <span>Pages</span>
            </a>
            <a href="#" class="bottom-nav-item" onclick="toggleSidebar();return false;">
                <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-linecap="round" stroke-linejoin="round">
                    <line x1="3" y1="12" x2="21" y2="12"/>
                    <line x1="3" y1="6" x2="21" y2="6"/>
                    <line x1="3" y1="18" x2="21" y2="18"/>
                </svg>
                <span>More</span>
            </a>
        </div>
    </nav>
    <?php endif; ?>

<?php else: ?>
    </main>
<?php endif; ?>

<footer class="site-footer">
    <div class="container">
        &copy; <?php echo date('Y'); ?> Firefly LMS Portal &mdash; All rights reserved.
    </div>
</footer>

<script>
// ── Sidebar toggle (also declared in sidebar.php for inline use) ──
if (typeof toggleSidebar === 'undefined') {
    function toggleSidebar() {
        var sidebar = document.getElementById('sidebar');
        var overlay = document.querySelector('.sidebar-overlay');
        var isOpen = sidebar.classList.contains('open');
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
}

// Close sidebar on ESC
document.addEventListener('keydown', function(e) {
    if (e.key === 'Escape') {
        var sidebar = document.getElementById('sidebar');
        if (sidebar && sidebar.classList.contains('open')) toggleSidebar();
    }
});

// Close sidebar when a nav link is clicked on mobile
document.querySelectorAll('.sidebar-nav a').forEach(function(link) {
    link.addEventListener('click', function() {
        if (window.innerWidth <= 768) toggleSidebar();
    });
});

// DataTables init
$(document).ready(function() {
    if ($.fn.DataTable) {
        $('.datatable').DataTable({
            pageLength: 25,
            responsive: true,
            language: { search: '', searchPlaceholder: 'Search...' }
        });
    }
});

// PWA: Register service worker
if ('serviceWorker' in navigator) {
    window.addEventListener('load', function() {
        navigator.serviceWorker.register('/service-worker.js')
            .then(function(reg) { console.log('SW registered'); })
            .catch(function(err) { console.log('SW error:', err); });
    });
}

// PWA: Install prompt
var deferredPrompt;
window.addEventListener('beforeinstallprompt', function(e) {
    e.preventDefault();
    deferredPrompt = e;
    var banner = document.getElementById('pwa-install-banner');
    if (banner) banner.classList.add('show');
});

function installPWA() {
    if (deferredPrompt) {
        deferredPrompt.prompt();
        deferredPrompt.userChoice.then(function() {
            deferredPrompt = null;
            var banner = document.getElementById('pwa-install-banner');
            if (banner) banner.classList.remove('show');
        });
    }
}

<?php if (isset($_SESSION['user_role']) && $_SESSION['user_role'] === 'participant'): ?>
// Activity heartbeat — only for participants, fires every 60s when tab visible
(function() {
    var page = document.body.dataset.page || 'dashboard';
    var itemId = document.body.dataset.itemId || '';
    var itemLabel = document.body.dataset.itemLabel || '';

    function sendHeartbeat() {
        if (document.hidden) return;
        var fd = new FormData();
        fd.append('page', page);
        fd.append('item_id', itemId);
        fd.append('item_label', itemLabel);
        fetch('<?= BASE_URL ?>/participant/heartbeat.php', { method: 'POST', body: fd })
            .catch(function(){});
    }

    sendHeartbeat();
    setInterval(sendHeartbeat, 60000);
})();
<?php endif; ?>
</script>
</body>
</html>