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
using Gee;

namespace Synapse.Gui
{
  public class SettingsWindow : Gtk.Window
  {
    class PluginTileObject: UI.Widgets.AbstractTileObject
    {
      public DataSink.PluginRegistry.PluginInfo pi { get; construct set; }
      
      public signal void configure ();

      public PluginTileObject (DataSink.PluginRegistry.PluginInfo info)
      {
        GLib.Object (name: info.title,
                     description: info.description,
                     icon: info.icon_name,
                     pi: info,
                     show_action_button: info.runnable,
                     add_button_stock: Gtk.STOCK_YES,
                     remove_button_stock: Gtk.STOCK_NO);
      }

      construct
      {
        sub_description_title = _("Status");

        add_button_tooltip = _("Enable this plugin");
        remove_button_tooltip = _("Disable this plugin");

        var help_button = new Gtk.Button ();
        help_button.set_image (
          new Gtk.Image.from_stock (Gtk.STOCK_HELP,
                                    Gtk.IconSize.SMALL_TOOLBAR));
        help_button.set_tooltip_markup (_("About this plugin"));
        help_button.clicked.connect (() =>
        {
          string id = Synapse.Utils.extract_type_name (pi.plugin_type);
          string address = "http://synapse.zeitgeist-project.com/wiki/index.php?title=Plugins/%s". printf (id);
          Synapse.CommonActions.open_uri (address);
        });
        add_user_button (help_button);
        
        if (pi.plugin_type.is_a (typeof (Synapse.Configurable)))
        {
          var config_button = new Gtk.Button ();
          config_button.set_image (
            new Gtk.Image.from_stock (Gtk.STOCK_PREFERENCES,
                                      Gtk.IconSize.SMALL_TOOLBAR));
          config_button.set_tooltip_markup (_("Configure plugin"));
          config_button.clicked.connect (() =>
          {
            this.configure ();
          });
          
          add_user_button (config_button);
        }
      }

      public void update_state (bool enabled)
      {
        this.enabled = enabled && pi.runnable;

        if (!this.enabled)
        {
          sub_description_text = pi.runnable ? _("Disabled") : pi.runnable_error;
        }
        else
        {
          sub_description_text = _("Enabled");
        }
      }
      
      public void refresh ()
      {
        DataSink.PluginRegistry.PluginInfo info;
        var registry = DataSink.PluginRegistry.get_default ();
        info = registry.get_plugin_info_for_type (pi.plugin_type);
        
        if (pi.runnable != info.runnable)
        {
          pi.runnable = info.runnable;
          pi.runnable_error = info.runnable_error;
          this.show_action_button = info.runnable;
          if (!info.runnable && this.enabled) this.enabled = false;

          update_state (this.enabled);
        }
      }
    }
    
    class UIConfig: ConfigObject
    {
      public string ui_type { get; set; default = "default"; }
      public bool show_indicator { get; set; default = true; }
    }

    private struct Theme
    {
      string name;
      string description;
      Type tclass;
      
      Theme (string name, string desc, Type obj_type)
      {
        this.name = name;
        this.description = desc;
        this.tclass = obj_type;
      }
    }

    private string selected_theme;
    private Gee.Map<string, Theme?> themes;
    private bool autostart;
    private unowned DataSink data_sink;
    private Gtk.ListStore model;
    private UIConfig config;
    
    public bool indicator_active { get { return config.show_indicator; } }

    public SettingsWindow (DataSink data_sink)
    {
      this.title = _("Synapse - Settings");
      this.data_sink = data_sink;
      this.set_position (WindowPosition.CENTER);
      this.set_size_request (500, 450);
      this.resizable = false;
      this.delete_event.connect (this.hide_on_delete);

      config = (UIConfig)
        ConfigService.get_default ().bind_config ("ui", "global", typeof (UIConfig));

      init_settings ();
      build_ui ();
      
      this.tile_view.map.connect (this.init_plugin_tiles);
      this.tile_view.visibility_notify_event.connect (() => { this.refresh_tiles (); return false; });
    }

    private void init_themes ()
    {
      themes = new Gee.HashMap<string, Theme?>();

      themes["default"] = Theme (_("Default"), "", typeof (SynapseWindow));
      themes["mini"] = Theme (_("Mini"), "", typeof (SynapseWindowMini));
      themes["dual"] = Theme (_("Dual"), "", typeof (SynapseWindowTwoLines));
      themes["virgilio"] = Theme (_("Virgilio"), "", typeof (SynapseWindowVirgilio));

      selected_theme = config.ui_type;
    }
    
    private void init_plugin_tiles ()
    {
      tile_view.clear ();
      var arr = new Gee.ArrayList<DataSink.PluginRegistry.PluginInfo> ();
      arr.add_all (DataSink.PluginRegistry.get_default ().get_plugins ());
      arr.sort ((a, b) => 
      {
        unowned DataSink.PluginRegistry.PluginInfo p1 =
          (DataSink.PluginRegistry.PluginInfo) a;
        unowned DataSink.PluginRegistry.PluginInfo p2 =
          (DataSink.PluginRegistry.PluginInfo) b;
        return strcmp (p1.title, p2.title);
      });
      
      foreach (var pi in arr)
      {
        var tile = new PluginTileObject (pi);
        tile_view.append_tile (tile);
        tile.update_state (data_sink.is_plugin_enabled (pi.plugin_type));
        
        tile.active_changed.connect ((tile_obj) =>
        {
          PluginTileObject pto = tile_obj as PluginTileObject;
          pto.update_state (!tile_obj.enabled);
          data_sink.set_plugin_enabled (pto.pi.plugin_type, tile_obj.enabled);
        });
        
        tile.configure.connect ((tile_obj) =>
        {
          PluginTileObject pto = tile_obj as PluginTileObject;
          var plugin = data_sink.get_plugin (pto.pi.plugin_type.name ()) as Configurable;
          return_if_fail (plugin != null);

          var widget = plugin.create_config_widget ();
          var dialog = new Gtk.Dialog.with_buttons (_("Configure plugin"),
                                                    this,
                                                    Gtk.DialogFlags.MODAL | Gtk.DialogFlags.NO_SEPARATOR,
                                                    Gtk.STOCK_CLOSE, null);
          dialog.set_default_size (300, 200);
          (dialog.get_content_area () as Gtk.Container).add (widget);
          dialog.run ();
          dialog.destroy ();
        });
      }
    }
    
    private void refresh_tiles ()
    {
      GLib.List<unowned UI.Widgets.AbstractTileObject> tiles = tile_view.get_tiles ();
      foreach (unowned UI.Widgets.AbstractTileObject pti in tiles)
      {
        (pti as PluginTileObject).refresh ();
      }
    }
    
    private void init_general_options ()
    {
      autostart = false;
    }

    private void init_settings ()
    {
      init_themes ();
      init_general_options ();
    }
    
    private UI.Widgets.TileView tile_view;

    private static string? get_name_from_key (uint keyval, Gdk.ModifierType mods)
    {
      unowned string keyname = Gdk.keyval_name (Gdk.keyval_to_lower (keyval));
      if (keyname == null) return null;
      
      string res = "";
      if (Gdk.ModifierType.SHIFT_MASK in mods) res += "<Shift>";
      if (Gdk.ModifierType.CONTROL_MASK in mods) res += "<Control>";
      if (Gdk.ModifierType.MOD1_MASK in mods) res += "<Alt>";
      if (Gdk.ModifierType.MOD2_MASK in mods) res += "<Mod2>";
      if (Gdk.ModifierType.MOD3_MASK in mods) res += "<Mod3>";
      if (Gdk.ModifierType.MOD4_MASK in mods) res += "<Mod4>";
      if (Gdk.ModifierType.MOD5_MASK in mods) res += "<Mod5>";
      if (Gdk.ModifierType.META_MASK in mods) res += "<Meta>";
      if (Gdk.ModifierType.SUPER_MASK in mods) res += "<Super>";
      if (Gdk.ModifierType.HYPER_MASK in mods) res += "<Hyper>";

      res += keyname;
      return res;
    }
    
    private void build_ui ()
    {
      var main_vbox = new VBox (false, 12);
      main_vbox.border_width = 12;
      this.add (main_vbox);
      
      var tabs = new Gtk.Notebook ();
      var general_tab = new VBox (false, 6);
      general_tab.border_width = 12;
      var plugin_tab = new VBox (false, 6);
      plugin_tab.border_width = 12;
      main_vbox.pack_start (tabs);
      tabs.append_page (general_tab, new Label (_("General")));
      tabs.append_page (plugin_tab, new Label (_("Plugins")));
      
      /* General Tab */
      var theme_frame = new Frame (null);
      theme_frame.set_shadow_type (Gtk.ShadowType.NONE);
      var theme_frame_label = new Label (null);
      theme_frame_label.set_markup (Markup.printf_escaped ("<b>%s</b>", _("Behavior & Look")));
      theme_frame.set_label_widget (theme_frame_label);

      var behavior_vbox = new VBox (false, 6);
      var align = new Alignment (0.5f, 0.5f, 1.0f, 1.0f);
      align.set_padding (6, 12, 12, 12);
      align.add (behavior_vbox);
      theme_frame.add (align);
      
      /* Select theme combobox row */
      var row = new HBox (false, 6);
      behavior_vbox.pack_start (row, false);
      var select_theme_label = new Label (_("Theme:"));
      row.pack_start (select_theme_label, false, false);
      row.pack_end (build_theme_combo (), false, false);

      /* Autostart checkbox */
      var autostart = new CheckButton.with_label (_("Startup on login"));
      autostart.active = autostart_exists ();
      autostart.toggled.connect (this.autostart_toggled);
      behavior_vbox.pack_start (autostart, false);
      
      /* Notification icon */
      var notification = new CheckButton.with_label (_("Show notification icon"));
      notification.active = config.show_indicator;
      notification.toggled.connect ((tb) =>
      {
        config.show_indicator = tb.get_active ();
        this.notify_property ("indicator-active");
      });
      behavior_vbox.pack_start (notification, false);

      general_tab.pack_start (theme_frame, false);

      /* Keybinding treeview */
      var shortcut_frame = new Frame (null);
      shortcut_frame.set_shadow_type (Gtk.ShadowType.NONE);
      var shortcut_frame_label = new Label (null);
      shortcut_frame_label.set_markup (Markup.printf_escaped ("<b>%s</b>", _("Shortcuts")));
      shortcut_frame.set_label_widget (shortcut_frame_label);
      align = new Alignment (0.5f, 0.5f, 1.0f, 1.0f);
      align.set_padding (6, 12, 12, 12);

      var shortcut_scroll = new Gtk.ScrolledWindow (null, null);    
      shortcut_scroll.set_shadow_type (ShadowType.IN);
      shortcut_scroll.set_policy (PolicyType.AUTOMATIC, PolicyType.AUTOMATIC);
      var tree_vbox = new VBox (false, 6);
      Gtk.TreeView treeview = new Gtk.TreeView ();
      tree_vbox.pack_start (shortcut_scroll);
      shortcut_scroll.add (treeview);
      align.add (tree_vbox);
      shortcut_frame.add (align);
      general_tab.pack_start (shortcut_frame, true, true);
      
      model = new Gtk.ListStore (2, typeof (string), typeof (string));
      treeview.set_model (model);

      Gtk.CellRenderer ren;
      Gtk.TreeViewColumn col;
      ren = new CellRendererText ();
      col = new TreeViewColumn.with_attributes (_("Action"), ren, "text", 0);
      treeview.append_column (col);

      ren = new CellRendererAccel ();
      (ren as CellRendererAccel).editable = true;
      (ren as CellRendererAccel).accel_mode = Gtk.CellRendererAccelMode.OTHER;
      (ren as CellRendererAccel).accel_edited.connect (
        (a, path, accel_key, accel_mods, keycode) =>
      {
        string? keyname = get_name_from_key (accel_key, accel_mods);
        this.set_keybinding (keyname ?? "");
      });
      (ren as CellRendererAccel).accel_cleared.connect (
        (a, path) =>
      {
        this.set_keybinding ("");
      });
      col = new TreeViewColumn.with_attributes (_("Shortcut"), ren, "text",1);
      treeview.append_column (col);

      // add the actual item
      Gtk.TreeIter iter;
      model.append (out iter);
      model.set (iter, 0, _("Activate"));
      
      /* Add info */
      
      var info_box = new HBox (false, 6);
      var info_image = new Image.from_stock (STOCK_INFO, IconSize.MENU);
      info_box.pack_start (info_image, false);
      var info_label = new Label (Markup.printf_escaped ("<span size=\"small\">%s</span>",
            _("Click the shortcut you wish to change and press the new shortcut.")));
      info_label.set_use_markup(true);
      info_label.set_alignment (0.0f, 0.5f);
      info_label.wrap = true;
      info_box.pack_start (info_label);
      info_box.show_all ();

      tree_vbox.pack_start (info_box, false);

      /* Plugin Tab */
      var scroll = new Gtk.ScrolledWindow (null, null);
      scroll.set_policy (Gtk.PolicyType.NEVER, Gtk.PolicyType.AUTOMATIC);
      scroll.set_shadow_type (Gtk.ShadowType.IN);
      tile_view = new UI.Widgets.TileView ();
      tile_view.icon_size = 32;
      tile_view.show ();
      scroll.add_with_viewport (tile_view);
      scroll.show ();

      plugin_tab.pack_start (scroll);

      /* Button */
      var bbox = new Gtk.HButtonBox ();
      bbox.set_layout (Gtk.ButtonBoxStyle.END);
      var close_button = new Gtk.Button.from_stock (Gtk.STOCK_CLOSE);
      close_button.clicked.connect (() => { this.hide (); });
      bbox.pack_start (close_button);
      
      main_vbox.pack_start (bbox, false);
      
      main_vbox.show_all ();
    }
    
    public signal void keybinding_changed (string keybinding);
    
    public void set_keybinding (string key, bool emit = true)
    {
      if (model != null)
      {
        Gtk.TreeIter iter;
        if (model.get_iter_first (out iter))
        {
          model.set (iter, 1, key != "" ? key : _("Disabled"));
        }
      }
      if (emit) keybinding_changed (key);
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
      foreach (Gee.Map.Entry<string,Theme?> e in themes.entries)
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
        config.ui_type = selected_theme;
        theme_selected (get_current_theme ());
      });
      
      return cb_themes;
    }
    public Type get_current_theme ()
    {
      return themes[selected_theme].tclass;
    }

    public signal void theme_selected (Type theme);

    private string autostart_file = 
      Path.build_filename (Environment.get_user_config_dir (), "autostart",
                           "synapse.desktop", null);

    private bool autostart_exists ()
    {
      return FileUtils.test (autostart_file, FileTest.EXISTS);
    }

    private void autostart_toggled (Widget w)
    {
      CheckButton check = w as CheckButton;
      bool active = check.active;
      if (!active && autostart_exists ())
      {
        // delete the autostart file
        FileUtils.remove (autostart_file);
      }
      else if (active && !autostart_exists ())
      {
        string autostart_entry = 
          "[Desktop Entry]\n" +
          "Name=Synapse\n" +
          "Exec=synapse --startup\n" +
          "Encoding=UTF-8\n" +
          "Type=Application\n" +
          "X-GNOME-Autostart-enabled=true\n" +
          "Icon=synapse\n";

        // create the autostart file
        string autostart_dir = 
          Path.build_filename (Environment.get_user_config_dir (),
                               "autostart", null);
        if (!FileUtils.test (autostart_dir, FileTest.EXISTS | FileTest.IS_DIR))
        {
          DirUtils.create_with_parents (autostart_dir, 0755);
        }
        try
        {
          FileUtils.set_contents (autostart_file, autostart_entry);
        }
        catch (Error err)
        {
          var d = new MessageDialog (this, 0, MessageType.ERROR, 
                                     ButtonsType.CLOSE,
                                     "%s", err.message);
          d.run ();
          d.destroy ();
        }
      }
    }
  }
}
