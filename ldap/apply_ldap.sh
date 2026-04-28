#!/bin/bash
# =============================================================
# apply_ldap.sh — Initialise OpenLDAP avec la structure IRIS
# A executer depuis SRV_MAIN : bash /vagrant/ldap/apply_ldap.sh
# =============================================================

set -e
LDAP_ADMIN="cn=admin,dc=iris,dc=local"
LDAP_PASS="adminpassword"
LDAP_HOST="localhost"
LDIF_DIR="/vagrant/ldap"

echo "=== Initialisation OpenLDAP IRIS ==="
echo "[INFO] Attente du container openldap..."
until docker exec openldap ldapsearch -x -H ldap://localhost -b "dc=iris,dc=local" -D "$LDAP_ADMIN" -w "$LDAP_PASS" > /dev/null 2>&1; do
    sleep 3
    echo "[WAIT] Container pas encore pret..."
done
echo "[OK] OpenLDAP accessible"

# ── Nettoyer les entrees generiques si presentes ──────────────
echo "[INFO] Suppression des anciens comptes de test (etudiant1, prof1...)..."
for uid in etudiant1 prof1 admin guest1; do
    docker exec openldap ldapdelete -x -H ldap://localhost \
        -D "$LDAP_ADMIN" -w "$LDAP_PASS" \
        "uid=${uid},dc=iris,dc=local" 2>/dev/null || true
done

# ── Appliquer la structure ────────────────────────────────────
echo "[INFO] Creation des OU et groupes..."
docker exec openldap ldapadd -x -H ldap://localhost \
    -D "$LDAP_ADMIN" -w "$LDAP_PASS" \
    -f /vagrant/ldap/01_structure.ldif 2>&1 | grep -v "^$" || true
echo "[OK] Structure OUs et groupes creee"

# ── Appliquer les utilisateurs ────────────────────────────────
echo "[INFO] Import des utilisateurs (miroir AD)..."
docker exec openldap ldapadd -x -H ldap://localhost \
    -D "$LDAP_ADMIN" -w "$LDAP_PASS" \
    -f /vagrant/ldap/02_users.ldif 2>&1 | grep -v "^$" || true
echo "[OK] Utilisateurs importes"

# ── Verification ──────────────────────────────────────────────
echo ""
echo "=== VERIFICATION ==="
echo "--- Nombre d'utilisateurs ---"
docker exec openldap ldapsearch -x -H ldap://localhost \
    -b "ou=Utilisateurs,dc=iris,dc=local" \
    -D "$LDAP_ADMIN" -w "$LDAP_PASS" \
    "(objectClass=inetOrgPerson)" uid 2>/dev/null | grep "^uid:" | sort

echo ""
echo "--- Groupes ---"
docker exec openldap ldapsearch -x -H ldap://localhost \
    -b "ou=Groupes,dc=iris,dc=local" \
    -D "$LDAP_ADMIN" -w "$LDAP_PASS" \
    "(objectClass=groupOfNames)" cn 2>/dev/null | grep "^cn:"

echo ""
echo "[OK] OpenLDAP initialise avec les vrais comptes IRIS"
echo "[INFO] Acces phpLDAPadmin : http://192.168.50.10:8080"
echo "[INFO] Login : cn=admin,dc=iris,dc=local / adminpassword"
