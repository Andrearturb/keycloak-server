# keycloak-server

Identity Provider central baseado em [Keycloak 26](https://www.keycloak.org/).
Gerencia autenticação para todas as aplicações do ecossistema (Enxoval Inteligente e futuras).

## Estrutura

```
keycloak-server/
├── Dockerfile            # Imagem otimizada (kc.sh build em build time)
├── docker-compose.yml    # Keycloak + PostgreSQL dedicado
├── .env.example          # Variáveis de ambiente (copie para .env)
└── realms/
    └── realm-enxoval.json   # Realm da aplicação Enxoval Inteligente
```

## Subir localmente

```bash
# 1. Copiar e preencher variáveis
cp .env.example .env

# 2. Build da imagem otimizada + inicialização
docker compose up -d --build

# 3. Aguardar o healthcheck ficar healthy (~60s no primeiro boot)
docker compose ps
```

**Admin Console:** http://localhost:8080/admin  
**Account Console:** http://localhost:8080/realms/enxoval/account  

No desenvolvimento local, mantenha `KC_HOSTNAME=http://localhost:8080` no `.env`.
Se trocar `KC_PORT`, atualize também a porta nessa URL. O hostname público fixo
mantém o issuer consistente para navegador e API em Docker
([documentação de hostname](https://www.keycloak.org/server/hostname)).
Não use `host.docker.internal` como hostname público; esse endereço serve para
a aplicação alcançar o servidor a partir dos containers.

Para integrar o webapp local, mantenha `APP_ENXOVAL_URL=http://localhost:5180` e
configure no `.env` do webapp `KEYCLOAK_HABILITADO=true`,
`KEYCLOAK_URL=http://host.docker.internal:8080`,
`KEYCLOAK_PUBLIC_URL=http://localhost:8080` e
`KEYCLOAK_ISSUER=http://localhost:8080/realms/enxoval`.
Recrie os containers API/frontend após alterar as variáveis.

As credenciais administrativas ficam no `.env` local. Para usar o aplicativo,
crie uma conta de família em **Cadastre-se** na tela de login; o administrador
do realm `master` não é uma conta de família do realm `enxoval`.

O client `webapp` inclui o scope padrão `basic`, necessário para o identificador
`sub` no access token. Se você já importou uma versão anterior deste realm,
adicione `basic` em **Clients → webapp → Client scopes** como **Default**.

O tema de login `enxoval` acompanha as cores, marca e fontes do aplicativo.
Após mudar o tema, reconstrua a imagem com `docker compose up -d --build`.
Para realms já existentes, selecione **Realm settings → Themes → Login theme → enxoval**.
O tema herda os formulários do Keycloak e personaliza sua apresentação com CSS.

## Confirmação de e-mail

O realm exige e-mail verificado antes de concluir o login. Configure `SMTP_*` no
`.env` antes de liberar cadastro. Para desenvolvimento, use:

```env
COMPOSE_PROFILES=email-local
MAILPIT_PORT=8026
SMTP_HOST=mailpit
SMTP_PORT=1025
SMTP_FROM=nao-responda@enxoval.local
SMTP_FROM_NAME=Enxoval Inteligente
SMTP_AUTH=false
SMTP_USER=
SMTP_PASSWORD=
SMTP_STARTTLS=false
SMTP_SSL=false
```

Suba com `docker compose up -d --build`. Acesse http://localhost:8026 para ler
as mensagens e abrir o link de confirmação. Mailpit captura e-mails localmente;
não os entrega à internet. Em produção, desative o perfil `email-local` e use
um SMTP de entrega com remetente autorizado, autenticação e TLS conforme o
provedor. Não publique a caixa de testes.

Para um realm já existente, execute no PowerShell:

```powershell
.\scripts\configurar-email.ps1
```

O script aplica somente `verifyEmail` e SMTP ao realm `enxoval`, lendo credenciais
do `.env` sem exibi-las. Não reimporta nem apaga usuários. Alternativamente,
configure **Realm settings → Email** e habilite **Login → Verify email** no console.
Usuários existentes sem confirmação precisarão verificar o endereço no próximo
login. Não marque seus e-mails como verificados manualmente para liberar acesso.

O tema `enxoval` consulta a sessão pendente a cada cinco segundos por até quinze
minutos. Depois da confirmação, a aba original continua o login automaticamente,
inclusive quando o link foi aberto em outro navegador (por exemplo, no VS Code).
As consultas não reenviam e-mails e não seguem o callback OAuth em segundo plano.
O link **Já confirmei meu e-mail — continuar** permite retomar manualmente.
Se o link for aberto fora do navegador do cadastro, o Keycloak pode pedir um
clique adicional para confirmar e mostrar apenas a mensagem de sucesso; volte à
aba original para acessar a aplicação.

## Ativar login com Google

1. Crie credenciais OAuth em https://console.cloud.google.com  
2. URIs de redirecionamento autorizados:
   - Dev: `http://localhost:8080/realms/enxoval/broker/google/endpoint`
   - Produção: `https://auth.seu-dominio.com/realms/enxoval/broker/google/endpoint`
3. Preencha `.env`:
   ```
   GOOGLE_CLIENT_ID=seu-client-id.apps.googleusercontent.com
   GOOGLE_CLIENT_SECRET=seu-client-secret
   GOOGLE_IDP_HABILITADO=true
   ```
4. No primeiro boot, o import lê essas variáveis. Se o realm já existe, configure **Identity Providers → Google** no Admin Console (Client ID, Client Secret e Enable). O import não sobrescreve realms existentes.

## Adicionar nova aplicação

1. Crie `realms/realm-nova-app.json` (baseie-se no `realm-enxoval.json`)
2. Reinicie com `docker compose restart keycloak` — o realm será importado automaticamente

## Produção

Altere no `.env`:

```env
KC_HOSTNAME=auth.seu-dominio.com
KC_HOSTNAME_STRICT=true
KC_HTTP_ENABLED=true
KC_PROXY_HEADERS=xforwarded
APP_ENXOVAL_URL=https://app.seu-dominio.com
```

E coloque um reverse proxy (Caddy, Nginx ou Traefik) na frente para terminar o TLS.
O proxy deve sobrescrever os headers `X-Forwarded-*`; restrinja o acesso à porta interna do Keycloak ao proxy. O healthcheck usa a porta interna 9000, sem publicar essa porta no host.

## Por que imagem com build?

O Keycloak recomenda executar `kc.sh build` em tempo de build da imagem Docker,
não em cada startup. Isso reduz o tempo de inicialização e detecta erros de
configuração antes de chegar em produção.

Referência: https://www.keycloak.org/server/containers
