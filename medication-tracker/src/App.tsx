import React from 'react'
import { Routes, Route, Navigate } from 'react-router-dom'
import Layout from './components/Layout'
import DeviceControl from './components/DeviceControl/DeviceControl'
import Calendar from './components/Calendar/Calendar'
import Logging from './components/Logging/Logging'
import Settings from './components/Settings'

function App() {
  return (
    <div className="min-h-screen bg-gray-50">
      <Routes>
        <Route path="/" element={<Layout />}>
          <Route index element={<Navigate to="/device" replace />} />
          <Route path="device" element={<DeviceControl />} />
          <Route path="calendar" element={<Calendar />} />
          <Route path="logging" element={<Logging />} />
          <Route path="settings" element={<Settings />} />
        </Route>
      </Routes>
    </div>
  )
}

export default App