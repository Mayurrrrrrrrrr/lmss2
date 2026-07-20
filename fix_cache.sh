#!/bin/bash
# Fix version.json for cache busting
cat > /var/www/lms-web/version.json << 'JSONEOF'
{"app_name":"lms_mobile_app","version":"2.0.0","build_number":"42","package_name":"lms_mobile_app"}
JSONEOF

# Update service worker version in bootstrap to force re-download
sed -i 's/3975913828/3975913829/g' /var/www/lms-web/flutter_bootstrap.js

# Also disable the service worker entirely by replacing it with a no-op
cat > /var/www/lms-web/flutter_service_worker.js << 'SWEOF'
// Service worker disabled for fresh deployment
self.addEventListener('install', function(event) {
  self.skipWaiting();
});
self.addEventListener('activate', function(event) {
  event.waitUntil(
    caches.keys().then(function(cacheNames) {
      return Promise.all(
        cacheNames.map(function(cacheName) {
          return caches.delete(cacheName);
        })
      );
    }).then(function() {
      return self.clients.claim();
    })
  );
});
self.addEventListener('fetch', function(event) {
  event.respondWith(fetch(event.request));
});
SWEOF

# Add no-cache headers to Caddy for JS files
echo "Done! Service worker replaced and cache busted."
