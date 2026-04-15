<?php
session_start();
require_once 'config.php';
if (isset($_SESSION['hr_user'])) {
    header('Location: dashboard.php'); exit;
}
$error = '';
if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    $u = trim($_POST['username'] ?? '');
    $p = $_POST['password'] ?? '';
    if (isset($hr_users[$u]) && $hr_users[$u]['password'] === $p) {
        $_SESSION['hr_user']   = $u;
        $_SESSION['hr_name']   = $hr_users[$u]['name'];
        $_SESSION['hr_dept']   = $hr_users[$u]['dept'];
        header('Location: dashboard.php'); exit;
    }
    $error = 'Invalid credentials. Please try again.';
}
?>
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>AGLG HR Portal — Employee Self-Service</title>
    <meta name="description" content="Arkanis Global Logistics Group — Human Resources Self-Service Portal">
    <link rel="preconnect" href="https://fonts.googleapis.com">
    <link href="https://fonts.googleapis.com/css2?family=Inter:wght@300;400;500;600;700&display=swap" rel="stylesheet">
    <link rel="stylesheet" href="static/style.css">
</head>
<body class="login-page">
<div class="login-split">
    <div class="login-panel">
        <div class="hr-logo">
            <div class="hr-logo-icon">HR</div>
            <div>
                <div class="hr-logo-name">AGLG Human Resources</div>
                <div class="hr-logo-sub">Employee Self-Service Portal</div>
            </div>
        </div>

        <div class="login-card">
            <h1 class="login-title">Welcome Back</h1>
            <p class="login-desc">Sign in with your AGLG employee credentials to access HR services</p>

            <?php if ($error): ?>
            <div class="alert alert-err" id="login-err">
                <svg width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                    <circle cx="12" cy="12" r="10"/><line x1="12" y1="8" x2="12" y2="12"/><line x1="12" y1="16" x2="12.01" y2="16"/>
                </svg>
                <?= htmlspecialchars($error) ?>
            </div>
            <?php endif; ?>

            <form method="post" action="login.php" id="login-form">
                <div class="form-grp">
                    <label for="username">Employee ID / Username</label>
                    <input type="text" id="username" name="username" placeholder="Enter your employee ID" autocomplete="off" required>
                </div>
                <div class="form-grp">
                    <label for="password">Password</label>
                    <input type="password" id="password" name="password" placeholder="Enter your password" required>
                </div>
                <button type="submit" class="btn-primary" id="login-submit">Sign In to HR Portal</button>
            </form>

            <div class="login-footer">
                <div class="security-note">
                    <svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                        <path d="M12 22s8-4 8-10V5l-8-3-8 3v7c0 6 8 10 8 10z"/>
                    </svg>
                    TLS encrypted • AGLG Secure Access v<?= AGLG_HR_VERSION ?>
                </div>
            </div>
        </div>
    </div>
    <div class="login-bg">
        <div class="bg-content">
            <h2>AGLG Employee Services</h2>
            <p>Manage your payroll, leave requests, documents, and HR information in one secure place.</p>
            <div class="feature-list">
                <div class="feature-item">
                    <span class="feature-icon">📋</span>
                    <div>
                        <strong>Payslip &amp; Tax Documents</strong>
                        <p>Download monthly payslips and annual tax summaries</p>
                    </div>
                </div>
                <div class="feature-item">
                    <span class="feature-icon">🗓️</span>
                    <div>
                        <strong>Leave Management</strong>
                        <p>Apply for, track, and manage all leave types</p>
                    </div>
                </div>
                <div class="feature-item">
                    <span class="feature-icon">📁</span>
                    <div>
                        <strong>Document Upload</strong>
                        <p>Submit contracts, ID proofs and compliance documents</p>
                    </div>
                </div>
            </div>
        </div>
    </div>
</div>
</body>
</html>
