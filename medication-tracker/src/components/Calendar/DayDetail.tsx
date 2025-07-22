import React, { useState } from 'react'
import { format } from 'date-fns'
import { XMarkIcon, CheckIcon, ClockIcon } from '@heroicons/react/24/outline'
import { CalendarDay, MedicationSchedule, ScheduledDose } from '../../types/medication'

interface DayDetailProps {
  day: CalendarDay
  schedules: MedicationSchedule[]
  onClose: () => void
  onComplete: (doseId: string, deviceUsed?: boolean) => void
  onSkip: (doseId: string, reason?: string) => void
}

const DayDetail: React.FC<DayDetailProps> = ({
  day,
  schedules,
  onClose,
  onComplete,
  onSkip
}) => {
  const [skipReason, setSkipReason] = useState('')
  const [showSkipDialog, setShowSkipDialog] = useState<string | null>(null)

  const getScheduleForDose = (dose: ScheduledDose) => {
    return schedules.find(s => s.id === dose.scheduleId)
  }

  const sortedDoses = [...day.scheduledDoses].sort((a, b) => {
    return a.time.localeCompare(b.time)
  })

  const handleSkipWithReason = (doseId: string) => {
    onSkip(doseId, skipReason || 'No reason provided')
    setShowSkipDialog(null)
    setSkipReason('')
  }

  const getDoseStatus = (dose: ScheduledDose) => {
    if (dose.isCompleted) return { label: 'Completed', color: 'text-green-600', bgColor: 'bg-green-100' }
    if (dose.skipped) return { label: 'Skipped', color: 'text-yellow-600', bgColor: 'bg-yellow-100' }
    return { label: 'Pending', color: 'text-gray-600', bgColor: 'bg-gray-100' }
  }

  return (
    <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center p-4 z-50">
      <div className="bg-white rounded-3xl shadow-2xl max-w-md w-full max-h-[90vh] overflow-y-auto">
        {/* Header */}
        <div className="flex items-center justify-between p-6 border-b border-gray-100">
          <div>
            <h3 className="text-xl font-semibold text-gray-900">
              {format(day.date, 'EEEE, MMMM d')}
            </h3>
            {day.isToday && (
              <span className="text-sm text-light-blue-600 font-medium">Today</span>
            )}
          </div>
          <button
            onClick={onClose}
            className="p-2 hover:bg-gray-100 rounded-xl transition-colors"
          >
            <XMarkIcon className="w-5 h-5 text-gray-500" />
          </button>
        </div>

        <div className="p-6">
          {sortedDoses.length === 0 ? (
            <div className="text-center py-8">
              <ClockIcon className="w-12 h-12 text-gray-300 mx-auto mb-3" />
              <p className="text-gray-500">No scheduled medications for this day</p>
            </div>
          ) : (
            <>
              {/* Summary */}
              <div className="bg-light-blue-50 rounded-2xl p-4 mb-6">
                <div className="flex items-center justify-between">
                  <div>
                    <h4 className="font-medium text-gray-900">Daily Summary</h4>
                    <p className="text-sm text-gray-600">
                      {day.completedCount} of {day.totalCount} doses completed
                    </p>
                  </div>
                  <div className="text-right">
                    <span className="text-2xl font-bold text-light-blue-600">
                      {day.totalCount > 0 ? Math.round((day.completedCount / day.totalCount) * 100) : 0}%
                    </span>
                  </div>
                </div>
                
                {/* Progress Bar */}
                <div className="w-full bg-gray-200 rounded-full h-2 mt-3">
                  <div 
                    className="bg-light-blue-500 h-2 rounded-full transition-all duration-300"
                    style={{ width: `${day.totalCount > 0 ? (day.completedCount / day.totalCount) * 100 : 0}%` }}
                  />
                </div>
              </div>

              {/* Doses List */}
              <div className="space-y-4">
                <h4 className="font-medium text-gray-900">Scheduled Doses</h4>
                
                {sortedDoses.map(dose => {
                  const schedule = getScheduleForDose(dose)
                  if (!schedule) return null

                  const status = getDoseStatus(dose)

                  return (
                    <div key={dose.id} className="border border-gray-200 rounded-2xl p-4">
                      <div className="flex items-start justify-between mb-3">
                        <div className="flex-1">
                          <div className="flex items-center space-x-2 mb-1">
                            <div 
                              className="w-3 h-3 rounded-full"
                              style={{ backgroundColor: schedule.color }}
                            />
                            <h5 className="font-medium text-gray-900">{schedule.name}</h5>
                            <span className={`text-xs font-medium px-2 py-1 rounded-full ${status.bgColor} ${status.color}`}>
                              {status.label}
                            </span>
                          </div>
                          
                          <div className="text-sm text-gray-600 space-y-0.5">
                            <p><strong>Time:</strong> {dose.time}</p>
                            <p><strong>Dosage:</strong> {schedule.dosage}</p>
                            {dose.completedAt && (
                              <p><strong>Completed at:</strong> {format(new Date(dose.completedAt), 'h:mm a')}</p>
                            )}
                            {dose.skipped && dose.skippedReason && (
                              <p><strong>Skip reason:</strong> {dose.skippedReason}</p>
                            )}
                            {schedule.notes && (
                              <p><strong>Notes:</strong> {schedule.notes}</p>
                            )}
                          </div>
                        </div>
                      </div>

                      {/* Actions */}
                      {!dose.isCompleted && !dose.skipped && (
                        <div className="flex space-x-2">
                          <button
                            onClick={() => onComplete(dose.id, false)}
                            className="flex-1 bg-green-500 hover:bg-green-600 text-white py-2 px-4 rounded-lg text-sm font-medium transition-colors flex items-center justify-center space-x-1"
                          >
                            <CheckIcon className="w-4 h-4" />
                            <span>Mark Complete</span>
                          </button>
                          
                          <button
                            onClick={() => setShowSkipDialog(dose.id)}
                            className="bg-gray-400 hover:bg-gray-500 text-white py-2 px-4 rounded-lg text-sm font-medium transition-colors"
                          >
                            Skip
                          </button>
                        </div>
                      )}
                    </div>
                  )
                })}
              </div>
            </>
          )}
        </div>

        {/* Skip Dialog */}
        {showSkipDialog && (
          <div className="absolute inset-0 bg-black bg-opacity-50 flex items-center justify-center p-4">
            <div className="bg-white rounded-2xl p-6 w-full max-w-sm">
              <h4 className="text-lg font-semibold text-gray-900 mb-4">Skip Dose</h4>
              
              <div className="mb-4">
                <label className="block text-sm font-medium text-gray-700 mb-2">
                  Reason (optional)
                </label>
                <textarea
                  value={skipReason}
                  onChange={(e) => setSkipReason(e.target.value)}
                  rows={3}
                  className="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-light-blue-200 focus:border-light-blue-500 resize-none"
                  placeholder="e.g., Forgot, Away from home, Side effects..."
                />
              </div>
              
              <div className="flex space-x-3">
                <button
                  onClick={() => {
                    setShowSkipDialog(null)
                    setSkipReason('')
                  }}
                  className="flex-1 btn-secondary py-2 px-4 text-sm"
                >
                  Cancel
                </button>
                <button
                  onClick={() => handleSkipWithReason(showSkipDialog)}
                  className="flex-1 bg-yellow-500 hover:bg-yellow-600 text-white py-2 px-4 rounded-lg text-sm font-medium transition-colors"
                >
                  Skip Dose
                </button>
              </div>
            </div>
          </div>
        )}
      </div>
    </div>
  )
}

export default DayDetail