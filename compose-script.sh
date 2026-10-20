#!/usr/bin/env bash
set -e

## ==============================================================================
## Helper Script para Executar Docker Compose em Produção
## Permite rodar comandos a partir de qualquer diretório mantendo caminhos absolutos:
#
## Exemplos:
##   ./compose-script.sh ps
##   ./compose-script.sh up -d
##   ./compose-script.sh down
##   ./compose-script.sh logs -f [SERVICE_NAME]
##   ./compose-script.sh exec [SERVICE_NAME] [ARGS]
##   ./compose-script.sh exec [SERVICE_NAME] [ARGS]
##   APP_ENV=production ./compose-script.sh ps
## ==============================================================================


## Diretório raiz onde este script está localizado
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

## Detecta se o sistema possui Docker Compose (plugin v2 ou standalone)
if docker compose version 2>/dev/null | grep -qi "Docker Compose"; then
    COMPOSE_CMD=(docker compose)
elif command -v docker-compose >/dev/null 2>&1; then
    COMPOSE_CMD=(docker-compose)
else
    echo "Erro: O Docker Compose não está instalado neste servidor." >&2
    echo "No Ubuntu 24.04, instale executando:" >&2
    echo "  sudo apt update && sudo apt install -y docker-compose-v2" >&2
    echo "  (ou: sudo apt install -y docker-compose-plugin)" >&2
    exit 1
fi

## Define arquivo compose base
if [ -f "$PROJECT_ROOT/compose.base.yml" ]; then
    COMPOSE_BASE="$PROJECT_ROOT/compose.base.yml"
elif [ -f "$PROJECT_ROOT/compose.yml" ]; then
    COMPOSE_BASE="$PROJECT_ROOT/compose.yml"
else
    echo "Erro: Nenhum arquivo compose.base.yml ou compose.yml encontrado em $PROJECT_ROOT" >&2
    exit 1
fi

# Define arquivo compose override de produção
if [ -f "$PROJECT_ROOT/compose.prod.yml" ]; then
    COMPOSE_PROD="$PROJECT_ROOT/compose.prod.yml"
elif [ -f "$PROJECT_ROOT/compose.production.yml" ]; then
    COMPOSE_PROD="$PROJECT_ROOT/compose.production.yml"
elif [ -f "$PROJECT_ROOT/compose.custom.yml" ]; then
    COMPOSE_PROD="$PROJECT_ROOT/compose.custom.yml"
else
    if [[ -f $COMPOSE_BASE ]]; then
        echo "Nenhum arquivo compose.prod.yml, compose.production.yml ou compose.custom.yml encontrado em
            '$PROJECT_ROOT,'
            usando apenas
            '$COMPOSE_BASE'" >&2
        echo;
    else
        echo "Erro: Nenhum arquivo compose.prod.yml, compose.production.yml ou compose.custom.yml encontrado em $PROJECT_ROOT" >&2
        exit 1
    fi
fi

## Busca arquivo de variáveis de ambiente para produção na ordem:
## 1. .env.${APP_ENV} (se APP_ENV estiver definido e existir .env.${APP_ENV})
## 2. .env.production
## 3. .env.prod
## 4. .env
ENV_FILE=""
if [ -n "$APP_ENV" ] && [ -f "$PROJECT_ROOT/.env.$APP_ENV" ]; then
    ENV_FILE="$PROJECT_ROOT/.env.$APP_ENV"
elif [ -f "$PROJECT_ROOT/.env.production" ]; then
    ENV_FILE="$PROJECT_ROOT/.env.production"
elif [ -f "$PROJECT_ROOT/.env.prod" ]; then
    ENV_FILE="$PROJECT_ROOT/.env.prod"
elif [ -f "$PROJECT_ROOT/.env" ]; then
    ENV_FILE="$PROJECT_ROOT/.env"
fi

ENV_ARGS=()
if [ -n "$ENV_FILE" ]; then
    echo "[prod.sh] Carregando variáveis de: $(basename "$ENV_FILE")" >&2
    ## Exporta variáveis para o shell para garantir compatibilidade com qualquer versão do compose
    set -a
    ## shellcheck disable=SC1090
    . "$ENV_FILE"
    set +a
    ENV_ARGS=(--env-file "$ENV_FILE")
else
    echo "[prod.sh] Nenhum arquivo .env (.env.production, .env.prod ou .env) encontrado. Utilizando variáveis de ambiente do sistema." >&2
fi

echo ;
echo "COMPOSE_BASE: $COMPOSE_BASE"
echo "COMPOSE_PROD: $COMPOSE_PROD"
echo ;

## Executa o comando compose apropriado com os caminhos absolutos dos arquivos de produção
if [ -v COMPOSE_PROD ]; then
    exec "${COMPOSE_CMD[@]}" --project-directory "$PROJECT_ROOT" "${ENV_ARGS[@]}" -f "$COMPOSE_BASE" -f "$COMPOSE_PROD" "$@"
else
    exec "${COMPOSE_CMD[@]}" --project-directory "$PROJECT_ROOT" "${ENV_ARGS[@]}" -f "$COMPOSE_BASE" "$@"
fi
