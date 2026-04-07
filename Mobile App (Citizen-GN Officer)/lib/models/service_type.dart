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
        options: [
          'Colombo',
          'Kandy',
          'Matara',
          'Galle',
          'Anuradhapura',
          'Other',
        ],
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
        options: ['Colombo', 'Kandy', 'Galle', 'Matara', 'Other'],
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
