#!/bin/bash
# ============================================================================
# restore.sh - Instalação completa do ambiente XFCE (Aspire Dev)
#
# Instala todos os pacotes necessários e aplica as configurações.
# Basta rodar e fornecer a senha sudo quando pedido.
#
# Uso: ./restore.sh
# ============================================================================

set -e

DOTFILES="$(cd "$(dirname "$0")" && pwd)"

# Cores para output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

info()  { echo -e "${GREEN}[✓]${NC} $1"; }
warn()  { echo -e "${YELLOW}[!]${NC} $1"; }
error() { echo -e "${RED}[✗]${NC} $1"; }
step()  { echo -e "\n${GREEN}==>${NC} $1"; }

# ============================================================================
# 1. REPOSITÓRIOS ADICIONAIS
# ============================================================================
step "Adicionando repositórios necessários..."

# PPA do Plank (se não estiver disponível no repo padrão)
if ! apt-cache show plank &>/dev/null; then
    warn "Adicionando PPA do Plank..."
    sudo add-apt-repository -y ppa:ricotz/docky
fi

# PPA do Papirus (ícones)
if ! apt-cache show papirus-icon-theme &>/dev/null; then
    warn "Adicionando PPA do Papirus..."
    sudo add-apt-repository -y ppa:papirus/papirus
fi

sudo apt update

# ============================================================================
# 2. INSTALAÇÃO DE PACOTES
# ============================================================================
step "Instalando pacotes..."

PACKAGES=(
    # XFCE core
    xfce4
    xfce4-goodies
    xfce4-terminal
    thunar
    xfce4-power-manager
    xfce4-notifyd
    xfce4-taskmanager

    # Compositor (cantos arredondados)
    picom

    # Dock
    plank

    # Display manager
    lightdm
    lightdm-gtk-greeter

    # Temas e ícones
    mint-themes
    papirus-icon-theme

    # Fontes
    fonts-ubuntu

    # Utilitários (usados pelo plank-padding)
    wmctrl
    xdotool
    x11-utils

    # Python + GTK bindings (plank-padding.py)
    python3
    gir1.2-gtk-3.0

    # Rede (applet no systray)
    network-manager-gnome
)

sudo apt install -y "${PACKAGES[@]}"
info "Pacotes instalados"

# ============================================================================
# 3. TEMA macOS PARA O PLANK
# ============================================================================
step "Instalando tema macOS do Plank..."

PLANK_THEMES_DIR="$HOME/.local/share/plank/themes/macOS"
if [ ! -d "$PLANK_THEMES_DIR" ]; then
    mkdir -p "$HOME/.local/share/plank/themes"
    # Baixa o tema mcOS do GitHub
    TEMP_DIR=$(mktemp -d)
    git clone --depth 1 https://github.com/nicnomo/plank-theme-starter.git "$TEMP_DIR/plank-macos" 2>/dev/null || true

    # Se o clone falhar, usa um tema mínimo que funciona
    if [ ! -d "$TEMP_DIR/plank-macos" ] || [ -z "$(ls -A "$TEMP_DIR/plank-macos" 2>/dev/null)" ]; then
        warn "Clone falhou, criando tema macOS básico..."
        mkdir -p "$PLANK_THEMES_DIR"
        cat > "$PLANK_THEMES_DIR/dock.theme" << 'EOF'
[PlankTheme]
#The roundness of the top corners.
TopRoundness=8
#The roundness of the bottom corners.
BottomRoundness=8
#The thickness (in pixels) of lines drawn.
LineWidth=0
#The color (RGBA) of the outer stroke.
OuterStrokeColor=0;;0;;0;;0
#The starting color (RGBA) of the inner stroke gradient.
InnerStrokeColor=255;;255;;255;;51
#The color (RGBA) of the dock background.
FillStartColor=45;;45;;48;;200
#The ending color (RGBA) of the dock background gradient.
FillEndColor=45;;45;;48;;200
#The height of the horizontal padding (in percent of IconSize).
HorizPadding=0.5
#The height of the top padding (in percent of IconSize).
TopPadding=0.2
#The height of the bottom padding (in percent of IconSize).
BottomPadding=0.2
#The height of each item's padding (in percent of IconSize).
ItemPadding=0.15
#The size of indicator icons (in percent of IconSize).
IndicatorSize=0.08
#The size of the icon shadow (in percent of IconSize).
IconShadowSize=0.1
#The size of the urgent glow (in percent of IconSize).
UrgentBounceHeight=0.6
#The icon bounce height during launch animation (in percent of IconSize).
LaunchBounceHeight=0.5
#The opacity of the fade for the urgent glow animation.
FadeOpacity=100
#Whether the click animation is enabled.
ClickTime=300
#The time for the urgent glow animation (in ms).
UrgentHueShift=150
#Whether item count badges are enabled.
ItemMoveTime=450
#The delay before hiding the dock (in ms).
CascadeHide=true
EOF
    else
        # Procura pelo tema macOS no repositório clonado
        find "$TEMP_DIR/plank-macos" -name "dock.theme" -exec dirname {} \; | head -1 | while read dir; do
            cp -r "$dir" "$PLANK_THEMES_DIR"
        done
        # Se não encontrou, copia o que tiver
        if [ ! -f "$PLANK_THEMES_DIR/dock.theme" ]; then
            cp -r "$TEMP_DIR/plank-macos" "$PLANK_THEMES_DIR" 2>/dev/null || true
        fi
    fi
    rm -rf "$TEMP_DIR"
    info "Tema macOS do Plank instalado"
else
    info "Tema macOS do Plank já existe"
fi

# ============================================================================
# 4. CONFIGURAÇÕES DO XFCE
# ============================================================================
step "Aplicando configurações do XFCE..."

# Garante que os diretórios existem
mkdir -p ~/.config/xfce4

# Copia configurações do XFCE (xfconf, panel, desktop, xfwm4)
cp -r "$DOTFILES/xfce4/"* ~/.config/xfce4/
info "XFCE configs aplicadas"

# ============================================================================
# 5. PICOM (compositor)
# ============================================================================
step "Aplicando configuração do Picom..."

mkdir -p ~/.config/picom
cp "$DOTFILES/picom/picom.conf" ~/.config/picom/
info "Picom configurado"

# ============================================================================
# 6. PLANK (dock)
# ============================================================================
step "Aplicando configuração do Plank..."

mkdir -p ~/.config/plank/dock1/launchers
cp -r "$DOTFILES/plank/"* ~/.config/plank/
info "Plank configurado"

# ============================================================================
# 7. PLANK PADDING SCRIPTS
# ============================================================================
step "Instalando scripts de padding do Plank..."

mkdir -p ~/.local/bin
cp "$DOTFILES/local-bin/plank-padding.sh" ~/.local/bin/
cp "$DOTFILES/local-bin/plank-padding.py" ~/.local/bin/
chmod +x ~/.local/bin/plank-padding.sh ~/.local/bin/plank-padding.py
info "Scripts instalados em ~/.local/bin"

# Garante que ~/.local/bin está no PATH
if ! echo "$PATH" | grep -q "$HOME/.local/bin"; then
    if [ -f ~/.bashrc ]; then
        if ! grep -q 'local/bin' ~/.bashrc; then
            echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc
            info "~/.local/bin adicionado ao PATH no .bashrc"
        fi
    fi
fi

# ============================================================================
# 8. AUTOSTART
# ============================================================================
step "Configurando autostart..."

mkdir -p ~/.config/autostart
cp "$DOTFILES/autostart/"* ~/.config/autostart/

# Corrige o path do autostart para o usuário atual
CURRENT_USER=$(whoami)
sed -i "s|/home/[^/]*/|/home/$CURRENT_USER/|g" ~/.config/autostart/plank-padding.desktop
info "Autostart configurado"

# ============================================================================
# 9. TEMA GTK
# ============================================================================
step "Aplicando tema GTK..."

mkdir -p ~/.config/gtk-3.0
cp -r "$DOTFILES/gtk-3.0/"* ~/.config/gtk-3.0/
cp "$DOTFILES/.gtkrc-2.0" ~/
info "Tema GTK aplicado (Mint-Y-Dark-Aqua + ePapirus-Dark)"

# ============================================================================
# 10. ÍCONES E TEMAS CUSTOMIZADOS (se existirem no backup)
# ============================================================================
if [ -d "$DOTFILES/.icons" ]; then
    step "Copiando ícones customizados..."
    cp -r "$DOTFILES/.icons" ~/
    info "Ícones customizados copiados"
fi

if [ -d "$DOTFILES/.themes" ]; then
    step "Copiando temas customizados..."
    cp -r "$DOTFILES/.themes" ~/
    info "Temas customizados copiados"
fi

# ============================================================================
# 11. WALLPAPERS (se existirem no backup)
# ============================================================================
if [ -d "$DOTFILES/backgrounds" ]; then
    step "Copiando wallpapers..."
    mkdir -p ~/.local/share
    cp -r "$DOTFILES/backgrounds" ~/.local/share/
    info "Wallpapers copiados"
fi

# ============================================================================
# 12. LIGHTDM (tela de login)
# ============================================================================
step "Configurando LightDM..."

if [ -f "$DOTFILES/lightdm.conf" ]; then
    sudo cp "$DOTFILES/lightdm.conf" /etc/lightdm/
    info "lightdm.conf aplicado"
fi

if [ -f "$DOTFILES/lightdm-gtk-greeter.conf" ]; then
    sudo cp "$DOTFILES/lightdm-gtk-greeter.conf" /etc/lightdm/
    info "lightdm-gtk-greeter.conf aplicado"
fi

# Habilita o LightDM como display manager padrão
sudo systemctl enable lightdm 2>/dev/null || true

# ============================================================================
# 13. VERIFICAÇÃO FINAL
# ============================================================================
step "Verificação final..."

echo ""
MISSING=""
for pkg in xfce4 picom plank lightdm wmctrl xdotool; do
    if command -v "$pkg" &>/dev/null || dpkg -l "$pkg" &>/dev/null 2>&1; then
        info "$pkg instalado"
    else
        error "$pkg NÃO encontrado"
        MISSING="$MISSING $pkg"
    fi
done

echo ""
echo "============================================"
if [ -z "$MISSING" ]; then
    info "Tudo instalado e configurado com sucesso!"
else
    warn "Pacotes com problema:$MISSING"
    warn "Tente: sudo apt install$MISSING"
fi
echo ""
echo "  Tema GTK:    Mint-Y-Dark-Aqua"
echo "  Ícones:      ePapirus-Dark"
echo "  WM tema:     Mint-Y-Dark-Aqua"
echo "  Dock:        Plank (tema macOS)"
echo "  Compositor:  Picom (cantos arredondados)"
echo ""
warn "Faça logout/login para aplicar todas as mudanças."
echo "============================================"
