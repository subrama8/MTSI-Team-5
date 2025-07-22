// Service Worker for medication tracker PWA

const CACHE_NAME = 'medication-tracker-v1'
const urlsToCache = [
  '/',
  '/static/js/bundle.js',
  '/static/css/main.css',
  '/manifest.json'
]

// Install event
self.addEventListener('install', (event) => {
  event.waitUntil(
    caches.open(CACHE_NAME)
      .then((cache) => cache.addAll(urlsToCache))
  )
})

// Fetch event
self.addEventListener('fetch', (event) => {
  event.respondWith(
    caches.match(event.request)
      .then((response) => {
        // Return cached version or fetch from network
        return response || fetch(event.request)
      })
  )
})

// Push notification event
self.addEventListener('push', (event) => {
  if (event.data) {
    const data = event.data.json()
    
    const options = {
      body: data.body,
      icon: '/icon-192x192.png',
      badge: '/icon-192x192.png',
      vibrate: [200, 100, 200],
      data: data.data,
      actions: [
        {
          action: 'complete',
          title: 'Mark Complete',
          icon: '/icon-check.png'
        },
        {
          action: 'snooze',
          title: 'Remind in 5min',
          icon: '/icon-snooze.png'
        }
      ]
    }
    
    event.waitUntil(
      self.registration.showNotification(data.title, options)
    )
  }
})

// Notification click event
self.addEventListener('notificationclick', (event) => {
  event.notification.close()
  
  if (event.action === 'complete') {
    // Send message to main app
    self.clients.matchAll().then((clients) => {
      clients.forEach((client) => {
        client.postMessage({
          type: 'NOTIFICATION_ACTION',
          action: 'complete',
          doseId: event.notification.data.doseId
        })
      })
    })
  } else if (event.action === 'snooze') {
    // Send message to main app
    self.clients.matchAll().then((clients) => {
      clients.forEach((client) => {
        client.postMessage({
          type: 'NOTIFICATION_ACTION',
          action: 'snooze',
          doseId: event.notification.data.doseId
        })
      })
    })
  } else {
    // Default action - open app
    event.waitUntil(
      self.clients.matchAll().then((clientList) => {
        if (clientList.length > 0) {
          return clientList[0].focus()
        }
        return self.clients.openWindow('/')
      })
    )
  }
})

// Background sync for offline functionality
self.addEventListener('sync', (event) => {
  if (event.tag === 'background-sync') {
    event.waitUntil(doBackgroundSync())
  }
})

function doBackgroundSync() {
  // Sync medication data when back online
  return fetch('/api/sync')
    .then((response) => {
      if (!response.ok) {
        throw new Error('Sync failed')
      }
      return response.json()
    })
    .catch((error) => {
      console.error('Background sync failed:', error)
    })
}

// Periodic background sync for scheduling notifications
self.addEventListener('periodicsync', (event) => {
  if (event.tag === 'schedule-notifications') {
    event.waitUntil(scheduleUpcomingNotifications())
  }
})

function scheduleUpcomingNotifications() {
  // This would be called periodically to schedule notifications
  // Implementation would depend on your specific notification scheduling logic
  return Promise.resolve()
}