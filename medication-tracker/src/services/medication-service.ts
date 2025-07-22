import { format, addDays, startOfDay, parseISO, isAfter, isBefore } from 'date-fns'
import { MedicationSchedule, ScheduledDose, MedicationLog, CalendarDay } from '../types/medication'

export class MedicationService {
  private static readonly STORAGE_KEYS = {
    SCHEDULES: 'medication_schedules',
    DOSES: 'scheduled_doses',
    LOGS: 'medication_logs'
  }

  // Schedule Management
  static getSchedules(): MedicationSchedule[] {
    const stored = localStorage.getItem(this.STORAGE_KEYS.SCHEDULES)
    return stored ? JSON.parse(stored) : []
  }

  static saveSchedule(schedule: MedicationSchedule): void {
    const schedules = this.getSchedules()
    const existingIndex = schedules.findIndex(s => s.id === schedule.id)
    
    if (existingIndex >= 0) {
      schedules[existingIndex] = schedule
    } else {
      schedules.push(schedule)
    }
    
    localStorage.setItem(this.STORAGE_KEYS.SCHEDULES, JSON.stringify(schedules))
    
    // Generate doses for this schedule
    this.generateDosesForSchedule(schedule)
  }

  static deleteSchedule(scheduleId: string): void {
    const schedules = this.getSchedules().filter(s => s.id !== scheduleId)
    localStorage.setItem(this.STORAGE_KEYS.SCHEDULES, JSON.stringify(schedules))
    
    // Remove related doses
    const doses = this.getScheduledDoses().filter(d => d.scheduleId !== scheduleId)
    localStorage.setItem(this.STORAGE_KEYS.DOSES, JSON.stringify(doses))
  }

  // Dose Management
  static getScheduledDoses(): ScheduledDose[] {
    const stored = localStorage.getItem(this.STORAGE_KEYS.DOSES)
    return stored ? JSON.parse(stored) : []
  }

  static markDoseCompleted(doseId: string, deviceUsed: boolean = false): void {
    const doses = this.getScheduledDoses()
    const dose = doses.find(d => d.id === doseId)
    
    if (dose && !dose.isCompleted) {
      dose.isCompleted = true
      dose.completedAt = new Date().toISOString()
      dose.skipped = false
      
      localStorage.setItem(this.STORAGE_KEYS.DOSES, JSON.stringify(doses))
      
      // Log the medication usage
      const schedule = this.getSchedules().find(s => s.id === dose.scheduleId)
      if (schedule) {
        this.logMedicationUsage({
          id: this.generateId(),
          scheduleId: dose.scheduleId,
          timestamp: new Date().toISOString(),
          type: deviceUsed ? 'automatic' : 'scheduled',
          medicationName: schedule.name,
          dosage: schedule.dosage,
          deviceUsed,
          notes: deviceUsed ? 'Completed via eye tracker device' : 'Marked as completed'
        })
      }
    }
  }

  static markDoseSkipped(doseId: string, reason?: string): void {
    const doses = this.getScheduledDoses()
    const dose = doses.find(d => d.id === doseId)
    
    if (dose && !dose.isCompleted && !dose.skipped) {
      dose.skipped = true
      dose.skippedReason = reason
      
      localStorage.setItem(this.STORAGE_KEYS.DOSES, JSON.stringify(doses))
    }
  }

  static getDosesForDate(date: string): ScheduledDose[] {
    return this.getScheduledDoses().filter(dose => dose.date === date)
  }

  static getUpcomingDoses(hours: number = 24): ScheduledDose[] {
    const now = new Date()
    const endTime = addDays(now, 1)
    
    return this.getScheduledDoses()
      .filter(dose => {
        if (dose.isCompleted || dose.skipped) return false
        
        const doseDateTime = parseISO(`${dose.date}T${dose.time}:00`)
        return isAfter(doseDateTime, now) && isBefore(doseDateTime, endTime)
      })
      .sort((a, b) => {
        const dateA = parseISO(`${a.date}T${a.time}:00`)
        const dateB = parseISO(`${b.date}T${b.time}:00`)
        return dateA.getTime() - dateB.getTime()
      })
  }

  // Logging
  static getMedicationLogs(): MedicationLog[] {
    const stored = localStorage.getItem(this.STORAGE_KEYS.LOGS)
    return stored ? JSON.parse(stored) : []
  }

  static logMedicationUsage(log: MedicationLog): void {
    const logs = this.getMedicationLogs()
    logs.push(log)
    localStorage.setItem(this.STORAGE_KEYS.LOGS, JSON.stringify(logs))
  }

  static getLogsForDateRange(startDate: string, endDate: string): MedicationLog[] {
    return this.getMedicationLogs()
      .filter(log => {
        const logDate = log.timestamp.split('T')[0]
        return logDate >= startDate && logDate <= endDate
      })
      .sort((a, b) => new Date(b.timestamp).getTime() - new Date(a.timestamp).getTime())
  }

  // Calendar Generation
  static generateCalendarDays(year: number, month: number): CalendarDay[] {
    const days: CalendarDay[] = []
    const firstDay = new Date(year, month, 1)
    const lastDay = new Date(year, month + 1, 0)
    const startDate = new Date(firstDay)
    
    // Start from the Sunday of the week containing the first day
    startDate.setDate(startDate.getDate() - startDate.getDay())
    
    // Generate 6 weeks worth of days
    for (let i = 0; i < 42; i++) {
      const currentDate = new Date(startDate)
      currentDate.setDate(startDate.getDate() + i)
      
      const dateString = format(currentDate, 'yyyy-MM-dd')
      const scheduledDoses = this.getDosesForDate(dateString)
      const completedCount = scheduledDoses.filter(d => d.isCompleted).length
      
      days.push({
        date: currentDate,
        dateString,
        isToday: format(currentDate, 'yyyy-MM-dd') === format(new Date(), 'yyyy-MM-dd'),
        isCurrentMonth: currentDate.getMonth() === month,
        scheduledDoses,
        completedCount,
        totalCount: scheduledDoses.length
      })
    }
    
    return days
  }

  // Dose Generation
  static generateDosesForSchedule(schedule: MedicationSchedule): void {
    if (!schedule.isActive) return
    
    const startDate = parseISO(schedule.startDate)
    const endDate = schedule.endDate ? parseISO(schedule.endDate) : addDays(new Date(), 365) // Default to 1 year
    const currentDoses = this.getScheduledDoses().filter(d => d.scheduleId === schedule.id)
    
    // Generate doses for the next 90 days or until end date
    let currentDate = new Date(Math.max(startDate.getTime(), new Date().getTime()))
    const maxDate = new Date(Math.min(endDate.getTime(), addDays(new Date(), 90).getTime()))
    
    while (currentDate <= maxDate) {
      const dateString = format(currentDate, 'yyyy-MM-dd')
      
      // Check if doses already exist for this date
      const existingDoses = currentDoses.filter(d => d.date === dateString)
      
      if (existingDoses.length === 0) {
        // Generate doses for this date
        schedule.times.forEach(time => {
          const dose: ScheduledDose = {
            id: this.generateId(),
            scheduleId: schedule.id,
            date: dateString,
            time,
            isCompleted: false,
            skipped: false,
            reminderSent: false
          }
          
          currentDoses.push(dose)
        })
      }
      
      currentDate = addDays(currentDate, 1)
    }
    
    // Save all doses
    const allDoses = this.getScheduledDoses().filter(d => d.scheduleId !== schedule.id)
    allDoses.push(...currentDoses)
    localStorage.setItem(this.STORAGE_KEYS.DOSES, JSON.stringify(allDoses))
  }

  static generateDosesForAllSchedules(): void {
    const schedules = this.getSchedules().filter(s => s.isActive)
    schedules.forEach(schedule => this.generateDosesForSchedule(schedule))
  }

  // Utility
  static generateId(): string {
    return Date.now().toString(36) + Math.random().toString(36).substr(2)
  }

  static getDefaultSchedule(): Partial<MedicationSchedule> {
    return {
      name: '',
      dosage: '',
      frequency: 'twice',
      times: ['08:00', '20:00'],
      startDate: format(new Date(), 'yyyy-MM-dd'),
      isActive: true,
      reminderMinutes: 10,
      color: '#0ea5e9'
    }
  }

  // Statistics
  static getComplianceStats(days: number = 30): { total: number; completed: number; percentage: number } {
    const endDate = new Date()
    const startDate = addDays(endDate, -days)
    
    const doses = this.getScheduledDoses().filter(dose => {
      const doseDate = parseISO(dose.date)
      return doseDate >= startDate && doseDate <= endDate
    })
    
    const total = doses.length
    const completed = doses.filter(d => d.isCompleted).length
    const percentage = total > 0 ? Math.round((completed / total) * 100) : 0
    
    return { total, completed, percentage }
  }
}