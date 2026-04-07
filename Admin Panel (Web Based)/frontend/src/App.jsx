import React from 'react';
import { BrowserRouter, Routes, Route, Link, useLocation } from 'react-router-dom';
import { useTranslation } from 'react-i18next';
import { 
  LayoutDashboard, Users, Settings, LogOut, FileText, 
  Coins, MapPin, AlertOctagon, TrendingUp, Search, Bell, 
  ChevronRight, Calendar, UserCheck, ShieldCheck, FileSignature, Lock, Truck, Menu, Globe
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
import Payments from './Payments';
import { generateAdminReport } from './utils/pdfGenerator';

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
  const [pdfLoading, setPdfLoading] = React.useState(false);
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
        { path: '/payments', label: t('Payments Hub'), icon: <Coins size={18} /> },
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
    let newLang = 'en';
    if (i18n.language === 'en') newLang = 'si';
    else if (i18n.language === 'si') newLang = 'ta';
    i18n.changeLanguage(newLang);
  };

  if (authChecking) {
    return <div style={{ minHeight: '100vh', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>Loading Administration Portal...</div>;
  }

  if (!user) {
    return (
      <div style={{ 
        minHeight: '100vh', 
        display: 'flex', 
        alignItems: 'center', 
        justifyContent: 'center', 
        backgroundColor: '#F1F5F9',
        position: 'relative',
        overflow: 'hidden',
        padding: '2rem'
      }}>
        {/* Animated Background Orbs */}
        <div style={{ position: 'absolute', inset: 0, opacity: 0.8, pointerEvents: 'none', zIndex: 0 }}>
          <motion.div
            animate={{ x: [0, 150, 0], y: [0, -100, 0], scale: [1, 1.2, 1] }}
            transition={{ duration: 25, repeat: Infinity, ease: "linear" }}
            style={{ position: 'absolute', top: '10%', left: '15%', width: '50vw', height: '50vw', background: 'radial-gradient(circle, rgba(10,102,194,0.15) 0%, transparent 60%)', borderRadius: '50%', filter: 'blur(60px)' }}
          />
          <motion.div
            animate={{ x: [0, -200, 0], y: [0, 150, 0], scale: [1, 1.3, 1] }}
            transition={{ duration: 30, repeat: Infinity, ease: "easeInOut" }}
            style={{ position: 'absolute', bottom: '-10%', right: '5%', width: '60vw', height: '60vw', background: 'radial-gradient(circle, rgba(99,102,241,0.12) 0%, transparent 60%)', borderRadius: '50%', filter: 'blur(60px)' }}
          />
          <motion.div
            animate={{ x: [0, 100, 0], y: [0, 200, 0] }}
            transition={{ duration: 20, repeat: Infinity, ease: "easeInOut" }}
            style={{ position: 'absolute', top: '30%', right: '25%', width: '30vw', height: '30vw', background: 'radial-gradient(circle, rgba(20,184,166,0.1) 0%, transparent 60%)', borderRadius: '50%', filter: 'blur(50px)' }}
          />
        </div>

        {/* Floating Glass Bento Box */}
        <motion.div 
          initial={{ opacity: 0, y: 40, scale: 0.97 }} 
          animate={{ opacity: 1, y: 0, scale: 1 }} 
          transition={{ duration: 0.8, type: 'spring', damping: 25, stiffness: 120 }}
          style={{
            zIndex: 1,
            display: 'flex',
            flexDirection: 'row',
            width: '100%',
            maxWidth: '1100px',
            minHeight: '650px',
            background: 'rgba(255, 255, 255, 0.7)',
            backdropFilter: 'blur(25px)',
            WebkitBackdropFilter: 'blur(25px)',
            borderRadius: '32px',
            overflow: 'hidden',
            boxShadow: '0 25px 50px -12px rgba(10, 102, 194, 0.15), 0 0 0 1px rgba(255, 255, 255, 0.8) inset',
          }}
        >
          {/* Left Side: Dynamic Branding pane */}
          <div className="hide-on-mobile" style={{ 
            flex: '1.2', 
            position: 'relative',
            padding: '4rem',
            display: 'flex',
            flexDirection: 'column',
            justifyContent: 'space-between',
            background: 'linear-gradient(135deg, rgba(10, 102, 194, 0.95) 0%, rgba(0, 65, 130, 0.98) 100%)',
            overflow: 'hidden',
            color: 'white'
          }}>
            {/* Inner decorative grid and shapes */}
            <div style={{ position: 'absolute', inset: 0, backgroundImage: 'linear-gradient(rgba(255,255,255,0.05) 1px, transparent 1px), linear-gradient(90deg, rgba(255,255,255,0.05) 1px, transparent 1px)', backgroundSize: '40px 40px', opacity: 0.3 }} />
            
            <motion.div initial={{ opacity: 0, x: -30 }} animate={{ opacity: 1, x: 0 }} transition={{ delay: 0.3, duration: 0.8, type: 'spring' }}>
              <div style={{ display: 'inline-flex', padding: '14px', background: 'rgba(255,255,255,0.1)', backdropFilter: 'blur(10px)', border: '1px solid rgba(255,255,255,0.2)', borderRadius: '20px', marginBottom: '2rem', boxShadow: '0 8px 32px rgba(0,0,0,0.1)' }}>
                <ShieldCheck size={38} color="#fff" strokeWidth={1.5} />
              </div>
              <h1 style={{ fontSize: '3.8rem', fontWeight: 800, lineHeight: 1.05, letterSpacing: '-1.5px', marginBottom: '1.5rem', textShadow: '0 4px 12px rgba(0,0,0,0.1)' }}>
                Divisional<br/>Secretariat<br/><span style={{ color: '#93C5FD' }}>Intelligence.</span>
              </h1>
              <p style={{ color: 'rgba(255,255,255,0.85)', fontSize: '1.15rem', maxWidth: '380px', lineHeight: 1.6, fontWeight: 400 }}>
                Centralized administrative portal for Government Officials. Secure, real-time, and built for national scale.
              </p>
            </motion.div>

            <motion.div initial={{ opacity: 0 }} animate={{ opacity: 1 }} transition={{ delay: 0.6 }} style={{ color: 'rgba(255,255,255,0.5)', fontSize: '0.85rem', display: 'flex', alignItems: 'center', gap: '8px' }}>
              <Lock size={14} />
              <span>State Level 256-bit Encryption • v2.4.0</span>
            </motion.div>
          </div>

          {/* Right Side: Pristine Form pane */}
          <div style={{ 
            flex: '1', 
            padding: '4rem', 
            display: 'flex', 
            flexDirection: 'column', 
            justifyContent: 'center',
            position: 'relative'
          }}>
            <motion.div initial={{ opacity: 0, y: 20 }} animate={{ opacity: 1, y: 0 }} transition={{ delay: 0.4, duration: 0.6 }}>
              <div className="show-on-mobile" style={{ marginBottom: '2rem' }}>
                <div style={{ display: 'inline-flex', padding: '12px', background: 'var(--primary-light)', color: 'var(--primary)', borderRadius: '16px' }}>
                  <ShieldCheck size={32} />
                </div>
              </div>

              <h2 style={{ color: 'var(--text-main)', fontSize: '2.2rem', fontWeight: 800, letterSpacing: '-1px', marginBottom: '0.5rem' }}>
                Welcome back
              </h2>
              <p style={{ color: 'var(--text-muted)', fontSize: '1rem', marginBottom: '3rem' }}>
                Sign in to your administrative dashboard.
              </p>

              <form onSubmit={handleAuthSubmit} style={{ display: 'flex', flexDirection: 'column', gap: '1.5rem' }}>
                <AnimatePresence>
                  {authError && (
                    <motion.div initial={{ opacity: 0, height: 0, y: -10 }} animate={{ opacity: 1, height: 'auto', y: 0 }} exit={{ opacity: 0, height: 0 }}>
                      <div style={{ padding: '1rem', backgroundColor: 'rgba(239, 68, 68, 0.1)', borderLeft: '4px solid #EF4444', color: '#B91C1C', borderRadius: '8px', fontSize: '0.85rem', fontWeight: 600, display: 'flex', alignItems: 'center', gap: '8px' }}>
                        <AlertOctagon size={18} />
                        {authError}
                      </div>
                    </motion.div>
                  )}
                </AnimatePresence>
                
                <motion.div initial={{ opacity: 0, x: 20 }} animate={{ opacity: 1, x: 0 }} transition={{ delay: 0.5 }}>
                  <label style={{ display: 'block', fontSize: '0.85rem', color: 'var(--text-main)', fontWeight: 700, marginBottom: '0.6rem' }}>Gov Email</label>
                  <div style={{ position: 'relative' }}>
                    <div style={{ position: 'absolute', left: '16px', top: '50%', transform: 'translateY(-50%)', color: 'var(--text-muted)' }}>
                      <UserCheck size={20} />
                    </div>
                    <input 
                      type="email" 
                      required 
                      placeholder="admin@ds.gov.lk"
                      style={{ 
                        width: '100%', padding: '0 1rem 0 3rem', height: '54px', fontSize: '1rem', 
                        backgroundColor: '#F8FAFC', border: '2px solid transparent', borderRadius: '16px', 
                        transition: 'all 0.3s cubic-bezier(0.4, 0, 0.2, 1)', outline: 'none',
                        color: 'var(--text-main)', fontWeight: 500
                      }}
                      value={email} 
                      onChange={e => setEmail(e.target.value)} 
                      onFocus={e => { e.target.style.backgroundColor = '#fff'; e.target.style.borderColor = 'var(--primary)'; e.target.style.boxShadow = '0 0 0 5px rgba(10,102,194,0.1)'; }}
                      onBlur={e => { e.target.style.backgroundColor = '#F8FAFC'; e.target.style.borderColor = 'transparent'; e.target.style.boxShadow = 'none'; }}
                    />
                  </div>
                </motion.div>

                <motion.div initial={{ opacity: 0, x: 20 }} animate={{ opacity: 1, x: 0 }} transition={{ delay: 0.6 }}>
                  <label style={{ display: 'block', fontSize: '0.85rem', color: 'var(--text-main)', fontWeight: 700, marginBottom: '0.6rem' }}>Passcode</label>
                  <div style={{ position: 'relative' }}>
                    <div style={{ position: 'absolute', left: '16px', top: '50%', transform: 'translateY(-50%)', color: 'var(--text-muted)' }}>
                      <Lock size={20} />
                    </div>
                    <input 
                      type="password" 
                      required 
                      placeholder="••••••••"
                      style={{ 
                        width: '100%', padding: '0 1rem 0 3rem', height: '54px', fontSize: '1.2rem', letterSpacing: '2px',
                        backgroundColor: '#F8FAFC', border: '2px solid transparent', borderRadius: '16px', 
                        transition: 'all 0.3s cubic-bezier(0.4, 0, 0.2, 1)', outline: 'none',
                        color: 'var(--text-main)', fontWeight: 700
                      }}
                      value={password} 
                      onChange={e => setPassword(e.target.value)} 
                      onFocus={e => { e.target.style.backgroundColor = '#fff'; e.target.style.borderColor = 'var(--primary)'; e.target.style.boxShadow = '0 0 0 5px rgba(10,102,194,0.1)'; }}
                      onBlur={e => { e.target.style.backgroundColor = '#F8FAFC'; e.target.style.borderColor = 'transparent'; e.target.style.boxShadow = 'none'; }}
                    />
                  </div>
                </motion.div>

                <motion.div initial={{ opacity: 0, y: 20 }} animate={{ opacity: 1, y: 0 }} transition={{ delay: 0.7 }}>
                  <button 
                    disabled={isSubmitting} 
                    type="submit" 
                    style={{ 
                      marginTop: '1rem', 
                      height: '56px', 
                      width: '100%', 
                      background: 'linear-gradient(135deg, var(--primary) 0%, #084c94 100%)', 
                      color: 'white', 
                      borderRadius: '16px', 
                      fontSize: '1rem', 
                      fontWeight: 700, 
                      border: 'none', 
                      cursor: isSubmitting ? 'wait' : 'pointer',
                      display: 'flex',
                      alignItems: 'center',
                      justifyContent: 'center',
                      gap: '0.75rem',
                      boxShadow: '0 10px 25px -5px rgba(10, 102, 194, 0.4)',
                      transition: 'all 0.3s cubic-bezier(0.4, 0, 0.2, 1)',
                      opacity: isSubmitting ? 0.8 : 1,
                      position: 'relative',
                      overflow: 'hidden'
                    }}
                    onMouseOver={e => !isSubmitting && (e.currentTarget.style.transform = 'translateY(-3px)', e.currentTarget.style.boxShadow = '0 15px 30px -5px rgba(10, 102, 194, 0.5)')}
                    onMouseOut={e => !isSubmitting && (e.currentTarget.style.transform = 'translateY(0)', e.currentTarget.style.boxShadow = '0 10px 25px -5px rgba(10, 102, 194, 0.4)')}
                  >
                    {isSubmitting ? (
                      <motion.div animate={{ rotate: 360 }} transition={{ repeat: Infinity, duration: 1, ease: 'linear' }}>
                        <Lock size={20} />
                      </motion.div>
                    ) : (
                      <>
                        Secure Sign In
                        <ChevronRight size={20} />
                      </>
                    )}
                  </button>
                </motion.div>
              </form>
            </motion.div>
          </div>
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
              <button onClick={toggleLanguage} style={{ display: 'flex', alignItems: 'center', gap: '6px', fontSize: '0.8rem', fontWeight: 600, padding: '6px 12px', border: '1px solid var(--border)', borderRadius: '20px', backgroundColor: 'var(--bg-color)', color: 'var(--text-main)' }}>
                <Globe size={14} /> 
                {i18n.language === 'ta' ? 'தமிழ்' : i18n.language === 'si' ? 'සිංහල' : 'English'}
              </button>
            <button 
              className="hide-on-mobile" 
              style={{ display: 'flex', alignItems: 'center', gap: '0.5rem', fontSize: '0.85rem', fontWeight: 600, color: 'var(--primary)', border: '1px solid var(--primary)', padding: '0.4rem 0.8rem', borderRadius: '8px', cursor: pdfLoading ? 'not-allowed' : 'pointer', background: 'transparent', opacity: pdfLoading ? 0.7 : 1 }} 
              onClick={() => generateAdminReport(adminProfile, setPdfLoading)}
              disabled={pdfLoading}
            >
               <FileText size={16} /> {pdfLoading ? t("Generating...") : t("Export PDF")}
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
              <Route path="/payments" element={<Payments adminProfile={adminProfile} />} />
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
