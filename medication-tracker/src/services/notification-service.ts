import { MedicationService } from './medication-service'
import { ScheduledDose, MedicationSchedule } from '../types/medication'
import { addMinutes, parseISO, format } from 'date-fns'

export class NotificationService {
  private static scheduleTimers: Map<string, NodeJS.Timeout> = new Map()
  private static isInitialized = false

  static async initialize(): Promise<boolean> {
    if (this.isInitialized) return true

    // Request notification permission
    if (!('Notification' in window)) {
      console.warn('This browser does not support notifications')
      return false
    }

    if (Notification.permission === 'default') {
      const permission = await Notification.requestPermission()
      if (permission !== 'granted') {
        console.warn('Notification permission denied')
        return false
      }
    } else if (Notification.permission === 'denied') {
      console.warn('Notifications are blocked')
      return false
    }

    this.isInitialized = true
    return true
  }

  static async scheduleAllNotifications(): Promise<void> {
    if (!this.isInitialized) {
      const initialized = await this.initialize()
      if (!initialized) return
    }

    // Clear existing timers
    this.clearAllTimers()

    // Get upcoming doses for the next 24 hours
    const upcomingDoses = MedicationService.getUpcomingDoses(24)
    const schedules = MedicationService.getSchedules()

    upcomingDoses.forEach(dose => {
      const schedule = schedules.find(s => s.id === dose.scheduleId)
      if (schedule && schedule.isActive) {
        this.scheduleDoseReminder(dose, schedule)
      }
    })

    console.log(`Scheduled ${upcomingDoses.length} medication reminders`)
  }

  private static scheduleDoseReminder(dose: ScheduledDose, schedule: MedicationSchedule): void {
    const doseDateTime = parseISO(`${dose.date}T${dose.time}:00`)
    const reminderTime = addMinutes(doseDateTime, -schedule.reminderMinutes)
    const now = new Date()

    // Only schedule if reminder time is in the future
    if (reminderTime <= now) return

    const timeoutMs = reminderTime.getTime() - now.getTime()
    
    const timer = setTimeout(() => {
      this.sendNotification(dose, schedule)
    }, timeoutMs)

    this.scheduleTimers.set(dose.id, timer)
  }

  private static sendNotification(dose: ScheduledDose, schedule: MedicationSchedule): void {
    if (!this.isInitialized || Notification.permission !== 'granted') return

    const doseDateTime = parseISO(`${dose.date}T${dose.time}:00`)
    const timeString = format(doseDateTime, 'h:mm a')

    const notification = new Notification(`Medication Reminder: ${schedule.name}`, {
      body: `Time to take ${schedule.dosage} at ${timeString}`,
      icon: '/icon-192x192.png',
      badge: '/icon-192x192.png',
      tag: dose.id,
      requireInteraction: true,
      actions: [
        {
          action: 'complete',
          title: 'Mark Complete'
        },
        {
          action: 'snooze',
          title: 'Remind in 5min'
        }
      ],
      data: {
        doseId: dose.id,
        scheduleId: schedule.id,
        medicationName: schedule.name
      }
    })

    // Handle notification clicks
    notification.onclick = () => {
      window.focus()
      // Navigate to the calendar page
      if (window.location.pathname !== '/calendar') {
        window.location.href = '/calendar'
      }
      notification.close()
    }

    // Mark reminder as sent
    const doses = MedicationService.getScheduledDoses()
    const doseIndex = doses.findIndex(d => d.id === dose.id)
    if (doseIndex >= 0) {
      doses[doseIndex].reminderSent = true
      doses[doseIndex].reminderSentAt = new Date().toISOString()
      localStorage.setItem('scheduled_doses', JSON.stringify(doses))
    }

    // Play sound if enabled
    this.playReminderSound()

    // Auto-close after 30 seconds if not interacted with
    setTimeout(() => {
      notification.close()
    }, 30000)
  }

  private static playReminderSound(): void {
    const settings = localStorage.getItem('app_settings')
    const soundEnabled = settings ? JSON.parse(settings).reminderSound !== false : true
    
    if (soundEnabled) {
      // Create a simple notification sound using Web Audio API
      try {
        const audioContext = new (window.AudioContext || (window as any).webkitAudioContext)()
        
        // Create a simple beep sound
        const oscillator = audioContext.createOscillator()
        const gainNode = audioContext.createGain()
        
        oscillator.connect(gainNode)
        gainNode.connect(audioContext.destination)
        
        oscillator.frequency.setValueAtTime(800, audioContext.currentTime)
        oscillator.type = 'sine'
        
        gainNode.gain.setValueAtTime(0.3, audioContext.currentTime)
        gainNode.gain.exponentialRampToValueAtTime(0.01, audioContext.currentTime + 0.5)
        
        oscillator.start(audioContext.currentTime)
        oscillator.stop(audioContext.currentTime + 0.5)
      } catch (error) {
        console.warn('Could not play notification sound:', error)
      }
    }
  }

  static snoozeNotification(doseId: string, minutes: number = 5): void {
    const doses = MedicationService.getScheduledDoses()
    const dose = doses.find(d => d.id === doseId)
    
    if (!dose) return

    const schedules = MedicationService.getSchedules()
    const schedule = schedules.find(s => s.id === dose.scheduleId)
    
    if (!schedule) return

    // Clear existing timer
    const existingTimer = this.scheduleTimers.get(doseId)
    if (existingTimer) {
      clearTimeout(existingTimer)
    }

    // Schedule new reminder
    const snoozeTime = addMinutes(new Date(), minutes)
    const timeoutMs = snoozeTime.getTime() - new Date().getTime()
    
    const timer = setTimeout(() => {
      this.sendNotification(dose, schedule)
    }, timeoutMs)

    this.scheduleTimers.set(doseId, timer)
  }

  static clearAllTimers(): void {
    this.scheduleTimers.forEach(timer => clearTimeout(timer))
    this.scheduleTimers.clear()
  }

  static clearTimerForDose(doseId: string): void {
    const timer = this.scheduleTimers.get(doseId)
    if (timer) {
      clearTimeout(timer)
      this.scheduleTimers.delete(doseId)
    }
  }

  // Service Worker registration for background notifications
  static async registerServiceWorker(): Promise<void> {
    if ('serviceWorker' in navigator) {
      try {
        const registration = await navigator.serviceWorker.register('/sw.js')
        console.log('Service Worker registered:', registration)
        
        // Listen for message from service worker
        navigator.serviceWorker.addEventListener('message', (event) => {
          if (event.data && event.data.type === 'NOTIFICATION_ACTION') {
            this.handleNotificationAction(event.data.action, event.data.doseId)
          }
        })
      } catch (error) {
        console.error('Service Worker registration failed:', error)
      }
    }
  }

  private static handleNotificationAction(action: string, doseId: string): void {
    switch (action) {
      case 'complete':
        MedicationService.markDoseCompleted(doseId, false)
        this.clearTimerForDose(doseId)
        break
      case 'snooze':
        this.snoozeNotification(doseId, 5)
        break
    }
  }

  // Test notification function
  static sendTestNotification(): void {
    if (Notification.permission === 'granted') {
      new Notification('Test Notification', {
        body: 'Your medication reminders are working correctly!',
        icon: '/icon-192x192.png',
        tag: 'test'
      })
    } else {
      console.warn('Notifications not permitted')
    }
  }

  // Check if notifications are supported and enabled
  static isSupported(): boolean {
    return 'Notification' in window
  }

  static isEnabled(): boolean {
    return this.isSupported() && Notification.permission === 'granted'
  }

  static getPermissionStatus(): NotificationPermission {
    return this.isSupported() ? Notification.permission : 'denied'
  }
}