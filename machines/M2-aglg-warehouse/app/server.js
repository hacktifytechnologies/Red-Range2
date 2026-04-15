// Operation BlackVault — M2: aglg-warehouse (IDOR / Broken Access Control)
// Node.js/Express API + SPA

'use strict';
const express  = require('express');
const morgan   = require('morgan');
const path     = require('path');
const fs       = require('fs');

const app  = express();
const PORT = process.env.PORT || 3000;

app.use(express.json());
app.use(express.urlencoded({ extended: true }));
app.use(morgan('combined'));
app.use(express.static(path.join(__dirname, 'public')));

// ── In-memory user store ──────────────────────────────────────────────────────
const users = {
  1: { id: 1, username: 'vendor_ops',  password: 'V3nd0r@AGLG',  role: 'vendor',  name: 'Vendor Operations' },
  2: { id: 2, username: 'cargo_ops',   password: 'C@rg0Ops2024', role: 'operator', name: 'Cargo Operations' },
  3: { id: 3, username: 'logistics',   password: 'L0g1st1cs!',   role: 'operator', name: 'Logistics Team' },
  // VULNERABILITY: Admin user at ID 0 with embedded creds — IDOR target
  0: {
    id: 0,
    username: 'admin',
    password: 'Wh@reh0use_Adm1n!',
    role: 'admin',
    name: 'Warehouse Administrator',
    internal_note: 'HR Portal migration to DMZ complete. Creds: hr_ops : HR0ps@AGLG24 | SSH to aglg-hrportal:22',
    flag: 'FLAG2_PLACEHOLDER',
  },
};

// Active sessions (token → user id)
const sessions = {};
function genToken() { return require('crypto').randomBytes(24).toString('hex'); }

// ── In-memory inventory ────────────────────────────────────────────────────────
const inventory = [
  { id: 1,   sku: 'WH-D001', name: 'Dry Cargo Container 20ft',    qty: 142, zone: 'A1', status: 'Available', owner_id: 2 },
  { id: 2,   sku: 'WH-R002', name: 'Reefer Unit 40ft',            qty: 67,  zone: 'B3', status: 'In Use',    owner_id: 1 },
  { id: 3,   sku: 'WH-B003', name: 'Bonded Storage Bay',          qty: 28,  zone: 'C2', status: 'Available', owner_id: 2 },
  { id: 4,   sku: 'WH-H004', name: 'Hazmat Certified Crate',      qty: 15,  zone: 'H1', status: 'Restricted',owner_id: 3 },
  { id: 5,   sku: 'WH-P005', name: 'Pallet Racking Unit',         qty: 340, zone: 'A4', status: 'Available', owner_id: 1 },
  { id: 6,   sku: 'WH-F006', name: 'Forklift AGV Unit',           qty: 8,   zone: 'OPS',status: 'In Use',   owner_id: 2 },
  { id: 7,   sku: 'WH-C007', name: 'Cold Room Module (200m²)',    qty: 4,   zone: 'C1', status: 'Available', owner_id: 3 },
  { id: 8,   sku: 'WH-S008', name: 'Secure Cage (Classified)',    qty: 3,   zone: 'S-VAULT', status: 'Restricted', owner_id: 0 },
];

// ── Auth middleware ─────────────────────────────────────────────────────────────
function requireAuth(req, res, next) {
  const token = req.headers['x-auth-token'] || req.query.token;
  if (!token || !sessions[token]) {
    return res.status(401).json({ error: 'Authentication required.' });
  }
  req.user = users[sessions[token]];
  next();
}

// ── Routes: Public ─────────────────────────────────────────────────────────────
app.get('/api/docs', (req, res) => {
  res.json({
    endpoints: [
      'POST /api/login',
      'GET  /api/inventory          (auth)',
      'GET  /api/inventory/:id      (auth)',
      'GET  /api/shipment/mine      (auth)',
      'GET  /api/admin/secrets      (admin)',
      'GET  /.well-known/config',
    ]
  });
});

app.get('/.well-known/config', (req, res) => {
  res.json({
    api_version: '2.4.1',
    organization: 'AGLG Warehouse Division',
    network_note: 'DMZ range: 11.0.0.0/8 — internal HR portal accessible via SSH',
    default_vendor_id: 1,
  });
});

app.post('/api/login', (req, res) => {
  const { username, password } = req.body;
  const user = Object.values(users).find(
    u => u.username === username && u.password === password
  );
  if (!user) return res.status(401).json({ error: 'Invalid credentials.' });
  const token = genToken();
  sessions[token] = user.id;
  res.json({ token, user: { id: user.id, username: user.username, role: user.role } });
});

// ── Routes: Authenticated ──────────────────────────────────────────────────────
app.get('/api/inventory', requireAuth, (req, res) => {
  // Returns items owned by current user only
  const items = inventory.filter(i => i.owner_id === req.user.id);
  res.json({ count: items.length, items });
});

// VULNERABILITY: No ownership check — any authenticated user can access any item by ID
app.get('/api/inventory/:id', requireAuth, (req, res) => {
  const id = parseInt(req.params.id, 10);
  // Admin user is stored at id=0 — IDOR: enumerate to find it
  const user = users[id];
  if (user === undefined) return res.status(404).json({ error: 'Record not found.' });
  // Returns full user/admin object including internal_note and flag
  const { password, ...safeUser } = user;
  res.json(safeUser);
});

app.get('/api/shipment/mine', requireAuth, (req, res) => {
  const items = inventory.filter(i => i.owner_id === req.user.id);
  res.json({ shipments: items });
});

app.get('/api/admin/secrets', requireAuth, (req, res) => {
  if (req.user.role !== 'admin') {
    return res.status(403).json({ error: 'Access denied. Admin only.' });
  }
  res.json({
    flag: users[0].flag,
    classified_note: users[0].internal_note,
  });
});

// ── Start ──────────────────────────────────────────────────────────────────────
app.listen(PORT, '0.0.0.0', () => {
  console.log(`[aglg-warehouse] Inventory API running on :${PORT}`);
});
