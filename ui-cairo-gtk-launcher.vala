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
  public static int main (string[] argv)
  {
    Gtk.init (ref argv);
#if UI_MINI
    var window = new SezenWindowMini ();
#else
    var window = new SezenWindow ();
#endif
    window.show ();

    //TODO: window.show_settings_clicked.connect (/* SHOW SETTINGS WINDOW */);

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
        window.show ();
        window.present_with_time (event_time);
      });
    }
    catch (Error err)
    {
      warning ("%s", err.message);
    }

    Gtk.main ();
    return 0;
  }
}
