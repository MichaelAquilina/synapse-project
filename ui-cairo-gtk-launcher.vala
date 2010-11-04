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

namespace Sezen
{
  public class UILauncher
  {
    private UIInterface ui;
    private SettingsWindow sett;
    private DataSink global_data_sink;
    public UILauncher ()
    {
      ui = null;
      global_data_sink = new DataSink ();
      sett = new SettingsWindow ();
      
      bind_keyboard_shortcut ();
      
      init_ui (sett.get_current_theme ());
      
      sett.theme_selected.connect (init_ui);
    }
    private void init_ui (Type t)
    {
      if (ui != null)
        ui.hide(); //TODO: destroy?
      ui = (UIInterface)GLib.Object.new (t);
      // Data Sink MUST be initialized after constructor
      ui.set_data_sink (global_data_sink);
      ui.show_settings_clicked.connect (()=>{
        sett.show_all ();
      });
      ui.show ();
    }
    private void bind_keyboard_shortcut ()
    {
      var registry = GtkHotkey.Registry.get_default ();
      GtkHotkey.Info hotkey;
      try
      {
        if (registry.has_hotkey ("sezen2", "activate"))
        {
          hotkey = registry.get_hotkey ("sezen2", "activate");
        }
        else
        {
          hotkey = new GtkHotkey.Info ("sezen2", "activate",
                                       "<Control>space", null);
          registry.store_hotkey (hotkey);
        }
        debug ("Binding activation to %s", hotkey.signature);
        hotkey.bind ();
        hotkey.activated.connect ((event_time) =>
        {
          if (this.ui == null)
            return;
          this.ui.show ();
          this.ui.present_with_time (event_time);
        });
      }
      catch (Error err)
      {
        warning ("%s", err.message);
      }/* */
    }
  }
  

  
  public static int main (string[] argv)
  {
    Gtk.init (ref argv);
    var launcher = new UILauncher ();
    Gtk.main ();
    return 0;
  }
}
