.PHONY: help deploy destroy plan output status clean

# Configurações
PROJECT_NAME = fiap-hack
AWS_REGION = us-east-1
ENVIRONMENT = production

help: ## Mostra esta ajuda
	@echo "🔴 Redis - Cache e Session Storage"
	@echo ""
	@echo "📋 Comandos disponíveis:"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-20s\033[0m %s\n", $$1, $$2}'

deploy: ## Deploy do Redis no Kubernetes
	@echo "🚀 Deployando Redis..."
	@echo "🔍 Verificando se o cluster EKS está pronto..."
	./check-cluster.sh
	@echo "📦 Inicializando Terraform..."
	cd terraform && terraform init
	@echo "📋 Gerando plano..."
	cd terraform && terraform plan -out=tfplan
	@echo "🚀 Aplicando configurações..."
	cd terraform && terraform apply tfplan
	@echo "✅ Redis deployado!"

destroy: ## Destroi o Redis
	@echo "🗑️ Destruindo Redis..."
	cd terraform && terraform destroy -auto-approve
	@echo "✅ Redis destruído!"

plan: ## Plano do Terraform
	@echo "📋 Gerando plano do Terraform..."
	cd terraform && terraform init
	cd terraform && terraform plan

output: ## Mostra outputs do Terraform
	@echo "📊 Outputs do Redis:"
	cd terraform && terraform output

status: ## Status do Redis no Kubernetes
	@echo "📊 Status do Redis:"
	@kubectl get pods -n redis 2>/dev/null || echo "Namespace redis não encontrado"

get-credentials: ## Obtém credenciais do Redis
	@echo "🔑 Credenciais do Redis:"
	@echo "Host: $(shell cd terraform && terraform output -raw redis_host 2>/dev/null || echo 'N/A')"
	@echo "Port: $(shell cd terraform && terraform output -raw redis_port 2>/dev/null || echo 'N/A')"
	@echo "Password: $(shell cd terraform && terraform output -raw redis_password 2>/dev/null || echo 'N/A')"

clean: ## Limpa arquivos temporários
	@echo "🧹 Limpando arquivos temporários..."
	cd terraform && rm -f tfplan
	@echo "✅ Limpeza concluída!" 