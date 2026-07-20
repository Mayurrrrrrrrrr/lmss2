#!/bin/bash

# 1. Update flutter_bootstrap.js to add cache-busting param to main.dart.js
TIMESTAMP=$(date +%s)
sed -i "s|main.dart.js|main.dart.js?v=$TIMESTAMP|g" /var/www/lms-web/flutter_bootstrap.js

# 2. Also update the service worker version to force a re-register
sed -i "s/serviceWorkerVersion: \"[^\"]*\"/serviceWorkerVersion: \"$TIMESTAMP\"/" /var/www/lms-web/flutter_bootstrap.js

# 3. Replace index.html to forcefully unregister any existing service workers
cat > /var/www/lms-web/index.html << 'HTMLEOF'
<!DOCTYPE html>
<html>
<head>
  <base href="/">
  <meta charset="UTF-8">
  <meta content="IE=Edge" http-equiv="X-UA-Compatible">
  <meta name="description" content="Firefly Diamonds LMS">
  <meta name="mobile-web-app-capable" content="yes">
  <meta name="apple-mobile-web-app-status-bar-style" content="black">
  <meta name="apple-mobile-web-app-title" content="Firefly LMS">
  <link rel="apple-touch-icon" href="icons/Icon-192.png">
  <link rel="icon" type="image/png" href="favicon.png"/>
  <title>Firefly LMS</title>
  <link rel="manifest" href="manifest.json">
</head>
<body>
  <script>
    // Force unregister all service workers and clear caches before loading Flutter
    if ('serviceWorker' in navigator) {
      navigator.serviceWorker.getRegistrations().then(function(registrations) {
        for (let registration of registrations) {
          registration.unregister();
          console.log('Service worker unregistered');
        }
      });
      caches.keys().then(function(names) {
        for (let name of names) {
          caches.delete(name);
          console.log('Cache cleared:', name);
        }
      });
    }
  </script>
  <script src="flutter_bootstrap.js" async></script>
</body>
</html>
HTMLEOF

echo "Done! Cache busted with timestamp: $TIMESTAMP"
