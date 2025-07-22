import React, { useState, useEffect } from 'react'
import { XMarkIcon, PlusIcon, MinusIcon } from '@heroicons/react/24/outline'
import { MedicationSchedule } from '../../types/medication'
import { MedicationService } from '../../services/medication-service'

interface ScheduleFormProps {
  schedule: MedicationSchedule | null
  onSave: (schedule: MedicationSchedule) => void
  onClose: () => void
}

const ScheduleForm: React.FC<ScheduleFormProps> = ({
  schedule,
  onSave,
  onClose
}) => {
  const [formData, setFormData] = useState<Partial<MedicationSchedule>>(
    schedule || MedicationService.getDefaultSchedule()
  )
  const [errors, setErrors] = useState<Record<string, string>>({})

  useEffect(() => {
    if (schedule) {
      setFormData(schedule)
    }
  }, [schedule])

  const frequencyOptions = [
    { value: 'once', label: 'Once daily', times: ['08:00'] },
    { value: 'twice', label: 'Twice daily', times: ['08:00', '20:00'] },
    { value: 'three-times', label: 'Three times daily', times: ['08:00', '14:00', '20:00'] },
    { value: 'four-times', label: 'Four times daily', times: ['08:00', '12:00', '16:00', '20:00'] },
    { value: 'custom', label: 'Custom schedule', times: [] }
  ]

  const colorOptions = [
    '#0ea5e9', // light-blue-500
    '#10b981', // emerald-500
    '#f59e0b', // amber-500
    '#ef4444', // red-500
    '#8b5cf6', // violet-500
    '#06b6d4', // cyan-500
    '#84cc16', // lime-500
    '#f97316'  // orange-500
  ]

  const handleFrequencyChange = (frequency: string) => {
    const option = frequencyOptions.find(opt => opt.value === frequency)
    if (option && option.value !== 'custom') {
      setFormData(prev => ({
        ...prev,
        frequency: frequency as any,
        times: [...option.times]
      }))
    } else {
      setFormData(prev => ({
        ...prev,
        frequency: 'custom',
        times: prev.times?.length ? prev.times : ['08:00']
      }))
    }
  }

  const addCustomTime = () => {
    setFormData(prev => ({
      ...prev,
      times: [...(prev.times || []), '09:00']
    }))
  }

  const removeCustomTime = (index: number) => {
    setFormData(prev => ({
      ...prev,
      times: prev.times?.filter((_, i) => i !== index) || []
    }))
  }

  const updateTime = (index: number, time: string) => {
    setFormData(prev => ({
      ...prev,
      times: prev.times?.map((t, i) => i === index ? time : t) || []
    }))
  }

  const validateForm = (): boolean => {
    const newErrors: Record<string, string> = {}

    if (!formData.name?.trim()) {
      newErrors.name = 'Medication name is required'
    }

    if (!formData.dosage?.trim()) {
      newErrors.dosage = 'Dosage is required'
    }

    if (!formData.times?.length) {
      newErrors.times = 'At least one time is required'
    }

    if (!formData.startDate) {
      newErrors.startDate = 'Start date is required'
    }

    setErrors(newErrors)
    return Object.keys(newErrors).length === 0
  }

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault()
    
    if (!validateForm()) return

    const scheduleData: MedicationSchedule = {
      id: formData.id || MedicationService.generateId(),
      name: formData.name!,
      dosage: formData.dosage!,
      frequency: formData.frequency || 'twice',
      times: formData.times || [],
      startDate: formData.startDate!,
      endDate: formData.endDate || undefined,
      isActive: formData.isActive ?? true,
      reminderMinutes: formData.reminderMinutes || 10,
      notes: formData.notes || '',
      color: formData.color || '#0ea5e9'
    }

    onSave(scheduleData)
  }

  return (
    <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center p-4 z-50">
      <div className="bg-white rounded-3xl shadow-2xl max-w-lg w-full max-h-[90vh] overflow-y-auto">
        {/* Header */}
        <div className="flex items-center justify-between p-6 border-b border-gray-100">
          <h3 className="text-xl font-semibold text-gray-900">
            {schedule ? 'Edit Schedule' : 'New Medication Schedule'}
          </h3>
          <button
            onClick={onClose}
            className="p-2 hover:bg-gray-100 rounded-xl transition-colors"
          >
            <XMarkIcon className="w-5 h-5 text-gray-500" />
          </button>
        </div>

        <form onSubmit={handleSubmit} className="p-6 space-y-6">
          {/* Medication Name */}
          <div>
            <label className="block text-sm font-medium text-gray-700 mb-2">
              Medication Name *
            </label>
            <input
              type="text"
              value={formData.name || ''}
              onChange={(e) => setFormData(prev => ({ ...prev, name: e.target.value }))}
              className="w-full px-4 py-3 border border-gray-300 rounded-xl focus:ring-2 focus:ring-light-blue-200 focus:border-light-blue-500"
              placeholder="e.g., Latanoprost"
            />
            {errors.name && <p className="text-red-500 text-sm mt-1">{errors.name}</p>}
          </div>

          {/* Dosage */}
          <div>
            <label className="block text-sm font-medium text-gray-700 mb-2">
              Dosage *
            </label>
            <input
              type="text"
              value={formData.dosage || ''}
              onChange={(e) => setFormData(prev => ({ ...prev, dosage: e.target.value }))}
              className="w-full px-4 py-3 border border-gray-300 rounded-xl focus:ring-2 focus:ring-light-blue-200 focus:border-light-blue-500"
              placeholder="e.g., 1 drop"
            />
            {errors.dosage && <p className="text-red-500 text-sm mt-1">{errors.dosage}</p>}
          </div>

          {/* Frequency */}
          <div>
            <label className="block text-sm font-medium text-gray-700 mb-2">
              Frequency *
            </label>
            <div className="space-y-2">
              {frequencyOptions.map(option => (
                <label key={option.value} className="flex items-center space-x-3">
                  <input
                    type="radio"
                    value={option.value}
                    checked={formData.frequency === option.value}
                    onChange={(e) => handleFrequencyChange(e.target.value)}
                    className="w-4 h-4 text-light-blue-600 focus:ring-light-blue-500"
                  />
                  <span className="text-gray-700">{option.label}</span>
                </label>
              ))}
            </div>
          </div>

          {/* Custom Times */}
          {formData.frequency === 'custom' && (
            <div>
              <div className="flex items-center justify-between mb-3">
                <label className="block text-sm font-medium text-gray-700">
                  Schedule Times
                </label>
                <button
                  type="button"
                  onClick={addCustomTime}
                  className="flex items-center space-x-1 text-light-blue-600 hover:text-light-blue-700"
                >
                  <PlusIcon className="w-4 h-4" />
                  <span className="text-sm">Add Time</span>
                </button>
              </div>
              <div className="space-y-2">
                {(formData.times || []).map((time, index) => (
                  <div key={index} className="flex items-center space-x-2">
                    <input
                      type="time"
                      value={time}
                      onChange={(e) => updateTime(index, e.target.value)}
                      className="flex-1 px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-light-blue-200 focus:border-light-blue-500"
                    />
                    {formData.times!.length > 1 && (
                      <button
                        type="button"
                        onClick={() => removeCustomTime(index)}
                        className="p-2 text-red-500 hover:text-red-600"
                      >
                        <MinusIcon className="w-4 h-4" />
                      </button>
                    )}
                  </div>
                ))}
              </div>
            </div>
          )}

          {/* Non-custom frequency times display */}
          {formData.frequency !== 'custom' && (
            <div>
              <label className="block text-sm font-medium text-gray-700 mb-2">
                Schedule Times
              </label>
              <div className="bg-gray-50 rounded-xl p-3">
                <p className="text-sm text-gray-600">
                  {formData.times?.join(', ') || 'No times set'}
                </p>
              </div>
            </div>
          )}

          {/* Date Range */}
          <div className="grid grid-cols-2 gap-4">
            <div>
              <label className="block text-sm font-medium text-gray-700 mb-2">
                Start Date *
              </label>
              <input
                type="date"
                value={formData.startDate || ''}
                onChange={(e) => setFormData(prev => ({ ...prev, startDate: e.target.value }))}
                className="w-full px-4 py-3 border border-gray-300 rounded-xl focus:ring-2 focus:ring-light-blue-200 focus:border-light-blue-500"
              />
              {errors.startDate && <p className="text-red-500 text-sm mt-1">{errors.startDate}</p>}
            </div>
            <div>
              <label className="block text-sm font-medium text-gray-700 mb-2">
                End Date (Optional)
              </label>
              <input
                type="date"
                value={formData.endDate || ''}
                onChange={(e) => setFormData(prev => ({ ...prev, endDate: e.target.value || undefined }))}
                className="w-full px-4 py-3 border border-gray-300 rounded-xl focus:ring-2 focus:ring-light-blue-200 focus:border-light-blue-500"
              />
            </div>
          </div>

          {/* Reminder */}
          <div>
            <label className="block text-sm font-medium text-gray-700 mb-2">
              Reminder (minutes before)
            </label>
            <select
              value={formData.reminderMinutes || 10}
              onChange={(e) => setFormData(prev => ({ ...prev, reminderMinutes: parseInt(e.target.value) }))}
              className="w-full px-4 py-3 border border-gray-300 rounded-xl focus:ring-2 focus:ring-light-blue-200 focus:border-light-blue-500"
            >
              <option value={5}>5 minutes</option>
              <option value={10}>10 minutes</option>
              <option value={15}>15 minutes</option>
              <option value={30}>30 minutes</option>
              <option value={60}>1 hour</option>
            </select>
          </div>

          {/* Color */}
          <div>
            <label className="block text-sm font-medium text-gray-700 mb-2">
              Calendar Color
            </label>
            <div className="flex space-x-2">
              {colorOptions.map(color => (
                <button
                  key={color}
                  type="button"
                  onClick={() => setFormData(prev => ({ ...prev, color }))}
                  className={`w-8 h-8 rounded-full border-2 ${
                    formData.color === color ? 'border-gray-800' : 'border-gray-300'
                  }`}
                  style={{ backgroundColor: color }}
                />
              ))}
            </div>
          </div>

          {/* Notes */}
          <div>
            <label className="block text-sm font-medium text-gray-700 mb-2">
              Notes (Optional)
            </label>
            <textarea
              value={formData.notes || ''}
              onChange={(e) => setFormData(prev => ({ ...prev, notes: e.target.value }))}
              rows={3}
              className="w-full px-4 py-3 border border-gray-300 rounded-xl focus:ring-2 focus:ring-light-blue-200 focus:border-light-blue-500 resize-none"
              placeholder="Any special instructions or notes..."
            />
          </div>

          {/* Active Toggle */}
          <div className="flex items-center space-x-3">
            <input
              type="checkbox"
              id="isActive"
              checked={formData.isActive ?? true}
              onChange={(e) => setFormData(prev => ({ ...prev, isActive: e.target.checked }))}
              className="w-4 h-4 text-light-blue-600 focus:ring-light-blue-500 rounded"
            />
            <label htmlFor="isActive" className="text-sm font-medium text-gray-700">
              Schedule is active
            </label>
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
              {schedule ? 'Update Schedule' : 'Create Schedule'}
            </button>
          </div>
        </form>
      </div>
    </div>
  )
}

export default ScheduleForm