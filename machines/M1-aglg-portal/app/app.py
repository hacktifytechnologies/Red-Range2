import os
import sqlite3
import subprocess
from flask import Flask, render_template, request, redirect, url_for, session, g

app = Flask(__name__)
app.secret_key = 'aglg-blackvault-2024-internal-key'

DATABASE = os.path.join(os.path.dirname(__file__), 'aglg.db')

def get_db():
    db = getattr(g, '_database', None)
    if db is None:
        db = g._database = sqlite3.connect(DATABASE)
        db.row_factory = sqlite3.Row
    return db

@app.teardown_appcontext
def close_connection(exception):
    db = getattr(g, '_database', None)
    if db is not None:
        db.close()

# ── Routes ─────────────────────────────────────────────────────────────────────

@app.route('/')
def index():
    return render_template('index.html')

@app.route('/login', methods=['GET', 'POST'])
def login():
    error = None
    if request.method == 'POST':
        username = request.form.get('username', '')
        password = request.form.get('password', '')
        db = get_db()
        # VULNERABILITY: Raw string interpolation — SQL Injection
        query = f"SELECT * FROM users WHERE username='{username}' AND password='{password}'"
        try:
            cur = db.execute(query)
            user = cur.fetchone()
        except Exception as e:
            error = "Database error."
            return render_template('index.html', error=error)
        if user:
            session['user'] = user['username']
            session['role'] = user['role']
            return redirect(url_for('dashboard'))
        else:
            error = "Invalid credentials. Access denied."
    return render_template('index.html', error=error)

@app.route('/dashboard')
def dashboard():
    if 'user' not in session:
        return redirect(url_for('login'))
    db = get_db()
    cur = db.execute("SELECT * FROM shipments ORDER BY id DESC LIMIT 5")
    shipments = cur.fetchall()
    return render_template('dashboard.html', user=session['user'], shipments=shipments)

@app.route('/track', methods=['GET', 'POST'])
def track():
    if 'user' not in session:
        return redirect(url_for('login'))
    result = None
    if request.method == 'POST':
        tracking_id = request.form.get('tracking_id', '')
        db = get_db()
        cur = db.execute(
            "SELECT * FROM shipments WHERE tracking_id = ?", (tracking_id,)
        )
        result = cur.fetchone()
    return render_template('track.html', user=session['user'], result=result)

@app.route('/report', methods=['GET', 'POST'])
def report():
    if 'user' not in session:
        return redirect(url_for('login'))
    output = None
    if request.method == 'POST':
        # SECONDARY VULNERABILITY: Command injection via subprocess (post-auth RCE)
        shipment_id = request.form.get('shipment_id', '')
        try:
            cmd = f"echo 'Generating report for: {shipment_id}' && date"
            result = subprocess.run(cmd, shell=True, capture_output=True, text=True, timeout=5)
            output = result.stdout + result.stderr
        except Exception as e:
            output = str(e)
    return render_template('report.html', user=session['user'], output=output)

@app.route('/inquiry', methods=['GET', 'POST'])
def inquiry():
    if 'user' not in session:
        return redirect(url_for('login'))
    submitted = False
    if request.method == 'POST':
        submitted = True
    return render_template('inquiry.html', user=session['user'], submitted=submitted)

@app.route('/logout')
def logout():
    session.clear()
    return redirect(url_for('index'))

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=80)
