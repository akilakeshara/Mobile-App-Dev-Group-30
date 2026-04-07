import React, { useState, useEffect } from 'react';
import { motion } from 'framer-motion';
import { Coins, Search, FileText, CheckCircle2, TrendingUp, CreditCard, Filter } from 'lucide-react';
import { db } from './firebase';
import { collection, onSnapshot, query, orderBy } from 'firebase/firestore';

export default function Payments({ adminProfile }) {
  const [payments, setPayments] = useState([]);
  const [searchTerm, setSearchTerm] = useState('');
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    // Fetch applications which acts as our payment ledger for now
    // assuming each service application involves a payment step
    const qApps = query(collection(db, 'applications'));

    const unsub = onSnapshot(qApps, (snapshot) => {
      const list = [];
      snapshot.forEach(docSnap => {
        const data = docSnap.data();
        // Ignore complaints which might be mixed in if we're just checking all applications
        // But assuming 'applications' are all service requests with a fee.
        
        // Mobile app uses 'paid', 'paymentId', and 'paymentAmount' to record payments
        let paymentStatus = data.paid ? 'Successful' : (data.status === 'Pending' ? 'Pending' : 'Successful');
        if (data.status === 'Declined') paymentStatus = 'Refunded/Failed';

        // Fetch real amount from database
        const feeAmount = data.paymentAmount || data.fee || data.amount || 250.00; 

        list.push({
          id: data.paymentId || docSnap.id,
          type: data.serviceType || 'DS Service Request',
          applicant: data.formData?.fullName || data.applicantName || 'Citizen',
          createdAt: data.paymentAt ? new Date(data.paymentAt) : (data.createdAt ? new Date(data.createdAt) : new Date()),
          status: paymentStatus,
          amount: feeAmount,
          appStatus: data.status,
          rawString: JSON.stringify(data).toLowerCase()
        });
      });
      setPayments(list.sort((a,b) => b.createdAt.getTime() - a.createdAt.getTime()));
      setLoading(false);
    }, (error) => {
      console.error("Error fetching payments:", error);
      setLoading(false);
    });

    return () => unsub();
  }, [adminProfile]);

  const filteredPayments = payments.filter(p => 
    p.type.toLowerCase().includes(searchTerm.toLowerCase()) ||
    p.applicant.toLowerCase().includes(searchTerm.toLowerCase()) ||
    p.id.toLowerCase().includes(searchTerm.toLowerCase())
  );

  const totalRevenue = payments.filter(p => p.status === 'Successful').reduce((acc, curr) => acc + curr.amount, 0);
  const pendingRevenue = payments.filter(p => p.status === 'Pending').reduce((acc, curr) => acc + curr.amount, 0);
  const successCount = payments.filter(p => p.status === 'Successful').length;

  return (
    <motion.div initial={{ opacity: 0, y: 10 }} animate={{ opacity: 1, y: 0 }} exit={{ opacity: 0 }}>
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '2rem' }}>
        <div>
          <h1 style={{ color: 'var(--text-main)', fontSize: '1.8rem', letterSpacing: '-0.5px', display: 'flex', alignItems: 'center', gap: '0.5rem' }}>
            <Coins color="var(--primary)" size={28} />
            Payments Hub
          </h1>
          <p style={{ color: 'var(--text-muted)', marginTop: '5px' }}>
            Monitor and audit citizen service payments via PayHere Gateway.
          </p>
        </div>
      </div>

      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(200px, 1fr))', gap: '1.5rem', marginBottom: '2rem' }}>
        <motion.div initial={{ opacity: 0, y: 10 }} animate={{ opacity: 1, y: 0 }} transition={{ delay: 0.1 }} className="glass" style={{ padding: '1.5rem', borderRadius: '16px', borderLeft: '4px solid var(--primary)', display: 'flex', alignItems: 'center', gap: '15px' }}>
          <div style={{ background: 'rgba(37, 99, 235, 0.1)', padding: '12px', borderRadius: '50%' }}>
            <TrendingUp size={24} color="var(--primary)" />
          </div>
          <div>
            <h3 style={{ fontSize: '0.75rem', color: 'var(--text-muted)', textTransform: 'uppercase', fontWeight: 700 }}>Total Revenue</h3>
            <p style={{ fontSize: '1.6rem', fontWeight: 800, color: 'var(--text-main)', margin: 0 }}>Rs. {totalRevenue.toFixed(2)}</p>
          </div>
        </motion.div>
        
        <motion.div initial={{ opacity: 0, y: 10 }} animate={{ opacity: 1, y: 0 }} transition={{ delay: 0.2 }} className="glass" style={{ padding: '1.5rem', borderRadius: '16px', borderLeft: '4px solid #10b981', display: 'flex', alignItems: 'center', gap: '15px' }}>
          <div style={{ background: 'rgba(16, 185, 129, 0.1)', padding: '12px', borderRadius: '50%' }}>
            <CheckCircle2 size={24} color="#10b981" />
          </div>
          <div>
            <h3 style={{ fontSize: '0.75rem', color: 'var(--text-muted)', textTransform: 'uppercase', fontWeight: 700 }}>Success Txns</h3>
            <p style={{ fontSize: '1.6rem', fontWeight: 800, color: 'var(--text-main)', margin: 0 }}>{successCount}</p>
          </div>
        </motion.div>

        <motion.div initial={{ opacity: 0, y: 10 }} animate={{ opacity: 1, y: 0 }} transition={{ delay: 0.3 }} className="glass" style={{ padding: '1.5rem', borderRadius: '16px', borderLeft: '4px solid #f59e0b', display: 'flex', alignItems: 'center', gap: '15px' }}>
          <div style={{ background: 'rgba(245, 158, 11, 0.1)', padding: '12px', borderRadius: '50%' }}>
            <CreditCard size={24} color="#f59e0b" />
          </div>
          <div>
            <h3 style={{ fontSize: '0.75rem', color: 'var(--text-muted)', textTransform: 'uppercase', fontWeight: 700 }}>Pending Holds</h3>
            <p style={{ fontSize: '1.6rem', fontWeight: 800, color: 'var(--text-main)', margin: 0 }}>Rs. {pendingRevenue.toFixed(2)}</p>
          </div>
        </motion.div>
      </div>

      <div className="card glass" style={{ padding: 0, overflow: 'hidden' }}>
        <div style={{ padding: '1.5rem', borderBottom: '1px solid var(--border)', display: 'flex', gap: '1rem', backgroundColor: 'var(--surface)' }}>
          <div style={{ position: 'relative', width: '400px' }}>
            <Search size={18} color="var(--text-muted)" style={{ position: 'absolute', left: '12px', top: '50%', transform: 'translateY(-50%)' }} />
            <input 
              type="text" 
              placeholder="Search by ref ID, applicant, or service..." 
              className="input-field" 
              style={{ paddingLeft: '2.5rem' }}
              value={searchTerm}
              onChange={(e) => setSearchTerm(e.target.value)}
            />
          </div>
          <button style={{ background: 'transparent', border: '1px solid var(--border)', padding: '0 1rem', borderRadius: '8px', display: 'flex', alignItems: 'center', gap: '0.5rem', fontWeight: 600, color: 'var(--text-main)' }}>
            <Filter size={16} /> Filter
          </button>
        </div>

        <div style={{ overflowX: 'auto' }}>
          <table style={{ width: '100%', borderCollapse: 'collapse', textAlign: 'left' }}>
            <thead style={{ backgroundColor: 'var(--primary-light)', color: 'var(--primary-dark)', fontSize: '0.85rem' }}>
              <tr>
                <th style={{ padding: '1.2rem 1.5rem', fontWeight: '600' }}>Transaction Ref</th>
                <th style={{ padding: '1.2rem 1.5rem', fontWeight: '600' }}>Service Type</th>
                <th style={{ padding: '1.2rem 1.5rem', fontWeight: '600' }}>Applicant</th>
                <th style={{ padding: '1.2rem 1.5rem', fontWeight: '600' }}>Date & Time</th>
                <th style={{ padding: '1.2rem 1.5rem', fontWeight: '600' }}>Amount</th>
                <th style={{ padding: '1.2rem 1.5rem', fontWeight: '600', textAlign: 'right' }}>Payment Status</th>
              </tr>
            </thead>
            <tbody>
              {loading ? (
                <tr>
                  <td colSpan="6" style={{ padding: '4rem', textAlign: 'center' }}>
                    <div className="animate-pulse">Retrieving ledger...</div>
                  </td>
                </tr>
              ) : filteredPayments.length === 0 ? (
                <tr>
                  <td colSpan="6" style={{ padding: '4rem', textAlign: 'center', color: 'var(--text-muted)' }}>
                    No transactions match your criteria.
                  </td>
                </tr>
              ) : filteredPayments.map((p) => {
                let badgeColor = '#dcfce7'; let badgeText = '#166534';
                if (p.status === 'Pending') { badgeColor = '#fef3c7'; badgeText = '#92400e'; }
                if (p.status === 'Refunded/Failed') { badgeColor = '#fee2e2'; badgeText = '#991b1b'; }

                return (
                  <tr key={p.id} style={{ borderBottom: '1px solid var(--border)', fontSize: '0.95rem', transition: 'background 0.2s' }} onMouseOver={e => e.currentTarget.style.backgroundColor='rgba(10, 102, 194, 0.02)'} onMouseOut={e => e.currentTarget.style.backgroundColor='transparent'}>
                    <td style={{ padding: '1.2rem 1.5rem', fontFamily: 'monospace', color: 'var(--primary)', fontWeight: 'bold', fontSize: '0.85rem' }}>
                      TXN-{p.id.substring(0, 8).toUpperCase()}
                    </td>
                    <td style={{ padding: '1.2rem 1.5rem', fontWeight: 600, color: 'var(--text-main)' }}>
                      {p.type}
                    </td>
                    <td style={{ padding: '1.2rem 1.5rem', color: 'var(--text-main)' }}>
                      {p.applicant}
                    </td>
                    <td style={{ padding: '1.2rem 1.5rem', color: 'var(--text-muted)', fontSize: '0.9rem' }}>
                      {p.createdAt.toLocaleString()}
                    </td>
                    <td style={{ padding: '1.2rem 1.5rem', fontWeight: 700, color: 'var(--text-main)' }}>
                      LKR {parseFloat(p.amount).toFixed(2)}
                    </td>
                    <td style={{ padding: '1.2rem 1.5rem', textAlign: 'right' }}>
                      <span style={{
                        display: 'inline-flex', alignItems: 'center', gap: '6px',
                        backgroundColor: badgeColor, color: badgeText,
                        padding: '0.3rem 0.8rem', borderRadius: '50px',
                        fontSize: '0.75rem', fontWeight: '700', textTransform: 'uppercase'
                      }}>
                        {p.status}
                      </span>
                    </td>
                  </tr>
                )
              })}
            </tbody>
          </table>
        </div>
      </div>
    </motion.div>
  );
}
