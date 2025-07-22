export interface MedicationSchedule {
  id: string
  name: string
  dosage: string
  frequency: 'once' | 'twice' | 'three-times' | 'four-times' | 'custom'
  customFrequency?: number
  times: string[] // Array of time strings like "08:00", "20:00"
  startDate: string // ISO date string
  endDate?: string // ISO date string, optional for ongoing medication
  isActive: boolean
  reminderMinutes: number // Minutes before to remind, default 10
  notes?: string
  color: string // Hex color for calendar display
}

export interface ScheduledDose {
  id: string
  scheduleId: string
  date: string // ISO date string (YYYY-MM-DD)
  time: string // Time string (HH:MM)
  isCompleted: boolean
  completedAt?: string // ISO datetime string
  skipped: boolean
  skippedReason?: string
  reminderSent: boolean
  reminderSentAt?: string // ISO datetime string
}

export interface MedicationLog {
  id: string
  scheduleId?: string // Optional - may be manual entry
  timestamp: string // ISO datetime string
  type: 'scheduled' | 'manual' | 'automatic'
  medicationName: string
  dosage?: string
  notes?: string
  deviceUsed: boolean // Whether the eye tracker device was used
}

export interface CalendarDay {
  date: Date
  dateString: string // YYYY-MM-DD format
  isToday: boolean
  isCurrentMonth: boolean
  scheduledDoses: ScheduledDose[]
  completedCount: number
  totalCount: number
}