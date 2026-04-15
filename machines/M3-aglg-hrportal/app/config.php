<?php
// AGLG HR Portal — Shared Configuration
define('AGLG_HR_VERSION', '3.1.0');
define('UPLOAD_DIR', __DIR__ . '/uploads/');
define('UPLOAD_URL', '/uploads/');

// Static credentials for HR portal (intentionally hardcoded for CTF)
$hr_users = [
    'hr_ops'     => ['password' => 'HR0ps@AGLG24',   'name' => 'HR Operations',    'dept' => 'Human Resources'],
    'hr_admin'   => ['password' => 'HR@dm1n2024!',   'name' => 'HR Administrator', 'dept' => 'Human Resources'],
    'emp_portal' => ['password' => 'Emp0rt@l!AGLG',  'name' => 'Employee Self-Service', 'dept' => 'All Departments'],
];
