import i18n from 'i18next';
import { initReactI18next } from 'react-i18next';
import LanguageDetector from 'i18next-browser-languagedetector';

const resources = {
  en: {
    translation: {
      // Sidebar & Nav
      "Command Center": "Command Center",
      "Civil Registrations": "Civil Registrations",
      "Service Applications": "Service Applications",
      "Payments Hub": "Payments Hub",
      "Waste Schedule": "Waste Schedule",
      "Escalated Complaints": "Escalated Complaints",
      "GN Officers Management": "GN Officers Management",
      "System Settings": "System Settings",
      "GovEase": "GovEase",
      "Admin": "Admin",
      "Pradeshiya Lekam": "Pradeshiya Lekam",
      "Overview": "Overview",
      "DS Level Services": "DS Level Services",
      "Administration": "Administration",
      "Secure Logout": "Secure Logout",
      
      // Topbar
      "Export PDF": "Export PDF",
      "Trace ID or Subject...": "Trace ID or Subject...",
      "Language": "English",
      "No notifications yet": "No notifications yet",
      "Mark all as read": "Mark all as read",
      "Notifications": "Notifications",
      
      // Auth
      "Admin Portal Login": "Admin Portal Login",
      "GovEase Divisional Secretariat": "GovEase Divisional Secretariat",
      "Admin Email": "Admin Email",
      "Password": "Password",
      "Secure Sign In": "Secure Sign In",

      // Dashboard
      "Good Morning": "Good Morning",
      "Good Afternoon": "Good Afternoon",
      "Good Evening": "Good Evening",
      "Divisional Secretariat Portal": "Divisional Secretariat Portal",
      "You are viewing the real-time command center for the": "You are viewing the real-time command center for the",
      "division. Monitor citizen requests, officer availability, and active escalations securely.": "division. Monitor citizen requests, officer availability, and active escalations securely.",
      "Verified Citizens": "Verified Citizens",
      "Registered profiles": "Registered profiles",
      "Active GN Officers": "Active GN Officers",
      "Assigned to division": "Assigned to division",
      "Actionable Requests": "Actionable Requests",
      "Pending DS approval": "Pending DS approval",
      "Open Escalations": "Open Escalations",
      "Requiring attention": "Requiring attention",
      "Total Revenue": "Total Revenue",
      "Successful payments synced": "Successful payments synced",
      "LIVE": "LIVE",
      
      // Dashboard Tables & Panels
      "Real-Time Service Queue": "Real-Time Service Queue",
      "Latest applications submitted by citizens within your division": "Latest applications submitted by citizens within your division",
      "Service Type": "Service Type",
      "Citizen Info": "Citizen Info",
      "Submitted": "Submitted",
      "Status": "Status",
      "Syncing Divisional Data...": "Syncing Divisional Data...",
      "No pending requests.": "No pending requests.",
      "Your division's queue is completely clear!": "Your division's queue is completely clear!",
      "Quick Actions": "Quick Actions",
      "Rapidly navigate to frequently used administrative modules.": "Rapidly navigate to frequently used administrative modules.",
      "Grama Niladhari Ops": "Grama Niladhari Ops",
      "Review Escalations": "Review Escalations",
      "Citizen Directory": "Citizen Directory",
      "System Health": "System Health",
      "DB Sync Status": "DB Sync Status",
      "Connected": "Connected",
      "Division Load / Activity": "Division Load / Activity",
      "Moderate": "Moderate",

      // Payments
      "Monitor and audit citizen service payments via PayHere Gateway.": "Monitor and audit citizen service payments via PayHere Gateway.",
      "Success Txns": "Success Txns",
      "Pending Holds": "Pending Holds",
      "Filter": "Filter",
      "Transaction Ref": "Transaction Ref",
      "Applicant": "Applicant",
      "Date & Time": "Date & Time",
      "Amount": "Amount",
      "Payment Status": "Payment Status",
      "Retrieving ledger...": "Retrieving ledger...",
      "No transactions match your criteria.": "No transactions match your criteria.",
      "Previous": "Previous",
      "Next": "Next",
      "Showing": "Showing",
      "to": "to",
      "of": "of",
      "entries": "entries"
    }
  },
  si: {
    translation: {
      // Sidebar & Nav
      "Command Center": "ප්‍රධාන පාලක මැදිරිය",
      "Civil Registrations": "සිවිල් ලියාපදිංචි කිරීම්",
      "Service Applications": "සේවා අයදුම්පත්",
      "Payments Hub": "ගෙවීම් මධ්‍යස්ථානය",
      "Waste Schedule": "කසළ කළමනාකරණය",
      "Escalated Complaints": "යොමුකළ පැමිණිලි",
      "GN Officers Management": "ග්‍රාම නිලධාරී පාලනය",
      "System Settings": "පද්ධති සැකසුම්",
      "GovEase": "GovEase",
      "Admin": "පාලක",
      "Pradeshiya Lekam": "ප්‍රාදේශීය ලේකම්",
      "Overview": "දළ විශ්ලේෂණය",
      "DS Level Services": "ප්‍රාදේශීය ලේකම් සේවා",
      "Administration": "පාලන කටයුතු",
      "Secure Logout": "ඉවත් වන්න",
      
      // Topbar
      "Export PDF": "PDF ලබාගන්න",
      "Trace ID or Subject...": "Trace ID හෝ මාතෘකාව...",
      "Language": "සිංහල",
      "No notifications yet": "කිසිදු නිවේදනයක් නොමැත",
      "Mark all as read": "සියල්ල කියවූ බව සටහන් කරන්න",
      "Notifications": "නිවේදන",
      
      // Auth
      "Admin Portal Login": "පාලක මණ්ඩල පිවිසුම",
      "GovEase Divisional Secretariat": "ගොව්ඊස් ප්‍රාදේශීය ලේකම් කාර්යාලය",
      "Admin Email": "ඊමේල් ලිපිනය",
      "Password": "මුරපදය",
      "Secure Sign In": "ඇතුල් වන්න",

      // Dashboard
      "Good Morning": "සුභ උදෑසනක්",
      "Good Afternoon": "සුභ දහවලක්",
      "Good Evening": "සුභ සන්ධ්‍යාවක්",
      "Divisional Secretariat Portal": "ප්‍රාදේශීය ලේකම් ද්වාරය",
      "You are viewing the real-time command center for the": "ඔබ නිරීක්ෂණය කරන්නේ පහත කොට්ඨාශයේ පාලක මැදිරියයි:",
      "division. Monitor citizen requests, officer availability, and active escalations securely.": "මෙහිදී ජනතා ඉල්ලීම්, නිලධාරීන්ගේ තොරතුරු සහ පැමිණිලි නිරීක්ෂණය කළ හැක.",
      "Verified Citizens": "තහවුරු කළ පුරවැසියන්",
      "Registered profiles": "ලියාපදිංචි ගිණුම්",
      "Active GN Officers": "ග්‍රාම නිලධාරීන්",
      "Assigned to division": "කොට්ඨාශයට අනුයුක්ත",
      "Actionable Requests": "සක්‍රීය අයදුම්පත්",
      "Pending DS approval": "අනුමැතිය අපේක්ෂිත",
      "Open Escalations": "විවෘත පැමිණිලි",
      "Requiring attention": "අවධානය යොමු කළ යුතු",
      "Total Revenue": "මුළු ආදායම",
      "Successful payments synced": "සාර්ථක ගෙවීම් යාවත්කාලීන විය",
      "LIVE": "සජීවී",
      
      // Dashboard Tables & Panels
      "Real-Time Service Queue": "සජීවී සේවා පෝලිම",
      "Latest applications submitted by citizens within your division": "ඔබගේ කොට්ඨාශයේ පුරවැසියන්ගේ නවතම අයදුම්පත්",
      "Service Type": "සේවා වර්ගය",
      "Citizen Info": "පුරවැසි තොරතුරු",
      "Submitted": "ඉදිරිපත් කළේ",
      "Status": "තත්වය",
      "Syncing Divisional Data...": "දත්ත යාවත්කාලීන වෙමින් පවතී...",
      "No pending requests.": "පොරොත්තු ඉල්ලීම් නොමැත.",
      "Your division's queue is completely clear!": "ඔබගේ කොට්ඨාශ පෝලිම සම්පූර්ණයෙන්ම හිස්ය!",
      "Quick Actions": "ඉක්මන් ක්‍රියාමාර්ග",
      "Rapidly navigate to frequently used administrative modules.": "නිතර භාවිතා කරන පාලන අංශ වෙත ඉක්මනින් පිවිසෙන්න.",
      "Grama Niladhari Ops": "ග්‍රාම නිලධාරී මෙහෙයුම්",
      "Review Escalations": "පැමිණිලි සමාලෝචනය",
      "Citizen Directory": "පුරවැසි නාමාවලිය",
      "System Health": "පද්ධති සෞඛ්‍ය",
      "DB Sync Status": "දත්ත සමමුහුර්ත තත්වය",
      "Connected": "සම්බන්ධයි",
      "Division Load / Activity": "කාර්යබහුලත්වය",
      "Moderate": "මධ්‍යමයි",

      // Payments
      "Monitor and audit citizen service payments via PayHere Gateway.": "PayHere හරහා පුරවැසි සේවා ගෙවීම් නිරීක්ෂණය සහ විගණනය කරන්න.",
      "Success Txns": "සාර්ථක ගෙවීම්",
      "Pending Holds": "පොරොත්තු මුදල්",
      "Filter": "පෙරහන් කරන්න",
      "Transaction Ref": "ගනුදෙනු අංකය",
      "Applicant": "අයදුම්කරු",
      "Date & Time": "දිනය සහ වේලාව",
      "Amount": "මුදල",
      "Payment Status": "ගෙවීම් තත්වය",
      "Retrieving ledger...": "ගෙවීම් ලේඛනය ලබා ගනිමින් පවතී...",
      "No transactions match your criteria.": "පෙරහන් සඳහා ගනුදෙනු මොකුත් හමුවූයේ නැත.",
      "Previous": "පෙර",
      "Next": "මීළඟ",
      "Showing": "පෙන්වන්නේ",
      "to": "සිට",
      "of": "දක්වා",
      "entries": "වාර්තා"
    }
  },
  ta: {
    translation: {
      // Sidebar & Nav
      "Command Center": "கட்டளை மையம்",
      "Civil Registrations": "சிவில் பதிவுகள்",
      "Service Applications": "சேவை விண்ணப்பங்கள்",
      "Payments Hub": "கொடுப்பனவு மையம்",
      "Waste Schedule": "கழிவு அட்டவணை",
      "Escalated Complaints": "மேல்முறையீடு புகார்கள்",
      "GN Officers Management": "அலுவலர் மேலாண்மை",
      "System Settings": "கணினி அமைப்புகள்",
      "GovEase": "GovEase",
      "Admin": "நிர்வாகி",
      "Pradeshiya Lekam": "பிரதேச செயலகம்",
      "Overview": "கண்ணோட்டம்",
      "DS Level Services": "செயலக சேவைகள்",
      "Administration": "நிர்வாகம்",
      "Secure Logout": "வெளியேறு",
      
      // Topbar
      "Export PDF": "PDF பதிவிறக்கு",
      "Trace ID or Subject...": "ஐடி அல்லது தலைப்பைத் தேடு...",
      "Language": "தமிழ்",
      "No notifications yet": "அறிவிப்புகள் ஏதுமில்லை",
      "Mark all as read": "அனைத்தையும் வாசித்ததாக குறி",
      "Notifications": "அறிவிப்புகள்",
      
      // Auth
      "Admin Portal Login": "நிர்வாகி உள்நுழைவு",
      "GovEase Divisional Secretariat": "GovEase பிரதேச செயலகம்",
      "Admin Email": "மின்னஞ்சல்",
      "Password": "கடவுச்சொல்",
      "Secure Sign In": "உள்நுழைய",

      // Dashboard
      "Good Morning": "காலை வணக்கம்",
      "Good Afternoon": "மதிய வணக்கம்",
      "Good Evening": "மாலை வணக்கம்",
      "Divisional Secretariat Portal": "பிரதேச செயலக நுழைவாயில்",
      "You are viewing the real-time command center for the": "நீங்கள் பார்ப்பது கீழே உள்ள பிரிவின் கட்டளை மையத்தை:",
      "division. Monitor citizen requests, officer availability, and active escalations securely.": "பொதுமக்கள் கோரிக்கைகள் மற்றும் அலுவலர் விவரங்களை பாதுகாப்பாக நிர்வகிக்கவும்.",
      "Verified Citizens": "உறுதிசெய்யப்பட்ட மக்கள்",
      "Registered profiles": "பதிவு செய்யப்பட்டவை",
      "Active GN Officers": "கிராம அலுவலர்கள்",
      "Assigned to division": "இந்த பிரிவிற்கு நியமிக்கப்பட்டவர்கள்",
      "Actionable Requests": "நடவடிக்கைக்கான கோரிக்கைகள்",
      "Pending DS approval": "அனுமதி நிலுவையில்",
      "Open Escalations": "திறந்த புகார்கள்",
      "Requiring attention": "கவனம் தேவை",
      "Total Revenue": "மொத்த வருவாய்",
      "Successful payments synced": "வெற்றிகரமான கொடுப்பனவுகள்",
      "LIVE": "நேரலை",
      
      // Dashboard Tables & Panels
      "Real-Time Service Queue": "சேவை வரிசை",
      "Latest applications submitted by citizens within your division": "உங்கள் பிரிவில் புதிய விண்ணப்பங்கள்",
      "Service Type": "சேவை வகை",
      "Citizen Info": "குடிமகன் தகவல்",
      "Submitted": "சமர்ப்பிக்கப்பட்டது",
      "Status": "நிலை",
      "Syncing Divisional Data...": "தரவு ஒத்திசைகிறது...",
      "No pending requests.": "நிலுவையில் கோரிக்கைகள் இல்லை.",
      "Your division's queue is completely clear!": "உங்கள் பிரிவின் வரிசை காலியானது!",
      "Quick Actions": "விரைவான செயல்கள்",
      "Rapidly navigate to frequently used administrative modules.": "அடிக்கடி பயன்படுத்தும் பகுதிகளுக்கு செல்லவும்.",
      "Grama Niladhari Ops": "கிராம அலுவலர் செயல்கள்",
      "Review Escalations": "புகார்களை பரிசீலனை செய்",
      "Citizen Directory": "குடிமக்கள் பட்டியல்",
      "System Health": "கணினி நிலை",
      "DB Sync Status": "தரவுத்தள இணைப்பு",
      "Connected": "இணைக்கப்பட்டுள்ளது",
      "Division Load / Activity": "செயல்பாடு",
      "Moderate": "மிதமானது",

      // Payments
      "Monitor and audit citizen service payments via PayHere Gateway.": "PayHere மூலம் கொடுப்பனவுகளை நிர்வகிக்கவும்.",
      "Success Txns": "வெற்றிகர கொடுப்பனவுகள்",
      "Pending Holds": "நிலுவை முடக்கங்கள்",
      "Filter": "வடிகட்டி",
      "Transaction Ref": "பரிவர்த்தனை குறிப்பு",
      "Applicant": "விண்ணப்பதாரர்",
      "Date & Time": "தேதி & நேரம்",
      "Amount": "தொகை",
      "Payment Status": "கொடுப்பனவு நிலை",
      "Retrieving ledger...": "தரவை பெறுகிறது...",
      "No transactions match your criteria.": "பரிவர்த்தனைகள் ஏதுமில்லை.",
      "Previous": "முந்தைய",
      "Next": "அடுத்த",
      "Showing": "காண்பிக்கப்படுகிறது",
      "to": "முதல்",
      "of": "வரை",
      "entries": "பரிவர்த்தனைகள்"
    }
  }
};

i18n
  .use(LanguageDetector)
  .use(initReactI18next)
  .init({
    resources,
    fallbackLng: 'en',
    interpolation: {
      escapeValue: false, // not needed for react as it escapes by default
    }
  });

export default i18n;
