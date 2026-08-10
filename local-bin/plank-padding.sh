#!/bin/bash
# plank-padding.sh - Adiciona padding entre o Plank e a borda inferior da tela
# Funciona dinamicamente com múltiplos monitores

PADDING=3  # pixels de gap entre o plank e a borda da tela

apply_padding() {
    # Pega o ID da janela do Plank
    PLANK_ID=$(wmctrl -l | grep -i "plank" | awk '{print $1}')
    
    if [ -z "$PLANK_ID" ]; then
        echo "Plank não encontrado, aguardando..."
        return 1
    fi

    # Pega a geometria atual da janela do Plank
    GEOM=$(xwininfo -id "$PLANK_ID" 2>/dev/null)
    PLANK_W=$(echo "$GEOM" | grep "Width:" | awk '{print $2}')
    PLANK_H=$(echo "$GEOM" | grep "Height:" | awk '{print $2}')
    PLANK_X=$(echo "$GEOM" | grep "Absolute upper-left X:" | awk '{print $NF}')

    # Detecta o monitor onde o Plank está (baseado no X)
    # Pega a altura do monitor correspondente
    SCREEN_H=$(xrandr --query | grep " connected" | while read line; do
        # Extrai geometria: WxH+X+Y
        GEOM_STR=$(echo "$line" | grep -oP '\d+x\d+\+\d+\+\d+')
        if [ -n "$GEOM_STR" ]; then
            MON_W=$(echo "$GEOM_STR" | cut -d'x' -f1)
            MON_H=$(echo "$GEOM_STR" | cut -d'x' -f2 | cut -d'+' -f1)
            MON_X=$(echo "$GEOM_STR" | cut -d'+' -f2)
            MON_Y=$(echo "$GEOM_STR" | cut -d'+' -f3)
            
            # Verifica se o Plank está neste monitor
            MON_END_X=$((MON_X + MON_W))
            if [ "$PLANK_X" -ge "$MON_X" ] && [ "$PLANK_X" -lt "$MON_END_X" ]; then
                echo "$MON_H"
                break
            fi
        fi
    done)

    if [ -z "$SCREEN_H" ]; then
        # Fallback: usa a primeira tela conectada
        SCREEN_H=$(xrandr --query | grep " connected" | grep -oP '\d+x\d+' | head -1 | cut -d'x' -f2)
    fi

    # Calcula nova posição Y (tela_altura - altura_plank - padding)
    NEW_Y=$((SCREEN_H - PLANK_H - PADDING))

    echo "Monitor H=$SCREEN_H | Plank: ${PLANK_W}x${PLANK_H} @ X=$PLANK_X | Nova posição Y=$NEW_Y (padding=${PADDING}px)"

    # Move o Plank para a nova posição
    wmctrl -i -r "$PLANK_ID" -e "0,$PLANK_X,$NEW_Y,$PLANK_W,$PLANK_H"

    # Atualiza o strut para incluir o padding
    NEW_STRUT=$((PLANK_H + PADDING))
    
    # Calcula o strut_partial correto
    # bottom_strut, bottom_start_x, bottom_end_x
    STRUT_END_X=$((PLANK_X + PLANK_W - 1))
    
    xprop -id "$PLANK_ID" -f _NET_WM_STRUT 32c -set _NET_WM_STRUT "0,0,0,$NEW_STRUT"
    xprop -id "$PLANK_ID" -f _NET_WM_STRUT_PARTIAL 32c -set _NET_WM_STRUT_PARTIAL "0,0,0,$NEW_STRUT,0,0,0,0,0,0,$PLANK_X,$STRUT_END_X"

    echo "Strut atualizado para ${NEW_STRUT}px (plank ${PLANK_H} + padding ${PADDING})"
}

# Espera o Plank iniciar se necessário
wait_for_plank() {
    local attempts=0
    while [ $attempts -lt 30 ]; do
        if wmctrl -l | grep -qi "plank"; then
            sleep 1  # Dá tempo pro Plank se posicionar
            return 0
        fi
        sleep 1
        attempts=$((attempts + 1))
    done
    echo "Timeout esperando o Plank iniciar"
    return 1
}

# Modo daemon: monitora mudanças de tela
if [ "$1" = "--daemon" ]; then
    echo "Plank Padding Daemon iniciado (padding=${PADDING}px)"
    
    wait_for_plank && apply_padding
    
    # Monitora eventos de mudança de tela via xrandr
    # Reaplica quando detecta mudança
    LAST_SCREENS=""
    while true; do
        CURRENT_SCREENS=$(xrandr --query | grep " connected" | sort)
        if [ "$CURRENT_SCREENS" != "$LAST_SCREENS" ]; then
            if [ -n "$LAST_SCREENS" ]; then
                echo "Mudança de monitor detectada, reaplicando padding..."
                sleep 2  # Espera o Plank se reposicionar
                apply_padding
            fi
            LAST_SCREENS="$CURRENT_SCREENS"
        fi
        sleep 3
    done
else
    # Execução única
    wait_for_plank && apply_padding
fi
