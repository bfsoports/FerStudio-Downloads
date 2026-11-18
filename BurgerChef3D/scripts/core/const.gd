class_name Const
extends RefCounted
## Constantes globales del proyecto (capas de física, rutas de escenas, modos de juego...).

const GAME_NAME := "Burger Chef 3D"
const GAME_VERSION := "1.0.0"

# Datos del estudio (rincondigitaloficial.com). Se muestran en Créditos y Ajustes y se usan en la ficha de las tiendas.
const STUDIO_NAME := "FerStudio"
const STUDIO_OWNER := "Bairon Fernando Portocarrero Rodríguez"
const SUPPORT_EMAIL := "bfsoports@gmail.com"
const WEBSITE_URL := "https://rincondigitaloficial.com/"
## Ficha del juego y textos legales propios, dentro de la web de FerStudio (publicados el 11-11-2026).
const GAME_SITE_URL := "https://rincondigitaloficial.com/juegos/burgerchef3d/"
const PRIVACY_URL := "https://rincondigitaloficial.com/legal/privacidad-burger-chef-3d/"
const WEBSITE_PRIVACY_URL := "https://rincondigitaloficial.com/legal/privacidad/"
const TERMS_URL := "https://rincondigitaloficial.com/legal/terminos-burger-chef-3d/"
const SUPPORT_URL := "https://rincondigitaloficial.com/juegos/burgerchef3d/#h-faq"
const GAMES_URL := "https://rincondigitaloficial.com/juegos/"
const SAVE_VERSION := 1

# Capas de física 3D (valores de máscara de bits).
const LAYER_WORLD := 1
const LAYER_PLAYER := 2
const LAYER_INTERACT := 4

const REACH := 3.2            # alcance de interacción en metros
const CARRY_SCALE := 0.55     # escala de un objeto mientras se transporta
const MIN_TOUCH := 76         # tamaño mínimo de un objetivo táctil (px del lienzo 1280x720)
const MAX_PLAYER_LEVEL := 50

const SCENE_BOOT := "res://scenes/boot/boot.tscn"
const SCENE_MENU := "res://scenes/menus/main_menu.tscn"
const SCENE_GAME := "res://scenes/gameplay/gameplay.tscn"

const MODE_CAMPAIGN := "campaign"
const MODE_FREE := "free"
const MODE_TUTORIAL := "tutorial"

const GROUP_SHADOW_LIGHTS := "shadow_lights"
const GROUP_EXTRA_LIGHTS := "extra_lights"
