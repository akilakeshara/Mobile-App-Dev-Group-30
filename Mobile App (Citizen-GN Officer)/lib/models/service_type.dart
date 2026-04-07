class ServiceFormField {
  final String id;
  final String label;
  final String hint;
  final String type; // 'text', 'email', 'phone', 'date', 'dropdown', 'checkbox'
  final bool required;
  final List<String>? options;

  ServiceFormField({
    required this.id,
    required this.label,
    required this.hint,
    required this.type,
    required this.required,
    this.options,
  });
}

// Full province and district administrative hierarchy dataset
const Map<String, Map<String, Map<String, List<String>>>> administrativeDataset = {
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

List<String> getAllDistricts() {
  final districts = <String>{};
  for (final province in administrativeDataset.values) {
    districts.addAll(province.keys);
  }
  final sortedDistricts = districts.toList()..sort();
  sortedDistricts.add('Other');
  return sortedDistricts;
}

class ServiceType {
  final String name;
  final String description;
  final double fee;
  final String processingTime;
  final String icon;
  final List<String> requiredDocuments;
  final List<ServiceFormField> formFields;

  ServiceType({
    required this.name,
    required this.description,
    required this.fee,
    required this.processingTime,
    required this.icon,
    required this.requiredDocuments,
    required this.formFields,
  });
}

// Service Type Catalog
final Map<String, ServiceType> serviceCatalog = {
  'NIC Renewal': ServiceType(
    name: 'NIC Renewal',
    description: 'Renew your National Identity Card',
    fee: 500.0,
    processingTime: '3-5 Working Days',
    icon: '🪪',
    requiredDocuments: ['NIC Front', 'NIC Back', 'Recent Passport Photo'],
    formFields: [
      ServiceFormField(
        id: 'nic',
        label: 'Current NIC Number',
        hint: 'e.g., 123456789V',
        type: 'text',
        required: true,
      ),
      ServiceFormField(
        id: 'issueDate',
        label: 'Issue Date',
        hint: 'Select your current NIC issue date',
        type: 'date',
        required: true,
      ),
      ServiceFormField(
        id: 'reason',
        label: 'Reason for Renewal',
        hint: 'Select reason',
        type: 'dropdown',
        required: true,
        options: ['Damage', 'Loss', 'Page Full', 'Name Change', 'Other'],
      ),
      ServiceFormField(
        id: 'notes',
        label: 'Additional Notes',
        hint: 'Any additional information...',
        type: 'text',
        required: false,
      ),
    ],
  ),
  'Birth Certificate Copy': ServiceType(
    name: 'Birth Certificate Copy',
    description: 'Get an authenticated copy of your birth certificate',
    fee: 250.0,
    processingTime: '2-3 Working Days',
    icon: '👶',
    requiredDocuments: ['NIC', 'Original Birth Certificate (if available)'],
    formFields: [
      ServiceFormField(
        id: 'fullName',
        label: 'Full Name at Birth',
        hint: 'Your complete name as recorded',
        type: 'text',
        required: true,
      ),
      ServiceFormField(
        id: 'dob',
        label: 'Date of Birth',
        hint: 'Select your date of birth',
        type: 'date',
        required: true,
      ),
      ServiceFormField(
        id: 'birthDistrict',
        label: 'District of Birth',
        hint: 'Select district',
        type: 'dropdown',
        required: true,
        options: getAllDistricts(),
      ),
      ServiceFormField(
        id: 'copies',
        label: 'Number of Copies Required',
        hint: 'Select quantity',
        type: 'dropdown',
        required: true,
        options: ['1', '2', '3', '5', 'Other'],
      ),
    ],
  ),
  'Death Certificate Copy': ServiceType(
    name: 'Death Certificate Copy',
    description: 'Obtain a certified death certificate copy',
    fee: 300.0,
    processingTime: '2-4 Working Days',
    icon: '⚰️',
    requiredDocuments: ['NIC', 'Original Death Certificate (if available)'],
    formFields: [
      ServiceFormField(
        id: 'deceasedName',
        label: 'Deceased Full Name',
        hint: 'Name of the deceased',
        type: 'text',
        required: true,
      ),
      ServiceFormField(
        id: 'relationship',
        label: 'Your Relationship',
        hint: 'Select relationship',
        type: 'dropdown',
        required: true,
        options: ['Spouse', 'Child', 'Parent', 'Sibling', 'Other'],
      ),
      ServiceFormField(
        id: 'dateOfDeath',
        label: 'Date of Death',
        hint: 'Select date',
        type: 'date',
        required: true,
      ),
      ServiceFormField(
        id: 'registrationNo',
        label: 'Registration Number (if known)',
        hint: 'Optional - helps expedite search',
        type: 'text',
        required: false,
      ),
    ],
  ),
  'Marriage Certificate Copy': ServiceType(
    name: 'Marriage Certificate Copy',
    description: 'Get a certified copy of your marriage certificate',
    fee: 350.0,
    processingTime: '3-5 Working Days',
    icon: '💍',
    requiredDocuments: ['NIC', 'Original Marriage Certificate (if available)'],
    formFields: [
      ServiceFormField(
        id: 'spouseName',
        label: 'Spouse Full Name',
        hint: 'Your spouse\'s complete name',
        type: 'text',
        required: true,
      ),
      ServiceFormField(
        id: 'marriageDate',
        label: 'Marriage Date',
        hint: 'Select marriage date',
        type: 'date',
        required: true,
      ),
      ServiceFormField(
        id: 'marriagePlace',
        label: 'Place of Marriage',
        hint: 'District or location',
        type: 'text',
        required: true,
      ),
      ServiceFormField(
        id: 'registeredAt',
        label: 'Registered At',
        hint: 'Select location',
        type: 'dropdown',
        required: true,
        options: getAllDistricts(),
      ),
    ],
  ),
  'Passport Application': ServiceType(
    name: 'Passport Application',
    description: 'Apply for a new or renewal passport',
    fee: 1200.0,
    processingTime: '7-10 Working Days',
    icon: '🛂',
    requiredDocuments: [
      'NIC',
      'Birth Certificate',
      'Passport Photo',
      'Marriage Certificate (if applicable)',
    ],
    formFields: [
      ServiceFormField(
        id: 'passportType',
        label: 'Passport Type',
        hint: 'Select type',
        type: 'dropdown',
        required: true,
        options: ['New', 'Renewal', 'Replacement'],
      ),
      ServiceFormField(
        id: 'pages',
        label: 'Number of Pages',
        hint: 'Select page count',
        type: 'dropdown',
        required: true,
        options: ['32 Pages', '64 Pages'],
      ),
      ServiceFormField(
        id: 'duration',
        label: 'Validity Period',
        hint: 'Select duration',
        type: 'dropdown',
        required: true,
        options: ['5 Years', '10 Years'],
      ),
      ServiceFormField(
        id: 'address',
        label: 'Current Address',
        hint: 'Your complete address',
        type: 'text',
        required: true,
      ),
    ],
  ),
  'Driving License Renewal': ServiceType(
    name: 'Driving License Renewal',
    description: 'Renew your Driving License',
    fee: 480.0,
    processingTime: '2-3 Working Days',
    icon: '🚗',
    requiredDocuments: ['NIC', 'Current Driving License', 'Medical Report'],
    formFields: [
      ServiceFormField(
        id: 'licenseNumber',
        label: 'License Number',
        hint: 'Your current license number',
        type: 'text',
        required: true,
      ),
      ServiceFormField(
        id: 'expiryDate',
        label: 'Current Expiry Date',
        hint: 'Select expiry date',
        type: 'date',
        required: true,
      ),
      ServiceFormField(
        id: 'category',
        label: 'License Category',
        hint: 'Select category',
        type: 'dropdown',
        required: true,
        options: [
          'A - Motorcycle',
          'B - Car',
          'C - Lorry',
          'D - Bus',
          'Multiple',
        ],
      ),
      ServiceFormField(
        id: 'medicalTest',
        label: 'Medical Test Completed',
        hint: 'Yes/No',
        type: 'dropdown',
        required: true,
        options: ['Yes', 'No'],
      ),
    ],
  ),
};

ServiceType? getServiceType(String serviceName) {
  return serviceCatalog[serviceName];
}

List<ServiceType> getAllServiceTypes() {
  return serviceCatalog.values.toList();
}
