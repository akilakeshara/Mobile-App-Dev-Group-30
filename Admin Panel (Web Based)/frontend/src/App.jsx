import React from 'react';
import { BrowserRouter, Routes, Route, Link, useLocation } from 'react-router-dom';
import { useTranslation } from 'react-i18next';
import { 
  LayoutDashboard, Users, Settings, LogOut, FileText, 
  Coins, MapPin, AlertOctagon, TrendingUp, Search, Bell, 
  ChevronRight, Calendar, UserCheck, ShieldCheck, FileSignature, Lock, Truck, Menu 
} from 'lucide-react';
/* eslint-disable no-unused-vars */
import { motion, AnimatePresence } from 'framer-motion';
/* eslint-enable no-unused-vars */
import Officers from './Officers';
import CivilRegistrations from './CivilRegistrations';
import Dashboard from './Dashboard';
import WasteSchedule from './WasteSchedule';
import EscalatedComplaints from './EscalatedComplaints';
import SystemSettings from './SystemSettings';
import ServiceApplications from './ServiceApplications';

import { auth, db } from './firebase';
import { signInWithEmailAndPassword, onAuthStateChanged, signOut } from 'firebase/auth';
import { doc, getDoc, collection, query, where, orderBy, onSnapshot, updateDoc } from 'firebase/firestore';


// --- Services Placeholder Component ---
const ServicesView = ({ title, icon }) => (
  <motion.div initial={{ opacity: 0, y: 10 }} animate={{ opacity: 1, y: 0 }} exit={{ opacity: 0 }}>
    <div style={{ display: 'flex', alignItems: 'center', gap: '1rem', marginBottom: '2rem' }}>
      <div style={{ padding: '1rem', backgroundColor: 'var(--primary)', color: 'white', borderRadius: '12px' }}>{icon}</div>
      <div>
        <h1 style={{ color: 'var(--text-main)', fontSize: '1.8rem', letterSpacing: '-0.5px' }}>{title}</h1>
        <p style={{ color: 'var(--text-muted)' }}>Manage Pradeshiya Lekam level applications</p>
      </div>
    </div>
    
    <div className="card glass" style={{ padding: '6rem 2rem', textAlign: 'center' }}>
      <Search size={48} color="var(--border)" style={{ margin: '0 auto 1.5rem auto' }} />
      <h2 style={{ color: 'var(--text-main)', marginBottom: '0.5rem' }}>Service Directory Loading...</h2>
      <p style={{ color: 'var(--text-muted)', maxWidth: '400px', margin: '0 auto' }}>
        This module controls the backend verifications for {title.toLowerCase()}. Authorized DS staff can process them here safely bypassing the Grama Niladhari stage.
      </p>
    </div>
  </motion.div>
);

// --- Layout Wrapper ---
const Layout = () => {
  const location = useLocation();
  const { t, i18n } = useTranslation();
  const [user, setUser] = React.useState(null);
  const [adminProfile, setAdminProfile] = React.useState(null);
  const [authChecking, setAuthChecking] = React.useState(true);

  // Login Form State
  const [email, setEmail] = React.useState('');
  const [password, setPassword] = React.useState('');
  const [authError, setAuthError] = React.useState('');
  const [isSubmitting, setIsSubmitting] = React.useState(false);
  const [notifications, setNotifications] = React.useState([]);
  const [showNotifications, setShowNotifications] = React.useState(false);
  const [isMobileMenuOpen, setIsMobileMenuOpen] = React.useState(false);

  React.useEffect(() => {
    let unsubscribeNotifs = null;
    
    const unsub = onAuthStateChanged(auth, async (u) => {
      if (u) {
        setUser(u);
        try {
          // Fetch the DS Admin's assigned division
          const docSnap = await getDoc(doc(db, 'ds_admins', u.uid));
          if (docSnap.exists()) {
            setAdminProfile({ id: docSnap.id, ...docSnap.data() });
          }
        } catch (error) {
          console.error("Failed to fetch admin profile:", error);
        }

        const q = query(
          collection(db, 'notifications'), 
          where('userId', '==', u.uid),
          orderBy('createdAt', 'desc')
        );
        unsubscribeNotifs = onSnapshot(q, (snap) => {
          setNotifications(snap.docs.map(doc => ({ id: doc.id, ...doc.data() })));
        });
        
        setAuthChecking(false);
      } else {
        setUser(null);
        setAdminProfile(null);
        setNotifications([]);
        if (unsubscribeNotifs) {
          unsubscribeNotifs();
        }
        setAuthChecking(false);
      }
    });
    
    return () => {
      unsub();
      if (unsubscribeNotifs) {
        unsubscribeNotifs();
      }
    };
  }, []);

  const handleAuthSubmit = async (e) => {
    e.preventDefault();
    setIsSubmitting(true);
    setAuthError('');
    try {
      await signInWithEmailAndPassword(auth, email, password);
    } catch {
      setAuthError('Invalid Administrator credentials.');
    } finally {
      setIsSubmitting(false);
    }
  };

  const navGroups = [
    {
      group: t("Overview"),
      items: [
        { path: '/', label: t('Command Center'), icon: <LayoutDashboard size={18} /> },
      ]
    },
    {
      group: t("DS Level Services"),
      items: [
        { path: '/civil', label: t('Civil Registrations'), icon: <FileSignature size={18} /> },
        { path: '/applications', label: t('Service Applications'), icon: <FileText size={18} /> },
        { path: '/waste', label: t('Waste Schedule'), icon: <Truck size={18} /> },
        { path: '/escalations', label: t('Escalated Complaints'), icon: <AlertOctagon size={18} /> },
      ]
    },
    {
      group: t("Administration"),
      items: [
        { path: '/officers', label: t('GN Officers Management'), icon: <UserCheck size={18} /> },
        { path: '/settings', label: t('System Settings'), icon: <Settings size={18} /> },
      ]
    }
  ];

  const toggleLanguage = () => {
    const newLang = i18n.language === 'en' ? 'si' : 'en';
    i18n.changeLanguage(newLang);
  };

  if (authChecking) {
    return <div style={{ minHeight: '100vh', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>Loading Administration Portal...</div>;
  }

  if (!user) {
    return (
      <div style={{ minHeight: '100vh', backgroundColor: 'var(--bg-color)', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
        <motion.div initial={{ opacity: 0, y: 10 }} animate={{ opacity: 1, y: 0 }} className="card glass" style={{ width: '100%', maxWidth: '400px', padding: '2.5rem' }}>
          <div style={{ textAlign: 'center', marginBottom: '2rem' }}>
            <div style={{ display: 'inline-flex', padding: '1rem', backgroundColor: 'rgba(10, 102, 194, 0.1)', color: 'var(--primary)', borderRadius: '50%', marginBottom: '1rem' }}>
              <Lock size={32} />
            </div>
            <h2 style={{ color: 'var(--text-main)', fontSize: '1.5rem', marginBottom: '0.5rem' }}>Admin Portal Login</h2>
            <p style={{ color: 'var(--text-muted)', fontSize: '0.9rem' }}>GovEase Divisional Secretariat</p>
          </div>
          {authError && <div style={{ padding: '0.75rem', backgroundColor: 'rgba(239, 68, 68, 0.1)', color: 'var(--danger)', borderRadius: '8px', marginBottom: '1rem', fontSize: '0.85rem', textAlign: 'center' }}>{authError}</div>}
          <form onSubmit={handleAuthSubmit} style={{ display: 'flex', flexDirection: 'column', gap: '1rem' }}>
            <div>
              <label style={{ display: 'block', fontSize: '0.85rem', fontWeight: 600, marginBottom: '0.5rem' }}>Admin Email</label>
              <input type="email" required className="input-field" value={email} onChange={e => setEmail(e.target.value)} />
            </div>
            <div>
              <label style={{ display: 'block', fontSize: '0.85rem', fontWeight: 600, marginBottom: '0.5rem' }}>Password</label>
              <input type="password" required className="input-field" value={password} onChange={e => setPassword(e.target.value)} />
            </div>
            <button disabled={isSubmitting} type="submit" className="btn-primary" style={{ marginTop: '0.5rem', width: '100%', opacity: isSubmitting ? 0.7 : 1 }}>
              {isSubmitting ? 'Authenticating...' : 'Secure Sign In'}
            </button>
          </form>
        </motion.div>
      </div>
    );
  }

  return (
    <div className="app-container">
      {/* Mobile Sidebar Overlay */}
      <div 
        className={`sidebar-overlay ${isMobileMenuOpen ? 'open' : ''}`}
        onClick={() => setIsMobileMenuOpen(false)}
      />

      {/* Sidebar */}
      <div className={`sidebar ${isMobileMenuOpen ? 'open' : ''}`} style={{ zIndex: 1010 }}>
        <div style={{ padding: '0.5rem 0 2rem 0', display: 'flex', alignItems: 'center', gap: '0.75rem' }}>
          <div style={{ backgroundColor: 'var(--primary)', backgroundImage: 'linear-gradient(135deg, var(--primary) 0%, var(--primary-dark) 100%)', color: 'white', padding: '0.6rem', borderRadius: '10px', boxShadow: '0 4px 12px rgba(10, 102, 194, 0.3)' }}>
            <ShieldCheck size={26} />
          </div>
          <div>
            <h2 style={{ fontSize: '1.3rem', color: 'var(--text-main)', letterSpacing: '-0.5px', fontWeight: 800 }}>GovEase <span style={{ color: 'var(--primary)' }}>Admin</span></h2>
            <p style={{ fontSize: '0.7rem', color: 'var(--text-muted)', fontWeight: '700', textTransform: 'uppercase', letterSpacing: '0.5px' }}>Pradeshiya Lekam</p>
          </div>
        </div>

        <nav style={{ flex: 1, display: 'flex', flexDirection: 'column', gap: '1.5rem', overflowY: 'auto' }}>
          {navGroups.map((group, idx) => (
            <div key={idx}>
              <h4 style={{ fontSize: '0.75rem', textTransform: 'uppercase', color: 'var(--text-muted)', letterSpacing: '1px', marginBottom: '0.75rem', paddingLeft: '0.5rem' }}>
                {group.group}
              </h4>
              <div style={{ display: 'flex', flexDirection: 'column', gap: '0.25rem' }}>
                {group.items.map((item) => {
                  const isActive = location.pathname === item.path;
                  return (
                    <Link 
                      key={item.path} 
                      to={item.path} 
                      style={{
                        display: 'flex',
                        alignItems: 'center',
                        gap: '0.75rem',
                        padding: '0.65rem 1rem',
                        borderRadius: '10px',
                        backgroundColor: isActive ? 'var(--primary)' : 'transparent',
                        color: isActive ? 'white' : 'var(--text-muted)',
                        fontWeight: isActive ? '600' : '500',
                        transition: 'all 0.2s cubic-bezier(0.4, 0, 0.2, 1)',
                        boxShadow: isActive ? '0 4px 12px rgba(10, 102, 194, 0.3)' : 'none'
                      }}
                    >
                      {item.icon}
                      {item.label}
                    </Link>
                  )
                })}
              </div>
            </div>
          ))}
        </nav>

        <div style={{ borderTop: '1px solid var(--border)', paddingTop: '1.5rem', marginTop: '1.5rem' }}>
          <div style={{ display: 'flex', alignItems: 'center', gap: '0.75rem', marginBottom: '1rem' }}>
            <img src={`https://ui-avatars.com/api/?name=${adminProfile?.name || user?.email || 'Admin+User'}&background=EEF3F8&color=0A66C2`} alt="Avatar" style={{ width: '40px', height: '40px', borderRadius: '50%' }} />
            <div style={{ overflow: 'hidden' }}>
              <p style={{ fontSize: '0.9rem', fontWeight: '700', whiteSpace: 'nowrap', textOverflow: 'ellipsis' }}>{adminProfile?.name || user?.email || 'Admin User'}</p>
              <p style={{ fontSize: '0.75rem', color: 'var(--text-muted)' }}>{adminProfile?.dsDivision ? `${adminProfile.dsDivision} DS` : 'Divisional Secretary'}</p>
            </div>
          </div>
          <button onClick={() => signOut(auth)} style={{ display: 'flex', alignItems: 'center', gap: '0.75rem', color: 'var(--danger)', fontWeight: '600', padding: '0.65rem 1rem', width: '100%', borderRadius: '10px', transition: 'background 0.2s' }} onMouseOver={e => e.currentTarget.style.backgroundColor = '#FEF2F2'} onMouseOut={e => e.currentTarget.style.backgroundColor = 'transparent'}>
            <LogOut size={18} />
            Secure Logout
          </button>
        </div>
      </div>

      {/* Main Content Pane */}
      <div className="main-content flex-1" style={{ position: 'relative' }}>
        {/* Decorative background element */}
        <div style={{ position: 'absolute', top: 0, left: 0, right: 0, height: '250px', backgroundImage: 'linear-gradient(to bottom, #E8F2FC, transparent)', zIndex: 0, pointerEvents: 'none' }} />
        
        <div className="topbar glass" style={{ zIndex: 10, background: 'rgba(255,255,255,0.85)', backdropFilter: 'blur(20px)', position: 'sticky', top: 0 }}>
          <div style={{ display: 'flex', alignItems: 'center', gap: '1rem' }}>
            <button className="show-on-mobile" onClick={() => setIsMobileMenuOpen(true)}>
              <Menu size={24} color="var(--text-main)" />
            </button>
            <div className="hide-on-mobile" style={{ position: 'relative', width: '300px' }}>
              <Search size={18} color="var(--text-muted)" style={{ position: 'absolute', left: '12px', top: '50%', transform: 'translateY(-50%)' }} />
              <input type="text" placeholder={t("Trace ID or Subject...")} className="input-field" style={{ paddingLeft: '2.5rem', borderRadius: '99px', backgroundColor: 'transparent', border: '1px solid var(--border)' }} />
            </div>
          </div>
          <div style={{ display: 'flex', alignItems: 'center', gap: '1.5rem', position: 'relative' }}>
            <button className="hide-on-mobile" style={{ display: 'flex', alignItems: 'center', gap: '0.5rem', fontSize: '0.85rem', fontWeight: 600, color: 'var(--text-main)', border: '1px solid var(--border)', padding: '0.4rem 0.8rem', borderRadius: '8px', cursor: 'pointer', background: 'transparent' }} onClick={toggleLanguage}>
               {i18n.language === 'en' ? 'සිංහල' : 'English'}
            </button>
            <button className="hide-on-mobile" style={{ display: 'flex', alignItems: 'center', gap: '0.5rem', fontSize: '0.85rem', fontWeight: 600, color: 'var(--primary)', border: '1px solid var(--primary)', padding: '0.4rem 0.8rem', borderRadius: '8px', cursor: 'pointer', background: 'transparent' }} onClick={() => window.print()}>
               <FileText size={16} /> {t("Export PDF")}
            </button>
            <button 
              onClick={() => setShowNotifications(!showNotifications)}
              style={{ position: 'relative', color: 'var(--text-muted)', background: 'none', border: 'none', cursor: 'pointer' }}
            >
              <Bell size={22} />
              {notifications.filter(n => !n.isRead).length > 0 && (
                <span style={{ 
                  position: 'absolute', top: '-4px', right: '-4px', 
                  backgroundColor: 'var(--danger)', color: 'white', 
                  fontSize: '0.65rem', fontWeight: 'bold',
                  padding: '2px 5px', borderRadius: '10px', border: '2px solid white' 
                }}>
                  {notifications.filter(n => !n.isRead).length}
                </span>
              )}
            </button>
            
            {/* Notifications Dropdown */}
            <AnimatePresence>
              {showNotifications && (
                <motion.div 
                  initial={{ opacity: 0, y: 15, scale: 0.95 }}
                  animate={{ opacity: 1, y: 0, scale: 1 }}
                  exit={{ opacity: 0, y: 10, scale: 0.95 }}
                  transition={{ duration: 0.2, type: 'spring', damping: 25, stiffness: 300 }}
                  style={{
                    position: 'absolute', top: '50px', right: '0', width: '380px',
                    backgroundColor: 'rgba(255, 255, 255, 0.85)', backdropFilter: 'blur(25px)',
                    borderRadius: '16px', boxShadow: '0 20px 40px rgba(0,0,0,0.12), 0 0 0 1px rgba(255,255,255,0.6)',
                    zIndex: 100, overflow: 'hidden'
                  }}
                >
                  <div style={{ padding: '16px 24px', borderBottom: '1px solid rgba(0,0,0,0.06)', display: 'flex', justifyContent: 'space-between', alignItems: 'center', backgroundColor: 'rgba(255,255,255,0.5)' }}>
                    <div style={{ display: 'flex', alignItems: 'center', gap: '10px' }}>
                      <h3 style={{ margin: 0, fontSize: '1.1rem', color: '#111827', fontWeight: '800', letterSpacing: '-0.3px' }}>Notifications</h3>
                      {notifications.filter(n => !n.isRead).length > 0 && (
                        <span style={{ backgroundColor: 'var(--danger)', color: 'white', fontSize: '0.65rem', fontWeight: '700', padding: '3px 8px', borderRadius: '10px', textTransform: 'uppercase', letterSpacing: '0.5px' }}>
                          {notifications.filter(n => !n.isRead).length} New
                        </span>
                      )}
                    </div>
                    {notifications.filter(n => !n.isRead).length > 0 && (
                      <span 
                        style={{ fontSize: '0.8rem', color: 'var(--primary)', cursor: 'pointer', fontWeight: '600', transition: 'color 0.2s' }} 
                        onMouseOver={e => e.currentTarget.style.color = 'var(--primary-dark)'}
                        onMouseOut={e => e.currentTarget.style.color = 'var(--primary)'}
                        onClick={async () => {
                          const unreads = notifications.filter(n => !n.isRead);
                          for (const un of unreads) {
                            await updateDoc(doc(db, 'notifications', un.id), { isRead: true });
                          }
                        }}
                      >Mark all read</span>
                    )}
                  </div>
                  <div style={{ maxHeight: '400px', overflowY: 'auto', padding: '8px' }} className="custom-scrollbar">
                    {notifications.length === 0 ? (
                      <div style={{ padding: '50px 20px', textAlign: 'center', display: 'flex', flexDirection: 'column', alignItems: 'center', gap: '12px' }}>
                        <div style={{ width: '56px', height: '56px', borderRadius: '50%', backgroundColor: 'rgba(0,0,0,0.02)', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
                          <Bell size={26} color="#d1d5db" />
                        </div>
                        <p style={{ margin: 0, color: '#9ca3af', fontSize: '0.9rem', fontWeight: '600' }}>You're all caught up!</p>
                        <p style={{ margin: 0, color: '#d1d5db', fontSize: '0.75rem', fontWeight: '500' }}>No new alerts at the moment.</p>
                      </div>
                    ) : (
                      notifications.map(notif => {
                        const time = notif.createdAt?.toDate ? notif.createdAt.toDate().toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' }) : '';
                        
                        return (
                          <motion.div 
                            key={notif.id}
                            initial={{ x: -10, opacity: 0 }}
                            animate={{ x: 0, opacity: 1 }}
                            onClick={async () => {
                              if (!notif.isRead) {
                                await updateDoc(doc(db, 'notifications', notif.id), { isRead: true });
                              }
                            }}
                            style={{ 
                              padding: '16px 20px', margin: '4px', borderRadius: '12px',
                              backgroundColor: notif.isRead ? 'transparent' : 'rgba(10, 102, 194, 0.06)',
                              cursor: 'pointer', transition: 'all 0.25s cubic-bezier(0.4, 0, 0.2, 1)',
                              border: notif.isRead ? '1px solid transparent' : '1px solid rgba(10, 102, 194, 0.1)',
                              position: 'relative',
                              display: 'flex', gap: '14px'
                            }}
                            onMouseOver={e => {
                              e.currentTarget.style.backgroundColor = notif.isRead ? 'rgba(0,0,0,0.03)' : 'rgba(10, 102, 194, 0.1)';
                              e.currentTarget.style.transform = 'scale(1.01)';
                            }}
                            onMouseOut={e => {
                              e.currentTarget.style.backgroundColor = notif.isRead ? 'transparent' : 'rgba(10, 102, 194, 0.06)';
                              e.currentTarget.style.transform = 'scale(1)';
                            }}
                          >
                            {!notif.isRead && <div style={{ position: 'absolute', left: '-1px', top: '16px', bottom: '16px', width: '4px', backgroundColor: 'var(--primary)', borderRadius: '0 4px 4px 0' }} />}
                            
                            <div style={{ flex: 1 }}>
                              <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start', marginBottom: '6px' }}>
                                <span style={{ fontWeight: notif.isRead ? '600' : '700', fontSize: '0.9rem', color: notif.isRead ? '#374151' : 'var(--primary)', lineHeight: 1.3 }}>
                                  {notif.title}
                                </span>
                                <span style={{ fontSize: '0.7rem', color: notif.isRead ? '#9ca3af' : 'var(--primary)', fontWeight: '600', whiteSpace: 'nowrap', marginLeft: '10px' }}>{time}</span>
                              </div>
                              <p style={{ margin: 0, fontSize: '0.8rem', color: '#4b5563', lineHeight: 1.5 }}>{notif.body}</p>
                            </div>
                          </motion.div>
                        );
                      })
                    )}
                  </div>
                </motion.div>
              )}
            </AnimatePresence>
          </div>
        </div>
        
        <div className="content-area" style={{ zIndex: 1, position: 'relative' }}>
          <AnimatePresence mode="wait">
            <Routes location={location} key={location.pathname}>
              <Route path="/" element={<Dashboard adminProfile={adminProfile} />} />
              <Route path="/civil" element={<CivilRegistrations adminProfile={adminProfile} />} />
              <Route path="/applications" element={<ServiceApplications adminProfile={adminProfile} />} />
              <Route path="/waste" element={<WasteSchedule adminProfile={adminProfile} />} />
              <Route path="/escalations" element={<EscalatedComplaints adminProfile={adminProfile} />} />
              <Route path="/officers" element={<Officers adminProfile={adminProfile} />} />
              <Route path="/settings" element={<SystemSettings adminProfile={adminProfile} />} />
              <Route path="*" element={<Dashboard adminProfile={adminProfile} />} />
            </Routes>
          </AnimatePresence>
        </div>
      </div>
    </div>
  );
};

function App() {
  return (
    <BrowserRouter>
      <Layout />
    </BrowserRouter>
  );
}

export default App;
