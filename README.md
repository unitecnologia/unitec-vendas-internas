# Unitec Vendas Internas

App Flutter para vendas na loja (Wi‑Fi). Envia **orçamentos abertos** ao ERP; o **PDV** importa e finaliza a venda.

## Conectar ao servidor

| Ambiente | Porta | Exemplo no app |
|----------|-------|----------------|
| **Produção / loja** (instalador Unitec) | **8765** | `192.168.0.10:8765` |
| **Desenvolvimento** (`dev-windows.ps1`) | **8000** | `192.168.0.10:8000` |

- Se digitar só o IP (ex.: `192.168.0.10`), o app tenta **8765** e depois **8000**.
- **Buscar na rede** varre a Wi‑Fi nas duas portas e chama `/api/v1/vendas-internas/ping`.
- PC e celular na **mesma rede**; desative **modo avião**.
- No Windows, libere a porta no firewall (produção: 8765; dev: 8000).

## Fluxo

1. Conectar ao servidor ERP na rede local
2. Administrador autoriza o aparelho em **Vendas Internas → Aparelhos**
3. Vendedor faz login (mesma senha do app Força de Vendas)
4. **Nova Venda** → orçamento aberto no ERP (DAV)
5. Caixa importa no PDV → pagamento → número do pedido (`vendas.numero`) volta ao app

## API

Base: `/api/v1/vendas-internas/`  
Header do aparelho: `X-VI-Device`

## Desenvolvimento

```bash
cd apps/vendas-internas
flutter pub get
flutter run
```

Build Android segue o mesmo padrão do app Força de Vendas (`codemagic.yaml`).

## CI (Codemagic)

1. Conecte o repositório `unitecnologia/unitec-vendas-internas` no [Codemagic](https://codemagic.io).
2. Use o workflow `vendas-internas-android` definido em `codemagic.yaml`.
3. Configure o grupo **`keystore_credentials`** (opcional; o repo já inclui `ci/unitecfv-release.p12`, mesma chave do FV).
4. Troque o e-mail em `codemagic.yaml` → `publishing.email.recipients`.
