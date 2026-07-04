# Unitec Vendas Internas

App Flutter para vendas na loja (Wi‑Fi). Envia **orçamentos abertos** ao ERP; o **PDV** importa e finaliza a venda.

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
