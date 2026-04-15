import os
import subprocess
from flask import Flask, render_template, request, redirect, url_for, session

app = Flask(__name__)
app.secret_key = 'aglg-noc-monitor-2024-k3y'

# Static operator credentials
OPERATORS = {
    'netops':    'N3t0ps@Mon1t0r',
    'noc_admin': 'N0cAdm1n@AGLG!',
}

# Simulated node health data
NODES = [
    {'name': 'aglg-portal',      'ip': '203.0.1.10', 'role': 'Web Frontend',     'status': 'up',   'latency': 12,  'uptime': '99.97%'},
    {'name': 'aglg-warehouse',   'ip': '11.0.0.22',  'role': 'Inventory API',    'status': 'up',   'latency': 8,   'uptime': '99.92%'},
    {'name': 'aglg-hrportal',    'ip': '11.0.0.35',  'role': 'HR Self-Service',  'status': 'up',   'latency': 15,  'uptime': '99.88%'},
    {'name': 'aglg-db-primary',  'ip': '195.0.0.5',  'role': 'Database Primary', 'status': 'up',   'latency': 3,   'uptime': '99.99%'},
    {'name': 'aglg-db-replica',  'ip': '195.0.0.6',  'role': 'Database Replica', 'status': 'warn', 'latency': 45,  'uptime': '98.10%'},
    {'name': 'aglg-vault',       'ip': '195.0.0.21', 'role': 'Document Vault',   'status': 'up',   'latency': 7,   'uptime': '99.95%'},
    {'name': 'aglg-backup',      'ip': '195.0.0.44', 'role': 'Backup Service',   'status': 'down', 'latency': 0,   'uptime': '87.20%'},
]

ALERTS = [
    {'id': 'ALT-0041', 'severity': 'critical', 'host': 'aglg-backup',      'msg': 'Service unreachable — heartbeat timeout',         'time': '09:14'},
    {'id': 'ALT-0040', 'severity': 'warning',  'host': 'aglg-db-replica',  'msg': 'High replication lag detected (>30s)',             'time': '08:52'},
    {'id': 'ALT-0039', 'severity': 'info',     'host': 'aglg-hrportal',    'msg': 'Certificate renewal scheduled in 14 days',        'time': '07:30'},
    {'id': 'ALT-0038', 'severity': 'warning',  'host': 'aglg-warehouse',   'msg': 'Memory usage >85% on worker process',             'time': '06:11'},
    {'id': 'ALT-0037', 'severity': 'info',     'host': 'aglg-portal',      'msg': 'Scheduled maintenance window: Sun 02:00–04:00',   'time': 'Yesterday'},
]

# ── Routes ─────────────────────────────────────────────────────────────────────
@app.route('/')
def index():
    if 'user' not in session:
        return redirect(url_for('login'))
    return render_template('index.html', user=session['user'], nodes=NODES, alerts=ALERTS)

@app.route('/login', methods=['GET', 'POST'])
def login():
    error = None
    if request.method == 'POST':
        u = request.form.get('username', '')
        p = request.form.get('password', '')
        if OPERATORS.get(u) == p:
            session['user'] = u
            return redirect(url_for('index'))
        error = 'Invalid credentials.'
    return render_template('login.html', error=error)

@app.route('/tools/ping', methods=['GET', 'POST'])
def ping_tool():
    if 'user' not in session:
        return redirect(url_for('login'))
    output = None
    if request.method == 'POST':
        host = request.form.get('host', '').strip()
        if host:
            # VULNERABILITY: Direct string interpolation — OS Command Injection
            cmd = f"ping -c 2 -W 2 {host}"
            try:
                result = subprocess.run(
                    cmd, shell=True, capture_output=True, text=True, timeout=10
                )
                output = result.stdout + result.stderr
            except subprocess.TimeoutExpired:
                output = "Request timed out."
            except Exception as e:
                output = f"Error: {e}"
    return render_template('tools.html', user=session['user'], tool='ping', output=output)

@app.route('/tools/traceroute', methods=['GET', 'POST'])
def traceroute_tool():
    if 'user' not in session:
        return redirect(url_for('login'))
    output = None
    if request.method == 'POST':
        host = request.form.get('host', '').strip()
        if host:
            # VULNERABILITY: Direct string interpolation — OS Command Injection
            cmd = f"traceroute -m 10 {host}"
            try:
                result = subprocess.run(
                    cmd, shell=True, capture_output=True, text=True, timeout=15
                )
                output = result.stdout + result.stderr
            except subprocess.TimeoutExpired:
                output = "Traceroute timed out."
            except Exception as e:
                output = f"Error: {e}"
    return render_template('tools.html', user=session['user'], tool='traceroute', output=output)

@app.route('/alerts')
def alerts():
    if 'user' not in session:
        return redirect(url_for('login'))
    return render_template('alerts.html', user=session['user'], alerts=ALERTS)

@app.route('/logout')
def logout():
    session.clear()
    return redirect(url_for('login'))

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000)
