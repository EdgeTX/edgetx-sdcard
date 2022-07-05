!!! IMPORTANT
EdgeTX 2.5 Theme implementation is first approach and may be changed in next
releases. That means color variables and YAML file structure may change.


EdgeTX 2.5 Theme
----------------
There are 11 EdgeTX OS color variables that are used to define EdgeTX UI look &
feel. PRIMARY1, PRIMARY2, PRIMARY3, SECONDARY1, SECONDARY2, SECONDARY3, FOCUS,
ACTIVE, WARNING & DISABLED.
Color values format uses 24bit value (RGB color scheme) coded in hex format
RRGGBB where RR stands for Red component value, GG for Green and BB for Blue.
Each component can have 256 values (00-FF range in hex format)

RGB color scheme examples:
FF0000 (Light Red)
440000 (Dark Red)
00FF00 (Light Green)
002400 (Dark Green)
0000FF (Light Blue)
000064 (Dark Blue)
FFFFFF (White)
808080 (50% Gray)
202020 (Dark Gray)


EdgeTX 2.5 Theme definition
---------------------------
Themes colors definition is stored in YAML format text files placed in /THEMES
folder in radio's SD card. YAML (Yet Another Markup Language) is simple markup
language to define data structure. It can be edited using any text editor.
File name has to have .yml extension.
Example: custom_theme.yml

Additionally you can include graphic file (in PNG format) to display in EdgeTX
User Interface Tab theme preview. To display preview file name must be the same
as YAML file.
Example:
If theme color definition is name new_theme.yml graphic preview file must be
named new_theme.png


EdgeTX 2.5 Theme definition YAML file structure
-----------------------------------------------
Data in YAML file is structured using basic scheme "name: value"
Leading spaces are important as they define data group assignment.

Example of theme colors definition:

---
summary:
  name: Theme name
  author: Creator
  info: Here is short description
colors:
 PRIMARY1:   0xA0A0A0
 PRIMARY2:   0x202020
 PRIMARY3:   0x505050
 SECONDARY1: 0x808080
 SECONDARY2: 0x505050
 SECONDARY3: 0x303030
 FOCUS:      0xC0C0C0
 EDIT:       0xEEEEEE
 ACTIVE:     0xD0D0D0
 WARNING:    0x404040
 DISABLED:   0x808080

'---'         YAML format marker (must be placed as first line)
'summary: '   Group marker (description)
' name: '     Name of theme displayed in EdgeTX UI
' author: '   Name of author displayed in EdgeTX UI
' info: '     Short info about theme displayed in EdgeTX UI
'colors: '    Group marker (colors definition)
' PRIMARY1: ' ETX color variable in 0xRRGGBB format (0x means value is in hex)
' PRIMARY2: ' ETX color variable in 0xRRGGBB format (0x means value is in hex)
etc


ETX 2.5 UI elements color variables assignment
----------------------------------------------
PRIMARY1
 Label text
 Button text (not focused)
PRIMARY2
  ETX Logo icon,
  TopBar Icons
  TopBar text
  TopBar tab name text
  BottomBar text
  Editable field background
  Editable field text (editing)
  Button text (focused)
  PopUp selectable field background
  Trim knob
  Slider knob
PRIMARY3
  Scroll marker
  Inactive part of TopBar icons
SECONDARY1
  TopBar background
  BottomBar background
  Trim knob path
  Trim Knob shadow
  Slider path
  Slider knob shadow
SECONDARY2
  Label background
  Button background
SECONDARY3
  Main screen's background
  PopUp's background
FOCUS
  ETX Logo background
  TopBar icon background (selected)
  Label background (focused)
  Editable field background (focused)
  Trim knob
  Slider knob
EDIT
  Editable field background (editing)
ACTIVE
  Buttons background (button active)
  Editable field background (variable active)
WARNING
  Label text (warning)
DISABLED
  Disabled elements


Creating EdgeTX 2.5 theme color definition
-------------------------------------------
1. Create *.yml file with theme definition
2. Create *.png file with theme preview
3. Place *.yml & *.png files in /THEMES folder on radio's SD Card
4. Reboot radio
5. Navigate to 'User Interface' Tab in EdgeTX
6. Select new theme from the dropdown list.


EdgeTX 2.5 Theme implementation
-------------------------------
1. If there is no files in /THEMES folder default EdgeTX theme will be applied.
2. selectedtheme.txt file holds name of selected theme YAML file. If empty or
not present default EdgeTX theme will be applied.
3. If color variable definition is omitted in YAML file, last applied color
value is used (color value from previously used theme)
4. If *.png file in not present or has different name than YAML file it won't be
displayed in EdgeTX UI
