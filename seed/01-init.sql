-- ============================================================================
-- MCP Lab: fake CRM seed data
-- Runs automatically on first container start (docker-entrypoint-initdb.d).
-- To re-seed from scratch: docker compose down -v && docker compose up -d
-- ============================================================================

-- ----------------------------------------------------------------------------
-- Least-privilege role for the MCP server.
-- TALKING POINT: even if the AI is tricked into attempting a destructive
-- query (prompt injection, etc.), the database itself refuses. Defense in
-- depth — the control survives a failure of every layer above it.
-- ----------------------------------------------------------------------------
CREATE ROLE mcp_reader LOGIN PASSWORD 'readonly-lab';
GRANT CONNECT ON DATABASE crm TO mcp_reader;

CREATE TABLE customers (
    id            SERIAL PRIMARY KEY,
    company_name  TEXT NOT NULL,
    industry      TEXT,
    city          TEXT,
    province      TEXT,
    account_tier  TEXT CHECK (account_tier IN ('standard','premium','enterprise')),
    created_at    DATE NOT NULL
);

CREATE TABLE contacts (
    id           SERIAL PRIMARY KEY,
    customer_id  INT NOT NULL REFERENCES customers(id),
    full_name    TEXT NOT NULL,
    title        TEXT,
    email        TEXT,
    phone        TEXT,
    ssn          TEXT            -- demo PII: redacted in-flight by the gateway's PII-filter plugin
);

CREATE TABLE orders (
    id           SERIAL PRIMARY KEY,
    customer_id  INT NOT NULL REFERENCES customers(id),
    order_ref    TEXT UNIQUE NOT NULL,
    description  TEXT,
    amount_cad   NUMERIC(12,2) NOT NULL,
    status       TEXT CHECK (status IN ('quoted','invoiced','paid','cancelled')),
    order_date   DATE NOT NULL
);

CREATE TABLE support_tickets (
    id           SERIAL PRIMARY KEY,
    customer_id  INT NOT NULL REFERENCES customers(id),
    subject      TEXT NOT NULL,
    severity     TEXT CHECK (severity IN ('low','medium','high','critical')),
    status       TEXT CHECK (status IN ('open','in_progress','resolved','closed')),
    opened_at    DATE NOT NULL,
    summary      TEXT
);

-- ----------------------------------------------------------------------------
-- Customers (Henderson Industrial is the cross-system demo anchor: it also
-- has a contract document on the file share)
-- ----------------------------------------------------------------------------
INSERT INTO customers (company_name, industry, city, province, account_tier, created_at) VALUES
('Henderson Industrial Ltd.',   'Manufacturing',     'Surrey',      'BC', 'enterprise', '2021-03-15'),
('Pacific Rim Logistics',       'Transportation',    'Richmond',    'BC', 'premium',    '2022-07-02'),
('Cascadia Health Partners',    'Healthcare',        'Vancouver',   'BC', 'enterprise', '2020-11-20'),
('Northshore Legal Group',      'Legal Services',    'North Vancouver', 'BC', 'standard','2023-01-30'),
('Fraser Valley Foods Co.',     'Food Production',   'Abbotsford',  'BC', 'premium',    '2022-04-11'),
('Summit Peak Outfitters',      'Retail',            'Squamish',    'BC', 'standard',   '2023-09-05'),
('Tri-Cities Dental Network',   'Healthcare',        'Coquitlam',   'BC', 'standard',   '2024-02-14'),
('Westcoast Marine Services',   'Marine',            'Nanaimo',     'BC', 'premium',    '2021-08-23');

-- NOTE: the ssn values below are fake, lab-only data. They exist solely to
-- demonstrate the gateway's PII masking — every contact carries an email AND
-- an SSN so a single lookup shows two PII types being redacted together.
INSERT INTO contacts (customer_id, full_name, title, email, phone, ssn) VALUES
(1, 'Margaret Chen',   'IT Director',          'mchen@hendersonindustrial.example',  '604-555-0142', '521-44-8190'),
(1, 'David Okafor',    'Procurement Manager',  'dokafor@hendersonindustrial.example','604-555-0187', '487-22-6531'),
(2, 'Liam Tremblay',   'Operations Manager',   'ltremblay@pacificrim.example',       '604-555-0233', '612-19-3344'),
(3, 'Dr. Sarah Patel', 'CIO',                  'spatel@cascadiahealth.example',      '604-555-0311', '559-07-2281'),
(3, 'Kevin Wong',      'Network Administrator','kwong@cascadiahealth.example',       '604-555-0344', '433-65-9012'),
(4, 'Anita Rosario',   'Managing Partner',     'arosario@northshorelegal.example',   '604-555-0402', '690-31-5577'),
(5, 'Tom Berg',        'Plant Manager',        'tberg@fvfoods.example',              '604-555-0518', '502-88-1043'),
(6, 'Jessie Park',     'Owner',                'jpark@summitpeak.example',           '604-555-0627', '547-29-6618'),
(7, 'Dr. Alan Reyes',  'Practice Lead',        'areyes@tricitiesdental.example',     '604-555-0709', '618-54-7729'),
(8, 'Nicole Fontaine', 'Fleet IT Coordinator', 'nfontaine@westcoastmarine.example',  '250-555-0815', '471-93-2250');

INSERT INTO orders (customer_id, order_ref, description, amount_cad, status, order_date) VALUES
(1, 'ORD-2024-0117', 'Network refresh: 4x access switches + wireless survey',           48750.00, 'paid',     '2024-04-22'),
(1, 'ORD-2025-0034', 'Firewall HA pair upgrade and migration services',                 92300.00, 'paid',     '2025-02-10'),
(1, 'ORD-2026-0009', 'Managed SOC onboarding - Phase 1 (per contract MSA-2026-HND)',    61500.00, 'invoiced', '2026-01-19'),
(2, 'ORD-2025-0188', 'Warehouse Wi-Fi 6E deployment, 3 sites',                          37200.00, 'paid',     '2025-09-03'),
(3, 'ORD-2025-0142', 'Zero-trust remote access rollout, 850 seats',                    128900.00, 'paid',     '2025-06-30'),
(3, 'ORD-2026-0021', 'Annual security assessment + tabletop exercise',                  24000.00, 'quoted',   '2026-03-02'),
(4, 'ORD-2025-0201', 'Office move: structured cabling + UC migration',                  18400.00, 'paid',     '2025-10-15'),
(5, 'ORD-2025-0096', 'OT network segmentation assessment',                              31750.00, 'paid',     '2025-05-12'),
(6, 'ORD-2026-0014', 'POS network hardening, 2 stores',                                  8900.00, 'invoiced', '2026-02-06'),
(7, 'ORD-2026-0030', 'Endpoint management onboarding, 45 devices',                      12600.00, 'quoted',   '2026-04-18'),
(8, 'ORD-2025-0233', 'Shipboard connectivity pilot, 2 vessels',                         44100.00, 'cancelled','2025-11-27');

INSERT INTO support_tickets (customer_id, subject, severity, status, opened_at, summary) VALUES
(1, 'Intermittent packet loss on plant floor VLAN',        'high',    'in_progress', '2026-05-28', 'CRC errors on uplink to weld-shop switch; suspect damaged fibre run. Replacement scheduled.'),
(1, 'Request: SOC alert tuning for OT subnet',             'medium',  'open',        '2026-06-02', 'Too many false positives from PLC heartbeat traffic. Needs allowlist review under MSA-2026-HND scope.'),
(2, 'VPN tunnel flapping - Richmond DC',                   'high',    'resolved',    '2026-04-14', 'ISP circuit errors; carrier replaced SFP at their PE. Stable since 2026-04-16.'),
(3, 'MFA rollout: legacy lab devices cannot enroll',       'medium',  'in_progress', '2026-05-20', 'Six instruments on deprecated OS. Proposing network-level compensating controls.'),
(5, 'Production line outage - core switch failure',        'critical','closed',      '2025-12-09', 'PSU failure. RMA completed; recommended adding redundant supervisor. Quote pending.'),
(6, 'Guest Wi-Fi captive portal not loading',              'low',     'resolved',    '2026-03-11', 'Expired portal certificate. Renewed and added expiry monitoring.'),
(8, 'Vessel connectivity pilot cancelled - billing query', 'low',     'closed',      '2025-12-02', 'Customer cancelled pilot ORD-2025-0233 mid-deployment; partial invoice disputed then settled.');

-- Grant read-only access AFTER tables exist
GRANT USAGE ON SCHEMA public TO mcp_reader;
GRANT SELECT ON ALL TABLES IN SCHEMA public TO mcp_reader;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT ON TABLES TO mcp_reader;