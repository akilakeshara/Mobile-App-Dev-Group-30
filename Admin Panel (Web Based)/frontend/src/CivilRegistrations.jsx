import React, { useState, useEffect } from 'react';
import { motion } from 'framer-motion';
import { UserCheck, Search, MapPin, Phone, Shield, Calendar, Mail, Users, UserPlus, Map, ShieldCheck } from 'lucide-react';
import { db } from './firebase';
import { collection, onSnapshot, query, where } from 'firebase/firestore';
import { decryptText } from './utils/encryption';

export default function CivilRegistrations({ adminProfile }) {
  const [citizens, setCitizens] = useState([]);
  const [searchTerm, setSearchTerm] = useState('');
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    // DS Admin should only see citizens from their own Pradeshiya Lekam division (DS Division)
    // Note: Citizens in Firestore have encrypted location fields. We must fetch and then filter client-side 
    // unless we had a hashed/normalized searchable field.
    const q = collection(db, 'citizens');
    
    const unsubscribe = onSnapshot(q, (snapshot) => {
      const list = [];
      snapshot.forEach((doc) => {
        const data = doc.data();
        
        // Decrypt location fields to check division matching
        const decryptedPS = decryptText(data.pradeshiyaSabha);
        const decryptedDivision = decryptText(data.division || data.gramasewaWasama);
        const decryptedName = decryptText(data.name);
        const decryptedNic = decryptText(data.nic);
        
        // Filter by DS Division if the admin is a DS level admin
        const adminDS = adminProfile?.dsDivision;
        const normalize = (s) => (s || '').toLowerCase()
          .replace(/\b(ps|mc|uc|sabha|council|division|ds|urban|municipal|lekam|kottasha|pradeshiya)\b/g, '')
          .replace(/[^a-z0-9]/g, '')
          .trim();
        
        const normAdminDS = normalize(adminDS);
        const normCitizenPS = normalize(decryptedPS);
        
        if (!adminDS || (normCitizenPS && normAdminDS && normCitizenPS === normAdminDS)) {
          list.push({
            id: doc.id,
            ...data,
            name: decryptedName || data.name, // Fallback if not encrypted
            nic: decryptedNic,
            pradeshiyaSabha: decryptedPS,
            division: decryptedDivision,
            gramasewaWasama: decryptedDivision,
            phone: data.phone || 'N/A',
            createdAt: data.createdAt
          });
        }
      });
      
      // Sort by name
      list.sort((a, b) => a.name.localeCompare(b.name));
      setCitizens(list);
      setLoading(false);
    }, (error) => {
      console.error("Error fetching citizens:", error);
      setLoading(false);
    });

    return () => unsubscribe();
  }, [adminProfile]);

  const filteredCitizens = citizens.filter(c => 
    c.name?.toLowerCase().includes(searchTerm.toLowerCase()) ||
    c.nic?.toLowerCase().includes(searchTerm.toLowerCase()) ||
    c.division?.toLowerCase().includes(searchTerm.toLowerCase())
  );

  const totalCitizens = filteredCitizens.length;
  const newCitizens = filteredCitizens.filter(c => {
    if (!c.createdAt) return false;
    const date = new Date(c.createdAt);
    const thirtyDaysAgo = new Date();
    thirtyDaysAgo.setDate(thirtyDaysAgo.getDate() - 30);
    return date > thirtyDaysAgo;
  }).length;
  const uniqueDivisions = new Set(filteredCitizens.map(c => c.division || c.gramasewaWasama)).size;

  return (
    <motion.div initial={{ opacity: 0, y: 10 }} animate={{ opacity: 1, y: 0 }} exit={{ opacity: 0 }}>
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '2rem' }}>
        <div>
          <h1 style={{ color: 'var(--text-main)', fontSize: '1.8rem', letterSpacing: '-0.5px', display: 'flex', alignItems: 'center', gap: '0.5rem' }}>
            <UserCheck color="var(--primary)" size={28} />
            Civil Registrations
          </h1>
          <p style={{ color: 'var(--text-muted)' }}>
            Verified residents of {adminProfile?.dsDivision ? adminProfile.dsDivision.replace(' DS', '') : 'your division'}
          </p>
        </div>
      </div>

      {/* Summary Cards */}
      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(200px, 1fr))', gap: '1.5rem', marginBottom: '2rem' }}>
        <motion.div initial={{ opacity: 0, y: 10 }} animate={{ opacity: 1, y: 0 }} transition={{ delay: 0.1 }} className="glass" style={{ padding: '1.5rem', borderRadius: '16px', borderLeft: '4px solid var(--primary)', display: 'flex', alignItems: 'center', gap: '15px' }}>
          <div style={{ background: 'rgba(37, 99, 235, 0.1)', padding: '12px', borderRadius: '50%' }}>
            <Users size={24} color="var(--primary)" />
          </div>
          <div>
            <h3 style={{ fontSize: '0.75rem', color: 'var(--text-muted)', textTransform: 'uppercase', fontWeight: 700, letterSpacing: '0.5px', margin: '0 0 4px 0' }}>Total Registered</h3>
            <p style={{ fontSize: '1.6rem', fontWeight: 800, color: 'var(--text-main)', margin: 0 }}>{totalCitizens}</p>
          </div>
        </motion.div>
        
        <motion.div initial={{ opacity: 0, y: 10 }} animate={{ opacity: 1, y: 0 }} transition={{ delay: 0.2 }} className="glass" style={{ padding: '1.5rem', borderRadius: '16px', borderLeft: '4px solid #10b981', display: 'flex', alignItems: 'center', gap: '15px' }}>
          <div style={{ background: 'rgba(16, 185, 129, 0.1)', padding: '12px', borderRadius: '50%' }}>
            <UserPlus size={24} color="#10b981" />
          </div>
          <div>
            <h3 style={{ fontSize: '0.75rem', color: 'var(--text-muted)', textTransform: 'uppercase', fontWeight: 700, letterSpacing: '0.5px', margin: '0 0 4px 0' }}>New (Last 30 Days)</h3>
            <p style={{ fontSize: '1.6rem', fontWeight: 800, color: 'var(--text-main)', margin: 0 }}>{newCitizens}</p>
          </div>
        </motion.div>

        <motion.div initial={{ opacity: 0, y: 10 }} animate={{ opacity: 1, y: 0 }} transition={{ delay: 0.3 }} className="glass" style={{ padding: '1.5rem', borderRadius: '16px', borderLeft: '4px solid #8b5cf6', display: 'flex', alignItems: 'center', gap: '15px' }}>
          <div style={{ background: 'rgba(139, 92, 246, 0.1)', padding: '12px', borderRadius: '50%' }}>
            <Map size={24} color="#8b5cf6" />
          </div>
          <div>
            <h3 style={{ fontSize: '0.75rem', color: 'var(--text-muted)', textTransform: 'uppercase', fontWeight: 700, letterSpacing: '0.5px', margin: '0 0 4px 0' }}>Active GS Divisions</h3>
            <p style={{ fontSize: '1.6rem', fontWeight: 800, color: 'var(--text-main)', margin: 0 }}>{uniqueDivisions}</p>
          </div>
        </motion.div>

        <motion.div initial={{ opacity: 0, y: 10 }} animate={{ opacity: 1, y: 0 }} transition={{ delay: 0.4 }} className="glass" style={{ padding: '1.5rem', borderRadius: '16px', borderLeft: '4px solid #f59e0b', display: 'flex', alignItems: 'center', gap: '15px' }}>
          <div style={{ background: 'rgba(245, 158, 11, 0.1)', padding: '12px', borderRadius: '50%' }}>
            <ShieldCheck size={24} color="#f59e0b" />
          </div>
          <div>
            <h3 style={{ fontSize: '0.75rem', color: 'var(--text-muted)', textTransform: 'uppercase', fontWeight: 700, letterSpacing: '0.5px', margin: '0 0 4px 0' }}>Verified Identities</h3>
            <p style={{ fontSize: '1.6rem', fontWeight: 800, color: 'var(--text-main)', margin: 0 }}>{totalCitizens}</p>
          </div>
        </motion.div>
      </div>

      <div className="card glass" style={{ padding: 0, overflow: 'hidden' }}>
        <div style={{ padding: '1.5rem', borderBottom: '1px solid var(--border)', display: 'flex', gap: '1rem', backgroundColor: 'var(--surface)' }}>
          <div style={{ position: 'relative', width: '400px' }}>
            <Search size={18} color="var(--text-muted)" style={{ position: 'absolute', left: '12px', top: '50%', transform: 'translateY(-50%)' }} />
            <input 
              type="text" 
              placeholder="Search by name, NIC or GN division..." 
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
                <th style={{ padding: '1rem 1.5rem', fontWeight: '600' }}>Citizen Name</th>
                <th style={{ padding: '1rem 1.5rem', fontWeight: '600' }}>Identity (NIC)</th>
                <th style={{ padding: '1rem 1.5rem', fontWeight: '600' }}>Division Scopes</th>
                <th style={{ padding: '1rem 1.5rem', fontWeight: '600' }}>Contact Details</th>
                <th style={{ padding: '1rem 1.5rem', fontWeight: '600' }}>Joined Date</th>
              </tr>
            </thead>
            <tbody>
              {loading ? (
                <tr>
                  <td colSpan="5" style={{ padding: '4rem', textAlign: 'center' }}>
                    <div className="animate-pulse">Loading civil records...</div>
                  </td>
                </tr>
              ) : filteredCitizens.length === 0 ? (
                <tr>
                  <td colSpan="5" style={{ padding: '4rem', textAlign: 'center', color: 'var(--text-muted)' }}>
                    No citizens found matching the search criteria.
                  </td>
                </tr>
              ) : filteredCitizens.map((citizen) => (
                <tr key={citizen.id} style={{ borderBottom: '1px solid var(--border)', fontSize: '0.95rem' }}>
                  <td style={{ padding: '1.2rem 1.5rem' }}>
                    <div style={{ display: 'flex', alignItems: 'center', gap: '0.75rem' }}>
                      <div style={{ width: '36px', height: '36px', borderRadius: '50%', backgroundColor: 'var(--primary-light)', color: 'var(--primary)', display: 'flex', alignItems: 'center', justifyContent: 'center', fontWeight: '700', fontSize: '0.8rem' }}>
                        {citizen.name.charAt(0)}
                      </div>
                      <span style={{ fontWeight: '700', color: 'var(--text-main)' }}>{citizen.name}</span>
                    </div>
                  </td>
                  <td style={{ padding: '1.2rem 1.5rem' }}>
                    <div style={{ display: 'flex', alignItems: 'center', gap: '0.4rem', color: 'var(--text-main)', fontWeight: '600' }}>
                      <Shield size={14} color="var(--success)" />
                      {citizen.nic}
                    </div>
                  </td>
                  <td style={{ padding: '1.2rem 1.5rem' }}>
                    <div style={{ display: 'flex', flexDirection: 'column', gap: '0.2rem' }}>
                      <div style={{ display: 'flex', alignItems: 'center', gap: '0.25rem', color: 'var(--text-main)', fontWeight: '600', fontSize: '0.9rem' }}>
                        <MapPin size={14} color="var(--primary)" /> {citizen.division || citizen.gramasewaWasama}
                      </div>
                      <span style={{ fontSize: '0.75rem', color: 'var(--text-muted)', marginLeft: '1.2rem' }}>
                        {citizen.pradeshiyaSabha} Section
                      </span>
                    </div>
                  </td>
                  <td style={{ padding: '1.2rem 1.5rem' }}>
                    <div style={{ display: 'flex', flexDirection: 'column', gap: '0.2rem' }}>
                      <div style={{ display: 'flex', alignItems: 'center', gap: '0.4rem', fontSize: '0.85rem' }}>
                        <Phone size={14} color="var(--text-muted)" /> {citizen.phone}
                      </div>
                      {citizen.email && (
                        <div style={{ display: 'flex', alignItems: 'center', gap: '0.4rem', fontSize: '0.85rem' }}>
                          <Mail size={14} color="var(--text-muted)" /> {citizen.email}
                        </div>
                      )}
                    </div>
                  </td>
                  <td style={{ padding: '1.2rem 1.5rem', color: 'var(--text-muted)' }}>
                    <div style={{ display: 'flex', alignItems: 'center', gap: '0.4rem', fontSize: '0.85rem' }}>
                      <Calendar size={14} />
                      {citizen.createdAt ? new Date(citizen.createdAt).toLocaleDateString() : 'N/A'}
                    </div>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </div>
    </motion.div>
  );
}
