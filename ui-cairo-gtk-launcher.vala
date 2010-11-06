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

namespace Synapse
{
  public class UILauncher
  {
    private static bool is_startup = false;
    const OptionEntry[] options =
    {
      {
        "startup", 's', 0, OptionArg.NONE,
        out is_startup, "Startup mode (don't show the UI immediately)", ""
      },
      {
        null
      }
    };
    
    private UIInterface ui;
    private SettingsWindow sett;
    private DataSink data_sink;
    public UILauncher ()
    {
      ui = null;
      data_sink = new DataSink ();
      sett = new SettingsWindow (data_sink);
      
      bind_keyboard_shortcut ();
      
      init_ui (sett.get_current_theme ());
      if (!is_startup) ui.show ();
      
      sett.theme_selected.connect (init_ui);
    }
    private void init_ui (Type t)
    {
      ui = GLib.Object.new (t, "data-sink", data_sink) as UIInterface;
      ui.show_settings_clicked.connect (()=>{
        sett.show ();
      });
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
          if (this.ui == null) return;
          this.ui.show ();
          this.ui.present_with_time (event_time);
        });
      }
      catch (Error err)
      {
        warning ("%s", err.message);
      }/* */
    }

    public void run ()
    {
      Environment.unset_variable ("DESKTOP_AUTOSTART_ID");
      Gtk.main ();
    }

    public static int main (string[] argv)
    {
      var context = new OptionContext (" - Awn Applet Activation Options");
      context.add_main_entries (options, null);
      context.add_group (Gtk.get_option_group (false));
      try
      {
        context.parse (ref argv);

        Gtk.init (ref argv);
        var launcher = new UILauncher ();
        launcher.run ();
      }
      catch (Error err)
      {
        warning ("%s", err.message);
      }
      return 0;
    }
  }
}
