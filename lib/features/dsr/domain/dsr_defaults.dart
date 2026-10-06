// Default table row labels for new DSR forms — aligned with web `study-form.builder.ts`.

const productVolumeDefaults = ['product 1', 'product 2', 'product 3'];
const customerBaseDefaults = ['customer 1', 'customer 2', 'customer 3'];
const marketFocusDefaults = ['Export', 'Domestic B2B', 'Retail B2C', 'Online'];

const qualityPerformanceDefaults = [
  'Customer Complaint',
  'Rework %',
  'Right First Time',
  'Rejection %',
  'Second Grade %',
  'Re screen / Failed shipments',
  'Cut to Ship Ratio',
];

const headCountDefaults = [
  'Raw material Warehouse',
  'CAD',
  'Cutting Room',
  'Sewing',
  'Finishing',
  'Packing',
  'Quality',
  'Maintenance',
  'Industrial Engineering',
  'Merchandising',
  'HR',
  'Import / Export',
  'IT',
  'General Management / Others',
];

const deliveryPerformanceDefaults = [
  'Ontime in Full',
  'Order to Ship Ratio',
  'Average Lead Time',
];

const leanBeltLevels = {
  1: 'White',
  2: 'Yellow',
  3: 'Green',
  4: 'Black',
  5: 'Master Black',
};

const fiveSLevels = {
  1: 'Excellence',
  2: 'Sustenance',
  3: 'Model',
};

const leanPracticeMethods = {
  1: 'Self implementation',
  2: 'Hired coach',
};

const processExcellenceQuestions = [
  (
    field: 'measure_standard_time',
    label: 'Do you measure Standard Time?',
  ),
  (
    field: 'measure_pcd',
    label: 'Do you measure Planned Cut Date (PCD) performance?',
  ),
  (
    field: 'interested_automation',
    label: 'Are you interested in automation of processes?',
  ),
  (
    field: 'ie_department',
    label: 'Do you have Industrial Engineering / Operation Excellence Department?',
  ),
  (
    field: 'lean_belt_professionals',
    label: 'Do you have Lean Belt certified professionals in the organization?',
  ),
  (
    field: 'track_operator_performance',
    label: 'Do you track individual operator performance?',
  ),
  (
    field: 'training_school',
    label: 'Do you have Training School for operators / Supervisor?',
  ),
  (
    field: 'five_s_certification',
    label: 'Do you have certification of 5S?',
  ),
  (
    field: 'incentive_system',
    label: 'Do you have incentive system in the factory?',
  ),
  (
    field: 'one_year_plan',
    label: 'Do you have 1 year plan for improvement?',
  ),
  (
    field: 'lean_tools_practiced',
    label: 'Have you ever practiced Lean Manufacturing Tools & Technique?',
  ),
];
