#!/usr/bin/env php
<?php
/**
 * patch_softdelete.php
 * Patches trainer PHP files to use soft-delete instead of hard-delete.
 * Run once from CLI: php /home/ubuntu/patch_softdelete.php
 */

$patches = [
    // ── courses.php ────────────────────────────────────────────────────
    '/var/www/html/lms/trainer/courses.php' => [
        [
            'find'    => 'DELETE FROM courses WHERE id = ? AND created_by = ?',
            'replace' => 'UPDATE courses SET deleted_at = NOW() WHERE id = ? AND created_by = ?',
        ],
        [
            'find'    => 'WHERE c.created_by = ? ' . "\n" . '    ORDER BY c.created_at DESC',
            'replace' => 'WHERE c.created_by = ? AND c.deleted_at IS NULL ' . "\n" . '    ORDER BY c.created_at DESC',
        ],
    ],

    // ── modules.php ────────────────────────────────────────────────────
    '/var/www/html/lms/trainer/modules.php' => [
        [
            'find'    => 'DELETE FROM modules WHERE id = ? AND course_id = ?',
            'replace' => 'UPDATE modules SET deleted_at = NOW() WHERE id = ? AND course_id = ?',
        ],
    ],

    // ── chapters.php ───────────────────────────────────────────────────
    '/var/www/html/lms/trainer/chapters.php' => [
        [
            'find'    => 'DELETE FROM chapters WHERE id = ? AND module_id = ?',
            'replace' => 'UPDATE chapters SET deleted_at = NOW() WHERE id = ? AND module_id = ?',
        ],
    ],

    // ── quizzes.php ────────────────────────────────────────────────────
    '/var/www/html/lms/trainer/quizzes.php' => [
        [
            'find'    => 'DELETE FROM quizzes WHERE id = ? AND created_by = ?',
            'replace' => 'UPDATE quizzes SET deleted_at = NOW() WHERE id = ? AND created_by = ?',
        ],
    ],

    // ── questions.php ──────────────────────────────────────────────────
    '/var/www/html/lms/trainer/questions.php' => [
        [
            'find'    => 'DELETE FROM questions WHERE id = ? AND quiz_id = ?',
            'replace' => 'UPDATE questions SET deleted_at = NOW() WHERE id = ? AND quiz_id = ?',
        ],
    ],
];

$ok = 0; $fail = 0;
foreach ($patches as $file => $replacements) {
    if (!file_exists($file)) {
        echo "⚠️  SKIP (not found): $file\n";
        continue;
    }
    $content = file_get_contents($file);
    $original = $content;
    foreach ($replacements as $p) {
        if (strpos($content, $p['find']) !== false) {
            $content = str_replace($p['find'], $p['replace'], $content);
            echo "✅ Patched: $file\n   → " . substr($p['replace'], 0, 60) . "…\n";
        } else {
            // Already patched or different version
            if (strpos($content, $p['replace']) !== false) {
                echo "ℹ️  Already patched: $file\n";
            } else {
                echo "❌ NOT FOUND in $file:\n   → " . substr($p['find'], 0, 60) . "\n";
                $fail++;
            }
        }
    }
    if ($content !== $original) {
        file_put_contents($file, $content);
        $ok++;
    }
}

// Also patch SELECT queries to exclude soft-deleted chapters and modules
$select_patches = [
    '/var/www/html/lms/trainer/chapters.php' => [
        [
            'find'    => 'WHERE module_id = ? ORDER BY id ASC',
            'replace' => 'WHERE module_id = ? AND deleted_at IS NULL ORDER BY id ASC',
        ],
    ],
    '/var/www/html/lms/trainer/modules.php' => [
        [
            'find'    => 'WHERE course_id = ? ORDER BY id ASC',
            'replace' => 'WHERE course_id = ? AND deleted_at IS NULL ORDER BY id ASC',
        ],
    ],
    '/var/www/html/lms/trainer/questions.php' => [
        [
            'find'    => 'WHERE quiz_id = ? ORDER BY id ASC',
            'replace' => 'WHERE quiz_id = ? AND deleted_at IS NULL ORDER BY id ASC',
        ],
    ],
];

foreach ($select_patches as $file => $replacements) {
    if (!file_exists($file)) continue;
    $content = file_get_contents($file);
    $original = $content;
    foreach ($replacements as $p) {
        if (strpos($content, $p['find']) !== false) {
            $content = str_replace($p['find'], $p['replace'], $content);
            echo "✅ SELECT patched: $file\n";
        }
    }
    if ($content !== $original) {
        file_put_contents($file, $content);
        $ok++;
    }
}

echo "\nDone. Patched $ok file(s). Failures: $fail\n";
