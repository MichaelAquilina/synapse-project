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
    public struct PluginSetting
    {
      bool enabled;
      Type plugin_class;
    }
    public struct SezenSettings
    {
      Type selected_theme;
      Gee.Map<string, Type> themes;
      Gee.Map<string, PluginSetting?> plugins;
      bool autostart;
    }
    SezenSettings sett;
    public SettingsWindow ()
    {
      this.title = "Sezen 2 - Settings"; //TODO: i18n
      this.set_size_request (500, 450);
      this.resizable = false;
      init_settings ();
      build_ui ();
    }
    private void init_settings ()
    {
      sett = SezenSettings ()
      {
        selected_theme = typeof (SezenWindowMini),
        themes = new Gee.HashMap<string, Type>(),
        plugins = new Gee.HashMap<string, PluginSetting?>(),
        autostart = false
      };
      //GLOBAL TODO: i18n
      sett.themes.set ("Default", typeof(SezenWindow));
      sett.themes.set ("Mini", typeof(SezenWindowMini));
      
      //TODO: Make a new Interface to be implemented in Plugins to get name and description
      sett.plugins.set ("Launchers", PluginSetting (){
        enabled = true,
        plugin_class = typeof (DesktopFilePlugin)
      });
      sett.plugins.set ("Zeitgeist", PluginSetting (){
        enabled = true,
        plugin_class = typeof (ZeitgeistPlugin)
      });
      sett.plugins.set ("Hybrid", PluginSetting (){
        enabled = true,
        plugin_class = typeof (HybridSearchPlugin)
      });
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
      ComboBox cb_themes = new ComboBox.text ();
      foreach (Gee.Map.Entry<string,GLib.Type> e in sett.themes)
        cb_themes.append_text (e.key);
      cb_themes.set_active (0);
      row.pack_start (new Label ("Select Theme:"), false, false);
      row.pack_start (cb_themes, false, false);
      general_tab.pack_start (row, false, false);
      
            
      tabs.show_all ();
    }
  }
}
