import React, { useState, useEffect } from 'react';
import { motion, AnimatePresence } from 'framer-motion';
import { FileText, Search, ShieldCheck, CheckCircle2, XCircle, Clock, Eye, AlertCircle, RefreshCw, Layers, CheckCircle, X, ExternalLink } from 'lucide-react';
import { db } from './firebase';
import { collection, onSnapshot, query, orderBy, getDoc, doc, updateDoc } from 'firebase/firestore';
import { decryptText } from './utils/encryption';

export default function ServiceApplications({ adminProfile }) {
  const [applications, setApplications] = useState([]);
  const [validCitizens, setValidCitizens] = useState(new Map());
  const [searchTerm, setSearchTerm] = useState('');
  const [loading, setLoading] = useState(true);
  const [selectedApp, setSelectedApp] = useState(null);

  const normalize = (s) => (s || '').toLowerCase()
    .replace(/\b(ps|mc|uc|sabha|council|division|ds|urban|municipal|lekam|kottasha|pradeshiya)\b/g, '')
    .replace(/[^a-z0-9]/g, '')
    .trim();

  useEffect(() => {
    const adminDS = adminProfile?.dsDivision;
    const normAdminDS = normalize(adminDS);

    // Fetch valid citizens for strict filtering fallback
    const qCitizens = collection(db, 'citizens');
    const unsubCitizens = onSnapshot(qCitizens, (snapshot) => {
      const map = new Map();
      snapshot.forEach(docSnap => {
        const data = docSnap.data();
        const pSabha = normalize(decryptText(data.pradeshiyaSabha));
        const division = normalize(decryptText(data.division));
        
        if (!adminDS || pSabha.includes(normAdminDS) || division.includes(normAdminDS)) {
          map.set(docSnap.id, data);
        }
      });
      setValidCitizens(map);
    }, (error) => console.error("Citizens sync issue:", error));

    return () => unsubCitizens();
  }, [adminProfile]);

  useEffect(() => {
    const qApps = query(collection(db, 'applications'));

    const unsubApps = onSnapshot(qApps, (snapshot) => {
      const list = [];
      snapshot.forEach((docSnap) => {
        const data = docSnap.data();
        list.push({
          id: docSnap.id,
          ...data,
          type: data.serviceType || 'DS Service Request',
          applicant: data.formData?.fullName || data.applicantName || 'Citizen',
          status: data.status || 'Pending',
          createdAt: data.createdAt ? new Date(data.createdAt) : new Date(),
          userId: data.userId || '',
          gnDivision: data.gnDivision || '',
          rawString: JSON.stringify(data).toLowerCase()
        });
      });
      setApplications(list);
      setLoading(false);
    }, (error) => {
      console.error("Error fetching applications:", error);
      setLoading(false);
    });

    return () => unsubApps();
  }, []);

  const handleStatusUpdate = async (id, currentStatus) => {
    let nextStatus = currentStatus;
    if (currentStatus === 'Submitted' || currentStatus === 'Pending') nextStatus = 'Processing';
    else if (currentStatus === 'Processing') nextStatus = 'Verified';
    else if (currentStatus === 'Verified') nextStatus = 'Completed';
    else if (currentStatus === 'Declined') nextStatus = 'Submitted';
    else if (currentStatus === 'Completed' || currentStatus === 'Approved') nextStatus = 'Declined';
    
    if (nextStatus === currentStatus) return;
    
    try {
      await updateDoc(doc(db, 'applications', id), { 
        status: nextStatus,
        statusUpdatedAt: new Date().toISOString()
      });
    } catch (e) {
      alert("Failed to update status.");
    }
  };

  const handleDecision = async (id, newStatus) => {
    try {
      await updateDoc(doc(db, 'applications', id), { 
        status: newStatus,
        statusUpdatedAt: new Date().toISOString()
      });
      setSelectedApp(null);
    } catch (e) {
      alert("Failed to record decision. Please try again.");
    }
  };

  const getStatusStyle = (status) => {
    switch (status) {
      case 'Approved':
      case 'Completed': return { bg: '#dcfce7', text: '#166534', icon: <CheckCircle2 size={14}/> };
      case 'Verified': return { bg: '#dbeafe', text: '#1e40af', icon: <ShieldCheck size={14}/> };
      case 'Declined':
      case 'Rejected': return { bg: '#fee2e2', text: '#991b1b', icon: <XCircle size={14}/> };
      case 'Processing': return { bg: '#fef3c7', text: '#92400e', icon: <Clock size={14}/> };
      default: return { bg: '#f3f4f6', text: '#4b5563', icon: <Clock size={14}/> };
    }
  };

  const filteredApps = applications.filter(app => {
    const adminDS = adminProfile?.dsDivision;
    const normAdminDS = normalize(adminDS);
    
    let belongsToDS = false;
    if (!adminDS) belongsToDS = true;
    else if (app.gnDivision && normalize(app.gnDivision).includes(normAdminDS)) belongsToDS = true;
    else if (validCitizens.has(app.userId)) belongsToDS = true;
    else if (app.rawString && app.rawString.includes(normAdminDS)) belongsToDS = true; // Absolute fallback
    
    if (!belongsToDS) return false;
    
    return app.type?.toLowerCase().includes(searchTerm.toLowerCase()) ||
      app.applicant?.toLowerCase().includes(searchTerm.toLowerCase()) ||
      app.id.toLowerCase().includes(searchTerm.toLowerCase());
  }).sort((a,b) => {
    const dateA = a.createdAt ? new Date(a.createdAt).getTime() : 0;
    const dateB = b.createdAt ? new Date(b.createdAt).getTime() : 0;
    return dateB - dateA;
  });

  const totalApps = filteredApps.length;
  const pendingApps = filteredApps.filter(a => a.status === 'Submitted' || a.status === 'Pending').length;
  const inProgressApps = filteredApps.filter(a => a.status === 'Processing' || a.status === 'Verified').length;
  const completedApps = filteredApps.filter(a => a.status === 'Completed' || a.status === 'Approved').length;

  return (
    <motion.div initial={{ opacity: 0, y: 10 }} animate={{ opacity: 1, y: 0 }} exit={{ opacity: 0 }}>
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '2rem' }}>
        <div>
          <h1 style={{ color: 'var(--text-main)', fontSize: '1.8rem', letterSpacing: '-0.5px', display: 'flex', alignItems: 'center', gap: '0.5rem' }}>
            <FileText color="var(--primary)" size={28} />
            Service Applications
          </h1>
          <p style={{ color: 'var(--text-muted)', marginTop: '5px' }}>
            Manage and process civic service requests for {adminProfile?.dsDivision ? adminProfile.dsDivision.replace(' DS', '') : 'your division'}
          </p>
        </div>
        <button 
          style={{ background: 'var(--primary)', color: 'white', border: 'none', padding: '10px 20px', borderRadius: '50px', display: 'flex', alignItems: 'center', gap: '8px', cursor: 'pointer', fontWeight: 600, boxShadow: '0 4px 15px rgba(37, 99, 235, 0.2)' }}
          onMouseOver={e=>e.currentTarget.style.transform='translateY(-2px)'}
          onMouseOut={e=>e.currentTarget.style.transform='translateY(0)'}
        >
          <RefreshCw size={18} /> Refresh Queue
        </button>
      </div>

      {/* Summary Cards */}
      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(200px, 1fr))', gap: '1.5rem', marginBottom: '2rem' }}>
        <motion.div initial={{ opacity: 0, y: 10 }} animate={{ opacity: 1, y: 0 }} transition={{ delay: 0.1 }} className="glass" style={{ padding: '1.5rem', borderRadius: '16px', borderLeft: '4px solid var(--primary)', display: 'flex', alignItems: 'center', gap: '15px' }}>
          <div style={{ background: 'rgba(37, 99, 235, 0.1)', padding: '12px', borderRadius: '50%' }}>
            <Layers size={24} color="var(--primary)" />
          </div>
          <div>
            <h3 style={{ fontSize: '0.75rem', color: 'var(--text-muted)', textTransform: 'uppercase', fontWeight: 700, letterSpacing: '0.5px', margin: '0 0 4px 0' }}>Total Requests</h3>
            <p style={{ fontSize: '1.6rem', fontWeight: 800, color: 'var(--text-main)', margin: 0 }}>{totalApps}</p>
          </div>
        </motion.div>
        
        <motion.div initial={{ opacity: 0, y: 10 }} animate={{ opacity: 1, y: 0 }} transition={{ delay: 0.2 }} className="glass" style={{ padding: '1.5rem', borderRadius: '16px', borderLeft: '4px solid #f59e0b', display: 'flex', alignItems: 'center', gap: '15px' }}>
          <div style={{ background: 'rgba(245, 158, 11, 0.1)', padding: '12px', borderRadius: '50%' }}>
            <AlertCircle size={24} color="#f59e0b" />
          </div>
          <div>
            <h3 style={{ fontSize: '0.75rem', color: 'var(--text-muted)', textTransform: 'uppercase', fontWeight: 700, letterSpacing: '0.5px', margin: '0 0 4px 0' }}>New / Pending</h3>
            <p style={{ fontSize: '1.6rem', fontWeight: 800, color: 'var(--text-main)', margin: 0 }}>{pendingApps}</p>
          </div>
        </motion.div>

        <motion.div initial={{ opacity: 0, y: 10 }} animate={{ opacity: 1, y: 0 }} transition={{ delay: 0.3 }} className="glass" style={{ padding: '1.5rem', borderRadius: '16px', borderLeft: '4px solid #3b82f6', display: 'flex', alignItems: 'center', gap: '15px' }}>
          <div style={{ background: 'rgba(59, 130, 246, 0.1)', padding: '12px', borderRadius: '50%' }}>
            <Clock size={24} color="#3b82f6" />
          </div>
          <div>
            <h3 style={{ fontSize: '0.75rem', color: 'var(--text-muted)', textTransform: 'uppercase', fontWeight: 700, letterSpacing: '0.5px', margin: '0 0 4px 0' }}>In Progress</h3>
            <p style={{ fontSize: '1.6rem', fontWeight: 800, color: 'var(--text-main)', margin: 0 }}>{inProgressApps}</p>
          </div>
        </motion.div>

        <motion.div initial={{ opacity: 0, y: 10 }} animate={{ opacity: 1, y: 0 }} transition={{ delay: 0.4 }} className="glass" style={{ padding: '1.5rem', borderRadius: '16px', borderLeft: '4px solid #10b981', display: 'flex', alignItems: 'center', gap: '15px' }}>
          <div style={{ background: 'rgba(16, 185, 129, 0.1)', padding: '12px', borderRadius: '50%' }}>
            <CheckCircle size={24} color="#10b981" />
          </div>
          <div>
            <h3 style={{ fontSize: '0.75rem', color: 'var(--text-muted)', textTransform: 'uppercase', fontWeight: 700, letterSpacing: '0.5px', margin: '0 0 4px 0' }}>Completed</h3>
            <p style={{ fontSize: '1.6rem', fontWeight: 800, color: 'var(--text-main)', margin: 0 }}>{completedApps}</p>
          </div>
        </motion.div>
      </div>

      <div className="card glass" style={{ padding: 0, overflow: 'hidden' }}>
        <div style={{ padding: '1.5rem', borderBottom: '1px solid var(--border)', display: 'flex', gap: '1rem', backgroundColor: 'var(--surface)' }}>
          <div style={{ position: 'relative', width: '400px' }}>
            <Search size={18} color="var(--text-muted)" style={{ position: 'absolute', left: '12px', top: '50%', transform: 'translateY(-50%)' }} />
            <input 
              type="text" 
              placeholder="Search by reference ID, applicant, or service..." 
              className="input-field" 
              style={{ paddingLeft: '2.5rem' }}
              value={searchTerm}
              onChange={(e) => setSearchTerm(e.target.value)}
            />
          </div>
        </div>

        <div style={{ overflowX: 'auto' }}>
          <table style={{ width: '100%', borderCollapse: 'collapse', textAlign: 'left' }}>
            <thead style={{ backgroundColor: 'var(--primary-light)', color: 'var(--primary-dark)', fontSize: '0.85rem' }}>
              <tr>
                <th style={{ padding: '1.2rem 1.5rem', fontWeight: '600' }}>Reference & Request Info</th>
                <th style={{ padding: '1.2rem 1.5rem', fontWeight: '600' }}>Citizen details</th>
                <th style={{ padding: '1.2rem 1.5rem', fontWeight: '600' }}>Submission Date</th>
                <th style={{ padding: '1.2rem 1.5rem', fontWeight: '600' }}>Administrative Status</th>
                <th style={{ padding: '1.2rem 1.5rem', fontWeight: '600', textAlign: 'right' }}>Action Workflow</th>
              </tr>
            </thead>
            <tbody>
              {loading ? (
                <tr>
                  <td colSpan="5" style={{ padding: '4rem', textAlign: 'center' }}>
                    <div className="animate-pulse">Loading service requests...</div>
                  </td>
                </tr>
              ) : filteredApps.length === 0 ? (
                <tr>
                  <td colSpan="5" style={{ padding: '4rem', textAlign: 'center', color: 'var(--text-muted)' }}>
                    No service applications match your criteria.
                  </td>
                </tr>
              ) : filteredApps.map((app) => {
                const sStyle = getStatusStyle(app.status);
                return (
                  <tr key={app.id} style={{ borderBottom: '1px solid var(--border)', fontSize: '0.95rem', transition: 'background-color 0.2s' }} onMouseOver={e => e.currentTarget.style.backgroundColor='rgba(10, 102, 194, 0.02)'} onMouseOut={e => e.currentTarget.style.backgroundColor='transparent'}>
                    <td style={{ padding: '1.2rem 1.5rem' }}>
                      <div style={{ display: 'flex', flexDirection: 'column', gap: '0.2rem' }}>
                        <span style={{ fontWeight: '700', color: 'var(--text-main)', fontSize: '0.95rem' }}>{app.type}</span>
                        <span style={{ fontSize: '0.75rem', color: 'var(--text-muted)', fontFamily: 'monospace', letterSpacing: '0.5px' }}>
                          REF: {app.id.substring(0, 10).toUpperCase()}
                        </span>
                      </div>
                    </td>
                    <td style={{ padding: '1.2rem 1.5rem' }}>
                      <div style={{ fontWeight: '600', color: 'var(--text-main)' }}>{app.applicant}</div>
                    </td>
                    <td style={{ padding: '1.2rem 1.5rem', color: 'var(--text-muted)', fontSize: '0.9rem' }}>
                      {app.createdAt.toLocaleDateString(undefined, { year: 'numeric', month: 'short', day: 'numeric'})}
                    </td>
                    <td style={{ padding: '1.2rem 1.5rem' }}>
                      <span style={{
                        display: 'inline-flex', alignItems: 'center', gap: '6px',
                        backgroundColor: sStyle.bg, color: sStyle.text,
                        padding: '0.3rem 0.8rem', borderRadius: '50px',
                        fontSize: '0.75rem', fontWeight: '700', textTransform: 'uppercase'
                      }}>
                        {sStyle.icon} {app.status}
                      </span>
                    </td>
                    <td style={{ padding: '1.2rem 1.5rem', textAlign: 'right' }}>
                      <div style={{ display: 'flex', justifyContent: 'flex-end', alignItems: 'center', gap: '0.8rem' }}>
                        <button 
                          onClick={() => setSelectedApp(app)}
                          style={{ width: '34px', height: '34px', padding: 0, borderRadius: '8px', border: '1px solid var(--border)', background: 'white', color: 'var(--text-main)', cursor: 'pointer', transition: 'all 0.2s', display: 'flex', alignItems: 'center', justifyContent: 'center' }}
                          title="View Application Details"
                          onMouseOver={e=>e.currentTarget.style.background='var(--surface)'} onMouseOut={e=>e.currentTarget.style.background='white'}
                        >
                          <Eye size={16} />
                        </button>
                        
                        {(app.status === 'Submitted' || app.status === 'Pending') && (
                          <button 
                            onClick={() => handleStatusUpdate(app.id, app.status)}
                            style={{ height: '34px', padding: '0 1rem', borderRadius: '8px', border: 'none', background: 'var(--primary)', color: 'white', fontWeight: 600, fontSize: '0.8rem', cursor: 'pointer', transition: 'all 0.2s', boxShadow: '0 2px 10px rgba(37, 99, 235, 0.2)' }}
                            onMouseOver={e=>e.currentTarget.style.transform='translateY(-1px)'} onMouseOut={e=>e.currentTarget.style.transform='translateY(0)'}
                          >
                            Mark Processing
                          </button>
                        )}
                        {app.status === 'Processing' && (
                          <button 
                            onClick={() => handleStatusUpdate(app.id, app.status)}
                            style={{ height: '34px', padding: '0 1rem', borderRadius: '8px', border: 'none', background: 'var(--primary)', color: 'white', fontWeight: 600, fontSize: '0.8rem', cursor: 'pointer', transition: 'all 0.2s', boxShadow: '0 2px 10px rgba(37, 99, 235, 0.2)' }}
                            onMouseOver={e=>e.currentTarget.style.transform='translateY(-1px)'} onMouseOut={e=>e.currentTarget.style.transform='translateY(0)'}
                          >
                            Verify Data
                          </button>
                        )}
                        {app.status === 'Verified' && (
                          <button 
                            onClick={() => handleStatusUpdate(app.id, app.status)}
                            style={{ height: '34px', padding: '0 1rem', borderRadius: '8px', border: 'none', background: '#10b981', color: 'white', fontWeight: 600, fontSize: '0.8rem', cursor: 'pointer', transition: 'all 0.2s', boxShadow: '0 2px 10px rgba(16, 185, 129, 0.2)' }}
                            onMouseOver={e=>e.currentTarget.style.transform='translateY(-1px)'} onMouseOut={e=>e.currentTarget.style.transform='translateY(0)'}
                          >
                            Approve
                          </button>
                        )}
                        {app.status === 'Completed' && (
                          <div style={{ height: '34px', padding: '0 1rem', borderRadius: '8px', background: 'rgba(16, 185, 129, 0.1)', color: '#10b981', fontWeight: 700, fontSize: '0.8rem', display: 'flex', alignItems: 'center', gap: '6px' }}>
                            <CheckCircle2 size={16} /> Done
                          </div>
                        )}
                        {app.status === 'Declined' && (
                          <div style={{ height: '34px', padding: '0 1rem', borderRadius: '8px', background: 'rgba(239, 68, 68, 0.1)', color: '#ef4444', fontWeight: 700, fontSize: '0.8rem', display: 'flex', alignItems: 'center', gap: '6px' }}>
                            <XCircle size={16} /> Closed
                          </div>
                        )}
                      </div>
                    </td>
                  </tr>
                )
              })}
            </tbody>
          </table>
        </div>
      </div>

      <AnimatePresence>
        {selectedApp && (
          <div style={{ position: 'fixed', top: 0, left: 0, right: 0, bottom: 0, backgroundColor: 'rgba(0,0,0,0.5)', backdropFilter: 'blur(4px)', zIndex: 100, display: 'flex', justifyContent: 'center', alignItems: 'center', padding: '2rem' }}>
            <motion.div 
              initial={{ opacity: 0, scale: 0.95, y: 20 }} animate={{ opacity: 1, scale: 1, y: 0 }} exit={{ opacity: 0, scale: 0.95, y: 20 }}
              style={{ background: 'white', borderRadius: '24px', width: '100%', maxWidth: '800px', maxHeight: '90vh', display: 'flex', flexDirection: 'column', overflow: 'hidden', boxShadow: '0 25px 50px -12px rgba(0, 0, 0, 0.25)' }}
            >
              <div style={{ padding: '1.5rem 2rem', borderBottom: '1px solid var(--border)', display: 'flex', justifyContent: 'space-between', alignItems: 'center', background: 'var(--surface)' }}>
                <div>
                  <h2 style={{ fontSize: '1.4rem', fontWeight: 800, color: 'var(--text-main)', margin: 0 }}>{selectedApp.type}</h2>
                  <p style={{ fontSize: '0.85rem', color: 'var(--text-muted)', margin: '4px 0 0 0', fontFamily: 'monospace' }}>REF: {selectedApp.id}</p>
                </div>
                <button onClick={() => setSelectedApp(null)} style={{ background: 'transparent', border: 'none', cursor: 'pointer', color: 'var(--text-muted)' }}><X size={24} /></button>
              </div>

              <div style={{ padding: '2rem', overflowY: 'auto', flex: 1, display: 'flex', flexDirection: 'column', gap: '2rem' }}>
                <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(280px, 1fr))', gap: '2rem' }}>
                  <div>
                    <h3 style={{ fontSize: '0.9rem', textTransform: 'uppercase', color: 'var(--text-muted)', fontWeight: 700, letterSpacing: '0.5px', marginBottom: '1rem', display: 'flex', alignItems: 'center', gap: '8px' }}><ShieldCheck size={16} color="var(--primary)" /> Citizen Demographics</h3>
                    <div style={{ background: 'rgba(37, 99, 235, 0.03)', padding: '1.2rem', borderRadius: '12px', border: '1px solid rgba(37, 99, 235, 0.1)', display: 'flex', flexDirection: 'column', gap: '0.8rem' }}>
                      <div style={{ display: 'flex', flexDirection: 'column' }}>
                        <span style={{ fontSize: '0.75rem', color: 'var(--text-muted)', textTransform: 'uppercase' }}>Full Name</span>
                        <strong style={{ color: 'var(--text-main)', fontSize: '1rem' }}>{selectedApp.applicant}</strong>
                      </div>
                      
                      {(() => {
                        const cit = validCitizens.get(selectedApp.userId);
                        if (!cit) return <p style={{ fontSize: '0.85rem', color: 'var(--text-muted)', margin: 0 }}>Basic profile only.</p>;
                        return (
                          <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '0.8rem', marginTop: '0.5rem' }}>
                            <div style={{ display: 'flex', flexDirection: 'column' }}>
                              <span style={{ fontSize: '0.7rem', color: 'var(--text-muted)', textTransform: 'uppercase' }}>NIC No.</span>
                              <span style={{ color: 'var(--title-color)', fontWeight: 600, fontSize: '0.9rem' }}>{decryptText(cit.nic) || '-'}</span>
                            </div>
                            <div style={{ display: 'flex', flexDirection: 'column' }}>
                              <span style={{ fontSize: '0.7rem', color: 'var(--text-muted)', textTransform: 'uppercase' }}>Phone</span>
                              <span style={{ color: 'var(--title-color)', fontWeight: 600, fontSize: '0.9rem' }}>{cit.phone || '-'}</span>
                            </div>
                            <div style={{ display: 'flex', flexDirection: 'column', gridColumn: '1 / -1' }}>
                              <span style={{ fontSize: '0.7rem', color: 'var(--text-muted)', textTransform: 'uppercase' }}>Gramasewa Wasama</span>
                              <span style={{ color: 'var(--title-color)', fontWeight: 500, fontSize: '0.85rem' }}>{decryptText(cit.gramasewaWasama) || '-'}</span>
                            </div>
                            <div style={{ display: 'flex', flexDirection: 'column', gridColumn: '1 / -1' }}>
                              <span style={{ fontSize: '0.7rem', color: 'var(--text-muted)', textTransform: 'uppercase' }}>Divisional Secretariat</span>
                              <span style={{ color: 'var(--title-color)', fontWeight: 500, fontSize: '0.85rem' }}>{decryptText(cit.pradeshiyaSabha) || decryptText(cit.division) || '-'}</span>
                            </div>
                          </div>
                        );
                      })()}
                    </div>
                  </div>

                  <div>
                    <h3 style={{ fontSize: '0.9rem', textTransform: 'uppercase', color: 'var(--text-muted)', fontWeight: 700, letterSpacing: '0.5px', marginBottom: '1rem', display: 'flex', alignItems: 'center', gap: '8px' }}><FileText size={16} color="var(--primary)" /> Application Details</h3>
                    <div style={{ background: 'rgba(0,0,0,0.02)', padding: '1.2rem', borderRadius: '12px', border: '1px solid var(--border)', display: 'flex', flexDirection: 'column', gap: '0.8rem' }}>
                      <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '0.8rem' }}>
                        <div style={{ display: 'flex', flexDirection: 'column' }}>
                          <span style={{ fontSize: '0.7rem', color: 'var(--text-muted)', textTransform: 'uppercase' }}>Submission Date</span>
                          <span style={{ color: 'var(--title-color)', fontWeight: 600, fontSize: '0.9rem' }}>{selectedApp.createdAt.toLocaleDateString()}</span>
                        </div>
                        <div style={{ display: 'flex', flexDirection: 'column' }}>
                          <span style={{ fontSize: '0.7rem', color: 'var(--text-muted)', textTransform: 'uppercase' }}>Current Status</span>
                          <strong style={{ color: getStatusStyle(selectedApp.status).text, fontSize: '0.9rem' }}>{selectedApp.status}</strong>
                        </div>
                      </div>
                      
                      <div style={{ height: '1px', background: 'var(--border)', margin: '0.5rem 0' }}></div>
                      
                      {selectedApp.formData && Object.keys(selectedApp.formData).length > 0 ? (
                        <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '0.8rem' }}>
                          {Object.entries(selectedApp.formData).map(([key, val]) => (
                            <div key={key} style={{ display: 'flex', flexDirection: 'column', gridColumn: val?.length > 40 ? '1 / -1' : 'auto' }}>
                              <span style={{ fontSize: '0.7rem', color: 'var(--text-muted)', textTransform: 'uppercase' }}>{key.replace(/([A-Z])/g, ' $1').trim()}</span>
                              <span style={{ fontSize: '0.9rem', color: 'var(--text-main)', fontWeight: 500 }}>{val || '-'}</span>
                            </div>
                          ))}
                        </div>
                      ) : (
                        <p style={{ margin: 0, color: 'var(--text-muted)', fontSize: '0.85rem', fontStyle: 'italic' }}>No additional form data provided.</p>
                      )}
                    </div>
                  </div>
                </div>

                {selectedApp.documentUrls && Object.keys(selectedApp.documentUrls).length > 0 && (
                  <div>
                    <h3 style={{ fontSize: '0.9rem', textTransform: 'uppercase', color: 'var(--text-muted)', fontWeight: 700, letterSpacing: '0.5px', marginBottom: '1rem' }}>Attached Documents</h3>
                    <div style={{ display: 'flex', gap: '1rem', flexWrap: 'wrap' }}>
                      {Object.entries(selectedApp.documentUrls).map(([key, url]) => (
                        <a key={key} href={url} target="_blank" rel="noopener noreferrer" style={{ display: 'flex', alignItems: 'center', gap: '8px', padding: '0.8rem 1.2rem', background: 'var(--primary-light)', color: 'var(--primary-dark)', borderRadius: '8px', textDecoration: 'none', fontWeight: 600, fontSize: '0.85rem', border: '1px solid rgba(37, 99, 235, 0.2)' }}>
                          <FileText size={16} /> {key.replace(/_/g, ' ').toUpperCase()} <ExternalLink size={14} />
                        </a>
                      ))}
                    </div>
                  </div>
                )}
              </div>

              <div style={{ padding: '1.5rem 2rem', borderTop: '1px solid var(--border)', background: 'var(--surface)', display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
                <span style={{ color: 'var(--text-muted)', fontSize: '0.85rem' }}>Action Required: Administrative Decision</span>
                <div style={{ display: 'flex', gap: '1rem' }}>
                  {selectedApp.status !== 'Declined' && selectedApp.status !== 'Completed' && selectedApp.status !== 'Approved' && (
                    <button onClick={() => handleDecision(selectedApp.id, 'Declined')} style={{ padding: '0.8rem 1.5rem', borderRadius: '50px', background: 'transparent', border: '1px solid #ef4444', color: '#ef4444', fontWeight: 600, cursor: 'pointer', transition: 'all 0.2s' }} onMouseOver={e=>e.currentTarget.style.background='#fee2e2'} onMouseOut={e=>e.currentTarget.style.background='transparent'}>
                      Decline Request
                    </button>
                  )}
                  {selectedApp.status === 'Submitted' || selectedApp.status === 'Pending' ? (
                    <button onClick={() => handleDecision(selectedApp.id, 'Processing')} style={{ padding: '0.8rem 1.5rem', borderRadius: '50px', background: 'var(--primary)', border: 'none', color: 'white', fontWeight: 600, cursor: 'pointer', transition: 'all 0.2s', boxShadow: '0 4px 15px rgba(37, 99, 235, 0.3)' }} onMouseOver={e=>e.currentTarget.style.transform='translateY(-2px)'} onMouseOut={e=>e.currentTarget.style.transform='translateY(0)'}>
                      Mark Processing
                    </button>
                  ) : selectedApp.status === 'Processing' ? (
                    <button onClick={() => handleDecision(selectedApp.id, 'Verified')} style={{ padding: '0.8rem 1.5rem', borderRadius: '50px', background: 'var(--primary)', border: 'none', color: 'white', fontWeight: 600, cursor: 'pointer', transition: 'all 0.2s', boxShadow: '0 4px 15px rgba(37, 99, 235, 0.3)' }} onMouseOver={e=>e.currentTarget.style.transform='translateY(-2px)'} onMouseOut={e=>e.currentTarget.style.transform='translateY(0)'}>
                      Verify Documents
                    </button>
                  ) : selectedApp.status === 'Verified' ? (
                    <button onClick={() => handleDecision(selectedApp.id, 'Completed')} style={{ padding: '0.8rem 1.5rem', borderRadius: '50px', background: '#10b981', border: 'none', color: 'white', fontWeight: 600, cursor: 'pointer', transition: 'all 0.2s', boxShadow: '0 4px 15px rgba(16, 185, 129, 0.3)' }} onMouseOver={e=>e.currentTarget.style.transform='translateY(-2px)'} onMouseOut={e=>e.currentTarget.style.transform='translateY(0)'}>
                      Approve & Complete
                    </button>
                  ) : null}
                  {(selectedApp.status === 'Completed' || selectedApp.status === 'Approved' || selectedApp.status === 'Declined') && (
                    <button onClick={() => handleDecision(selectedApp.id, 'Submitted')} style={{ padding: '0.8rem 1.5rem', borderRadius: '50px', background: 'var(--surface)', border: '1px solid var(--border)', color: 'var(--text-main)', fontWeight: 600, cursor: 'pointer', transition: 'all 0.2s' }}>
                      Re-open Application
                    </button>
                  )}
                </div>
              </div>
            </motion.div>
          </div>
        )}
      </AnimatePresence>
    </motion.div>
  );
}
