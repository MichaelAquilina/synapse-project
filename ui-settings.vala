/*
 * Copyright (C) 2010 Michal Hruby <michal.mhr@gmail.com>
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA 02110-1301  USA.
 *
 * Authored by Alberto Aldegheri <albyrock87+dev@gmail.com>
 *             Michal Hruby <michal.mhr@gmail.com>
 *
 */

using Gtk;
using Cairo;
using Gee;

namespace Sezen
{
  public class SettingsWindow : Gtk.Window
  {
    private struct Plugin
    {
      string name;
      string description;
      bool enabled;
      Type tclass;
    }
    private struct Theme
    {
      string name;
      string description;
      Type tclass;
    }

    string selected_theme;
    Gee.Map<string, Theme?> themes;
    Gee.Map<string, Plugin?> plugins;
    bool autostart;

    public SettingsWindow ()
    {
      this.title = "Sezen 2 - Settings"; //TODO: i18n
      this.set_position (WindowPosition.CENTER);
      this.set_size_request (500, 450);
      this.resizable = false;
      this.delete_event.connect (this.hide_on_delete);
      init_settings ();
      build_ui ();
    }

    private void init_plugins ()
    {
      plugins = new Gee.HashMap<string, Plugin?>();
      plugins.set ("DesktopFilePlugin",
                   Plugin(){
                     name = "Desktop File", //i18n
                     description = "", //i18n
                     tclass = typeof (DesktopFilePlugin),
                     enabled = true
                   });
      plugins.set ("ZeitgeistPlugin",
                   Plugin(){
                     name = "Zeitgeist", //i18n
                     description = "", //i18n
                     tclass = typeof (ZeitgeistPlugin),
                     enabled = true
                   });
      plugins.set ("HybridSearchPlugin",
                   Plugin(){
                     name = "Hybrid Search", //i18n
                     description = "", //i18n
                     tclass = typeof (HybridSearchPlugin),
                     enabled = true
                   });
      plugins.set ("GnomeSessionPlugin",
                   Plugin(){
                     name = "Gnome Session", //i18n
                     description = "", //i18n
                     tclass = typeof (GnomeSessionPlugin),
                     enabled = true
                   });
      plugins.set ("UPowerPlugin",
                   Plugin(){
                     name = "Power Management", //i18n
                     description = "", //i18n
                     tclass = typeof (UPowerPlugin),
                     enabled = true
                   });
      plugins.set ("TestSlowPlugin",
                   Plugin(){
                     name = "Test Slow Search", //i18n
                     description = "", //i18n
                     tclass = typeof (TestSlowPlugin),
                     enabled = false
                   });
      plugins.set ("CommonActions",
                   Plugin(){
                     name = "Common Actions", //i18n
                     description = "", //i18n
                     tclass = typeof (CommonActions),
                     enabled = true
                   });
      plugins.set ("DictionaryPlugin",
                   Plugin(){
                     name = "Dictionary Plugin", //i18n
                     description = "", //i18n
                     tclass = typeof (DictionaryPlugin),
                     enabled = true
                   });
      // TODO: read from gconf if enabled or not
    }
    private void init_themes ()
    {
      themes = new Gee.HashMap<string, Theme?>();
      themes.set ("Default",
                   Theme(){
                     name = "Default", //i18n
                     description = "", //i18n
                     tclass = typeof (SezenWindow)
                   });
      themes.set ("Mini",
                   Theme(){
                     name = "Mini", //i18n
                     description = "", //i18n
                     tclass = typeof (SezenWindowMini)
                   });

      // TODO: read from gconf the selected one
#if UI_MINI
      selected_theme = "Mini";
#else
      selected_theme = "Default";
#endif
    }
    
    private void init_general_options ()
    {
      autostart = false;
    }

    private void init_settings ()
    {
      init_themes ();
      init_plugins ();
      init_general_options ();
    }

    private void build_ui ()
    {
      var tabs = new Gtk.Notebook ();
      var general_tab = new VBox (false, 4);
      general_tab.border_width = 5;
      var plugin_tab = new VBox (false, 4);
      plugin_tab.border_width = 5;
      this.add (tabs);
      tabs.append_page (general_tab, new Label ("General"));
      tabs.append_page (plugin_tab, new Label ("Plugins"));
      
      HBox row;

      /* General Tab */
      row = new HBox (false, 5);

      row.pack_start (new Label ("Select Theme:"), false, false);
      row.pack_start (build_theme_combo (), false, false);
      general_tab.pack_start (row, false, false);
            
      tabs.show_all ();
    }

    private ComboBox build_theme_combo ()
    {
      var cb_themes = new ComboBox.text ();
      /* Set the model */                  /* key */      /* Label */
      var theme_list = new ListStore (2, typeof(string), typeof(string));
      cb_themes.clear ();
      cb_themes.set_model (theme_list);
      /* Set the renderer only for the Label */
      var ctxt = new CellRendererText();
      cb_themes.pack_start (ctxt, true);
      cb_themes.set_attributes (ctxt, "text", 1);
      /* Pack data into the model and select current theme */
      TreeIter iter;
      foreach (Gee.Map.Entry<string,Theme?> e in themes)
      {
        theme_list.append (out iter);
        theme_list.set (iter, 0, e.key, 1, e.value.name);
        if (e.key == selected_theme)
          cb_themes.set_active_iter (iter);
      }
      /* Listen on value changed */
      cb_themes.changed.connect (() => {
        TreeIter active_iter;
        cb_themes.get_active_iter (out active_iter);
        theme_list.get (active_iter, 0, out selected_theme);
        theme_selected (get_current_theme ());
      });
      
      return cb_themes;
    }
    public Type get_current_theme ()
    {
      return themes.get(selected_theme).tclass;
    }

    public signal void theme_selected (Type theme);
  }
}
