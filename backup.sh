#!/bin/bash
# Backup das configurações XFCE, Picom, Plank e afins
DOTFILES="$(cd "$(dirname "$0")" && pwd)"

echo "Fazendo backup das configurações..."

# XFCE
cp -r ~/.config/xfce4 "$DOTFILES/" 2>/dev/null

# Picom
cp ~/.config/picom.conf "$DOTFILES/" 2>/dev/null
cp -r ~/.config/picom "$DOTFILES/" 2>/dev/null

# Plank
cp -r ~/.config/plank "$DOTFILES/" 2>/dev/null

# Plank padding scripts
mkdir -p "$DOTFILES/local-bin"
cp ~/.local/bin/plank-padding.sh "$DOTFILES/local-bin/" 2>/dev/null
cp ~/.local/bin/plank-padding.py "$DOTFILES/local-bin/" 2>/dev/null

# Autostart
cp -r ~/.config/autostart "$DOTFILES/" 2>/dev/null

# LightDM (tela de login)
sudo cp /etc/lightdm/lightdm.conf "$DOTFILES/" 2>/dev/null
sudo cp /etc/lightdm/lightdm-gtk-greeter.conf "$DOTFILES/" 2>/dev/null

# Tema GTK
cp -r ~/.config/gtk-3.0 "$DOTFILES/" 2>/dev/null
cp ~/.gtkrc-2.0 "$DOTFILES/" 2>/dev/null

# Ícones e temas customizados
cp -r ~/.icons "$DOTFILES/" 2>/dev/null
cp -r ~/.themes "$DOTFILES/" 2>/dev/null

# Wallpapers
cp -r ~/.local/share/backgrounds "$DOTFILES/" 2>/dev/null

echo "Backup concluído em: $DOTFILES"
