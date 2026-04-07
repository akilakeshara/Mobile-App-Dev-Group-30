import jsPDF from 'jspdf';
import autoTable from 'jspdf-autotable';
import { collection, getDocs } from 'firebase/firestore';
import { db } from '../firebase';
import { decryptText } from './encryption';

export const generateAdminReport = async (adminProfile, setPdfLoading) => {
  if (setPdfLoading) setPdfLoading(true);
  try {
    const doc = new jsPDF('p', 'pt', 'a4');
    const primaryColor = [10, 102, 194]; // Mobile-App-Dev-Group-30 primary blue
    const pageHeight = doc.internal.pageSize.height || doc.internal.pageSize.getHeight();
    const pageWidth = doc.internal.pageSize.width || doc.internal.pageSize.getWidth();

    // 1. Fetch System Data
    const citizensSnap = await getDocs(collection(db, 'citizens'));
    const complaintsSnap = await getDocs(collection(db, 'complaints'));
    const appsSnap = await getDocs(collection(db, 'applications'));

    let totalCitizens = 0;
    
    // Filter data based on DS Admin Profile if needed (just like the dash)
    const adminDS = adminProfile?.dsDivision ? adminProfile.dsDivision.toLowerCase().replace(/\b(ds|division|secretariat)\b/g, '').trim() : '';
    
    citizensSnap.forEach(doc => {
      const data = doc.data();
      const div = (decryptText(data.division) || '').toLowerCase();
      const ps = (decryptText(data.pradeshiyaSabha) || '').toLowerCase();
      if (!adminDS || div.includes(adminDS) || ps.includes(adminDS)) {
        totalCitizens++;
      }
    });

    const activeComplaints = [];
    complaintsSnap.forEach(doc => {
      activeComplaints.push({ id: doc.id, ...doc.data() });
    });

    const activeApps = [];
    let totalRevenue = 0;
    appsSnap.forEach(doc => {
      const data = doc.data();
      activeApps.push({ id: doc.id, ...data });
      if (data.paid || data.status === 'Completed') {
        totalRevenue += (data.paymentAmount || data.fee || data.amount || 250);
      }
    });

    // --- PAGE 1: COVER DESIGNS ---
    
    // Top colored banner
    doc.setFillColor(primaryColor[0], primaryColor[1], primaryColor[2]);
    doc.rect(0, 0, pageWidth, 120, 'F');
    
    doc.setTextColor(255, 255, 255);
    doc.setFontSize(28);
    doc.setFont('helvetica', 'bold');
    doc.text("GovEase Divisional Admin Report", 40, 60);
    
    doc.setFontSize(12);
    doc.setFont('helvetica', 'normal');
    doc.text(`Divisional Secretariat: ${adminProfile?.dsDivision || 'Super Admin'}`, 40, 85);
    doc.text(`Generated on: ${new Date().toLocaleString()}`, 40, 100);

    // Document Outline
    let currentY = 160;

    // --- Executive Summary ---
    doc.setTextColor(40, 40, 40);
    doc.setFontSize(18);
    doc.setFont('helvetica', 'bold');
    doc.text("1. Executive Summary", 40, currentY);
    currentY += 25;

    doc.setFontSize(11);
    doc.setFont('helvetica', 'normal');
    doc.setTextColor(80, 80, 80);
    const summaryText = doc.splitTextToSize(
      `This report provides a comprehensive overview of the administrative operations within the ${adminProfile?.dsDivision || 'Divisional'} jurisdiction governed by GovEase. It includes statistical metrics on citizen engagement, real-time complaint escalations, service application pipelines, and financial records.`, 
      pageWidth - 80
    );
    doc.text(summaryText, 40, currentY);
    currentY += (summaryText.length * 15) + 30;

    // --- KPI Cards (Drawn as Rectangles) ---
    const drawKpi = (x, y, title, value) => {
      doc.setFillColor(245, 247, 250);
      doc.setDrawColor(220, 225, 230);
      doc.roundedRect(x, y, 150, 70, 5, 5, 'FD');
      
      doc.setTextColor(120, 130, 140);
      doc.setFontSize(10);
      doc.text(title, x + 15, y + 25);
      
      doc.setTextColor(primaryColor[0], primaryColor[1], primaryColor[2]);
      doc.setFontSize(22);
      doc.setFont('helvetica', 'bold');
      doc.text(value.toString(), x + 15, y + 55);
      doc.setFont('helvetica', 'normal');
    };

    drawKpi(40, currentY, "TOTAL CITIZENS", totalCitizens.toString());
    drawKpi(210, currentY, "TOTAL APPLICATIONS", activeApps.length.toString());
    drawKpi(380, currentY, "GROSS REVENUE (LKR)", `Rs. ${totalRevenue.toLocaleString()}`);

    currentY += 110;

    // --- Current Active Complaints ---
    doc.setTextColor(40, 40, 40);
    doc.setFontSize(18);
    doc.setFont('helvetica', 'bold');
    doc.text("2. Escalated Complaints Overview", 40, currentY);
    currentY += 15;

    const complaintsTableData = activeComplaints
      .sort((a, b) => (b.createdAt || 0) - (a.createdAt || 0))
      .slice(0, 15) // Limit to latest 15 to keep it clean
      .map(c => [
        c.title || 'Untitled',
        c.category || 'General',
        c.gnDivision || 'Unknown GN',
        c.priority || 'Medium',
        c.status || 'Open',
        c.createdAt ? new Date(c.createdAt).toLocaleDateString() : 'N/A'
      ]);

    autoTable(doc, {
      startY: currentY,
      head: [['Title / Subject', 'Category', 'GN Division', 'Priority', 'Status', 'Date']],
      body: complaintsTableData,
      theme: 'grid',
      headStyles: { fillColor: primaryColor, textColor: [255,255,255], fontStyle: 'bold' },
      styles: { fontSize: 9, cellPadding: 5 },
      alternateRowStyles: { fillColor: [248, 250, 252] },
      margin: { left: 40, right: 40 }
    });

    currentY = doc.lastAutoTable.finalY + 40;

    // --- Recent Service Applications ---
    // Make sure we have space, otherwise add page
    if (currentY > pageHeight - 150) {
      doc.addPage();
      currentY = 60;
    }

    doc.setTextColor(40, 40, 40);
    doc.setFontSize(18);
    doc.setFont('helvetica', 'bold');
    doc.text("3. Service Applications & Processing", 40, currentY);
    currentY += 15;

    const appsTableData = activeApps
      .sort((a, b) => {
        const timeA = a.createdAt?.toMillis ? a.createdAt.toMillis() : (a.createdAt ? new Date(a.createdAt).getTime() : 0);
        const timeB = b.createdAt?.toMillis ? b.createdAt.toMillis() : (b.createdAt ? new Date(b.createdAt).getTime() : 0);
        return timeB - timeA;
      })
      .slice(0, 15)
      .map(a => [
        `APP-${(a.id || '').substring(0, 8).toUpperCase()}`,
        a.serviceType || a.type || 'Service Request',
        a.applicantName || a.formData?.fullName || 'Citizen',
        a.status || 'Pending',
        a.paid ? 'Success' : 'Pending'
      ]);

    autoTable(doc, {
      startY: currentY,
      head: [['App ID', 'Service Type', 'Applicant Name', 'Current Status', 'Payment']],
      body: appsTableData,
      theme: 'striped',
      headStyles: { fillColor: [16, 185, 129], textColor: [255,255,255], fontStyle: 'bold' }, // Success green header
      styles: { fontSize: 9, cellPadding: 5 },
      margin: { left: 40, right: 40 }
    });

    // Add Footer to all pages
    const pageCount = doc.internal.getNumberOfPages();
    for(let i = 1; i <= pageCount; i++) {
      doc.setPage(i);
      doc.setFontSize(8);
      doc.setTextColor(150, 150, 150);
      doc.text(`GovEase Automated Reporting System • Confidential • Page ${i} of ${pageCount}`, pageWidth / 2, pageHeight - 20, { align: 'center' });
    }

    doc.save(`govease_ds_${(adminProfile?.dsDivision || 'admin').toLowerCase()}_report.pdf`);
    
  } catch (error) {
    console.error("PDF Generation failed: ", error);
  } finally {
    if (setPdfLoading) setPdfLoading(false);
  }
};
