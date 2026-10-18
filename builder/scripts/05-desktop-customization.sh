#!/bin/bash
set -e

echo "=== Customizing Desktop Environment (XFCE) ==="

# 1. LightDM Autologin + Wallpaper Directory
echo "Configuring LightDM autologin..."
mkdir -p /usr/share/backgrounds/telcosec
mkdir -p /etc/lightdm/lightdm.conf.d

cat << 'EOF' > /etc/lightdm/lightdm.conf.d/50-telcosec-autologin.conf
[Seat:*]
autologin-user=telcosec
autologin-user-timeout=0
user-session=xfce
EOF

# NOTE: /etc/casper.conf is NOT written here. build-iso.sh writes it once,
# after all provisioning scripts run, as the single source of truth (it used
# to be written in both places, with build-iso.sh's copy silently winning
# since it runs last — that duplicate authority has been removed).

# 2. XFCE defaults (Themes, Fonts, Wallpaper, Keybindings)
# Theme is Yaru-bark-dark — the previous "Yaru-teal-dark" does not exist in
# Ubuntu 24.04's yaru-theme-gtk package at all (verified against the real
# noble package file listing: only bark/blue/magenta/olive/prussiangreen/
# purple/red/sage/viridian variants ship, each with a -dark suffix — no
# "teal"). GTK/xfwm4/lightdm-gtk-greeter would have silently fallen back to
# plain Yaru/Adwaita instead of the intended branded look. Yaru doesn't ship
# an amber/orange variant; "bark" (warm brown/tan) is the closest available
# match to the brand's amber accent (#e8921e), completing the harmonization
# already done for Calamares/tmux/docs.
echo "Writing XFCE default configurations..."
mkdir -p /etc/xdg/xfce4/xfconf/xfce-perchannel-xml /etc/skel/.config/xfce4/xfconf/xfce-perchannel-xml /etc/skel/.config/gtk-3.0

cat << 'EOF' > /etc/xdg/xfce4/xfconf/xfce-perchannel-xml/xsettings.xml
<?xml version="1.0" encoding="UTF-8"?>
<channel name="xsettings" version="1.0">
  <property name="Net" type="empty">
    <property name="ThemeName" type="string" value="Yaru-bark-dark"/>
    <property name="IconThemeName" type="string" value="Papirus-Dark"/>
    <property name="EnableAnimations" type="bool" value="true"/>
  </property>
  <property name="Gtk" type="empty">
    <property name="FontName" type="string" value="Ubuntu 10"/>
    <property name="MonospaceFontName" type="string" value="Ubuntu Mono 12"/>
    <property name="MenuPopupDelay" type="int" value="0"/>
    <property name="ToolbarStyle" type="string" value="icons"/>
    <property name="ButtonImages" type="bool" value="true"/>
    <property name="MenuImages" type="bool" value="true"/>
  </property>
</channel>
EOF

cat << 'EOF' > /etc/skel/.config/gtk-3.0/settings.ini
[Settings]
gtk-theme-name = Yaru-bark-dark
gtk-icon-theme-name = Papirus-Dark
gtk-font-name = Ubuntu 10
gtk-monospace-font-name = Ubuntu Mono 12
gtk-menu-popup-delay = 0
gtk-enable-animations = 1
gtk-application-prefer-dark-theme = 1
EOF

# Deploy custom TelcoChisel Cyberpunk GTK 3 theme for XFCE panel, menus, and widgets
mkdir -p /etc/xdg/gtk-3.0 /etc/skel/.config/gtk-3.0
cat << 'GTKEOF' | tee /etc/xdg/gtk-3.0/gtk.css > /etc/skel/.config/gtk-3.0/gtk.css
/* ==========================================================================
   TelcoChisel OS — Tactical Cyberpunk GTK 3 Theme
   Palette:
     Canvas:        #0a0e17   Surface:     #0e121a   Elevate:     #161b22
     Cyan accent:   #00ffd5   Amber warn:  #e8921e   Alert:       #ff4466
     Border subtle: #21262d   Text:        #e6edf3   Muted:       #8b949e
   ========================================================================== */

/* ── Panel ─────────────────────────────────────────────────────────────────── */
.xfce4-panel {
  background-color: rgba(10, 14, 23, 0.97);
  color: #e6edf3;
  border-bottom: 2px solid #00ffd5;
  box-shadow: 0 2px 12px rgba(0, 255, 213, 0.12);
  font-family: "Ubuntu", sans-serif;
  font-size: 10pt;
}

.xfce4-panel button {
  background-color: transparent;
  color: #c9d1d9;
  border: none;
  border-radius: 4px;
  margin: 2px 1px;
  padding: 0 4px;
  transition: background-color 120ms ease, color 120ms ease;
}

.xfce4-panel button:hover {
  background-color: rgba(0, 255, 213, 0.14);
  color: #00ffd5;
}

.xfce4-panel button:checked,
.xfce4-panel button:active {
  background-color: rgba(0, 255, 213, 0.22);
  color: #ffffff;
  border-bottom: 2px solid #00ffd5;
}

/* ── Tasklist ──────────────────────────────────────────────────────────────── */
.xfce4-panel .tasklist button {
  padding: 0 8px;
  border-radius: 3px;
  margin: 2px 2px;
  border-bottom: 2px solid transparent;
}

.xfce4-panel .tasklist button:hover {
  background-color: rgba(0, 255, 213, 0.10);
  border-bottom: 2px solid rgba(0, 255, 213, 0.45);
}

.xfce4-panel .tasklist button:checked {
  background-color: rgba(14, 23, 38, 0.95);
  color: #00ffd5;
  border-bottom: 2px solid #00ffd5;
}

/* ── Workspace Pager ───────────────────────────────────────────────────────── */
.xfce4-panel .pager button {
  background-color: rgba(22, 27, 34, 0.7);
  border: 1px solid #21262d;
  color: #8b949e;
  border-radius: 3px;
  margin: 2px 1px;
  padding: 0 4px;
  font-size: 8pt;
}

.xfce4-panel .pager button:hover {
  border-color: #e8921e;
  color: #e8921e;
}

.xfce4-panel .pager button:checked {
  background-color: rgba(0, 255, 213, 0.18);
  border: 1px solid #00ffd5;
  color: #00ffd5;
  font-weight: bold;
}

/* ── Whisker Menu button ───────────────────────────────────────────────────── */
#whiskermenu-button {
  font-weight: bold;
  color: #00ffd5;
  padding: 0 10px;
  letter-spacing: 0.5px;
}

#whiskermenu-button:hover {
  background-color: rgba(0, 255, 213, 0.18);
  color: #ffffff;
}

/* ── Whisker Menu window ───────────────────────────────────────────────────── */
#whiskermenu-window {
  background-color: #0b0f19;
  border: 1px solid rgba(0, 255, 213, 0.5);
  border-radius: 6px;
  box-shadow: 0 12px 32px rgba(0, 0, 0, 0.8);
  color: #e6edf3;
}

#whiskermenu-window entry {
  background-color: #141a26;
  border: 1px solid #21262d;
  border-radius: 4px;
  color: #ffffff;
  padding: 6px 10px;
  caret-color: #00ffd5;
}

#whiskermenu-window entry:focus {
  border-color: #00ffd5;
  box-shadow: 0 0 8px rgba(0, 255, 213, 0.28);
  outline: none;
}

#whiskermenu-window treeview {
  background-color: transparent;
  color: #c9d1d9;
}

#whiskermenu-window treeview:selected {
  background-color: rgba(0, 255, 213, 0.18);
  color: #00ffd5;
  border-left: 3px solid #00ffd5;
}

#whiskermenu-window treeview:hover {
  background-color: rgba(0, 255, 213, 0.08);
}

/* Category list column */
#whiskermenu-window .sidebar treeview:selected {
  background-color: rgba(0, 255, 213, 0.22);
  color: #00ffd5;
  font-weight: bold;
}

/* ── Application Menu / Context Menu ──────────────────────────────────────── */
menu,
.menu,
.context-menu {
  background-color: #0e121a;
  border: 1px solid #21262d;
  border-radius: 5px;
  box-shadow: 0 8px 24px rgba(0, 0, 0, 0.75);
  padding: 4px 0;
  color: #e6edf3;
}

menuitem {
  padding: 5px 14px;
  border-radius: 3px;
  margin: 1px 4px;
  color: #c9d1d9;
  font-size: 10pt;
}

menuitem:hover,
menuitem:selected {
  background-color: rgba(0, 255, 213, 0.16);
  color: #00ffd5;
}

menuitem:disabled {
  color: #484f58;
}

menu separator,
menuseparator {
  background-color: #21262d;
  margin: 4px 8px;
  min-height: 1px;
}

/* ── GtkEntry / Input Fields ───────────────────────────────────────────────── */
entry {
  background-color: #161b22;
  border: 1px solid #21262d;
  border-radius: 4px;
  color: #e6edf3;
  padding: 5px 8px;
  caret-color: #00ffd5;
  transition: border-color 120ms ease, box-shadow 120ms ease;
}

entry:focus {
  border-color: #00ffd5;
  box-shadow: 0 0 0 2px rgba(0, 255, 213, 0.18);
  outline: none;
}

entry:disabled {
  background-color: #0e121a;
  color: #484f58;
  border-color: #21262d;
}

/* ── Buttons ───────────────────────────────────────────────────────────────── */
button {
  background-color: #161b22;
  border: 1px solid #21262d;
  border-radius: 4px;
  color: #e6edf3;
  padding: 5px 12px;
  transition: background-color 120ms ease, border-color 120ms ease;
}

button:hover {
  background-color: rgba(0, 255, 213, 0.12);
  border-color: rgba(0, 255, 213, 0.4);
  color: #00ffd5;
}

button:active,
button:checked {
  background-color: rgba(0, 255, 213, 0.22);
  border-color: #00ffd5;
  color: #ffffff;
}

button.suggested-action {
  background-color: rgba(0, 255, 213, 0.20);
  border-color: #00ffd5;
  color: #00ffd5;
  font-weight: bold;
}

button.destructive-action {
  background-color: rgba(255, 68, 102, 0.18);
  border-color: #ff4466;
  color: #ff4466;
}

/* ── CheckButton / RadioButton ─────────────────────────────────────────────── */
checkbutton check,
radiobutton radio {
  background-color: #161b22;
  border: 1px solid #21262d;
  border-radius: 3px;
  min-width: 14px;
  min-height: 14px;
}

checkbutton:hover check,
radiobutton:hover radio {
  border-color: #00ffd5;
}

checkbutton:checked check,
radiobutton:checked radio {
  background-color: #00ffd5;
  border-color: #00ffd5;
  color: #0a0e17;
}

/* ── ComboBox ──────────────────────────────────────────────────────────────── */
combobox button {
  padding: 4px 8px;
}

combobox > .linked > button:last-child {
  border-left: none;
}

/* ── Scrollbar ─────────────────────────────────────────────────────────────── */
scrollbar {
  background-color: transparent;
  border: none;
}

scrollbar slider {
  background-color: rgba(0, 255, 213, 0.22);
  border-radius: 10px;
  min-width: 6px;
  min-height: 6px;
  margin: 2px;
  transition: background-color 120ms ease;
}

scrollbar slider:hover {
  background-color: rgba(0, 255, 213, 0.45);
}

scrollbar slider:active {
  background-color: #00ffd5;
}

/* ── Notebook / Tabs (Terminator, Firefox, etc.) ───────────────────────────── */
notebook > header {
  background-color: #0a0e17;
  border-bottom: 1px solid #21262d;
  padding: 0;
}

notebook > header tab {
  background-color: transparent;
  border: none;
  border-bottom: 2px solid transparent;
  color: #8b949e;
  padding: 6px 14px;
  margin: 0 1px;
  transition: color 120ms ease, border-color 120ms ease;
}

notebook > header tab:hover {
  color: #c9d1d9;
  border-bottom-color: rgba(0, 255, 213, 0.4);
}

notebook > header tab:checked {
  color: #00ffd5;
  border-bottom-color: #00ffd5;
  font-weight: bold;
}

/* ── GtkHeaderBar (Firefox, Thunar) ────────────────────────────────────────── */
headerbar {
  background-color: #0e121a;
  border-bottom: 1px solid #21262d;
  color: #e6edf3;
  padding: 4px 8px;
  box-shadow: none;
}

headerbar entry {
  background-color: #161b22;
  border-radius: 20px;
  padding: 4px 12px;
}

/* ── Window / Dialog ───────────────────────────────────────────────────────── */
window,
dialog {
  background-color: #0e121a;
  color: #e6edf3;
}

dialog .dialog-action-area button {
  min-width: 80px;
}

/* ── Treeview (Thunar file list) ───────────────────────────────────────────── */
treeview {
  background-color: #0e121a;
  color: #c9d1d9;
}

treeview:selected {
  background-color: rgba(0, 255, 213, 0.18);
  color: #00ffd5;
}

treeview:hover {
  background-color: rgba(255, 255, 255, 0.04);
}

treeview header button {
  background-color: #0a0e17;
  border-bottom: 1px solid #21262d;
  color: #8b949e;
  border-radius: 0;
  padding: 4px 8px;
}

treeview header button:hover {
  color: #00ffd5;
}

/* ── Sidebar (Thunar, Files) ───────────────────────────────────────────────── */
.sidebar {
  background-color: #0a0e17;
  border-right: 1px solid #21262d;
  color: #c9d1d9;
}

.sidebar row:selected,
.sidebar row:selected:focus {
  background-color: rgba(0, 255, 213, 0.16);
  color: #00ffd5;
}

.sidebar row:hover {
  background-color: rgba(255, 255, 255, 0.04);
}

/* ── Progressbar ───────────────────────────────────────────────────────────── */
progressbar trough {
  background-color: #161b22;
  border-radius: 10px;
  min-height: 6px;
}

progressbar progress {
  background-color: #00ffd5;
  border-radius: 10px;
}

/* ── Scale (sliders) ───────────────────────────────────────────────────────── */
scale trough {
  background-color: #161b22;
  border-radius: 4px;
  min-height: 4px;
}

scale highlight {
  background-color: #00ffd5;
  border-radius: 4px;
}

scale slider {
  background-color: #00ffd5;
  border-radius: 50%;
  min-width: 14px;
  min-height: 14px;
  box-shadow: 0 0 4px rgba(0, 255, 213, 0.4);
}

/* ── Tooltip ───────────────────────────────────────────────────────────────── */
tooltip {
  background-color: rgba(10, 14, 23, 0.97);
  border: 1px solid rgba(0, 255, 213, 0.5);
  border-radius: 4px;
  color: #e6edf3;
  padding: 5px 10px;
  box-shadow: 0 4px 12px rgba(0, 0, 0, 0.6);
}

/* ── Status Bar ────────────────────────────────────────────────────────────── */
statusbar {
  background-color: #0a0e17;
  border-top: 1px solid #21262d;
  color: #8b949e;
  padding: 2px 8px;
  font-size: 9pt;
}

/* ── Genmon panel label spans (pango markup colour pass-through) ─────────────
   Genmon renders via a GtkLabel — no extra CSS needed; colours come from
   <span foreground='...'> pango markup. Ensure the panel label baseline
   colour doesn't interfere with the span overrides.                        */
.xfce4-panel label {
  color: #8b949e;
  font-family: "Ubuntu Mono", monospace;
  font-size: 9pt;
}
GTKEOF

# Also install as system GTK theme override for LightDM greeter
mkdir -p /etc/gtk-3.0
cp /etc/xdg/gtk-3.0/gtk.css /etc/gtk-3.0/gtk.css


cat << 'EOF' > /etc/xdg/xfce4/xfconf/xfce-perchannel-xml/xfce4-desktop.xml
<?xml version="1.0" encoding="UTF-8"?>
<channel name="xfce4-desktop" version="1.0">
  <property name="backdrop" type="empty">
    <property name="screen0" type="empty">
      <property name="monitor0" type="empty">
        <property name="workspace0" type="empty">
          <property name="last-image" type="string" value="/usr/share/backgrounds/telcosec/wallpaper.jpg"/>
          <property name="image-style" type="int" value="5"/>
        </property>
        <property name="workspace1" type="empty">
          <property name="last-image" type="string" value="/usr/share/backgrounds/telcosec/wallpaper.jpg"/>
          <property name="image-style" type="int" value="5"/>
        </property>
        <property name="workspace2" type="empty">
          <property name="last-image" type="string" value="/usr/share/backgrounds/telcosec/wallpaper.jpg"/>
          <property name="image-style" type="int" value="5"/>
        </property>
        <property name="workspace3" type="empty">
          <property name="last-image" type="string" value="/usr/share/backgrounds/telcosec/wallpaper.jpg"/>
          <property name="image-style" type="int" value="5"/>
        </property>
        <property name="workspace4" type="empty">
          <property name="last-image" type="string" value="/usr/share/backgrounds/telcosec/wallpaper.jpg"/>
          <property name="image-style" type="int" value="5"/>
        </property>
        <property name="workspace5" type="empty">
          <property name="last-image" type="string" value="/usr/share/backgrounds/telcosec/wallpaper.jpg"/>
          <property name="image-style" type="int" value="5"/>
        </property>
        <property name="workspace6" type="empty">
          <property name="last-image" type="string" value="/usr/share/backgrounds/telcosec/wallpaper.jpg"/>
          <property name="image-style" type="int" value="5"/>
        </property>
      </property>
    </property>
  </property>
  <property name="desktop-icons" type="empty">
    <property name="style" type="int" value="2"/>
    <property name="file-icons" type="empty">
      <property name="show-filesystem" type="bool" value="false"/>
      <property name="show-home" type="bool" value="false"/>
      <property name="show-trash" type="bool" value="false"/>
      <property name="show-removable" type="bool" value="false"/>
    </property>
  </property>
</channel>
EOF

cat << 'EOF' > /etc/xdg/xfce4/xfconf/xfce-perchannel-xml/xfwm4.xml
<?xml version="1.0" encoding="UTF-8"?>
<channel name="xfwm4" version="1.0">
  <property name="general" type="empty">
    <property name="theme" type="string" value="Yaru-bark-dark"/>
    <property name="button_layout" type="string" value="O|HMC"/>
    <property name="workspace_count" type="int" value="7"/>
    <property name="workspace_names" type="array">
      <value type="string" value="📡 1: RF-DSP"/>
      <value type="string" value="📻 2: GSM-RAN"/>
      <value type="string" value="⚡ 3: CORE-5G"/>
      <value type="string" value="🧪 4: PRO-LABS"/>
      <value type="string" value="🎓 5: ACADEMY"/>
      <value type="string" value="🔍 6: DISSECT"/>
      <value type="string" value="📝 7: EVIDENCE"/>
    </property>
    <!-- Compositor: disabled — Picom GLX handles compositing externally -->
    <!-- xfwm4 built-in compositor is OFF to avoid double-compositing overhead -->
    <property name="use_compositing" type="bool" value="false"/>
    <!-- Unredirect full-screen overlays (SDR waterfalls bypass compositor entirely) -->
    <property name="unredirect_overlays" type="bool" value="true"/>
    <!-- VBlank via XPresent for lowest-latency GPU sync (requires mesa 20+) -->
    <property name="vblank_mode" type="string" value="xpresent"/>
    <property name="cycle_preview" type="bool" value="true"/>
    <property name="cycle_tabwin_mode" type="int" value="1"/>
    <property name="zoom_desktop" type="bool" value="false"/>
    <property name="show_dock_shadow" type="bool" value="false"/>
    <property name="show_popup_shadow" type="bool" value="false"/>
    <property name="frame_opacity" type="int" value="100"/>
    <property name="inactive_opacity" type="int" value="100"/>
    <property name="snap_to_border" type="bool" value="true"/>
    <property name="snap_to_windows" type="bool" value="true"/>
    <property name="snap_resist" type="bool" value="true"/>
    <property name="tile_on_move" type="bool" value="true"/>
    <!-- Solid drag/resize for clear feedback during spectrum window moves -->
    <property name="box_move" type="bool" value="false"/>
    <property name="box_resize" type="bool" value="false"/>
    <!-- Focus-follows-mouse: operator looks at the window they're typing into -->
    <property name="click_to_focus" type="bool" value="false"/>
    <property name="raise_on_focus" type="bool" value="false"/>
    <property name="raise_on_click" type="bool" value="true"/>
  </property>
</channel>
EOF

cat << 'EOF' > /etc/xdg/xfce4/xfconf/xfce-perchannel-xml/xfce4-session.xml
<?xml version="1.0" encoding="UTF-8"?>
<channel name="xfce4-session" version="1.0">
  <property name="general" type="empty">
    <property name="FailsafeSessionName" type="string" value="Failsafe"/>
    <property name="LockCommand" type="string" value="xflock4"/>
    <property name="SaveOnExit" type="bool" value="false"/>
    <property name="PromptOnLogout" type="bool" value="true"/>
  </property>
  <property name="sessions" type="empty">
    <property name="Failsafe" type="empty">
      <property name="IsFailsafe" type="bool" value="true"/>
      <property name="Count" type="int" value="4"/>
      <property name="Client0_Command" type="array">
        <value type="string" value="xfsettingsd"/>
      </property>
      <property name="Client0_Priority" type="int" value="5"/>
      <property name="Client0_PerScreen" type="bool" value="false"/>
      <property name="Client1_Command" type="array">
        <value type="string" value="xfwm4"/>
      </property>
      <property name="Client1_Priority" type="int" value="15"/>
      <property name="Client1_PerScreen" type="bool" value="false"/>
      <property name="Client2_Command" type="array">
        <value type="string" value="xfce4-panel"/>
      </property>
      <property name="Client2_Priority" type="int" value="25"/>
      <property name="Client2_PerScreen" type="bool" value="false"/>
      <property name="Client3_Command" type="array">
        <value type="string" value="xfdesktop"/>
      </property>
      <property name="Client3_Priority" type="int" value="35"/>
      <property name="Client3_PerScreen" type="bool" value="false"/>
    </property>
  </property>
  <property name="compat" type="empty">
    <property name="LaunchGNOME" type="bool" value="false"/>
    <property name="LaunchKDE" type="bool" value="false"/>
  </property>
  <property name="shutdown" type="empty">
    <property name="ShowHibernate" type="bool" value="false"/>
    <property name="ShowSuspend" type="bool" value="false"/>
  </property>
</channel>
EOF

cat << 'EOF' > /etc/xdg/xfce4/xfconf/xfce-perchannel-xml/thunar.xml
<?xml version="1.0" encoding="UTF-8"?>
<channel name="thunar" version="1.0">
  <property name="last-view" type="string" value="ThunarDetailsView"/>
  <property name="misc-single-click" type="bool" value="false"/>
  <property name="misc-show-hidden" type="bool" value="false"/>
  <property name="misc-parallel-copy-mode" type="string" value="THUNAR_PARALLEL_COPY_MODE_NEVER"/>
  <property name="misc-date-style" type="string" value="THUNAR_DATE_STYLE_SHORT"/>
  <property name="misc-thumbnail-mode" type="string" value="THUNAR_THUMBNAIL_MODE_ONLY_LOCAL"/>
</channel>
EOF

cat << 'EOF' > /etc/xdg/xfce4/xfconf/xfce-perchannel-xml/xfce4-power-manager.xml
<?xml version="1.0" encoding="UTF-8"?>
<channel name="xfce4-power-manager" version="1.0">
  <property name="xfce4-power-manager" type="empty">
    <property name="power-button-action" type="uint" value="3"/>
    <property name="dpms-enabled" type="bool" value="false"/>
    <property name="blank-on-ac" type="int" value="0"/>
    <property name="blank-on-battery" type="int" value="0"/>
    <property name="dpms-on-ac-sleep" type="uint" value="0"/>
    <property name="dpms-on-ac-off" type="uint" value="0"/>
    <property name="dpms-on-battery-sleep" type="uint" value="0"/>
    <property name="dpms-on-battery-off" type="uint" value="0"/>
  </property>
</channel>
EOF

# Single top panel: Whisker Menu on the left, quick launchers for Telecom Red Team workflows,
# window list with middle-click close filling the middle, 7-workspace pager + systray + clock on the right.
cat << 'EOF' > /etc/xdg/xfce4/xfconf/xfce-perchannel-xml/xfce4-panel.xml
<?xml version="1.0" encoding="UTF-8"?>
<channel name="xfce4-panel" version="1.0">
  <property name="configver" type="int" value="2"/>
  <property name="panels" type="array">
    <value type="int" value="1"/>
    <property name="panel-1" type="empty">
      <property name="position" type="string" value="p=6;x=0;y=0"/>
      <property name="length" type="uint" value="100"/>
      <property name="length-adjust" type="bool" value="true"/>
      <property name="position-locked" type="bool" value="true"/>
      <property name="size" type="uint" value="34"/>
      <property name="plugin-ids" type="array">
        <value type="int" value="1"/>
        <value type="int" value="14"/>
        <value type="int" value="6"/>
        <value type="int" value="7"/>
        <value type="int" value="8"/>
        <value type="int" value="9"/>
        <value type="int" value="10"/>
        <value type="int" value="11"/>
        <value type="int" value="12"/>
        <value type="int" value="13"/>
        <value type="int" value="15"/>
        <value type="int" value="2"/>
        <value type="int" value="16"/>
        <value type="int" value="21"/>
        <value type="int" value="18"/>
        <value type="int" value="19"/>
        <value type="int" value="20"/>
        <value type="int" value="22"/>
        <value type="int" value="3"/>
        <value type="int" value="17"/>
        <value type="int" value="4"/>
        <value type="int" value="5"/>
      </property>
    </property>
  </property>
  <property name="plugins" type="empty">
    <property name="plugin-1" type="string" value="whiskermenu">
      <property name="button-title" type="string" value="TelcoChisel"/>
      <property name="button-icon" type="string" value="telcosec"/>
      <property name="show-button-title" type="bool" value="true"/>
      <property name="show-button-icon" type="bool" value="true"/>
    </property>
    <property name="plugin-14" type="string" value="separator">
      <property name="style" type="uint" value="0"/>
    </property>
    <property name="plugin-6" type="string" value="launcher">
      <property name="items" type="array">
        <value type="string" value="net.tenshu.Terminator.desktop"/>
      </property>
    </property>
    <property name="plugin-7" type="string" value="launcher">
      <property name="items" type="array">
        <value type="string" value="telcosec-tmux-redteam.desktop"/>
      </property>
    </property>
    <property name="plugin-8" type="string" value="launcher">
      <property name="items" type="array">
        <value type="string" value="telcosec-prolabs.desktop"/>
      </property>
    </property>
    <property name="plugin-9" type="string" value="launcher">
      <property name="items" type="array">
        <value type="string" value="telcosec-academy.desktop"/>
      </property>
    </property>
    <property name="plugin-10" type="string" value="launcher">
      <property name="items" type="array">
        <value type="string" value="wireshark-mon.desktop"/>
      </property>
    </property>
    <property name="plugin-11" type="string" value="launcher">
      <property name="items" type="array">
        <value type="string" value="gqrx.desktop"/>
      </property>
    </property>
    <property name="plugin-12" type="string" value="launcher">
      <property name="items" type="array">
        <value type="string" value="pysim-shell.desktop"/>
      </property>
    </property>
    <property name="plugin-13" type="string" value="launcher">
      <property name="items" type="array">
        <value type="string" value="telcosec-docs.desktop"/>
      </property>
    </property>
    <property name="plugin-15" type="string" value="separator">
      <property name="style" type="uint" value="1"/>
    </property>
    <property name="plugin-2" type="string" value="tasklist">
      <property name="expand" type="bool" value="true"/>
      <property name="grouping" type="uint" value="1"/>
      <property name="middle-click" type="uint" value="3"/>
      <property name="flat-buttons" type="bool" value="true"/>
      <property name="show-labels" type="bool" value="true"/>
    </property>
    <property name="plugin-16" type="string" value="separator">
      <property name="style" type="uint" value="0"/>
    </property>
    <!-- Live Telecom Telemetry: left separator -->
    <property name="plugin-21" type="string" value="separator">
      <property name="style" type="uint" value="0"/>
    </property>
    <!-- Genmon 18: SDR Hardware Probe (every 3s, click opens lsusb sdr probe) -->
    <property name="plugin-18" type="string" value="genmon">
      <property name="command" type="string" value="/usr/local/bin/telcosec-genmon-sdr"/>
      <property name="use-label" type="bool" value="false"/>
      <property name="update-period" type="uint" value="3"/>
      <property name="font" type="string" value="Fira Code Bold 9"/>
    </property>
    <!-- Genmon 19: 5G Core and Cellular Stack Status -->
    <property name="plugin-19" type="string" value="genmon">
      <property name="command" type="string" value="/usr/local/bin/telcosec-genmon-core"/>
      <property name="use-label" type="bool" value="false"/>
      <property name="update-period" type="uint" value="3"/>
      <property name="font" type="string" value="Fira Code Bold 9"/>
    </property>
    <!-- Genmon 20: VPN / Tunnel / ProLabs Network Status -->
    <property name="plugin-20" type="string" value="genmon">
      <property name="command" type="string" value="/usr/local/bin/telcosec-genmon-net"/>
      <property name="use-label" type="bool" value="false"/>
      <property name="update-period" type="uint" value="3"/>
      <property name="font" type="string" value="Fira Code Bold 9"/>
    </property>
    <!-- Live Telecom Telemetry: right separator -->
    <property name="plugin-22" type="string" value="separator">
      <property name="style" type="uint" value="0"/>
    </property>
    <property name="plugin-3" type="string" value="pager">
      <property name="rows" type="uint" value="1"/>
      <property name="miniature-view" type="bool" value="false"/>
    </property>
    <property name="plugin-17" type="string" value="separator">
      <property name="style" type="uint" value="1"/>
    </property>
    <property name="plugin-4" type="string" value="systray"/>
    <property name="plugin-5" type="string" value="clock">
      <property name="digital-layout" type="uint" value="2"/>
      <property name="digital-time-format" type="string" value="%H:%M"/>
      <property name="digital-date-format" type="string" value="%a %d %b"/>
    </property>
  </property>
</channel>
EOF

# Keyboard shortcuts: only additions beyond XFCE's own stock defaults (which
# already cover Alt+Tab, Ctrl+Alt+Left/Right workspace switching, etc.) —
# Super key for one-key Whisker Menu access, and Super+Arrow for basic
# window tiling, neither of which XFCE binds out of the box.
cat << 'EOF' > /etc/xdg/xfce4/xfconf/xfce-perchannel-xml/xfce4-keyboard-shortcuts.xml
<?xml version="1.0" encoding="UTF-8"?>
<channel name="xfce4-keyboard-shortcuts" version="1.0">
  <property name="commands" type="empty">
    <property name="custom" type="empty">
      <property name="Super_L" type="string" value="xfce4-popup-whiskermenu"/>
      <property name="&lt;Primary&gt;&lt;Alt&gt;t" type="string" value="terminator"/>
      <property name="&lt;Super&gt;Return" type="string" value="terminator"/>
      <property name="&lt;Super&gt;e" type="string" value="thunar"/>
      <property name="&lt;Super&gt;l" type="string" value="xflock4"/>
      <property name="&lt;Super&gt;&lt;Shift&gt;w" type="string" value="wireshark -k -Y gsmtap"/>
      <property name="&lt;Super&gt;&lt;Shift&gt;g" type="string" value="gqrx"/>
      <property name="&lt;Super&gt;&lt;Shift&gt;s" type="string" value="terminator -e pysim-shell"/>
      <property name="&lt;Super&gt;&lt;Shift&gt;t" type="string" value="/usr/local/bin/telcosec-tmux-redteam"/>
      <property name="&lt;Super&gt;&lt;Shift&gt;h" type="string" value="/usr/local/bin/telcosec-toggle-hud"/>
      <property name="&lt;Super&gt;&lt;Shift&gt;x" type="string" value="telcosec-prolabs open"/>
      <property name="&lt;Super&gt;&lt;Shift&gt;m" type="string" value="telcosec-academy open"/>
      <property name="&lt;Super&gt;&lt;Shift&gt;d" type="string" value="firefox file:///usr/share/doc/telcosec/index.html"/>
      <property name="&lt;Super&gt;F1" type="string" value="terminator -T &quot;TelcoSec Pre-flight Doctor&quot; --geometry=960x640 -e &quot;telcosec check; echo ''; read -p 'Press enter to exit...'&quot;"/>
      <property name="&lt;Super&gt;F2" type="string" value="terminator -T &quot;TelcoSec Hardware Probe&quot; --geometry=960x640 -e &quot;telcosec hardware; echo ''; read -p 'Press enter to exit...'&quot;"/>
      <property name="&lt;Super&gt;F3" type="string" value="terminator -T &quot;5G SA Core Status&quot; --geometry=960x640 -e &quot;telcosec 5g-sa status; echo ''; read -p 'Press enter to exit...'&quot;"/>
      <property name="&lt;Super&gt;F4" type="string" value="terminator -T &quot;10GbE Network Zero-Drop Tuning&quot; --geometry=960x640 -e &quot;sudo telcosec sdr 10g tune; echo ''; read -p 'Press enter to exit...'&quot;"/>
      <property name="&lt;Super&gt;F5" type="string" value="terminator -T &quot;TelcoSec ProLabs Range Status&quot; --geometry=960x640 -e &quot;telcosec prolabs status; echo ''; read -p 'Press enter to exit...'&quot;"/>
      <property name="&lt;Super&gt;F6" type="string" value="terminator -T &quot;TelcoSec Academy Course Manager&quot; --geometry=960x640 -e &quot;telcosec academy status; echo ''; read -p 'Press enter to exit...'&quot;"/>
    </property>
  </property>
  <property name="xfwm4" type="empty">
    <property name="custom" type="empty">
      <property name="&lt;Primary&gt;&lt;Alt&gt;Left" type="string" value="left_workspace_key"/>
      <property name="&lt;Primary&gt;&lt;Alt&gt;Right" type="string" value="right_workspace_key"/>
      <property name="&lt;Super&gt;1" type="string" value="workspace_1_key"/>
      <property name="&lt;Super&gt;2" type="string" value="workspace_2_key"/>
      <property name="&lt;Super&gt;3" type="string" value="workspace_3_key"/>
      <property name="&lt;Super&gt;4" type="string" value="workspace_4_key"/>
      <property name="&lt;Super&gt;5" type="string" value="workspace_5_key"/>
      <property name="&lt;Super&gt;6" type="string" value="workspace_6_key"/>
      <property name="&lt;Super&gt;7" type="string" value="workspace_7_key"/>
      <property name="&lt;Super&gt;Left" type="string" value="tile_left_key"/>
      <property name="&lt;Super&gt;Right" type="string" value="tile_right_key"/>
      <property name="&lt;Super&gt;Up" type="string" value="tile_up_key"/>
      <property name="&lt;Super&gt;Down" type="string" value="tile_down_key"/>
    </property>
  </property>
</channel>
EOF

# Notification daemon: quiet defaults for a research workstation — short
# display time, top-right position (below the panel), no persistent history
# clutter.
cat << 'EOF' > /etc/xdg/xfce4/xfconf/xfce-perchannel-xml/xfce4-notifyd.xml
<?xml version="1.0" encoding="UTF-8"?>
<channel name="xfce4-notifyd" version="1.0">
  <property name="theme" type="string" value="Default"/>
  <property name="notify-location" type="int" value="2"/>
  <property name="expire-timeout" type="int" value="4"/>
  <property name="do-fadeout" type="bool" value="true"/>
  <property name="do-slideout" type="bool" value="true"/>
  <property name="log-level" type="int" value="0"/>
</channel>
EOF

# Copy all system XFCE configurations to /etc/skel/.config/xfce4/xfconf/xfce-perchannel-xml
mkdir -p /etc/skel/.config/xfce4/xfconf/xfce-perchannel-xml
cp -r /etc/xdg/xfce4/xfconf/xfce-perchannel-xml/*.xml /etc/skel/.config/xfce4/xfconf/xfce-perchannel-xml/

# Pre-configure Whisker Menu favorites, layout dimensions, and panel properties
mkdir -p /etc/skel/.config/xfce4/panel/launcher-6 \
         /etc/skel/.config/xfce4/panel/launcher-7 \
         /etc/skel/.config/xfce4/panel/launcher-8 \
         /etc/skel/.config/xfce4/panel/launcher-9 \
         /etc/skel/.config/xfce4/panel/launcher-10 \
         /etc/skel/.config/xfce4/panel/launcher-11 \
         /etc/skel/.config/xfce4/panel/launcher-12 \
         /etc/skel/.config/xfce4/panel/launcher-13

cat << 'EOF' > /etc/skel/.config/xfce4/panel/whiskermenu-1.rc
favorites=net.tenshu.Terminator.desktop,telcosec-tmux-redteam.desktop,telcosec-prolabs.desktop,telcosec-academy.desktop,wireshark-mon.desktop,gqrx.desktop,pysim-shell.desktop,sigploit.desktop,firmwire.desktop,diafuzzer.desktop,ueransim-gnb.desktop,5ghoul-fuzzer.desktop,falcon.desktop,telcosec-ran-status.desktop,sdr-info.desktop,telcosec-docs.desktop
button-title=TelcoChisel
button-icon=telcosec
show-button-title=true
show-button-icon=true
category-icon-size=2
item-icon-size=2
menu-width=560
menu-height=620
menu-opacity=98
position-search-alternate=true
stay-on-focus-out=false
EOF
# ─── Whisker Menu 11-Domain XDG Applications Menu ────────────────────────────
# Creates a custom .menu file that groups all TelcoSec desktop entries into
# the 11 canonical security domains visible in the Whisker Menu category pane.
# Each <Category> here must match a Categories= entry in the .desktop files.
echo "Deploying TelcoSec 11-domain XDG applications menu..."
mkdir -p /etc/xdg/menus /usr/share/desktop-directories

cat << 'EOF' > /etc/xdg/menus/telcosec-applications.menu
<!DOCTYPE Menu PUBLIC "-//freedesktop//DTD Menu 1.0//EN"
  "http://www.freedesktop.org/standards/menu-spec/menu-1.0.dtd">
<Menu>
  <Name>Applications</Name>
  <MergeFile type="parent">/etc/xdg/menus/applications.menu</MergeFile>

  <!-- ══ 01. SDR & Spectrum Analysis ═══════════════════════════════════════ -->
  <Menu>
    <Name>01-SDR-Spectrum</Name>
    <Directory>telcosec-01-sdr.directory</Directory>
    <Include><Category>TelcoSec-SDR</Category></Include>
  </Menu>

  <!-- ══ 02. GSM / 2G Cellular ════════════════════════════════════════════ -->
  <Menu>
    <Name>02-GSM-2G</Name>
    <Directory>telcosec-02-gsm.directory</Directory>
    <Include><Category>TelcoSec-GSM</Category></Include>
  </Menu>

  <!-- ══ 03. LTE / 4G Cellular ════════════════════════════════════════════ -->
  <Menu>
    <Name>03-LTE-4G</Name>
    <Directory>telcosec-03-lte.directory</Directory>
    <Include><Category>TelcoSec-LTE</Category></Include>
  </Menu>

  <!-- ══ 04. 5G NR & O-RAN ════════════════════════════════════════════════ -->
  <Menu>
    <Name>04-5GNR-ORAN</Name>
    <Directory>telcosec-04-5g.directory</Directory>
    <Include><Category>TelcoSec-5G</Category></Include>
  </Menu>

  <!-- ══ 05. Baseband & Firmware ══════════════════════════════════════════ -->
  <Menu>
    <Name>05-Baseband-Firmware</Name>
    <Directory>telcosec-05-baseband.directory</Directory>
    <Include><Category>TelcoSec-Baseband</Category></Include>
  </Menu>

  <!-- ══ 06. SIM / Smartcard Security ════════════════════════════════════ -->
  <Menu>
    <Name>06-SIM-Smartcard</Name>
    <Directory>telcosec-06-sim.directory</Directory>
    <Include><Category>TelcoSec-SIM</Category></Include>
  </Menu>

  <!-- ══ 07. Protocol Fuzzing & Exploit ═══════════════════════════════════ -->
  <Menu>
    <Name>07-Fuzzing-Exploit</Name>
    <Directory>telcosec-07-fuzzing.directory</Directory>
    <Include><Category>TelcoSec-Fuzzing</Category></Include>
  </Menu>

  <!-- ══ 08. Forensics & Evidence ════════════════════════════════════════ -->
  <Menu>
    <Name>08-Forensics-Evidence</Name>
    <Directory>telcosec-08-forensics.directory</Directory>
    <Include><Category>TelcoSec-Forensics</Category></Include>
  </Menu>

  <!-- ══ 09. Core Network & Packet Analysis ══════════════════════════════ -->
  <Menu>
    <Name>09-Core-Network</Name>
    <Directory>telcosec-09-core.directory</Directory>
    <Include><Category>TelcoSec-Core</Category></Include>
  </Menu>

  <!-- ══ 10. ProLabs & Academy ════════════════════════════════════════════ -->
  <Menu>
    <Name>10-ProLabs-Academy</Name>
    <Directory>telcosec-10-prolabs.directory</Directory>
    <Include><Category>TelcoSec-ProLabs</Category></Include>
  </Menu>

  <!-- ══ 11. TelcoSec Tools (catch-all) ═══════════════════════════════════ -->
  <Menu>
    <Name>11-TelcoSec-All</Name>
    <Directory>telcosec-11-all.directory</Directory>
    <Include><Category>TelcoSec-Tools</Category></Include>
    <Exclude>
      <Category>TelcoSec-SDR</Category>
      <Category>TelcoSec-GSM</Category>
      <Category>TelcoSec-LTE</Category>
      <Category>TelcoSec-5G</Category>
      <Category>TelcoSec-Baseband</Category>
      <Category>TelcoSec-SIM</Category>
      <Category>TelcoSec-Fuzzing</Category>
      <Category>TelcoSec-Forensics</Category>
      <Category>TelcoSec-Core</Category>
      <Category>TelcoSec-ProLabs</Category>
    </Exclude>
  </Menu>
</Menu>
EOF

# Write .directory files (icon + display name for each category)
for entry in \
  "telcosec-01-sdr.directory|📻 SDR & Spectrum Analysis|gqrx" \
  "telcosec-02-gsm.directory|📡 GSM / 2G Cellular|network-wireless" \
  "telcosec-03-lte.directory|📶 LTE / 4G Cellular|network-wireless-signal-excellent" \
  "telcosec-04-5g.directory|⚡ 5G NR & O-RAN|network-wireless-signal-excellent-symbolic" \
  "telcosec-05-baseband.directory|🔬 Baseband & Firmware|applications-engineering" \
  "telcosec-06-sim.directory|💳 SIM / Smartcard|smartcard" \
  "telcosec-07-fuzzing.directory|💥 Fuzzing & Exploit|security-high" \
  "telcosec-08-forensics.directory|🔍 Forensics & Evidence|document-properties" \
  "telcosec-09-core.directory|🌐 Core Network & Packets|network-wired" \
  "telcosec-10-prolabs.directory|🧪 ProLabs & Academy|applications-education" \
  "telcosec-11-all.directory|🛠️ TelcoSec Tools|telcosec"
do
  fname="${entry%%|*}"
  name="$(echo "$entry" | cut -d'|' -f2)"
  icon="$(echo "$entry" | cut -d'|' -f3)"
  cat << DIREOF > "/usr/share/desktop-directories/${fname}"
[Desktop Entry]
Version=1.0
Type=Directory
Name=${name}
Icon=${icon}
DIREOF
done

# Install the custom menu as the default for XFCE's applications
# xdg-menu reads XDG_MENU_PREFIX; we set it to 'telcosec-' via the file above
if [ -f /etc/xdg/menus/applications.menu ]; then
  cp /etc/xdg/menus/applications.menu /etc/xdg/menus/applications.menu.bak 2>/dev/null || true
fi
ln -sf /etc/xdg/menus/telcosec-applications.menu /etc/xdg/menus/xfce-applications.menu 2>/dev/null || \
  cp  /etc/xdg/menus/telcosec-applications.menu /etc/xdg/menus/xfce-applications.menu
# ─────────────────────────────────────────────────────────────────────────────

# Deploy panel launcher desktop entries
# Launcher 6: Terminator
cat << 'EOF' > /etc/skel/.config/xfce4/panel/launcher-6/net.tenshu.Terminator.desktop
[Desktop Entry]
Name=Terminator
Comment=Multiple terminals in one window
TryExec=terminator
Exec=terminator
Icon=terminator
Type=Application
Categories=GNOME;GTK;Utility;TerminalEmulator;System;
StartupNotify=true
X-Ubuntu-Gettext-Domain=terminator
EOF
cp /etc/skel/.config/xfce4/panel/launcher-6/net.tenshu.Terminator.desktop /etc/skel/.config/xfce4/panel/launcher-6/1.desktop

# Launcher 7: 4-Pane Operator Matrix
cat << 'EOF' > /etc/skel/.config/xfce4/panel/launcher-7/telcosec-tmux-redteam.desktop
[Desktop Entry]
Version=1.0
Type=Application
Name=TelcoSec 4-Pane Operator Matrix
Comment=Telecom Red Team Multi-Window Command & Control Operational Environment
Exec=telcosec-tmux-redteam
Icon=utilities-terminal
Terminal=false
Categories=TelcoSec-Tools;System;Utility;
EOF
cp /etc/skel/.config/xfce4/panel/launcher-7/telcosec-tmux-redteam.desktop /etc/skel/.config/xfce4/panel/launcher-7/1.desktop

# Launcher 8: TelcoSec ProLabs
cat << 'EOF' > /etc/skel/.config/xfce4/panel/launcher-8/telcosec-prolabs.desktop
[Desktop Entry]
Version=1.0
Type=Application
Name=TelcoSec ProLabs Cyber Range
Comment=Carrier Testbeds, 5G SA Pods, and Remote Telecom Cyber Ranges
Exec=telcosec-prolabs open
Icon=network-vpn
Terminal=false
Categories=TelcoSec-Tools;Network;Security;
EOF
cp /etc/skel/.config/xfce4/panel/launcher-8/telcosec-prolabs.desktop /etc/skel/.config/xfce4/panel/launcher-8/1.desktop

# Launcher 9: TelcoSec Academy
cat << 'EOF' > /etc/skel/.config/xfce4/panel/launcher-9/telcosec-academy.desktop
[Desktop Entry]
Version=1.0
Type=Application
Name=TelcoSec Academy Practice Labs
Comment=Telecom Security Practice Lessons, Course Modules, and Exercise Datasets
Exec=telcosec-academy open
Icon=applications-education
Terminal=false
Categories=TelcoSec-Tools;Education;Security;
EOF
cp /etc/skel/.config/xfce4/panel/launcher-9/telcosec-academy.desktop /etc/skel/.config/xfce4/panel/launcher-9/1.desktop

# Launcher 10: Wireshark GSMTAP
cat << 'EOF' > /etc/skel/.config/xfce4/panel/launcher-10/wireshark-mon.desktop
[Desktop Entry]
Version=1.0
Type=Application
Name=Wireshark (GSMTAP Dissection)
Comment=Cellular Traffic Analysis with Custom GSMTAP and 5G Dissectors
Exec=wireshark -k -Y gsmtap
Icon=wireshark
Terminal=false
Categories=TelcoSec-Tools;06-Dissection-Capture;
EOF
cp /etc/skel/.config/xfce4/panel/launcher-10/wireshark-mon.desktop /etc/skel/.config/xfce4/panel/launcher-10/1.desktop

# Launcher 11: Gqrx SDR
cat << 'EOF' > /etc/skel/.config/xfce4/panel/launcher-11/gqrx.desktop
[Desktop Entry]
Version=1.0
Type=Application
Name=Gqrx SDR
Comment=Software Defined Radio Receiver & Spectrum Waterfall
Exec=gqrx
Icon=gqrx
Terminal=false
Categories=TelcoSec-Tools;01-RF-SDR-Hardware;
EOF
cp /etc/skel/.config/xfce4/panel/launcher-11/gqrx.desktop /etc/skel/.config/xfce4/panel/launcher-11/1.desktop

# Launcher 12: pySim-shell
cat << 'EOF' > /etc/skel/.config/xfce4/panel/launcher-12/pysim-shell.desktop
[Desktop Entry]
Version=1.0
Type=Application
Name=pySim Shell
Comment=SIM/USIM/ISIM Smartcard Programming & APDU Explorer
Exec=terminator -e "pysim-shell"
Icon=smartcard
Terminal=false
Categories=TelcoSec-Tools;08-SIM-Smartcard;
EOF
cp /etc/skel/.config/xfce4/panel/launcher-12/pysim-shell.desktop /etc/skel/.config/xfce4/panel/launcher-12/1.desktop

# Launcher 13: TelcoSec Documentation
cat << 'EOF' > /etc/skel/.config/xfce4/panel/launcher-13/telcosec-docs.desktop
[Desktop Entry]
Version=1.0
Type=Application
Name=TelcoSec Documentation
Comment=Offline Telecom Security OS Documentation and Tool Reference
Exec=firefox file:///usr/share/doc/telcosec/index.html
Icon=help-browser
Terminal=false
Categories=TelcoSec-Tools;
EOF
cp /etc/skel/.config/xfce4/panel/launcher-13/telcosec-docs.desktop /etc/skel/.config/xfce4/panel/launcher-13/1.desktop

# Deploy Thunar Custom Actions (uca.xml)
echo "Deploying Thunar custom actions (Wireshark GSMTAP, Inspectrum I/Q, pySim APDU, SHA256)..."
mkdir -p /etc/skel/.config/Thunar /etc/xdg/Thunar
cat << 'EOF' > /etc/skel/.config/Thunar/uca.xml
<?xml version="1.0" encoding="UTF-8"?>
<actions>
<action>
	<icon>utilities-terminal</icon>
	<name>Open Zsh Terminal Here</name>
	<submenu></submenu>
	<unique-id>1700000000000000-1</unique-id>
	<command>terminator --working-directory=%f</command>
	<description>Open high-performance Zsh terminal emulator in current folder</description>
	<range></range>
	<patterns>*</patterns>
	<directories/>
</action>
<action>
	<icon>wireshark</icon>
	<name>Analyze GSMTAP / Cellular PCAP (Wireshark)</name>
	<submenu></submenu>
	<unique-id>1700000000000000-2</unique-id>
	<command>wireshark -k -Y gsmtap %f</command>
	<description>Open cellular packet capture with GSMTAP protocol dissections</description>
	<range></range>
	<patterns>*.pcap;*.pcapng;*.cap;*.pcap.gz</patterns>
	<other-files/>
</action>
<action>
	<icon>gqrx</icon>
	<name>Inspect RF I/Q Spectrum (Inspectrum)</name>
	<submenu></submenu>
	<unique-id>1700000000000000-3</unique-id>
	<command>inspectrum %f</command>
	<description>Analyze raw SDR I/Q recording spectrum and demodulate bursts</description>
	<range></range>
	<patterns>*.cfile;*.iq;*.raw;*.bin;*.cs8;*.cs16;*.cf32</patterns>
	<other-files/>
</action>
<action>
	<icon>smartcard</icon>
	<name>Execute APDU Script (pySim-shell)</name>
	<submenu></submenu>
	<unique-id>1700000000000000-4</unique-id>
	<command>terminator -e "pysim-shell --script %f; echo ''; read -p 'Execution complete. Press enter...'"</command>
	<description>Execute SIM/USIM smartcard APDU batch sequence</description>
	<range></range>
	<patterns>*.apdu;*.pysim;*.sim;*.txt</patterns>
	<other-files/>
</action>
<action>
	<icon>document-properties</icon>
	<name>Compute SHA-256 Forensic Hash</name>
	<submenu></submenu>
	<unique-id>1700000000000000-5</unique-id>
	<command>terminator -e "echo '=== SHA-256 Forensic Checksum ==='; echo 'File: %n'; echo ''; sha256sum %f; echo ''; read -p 'Press enter to exit...'"</command>
	<description>Generate SHA-256 hash for forensic evidence chain-of-custody</description>
	<range></range>
	<patterns>*</patterns>
	<other-files/>
	<text-files/>
</action>
<action>
	<icon>wireshark</icon>
	<name>Extract IMSI / TMSI Identifiers (SCAT)</name>
	<submenu></submenu>
	<unique-id>1700000000000000-6</unique-id>
	<command>terminator -e "echo '=== IMSI/TMSI Extraction via SCAT ==='; scat -t qc -i %f -o /tmp/scat-extract.pcap 2>&amp;1; echo ''; echo 'Output: /tmp/scat-extract.pcap'; read -p 'Press enter to exit...'"</command>
	<description>Extract IMSI, TMSI, and subscriber identifiers from Qualcomm DIAG capture using SCAT</description>
	<range></range>
	<patterns>*.pcap;*.pcapng;*.cap;*.qmdl;*.hdf;*.pcap.gz</patterns>
	<other-files/>
</action>
<action>
	<icon>network-wired</icon>
	<name>Filter 5G NAS Messages (TShark)</name>
	<submenu></submenu>
	<unique-id>1700000000000000-7</unique-id>
	<command>terminator -e "echo '=== 5G NAS Registration &amp; Authentication Messages ==='; tshark -r %f -Y 'nas-5gs or ngap or sctp' -V 2>/dev/null | head -200; echo ''; read -p 'Press enter to exit...'"</command>
	<description>Decode and display 5G NAS, NGAP, and SCTP signaling messages from PCAP capture</description>
	<range></range>
	<patterns>*.pcap;*.pcapng;*.cap</patterns>
	<other-files/>
</action>
<action>
	<icon>media-record</icon>
	<name>Demodulate RF Signal (Universal Radio Hacker)</name>
	<submenu></submenu>
	<unique-id>1700000000000000-8</unique-id>
	<command>urh %f</command>
	<description>Open RF I/Q recording in Universal Radio Hacker for protocol analysis and demodulation</description>
	<range></range>
	<patterns>*.cfile;*.iq;*.raw;*.bin;*.cs8;*.cs16;*.cf32;*.wav</patterns>
	<other-files/>
</action>
</actions>
EOF
cp /etc/skel/.config/Thunar/uca.xml /etc/xdg/Thunar/uca.xml

# Deploy Terminator shortcut to Desktop
echo "Deploying Terminator desktop shortcut..."
mkdir -p /etc/skel/Desktop
cp /etc/skel/.config/xfce4/panel/launcher-6/net.tenshu.Terminator.desktop /etc/skel/Desktop/terminator.desktop
chmod 755 /etc/skel/Desktop/terminator.desktop
gio set -t string /etc/skel/Desktop/terminator.desktop metadata::trusted true 2>/dev/null || true

# Pre-configure Terminator Developer Palette & Behavior
mkdir -p /etc/skel/.config/terminator
cat << 'EOF' > /etc/skel/.config/terminator/config
[global_config]
  title_transmit_fg_color = "#00ffd5"
  title_transmit_bg_color = "#0e121a"
  title_receive_fg_color = "#ffffff"
  title_receive_bg_color = "#1f2430"
  title_inactive_fg_color = "#8b949e"
  title_inactive_bg_color = "#0e121a"
  title_use_system_font = False
  title_font = "Ubuntu Mono Bold 11"
  focus = "mouse"
  handle_size = 2
  window_state = "maximise"
  tab_position = "bottom"
  borderless = False
[keybindings]
  split_horiz = "<Primary><Shift>e"
  split_vert = "<Primary><Shift>o"
  close_term = "<Primary><Shift>w"
  toggle_fullscreen = "F11"
  search = "<Primary><Shift>f"
[profiles]
  [[default]]
    background_color = "#0e121a"
    foreground_color = "#e6edf3"
    cursor_color = "#00ffd5"
    cursor_color_default = False
    cursor_shape = "block"
    cursor_blink = True
    font = "Ubuntu Mono 13"
    use_system_font = False
    show_titlebar = True
    scrollbar_position = "hidden"
    scrollback_lines = 20000
    copy_on_selection = True
    palette = "#0e121a:#ff4466:#26d464:#f5aa35:#388bfd:#bc8cff:#00ffd5:#e6edf3:#484f58:#ff7b72:#7ee787:#e8921e:#79c0ff:#d2a8ff:#56d4dd:#ffffff"
EOF

# Optimize Tumbler Thumbnailer (Prevent USB I/O lockups on large dumps and captures)
sudo mkdir -p /etc/xdg/tumbler
cat << 'EOF' | sudo tee /etc/xdg/tumbler/tumbler.rc
[JPEGThumbnailer]
Disabled=false
Priority=1
Locations=
MaxFileSize=52428800

[PDFThumbnailer]
Disabled=false
Priority=1
Locations=
MaxFileSize=52428800
EOF

if [ -d /home/telcosec ]; then
  mkdir -p /home/telcosec/.config/xfce4/xfconf/xfce-perchannel-xml \
           /home/telcosec/.config/xfce4/panel \
           /home/telcosec/.config/gtk-3.0 \
           /home/telcosec/.config/terminator \
           /home/telcosec/.config/Thunar \
           /home/telcosec/Desktop
  cp /etc/xdg/xfce4/xfconf/xfce-perchannel-xml/*.xml \
     /home/telcosec/.config/xfce4/xfconf/xfce-perchannel-xml/ 2>/dev/null || true
  cp /etc/skel/.config/xfce4/panel/whiskermenu-1.rc \
     /home/telcosec/.config/xfce4/panel/ 2>/dev/null || true
  cp -r /etc/skel/.config/xfce4/panel/launcher-* \
     /home/telcosec/.config/xfce4/panel/ 2>/dev/null || true
  cp /etc/skel/.config/Thunar/uca.xml \
     /home/telcosec/.config/Thunar/uca.xml 2>/dev/null || true
  cp /etc/skel/.config/gtk-3.0/settings.ini \
     /home/telcosec/.config/gtk-3.0/settings.ini 2>/dev/null || true
  cp /etc/skel/.config/terminator/config \
     /home/telcosec/.config/terminator/config 2>/dev/null || true
  cp /etc/skel/Desktop/terminator.desktop \
     /home/telcosec/Desktop/ 2>/dev/null || true
  chmod 755 /home/telcosec/Desktop/*.desktop 2>/dev/null || true
  gio set -t string /home/telcosec/Desktop/*.desktop metadata::trusted true 2>/dev/null || true
  chown -R telcosec:telcosec /home/telcosec/.config /home/telcosec/Desktop
fi

# 1b. Tactical Desktop Conky HUD & RF Telemetry Engine
echo "Configuring Tactical Desktop Conky HUD and telemetry..."
mkdir -p /etc/skel/.config/conky /etc/xdg/autostart /usr/share/applications

cat << 'EOF' > /etc/skel/.config/conky/conky.conf
-- =============================================================================
-- TelcoChisel OS — Tactical Desktop HUD Configuration (Cyberpunk Dark)
-- =============================================================================

conky.config = {
    alignment = 'top_right',
    gap_x = 24,
    gap_y = 48,
    minimum_width = 380,
    maximum_width = 420,
    update_interval = 2.0,
    double_buffer = true,
    no_buffers = true,
    text_buffer_size = 2048,

    own_window = true,
    own_window_type = 'desktop',
    own_window_transparent = false,
    own_window_argb_visual = true,
    own_window_argb_value = 215,
    own_window_colour = '0a0e17',
    own_window_hints = 'undecorated,below,sticky,skip_taskbar,skip_pager',

    border_inner_margin = 14,
    border_outer_margin = 0,
    border_width = 1,
    draw_borders = true,
    draw_graph_borders = true,
    draw_outline = false,
    draw_shades = false,

    use_xft = true,
    font = 'Fira Code:size=9',
    xftalpha = 1.0,
    uppercase = false,

    default_color = 'e6edf3',
    color0 = '21262d', -- Subtle border
    color1 = '00ffd5', -- Cyan/Teal primary accent
    color2 = 'e8921e', -- Electric Amber telemetry
    color3 = '8b949e', -- Muted gray
    color4 = '00f2ff', -- Bright focus cyan
    color5 = 'ff4466', -- Alert coral
};

conky.text = [[
${color1}${font Fira Code:bold:size=10}📡 TELCOCHISEL OS — TACTICAL HUD${font}${alignr}${color3}v2026.2
${color0}${hr 1}
${color3}Host:${color} ${nodename}${alignr}${color3}Uptime:${color} ${uptime_short}
${color3}Kernel:${color} ${kernel} ${alignr}${color1}[Low-Latency]${color}
${color3}UTC Time:${color} ${utime %H:%M:%S}${alignr}${color3}Local:${color} ${time %H:%M}

${color1}${font Fira Code:bold:size=9}📻 RF HARDWARE & TRANSCEIVERS${font}${color}
${color0}${hr 1}
${color3}SDR Probes:${color}
${color}${execi 3 /usr/local/bin/telcosec-hud-sdr}${color}
${color3}USBFS Buffer:${color} ${execi 5 cat /sys/module/usbcore/parameters/usbfs_memory_mb 2>/dev/null || echo "N/A"} MB ${alignr}${color1}[1000MB Target]${color}

${color1}${font Fira Code:bold:size=9}⚡ CELLULAR & NETWORK INTERFACES${font}${color}
${color0}${hr 1}
${if_existing /sys/class/net/ogstun}${color2}ogstun (5G Core):${color} ${addr ogstun}${alignr}${color1}[UP]${color}${else}${color3}ogstun (5G Core): [Standby]${color}${endif}
${if_existing /sys/class/net/mon0}${color2}mon0 (GSMTAP):${color} Mon Mode Active${alignr}${color1}[SNIFF]${color}${endif}
${if_existing /sys/class/net/tun-prolabs}${color2}prolabs (Range):${color} ${addr tun-prolabs}${alignr}${color1}[CONNECTED]${color}${endif}
${if_existing /sys/class/net/wg0}${color2}wg0 (WireGuard):${color} ${addr wg0}${alignr}${color1}[TUNNEL]${color}${endif}
${if_existing /sys/class/net/tun0}${color2}tun0 (OpenVPN):${color} ${addr tun0}${alignr}${color1}[TUNNEL]${color}${endif}
${color3}Primary Net:${color} ${alignr}${color}${addr eth0}${color}${addr ens160}${color}${addr wlan0}
${color3}Bandwidth:${color} Down: ${color1}${downspeedf eth0}${downspeedf ens160}${downspeedf wlan0} KB/s${color} | Up: ${color2}${upspeedf eth0}${upspeedf ens160}${upspeedf wlan0} KB/s${color}

${color1}${font Fira Code:bold:size=9}🧠 SYSTEM & ZERO-DROP ENGINE${font}${color}
${color0}${hr 1}
${color3}CPU Load:${color} ${cpu cpu0}% ${color1}${cpubar 6,140 cpu0}${alignr}${color}${freq_g} GHz
${color3}Memory:${color}   ${mem} / ${memmax} (${memperc}%)
${color1}${membar 6}${color}
${color3}Root Disk:${color} ${fs_used /} / ${fs_size /} (${fs_used_perc /}%) ${alignr}${color1}[SSD Trim]${color}

${color2}${font Fira Code:bold:size=9}🎯 TELECOM FREQUENCY CHEATSHEET${font}${color}
${color0}${hr 1}
${color4}GSM-900${color}:  UL 890-915 MHz   | DL 935-960 MHz
${color4}DCS-1800${color}: UL 1710-1785 MHz | DL 1805-1880 MHz
${color4}LTE B3${color}:   UL 1710-1785 MHz | DL 1805-1880 MHz
${color4}LTE B20${color}:  UL 832-862 MHz   | DL 791-821 MHz
${color4}5G n78${color}:   3300 - 3800 MHz (C-Band TDD)

${color1}${font Fira Code:bold:size=9}⌨️ TACTICAL OPERATOR SHORTCUTS${font}${color}
${color0}${hr 1}
${color4}Super+Return${color}: Terminator     ${color4}Super+Shift+W${color}: Wireshark
${color4}Super+Shift+T${color}: 4-Pane Matrix ${color4}Super+Shift+G${color}: Gqrx SDR
${color4}Super+Shift+S${color}: pySim-shell  ${color4}Super+Shift+H${color}: Toggle HUD
${color4}Super+1..7${color}:   Workspaces     ${color4}Super+F1..F6${color}:  Diag Doctor
]];
EOF

# Deploy SDR Hardware Telemetry Helper for HUD
cat << 'EOF' > /usr/local/bin/telcosec-hud-sdr
#!/bin/bash
# =============================================================================
# telcosec-hud-sdr — Live Conky SDR Hardware Telemetry Helper
# =============================================================================
found=0

if lsusb 2>/dev/null | grep -qi "2500:0020"; then
    echo "  • USRP B200/B210 (FX3 Bootloader - 2500:0020)"
    found=1
elif lsusb 2>/dev/null | grep -qi "2500:0021"; then
    echo "  • USRP B200/B210 (Operational - USB 3.0)"
    found=1
elif lsusb 2>/dev/null | grep -qi "2500"; then
    echo "  • Ettus Research USRP Transceiver"
    found=1
fi

if lsusb 2>/dev/null | grep -qi "1d50:6089\|HackRF"; then
    echo "  • HackRF One (1d50:6089)"
    found=1
fi

if lsusb 2>/dev/null | grep -qi "BladeRF\|2cf0:5246"; then
    echo "  • Nuand BladeRF 2.0 micro (2cf0:5246)"
    found=1
fi

if lsusb 2>/dev/null | grep -qi "LimeSDR\|0403:601f"; then
    echo "  • MyriadRF LimeSDR-USB (0403:601f)"
    found=1
fi

if lsusb 2>/dev/null | grep -qi "RTL2838\|RTL2832"; then
    echo "  • RTL-SDR Receiver (R820T2/R828D)"
    found=1
fi

if lsusb 2>/dev/null | grep -qi "1d50:60e3\|simtrace"; then
    echo "  • Sysmocom SIMtrace 2 Smartcard Sniffer"
    found=1
fi

if [ $found -eq 0 ]; then
    echo "  • [No SDR connected — Plug USRP/HackRF/BladeRF]"
fi
EOF
chmod 755 /usr/local/bin/telcosec-hud-sdr

# Deploy Tactical HUD Toggle Utility
cat << 'EOF' > /usr/local/bin/telcosec-toggle-hud
#!/bin/bash
# =============================================================================
# telcosec-toggle-hud — Show/Hide Tactical Desktop Conky HUD
# =============================================================================
if pgrep -x conky >/dev/null 2>&1; then
    killall conky
    notify-send -u low -i preferences-desktop-display "Tactical HUD" "Desktop HUD Hidden" 2>/dev/null || true
else
    conky -c ~/.config/conky/conky.conf 2>/dev/null || conky -c /etc/skel/.config/conky/conky.conf &
    notify-send -u low -i preferences-desktop-display "Tactical HUD" "Desktop HUD Active" 2>/dev/null || true
fi
EOF
chmod 755 /usr/local/bin/telcosec-toggle-hud

# ─── Genmon Panel Telemetry Scripts ──────────────────────────────────────────
# Three xfce4-genmon-plugin scripts for live panel indicators.
# Output is a single-line genmon XML fragment: <txt>LABEL</txt><click>CMD</click>
# Each script is called every 3s by genmon; must complete in <1s.
# ─────────────────────────────────────────────────────────────────────────────

# Genmon 18 ▸ SDR Hardware Probe
# Shows first detected SDR transceiver in panel; click opens full probe terminal.
cat << 'GENMON_SDR' > /usr/local/bin/telcosec-genmon-sdr
#!/bin/bash
# =============================================================================
# telcosec-genmon-sdr — XFCE Panel Live SDR Hardware Indicator (genmon)
# Probes USB bus for known SDR VID:PIDs and emits a colour-coded genmon label.
# Output: single-line genmon XML: <txt>…</txt><click>…</click><tool>…</tool>
# =============================================================================

# Detected transceivers list (max 1 shown inline, rest in tooltip)
declare -a DETECTED=()
TOOLTIP=""

# USRP B200/B210 — FX3 USB bootloader (pre-firmware) or post-firmware ID
if lsusb 2>/dev/null | grep -qiE "04b4:00f3|2500:0020|2500:0022|Ettus"; then
    DETECTED+=("USRP")
    TOOLTIP+="• Ettus USRP B200/B210\n"
fi
# HackRF One
if lsusb 2>/dev/null | grep -qiE "1d50:6089|HackRF"; then
    DETECTED+=("HackRF")
    TOOLTIP+="• HackRF One (1d50:6089)\n"
fi
# Nuand BladeRF 2.0
if lsusb 2>/dev/null | grep -qiE "2cf0:5246|BladeRF"; then
    DETECTED+=("BladeRF")
    TOOLTIP+="• Nuand BladeRF 2.0 micro\n"
fi
# MyriadRF LimeSDR
if lsusb 2>/dev/null | grep -qiE "0403:601f|LimeSDR"; then
    DETECTED+=("LimeSDR")
    TOOLTIP+="• MyriadRF LimeSDR-USB\n"
fi
# RTL-SDR
if lsusb 2>/dev/null | grep -qiE "RTL2838|RTL2832"; then
    DETECTED+=("RTL-SDR")
    TOOLTIP+="• RTL-SDR (R820T2/R828D)\n"
fi
# SIMtrace 2
if lsusb 2>/dev/null | grep -qiE "1d50:60e3|simtrace"; then
    DETECTED+=("SIMtrace")
    TOOLTIP+="• Sysmocom SIMtrace 2\n"
fi

COUNT="${#DETECTED[@]}"
if [ "$COUNT" -eq 0 ]; then
    # No SDR — amber warning
    printf '<txt><span foreground="#f5aa35" weight="bold">📻 NO-SDR</span></txt>'
    printf '<click>terminator -e "lsusb; echo; echo No SDR detected. Plug USRP/HackRF/BladeRF/RTL-SDR; read -p Press-enter..."</click>'
    printf '<tool>No SDR transceiver detected on USB bus</tool>'
elif [ "$COUNT" -eq 1 ]; then
    printf '<txt><span foreground="#00ffd5" weight="bold">📻 %s</span></txt>' "${DETECTED[0]}"
    printf '<click>terminator -e "/usr/local/bin/telcosec-hud-sdr; read -p Press-enter..."</click>'
    printf '<tool>SDR Active: %s\nClick for full hardware probe</tool>' "${DETECTED[0]}"
else
    printf '<txt><span foreground="#00ffd5" weight="bold">📻 %dx SDR</span></txt>' "$COUNT"
    printf '<click>terminator -e "/usr/local/bin/telcosec-hud-sdr; read -p Press-enter..."</click>'
    printf '<tool>%d SDR transceivers detected:\n%s\nClick for full hardware probe</tool>' "$COUNT" "$TOOLTIP"
fi
GENMON_SDR
chmod 755 /usr/local/bin/telcosec-genmon-sdr

# Genmon 19 ▸ 5G Core & Cellular Stack Status
# Shows Open5GS/srsRAN running state; click opens journalctl for open5gs-smfd.
cat << 'GENMON_CORE' > /usr/local/bin/telcosec-genmon-core
#!/bin/bash
# =============================================================================
# telcosec-genmon-core — XFCE Panel 5G/LTE Core Network Status (genmon)
# Checks for active Open5GS, srsRAN, UERANSIM, OsmocomBB and OGS processes.
# =============================================================================

declare -a ACTIVE=()

# Open5GS AMF (5G) or MME (4G)
if pgrep -x open5gs-amfd >/dev/null 2>&1; then
    ACTIVE+=("5GC")
elif pgrep -x open5gs-mmed >/dev/null 2>&1; then
    ACTIVE+=("EPC")
fi
# srsRAN gNB or eNB
if pgrep -x gnb >/dev/null 2>&1 || pgrep -x srsenb >/dev/null 2>&1; then
    ACTIVE+=("gNB")
fi
# UERANSIM gNB
if pgrep -x nr-gnb >/dev/null 2>&1; then
    ACTIVE+=("UERAN")
fi
# UERANSIM UE
if pgrep -x nr-ue >/dev/null 2>&1; then
    ACTIVE+=("UE")
fi
# OsmocomBB
if pgrep -x osmocon >/dev/null 2>&1; then
    ACTIVE+=("OsmoBB")
fi
# OGS TUN interface presence (ogstun = 5G core data plane active)
if ip link show ogstun >/dev/null 2>&1; then
    ACTIVE+=("ogstun↑")
fi

COUNT="${#ACTIVE[@]}"
if [ "$COUNT" -eq 0 ]; then
    printf '<txt><span foreground="#484f58" weight="bold">⚡ CORE:OFF</span></txt>'
    printf '<click>terminator -e "systemctl status open5gs-amfd open5gs-mmed 2>/dev/null || echo No 5G/LTE core running; read -p Press-enter..."</click>'
    printf '<tool>No 5G/LTE core stack running\nServices: open5gs, srsRAN, UERANSIM, OsmocomBB</tool>'
else
    LABEL=$(IFS='+'; echo "${ACTIVE[*]}")
    printf '<txt><span foreground="#26d464" weight="bold">⚡ %s</span></txt>' "$LABEL"
    printf '<click>terminator -e "journalctl -u open5gs-amfd -u open5gs-smfd -n 50 --no-pager 2>/dev/null; read -p Press-enter..."</click>'
    printf '<tool>Active 5G/LTE core processes: %s\nClick for Open5GS service logs</tool>' "$LABEL"
fi
GENMON_CORE
chmod 755 /usr/local/bin/telcosec-genmon-core

# Genmon 20 ▸ VPN / Tunnel / ProLabs Network Status
# Shows WireGuard, OpenVPN tun, ProLabs GRE, and monitor interfaces.
cat << 'GENMON_NET' > /usr/local/bin/telcosec-genmon-net
#!/bin/bash
# =============================================================================
# telcosec-genmon-net — XFCE Panel Tunnel/VPN/Monitor Interface Status (genmon)
# Checks for active WireGuard, OpenVPN, ProLabs GRE, and RF monitor interfaces.
# =============================================================================

declare -a TUNNELS=()

# WireGuard (wg0, wg-*)
if ip link show wg0 >/dev/null 2>&1; then
    TUNNELS+=("wg0")
elif ip link | grep -qE "^[0-9]+: wg[0-9]"; then
    WG=$(ip link | grep -oE "wg[0-9]+" | head -1)
    TUNNELS+=("$WG")
fi
# OpenVPN tunnel
if ip link | grep -qE "^[0-9]+: tun[0-9]"; then
    TUN=$(ip link | grep -oE "tun[0-9]+" | head -1)
    TUNNELS+=("$TUN")
fi
# ProLabs named tunnel
if ip link show tun-prolabs >/dev/null 2>&1; then
    TUNNELS+=("ProLabs")
fi
# RF Monitor mode interface (mon0, wlan*mon)
if ip link | grep -qE "^[0-9]+: (mon[0-9]+|wlan[0-9]+mon)"; then
    MON=$(ip link | grep -oE "(mon[0-9]+|wlan[0-9]+mon)" | head -1)
    TUNNELS+=("${MON}↑")
fi

COUNT="${#TUNNELS[@]}"
if [ "$COUNT" -eq 0 ]; then
    printf '<txt><span foreground="#484f58" weight="bold">🔒 VPN:OFF</span></txt>'
    printf '<click>terminator -e "ip -br link show; echo; read -p Press-enter..."</click>'
    printf '<tool>No VPN tunnels or monitor interfaces active\nClick to show all network interfaces</tool>'
else
    LABEL=$(IFS=' '; echo "${TUNNELS[*]}")
    printf '<txt><span foreground="#bc8cff" weight="bold">🔒 %s</span></txt>' "$LABEL"
    printf '<click>terminator -e "ip -br addr show; echo; wg show 2>/dev/null; read -p Press-enter..."</click>'
    printf '<tool>Active tunnels: %s\nClick for interface detail + WireGuard status</tool>' "$LABEL"
fi
GENMON_NET
chmod 755 /usr/local/bin/telcosec-genmon-net

# Deploy Desktop Menu Entry for HUD Toggle
cat << 'EOF' > /usr/share/applications/telcosec-hud-toggle.desktop
[Desktop Entry]
Version=1.0
Type=Application
Name=Toggle Tactical Desktop HUD
Comment=Show or hide live RF SDR and cellular telemetry HUD
Exec=/usr/local/bin/telcosec-toggle-hud
Icon=preferences-desktop-display
Terminal=false
Categories=TelcoSec-Tools;System;Utility;
Keywords=hud;conky;telemetry;sdr;rf;status;
EOF
chmod 644 /usr/share/applications/telcosec-hud-toggle.desktop

# Deploy Autostart for Conky Tactical HUD
cat << 'EOF' > /etc/xdg/autostart/telcosec-conky.desktop
[Desktop Entry]
Type=Application
Name=TelcoSec Tactical Desktop HUD
Comment=Live SDR, Cellular, and RF telemetry desktop overlay
Exec=sh -c "sleep 3 && conky -c /etc/skel/.config/conky/conky.conf"
Terminal=false
StartupNotify=false
Hidden=false
OnlyShowIn=XFCE;
EOF
chmod 644 /etc/xdg/autostart/telcosec-conky.desktop

# Autostart: Picom GLX compositor for XFCE session
# Picom must start AFTER the XFCE compositor is disabled (xfwm4 use_compositing=false)
# to avoid double-compositing overhead. sleep 2 gives xfwm4 time to initialize.
cat << 'EOF' > /etc/xdg/autostart/telcosec-picom.desktop
[Desktop Entry]
Type=Application
Name=TelcoSec Picom GLX Compositor
Comment=Zero-drop GLX compositor for SDR FFT waterfall rendering
Exec=sh -c "sleep 2 && picom --config /etc/xdg/picom/picom.conf -b 2>/dev/null"
Terminal=false
StartupNotify=false
Hidden=false
OnlyShowIn=XFCE;
EOF
chmod 644 /etc/xdg/autostart/telcosec-picom.desktop

if [ -d /home/telcosec ]; then
  mkdir -p /home/telcosec/.config/conky
  cp /etc/skel/.config/conky/conky.conf /home/telcosec/.config/conky/conky.conf 2>/dev/null || true
  chown -R telcosec:telcosec /home/telcosec/.config/conky 2>/dev/null || true
fi

# ─── Thunar Sidebar Bookmarks + Telecom Directory Scaffold ───────────────────
echo "Deploying Thunar sidebar bookmarks and telecom directory scaffold..."

# Create canonical telecom working directories (skel + live user)
mkdir -p \
    /etc/skel/captures \
    /etc/skel/captures/pcap \
    /etc/skel/captures/iq \
    /etc/skel/captures/apdu \
    /etc/skel/captures/evidence

# Write placeholder READMEs so the directories are not empty in the live image
cat << 'EOF' > /etc/skel/captures/README.md
# TelcoChisel Captures Directory

| Subdirectory | Purpose |
| :--- | :--- |
| `pcap/` | Wireshark PCAP, PCAPNG — GSMTAP, SCTP, NGAP, Diameter |
| `iq/` | Raw SDR I/Q recordings (`.cfile`, `.cs8`, `.cf32`, `.iq`) |
| `apdu/` | SIM/USIM APDU batch scripts and pySim-shell session logs |
| `evidence/` | Chain-of-custody forensic artefacts with SHA-256 manifests |
EOF

# Telecom tool source tree (git repos land here via telcosec-pkg install)
mkdir -p /opt/telcosec
cat << 'EOF' > /opt/telcosec/README.md
# TelcoChisel Tool Source Tree
Installed via: telcosec-pkg install <tool>
EOF

# Telecom wordlists (MCC/MNC tables, APN databases, IMSI pools, carrier passwords)
mkdir -p /usr/share/wordlists/telecom
cat << 'EOF' > /usr/share/wordlists/telecom/README.md
# TelcoSec Telecom Wordlists
- mcc-mnc.csv — ITU-T E.212 MCC/MNC assignments
- apn-database.txt — Common APN names per carrier
- default-passwords.txt — Default device credentials (routers, eNBs)
EOF

# Write skel gtk-bookmarks for Thunar sidebar
mkdir -p /etc/skel/.config/gtk-3.0
cat << 'EOF' > /etc/skel/.config/gtk-3.0/bookmarks
file:///home/telcosec/captures 📦 Captures
file:///home/telcosec/captures/pcap 📡 PCAP Captures
file:///home/telcosec/captures/iq 📻 I/Q Recordings
file:///home/telcosec/captures/apdu 💳 APDU Scripts
file:///home/telcosec/captures/evidence 🔒 Evidence Chain
file:///opt/telcosec 🛠️ TelcoSec Tools
file:///usr/share/wordlists/telecom 📖 Telecom Wordlists
file:///usr/share/doc/telcosec 📚 Offline Documentation
EOF

if [ -d /home/telcosec ]; then
  mkdir -p /home/telcosec/captures/pcap \
            /home/telcosec/captures/iq \
            /home/telcosec/captures/apdu \
            /home/telcosec/captures/evidence
  cp /etc/skel/captures/README.md /home/telcosec/captures/README.md 2>/dev/null || true
  mkdir -p /home/telcosec/.config/gtk-3.0
  cp /etc/skel/.config/gtk-3.0/bookmarks /home/telcosec/.config/gtk-3.0/bookmarks 2>/dev/null || true
  chown -R telcosec:telcosec /home/telcosec/captures /home/telcosec/.config/gtk-3.0 2>/dev/null || true
fi
# ─────────────────────────────────────────────────────────────────────────────

# 2. Message of the Day (MOTD)
echo "Configuring MOTD..."
# Remove default Ubuntu dynamic MOTD scripts for a cleaner look
rm -f /etc/update-motd.d/10-help-text /etc/update-motd.d/50-motd-news

# Create a custom TelcoSec ASCII Art MOTD
cat << 'EOF' > /etc/update-motd.d/05-telcosec-logo
#!/bin/sh
echo "  _______    __           _____           "
echo " |__   __|  | |          / ____|          "
echo "    | | ___ | | ___ ___ | (___   ___  ___ "
echo "    | |/ _ \| |/ __/ _ \ \___ \ / _ \/ __|"
echo "    | |  __/| | (_| (_) |____) |  __/ (__ "
echo "    |_|\___||_|\___\___/|_____/ \___|\___|"
echo "                                          "
echo "      --- Telecom Security Platform ---   "
echo ""
EOF
chmod +x /etc/update-motd.d/05-telcosec-logo

# 3. Custom Rich Bash Prompt (Optimized, Simple, Zero-Lag, Single-Line Style)
echo "Configuring Global Bash Prompt..."
cat << 'PROMPTEOF' > /etc/profile.d/telcosec_prompt.sh
# TelcoSec simple prompt: user@host:dir $
__telcosec_ps1() {
  local EXIT="$?"
  
  # Colors mapped to ANSI standards
  local CY='\[\e[0;36m\]'      # user@host (ANSI Cyan)
  local W='\[\e[1;37m\]'       # path/directory (ANSI White)
  local R='\[\e[0m\]'          # reset
  local RED='\[\e[0;31m\]'     # error indicator (ANSI Red)
  
  # Exit status indicator for the prompt symbol ($ for user, # for root)
  local p_symbol="\$"
  if [ "$EXIT" -ne 0 ]; then
    p_symbol="${RED}${p_symbol}"
  else
    p_symbol="${CY}${p_symbol}"
  fi

  PS1="${CY}\u@\h${R}:${W}\w${R} ${p_symbol}${R} "
}
export PROMPT_COMMAND=__telcosec_ps1
PROMPTEOF
chmod +x /etc/profile.d/telcosec_prompt.sh

if ! grep -q "telcosec_prompt" /etc/bash.bashrc 2>/dev/null; then
  cat >> /etc/bash.bashrc << 'BASHRC'
# TelcoSec custom prompt (also loaded by /etc/profile.d/ for login shells)
if [ -f /etc/profile.d/telcosec_prompt.sh ]; then
    . /etc/profile.d/telcosec_prompt.sh
fi

# Enable fzf shell integration (Ctrl+r, Alt+c, etc.) if installed
if [ -f /usr/share/doc/fzf/examples/key-bindings.bash ]; then
    . /usr/share/doc/fzf/examples/key-bindings.bash
fi
if [ -f /usr/share/doc/fzf/examples/completion.bash ]; then
    . /usr/share/doc/fzf/examples/completion.bash
fi
BASHRC
fi

# 3b. High-Performance Zsh Shell Environment & Completions
echo "Configuring optimized Zsh environment and telecom completions..."
mkdir -p /etc/zsh /etc/skel /usr/share/zsh/site-functions /usr/share/zsh/vendor-completions

cat << 'EOF' > /etc/skel/.zshrc
# =============================================================================
# TelcoChisel OS — Optimized Zsh Configuration for Telecom Security
# =============================================================================

# 1. Environment & Path Loading
if [ -f /etc/profile.d/telcosec-env.sh ]; then
    . /etc/profile.d/telcosec-env.sh
fi
if [ -f /etc/profile.d/telcosec-aliases.sh ]; then
    . /etc/profile.d/telcosec-aliases.sh
fi

# 2. History Configuration
HISTFILE=~/.zsh_history
HISTSIZE=50000
SAVEHIST=50000
setopt SHARE_HISTORY          # Share command history across open terminals
setopt HIST_EXPIRE_DUPS_FIRST # Delete duplicate commands first when trimming
setopt HIST_IGNORE_DUPS       # Do not record an entry that was just recorded
setopt HIST_IGNORE_ALL_DUPS   # Delete old duplicate entry when new is added
setopt HIST_FIND_NO_DUPS      # Do not display duplicates when searching history
setopt HIST_IGNORE_SPACE      # Do not record lines starting with a space
setopt HIST_SAVE_NO_DUPS      # Do not write duplicate events to history file
setopt HIST_REDUCE_BLANKS     # Remove unnecessary blanks from history
setopt EXTENDED_HISTORY       # Record timestamps in history

# 3. Directory Navigation Options
setopt AUTO_CD                # Type directory name to cd into it
setopt AUTO_PUSHD             # Make cd push old directory onto directory stack
setopt PUSHD_IGNORE_DUPS      # Do not push duplicates onto directory stack
setopt PUSHD_SILENT           # Do not print directory stack after pushd/popd
setopt NO_BEEP                # Disable audio bell

# 4. Advanced Tab Completion System
autoload -Uz compinit
# Cache compinit dump once daily for instant shell startup
typeset -i updated_at=$(date +'%j' -r ~/.zcompdump 2>/dev/null || stat -f '%Sm' -t '%j' ~/.zcompdump 2>/dev/null || echo 0)
if [ $(date +'%j') != $updated_at ]; then
    compinit -i
else
    compinit -C -i
fi

zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}' 'r:|[._-]=* r:|=*' 'l:|=* r:|=*'
zstyle ':completion:*' list-colors "${(s.:.)LS_COLORS}"
zstyle ':completion:*' menu select
zstyle ':completion:*:descriptions' format '%F{cyan}-- %d --%f'
zstyle ':completion:*:processes' command 'ps -au$USER'

# 5. Fast, Zero-Lag Custom Prompt with Git Integration
autoload -Uz vcs_info
precmd_vcs_info() { vcs_info }
precmd_functions+=( precmd_vcs_info )
setopt prompt_subst
zstyle ':vcs_info:git:*' formats ' %F{242}(%F{green}%b%F{242})%f'

# Prompt layout: user@host:path (git_branch) $
PROMPT='%F{cyan}%n@%m%f:%F{white}%~%f${vcs_info_msg_0_} %(?.%F{cyan}%#%f.%F{red}%#%f) '
RPROMPT='%F{242}[%*]%f'

# 6. Keybindings (Standard Line Editing & History Substring Navigation)
bindkey -e
bindkey '^[[H' beginning-of-line
bindkey '^[[F' end-of-line
bindkey '^[[3~' delete-char
bindkey '^[[1;5C' forward-word
bindkey '^[[1;5D' backward-word
bindkey '^[[A' history-beginning-search-backward
bindkey '^[[B' history-beginning-search-forward

# 7. Zsh Plugins Integration (Autosuggestions & Syntax Highlighting)
if [ -f /usr/share/zsh-autosuggestions/zsh-autosuggestions.zsh ]; then
    source /usr/share/zsh-autosuggestions/zsh-autosuggestions.zsh
    ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE='fg=244'
    ZSH_AUTOSUGGEST_STRATEGY=(history completion)
fi

if [ -f /usr/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh ]; then
    source /usr/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
fi

# 8. FZF Integration (Fuzzy History & File Search)
if [ -f /usr/share/doc/fzf/examples/key-bindings.zsh ]; then
    source /usr/share/doc/fzf/examples/key-bindings.zsh
fi
if [ -f /usr/share/doc/fzf/examples/completion.zsh ]; then
    source /usr/share/doc/fzf/examples/completion.zsh
fi

# 9. Productive Telecom & System Aliases
alias ls='ls --color=auto'
alias ll='ls -lah --color=auto'
alias la='ls -A --color=auto'
alias l='ls -CF --color=auto'
alias grep='grep --color=auto'
alias egrep='egrep --color=auto'
alias fgrep='fgrep --color=auto'

command -v batcat >/dev/null 2>&1 && alias cat='batcat --paging=never'
command -v bat >/dev/null 2>&1 && alias cat='bat --paging=never'

alias ports='sudo netstat -tulpn'
alias update-sdr='sudo /usr/local/bin/uhd-download-images && sudo /usr/local/bin/LimeUtil --update'
alias yate-logs='tail -f /var/log/yate.log'
alias gsmtap='sudo tcpdump -i any -n "udp port 4729 or udp port 47290"'

alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'
EOF

# Copy Zsh configuration to /etc/zsh/zprofile and skeleton
cp /etc/skel/.zshrc /etc/zsh/zshrc 2>/dev/null || true

# Deploy telcosec CLI zsh completion if available
if [ -f /tmp/telcosec-cli/completions/_telcosec ]; then
    cp /tmp/telcosec-cli/completions/_telcosec /usr/share/zsh/site-functions/_telcosec
    cp /tmp/telcosec-cli/completions/_telcosec /usr/share/zsh/vendor-completions/_telcosec
    chmod 644 /usr/share/zsh/site-functions/_telcosec /usr/share/zsh/vendor-completions/_telcosec
fi

# Set default user shell to zsh if installed
if [ -f /bin/zsh ] || [ -f /usr/bin/zsh ]; then
    ZSH_PATH=$(which zsh)
    sed -i "s|SHELL=/bin/sh|SHELL=$ZSH_PATH|" /etc/default/useradd 2>/dev/null || true
    sed -i "s|DSHELL=/bin/bash|DSHELL=$ZSH_PATH|" /etc/adduser.conf 2>/dev/null || true
    chsh -s "$ZSH_PATH" telcosec 2>/dev/null || true
fi

if [ -d /home/telcosec ]; then
    cp /etc/skel/.zshrc /home/telcosec/.zshrc
    chown telcosec:telcosec /home/telcosec/.zshrc
fi

# 4. Deploy Local Documentation & Configure Firefox Policies
echo "Deploying local documentation..."
mkdir -p /usr/share/doc/telcosec/
if [ -d /tmp/docs ]; then
  cp -rf /tmp/docs/. /usr/share/doc/telcosec/
  find /usr/share/doc/telcosec/ -type f -exec chmod 644 {} +
fi

echo "Configuring Firefox enterprise policies..."
mkdir -p /etc/firefox/policies/
cat << 'EOF' > /etc/firefox/policies/policies.json
{
  "policies": {
    "DisableAppUpdate": true,
    "DisableTelemetry": true,
    "DisableFirefoxStudies": true,
    "DisablePocket": true,
    "CaptivePortal": false,
    "DNSOverHTTPS": {"Enabled": false},
    "OfferToSaveLogins": false,
    "PasswordManagerEnabled": false,
    "SearchSuggestEnabled": false,
    "OverrideFirstRunPage": "",
    "OverridePostUpdatePage": "",
    "Homepage": {
      "URL": "file:///usr/share/doc/telcosec/index.html",
      "Locked": false,
      "StartPage": "homepage"
    }
  }
}
EOF

# 5. Network: DHCP default + dedicated monitoring interface
echo "Configuring network defaults..."
mkdir -p /etc/NetworkManager/conf.d
cat << 'EOF' > /etc/NetworkManager/conf.d/telcosec.conf
[main]
dhcp=internal

[device]
wifi.scan-rand-mac-address=no
carrier-wait-timeout=2000

[connection]
ipv4.dhcp-timeout=10
ipv6.dhcp-timeout=10
ipv4.may-fail=yes
ipv6.may-fail=yes
EOF

mkdir -p /etc/netplan
cat << 'EOF' > /etc/netplan/90-telcosec-ens160.yaml
network:
  version: 2
  renderer: NetworkManager
  ethernets:
    ens160:
      dhcp4: true
      dhcp6: true
      optional: true
EOF

cat << 'EOF' > /usr/local/bin/telcosec-mon-setup
#!/bin/bash
WLAN=$(iw dev 2>/dev/null | awk '/Interface/{print $2}' | grep -vm1 '^mon' || true)
if [ -z "$WLAN" ]; then
  echo "telcosec-mon-setup: no wireless interface found, skipping mon0 creation"
  exit 0
fi
if ip link show mon0 &>/dev/null; then
  echo "telcosec-mon-setup: mon0 already exists"
  exit 0
fi
echo "telcosec-mon-setup: creating mon0 from ${WLAN}"
ip link set "$WLAN" down
iw dev "$WLAN" interface add mon0 type monitor 2>/dev/null || \
  airmon-ng start "$WLAN" 2>/dev/null || true
ip link set mon0 up 2>/dev/null || true
ip link set "$WLAN" up 2>/dev/null || true
EOF
chmod +x /usr/local/bin/telcosec-mon-setup

cat << 'EOF' > /etc/systemd/system/telcosec-mon.service
[Unit]
Description=TelcoSec Monitoring Interface (mon0)
After=network.target
Wants=network.target

[Service]
Type=oneshot
ExecStart=/usr/local/bin/telcosec-mon-setup
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF
systemctl enable telcosec-mon.service 2>/dev/null || true

# 6. Automatic Desktop Launcher Trust & Executable Permissions (XFCE/GIO)
echo "Deploying Desktop launcher trust initializer..."
cat << 'EOF' > /usr/local/bin/telcosec-desktop-trust
#!/bin/bash
# Ensures desktop launchers are executable and marked trusted in XFCE/GIO
if [ -d "$HOME/Desktop" ]; then
    chmod 755 "$HOME/Desktop"/*.desktop 2>/dev/null || true
    for f in "$HOME/Desktop"/*.desktop; do
        [ -f "$f" ] || continue
        gio set -t string "$f" metadata::trusted true 2>/dev/null || true
        gio set -t string "$f" metadata::trusted yes 2>/dev/null || true
    done
fi
EOF
chmod 755 /usr/local/bin/telcosec-desktop-trust

mkdir -p /etc/xdg/autostart
cat << 'EOF' > /etc/xdg/autostart/telcosec-desktop-trust.desktop
[Desktop Entry]
Type=Application
Name=TelcoSec Desktop Trust Initializer
Comment=Ensures desktop shortcuts are trusted and executable
Exec=/usr/local/bin/telcosec-desktop-trust
Terminal=false
StartupNotify=false
Hidden=false
OnlyShowIn=XFCE;
EOF
chmod 644 /etc/xdg/autostart/telcosec-desktop-trust.desktop

# Note: Wireshark preferences (capture.default_interface=mon0, prom_mode, etc.)
# are written later by 08-system-optimization.sh from the canonical
# builder/wireshark/preferences file — not duplicated here.

grep -q '^TERMINAL=' /etc/environment 2>/dev/null && \
  sed -i 's/^TERMINAL=.*/TERMINAL=terminator/' /etc/environment || \
  echo 'TERMINAL=terminator' >> /etc/environment

update-alternatives --set x-terminal-emulator /usr/bin/terminator 2>/dev/null || true

mkdir -p /etc/skel/.config
cat << 'EOF' > /etc/skel/.config/mimeapps.list
[Default Applications]
x-scheme-handler/terminal=net.tenshu.Terminator.desktop
EOF
if [ -d /home/telcosec ]; then
  cp /etc/skel/.config/mimeapps.list /home/telcosec/.config/mimeapps.list
  chown telcosec:telcosec /home/telcosec/.config/mimeapps.list
fi

# Disable Ubuntu crash reporter
systemctl disable apport 2>/dev/null || true
systemctl mask apport 2>/dev/null || true
rm -f /etc/apport/crashdb.conf 2>/dev/null || true

# 7. tmux configuration & Telecom RAN Status Monitor
echo "Deploying telcosec-ran-status telemetry helper..."
cat << 'EOF' > /usr/local/bin/telcosec-ran-status
#!/bin/bash
# =============================================================================
# telcosec-ran-status — Live RAN & SDR Hardware Telemetry for TelcoChiselOS
# =============================================================================

PRINT_SUMMARY() {
    # 1-line summary for tmux status bar
    local sdr_cnt=0
    local sdr_names=""
    if lsusb 2>/dev/null | grep -qi "2500\|USRP\|National Instruments"; then
        sdr_cnt=$((sdr_cnt+1))
        sdr_names="${sdr_names}USRP "
    fi
    if lsusb 2>/dev/null | grep -qi "1d50:6089\|HackRF"; then
        sdr_cnt=$((sdr_cnt+1))
        sdr_names="${sdr_names}HackRF "
    fi
    if lsusb 2>/dev/null | grep -qi "BladeRF\|2cf0:5246"; then
        sdr_cnt=$((sdr_cnt+1))
        sdr_names="${sdr_names}BladeRF "
    fi
    if lsusb 2>/dev/null | grep -qi "LimeSDR\|0403:601f"; then
        sdr_cnt=$((sdr_cnt+1))
        sdr_names="${sdr_names}LimeSDR "
    fi
    if lsusb 2>/dev/null | grep -qi "RTL2838\|RTL2832"; then
        sdr_cnt=$((sdr_cnt+1))
        sdr_names="${sdr_names}RTL-SDR "
    fi

    local core_status="Off"
    if systemctl is-active open5gs-amfd >/dev/null 2>&1 || systemctl is-active open5gs-upfd >/dev/null 2>&1; then
        core_status="5G-UP"
    elif ip link show ogstun >/dev/null 2>&1; then
        core_status="Core-TUN"
    fi

    local vpn_status="None"
    if ip link show tun0 >/dev/null 2>&1; then
        vpn_status="VPN"
    elif ip link show wg0 >/dev/null 2>&1; then
        vpn_status="WG"
    fi

    if [ "$sdr_cnt" -gt 0 ]; then
        echo -n "📡 [${sdr_names% }] | 📶 ${core_status} | 🛡️ ${vpn_status}"
    else
        echo -n "📡 [No SDR] | 📶 ${core_status} | 🛡️ ${vpn_status}"
    fi
}

PRINT_FULL() {
    clear
    echo -e "\033[1;36m=== 📡 TelcoChisel Live RAN & SDR Hardware Telemetry ===\033[0m"
    echo -e "\033[1;30mTimestamp: $(date -u '+%Y-%m-%d %H:%M:%S UTC')\033[0m\n"
    
    echo -e "\033[1;33m[1] Connected SDR Transceivers & RF Probes:\033[0m"
    local found_sdr=0
    if command -v uhd_find_devices &>/dev/null; then
        local uhd_out
        uhd_out=$(uhd_find_devices 2>&1 | grep -E "type:|product:|serial:" || true)
        if [ -n "$uhd_out" ]; then
            echo -e "  \033[1;32m✓ USRP Hardware:\033[0m\n$uhd_out"
            found_sdr=1
        fi
    fi
    if lsusb 2>/dev/null | grep -qi "1d50:6089\|HackRF"; then
        echo -e "  \033[1;32m✓ HackRF One (USB)\033[0m"
        found_sdr=1
    fi
    if lsusb 2>/dev/null | grep -qi "BladeRF\|2cf0:5246"; then
        echo -e "  \033[1;32m✓ Nuand BladeRF 2.0 micro (USB 3.0)\033[0m"
        found_sdr=1
    fi
    if lsusb 2>/dev/null | grep -qi "LimeSDR\|0403:601f"; then
        echo -e "  \033[1;32m✓ LimeSDR Transceiver\033[0m"
        found_sdr=1
    fi
    if lsusb 2>/dev/null | grep -qi "RTL2838\|RTL2832"; then
        echo -e "  \033[1;32m✓ RTL-SDR Receiver (R820T2/R828D)\033[0m"
        found_sdr=1
    fi
    if [ "$found_sdr" -eq 0 ]; then
        echo -e "  \033[1;31m✗ No SDR transceivers detected (Check USB / PCIe links)\033[0m"
    fi

    echo -e "\n\033[1;33m[2] SIM & Smart Card Readers:\033[0m"
    local found_sim=0
    if lsusb 2>/dev/null | grep -qi "simtrace\|sysmocom"; then
        echo -e "  \033[1;32m✓ Sysmocom SIMtrace 2 Hardware Attached\033[0m"
        found_sim=1
    fi
    if lsusb 2>/dev/null | grep -qi "smart card\|ccid\|omnikey\|acr38\|gemalto"; then
        echo -e "  \033[1;32m✓ PCSC Smart Card Reader Attached\033[0m"
        found_sim=1
    fi
    if [ "$found_sim" -eq 0 ]; then
        echo -e "  \033[1;30m- No SIMtrace or CCID readers attached\033[0m"
    fi

    echo -e "\n\033[1;33m[3] Cellular Virtual Interfaces & Zero-Drop MTU:\033[0m"
    ip -brief addr show ogstun uesimtun0 srsran_tun tun_srsue 2>/dev/null || echo -e "  \033[1;30m- No active cellular TUN interfaces\033[0m"

    local usbfs_mb
    usbfs_mb=$(cat /sys/module/usbcore/parameters/usbfs_memory_mb 2>/dev/null || echo "N/A")
    echo -e "  USBFS Memory Buffer : \033[1;36m${usbfs_mb} MB\033[0m (Target: 1000 MB)"
}

if [ "$1" = "--summary" ]; then
    PRINT_SUMMARY
    exit 0
elif [ "$1" = "--watch" ]; then
    while true; do
        PRINT_FULL
        sleep 2
    done
else
    PRINT_FULL
fi
EOF
chmod 755 /usr/local/bin/telcosec-ran-status

echo "Configuring advanced tmux status, Zsh integration, and defaults..."
cat << 'EOF' > /etc/skel/.tmux.conf
# =============================================================================
# TelcoChisel OS — Advanced Tmux Configuration for Telecom Red Team
# =============================================================================

# 1. Shell & Terminal Setup (Default to Zsh with TrueColor)
set -g default-shell /bin/zsh
set -g default-command "${SHELL}"
set -g default-terminal "screen-256color"
set-option -sa terminal-overrides ",xterm-256color:RGB"
set -ga terminal-overrides ",*256col*:Tc"
set -s escape-time 0
set -g focus-events on

# 2. Ergonomic Prefix Keys (Ctrl+b & Ctrl+a)
set -g prefix C-b
set -g prefix2 C-a
bind C-a send-prefix

# 3. Mouse & History
set -g mouse on
set -g history-limit 50000

# 4. 1-Based Indexing for Windows & Panes
set -g base-index 1
setw -g pane-base-index 1
set -g renumber-windows on

# 5. Intuitive Window Splitting (Preserving Working Directory)
bind | split-window -h -c "#{pane_current_path}"
bind - split-window -v -c "#{pane_current_path}"
bind _ split-window -v -c "#{pane_current_path}"
unbind '"'
unbind %

# 6. Pane Navigation (Vim Keys & Alt+Arrow Direct Navigation)
bind h select-pane -L
bind j select-pane -D
bind k select-pane -U
bind l select-pane -R

bind -n M-Left select-pane -L
bind -n M-Right select-pane -R
bind -n M-Up select-pane -U
bind -n M-Down select-pane -D

bind -n M-h select-pane -L
bind -n M-j select-pane -D
bind -n M-k select-pane -U
bind -n M-l select-pane -R

# 7. Pane Resizing (Prefix + Shift + Vim Keys)
bind -r H resize-pane -L 5
bind -r J resize-pane -D 5
bind -r K resize-pane -U 5
bind -r L resize-pane -R 5

# 8. Vi Mode Copy & System Clipboard Integration
setw -g mode-keys vi
bind -T copy-mode-vi v send-keys -X begin-selection
bind -T copy-mode-vi y send-keys -X copy-pipe-and-cancel "xclip -in -selection clipboard 2>/dev/null || true"
bind -T copy-mode-vi Enter send-keys -X copy-pipe-and-cancel "xclip -in -selection clipboard 2>/dev/null || true"

# 9. Quick Config Reload
bind r source-file ~/.tmux.conf \; display-message "⚡ Tmux configuration reloaded successfully!"

# 10. Cyberpunk Dark Status Bar with Live RAN Telemetry
set -g status-interval 3
set -g status-style bg='#0e121a',fg='#e6edf3'
set -g status-left-length 40
set -g status-right-length 120

set -g status-left '#[bg=#00ffd5,fg=#0e121a,bold] 📡 TELCO-SEC #[bg=default,fg=default] '
set -g status-right '#[fg=#e8921e,bold]#(/usr/local/bin/telcosec-ran-status --summary 2>/dev/null) #[fg=#00ffd5,bold]@#h #[fg=#ffffff,bold]%H:%M:%S '
set -g status-justify left

setw -g window-status-current-style bg='#00ffd5',fg='#0e121a',bold
setw -g window-status-current-format ' #I:#W#F '

setw -g window-status-style bg=default,fg='#8b949e'
setw -g window-status-format ' #I:#W '

set -g pane-border-style fg='#21262d'
set -g pane-active-border-style fg='#00ffd5'

set -g message-style bg='#00ffd5',fg='#0e121a',bold
set -g message-command-style bg='#e8921e',fg='#0e121a',bold

set -g bell-action none
set -g visual-bell off
EOF

if [ -d /home/telcosec ]; then
    cp /etc/skel/.tmux.conf /home/telcosec/.tmux.conf
    chown telcosec:telcosec /home/telcosec/.tmux.conf
fi

# 8. LightDM GTK Greeter configuration
echo "Branding LightDM login screen..."
mkdir -p /etc/lightdm
cat << 'EOF' > /etc/lightdm/lightdm-gtk-greeter.conf
[greeter]
background=/usr/share/backgrounds/telcosec/wallpaper.jpg
theme-name=Yaru-bark-dark
icon-theme-name=Papirus-Dark
font-name=Ubuntu 11
xft-antialias=true
xft-dpi=96
xft-hintstyle=hintslight
xft-rgba=rgb
indicators=~host;~spacer;~clock;~spacer;~session;~language;~power
clock-format=%d %b, %H:%M
hide-user-image=true
EOF

# 10. i3 Tiling Window Manager Configuration (Telecom Red Team Operational Mode)
echo "Configuring i3 Tiling Window Manager for Telecom Red Team Operations..."
mkdir -p /etc/skel/.config/i3 /etc/skel/.config/i3status /etc/skel/.config/rofi /etc/skel/.config/picom

# 10.1 Dedicated i3 Configuration
cat << 'EOF' > /etc/skel/.config/i3/config
# TelcoChisel i3 Configuration — Telecom Red Team Operational Mode (RFS Style)
set $mod Mod4

font pango:Fira Code, Ubuntu Mono 11

# Cyberpunk & Dark Tactical Theme
# class                 border  bground text    indicator child_border
client.focused          #00ffd5 #0e121a #ffffff #00ffd5   #00ffd5
client.focused_inactive #21262d #0e121a #8b949e #21262d   #21262d
client.unfocused        #161b22 #0e121a #6e7681 #161b22   #161b22
client.urgent           #ff4466 #ff4466 #ffffff #ff4466   #ff4466
client.placeholder      #0e121a #0e121a #ffffff #0e121a   #0e121a
client.background       #0e121a

# Windows & Floating Rules
floating_modifier $mod
default_border pixel 2
default_floating_border pixel 2

for_window [window_role="pop-up"] floating enable
for_window [window_role="task_dialog"] floating enable
for_window [class="(?i)calamares"] floating enable
for_window [title="TelcoSec Pre-flight Doctor"] floating enable, resize set 960 640
for_window [title="TelcoSec Hardware Probe"] floating enable, resize set 960 640
for_window [title="5G SA Core Status"] floating enable, resize set 960 640
for_window [title="10GbE Network Zero-Drop Tuning"] floating enable, resize set 960 640
for_window [title="TelcoSec ProLabs Range Status"] floating enable, resize set 960 640
for_window [title="TelcoSec Academy Course Manager"] floating enable, resize set 960 640
for_window [class="Gqrx"] floating enable, resize set 1100 750
for_window [class="Inspectrum"] floating enable, resize set 1100 750
for_window [class="URH"] floating enable, resize set 1200 800

# 7 Dedicated Telecom Operational Workspaces (Harmonized with XFCE)
set $ws1 "1: 📡 RF-DSP"
set $ws2 "2: 📻 GSM-RAN"
set $ws3 "3: ⚡ CORE-5G"
set $ws4 "4: 🧪 PRO-LABS"
set $ws5 "5: 🎓 ACADEMY"
set $ws6 "6: 🔍 DISSECT"
set $ws7 "7: 📝 EVIDENCE"

# Switch Workspaces
bindsym $mod+1 workspace $ws1
bindsym $mod+2 workspace $ws2
bindsym $mod+3 workspace $ws3
bindsym $mod+4 workspace $ws4
bindsym $mod+5 workspace $ws5
bindsym $mod+6 workspace $ws6
bindsym $mod+7 workspace $ws7

# Move Containers to Workspaces
bindsym $mod+Shift+1 move container to workspace $ws1
bindsym $mod+Shift+2 move container to workspace $ws2
bindsym $mod+Shift+3 move container to workspace $ws3
bindsym $mod+Shift+4 move container to workspace $ws4
bindsym $mod+Shift+5 move container to workspace $ws5
bindsym $mod+Shift+6 move container to workspace $ws6
bindsym $mod+Shift+7 move container to workspace $ws7

# Auto-Assignment of Telecom Applications to Workspaces
assign [class="(?i)gnuradio|gqrx|inspectrum|urh|gpredict|cubicsdr"] $ws1
assign [class="(?i)osmocom|openbts|yate|kalibrate|modmobmap"]       $ws2
assign [class="(?i)open5gs|ueransim|srsran|5ghoul"]                $ws3
assign [title="(?i)prolabs"]                                       $ws4
assign [title="(?i)academy|course"]                                $ws5
assign [class="(?i)wireshark"]                                     $ws6
assign [class="(?i)firefox|chromium|cherrytree|leafpad|mousepad"]  $ws7

# Core Navigation & Window Controls
bindsym $mod+Return exec terminator
bindsym $mod+d exec rofi -show drun -show-icons
bindsym $mod+Shift+q kill
bindsym $mod+Shift+c reload
bindsym $mod+Shift+r restart
bindsym $mod+Shift+e exec xfce4-session-logout

# Window Focus (Vim keys & Arrows)
bindsym $mod+h focus left
bindsym $mod+j focus down
bindsym $mod+k focus up
bindsym $mod+l focus right
bindsym $mod+Left focus left
bindsym $mod+Down focus down
bindsym $mod+Up focus up
bindsym $mod+Right focus right

# Move Focused Window
bindsym $mod+Shift+h move left
bindsym $mod+Shift+j move down
bindsym $mod+Shift+k move up
bindsym $mod+Shift+l move right

# Layout Controls
bindsym $mod+b split h
bindsym $mod+v split v
bindsym $mod+f fullscreen toggle
bindsym $mod+s layout stacking
bindsym $mod+w layout tabbed
bindsym $mod+e layout toggle split
bindsym $mod+Shift+space floating toggle
bindsym $mod+space focus mode_toggle

# Direct Telecom Red Team Diagnostic Popups
bindsym $mod+F1 exec --no-startup-id terminator -T "TelcoSec Pre-flight Doctor" --geometry=960x640 -e "telcosec check; echo ''; read -p 'Press enter to exit...'"
bindsym $mod+F2 exec --no-startup-id terminator -T "TelcoSec Hardware Probe" --geometry=960x640 -e "telcosec hardware; echo ''; read -p 'Press enter to exit...'"
bindsym $mod+F3 exec --no-startup-id terminator -T "5G SA Core Status" --geometry=960x640 -e "telcosec 5g-sa status; echo ''; read -p 'Press enter to exit...'"
bindsym $mod+F4 exec --no-startup-id terminator -T "10GbE Network Zero-Drop Tuning" --geometry=960x640 -e "sudo telcosec sdr 10g tune; echo ''; read -p 'Press enter to exit...'"
bindsym $mod+F5 exec --no-startup-id terminator -T "TelcoSec ProLabs Range Status" --geometry=960x640 -e "telcosec prolabs status; echo ''; read -p 'Press enter to exit...'"
bindsym $mod+F6 exec --no-startup-id terminator -T "TelcoSec Academy Course Manager" --geometry=960x640 -e "telcosec academy status; echo ''; read -p 'Press enter to exit...'"

# Direct Telecom Tool Launch Shortcuts
bindsym $mod+Shift+w exec --no-startup-id wireshark-mon
bindsym $mod+Shift+g exec --no-startup-id gqrx
bindsym $mod+Shift+s exec --no-startup-id pysim-shell
bindsym $mod+Shift+p exec --no-startup-id sigploit
bindsym $mod+Shift+f exec --no-startup-id 5ghoul-fuzzer
bindsym $mod+Shift+t exec --no-startup-id /usr/local/bin/telcosec-tmux-redteam
bindsym $mod+Shift+x exec --no-startup-id telcosec-prolabs open
bindsym $mod+Shift+m exec --no-startup-id telcosec-academy open
bindsym $mod+Shift+d exec --no-startup-id firefox file:///usr/share/doc/telcosec/index.html

# Operational Status Bar
bar {
    position top
    status_command i3status
    colors {
        background #0e121a
        statusline #00ffd5
        separator  #21262d
        focused_workspace  #00ffd5 #00ffd5 #0e121a
        active_workspace   #21262d #21262d #ffffff
        inactive_workspace #0e121a #0e121a #8b949e
        urgent_workspace   #ff4466 #ff4466 #ffffff
    }
}

# Autostart Programs
exec --no-startup-id feh --bg-fill /usr/share/backgrounds/telcosec/wallpaper.jpg 2>/dev/null || true
exec --no-startup-id picom -b --config /etc/skel/.config/picom/picom.conf 2>/dev/null || true
exec --no-startup-id /usr/local/bin/telcosec-tmux-redteam
EOF

# 10.2 Telecom Telemetry Status Bar Configuration
cat << 'EOF' > /etc/skel/.config/i3status/config
general {
    colors = true
    color_good = "#00ffd5"
    color_degraded = "#f5aa35"
    color_bad = "#ff4466"
    interval = 1
}

order += "wireless _first_"
order += "ethernet _first_"
order += "ethernet prolabs0"
order += "ethernet tun-prolabs"
order += "ethernet wg0"
order += "ethernet tun0"
order += "load"
order += "memory"
order += "tztime utc"
order += "tztime local"

wireless _first_ {
    format_up = "📶 WLAN: %ip (%essid %quality)"
    format_down = "📶 WLAN: down"
}

ethernet _first_ {
    format_up = "🌐 ETH: %ip (%speed)"
    format_down = "🌐 ETH: down"
}

ethernet prolabs0 {
    format_up = "🧪 PROLABS: %ip"
    format_down = ""
}

ethernet tun-prolabs {
    format_up = "🧪 PROLABS-OVPN: %ip"
    format_down = ""
}

ethernet wg0 {
    format_up = "🛡️ WG: %ip"
    format_down = ""
}

ethernet tun0 {
    format_up = "🛡️ VPN: %ip"
    format_down = ""
}

load {
    format = "⚡ CPU: %1min"
}

memory {
    format = "🧠 RAM: %used / %total"
    threshold_degraded = "15%"
    threshold_critical = "5%"
    format_degraded = "⚠️ RAM LOW: %free"
}

tztime utc {
    format = "🌐 UTC: %H:%M:%S"
}

tztime local {
    format = "📅 %Y-%m-%d ⏰ %H:%M:%S"
}
EOF

# 10.3 Rofi Cyberpunk Dark Theme Configuration
cat << 'EOF' > /etc/skel/.config/rofi/config.rasi
configuration {
    modi: "drun,run,window";
    font: "Fira Code Medium 12";
    show-icons: true;
    display-drun: "📡 TelcoSec [100 Tools]";
    display-run: "⚡ Exec";
    display-window: "🪟 Windows";
    drun-display-format: "{name}";
}

@theme "/dev/null"

* {
    bg: #0e121a;
    bg-alt: #161b22;
    fg: #e6edf3;
    accent-cyan: #00f2ff;
    accent-teal: #00ffd5;
    accent-amber: #e8921e;
    alert-red: #ff4466;
    border-col: #21262d;
    background-color: @bg;
    text-color: @fg;
    margin: 0;
    padding: 0;
}

window {
    width: 680px;
    border: 2px solid;
    border-color: @accent-teal;
    border-radius: 8px;
    padding: 20px;
}

inputbar {
    children: [prompt, entry];
    background-color: @bg-alt;
    border-radius: 6px;
    padding: 10px 14px;
    margin: 0 0 16px 0;
    border: 1px solid @border-col;
}

prompt {
    text-color: @accent-cyan;
    font: "Fira Code Bold 12";
    margin: 0 10px 0 0;
}

entry {
    placeholder: "Search 100 telecom tools, ProLabs ranges, Academy labs, SDR drivers...";
    placeholder-color: #6e7681;
    text-color: @fg;
}

listview {
    lines: 10;
    columns: 1;
    scrollbar: false;
}

element {
    padding: 8px 12px;
    border-radius: 4px;
    background-color: transparent;
    text-color: @fg;
}

element selected {
    background-color: @bg-alt;
    border: 1px solid @accent-teal;
    text-color: @accent-teal;
}

element-icon {
    size: 24px;
    margin: 0 12px 0 0;
}

element-text {
    vertical-align: 0.5;
    text-color: inherit;
}
EOF

# 10.4 Picom Compositor Configuration for Glitch-Free FFT Waterfalls
cat << 'EOF' > /etc/skel/.config/picom/picom.conf
# =============================================================================
# TelcoChisel OS — Picom GLX Compositor Configuration
# Optimized for zero-drop SDR FFT waterfall rendering.
#
# Design principles:
#   1. GLX backend with XPresent VSync — lowest GPU-to-display latency path.
#   2. use-damage = false — redraws the entire frame each tick, avoiding
#      partial-update artifacts on high-frequency OpenGL SDR waterfalls.
#   3. unredirect_on_fullscreen — SDR windows that go fullscreen bypass the
#      compositor entirely (raw GPU scanout) for maximum throughput.
#   4. SDR tools (Gqrx, Inspectrum, GNU Radio, URH, Wireshark) are excluded
#      from ALL opacity, shadow, and fading rules to eliminate overhead.
#   5. Conky HUD excluded from shadows so it renders as a flat surface overlay.
# =============================================================================

# ── Backend ──────────────────────────────────────────────────────────────────
backend = "glx";
glx-no-stencil = true;
glx-copy-from-front = false;

# ── VSync ────────────────────────────────────────────────────────────────────
# xpresent: uses X11 Present extension for sub-millisecond vsync accuracy.
# Falls back to drm if xpresent is unavailable (older mesa / nvidia prop).
vsync = true;
vblank-mode = "xpresent";
glx-use-copysubbuffer-mesa = false;

# ── Damage tracking ──────────────────────────────────────────────────────────
# CRITICAL for SDR waterfall: use-damage=false forces full-frame redraws.
# This prevents the partial-damage algorithm from leaving stale FFT columns
# when the waterfall scrolls faster than the compositor damage region updates.
use-damage = false;

# ── Full-screen unredirect ────────────────────────────────────────────────────
# SDR apps (Gqrx, GNU Radio, Inspectrum) that go fullscreen for waterfall
# analysis bypass the compositor entirely → raw GPU scanout, zero overhead.
unredir-if-possible = true;
unredir-if-possible-delay = 0;
unredir-if-possible-exclude = [
  "class_g = 'Conky'",
  "class_g = 'xfce4-panel'"
];

# ── Opacity ──────────────────────────────────────────────────────────────────
active-opacity   = 1.0;
inactive-opacity = 0.95;
frame-opacity    = 1.0;
inactive-opacity-override = false;

# SDR + critical windows always 100% opacity — no translucency overhead
opacity-rule = [
  "100:class_g = 'Gqrx'",
  "100:class_g = 'Inspectrum'",
  "100:class_g *=  'gnuradio'",
  "100:class_g = 'URH'",
  "100:class_g = 'universal-radio-hacker'",
  "100:class_g = 'Wireshark'",
  "100:class_g = 'firefox'",
  "100:class_g = 'Conky'",
  "100:name    *=  'GNU Radio Companion'",
  "100:name    *=  'Inspectrum'",
  "100:name    *=  'GQRX'",
  "100:name    *=  'Wireshark'",
  "92:class_g  = 'Terminator' && !focused",
  "100:class_g = 'Terminator' && focused"
];

# ── Fading ───────────────────────────────────────────────────────────────────
# Fast fade deltas keep UI snappy; SDR/fullscreen apps are excluded.
fading      = true;
fade-delta  = 5;
fade-in-step  = 0.04;
fade-out-step = 0.04;
no-fading-openclose = false;
no-fading-destroyed-argb = true;

fade-exclude = [
  "class_g = 'Gqrx'",
  "class_g = 'Inspectrum'",
  "class_g *=  'gnuradio'",
  "class_g = 'URH'",
  "class_g = 'universal-radio-hacker'",
  "class_g = 'Wireshark'",
  "name    *=  'GNU Radio Companion'",
  "class_g = 'Conky'"
];

# ── Shadow ────────────────────────────────────────────────────────────────────
# Subtle tactical shadows; SDR tools, Conky HUD, and notifications excluded.
shadow         = true;
shadow-radius  = 10;
shadow-opacity = 0.35;
shadow-offset-x = -8;
shadow-offset-y = -8;

shadow-exclude = [
  "name    = 'Notification'",
  "class_g = 'Conky'",
  "class_g ?= 'Notify-osd'",
  "class_g = 'Cairo-clock'",
  "class_g = 'Gqrx'",
  "class_g = 'Inspectrum'",
  "class_g *=  'gnuradio'",
  "class_g = 'URH'",
  "class_g = 'universal-radio-hacker'",
  "class_g = 'Wireshark'",
  "name    *=  'GNU Radio Companion'",
  "name    *=  'GQRX'",
  "_GTK_FRAME_EXTENTS@:c"
];

# ── Window type overrides ─────────────────────────────────────────────────────
# Dock (xfce4-panel), desktop (wallpaper), and tooltip get zero overhead.
wintypes = {
  tooltip      = { fade = false; shadow = false; opacity = 1.0; };
  dock         = { shadow = false; opacity = 1.0; };
  desktop      = { shadow = false; };
  dnd          = { shadow = false; };
  popup_menu   = { opacity = 1.0; };
  dropdown_menu = { opacity = 1.0; };
};
EOF
# Ensure picom config is also deployed to /etc/xdg for system-wide default
mkdir -p /etc/xdg/picom
cp /etc/skel/.config/picom/picom.conf /etc/xdg/picom/picom.conf

# 10.5 Telecom Red Team Tmux Operational Workspace Script
cat << 'EOF' > /usr/local/bin/telcosec-tmux-redteam
#!/bin/bash
# =============================================================================
# telcosec-tmux-redteam — Telecom Red Team Multi-Window Operational Environment
# =============================================================================
SESSION="telco-redteam"

if ! tmux has-session -t "$SESSION" 2>/dev/null; then
    # Window 1: OPERATOR (4-Pane Live Command & Control Matrix)
    tmux new-session -d -s "$SESSION" -n "OPERATOR"
    
    # Split horizontally (Top / Bottom)
    tmux split-window -v -t "$SESSION:1"
    # Split top pane into Top-Left and Top-Right
    tmux split-window -h -t "$SESSION:1.1"
    # Split bottom pane into Bottom-Left and Bottom-Right
    tmux split-window -h -t "$SESSION:1.3"
    
    # Pane 1 (Top-Left): Real-time RAN Hardware & SDR Transceiver Telemetry
    tmux send-keys -t "$SESSION:1.1" "/usr/local/bin/telcosec-ran-status --watch" C-m
    
    # Pane 2 (Top-Right): 5G SA Core & Diagnostic Doctor
    tmux send-keys -t "$SESSION:1.2" "telcosec 5g-sa status; echo ''; telcosec check" C-m
    
    # Pane 3 (Bottom-Left): Live Telecom System Logs
    tmux send-keys -t "$SESSION:1.3" "clear; echo '=== 📡 Telecom Kernel & Protocol Logs ==='; journalctl -f -n 25 -o short-iso" C-m
    
    # Pane 4 (Bottom-Right): Primary Operator Action Shell (Zsh + Conda SDR)
    tmux send-keys -t "$SESSION:1.4" "clear; echo '=== ⚡ Telecom Red Team Shell (Zsh / SDR Ready) ==='; conda activate telcosec-sdr 2>/dev/null || true" C-m
    
    # Window 2: RAN-SNIFF (Air Interface & GSMTAP Analysis)
    tmux new-window -t "$SESSION" -n "RAN-SNIFF"
    tmux split-window -v -t "$SESSION:2"
    tmux send-keys -t "$SESSION:2.1" "clear; echo '=== 📡 GSMTAP & Cellular Protocol Sniffer ==='; echo 'Run: gsmtap  (or tshark -i any -f \"udp port 4729 or udp port 47290\")'; gsmtap" C-m
    tmux send-keys -t "$SESSION:2.2" "clear; echo '=== 📻 RF & Cellular Survey Shell ==='; echo 'Available: gqrx, inspectrum, urh, kalibrate-rtl, srsran_sniffer'; conda activate telcosec-sdr 2>/dev/null || true" C-m
    
    # Window 3: SIGNALING (Core Protocol Audit, Fuzzing & SIM Extraction)
    tmux new-window -t "$SESSION" -n "SIGNALING"
    tmux split-window -h -t "$SESSION:3"
    tmux send-keys -t "$SESSION:3.1" "clear; echo '=== ⚡ Signaling & Fuzzing (SigPloit / 5Ghoul / DiaFuzzer) ==='; cd /opt/telcosec/sigploit 2>/dev/null || cd ~" C-m
    tmux send-keys -t "$SESSION:3.2" "clear; echo '=== 💳 SIM & Smart Card Security (pySim-shell / SIMtrace2) ==='; cd /opt/telcosec/pysim 2>/dev/null || cd ~" C-m
    
    # Window 4: NET-STATE (10GbE Network Zero-Drop, Routing & SCTP Sockets)
    tmux new-window -t "$SESSION" -n "NET-STATE"
    tmux send-keys -t "$SESSION:4" "clear; echo '=== 🌐 Network Interfaces, SCTP Sockets & Tunnels ==='; ip -brief addr; echo ''; ss -S -a 2>/dev/null || true; echo ''; sudo netstat -tulpn" C-m
    
    # Select Window 1 and focus the interactive operator prompt
    tmux select-window -t "$SESSION:1"
    tmux select-pane -t "$SESSION:1.4"
fi

terminator -e "tmux attach-session -t $SESSION" 2>/dev/null || tmux attach-session -t "$SESSION"
EOF
chmod +x /usr/local/bin/telcosec-tmux-redteam

# 10.6 Deploy LightDM Session Selector Hook
cat << 'EOF' > /usr/local/bin/telcosec-session-select
#!/bin/bash
# Selects desktop session based on kernel cmdline 'desktop=i3'
if grep -q "desktop=i3" /proc/cmdline 2>/dev/null; then
    mkdir -p /etc/lightdm/lightdm.conf.d
    cat > /etc/lightdm/lightdm.conf.d/50-telcosec-autologin.conf << 'LIGHTDM'
[Seat:*]
autologin-user=telcosec
autologin-user-timeout=0
user-session=i3
LIGHTDM
fi
EOF
chmod +x /usr/local/bin/telcosec-session-select

# Add systemd oneshot to execute session selector before LightDM starts
cat << 'EOF' > /etc/systemd/system/telcosec-session-select.service
[Unit]
Description=TelcoSec Boot Desktop Session Selector
Before=lightdm.service
DefaultDependencies=no

[Service]
Type=oneshot
ExecStart=/usr/local/bin/telcosec-session-select

[Install]
WantedBy=multi-user.target
EOF
systemctl enable telcosec-session-select.service 2>/dev/null || true

# Deploy TelcoSec ProLabs, Academy, and Red Team binaries
if [ -d /tmp/scripts/bin ]; then
    cp -f /tmp/scripts/bin/telcosec-prolabs /usr/local/bin/telcosec-prolabs 2>/dev/null || true
    cp -f /tmp/scripts/bin/telcosec-academy /usr/local/bin/telcosec-academy 2>/dev/null || true
    chmod 755 /usr/local/bin/telcosec-prolabs /usr/local/bin/telcosec-academy 2>/dev/null || true
fi

# Copy i3 configs to home if exists
if [ -d /home/telcosec ]; then
    mkdir -p /home/telcosec/.config/i3 /home/telcosec/.config/i3status /home/telcosec/.config/rofi /home/telcosec/.config/picom
    cp -r /etc/skel/.config/i3 /home/telcosec/.config/ 2>/dev/null || true
    cp -r /etc/skel/.config/i3status /home/telcosec/.config/ 2>/dev/null || true
    cp -r /etc/skel/.config/rofi /home/telcosec/.config/ 2>/dev/null || true
    cp -r /etc/skel/.config/picom /home/telcosec/.config/ 2>/dev/null || true
    chown -R telcosec:telcosec /home/telcosec/.config || true
fi


