<?php
session_start();
require_once 'config.php';
if (!isset($_SESSION['hr_user'])) {
    header('Location: login.php'); exit;
}
$user = $_SESSION['hr_user'];
$name = $_SESSION['hr_name'];
$dept = $_SESSION['hr_dept'];
?>
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>AGLG HR Portal — Dashboard</title>
    <link rel="preconnect" href="https://fonts.googleapis.com">
    <link href="https://fonts.googleapis.com/css2?family=Inter:wght@300;400;500;600;700&display=swap" rel="stylesheet">
    <link rel="stylesheet" href="static/style.css">
</head>
<body>
<div class="app-layout">
    <!-- Sidebar -->
    <aside class="sidebar">
        <div class="sb-brand">
            <div class="sb-logo">HR</div>
            <div>
                <div class="sb-name">AGLG HR</div>
                <div class="sb-ver">v<?= AGLG_HR_VERSION ?></div>
            </div>
        </div>
        <nav class="sb-nav">
            <div class="sb-section">MAIN</div>
            <a href="dashboard.php" class="sb-link active" id="nav-dash">
                <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><rect x="3" y="3" width="7" height="7"/><rect x="14" y="3" width="7" height="7"/><rect x="14" y="14" width="7" height="7"/><rect x="3" y="14" width="7" height="7"/></svg>
                Dashboard
            </a>
            <a href="upload.php" class="sb-link" id="nav-upload">
                <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4"/><polyline points="17 8 12 3 7 8"/><line x1="12" y1="3" x2="12" y2="15"/></svg>
                Document Upload
            </a>
            <div class="sb-section mt">ACCOUNT</div>
            <a href="?logout=1" class="sb-link" onclick="<?php if(isset($_GET['logout'])){session_destroy();header('Location: login.php');exit;}?>">
                <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M9 21H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h4"/><polyline points="16 17 21 12 16 7"/><line x1="21" y1="12" x2="9" y2="12"/></svg>
                Sign Out
            </a>
        </nav>
        <?php if(isset($_GET['logout'])){ session_destroy(); header('Location: login.php'); exit; } ?>
        <div class="sb-user">
            <div class="sb-avatar"><?= strtoupper(substr($name,0,1)) ?></div>
            <div>
                <div class="sb-uname"><?= htmlspecialchars($name) ?></div>
                <div class="sb-udept"><?= htmlspecialchars($dept) ?></div>
            </div>
        </div>
    </aside>

    <!-- Main content -->
    <main class="main">
        <div class="top-bar">
            <div>
                <h2>Employee Dashboard</h2>
                <p class="top-sub">Welcome back, <?= htmlspecialchars($name) ?> — <?= date('l, d F Y') ?></p>
            </div>
            <div class="top-actions">
                <span class="status-pill active">
                    <span class="dot"></span>HR System Online
                </span>
            </div>
        </div>

        <div class="dash-grid">
            <div class="info-card blue">
                <div class="ic-header">Leave Balance</div>
                <div class="ic-val">18</div>
                <div class="ic-sub">Days remaining (Annual)</div>
                <div class="ic-bar"><div class="ic-fill" style="width:60%"></div></div>
            </div>
            <div class="info-card green">
                <div class="ic-header">Payslips Available</div>
                <div class="ic-val">12</div>
                <div class="ic-sub">For financial year 2024</div>
            </div>
            <div class="info-card teal">
                <div class="ic-header">Documents Submitted</div>
                <div class="ic-val">3</div>
                <div class="ic-sub">Awaiting HR review</div>
            </div>
            <div class="info-card gold">
                <div class="ic-header">Training Compliance</div>
                <div class="ic-val">94%</div>
                <div class="ic-sub">Mandatory modules complete</div>
            </div>
        </div>

        <div class="card-row">
            <div class="dash-card">
                <div class="dc-hdr">Recent Payslips</div>
                <table class="dash-table">
                    <thead><tr><th>Month</th><th>Gross</th><th>Net</th><th>Status</th></tr></thead>
                    <tbody>
                        <tr><td>September 2024</td><td>$6,200</td><td>$5,040</td><td><span class="badge b-green">Processed</span></td></tr>
                        <tr><td>August 2024</td><td>$6,200</td><td>$5,040</td><td><span class="badge b-green">Processed</span></td></tr>
                        <tr><td>July 2024</td><td>$6,050</td><td>$4,930</td><td><span class="badge b-green">Processed</span></td></tr>
                    </tbody>
                </table>
            </div>
            <div class="dash-card">
                <div class="dc-hdr">Leave Requests</div>
                <table class="dash-table">
                    <thead><tr><th>Type</th><th>From</th><th>To</th><th>Status</th></tr></thead>
                    <tbody>
                        <tr><td>Annual</td><td>15 Oct</td><td>19 Oct</td><td><span class="badge b-yellow">Pending</span></td></tr>
                        <tr><td>Medical</td><td>02 Aug</td><td>03 Aug</td><td><span class="badge b-green">Approved</span></td></tr>
                    </tbody>
                </table>
            </div>
        </div>
    </main>
</div>
</body>
</html>
