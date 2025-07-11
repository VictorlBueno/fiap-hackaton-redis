# Redis - Estado dos Processamentos

Este módulo provisiona uma instância Redis no Kubernetes (EKS) para armazenar o estado dos processamentos de vídeo enquanto estão sendo processados, acelerando as consultas de status.

## 📋 Visão Geral

O Redis é configurado como um deployment no Kubernetes com:
- **Persistência**: Volume persistente para dados de estado
- **Segurança**: Senha configurável via secret
- **Monitoramento**: Health checks e probes
- **Performance**: Cache de alta velocidade para consultas de status
- **Escalabilidade**: Configurável via variáveis


## 🚀 Deploy

### Pré-requisitos

- Cluster EKS configurado e funcionando
- kubectl configurado para o cluster
- AWS CLI configurado
- Terraform instalado

### Deploy Automático (GitHub Actions)

O deploy é executado automaticamente via GitHub Actions quando há push para a branch `main`:

```yaml
# .github/workflows/deploy.yml
- Validação do Terraform
- Geração do plano
- Aplicação das mudanças
- Verificação do deployment
- Teste de conectividade
```

### Deploy Manual

```bash
# Deploy completo
make deploy

# Apenas gerar plano
make plan

# Verificar status
make status

# Obter credenciais
make get-credentials
```

## ⚙️ Configuração

### Variáveis Principais

| Variável | Descrição | Padrão |
|----------|-----------|--------|
| `redis_namespace` | Namespace Kubernetes | `redis` |
| `redis_image` | Imagem Docker | `redis:7-alpine` |
| `redis_storage_size` | Tamanho do volume | `1Gi` |
| `redis_max_memory` | Memória máxima | `128mb` |

### Configuração de Recursos

| Recurso | Request | Limit |
|---------|---------|-------|
| CPU | `50m` | `100m` |
| Memory | `64Mi` | `128Mi` |

## 🔧 Comandos Úteis

### Makefile

```bash
# Ajuda
make help

# Deploy completo
make deploy

# Destruir infraestrutura
make destroy

# Gerar plano
make plan

# Ver outputs
make output

# Status do deployment
make status

# Obter credenciais
make get-credentials

# Limpar arquivos temporários
make clean
```

### kubectl

```bash
# Ver pods do Redis
kubectl get pods -n redis

# Ver services
kubectl get svc -n redis

# Logs do Redis
kubectl logs -n redis deployment/redis

# Executar comando no Redis
kubectl exec -n redis deployment/redis -- redis-cli ping

# Descrever deployment
kubectl describe deployment redis -n redis
```

### Terraform

```bash
# Inicializar
cd terraform && terraform init

# Plan
cd terraform && terraform plan

# Apply
cd terraform && terraform apply

# Outputs
cd terraform && terraform output

# Destroy
cd terraform && terraform destroy
```

## 🔗 Conectividade

### Interno (Kubernetes)

```bash
# URL interna
redis-service.redis.svc.cluster.local:6379

# Teste de conectividade
kubectl exec -n redis deployment/redis -- redis-cli -a $REDIS_PASSWORD ping
```

### Exemplo de Uso - Estado de Processamento

```bash
# Armazenar estado de processamento
kubectl exec -n redis deployment/redis -- redis-cli -a $REDIS_PASSWORD SET "job:12345" "processing"

# Consultar estado de processamento
kubectl exec -n redis deployment/redis -- redis-cli -a $REDIS_PASSWORD GET "job:12345"

# Atualizar estado para concluído
kubectl exec -n redis deployment/redis -- redis-cli -a $REDIS_PASSWORD SET "job:12345" "completed"

# Definir TTL para limpeza automática (24 horas)
kubectl exec -n redis deployment/redis -- redis-cli -a $REDIS_PASSWORD EXPIRE "job:12345" 86400
```

### Externo (se necessário)

Para acesso externo, você pode criar um Service do tipo LoadBalancer ou usar port-forward:

```bash
# Port forward temporário
kubectl port-forward -n redis svc/redis-service 6379:6379

# Conectar localmente
redis-cli -h localhost -p 6379 -a $REDIS_PASSWORD
```

## 📊 Monitoramento

### Health Checks

- **Liveness Probe**: TCP na porta 6379
- **Readiness Probe**: TCP na porta 6379
- **Initial Delay**: 15s (liveness), 5s (readiness)

### Métricas

O Redis expõe métricas básicas que podem ser coletadas por Prometheus:

```yaml
# Exemplo de configuração Prometheus
- job_name: 'redis'
  static_configs:
    - targets: ['redis-service.redis.svc.cluster.local:6379']
```

### Monitoramento de Estado

```bash
# Verificar número de jobs em processamento
kubectl exec -n redis deployment/redis -- redis-cli -a $REDIS_PASSWORD KEYS "job:*" | wc -l

# Verificar jobs por status
kubectl exec -n redis deployment/redis -- redis-cli -a $REDIS_PASSWORD KEYS "job:*processing*"
kubectl exec -n redis deployment/redis -- redis-cli -a $REDIS_PASSWORD KEYS "job:*completed*"

# Verificar uso de memória
kubectl exec -n redis deployment/redis -- redis-cli -a $REDIS_PASSWORD INFO memory
```

## 🔒 Segurança

### Secrets

A senha do Redis é armazenada como Kubernetes Secret:

```bash
# Ver secret
kubectl get secret redis-secret -n redis

# Decodificar senha
kubectl get secret redis-secret -n redis -o jsonpath='{.data.redis-password}' | base64 -d
```

### Network Policies

Recomenda-se configurar Network Policies para restringir acesso:

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: redis-network-policy
  namespace: redis
spec:
  podSelector:
    matchLabels:
      app: redis
  policyTypes:
  - Ingress
  ingress:
  - from:
    - namespaceSelector:
        matchLabels:
          name: app
    ports:
    - protocol: TCP
      port: 6379
```

## 🗂️ Persistência

### Storage Class

O Redis usa a storage class `fiap-hack-gp2` (EBS GP2) para persistência dos dados de estado.

### Backup

Para backup dos dados de estado, considere:

1. **Snapshot EBS**: Backup automático do volume
2. **Redis RDB**: Configurar save points para recuperação
3. **Redis AOF**: Append-only file para durabilidade dos dados

### Limpeza Automática

```bash
# Configurar TTL padrão para jobs (24 horas)
kubectl exec -n redis deployment/redis -- redis-cli -a $REDIS_PASSWORD CONFIG SET maxmemory-policy "volatile-ttl"

# Limpar jobs antigos manualmente
kubectl exec -n redis deployment/redis -- redis-cli -a $REDIS_PASSWORD KEYS "job:*" | xargs -I {} kubectl exec -n redis deployment/redis -- redis-cli -a $REDIS_PASSWORD DEL {}
```

## 🔄 Atualizações

### Rolling Update

O deployment usa estratégia `Recreate` para atualizações:

```bash
# Atualizar imagem
kubectl set image deployment/redis redis=redis:7.2-alpine -n redis

# Verificar rollout
kubectl rollout status deployment/redis -n redis
```

### Terraform

```bash
# Atualizar configuração
cd terraform && terraform plan
cd terraform && terraform apply
```

## 🚨 Troubleshooting

### Problemas Comuns

1. **Pod não inicia**
   ```bash
   kubectl describe pod -n redis
   kubectl logs -n redis deployment/redis
   ```

2. **Volume não monta**
   ```bash
   kubectl describe pvc -n redis
   kubectl get pv
   ```

3. **Conectividade falha**
   ```bash
   kubectl exec -n redis deployment/redis -- redis-cli ping
   kubectl get svc -n redis
   ```

### Logs

```bash
# Logs do Redis
kubectl logs -n redis deployment/redis

# Logs com follow
kubectl logs -f -n redis deployment/redis

# Logs de um pod específico
kubectl logs -n redis <pod-name>
```

## 📝 Notas Importantes

- O Redis é configurado com `appendonly yes` para durabilidade dos dados de estado
- A política de memória é `allkeys-lru` (Least Recently Used) para otimizar performance
- O deployment usa `Recreate` strategy para evitar problemas de compatibilidade
- A senha é obrigatória e deve ser fornecida via variável ou secret
- **Padrão de Chaves**: Use `job:{id}` para armazenar estados de processamento
- **TTL Recomendado**: Configure TTL de 24 horas para limpeza automática
- **Performance**: Consultas de estado são otimizadas para alta velocidade

### Vantagens do Redis para Estado

- **Velocidade**: Consultas em milissegundos
- **Persistência**: Dados sobrevivem a reinicializações
- **TTL**: Limpeza automática de dados antigos
- **Escalabilidade**: Suporta milhares de consultas simultâneas 