import React from 'react'
import { format, parseISO } from 'date-fns'
import { ClockIcon, CheckIcon, XMarkIcon } from '@heroicons/react/24/outline'
import { ScheduledDose, MedicationSchedule } from '../../types/medication'

interface UpcomingDosesProps {
  doses: ScheduledDose[]
  schedules: MedicationSchedule[]
  onComplete: (doseId: string, deviceUsed?: boolean) => void
  onSkip: (doseId: string, reason?: string) => void
}

const UpcomingDoses: React.FC<UpcomingDosesProps> = ({
  doses,
  schedules,
  onComplete,
  onSkip
}) => {
  const getScheduleForDose = (dose: ScheduledDose) => {
    return schedules.find(s => s.id === dose.scheduleId)
  }

  const getTimeUntilDose = (dose: ScheduledDose) => {
    const doseTime = parseISO(`${dose.date}T${dose.time}:00`)
    const now = new Date()
    const diffMinutes = Math.floor((doseTime.getTime() - now.getTime()) / (1000 * 60))
    
    if (diffMinutes < 0) return 'Overdue'
    if (diffMinutes < 60) return `${diffMinutes}m`
    if (diffMinutes < 1440) return `${Math.floor(diffMinutes / 60)}h ${diffMinutes % 60}m`
    return `${Math.floor(diffMinutes / 1440)}d`
  }

  if (doses.length === 0) return null

  return (
    <div className="card">
      <div className="flex items-center space-x-3 mb-4">
        <ClockIcon className="w-6 h-6 text-light-blue-500" />
        <h3 className="text-lg font-semibold text-gray-900">Upcoming Doses</h3>
        <span className="bg-light-blue-100 text-light-blue-800 text-xs font-medium px-2.5 py-0.5 rounded-full">
          {doses.length}
        </span>
      </div>

      <div className="space-y-3">
        {doses.slice(0, 3).map(dose => {
          const schedule = getScheduleForDose(dose)
          if (!schedule) return null

          const doseTime = parseISO(`${dose.date}T${dose.time}:00`)
          const timeUntil = getTimeUntilDose(dose)
          const isOverdue = timeUntil === 'Overdue'

          return (
            <div 
              key={dose.id}
              className={`p-4 rounded-2xl border-2 ${
                isOverdue 
                  ? 'bg-red-50 border-red-200' 
                  : 'bg-light-blue-50 border-light-blue-200'
              }`}
            >
              <div className="flex items-center justify-between">
                <div className="flex-1">
                  <div className="flex items-center space-x-2 mb-1">
                    <div 
                      className="w-3 h-3 rounded-full"
                      style={{ backgroundColor: schedule.color }}
                    />
                    <h4 className="font-medium text-gray-900">{schedule.name}</h4>
                    <span className={`text-xs font-medium px-2 py-1 rounded-full ${
                      isOverdue 
                        ? 'bg-red-200 text-red-800'
                        : 'bg-light-blue-200 text-light-blue-800'
                    }`}>
                      {timeUntil}
                    </span>
                  </div>
                  
                  <div className="text-sm text-gray-600 mb-2">
                    <p><strong>Dosage:</strong> {schedule.dosage}</p>
                    <p><strong>Time:</strong> {format(doseTime, 'h:mm a')}</p>
                    {format(doseTime, 'yyyy-MM-dd') !== format(new Date(), 'yyyy-MM-dd') && (
                      <p><strong>Date:</strong> {format(doseTime, 'MMM d')}</p>
                    )}
                  </div>

                  <div className="flex space-x-2">
                    <button
                      onClick={() => onComplete(dose.id, false)}
                      className="flex items-center space-x-1 bg-green-500 hover:bg-green-600 text-white px-3 py-1.5 rounded-lg text-xs font-medium transition-colors"
                    >
                      <CheckIcon className="w-3 h-3" />
                      <span>Complete</span>
                    </button>
                    
                    <button
                      onClick={() => onSkip(dose.id, 'Manual skip')}
                      className="flex items-center space-x-1 bg-gray-400 hover:bg-gray-500 text-white px-3 py-1.5 rounded-lg text-xs font-medium transition-colors"
                    >
                      <XMarkIcon className="w-3 h-3" />
                      <span>Skip</span>
                    </button>
                  </div>
                </div>
              </div>
            </div>
          )
        })}
      </div>

      {doses.length > 3 && (
        <div className="text-center mt-4">
          <p className="text-sm text-gray-500">
            +{doses.length - 3} more dose{doses.length - 3 !== 1 ? 's' : ''} scheduled
          </p>
        </div>
      )}
    </div>
  )
}

export default UpcomingDoses