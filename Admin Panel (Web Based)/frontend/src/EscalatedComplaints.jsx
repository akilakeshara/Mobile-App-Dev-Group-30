import React, { useState, useEffect } from 'react';
import { createPortal } from 'react-dom';
import { motion, AnimatePresence } from 'framer-motion';
import { AlertOctagon, Search, MapPin, Calendar, CheckCircle, Clock, ClipboardList, AlertCircle, X, Eye, FileText, Image as ImageIcon } from 'lucide-react';
import { db } from './firebase';
import { collection, onSnapshot, updateDoc, doc, query, orderBy } from 'firebase/firestore';
import { decryptText } from './utils/encryption';

export default function EscalatedComplaints({ adminProfile }) {
  const [complaints, setComplaints] = useState([]);
  const [validCitizenIds, setValidCitizenIds] = useState(null);
  const [searchTerm, setSearchTerm] = useState('');
  const [loading, setLoading] = useState(true);
  const [selectedComplaint, setSelectedComplaint] = useState(null);
  const [updating, setUpdating] = useState(false);

  useEffect(() => {
    const adminDS = adminProfile?.dsDivision;
    const qCitizens = collection(db, 'citizens');
    
    const unsubscribeCitizens = onSnapshot(qCitizens, (snapshot) => {
      const ids = new Set();
      snapshot.forEach((docSnap) => {
        const data = docSnap.data();
        const decryptedPS = decryptText(data.pradeshiyaSabha);
        const decryptedDiv = decryptText(data.division);
        
        const normalize = (s) => (s || '').toLowerCase()
          .replace(/\b(ps|mc|uc|sabha|council|division|ds|urban|municipal|lekam|kottasha|pradeshiya)\b/g, '')
          .replace(/[^a-z0-9]/g, '')
          .trim();
        
        const normAdminDS = normalize(adminDS);
        const normCitizenPS = normalize(decryptedPS);
        const normCitizenDiv = normalize(decryptedDiv);
        
        if (!adminDS || normCitizenPS.includes(normAdminDS) || normCitizenDiv.includes(normAdminDS)) {
          ids.add(docSnap.id);
        }
      });
      setValidCitizenIds(ids);
    }, (error) => {
      console.error("Error fetching citizens:", error);
      setValidCitizenIds(new Set());
    });

    return () => unsubscribeCitizens();
  }, [adminProfile]);

  useEffect(() => {
    // Only fetch complaints. Ideally, a cloud function limits this or indexes it.
    // We order by createdAt descending.
    const q = query(collection(db, 'complaints'), orderBy('createdAt', 'desc'));
    
    const unsubscribe = onSnapshot(q, (snapshot) => {
      const list = [];
      snapshot.forEach((docSnap) => {
        const data = docSnap.data();
        
        // Filter by DS Division if the admin has one, assuming we might only want relevant complaints via gnDivision logic
        // For now, DS Admins see complaints within their province/division if gnDivision falls under it.
        // We will just show all or filter if needed based on adminProfile
        
        list.push({
          id: docSnap.id,
          ...data,
          title: data.title || 'Untitled',
          category: data.category || 'General',
          description: data.description || '',
          location: data.location || 'Unknown Location',
          status: data.status || 'Open',
          priority: data.priority || 'Medium',
          createdAt: data.createdAt,
          gnDivision: data.gnDivision || '',
          isAnonymous: data.isAnonymous || false,
          imageUrl: data.imageUrl || data.image_url || null,
          citizenName: data.citizenName || 'Unknown Citizen',
        });
      });
      
      setComplaints(list);
      setLoading(false);
    }, (error) => {
      console.error("Error fetching complaints:", error);
      setLoading(false);
    });

    return () => unsubscribe();
  }, [adminProfile]);

  const handleStatusChange = async (id, newStatus) => {
    setUpdating(true);
    try {
      await updateDoc(doc(db, 'complaints', id), { status: newStatus });
      if (selectedComplaint && selectedComplaint.id === id) {
        setSelectedComplaint({ ...selectedComplaint, status: newStatus });
      }
    } catch (e) {
      console.error("Status update failed", e);
    } finally {
      setUpdating(false);
    }
  };

  const filteredComplaints = complaints.filter(c => {
    if (validCitizenIds && !validCitizenIds.has(c.userId)) {
      return false; // Skip if citizen doesn't belong to this DS
    }
    
    return c.title?.toLowerCase().includes(searchTerm.toLowerCase()) ||
      c.category?.toLowerCase().includes(searchTerm.toLowerCase()) ||
      c.location?.toLowerCase().includes(searchTerm.toLowerCase()) ||
      c.gnDivision?.toLowerCase().includes(searchTerm.toLowerCase());
  });

  const getPriorityColor = (prio) => {
    switch (prio) {
      case 'High': return 'var(--danger)';
      case 'Medium': return 'var(--warning)';
      default: return 'var(--success)';
    }
  };

  const getStatusBadge = (status) => {
    switch (status) {
      case 'Open': return { bg: 'rgba(239, 68, 68, 0.1)', text: 'var(--danger)' };
      case 'In Progress': return { bg: 'rgba(245, 158, 11, 0.1)', text: 'var(--warning)' };
      case 'Closed': return { bg: 'rgba(16, 185, 129, 0.1)', text: 'var(--success)' };
      default: return { bg: 'rgba(156, 163, 175, 0.1)', text: 'var(--text-muted)' };
    }
  };

  return (
    <motion.div initial={{ opacity: 0, y: 10 }} animate={{ opacity: 1, y: 0 }} exit={{ opacity: 0 }}>
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '2rem' }}>
        <div>
          <h1 style={{ color: 'var(--text-main)', fontSize: '1.8rem', letterSpacing: '-0.5px', display: 'flex', alignItems: 'center', gap: '0.5rem' }}>
            <AlertOctagon color="var(--danger)" size={28} />
            Escalated Complaints
          </h1>
          <p style={{ color: 'var(--text-muted)' }}>
            Real-time citizen reports and issues requiring attention
          </p>
        </div>
      </div>

      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(200px, 1fr))', gap: '1rem', marginBottom: '1.5rem' }}>
        <div className="card glass" style={{ display: 'flex', alignItems: 'center', gap: '1rem', padding: '1.5rem' }}>
          <div style={{ backgroundColor: 'rgba(59, 130, 246, 0.1)', color: '#3b82f6', padding: '1rem', borderRadius: '12px' }}>
            <ClipboardList size={26} />
          </div>
          <div>
            <p style={{ color: 'var(--text-muted)', fontSize: '0.85rem', fontWeight: 600, textTransform: 'uppercase' }}>Total Complaints</p>
            <h3 style={{ color: 'var(--text-main)', fontSize: '1.8rem', marginTop: '0.2rem', fontWeight: 800 }}>{filteredComplaints.length}</h3>
          </div>
        </div>
        
        <div className="card glass" style={{ display: 'flex', alignItems: 'center', gap: '1rem', padding: '1.5rem' }}>
          <div style={{ backgroundColor: 'rgba(239, 68, 68, 0.1)', color: 'var(--danger)', padding: '1rem', borderRadius: '12px' }}>
            <AlertCircle size={26} />
          </div>
          <div>
            <p style={{ color: 'var(--text-muted)', fontSize: '0.85rem', fontWeight: 600, textTransform: 'uppercase' }}>New / Open</p>
            <h3 style={{ color: 'var(--text-main)', fontSize: '1.8rem', marginTop: '0.2rem', fontWeight: 800 }}>{filteredComplaints.filter(c => c.status === 'Open').length}</h3>
          </div>
        </div>

        <div className="card glass" style={{ display: 'flex', alignItems: 'center', gap: '1rem', padding: '1.5rem' }}>
          <div style={{ backgroundColor: 'rgba(245, 158, 11, 0.1)', color: 'var(--warning)', padding: '1rem', borderRadius: '12px' }}>
            <Clock size={26} />
          </div>
          <div>
            <p style={{ color: 'var(--text-muted)', fontSize: '0.85rem', fontWeight: 600, textTransform: 'uppercase' }}>In Progress</p>
            <h3 style={{ color: 'var(--text-main)', fontSize: '1.8rem', marginTop: '0.2rem', fontWeight: 800 }}>{filteredComplaints.filter(c => c.status === 'In Progress').length}</h3>
          </div>
        </div>

        <div className="card glass" style={{ display: 'flex', alignItems: 'center', gap: '1rem', padding: '1.5rem' }}>
          <div style={{ backgroundColor: 'rgba(16, 185, 129, 0.1)', color: 'var(--success)', padding: '1rem', borderRadius: '12px' }}>
            <CheckCircle size={26} />
          </div>
          <div>
            <p style={{ color: 'var(--text-muted)', fontSize: '0.85rem', fontWeight: 600, textTransform: 'uppercase' }}>Resolved</p>
            <h3 style={{ color: 'var(--text-main)', fontSize: '1.8rem', marginTop: '0.2rem', fontWeight: 800 }}>{filteredComplaints.filter(c => c.status === 'Closed').length}</h3>
          </div>
        </div>
      </div>

      <div className="card glass" style={{ padding: 0, overflow: 'hidden' }}>
        <div style={{ padding: '1.5rem', borderBottom: '1px solid var(--border)', display: 'flex', gap: '1rem', backgroundColor: 'var(--surface)' }}>
          <div style={{ position: 'relative', width: '400px' }}>
            <Search size={18} color="var(--text-muted)" style={{ position: 'absolute', left: '12px', top: '50%', transform: 'translateY(-50%)' }} />
            <input 
              type="text" 
              placeholder="Search by title, location or GN division..." 
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
                <th style={{ padding: '1rem 1.5rem', fontWeight: '600' }}>Issue Details</th>
                <th style={{ padding: '1rem 1.5rem', fontWeight: '600' }}>Location & Division</th>
                <th style={{ padding: '1rem 1.5rem', fontWeight: '600' }}>Priority & Date</th>
                <th style={{ padding: '1rem 1.5rem', fontWeight: '600' }}>Current Status</th>
                <th style={{ padding: '1rem 1.5rem', fontWeight: '600', textAlign: 'right' }}>Actions</th>
              </tr>
            </thead>
            <tbody>
              {loading ? (
                <tr>
                  <td colSpan="4" style={{ padding: '4rem', textAlign: 'center' }}>
                    <div className="animate-pulse">Syncing complaints from real-time database...</div>
                  </td>
                </tr>
              ) : filteredComplaints.length === 0 ? (
                <tr>
                  <td colSpan="4" style={{ padding: '4rem', textAlign: 'center', color: 'var(--text-muted)' }}>
                    No complaints found.
                  </td>
                </tr>
              ) : filteredComplaints.map((comp) => {
                const sBadge = getStatusBadge(comp.status);
                return (
                  <tr key={comp.id} style={{ borderBottom: '1px solid var(--border)', fontSize: '0.95rem', transition: 'background-color 0.2s' }} onMouseOver={e => e.currentTarget.style.backgroundColor='rgba(0,0,0,0.01)'} onMouseOut={e => e.currentTarget.style.backgroundColor='transparent'}>
                    <td style={{ padding: '1.2rem 1.5rem' }}>
                      <div style={{ display: 'flex', flexDirection: 'column', gap: '0.2rem' }}>
                        <span style={{ fontWeight: '700', color: 'var(--text-main)' }}>{comp.title}</span>
                        <span style={{ fontSize: '0.8rem', color: 'var(--text-muted)' }}>{comp.category} • {comp.isAnonymous ? 'Anonymous' : 'Reported User'}</span>
                      </div>
                    </td>
                    <td style={{ padding: '1.2rem 1.5rem' }}>
                      <div style={{ display: 'flex', flexDirection: 'column', gap: '0.2rem' }}>
                        <div style={{ display: 'flex', alignItems: 'center', gap: '0.25rem', color: 'var(--text-main)', fontWeight: '600', fontSize: '0.9rem' }}>
                          <MapPin size={14} color="var(--primary)" /> {comp.location}
                        </div>
                        {comp.gnDivision && (
                          <span style={{ fontSize: '0.75rem', color: 'var(--text-muted)', marginLeft: '1.2rem' }}>
                            {comp.gnDivision} GN Div.
                          </span>
                        )}
                      </div>
                    </td>
                    <td style={{ padding: '1.2rem 1.5rem', color: 'var(--text-muted)' }}>
                      <div style={{ display: 'flex', flexDirection: 'column', gap: '0.3rem' }}>
                        <span style={{ display: 'inline-flex', alignItems: 'center', gap: '4px', fontSize: '0.75rem', fontWeight: 'bold', color: getPriorityColor(comp.priority) }}>
                           {comp.priority} Priority
                        </span>
                        <div style={{ display: 'flex', alignItems: 'center', gap: '0.4rem', fontSize: '0.85rem' }}>
                          <Calendar size={14} />
                          {comp.createdAt ? new Date(comp.createdAt).toLocaleDateString() : 'N/A'}
                        </div>
                      </div>
                    </td>
                    <td style={{ padding: '1.2rem 1.5rem' }}>
                      <span
                        style={{
                          backgroundColor: sBadge.bg, color: sBadge.text,
                          padding: '0.4rem 0.8rem', borderRadius: '50px',
                          display: 'inline-flex', alignItems: 'center', gap: '6px',
                          fontSize: '0.75rem', fontWeight: '700', textTransform: 'uppercase'
                        }}
                      >
                        {comp.status === 'Closed' ? <CheckCircle size={14} /> : <Clock size={14} />}
                        {comp.status}
                      </span>
                    </td>
                    <td style={{ padding: '1.2rem 1.5rem', textAlign: 'right' }}>
                      <button 
                        onClick={() => setSelectedComplaint(comp)}
                        style={{ background: 'var(--primary-light)', color: 'var(--primary)', padding: '0.5rem', borderRadius: '8px', cursor: 'pointer', border: '1px solid var(--primary-light)', display: 'inline-flex', transition: 'all 0.2s' }}
                        onMouseOver={e => {e.currentTarget.style.background = 'var(--primary)'; e.currentTarget.style.color = 'white';}}
                        onMouseOut={e => {e.currentTarget.style.background = 'var(--primary-light)'; e.currentTarget.style.color = 'var(--primary)';}}
                      >
                        <Eye size={18} />
                      </button>
                    </td>
                  </tr>
                )
              })}
            </tbody>
          </table>
        </div>
      </div>

      {createPortal(
        <AnimatePresence>
          {selectedComplaint && (
            <>
              <motion.div
              initial={{ opacity: 0 }} animate={{ opacity: 1 }} exit={{ opacity: 0 }}
              style={{ position: 'fixed', top: 0, left: 0, right: 0, bottom: 0, background: 'rgba(0,0,0,0.6)', backdropFilter: 'blur(4px)', zIndex: 9999, display: 'flex', alignItems: 'center', justifyContent: 'center' }}
              onClick={() => setSelectedComplaint(null)}
            >
              <div 
                style={{ width: '100%', height: '100%', display: 'flex', alignItems: 'center', justifyContent: 'center', padding: '1rem' }}
              >
                <motion.div
                  initial={{ opacity: 0, y: 50, scale: 0.95 }}
                  animate={{ opacity: 1, y: 0, scale: 1 }}
                  exit={{ opacity: 0, y: 20, scale: 0.95 }}
                  transition={{ type: 'spring', damping: 25, stiffness: 300 }}
                  className="card glass"
                  onClick={e => e.stopPropagation()} // prevent clicking inside from closing it
                  style={{ width: '100%', maxWidth: '700px', maxHeight: '90vh', overflowY: 'auto', padding: 0, position: 'relative' }}
                >
                  <div style={{ padding: '1.5rem 2rem', borderBottom: '1px solid rgba(0,0,0,0.05)', display: 'flex', justifyContent: 'space-between', alignItems: 'center', background: 'white', position: 'sticky', top: 0, zIndex: 2 }}>
                <h2 style={{ fontSize: '1.4rem', fontWeight: 800, color: 'var(--text-main)', display: 'flex', alignItems: 'center', gap: '0.5rem' }}>
                  <AlertCircle color="var(--primary)" size={22} />
                  Complaint Details
                </h2>
                <button 
                  onClick={() => setSelectedComplaint(null)}
                  style={{ background: 'var(--bg-color)', border: 'none', padding: '0.5rem', borderRadius: '50%', cursor: 'pointer', display: 'flex', color: 'var(--text-muted)', transition: 'background 0.2m' }}
                  onMouseOver={e=>e.currentTarget.style.background='rgba(0,0,0,0.05)'}
                  onMouseOut={e=>e.currentTarget.style.background='var(--bg-color)'}
                >
                  <X size={20} />
                </button>
              </div>

              <div style={{ padding: '2rem' }}>
                <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '2rem', marginBottom: '1.5rem' }}>
                  <div>
                    <p style={{ fontSize: '0.8rem', color: 'var(--text-muted)', textTransform: 'uppercase', fontWeight: 700, marginBottom: '0.3rem' }}>Title & Category</p>
                    <h3 style={{ fontSize: '1.1rem', fontWeight: 700, color: 'var(--text-main)', marginBottom: '0.2rem' }}>{selectedComplaint.title}</h3>
                    <span style={{ fontSize: '0.85rem', color: 'var(--text-muted)' }}>{selectedComplaint.category}</span>
                  </div>
                  <div>
                    <p style={{ fontSize: '0.8rem', color: 'var(--text-muted)', textTransform: 'uppercase', fontWeight: 700, marginBottom: '0.3rem' }}>Reporting Citizen</p>
                    <h3 style={{ fontSize: '1.1rem', fontWeight: 700, color: 'var(--text-main)', marginBottom: '0.2rem' }}>
                      {selectedComplaint.isAnonymous ? 'Anonymous Reporter' : selectedComplaint.citizenName}
                    </h3>
                  </div>
                </div>

                <div style={{ display: 'flex', gap: '1.5rem', marginBottom: '2rem', padding: '1rem', backgroundColor: 'rgba(10, 102, 194, 0.05)', borderRadius: '12px', border: '1px solid rgba(10,102,194,0.1)' }}>
                  <div style={{ flex: 1 }}>
                    <p style={{ fontSize: '0.75rem', color: 'var(--text-muted)', fontWeight: 600, display: 'flex', alignItems: 'center', gap: '4px' }}><MapPin size={12}/> Location</p>
                    <p style={{ fontSize: '0.9rem', fontWeight: 600, color: 'var(--text-main)' }}>{selectedComplaint.location}</p>
                    {selectedComplaint.gnDivision && <p style={{ fontSize: '0.8rem', color: 'var(--text-muted)' }}>{selectedComplaint.gnDivision} GN Division</p>}
                  </div>
                  <div style={{ flex: 1 }}>
                    <p style={{ fontSize: '0.75rem', color: 'var(--text-muted)', fontWeight: 600, display: 'flex', alignItems: 'center', gap: '4px' }}><Calendar size={12}/> Reported On</p>
                    <p style={{ fontSize: '0.9rem', fontWeight: 600, color: 'var(--text-main)' }}>
                      {selectedComplaint.createdAt ? new Date(selectedComplaint.createdAt).toLocaleString() : 'N/A'}
                    </p>
                  </div>
                  <div>
                    <p style={{ fontSize: '0.75rem', color: 'var(--text-muted)', fontWeight: 600, display: 'flex', alignItems: 'center', gap: '4px' }}><AlertOctagon size={12}/> Priority</p>
                    <span style={{ display: 'inline-block', padding: '4px 8px', borderRadius: '4px', fontSize: '0.75rem', fontWeight: 800, backgroundColor: 'white', color: getPriorityColor(selectedComplaint.priority), border: `1px solid ${getPriorityColor(selectedComplaint.priority)}`}}>
                      {selectedComplaint.priority}
                    </span>
                  </div>
                </div>

                <div style={{ marginBottom: '2rem' }}>
                  <p style={{ fontSize: '0.85rem', color: 'var(--text-muted)', textTransform: 'uppercase', fontWeight: 700, marginBottom: '0.5rem', display: 'flex', alignItems: 'center', gap: '6px' }}>
                    <FileText size={16} /> Description
                  </p>
                  <div style={{ backgroundColor: 'white', padding: '1.2rem', borderRadius: '12px', border: '1px solid var(--border)', fontSize: '0.95rem', lineHeight: 1.6, color: 'var(--text-main)', whiteSpace: 'pre-wrap' }}>
                    {selectedComplaint.description || 'No detailed description provided.'}
                  </div>
                </div>

                {selectedComplaint.imageUrl && (
                  <div style={{ marginBottom: '2rem' }}>
                    <p style={{ fontSize: '0.85rem', color: 'var(--text-muted)', textTransform: 'uppercase', fontWeight: 700, marginBottom: '0.8rem', display: 'flex', alignItems: 'center', gap: '6px' }}>
                      <ImageIcon size={16} /> Attachment
                    </p>
                    <img 
                      src={selectedComplaint.imageUrl} 
                      alt="Complaint attachment" 
                      style={{ width: '100%', maxHeight: '300px', objectFit: 'contain', borderRadius: '12px', border: '1px solid var(--border)', backgroundColor: 'var(--bg-color)' }}
                    />
                  </div>
                )}

                <div style={{ borderTop: '1px solid var(--border)', paddingTop: '1.5rem' }}>
                  <p style={{ fontSize: '0.85rem', color: 'var(--text-muted)', textTransform: 'uppercase', fontWeight: 700, marginBottom: '0.8rem' }}>Update Status</p>
                  <div style={{ display: 'flex', gap: '1rem' }}>
                    {['Open', 'In Progress', 'Closed'].map(status => {
                      const isActive = selectedComplaint.status === status;
                      const sBadge = getStatusBadge(status);
                      return (
                        <button
                          key={status}
                          disabled={updating || isActive}
                          onClick={() => handleStatusChange(selectedComplaint.id, status)}
                          style={{
                            flex: 1, padding: '0.8rem', borderRadius: '8px', cursor: isActive || updating ? 'not-allowed' : 'pointer',
                            backgroundColor: isActive ? sBadge.bg : 'white',
                            color: isActive ? sBadge.text : 'var(--text-muted)',
                            border: `2px solid ${isActive ? sBadge.text : 'var(--border)'}`,
                            fontWeight: 700, transition: 'all 0.2s', opacity: updating && !isActive ? 0.5 : 1
                          }}
                        >
                          {updating && isActive ? 'Updating...' : status}
                        </button>
                      )
                    })}
                  </div>
                </div>

              </div>
            </motion.div>
          </div>
        </motion.div>
      </>
          )}
        </AnimatePresence>,
        document.body
      )}

    </motion.div>
  );
}
