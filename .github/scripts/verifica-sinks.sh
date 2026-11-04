#!/usr/bin/env bash
# Verifica os "sinks" de XSS e o /debug/info contra a aplicacao em execucao.
# Uso: bash .github/scripts/verifica-sinks.sh http://localhost:5000
set -u
BASE="${1:-http://localhost:5000}"
JAR="$(mktemp)"
erro=0

falha() { echo "FALHA: $1"; erro=1; }

curl -s -c "$JAR" -o /dev/null -d "username=admin&password=admin123" "$BASE/login"
curl -s -b "$JAR" -o /dev/null \
  --data-urlencode "title=teste xss" \
  --data-urlencode "description=<script>alert('XSS')</script>" "$BASE/tasks/new"

# 1) XSS armazenado: a descricao tem que aparecer como texto, nunca como <script>
corpo="$(curl -s -b "$JAR" "$BASE/tasks")"
echo "$corpo" | grep -q "<script>alert('XSS')</script>" && falha "XSS armazenado: o <script> saiu cru em /tasks"
echo "$corpo" | grep -q "&lt;script&gt;" || falha "XSS armazenado: o texto nao apareceu escapado em /tasks"

# 2) parametro q da busca
corpo="$(curl -s -b "$JAR" "$BASE/tasks?q=%3Cscript%3Ealert(1)%3C/script%3E")"
echo "$corpo" | grep -q "<script>alert(1)</script>" && falha "parametro q: o <script> voltou cru"

# 3) mensagem de erro do login
corpo="$(curl -s -d "username=%3Cscript%3Ealert(2)%3C/script%3E&password=x" "$BASE/login")"
echo "$corpo" | grep -q "<script>alert(2)</script>" && falha "erro do login: o <script> voltou cru"

# 4) endpoint de debug removido
codigo="$(curl -s -o /dev/null -w '%{http_code}' "$BASE/debug/info")"
[ "$codigo" = "404" ] || falha "/debug/info devolveu $codigo (esperado 404)"

rm -f "$JAR"
if [ "$erro" = "0" ]; then echo "OK: sinks de XSS e /debug/info verificados"; fi
exit "$erro"
