#!/usr/bin/env bash
# =============================================================================
# generate-csr.sh
# Gera um CSR com SAN para um FQDN válido no Brasil (suporta Wildcard).
# Uso: ./generate-csr.sh "meusite.com.br" ou ./generate-csr.sh "*.meusite.com.br"
# IMPORTANTE: Sempre use aspas ao passar um wildcard para evitar expansão do shell.
# =============================================================================

set -euo pipefail

# -----------------------------------------------------------------------------
# Constantes — ajuste conforme sua organização
# -----------------------------------------------------------------------------
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly NC='\033[0m'

readonly OUTPUT_DIR="./csr-output"
readonly KEY_BITS=2048
readonly COUNTRY="BR"
readonly STATE="Bahia"
readonly CITY="Salvador"
readonly ORGANIZATION="Minha Empresa Ltda"
readonly ORG_UNIT="TI"

# SLDs oficiais registrados no Brasil (Registro.br)
readonly BR_SLDS=(
  "com.br" "net.br" "org.br" "gov.br" "edu.br" "mil.br"
  "art.br" "blog.br" "emp.br" "eng.br" "esp.br" "etc.br"
  "far.br" "flog.br" "foto.br" "info.br" "jor.br" "med.br"
  "nom.br" "not.br" "ntr.br" "odo.br" "ppg.br" "pro.br"
  "psc.br" "rec.br" "slg.br" "srv.br" "taxi.br" "teo.br"
  "tmp.br" "trd.br" "tur.br" "tv.br" "vlog.br" "wiki.br"
  "zlg.br" "adm.br" "adv.br" "agr.br" "arq.br" "ato.br"
  "bio.br" "bmd.br" "cim.br" "cng.br" "cnt.br" "coop.br"
  "ecn.br" "eco.br" "eti.br" "fnd.br" "imb.br" "ind.br"
  "inf.br" "leg.br" "mat.br" "mus.br" "nfe.br" "ong.br"
  "pol.br" "radio.br" "seg.br" "tec.br" "van.br" "vet.br"
  "b.br" "am.br" "br.com"
)

# -----------------------------------------------------------------------------
# Funções auxiliares
# -----------------------------------------------------------------------------
log_info()  { echo -e "${GREEN}[INFO]${NC}  $*"; }
log_warn()  { echo -e "${YELLOW}[WARN]${NC}  $*"; }
log_error() { echo -e "${RED}[ERROR]${NC} $*" >&2; }

usage() {
  echo "Uso: $0 <fqdn>"
  echo "Exemplo Normal  : $0 meusite.com.br"
  echo "Exemplo Wildcard: $0 \"*.meusite.com.br\" (Use aspas!)"
  exit 1
}

# -----------------------------------------------------------------------------
# Validações de FQDN (RFC 1035)
# -----------------------------------------------------------------------------
validate_fqdn() {
  local fqdn="${1,,}"

  if [[ ${#fqdn} -gt 253 ]]; then
    log_error "FQDN excede 253 caracteres (RFC 1035)."
    return 1
  fi

  if [[ "$fqdn" =~ ^\. || "$fqdn" =~ \.$ ]]; then
    log_error "FQDN não pode iniciar ou terminar com ponto."
    return 1
  fi

  IFS='.' read -ra labels <<< "$fqdn"

  for label in "${labels[@]}"; do
    if [[ ${#label} -lt 1 || ${#label} -gt 63 ]]; then
      log_error "Label '$label' inválido: deve ter entre 1 e 63 caracteres."
      return 1
    fi
    if [[ ! "$label" =~ ^[a-z0-9]([a-z0-9-]*[a-z0-9])?$ && ! "$label" =~ ^[a-z0-9]$ ]]; then
      log_error "Label '$label' contém caracteres inválidos ou hífen em posição indevida."
      return 1
    fi
  done

  if [[ ${#labels[@]} -lt 2 ]]; then
    log_error "FQDN deve conter ao menos dois níveis (ex: site.com.br)."
    return 1
  fi

  return 0
}

validate_br_domain() {
  local fqdn="${1,,}"
  local matched=false

  for sld in "${BR_SLDS[@]}"; do
    if [[ "$fqdn" == *."$sld" ]]; then
      matched=true
      break
    fi
  done

  if [[ "$fqdn" == *.br ]] && [[ "$matched" == false ]]; then
    log_warn "Domínio .br sem SLD oficial reconhecido. Verifique no Registro.br."
    matched=true
  fi

  if [[ "$matched" == false ]]; then
    log_error "Domínio '$fqdn' não possui um SLD válido registrado no Brasil."
    log_error "Exemplos válidos: .com.br, .net.br, .org.br, .gov.br, .edu.br"
    return 1
  fi

  return 0
}

# -----------------------------------------------------------------------------
# Dependências
# -----------------------------------------------------------------------------
check_dependencies() {
  if ! command -v openssl &>/dev/null; then
    log_error "OpenSSL não encontrado. Instale com: apt install openssl"
    exit 1
  fi
}

# -----------------------------------------------------------------------------
# Geração do CSR com SAN (FQDN + www.FQDN ou *.FQDN + FQDN)
# -----------------------------------------------------------------------------
generate_csr() {
  local input_fqdn="${1,,}"
  local is_wildcard="${2}"
  local base_domain="${3,,}"

  local safe_name
  local out_dir="${OUTPUT_DIR}/${base_domain}"
  local dns1
  local dns2

  if [[ "$is_wildcard" == true ]]; then
    safe_name="wildcard_${base_domain//./_}"
    dns1="${input_fqdn}"
    dns2="${base_domain}"
  else
    safe_name="${base_domain//./_}"
    dns1="${base_domain}"
    dns2="www.${base_domain}"
  fi

  local key_file="${out_dir}/${safe_name}.key"
  local csr_file="${out_dir}/${safe_name}.csr"
  local conf_file="${out_dir}/${safe_name}.cnf"

  mkdir -p "$out_dir"

  log_info "Gerando configuração OpenSSL..."
  cat > "$conf_file" <<EOF
[ req ]
default_bits        = ${KEY_BITS}
default_md          = sha256
prompt              = no
encrypt_key         = no
distinguished_name  = dn
req_extensions      = req_ext

[ dn ]
C  = ${COUNTRY}
ST = ${STATE}
L  = ${CITY}
O  = ${ORGANIZATION}
OU = ${ORG_UNIT}
CN = ${input_fqdn}

[ req_ext ]
subjectAltName = @alt_names

[ alt_names ]
DNS.1 = ${dns1}
DNS.2 = ${dns2}
EOF

  log_info "Gerando chave privada RSA ${KEY_BITS} bits..."
  openssl genrsa -out "$key_file" "$KEY_BITS" 2>/dev/null

  log_info "Gerando CSR..."
  openssl req -new \
    -key "$key_file" \
    -out "$csr_file" \
    -config "$conf_file"

  log_info "Validando SANs do CSR gerado..."
  openssl req -noout -text -in "$csr_file" | grep -E "Subject:|DNS:" || true

  echo ""
  log_info "Arquivos gerados em: ${out_dir}/"
  echo -e "  ${YELLOW}Chave privada :${NC} ${key_file}"
  echo -e "  ${YELLOW}CSR           :${NC} ${csr_file}"
  echo -e "  ${YELLOW}Config OpenSSL:${NC} ${conf_file}"
  echo ""
  log_warn "GUARDE A CHAVE PRIVADA EM LOCAL SEGURO. Nunca envie para a CA."
}

# -----------------------------------------------------------------------------
# Main
# -----------------------------------------------------------------------------
main() {
  [[ $# -lt 1 ]] && usage

  local input_fqdn="${1}"
  local is_wildcard=false
  local base_domain="$input_fqdn"

  if [[ "$input_fqdn" == \*\.* ]]; then
    is_wildcard=true
    base_domain="${input_fqdn#\*.}"
  fi

  check_dependencies

  log_info "Validando domínio base: ${base_domain}"
  validate_fqdn "$base_domain"      || exit 1
  validate_br_domain "$base_domain" || exit 1
  log_info "Domínio válido."

  generate_csr "$input_fqdn" "$is_wildcard" "$base_domain"

  if [[ "$is_wildcard" == true ]]; then
    log_info "CSR Wildcard gerado com sucesso para: ${input_fqdn} e ${base_domain}"
  else
    log_info "CSR gerado com sucesso para: ${base_domain} e www.${base_domain}"
  fi
}

main "$@"
