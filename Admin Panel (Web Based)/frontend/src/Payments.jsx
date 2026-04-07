import React, { useState, useEffect } from 'react';
import { motion } from 'framer-motion';
import { Coins, Search, FileText, CheckCircle2, TrendingUp, CreditCard, Filter } from 'lucide-react';
import { db } from './firebase';
import { collection, onSnapshot, query, orderBy } from 'firebase/firestore';
import { useTranslation } from 'react-i18next';

export default function Payments({ adminProfile }) {
  const { t } = useTranslation();
  const [payments, setPayments] = useState([]);
  const [searchTerm, setSearchTerm] = useState('');
  const [loading, setLoading] = useState(true);
  const [currentPage, setCurrentPage] = useState(1);
  const itemsPerPage = 8;

  useEffect(() => {
    setCurrentPage(1);
  }, [searchTerm]);

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

  const totalPages = Math.ceil(filteredPayments.length / itemsPerPage);
  const indexOfLastItem = currentPage * itemsPerPage;
  const indexOfFirstItem = indexOfLastItem - itemsPerPage;
  const currentItems = filteredPayments.slice(indexOfFirstItem, indexOfLastItem);

  return (
    <motion.div initial={{ opacity: 0, y: 10 }} animate={{ opacity: 1, y: 0 }} exit={{ opacity: 0 }}>
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '2rem' }}>
        <div>
          <h1 style={{ color: 'var(--text-main)', fontSize: '1.8rem', letterSpacing: '-0.5px', display: 'flex', alignItems: 'center', gap: '0.5rem' }}>
            <Coins color="var(--primary)" size={28} />
            {t('Payments Hub')}
          </h1>
          <p style={{ color: 'var(--text-muted)', marginTop: '5px' }}>
            {t('Monitor and audit citizen service payments via PayHere Gateway.')}
          </p>
        </div>
      </div>

      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(200px, 1fr))', gap: '1.5rem', marginBottom: '2rem' }}>
        <motion.div initial={{ opacity: 0, y: 10 }} animate={{ opacity: 1, y: 0 }} transition={{ delay: 0.1 }} className="glass" style={{ padding: '1.5rem', borderRadius: '16px', borderLeft: '4px solid var(--primary)', display: 'flex', alignItems: 'center', gap: '15px' }}>
          <div style={{ background: 'rgba(37, 99, 235, 0.1)', padding: '12px', borderRadius: '50%' }}>
            <TrendingUp size={24} color="var(--primary)" />
          </div>
          <div>
            <h3 style={{ fontSize: '0.75rem', color: 'var(--text-muted)', textTransform: 'uppercase', fontWeight: 700 }}>{t('Total Revenue')}</h3>
            <p style={{ fontSize: '1.6rem', fontWeight: 800, color: 'var(--text-main)', margin: 0 }}>Rs. {totalRevenue.toFixed(2)}</p>
          </div>
        </motion.div>
        
        <motion.div initial={{ opacity: 0, y: 10 }} animate={{ opacity: 1, y: 0 }} transition={{ delay: 0.2 }} className="glass" style={{ padding: '1.5rem', borderRadius: '16px', borderLeft: '4px solid #10b981', display: 'flex', alignItems: 'center', gap: '15px' }}>
          <div style={{ background: 'rgba(16, 185, 129, 0.1)', padding: '12px', borderRadius: '50%' }}>
            <CheckCircle2 size={24} color="#10b981" />
          </div>
          <div>
            <h3 style={{ fontSize: '0.75rem', color: 'var(--text-muted)', textTransform: 'uppercase', fontWeight: 700 }}>{t('Success Txns')}</h3>
            <p style={{ fontSize: '1.6rem', fontWeight: 800, color: 'var(--text-main)', margin: 0 }}>{successCount}</p>
          </div>
        </motion.div>

        <motion.div initial={{ opacity: 0, y: 10 }} animate={{ opacity: 1, y: 0 }} transition={{ delay: 0.3 }} className="glass" style={{ padding: '1.5rem', borderRadius: '16px', borderLeft: '4px solid #f59e0b', display: 'flex', alignItems: 'center', gap: '15px' }}>
          <div style={{ background: 'rgba(245, 158, 11, 0.1)', padding: '12px', borderRadius: '50%' }}>
            <CreditCard size={24} color="#f59e0b" />
          </div>
          <div>
            <h3 style={{ fontSize: '0.75rem', color: 'var(--text-muted)', textTransform: 'uppercase', fontWeight: 700 }}>{t('Pending Holds')}</h3>
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
            <Filter size={16} /> {t('Filter')}
          </button>
        </div>

        <div style={{ overflowX: 'auto' }}>
          <table style={{ width: '100%', borderCollapse: 'collapse', textAlign: 'left' }}>
            <thead style={{ backgroundColor: 'var(--primary-light)', color: 'var(--primary-dark)', fontSize: '0.85rem' }}>
              <tr>
                <th style={{ padding: '1.2rem 1.5rem', fontWeight: '600' }}>{t('Transaction Ref')}</th>
                <th style={{ padding: '1.2rem 1.5rem', fontWeight: '600' }}>{t('Service Type')}</th>
                <th style={{ padding: '1.2rem 1.5rem', fontWeight: '600' }}>{t('Applicant')}</th>
                <th style={{ padding: '1.2rem 1.5rem', fontWeight: '600' }}>{t('Date & Time')}</th>
                <th style={{ padding: '1.2rem 1.5rem', fontWeight: '600' }}>{t('Amount')}</th>
                <th style={{ padding: '1.2rem 1.5rem', fontWeight: '600', textAlign: 'right' }}>{t('Payment Status')}</th>
              </tr>
            </thead>
            <tbody>
              {loading ? (
                <tr>
                  <td colSpan="6" style={{ padding: '4rem', textAlign: 'center' }}>
                    <div className="animate-pulse">{t('Retrieving ledger...')}</div>
                  </td>
                </tr>
              ) : currentItems.length === 0 ? (
                <tr>
                  <td colSpan="6" style={{ padding: '4rem', textAlign: 'center', color: 'var(--text-muted)' }}>
                    {t('No transactions match your criteria.')}
                  </td>
                </tr>
              ) : currentItems.map((p) => {
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
        
        <div style={{ padding: '1rem 1.5rem', borderTop: '1px solid var(--border)', display: 'flex', justifyContent: 'space-between', alignItems: 'center', backgroundColor: 'var(--surface)' }}>
          <span style={{ fontSize: '0.85rem', color: 'var(--text-muted)' }}>
            {t('Showing')} {filteredPayments.length === 0 ? 0 : indexOfFirstItem + 1} {t('to')} {Math.min(indexOfLastItem, filteredPayments.length)} {t('of')} {filteredPayments.length} {t('entries')}
          </span>
          <div style={{ display: 'flex', gap: '8px' }}>
            <button 
              disabled={currentPage === 1}
              onClick={() => setCurrentPage(prev => Math.max(prev - 1, 1))}
              style={{ padding: '0.4rem 0.8rem', borderRadius: '6px', border: '1px solid var(--border)', background: currentPage === 1 ? 'var(--bg-color)' : 'white', color: currentPage === 1 ? 'var(--text-muted)' : 'var(--text-main)', cursor: currentPage === 1 ? 'not-allowed' : 'pointer', fontSize: '0.85rem', fontWeight: 600 }}
            >
              {t('Previous')}
            </button>
            
            {Array.from({ length: totalPages }, (_, i) => i + 1).map(page => (
              <button 
                key={page}
                onClick={() => setCurrentPage(page)}
                style={{ 
                  padding: '0.4rem 0.8rem', 
                  borderRadius: '6px', 
                  border: currentPage === page ? '1px solid var(--primary)' : '1px solid var(--border)', 
                  background: currentPage === page ? 'var(--primary)' : 'white', 
                  color: currentPage === page ? 'white' : 'var(--text-main)', 
                  cursor: 'pointer', 
                  fontSize: '0.85rem', 
                  fontWeight: 600 
                }}
              >
                {page}
              </button>
            ))}

            <button 
              disabled={currentPage === totalPages || totalPages === 0}
              onClick={() => setCurrentPage(prev => Math.min(prev + 1, totalPages))}
              style={{ padding: '0.4rem 0.8rem', borderRadius: '6px', border: '1px solid var(--border)', background: currentPage === totalPages || totalPages === 0 ? 'var(--bg-color)' : 'white', color: currentPage === totalPages || totalPages === 0 ? 'var(--text-muted)' : 'var(--text-main)', cursor: currentPage === totalPages || totalPages === 0 ? 'not-allowed' : 'pointer', fontSize: '0.85rem', fontWeight: 600 }}
            >
              {t('Next')}
            </button>
          </div>
        </div>
      </div>
    </motion.div>
  );
}
