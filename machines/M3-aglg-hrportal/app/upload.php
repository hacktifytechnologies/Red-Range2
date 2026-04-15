<?php
session_start();
require_once 'config.php';
if (!isset($_SESSION['hr_user'])) {
    header('Location: login.php'); exit;
}

$upload_msg  = '';
$upload_ok   = false;
$uploaded_url = '';

if ($_SERVER['REQUEST_METHOD'] === 'POST' && isset($_FILES['document'])) {
    $file    = $_FILES['document'];
    $origname = $file['name'];
    $tmppath  = $file['tmp_name'];
    $size     = $file['size'];

    // VULNERABILITY: Only client-side check — NO server-side extension/MIME enforcement
    // Allowed check is deliberately missing — all file types accepted
    if ($size > 0 && $tmppath) {
        $destname = basename($origname);          // no rename — preserves .php extension
        $destpath = UPLOAD_DIR . $destname;
        if (move_uploaded_file($tmppath, $destpath)) {
            $upload_ok   = true;
            $uploaded_url = UPLOAD_URL . $destname;
            $upload_msg  = "File '{$destname}' uploaded successfully.";
        } else {
            $upload_msg = "Upload failed. Please try again.";
        }
    } else {
        $upload_msg = "No file selected or file is empty.";
    }
}
?>
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>AGLG HR Portal — Document Upload</title>
    <link rel="preconnect" href="https://fonts.googleapis.com">
    <link href="https://fonts.googleapis.com/css2?family=Inter:wght@300;400;500;600;700&display=swap" rel="stylesheet">
    <link rel="stylesheet" href="static/style.css">
</head>
<body>
<div class="app-layout">
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
            <a href="dashboard.php" class="sb-link" id="nav-dash">
                <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><rect x="3" y="3" width="7" height="7"/><rect x="14" y="3" width="7" height="7"/><rect x="14" y="14" width="7" height="7"/><rect x="3" y="14" width="7" height="7"/></svg>
                Dashboard
            </a>
            <a href="upload.php" class="sb-link active" id="nav-upload">
                <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4"/><polyline points="17 8 12 3 7 8"/><line x1="12" y1="3" x2="12" y2="15"/></svg>
                Document Upload
            </a>
            <div class="sb-section mt">ACCOUNT</div>
            <a href="login.php" class="sb-link" onclick="<?php session_destroy(); ?>">
                <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M9 21H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h4"/><polyline points="16 17 21 12 16 7"/><line x1="21" y1="12" x2="9" y2="12"/></svg>
                Sign Out
            </a>
        </nav>
        <div class="sb-user">
            <div class="sb-avatar"><?= strtoupper(substr($_SESSION['hr_name'],0,1)) ?></div>
            <div>
                <div class="sb-uname"><?= htmlspecialchars($_SESSION['hr_name']) ?></div>
                <div class="sb-udept"><?= htmlspecialchars($_SESSION['hr_dept']) ?></div>
            </div>
        </div>
    </aside>

    <main class="main">
        <div class="top-bar">
            <div>
                <h2>Document Upload Centre</h2>
                <p class="top-sub">Submit employment documents, contracts, and compliance certificates</p>
            </div>
        </div>

        <?php if ($upload_msg): ?>
        <div class="alert <?= $upload_ok ? 'alert-ok' : 'alert-err' ?>" id="upload-msg">
            <svg width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                <?php if ($upload_ok): ?>
                <polyline points="20 6 9 17 4 12"/>
                <?php else: ?>
                <circle cx="12" cy="12" r="10"/><line x1="12" y1="8" x2="12" y2="12"/><line x1="12" y1="16" x2="12.01" y2="16"/>
                <?php endif; ?>
            </svg>
            <?= htmlspecialchars($upload_msg) ?>
            <?php if ($upload_ok): ?>
            — <a href="<?= htmlspecialchars($uploaded_url) ?>" class="link-teal" id="uploaded-link" target="_blank">View uploaded file</a>
            <?php endif; ?>
        </div>
        <?php endif; ?>

        <div class="upload-container">
            <div class="upload-card">
                <div class="dc-hdr">Upload Employee Document</div>
                <form method="post" action="upload.php" enctype="multipart/form-data" id="upload-form">
                    <div class="upload-info">
                        <p>Accepted document types: PDF, DOC, DOCX, JPG, PNG, ZIP</p>
                        <p class="upload-note">Maximum file size: 10MB</p>
                    </div>
                    <div class="drop-zone" id="drop-zone" onclick="document.getElementById('doc-file').click()">
                        <div class="dz-icon">📄</div>
                        <div class="dz-title">Drop files here or click to browse</div>
                        <div class="dz-sub" id="dz-filename">No file selected</div>
                    </div>
                    <input type="file" id="doc-file" name="document" style="display:none" onchange="updateFilename(this)" accept=".pdf,.doc,.docx,.jpg,.jpeg,.png,.zip">

                    <div class="form-grp mt">
                        <label for="doc-type">Document Category</label>
                        <select id="doc-type" name="doc_type">
                            <option>Employment Contract</option>
                            <option>Identity Proof</option>
                            <option>Educational Certificate</option>
                            <option>Tax Declaration</option>
                            <option>Medical Certificate</option>
                            <option>Other</option>
                        </select>
                    </div>
                    <div class="form-grp">
                        <label for="doc-desc">Description (optional)</label>
                        <textarea id="doc-desc" name="doc_desc" rows="2" placeholder="Brief description of the document..."></textarea>
                    </div>

                    <div class="upload-progress" id="upload-progress" style="display:none">
                        <div class="progress-bar"><div class="progress-fill" id="progress-fill"></div></div>
                        <span id="progress-text">Uploading…</span>
                    </div>

                    <button type="submit" class="btn-primary" id="upload-btn">
                        <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                            <path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4"/><polyline points="17 8 12 3 7 8"/><line x1="12" y1="3" x2="12" y2="15"/>
                        </svg>
                        Upload Document
                    </button>
                </form>
            </div>

            <div class="upload-card">
                <div class="dc-hdr">Previously Uploaded Documents</div>
                <?php
                $files = glob(UPLOAD_DIR . '*');
                if ($files && count($files) > 0):
                ?>
                <div class="file-list">
                    <?php foreach (array_reverse($files) as $f):
                        $fname = basename($f);
                        $fsize = round(filesize($f)/1024, 1) . ' KB';
                        $fdate = date('d M Y H:i', filemtime($f));
                    ?>
                    <div class="file-row">
                        <div class="file-icon">📄</div>
                        <div class="file-info">
                            <div class="file-name"><?= htmlspecialchars($fname) ?></div>
                            <div class="file-meta"><?= $fsize ?> • <?= $fdate ?></div>
                        </div>
                        <a href="<?= UPLOAD_URL . htmlspecialchars($fname) ?>" target="_blank" class="file-link">Open</a>
                    </div>
                    <?php endforeach; ?>
                </div>
                <?php else: ?>
                <div class="empty-files">No documents uploaded yet.</div>
                <?php endif; ?>
            </div>
        </div>
    </main>
</div>
<script>
function updateFilename(input) {
    const el = document.getElementById('dz-filename');
    el.textContent = input.files.length > 0 ? input.files[0].name : 'No file selected';
}
document.getElementById('upload-form').addEventListener('submit', function() {
    const el = document.getElementById('upload-progress');
    const fill = document.getElementById('progress-fill');
    el.style.display = 'flex';
    let w = 0;
    const t = setInterval(() => {
        w = Math.min(w + Math.random() * 15, 90);
        fill.style.width = w + '%';
        if (w >= 90) clearInterval(t);
    }, 200);
});
</script>
</body>
</html>
