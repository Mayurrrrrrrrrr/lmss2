<?php
require_once '/var/www/html/lms/config.php';
require_once '/var/www/html/lms/database.php';
$db = Database::getInstance()->getConnection();
$db->exec("UPDATE system_settings SET setting_value = '1.1.9' WHERE setting_key = 'latest_android_version'");
$db->exec("UPDATE system_settings SET setting_value = 'https://lms.yuktaa.com/uploads/app-release.apk?v=1.1.9' WHERE setting_key = 'apk_download_url'");
echo "DB settings updated successfully to 1.1.9\n";
unlink(__FILE__);
?>
