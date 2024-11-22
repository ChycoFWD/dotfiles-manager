#!/bin/bash

set -euo pipefail
IFS=$'\n\t'

# Variáveis padrão
readonly REPO_URL="https://github.com/chycifwd/dotfiles.git"
readonly DOTFILES_DIR="$HOME/dotfiles"
readonly BACKUP_DIR="$HOME/dotfiles_backup"
readonly REMOTE_BACKUP_DIR="/path/to/remote/backup"  # Ajuste conforme necessário
FILES_TO_BACKUP=()

# Função para exibir o manual de ajuda
show_help() {
    echo "==== Dotfiles Manager ===="
    echo "Gerencia seus arquivos de configuração e backups com opções de sincronização."
    echo ""
    echo "Uso:"
    echo "  -h, --help              Exibe esta mensagem de ajuda."
    echo "  -b, --backup-install    Backup e Instalar Dotfiles"
    echo "  -s, --store-backup      Armazenar Backup em Local Seguro"
    echo "  -x, --sync-dotfiles     Sincronizar Dotfiles"
    echo "  -q, --exit              Sair"
    echo ""
}

# Função para processar parâmetros passados pela linha de comando
parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)
                show_help
                exit 0
                ;;
            -b|--backup-install)
                ACTION="backup_install"
                ;;
            -s|--store-backup)
                ACTION="secure_backup"
                ;;
            -x|--sync-dotfiles)
                ACTION="sync_dotfiles"
                ;;
            -q|--exit)
                echo "Saindo..."
                exit 0
                ;;
            *)
                echo "Opção inválida: $1"
                show_help
                exit 1
                ;;
        esac
        shift
    done
}

# Função para verificar e carregar variáveis de ambiente do arquivo .env
load_env() {
    if [[ -f "$HOME/.env" ]]; then
        echo "🔍 Carregando configurações do arquivo .env..."
        source "$HOME/.env"
    fi
}

# Função para detectar os arquivos de configuração
detect_dotfiles() {
    echo "🔍 Detectando arquivos de configuração..."
    FILES_TO_BACKUP=($(find "$HOME" -maxdepth 1 -type f -name ".*" -printf "%f\n"))

    if [ ${#FILES_TO_BACKUP[@]} -eq 0 ]; then
        echo "❌ Nenhum arquivo de configuração encontrado."
        return 1
    fi

    echo "📋 Arquivos detectados:"
    for file in "${FILES_TO_BACKUP[@]}"; do
        echo "  - $file"
    done
    return 0
}

# Função para verificar e instalar rsync
install_rsync() {
    echo "🔍 Verificando a instalação do rsync..."

    # Verifica se o rsync já está instalado
    if ! command -v rsync &> /dev/null; then
        echo "❌ rsync não encontrado! Tentando instalar..."

        if [[ "$(uname)" == "Linux" ]]; then
            # Se for Linux, tenta instalar via gerenciador de pacotes primeiro
            if command -v apt &> /dev/null; then
                echo "📦 Instalando rsync no Ubuntu/Debian via apt..."
                sudo apt update && sudo apt install rsync -y
            elif command -v yum &> /dev/null; then
                echo "📦 Instalando rsync no RedHat/CentOS via yum..."
                sudo yum install rsync -y
            elif command -v snap &> /dev/null; then
                echo "📦 Instalando rsync no Linux via Snap..."
                sudo snap install rsync
            else
                # Se não encontrou nenhum gerenciador de pacotes compatível
                echo "❌ Nenhum gerenciador de pacotes compatível encontrado. Tentando instalar rsync via fonte..."
                install_rsync_from_source
            fi

        elif [[ "$(uname)" == "Darwin" ]]; then
            # Se for macOS, tenta instalar via Homebrew
            if ! command -v brew &> /dev/null; then
                echo "❌ Homebrew não encontrado! Instalando Homebrew..."

                # Instalar Homebrew no macOS
                /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

                # Após instalar o Homebrew, adicione-o ao PATH
                if [[ -x /opt/homebrew/bin/brew ]]; then
                    echo "export PATH=/opt/homebrew/bin:$PATH" >> "$HOME/.bash_profile"
                    source "$HOME/.bash_profile"
                elif [[ -x /usr/local/bin/brew ]]; then
                    echo "export PATH=/usr/local/bin:$PATH" >> "$HOME/.bash_profile"
                    source "$HOME/.bash_profile"
                fi
            fi

            echo "📦 Instalando rsync via Homebrew no macOS..."
            brew install rsync
        else
            echo "❌ Sistema operacional não suportado para a instalação automática do rsync!"
            exit 1
        fi
    else
        echo "✅ rsync já está instalado!"
    fi
}

# Função para instalar rsync a partir da fonte
install_rsync_from_source() {
    echo "🔧 Instalando rsync a partir da fonte..."

    # Instala dependências necessárias para compilação
    if command -v apt &> /dev/null; then
        sudo apt-get install build-essential -y
    elif command -v yum &> /dev/null; then
        sudo yum groupinstall "Development Tools" -y
    fi

    # Baixa e compila o rsync a partir da fonte
    git clone https://github.com/WayneD/rsync.git
    cd rsync
    ./autogen.sh
    ./configure
    make
    sudo make install
    cd ..
    echo "✅ rsync instalado a partir da fonte!"
}

# Função para fazer backup dos arquivos existentes
backup_files() {
    echo "🔄 Fazendo backup..."
    mkdir -p "$BACKUP_DIR"

    for file in "${FILES_TO_BACKUP[@]}"; do
        if [ -f "$HOME/$file" ]; then
            mv "$HOME/$file" "$BACKUP_DIR/"
            echo "📦 $file movido para $BACKUP_DIR"
        fi
    done

    echo "✅ Backup concluído!"
}

# Função para clonar e instalar os Dotfiles
install_dotfiles() {
    echo "📥 Clonando o repositório Dotfiles..."
    if [ -d "$DOTFILES_DIR" ]; then
        echo "🔄 Diretório existente. Atualizando o repositório..."
        cd "$DOTFILES_DIR" && git pull
    else
        git clone "$REPO_URL" "$DOTFILES_DIR"
    fi

    echo "🔧 Instalando os Dotfiles..."
    cd "$DOTFILES_DIR"
    if command -v make &> /dev/null; then
        make build
    else
        echo "❌ O comando 'make' não está instalado. Instale-o antes de continuar."
        exit 1
    fi
    echo "✅ Dotfiles instalados!"
}

# Função para armazenar o backup em local seguro
secure_backup() {
    echo "==== Escolha o método de armazenamento seguro ===="
    echo "1. Usar Git"
    echo "2. Usar Rsync"
    echo "3. Usar uma ferramenta customizada"
    read -rp "Escolha uma opção: " backup_method

    case "$backup_method" in
        1) 
            echo "🔄 Enviando backup para o repositório Git..."
            cd "$BACKUP_DIR"
            git init
            git remote add origin "$REPO_URL"
            git add . 
            git commit -m "Backup dos Dotfiles"
            git push -u origin main
            echo "✅ Backup enviado para o Git!"
            ;;
        2) 
            echo "🔄 Sincronizando backup com Rsync..."
            rsync -avh --delete "$BACKUP_DIR/" "$REMOTE_BACKUP_DIR/"
            echo "✅ Backup sincronizado com sucesso!"
            ;;
        3) 
            echo "❌ Nenhuma ferramenta customizada foi implementada ainda."
            ;;
        *) 
            echo "Opção inválida!"
            secure_backup
            ;;
    esac
}

# Função para sincronizar Dotfiles (download/upload)
sync_dotfiles() {
    echo "==== Escolha o tipo de sincronização ===="
    echo "1. Download (Sincronizar do backup para o sistema local)"
    echo "2. Upload (Enviar alterações locais para o backup)"
    read -rp "Escolha uma opção: " sync_choice

    case "$sync_choice" in
        1) 
            echo "🔄 Baixando backup com Rsync..."
            rsync -avh --delete "$REMOTE_BACKUP_DIR/" "$HOME/"
            echo "✅ Sincronização concluída (download)!"
            ;;
        2) 
            echo "🔄 Enviando alterações locais para o backup..."
            rsync -avh --delete "$HOME/" "$REMOTE_BACKUP_DIR/"
            echo "✅ Sincronização concluída (upload)!"
            ;;
        *) 
            echo "Opção inválida!"
            sync_dotfiles
            ;;
    esac
}

# Função para exibir o menu principal
main_menu() {
    echo "==== Dotfiles Manager ===="
    echo "A. Backup e Instalar Dotfiles"
    echo "B. Armazenar Backup em Local Seguro"
    echo "C. Sincronizar Dotfiles"
    echo "D. Sair"
    read -rp "Escolha uma opção: " choice

    case "$choice" in
        A) detect_dotfiles && backup_files && install_dotfiles ;;
        B) secure_backup ;;
        C) sync_dotfiles ;;
        D) echo "Saindo..."; exit 0 ;;
        *) echo "Opção inválida!"; main_menu ;;
    esac
}

# Função principal de execução com base em parâmetros
run() {
    load_env
    parse_args "$@"

    # Se uma ação foi definida, executa diretamente
    if [[ -n "${ACTION:-}" ]]; then
        case "$ACTION" in
            "backup_install")
                detect_dotfiles && backup_files && install_dotfiles
                ;;
            "secure_backup")
                secure_backup
                ;;
            "sync_dotfiles")
                sync_dotfiles
                ;;
            *)
                echo "Ação não reconhecida!"
                show_help
                exit 1
                ;;
        esac
    else
        # Se não foi passada nenhuma ação via argumento ou .env, mostra o menu interativo
        main_menu
    fi
}

# Início do script
run "$@"