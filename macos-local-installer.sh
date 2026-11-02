#!/usr/bin/env bash
# DeskcommCRM - Instalador local para macOS (Intel ou Apple Silicon)
#
# Sobe tudo NO SEU MAC: Supabase local (Postgres + Auth + Storage + Realtime),
# app, worker, scheduler (lembretes e automações), WAHA (WhatsApp) e Redis.
# Nada vai para a nuvem, a não ser o que você ligar depois (ex.: provedor de IA).
#
# Uso, dentro do clone:   bash macos-local-installer.sh
# Escolher o e-mail do admin sem pergunta:  OWNER_EMAIL=voce@exemplo.com bash macos-local-installer.sh
#
# Compatível com o Bash 3.2 que vem no macOS.

set -Eeuo pipefail

paint() { printf '\033[%sm%s\033[0m\n' "$1" "$2"; }
step()  { printf '\n'; paint 32 "▶ $1"; }
warn()  { paint 33 "⚠ $1"; }
error() { printf '\n'; paint 31 "✖ $1"; exit 1; }

[[ "$(uname -s)" == "Darwin" ]] || error "Este instalador é para macOS. No Ubuntu, use ./ubuntu-local-installer.sh."

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$ROOT_DIR"

# ── 1. Homebrew ────────────────────────────────────────────────────────────
step "Verificando o Homebrew..."
if ! command -v brew >/dev/null 2>&1; then
  for candidato in /opt/homebrew/bin/brew /usr/local/bin/brew; do
    if [[ -x "$candidato" ]]; then eval "$("$candidato" shellenv)"; break; fi
  done
fi
if ! command -v brew >/dev/null 2>&1; then
  paint 33 "O Homebrew (instalador de programas do Mac) não está instalado."
  echo  "Instale com o comando abaixo (ele pede a senha do Mac) e rode este instalador de novo:"
  echo
  echo  '  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"'
  echo
  exit 1
fi

# ── 2. Docker Desktop ──────────────────────────────────────────────────────
step "Verificando o Docker Desktop..."
if ! command -v docker >/dev/null 2>&1 && [[ ! -d /Applications/Docker.app ]]; then
  echo "Instalando o Docker Desktop pelo Homebrew..."
  brew install --cask docker
fi
if ! docker info >/dev/null 2>&1; then
  echo "Abrindo o Docker Desktop (na primeira vez, aceite os termos na janela que abrir)..."
  open -a Docker || true
  for _ in $(seq 1 60); do
    docker info >/dev/null 2>&1 && break
    sleep 3
  done
fi
docker info >/dev/null 2>&1 || error "O Docker não respondeu. Abra o Docker Desktop, espere ficar verde e rode de novo."

MEM_DOCKER_GB=$(( $(docker info --format '{{.MemTotal}}' 2>/dev/null || echo 0) / 1024 / 1024 / 1024 ))
if (( MEM_DOCKER_GB > 0 && MEM_DOCKER_GB < 6 )); then
  warn "O Docker Desktop está com ${MEM_DOCKER_GB} GB de memória. Recomendo 6 GB ou mais"
  warn "(Docker Desktop › Settings › Resources) para o build não falhar."
fi

# ── 3. Node 22 + pnpm ──────────────────────────────────────────────────────
step "Verificando Node.js 22 e pnpm..."
NODE_MAJOR="$(node -p 'process.versions.node.split(".")[0]' 2>/dev/null || true)"
if [[ "${NODE_MAJOR:-0}" != "22" ]]; then
  brew list node@22 >/dev/null 2>&1 || brew install node@22
  export PATH="$(brew --prefix node@22)/bin:$PATH"
fi
if ! command -v pnpm >/dev/null 2>&1; then
  npm install --global pnpm@9.15.9
fi
command -v git >/dev/null 2>&1 || brew install git
command -v openssl >/dev/null 2>&1 || brew install openssl

# Se não estivermos na raiz do projeto, clona e entra nele.
if [[ ! -f "package.json" ]]; then
  step "Clonando o repositório..."
  git clone https://github.com/carlosmionbsb-ai/DeskcommCRM.git
  cd DeskcommCRM
  ROOT_DIR="$(pwd)"
fi

# ── 4. Dependências e stack ────────────────────────────────────────────────
step "Instalando dependências do projeto (pode levar alguns minutos)..."
pnpm install --frozen-lockfile

step "Subindo Supabase local e os serviços (o primeiro build leva de 10 a 20 minutos)..."
# local-stack.sh inicia o Supabase local, aplica o schema (baseline.sql), gera
# o .env.local com segredos aleatórios (scripts/local-env.sh) e sobe app,
# worker, scheduler, WAHA e Redis. Rodar de novo não apaga nada.
./scripts/local-stack.sh up

env_value() { awk -F= -v key="$1" '$1 == key { sub(/^[^=]*=/, ""); print; exit }' .env.local; }
APP_URL="$(env_value NEXT_PUBLIC_APP_URL)"

# ── 5. Usuário administrador ───────────────────────────────────────────────
step "Criando o usuário administrador..."
if [[ -z "${OWNER_EMAIL:-}" && -t 0 ]]; then
  read -r -p "E-mail para entrar no sistema [admin@admin.com]: " OWNER_EMAIL || true
fi
export OWNER_EMAIL="${OWNER_EMAIL:-admin@admin.com}"
# A senha NASCE ALEATÓRIA e é impressa no fim (mesma regra do instalador Ubuntu).
export OWNER_PASSWORD="${OWNER_PASSWORD:-$(openssl rand -base64 18)}"
export OWNER_ORG_NAME="${OWNER_ORG_NAME:-Consultório}"
export APP_LOCALE="pt-BR"
NEXT_PUBLIC_SUPABASE_URL="$(env_value NEXT_PUBLIC_SUPABASE_URL)"
SUPABASE_SERVICE_ROLE_KEY="$(env_value SUPABASE_SERVICE_ROLE_KEY)"
export NEXT_PUBLIC_SUPABASE_URL SUPABASE_SERVICE_ROLE_KEY
pnpm exec tsx scripts/bootstrap-owner.ts

printf '\n\n\033[32m================================================================\033[0m\n'
paint 32 "✅ Instalação concluída!"
echo
echo "🌐 Abra no navegador: $APP_URL"
echo "🔑 E-mail: $OWNER_EMAIL"
echo "🔑 Senha:  $OWNER_PASSWORD   (anote agora; troque depois em Perfil)"
echo
echo "🧭 Status:  ./scripts/local-stack.sh status"
echo "🛑 Parar:   ./scripts/local-stack.sh down"
echo "▶️  Ligar:   ./scripts/local-stack.sh up"
echo
paint 33 "Para os lembretes de consulta saírem na hora:"
echo "  • Docker Desktop › Settings › General › marque 'Start Docker Desktop when you sign in'"
echo "  • Ajustes do Sistema › Bateria/Energia › impeça o Mac de dormir com a tela desligada"
echo "    (ou deixe rodando:  caffeinate -dimsu &  )"
echo
paint 33 "Segurança (conversas de paciente são dado sensível):"
echo "  • O CRM e o painel do WhatsApp só atendem este Mac (127.0.0.1)."
echo "  • Ative o firewall: Ajustes do Sistema › Rede › Firewall, e marque"
echo "    'Bloquear todas as conexões de entrada' nas opções. Isso também fecha"
echo "    as portas do banco local para o Wi-Fi do consultório."
echo "  • Ative o FileVault (criptografia do disco) em Privacidade e Segurança."
printf '\033[32m================================================================\033[0m\n'
