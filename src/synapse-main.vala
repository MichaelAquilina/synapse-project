/*
 * Copyright (C) 2010 Michal Hruby <michal.mhr@gmail.com>
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 *
 * Authored by Alberto Aldegheri <albyrock87+dev@gmail.com>
 *             Michal Hruby <michal.mhr@gmail.com>
 *
 */

using Gtk;
using Synapse.Gui;
using UI;

namespace Synapse
{
  public class UILauncher
  {
    private static bool is_startup = false;
    const OptionEntry[] options =
    {
      {
        "startup", 's', 0, OptionArg.NONE,
        out is_startup, "Startup mode (hide the UI until activated).", ""
      },
      {
        null
      }
    };
    
    private UIInterface? ui;
    private SettingsWindow settings;
    private DataSink data_sink;
    private GtkHotkey.Info? hotkey;
    private ConfigService config;
#if HAVE_INDICATOR
    private AppIndicator.Indicator indicator;
#endif
    
    public UILauncher ()
    {
      ui = null;
      config = ConfigService.get_default ();
      data_sink = new DataSink ();
      register_plugins ();
      settings = new SettingsWindow (data_sink);
      settings.keybinding_changed.connect (this.change_keyboard_shortcut);
      
      bind_keyboard_shortcut ();
      
      init_ui (settings.get_current_theme ());
      if (!is_startup) this.show_ui (Gtk.get_current_event_time ());
      
      settings.theme_selected.connect (init_ui);
      init_indicator ();
    }
    
    ~UILauncher ()
    {
      config.save ();
    }
    
    private void init_ui (Type t)
    {
      ui = GLib.Object.new (t, "data-sink", data_sink) as UIInterface;
      ui.show_settings_clicked.connect (()=>{
        settings.show ();
      });
    }
    
    private void init_indicator ()
    {
#if HAVE_INDICATOR
      indicator = new AppIndicator.Indicator (
        "synapse", "synapse", AppIndicator.Category.APPLICATION_STATUS);

      var indicator_menu = new Menu ();
      var activate_item = new ImageMenuItem.with_label (_ ("Activate"));
      activate_item.set_image (new Gtk.Image.from_stock (Gtk.STOCK_EXECUTE, Gtk.IconSize.MENU));
      activate_item.activate.connect (() =>
      {
        show_ui (Gtk.get_current_event_time ());
      });
      indicator_menu.append (activate_item);
      var settings_item = new ImageMenuItem.from_stock (Gtk.STOCK_PREFERENCES, null);
      settings_item.activate.connect (() => { settings.show (); });
      indicator_menu.append (settings_item);
      indicator_menu.append (new SeparatorMenuItem ());
      var quit_item = new ImageMenuItem.from_stock (Gtk.STOCK_QUIT, null);
      quit_item.activate.connect (Gtk.main_quit);
      indicator_menu.append (quit_item);
      indicator_menu.show_all ();
      
      indicator.set_menu (indicator_menu);
      if (settings.indicator_active) indicator.set_status (AppIndicator.Status.ACTIVE);

      settings.notify["indicator-active"].connect (() =>
      {
        indicator.set_status (settings.indicator_active ?
          AppIndicator.Status.ACTIVE : AppIndicator.Status.PASSIVE);
      });
#endif
    }
    
    private void register_plugins ()
    {
      // while we don't install proper plugin .so files, we'll do it this way
      Type[] plugin_types =
      {
        typeof (DesktopFilePlugin),
        typeof (ZeitgeistPlugin),
        typeof (HybridSearchPlugin),
        //typeof (LocatePlugin),
        typeof (GnomeSessionPlugin),
        typeof (GnomeScreenSaverPlugin),
        typeof (UPowerPlugin),
        typeof (CommandPlugin),
        typeof (RhythmboxActions),
        typeof (BansheeActions),
        typeof (DirectoryPlugin),
#if TEST_PLUGINS
        typeof (TestSlowPlugin),
#endif
        typeof (DictionaryPlugin),
        typeof (DevhelpPlugin)
      };
      foreach (Type t in plugin_types)
      {
        data_sink.register_static_plugin (t);
      }
    }
    
    protected void show_ui (uint32 event_time)
    {
      if (this.ui == null) return;
      this.ui.show_hide_with_time (event_time);
    }
    
    private void bind_keyboard_shortcut ()
    {
      var registry = GtkHotkey.Registry.get_default ();
      try
      {
        if (registry.has_hotkey ("synapse", "activate"))
        {
          hotkey = registry.get_hotkey ("synapse", "activate");
        }
        else
        {
          hotkey = new GtkHotkey.Info ("synapse", "activate",
                                       "<Control>space", null);
          registry.store_hotkey (hotkey);
        }
        debug ("Binding activation to %s", hotkey.signature);
        settings.set_keybinding (hotkey.signature, false);
        hotkey.bind ();
        hotkey.activated.connect ((event_time) => { this.show_ui (event_time); });
      }
      catch (Error err)
      {
        warning ("%s", err.message);
        var d = new MessageDialog (settings.visible ? settings : null, 0, MessageType.ERROR, 
                                     ButtonsType.CLOSE,
                                     "%s", err.message);
        d.run ();
        d.destroy ();
      }/* */
    }
    
    private void change_keyboard_shortcut (string key)
    {
      var registry = GtkHotkey.Registry.get_default ();
      try
      {
        if (hotkey.is_bound ()) hotkey.unbind ();
      }
      catch (Error err)
      {
        warning ("%s", err.message);
      }
      
      try
      {
        if (registry.has_hotkey ("synapse", "activate"))
        {
          registry.delete_hotkey ("synapse", "activate");
        }
        
        if (key != "")
        {
          hotkey = new GtkHotkey.Info ("synapse", "activate",
                                       key, null);
          registry.store_hotkey (hotkey);
          hotkey.bind ();
          hotkey.activated.connect ((event_time) => { this.show_ui (event_time); });
        }
      }
      catch (Error err)
      {
        Gtk.MessageDialog dialog = new Gtk.MessageDialog (this.settings, 0,
          Gtk.MessageType.WARNING, Gtk.ButtonsType.OK,
          "%s", err.message
        );
        dialog.run ();
        dialog.destroy ();
      }
    }

    public void run ()
    {
      Environment.unset_variable ("DESKTOP_AUTOSTART_ID");
      Gtk.main ();
    }

    private static void load_custom_style ()
    {
      string custom_gtkrc = 
        Path.build_filename (Environment.get_user_config_dir (), "synapse",
                             "gtkrc");
      File f = File.new_for_path (custom_gtkrc);
      debug ("Try to load custom gtkrc in %s", custom_gtkrc);
      if (f.query_exists ())
      {
        Gtk.rc_add_default_file (custom_gtkrc);
        Gtk.rc_reparse_all ();
        debug ("Custom style loaded.");
      }
      else
        debug ("Custom style not present.");
    }
    
    public static int main (string[] argv)
    {
      var context = new OptionContext (" - Synapse");
      context.add_main_entries (options, null);
      context.add_group (Gtk.get_option_group (false));
      try
      {
        context.parse (ref argv);

        /* Custom style loading must be done before Gtk.init */
        load_custom_style ();
        Gtk.init (ref argv);
        
        var app = new Unique.App ("org.gnome.Synapse", null);
        if (app.is_running)
        {
          debug ("Synapse is already running, activating...");
          app.send_message (Unique.Command.ACTIVATE, null);
        }
        else
        {
          var launcher = new UILauncher ();
          app.message_received.connect ((cmd, data, event_time) =>
          {
            if (cmd == Unique.Command.ACTIVATE)
            {
              launcher.show_ui (event_time);

              return Unique.Response.OK;
            }

            return Unique.Response.PASSTHROUGH;
          });
          launcher.run ();
        }
      }
      catch (Error err)
      {
        warning ("%s", err.message);
      }
      return 0;
    }
  }
}
