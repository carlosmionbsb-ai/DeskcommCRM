# Rodar o DeskcommCRM no Mac

Este guia instala o CRM inteiro no seu Mac (Intel ou Apple Silicon). O banco, as
conversas e o WhatsApp ficam na sua máquina.

## Antes de começar

- macOS 13 ou mais novo, com pelo menos 16 GB de RAM e 30 GB livres.
- Internet para baixar os programas na primeira vez.
- O celular com o WhatsApp Business do consultório, para ler o QR code.

## Instalar

Abra o app **Terminal** e rode:

```bash
git clone https://github.com/carlosmionbsb-ai/DeskcommCRM.git
cd DeskcommCRM
bash macos-local-installer.sh
```

O instalador:

1. Confere o Homebrew (se faltar, ele mostra o comando para instalar e para).
2. Instala e abre o **Docker Desktop**, se ainda não tiver.
3. Instala o Node.js 22 e o pnpm.
4. Sobe o banco local (Supabase), aplica o schema e gera senhas aleatórias no `.env.local`.
5. Constrói e sobe o app, o worker, o agendador de lembretes, o WhatsApp (WAHA) e o Redis.
6. Cria o seu usuário e mostra a senha no fim. **Anote.**

O primeiro build leva de 10 a 20 minutos. Depois, ligar e desligar é rápido.

Abra o endereço mostrado no fim (normalmente <http://localhost:3000>), entre e,
no onboarding, leia o QR code com o WhatsApp Business.

## Dia a dia

| Para | Comando (dentro da pasta DeskcommCRM) |
|---|---|
| Ligar | `./scripts/local-stack.sh up` |
| Ver se está tudo de pé | `./scripts/local-stack.sh status` |
| Ver o que o app está fazendo | `./scripts/local-stack.sh logs app` |
| Desligar | `./scripts/local-stack.sh down` |

## Para os lembretes saírem na hora

Os lembretes de consulta são enviados pelo agendador que roda no Mac. Se o Mac
dormir ou o Docker fechar, eles atrasam até o Mac voltar.

- Docker Desktop › Settings › General › marque **Start Docker Desktop when you sign in**.
- Ajustes do Sistema › Bateria (ou Energia) › impeça o Mac de dormir com a tela desligada.
- Depois de reiniciar o Mac, rode `./scripts/local-stack.sh up`.

## Segurança

Conversas com pacientes são **dado sensível** pela LGPD. O instalador já deixa o
CRM e o painel do WhatsApp atendendo só este Mac (`127.0.0.1`). Complete com:

- **Firewall:** Ajustes do Sistema › Rede › Firewall › Opções › marque
  *Bloquear todas as conexões de entrada*. Isso fecha as portas do banco local
  para o Wi-Fi do consultório.
- **FileVault:** Ajustes do Sistema › Privacidade e Segurança › FileVault, ligado.
- **Senha forte no Mac** e bloqueio de tela automático.
- **IA:** se você ligar o agente de IA, o texto das conversas vai para o provedor
  escolhido (Anthropic, OpenAI, OpenRouter). Dá para usar a agenda e os lembretes
  sem ligar a IA.
- **WhatsApp por QR code** (WAHA) não é a API oficial da Meta e tem risco de
  bloqueio do número. O CRM limita a velocidade de envio para reduzir isso. Se
  preferir o canal oficial, ele também é suportado (Conexões › canal oficial).

## Se algo der errado

- *"O Docker não respondeu"*: abra o Docker Desktop, espere o ícone ficar verde, rode de novo.
- *Build morre por memória*: Docker Desktop › Settings › Resources, suba para 6 GB ou mais.
- Rodar o instalador de novo não apaga seus dados. Ele gera uma senha nova para o
  usuário admin e mostra no fim.
