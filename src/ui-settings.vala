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
using Gee;

namespace Synapse
{
  public class SettingsWindow : Gtk.Window
  {
    class PluginTileObject: UI.Widgets.AbstractTileObject
    {
      public DataSink.PluginRegistry.PluginInfo pi { get; construct set; }
      public PluginTileObject (DataSink.PluginRegistry.PluginInfo info)
      {
        GLib.Object (name: info.title,
                     description: info.description,
                     icon: info.icon_name,
                     pi: info,
                     show_action_button: info.runnable);
      }

      construct
      {
        sub_description_title = "Status"; // FIXME: i18n

        add_button_tooltip = "Enable this plugin"; // FIXME: i18n
        remove_button_tooltip = "Disable this plugin"; // FIXME: i18n
      }

      public void update_state (bool enabled)
      {
        this.enabled = enabled && pi.runnable;

        if (!this.enabled)
        {
          sub_description_text = pi.runnable ? "Disabled" : pi.runnable_error; // i18n!
        }
        else
        {
          sub_description_text = "Enabled"; // i18n!
        }
      }
    }
    
    class UIConfig: ConfigObject
    {
      public string ui_type { get; set; default = "default"; }
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

    public SettingsWindow (DataSink data_sink)
    {
      this.title = "Synapse - Settings"; //TODO: i18n
      this.data_sink = data_sink;
      this.set_position (WindowPosition.CENTER);
      this.set_size_request (500, 450);
      this.resizable = false;
      this.delete_event.connect (this.hide_on_delete);
      
      config = (UIConfig) 
        Configuration.get_default ().get_config ("ui", "global", typeof (UIConfig));

      init_settings ();
      build_ui ();
      
      this.tile_view.map.connect (this.init_plugin_tiles);
    }

    private void init_themes ()
    {
      themes = new Gee.HashMap<string, Theme?>();

      themes["default"] = Theme ("Default", "", typeof (SynapseWindow)); //i18n
      themes["mini"] = Theme ("Mini", "", typeof (SynapseWindowMini)); //i18n
      themes["dual"] = Theme ("Dual", "", typeof (SynapseWindowTwoLines)); //i18n

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
      var main_vbox = new VBox (false, 6);
      main_vbox.border_width = 4;
      this.add (main_vbox);
      
      var tabs = new Gtk.Notebook ();
      var general_tab = new VBox (false, 6);
      general_tab.border_width = 5;
      var plugin_tab = new VBox (false, 6);
      plugin_tab.border_width = 5;
      main_vbox.pack_start (tabs);
      tabs.append_page (general_tab, new Label ("General"));
      tabs.append_page (plugin_tab, new Label ("Plugins"));
      
      /* General Tab */
      var theme_frame = new Frame (null);
      theme_frame.set_shadow_type (Gtk.ShadowType.NONE);
      var theme_frame_label = new Label (null);
      theme_frame_label.set_markup (Markup.printf_escaped ("<b>%s</b>", "Behavior & Look"));
      theme_frame.set_label_widget (theme_frame_label);

      var behavior_vbox = new VBox (false, 4);
      var align = new Alignment (0.5f, 0.5f, 1.0f, 1.0f);
      align.set_padding (0, 0, 10, 0);
      align.add (behavior_vbox);
      theme_frame.add (align);
      
      /* Select theme combobox row */
      var row = new HBox (false, 5);
      behavior_vbox.pack_start (row, false);
      var select_theme_label = new Label ("Select Theme:");
      select_theme_label.xalign = 0.0f;
      row.pack_start (select_theme_label, true, true);
      row.pack_start (build_theme_combo (), false, false);

      /* Autostart checkbox */
      var autostart = new CheckButton.with_label ("Startup on login");
      autostart.active = autostart_exists ();
      autostart.toggled.connect (this.autostart_toggled);
      behavior_vbox.pack_start (autostart, false);

      general_tab.pack_start (theme_frame, false);

      /* keybinding treeview */
      var shortcut_frame = new Frame (null);
      shortcut_frame.set_shadow_type (Gtk.ShadowType.NONE);
      var shortcut_frame_label = new Label (null);
      shortcut_frame_label.set_markup (Markup.printf_escaped ("<b>%s</b>", "Shortcuts"));
      shortcut_frame.set_label_widget (shortcut_frame_label);
      align = new Alignment (0.5f, 0.5f, 1.0f, 1.0f);
      align.set_padding (0, 0, 10, 0);
      
      var tree_vbox = new VBox (false, 4);
      Gtk.TreeView treeview = new Gtk.TreeView ();
      tree_vbox.pack_start (treeview, false);
      align.add (tree_vbox);
      shortcut_frame.add (align);
      general_tab.pack_start (shortcut_frame, false, false);
      
      model = new Gtk.ListStore (2, typeof (string), typeof (string));
      treeview.set_model (model);

      Gtk.CellRenderer ren;
      Gtk.TreeViewColumn col;
      ren = new CellRendererText ();
      col = new TreeViewColumn.with_attributes ("Action", ren, "text", 0); // FIXME: i18n
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
      col = new TreeViewColumn.with_attributes ("Shortcut", ren, "text",1);
      treeview.append_column (col);

      // add the actual item
      Gtk.TreeIter iter;
      model.append (out iter);
      model.set (iter, 0, "Activate");
      
      /* Add info */
      
      var info_box = new HBox (false, 12);
      var info_image = new Image.from_stock (STOCK_INFO, IconSize.DND);
      info_box.pack_start (info_image, false, true);
      var info_label = new Label ("To edit a shortcut, double click it and press a new one.");
      info_box.pack_start (info_label);
      info_box.show_all ();

      tree_vbox.pack_start (info_box, false);

      /* Plugin Tab */
      var scroll = new Gtk.ScrolledWindow (null, null);
      scroll.set_policy (Gtk.PolicyType.NEVER, Gtk.PolicyType.AUTOMATIC);
      tile_view = new UI.Widgets.TileView ();
      tile_view.show_all ();
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
          model.set (iter, 1, key != "" ? key : "Disabled");
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
        Configuration.get_default ().set_config ("ui", "global", config);
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
