import React, { useState, useEffect, useMemo } from 'react';
/* eslint-disable no-unused-vars */
import { motion } from 'framer-motion';
/* eslint-enable no-unused-vars */
import { Users, Search, PlusCircle, MapPin, Edit2, Trash2, X, UserCheck, Map, ShieldAlert } from 'lucide-react';
import { db } from './firebase';
import { collection, onSnapshot, addDoc, serverTimestamp, doc, getDoc, deleteDoc, updateDoc } from 'firebase/firestore';
import { decryptText } from './utils/encryption';

const ADMIN_HIERARCHY = {
  // ... current hardcoded hierarchy as fallback ...

  'Western': {
    'Colombo': {
      'Kolonnawa PS': ['Wellampitiya', 'Meethotamulla', 'Sedawatta'],
      'Homagama PS': ['Homagama', 'Pitipana', 'Godagama'],
    },
    'Gampaha': {
      'Ja-Ela PS': ['Ja-Ela South', 'Ekala', 'Kandana'],
      'Divulapitiya PS': ['Divulapitiya', 'Badalgama', 'Minsingama'],
    },
    'Kalutara': {
      'Bandaragama PS': ['Bandaragama', 'Waskaduwa', 'Raigama'],
      'Millaniya PS': ['Millaniya', 'Yatadolawatta', 'Halwatura'],
    },
  },
  'Central': {
    'Kandy': {
      'Akurana PS': ['Akurana', 'Bahirawakanda', 'Dunuwila'],
      'Pathadumbara PS': ['Katugastota', 'Poojapitiya', 'Wattegama'],
    },
    'Matale': {
      'Dambulla PS': ['Dambulla', 'Kandalama', 'Ibbankatuwa'],
      'Galewela PS': ['Galewela', 'Bambaragaswewa', 'Kalundewa'],
    },
    'Nuwara Eliya': {
      'Nuwara Eliya PS': ['Nuwara Eliya', 'Hawa Eliya', 'Blackpool'],
      'Ambagamuwa PS': ['Ginigathhena', 'Nallathanniya', 'Watawala'],
    },
  },
  'Southern': {
    'Galle': {
      'Bope Poddala PS': ['Poddala', 'Labuduwa', 'Yakkalamulla'],
      'Habaraduwa PS': ['Habaraduwa', 'Ahangama', 'Koggala'],
    },
    'Matara': {
      'Weligama PS': ['Weligama', 'Pelena', 'Denipitiya'],
      'Akuressa PS': ['Akuressa', 'Aparekka', 'Kamburupitiya'],
    },
    'Hambantota': {
      'Tissamaharama PS': ['Tissamaharama', 'Debarawewa', 'Yodakandiya'],
      'Tangalle PS': ['Tangalle', 'Kudawella', 'Netolpitiya'],
    },
  },
  'Northern': {
    'Jaffna': {
      'Nallur PS': ['Nallur', 'Kokuvil East', 'Kokuvil West'],
      'Chavakachcheri PS': ['Chavakachcheri', 'Kodikamam', 'Kachchai'],
    },
    'Kilinochchi': {
      'Karachchi PS': ['Kilinochchi', 'Kanakapuram', 'Paranthan'],
    },
    'Mannar': {
      'Mannar PS': ['Mannar Town', 'Pesalai', 'Thoddaveli'],
    },
    'Mullaitivu': {
      'Maritimepattu PS': ['Mullaitivu', 'Puthukudiyiruppu', 'Oddusuddan'],
    },
    'Vavuniya': {
      'Vavuniya PS': ['Vavuniya', 'Nedunkeni', 'Cheddikulam'],
    },
  },
  'Eastern': {
    'Trincomalee': {
      'Kinniya PS': ['Kinniya', 'Periyathottam', 'Kurinchakerny'],
      'Morawewa PS': ['Morawewa', 'Gomarankadawala', 'Pulmoddai'],
    },
    'Batticaloa': {
      'Kattankudy PS': ['Kattankudy', 'Navatkuda', 'Eravur'],
      'Kaluwanchikudy PS': ['Kaluwanchikudy', 'Cheddipalayam', 'Vellaveli'],
    },
    'Ampara': {
      'Sainthamaruthu PS': ['Sainthamaruthu', 'Sammanthurai', 'Nintavur'],
      'Akkaraipattu PS': ['Akkaraipattu', 'Alayadivembu', 'Karaitivu'],
    },
  },
  'North Western': {
    'Kurunegala': {
      'Kuliyapitiya PS': ['Kuliyapitiya', 'Wariyapola', 'Narammala'],
      'Pannala PS': ['Pannala', 'Makandura', 'Wenwita'],
    },
    'Puttalam': {
      'Wennappuwa PS': ['Wennappuwa', 'Lunuwila', 'Waikkal'],
      'Anamaduwa PS': ['Anamaduwa', 'Mahauswewa', 'Pahala Puliyankulama'],
    },
  },
  'North Central': {
    'Anuradhapura': {
      'Nuwaragam Palatha Central PS': [
        'Anuradhapura Town',
        'Mihintale',
        'Nachchaduwa',
      ],
      'Kekirawa PS': ['Kekirawa', 'Maradankadawala', 'Madatugama'],
    },
    'Polonnaruwa': {
      'Thamankaduwa PS': ['Polonnaruwa', 'Kaduruwela', 'Hingurakgoda'],
    },
  },
  'Uva': {
    'Badulla': {
      'Badulla PS': ['Badulla', 'Haliela', 'Passara'],
      'Bandarawela PS': ['Bandarawela', 'Diyatalawa', 'Ella'],
    },
    'Monaragala': {
      'Monaragala PS': ['Monaragala', 'Buttala', 'Wellawaya'],
    },
  },
  'Sabaragamuwa': {
    'Ratnapura': {
      'Ratnapura PS': ['Ratnapura', 'Kuruwita', 'Eheliyagoda'],
      'Pelmadulla PS': ['Pelmadulla', 'Balangoda', 'Godakawela'],
    },
    'Kegalle': {
      'Kegalle PS': ['Kegalle', 'Mawanella', 'Rambukkana'],
      'Warakapola PS': ['Warakapola', 'Galigamuwa', 'Yatiyantota'],
    },
  },
};

export default function Officers({ adminProfile }) {
  const [officers, setOfficers] = useState([]);
  const [searchTerm, setSearchTerm] = useState('');
  const [isModalOpen, setIsModalOpen] = useState(false);
  const [editingId, setEditingId] = useState(null);
  const [isSubmitting, setIsSubmitting] = useState(false);
  const [hierarchy, setHierarchy] = useState(ADMIN_HIERARCHY);

  // Sync with official mobile hierarchy config from Firestore
  useEffect(() => {
    const fetchHierarchy = async () => {
      try {
        const docRef = doc(db, 'config', 'administrative_hierarchy');
        const docSnap = await getDoc(docRef);
        if (docSnap.exists()) {
          const data = docSnap.data();
          const remoteHierarchy = data.provinces || data.hierarchy || data;
          if (remoteHierarchy && typeof remoteHierarchy === 'object' && Object.keys(remoteHierarchy).length > 0) {
            setHierarchy(remoteHierarchy);
          }
        }
      } catch (_err) {
        console.error("Failed to load official hierarchy:", _err);
      }
    };
    fetchHierarchy();
  }, []);
  
  // Form State
  const [formData, setFormData] = useState({
    name: '',
    officerId: '',
    phone: '',
    password: '',
    province: '',
    district: '',
    pradeshiyaSabha: '',
    gnDivision: ''
  });

  // Hierarchical dropdown options using the dynamic hierarchy
  const provinces = useMemo(() => Object.keys(hierarchy).sort(), [hierarchy]);
  const districts = useMemo(() => {
    if (!formData.province || !hierarchy[formData.province]) return [];
    return Object.keys(hierarchy[formData.province]).sort();
  }, [formData.province, hierarchy]);

  const pradeshiyaSabhas = useMemo(() => {
    if (!formData.province || !formData.district || !hierarchy[formData.province]?.[formData.district]) return [];
    return Object.keys(hierarchy[formData.province][formData.district]).sort();
  }, [formData.province, formData.district, hierarchy]);

  const gnDivisions = useMemo(() => {
    if (!formData.province || !formData.district || !formData.pradeshiyaSabha || !hierarchy[formData.province]?.[formData.district]?.[formData.pradeshiyaSabha]) return [];
    return hierarchy[formData.province][formData.district][formData.pradeshiyaSabha].sort();
  }, [formData.province, formData.district, formData.pradeshiyaSabha, hierarchy]);

  // Real-time listener for officers
  useEffect(() => {
    const q = collection(db, 'officers');
    const unsubscribe = onSnapshot(q, (snapshot) => {
      const officersList = [];
      snapshot.forEach((doc) => {
        const data = doc.data();
        // Decrypt profile fields for Admin use
        officersList.push({ 
          id: doc.id, 
          ...data,
          name: decryptText(data.name),
          nic: decryptText(data.nic),
          province: decryptText(data.province),
          district: decryptText(data.district),
          pradeshiyaSabha: decryptText(data.pradeshiyaSabha),
          gnDivision: decryptText(data.gnDivision || data.gramasewaWasama),
          gramasewaWasama: decryptText(data.gramasewaWasama || data.gnDivision),
        });
      });
      setOfficers(officersList);
    }, (_error) => {
      console.error("Error fetching officers:", _error);
    });

    return () => unsubscribe();
  }, []);

  // Auto-generate ID when modal opens for new officer
  useEffect(() => {
    if (isModalOpen && !editingId) {
      const year = new Date().getFullYear();
      const randomId = Math.floor(1000 + Math.random() * 9000).toString();
      const generatedId = `GN-${year}-${randomId}`;

      // Pre-fill from admin profile safely
      const adminProv = (adminProfile?.province || '').replace(' Province', '').trim();
      const adminDist = (adminProfile?.district || '').trim();
      const adminPS = (adminProfile?.pradeshiyaSabha || adminProfile?.dsDivision || '').trim();

      setFormData(prev => ({
        ...prev,
        officerId: generatedId,
        province: hierarchy[adminProv] ? adminProv : '',
        district: (hierarchy[adminProv]?.[adminDist]) ? adminDist : '',
        pradeshiyaSabha: (hierarchy[adminProv]?.[adminDist]?.[adminPS]) ? adminPS : '',
        gnDivision: ''
      }));
    }
  }, [isModalOpen, editingId, adminProfile, hierarchy]);

  const handleCreateOfficer = async (e) => {
    e.preventDefault();
    setIsSubmitting(true);
    try {
      const officerData = {
        name: formData.name,
        officerId: formData.officerId.trim().toUpperCase(),
        officerIdNormalized: formData.officerId.trim().toUpperCase(),
        phone: formData.phone,
        phoneNormalized: formData.phone.replace(/[^0-9]/g, '').slice(-10),
        province: formData.province,
        district: formData.district,
        pradeshiyaSabha: formData.pradeshiyaSabha,
        gnDivision: formData.gnDivision,
        gramasewaWasama: formData.gnDivision, // Alias for mobile app compatibility
        role: 'officer',
        updatedAt: serverTimestamp(),
      };

      if (editingId) {
        await updateDoc(doc(db, 'officers', editingId), officerData);
        alert('Grama Niladhari successfully updated!');
      } else {
        officerData.password = formData.password;
        officerData.createdAt = serverTimestamp();
        await addDoc(collection(db, 'officers'), officerData);
        alert('Grama Niladhari successfully registered!');
      }
      setIsModalOpen(false);
      setEditingId(null);
      setFormData({ name: '', officerId: '', phone: '', password: '', province: '', district: '', pradeshiyaSabha: '', gnDivision: '' });
    } catch (err) {
      alert(err.message);
    } finally {
      setIsSubmitting(false);
    }
  };

  const handleDeleteOfficer = async (id) => {
    if (window.confirm('Are you sure you want to delete this GN Officer?')) {
      try {
        await deleteDoc(doc(db, 'officers', id));
      } catch (err) {
        alert(err.message);
      }
    }
  };

  const openEditModal = (officer) => {
    setEditingId(officer.id);
    setFormData({
      name: officer.name || '',
      officerId: officer.officerId || '',
      phone: officer.phone || '',
      password: '',
      province: officer.province || '',
      district: officer.district || '',
      pradeshiyaSabha: officer.pradeshiyaSabha || '',
      gnDivision: officer.gnDivision || officer.gramasewaWasama || ''
    });
    setIsModalOpen(true);
  };

  const filteredOfficers = officers.filter(o => {
    const adminDS = adminProfile?.dsDivision;
    const normalize = (s) => (s || '').toLowerCase()
      .replace(/\b(ps|mc|uc|sabha|council|division|ds|urban|municipal|lekam|kottasha|pradeshiya)\b/g, '')
      .replace(/[^a-z0-9]/g, '')
      .trim();

    const normAdminDS = normalize(adminDS);
    const normOfficerPS = normalize(o.pradeshiyaSabha);

    if (adminDS && (!normOfficerPS || !normAdminDS || normOfficerPS !== normAdminDS)) {
      return false;
    }

    const searchStr = searchTerm.toLowerCase();
    return (
      o.name?.toLowerCase().includes(searchStr) || 
      o.gnDivision?.toLowerCase().includes(searchStr) ||
      o.officerId?.toLowerCase().includes(searchStr)
    );
  });

  return (
    <motion.div initial={{ opacity: 0, y: 10 }} animate={{ opacity: 1, y: 0 }} exit={{ opacity: 0 }}>
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '2rem' }}>
        <div>
          <h1 style={{ color: 'var(--text-main)', fontSize: '1.8rem', letterSpacing: '-0.5px', display: 'flex', alignItems: 'center', gap: '0.5rem' }}>
            <Users color="var(--primary)" size={28} />
            GN Officers Management
          </h1>
          <p style={{ color: 'var(--text-muted)' }}>Manage Grama Niladhari staff administrative scopes</p>
        </div>
        <button className="btn-primary" onClick={() => { setEditingId(null); setIsModalOpen(true); }}>
          <PlusCircle size={18} /> Register GN Officer
        </button>
      </div>

      {/* Summary Cards */}
      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(200px, 1fr))', gap: '1.5rem', marginBottom: '2rem' }}>
        <motion.div initial={{ opacity: 0, y: 10 }} animate={{ opacity: 1, y: 0 }} transition={{ delay: 0.1 }} className="glass" style={{ padding: '1.5rem', borderRadius: '16px', borderLeft: '4px solid var(--primary)', display: 'flex', alignItems: 'center', gap: '15px' }}>
          <div style={{ background: 'rgba(37, 99, 235, 0.1)', padding: '12px', borderRadius: '50%' }}>
            <Users size={24} color="var(--primary)" />
          </div>
          <div>
            <h3 style={{ fontSize: '0.75rem', color: 'var(--text-muted)', textTransform: 'uppercase', fontWeight: 700, letterSpacing: '0.5px', margin: '0 0 4px 0' }}>Total GN Staff</h3>
            <p style={{ fontSize: '1.6rem', fontWeight: 800, color: 'var(--text-main)', margin: 0 }}>{filteredOfficers.length}</p>
          </div>
        </motion.div>
        
        <motion.div initial={{ opacity: 0, y: 10 }} animate={{ opacity: 1, y: 0 }} transition={{ delay: 0.2 }} className="glass" style={{ padding: '1.5rem', borderRadius: '16px', borderLeft: '4px solid #10b981', display: 'flex', alignItems: 'center', gap: '15px' }}>
          <div style={{ background: 'rgba(16, 185, 129, 0.1)', padding: '12px', borderRadius: '50%' }}>
            <Map size={24} color="#10b981" />
          </div>
          <div>
            <h3 style={{ fontSize: '0.75rem', color: 'var(--text-muted)', textTransform: 'uppercase', fontWeight: 700, letterSpacing: '0.5px', margin: '0 0 4px 0' }}>Covered GS Divisions</h3>
            <p style={{ fontSize: '1.6rem', fontWeight: 800, color: 'var(--text-main)', margin: 0 }}>{new Set(filteredOfficers.map(o => o.gnDivision || o.gramasewaWasama).filter(Boolean)).size}</p>
          </div>
        </motion.div>

        <motion.div initial={{ opacity: 0, y: 10 }} animate={{ opacity: 1, y: 0 }} transition={{ delay: 0.3 }} className="glass" style={{ padding: '1.5rem', borderRadius: '16px', borderLeft: `4px solid ${filteredOfficers.filter(o => !o.gnDivision && !o.gramasewaWasama).length > 0 ? '#ef4444' : '#8b5cf6'}`, display: 'flex', alignItems: 'center', gap: '15px' }}>
          <div style={{ background: filteredOfficers.filter(o => !o.gnDivision && !o.gramasewaWasama).length > 0 ? 'rgba(239, 68, 68, 0.1)' : 'rgba(139, 92, 246, 0.1)', padding: '12px', borderRadius: '50%' }}>
            <ShieldAlert size={24} color={filteredOfficers.filter(o => !o.gnDivision && !o.gramasewaWasama).length > 0 ? "#ef4444" : "#8b5cf6"} />
          </div>
          <div>
            <h3 style={{ fontSize: '0.75rem', color: 'var(--text-muted)', textTransform: 'uppercase', fontWeight: 700, letterSpacing: '0.5px', margin: '0 0 4px 0' }}>Unassigned Officers</h3>
            <p style={{ fontSize: '1.6rem', fontWeight: 800, color: 'var(--text-main)', margin: 0 }}>{filteredOfficers.filter(o => !o.gnDivision && !o.gramasewaWasama).length}</p>
          </div>
        </motion.div>
      </div>

      <div className="card glass" style={{ padding: 0, overflow: 'hidden' }}>
        <div style={{ padding: '1.5rem', borderBottom: '1px solid var(--border)', display: 'flex', gap: '1rem', backgroundColor: 'var(--surface)' }}>
          <div style={{ position: 'relative', width: '350px' }}>
            <Search size={18} color="var(--text-muted)" style={{ position: 'absolute', left: '12px', top: '50%', transform: 'translateY(-50%)' }} />
            <input 
              type="text" 
              placeholder="Search by name, ID or division..." 
              className="input-field" 
              style={{ paddingLeft: '2.5rem' }}
              value={searchTerm}
              onChange={(e) => setSearchTerm(e.target.value)}
            />
          </div>
        </div>

        <table style={{ width: '100%', borderCollapse: 'collapse', textAlign: 'left' }}>
          <thead style={{ backgroundColor: 'var(--primary-light)', color: 'var(--primary-dark)', fontSize: '0.85rem' }}>
            <tr>
              <th style={{ padding: '1rem 1.5rem', fontWeight: '600' }}>Officer ID</th>
              <th style={{ padding: '1rem 1.5rem', fontWeight: '600' }}>Name</th>
              <th style={{ padding: '1rem 1.5rem', fontWeight: '600' }}>Contact</th>
              <th style={{ padding: '1rem 1.5rem', fontWeight: '600' }}>Administrative Assignment</th>
              <th style={{ padding: '1rem 1.5rem', fontWeight: '600', textAlign: 'right' }}>Actions</th>
            </tr>
          </thead>
          <tbody>
            {filteredOfficers.length === 0 ? (
              <tr>
                <td colSpan="5" style={{ padding: '3rem', textAlign: 'center', color: 'var(--text-muted)' }}>
                  No Grama Niladhari officers found.
                </td>
              </tr>
            ) : filteredOfficers.map((officer) => (
              <tr key={officer.id} style={{ borderBottom: '1px solid var(--border)', fontSize: '0.95rem' }}>
                <td style={{ padding: '1rem 1.5rem', fontWeight: '600', color: 'var(--text-main)' }}>{officer.officerId || '-'}</td>
                <td style={{ padding: '1rem 1.5rem', fontWeight: '600', color: 'var(--text-main)' }}>{officer.name}</td>
                <td style={{ padding: '1rem 1.5rem', color: 'var(--text-muted)' }}>{officer.phone}</td>
                <td style={{ padding: '1rem 1.5rem', color: 'var(--text-muted)' }}>
                  <div style={{ display: 'flex', flexDirection: 'column', gap: '0.1rem' }}>
                    <div style={{ display: 'flex', alignItems: 'center', gap: '0.25rem', fontWeight: '600', color: 'var(--text-main)' }}>
                      <MapPin size={14} color="var(--primary)" /> {officer.gnDivision || officer.gramasewaWasama || 'Unassigned'}
                    </div>
                    <span style={{ fontSize: '0.75rem', marginLeft: '1.2rem' }}>
                      {officer.pradeshiyaSabha}, {officer.district}
                    </span>
                  </div>
                </td>
                <td style={{ padding: '1rem 1.5rem', textAlign: 'right' }}>
                  <button onClick={() => openEditModal(officer)} style={{ padding: '0.4rem', color: 'var(--primary)', background: 'none', border: 'none', cursor: 'pointer', borderRadius: '6px', marginRight: '0.5rem' }}>
                    <Edit2 size={16} />
                  </button>
                  <button onClick={() => handleDeleteOfficer(officer.id)} style={{ padding: '0.4rem', color: 'var(--danger)', background: 'none', border: 'none', cursor: 'pointer', borderRadius: '6px' }}>
                    <Trash2 size={16} />
                  </button>
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>

      {/* Registration Modal Overlay */}
      {isModalOpen && (
        <div style={{ position: 'fixed', inset: 0, backgroundColor: 'rgba(0,0,0,0.5)', backdropFilter: 'blur(4px)', display: 'flex', alignItems: 'center', justifyContent: 'center', zIndex: 100 }}>
          <motion.div 
            initial={{ scale: 0.95, opacity: 0 }}
            animate={{ scale: 1, opacity: 1 }}
            className="card"
            style={{ width: '100%', maxWidth: '600px', maxHeight: '90vh', overflowY: 'auto' }}
          >
            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '1rem' }}>
              <h2 style={{ color: 'var(--text-main)' }}>{editingId ? 'Edit GN Officer' : 'New GN Registration'}</h2>
              <button onClick={() => { setIsModalOpen(false); setEditingId(null); }} style={{ background: 'none', border: 'none', cursor: 'pointer' }}>
                <X size={20} color="var(--text-muted)" />
              </button>
            </div>
            
            <form onSubmit={handleCreateOfficer} style={{ display: 'flex', flexDirection: 'column', gap: '1rem' }}>
              <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '1rem' }}>
                <div>
                  <label style={{ display: 'block', fontSize: '0.85rem', fontWeight: 600, marginBottom: '0.25rem' }}>Officer ID</label>
                  <input required disabled type="text" className="input-field" value={formData.officerId} style={{ backgroundColor: 'var(--surface)' }} />
                </div>
                <div>
                  <label style={{ display: 'block', fontSize: '0.85rem', fontWeight: 600, marginBottom: '0.25rem' }}>Officer Name</label>
                  <input required type="text" className="input-field" value={formData.name} onChange={e => setFormData({...formData, name: e.target.value})} />
                </div>
              </div>

              <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '1rem' }}>
                <div>
                  <label style={{ display: 'block', fontSize: '0.85rem', fontWeight: 600, marginBottom: '0.25rem' }}>Mobile Number</label>
                  <input required type="tel" className="input-field" value={formData.phone} onChange={e => setFormData({...formData, phone: e.target.value})} placeholder="e.g. 0771234567" />
                </div>
                {!editingId && (
                  <div>
                    <label style={{ display: 'block', fontSize: '0.85rem', fontWeight: 600, marginBottom: '0.25rem' }}>Temporary Password</label>
                    <input required type="password" className="input-field" value={formData.password} onChange={e => setFormData({...formData, password: e.target.value})} />
                  </div>
                )}
              </div>

              <hr style={{ border: 'none', borderTop: '1px solid var(--border)', margin: '0.5rem 0' }} />
              <p style={{ fontSize: '0.85rem', fontWeight: 700, color: 'var(--primary)' }}>Administrative Assignment</p>

              <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '1rem' }}>
                <div>
                  <label style={{ display: 'block', fontSize: '0.85rem', fontWeight: 600, marginBottom: '0.25rem' }}>Province</label>
                  <select required className="input-field" value={formData.province} onChange={e => setFormData({...formData, province: e.target.value, district: '', pradeshiyaSabha: '', gnDivision: ''})}>
                    <option value="">Select Province</option>
                    {provinces.map(p => <option key={p} value={p}>{p}</option>)}
                  </select>
                </div>
                <div>
                  <label style={{ display: 'block', fontSize: '0.85rem', fontWeight: 600, marginBottom: '0.25rem' }}>District</label>
                  <select required className="input-field" value={formData.district} onChange={e => setFormData({...formData, district: e.target.value, pradeshiyaSabha: '', gnDivision: ''})} disabled={!formData.province}>
                    <option value="">Select District</option>
                    {districts.map(d => <option key={d} value={d}>{d}</option>)}
                  </select>
                </div>
              </div>

              <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '1rem' }}>
                <div>
                  <label style={{ display: 'block', fontSize: '0.85rem', fontWeight: 600, marginBottom: '0.25rem' }}>Pradeshiya Sabha</label>
                  <select required className="input-field" value={formData.pradeshiyaSabha} onChange={e => setFormData({...formData, pradeshiyaSabha: e.target.value, gnDivision: ''})} disabled={!formData.district}>
                    <option value="">Select Sabha</option>
                    {pradeshiyaSabhas.map(ps => <option key={ps} value={ps}>{ps}</option>)}
                  </select>
                </div>
                <div>
                  <label style={{ display: 'block', fontSize: '0.85rem', fontWeight: 600, marginBottom: '0.25rem' }}>GN Division</label>
                  <select required className="input-field" value={formData.gnDivision} onChange={e => setFormData({...formData, gnDivision: e.target.value})} disabled={!formData.pradeshiyaSabha}>
                    <option value="">Select Division</option>
                    {gnDivisions.map(gn => <option key={gn} value={gn}>{gn}</option>)}
                  </select>
                </div>
              </div>

              <div style={{ display: 'flex', gap: '1rem', marginTop: '1rem' }}>
                <button type="button" className="btn-secondary" style={{ flex: 1 }} onClick={() => { setIsModalOpen(false); setEditingId(null); }}>Cancel</button>
                <button type="submit" className="btn-primary" style={{ flex: 1 }} disabled={isSubmitting}>
                  {isSubmitting ? 'Saving...' : (editingId ? 'Update Officer' : 'Register Officer')}
                </button>
              </div>
            </form>
          </motion.div>
        </div>
      )}
    </motion.div>
  );
}
