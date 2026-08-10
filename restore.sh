#!/bin/bash
# Restaurar configurações XFCE, Picom, Plank e afins
DOTFILES="$(cd "$(dirname "$0")" && pwd)"

echo "Restaurando configurações..."

# XFCE
cp -r "$DOTFILES/xfce4" ~/.config/ 2>/dev/null

# Picom
cp "$DOTFILES/picom.conf" ~/.config/ 2>/dev/null
cp -r "$DOTFILES/picom" ~/.config/ 2>/dev/null

# Plank
cp -r "$DOTFILES/plank" ~/.config/ 2>/dev/null

# Plank padding scripts
mkdir -p ~/.local/bin
cp "$DOTFILES/local-bin/plank-padding.sh" ~/.local/bin/ 2>/dev/null
cp "$DOTFILES/local-bin/plank-padding.py" ~/.local/bin/ 2>/dev/null
chmod +x ~/.local/bin/plank-padding.sh ~/.local/bin/plank-padding.py

# Autostart
mkdir -p ~/.config/autostart
cp -r "$DOTFILES/autostart/"* ~/.config/autostart/ 2>/dev/null

# LightDM (tela de login)
sudo cp "$DOTFILES/lightdm.conf" /etc/lightdm/ 2>/dev/null
sudo cp "$DOTFILES/lightdm-gtk-greeter.conf" /etc/lightdm/ 2>/dev/null

# Tema GTK
cp -r "$DOTFILES/gtk-3.0" ~/.config/ 2>/dev/null
cp "$DOTFILES/.gtkrc-2.0" ~/ 2>/dev/null

# Ícones e temas customizados
cp -r "$DOTFILES/.icons" ~/ 2>/dev/null
cp -r "$DOTFILES/.themes" ~/ 2>/dev/null

# Wallpapers
mkdir -p ~/.local/share
cp -r "$DOTFILES/backgrounds" ~/.local/share/ 2>/dev/null

echo "Configurações restauradas! Faça logout/login para aplicar."
