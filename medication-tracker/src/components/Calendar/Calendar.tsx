import React, { useState, useEffect } from 'react'
import { format, addMonths, subMonths, startOfMonth } from 'date-fns'
import { 
  ChevronLeftIcon, 
  ChevronRightIcon, 
  PlusIcon,
  CalendarDaysIcon,
  ClockIcon
} from '@heroicons/react/24/outline'
import { MedicationService } from '../../services/medication-service'
import { CalendarDay, MedicationSchedule, ScheduledDose } from '../../types/medication'
import CalendarGrid from './CalendarGrid'
import ScheduleForm from './ScheduleForm'
import DayDetail from './DayDetail'
import UpcomingDoses from './UpcomingDoses'

const Calendar: React.FC = () => {
  const [currentDate, setCurrentDate] = useState(new Date())
  const [calendarDays, setCalendarDays] = useState<CalendarDay[]>([])
  const [schedules, setSchedules] = useState<MedicationSchedule[]>([])
  const [selectedDay, setSelectedDay] = useState<CalendarDay | null>(null)
  const [showScheduleForm, setShowScheduleForm] = useState(false)
  const [editingSchedule, setEditingSchedule] = useState<MedicationSchedule | null>(null)
  const [upcomingDoses, setUpcomingDoses] = useState<ScheduledDose[]>([])

  useEffect(() => {
    loadData()
  }, [currentDate])

  useEffect(() => {
    // Refresh upcoming doses every minute
    const interval = setInterval(() => {
      setUpcomingDoses(MedicationService.getUpcomingDoses())
    }, 60000)
    
    return () => clearInterval(interval)
  }, [])

  const loadData = () => {
    const year = currentDate.getFullYear()
    const month = currentDate.getMonth()
    
    setCalendarDays(MedicationService.generateCalendarDays(year, month))
    setSchedules(MedicationService.getSchedules())
    setUpcomingDoses(MedicationService.getUpcomingDoses())
  }

  const navigateMonth = (direction: 'prev' | 'next') => {
    setCurrentDate(prev => 
      direction === 'prev' ? subMonths(prev, 1) : addMonths(prev, 1)
    )
  }

  const handleDayClick = (day: CalendarDay) => {
    setSelectedDay(day)
  }

  const handleScheduleSave = (schedule: MedicationSchedule) => {
    MedicationService.saveSchedule(schedule)
    setShowScheduleForm(false)
    setEditingSchedule(null)
    loadData()
  }

  const handleScheduleEdit = (schedule: MedicationSchedule) => {
    setEditingSchedule(schedule)
    setShowScheduleForm(true)
  }

  const handleScheduleDelete = (scheduleId: string) => {
    if (confirm('Are you sure you want to delete this medication schedule?')) {
      MedicationService.deleteSchedule(scheduleId)
      loadData()
    }
  }

  const handleDoseComplete = (doseId: string, deviceUsed: boolean = false) => {
    MedicationService.markDoseCompleted(doseId, deviceUsed)
    loadData()
  }

  const handleDoseSkip = (doseId: string, reason?: string) => {
    MedicationService.markDoseSkipped(doseId, reason)
    loadData()
  }

  const monthYear = format(currentDate, 'MMMM yyyy')
  const complianceStats = MedicationService.getComplianceStats(30)

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="text-center">
        <h2 className="text-3xl font-bold text-gray-900 mb-2">Medication Schedule</h2>
        <p className="text-gray-600">Plan and track your eye medication routine</p>
      </div>

      {/* Upcoming Doses */}
      {upcomingDoses.length > 0 && (
        <UpcomingDoses 
          doses={upcomingDoses}
          schedules={schedules}
          onComplete={handleDoseComplete}
          onSkip={handleDoseSkip}
        />
      )}

      {/* Statistics Card */}
      <div className="card">
        <div className="flex items-center justify-between mb-4">
          <div className="flex items-center space-x-3">
            <CalendarDaysIcon className="w-6 h-6 text-light-blue-500" />
            <h3 className="text-lg font-semibold text-gray-900">30-Day Compliance</h3>
          </div>
          <div className="text-right">
            <p className="text-2xl font-bold text-light-blue-600">{complianceStats.percentage}%</p>
            <p className="text-sm text-gray-500">
              {complianceStats.completed} of {complianceStats.total} doses
            </p>
          </div>
        </div>
        
        {/* Progress Bar */}
        <div className="w-full bg-gray-200 rounded-full h-3">
          <div 
            className="bg-light-blue-500 h-3 rounded-full transition-all duration-300"
            style={{ width: `${complianceStats.percentage}%` }}
          ></div>
        </div>
      </div>

      {/* Calendar Controls */}
      <div className="card">
        <div className="flex items-center justify-between mb-6">
          <button
            onClick={() => navigateMonth('prev')}
            className="p-3 hover:bg-gray-100 rounded-xl transition-colors"
          >
            <ChevronLeftIcon className="w-6 h-6 text-gray-600" />
          </button>
          
          <h3 className="text-xl font-bold text-gray-900">{monthYear}</h3>
          
          <button
            onClick={() => navigateMonth('next')}
            className="p-3 hover:bg-gray-100 rounded-xl transition-colors"
          >
            <ChevronRightIcon className="w-6 h-6 text-gray-600" />
          </button>
        </div>

        {/* Calendar Grid */}
        <CalendarGrid
          days={calendarDays}
          onDayClick={handleDayClick}
          selectedDay={selectedDay}
        />
      </div>

      {/* Active Schedules */}
      <div className="card">
        <div className="flex items-center justify-between mb-6">
          <div className="flex items-center space-x-3">
            <ClockIcon className="w-6 h-6 text-light-blue-500" />
            <h3 className="text-lg font-semibold text-gray-900">Active Schedules</h3>
          </div>
          
          <button
            onClick={() => setShowScheduleForm(true)}
            className="btn-primary flex items-center space-x-2 py-3 px-4 text-sm"
          >
            <PlusIcon className="w-4 h-4" />
            <span>Add Schedule</span>
          </button>
        </div>

        {schedules.filter(s => s.isActive).length === 0 ? (
          <div className="text-center py-8">
            <CalendarDaysIcon className="w-12 h-12 text-gray-300 mx-auto mb-3" />
            <p className="text-gray-500 mb-4">No medication schedules yet</p>
            <button
              onClick={() => setShowScheduleForm(true)}
              className="btn-secondary text-sm py-2 px-4"
            >
              Create First Schedule
            </button>
          </div>
        ) : (
          <div className="space-y-4">
            {schedules.filter(s => s.isActive).map(schedule => (
              <div key={schedule.id} className="bg-gray-50 rounded-2xl p-4">
                <div className="flex items-start justify-between">
                  <div className="flex-1">
                    <div className="flex items-center space-x-3 mb-2">
                      <div 
                        className="w-4 h-4 rounded-full"
                        style={{ backgroundColor: schedule.color }}
                      ></div>
                      <h4 className="font-medium text-gray-900">{schedule.name}</h4>
                    </div>
                    
                    <div className="text-sm text-gray-600 space-y-1">
                      <p><strong>Dosage:</strong> {schedule.dosage}</p>
                      <p><strong>Times:</strong> {schedule.times.join(', ')}</p>
                      <p><strong>Reminder:</strong> {schedule.reminderMinutes} minutes before</p>
                      {schedule.notes && <p><strong>Notes:</strong> {schedule.notes}</p>}
                    </div>
                  </div>
                  
                  <div className="flex space-x-2">
                    <button
                      onClick={() => handleScheduleEdit(schedule)}
                      className="text-light-blue-600 hover:text-light-blue-700 text-sm font-medium"
                    >
                      Edit
                    </button>
                    <button
                      onClick={() => handleScheduleDelete(schedule.id)}
                      className="text-red-600 hover:text-red-700 text-sm font-medium"
                    >
                      Delete
                    </button>
                  </div>
                </div>
              </div>
            ))}
          </div>
        )}
      </div>

      {/* Schedule Form Modal */}
      {showScheduleForm && (
        <ScheduleForm
          schedule={editingSchedule}
          onSave={handleScheduleSave}
          onClose={() => {
            setShowScheduleForm(false)
            setEditingSchedule(null)
          }}
        />
      )}

      {/* Day Detail Modal */}
      {selectedDay && (
        <DayDetail
          day={selectedDay}
          schedules={schedules}
          onClose={() => setSelectedDay(null)}
          onComplete={handleDoseComplete}
          onSkip={handleDoseSkip}
        />
      )}
    </div>
  )
}

export default Calendar