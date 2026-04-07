import React, { useState } from 'react';
import { motion } from 'framer-motion';
import { Settings, Building, Sliders, Shield, BellRing, Save } from 'lucide-react';

export default function SystemSettings({ adminProfile }) {
  const [activeTab, setActiveTab] = useState('general');
  const [saving, setSaving] = useState(false);

  // Simulated state for settings
  const [config, setConfig] = useState({
    dsName: adminProfile?.dsDivision || 'Admin Division',
    address: '',
    helpline: '',
    email: '',
    enableNotifications: true,
    autoAssignGN: false,
    publicFeedback: true,
    twoFactorAuth: false,
    sessionTimeout: '30'
  });

  const handleSave = () => {
    setSaving(true);
    setTimeout(() => {
      setSaving(false);
      alert('System configurations updated successfully!');
    }, 1000);
  };

  return (
    <motion.div initial={{ opacity: 0, y: 10 }} animate={{ opacity: 1, y: 0 }} exit={{ opacity: 0 }}>
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '2rem' }}>
        <div>
          <h1 style={{ color: 'var(--text-main)', fontSize: '1.8rem', letterSpacing: '-0.5px', display: 'flex', alignItems: 'center', gap: '0.5rem' }}>
            <Settings color="var(--primary)" size={28} />
            System Settings
          </h1>
          <p style={{ color: 'var(--text-muted)' }}>Configure core parameters for your administrative division</p>
        </div>
        <button className="btn-primary" onClick={handleSave} disabled={saving} style={{ padding: '0.75rem 1.5rem', display: 'flex', gap: '0.5rem', alignItems: 'center' }}>
          <Save size={18} /> {saving ? 'Applying Changes...' : 'Save Configuration'}
        </button>
      </div>

      <div style={{ display: 'flex', gap: '2rem', alignItems: 'flex-start' }}>
        {/* Sidebar Nav */}
        <div style={{ width: '250px', display: 'flex', flexDirection: 'column', gap: '0.5rem' }}>
          <button 
            onClick={() => setActiveTab('general')}
            style={{ display: 'flex', alignItems: 'center', gap: '0.8rem', padding: '1rem', borderRadius: '12px', background: activeTab === 'general' ? 'var(--primary)' : 'transparent', color: activeTab === 'general' ? 'white' : 'var(--text-main)', border: 'none', cursor: 'pointer', textAlign: 'left', fontWeight: activeTab === 'general' ? 600 : 500, transition: 'all 0.2s' }}
          >
            <Building size={18} /> General Identity
          </button>
          <button 
            onClick={() => setActiveTab('features')}
            style={{ display: 'flex', alignItems: 'center', gap: '0.8rem', padding: '1rem', borderRadius: '12px', background: activeTab === 'features' ? 'var(--primary)' : 'transparent', color: activeTab === 'features' ? 'white' : 'var(--text-main)', border: 'none', cursor: 'pointer', textAlign: 'left', fontWeight: activeTab === 'features' ? 600 : 500, transition: 'all 0.2s' }}
          >
            <Sliders size={18} /> Feature Toggles
          </button>
          <button 
            onClick={() => setActiveTab('security')}
            style={{ display: 'flex', alignItems: 'center', gap: '0.8rem', padding: '1rem', borderRadius: '12px', background: activeTab === 'security' ? 'var(--primary)' : 'transparent', color: activeTab === 'security' ? 'white' : 'var(--text-main)', border: 'none', cursor: 'pointer', textAlign: 'left', fontWeight: activeTab === 'security' ? 600 : 500, transition: 'all 0.2s' }}
          >
            <Shield size={18} /> Security & Access
          </button>
          <button 
            onClick={() => setActiveTab('notifications')}
            style={{ display: 'flex', alignItems: 'center', gap: '0.8rem', padding: '1rem', borderRadius: '12px', background: activeTab === 'notifications' ? 'var(--primary)' : 'transparent', color: activeTab === 'notifications' ? 'white' : 'var(--text-main)', border: 'none', cursor: 'pointer', textAlign: 'left', fontWeight: activeTab === 'notifications' ? 600 : 500, transition: 'all 0.2s' }}
          >
            <BellRing size={18} /> Alerts Configuration
          </button>
        </div>

        {/* Content Area */}
        <div style={{ flex: 1 }}>
          <div className="card glass" style={{ padding: '2rem' }}>
            {activeTab === 'general' && (
              <motion.div initial={{ opacity: 0, x: 20 }} animate={{ opacity: 1, x: 0 }}>
                <h2 style={{ fontSize: '1.2rem', marginBottom: '1.5rem', color: 'var(--text-main)', display: 'flex', alignItems: 'center', gap: '0.5rem' }}><Building color="var(--primary)" size={20} /> Divisional Headquarters</h2>
                
                <div style={{ display: 'flex', flexDirection: 'column', gap: '1.5rem' }}>
                  <div>
                    <label style={{ display: 'block', marginBottom: '0.5rem', color: 'var(--text-main)', fontWeight: 600 }}>Division Header Name</label>
                    <input type="text" className="input-field" value={config.dsName} onChange={e => setConfig({...config, dsName: e.target.value})} />
                  </div>
                  
                  <div>
                    <label style={{ display: 'block', marginBottom: '0.5rem', color: 'var(--text-main)', fontWeight: 600 }}>Official Address</label>
                    <textarea className="input-field" rows={3} placeholder="Enter the physical address of the DS office" value={config.address} onChange={e => setConfig({...config, address: e.target.value})}></textarea>
                  </div>

                  <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '1.5rem' }}>
                    <div>
                      <label style={{ display: 'block', marginBottom: '0.5rem', color: 'var(--text-main)', fontWeight: 600 }}>Helpline Number</label>
                      <input type="tel" className="input-field" placeholder="e.g. 011 2 123456" value={config.helpline} onChange={e => setConfig({...config, helpline: e.target.value})} />
                    </div>
                    <div>
                      <label style={{ display: 'block', marginBottom: '0.5rem', color: 'var(--text-main)', fontWeight: 600 }}>Contact Email</label>
                      <input type="email" className="input-field" placeholder="contact@ds.gov.lk" value={config.email} onChange={e => setConfig({...config, email: e.target.value})} />
                    </div>
                  </div>
                </div>
              </motion.div>
            )}

            {activeTab === 'features' && (
              <motion.div initial={{ opacity: 0, x: 20 }} animate={{ opacity: 1, x: 0 }}>
                <h2 style={{ fontSize: '1.2rem', marginBottom: '1.5rem', color: 'var(--text-main)', display: 'flex', alignItems: 'center', gap: '0.5rem' }}><Sliders color="var(--primary)" size={20} /> Application Modules</h2>
                
                <div style={{ display: 'flex', flexDirection: 'column', gap: '1rem' }}>
                  <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', padding: '1rem', background: 'var(--surface)', borderRadius: '12px', border: '1px solid var(--border)' }}>
                    <div>
                      <h4 style={{ margin: '0 0 0.25rem 0', color: 'var(--text-main)', fontSize: '1rem' }}>Auto-assign GN Officers</h4>
                      <p style={{ margin: 0, color: 'var(--text-muted)', fontSize: '0.85rem' }}>Automatically route citizen requests to their respective GN based on exact division match.</p>
                    </div>
                    <label className="switch">
                      <input type="checkbox" checked={config.autoAssignGN} onChange={e => setConfig({...config, autoAssignGN: e.target.checked})} />
                      <span className="slider round"></span>
                    </label>
                  </div>
                  
                  <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', padding: '1rem', background: 'var(--surface)', borderRadius: '12px', border: '1px solid var(--border)' }}>
                    <div>
                      <h4 style={{ margin: '0 0 0.25rem 0', color: 'var(--text-main)', fontSize: '1rem' }}>Public Feedback Portal</h4>
                      <p style={{ margin: 0, color: 'var(--text-muted)', fontSize: '0.85rem' }}>Allow citizens to submit post-service survey feedback and ratings.</p>
                    </div>
                    <label className="switch">
                      <input type="checkbox" checked={config.publicFeedback} onChange={e => setConfig({...config, publicFeedback: e.target.checked})} />
                      <span className="slider round"></span>
                    </label>
                  </div>
                </div>
              </motion.div>
            )}

            {activeTab === 'security' && (
              <motion.div initial={{ opacity: 0, x: 20 }} animate={{ opacity: 1, x: 0 }}>
                <h2 style={{ fontSize: '1.2rem', marginBottom: '1.5rem', color: 'var(--text-main)', display: 'flex', alignItems: 'center', gap: '0.5rem' }}><Shield color="var(--primary)" size={20} /> Access Security</h2>
                
                <div style={{ display: 'flex', flexDirection: 'column', gap: '1.5rem' }}>
                  <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', padding: '1rem', background: 'var(--surface)', borderRadius: '12px', border: '1px solid var(--border)' }}>
                    <div>
                      <h4 style={{ margin: '0 0 0.25rem 0', color: 'var(--text-main)', fontSize: '1rem' }}>Enforce Two-Factor Auth (2FA)</h4>
                      <p style={{ margin: 0, color: 'var(--text-muted)', fontSize: '0.85rem' }}>Require OTP verification when a GN officer logs in from a new device.</p>
                    </div>
                    <label className="switch">
                      <input type="checkbox" checked={config.twoFactorAuth} onChange={e => setConfig({...config, twoFactorAuth: e.target.checked})} />
                      <span className="slider round"></span>
                    </label>
                  </div>

                  <div>
                    <label style={{ display: 'block', marginBottom: '0.5rem', color: 'var(--text-main)', fontWeight: 600 }}>Web Session Timeout (Minutes)</label>
                    <select className="input-field" value={config.sessionTimeout} onChange={e => setConfig({...config, sessionTimeout: e.target.value})}>
                      <option value="15">15 Minutes</option>
                      <option value="30">30 Minutes (Default)</option>
                      <option value="60">1 Hour</option>
                      <option value="never">Never Timeout</option>
                    </select>
                    <p style={{ margin: '0.5rem 0 0 0', color: 'initial', fontSize: '0.8rem', color: 'var(--text-muted)' }}>Automatically sign out administrators after period of inactivity.</p>
                  </div>
                </div>
              </motion.div>
            )}

            {activeTab === 'notifications' && (
              <motion.div initial={{ opacity: 0, x: 20 }} animate={{ opacity: 1, x: 0 }}>
                <h2 style={{ fontSize: '1.2rem', marginBottom: '1.5rem', color: 'var(--text-main)', display: 'flex', alignItems: 'center', gap: '0.5rem' }}><BellRing color="var(--primary)" size={20} /> System Alerts</h2>
                
                <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', padding: '1rem', background: 'var(--surface)', borderRadius: '12px', border: '1px solid var(--border)' }}>
                  <div>
                    <h4 style={{ margin: '0 0 0.25rem 0', color: 'var(--text-main)', fontSize: '1rem' }}>Push Notifications via GovEase</h4>
                    <p style={{ margin: 0, color: 'var(--text-muted)', fontSize: '0.85rem' }}>Send real-time alerts to mobile phones whenever citizen records are updated.</p>
                  </div>
                  <label className="switch">
                    <input type="checkbox" checked={config.enableNotifications} onChange={e => setConfig({...config, enableNotifications: e.target.checked})} />
                    <span className="slider round"></span>
                  </label>
                </div>
              </motion.div>
            )}

          </div>
        </div>
      </div>
      
      {/* Toggle switch styles inline for convenience */}
      <style>{`
        .switch {
          position: relative;
          display: inline-block;
          width: 50px;
          height: 28px;
        }
        .switch input { 
          opacity: 0;
          width: 0;
          height: 0;
        }
        .slider {
          position: absolute;
          cursor: pointer;
          top: 0;
          left: 0;
          right: 0;
          bottom: 0;
          background-color: #cbd5e1;
          transition: .3s;
        }
        .slider:before {
          position: absolute;
          content: "";
          height: 20px;
          width: 20px;
          left: 4px;
          bottom: 4px;
          background-color: white;
          transition: .3s;
        }
        input:checked + .slider {
          background-color: var(--primary);
        }
        input:checked + .slider:before {
          transform: translateX(22px);
        }
        .slider.round {
          border-radius: 34px;
        }
        .slider.round:before {
          border-radius: 50%;
        }
      `}</style>
    </motion.div>
  );
}
