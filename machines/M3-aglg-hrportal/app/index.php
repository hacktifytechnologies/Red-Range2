<?php
// AGLG HR Portal — Main Entry (Login redirect)
session_start();
if (isset($_SESSION['hr_user'])) {
    header('Location: dashboard.php');
    exit;
}
header('Location: login.php');
exit;
