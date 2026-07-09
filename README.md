# 💰 Receitas Marketing

Aplicativo de controle financeiro desenvolvido para ajudar empresas a gerenciar seus custos fixos e receitas monetárias de forma simples, ágil e organizada — com foco especial em times e áreas de marketing.

---

## ✨ Funcionalidades

- 📸 **Registro de notas:** anexe comprovantes e notas fiscais diretamente por foto.
- 💰 **Cadastro manual:** adicione valores, entradas e saídas com facilidade.
- 📊 **Visualização de dados:** acompanhe o histórico de todos os seus lançamentos.
- 📤 **Compartilhamento:** exporte informações e envie comprovantes rapidamente.
- 📄 **Exportação em PDF:** gere relatórios das transações por período.
- 📋 **Exportação para Excel:** copie os lançamentos com um toque e cole direto em uma planilha (Ctrl+C / Ctrl+V), sem precisar gerar ou importar arquivos.

## ☁️ Backup automático

Os dados são sincronizados automaticamente com o **Google Drive** do usuário, garantindo que as informações fiquem protegidas contra perda de aparelho ou reinstalação do app — sem necessidade de backup manual.

## 🛠️ Tecnologias

- [Flutter](https://flutter.dev/) — framework multiplataforma
- [Riverpod](https://riverpod.dev/) — gerenciamento de estado
- SQLite (via `sqflite`) — armazenamento local
- Suporte a Android e Windows Desktop

---

## 📥 Instalação

As instruções de instalação (Android e Windows) ficam diretamente na página de cada versão publicada:

**🔗 [Releases](https://github.com/AndradyLab/Receitas_MKT/releases)**

---

## 🏗️ Build do projeto

### Pré-requisitos

- [Flutter SDK](https://docs.flutter.dev/get-started/install) instalado e configurado
- `flutter doctor` sem pendências para as plataformas desejadas

```bash
git clone https://github.com/AndradyLab/Receitas_MKT.git
cd Receitas_MKT
flutter pub get
```

### 📱 Build para Android

Gerar um APK de release:

```bash
flutter build apk --release
```

O arquivo gerado fica em:

```
build\app\outputs\flutter-apk\app-release.apk
```

> Prefere um pacote otimizado por dispositivo (menor tamanho) para publicar na Play Store? Use `flutter build appbundle --release` em vez do comando acima.

### 💻 Build para Windows

Certifique-se de ter o suporte a desktop habilitado:

```bash
flutter config --enable-windows-desktop
```

Gerar o build de release:

```bash
flutter build windows --release
```

O executável e as dependências ficam em:

```
build\windows\x64\runner\Release\
```

Para gerar o instalador `.msix` assinado (usado nas releases distribuídas), o projeto já está configurado no `pubspec.yaml` com `msix_config`. Após o build acima, rode:

```bash
flutter pub run msix:create --certificate-password=SUA_SENHA_AQUI
```

> O certificado (`.pfx`) não é versionado no repositório por questões de segurança. Fale com o mantenedor do projeto caso precise gerar um novo pacote assinado.

---

## 📬 Suporte

Ficou com alguma dúvida ou encontrou um problema? Entre em contato:

- ✉️ Email: viniciusandradeprog@gmail.com
- 💬 WhatsApp: (85) 99278-4784

---

## 📝 Sobre este projeto

Este projeto foca em cobrir o fluxo essencial de controle financeiro manual para uma equipe de marketing.
