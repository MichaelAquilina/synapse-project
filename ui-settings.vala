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

    public SettingsWindow ()
    {
      this.title = "Sezen 2 - Settings"; //TODO: i18n
      this.set_size_request (500, 450);
      init_settings ();
      build_ui ();
    }
    private void init_settings ()
    {
      SezenSettings sett = SezenSettings ()
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
      
    }
  }
}
