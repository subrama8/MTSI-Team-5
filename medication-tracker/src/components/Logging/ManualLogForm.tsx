import React, { useState } from 'react'
import { format } from 'date-fns'
import { XMarkIcon } from '@heroicons/react/24/outline'
import { MedicationLog, MedicationSchedule } from '../../types/medication'
import { MedicationService } from '../../services/medication-service'

interface ManualLogFormProps {
  schedules: MedicationSchedule[]
  onSave: (log: MedicationLog) => void
  onClose: () => void
}

const ManualLogForm: React.FC<ManualLogFormProps> = ({
  schedules,
  onSave,
  onClose
}) => {
  const [formData, setFormData] = useState({
    scheduleId: '',
    medicationName: '',
    dosage: '',
    timestamp: format(new Date(), "yyyy-MM-dd'T'HH:mm"),
    notes: '',
    deviceUsed: false
  })
  const [errors, setErrors] = useState<Record<string, string>>({})

  const handleScheduleChange = (scheduleId: string) => {
    const schedule = schedules.find(s => s.id === scheduleId)
    setFormData(prev => ({
      ...prev,
      scheduleId,
      medicationName: schedule?.name || '',
      dosage: schedule?.dosage || ''
    }))
  }

  const validateForm = (): boolean => {
    const newErrors: Record<string, string> = {}

    if (!formData.medicationName.trim()) {
      newErrors.medicationName = 'Medication name is required'
    }

    if (!formData.timestamp) {
      newErrors.timestamp = 'Date and time is required'
    }

    setErrors(newErrors)
    return Object.keys(newErrors).length === 0
  }

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault()
    
    if (!validateForm()) return

    const log: MedicationLog = {
      id: MedicationService.generateId(),
      scheduleId: formData.scheduleId || undefined,
      timestamp: new Date(formData.timestamp).toISOString(),
      type: 'manual',
      medicationName: formData.medicationName,
      dosage: formData.dosage || undefined,
      notes: formData.notes || undefined,
      deviceUsed: formData.deviceUsed
    }

    onSave(log)
  }

  return (
    <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center p-4 z-50">
      <div className="bg-white rounded-3xl shadow-2xl max-w-lg w-full max-h-[90vh] overflow-y-auto">
        {/* Header */}
        <div className="flex items-center justify-between p-6 border-b border-gray-100">
          <h3 className="text-xl font-semibold text-gray-900">Add Manual Entry</h3>
          <button
            onClick={onClose}
            className="p-2 hover:bg-gray-100 rounded-xl transition-colors"
          >
            <XMarkIcon className="w-5 h-5 text-gray-500" />
          </button>
        </div>

        <form onSubmit={handleSubmit} className="p-6 space-y-6">
          {/* Existing Schedule (Optional) */}
          <div>
            <label className="block text-sm font-medium text-gray-700 mb-2">
              Existing Schedule (Optional)
            </label>
            <select
              value={formData.scheduleId}
              onChange={(e) => handleScheduleChange(e.target.value)}
              className="w-full px-4 py-3 border border-gray-300 rounded-xl focus:ring-2 focus:ring-light-blue-200 focus:border-light-blue-500"
            >
              <option value="">Select an existing medication...</option>
              {schedules.filter(s => s.isActive).map(schedule => (
                <option key={schedule.id} value={schedule.id}>
                  {schedule.name} - {schedule.dosage}
                </option>
              ))}
            </select>
            <p className="text-xs text-gray-500 mt-1">
              Choose from your scheduled medications or enter details manually below
            </p>
          </div>

          {/* Medication Name */}
          <div>
            <label className="block text-sm font-medium text-gray-700 mb-2">
              Medication Name *
            </label>
            <input
              type="text"
              value={formData.medicationName}
              onChange={(e) => setFormData(prev => ({ ...prev, medicationName: e.target.value }))}
              className="w-full px-4 py-3 border border-gray-300 rounded-xl focus:ring-2 focus:ring-light-blue-200 focus:border-light-blue-500"
              placeholder="e.g., Latanoprost"
            />
            {errors.medicationName && (
              <p className="text-red-500 text-sm mt-1">{errors.medicationName}</p>
            )}
          </div>

          {/* Dosage */}
          <div>
            <label className="block text-sm font-medium text-gray-700 mb-2">
              Dosage (Optional)
            </label>
            <input
              type="text"
              value={formData.dosage}
              onChange={(e) => setFormData(prev => ({ ...prev, dosage: e.target.value }))}
              className="w-full px-4 py-3 border border-gray-300 rounded-xl focus:ring-2 focus:ring-light-blue-200 focus:border-light-blue-500"
              placeholder="e.g., 1 drop"
            />
          </div>

          {/* Date and Time */}
          <div>
            <label className="block text-sm font-medium text-gray-700 mb-2">
              Date and Time *
            </label>
            <input
              type="datetime-local"
              value={formData.timestamp}
              onChange={(e) => setFormData(prev => ({ ...prev, timestamp: e.target.value }))}
              max={format(new Date(), "yyyy-MM-dd'T'HH:mm")}
              className="w-full px-4 py-3 border border-gray-300 rounded-xl focus:ring-2 focus:ring-light-blue-200 focus:border-light-blue-500"
            />
            {errors.timestamp && (
              <p className="text-red-500 text-sm mt-1">{errors.timestamp}</p>
            )}
          </div>

          {/* Device Used */}
          <div className="flex items-center space-x-3">
            <input
              type="checkbox"
              id="deviceUsed"
              checked={formData.deviceUsed}
              onChange={(e) => setFormData(prev => ({ ...prev, deviceUsed: e.target.checked }))}
              className="w-4 h-4 text-light-blue-600 focus:ring-light-blue-500 rounded"
            />
            <label htmlFor="deviceUsed" className="text-sm font-medium text-gray-700">
              Eye tracking device was used
            </label>
          </div>

          {/* Notes */}
          <div>
            <label className="block text-sm font-medium text-gray-700 mb-2">
              Notes (Optional)
            </label>
            <textarea
              value={formData.notes}
              onChange={(e) => setFormData(prev => ({ ...prev, notes: e.target.value }))}
              rows={3}
              className="w-full px-4 py-3 border border-gray-300 rounded-xl focus:ring-2 focus:ring-light-blue-200 focus:border-light-blue-500 resize-none"
              placeholder="Any additional notes about this medication dose..."
            />
          </div>

          {/* Action Buttons */}
          <div className="flex space-x-4 pt-6 border-t border-gray-100">
            <button
              type="button"
              onClick={onClose}
              className="flex-1 btn-secondary"
            >
              Cancel
            </button>
            <button
              type="submit"
              className="flex-1 btn-primary"
            >
              Add Entry
            </button>
          </div>
        </form>
      </div>
    </div>
  )
}

export default ManualLogForm