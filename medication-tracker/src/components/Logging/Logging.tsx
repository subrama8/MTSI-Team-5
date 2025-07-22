import React, { useState, useEffect } from 'react'
import { format, subDays, startOfDay } from 'date-fns'
import { 
  ClipboardDocumentListIcon, 
  PlusIcon, 
  EyeIcon,
  DevicePhoneMobileIcon,
  UserIcon,
  CalendarIcon,
  TrashIcon
} from '@heroicons/react/24/outline'
import { MedicationService } from '../../services/medication-service'
import { MedicationLog, MedicationSchedule } from '../../types/medication'
import ManualLogForm from './ManualLogForm'

const Logging: React.FC = () => {
  const [logs, setLogs] = useState<MedicationLog[]>([])
  const [schedules, setSchedules] = useState<MedicationSchedule[]>([])
  const [selectedPeriod, setSelectedPeriod] = useState('7') // days
  const [showManualForm, setShowManualForm] = useState(false)
  const [filter, setFilter] = useState<'all' | 'scheduled' | 'manual' | 'automatic'>('all')

  useEffect(() => {
    loadLogs()
  }, [selectedPeriod])

  const loadLogs = () => {
    const days = parseInt(selectedPeriod)
    const endDate = format(new Date(), 'yyyy-MM-dd')
    const startDate = format(subDays(new Date(), days - 1), 'yyyy-MM-dd')
    
    const allLogs = MedicationService.getLogsForDateRange(startDate, endDate)
    setLogs(allLogs)
    setSchedules(MedicationService.getSchedules())
  }

  const handleManualLogSave = (log: MedicationLog) => {
    MedicationService.logMedicationUsage(log)
    setShowManualForm(false)
    loadLogs()
  }

  const deleteLog = (logId: string) => {
    if (confirm('Are you sure you want to delete this log entry?')) {
      const allLogs = MedicationService.getMedicationLogs()
      const updatedLogs = allLogs.filter(log => log.id !== logId)
      localStorage.setItem('medication_logs', JSON.stringify(updatedLogs))
      loadLogs()
    }
  }

  const filteredLogs = logs.filter(log => {
    if (filter === 'all') return true
    return log.type === filter
  })

  const getLogIcon = (log: MedicationLog) => {
    switch (log.type) {
      case 'automatic':
        return <DevicePhoneMobileIcon className="w-5 h-5 text-green-500" />
      case 'scheduled':
        return <CalendarIcon className="w-5 h-5 text-blue-500" />
      case 'manual':
        return <UserIcon className="w-5 h-5 text-purple-500" />
      default:
        return <ClipboardDocumentListIcon className="w-5 h-5 text-gray-500" />
    }
  }

  const getLogTypeLabel = (type: string) => {
    switch (type) {
      case 'automatic': return 'Device Used'
      case 'scheduled': return 'Scheduled'
      case 'manual': return 'Manual Entry'
      default: return 'Unknown'
    }
  }

  const getLogTypeColor = (type: string) => {
    switch (type) {
      case 'automatic': return 'bg-green-100 text-green-800'
      case 'scheduled': return 'bg-blue-100 text-blue-800'
      case 'manual': return 'bg-purple-100 text-purple-800'
      default: return 'bg-gray-100 text-gray-800'
    }
  }

  const getStats = () => {
    const total = filteredLogs.length
    const deviceUsed = filteredLogs.filter(log => log.deviceUsed).length
    const manual = filteredLogs.filter(log => log.type === 'manual').length
    const scheduled = filteredLogs.filter(log => log.type === 'scheduled').length
    
    return { total, deviceUsed, manual, scheduled }
  }

  const stats = getStats()

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="text-center">
        <h2 className="text-3xl font-bold text-gray-900 mb-2">Medication History</h2>
        <p className="text-gray-600">Track and review your medication usage</p>
      </div>

      {/* Statistics Cards */}
      <div className="grid grid-cols-2 gap-4">
        <div className="card text-center">
          <div className="text-2xl font-bold text-light-blue-600 mb-1">{stats.total}</div>
          <div className="text-sm text-gray-600">Total Doses</div>
        </div>
        
        <div className="card text-center">
          <div className="text-2xl font-bold text-green-600 mb-1">{stats.deviceUsed}</div>
          <div className="text-sm text-gray-600">Device Assisted</div>
        </div>
      </div>

      {/* Controls */}
      <div className="card">
        <div className="flex flex-col sm:flex-row gap-4 items-start sm:items-center justify-between">
          <div className="flex items-center space-x-4">
            {/* Time Period */}
            <div>
              <label className="block text-sm font-medium text-gray-700 mb-1">
                Time Period
              </label>
              <select
                value={selectedPeriod}
                onChange={(e) => setSelectedPeriod(e.target.value)}
                className="px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-light-blue-200 focus:border-light-blue-500"
              >
                <option value="7">Last 7 days</option>
                <option value="14">Last 14 days</option>
                <option value="30">Last 30 days</option>
                <option value="90">Last 90 days</option>
              </select>
            </div>

            {/* Filter */}
            <div>
              <label className="block text-sm font-medium text-gray-700 mb-1">
                Filter
              </label>
              <select
                value={filter}
                onChange={(e) => setFilter(e.target.value as any)}
                className="px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-light-blue-200 focus:border-light-blue-500"
              >
                <option value="all">All Entries</option>
                <option value="automatic">Device Assisted</option>
                <option value="scheduled">Scheduled</option>
                <option value="manual">Manual</option>
              </select>
            </div>
          </div>

          {/* Add Manual Entry */}
          <button
            onClick={() => setShowManualForm(true)}
            className="btn-primary flex items-center space-x-2 py-3 px-4 text-sm whitespace-nowrap"
          >
            <PlusIcon className="w-4 h-4" />
            <span>Add Entry</span>
          </button>
        </div>
      </div>

      {/* Logs List */}
      <div className="card">
        {filteredLogs.length === 0 ? (
          <div className="text-center py-8">
            <ClipboardDocumentListIcon className="w-12 h-12 text-gray-300 mx-auto mb-3" />
            <p className="text-gray-500 mb-4">
              {filter === 'all' 
                ? 'No medication logs found for this period'
                : `No ${filter} logs found for this period`
              }
            </p>
            {filter !== 'all' && (
              <button
                onClick={() => setFilter('all')}
                className="btn-secondary text-sm py-2 px-4"
              >
                Show All Logs
              </button>
            )}
          </div>
        ) : (
          <div className="space-y-4">
            <div className="flex items-center justify-between">
              <h3 className="text-lg font-semibold text-gray-900">
                Medication Entries ({filteredLogs.length})
              </h3>
              <EyeIcon className="w-5 h-5 text-gray-400" />
            </div>

            <div className="space-y-3">
              {filteredLogs.map(log => (
                <div key={log.id} className="border border-gray-200 rounded-2xl p-4">
                  <div className="flex items-start justify-between">
                    <div className="flex items-start space-x-3 flex-1">
                      {getLogIcon(log)}
                      
                      <div className="flex-1">
                        <div className="flex items-center space-x-2 mb-1">
                          <h4 className="font-medium text-gray-900">{log.medicationName}</h4>
                          <span className={`text-xs font-medium px-2 py-1 rounded-full ${getLogTypeColor(log.type)}`}>
                            {getLogTypeLabel(log.type)}
                          </span>
                          {log.deviceUsed && (
                            <span className="text-xs font-medium px-2 py-1 rounded-full bg-green-100 text-green-800">
                              Device Used
                            </span>
                          )}
                        </div>
                        
                        <div className="text-sm text-gray-600 space-y-0.5">
                          <p>
                            <strong>Date & Time:</strong> {format(new Date(log.timestamp), 'MMM d, h:mm a')}
                          </p>
                          {log.dosage && (
                            <p><strong>Dosage:</strong> {log.dosage}</p>
                          )}
                          {log.notes && (
                            <p><strong>Notes:</strong> {log.notes}</p>
                          )}
                        </div>
                      </div>
                    </div>
                    
                    {log.type === 'manual' && (
                      <button
                        onClick={() => deleteLog(log.id)}
                        className="p-2 text-red-400 hover:text-red-600 hover:bg-red-50 rounded-lg transition-colors"
                        title="Delete manual entry"
                      >
                        <TrashIcon className="w-4 h-4" />
                      </button>
                    )}
                  </div>
                </div>
              ))}
            </div>
          </div>
        )}
      </div>

      {/* Manual Log Form Modal */}
      {showManualForm && (
        <ManualLogForm
          schedules={schedules}
          onSave={handleManualLogSave}
          onClose={() => setShowManualForm(false)}
        />
      )}
    </div>
  )
}

export default Logging