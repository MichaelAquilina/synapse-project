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
  public class UILauncher: GLib.Object
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
    
    private SettingsWindow settings;
    private DataSink data_sink;
    private Gui.KeyComboConfig key_combo_config;
    private Gui.CategoryConfig category_config;
    private string current_shortcut;
    private ConfigService config;
#if HAVE_INDICATOR
    private AppIndicator.Indicator indicator;
#else
    private StatusIcon status_icon;
#endif
    private Gui.IController controller;
    
    public UILauncher ()
    {
      config = ConfigService.get_default ();
      data_sink = new DataSink ();
      key_combo_config = (Gui.KeyComboConfig) config.bind_config ("ui", "shortcuts", typeof (Gui.KeyComboConfig));
      category_config = (Gui.CategoryConfig) config.get_config ("ui", "categories", typeof (Gui.CategoryConfig));
      key_combo_config.update_bindings ();
      register_plugins ();
      settings = new SettingsWindow (data_sink, key_combo_config);
      settings.keybinding_changed.connect (this.change_keyboard_shortcut);
      
      Keybinder.init ();
      bind_keyboard_shortcut ();
      
      controller = GLib.Object.new (typeof (Gui.Controller), 
                                    "data-sink", data_sink,
                                    "key-combo-config", key_combo_config,
                                    "category-config", category_config) as Gui.IController;

      controller.show_settings_requested.connect (()=>{
        settings.show ();
        uint32 timestamp = Gtk.get_current_event_time ();
        /* Make sure that the settings window is showed */
        settings.deiconify ();
        settings.present_with_time (timestamp);
        settings.get_window ().raise ();
        settings.get_window ().focus (timestamp);
        controller.summon_or_vanish ();
      });

      init_ui (settings.get_current_theme ());

      if (!is_startup) controller.summon_or_vanish ();
      
      settings.theme_selected.connect (init_ui);
      init_indicator ();
    }
    
    private void init_ui (Type t)
    {
      controller.set_view (t);
    }
    
    ~UILauncher ()
    {
      config.save ();
    }
    
    private void init_indicator ()
    {
      var indicator_menu = new Gtk.Menu ();
      var activate_item = new ImageMenuItem.with_label (_ ("Activate"));
      activate_item.set_image (new Gtk.Image.from_stock (Gtk.Stock.EXECUTE, Gtk.IconSize.MENU));
      activate_item.activate.connect (() =>
      {
        show_ui (Gtk.get_current_event_time ());
      });
      indicator_menu.append (activate_item);
      var settings_item = new ImageMenuItem.from_stock (Gtk.Stock.PREFERENCES, null);
      settings_item.activate.connect (() => { settings.show (); });
      indicator_menu.append (settings_item);
      indicator_menu.append (new SeparatorMenuItem ());
      var quit_item = new ImageMenuItem.from_stock (Gtk.Stock.QUIT, null);
      quit_item.activate.connect (Gtk.main_quit);
      indicator_menu.append (quit_item);
      indicator_menu.show_all ();

#if HAVE_INDICATOR
      // Why Category.OTHER? See >
      // https://bugs.launchpad.net/synapse-project/+bug/685634/comments/13
      indicator = new AppIndicator.Indicator ("synapse", "synapse",
                                              AppIndicator.IndicatorCategory.OTHER);

      indicator.set_menu (indicator_menu);
      if (settings.indicator_active) indicator.set_status (AppIndicator.IndicatorStatus.ACTIVE);

      settings.notify["indicator-active"].connect (() =>
      {
        indicator.set_status (settings.indicator_active ?
          AppIndicator.IndicatorStatus.ACTIVE : AppIndicator.IndicatorStatus.PASSIVE);
      });
#else
      status_icon = new StatusIcon.from_icon_name ("synapse");

      status_icon.popup_menu.connect ((icon, button, event_time) =>
      {
        indicator_menu.popup (null, null, status_icon.position_menu, button, event_time);
      });
      status_icon.activate.connect (() =>
      {
        show_ui (Gtk.get_current_event_time ());
      });
      status_icon.set_visible (settings.indicator_active);
      
      settings.notify["indicator-active"].connect (() =>
      {
        status_icon.set_visible (settings.indicator_active);
      });
#endif
    }
    
    private void register_plugins ()
    {
      // while we don't install proper plugin .so files, we'll do it this way
      Type[] plugin_types =
      {
#if TEST_PLUGINS
        typeof (TestSlowPlugin),
        typeof (HelloWorldPlugin),
#endif
        // item providing plugins
        typeof (DesktopFilePlugin),
        typeof (HybridSearchPlugin),
        typeof (GnomeSessionPlugin),
        typeof (GnomeScreenSaverPlugin),
        typeof (SystemManagementPlugin),
        typeof (CommandPlugin),
        typeof (RhythmboxActions),
        typeof (BansheeActions),
        typeof (DirectoryPlugin),
        typeof (LaunchpadPlugin),
        typeof (CalculatorPlugin),
        typeof (SelectionPlugin),
        typeof (SshPlugin),
        typeof (XnoiseActions),
        typeof (ChromiumPlugin),
        // typeof (FileOpPlugin),
        // typeof (PidginPlugin),
        // typeof (ChatActions),
#if HAVE_ZEITGEIST
        typeof (ZeitgeistPlugin),
        typeof (ZeitgeistRelated),
#endif
#if HAVE_LIBREST
        typeof (ImgUrPlugin),
#endif
        // action-only plugins
        typeof (DevhelpPlugin),
        typeof (OpenSearchPlugin),
        typeof (LocatePlugin),
        typeof (PastebinPlugin),
        typeof (DictionaryPlugin)
      };
      foreach (Type t in plugin_types)
      {
        data_sink.register_static_plugin (t);
      }
    }
    
    protected void show_ui (uint32 event_time)
    {
      //if (this.ui == null) return;
      //this.ui.show_hide_with_time (event_time);
      if (this.controller == null) return;
      this.controller.summon_or_vanish ();
    }

    private void bind_keyboard_shortcut ()
    {
      current_shortcut = key_combo_config.activate;
      Utils.Logger.log (this, "Binding activation to %s", current_shortcut);
      settings.set_keybinding (current_shortcut, false);
      Keybinder.bind (current_shortcut, handle_shortcut, this);
    }
    
    static void handle_shortcut (string key, void* data)
    {
      ((UILauncher)data).show_ui (Keybinder.get_current_event_time ());
    }

    private void change_keyboard_shortcut (string key)
    {
      Keybinder.unbind (current_shortcut, handle_shortcut);
      current_shortcut = key;
      Keybinder.bind (current_shortcut, handle_shortcut, this);
    }

    public void run ()
    {
      Environment.unset_variable ("DESKTOP_AUTOSTART_ID");
      Gdk.Window.process_all_updates ();
      Gtk.main ();
    }

    private static void load_custom_style ()
    {
      string custom_gtkrc = 
        Path.build_filename (Environment.get_user_config_dir (),
                             "synapse",
                             "gtkrc");

      if (FileUtils.test (custom_gtkrc, FileTest.EXISTS))
      {
        Gtk.rc_add_default_file (custom_gtkrc);
        Gtk.rc_reparse_all ();
      }
    }

    private static void ibus_fix ()
    {
      /* try to fix IBUS input method adding synapse to no-snooper-apps */
      string ibus_no_snooper = GLib.Environment.get_variable ("IBUS_NO_SNOOPER_APPS");
      if (ibus_no_snooper == null || ibus_no_snooper == "")
      {
        GLib.Environment.set_variable ("IBUS_NO_SNOOPER_APPS", "synapse", true);
        return;
      }
      if ("synapse" in ibus_no_snooper) return;
      /* add synapse */
      if (!ibus_no_snooper.has_suffix (","))
        ibus_no_snooper = ibus_no_snooper + ",";
      ibus_no_snooper = ibus_no_snooper + "synapse";
      GLib.Environment.set_variable ("IBUS_NO_SNOOPER_APPS", ibus_no_snooper, true);
    }
    public static int main (string[] argv)
    {
      Utils.Logger.log (null, "Starting up...");
      ibus_fix ();
      Intl.bindtextdomain ("synapse", Config.DATADIR + "/locale");
      var context = new OptionContext (" - Synapse");
      context.add_main_entries (options, null);
      context.add_group (Gtk.get_option_group (false));
      try
      {
        context.parse (ref argv);

        /* Custom style loading must be done before Gtk.init */
        load_custom_style ();
        Gtk.init (ref argv);
        Notify.init ("synapse");
        
        var app = new Unique.App ("org.gnome.Synapse", "");
        if (app.is_running ())
        {
          Utils.Logger.log (null, "Synapse is already running, activating...");
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
