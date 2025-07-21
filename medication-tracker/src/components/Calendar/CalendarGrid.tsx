import React from 'react'
import { format } from 'date-fns'
import { CalendarDay } from '../../types/medication'

interface CalendarGridProps {
  days: CalendarDay[]
  onDayClick: (day: CalendarDay) => void
  selectedDay: CalendarDay | null
}

const CalendarGrid: React.FC<CalendarGridProps> = ({
  days,
  onDayClick,
  selectedDay
}) => {
  const weekdays = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat']

  const getDayClasses = (day: CalendarDay) => {
    let classes = 'calendar-day relative'
    
    if (!day.isCurrentMonth) {
      classes += ' opacity-30'
    }
    
    if (day.isToday) {
      classes += ' calendar-day-today'
    }
    
    if (day.totalCount > 0) {
      classes += ' calendar-day-has-medication'
    }
    
    if (selectedDay && day.dateString === selectedDay.dateString) {
      classes += ' calendar-day-selected'
    }
    
    return classes
  }

  const getCompletionColor = (day: CalendarDay) => {
    if (day.totalCount === 0) return 'transparent'
    
    const percentage = day.completedCount / day.totalCount
    
    if (percentage === 1) return '#10b981' // green-500
    if (percentage >= 0.5) return '#f59e0b' // amber-500
    return '#ef4444' // red-500
  }

  return (
    <div className="w-full">
      {/* Weekday Headers */}
      <div className="grid grid-cols-7 gap-1 mb-2">
        {weekdays.map(day => (
          <div key={day} className="text-center py-2">
            <span className="text-sm font-medium text-gray-600">{day}</span>
          </div>
        ))}
      </div>

      {/* Calendar Days */}
      <div className="grid grid-cols-7 gap-1">
        {days.map((day, index) => (
          <button
            key={index}
            onClick={() => onDayClick(day)}
            className={getDayClasses(day)}
            disabled={!day.isCurrentMonth}
          >
            <span className="relative z-10">
              {format(day.date, 'd')}
            </span>
            
            {/* Medication indicator dots */}
            {day.totalCount > 0 && (
              <div className="absolute bottom-1 left-1/2 transform -translate-x-1/2 flex space-x-1">
                {Array.from({ length: Math.min(day.totalCount, 3) }, (_, i) => {
                  const isCompleted = i < day.completedCount
                  return (
                    <div
                      key={i}
                      className={`w-1.5 h-1.5 rounded-full ${
                        isCompleted ? 'bg-green-500' : 'bg-gray-300'
                      }`}
                    />
                  )
                })}
                {day.totalCount > 3 && (
                  <span className="text-xs text-gray-500 ml-1">+{day.totalCount - 3}</span>
                )}
              </div>
            )}

            {/* Completion ring for days with medications */}
            {day.totalCount > 0 && (
              <div className="absolute inset-0 rounded-xl">
                <svg className="w-full h-full" viewBox="0 0 48 48">
                  <circle
                    cx="24"
                    cy="24"
                    r="20"
                    fill="none"
                    stroke="#e5e7eb"
                    strokeWidth="2"
                  />
                  <circle
                    cx="24"
                    cy="24"
                    r="20"
                    fill="none"
                    stroke={getCompletionColor(day)}
                    strokeWidth="2"
                    strokeDasharray={`${2 * Math.PI * 20}`}
                    strokeDashoffset={`${2 * Math.PI * 20 * (1 - day.completedCount / day.totalCount)}`}
                    strokeLinecap="round"
                    transform="rotate(-90 24 24)"
                    className="transition-all duration-300"
                  />
                </svg>
              </div>
            )}
          </button>
        ))}
      </div>
    </div>
  )
}

export default CalendarGrid