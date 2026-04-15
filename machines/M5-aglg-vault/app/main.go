// Operation BlackVault — M5: aglg-vault (LFI + SUID)
// Go HTTP server — Classified Document Vault Portal

package main

import (
	"fmt"
	"html/template"
	"log"
	"net/http"
	"os"
	"path/filepath"
	"strings"
)

var (
	vaultPort = getEnv("VAULT_PORT", "8443")
	vaultRoot = getEnv("VAULT_ROOT", "/opt/aglg/vault")
	templates = template.Must(template.ParseGlob("templates/*.html"))
)

func getEnv(key, def string) string {
	if v := os.Getenv(key); v != "" {
		return v
	}
	return def
}

// Static credentials
var vaultUsers = map[string]string{
	"archivist": "Arch1v1st@AGLG",
	"vault_ops": "V@ultOps2024!",
}

// Session store (in-memory)
var sessions = map[string]string{}

func genToken() string {
	b := make([]byte, 16)
	f, _ := os.Open("/dev/urandom")
	f.Read(b)
	f.Close()
	return fmt.Sprintf("%x", b)
}

func getUser(r *http.Request) string {
	cookie, err := r.Cookie("vault_session")
	if err != nil {
		return ""
	}
	return sessions[cookie.Value]
}

// ── Handlers ─────────────────────────────────────────────────────────────────

func indexHandler(w http.ResponseWriter, r *http.Request) {
	if getUser(r) != "" {
		http.Redirect(w, r, "/dashboard", http.StatusFound)
		return
	}
	templates.ExecuteTemplate(w, "index.html", nil)
}

func loginHandler(w http.ResponseWriter, r *http.Request) {
	if r.Method == http.MethodGet {
		templates.ExecuteTemplate(w, "index.html", nil)
		return
	}
	user := r.FormValue("username")
	pass := r.FormValue("password")
	if pw, ok := vaultUsers[user]; ok && pw == pass {
		token := genToken()
		sessions[token] = user
		http.SetCookie(w, &http.Cookie{Name: "vault_session", Value: token, Path: "/"})
		http.Redirect(w, r, "/dashboard", http.StatusFound)
		return
	}
	templates.ExecuteTemplate(w, "index.html", map[string]string{"Error": "Invalid credentials."})
}

func dashboardHandler(w http.ResponseWriter, r *http.Request) {
	user := getUser(r)
	if user == "" {
		http.Redirect(w, r, "/", http.StatusFound)
		return
	}
	// Enumerate vault documents for display
	docs := []map[string]string{}
	entries, _ := os.ReadDir(vaultRoot)
	for _, e := range entries {
		if e.IsDir() {
			subEntries, _ := os.ReadDir(filepath.Join(vaultRoot, e.Name()))
			for _, se := range subEntries {
				if !se.IsDir() {
					docs = append(docs, map[string]string{
						"Path": e.Name() + "/" + se.Name(),
						"Name": se.Name(),
						"Dir":  e.Name(),
					})
				}
			}
		}
	}
	templates.ExecuteTemplate(w, "dashboard.html", map[string]interface{}{
		"User": user,
		"Docs": docs,
	})
}

func viewHandler(w http.ResponseWriter, r *http.Request) {
	user := getUser(r)
	if user == "" {
		http.Redirect(w, r, "/", http.StatusFound)
		return
	}

	// VULNERABILITY: Path traversal — doc parameter not sanitized
	// Intended: serve files from vaultRoot only
	// Flaw: filepath.Join does not prevent traversal with ../../
	docParam := r.URL.Query().Get("doc")
	if docParam == "" {
		http.Error(w, "Missing doc parameter", 400)
		return
	}

	// Weak check — only looks for literal ".." string, easily bypassed
	if strings.Contains(docParam, "....") {
		http.Error(w, "Invalid path", 403)
		return
	}

	// VULNERABILITY: Path traversal — combines vaultRoot with attacker-controlled path
	targetPath := filepath.Join(vaultRoot, docParam)
	// Note: filepath.Clean("../../root/flag5.txt") resolves successfully
	content, err := os.ReadFile(targetPath)
	if err != nil {
		templates.ExecuteTemplate(w, "view.html", map[string]interface{}{
			"User":    user,
			"Doc":     docParam,
			"Error":   "Document not found or access denied.",
			"Content": "",
		})
		return
	}

	templates.ExecuteTemplate(w, "view.html", map[string]interface{}{
		"User":    user,
		"Doc":     docParam,
		"Error":   "",
		"Content": string(content),
	})
}

func logoutHandler(w http.ResponseWriter, r *http.Request) {
	cookie, err := r.Cookie("vault_session")
	if err == nil {
		delete(sessions, cookie.Value)
	}
	http.SetCookie(w, &http.Cookie{Name: "vault_session", Value: "", MaxAge: -1, Path: "/"})
	http.Redirect(w, r, "/", http.StatusFound)
}

func apiStatusHandler(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "application/json")
	fmt.Fprintf(w, `{"status":"operational","version":"1.0.3","vault":"%s"}`, vaultRoot)
}

func main() {
	http.HandleFunc("/", indexHandler)
	http.HandleFunc("/login", loginHandler)
	http.HandleFunc("/dashboard", dashboardHandler)
	http.HandleFunc("/view", viewHandler)
	http.HandleFunc("/logout", logoutHandler)
	http.HandleFunc("/api/status", apiStatusHandler)

	addr := "0.0.0.0:" + vaultPort
	log.Printf("[aglg-vault] Classified Vault running on %s — vault root: %s", addr, vaultRoot)
	log.Fatal(http.ListenAndServe(addr, nil))
}
