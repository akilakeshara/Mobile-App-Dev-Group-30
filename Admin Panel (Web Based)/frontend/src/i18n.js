import i18n from 'i18next';
import { initReactI18next } from 'react-i18next';
import LanguageDetector from 'i18next-browser-languagedetector';

const resources = {
  en: {
    translation: {
      "Command Center": "Command Center",
      "Civil Registrations": "Civil Registrations",
      "Welfare & Pensions": "Welfare & Pensions",
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
      "Export PDF": "Export PDF",
      "Trace ID or Subject...": "Trace ID or Subject...",
      "Admin Portal Login": "Admin Portal Login",
      "GovEase Divisional Secretariat": "GovEase Divisional Secretariat",
      "Admin Email": "Admin Email",
      "Password": "Password",
      "Secure Sign In": "Secure Sign In",
      "Language": "English",
      "No notifications yet": "No notifications yet",
      "Mark all as read": "Mark all as read",
      "Notifications": "Notifications"
    }
  },
  si: {
    translation: {
      "Command Center": "ප්‍රධාන පාලක මැදිරිය",
      "Civil Registrations": "සිවිල් ලියාපදිංචි කිරීම්",
      "Welfare & Pensions": "සුභසාධන සහ විශ්‍රාම වැටුප්",
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
      "Export PDF": "PDF ලබාගන්න",
      "Trace ID or Subject...": "Trace ID හෝ මාතෘකාව...",
      "Admin Portal Login": "පාලක මණ්ඩල පිවිසුම",
      "GovEase Divisional Secretariat": "ගොව්ඊස් ප්‍රාදේශීය ලේකම් කාර්යාලය",
      "Admin Email": "ඊමේල් ලිපිනය",
      "Password": "මුරපදය",
      "Secure Sign In": "ඇතුල් වන්න",
      "Language": "සිංහල",
      "No notifications yet": "කිසිදු නිවේදනයක් නොමැත",
      "Mark all as read": "සියල්ල කියවූ බව සටහන් කරන්න",
      "Notifications": "නිවේදන"
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
