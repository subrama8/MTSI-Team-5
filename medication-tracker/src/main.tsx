import React from 'react'
import ReactDOM from 'react-dom/client'
import { BrowserRouter } from 'react-router-dom'
import App from './App.tsx'
import './styles/index.css'
import { NotificationService } from './services/notification-service'
import { MedicationService } from './services/medication-service'

// Initialize app services
const initializeApp = async () => {
  // Register service worker for PWA functionality
  await NotificationService.registerServiceWorker()
  
  // Initialize notification service
  await NotificationService.initialize()
  
  // Generate doses for existing schedules
  MedicationService.generateDosesForAllSchedules()
  
  // Schedule notifications for upcoming doses
  await NotificationService.scheduleAllNotifications()
  
  // Schedule periodic notification updates (every hour)
  setInterval(() => {
    NotificationService.scheduleAllNotifications()
  }, 60 * 60 * 1000)
}

// Start app initialization
initializeApp().catch(console.error)

ReactDOM.createRoot(document.getElementById('root')!).render(
  <React.StrictMode>
    <BrowserRouter>
      <App />
    </BrowserRouter>
  </React.StrictMode>,
)