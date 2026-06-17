# tess-acme

> Gerador de CSR com validação de domínio brasileiro e suporte a wildcard via protocolo ACME.

## ✅ Funcionalidades

- Validação de FQDN conforme **RFC 1035**
- Validação de **SLDs oficiais do Registro.br** (`.com.br`, `.org.br`, `.gov.br`, etc.)
- Suporte a certificados **padrão** e **wildcard** (`*.dominio.com.br`)
- Geração automática de **SAN** (Subject Alternative Names)
- Saída organizada por domínio em `./csr-output/<fqdn>/`

---

## 📋 Pré-requisitos

```bash
# Debian/Ubuntu
apt install openssl

# RHEL/CentOS
yum install openssl
```

---

## 🚀 Uso

```bash
# Dar permissão de execução
chmod +x scripts/generate-csr.sh

# Certificado padrão (FQDN + www.FQDN)
./scripts/generate-csr.sh meusite.com.br

# Certificado wildcard (*.FQDN + FQDN)
./scripts/generate-csr.sh "*.meusite.com.br"
```

> ⚠️ **Sempre use aspas ao passar domínio wildcard** para evitar expansão do shell.

---

## 📁 Estrutura de saída

```
csr-output/
└── meusite.com.br/
    ├── meusite_com_br.key          # Chave privada RSA 2048 bits
    ├── meusite_com_br.csr          # CSR pronto para envio à CA
    └── meusite_com_br.cnf          # Configuração OpenSSL utilizada

csr-output/
└── meusite.com.br/
    ├── wildcard_meusite_com_br.key # Chave privada RSA 2048 bits
    ├── wildcard_meusite_com_br.csr # CSR wildcard pronto para envio à CA
    └── wildcard_meusite_com_br.cnf # Configuração OpenSSL utilizada
```

---

## 🔐 Integração com Certbot (ACME / DigiCert)

```bash
# Certificado padrão
certbot certonly --csr csr-output/meusite.com.br/meusite_com_br.csr \
  --cert-path /etc/letsencrypt/live/meusite.com.br/cert.pem \
  --chain-path /etc/letsencrypt/live/meusite.com.br/chain.pem \
  --fullchain-path /etc/letsencrypt/live/meusite.com.br/fullchain.pem \
  --preferred-challenges http

# Certificado wildcard (requer desafio DNS)
certbot certonly --csr csr-output/meusite.com.br/wildcard_meusite_com_br.csr \
  --cert-path /etc/letsencrypt/live/meusite.com.br/cert.pem \
  --chain-path /etc/letsencrypt/live/meusite.com.br/chain.pem \
  --fullchain-path /etc/letsencrypt/live/meusite.com.br/fullchain.pem \
  --preferred-challenges dns
```

> ⚠️ Certificados wildcard **exigem desafio DNS** (`--preferred-challenges dns`). Desafios HTTP não são suportados para wildcards no protocolo ACME.

---

## 📌 SANs gerados por tipo

| Tipo        | DNS.1                  | DNS.2            |
|-------------|------------------------|------------------|
| Padrão      | `meusite.com.br`       | `www.meusite.com.br` |
| Wildcard    | `*.meusite.com.br`     | `meusite.com.br` |

---

## ⚙️ Configuração

Edite as constantes no topo do script conforme sua organização:

```bash
readonly STATE="Bahia"
readonly CITY="Salvador"
readonly ORGANIZATION="Minha Empresa Ltda"
readonly ORG_UNIT="TI"
```

---

## 🛡️ Segurança

- A chave privada (`.key`) **nunca deve ser enviada para a CA**
- Armazene a chave em local seguro (ex: HashiCorp Vault, AWS Secrets Manager)
- O arquivo `.cnf` pode ser versionado com segurança

---

## 📄 Licença

MIT © [Inaldo Nascimento da Conceição](https://github.com/inaldoconceicao-prodeb)
