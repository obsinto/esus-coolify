#!/bin/sh
# Script de backup automático do e-SUS PEC
# Executa backup diário e mantém apenas os últimos N backups
# Os backups são salvos diretamente no host via bind mount

set -e

# Configurações
BACKUP_DIR="/backups"
DB_NAME="${POSTGRES_DB:-esus}"
DB_USER="${POSTGRES_USER:-postgres}"
RETENTION_DAYS="${BACKUP_RETENTION_DAYS:-7}"
TIMESTAMP=$(date +"%Y_%m_%d__%H_%M_%S")
BACKUP_FILE="${BACKUP_DIR}/backup_${TIMESTAMP}.backup"

# Criar diretório de backups se não existir
mkdir -p "${BACKUP_DIR}"

echo "=== Iniciando backup automático ==="
echo "Data/Hora: $(date)"
echo "Banco: ${DB_NAME}"
echo "Arquivo: ${BACKUP_FILE}"

# Executar backup
pg_dump \
  --host localhost \
  --port 5432 \
  -U "${DB_USER}" \
  --format custom \
  --blobs \
  --encoding UTF8 \
  --no-privileges \
  --no-tablespaces \
  --no-unlogged-table-data \
  --file "${BACKUP_FILE}" \
  "${DB_NAME}"

if [ $? -eq 0 ]; then
  echo "✅ Backup criado com sucesso: ${BACKUP_FILE}"

  # Verificar tamanho do backup
  BACKUP_SIZE=$(du -h "${BACKUP_FILE}" | cut -f1)
  echo "Tamanho do backup: ${BACKUP_SIZE}"

  # Upload para S3 se configurado
  if [ -n "${S3_BUCKET}" ]; then
    echo ""
    echo "=== Enviando backup para S3 ==="
    echo "Bucket: ${S3_BUCKET}"
    echo "Região: ${AWS_DEFAULT_REGION:-us-east-1}"

    # Verificar se AWS CLI está disponível
    if command -v aws >/dev/null 2>&1; then
      # Nome do arquivo no S3
      S3_KEY="esus-backups/$(basename ${BACKUP_FILE})"

      # Upload para S3
      aws s3 cp "${BACKUP_FILE}" "s3://${S3_BUCKET}/${S3_KEY}" \
        ${AWS_ENDPOINT_URL:+--endpoint-url "$AWS_ENDPOINT_URL"} \
        && echo "✅ Backup enviado para S3: s3://${S3_BUCKET}/${S3_KEY}" \
        || echo "❌ Erro ao enviar backup para S3"

      # Limpar backups antigos no S3
      if [ -n "${BACKUP_RETENTION_DAYS}" ] && [ "${BACKUP_RETENTION_DAYS}" -gt 0 ]; then
        echo ""
        echo "=== Limpando backups antigos no S3 ==="
        CUTOFF_DATE=$(date -d "${BACKUP_RETENTION_DAYS} days ago" +%Y-%m-%d 2>/dev/null || date -v-${BACKUP_RETENTION_DAYS}d +%Y-%m-%d)

        aws s3 ls "s3://${S3_BUCKET}/esus-backups/" ${AWS_ENDPOINT_URL:+--endpoint-url "$AWS_ENDPOINT_URL"} | while read -r line; do
          FILE_DATE=$(echo "$line" | awk '{print $1}')
          FILE_NAME=$(echo "$line" | awk '{print $4}')

          if [ -n "$FILE_NAME" ] && [ "$FILE_DATE" \< "$CUTOFF_DATE" ]; then
            echo "Removendo backup antigo do S3: $FILE_NAME"
            aws s3 rm "s3://${S3_BUCKET}/esus-backups/${FILE_NAME}" ${AWS_ENDPOINT_URL:+--endpoint-url "$AWS_ENDPOINT_URL"}
          fi
        done
      fi
    else
      echo "⚠️  AWS CLI não instalado - pulando upload para S3"
      echo "Para habilitar backups S3, instale o AWS CLI na imagem Docker"
    fi
  fi
else
  echo "❌ Erro ao criar backup!"
  exit 1
fi

# Remover backups antigos (manter apenas os últimos N dias)
echo ""
echo "=== Limpando backups antigos (mantendo últimos ${RETENTION_DAYS} dias) ==="
BACKUP_COUNT=$(find "${BACKUP_DIR}" -name "backup_*.backup" -type f 2>/dev/null | wc -l)
echo "Total de backups antes da limpeza: ${BACKUP_COUNT}"

if [ "${BACKUP_COUNT}" -gt 0 ]; then
  # Remover backups com mais de RETENTION_DAYS dias
  REMOVED=0
  find "${BACKUP_DIR}" -name "backup_*.backup" -type f -mtime +${RETENTION_DAYS} 2>/dev/null | while read -r old_backup; do
    if [ -f "$old_backup" ]; then
      echo "Removendo backup antigo: $(basename "$old_backup")"
      rm -f "$old_backup"
      REMOVED=$((REMOVED + 1))
    fi
  done

  BACKUP_COUNT_AFTER=$(find "${BACKUP_DIR}" -name "backup_*.backup" -type f 2>/dev/null | wc -l)
  echo "Backups restantes: ${BACKUP_COUNT_AFTER}"
else
  echo "Nenhum backup encontrado para limpar"
fi

# Listar backups disponíveis
echo ""
echo "=== Backups disponíveis ==="
ls -lh "${BACKUP_DIR}"/backup_*.backup 2>/dev/null || echo "Nenhum backup encontrado"

echo ""
echo "=== Backup automático concluído ==="
