# ---------------------------------------------------------------------------
# Imagem otimizada do Keycloak — abordagem recomendada pela documentação oficial.
#
# Por que build em dois estágios?
# O Keycloak recomenda rodar "kc.sh build" em tempo de build da imagem Docker,
# não em tempo de startup. Isso:
#   1. Reduz o tempo de inicialização do container
#   2. Detecta erros de configuração em build time, não em produção
#   3. Segue a prática oficial: https://www.keycloak.org/server/containers
#
# Estágio 1 (builder): executa "kc.sh build" com as opções de produção
# Estágio 2 (runtime): copia o resultado otimizado e define o entrypoint
# ---------------------------------------------------------------------------

FROM quay.io/keycloak/keycloak:26.2.5 AS builder

# Configura as opções de build (banco, features, etc.)
# Estas opções são "compiled in" e não podem ser alteradas em runtime sem rebuild.
ENV KC_DB=postgres
ENV KC_HEALTH_ENABLED=true
ENV KC_METRICS_ENABLED=true

# Executa o build de otimização do Keycloak
RUN /opt/keycloak/bin/kc.sh build

# ---------------------------------------------------------------------------
# Imagem final de runtime
# ---------------------------------------------------------------------------
FROM quay.io/keycloak/keycloak:26.2.5

# Copia o resultado otimizado do builder
COPY --from=builder /opt/keycloak/ /opt/keycloak/

# Copia os realms para importação automática na primeira inicialização
COPY realms/ /opt/keycloak/data/import/
COPY themes/ /opt/keycloak/themes/

ENTRYPOINT ["/opt/keycloak/bin/kc.sh"]
