import React, { useState, useEffect } from 'react';
import { motion } from 'framer-motion';
import { 
  Users, MapPin, Activity, Clock, ShieldCheck, 
  FileText, AlertTriangle, ArrowUpRight, ArrowDownRight, 
  CalendarDays, CheckCircle2, LayoutGrid, Search, Coins, TrendingUp
} from 'lucide-react';
import { db } from './firebase';
import { collection, onSnapshot, query, orderBy, limit } from 'firebase/firestore';
import { decryptText } from './utils/encryption';

const MetricCard = ({ title, value, subtitle, icon: Icon, color, delay }) => (
  <motion.div 
    initial={{ opacity: 0, y: 20 }}
    animate={{ opacity: 1, y: 0 }}
    transition={{ duration: 0.5, delay, ease: [0.22, 1, 0.36, 1] }}
    whileHover={{ y: -5, scale: 1.02 }}
    className="glass"
    style={{ 
      padding: '1.5rem', 
      borderRadius: '20px', 
      position: 'relative', 
      overflow: 'hidden',
      border: '1px solid rgba(255,255,255,0.4)',
      boxShadow: '0 10px 30px -10px rgba(0, 0, 0, 0.05)',
      background: 'linear-gradient(135deg, rgba(255,255,255,0.9) 0%, rgba(255,255,255,0.4) 100%)',
    }}
  >
    {/* Decorative blur blob */}
    <div style={{ position: 'absolute', top: '-10px', right: '-10px', width: '80px', height: '80px', background: `${color}30`, borderRadius: '50%', filter: 'blur(20px)', zIndex: 0 }} />
    
    <div style={{ position: 'relative', zIndex: 1 }}>
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '1rem' }}>
        <div style={{ padding: '12px', background: `${color}15`, color: color, borderRadius: '16px' }}>
          <Icon size={24} strokeWidth={2.5} />
        </div>
        <div style={{ background: 'rgba(255,255,255,0.8)', padding: '4px 10px', borderRadius: '20px', fontSize: '0.75rem', fontWeight: 700, color: 'var(--text-main)', display: 'flex', alignItems: 'center', gap: '4px' }}>
          Real-time <div style={{ width: '6px', height: '6px', borderRadius: '50%', backgroundColor: color, animation: 'pulse 2s infinite' }} />
        </div>
      </div>
      <h3 style={{ fontSize: '0.9rem', color: 'var(--text-muted)', fontWeight: 600, textTransform: 'uppercase', letterSpacing: '0.5px' }}>{title}</h3>
      <div style={{ display: 'flex', alignItems: 'flex-end', gap: '0.5rem', marginTop: '0.2rem' }}>
        <h2 style={{ fontSize: '2.5rem', color: 'var(--text-main)', fontWeight: 800, lineHeight: 1 }}>{value}</h2>
        <span style={{ fontSize: '0.85rem', color: 'var(--text-muted)', fontWeight: 600, marginBottom: '0.4rem' }}>{subtitle}</span>
      </div>
    </div>
  </motion.div>
);

const normalize = (s) => (s || '').toLowerCase()
  .replace(/\b(ps|mc|uc|sabha|council|division|ds|urban|municipal|lekam|kottasha|pradeshiya)\b/g, '')
  .replace(/[^a-z0-9]/g, '')
  .trim();

export default function Dashboard({ adminProfile }) {
  const [stats, setStats] = useState({
    citizens: 0,
    officers: 0,
    applications: 0,
    complaints: 0,
    revenue: 0,
  });
  const [recentApps, setRecentApps] = useState([]);
  const [loading, setLoading] = useState(true);
  const [greeting, setGreeting] = useState('');

  useEffect(() => {
    const hour = new Date().getHours();
    if (hour < 12) setGreeting('Good Morning');
    else if (hour < 18) setGreeting('Good Afternoon');
    else setGreeting('Good Evening');
  }, []);

  useEffect(() => {
    if (!adminProfile) return;

    const adminDS = adminProfile.dsDivision;
    const normAdminDS = normalize(adminDS);
    let validCitizenIds = new Set();

    // 1. Fetch Citizens strictly for this DS
    const unsubCitizens = onSnapshot(collection(db, 'citizens'), (snapshot) => {
      let count = 0;
      const ids = new Set();
      snapshot.forEach(doc => {
        const data = doc.data();
        const pSabha = normalize(decryptText(data.pradeshiyaSabha));
        const division = normalize(decryptText(data.division));
        
        if (!adminDS || pSabha.includes(normAdminDS) || division.includes(normAdminDS)) {
          count++;
          ids.add(doc.id);
        }
      });
      validCitizenIds = ids;
      setStats(s => ({ ...s, citizens: count, validCitizenIds: ids }));
      
      // 2. Fetch Complaints (only those from valid citizens inside this DS)
      const unsubComplaints = onSnapshot(collection(db, 'complaints'), (compSnap) => {
        let compCount = 0;
        compSnap.forEach(doc => {
          const compData = doc.data();
          if (compData.status !== 'Closed' && (validCitizenIds.has(compData.userId) || !adminDS)) {
             compCount++;
          }
        });
        setStats(s => ({ ...s, complaints: compCount }));
      });

      return () => unsubComplaints();
    });

    // 3. Fetch Officers for this DS
    const unsubOfficers = onSnapshot(collection(db, 'officers'), (snapshot) => {
      let count = 0;
      snapshot.forEach(doc => {
        const pSabha = doc.data().pradeshiyaSabha;
        if (!adminDS || normalize(pSabha) === normAdminDS) count++;
      });
      setStats(s => ({ ...s, officers: count }));
    });

    // 4. Fetch the latest general applications/requests
    const qApps = query(collection(db, 'applications'));
    const unsubApps = onSnapshot(qApps, (snapshot) => {
      const list = [];

      snapshot.forEach(doc => {
        const data = doc.data();
        list.push({
          id: doc.id,
          ...data,
          type: data.serviceType || 'DS Service Request',
          applicant: data.formData?.fullName || 'Citizen',
          date: data.createdAt ? new Date(data.createdAt).toLocaleDateString(undefined, {month:'short', day:'numeric'}) : 'Today',
          status: data.status || 'Pending Review',
          userId: data.userId || '',
          gnDivision: data.gnDivision || '',
          rawString: JSON.stringify(data).toLowerCase(),
          paid: data.paid || false,
          paymentAmount: data.paymentAmount || 0
        });
      });

      // We should calculate revenue for dashboard stats.
      let rev = 0;
      list.forEach(app => {
        if (app.paid && app.paymentAmount) rev += app.paymentAmount;
      });
      setStats(s => ({ ...s, revenue: rev }));

      setRecentApps(list);
      setLoading(false);
    });

    return () => {
      unsubCitizens();
      unsubOfficers();
      unsubApps();
    };
  }, [adminProfile]);

  const getStatusStyle = (status) => {
    switch(status.toLowerCase()) {
      case 'completed': 
      case 'approved': return { bg: '#dcfce7', color: '#166534', border: '#bbf7d0' };
      case 'rejected': 
      case 'declined': return { bg: '#fee2e2', color: '#991b1b', border: '#fecaca' };
      case 'in progress':
      case 'processing': return { bg: '#fef3c7', color: '#92400e', border: '#fde68a' };
      case 'verified': return { bg: '#dbeafe', color: '#1e40af', border: '#bfdbfe' };
      default: return { bg: '#f3f4f6', color: '#4b5563', border: '#e5e7eb' };
    }
  };

  // Computed derived state for Applications in Dashboard based on validCitizenIds or string fallback
  const filteredDashboardApps = React.useMemo(() => {
    const adminDS = adminProfile?.dsDivision;
    const normAdminDS = normalize(adminDS);
    let count = 0;
    const recent = [];
    
    for (const app of recentApps) {
      let belongsToDS = false;
      if (!adminDS) belongsToDS = true;
      else if (app.gnDivision && normalize(app.gnDivision).includes(normAdminDS)) belongsToDS = true;
      else if (stats.validCitizenIds && stats.validCitizenIds.has(app.userId)) belongsToDS = true;
      else if (app.rawString && app.rawString.includes(normAdminDS)) belongsToDS = true;

      if (belongsToDS) {
        if (app.status !== 'Completed' && app.status !== 'Approved') count++;
        if (recent.length < 6) recent.push(app);
      }
    }
    
    return { count, recent };
  }, [recentApps, adminProfile, stats.validCitizenIds]);

  return (
    <motion.div 
      initial={{ opacity: 0 }} animate={{ opacity: 1 }} exit={{ opacity: 0 }}
      style={{ display: 'flex', flexDirection: 'column', gap: '2rem', paddingBottom: '2rem' }}
    >
      {/* Premium Hero Section */}
      <motion.div 
        initial={{ y: 20, opacity: 0 }} animate={{ y: 0, opacity: 1 }} transition={{ duration: 0.6 }}
        style={{
          background: 'linear-gradient(135deg, var(--primary) 0%, var(--primary-dark) 100%)',
          borderRadius: '24px', padding: '2.5rem', color: 'white', position: 'relative', overflow: 'hidden',
          boxShadow: '0 20px 40px -15px rgba(10, 102, 194, 0.4)'
        }}
      >
        <div style={{ position: 'absolute', right: '-10%', top: '-20%', width: '300px', height: '300px', background: 'rgba(255,255,255,0.1)', borderRadius: '50%', filter: 'blur(30px)' }} />
        <div style={{ position: 'absolute', left: '10%', bottom: '-40%', width: '200px', height: '200px', background: 'rgba(255,255,255,0.05)', borderRadius: '50%', filter: 'blur(20px)' }} />
        
        <div style={{ position: 'relative', zIndex: 1 }}>
          <span style={{ fontSize: '0.9rem', fontWeight: 600, textTransform: 'uppercase', letterSpacing: '1px', opacity: 0.8, display: 'flex', alignItems: 'center', gap: '8px' }}>
            <ShieldCheck size={16} /> Divisional Secretariat Portal
          </span>
          <h1 style={{ fontSize: '2.8rem', fontWeight: 800, margin: '0.5rem 0 1rem 0', letterSpacing: '-1px' }}>
            {greeting}, Admin!
          </h1>
          <p style={{ fontSize: '1.1rem', opacity: 0.9, maxWidth: '600px', lineHeight: 1.5 }}>
            You are viewing the real-time command center for the <strong>{adminProfile?.dsDivision || 'assigned'}</strong> division. Monitor citizen requests, officer availability, and active escalations securely.
          </p>
        </div>
      </motion.div>

      {/* Modern Bento Box Metrics */}
      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(240px, 1fr))', gap: '1.5rem' }}>
        <MetricCard delay={0.1} title="Verified Citizens" value={loading ? '-' : stats.citizens} subtitle="Registered profiles" icon={Users} color="#10b981" />
        <MetricCard delay={0.2} title="Active GN Officers" value={loading ? '-' : stats.officers} subtitle="Assigned to division" icon={MapPin} color="#3b82f6" />
        <MetricCard delay={0.3} title="Actionable Requests" value={loading ? '-' : filteredDashboardApps.count} subtitle="Pending DS approval" icon={FileText} color="#f59e0b" />
        <MetricCard delay={0.4} title="Open Escalations" value={loading ? '-' : stats.complaints} subtitle="Requiring attention" icon={AlertTriangle} color="#ef4444" />
      </div>

      <div style={{ display: 'grid', gridTemplateColumns: '2fr 1fr', gap: '1.5rem' }}>
        {/* Advanced Data Table for Requests */}
        <motion.div 
          initial={{ opacity: 0, x: -20 }} animate={{ opacity: 1, x: 0 }} transition={{ delay: 0.5, duration: 0.6 }}
          className="glass" 
          style={{ padding: 0, borderRadius: '24px', overflow: 'hidden', border: '1px solid rgba(0,0,0,0.05)', boxShadow: '0 10px 30px -10px rgba(0, 0, 0, 0.05)' }}
        >
          <div style={{ padding: '1.5rem 2rem', borderBottom: '1px solid rgba(0,0,0,0.05)', display: 'flex', justifyContent: 'space-between', alignItems: 'center', background: 'rgba(255,255,255,0.7)' }}>
            <div>
              <h3 style={{ fontSize: '1.2rem', fontWeight: 800, color: 'var(--text-main)', display: 'flex', alignItems: 'center', gap: '10px' }}>
                <Activity size={20} color="var(--primary)" /> Real-Time Service Queue
              </h3>
              <p style={{ fontSize: '0.85rem', color: 'var(--text-muted)', marginTop: '4px' }}>Latest applications submitted by citizens within your division</p>
            </div>
          </div>
          <table style={{ width: '100%', borderCollapse: 'collapse', textAlign: 'left' }}>
            <thead>
              <tr style={{ backgroundColor: 'rgba(0,0,0,0.02)' }}>
                <th style={{ padding: '1.2rem 2rem', fontSize: '0.8rem', fontWeight: 700, color: 'var(--text-muted)', textTransform: 'uppercase', letterSpacing: '1px' }}>Service Type</th>
                <th style={{ padding: '1.2rem 2rem', fontSize: '0.8rem', fontWeight: 700, color: 'var(--text-muted)', textTransform: 'uppercase', letterSpacing: '1px' }}>Citizen Info</th>
                <th style={{ padding: '1.2rem 2rem', fontSize: '0.8rem', fontWeight: 700, color: 'var(--text-muted)', textTransform: 'uppercase', letterSpacing: '1px' }}>Submitted</th>
                <th style={{ padding: '1.2rem 2rem', fontSize: '0.8rem', fontWeight: 700, color: 'var(--text-muted)', textTransform: 'uppercase', letterSpacing: '1px' }}>Status</th>
              </tr>
            </thead>
            <tbody>
              {loading ? (
                <tr>
                  <td colSpan="4" style={{ padding: '4rem', textAlign: 'center' }}>
                    <div className="animate-pulse" style={{ color: 'var(--text-muted)', fontWeight: 600 }}>Syncing Divisional Data...</div>
                  </td>
                </tr>
              ) : filteredDashboardApps.recent.length === 0 ? (
                <tr>
                  <td colSpan="4" style={{ padding: '4rem', textAlign: 'center', color: 'var(--text-muted)' }}>
                    <CheckCircle2 size={40} style={{ margin: '0 auto 10px auto', opacity: 0.5 }} />
                    <p style={{ fontWeight: 600 }}>No pending requests.</p>
                    <span style={{ fontSize: '0.85rem' }}>Your division's queue is completely clear!</span>
                  </td>
                </tr>
              ) : filteredDashboardApps.recent.map((req, i) => {
                const sStyle = getStatusStyle(req.status);
                return (
                  <tr key={i} style={{ borderBottom: '1px solid rgba(0,0,0,0.03)', transition: 'background-color 0.2s', cursor: 'pointer' }} onMouseOver={e=>e.currentTarget.style.backgroundColor='rgba(0,0,0,0.01)'} onMouseOut={e=>e.currentTarget.style.backgroundColor='transparent'}>
                    <td style={{ padding: '1.2rem 2rem' }}>
                      <div style={{ fontWeight: 700, color: 'var(--text-main)' }}>{req.type}</div>
                      <div style={{ fontSize: '0.75rem', color: 'var(--text-muted)', marginTop: '4px', fontFamily: 'monospace' }}>REF: {req.id.substring(0, 8).toUpperCase()}</div>
                    </td>
                    <td style={{ padding: '1.2rem 2rem', fontWeight: 600, color: '#374151' }}>
                      {req.applicant}
                    </td>
                    <td style={{ padding: '1.2rem 2rem', color: 'var(--text-muted)', fontSize: '0.9rem', display: 'flex', alignItems: 'center', gap: '6px' }}>
                      <CalendarDays size={14} /> {req.date}
                    </td>
                    <td style={{ padding: '1.2rem 2rem' }}>
                      <span style={{ 
                        padding: '6px 12px', borderRadius: '50px', fontSize: '0.75rem', fontWeight: 800, textTransform: 'uppercase', letterSpacing: '0.5px',
                        backgroundColor: sStyle.bg, color: sStyle.color, border: `1px solid ${sStyle.border}`
                      }}>
                        {req.status}
                      </span>
                    </td>
                  </tr>
                )
              })}
            </tbody>
          </table>
        </motion.div>

        {/* Priority Actions Side Panel */}
        <motion.div 
          initial={{ opacity: 0, x: 20 }} animate={{ opacity: 1, x: 0 }} transition={{ delay: 0.6, duration: 0.6 }}
          style={{ display: 'flex', flexDirection: 'column', gap: '1.5rem' }}
        >
          {/* Finance Wallet Card */}
          <div className="glass" style={{ padding: '2rem', borderRadius: '24px', background: 'linear-gradient(135deg, #8b5cf6, #6d28d9)', color: 'white', border: '1px solid rgba(255,255,255,0.1)', boxShadow: '0 20px 40px -10px rgba(139, 92, 246, 0.4)' }}>
            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
              <div style={{ padding: '10px', background: 'rgba(255,255,255,0.2)', borderRadius: '12px' }}>
                <Coins size={24} color="white" />
              </div>
              <span style={{ background: 'rgba(0,0,0,0.2)', padding: '4px 12px', borderRadius: '20px', fontSize: '0.75rem', fontWeight: 700 }}>LIVE</span>
            </div>
            <div style={{ marginTop: '1.5rem' }}>
              <p style={{ fontSize: '0.85rem', color: 'rgba(255,255,255,0.8)', textTransform: 'uppercase', letterSpacing: '1px', fontWeight: 600 }}>Total Revenue</p>
              <h2 style={{ fontSize: '2.4rem', fontWeight: 800, margin: '0.2rem 0', letterSpacing: '-1px' }}>
                 <span style={{ fontSize: '1.4rem', opacity: 0.8, marginRight: '4px' }}>Rs.</span>{stats.revenue.toFixed(2)}
              </h2>
              <div style={{ display: 'flex', alignItems: 'center', gap: '6px', fontSize: '0.85rem', color: '#dcfce7', marginTop: '0.5rem' }}>
                <TrendingUp size={16} /> Successful payments synced
              </div>
            </div>
          </div>

          <div className="glass" style={{ padding: '2rem', borderRadius: '24px', background: 'linear-gradient(to bottom, #fff, #f8fafc)', border: '1px solid rgba(0,0,0,0.05)', boxShadow: '0 10px 30px -10px rgba(0, 0, 0, 0.05)' }}>
            <div style={{ width: '48px', height: '48px', borderRadius: '16px', background: 'rgba(10, 102, 194, 0.1)', display: 'flex', alignItems: 'center', justifyContent: 'center', marginBottom: '1.5rem' }}>
               <LayoutGrid size={24} color="var(--primary)" />
            </div>
            <h3 style={{ fontSize: '1.3rem', fontWeight: 800, color: 'var(--text-main)', marginBottom: '0.5rem' }}>Quick Actions</h3>
            <p style={{ fontSize: '0.9rem', color: 'var(--text-muted)', marginBottom: '1.5rem', lineHeight: 1.5 }}>
              Rapidly navigate to frequently used administrative modules.
            </p>
            
            <div style={{ display: 'flex', flexDirection: 'column', gap: '0.75rem' }}>
              {[
                { title: "Grama Niladhari Ops", icon: MapPin },
                { title: "Review Escalations", icon: AlertTriangle },
                { title: "Citizen Directory", icon: Users },
              ].map((act, i) => (
                <div key={i} style={{ display: 'flex', alignItems: 'center', gap: '12px', padding: '12px 16px', borderRadius: '14px', border: '1px solid var(--border)', background: 'white', cursor: 'pointer', transition: 'all 0.2s' }} onMouseOver={e=>{e.currentTarget.style.borderColor='var(--primary)'; e.currentTarget.style.boxShadow='0 4px 12px rgba(10,102,194,0.1)';}} onMouseOut={e=>{e.currentTarget.style.borderColor='var(--border)'; e.currentTarget.style.boxShadow='none';}}>
                  <act.icon size={18} color="var(--primary)" />
                  <span style={{ flex: 1, fontSize: '0.9rem', fontWeight: 600, color: 'var(--text-main)' }}>{act.title}</span>
                  <ArrowUpRight size={16} color="var(--text-muted)" />
                </div>
              ))}
            </div>
          </div>
          
          <div className="glass" style={{ padding: '2rem', borderRadius: '24px', backgroundColor: '#1e293b', backgroundImage: 'radial-gradient(circle at top right, #334155, #0f172a)', color: 'white', border: '1px solid rgba(255,255,255,0.1)', boxShadow: '0 20px 40px -10px rgba(0, 0, 0, 0.4)' }}>
            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start', marginBottom: '1.5rem' }}>
              <h3 style={{ fontSize: '1.2rem', fontWeight: 700, display: 'flex', alignItems: 'center', gap: '0.5rem' }}>
                <Activity size={18} color="#34d399" /> System Health
              </h3>
            </div>
            
            <div style={{ display: 'flex', flexDirection: 'column', gap: '1rem' }}>
              <div>
                <div style={{ display: 'flex', justifyContent: 'space-between', marginBottom: '6px', fontSize: '0.85rem', fontWeight: 600, color: 'rgba(255,255,255,0.8)' }}>
                  <span>DB Sync Status</span>
                  <span style={{ color: '#34d399' }}>Connected</span>
                </div>
                <div style={{ height: '6px', width: '100%', backgroundColor: 'rgba(255,255,255,0.1)', borderRadius: '10px', overflow: 'hidden' }}>
                  <div style={{ height: '100%', width: '100%', backgroundColor: '#34d399', borderRadius: '10px' }} />
                </div>
              </div>
              
              <div>
                <div style={{ display: 'flex', justifyContent: 'space-between', marginBottom: '6px', fontSize: '0.85rem', fontWeight: 600, color: 'rgba(255,255,255,0.8)' }}>
                  <span>Division Load / Activity</span>
                  <span>Moderate</span>
                </div>
                <div style={{ height: '6px', width: '100%', backgroundColor: 'rgba(255,255,255,0.1)', borderRadius: '10px', overflow: 'hidden' }}>
                  <div style={{ height: '100%', width: '65%', backgroundColor: '#60a5fa', borderRadius: '10px' }} />
                </div>
              </div>
            </div>
          </div>
        </motion.div>
      </div>

    </motion.div>
  );
}
