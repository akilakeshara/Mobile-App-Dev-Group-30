import React, { useState, useEffect } from 'react';
import { motion } from 'framer-motion';
import { Calendar, Save, Plus, Trash2, Truck, Map, CheckCircle2 } from 'lucide-react';
import { db } from './firebase';
import { doc, getDoc, setDoc } from 'firebase/firestore';

export default function WasteSchedule({ adminProfile }) {
  const [schedule, setSchedule] = useState({
    entries: []
  });
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);

  useEffect(() => {
    if (!adminProfile) return;

    const dsName = adminProfile.dsDivision;
    
    const fetchConfig = async () => {
      try {
        const docRef = doc(db, 'config', 'waste_collection_schedule');
        const docSnap = await getDoc(docRef);
        
        if (docSnap.exists()) {
          const data = docSnap.data();
          const hierarchy = data.hierarchy || data.provinces || data;
          
          let foundData = null;
          let foundMatchedKey = null;
          
          const findDivision = (obj) => {
            if (!obj || typeof obj !== 'object') return;
            for (const key in obj) {
              if (key === 'entries') continue;
              
              if (key.toLowerCase().includes(dsName.toLowerCase().replace(' ps', '').replace(' ds', '').trim())) {
                if (!foundData || key.length > foundMatchedKey?.length) { // Prioritize 'Maharagama MC' over 'Maharagama'
                  foundData = obj[key];
                  foundMatchedKey = key;
                }
              }
              findDivision(obj[key]);
            }
          };

          findDivision(hierarchy);
          
          if (foundData) {
            setSchedule({
              entries: foundData.entries || []
            });
            setMatchedKey(foundMatchedKey);
          }
        }
      } catch (error) {
        console.error("Error fetching waste schedule:", error);
      }
      setLoading(false);
    };
    
    fetchConfig();
  }, [adminProfile]);

  const [matchedKey, setMatchedKey] = useState(null);

  const addEntry = () => {
    setSchedule(prev => ({
      ...prev,
      entries: [...prev.entries, { day: 'Monday', time: '08:00 AM', route: '' }]
    }));
  };

  const removeEntry = (index) => {
    setSchedule(prev => ({
      ...prev,
      entries: prev.entries.filter((_, i) => i !== index)
    }));
  };

  const updateEntry = (index, field, value) => {
    setSchedule(prev => {
      const newEntries = [...prev.entries];
      newEntries[index] = { ...newEntries[index], [field]: value };
      return { ...prev, entries: newEntries };
    });
  };

  const saveUpdates = async () => {
    if (!adminProfile) return;
    setSaving(true);
    try {
      const docRef = doc(db, 'config', 'waste_collection_schedule');
      const docSnap = await getDoc(docRef);
      
      let data = docSnap.exists() ? docSnap.data() : { hierarchy: {} };
      if (!data.hierarchy && !data.provinces) data = { hierarchy: data };
      
      const root = data.hierarchy || data.provinces;
      const p = adminProfile.province || 'Unknown Province';
      const d = adminProfile.district || 'Unknown District';
      
      // Use the matchedKey from DB if it exists, otherwise fallback to admin profile PS
      const ps = matchedKey || adminProfile.dsDivision || 'Unknown PS';
      
      if (!root[p]) root[p] = {};
      if (!root[p][d]) root[p][d] = {};
      
      root[p][d][ps] = {
        ...(root[p][d][ps] || {}),
        entries: schedule.entries,
        updatedAt: new Date().toLocaleDateString()
      };
      
      await setDoc(docRef, data);
      alert('Waste collection schedule updated successfully!');
    } catch (error) {
      console.error("Error saving waste schedule:", error);
      alert('Failed to save schedule. Check permissions.');
    }
    setSaving(false);
  };

  if (loading) {
    return <div className="animate-pulse" style={{ padding: '2rem' }}>Loading schedule data...</div>;
  }

  return (
    <motion.div initial={{ opacity: 0, y: 10 }} animate={{ opacity: 1, y: 0 }} exit={{ opacity: 0 }}>
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '2rem' }}>
        <div>
          <h1 style={{ color: 'var(--text-main)', fontSize: '1.8rem', letterSpacing: '-0.5px', display: 'flex', alignItems: 'center', gap: '0.5rem' }}>
            <Truck color="var(--primary)" size={28} />
            Waste Collection Schedule
          </h1>
          <p style={{ color: 'var(--text-muted)' }}>
            Manage the garbage collection days, times, and routes for {adminProfile?.dsDivision}
          </p>
        </div>
        <button 
          onClick={saveUpdates} 
          disabled={saving}
          className="btn-primary" 
          style={{ padding: '0.75rem 1.5rem' }}
        >
          {saving ? 'Saving...' : <><Save size={18} /> Save Timetable</>}
        </button>
      </div>
      
      {/* Summary Cards */}
      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(200px, 1fr))', gap: '1.5rem', marginBottom: '2rem' }}>
        <motion.div initial={{ opacity: 0, y: 10 }} animate={{ opacity: 1, y: 0 }} transition={{ delay: 0.1 }} className="glass" style={{ padding: '1.5rem', borderRadius: '16px', borderLeft: '4px solid var(--primary)', display: 'flex', alignItems: 'center', gap: '15px' }}>
          <div style={{ background: 'rgba(37, 99, 235, 0.1)', padding: '12px', borderRadius: '50%' }}>
            <Map size={24} color="var(--primary)" />
          </div>
          <div>
            <h3 style={{ fontSize: '0.75rem', color: 'var(--text-muted)', textTransform: 'uppercase', fontWeight: 700, letterSpacing: '0.5px', margin: '0 0 4px 0' }}>Configured Routes</h3>
            <p style={{ fontSize: '1.6rem', fontWeight: 800, color: 'var(--text-main)', margin: 0 }}>{schedule.entries.length}</p>
          </div>
        </motion.div>
        
        <motion.div initial={{ opacity: 0, y: 10 }} animate={{ opacity: 1, y: 0 }} transition={{ delay: 0.2 }} className="glass" style={{ padding: '1.5rem', borderRadius: '16px', borderLeft: '4px solid #10b981', display: 'flex', alignItems: 'center', gap: '15px' }}>
          <div style={{ background: 'rgba(16, 185, 129, 0.1)', padding: '12px', borderRadius: '50%' }}>
            <Calendar size={24} color="#10b981" />
          </div>
          <div>
            <h3 style={{ fontSize: '0.75rem', color: 'var(--text-muted)', textTransform: 'uppercase', fontWeight: 700, letterSpacing: '0.5px', margin: '0 0 4px 0' }}>Active Collection Days</h3>
            <p style={{ fontSize: '1.6rem', fontWeight: 800, color: 'var(--text-main)', margin: 0 }}>{new Set(schedule.entries.map(e => e.day)).size}</p>
          </div>
        </motion.div>

        <motion.div initial={{ opacity: 0, y: 10 }} animate={{ opacity: 1, y: 0 }} transition={{ delay: 0.3 }} className="glass" style={{ padding: '1.5rem', borderRadius: '16px', borderLeft: '4px solid #f59e0b', display: 'flex', alignItems: 'center', gap: '15px' }}>
          <div style={{ background: 'rgba(245, 158, 11, 0.1)', padding: '12px', borderRadius: '50%' }}>
            <CheckCircle2 size={24} color="#f59e0b" />
          </div>
          <div>
            <h3 style={{ fontSize: '0.75rem', color: 'var(--text-muted)', textTransform: 'uppercase', fontWeight: 700, letterSpacing: '0.5px', margin: '0 0 4px 0' }}>Timetable Status</h3>
            <p style={{ fontSize: '1.2rem', fontWeight: 800, color: 'var(--text-main)', margin: 0 }}>{schedule.entries.length > 0 ? 'Active' : 'Pending'}</p>
          </div>
        </motion.div>
      </div>

      <div className="card glass" style={{ padding: 0, overflow: 'hidden' }}>
        <div style={{ padding: '1.5rem', borderBottom: '1px solid var(--border)', display: 'flex', justifyContent: 'space-between', alignItems: 'center', backgroundColor: 'var(--surface)' }}>
          <h3 style={{ fontSize: '1.1rem', display: 'flex', alignItems: 'center', gap: '0.5rem' }}>
            <Calendar size={20} color="var(--warning)" /> Route Timetable
          </h3>
          <button onClick={addEntry} style={{ color: 'var(--primary)', fontSize: '0.9rem', fontWeight: 600, display: 'flex', alignItems: 'center', gap: '0.25rem', backgroundColor: 'transparent', border: 'none', cursor: 'pointer' }}>
            <Plus size={16} /> Add Route
          </button>
        </div>
        
        {schedule.entries.length === 0 ? (
          <div style={{ padding: '3rem', textAlign: 'center', color: 'var(--text-muted)' }}>
            No timetables created yet. Click "Add Route" to configure collections.
          </div>
        ) : (
          <div style={{ padding: '1.5rem', display: 'flex', flexDirection: 'column', gap: '1rem' }}>
            {schedule.entries.map((entry, index) => (
              <div key={index} style={{ display: 'flex', gap: '1rem', alignItems: 'flex-start', padding: '1rem', backgroundColor: 'var(--primary-light)', borderRadius: '12px' }}>
                <div style={{ flex: 1 }}>
                  <label style={{ display: 'block', fontSize: '0.8rem', fontWeight: 600, marginBottom: '0.25rem' }}>Collection Day</label>
                  <select 
                    className="input-field" 
                    value={entry.day}
                    onChange={e => updateEntry(index, 'day', e.target.value)}
                    style={{ backgroundColor: 'white' }}
                  >
                    {['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'].map(d => <option key={d}>{d}</option>)}
                  </select>
                </div>
                <div style={{ flex: 1 }}>
                  <label style={{ display: 'block', fontSize: '0.8rem', fontWeight: 600, marginBottom: '0.25rem' }}>Time</label>
                  <input 
                    type="text" 
                    className="input-field" 
                    value={entry.time}
                    placeholder="e.g. 08:30 AM"
                    onChange={e => updateEntry(index, 'time', e.target.value)}
                    style={{ backgroundColor: 'white' }}
                  />
                </div>
                <div style={{ flex: 2 }}>
                  <label style={{ display: 'block', fontSize: '0.8rem', fontWeight: 600, marginBottom: '0.25rem' }}>Collection Route</label>
                  <input 
                    type="text" 
                    className="input-field" 
                    value={entry.route}
                    placeholder="e.g. Navinna - Delkanda"
                    onChange={e => updateEntry(index, 'route', e.target.value)}
                    style={{ backgroundColor: 'white' }}
                  />
                </div>
                <button 
                  onClick={() => removeEntry(index)}
                  style={{ marginTop: '1.5rem', padding: '0.5rem', color: 'var(--danger)', backgroundColor: 'rgba(239, 68, 68, 0.1)', borderRadius: '8px', border: 'none', cursor: 'pointer' }}
                >
                  <Trash2 size={20} />
                </button>
              </div>
            ))}
          </div>
        )}
      </div>
    </motion.div>
  );
}
